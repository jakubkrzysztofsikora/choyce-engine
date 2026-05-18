## Persistent filesystem adapter for AuditLedgerPort.
## Stores audit records as newline-delimited JSON (JSONL) with
## hash-chain integrity verification. Fails closed on I/O errors.
class_name FilesystemAuditLedger
extends AuditLedgerPort

var _base_path: String = "user://audit"
var _file_path: String = ""


func setup(base_path: String = "user://audit") -> FilesystemAuditLedger:
	_base_path = base_path
	_file_path = _base_path.path_join("audit.jsonl")
	_ensure_directory()
	return self


func append_record(record: AuditRecord) -> bool:
	if not _ensure_directory():
		return false
	if record == null:
		push_error("FilesystemAuditLedger: null record")
		return false
	if record.record_id.strip_edges().is_empty():
		push_error("FilesystemAuditLedger: empty record_id")
		return false
	if not record.verify():
		push_error("FilesystemAuditLedger: record hash verification failed for %s" % record.record_id)
		return false

	var expected_prev := last_hash()
	if record.previous_hash != expected_prev:
		push_error("FilesystemAuditLedger: hash chain broken for record %s" % record.record_id)
		return false

	var dict := record.to_dict()
	var line := JSON.stringify(dict) + "\n"

	var file: FileAccess
	if FileAccess.file_exists(_file_path):
		file = FileAccess.open(_file_path, FileAccess.READ_WRITE)
		if file != null:
			file.seek_end()
	else:
		file = FileAccess.open(_file_path, FileAccess.WRITE)

	if file == null:
		push_error("FilesystemAuditLedger: cannot open file for writing: %s" % _file_path)
		return false

	file.store_string(line)
	file.close()

	# Verify integrity by reading back the last line
	var verify_file := FileAccess.open(_file_path, FileAccess.READ)
	if verify_file == null:
		push_error("FilesystemAuditLedger: cannot open file for verification")
		return false

	var last_line := ""
	while not verify_file.eof_reached():
		var current := verify_file.get_line()
		if not current.strip_edges().is_empty():
			last_line = current
	verify_file.close()

	if last_line.is_empty():
		push_error("FilesystemAuditLedger: verification read returned empty")
		return false

	var parsed: Variant = JSON.parse_string(last_line)
	if not (parsed is Dictionary):
		push_error("FilesystemAuditLedger: last line is not valid JSON")
		return false

	var read_back := AuditRecord.from_dict(parsed as Dictionary)
	if read_back.record_hash != record.record_hash:
		push_error("FilesystemAuditLedger: hash mismatch after write")
		return false

	return true


func get_records(filter: Dictionary = {}) -> Array:
	var result: Array = []
	if not FileAccess.file_exists(_file_path):
		return result

	var file := FileAccess.open(_file_path, FileAccess.READ)
	if file == null:
		push_error("FilesystemAuditLedger: cannot open file for reading")
		return result

	var actor_filter := str(filter.get("actor_id", "")).strip_edges()
	var type_filter := str(filter.get("event_type", "")).strip_edges()
	var from_iso := str(filter.get("from_iso", "")).strip_edges()
	var to_iso := str(filter.get("to_iso", "")).strip_edges()
	var limit_val: int = filter.get("limit", 100) as int if filter.get("limit") is int else 100

	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line.is_empty():
			continue
		var parsed: Variant = JSON.parse_string(line)
		if not (parsed is Dictionary):
			continue
		var record := AuditRecord.from_dict(parsed as Dictionary)

		if not actor_filter.is_empty() and record.actor_id != actor_filter:
			continue
		if not type_filter.is_empty() and record.event_type != type_filter:
			continue
		if not from_iso.is_empty() and record.timestamp < from_iso:
			continue
		if not to_iso.is_empty() and record.timestamp >= to_iso:
			continue

		result.append(record)
		if result.size() >= limit_val:
			break

	file.close()
	return result


func verify_integrity() -> Dictionary:
	if not FileAccess.file_exists(_file_path):
		return {"ok": true, "total_records": 0, "last_valid_index": -1}

	var file := FileAccess.open(_file_path, FileAccess.READ)
	if file == null:
		push_error("FilesystemAuditLedger: cannot open file for integrity check")
		return {"ok": false, "total_records": 0, "last_valid_index": -1}

	var prev_hash := ""
	var index := 0
	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line.is_empty():
			continue
		var parsed: Variant = JSON.parse_string(line)
		if not (parsed is Dictionary):
			return {"ok": false, "total_records": index, "last_valid_index": index - 1}

		var record := AuditRecord.from_dict(parsed as Dictionary)
		if record.previous_hash != prev_hash:
			return {"ok": false, "total_records": index + 1, "last_valid_index": index - 1}
		if not record.verify():
			return {"ok": false, "total_records": index + 1, "last_valid_index": index - 1}

		prev_hash = record.record_hash
		index += 1

	file.close()
	return {"ok": true, "total_records": index, "last_valid_index": index - 1}


func record_count() -> int:
	if not FileAccess.file_exists(_file_path):
		return 0
	var file := FileAccess.open(_file_path, FileAccess.READ)
	if file == null:
		return 0
	var count := 0
	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if not line.is_empty():
			count += 1
	file.close()
	return count


func last_hash() -> String:
	if not FileAccess.file_exists(_file_path):
		return ""
	var file := FileAccess.open(_file_path, FileAccess.READ)
	if file == null:
		return ""
	var last_line := ""
	while not file.eof_reached():
		var current := file.get_line().strip_edges()
		if not current.is_empty():
			last_line = current
	file.close()
	if last_line.is_empty():
		return ""
	var parsed: Variant = JSON.parse_string(last_line)
	if not (parsed is Dictionary):
		return ""
	var record := AuditRecord.from_dict(parsed as Dictionary)
	return record.record_hash


## Convenience alias for append_record.
func append(record: AuditRecord) -> bool:
	return append_record(record)


## Typed query wrapper over get_records.
func query(actor_id: String = "", event_type: String = "", from_iso: String = "", to_iso: String = "", limit: int = 100) -> Array[AuditRecord]:
	var filter := {}
	if not actor_id.is_empty():
		filter["actor_id"] = actor_id
	if not event_type.is_empty():
		filter["event_type"] = event_type
	if not from_iso.is_empty():
		filter["from_iso"] = from_iso
	if not to_iso.is_empty():
		filter["to_iso"] = to_iso
	filter["limit"] = limit
	var result: Array[AuditRecord] = []
	for item in get_records(filter):
		if item is AuditRecord:
			result.append(item)
	return result


## Convenience alias for last_hash.
func get_latest_hash() -> String:
	return last_hash()


func _ensure_directory() -> bool:
	if not DirAccess.dir_exists_absolute(_base_path):
		var err := DirAccess.make_dir_recursive_absolute(_base_path)
		if err != OK:
			push_error("FilesystemAuditLedger: failed to create directory: %s" % _base_path)
			return false
	return true
