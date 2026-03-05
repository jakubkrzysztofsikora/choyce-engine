Please review TASK-038 implementation in:
- .github/workflows/quality-gates.yml
- scripts/ci/check-domain-isolation.sh
- scripts/ci/run-prompt-regression.sh
- scripts/ci/run-safety-gates.sh
- scripts/run-quality-gates.sh
- tests/safety/run_prompt_regression_tests.gd
- tests/safety/run_safety_redteam_tests.gd

Handoff details:
- .ai/handoffs/TASK-038-handoff-to-claude.md

Acceptance targets:
1. CI enforces high domain test isolation from engine runtime and network dependencies.
2. Safety red-team and AI regression suites gate model and policy changes.
