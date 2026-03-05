# Handoff: TASK-014 -> Claude (Cross-Review)

## Summary of changes
Implemented reversible AI patch workflow with Preview / Apply / Undo action-card behaviors and parent gating for high-impact script/asset changes.

### New workflow service
- Added `AIPatchWorkflowService`:
  - `track_action(action)` registers proposed AI actions for card lifecycle.
  - `preview(action_id, actor)` returns card payload with:
    - status
    - impact level
    - requires_parent_approval
    - can_apply / can_undo flags
    - available actions (`Preview`, `Apply`, `Undo`)
  - `apply(action_id, actor)`:
    - enforces parent approval gate for:
      - high-impact actions
      - `script_edit`
      - `asset_import`
      - schema-flagged `requires_approval`
    - executes tool invocations transactionally through `ToolExecutionGateway`
    - stores reversible `undo_tokens`
    - records apply transition in `EventSourcedActionLog`
    - emits `AIAssistanceAppliedEvent`
  - `undo(action_id, actor)`:
    - rolls back undo tokens in reverse order
    - marks action as `REVERTED`
    - records revert transition in `EventSourcedActionLog`

### TASK-013 follow-up hardening integrated
While implementing downstream workflow, applied non-blocking improvements from Claude’s TASK-013 review:
- Parent-approval schema flag now influences impact assessment in `RequestAICreationHelpService._assess_impact(...)`.
- `safety_check` now requires at least one payload target (`text` or `image_ref`) in `AIToolRegistry`.
- `DeterministicToolExecutionGateway`:
  - bounded idempotency caches with eviction (`MAX_CACHE_ENTRIES`)
  - default execute result no longer stores full context payload
  - unsupported-type fingerprint serialization now includes type id
- Added test coverage for unknown-tool handler registration rejection.

## Files created
- `src/application/ai_patch_workflow_service.gd`
- `tests/contracts/ai_patch_workflow_service_contract_test.gd`
- `.ai/handoffs/TASK-014-handoff-to-claude.md`

## Files updated
- `src/application/request_ai_creation_help_service.gd`
- `src/application/ai_tool_registry.gd`
- `src/application/deterministic_tool_execution_gateway.gd`
- `tests/contracts/ai_tool_registry_contract_test.gd`
- `tests/contracts/deterministic_tool_execution_gateway_contract_test.gd`
- `tests/contracts/run_contract_tests.gd`
- `tests/contracts/README.md`
- `.ai/tasks/backlog.yaml` (`TASK-014` -> `in_review`; `TASK-013` -> `done`)

## Verification
Executed:
```bash
./scripts/run-contract-tests.sh
```

Result:
- `Contracts: 32`
- `Checks: 362`
- `Failed contracts: 0`

New passing contract:
- `AIPatchWorkflowService` (13 checks)

## Acceptance criteria mapping
1. AI action cards expose Preview / Apply / Undo:
   - Implemented via `AIPatchWorkflowService.preview/apply/undo`.
2. Parent approval gate for high-impact script and asset mutations:
   - Enforced in `_requires_parent_gate(...)` for high impact + `script_edit` + `asset_import` + schema approval flags.

## Review focus areas
1. Validate parent-gating logic for script/asset and high-impact actions.
2. Validate transactional apply + reverse-order undo rollback semantics.
3. Validate action-card payload semantics (preview flags and available actions).
