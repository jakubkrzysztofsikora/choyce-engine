# TASK-047 Handoff to Claude (Cross-Review)

## Scope
Remediation + completion pass for TASK-047:
- provenance badges wired to active Create/Play/Library/Parent flows
- provenance metadata populated at runtime for AI text/visual/audio flows
- project manifest now stores AI provenance summary with audit linkage
- provenance tests wired into CI runners (non-orphan)

## Key implementation changes
- Runtime provenance tagging:
  - `src/application/request_ai_creation_help_service.gd`
  - `src/application/visual_asset_generation_service.gd`
  - `src/application/audio_governance_service.gd`
  - `src/application/apply_world_edit_service.gd`
- Domain metadata carriers:
  - `src/domain/ai_orchestration/ai_assistant_action.gd`
  - `src/domain/shared/tool_invocation.gd`
- Project metadata tagging:
  - `src/adapters/outbound/filesystem_project_store.gd`
- Badge localization + shell wiring:
  - `src/adapters/inbound/shared/ui/provenance_badge.gd`
  - `src/adapters/inbound/scenes/create/create_shell.gd`
  - `src/adapters/inbound/scenes/play/play_shell.gd`
  - `src/adapters/inbound/scenes/library/library_shell.gd`
  - `src/adapters/inbound/scenes/parent/parent_zone_shell.gd`
  - `src/adapters/inbound/main.gd`
- Runner/CI wiring:
  - `tests/contracts/run_task_047_tests.gd`
  - `tests/contracts/run_contract_tests.gd`
  - `tests/contracts/README.md`
  - `scripts/run-quality-gates.sh`

## Added tests
- `tests/contracts/provenance_badge_localization_contract_test.gd`
- `tests/contracts/apply_world_edit_service_provenance_contract_test.gd`
- Updated:
  - `tests/contracts/request_ai_creation_help_service_contract_test.gd`
  - `tests/contracts/visual_asset_generation_service_contract_test.gd`
  - `tests/contracts/audio_governance_service_contract_test.gd`
  - `tests/contracts/filesystem_project_store_adapter_contract_test.gd`

## Validation run
- `godot4 --headless --path . --script tests/contracts/run_task_047_tests.gd`
  - `Tests: 6  Checks: 126  Failed tests: 0`
- `./scripts/run-quality-gates.sh`
  - passed (includes TASK-047 suite now)
