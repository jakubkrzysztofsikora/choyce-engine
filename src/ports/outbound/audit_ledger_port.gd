## Outbound port for the tamper-evident audit ledger.
## Stores AuditRecord entries in an append-only hash-chained log.
## Adapters must maintain the hash chain and support integrity verification.
class_name AuditLedgerPort
extends RefCounted


## Appends a record to the ledger. Returns true on success.
func append_record(record: AuditRecord) -> bool:
	push_error("AuditLedgerPort.append_record() not implemented")
	return false


## Returns records matching the filter criteria.
## Supported filter keys:
##   actor_id: String — filter by actor
##   event_type: String — filter by event type
##   from_iso: String — inclusive start timestamp (ISO 8601)
##   to_iso: String — exclusive end timestamp (ISO 8601)
##   limit: int — max records to return (default 100)
func get_records(filter: Dictionary = {}) -> Array:
	push_error("AuditLedgerPort.get_records() not implemented")
	return []


## Verifies the hash chain integrity of the entire ledger.
## Returns {ok: bool, total_records: int, last_valid_index: int}.
## If ok is false, last_valid_index points to the last record that
## passed verification (or -1 if the first record is corrupt).
func verify_integrity() -> Dictionary:
	push_error("AuditLedgerPort.verify_integrity() not implemented")
	return {"ok": false, "total_records": 0, "last_valid_index": -1}


## Returns the total number of records in the ledger.
func record_count() -> int:
	push_error("AuditLedgerPort.record_count() not implemented")
	return 0


## Returns the hash of the most recently appended record,
## or empty string if the ledger is empty.
func last_hash() -> String:
	push_error("AuditLedgerPort.last_hash() not implemented")
	return ""
