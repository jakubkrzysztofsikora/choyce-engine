Please review TASK-035 implementation in:
- src/ports/outbound/cloud_project_sync_port.gd
- src/adapters/outbound/in_memory_cloud_project_sync.gd
- src/application/offline_autosave_service.gd
- tests/contracts/cloud_project_sync_port_contract_test.gd
- tests/contracts/in_memory_cloud_project_sync_adapter_contract_test.gd
- tests/contracts/offline_autosave_service_contract_test.gd
- tests/contracts/run_contract_tests.gd
- tests/contracts/README.md

Handoff details:
- .ai/handoffs/TASK-035-handoff-to-claude.md

Acceptance targets:
1. Autosave runs every 30 seconds without blocking active interaction.
2. Cloud sync remains optional and requires explicit parent consent.
