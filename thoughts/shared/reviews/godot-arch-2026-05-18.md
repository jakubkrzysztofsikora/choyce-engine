---
date: 2026-05-18
reviewer: godot-arch
commit: 68d73a3
status: complete
---
# Review: Godot Architecture

## Summary
Boot path is broken at the asset layer: `data/themes/choyce_theme.tres` references three fonts that have no `.import` sidecars under any build path I can produce, so the global theme silently fails on every launch and every Control falls back to default fonts. On top of that, the `LandingShell` IA entry only works because of an accidental side-effect inside `ShellNavigator._instant_switch` — the TSCN starts it with `visible = false` while the other four shells start `visible = true`, so for one frame after `_ready` all four "main" shells stack over the landing screen. Finally, the composition root still hand-rolls `OS.get_environment` for `_build_default_profile()` even though `EnvironmentPort` exists and the file's own comment claims that pattern is purged — a regression of Phase 7b.

Three sharpest findings:
1. **Theme broken at boot** — every UI screen renders without the intended fonts/styles.
2. **Shell stacking on first frame** — Create/Play/Library/Parent are visible simultaneously over Landing until `show_shell` runs.
3. **`OS.get_environment` leak in composition root** — `_build_default_profile` violates the Phase 7b boundary that `_resolve_vault_signing_key` was just refactored to respect.

## Findings (severity-ranked)

### Critical (block release)

**C1. Global theme fails to load — every launch.**
`main.gd:802` does `load("res://data/themes/choyce_theme.tres") as Theme`. On a clean worktree after `godot --headless --import` plus a normal `--path .` boot, the loader emits:
```
ERROR: No loader found for resource: res://data/fonts/Nunito-Regular.ttf (expected type: FontFile)
ERROR: res://data/themes/choyce_theme.tres:311 - Parse Error: [ext_resource] referenced non-existent resource at: res://data/fonts/Nunito-Regular.ttf.
ERROR: Failed loading resource: res://data/themes/choyce_theme.tres.
```
Repro: 100% on this worktree (`.claude/worktrees/agent-ab6c256eebf7fbaba`). The `.ttf` files exist in `data/fonts/` but Godot has no `.import` for them — they're treated as raw, not as `FontFile`. The Control sub-tree then runs with engine-default styling — the `_apply_global_theme` cast returns `null` and is silently dropped.
Files: `data/themes/choyce_theme.tres:311`, `src/adapters/inbound/main.gd:801-804`.
Fix candidates: (a) commit `.import` sidecars for the three TTFs, (b) drop the theme cast and `push_error` on load failure so this is loud rather than silent, (c) move font loading to a SystemFont fallback in code.

**C2. Theme load failure is silent.**
`_apply_global_theme` (`main.gd:801-804`) does `var theme := load(...) as Theme; if theme != null: ...`. There is no `push_error`, no telemetry, no `OS.crash` in production. Cert-safety guarantee that visual contrast / dyslexia-font tokens come from `choyce_theme.tres` is now invisibly violated. Anyone running the build today is seeing engine defaults and doesn't know it.
Fix: emit `push_error("Theme failed to load — UI styling will use engine defaults")` on the null branch. Add a unit test that asserts the theme file parses.

### High

**H1. Shell stacking on first frame — `main.tscn` defaults are inconsistent.**
In `main.tscn` only `LandingShell` is marked `visible = false`. `CreateShell`, `PlayShell`, `LibraryShell`, `ParentZoneShell` all default to `visible = true`. The scene tree therefore renders with four full-rect overlapping Control nodes the moment `_ready` starts running. `_navigator.show_shell(SHELL_LANDING)` doesn't run until `main.gd:131`, after `_setup_a11y_ui`, `_apply_navigation_theme`, `_apply_global_theme`, `_register_shells`, `_connect_navigation`, `_wire_shell_dependencies`, mascot wiring, `_apply_localized_text`, and `_setup_transitions` — that's potentially hundreds of ms on first launch and at least one rendered frame where input is dispatched to whichever shell sits on top of the Z-order. On low-end hardware (target audience: kid tablets) the first rendered frame is the wrong shell.
Fix: set every shell in `main.tscn` to `visible = false` except whichever is the boot shell, or call `_navigator._instant_switch(SHELL_LANDING)` synchronously at the top of `_ready` before any other heavy work.

**H2. `OS.get_environment` leak in the composition root — Phase 7b regression.**
`main.gd:169-189` (`_build_default_profile`) calls `OS.get_environment` five times directly. The same file's comment at line 201 says "No application or domain code calls `OS.get_environment` directly" and `_resolve_vault_signing_key` was just refactored to take `EnvironmentPort`. The composition root itself is the worst place to break this rule — every test that wants to override the boot profile now has to munge the process-wide environment. `OSEnvironmentAdapter` is already instantiated at line 115 inside `_ready` for the feature-flag path; pass it in instead.
Fix: thread `_phase1_env` (or a freshly built `OSEnvironmentAdapter`) into `_build_default_profile`. Construct the adapter once at the very top of `_ready` and reuse for both feature flags, profile, and ports.

**H3. `OnboardingService.start_onboarding` invoked twice.**
The headless boot log shows:
```
OnboardingService: event_bus not wired; event lost: OnboardingStepChanged
    [3] _wire_shell_dependencies (main.gd:711)
    [4] _ready (main.gd:125)
...
    [3] _wire_shell_dependencies (main.gd:711)
    [4] _build_default_ports_phase_2 (main.gd:420)
```
Phase 8d re-wires shells after Phase 2 (`main.gd:419-420`) — which is correct so that persistent ports replace stubs — but `CreateShell.setup` is non-idempotent: it re-starts the onboarding state machine. Each kid launch therefore emits two `OnboardingStepChanged` events, the first one is also lost because the event bus wasn't wired to `parent_audit` at Phase 1 (it was — but the `OnboardingService` itself logs as "event_bus not wired", meaning the service is constructed without a bus). Two issues bundled: (a) `OnboardingService` is built without `event_bus` despite one being available; (b) `setup()` is called twice with no idempotency guard.
Files: `src/application/onboarding_service.gd:85`, `src/adapters/inbound/scenes/create/create_shell.gd:177`, `src/adapters/inbound/main.gd:711-721`.
Fix: pass `_phase1_event_bus` into `OnboardingService` on construction; make `CreateShell.setup` reentrant (early-return if already wired with same ports), or extract a separate `rewire_ports` path that doesn't restart onboarding.

**H4. Landing-screen audio files referenced but assets missing.**
`AudioBank` warns on every boot:
```
WARNING: AudioBank: music not found — res://data/audio/music/landing_ambient.mp3
WARNING: AudioBank: voice not found — res://data/audio/voice/greet_landing.mp3
```
…yet `ls data/audio/music/` shows `landing_ambient.mp3` present, and `data/audio/voice/greet_landing.mp3` also present. The same import-pipeline gap from C1 — no `.import` sidecars under `data/audio/{music,voice}/`. Same failure mode: assets silently absent at runtime even though they exist on disk.
Fix: commit the audio `.import` files, or change `AudioBank` to use `FileAccess.file_exists` + a manual loader path so engine-import gaps don't go silent.

### Medium

**M1. `ButtonFeel` autoload connects to `get_tree().node_added` — global O(N) on every spawn.**
`button_feel.gd:33` wires `get_tree().node_added.connect(_on_node_added)`. Every node added anywhere in the scene tree — including throwaway VFX particles, 3D mesh instances inside `WorldRenderer`, tween-owned helpers — triggers `_try_attach`, which `isinstance`-checks against `Button|CheckButton|OptionButton`. For a kid scene with hundreds of props this is a measurable per-frame tax. Worse: this connection is never disconnected. Pair with `_make_toon_material` allocating a fresh `ShaderMaterial` per `MeshInstance3D` in `WorldRenderer` (M3 below) and you get a guaranteed slowdown spike on world load.
Fix: subscribe via `get_tree().get_root().child_entered_tree` scoped to the UI subtree, or expose a `ButtonFeel.attach_subtree(root)` helper for shells to call when they instantiate UI.

**M2. `ButtonFeel._on_press_sfx` uses `Engine.has_singleton("AudioBank")` — wrong API for autoloads.**
`button_feel.gd:84` and `:91` check `Engine.has_singleton("AudioBank")`. Autoloads are **not** engine singletons — they are nodes under `/root/`. `Engine.has_singleton` is for native engine singletons registered through `Engine::add_singleton`. The check therefore always returns `false`, and the code always falls through to the `has_node("/root/AudioBank")` branch. Dead-code defensive check; rename or delete.
Fix: drop the `Engine.has_singleton` arm entirely. Use the `/root/AudioBank` path only, or refactor to a dependency-injected port.

**M3. `WorldRenderer._make_toon_material` allocates a new `ShaderMaterial` per mesh instance.**
`world_renderer.gd:79-85` builds a fresh `ShaderMaterial` for every `MeshInstance3D` it touches — and the prop walker (`_apply_toon_to_prop`, lines 91-101) drills into every `MeshInstance3D` descendant of every glTF prop. A starter world has 17-18 nodes; many props contain multiple sub-meshes. That's easily 100+ `ShaderMaterial` instances per world load, each pinned to the same shader and only differing by `albedo`. The shader's pipeline state can't be shared because the material instances differ; this defeats Godot's per-material batching.
Fix: cache `_make_toon_material(color)` keyed by `color.to_html(false)` (or a quantised palette) so all "Trawa" instances share one material. Even an LRU of 64 entries shrinks the live material set 5-10x.

**M4. `WorldRenderer` uses `ResourceLoader.load` synchronously — blocks main thread.**
`world_renderer.gd:144` does `ResourceLoader.load(gltf_path)`. For 17-18 glTF props on first world load this can stall the main thread for a noticeable chunk on cold cache. Kid UX target on a tablet would be sub-100ms world-switch; this path eats it.
Fix: use `ResourceLoader.load_threaded_request` / `load_threaded_get` with a small loader pool, or pre-warm during onboarding while the mascot is talking.

**M5. `AudioBank` caches are unbounded.**
`audio_bank.gd:25-27` declares `_voice_cache`, `_sfx_cache`, `_music_cache` as plain `Dictionary` with no eviction. Every voice/SFX/music ever touched in a session sticks around. Long-running classroom sessions can accumulate large MP3 streams in RAM. Same recurring finding logged on TASK-028/041/043.
Fix: cap with an LRU (move-to-front on hit) sized to ~32 sfx, ~8 voice, ~4 music.

**M6. `WorldRenderer.clear_world` does not wait for `queue_free`.**
`world_renderer.gd:23-25` queue-frees children then immediately clears `_spawn_points`. If `render_world` is called twice in quick succession (e.g. from a play-shell rapid double-click), `add_child` calls in the second pass land while the first pass's nodes are still alive in tree — temporary double-population, double spawn points, potential physics-server churn. The Wave V3 prop wrapper (`StaticBody3D` + `CollisionShape3D`) makes this much more expensive than plain Node3D churn.
Fix: call `child.queue_free()` and then `child.set_owner(null)` + `remove_child(child)` so the tree reflects the cleared state immediately.

**M7. `LandingScreen` hard-codes Polish strings in code — bypasses `_t()` even though `_localization` is wired.**
`landing_screen.gd:157,163,174` set `_btn_play.text = "ZAGRAJ"`, `_btn_create.text = "ZRÓB"`, `_btn_parent.text = "RODZIC"`. The shell has `_localization: LocalizationPolicyPort` injected via `setup()` and uses it nowhere. This is the same class of bug as the F-056-01 release blocker that Wave C just closed for `create_shell` and `play_shell`. The landing screen is the literal first thing every kid sees and it's hard-coded Polish.
Fix: route through `_localization.translate("ui.landing.play")` etc.; add fallback dictionary like `main.gd._t`. Add the keys to `PolishLocalizationPolicy`.

**M8. `LandingScreen` reads `/root/AudioBank` directly — autoload coupling in scene-level code.**
`landing_screen.gd:234-243` does `has_node("/root/AudioBank")` and `get_node("/root/AudioBank")`. This is the same shape of cross-autoload coupling logged on `ButtonFeel`. For a scene that is part of the hexagonal inbound adapter, the audio dependency should arrive via DI (`setup(profile, project_store, localization, audio_player)`), not a hard-coded autoload path. Today there's no way to silence audio in tests without `add_autoload`-style hacks.
Fix: add an `AudioBankPort` and pass an instance into `setup()`, or use the existing `VoicePromptPort` consistently (the memory file calls this out as a Wave A win — `LandingScreen` regresses it).

### Low / nits

**L1. `IconFont` and `ShellTransition` are preloaded by path even though both declare `class_name`.**
`main.gd:4-5` `preload("res://src/adapters/inbound/shared/ui/icon_font.gd")` and similar for `ShellTransition`. Both files declare `class_name IconFont` / `class_name ShellTransition`. The constants shadow the global class names with local aliases, which means a future contributor can confuse the two. Drop the preloads; the `class_name` registrations are sufficient.

**L2. `class_name` comments on autoloads vs file naming.**
`audio_bank.gd:3` and `button_feel.gd:3` both correctly explain why they cannot declare `class_name`. Good. But the project would benefit from a single doc that surfaces this rule next to the autoload list in `project.godot`; otherwise the next contributor will rediscover it the hard way.

**L3. `InputMapInitializer` uses tabs/spaces inconsistently with the rest of the codebase.**
`src/adapters/inbound/shared/input_map_initializer.gd` is indented with spaces; the rest of `src/adapters/inbound/main.gd` and shells are indented with tabs. Cosmetic; the parser doesn't care, but it foils Godot's "Convert Indent To Tabs" defaults.

**L4. `toon_cel.gdshader` `light()` ignores `rim_amount` and `rim_color` uniforms — dead uniforms.**
Lines 18-19 declare `rim_amount` and `rim_color`, but the shader body never reads them. Either implement the rim pass or drop the uniforms so the inspector doesn't lie about adjustable parameters.

**L5. `toon_cel.gdshader` `fragment()` does `ALBEDO = albedo.rgb * tex_color.rgb` but `light()` does `ALBEDO * mix(...)` — ALBEDO is already the modulated value, so the math is correct but obtuse.**
Add a comment clarifying that `ALBEDO` is preserved across the boundary between `fragment` and `light`.

**L6. `LandingScreen._start_cloud_drift` uses `60.0 - float(i) * 12.0` while the comment says `48 / 36 / 24` — actual durations are `48 / 36 / 24` only if `i ∈ {1, 2, 3}`. Spec matches code, but the comment redundantly restates with a slightly different wording.**

**L7. `main.gd:802` casts the loaded resource via `as Theme` — silent null on failure.**
See C2. The cast plus the `if theme != null` is a common GDScript idiom but actively hides asset breakage. Combine with `push_error` to make load failures visible.

**L8. `_seed_starter_content_if_empty` writes `push_warning("Seeded %d starter worlds…")` even on success — this is information, not a warning. Use `print` or a structured event.**

## Manual test log

| # | Step | Result |
|---|------|--------|
| 1 | `git log --oneline -1` | `68d73a3 feat(audio): SFXPlayer in gameplay uses AudioBank-loaded streams` |
| 2 | `godot --version` | `4.6.1.stable.official.14d19694e` |
| 3 | `timeout 30 godot --editor --headless --quit \| grep ERROR\|Parse\|SCRIPT` | only the Blender-path warning; no parse errors |
| 4 | `godot --headless --import` | completes; Blender import path warning expected |
| 5 | `timeout 12 godot --path . --headless` | boots; theme load fails (see C1/C2), audio missing warnings (H4), onboarding event bus warning twice (H3) |
| 6 | Repeat step 5 to confirm reproducibility | same output |
| 7 | macOS GUI launch (`godot --path . &` + `screencapture`) | **skipped — running in worktree subagent without GUI access; documented as verification gap** |

Verification gap: I did not visually confirm shell stacking on first frame (H1) or the broken theme styling (C1/C2). Both are inferred from code + headless logs. A reviewer with GUI access should screencapture the landing screen + a click into Create within the first 500 ms to confirm both findings.

## Recommendations

Prioritized punch list:

1. **Fix or fail loud on theme load** (C1, C2). Either commit the `.import` sidecars for `data/fonts/*.ttf` or replace `load()` with a path that `push_error`s on null. Same for the missing audio `.import` files (H4). One root cause: import sidecars are not committed to the worktree.
2. **Default every shell to `visible = false` in `main.tscn` except `LandingShell`** (H1). One-line fix per shell node.
3. **Plumb `EnvironmentPort` through `_build_default_profile`** (H2). Eliminates the last `OS.get_environment` direct call in the inbound layer. Mirror the pattern from `_resolve_vault_signing_key`.
4. **Make `CreateShell.setup` reentrant and pass `event_bus` into `OnboardingService`** (H3). Fixes the double-onboarding-start and the "event_bus not wired" warning on every boot.
5. **Cache `ShaderMaterial` by quantised colour and switch glTF prop loading to threaded** (M3, M4). Both targeted at first-world-load latency on the kid-tablet target.
6. **Localize `LandingScreen` button text via `_localization`** (M7). Same release-blocker class as F-056-01 — landing is the first kid-visible screen.
7. **Inject `AudioBank` via a port into `LandingScreen` and `ButtonFeel`** (M8, M2). Removes the last hard `/root/AudioBank` coupling from inbound scenes and unblocks silent-in-tests audio.
8. **Scope `ButtonFeel` node-added subscription to the UI subtree** (M1). Cheap win, removes a global O(N) tax.
9. **Cap `AudioBank` caches with an LRU** (M5).
10. **`WorldRenderer.clear_world` should remove children synchronously, not just `queue_free`** (M6).

Out of scope but worth flagging to the next planner: the worktree has no committed `.godot/imported` cache, which means a clean clone cannot boot to a styled landing screen until someone runs `godot --headless --import` from a machine with valid Blender path. Either commit the `.import` sidecars or add a developer bootstrap script that runs the import pass.
