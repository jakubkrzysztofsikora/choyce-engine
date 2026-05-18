# Release Threat Model: Choyce Engine (v1.0-RC1)

## Document control
- Version: `2026-03-05`
- Owner: Security Governance (Codex)
- Scope: child safety, COPPA/GDPR-K compliance, release integrity
- Regression mapping: `docs/security/ABUSE_REGRESSION_MAPPING.md`

## Threat register
| Threat ID | Category | Impact | Mitigation status | Verification |
| --- | --- | --- | --- | --- |
| THREAT-01 | Unsafe content injection / jailbreak | High | Mitigated | `tests/safety/run_safety_redteam_tests.gd`, `tests/safety/run_safety_compliance_regression_suite.gd` |
| THREAT-02 | Parental/session role bypass | High | Mitigated | `tests/application/run_task_045_tests.gd`, `tests/safety/run_safety_compliance_regression_suite.gd` |
| THREAT-03 | Data lifecycle abuse and consent bypass | Critical | Mitigated | `tests/application/run_task_048_tests.gd`, `tests/safety/run_safety_compliance_regression_suite.gd` |
| THREAT-04 | Unauthorized publishing / visibility leakage | High | Mitigated | `tests/application/run_task_046_tests.gd`, `tests/e2e/run_mvp_acceptance_suite.gd` |
| THREAT-05 | Deployment/feature tampering | Medium | Mitigated | `tests/application/run_application_tests.gd` (`FeatureFlagService`) |

## Threat details
### THREAT-01: Unsafe content injection
- Actor: adversarial prompting by kid/adult.
- Core controls:
  - dual moderation (input + output),
  - bounded kid-mode tool scope,
  - fail-safe fallback mode.

### THREAT-02: Parental/session role bypass
- Actor: kid attempting to bypass parent-only boundaries.
- Core controls:
  - role-token verification on sensitive flows,
  - family/session policy checks,
  - deployment flag hard-disables for online surfaces.

### THREAT-03: Data lifecycle abuse
- Actor: unauthorized export/delete/retention mutation.
- Core controls:
  - parent + role-token authorization,
  - managed-subject scope checks,
  - consent-gated cloud export,
  - audit logging for lifecycle operations.

### THREAT-04: Unauthorized publishing and catalog leaks
- Actor: kid/user sharing content outside allowed scope.
- Core controls:
  - private-by-default publish visibility,
  - moderation pass requirement before catalog visibility,
  - family/classroom-scoped browsing rules.

### THREAT-05: Config tampering
- Actor: local user enabling restricted features.
- Core controls:
  - deployment hard-disable locks,
  - constrained feature override behavior,
  - signed-plugin gate.

## Release-blocking criteria
- Automatic no-go:
  - any failure in `THREAT-01`, `THREAT-02`, `THREAT-03` mapped checks,
  - any high or critical unresolved finding from safety/compliance suites.
- Conditional go (risk acceptance required):
  - unresolved medium findings in `THREAT-04` or `THREAT-05`.

## Execution gate
- CI command: `scripts/ci/run-abuse-regression.sh`
- Required companion gates:
  - `scripts/ci/run-safety-gates.sh`
  - `scripts/run-quality-gates.sh`
