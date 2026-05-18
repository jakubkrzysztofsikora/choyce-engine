# Release Exit Criteria

These criteria define production readiness gates for safety, performance, and compliance.

## 1. Safety readiness gates
- All release-blocking safety suites pass:
  - prompt regression
  - safety gates
  - MVP acceptance (`TASK-050`)
  - kid-parent-AI matrix (`TASK-053`)
  - safety/compliance regression (`TASK-054`) once delivered
- No unresolved high-severity child-safety findings
- Parent approval controls verified for high-impact mutations/publish flows
- AI fallback controls validated (failsafe + rules-based fallback)

## 2. Performance readiness gates
- Performance gates pass for `Tier-1` baseline (`TASK-039`)
- Tier-2 benchmark run archived for release candidate
- No regression above approved tolerance for:
  - cold-start
  - interaction latency
  - FPS targets

## 3. Compliance readiness gates
- COPPA/GDPR-K lifecycle operations validated for RC scope (`TASK-048`, `TASK-060`)
- Audit logging and traceability verified for:
  - moderation interventions
  - publish approvals/rejections
  - lifecycle operations (export/delete/retention/revocation)
- No unresolved high-severity compliance findings

## 4. Manual certification gates
- `./scripts/ci/validate-manual-qa-artifacts.sh` passes for `TASK-055/056/059/060`
- Manual evidence attached and triaged:
  - `TASK-055` gameplay charter
  - `TASK-056` localization/accessibility sweep
  - `TASK-059` trust charter
  - `TASK-060` compliance drill
- All critical findings have owner, remediation path, and deadline

## 5. Release governance gates
- Launch checklist completed (`launch-checklist.md`)
- Rollback plan tested and owned for launch window
- Incident response and support escalation rosters current
- Final go/no-go decision signed by release owner and safety/compliance approvers

## 6. Hard stop conditions (automatic no-go)
- Any unresolved high-severity safety or compliance finding
- Failure in required quality gates on RC commit
- Missing rollback path or unassigned incident commander
- Missing mandatory manual certification evidence for RC scope
