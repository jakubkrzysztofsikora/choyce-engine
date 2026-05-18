---
date: 2026-05-18
reviewer: ux-kid-flow
commit: 68d73a3
status: complete
---
# Review: UX / Kid Flow

## Summary
The kid-facing surface is a kitchen-sink of well-intentioned features (mascot, sparkles, confetti, sun, clouds, 3D preview, voice CTA timers, onboarding overlay) but the seams are wide and the cognitive load is high for the 5–8 cohort. Three sharpest findings: (1) `LandingScreen` ships hardcoded Polish strings (`"ZAGRAJ"`, `"ZRÓB"`, `"RODZIC"`, `"Choyce"`) baked into the scene-build code with **no `_t()` route at all**, regressing the F-056-01 Wave-A/C l10n work; (2) the entire landing layout is pinned to a 1920×1080 grid via absolute `Vector2` positions with no anchors, so on the 1600×960 project default the close button, sun, and grass strip render off-screen or clipped; (3) the `CreateShell` "3-second CTA idle timer" pattern is broken — `_reset_cta_idle_timer()` creates a *new* `SceneTreeTimer` on every interaction without killing the old one, so multiple TTS prompts can fire in overlap and the timer leaks Callables. The mascot fires hardcoded Polish phrases (`"Spróbuj inaczej!"`, `"Świetnie!"`) that bypass localization too. Net: not release-ready for the kid happy-path.

## Findings (severity-ranked)

### Critical (block release)

- **C1. Landing screen ships hardcoded Polish strings, no localization route.** `landing_screen.gd:142,157,163,174` set `title.text = "Choyce"`, `_btn_play.text = "ZAGRAJ"`, `_btn_create.text = "ZRÓB"`, `_btn_parent.text = "RODZIC"` as bare string literals. Unlike `CreateShell` / `PlayShell` which inject a `LocalizationPolicyPort`, `LandingScreen.setup()` *accepts* `_localization` but never calls `.translate()` anywhere in the file. F-056-01 was claimed CLOSED in MEMORY.md but the very first screen the kid sees regresses it. Worse, the world-picker close button is the literal glyph `"✕"` and the world-card icons (`"🏝"`, `"🚜"`, etc.) are inlined emoji that may not render on the bundled Fredoka/Nunito fonts (those fonts are Latin-only).

- **C2. Landing screen layout is non-responsive — fixed 1920×1080 coordinates on a 1600×960 viewport.** `project.godot` sets `window/size/viewport_width=1600`, `viewport_height=960`. But `landing_screen.gd` hardcodes: sun at `Vector2(1540, 60)` with 192px size (so sun's right edge is at 1732 — 132 px past the 1600 viewport right edge), grass strip at `Vector2(0, 900)` (only 60 px tall window remaining for a 180-px-tall strip — clips bottom), picker close button at `Vector2(1840, 20)` (240 px off-screen on the right), picker scroll at `Vector2(60, 120)` size `Vector2(1800, 580)` (extends 260 px past viewport). No `set_anchors_preset`, no `anchor_right=1.0` on these elements. On the default window the close button is unreachable and grass is clipped. (`canvas_items` stretch mode does not save you here because the elements are positioned past the design size *and* the design size itself does not match the viewport.)

- **C3. `_apply_world_edit_port` gated on `ports_ready`, but `_apply_active_tool()` skips the gate check.** `create_shell.gd:328` correctly disables tool buttons while `_ports_ready==false`. But `_apply_active_tool()` at line 375 only checks `_apply_world_edit_port == null`, not `_ports_ready`. If a tool button is somehow pressed before ports_ready (e.g. focus-driven keyboard navigation while disabled animations haven't kicked in, or a test calling `_apply_active_tool()` directly via the public `_set_active_tool` flow), the kid hits the port mid-init. Safety default for port gating should match Wave-B Phase 8d posture (BLOCK).

### High

- **H1. CTA idle timer leaks `SceneTreeTimer` references and stacks callbacks.** `create_shell.gd:1078-1083` `_reset_cta_idle_timer()` reassigns `_cta_idle_timer = get_tree().create_timer(3.0)` and `.timeout.connect(_on_cta_idle_timeout)` *without disconnecting the previous timer*. The old timer is still in the SceneTree and will fire its `timeout` 3 s after creation regardless. So a kid who taps Place→Paint→Move within 3 s will get 3 different timers all firing `_on_cta_idle_timeout`, racing against `_cta_tts_fired`. The flag mitigates the audio-overlap, but: (a) every interaction creates a new closure-captured Callable, (b) the timer's `timeout` keeps the shell alive across scene transitions (small leak per session). The timer should be a `Timer` node with `.stop()` + `.start()`, not a one-shot `SceneTreeTimer`.

- **H2. Mascot speech bubble fires bare Polish strings, no `_t()`.** `mascot.gd:166` (`say("Spróbuj inaczej!")`) and `_phrase_for()` lines 174–178 (`"Świetnie!"`, `"Brawo!"`, `"Hura! Idziemy bawić się!"`, `"Hej!"`) hardcode Polish. The mascot's `setup()` takes only `event_bus` + `voice_prompt`, no `LocalizationPolicyPort`. F-056-01 regression on the shared UI layer.

- **H3. Mascot speech bubble has no panel background — text is unreadable.** `mascot.gd:72-85` creates a `PanelContainer` named `_speech_panel` but never assigns a `StyleBoxFlat` to its `panel` theme override. The label is dark `Color(0.18, 0.18, 0.18)` on top of whatever happens to be behind the mascot (the bottom-left corner of any shell — often the sky-blue landing background or the dark canvas). Worst case (dark canvas, dark text) → invisible. Theme has a `StyleBoxFlat_panel` default that *should* apply to `PanelContainer/styles/panel`, but the mascot is in a separate layer and the theme propagation is not asserted.

- **H4. `ButtonFeel` auto-wires every Button globally, including `CheckButton` and `OptionButton`, but reads `.size` immediately.** `button_feel.gd:55-57`: when a button is added to the tree, `attach()` reads `btn.size`. For programmatically-created buttons (the entire landing screen!), `size` is `Vector2.ZERO` at that point because the parent container has not laid out yet. The `if btn.size != Vector2.ZERO` guard skips pivot-setting, then the `resized` callback should catch it later — but if a button never resizes (rare, but possible for fixed `custom_minimum_size`), pivot stays at `(0,0)` and the scale-bounce animation pivots from top-left → buttons "jump" left+up when pressed. Easy to verify visually on the landing primary buttons.

- **H5. `ButtonFeel` press SFX has no debounce.** `button_feel.gd:76,79` emit `press` and `play_sfx("ui_click")` on every `button_up`. Kids 5–8 *will* mash-tap. The hover SFX has `HOVER_THROTTLE_MSEC=100` but `ui_click` does not, so the SFX pool (`SFX_POOL_SIZE=6` in `audio_bank.gd:22`) gets exhausted on rapid taps, audio clipping audible.

- **H6. `PlayShell.show_celebration()` uses `_t()` for column labels but the celebration close button text is "Zagraj jeszcze" only in the fallback dict — no `play.celebration.close` key in shared translations file.** Need to verify translations bundle, but the inline-fallback pattern (`play_shell.gd:432-468`) hard-codes Polish in every shell — drift risk between the inline fallbacks and the actual `LocalizationPolicy` lookup table.

- **H7. Voice overlay record button is a 48×48 emoji "🎤".** `voice_assistant_overlay.gd:36-38` — for a 5–8 kid on a tablet, 48 px is well below the Apple HIG/Material recommended 44 pt touch target (≈ 88 px in this UI's density), and the emoji glyph itself may not render in the bundled fonts. Mascot uses 160×220 — touch targets are inconsistent.

### Medium

- **M1. Confetti emits over the celebration panel but does not respect viewport scale.** `play_shell.gd:344-358` reads `get_viewport().get_visible_rect().size` and positions the confetti at `Vector2(vp_size.x / 2.0, 80.0)`. Fine on the design viewport, but if the window resizes the confetti stays at the position recorded at celebration time, not re-anchored. Minor.

- **M2. Landing screen sun position `Vector2(1540, 60)` puts the sun near where the "Choyce" title sits (60, 32) — title at 96 px font size will be ~700 px wide and likely overlap the sun on small screens.** Visual collision risk.

- **M3. CreateShell `_apply_command_to_local_world` mutates the local `World` instance directly after `_apply_world_edit_port.execute()` already applied it server-side — risk of double-apply if port is idempotent or stale-state if port returns success but persisted state differs.** Not strictly a UX bug but the kid will see the local state diverge from a refresh.

- **M4. Onboarding overlay's `_gui_input` listens for any left mouse click anywhere on the screen to emit `advance_requested`.** `onboarding_overlay.gd:81-83` with `mouse_filter = MOUSE_FILTER_PASS`. This is supposed to be a feature (tap-to-advance) but it means a kid clicking a tool button *while the overlay is up* will both advance the overlay AND trigger the tool. Onboarding step coupling to the underlying UI is fragile. Need an "advance only outside target rect" check.

- **M5. Mascot `say()` uses `await get_tree().create_timer(duration_sec).timeout` then unconditionally fades.** If `say()` is called twice quickly (two events in succession), the first `await` resumes after 3 s and fades the bubble, overwriting whatever the second `say()` put there. Should `kill()` the previous fade tween and reset.

- **M6. `VoiceAssistantCard` (Wave V3) has hardcoded Polish labels with typos and no diacritics:** `voice_assistant_card.gd:13` `"Wiecej zmian"` (missing `ę` → "Więcej"), line 49 `"Slyszę"` (missing `ł` → "Słyszę"). Not just an l10n gap — the strings themselves are misspelled Polish.

- **M7. Landing world-picker shows raw `project.title` as the card name** (`landing_screen.gd:306`). If a kid named a world `"asdfg"` or copy-pasted garbage the picker shows that verbatim with no length cap. Easy to over-fill the 380×240 card.

### Low / nits

- **L1. Cloud animation duration comment is wrong.** `landing_screen.gd:347` says "Slow / medium / fast: 48 / 36 / 24 seconds" but the formula `60.0 - i * 12.0` for `i in 1..3` yields 48 / 36 / 24 — actually matches, comment is correct. (Self-correction; ignore this nit.)

- **L2. `landing_screen.gd:330-334` `_icon_for_template` returns emoji that match exactly five template ids in `create_shell.gd:738-744` — but `farm` icon is `"🚜"` in landing and `"🌾"` in create. Inconsistent visual identity for the same template across shells.

- **L3. Mascot uses `pivot_offset = Vector2(80, 180)` but `custom_minimum_size = Vector2(160, 220)`** — pivot is near bottom-middle which is fine for rotation, but the wiggle tween rotates ±4° which at a 220 px tall sprite produces ~15 px of head-sway. Cute, but may feel "drunk" rather than "idle". Consider ±2°.

- **L4. `landing_screen.gd:343` "Slow / medium / fast" cloud duration order is reversed visually** — cloud1 takes 48 s (slow), cloud3 takes 24 s (fast). But cloud3 is the smallest (`420 - 3*60 = 240 px wide`) and lowest on the screen. Parallax intuition suggests far/small=slow, near/big=fast — current implementation has it backwards.

- **L5. `audio_bank.gd:62-71` SFX pool fallback "overwrites slot 0" — if all 6 players are busy, a new SFX cuts off whatever was on slot 0 with no fade. Risk: a long `victory_fanfare` gets clipped by a `ui_click`.

- **L6. `theme.tres` `Button/styles/disabled = SubResource("StyleBoxFlat_secondary_normal")`** — disabled buttons get the *secondary normal* style (white background with teal border), not a visually-dimmed look. A disabled "Umieść" button looks like an active "Cofnij" button. Confusing for kids — they see a button that *looks* alive but doesn't respond.

- **L7. `CreateShell._wire_actions()` connects `_node_list.item_selected` with `is_connected` guard (line 271) but tool button signals at lines 247-270 have NO guard.** If `_wire_actions()` is ever called twice (e.g. shell re-attached), tool buttons fire 2x. Defensive `if not signal.is_connected()` would be safer.

- **L8. `play_shell.gd:97-129` `launch_world_by_id()` uses `push_warning` for every failure path with no kid-facing feedback.** If the project is missing, the kid sees nothing change. At least set `_info.text` to a friendly fallback.

## Manual test log

I am running in a Claude Code subagent inside an isolated git worktree, so the e2e recipe step 5 (manual Godot boot + screenshot) is **not available**. All findings above are code-level. The verification gap:

- ❌ Could not visually confirm landing-screen clipping on 1600×960 viewport (C2). Confidence is HIGH from the coordinate math but a runtime screenshot would prove it.
- ❌ Could not confirm mascot speech bubble is actually unreadable (H3). The theme override *might* propagate via `PanelContainer/styles/panel` from `choyce_theme.tres` — but the mascot is constructed in `_init`/`_ready` of a `Control` and the theme is set on `self`, not on the speech panel; whether the inherited theme applies depends on tree state. A runtime check is needed.
- ❌ Could not confirm `ButtonFeel` pivot-zero bug (H4) on freshly-built buttons.
- ❌ Could not confirm the CTA idle timer multi-fire (H1) — but the code is straightforwardly broken under any rapid interaction.

Steps that **were** performed:
1. `git log --oneline -1` → `68d73a3 feat(audio): SFXPlayer in gameplay uses AudioBank-loaded streams`. ✅
2. `godot --editor --headless --quit` → only a Blender path warning, no SCRIPT ERROR / Parse error. ✅
3. Static file inspection of all 8 files in the brief plus icon_font.gd, audio_bank.gd, onboarding_overlay.gd, voice_assistant_card.gd, project.godot. ✅
4. Asset existence check: 3 fonts present, 10 voice files, 13 SFX files, 5 music files, 6 landing textures. ✅ (No missing-asset risk on the happy path.)

## Recommendations

Prioritized punch list — fix in this order:

1. **(C1 + H2)** Route every kid-visible Polish string through `_t()`. Add `LocalizationPolicyPort` injection to `LandingScreen._build_scene_tree` and `Mascot.setup()`. Add `ui.landing.title`, `ui.landing.play`, `ui.landing.create`, `ui.landing.parent`, `mascot.cheer.world_remixed`, `mascot.cheer.quest_completed`, `mascot.cheer.onboarding_finished`, `mascot.sad.policy_decryption_failed`, `mascot.wave.onboarding_step_changed` translation keys. Same treatment for `VoiceAssistantCard` (M6) including typo fixes.

2. **(C2)** Re-author `landing_screen.gd` with anchors-driven layout. Sun should anchor top-right (`anchor_left = anchor_right = 1.0; offset_left = -260; offset_top = 60`). Close button bottom-right or top-right of `_picker_layer` with anchor preset. Grass strip should anchor bottom-full-width. Replace hard-coded `Vector2(1840, 20)` etc. with anchor presets. Verify on 1600×960 and 1280×720.

3. **(C3)** Make `CreateShell._apply_active_tool()` first check `if not _ports_ready: _set_status_message(_t("create.tools.unavailable"), false); return`. Safety default = BLOCK.

4. **(H1)** Replace `SceneTreeTimer` CTA-idle pattern with a single `Timer` node:
   ```gdscript
   _cta_idle_timer = Timer.new()
   _cta_idle_timer.wait_time = 3.0
   _cta_idle_timer.one_shot = true
   _cta_idle_timer.timeout.connect(_on_cta_idle_timeout)
   add_child(_cta_idle_timer)
   _cta_idle_timer.start()
   # On interaction: _cta_idle_timer.stop(); _cta_idle_timer.start()
   ```
   No leaked Callables, no overlap firing.

5. **(H3 + L6)** Give the mascot speech panel an explicit `StyleBoxFlat` background (rounded corners, semi-opaque cream `Color8(255, 252, 230, 230)`, ~12 px corner radius). Add a "speech tail" `draw_polygon` in `_draw()` pointing at the mascot head. Fix `Button/styles/disabled` in `choyce_theme.tres` to a visually-distinct grey-out style — not the same as secondary.

6. **(H4)** In `button_feel.gd:55`, *always* defer pivot to `call_deferred("_set_pivot", btn)` instead of relying on `btn.size != Vector2.ZERO` at attach time. Buttons that never resize will still get a centered pivot in the next frame.

7. **(H5 + L5)** Add a ~80 ms debounce on `ButtonFeel._on_press_sfx` (or push it down into AudioBank). Add a `play_sfx_replace` variant for non-cancellable cues like `victory_fanfare`.

8. **(H7)** Bump voice overlay record button to 88×88 (matches the touch-target standard for primary kid actions). Replace emoji with a styled `TextureButton` once microphone asset lands.

9. **(M3, M4, M5, M7)** Address as a polish pass after the above.

10. **(L4)** Reverse cloud durations so cloud3 (small, low) drifts *slowly* and cloud1 (big, top) drifts *fast* — matches parallax intuition.
