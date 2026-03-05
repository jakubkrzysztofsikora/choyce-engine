Please review TASK-032 implementation in:
- src/application/polish_first_language_policy_service.gd
- src/application/request_ai_creation_help_service.gd
- src/application/request_gameplay_hint_service.gd
- src/application/audio_governance_service.gd
- src/adapters/outbound/elevenlabs_tts_adapter.gd
- tests/contracts/polish_first_language_policy_service_contract_test.gd
- tests/contracts/request_ai_creation_help_service_contract_test.gd
- tests/contracts/request_gameplay_hint_service_contract_test.gd
- tests/contracts/audio_governance_service_contract_test.gd
- tests/contracts/run_task_032_tests.gd

Handoff details:
- .ai/handoffs/TASK-032-handoff-to-claude.md

Acceptance targets:
1. Kid and parent AI interactions default to Polish text and voice output.
2. Parent override can switch language while preserving kid-mode safety defaults.
