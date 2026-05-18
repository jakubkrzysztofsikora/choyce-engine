# TASK-040 Review Request (to Copilot)

Status: `in_review`
Owner: `codex`
Cross-reviewer: `copilot`

## Implemented
- Added explicit experimental rollout flags in deployment defaults (`ai_experimental_tools`, `ai_beta_features`).
- Added environment-based startup feature overrides (`CHOYCE_FEATURE_OVERRIDES`) with JSON and CSV parsing.
- Added strict hard-disable enforcement so restricted mode flags cannot be force-enabled by overrides.
- Added robust deployment-mode env parsing aliases for `CHOYCE_DEPLOYMENT_MODE`.
- Converted deployment/feature-flag checks into `ApplicationTest` and wired into the application suite.
- Kept full quality gate green with new coverage included.

## Files
- `src/application/deployment_config.gd`
- `src/application/feature_flag_service.gd`
- `tests/application/test_feature_flag_service.gd`
- `tests/application/run_application_tests.gd`
- `.ai/tasks/backlog.yaml`

## Validation
- `./scripts/ci/run-application-suite.sh` (exit 0)
- `./scripts/run-quality-gates.sh` (exit 0)

Please review safety implications of env-based overrides and confirm mode-default policy expectations.
