# Handoff: TASK-019 -> Codex (Cross-Review)

## Summary of changes
Implemented tamper-evident AI and moderation audit ledger with hash-chained records, parent-facing timeline/intervention queries, and family-linked visibility.

### New shared kernel value object
- Added `AuditRecord` (src/domain/shared/audit_record.gd):
  - Immutable record with record_id, event_type, event_id, actor_id, timestamp, payload
  - SHA-256 hash chain: each record hashes its content + previous_hash
  - `from_event()` factory extracts payload from any DomainEvent (including event-specific fields)
  - `to_dict()` / `from_dict()` for serialization
  - `verify()` re-computes hash to detect tampering
  - `compute_hash()` static for deterministic hash generation

### New outbound port
- Added `AuditLedgerPort` (src/ports/outbound/audit_ledger_port.gd):
  - `append_record(record: AuditRecord) -> bool`
  - `get_records(filter: Dictionary) -> Array` — supports actor_id, event_type, from_iso, to_iso, limit
  - `verify_integrity() -> Dictionary` — returns {ok, total_records, last_valid_index}
  - `record_count() -> int`
  - `last_hash() -> String`

### New adapters
- Added `InMemoryAuditLedger` (src/adapters/outbound/in_memory_audit_ledger.gd):
  - Append-only in-memory array with hash chain maintenance
  - Multi-criteria filtering (actor, type, timestamp range, limit)
  - `verify_integrity()` walks chain, checks previous_hash linkage + per-record hash
  - Rejects null records and empty record_ids

- Added `ParentAuditReadModelAdapter` (src/adapters/outbound/parent_audit_read_model_adapter.gd):
  - Implements `ParentAuditReadModel` port (get_timeline, get_interventions, update_from_event)
  - Delegates persistence to `AuditLedgerPort`
  - `register_family_link(parent_id, kid_id)` for parent-to-kid visibility
  - `update_from_event()` converts any DomainEvent → AuditRecord with hash chain
  - `get_timeline()` returns merged parent + linked kids events, sorted by timestamp
  - `get_interventions()` filters for SafetyInterventionTriggered events only

### Tamper-evidence model
- Each AuditRecord stores `previous_hash` (hash of preceding record) and `record_hash` (SHA-256 of its own content + previous_hash)
- Hash input: `record_id|event_type|event_id|timestamp|JSON(payload)|previous_hash`
- `verify_integrity()` re-walks the full chain and detects any modification
- Tested: modifying a record's payload causes chain verification to fail, with `last_valid_index` pointing to the record before the tampered one

## Files created
- `src/domain/shared/audit_record.gd`
- `src/ports/outbound/audit_ledger_port.gd`
- `src/adapters/outbound/in_memory_audit_ledger.gd`
- `src/adapters/outbound/parent_audit_read_model_adapter.gd`
- `tests/contracts/audit_ledger_port_contract_test.gd`
- `tests/contracts/in_memory_audit_ledger_adapter_contract_test.gd`
- `tests/contracts/parent_audit_read_model_adapter_contract_test.gd`
- `.ai/handoffs/TASK-019-handoff-to-codex.md`

## Files updated
- `tests/contracts/run_contract_tests.gd` (3 new test registrations)
- `src/domain/CONTEXT_MAP.md` (AuditRecord in shared kernel, 2 new adapters)
- `.ai/tasks/backlog.yaml` (TASK-019 → in_review)

## Verification
Executed:
```bash
./scripts/run-contract-tests.sh
```

Result:
- `Contracts: 46`
- `Checks: 535`
- `Failed contracts: 0`

New passing contracts:
- `AuditLedgerPort` (11 checks)
- `InMemoryAuditLedgerAdapter` (21 checks)
- `ParentAuditReadModelAdapter` (15 checks)

## Acceptance criteria mapping
1. Prompts, tool invocations, moderation decisions, and parent overrides are logged with reason data:
   - `AuditRecord.from_event()` extracts all event-specific fields into payload (decision_type, policy_rule, intent_summary, tool_invocations_count, impact_level, etc.)
   - `ParentAuditReadModelAdapter.update_from_event()` converts any DomainEvent into a persisted audit record

2. Audit records are tamper-evident and queryable for parent timeline views:
   - SHA-256 hash chain with `verify_integrity()` detects retroactive modification
   - `get_timeline()` provides parent-facing view with family-linked kid events
   - `get_interventions()` filters specifically for safety interventions

## Review focus areas
1. Validate hash chain computation and tamper detection semantics
2. Validate AuditRecord.from_event() payload extraction (uses get_property_list reflection)
3. Validate family-link based timeline filtering in ParentAuditReadModelAdapter
4. Validate that the port/adapter separation is clean and follows project patterns
