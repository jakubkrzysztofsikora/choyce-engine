# Adv CC — Test-Coverage Adversary Review
Date: 2026-05-19
Subject: Combat / animation / loot test coverage after `player_controller.gd` ATTACK_ANIMS landing.

## Scope audited
- `tests/application/` (40 files, all unit-style `SceneTree` smokes)
- `tests/domain/` (1 file: `test_loot_table_data.gd`)
- `tests/adapters/`, `tests/contracts/`, `tests/e2e/`
- `src/application/{combat,wave_director,gear_progression,xp_progression,game_mode}_service.gd`
- `src/adapters/inbound/gameplay/{player_controller,enemy_controller,gameplay_runtime}.gd`
- `src/domain/combat/{loot_entry,loot_table_data,wave_config}.gd`

## Ranked findings

### F-CC-01 — CRITICAL — `WaveDirectorService` has ZERO tests
`src/application/wave_director_service.gd` is pure RefCounted, 81 LOC, 4 branches, fully unit-testable. No file under `tests/` references `WaveDirector`. Procedural curve (`count = 3 + N*1.2 cap 7`, `hp_mult = 1 + sqrt(N)*0.25`, boss every 5th), config-override path, and `is_capped()` parental cap (incl. `cap <= 0` "no extra waves" edge) are all unverified. Adv 1 H1 fix sits on faith.

Proposed: `tests/application/test_wave_director_service.gd`
- `plan_wave_empty_configs_uses_procedural` — N=1 → pack=4, N=10 → pack=7 (cap), boss false at N=4 true at N=5.
- `plan_wave_exact_config_used_verbatim` — author N=3 with pack=99; service returns 99 not 6.
- `is_capped_zero_means_no_extra_waves` — cap=0, wave=1 → true.
- `is_capped_negative_disables` — cap=-1, wave=1 → true (current `<=0` branch).
- `is_capped_positive_threshold` — cap=5, wave=4 → false, wave=5 → true.

### F-CC-02 — CRITICAL — Punch-phase cycling not extracted, untestable
`_trigger_punch_animation` line 438-439 holds the only domain logic worth testing in the new change (`phase := _punch_phase % ATTACK_ANIMS.size(); _punch_phase += 1`). It's wedged inside a Node method that also touches `_anim_player`, `_punch_tween`, `_character_mesh`. Refactor blocks unit test.

Proposed extraction: `src/application/animation_phase_policy.gd` (RefCounted)
```
class_name AnimationPhasePolicy
extends RefCounted
const ATTACK_CLIPS := [...]
func next_clip(state: Dictionary) -> Dictionary:  ## {clip, next_phase}
```
Then `tests/application/test_animation_phase_policy.gd`:
- `cycles_0_1_2_3_0` — 5 calls from phase=0 return clips in expected order, final state.phase==0.
- `wraps_from_large_phase` — phase=999 still returns ATTACK_CLIPS[999%4].
- `policy_pure_no_side_effects` — same input dict twice → same clip (input dict not mutated; returned next_phase is +1).

### F-CC-03 — HIGH — `_on_anim_finished` predicate not extracted
Line 230-241: `if name_str in ATTACK_ANIMS:` flips `_is_punching=false` and rebinds movement clip. This is the regression-prone bit (regression: stray idle clip name in ATTACK_ANIMS list, or rename of a clip would silently strand `_is_punching=true` forever).

Proposed: extract `AnimationPhasePolicy.is_attack_clip(name: String) -> bool`. Test:
- `tests/application/test_animation_phase_policy.gd::is_attack_clip_recognizes_all_four` — every entry in ATTACK_CLIPS returns true.
- `is_attack_clip_rejects_movement` — `idle`, `walk`, `sprint`, `jump`, `""`, case-mismatch → false.
- `is_attack_clip_guards_against_typo_drift` — assert ATTACK_CLIPS.size()==4 and contents match a hardcoded literal list (catches accidental list bloat).

### F-CC-04 — HIGH — `CombatService` cap-divisor contract incomplete
`test_combat_service.gd` covers 7 cases but misses:
- `cap_when_raw_equals_hp` — `compute_damage(30, 30)` boundary.
- `kid_floor_when_hp_is_2` — `maxi(int(2/3),1)` = 1 (currently only hp=1 tested).
- `large_hp_cap` — `compute_damage(1000, 300)` should be 100; ensures division isn't using float.
- `negative_hp_treated_as_zero_cap` — `compute_damage(10, -5)`; undefined behavior in current code (no test, no guard).

Proposed: extend existing `test_combat_service.gd` with 4 asserts. Acceptance: `OK 11/11`.

### F-CC-05 — HIGH — `LootTableData.generate` cumulative-distribution and multi-entry weighting untested
`test_loot_table_data.gd` covers chance=0/1 single entries + determinism. Missing:
- `chance_05_roughly_half` — chance=0.5 over 1000 seeded rolls; assert count in [400, 600].
- `multi_entry_independent_rolls` — 3 entries each chance=1.0 → all 3 always present (not mutually exclusive).
- `weighted_quantity_distribution_uniform` — range=[1,10], 1000 rolls, every value 1..10 observed.
- `negative_chance_clamped` — chance=-0.1 → behaves like 0.0.
- `chance_above_1_clamped` — chance=2.0 → behaves like 1.0.

Proposed: extend `tests/domain/test_loot_table_data.gd`. Acceptance: deterministic counts with fixed seed.

### F-CC-06 — MEDIUM — `WaveConfig` and `LootEntry` Resources have no domain tests
Both are `@export`-heavy Resources. No defensive tests for default values, no `.tres` round-trip test, no `is WaveConfig` type-guard test. A typo'd `@export` would silently break `_config_to_dict()`.

Proposed: `tests/domain/test_wave_config_defaults.gd`
- `defaults_pack_size_positive`, `defaults_hp_mult_one`, `archetype_weights_starts_empty`.
- `tres_roundtrip` — save to tempfile, load, fields equal.

### F-CC-07 — MEDIUM — Signal multi-connect regression untested
`player_controller.gd:120` guards `animation_finished.is_connected(_on_anim_finished)` before connecting. Classic bug: forget guard → double-connect on re-`spawn_at()` → `_is_punching=false` flips twice = potential race. No test asserts single-connect after multi-spawn cycle.

Proposed: `tests/adapters/inbound/test_player_controller_signal_safety.gd` (SceneTree + headless Node instantiation)
- `respawn_does_not_duplicate_anim_finished_handler` — spawn, spawn, spawn → `_anim_player.animation_finished.get_connections().size()` == 1.

### F-CC-08 — MEDIUM — `gear_progression`, `xp_progression`, `game_mode` services tested but no boundary tests for level-cap / mode-switch race
Inspected file names confirm presence of `test_xp_progression_service.gd`, `test_gear_progression_service.gd`, `test_game_mode_service.gd`. Without re-reading each: spot-check for: max-XP overflow, simultaneous mode-switch + XP gain, gear unlock at exact level boundary (off-by-one). Likely missing.

Proposed: review-only finding; add boundary asserts to each existing file. Acceptance: each test file grows by ≥3 cases covering `at_cap`, `over_cap`, `under_cap_minus_one` patterns.

### F-CC-09 — LOW — `_perform_attack` mesh-squash regression has no smoke
Adv X note in code (line 376) says "user reported screen jumps weirdly when punching" — bug was scaling `self` instead of `_character_mesh`. No test guards against regression. Hard to unit-test (Tween + Node3D) but a contract-style test could assert `_character_mesh.scale != self.scale` after `_perform_attack()`.

Proposed: `tests/adapters/inbound/test_player_attack_camera_steady.gd` — instantiate controller, call `_perform_attack`, assert `transform.basis.get_scale() == Vector3.ONE` while tween runs.

### F-CC-10 — LOW — No end-to-end "combat full loop" integration test
`tests/e2e/` exists. No file ties `WaveDirectorService → spawn → EnemyController.apply_damage → LootTableData.generate → XP gain → wave_director.is_capped`. AI vision scenarios (TASK-061-066) are vision-soft-gate only, not unit pipe. One e2e SceneTree script driving this pipeline in-memory (no rendering) would catch port-wiring drift.

Proposed: `tests/e2e/test_combat_loop_in_memory.gd` — wire CombatService + WaveDirectorService + LootTableData + a stub XPProgressionService. Run 5 waves, assert XP increases monotonically and loot table called N times.

## Summary of regressions that WOULD slip past today's suite
1. Punch phase resetting to 0 every call (`_punch_phase += 1` dropped) — silent, no test.
2. ATTACK_ANIMS list mutated (typo, reorder) — `_on_anim_finished` filter passes wrong names, animations never finish their flag-clear — `_is_punching` stuck forever. No test.
3. `WaveDirectorService.is_capped` semantics for `cap=0` flipped — kids get unlimited waves. No test.
4. Procedural curve constants changed (`hp_mult * 0.25` → `* 2.5`) — wave 1 deals 2.5× HP. No test.
5. `animation_finished` signal double-connected on respawn — flag-flip race. No test.
6. LootTable chance>1.0 or <0.0 unguarded — Resource imported with bad data silently passes. No test.

## Recommended priority order
1. F-CC-01 (WaveDirector) — 30 min, zero refactor risk.
2. F-CC-02 + F-CC-03 (extract AnimationPhasePolicy) — 1 h, includes refactor, removes framework-coupling for one of the most-edited files.
3. F-CC-04, F-CC-05 (extend combat + loot suites) — 30 min combined.
4. F-CC-06 (Resource defaults) — 20 min.
5. F-CC-07 (signal multi-connect) — 45 min, requires headless Node test rig.
6. F-CC-10 (e2e combat loop) — 1-2 h, highest payoff for regression net.

Total: ~5 h of test work, covers 6 silent-regression vectors and unlocks future refactor of `player_controller.gd` animation block.

Report by Adv CC, ready for synthesis.
