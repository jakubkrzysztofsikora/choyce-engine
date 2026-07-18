# VS-022 Handoff to Codex (Copilot / Junior Coder)

## Summary
Implemented bounded, persistent player-character customization for the
Adventure sandbox loop. All choices are cosmetic only — zero impact on
combat stats, hit points, weapon damage, or economy.

1. New domain class `CharacterCustomization` at
   `src/domain/gameplay/character_customization.gd` with six bounded
   slots: `face` (a-f Kenney male variant), `skin` / `hair` / `top` /
   `pants` / `shoes` (each an index into a fixed 4-color palette). Static
   `PERSIST_PATH` keeps the JSON save at `user://character_customization.json`.
   `clamp_in_place()` rejects out-of-range indices and unknown face
   variants; `from_dict` / `to_dict` round-trip through JSON.
2. New UI overlay `CharacterCustomizationPanel` at
   `src/adapters/inbound/gameplay/character_customization_panel.gd`.
   Compact centre panel: face-variant button row (A–F) plus one swatch
   row per color dimension with a Polish label. Uses the project's
   translucent panel system, anchors to viewport centre, swatch selected
   state shown by border tint, no oversized labels or emoji.
3. Player controller extended with `set_face_variant(variant, set)`,
   `apply_customization(c)`, `_swap_character_glb(path)`,
   `_setup_character_appearance()` (factored from `_ready` so a swap can
   re-run it), `_apply_customization_colors(c)` (uses `material_override`
   on `body-mesh` / `head-mesh` to preserve imported textures while
   applying kid's color choices), `_tint_mesh`, `_find_mesh_by_name`.
4. `GameplayRuntime` wiring:
   - `_apply_loaded_customization()` runs once per session after
     `_player_controller.spawn_at(...)`, loading from disk and applying.
   - "Postać" button added to the HUD next to Wróć / Cofnij.
   - Pressing the button opens the panel, releases mouse capture, and
     releases the panel back to the HUD; live edits emit
     `customization_changed` → re-apply + `c.save_to_disk()`.
   - Closing the panel restores `MOUSE_MODE_CAPTURED` so 3D input works.
5. New unit test `tests/domain/test_character_customization.gd` with 7
   checks: defaults when file absent, save/load round-trip, clamp of
   out-of-range values, unknown face fallback, corrupt JSON fallback,
   JSON file format, palette/index bounds alignment with the UI.

## Files Touched
- `src/domain/gameplay/character_customization.gd` (new)
- `src/adapters/inbound/gameplay/character_customization_panel.gd` (new)
- `src/adapters/inbound/gameplay/player_controller.gd` (set_face_variant,
  apply_customization, _swap_character_glb, _setup_character_appearance,
  _apply_customization_colors, _tint_mesh, _find_mesh_by_name)
- `src/adapters/inbound/gameplay/gameplay_runtime.gd` (_customization +
  _customization_panel state, _apply_loaded_customization call in
  start_session, "Postać" HUD button, _on_customize_pressed,
  _on_customization_panel_changed, _close_customization_panel)
- `tests/domain/test_character_customization.gd` (new)
- `.ai/tasks/backlog.yaml` (status `in_progress` → `in_review`)

## Backlog Update
- `VS-022` moved to `in_review`.

## Validation Performed
- Project parse: `godot4 --check-only --headless --script
  res://src/adapters/inbound/gameplay/gameplay_runtime.gd` and the new
  files → compile cleanly.
- New unit test:
  `godot4 --headless --path . --script tests/domain/test_character_customization.gd`
  → `[test_character_customization] OK` (7 checks).
- Focused contract suites still green (re-run after the wiring edits):
  - `tests/contracts/run_task_032_tests.gd` (4/4, 61 checks)
  - `tests/contracts/run_task_044_tests.gd` (3/3, 27 checks)
- Smoke boot (`timeout 25 godot4 --headless --path .`): gameplay
  session starts, player spawns, `_apply_loaded_customization` is on the
  path. The pre-existing `data/audio/default_bus_layout.tres` parse
  warning + `adventure_island` null stream in `play_music` are not
  related to this task.

## Open Risks / Notes
- The Kenney toon-character GLB shares one body mesh for skin + clothes,
  so the per-slot choices (top / pants / shoes / hair) are blended into
  a single body-mesh tint via mean-of-four colours. Each individual
  choice still visibly moves the character. If the project later swaps
  to a KayKit Adventurer character with separate accessory slots, this
  becomes per-bodypart override rather than a tint blend — flag for a
  follow-up if VS-022 acceptance is re-evaluated.
- The "Postać" button sits between Cofnij and any future top-bar items
  (x = 384–544). It reuses `_hud_panel_style` with a violet accent so it
  doesn't collide with the blue Wróć or amber Cofnij.
- Mouse capture is released when the panel opens and restored on close;
  if the panel is closed via `queue_free` from elsewhere (session-end
  path), mouse capture won't auto-restore. Acceptable because
  `end_session` itself flips back to UI navigation mode.
- Customization data lives outside the project store and encrypted
  vault, so it survives a replay but does not leak into publish flows
  or audit ledger. Parental-control policy and moderation are
  unaffected.
- `PERSIST_PATH` is `static var` so the unit test can flip it for
  isolation. Game-time code should never mutate it; the canonical path
  is the default value.

## Review Focus Suggestions
- Whether the per-dimension colour blend on the body mesh is acceptable
  for visual review, or if the team would rather show two swatch rows
  ("Ubranie" / "Włosy") that drive top+pants and hair separately.
- Whether the "Postać" button placement overlaps with any planned
  top-bar additions (notably VS-016's rendered-QA flow).
- Whether the panel should also expose a "Reset to defaults" button to
  support kid onboarding re-runs.