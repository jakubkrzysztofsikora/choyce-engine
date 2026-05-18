# Abuse Regression Mapping (RC)

## Purpose
Maps release threat scenarios to executable regression checks and defines release-blocking handling.

## Threat to test mapping
| Threat ID | Threat scenario | Automated checks | Gate owner |
| --- | --- | --- | --- |
| THREAT-01 | Prompt/voice jailbreak and unsafe content injection | `tests/safety/run_safety_redteam_tests.gd`, `tests/safety/run_safety_compliance_regression_suite.gd` | Security + Safety |
| THREAT-02 | Parental control/session-role bypass | `tests/application/run_task_045_tests.gd`, `tests/safety/run_safety_compliance_regression_suite.gd` | Security |
| THREAT-03 | Data export/delete/retention abuse and consent bypass | `tests/application/run_task_048_tests.gd`, `tests/safety/run_safety_compliance_regression_suite.gd` | Compliance |
| THREAT-04 | Unauthorized publish/catalog visibility leakage | `tests/application/run_task_046_tests.gd`, `tests/e2e/run_mvp_acceptance_suite.gd` | Product Safety |
| THREAT-05 | Config/feature-flag tampering | `tests/application/run_application_tests.gd` (`FeatureFlagService`) | Release Eng |

## CI entrypoint
- `scripts/ci/run-abuse-regression.sh`
- Machine-readable output: `ABUSE_REGRESSION_REPORT_JSON=...`

## Release-blocking policy
- Any failing check mapped to `THREAT-01`, `THREAT-02`, or `THREAT-03` is release-blocking.
- Any high-severity finding produced by safety/compliance suite is release-blocking.
- Any unresolved medium-severity finding in `THREAT-04`/`THREAT-05` requires explicit risk acceptance by release owner.
