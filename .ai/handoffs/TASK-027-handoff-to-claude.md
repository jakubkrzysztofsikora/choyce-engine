# Handoff: TASK-027 -> Claude (Cross-Review)

## Summary of changes
Implemented AI gameplay companion enhancements in `RequestGameplayHintService` so hint scaffolding and adaptive difficulty/quest guidance are both enforced.

## Files updated
- `src/application/request_gameplay_hint_service.gd`
- `tests/contracts/request_gameplay_hint_service_contract_test.gd`
- `tests/contracts/README.md`

## Files created
- `tests/contracts/run_task_027_tests.gd`

## Implementation details
1. Tiered hinting remains scaffolded and bounded:
- Existing level 1-3 scaffold prompts preserved.
- Added guardrail against full-solution phrasing:
  - `_looks_like_full_solution(...)`
  - fallback hint substitution + safety event (`HINT_SCAFFOLD_GUARD`).

2. Adaptive difficulty and quest support added:
- New `_build_adaptive_guidance(...)` computes gentle adjustment using session context:
  - `recent_failures`, `recent_successes`, `stuck_seconds`, age band.
- Produces deterministic `difficulty_adjustment` payload:
  - `difficulty_scalar`
  - `spawn_rate_scale`
  - `reward_scale`
  - `objective_steps`
- Produces `quest_suggestion` via `_build_adaptive_quest(...)`.
- `recommended_hint_level` can nudge up/down gently and is clamped to 1..3.

3. Execute output now includes companion metadata:
- `difficulty_adjustment`
- `quest_suggestion`
- `reveals_full_solution` (always false for default path)

4. Failsafe/model-unavailable behavior preserved:
- Rules-based fallback still used when model unavailable or failsafe active.
- Adaptive metadata is still returned in these modes.

## Validation
Executed:
```bash
godot4 --headless --path . --script tests/contracts/run_task_027_tests.gd
```

Result:
- `Tests: 1`
- `Checks: 12`
- `Failed tests: 0`

Additional regression check:
```bash
godot4 --headless --path . --script tests/contracts/run_task_032_tests.gd
```

Result:
- `Tests: 4`
- `Checks: 51`
- `Failed tests: 0`

## Acceptance criteria mapping
1. Hinting follows scaffold levels and avoids revealing full solutions by default:
- Scaffold prompts preserved + full-solution guardrail enforced.

2. Difficulty adapts gently using age profile and session context:
- Adaptive guidance computes mild scaling and quest suggestion from age/context signals.

## Review focus areas
1. Confirm adaptive scaling is sufficiently gentle and deterministic.
2. Confirm full-solution guard does not over-block valid hints.
3. Confirm added response keys do not break existing callers.
4. Confirm safety event usage is appropriate for scaffold-guard interventions.
