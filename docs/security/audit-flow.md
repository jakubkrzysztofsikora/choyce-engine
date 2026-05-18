---
date: 2026-05-18
phase: 7f
ticket: contrarian-review-2026-05-18
status: canonical
---

# Audit Ledger Data Flow

## Source of Truth

**Decision: `event_bus → ParentAuditReadModelAdapter` is the sole write path into the audit ledger.**

All domain events MUST be emitted to `DomainEventBus` first. The read-model adapter (`ParentAuditReadModelAdapter`) subscribes via `event_bus.subscribe_all(...)` and is the only caller of `AuditLedgerPort.append_record()` at runtime.

Direct calls to `_audit_ledger.append_record()` from application services are **forbidden**, with the single migration exception documented in the table below.

## Rationale

1. **Single ordering guarantee.** The hash chain in both ledger implementations (`InMemoryAuditLedger`, `FilesystemAuditLedger`) is append-only and order-sensitive. Any concurrent or out-of-order writer risks breaking the `previous_hash` link and producing a chain verification failure. Funnelling all writes through one subscriber eliminates the race.

2. **Fewer call sites = easier audit.** At the time of this decision, only 2 callers of `append_record()` exist outside the ledger implementations themselves:
   - `ParentAuditReadModelAdapter.update_from_event()` — the legitimate subscriber (1 call site).
   - `ManageDataLifecycleService._log_audit()` — a direct bypass (1 call site).

   Routing the bypass through the event bus reduces total non-ledger callers to 1.

3. **Architecture alignment.** Application services already emit every other significant action via `_event_bus.emit(event)`. Consistency with that pattern avoids a second mental model for contributors.

4. **Testability.** Tests can inject a null ledger and still verify audit behaviour by asserting on bus events rather than ledger state.

## Migration Table

| File | Line | Current behaviour | Target behaviour | Priority |
|------|------|-------------------|------------------|----------|
| `src/application/manage_data_lifecycle_service.gd` | 212 | Calls `_audit_ledger.append_record(record)` directly after constructing an `AuditRecord` manually | Emit a new `DataLifecycleAuditEvent` (or reuse `DataExportRequestedEvent` / `DataDeleteRequestedEvent`) via injected `DomainEventBus`; remove `_audit_ledger` field from the service | Phase 8c or next available sprint |

No other application or adapter file calls `append_record()` outside the two locations above.

## Verification

Run these grep assertions in CI or pre-commit to enforce the contract:

```bash
# 1. Ledger constructed only in composition root
# Expected: exactly 2 lines (one per branch of the env var guard)
grep -rn "AuditLedger\.new()" src/ | grep -v "_build_default_ports"
# Must return EMPTY

# 2. Only ParentAuditReadModelAdapter calls append_record at runtime
# Expected: 1 hit (the adapter itself) + 1 hit (port stub)
grep -rn "append_record(" src/ | grep -v "audit_ledger_port.gd" | grep -v "parent_audit_read_model_adapter.gd"
# Must return EMPTY after migration of manage_data_lifecycle_service.gd

# 3. No service holds a direct AuditLedgerPort reference (except the adapter and the lifecycle service until migrated)
grep -rn ": AuditLedgerPort" src/application/ | grep -v "manage_data_lifecycle_service.gd"
# Must return EMPTY

# 4. subscribe_all wiring present in composition root
grep -n "subscribe_all.*parent_audit.*update_from_event" src/adapters/inbound/main.gd
# Must return exactly 1 hit
```

## Audit Chain Integrity Contract

*Placeholder for Phase 8c segment-seal protocol.*

When Phase 8c lands, this section will be expanded with:

- **Segment seal envelope**: `{ prev_seal_hash, segment_root_hash, last_record_hash, segment_id, signed_at }` written to `segment_N.seal` at rotation time. Signing key is the same vault key as Phase 6 (`CHOYCE_VAULT_KEY`).
- **Active-window first record**: its `prev_hash` field MUST reference the `last_record_hash` of the most recent seal, preserving chain continuity across rotations.
- **`verify_integrity(scope)` contract**:
  - `scope = "active"` — verifies the active window references a valid latest seal and that all active records form an unbroken chain.
  - `scope = "full"` — walks every seal from origin, verifying each segment's root hash and inter-segment linkage.
- **Rotation I/O**: dispatched to `WorkerThreadPool.add_task`; `append_record()` never blocks on the archive write. Active-window swap is atomic via in-memory pointer flip.
- **Decryption failure path**: if the vault key is absent or corrupted, `append_record()` MUST fail closed (return `false`) and emit `AuditLedgerDecryptionFailedEvent` to the event bus. Never silently drop records.
