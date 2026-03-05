# Handoff: TASK-038 -> Claude (Cross-Review)

## Summary
Implemented CI-quality gate scaffolding with explicit domain-isolation checks, safety red-team suite, and prompt-regression suite. Added a GitHub Actions workflow to run these gates on PRs/pushes.

## Files created
- `.github/workflows/quality-gates.yml`
- `scripts/ci/check-domain-isolation.sh`
- `scripts/ci/run-prompt-regression.sh`
- `scripts/ci/run-safety-gates.sh`
- `scripts/run-quality-gates.sh`
- `tests/safety/run_prompt_regression_tests.gd`
- `tests/safety/run_safety_redteam_tests.gd`

## Files updated
- `README.md`
- `.ai/tasks/backlog.yaml` (`TASK-038` -> `in_review`)

## Implementation details
1. Domain isolation gate
- `scripts/ci/check-domain-isolation.sh` scans `src/domain/` for forbidden runtime/network coupling patterns (scene classes, HTTP/network APIs, filesystem/runtime adapter references).
- Fails fast with offending lines.

2. Prompt regression quality gate
- `tests/safety/run_prompt_regression_tests.gd` loads prompt fixtures from:
  - `data/ai/prompt_regression_fixtures.json`
  - resolves templates through registry adapter
  - verifies expected markers per fixture
  - verifies kid locale guard (`en-US` request -> `pl-PL` resolution).
- Runner script: `scripts/ci/run-prompt-regression.sh`.

3. Safety red-team quality gate
- `tests/safety/run_safety_redteam_tests.gd` includes representative adversarial checks:
  - moderation blocks unsafe text categories,
  - kid disallowed-tool request rejected (`script_edit`),
  - unsafe voice transcript blocked by voice moderation pipeline.
- Runner script: `scripts/ci/run-safety-gates.sh`.

4. Unified local gate entrypoint
- `scripts/run-quality-gates.sh` executes:
  - domain isolation gate
  - prompt regression gate
  - safety red-team gate
  - focused baseline suites (`TASK-027`, `TASK-032`) for prompt/safety behavior.

5. CI workflow
- `.github/workflows/quality-gates.yml`
  - triggers on `pull_request` and push to `main/master`
  - installs Godot via `firebelley/setup-godot@v1`
  - executes `./scripts/run-quality-gates.sh`.

## Validation
Executed locally:
```bash
./scripts/ci/check-domain-isolation.sh
./scripts/ci/run-prompt-regression.sh
./scripts/ci/run-safety-gates.sh
./scripts/run-quality-gates.sh
```

Observed:
- all gates passed
- prompt-template port contract emits expected `push_error(...)` lines for abstract methods (consistent with existing contract harness behavior).

## Acceptance mapping
1. CI enforces high domain test isolation from engine runtime and network dependencies:
- Implemented through dedicated isolation gate script and workflow wiring.

2. Safety red-team and AI regression suites gate model and policy changes:
- Implemented via red-team runner + prompt regression runner + quality-gates workflow integration.

## Review focus
1. Domain-isolation forbidden patterns completeness/false-positive risk.
2. Safety red-team scenarios coverage depth for release gating.
3. Prompt regression fixture assertions and failure ergonomics.
4. GitHub workflow action/version suitability (`setup-godot`) for project CI environment.
