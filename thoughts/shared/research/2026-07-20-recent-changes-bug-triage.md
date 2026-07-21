---
date: 2026-07-20
commit: ec8d400edf35945baa8215e6fafaac03e6ee2302
branch: main
tags: [triage, gameplay, gym, build-grid, false-positives]
status: complete
---
# Research: Recent Changes (3-day window) — Bug Triage

## Summary
The last 3 days of commits (`fb38fd9..ec8d400`) are a **game-content slice** — gym,
homesteads, vehicles, water buoyancy, terrain grounding, food pickups, normal-mapped
block textures — shipped **with tests**. Two review agents were dispatched; nearly every
specific finding they produced was against **stale or misread code** and does not exist in
`HEAD`. There is **no fix swarm warranted**. The one real bug they flagged was already
fixed and committed. The remaining valid observations are **pre-tracked multi-day
feature-wiring carry-overs (TASK-025)**, not 3-day regressions.

## Commits in window
```
ec8d400 feat(physics+water+gym): trimesh collision, BoxMesh water segments, terrain grounding, normal maps
47e05a3 test: update split-screen + gym tests for new catalog filter + GLB spawner
861bfa2 fix(self-review): block texture seed loop, gym training type/method mismatch
30bd9b8 fix(gym+splash): E-key training, splash position order
bf4833b fix(world+blocks): spawn homesteads, water AABB, per-block noise textures
```

## Agent findings vs. reality

| Agent claim | Verdict | Evidence |
|---|---|---|
| MAJOR: `_build_grid.placed_count()` always 0 at `gameplay_runtime.gd:3972` | **FALSE POSITIVE** | `rg placed_count src/` → 0 hits. Actual code: `block_count()` (`build_grid.gd:43`), exists and correct. |
| Block-texture seed loop runaway | **ALREADY FIXED** | Commit `861bfa2`. `build_grid.gd` now `for i in range(block_id.length())` with proper `unicode_at(i)`. Bounded. |
| BLOCKER: remove `GymSpawner3D._ready()` `TrainingStats.new()` fallback, fail loud | **WOULD BREAK GYM** | `world_renderer.gd:941` constructs `GymSpawner3D` with `.new()` and **never calls `.setup()`**. The `_ready()` fallback (`gym_spawner_3d.gd:15-16`) is load-bearing. Removing it = null `_active_stats` = broken workouts. |
| BLOCKER: training path has no audit/parental hook, ignores `ManageProgressionPort` | **KNOWN CARRY-OVER (TASK-025)** | Progression services (`ManageProgressionService`, `CloneWorldService`, `RemixWorldService`) unwired since 2026-05-18 (see MEMORY.md carry-overs). Multi-day wiring task, not a 3-day regression. |
| MAJOR: hardcoded Polish in `dynamic_controls_overlay.gd` = F-056-01 regression | **NOT A REGRESSION** | `_t()` was never injected into the gameplay layer at all (`rg '_t\(' src/adapters/inbound/gameplay/` ≈ empty). 30+ gameplay files hardcode Polish identically. F-056-01 was scoped to shells (create/play/library/parent), all closed in Wave C. The overlay matches every sibling. |
| Normal-map: clamp-to-edge, freq 0.08, too subtle | **MISREAD CODE** | Actual `build_grid.gd:249-254`: offset-sampled `noise.get_noise_2d((nx+0.01)*32.0, …)`, freq 32.0, `*2.0` scale. Produces a real gradient. Not the code the agent described. |
| Zero tests for new code | **FALSE** | `test_gym_spawner_3d.gd`, `test_dynamic_controls_overlay.gd`, `test_build_grid_undo.gd`, `test_training.gd` all modified in window. |

## Real, honest observations (low priority, NOT swarm-worthy)

1. **Gym/training wiring is DI-incomplete** — `GymSpawner3D` self-constructs its
   `TrainingStats` because the composition root (`world_renderer.gd:941`) never injects one.
   Same shape as `homestead_spawner_3d.gd`. This is the **TASK-025 carry-over**, already
   tracked. Fix belongs in a deliberate progression-wiring task (inject shared
   `TrainingStats`, route through `ManageProgressionPort`, add audit + parental gate), **not**
   an emergency swarm against a fabricated bug list.

2. **Cross-adapter reach** `player_controller.gd:1751` → `runtime.get_node_or_null("WorldRenderer/GymSpawner3D")`
   + `has_method("perform_workout")`. Path-coupled duck-typing. Pervasive existing pattern
   (`food_pickup`, `nutrition_manager`, `training_equipment` all do `/root/...` lookups).
   Existing debt, not new. One cleanup task if/when the progression pipeline is wired.

3. **Gameplay-layer l10n gap** — the entire `src/adapters/inbound/gameplay/` slice hardcodes
   Polish. Real, large, pre-existing. A localization pass for gameplay is its own epic, not
   a bugfix.

## Conclusion — no fanout
- 1 flagged bug: **already fixed + committed**.
- Specific agent findings: **hallucinated method name, misread texture code, or
  regression mis-scoping**.
- Remaining valid items: **pre-tracked TASK-025 feature wiring** — deliberate work, not a
  swarm target.

Dispatching implementation agents here would burn effort rewriting whole-gameplay-layer
localization and wiring a multi-day progression pipeline **against a bug list that does not
correspond to `HEAD`**. Recommended next step: schedule TASK-025 progression wiring as a
scoped task (DI + port + audit + parental gate together), verified against live Godot, not
an agent swarm.

## Open Questions
- Is TASK-025 progression wiring ready to be scheduled now, or still blocked behind
  TASK-029 parent-zone review?
- Should gameplay-layer localization become its own epic before certification?
