# Handoff: TASK-004 -> Claude (Cross-Review)

## Summary of changes
Implemented TASK-004 scope for in-domain eventing and CQRS-lite read model boundaries:
- Added an in-domain `DomainEventBus` for typed and wildcard subscribers with bounded history.
- Added read model outbound ports:
  - `KidStatusReadModel`
  - `ParentAuditReadModel`
  - `AIPerformanceReadModel`
- Wired event emission in key application services to cover required action categories:
  - World edits (`WorldEditedEvent`)
  - Rule compilation changes (`RuleChangedEvent`)
  - AI request lifecycle (`AIAssistanceRequestedEvent`)
  - Safety interventions (`SafetyInterventionTriggeredEvent`)

## Files created
- `src/domain/events/event_bus.gd`
- `src/ports/outbound/kid_status_read_model.gd`
- `src/ports/outbound/parent_audit_read_model.gd`
- `src/ports/outbound/ai_performance_read_model.gd`
- `tests/contracts/domain_event_bus_contract_test.gd`
- `tests/contracts/kid_status_read_model_port_contract_test.gd`
- `tests/contracts/parent_audit_read_model_port_contract_test.gd`
- `tests/contracts/ai_performance_read_model_port_contract_test.gd`

## Files updated
- `src/application/apply_world_edit_service.gd` (emit `WorldEditedEvent`)
- `src/application/compile_block_logic_service.gd` (emit `RuleChangedEvent`)
- `src/application/request_ai_creation_help_service.gd` (emit `AIAssistanceRequestedEvent` and moderation block `SafetyInterventionTriggeredEvent`)
- `tests/contracts/run_contract_tests.gd` (added 4 new contract scripts)
- `tests/contracts/README.md` (documented added contract coverage)
- `.ai/tasks/backlog.yaml` (`TASK-004` moved to `in_review`)

## Verification
Executed:
```bash
./scripts/run-contract-tests.sh
```

Result:
- `Contracts: 21`
- `Checks: 187`
- `Failed contracts: 0`

Note:
- Abstract port tests intentionally log `push_error(... not implemented)`; this is expected in this harness and not a failure condition.

## Open risks and assumptions
1. Event bus is in-process and synchronous; no retry/queue semantics are included yet.
2. Publishing services currently instantiate domain events but do not emit through a shared event bus yet (tracked under publish-flow work).
3. Read model ports are interface-only in this task; concrete adapters are expected in later analytics/dashboard tasks.

## Review focus areas
1. Verify event coverage aligns with AR section 8 and includes world/rule/AI/safety action flows.
2. Validate event bus contract behavior (subscriber lifecycle, history capping, typed vs wildcard delivery).
3. Confirm read model port shape is sufficient for upcoming parent/kid dashboard adapter tasks.

## Commands used
```bash
godot4 --headless --path . --check-only --script src/domain/events/event_bus.gd
godot4 --headless --path . --check-only --script src/application/apply_world_edit_service.gd
godot4 --headless --path . --check-only --script src/application/compile_block_logic_service.gd
godot4 --headless --path . --check-only --script src/application/request_ai_creation_help_service.gd
godot4 --headless --path . --check-only --script tests/contracts/domain_event_bus_contract_test.gd
godot4 --headless --path . --check-only --script tests/contracts/kid_status_read_model_port_contract_test.gd
godot4 --headless --path . --check-only --script tests/contracts/parent_audit_read_model_port_contract_test.gd
godot4 --headless --path . --check-only --script tests/contracts/ai_performance_read_model_port_contract_test.gd
./scripts/run-contract-tests.sh
```
