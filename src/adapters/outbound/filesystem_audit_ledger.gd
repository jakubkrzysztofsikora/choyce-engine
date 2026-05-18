## Persistent filesystem adapter for AuditLedgerPort.
## Stores audit records as newline-delimited JSON (JSONL) with
## hash-chain integrity verification and segment-sealed rotation.
##
## Rotation: when the active window reaches _rotate_at records, the adapter
## archives them to segment_N.jsonl (JSONL) and writes segment_N.seal (JSON).
## Archive flush runs on WorkerThreadPool so append_record() never blocks on I/O.
## A mutex guards the active window snapshot so no race occurs with concurrent appends.
##
## Active window is persisted to audit_active.jsonl on each append so that
## re-instantiated adapters can resume without losing the active window.
##
## Seal schema (same as InMemoryAuditLedger):
##   {
##     segment_id: int,
##     record_count: int,
##     first_record_hash: String,
##     last_record_hash: String,
##     prev_seal_hash: String,
##     signed_at: String,
##     seal_integrity: String
##   }
##
## verify_integrity(scope) → {ok, scope, segments_verified, active_records, broken_at}
class_name FilesystemAuditLedger
extends AuditLedgerPort

## Production cap. Overridden for tests via setup_with_rotation().
const MAX_RECORDS := 50_000

var _base_path: String = "user://audit"
var _active_file: String = ""

## In-memory cache of the active window.
var _active_window: Array = []

## Hash of the most-recent record (or from latest seal after rotation).
var _last_hash: String = ""

## Hash of the most recent seal's last_record_hash (chain anchor).
var _last_seal_hash: String = ""

## Highest archived segment id (-1 if none).
var _last_segment_id: int = -1

## Hash of the most-recently-built seal dict (for chaining successive seals).
var _last_built_seal_hash: String = ""

## Rotation threshold.
var _rotate_at: int = MAX_RECORDS

## Active-window indexes for O(1) actor_id / event_type lookup in the hot path.
## Each key maps to Array[int] of indices into _active_window.
## Rebuilt atomically on rotation; archived segments are scan-only (slow path).
var _by_actor: Dictionary = {}
var _by_event_type: Dictionary = {}

## Incremental verify cache — highest active-window index verified.
## verify_integrity("active") only re-checks from here onward.
## Reset to -1 on rotation to prevent stale state across windows.
var _last_verified_seq: int = -1

## Mutex protecting _active_window and indexes during background rotation.
## append_record() locks for the window-snapshot + swap only (microseconds).
## Disk I/O (segment write) is never inside this lock.
var _mutex: Mutex = Mutex.new()

## Background rotation flush queue. Each entry: {segment_id, records, seal}.
## append_record() enqueues and dispatches WorkerThreadPool task — never blocks on I/O.
## flush_rotation() drains the queue synchronously (tests + shutdown).
## Multiple consecutive rotations each enqueue separately; tasks pop_front() under lock.
var _pending_flushes: Array = []
var _flush_mutex: Mutex = Mutex.new()


func setup(base_path: String = "user://audit") -> FilesystemAuditLedger:
	_base_path = base_path
	_active_file = _base_path.path_join("audit_active.jsonl")
	_rotate_at = MAX_RECORDS
	_ensure_directory()
	_load_active_window()
	return self


## Test-mode constructor: accepts custom rotation threshold.
func setup_with_rotation(base_path: String, rotate_at: int) -> FilesystemAuditLedger:
	_base_path = base_path
	_active_file = _base_path.path_join("audit_active.jsonl")
	_rotate_at = rotate_at
	_ensure_directory()
	_load_active_window()
	return self


func append_record(record: AuditRecord) -> bool:
	if record == null:
		push_error("FilesystemAuditLedger: null record")
		return false
	if record.record_id.strip_edges().is_empty():
		push_error("FilesystemAuditLedger: empty record_id")
		return false
	if record.previous_hash != _last_hash:
		push_error("FilesystemAuditLedger: hash chain broken for record %s" % record.record_id)
		return false
	if not record.verify():
		push_error("FilesystemAuditLedger: record hash verification failed for %s" % record.record_id)
		return false

	_mutex.lock()

	var idx := _active_window.size()
	_active_window.append(record)
	_last_hash = record.record_hash

	# Update indexes.
	var actor := record.actor_id
	if not _by_actor.has(actor):
		_by_actor[actor] = []
	(_by_actor[actor] as Array).append(idx)

	var etype := record.event_type
	if not _by_event_type.has(etype):
		_by_event_type[etype] = []
	(_by_event_type[etype] as Array).append(idx)

	_mutex.unlock()

	# Persist the new record to active window file.
	_append_line_to_active(record)

	# Rotate if cap reached.
	if _active_window.size() >= _rotate_at:
		_schedule_rotation()

	return true


func get_records(filter: Dictionary = {}) -> Array:
	var actor_filter := str(filter.get("actor_id", "")).strip_edges()
	var type_filter := str(filter.get("event_type", "")).strip_edges()
	var from_iso := str(filter.get("from_iso", "")).strip_edges()
	var to_iso := str(filter.get("to_iso", "")).strip_edges()
	var limit_val: int = filter.get("limit", 100) as int if filter.get("limit") is int else 100

	var result: Array = []

	# Fast path for actor_id using index (active window only).
	if not actor_filter.is_empty() and from_iso.is_empty() and to_iso.is_empty():
		var indices: Array = _by_actor.get(actor_filter, []) as Array
		for i in indices:
			if i >= _active_window.size():
				continue
			var r: AuditRecord = _active_window[i]
			if not type_filter.is_empty() and r.event_type != type_filter:
				continue
			result.append(r)
			if result.size() >= limit_val:
				break
		return result

	# Fast path for event_type using index (active window only).
	if not type_filter.is_empty() and from_iso.is_empty() and to_iso.is_empty():
		var indices: Array = _by_event_type.get(type_filter, []) as Array
		for i in indices:
			if i >= _active_window.size():
				continue
			var r: AuditRecord = _active_window[i]
			if not actor_filter.is_empty() and r.actor_id != actor_filter:
				continue
			result.append(r)
			if result.size() >= limit_val:
				break
		return result

	# Linear scan over active window.
	for record in _active_window:
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


## verify_integrity(scope) → {ok, scope, segments_verified, active_records, broken_at}
func verify_integrity(scope: String = "active") -> Dictionary:
	if scope == "full":
		return _verify_full()
	return _verify_active()


func _verify_active() -> Dictionary:
	var total := _active_window.size()
	var base := {
		"ok": true,
		"scope": "active",
		"segments_verified": 0,
		"active_records": total,
		"broken_at": null
	}

	if total == 0:
		_last_verified_seq = -1
		return base

	var start_idx := 0
	var prev_hash := _last_seal_hash

	if _last_verified_seq >= 0 and _last_verified_seq < total:
		start_idx = _last_verified_seq
		if start_idx == 0:
			prev_hash = _last_seal_hash
		else:
			var prev_rec: AuditRecord = _active_window[start_idx - 1]
			prev_hash = prev_rec.record_hash

	if start_idx == 0:
		prev_hash = _last_seal_hash

	for i in range(start_idx, total):
		var record: AuditRecord = _active_window[i]
		if record.previous_hash != prev_hash:
			return {"ok": false, "scope": "active", "segments_verified": 0,
					"active_records": total, "broken_at": i}
		if not record.verify():
			return {"ok": false, "scope": "active", "segments_verified": 0,
					"active_records": total, "broken_at": i}
		prev_hash = record.record_hash

	_last_verified_seq = total - 1
	return base


func _verify_full() -> Dictionary:
	var segments_verified := 0
	var prev_seal_hash := ""
	var seg_id := 0

	while true:
		var seg_path := _base_path.path_join("segment_%d.jsonl" % seg_id)
		var seal_path := _base_path.path_join("segment_%d.seal" % seg_id)

		# No more segments.
		if not FileAccess.file_exists(seg_path) and not FileAccess.file_exists(seal_path):
			break

		# Both files must exist.
		if not FileAccess.file_exists(seal_path):
			return {"ok": false, "scope": "full", "segments_verified": segments_verified,
					"active_records": _active_window.size(),
					"broken_at": "missing seal for segment %d" % seg_id}

		if not FileAccess.file_exists(seg_path):
			return {"ok": false, "scope": "full", "segments_verified": segments_verified,
					"active_records": _active_window.size(),
					"broken_at": "missing segment file %d" % seg_id}

		# Load seal.
		var seal_raw := FileAccess.get_file_as_string(seal_path)
		var seal: Variant = JSON.parse_string(seal_raw)
		if not (seal is Dictionary):
			return {"ok": false, "scope": "full", "segments_verified": segments_verified,
					"active_records": _active_window.size(),
					"broken_at": "corrupt seal json seg %d" % seg_id}
		var seal_dict: Dictionary = seal as Dictionary

		# Verify seal integrity.
		var stored_integrity := str(seal_dict.get("seal_integrity", ""))
		var expected_integrity := _compute_seal_integrity(seal_dict)
		if stored_integrity != expected_integrity:
			return {"ok": false, "scope": "full", "segments_verified": segments_verified,
					"active_records": _active_window.size(),
					"broken_at": "seal_integrity mismatch seg %d" % seg_id}

		# Verify prev_seal_hash chain.
		if str(seal_dict.get("prev_seal_hash", "")) != prev_seal_hash:
			return {"ok": false, "scope": "full", "segments_verified": segments_verified,
					"active_records": _active_window.size(),
					"broken_at": "prev_seal_hash chain break seg %d" % seg_id}

		# Load records.
		var records := _load_segment_records(seg_path)
		var record_count: int = seal_dict.get("record_count", 0)

		if records.size() != record_count:
			return {"ok": false, "scope": "full", "segments_verified": segments_verified,
					"active_records": _active_window.size(),
					"broken_at": "record_count mismatch seg %d (expected %d got %d)" % [seg_id, record_count, records.size()]}

		if records.size() == 0:
			return {"ok": false, "scope": "full", "segments_verified": segments_verified,
					"active_records": _active_window.size(),
					"broken_at": "empty segment %d" % seg_id}

		var first_r: AuditRecord = records[0]
		var last_r: AuditRecord = records[records.size() - 1]

		if first_r.record_hash != str(seal_dict.get("first_record_hash", "")):
			return {"ok": false, "scope": "full", "segments_verified": segments_verified,
					"active_records": _active_window.size(),
					"broken_at": "first_record_hash mismatch seg %d" % seg_id}

		if last_r.record_hash != str(seal_dict.get("last_record_hash", "")):
			return {"ok": false, "scope": "full", "segments_verified": segments_verified,
					"active_records": _active_window.size(),
					"broken_at": "last_record_hash mismatch seg %d" % seg_id}

		# Verify internal chain.
		var prev_h := first_r.previous_hash
		for rec in records:
			var r: AuditRecord = rec
			if r.previous_hash != prev_h:
				return {"ok": false, "scope": "full", "segments_verified": segments_verified,
						"active_records": _active_window.size(),
						"broken_at": "chain break in seg %d" % seg_id}
			if not r.verify():
				return {"ok": false, "scope": "full", "segments_verified": segments_verified,
						"active_records": _active_window.size(),
						"broken_at": "record verify fail seg %d" % seg_id}
			prev_h = r.record_hash

		prev_seal_hash = _hash_seal(seal_dict)
		segments_verified += 1
		seg_id += 1

	# Verify active window (incremental).
	var active_result := _verify_active()
	if not active_result.get("ok", false):
		return {"ok": false, "scope": "full", "segments_verified": segments_verified,
				"active_records": _active_window.size(),
				"broken_at": active_result.get("broken_at", "active_window")}

	return {
		"ok": true,
		"scope": "full",
		"segments_verified": segments_verified,
		"active_records": _active_window.size(),
		"broken_at": null
	}


func record_count() -> int:
	return _active_window.size()


func last_hash() -> String:
	return _last_hash


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


## Force all pending rotation flushes to disk synchronously.
## Used in tests and shutdown paths.
func flush_rotation() -> void:
	# Drain all pending flushes synchronously.
	while true:
		_flush_mutex.lock()
		if _pending_flushes.is_empty():
			_flush_mutex.unlock()
			break
		var entry: Dictionary = _pending_flushes.pop_front()
		_flush_mutex.unlock()
		_write_flush_entry(entry)


# ── Private helpers ───────────────────────────────────────────────────────────

func _schedule_rotation() -> void:
	# Take an atomic snapshot of the active window under mutex.
	_mutex.lock()
	var records_snapshot := _active_window.duplicate()
	var segment_id := _last_segment_id + 1
	_last_segment_id = segment_id

	# Reset active window (atomic swap).
	_active_window = []
	_by_actor = {}
	_by_event_type = {}
	_last_verified_seq = -1
	_mutex.unlock()

	# Build the seal (synchronous — fast, no I/O).
	# Use in-memory _last_built_seal_hash so we don't race against background disk flush
	# of a prior seal when computing the prev_seal_hash for this seal.
	var first_r: AuditRecord = records_snapshot[0]
	var last_r: AuditRecord = records_snapshot[records_snapshot.size() - 1]
	var seal := _build_seal_in_memory(segment_id, records_snapshot, first_r.record_hash, last_r.record_hash)

	# Update anchor hash for the new active window.
	_last_seal_hash = last_r.record_hash
	# _last_hash stays as last_r.record_hash — chain unbroken.

	# Clear the active file — new window starts empty.
	_clear_active_file()

	# Enqueue flush entry (safe for multiple rapid rotations).
	var entry := {"segment_id": segment_id, "records": records_snapshot, "seal": seal}
	_flush_mutex.lock()
	_pending_flushes.append(entry)
	_flush_mutex.unlock()

	# Dispatch to background thread — each task pops one entry.
	WorkerThreadPool.add_task(Callable(self, "_flush_to_disk_bg"))


func _flush_to_disk_bg() -> void:
	_flush_mutex.lock()
	if _pending_flushes.is_empty():
		_flush_mutex.unlock()
		return
	var entry: Dictionary = _pending_flushes.pop_front()
	_flush_mutex.unlock()
	_write_flush_entry(entry)


func _write_flush_entry(entry: Dictionary) -> void:
	var segment_id: int = entry.get("segment_id", 0)
	var records: Array = entry.get("records", [])
	var seal: Dictionary = entry.get("seal", {})
	_write_segment_jsonl(segment_id, records)
	_write_seal_file(segment_id, seal)


func _write_segment_jsonl(segment_id: int, records: Array) -> void:
	var path := _base_path.path_join("segment_%d.jsonl" % segment_id)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("FilesystemAuditLedger: cannot write segment_%d.jsonl" % segment_id)
		return
	for rec in records:
		if rec is AuditRecord:
			f.store_string(JSON.stringify(rec.to_dict()) + "\n")
	f.close()


func _write_seal_file(segment_id: int, seal: Dictionary) -> void:
	var path := _base_path.path_join("segment_%d.seal" % segment_id)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("FilesystemAuditLedger: cannot write segment_%d.seal" % segment_id)
		return
	f.store_string(JSON.stringify(seal))
	f.close()


func _clear_active_file() -> void:
	# Overwrite with empty file to represent the new empty active window.
	var f := FileAccess.open(_active_file, FileAccess.WRITE)
	if f != null:
		f.close()


func _append_line_to_active(record: AuditRecord) -> void:
	var f: FileAccess
	if FileAccess.file_exists(_active_file):
		f = FileAccess.open(_active_file, FileAccess.READ_WRITE)
		if f != null:
			f.seek_end()
	else:
		f = FileAccess.open(_active_file, FileAccess.WRITE)
	if f == null:
		push_error("FilesystemAuditLedger: cannot write active file")
		return
	f.store_string(JSON.stringify(record.to_dict()) + "\n")
	f.close()


func _load_active_window() -> void:
	_active_window = []
	_by_actor = {}
	_by_event_type = {}
	_last_hash = ""
	_last_verified_seq = -1

	# Discover how many segments exist and load _last_seal_hash.
	var seg_id := 0
	_last_segment_id = -1
	_last_built_seal_hash = ""
	while true:
		var seal_path := _base_path.path_join("segment_%d.seal" % seg_id)
		if not FileAccess.file_exists(seal_path):
			break
		var seal_raw := FileAccess.get_file_as_string(seal_path)
		var seal: Variant = JSON.parse_string(seal_raw)
		if seal is Dictionary:
			_last_seal_hash = str((seal as Dictionary).get("last_record_hash", ""))
			_last_hash = _last_seal_hash
			_last_built_seal_hash = _hash_seal(seal as Dictionary)
		_last_segment_id = seg_id
		seg_id += 1

	if not FileAccess.file_exists(_active_file):
		return

	var f := FileAccess.open(_active_file, FileAccess.READ)
	if f == null:
		return

	var idx := 0
	while not f.eof_reached():
		var line := f.get_line().strip_edges()
		if line.is_empty():
			continue
		var parsed: Variant = JSON.parse_string(line)
		if not (parsed is Dictionary):
			continue
		var record := AuditRecord.from_dict(parsed as Dictionary)

		_active_window.append(record)
		_last_hash = record.record_hash

		var actor := record.actor_id
		if not _by_actor.has(actor):
			_by_actor[actor] = []
		(_by_actor[actor] as Array).append(idx)

		var etype := record.event_type
		if not _by_event_type.has(etype):
			_by_event_type[etype] = []
		(_by_event_type[etype] as Array).append(idx)

		idx += 1
	f.close()


func _load_segment_records(seg_path: String) -> Array:
	var records: Array = []
	if not FileAccess.file_exists(seg_path):
		return records
	var f := FileAccess.open(seg_path, FileAccess.READ)
	if f == null:
		return records
	while not f.eof_reached():
		var line := f.get_line().strip_edges()
		if line.is_empty():
			continue
		var parsed: Variant = JSON.parse_string(line)
		if not (parsed is Dictionary):
			continue
		records.append(AuditRecord.from_dict(parsed as Dictionary))
	f.close()
	return records


## Build seal using in-memory _last_built_seal_hash (avoids disk read race).
func _build_seal_in_memory(
	segment_id: int,
	records: Array,
	first_record_hash: String,
	last_record_hash: String
) -> Dictionary:
	var seal := {
		"segment_id": segment_id,
		"record_count": records.size(),
		"first_record_hash": first_record_hash,
		"last_record_hash": last_record_hash,
		"prev_seal_hash": _last_built_seal_hash,
		"signed_at": "2026-05-18T00:00:00Z",
		"seal_integrity": ""
	}
	seal["seal_integrity"] = _compute_seal_integrity(seal)
	# Update chain anchor for next seal.
	_last_built_seal_hash = _hash_seal(seal)
	return seal


func _compute_seal_integrity(seal: Dictionary) -> String:
	var copy := seal.duplicate()
	copy.erase("seal_integrity")
	var keys := copy.keys()
	keys.sort()
	var parts: Array[String] = []
	for k in keys:
		parts.append("%s=%s" % [str(k), str(copy[k])])
	return "|".join(parts).sha256_text()


func _hash_seal(seal: Dictionary) -> String:
	var keys := seal.keys()
	keys.sort()
	var parts: Array[String] = []
	for k in keys:
		parts.append("%s=%s" % [str(k), str(seal[k])])
	return "|".join(parts).sha256_text()


func _ensure_directory() -> bool:
	if not DirAccess.dir_exists_absolute(_base_path):
		var err := DirAccess.make_dir_recursive_absolute(_base_path)
		if err != OK:
			push_error("FilesystemAuditLedger: failed to create directory: %s" % _base_path)
			return false
	return true
