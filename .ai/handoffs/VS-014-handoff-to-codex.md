# VS-014 Handoff to Codex (Copilot / Junior Coder)

## Summary
Replaced debug-looking HUD chrome and the legacy ninja greeting flag with a
single coherent visual system across the gameplay HUD and the launcher.

1. Removed emoji + debug text from the in-game weapon label.
   `🗡 Pięść (4 dmg)` → `Pięść`. `_apply_tier` and `_current_weapon_label()`
   no longer emit `🗡` or `(%d dmg)` strings, so the HUD and the hotbar
   tooltip agree.
2. Removed the `←` arrow emoji from the back button (`← Wróć` → `Wróć`).
3. Removed the `▶` emoji from the launcher play button (`▶  GRAJ` → `GRAJ`).
   Updated the Polish localization key `launcher.play` to match.
4. Replaced the BLUE/YELLOW Kenney placeholder textures on the 5-slot hotbar
   with the same `_hud_panel_style` (translucent dark + accent border) used by
   the rest of the HUD. Active slot now reads as a brighter amber accent on
   the same panel family rather than a different colored card. Deleted the
   now-unused `HUD_SLOT_BLUE` / `HUD_SLOT_YELLOW` texture preloads.
5. Toned the bright score yellow down to a warm off-white so the stat panel
   no longer reads as a debug rainbow.
6. Verified the legacy `Cześć, jestem twoim ninja` greeting was already
   suppressed in `landing_screen.gd:283` — no change needed.

## Files Touched
- `src/adapters/inbound/gameplay/gameplay_runtime.gd` (weapon label text,
  back button text, hotbar slot rendering, score color, removed
  `HUD_SLOT_BLUE` / `HUD_SLOT_YELLOW` consts)
- `src/adapters/inbound/scenes/launcher/launcher_overlay.gd` (play button
  text)
- `data/localization/ui_pl.json` (`launcher.play` string)
- `.ai/tasks/backlog.yaml` (status `todo` → `in_progress` → `in_review`)

## Backlog Update
- `VS-014` moved to `in_review`.

## Validation Performed
- Project parse: `godot4 --headless --path . --quit` → no parse errors after
  the pre-existing `data/audio/default_bus_layout.tres` resource warning
  (unrelated to this task).
- `godot4 --check-only --headless --script
  res://src/adapters/inbound/gameplay/gameplay_runtime.gd` → compiles cleanly.
- Focused contract tests still pass (unchanged):
  - `tests/contracts/run_task_027_tests.gd` (1/1, 12 checks)
  - `tests/contracts/run_task_032_tests.gd` (4/4, 61 checks)
  - `tests/contracts/run_task_044_tests.gd` (3/3, 27 checks)
  - `tests/contracts/run_task_047_tests.gd` (6/6, 126 checks)
- Full smoke boot (`timeout 25 godot4 --headless --path .`) emits no errors
  related to the HUD, hotbar, launcher, or localization changes. Pre-existing
  OnboardingService + audio resource warnings remain.

## Open Risks / Notes
- The remaining acceptance criterion ("screenshot review passes at reference
  and laptop resolutions") requires rendered capture, which is owned by
  VS-016 (rendered-qa) and uses the AI vision runner from TASK-063. This
  handoff is text + code-ready; visual confirmation needs the AI vision
  pipeline.
- The launcher's `PRZYGODA CZEKA…` trailer title still pulses on the
  cutscene, which reads as part of the cinematic trailer rather than debug
  chrome. Left intact per PLAN.md guidance ("trailer character voices are
  separate, youthful ElevenLabs voices, queued serially, captioned").
- The saturated green PLAY button (Color(0.16, 0.78, 0.42)) is the only
  remaining saturated accent. Kept as the launcher menu CTA so it pops for
  the kid — touch target is still well above the WCAG 2.2 AA recommended
  minimums (420×140 minimum size).

## Review Focus Suggestions
- Whether the new hotbar panel accent (amber when active, steel-blue when
  idle) reads clearly on both background variants of the Adventure biome.
- Whether the weapon label without the sword emoji still communicates "this
  is your tool" to a 6-8yo reader, or whether a pictogram (kit icon we
  already have in HUD_ICON_AXE) should be added back via TextureRect.
- Whether the `_hud_panel_style` corner radius / shadow size chosen here is
  consistent with the parent-zone and library shells or if a shared theme
  constant should be introduced.