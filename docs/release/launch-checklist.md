# Launch Checklist (All Modes)

Use this checklist for each release candidate (`RC`) before go/no-go.

## 1. Candidate metadata
- [ ] RC ID and git commit captured
- [ ] Build timestamp and target hardware tiers captured (`Tier-1`, `Tier-2`)
- [ ] Deployment mode explicitly selected (`local-only`, `family-cloud`, `classroom`)
- [ ] Release manager and incident commander assigned

## 2. Quality gate baseline
- [ ] `./scripts/run-quality-gates.sh` passed on RC commit
- [ ] Contract + application + STT + inbound shell suites passed
- [ ] Regression suites passed:
  - [ ] MVP acceptance (`TASK-050`)
  - [ ] Kid-parent-AI matrix (`TASK-053`)
  - [ ] Persistence resilience (`TASK-058`)
  - [ ] Performance gates (`TASK-039`)
- [ ] Machine-readable report artifacts archived with RC evidence

## 3. Safety and compliance controls
- [ ] Prompt safety and abuse regression gates green
- [ ] Child defaults verified as bounded and policy-safe
- [ ] Parent-only mutation paths enforce role-token checks
- [ ] AI action audit trail enabled and tamper checks pass
- [ ] Data lifecycle controls (export/delete/retention/consent) verified for current mode

## 4. Rollback readiness
- [ ] Rollback trigger criteria documented for this RC
- [ ] Previous known-good build artifact available
- [ ] Rollback command/playbook tested in dry-run
- [ ] Safe checkpoint restore and undo flows verified
- [ ] Owner on-call for rollback window assigned

## 5. Incident response readiness
- [ ] Incident severity matrix linked in release notes
- [ ] Pager/on-call roster verified
- [ ] AI safety incident template prepared
- [ ] Communication templates prepared (internal + parent-facing)
- [ ] Post-incident evidence capture path confirmed

## 6. Support escalation readiness
- [ ] L1 support runbook shared and acknowledged
- [ ] L2 engineering escalation contacts current
- [ ] Security/compliance escalation contacts current
- [ ] Known-issues list includes workaround and owner
- [ ] SLA targets documented for critical safety incidents

## 7. AI fallback controls
- [ ] Failsafe mode can be enabled without redeploy
- [ ] Rules-based fallback hints validated
- [ ] AI generation-off behavior validated for kid and parent surfaces
- [ ] Feature flags for AI experimental paths are default-safe
- [ ] Fallback activation and recovery events are auditable

## 8. Manual certification evidence
- [ ] `./scripts/ci/validate-manual-qa-artifacts.sh` passes for `TASK-055/056/059/060`
- [ ] `TASK-055` gameplay charter evidence attached
- [ ] `TASK-056` localization/accessibility evidence attached
- [ ] `TASK-059` pre-network trust charter evidence attached
- [ ] `TASK-060` compliance operations drill evidence attached
- [ ] All blocking findings triaged with owners and due dates

## 9. Go/No-Go decision
- [ ] Release exit criteria reviewed (`release-exit-criteria.md`)
- [ ] No unresolved high-severity safety/compliance risks
- [ ] Decision recorded with approver signatures
- [ ] Rollback owner confirmed for launch window
