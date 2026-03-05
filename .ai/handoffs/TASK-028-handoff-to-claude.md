# Handoff: TASK-028 -> Claude (Cross-Review)

## Summary of changes
Implemented parent advanced scripting workflow with edit/explain/refactor and enforced preview-diff + rollback mutation flow.

### New port + adapter
- Added `ScriptRepositoryPort` outbound contract:
  - `load_script(project_id, script_path)`
  - `save_script(project_id, script_path, code)`
  - `exists(project_id, script_path)`
- Added `InMemoryScriptRepository` adapter for deterministic local behavior and tests.

### New application service
- Added `ParentScriptEditorService` with parent-mode gate on all operations:
  - `load_script(...)`
  - `explain_script(...)` (LLM-powered parent explanation prompt)
  - `suggest_refactor(...)` (LLM-powered safe refactor prompt)
  - `preview_mutation(...)` (required pre-apply step with line diff output)
  - `apply_mutation(...)` (only for previewed mutation IDs)
  - `rollback_mutation(...)` (restores prior code from rollback token)

### Mutation safety model
- Every apply requires prior `preview_mutation` (cannot apply arbitrary mutation IDs).
- Preview returns explicit `diff`, `old_code`, and `new_code`.
- Apply returns `rollback_token` with previous code.
- Rollback restores exact previous script source.
- Apply and rollback transitions are recorded in `EventSourcedActionLog`.

## Files created
- `src/ports/outbound/script_repository_port.gd`
- `src/adapters/outbound/in_memory_script_repository.gd`
- `src/application/parent_script_editor_service.gd`
- `tests/contracts/script_repository_port_contract_test.gd`
- `tests/contracts/in_memory_script_repository_adapter_contract_test.gd`
- `tests/contracts/parent_script_editor_service_contract_test.gd`
- `.ai/handoffs/TASK-028-handoff-to-claude.md`

## Files updated
- `tests/contracts/run_contract_tests.gd`
- `tests/contracts/README.md`
- `.ai/tasks/backlog.yaml` (`TASK-028` -> `in_review`)

## Verification
Executed:
```bash
./scripts/run-contract-tests.sh
```

Result:
- `Contracts: 35`
- `Checks: 396`
- `Failed contracts: 0`

New passing contracts:
- `ScriptRepositoryPort` (8 checks)
- `InMemoryScriptRepositoryAdapter` (10 checks)
- `ParentScriptEditorService` (15 checks)

## Acceptance criteria mapping
1. Parent mode includes script editing + AI explain + refactor suggestions:
   - Implemented in `ParentScriptEditorService` (`load_script`, `explain_script`, `suggest_refactor`).
2. Every script mutation requires preview diff and supports rollback:
   - Apply is only possible via preview-generated mutation ID.
   - Preview returns explicit diff.
   - Apply returns rollback token.
   - Rollback restores previous script source.

## Review focus areas
1. Validate preview-before-apply enforcement and rollback semantics.
2. Validate parent-only access gate in all service operations.
3. Validate prompt wording and boundaries for explain/refactor flows.
