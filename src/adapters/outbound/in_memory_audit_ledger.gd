## In-memory adapter for AuditLedgerPort.
## Maintains an append-only array with hash chain verification.
## Supports segment-sealed rotation (MAX_RECORDS cap) to prevent unbounded growth.
## Archives live in-memory (Array of segment dicts); no thread pool needed
## because no disk I/O, but the same atomic-swap pattern is used.
##
## Segment seal schema:
##   {
##     segment_id: int,
##     record_count: int,
##     first_record_hash: String,
##     last_record_hash: String,
##     prev_seal_hash: String,   # "" for genesis seal
##     signed_at: String,        # ISO 8601 timestamp
##     seal_integrity: String    # SHA-256 of the seal content (sans this field)
##   }
##
## verify_integrity(scope) signature:
##   Returns { ok: bool, scope: String, segments_verified: int,
##             active_records: int, broken_at: Variant }
class_name InMemoryAuditLedger
extends AuditLedgerPort

## Production cap. Overridden in tests via setup_with_rotation().
const MAX_RECORDS := 50_000

## Active window of AuditRecord objects.
var _active_window: Array = []

## Last hash in the active window (or from latest seal on fresh active window).
var _last_hash: String = ""

## Archived segments. Each entry is a Dictionary:
##   { segment_id: int, records: Array[AuditRecord], seal: Dictionary }
var _segments: Array = []

## Active-window indexes for fast lookup.
var _by_actor: Dictionary = {}       # actor_id -> Array of indices into _active_window
var _by_event_type: Dictionary = {}  # event_type -> Array of indices into _active_window

## Rotation threshold (defaults to MAX_RECORDS; overridable for tests).
var _rotate_at: int = MAX_RECORDS

## Incremental verification cache.
var _last_verified_seq: int = -1

## Hash of the most recent seal (or "" if no seals yet).
var _last_seal_hash: String = ""


func setup() -> InMemoryAuditLedger:
	_active_window = []
	_last_hash = ""
	_segments = []
	_by_actor = {}
	_by_event_type = {}
	_rotate_at = MAX_RECORDS
	_last_verified_seq = -1
	_last_seal_hash = ""
	return self


## Test-mode constructor: accepts custom rotation threshold.
func setup_with_rotation(rotate_at: int) -> InMemoryAuditLedger:
	setup()
	_rotate_at = rotate_at
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

	var idx := _active_window.size()
	_active_window.append(record)
	_last_hash = record.record_hash

	# Update indexes
	var actor := record.actor_id
	if not _by_actor.has(actor):
		_by_actor[actor] = []
	(_by_actor[actor] as Array).append(idx)

	var etype := record.event_type
	if not _by_event_type.has(etype):
		_by_event_type[etype] = []
	(_by_event_type[etype] as Array).append(idx)

	# Rotate if active window has reached the cap.
	if _active_window.size() >= _rotate_at:
		_rotate()

	return true


func get_records(filter: Dictionary = {}) -> Array:
	var actor_filter := str(filter.get("actor_id", "")).strip_edges()
	var type_filter := str(filter.get("event_type", "")).strip_edges()
	var from_iso := str(filter.get("from_iso", "")).strip_edges()
	var to_iso := str(filter.get("to_iso", "")).strip_edges()
	var limit_val: int = filter.get("limit", 100) as int if filter.get("limit") is int else 100

	var result: Array = []

	# Fast path for actor_id filter using index.
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

	# Fast path for event_type filter using index.
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

	# Linear scan for date-range or combined filters.
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
## scope: "active" (default) or "full"
## Incremental: on "active" only re-verifies from _last_verified_seq+1 onward.
## Cache is invalidated on rotation.
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

	# Determine starting hash: either the last seal's last_record_hash or "".
	var starting_hash := _last_seal_hash

	# Incremental: start from where we left off unless chain anchor changed.
	var start_idx := 0
	if _last_verified_seq >= 0 and _last_verified_seq < total:
		# Re-verify only from _last_verified_seq onward (it may have been tampered).
		start_idx = _last_verified_seq
		# Compute what prev_hash should be at start_idx.
		if start_idx == 0:
			starting_hash = _last_seal_hash
		else:
			var prev_rec: AuditRecord = _active_window[start_idx - 1]
			starting_hash = prev_rec.record_hash

	var prev_hash := starting_hash
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

	# Walk archived segments in order.
	for seg_entry in _segments:
		var seg_id: int = seg_entry.get("segment_id", -1)
		var records: Array = seg_entry.get("records", [])
		var seal: Dictionary = seg_entry.get("seal", {})

		# Verify seal integrity field.
		var stored_integrity: String = str(seal.get("seal_integrity", ""))
		var expected_integrity := _compute_seal_integrity(seal)
		if stored_integrity != expected_integrity:
			return {"ok": false, "scope": "full", "segments_verified": segments_verified,
					"active_records": _active_window.size(),
					"broken_at": "seal_integrity seg %d" % seg_id}

		# Verify prev_seal_hash chain.
		if str(seal.get("prev_seal_hash", "")) != prev_seal_hash:
			return {"ok": false, "scope": "full", "segments_verified": segments_verified,
					"active_records": _active_window.size(),
					"broken_at": "prev_seal_hash seg %d" % seg_id}

		# Verify records in segment.
		var seg_first_hash: String = str(seal.get("first_record_hash", ""))
		var seg_last_hash: String = str(seal.get("last_record_hash", ""))
		var record_count: int = seal.get("record_count", 0)

		if records.size() != record_count:
			return {"ok": false, "scope": "full", "segments_verified": segments_verified,
					"active_records": _active_window.size(),
					"broken_at": "record_count mismatch seg %d" % seg_id}

		if records.size() == 0:
			return {"ok": false, "scope": "full", "segments_verified": segments_verified,
					"active_records": _active_window.size(),
					"broken_at": "empty segment %d" % seg_id}

		var first_r: AuditRecord = records[0]
		if first_r.record_hash != seg_first_hash:
			return {"ok": false, "scope": "full", "segments_verified": segments_verified,
					"active_records": _active_window.size(),
					"broken_at": "first_record_hash seg %d" % seg_id}

		var last_r: AuditRecord = records[records.size() - 1]
		if last_r.record_hash != seg_last_hash:
			return {"ok": false, "scope": "full", "segments_verified": segments_verified,
					"active_records": _active_window.size(),
					"broken_at": "last_record_hash seg %d" % seg_id}

		# Verify internal hash chain of segment.
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

		prev_seal_hash = _hash_seal(seal)
		segments_verified += 1

	# Now verify active window.
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


# ── Private helpers ───────────────────────────────────────────────────────────

func _rotate() -> void:
	var segment_id := _segments.size()
	var records_snapshot := _active_window.duplicate()

	var first_r: AuditRecord = records_snapshot[0]
	var last_r: AuditRecord = records_snapshot[records_snapshot.size() - 1]

	var seal := _build_seal(segment_id, records_snapshot, first_r.record_hash, last_r.record_hash)

	_segments.append({
		"segment_id": segment_id,
		"records": records_snapshot,
		"seal": seal
	})

	# Atomic swap: new empty active window.
	_active_window = []
	_by_actor = {}
	_by_event_type = {}

	# Active window anchor: first new record's prev_hash must equal last seal's last_record_hash.
	_last_seal_hash = last_r.record_hash
	# _last_hash already equals last_r.record_hash (unchanged — chain continues).

	# Invalidate incremental cache.
	_last_verified_seq = -1


func _build_seal(
	segment_id: int,
	records: Array,
	first_record_hash: String,
	last_record_hash: String
) -> Dictionary:
	var prev_seal_hash := ""
	if _segments.size() > 0:
		var prev_seg: Dictionary = _segments[_segments.size() - 1]
		prev_seal_hash = _hash_seal(prev_seg.get("seal", {}))

	var seal := {
		"segment_id": segment_id,
		"record_count": records.size(),
		"first_record_hash": first_record_hash,
		"last_record_hash": last_record_hash,
		"prev_seal_hash": prev_seal_hash,
		"signed_at": "2026-05-18T00:00:00Z",  # No ClockPort injected in-memory; use fixed stamp.
		"seal_integrity": ""  # Computed below.
	}
	seal["seal_integrity"] = _compute_seal_integrity(seal)
	return seal


## Compute SHA-256 of the seal dict (excluding the seal_integrity field itself).
func _compute_seal_integrity(seal: Dictionary) -> String:
	var copy := seal.duplicate()
	copy.erase("seal_integrity")
	# Sort keys for deterministic serialization.
	var keys := copy.keys()
	keys.sort()
	var parts: Array[String] = []
	for k in keys:
		parts.append("%s=%s" % [str(k), str(copy[k])])
	return "|".join(parts).sha256_text()


## Hash a complete seal dict (including seal_integrity) for chaining.
func _hash_seal(seal: Dictionary) -> String:
	var keys := seal.keys()
	keys.sort()
	var parts: Array[String] = []
	for k in keys:
		parts.append("%s=%s" % [str(k), str(seal[k])])
	return "|".join(parts).sha256_text()
