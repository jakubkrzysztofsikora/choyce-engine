# Handoff: TASK-012 -> Claude (Cross-Review)

## Summary of changes
Implemented deterministic AI orchestration flow in `RequestAICreationHelpService`:
- Added explicit loop stages:
  1. intent/event capture
  2. pre-check moderation
  3. LLM tool planning
  4. deterministic tool validation (scope + argument safety)
  5. impact classification + approval gating
  6. explanation generation
  7. output moderation
  8. transactional tool execution (with rollback)
  9. audit event emission
- High-impact actions now remain `PROPOSED` and are not executed until explicit approval.
- Low/medium actions execute transactionally through a gateway and emit `AIAssistanceAppliedEvent`.

## Files created
- `src/application/tool_execution_gateway.gd`
- `tests/contracts/request_ai_creation_help_service_contract_test.gd`
- `.ai/handoffs/TASK-012-handoff-to-claude.md`

## Files updated
- `src/application/request_ai_creation_help_service.gd`
- `src/application/approve_ai_patch_service.gd` (typed `reversible_patch_keys` population)
- `tests/contracts/run_contract_tests.gd`
- `tests/contracts/README.md`
- `.ai/tasks/backlog.yaml` (`TASK-012` moved to `in_review`)

## Behavior notes
1. Validation gate:
   - Blocks tool invocations outside `envelope.permitted_tools`.
   - Blocks non-deterministic argument types (`Callable`, `Object`).
2. Approval gate:
   - `requires_parent_approval` is set for high-impact proposals.
   - High-impact actions are returned as `PROPOSED` without execution.
3. Transaction semantics:
   - Executes tools in order through `ToolExecutionGateway`.
   - On failure, rolls back prior successful steps in reverse order.
4. Audit emissions:
   - `AIAssistanceRequestedEvent` emitted at request start.
   - `SafetyInterventionTriggeredEvent` emitted on moderation/validation blocks.
   - `AIAssistanceAppliedEvent` emitted for applied low/medium actions.

## Verification
Executed:
```bash
./scripts/run-contract-tests.sh
```

Result:
- `Contracts: 25`
- `Checks: 256`
- `Failed contracts: 0`

New passing contract:
- `RequestAICreationHelpService` (10 checks)

## Open risks and assumptions
1. If no `ToolExecutionGateway` is wired, execution path is deterministic no-op apply (explicit current fallback).
2. Tool schema-level determinism (argument schemas/idempotency catalog) is still coarse and expected to be tightened in TASK-013.
3. High-impact threshold logic remains heuristic (`logic_edit`/`script_edit` + batch size); policy tuning may be needed with real telemetry.

## Review focus areas
1. Validate loop stage ordering and failure handling against AR-AI-001/002/003.
2. Validate approval gating semantics for high-impact actions.
3. Validate transactional rollback behavior and emitted audit events for low/medium execution paths.
