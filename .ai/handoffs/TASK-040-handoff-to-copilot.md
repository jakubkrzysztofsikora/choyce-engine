# Handoff: TASK-040 -> Copilot (Cross-Review)

## Summary
Completed deployment-profile and feature-flag hardening for local-only, family-cloud, and classroom modes. Added explicit experimental rollout flags, environment override support for controlled rollouts, hard-disable enforcement for restricted features, and brought deployment/flag verification into the standard application quality gate.

## Files updated
- `src/application/deployment_config.gd`
- `src/application/feature_flag_service.gd`
- `tests/application/test_feature_flag_service.gd`
- `tests/application/run_application_tests.gd`
- `scripts/run-quality-gates.sh`
- `.ai/tasks/backlog.yaml` (`TASK-040` -> `in_review`)

## Implementation details
1. Deployment presets
- `DeploymentConfig` now carries explicit rollout-control keys:
  - `ai_experimental_tools`
  - `ai_beta_features`
  - `online_family_sessions`
- Mode defaults remain policy-safe:
  - `LOCAL_ONLY`: no multiplayer, no cloud sync, no telemetry
  - `FAMILY_CLOUD`: baseline cloud-enabled, experimental features disabled by default
  - `CLASSROOM`: cloud-managed, multiplayer blocked, experimental features disabled
- Added robust `CHOYCE_DEPLOYMENT_MODE` parsing aliases:
  - local: `local`, `local_only`, `local-only`, `offline`
  - classroom: `classroom`, `school`, `education`
  - family-cloud: `family`, `family_cloud`, `family-cloud`, `cloud`

2. Feature-flag rollout control
- `FeatureFlagService` now supports startup overrides via env var:
  - `CHOYCE_FEATURE_OVERRIDES`
- Supported formats:
  - JSON dictionary (preferred)
  - comma-separated `key=value` pairs fallback
- Runtime override behavior and signal emission preserved.
- Added hard-disable enforcement: restricted features cannot be force-enabled by overrides in locked modes (e.g. local/classroom online flags, classroom experimental flags).

3. Continuous verification
- Converted feature-flag test to `ApplicationTest` and included it in `run_application_tests.gd`.
- Coverage now includes:
  - mode defaults,
  - environment-mode parsing for deployment profiles,
  - runtime override behavior + signal emissions,
  - hard-disable override enforcement,
  - JSON and CSV environment override parsing.

## Validation
Executed locally:
```bash
./scripts/ci/run-application-suite.sh
./scripts/run-quality-gates.sh
```

Observed:
- both commands exited `0`
- `FeatureFlagService` test passes in application gate (`35 checks`)

## Acceptance mapping (TASK-040)
1. Deployment presets exist for local-only, family cloud, and classroom policy modes:
- Implemented and verified through deployment mode assertions in application tests.

2. Feature flags control experimental AI capabilities and rollout safety:
- Implemented via explicit experimental flag keys + startup env override parsing + runtime overrides + mode-level hard-disable locks for safety-critical keys.

## Review focus
1. Safety posture of env override behavior in production paths.
2. Whether override parsing should be restricted to parent/admin contexts only.
3. Naming and lifecycle for beta/experimental flags before release freeze.
