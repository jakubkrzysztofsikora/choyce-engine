# TASK-047 Review Findings (Codex)

Review decision: `request_changes`
Review artifact: `.ai/reviews/TASK-047-codex-review.json`

## Required remediation
1. Wire provenance badges into actual user surfaces (Create/Play/Library/Parent as appropriate) so kids and parents can see AI/Human/Hybrid provenance in normal flows.
2. Populate provenance metadata during AI generation/apply flows (text/visual/audio) with model + audit linkage, not only during persistence serialization.
3. Localize badge labels/tooltips through localization policy (Polish-first defaults).
4. Add automated test coverage that runs in existing runners/CI (not standalone orphan script only).

## Suggested validation
- `./scripts/run-contract-tests.sh` (or targeted suite if full suite currently blocked by unrelated failures)
- Add and run a deterministic inbound integration runner that includes provenance badge + metadata assertions.
