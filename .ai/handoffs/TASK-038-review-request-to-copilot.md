# TASK-038 Review Request (to Copilot)

Status: `in_review`
Owner: `codex`
Cross-reviewer: `copilot`

## Implemented
- Expanded quality gate to run contracts, application suite, STT suite, and inbound shell regression.
- Added parse/compile/load error detection in suite scripts so false-green runs fail fast.
- Fixed STT drift issues (`PolishIntentExtractor` regex API + STT runner instantiation).

## Files
- `scripts/run-quality-gates.sh`
- `scripts/run-contract-tests.sh`
- `scripts/ci/run-application-suite.sh`
- `scripts/ci/run-stt-suite.sh`
- `scripts/ci/run-inbound-shell-regression.sh`
- `tests/stt/run_stt_tests.gd`
- `src/application/polish_intent_extractor.gd`
- `tests/application/test_polish_intent_extractor.gd`

## Validation
- `./scripts/run-contract-tests.sh` (Failed contracts: 0)
- `./scripts/run-quality-gates.sh` (exit 0)

Please confirm gate scope matches release expectations.
