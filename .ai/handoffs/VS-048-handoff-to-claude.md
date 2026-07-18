# VS-048 Handoff to Claude (Cross-Review)

## Summary
Implemented the final remaining VS-048 acceptance criterion: Adventure music
crossfades among exploration, nearby danger, and driving states. The runtime
logic already existed in `GameplayRuntime._tick_adventure_music()` and the
crossfade machinery in `AudioBank`; this slice adds a focused runtime contract
test proving the wiring is correct and the three states transition as expected.

1. New contract test `tests/adapters/inbound/test_adventure_music_states.gd`
   subclasses `GameplayRuntime` to bypass the heavy Adventure scene setup and
   exercises `_tick_adventure_music()` directly against the real `AudioBank`
   autoload.
2. Assertions cover:
   - Default/no-threat state selects `explore` and sets AudioBank to `explore`.
   - An alive enemy within 15 m selects `danger` and sets AudioBank to `danger`.
   - An enemy beyond 15 m falls back to `explore`.
   - A defeated enemy falls back to `explore`.
   - An assigned active vehicle takes priority and selects `drive`.
   - Clearing the active vehicle returns to `explore`.
   - Unchanged state remains stable (no spurious AudioBank updates).
3. Backlog evidence updated with the new test file, run command, and a note
   that all VS-048 acceptance criteria are now covered pending Claude
   cross-review.

## Files Touched
- `tests/adapters/inbound/test_adventure_music_states.gd` (new)
- `tests/adapters/inbound/test_adventure_music_states.gd.uid` (new)
- `.ai/tasks/backlog.yaml` (VS-048 evidence + status `in_progress` → `in_review`)

## Backlog Update
- `VS-048` moved to `in_review`.

## Validation Performed
- New contract test:
  `godot4 --headless --path . --script tests/adapters/inbound/test_adventure_music_states.gd`
  → all 10 assertions pass.
- Regression checks still green:
  - `godot4 --headless --path . --script tests/adapters/inbound/test_vehicle_runtime.gd` → pass.
  - `godot4 --headless --path . --script tests/adapters/inbound/test_camp_civilians.gd` → pass.
  - `godot4 --headless --path . --script tests/domain/test_sandbox_state.gd` → pass.
  - `godot4 --headless --path . --script tests/application/test_sandbox_persistence.gd` → pass.

## Open Risks / Notes
- The test uses the real `AudioBank` autoload, so it exercises the production
  crossfade path without playing real audio in headless mode. Resource-leak
  warnings at exit mirror the existing `test_adventure_music_director.gd` and
  are not unique to this new test.
- `_tick_adventure_music()` selects `drive` whenever `_active_vehicle` is a
  valid instance; it does not inspect `VehicleBase.is_active`. This matches the
  current runtime contract (`_on_vehicle_exited` clears `_active_vehicle` to
  `null`). The test reflects that contract.
- Kid safety / parental controls are unchanged: the test manually injects an
  enemy and vehicle; real sessions still require parental combat opt-in for
  enemies and vehicle entry via the existing `VehicleBase` entry points.
- No hexagonal-boundary changes: test lives in the adapter test suite and only
  asserts adapter behavior.

## Review Focus Suggestions
- Confirm the contract test is sufficient evidence for the music-crossfade
  acceptance criterion, or whether an additional in-game/direct-play recording
  is desired.
- Verify that moving `VS-048` to `done` should wait for this Claude review per
  `cross_review_by: claude`.
- Decide whether to address the shared AudioBank resource-leak warnings as a
  follow-up cleanup task (affects both music tests, not VS-048 specific).
