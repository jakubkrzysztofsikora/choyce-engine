# Handoff: TASK-039 -> Copilot (Cross-Review)

## Summary
Implemented a deterministic performance benchmark harness with golden scene profiles, tier-specific thresholds, and CI quality-gate integration. Also tightened deployment-profile coverage by moving feature-flag tests into the application suite and adding override-path checks.

## Files created
- `data/performance/golden_scenes.json`
- `tests/performance/run_performance_benchmarks.gd`
- `scripts/ci/run-performance-gates.sh`

## Files updated
- `scripts/run-quality-gates.sh`
- `tests/application/run_application_tests.gd`
- `tests/application/test_feature_flag_service.gd`
- `src/application/deployment_config.gd`
- `src/application/feature_flag_service.gd`
- `.ai/tasks/backlog.yaml` (`TASK-039` -> `in_review`)

## Implementation details
1. Golden scene benchmark definitions
- Added `data/performance/golden_scenes.json` with three deterministic golden workloads:
  - `golden_template_obby`
  - `golden_template_farm`
  - `golden_template_city`
- Includes per-tier thresholds for:
  - cold start max ms
  - interaction latency max ms
  - minimum FPS

2. Benchmark harness runner
- Added `tests/performance/run_performance_benchmarks.gd`.
- Loads benchmark config, resolves target hardware tier(s), executes deterministic workloads, and validates measured metrics against thresholds.
- Emits reproducible output:
  - per-scene perf line (`PERF[...] ...`)
  - machine-readable JSON report (`PERF_REPORT_JSON=...`)
- Fails with non-zero exit when any metric breaches thresholds.

3. CI quality-gate integration
- Added `scripts/ci/run-performance-gates.sh` with parse/compile/load error detection and Godot bootstrap.
- Fixed env propagation so tier-selection variables are exported to Godot runner.
- Defaulted gate behavior to run all configured hardware tiers (`tier1` + `tier2`) for release-grade baseline coverage.
- Wired into `scripts/run-quality-gates.sh` so performance regressions are now release-gating.

4. Deployment profile and feature-flag verification hardening (`TASK-040` adjacency)
- Promoted `tests/application/test_feature_flag_service.gd` to `ApplicationTest` and included it in `tests/application/run_application_tests.gd`.
- Expanded assertions to cover:
  - deployment profile defaults (local/family/classroom)
  - runtime overrides and signal emissions
  - environment-driven override parsing (JSON and CSV)
- Explicitly modeled experimental/beta AI flags in deployment defaults.

## Validation
Executed locally:
```bash
./scripts/ci/run-performance-gates.sh
./scripts/ci/run-application-suite.sh
./scripts/run-quality-gates.sh
```

Observed:
- all commands exited with code `0`
- performance gate emitted deterministic metrics + JSON report
- full quality gate remained green with the new performance stage included

## Acceptance mapping (TASK-039)
1. Golden scenes benchmark cold start, interaction latency, and FPS targets on defined hardware tiers:
- Implemented via `golden_scenes.json` + deterministic benchmark harness with tiered thresholds.

2. Performance regressions fail quality checks with reproducible metrics:
- Implemented via threshold evaluation in benchmark runner + CI integration in quality gate.

## Review focus
1. Threshold realism for Tier 1 and Tier 2 hardware targets.
2. Whether additional real scene fixtures should replace synthetic workloads in the next iteration.
3. CI runtime/flake risk and whether strict mode should be split from default gate.
