# PLAN — Ship Choyce Engine to Playable MVP

**Goal (user, 2026-06-03):** Beautiful modern menu shell, playable world building with voice agent help, ≥2 world types with mechanics, animation, NPCs, win/lose scenarios.

**Status (commit `5dd34fc`):** 63/66 backlog tasks done. Hex-arch domain + ports/adapters complete. Tauri+Next.js shell skeleton wired (landing/create-chrome/library/parent). Godot scenes for landing/create/play/library/parent exist. 5 world templates in `data/templates/` (adventure, city, farm, obby, tycoon). Combat C1–C4 fight-feel landed. AI-vision test infra (TASK-061…066) in_review. **Carry-overs from the 2026-05-18 remediation session block the goal** — see `~/.claude/projects/-Users-jakubsikora-Repos-choyce-engine/memory/MEMORY.md` "Carry-overs" + "Critical Production Bugs".

---

## Files in scope (first-touch)

Wave-1 menu:
- `shell/src/app/page.tsx`, `shell/src/app/create-chrome/page.tsx`, `shell/src/app/library/page.tsx`, `shell/src/app/parent/page.tsx`
- `shell/src/app/globals.css`, `shell/src/messages/pl.json`
- `src/adapters/inbound/scenes/landing/landing_screen.{gd,tscn}`

Wave-2 voice-assisted build:
- `src/adapters/inbound/scenes/create/create_shell.{gd,tscn}`
- `src/application/services/request_ai_creation_help_service.gd`
- `src/adapters/outbound/ollama_llm_adapter.gd`, `moderating_stt_adapter.gd`, voice_prompt adapters
- `src/adapters/inbound/gameplay/build_grid.gd`, `world_renderer.gd`

Wave-3 two playable world types:
- `data/templates/adventure.json`, `data/templates/obby.json`
- `src/adapters/inbound/main.gd` (KEY_PROGRESSION / KEY_CLONE / KEY_REMIX wiring — TASK-025 carry-over)
- `src/application/services/{clone_world_service,remix_world_service,manage_progression_service}.gd`
- `src/adapters/inbound/gameplay/{gameplay_runtime.gd,player_controller.gd,enemy_controller.gd,victory_sequence.gd}`
- `src/domain/gameplay/{win_outcome.gd,quest.gd,quest_log.gd,session.gd}`
- `src/domain/world_authoring/game_goal.gd`

---

## Tasks (waves)

### Wave 0 — Unblock carry-overs (must precede playable)
- [ ] W0-1 Wire `KEY_PROGRESSION`, `KEY_CLONE`, `KEY_REMIX` in `main.gd::_build_default_ports`. Re-add CloneWorldService / RemixWorldService / ManageProgressionService to shell wiring. Flip TASK-025 in `backlog.yaml` back to `done` once composition-root CI gate is green.
- [ ] W0-2 Replace `FilesystemDataLifecycleAdapter._clear_profile_consent` private-field reach with public `FilesystemConsentStore.delete_profile()`.
- [ ] W0-3 Land TASK-061…066 cross-reviews (codex + copilot) so menu + create flows can be CI-gated with AI-vision scenarios.

### Wave 1 — Beautiful modern menu (kid + parent)
- [ ] W1-A Replace `sigma_protocol`/phonk glitch theme on landing with kid-targeted "Astro Bot diorama" aesthetic per `thoughts/shared/research/aaa-upgrade-synthesis-2026-05-19.md`. Phonk allowed only as opt-in parent-zone skin.
- [ ] W1-B Landing hero: 3 large cards — **Buduj** (create), **Graj** (library), **Rodzic** (parent). Animated SVG mascots. Polish strings only via `_t()` (zero hardcoded — protect F-056-01 closure).
- [ ] W1-C Tauri sidecar spawn: implement `shell_spawn_godot` in `shell/src-tauri/src/lib.rs`; surface engine readiness; friendly offline banner.
- [ ] W1-D Library page: grid of saved worlds from `FilesystemPublishStore` with cover thumbnails + play/edit/remix buttons. Friendly empty state.
- [ ] W1-E Parent zone polish: TabContainer (Consent / Audit / Dane / Limits / Policies) — fixes DaneTab discoverability carry-over. RBAC first-statement assert stays.
- [ ] W1-F Godot `landing_screen.tscn` either visually aligns with shell or hides itself when sidecar mode is active.

### Wave 2 — Voice-assisted world building
- [ ] W2-A True async Ollama streaming: rewrite `OllamaLLMAdapter` with raw `HTTPClient` + `Thread`, real-time `on_token` / `on_done` Callables. Replace `complete_with_tools_sync` in `RequestAICreationHelpService`. Behind `ai_stream_v2` flag for one release.
- [ ] W2-B Push-to-talk + wake gate in `create_shell.gd` using `VoicePromptPort` + `ModeratingSttAdapter` + `IntentExtractorPort`. Confidence < 0.6 → ask child to repeat. Blocked transcripts emit kid-register Polish feedback.
- [ ] W2-C Preview/Apply/Undo two-step UI for AI edits (UX-AI-002 carry-over). Hook into existing `WorldEditCommand` undo log (TASK-006).
- [ ] W2-D AI memory recall surfaces "ostatnio dodałeś…" suggestions; bound the cache (avoids recurring unbounded-cache review finding).
- [ ] W2-E Voice CTA wiring on every navigation step (UX-KID-001 carry-over).

### Wave 3 — Two playable world types end-to-end
**Type A — Adventure (PvE quest):** `data/templates/adventure.json`
- [ ] W3-A1 Win: collect 3 keys → unlock door → reach exit portal. Defined as `GameGoal` + `Quest` resources, evaluated by `GodotRulesRuntimeAdapter`.
- [ ] W3-A2 Lose: HP → 0 (3 lives) OR 5-min timer (parent-tunable).
- [ ] W3-A3 NPCs: 1 friendly quest-giver (dialogue from `data/templates/npc_dialogue.json`), 2 hostile (reuse `EnemyController` + combat C1-C4).
- [ ] W3-A4 Animation: `AnimationTree` blend tree for player + NPCs (idle/walk/run/attack/hit/death). Quaternius rigs already bundled.
- [ ] W3-A5 `NavigationRegion3D` bake on world load. Enemy patrol + chase via `NavigationAgent3D`.
- [ ] W3-A6 Quest-log HUD + `victory_sequence` celebration (confetti VFX, Polish narration via `VoicePromptPort`, save-and-continue prompt).

**Type B — Obby (parkour platformer):** `data/templates/obby.json`
- [ ] W3-B1 Win: reach finish flag within timer. Best-time persistence via `KidStatusReadModelAdapter`.
- [ ] W3-B2 Lose: fall below kill-plane → respawn at last checkpoint. Lives = 5.
- [ ] W3-B3 Mechanics: double-jump, sprint, sliding platforms, swinging hazards (`Area3D`), bounce pads, lava tiles — all via `RulesRuntimePort` block grammar so kids can author variants.
- [ ] W3-B4 NPCs: friendly "race coach" mascot, TTS taunts/cheers. No combat NPCs.
- [ ] W3-B5 Checkpoint flags, finish-line ribbon, fireworks VFX on win.

### Wave 4 — Verify
- [ ] W4-A Run `scripts/ci/run-ai-vision-tests.sh` against both world types. KF-001 onboarding, KF-002 hints, SC-001 COPPA still pass.
- [ ] W4-B Run TASK-055 manual kid-parent gameplay charter.
- [ ] W4-C Run TASK-056 localization + accessibility sweep (captions on, kid-register text only).
- [ ] W4-D Move audit-ledger `verify_integrity("full")` multi-segment scan off main thread (carry-over).

---

## Risk register

| Risk | Impact | Mitigation |
|---|---|---|
| Carry-over: TASK-025 progression unwired | Library save/load silently breaks; kids lose worlds | Wave 0 must land before Wave 3; composition-root CI gate catches it |
| Ollama streaming rewrite touches every AI call site | Regression in TASK-018 failsafe + TASK-043 memory layer | Feature flag `ai_stream_v2`; keep `_sync` shim for 1 release |
| Two world types share `gameplay_runtime` but diverge on rules | Code-fork or unmaintainable `if obby:` branches | Push divergence into `RulesRuntimePort` block resources; runtime stays polymorphic |
| Phonk/sigma_protocol theme on kid landing | Parents reject as edgy | Wave 1-A swaps to Astro-Bot kid aesthetic; phonk is parent-only optional skin |
| Composition-root gate not enforced pre-merge | Adapter regressions slip in | Mark `.github/workflows/composition-root-gate.yml` as required check on PRs touching `main.gd` |

---

## Sequencing & ownership

- **codex** — Wave 0 + Wave 2-A (Ollama streaming, AI-runtime touch).
- **claude (me)** — Wave 3 domain (win/lose, quest, goal) + review Wave 1-E parent RBAC.
- **copilot** — Wave 1 UI/UX + Wave 4-B/C manual QA.
- **mistral** — Wave 3 mechanics adapters (`player_controller`, `enemy_controller`, AnimationTree, navigation bake).

Estimated wall-clock with 4 agents parallel: **~6 working days** (Wave 0 day 1, Waves 1+2 days 2-3, Wave 3 days 3-5, Wave 4 day 6).

---

## Out of scope
- Cloud publishing (Wave B Phase 6 already shipped `FilesystemPublishStore`; HTTP stub stays).
- True multiplayer / friends list (FR-025 carry-over).
- New PBR asset re-authoring (Wave 3 graphics carry-over in `aaa-upgrade-synthesis-2026-05-19.md`).
- Mobile / iPad builds.

---

*This plan supersedes the auto-scaffolded PLAN.md. References: `~/.claude/projects/-Users-jakubsikora-Repos-choyce-engine/memory/MEMORY.md` (carry-overs + Wave A/B/C remediation), `.ai/tasks/backlog.yaml` (TASK-001…066), `thoughts/shared/research/aaa-upgrade-synthesis-2026-05-19.md` (art direction synthesis).*
