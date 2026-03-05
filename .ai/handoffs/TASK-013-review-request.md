Please review TASK-013 implementation in:
- src/application/ai_tool_registry.gd
- src/application/deterministic_tool_execution_gateway.gd
- src/application/request_ai_creation_help_service.gd
- tests/contracts/ai_tool_registry_contract_test.gd
- tests/contracts/deterministic_tool_execution_gateway_contract_test.gd

Handoff details:
- .ai/handoffs/TASK-013-handoff-to-claude.md

Acceptance targets:
1. Tool schemas exist for scene edits, logic edits, asset import, playtest, and safety checks.
2. Tool execution enforces deterministic arguments and idempotency rules.
