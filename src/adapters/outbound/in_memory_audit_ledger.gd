## In-memory adapter for AuditLedgerPort.
## Maintains an append-only array with hash chain verification.
## Suitable for testing and development; production use should
## persist to filesystem (LocalAuditLedgerAdapter).
class_name InMemoryAuditLedger
extends AuditLedgerPort

var _records: Array = []
var _last_hash: String = ""


func setup() -> InMemoryAuditLedger:
	_records = []
	_last_hash = ""
	return self


func append_record(record: AuditRecord) -> bool:
	if record == null:
		return false
	if record.record_id.strip_edges().is_empty():
		return false
	if record.previous_hash != _last_hash:
		return false
	if not record.verify():
		return false

	_records.append(record)
	_last_hash = record.record_hash
	return true


func get_records(filter: Dictionary = {}) -> Array:
	var actor_filter := str(filter.get("actor_id", "")).strip_edges()
	var type_filter := str(filter.get("event_type", "")).strip_edges()
	var from_iso := str(filter.get("from_iso", "")).strip_edges()
	var to_iso := str(filter.get("to_iso", "")).strip_edges()
	var limit_val: int = filter.get("limit", 100) as int if filter.get("limit") is int else 100

	var result: Array = []
	for record in _records:
		if not record is AuditRecord:
			continue
		var r: AuditRecord = record

		if not actor_filter.is_empty() and r.actor_id != actor_filter:
			continue
		if not type_filter.is_empty() and r.event_type != type_filter:
			continue
		if not from_iso.is_empty() and r.timestamp < from_iso:
			continue
		if not to_iso.is_empty() and r.timestamp >= to_iso:
			continue

		result.append(r)
		if result.size() >= limit_val:
			break

	return result


func verify_integrity() -> Dictionary:
	var total := _records.size()
	if total == 0:
		return {"ok": true, "total_records": 0, "last_valid_index": -1}

	var prev_hash := ""
	for i in range(total):
		var record: AuditRecord = _records[i]

		# Check that previous_hash links correctly
		if record.previous_hash != prev_hash:
			return {"ok": false, "total_records": total, "last_valid_index": i - 1}

		# Verify the record's own hash
		if not record.verify():
			return {"ok": false, "total_records": total, "last_valid_index": i - 1}

		prev_hash = record.record_hash

	return {"ok": true, "total_records": total, "last_valid_index": total - 1}


func record_count() -> int:
	return _records.size()


func last_hash() -> String:
	return _last_hash
