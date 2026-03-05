Please review TASK-018 implementation in:
- src/application/ai_failsafe_controller.gd
- src/application/request_ai_creation_help_service.gd
- src/application/request_gameplay_hint_service.gd
- tests/contracts/ai_failsafe_controller_contract_test.gd
- tests/contracts/request_gameplay_hint_service_contract_test.gd
- tests/contracts/request_ai_creation_help_service_contract_test.gd

Handoff details:
- .ai/handoffs/TASK-018-handoff-to-claude.md

Acceptance targets:
1. Failsafe mode disables generative output while keeping core editor usable.
2. Rules-based hint helper activates when model services are unavailable.
