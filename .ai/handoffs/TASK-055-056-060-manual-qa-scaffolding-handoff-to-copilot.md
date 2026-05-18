# Manual QA Scaffolding Handoff (TASK-055 / TASK-056 / TASK-060)

## Summary
Added structured manual-QA artifact scaffolding for remaining manual tasks and a deterministic validator to check evidence completeness before release sign-off.

## Files added
- `scripts/ci/validate-manual-qa-artifacts.sh`
- `.ai/manual-qa/TASK-055/README.md`
- `.ai/manual-qa/TASK-055/tier1-run.md`
- `.ai/manual-qa/TASK-055/tier2-run.md`
- `.ai/manual-qa/TASK-055/triage.md`
- `.ai/manual-qa/TASK-055/traceability.md`
- `.ai/manual-qa/TASK-055/evidence/.gitkeep`
- `.ai/manual-qa/TASK-056/README.md`
- `.ai/manual-qa/TASK-056/tier1-run.md`
- `.ai/manual-qa/TASK-056/tier2-run.md`
- `.ai/manual-qa/TASK-056/triage.md`
- `.ai/manual-qa/TASK-056/traceability.md`
- `.ai/manual-qa/TASK-056/evidence/.gitkeep`
- `.ai/manual-qa/TASK-060/README.md`
- `.ai/manual-qa/TASK-060/tier1-run.md`
- `.ai/manual-qa/TASK-060/tier2-run.md`
- `.ai/manual-qa/TASK-060/triage.md`
- `.ai/manual-qa/TASK-060/traceability.md`
- `.ai/manual-qa/TASK-060/evidence/.gitkeep`

## Files updated
- `README.md`
- `docs/release/README.md`
- `docs/release/launch-checklist.md`
- `docs/release/release-exit-criteria.md`
- `.ai/reviews/TASK-059-codex-review.json`
- `.ai/handoffs/TASK-059-codex-review-findings.md`

## Validator behavior
`validate-manual-qa-artifacts.sh` checks each task for:
1. Required files: `tier1-run.md`, `tier2-run.md`, `triage.md`, `traceability.md`
2. No `TODO`/`TBD` placeholders in required files
3. Non-empty `evidence/` folder (excluding `.gitkeep`)
4. Machine-readable summary output:
   - `MANUAL_QA_VALIDATION_REPORT_JSON=<json>`

## Usage
```bash
./scripts/ci/validate-manual-qa-artifacts.sh
./scripts/ci/validate-manual-qa-artifacts.sh TASK-059
```

Current expected state:
- Validator fails until manual runs are truly executed and artifacts are filled.
