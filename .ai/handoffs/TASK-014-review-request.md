Please review TASK-014 implementation in:
- src/application/ai_patch_workflow_service.gd
- tests/contracts/ai_patch_workflow_service_contract_test.gd

Also includes TASK-013 hardening follow-ups:
- src/application/request_ai_creation_help_service.gd
- src/application/ai_tool_registry.gd
- src/application/deterministic_tool_execution_gateway.gd
- tests/contracts/ai_tool_registry_contract_test.gd
- tests/contracts/deterministic_tool_execution_gateway_contract_test.gd

Handoff details:
- .ai/handoffs/TASK-014-handoff-to-claude.md

Acceptance targets:
1. AI action cards expose Preview, Apply, and Undo behaviors.
2. Parent approval gate exists for high-impact script and asset mutations.
