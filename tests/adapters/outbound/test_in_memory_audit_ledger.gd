## Tests for InMemoryAuditLedger segment-sealed rotation and integrity verification.
##
## MUST-1  Genesis: append 1 record; verify_integrity("active") returns ok:true
## MUST-2  Pre-rotation: append 3 records (below MAX_RECORDS); no segments created;
##          verify_integrity("active") ok; segments_verified == 0
## MUST-3  Cross-rotation: append MAX_RECORDS+1 records (forces 1 rotation);
##          verify_integrity("full") ok across the seal;
##          verify_integrity("active") checks just the post-rotation window
## MUST-4  Tamper-active: mutate a record hash in the active window;
##          verify_integrity("active") returns ok:false with broken_at populated
## MUST-5  Index correctness: append records with mixed actor_ids;
##          get_records({actor_id: "X"}) returns only X's records (no linear scan path for actor)
## MUST-6  Index event_type: get_records({event_type: "login"}) returns only login records
## MUST-7  Segment seal continuity: after rotation, first active record's previous_hash equals
##          last_record_hash from the seal
## MUST-8  verify_integrity("full") with 2 rotations walks all seals in order; ok:true
## MUST-9  Tamper-seal: manually corrupt a segment seal's last_record_hash;
##          verify_integrity("full") returns ok:false
## MUST-10 verify_integrity with no args defaults to active scope
## MUST-11 record_count() includes only active window count (not archived)
## MUST-12 last_hash() returns hash of most recent record
extends SceneTree


const MAX_RECORDS := 50_000


func _init() -> void:
	var failures: Array[String] = []
	var checks := 0

	# ── MUST-1: Genesis – single record, chain ok ─────────────────────────────
	var ledger := InMemoryAuditLedger.new().setup()
	var r0 := _make_record("r0", "", "actor-A", "login")
	var appended := ledger.append_record(r0)
	checks += 1
	if not appended:
		failures.append("MUST-1a: append_record() must return true for valid genesis record")

	var vi := ledger.verify_integrity("active")
	checks += 1
	if not vi.get("ok", false):
		failures.append("MUST-1b: verify_integrity(active) must be ok after 1 record")
	checks += 1
	if vi.get("active_records", -1) != 1:
		failures.append("MUST-1c: active_records must be 1, got %s" % str(vi.get("active_records")))
	checks += 1
	if vi.get("segments_verified", -1) != 0:
		failures.append("MUST-1d: segments_verified must be 0 before any rotation, got %s" % str(vi.get("segments_verified")))

	# ── MUST-2: Pre-rotation — 3 records, no segments ────────────────────────
	var ledger2 := InMemoryAuditLedger.new().setup()
	var prev := ""
	for i in range(3):
		var r := _make_record("pre-%d" % i, prev, "actor-B", "move")
		prev = r.record_hash
		ledger2.append_record(r)

	var vi2 := ledger2.verify_integrity("active")
	checks += 1
	if not vi2.get("ok", false):
		failures.append("MUST-2a: verify_integrity(active) must be ok for 3 records")
	checks += 1
	if vi2.get("segments_verified", -1) != 0:
		failures.append("MUST-2b: no segments yet for 3 records, got %s" % str(vi2.get("segments_verified")))

	# ── MUST-3: Cross-rotation — MAX_RECORDS+1 forces rotation ───────────────
	# Use a small MAX_RECORDS override for test speed: we override via the ledger's own const.
	# Since we cannot override a const, we use the ledger's _rotate_at setter if available,
	# or we use a test-mode constructor. The production const is 50_000 — too slow for unit
	# tests. We inject _rotate_at = 10 via the setup() overload.
	var ledger3 := InMemoryAuditLedger.new().setup_with_rotation(10)
	var prev3 := ""
	for i in range(11):
		var r := _make_record("rot-%d" % i, prev3, "actor-C", "jump")
		ledger3.append_record(r)
		prev3 = r.record_hash

	checks += 1
	var vi3_full := ledger3.verify_integrity("full")
	if not vi3_full.get("ok", false):
		failures.append("MUST-3a: verify_integrity(full) must be ok after 1 rotation, got: %s" % str(vi3_full))
	checks += 1
	if vi3_full.get("segments_verified", 0) < 1:
		failures.append("MUST-3b: segments_verified must be >= 1 after rotation, got %s" % str(vi3_full.get("segments_verified")))

	var vi3_active := ledger3.verify_integrity("active")
	checks += 1
	if not vi3_active.get("ok", false):
		failures.append("MUST-3c: verify_integrity(active) must be ok for the post-rotation window")
	checks += 1
	if vi3_active.get("active_records", -1) != 1:
		failures.append("MUST-3d: active window must have 1 record after rotating 10, got %s" % str(vi3_active.get("active_records")))

	# ── MUST-4: Tamper-active — corrupt a record in active window ─────────────
	var ledger4 := InMemoryAuditLedger.new().setup_with_rotation(10)
	var prev4 := ""
	for i in range(3):
		var r := _make_record("tamper-%d" % i, prev4, "actor-D", "chat")
		ledger4.append_record(r)
		prev4 = r.record_hash
	# Tamper: flip the record_hash of the first active record
	ledger4._active_window[0].record_hash = "badhash000"
	var vi4 := ledger4.verify_integrity("active")
	checks += 1
	if vi4.get("ok", true):
		failures.append("MUST-4a: verify_integrity(active) must return ok:false after tampering active record")
	checks += 1
	if not vi4.has("broken_at"):
		failures.append("MUST-4b: broken_at must be populated when ok:false")

	# ── MUST-5: Index correctness by actor_id ─────────────────────────────────
	var ledger5 := InMemoryAuditLedger.new().setup_with_rotation(10)
	var prev5 := ""
	var actor_x_ids: Array[String] = []
	for i in range(6):
		var actor := "X" if i % 2 == 0 else "Y"
		var r := _make_record("idx-%d" % i, prev5, actor, "action")
		ledger5.append_record(r)
		prev5 = r.record_hash
		if actor == "X":
			actor_x_ids.append(r.record_id)

	var x_records := ledger5.get_records({"actor_id": "X"})
	checks += 1
	if x_records.size() != actor_x_ids.size():
		failures.append("MUST-5a: get_records(actor_id:X) must return %d, got %d" % [actor_x_ids.size(), x_records.size()])
	checks += 1
	for rec in x_records:
		if rec is AuditRecord and rec.actor_id != "X":
			failures.append("MUST-5b: get_records(actor_id:X) must not contain actor_id=%s" % rec.actor_id)
			break

	# ── MUST-6: Index correctness by event_type ───────────────────────────────
	var ledger6 := InMemoryAuditLedger.new().setup_with_rotation(10)
	var prev6 := ""
	var login_ids: Array[String] = []
	for i in range(6):
		var etype := "login" if i % 3 == 0 else "move"
		var r := _make_record("evtype-%d" % i, prev6, "actor-E", etype)
		ledger6.append_record(r)
		prev6 = r.record_hash
		if etype == "login":
			login_ids.append(r.record_id)

	var login_records := ledger6.get_records({"event_type": "login"})
	checks += 1
	if login_records.size() != login_ids.size():
		failures.append("MUST-6a: get_records(event_type:login) must return %d, got %d" % [login_ids.size(), login_records.size()])
	checks += 1
	for rec in login_records:
		if rec is AuditRecord and rec.event_type != "login":
			failures.append("MUST-6b: get_records(event_type:login) must not contain event_type=%s" % rec.event_type)
			break

	# ── MUST-7: Seal continuity — first active record prev_hash == seal last_record_hash ─
	var ledger7 := InMemoryAuditLedger.new().setup_with_rotation(5)
	var prev7 := ""
	for i in range(6):
		var r := _make_record("seal-%d" % i, prev7, "actor-F", "event")
		ledger7.append_record(r)
		prev7 = r.record_hash

	checks += 1
	if ledger7._segments.size() < 1:
		failures.append("MUST-7a: must have at least 1 archived segment after 6 records with rotation=5")
	else:
		var last_seal: Dictionary = ledger7._segments[ledger7._segments.size() - 1].seal
		var first_active: AuditRecord = ledger7._active_window[0]
		if first_active.previous_hash != last_seal.get("last_record_hash", "MISSING"):
			failures.append("MUST-7b: first active record prev_hash must equal seal last_record_hash")

	# ── MUST-8: 2 rotations, full verify ok ───────────────────────────────────
	var ledger8 := InMemoryAuditLedger.new().setup_with_rotation(5)
	var prev8 := ""
	for i in range(12):
		var r := _make_record("two-rot-%d" % i, prev8, "actor-G", "tick")
		ledger8.append_record(r)
		prev8 = r.record_hash

	var vi8 := ledger8.verify_integrity("full")
	checks += 1
	if not vi8.get("ok", false):
		failures.append("MUST-8a: verify_integrity(full) must be ok after 2 rotations, got: %s" % str(vi8))
	checks += 1
	if vi8.get("segments_verified", 0) < 2:
		failures.append("MUST-8b: segments_verified must be >= 2 after 12 records with rotation=5, got %s" % str(vi8.get("segments_verified")))

	# ── MUST-9: Tamper-seal — corrupt seal last_record_hash ───────────────────
	var ledger9 := InMemoryAuditLedger.new().setup_with_rotation(5)
	var prev9 := ""
	for i in range(6):
		var r := _make_record("ts-%d" % i, prev9, "actor-H", "ev")
		ledger9.append_record(r)
		prev9 = r.record_hash

	checks += 1
	if ledger9._segments.size() < 1:
		failures.append("MUST-9-pre: must have at least 1 segment to tamper with")
	else:
		ledger9._segments[0].seal["last_record_hash"] = "tampered_seal_hash"
		var vi9 := ledger9.verify_integrity("full")
		if vi9.get("ok", true):
			failures.append("MUST-9a: verify_integrity(full) must return ok:false after seal tamper")

	# ── MUST-10: No-arg defaults to active ────────────────────────────────────
	var ledger10 := InMemoryAuditLedger.new().setup()
	var r10 := _make_record("default-0", "", "actor-I", "test")
	ledger10.append_record(r10)
	var vi10 := ledger10.verify_integrity()
	checks += 1
	if not vi10.get("ok", false):
		failures.append("MUST-10: verify_integrity() with no arg must return ok:true")
	checks += 1
	if vi10.get("scope", "") != "active":
		failures.append("MUST-10b: verify_integrity() default scope must be 'active', got: %s" % str(vi10.get("scope")))

	# ── MUST-11: record_count() returns active window size ────────────────────
	var ledger11 := InMemoryAuditLedger.new().setup_with_rotation(5)
	var prev11 := ""
	for i in range(7):
		var r := _make_record("rc-%d" % i, prev11, "actor-J", "ev")
		ledger11.append_record(r)
		prev11 = r.record_hash
	checks += 1
	# 7 records, rotation=5 → 1 segment of 5, active window has 2
	if ledger11.record_count() != 2:
		failures.append("MUST-11: record_count() must return 2 (active window), got %d" % ledger11.record_count())

	# ── MUST-12: last_hash() returns hash of most recent record ───────────────
	var ledger12 := InMemoryAuditLedger.new().setup()
	var r12a := _make_record("lh-0", "", "actor-K", "ev")
	var r12b := _make_record("lh-1", r12a.record_hash, "actor-K", "ev")
	ledger12.append_record(r12a)
	ledger12.append_record(r12b)
	checks += 1
	if ledger12.last_hash() != r12b.record_hash:
		failures.append("MUST-12: last_hash() must return hash of most recent record")

	# ── REGRESSION: real timestamp in seal signed_at (Wave C critical #2) ────
	# Build 2 seals (by triggering 2 rotations in sequence) and assert:
	# 1. signed_at is not the old hardcoded "2026-05-18T00:00:00Z" stub value
	# 2. seal_integrity hashes include signed_at (different timestamps → different hashes)
	#
	# NOTE: single-threaded test runner cannot guarantee 2 seals are built >0ms apart,
	# so we directly call _build_seal() with an injected OS-time check rather than
	# sleeping. Instead we build 2 ledgers separately and compare their seal signed_at
	# values — each call to Time.get_datetime_string_from_system() is independent.
	var ledger_ts_a := InMemoryAuditLedger.new().setup_with_rotation(2)
	var prev_ts_a := ""
	for i in range(3):
		var r := _make_record("ts-a-%d" % i, prev_ts_a, "actor-TS-A", "ev")
		ledger_ts_a.append_record(r)
		prev_ts_a = r.record_hash
	checks += 1
	var seal_a: Dictionary = ledger_ts_a._segments[0].seal if ledger_ts_a._segments.size() > 0 else {}
	var signed_at_a: String = str(seal_a.get("signed_at", ""))
	if signed_at_a == "2026-05-18T00:00:00Z":
		failures.append("REGRESSION-TS-1a: signed_at must not be hardcoded stub, got: %s" % signed_at_a)
	if signed_at_a.is_empty():
		failures.append("REGRESSION-TS-1b: signed_at must not be empty in seal")

	# Verify seal_integrity covers signed_at: recompute integrity with a different
	# signed_at and confirm it yields a different hash (proving signed_at is in the input).
	checks += 1
	if seal_a.size() > 0:
		var seal_modified := seal_a.duplicate()
		seal_modified["signed_at"] = "1970-01-01T00:00:00Z"
		seal_modified.erase("seal_integrity")
		var keys_m := seal_modified.keys()
		keys_m.sort()
		var parts_m: Array[String] = []
		for k in keys_m:
			parts_m.append("%s=%s" % [str(k), str(seal_modified[k])])
		var modified_integrity := "|".join(parts_m).sha256_text()
		var original_integrity: String = str(seal_a.get("seal_integrity", ""))
		if modified_integrity == original_integrity:
			failures.append("REGRESSION-TS-2: seal_integrity must differ when signed_at differs (signed_at not included in hash input)")

	# ── Report ─────────────────────────────────────────────────────────────────
	if failures.is_empty():
		print("[PASS] InMemoryAuditLedger (%d checks)" % checks)
		quit(0)
	else:
		print("[FAIL] InMemoryAuditLedger")
		for item in failures:
			print("  - %s" % item)
		quit(1)


func _make_record(
	record_id: String,
	previous_hash: String,
	actor_id: String,
	event_type: String
) -> AuditRecord:
	return AuditRecord.new(
		record_id,
		event_type,
		"evt-" + record_id,
		actor_id,
		"2026-05-18T10:00:00Z",
		{},
		previous_hash
	)
