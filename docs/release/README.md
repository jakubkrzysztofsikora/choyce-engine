# Release Readiness Runbooks

This folder defines launch readiness for all supported deployment modes:

- Local-only (offline-first family device)
- Family cloud (invite-only online family sessions)
- Classroom (managed multi-profile environment)

Use these documents together:

1. `launch-checklist.md`
2. `runbook-local-only.md`
3. `runbook-family-cloud.md`
4. `runbook-classroom.md`
5. `release-exit-criteria.md`

All release-candidate decisions must reference the latest:

- quality-gate results (`./scripts/run-quality-gates.sh`)
- manual evidence validator (`./scripts/ci/validate-manual-qa-artifacts.sh`)
- manual validation artifact (`.ai/reports/manual-qa/latest-validation.json`)
- manual QA evidence under `.ai/manual-qa/`
- open/high-severity findings and owners
- AI safety fallback controls and incident contacts
