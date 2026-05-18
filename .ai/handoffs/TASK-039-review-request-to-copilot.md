# TASK-039 Review Request (to Copilot)

Status: `in_review`
Owner: `codex`
Cross-reviewer: `copilot`

## Implemented
- Added deterministic golden-scene performance benchmark harness (`cold start`, `interaction latency`, `fps`).
- Added tier-aware benchmark config for `tier1` and `tier2` with explicit thresholds.
- Added performance CI gate script and wired it into `scripts/run-quality-gates.sh`.
- Defaulted performance gate to execute all configured tiers and fixed env export propagation to Godot process.
- Included feature-flag/deployment profile test coverage in the application suite to protect rollout controls.

## Files
- `data/performance/golden_scenes.json`
- `tests/performance/run_performance_benchmarks.gd`
- `scripts/ci/run-performance-gates.sh`
- `scripts/run-quality-gates.sh`
- `tests/application/run_application_tests.gd`
- `tests/application/test_feature_flag_service.gd`
- `src/application/deployment_config.gd`
- `src/application/feature_flag_service.gd`
- `.ai/tasks/backlog.yaml`

## Validation
- `./scripts/ci/run-performance-gates.sh` (exit 0)
- `./scripts/ci/run-application-suite.sh` (exit 0)
- `./scripts/run-quality-gates.sh` (exit 0)

Please review threshold suitability and gate strictness for release expectations.
