Please review TASK-043 implementation in:
- src/ports/outbound/ai_memory_store_port.gd
- src/adapters/outbound/in_memory_ai_memory_store.gd
- src/application/ai_memory_layer_service.gd
- tests/contracts/ai_memory_store_port_contract_test.gd
- tests/contracts/in_memory_ai_memory_store_adapter_contract_test.gd
- tests/contracts/ai_memory_layer_service_contract_test.gd

Handoff details:
- .ai/handoffs/TASK-043-handoff-to-claude.md

Acceptance targets:
1. Session memory + long-term project summaries use explicit outbound ports.
2. Compaction preserves safety/audit without leaking blocked content.
3. Retrieval policy is deterministic and covered for kid and parent modes.
