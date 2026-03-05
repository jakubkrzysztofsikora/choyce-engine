# Handoff: TASK-018 -> Claude (Cross-Review)

## Summary of changes
Implemented AI failsafe mode and graceful hint degradation using an explicit application-level controller and service integrations.

### New application component
1. `AIFailsafeController`
- New emergency-mode switch (`enable`, `disable`, `is_enabled`).
- Generates deterministic disabled-action responses for creation AI flows.
- Provides deterministic rules-based helper hints (levels 1-3) when generative models are unavailable.

### Updated AI creation orchestration
2. `RequestAICreationHelpService`
- Added optional `AIFailsafeController` dependency.
- When failsafe is enabled, service returns a rejected action with clear failsafe explanation instead of calling LLM tool-planning.
- Emits `SafetyInterventionTriggered` event with `policy_rule = FAILSAFE_MODE`.

### Updated gameplay hint service
3. `RequestGameplayHintService`
- Added optional `AIFailsafeController` dependency.
- If failsafe is enabled, bypasses LLM and returns deterministic rules-based hints.
- If LLM is unavailable (`empty response` or provider reports `fallback`), automatically switches to rules-based helper hints and emits a safety/intervention event for audit traceability.

## Files created
- `src/application/ai_failsafe_controller.gd`
- `tests/contracts/ai_failsafe_controller_contract_test.gd`
- `tests/contracts/request_gameplay_hint_service_contract_test.gd`
- `.ai/handoffs/TASK-018-handoff-to-claude.md`

## Files updated
- `src/application/request_ai_creation_help_service.gd`
- `src/application/request_gameplay_hint_service.gd`
- `tests/contracts/request_ai_creation_help_service_contract_test.gd`
- `tests/contracts/run_contract_tests.gd`
- `tests/contracts/README.md`
- `.ai/tasks/backlog.yaml` (`TASK-018` -> `in_review` after handoff)

## Verification
Executed:
```bash
./scripts/run-contract-tests.sh
```

Result:
- `Contracts: 40`
- `Checks: 453`
- `Failed contracts: 0`

New/updated passing contracts:
- `AIFailsafeController` (10 checks)
- `RequestGameplayHintService` (4 checks)
- `RequestAICreationHelpService` (14 checks, now includes failsafe assertions)

## Acceptance criteria mapping
1. Failsafe mode disables generative output while keeping core editor usable:
- Creation service now hard-stops AI generation/tool planning when failsafe is active, returning deterministic safe rejection state (no editor crash/path break).

2. Rules-based hint helper activates when model services are unavailable:
- Hint service now falls back to deterministic rules-based hinting when model output is unavailable or adapter reports fallback provider.
- Failsafe mode also forces deterministic hint helper behavior.

## Review focus areas
1. Validate failsafe gating behavior in `RequestAICreationHelpService` (no accidental generative path when enabled).
2. Validate model-unavailable detection and rules-based fallback semantics in `RequestGameplayHintService`.
3. Validate event policy-rule tagging (`FAILSAFE_MODE`, `RULES_HINT_FALLBACK`) for downstream audit/read-model consumption.
