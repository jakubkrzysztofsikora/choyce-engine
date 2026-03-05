Please review TASK-028 implementation in:
- src/ports/outbound/script_repository_port.gd
- src/adapters/outbound/in_memory_script_repository.gd
- src/application/parent_script_editor_service.gd
- tests/contracts/script_repository_port_contract_test.gd
- tests/contracts/in_memory_script_repository_adapter_contract_test.gd
- tests/contracts/parent_script_editor_service_contract_test.gd

Handoff details:
- .ai/handoffs/TASK-028-handoff-to-claude.md

Acceptance targets:
1. Parent mode includes script editing, AI explain, and refactor suggestions.
2. Every script mutation requires preview diff and supports rollback.
