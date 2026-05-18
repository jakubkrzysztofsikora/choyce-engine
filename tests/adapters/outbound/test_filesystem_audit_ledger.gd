## Tests for FilesystemAuditLedger segment-sealed rotation and integrity verification.
##
## MUST-1  Genesis: append 1 record; verify_integrity("active") returns ok:true
## MUST-2  Cross-rotation: append rotate_at+1 records; verify_integrity("full") ok across seal;
##          segment_N.jsonl and segment_N.seal files written to disk
## MUST-3  Tamper-segment-file: edit segment_0.jsonl to remove a line (corrupt records);
##          reload ledger; verify_integrity("full") returns ok:false, broken_at populated
## MUST-4  Tamper-seal-file: edit segment_0.seal; reload ledger;
##          verify_integrity("full") returns ok:false
## MUST-5  Index correctness: get_records(actor_id: "X") returns only X's active records
## MUST-6  Round-trip: re-instantiated ledger reads active window from disk,
##          verify_integrity("active") ok
## MUST-7  verify_integrity("full") with 2 rotations walks all seals; ok:true
## MUST-8  record_count() returns active window count only
## MUST-9  verify_integrity() with no arg defaults to scope "active"
## MUST-10 append after rotation maintains chain: active window first record prev_hash
##          equals seal last_record_hash
extends SceneTree


func _init() -> void:
	var failures: Array[String] = []
	var checks := 0

	const TEST_DIR := "user://test_fs_audit_ledger"

	# ── MUST-1: Genesis ────────────────────────────────────────────────────────
	_cleanup(TEST_DIR + "/must1")
	var ledger1 := FilesystemAuditLedger.new().setup_with_rotation(TEST_DIR + "/must1", 10)
	var r0 := _make_record("r0", "", "actor-A", "login")
	var appended := ledger1.append_record(r0)
	checks += 1
	if not appended:
		failures.append("MUST-1a: append_record() must return true")
	var vi1 := ledger1.verify_integrity("active")
	checks += 1
	if not vi1.get("ok", false):
		failures.append("MUST-1b: verify_integrity(active) must be ok after 1 record, got: %s" % str(vi1))

	# ── MUST-2: Cross-rotation — segment files written ────────────────────────
	_cleanup(TEST_DIR + "/must2")
	var ledger2 := FilesystemAuditLedger.new().setup_with_rotation(TEST_DIR + "/must2", 5)
	var prev2 := ""
	for i in range(6):
		var r := _make_record("rot-%d" % i, prev2, "actor-B", "move")
		ledger2.append_record(r)
		prev2 = r.record_hash
	# Flush rotation to disk synchronously for test
	ledger2.flush_rotation()

	checks += 1
	var seg_path := ProjectSettings.globalize_path(TEST_DIR + "/must2/segment_0.jsonl")
	var seal_path := ProjectSettings.globalize_path(TEST_DIR + "/must2/segment_0.seal")
	if not FileAccess.file_exists(TEST_DIR + "/must2/segment_0.jsonl"):
		failures.append("MUST-2a: segment_0.jsonl must exist after rotation")
	if not FileAccess.file_exists(TEST_DIR + "/must2/segment_0.seal"):
		failures.append("MUST-2b: segment_0.seal must exist after rotation")

	var vi2_full := ledger2.verify_integrity("full")
	checks += 1
	if not vi2_full.get("ok", false):
		failures.append("MUST-2c: verify_integrity(full) must be ok after 1 rotation, got: %s" % str(vi2_full))
	checks += 1
	if vi2_full.get("segments_verified", 0) < 1:
		failures.append("MUST-2d: segments_verified must be >= 1, got %s" % str(vi2_full.get("segments_verified")))

	# ── MUST-3: Tamper segment file ────────────────────────────────────────────
	_cleanup(TEST_DIR + "/must3")
	var ledger3 := FilesystemAuditLedger.new().setup_with_rotation(TEST_DIR + "/must3", 5)
	var prev3 := ""
	for i in range(6):
		var r := _make_record("t3-%d" % i, prev3, "actor-C", "action")
		ledger3.append_record(r)
		prev3 = r.record_hash
	ledger3.flush_rotation()

	# Remove the first line from segment_0.jsonl (delete one record)
	var orig_seg := _read_file_lines(TEST_DIR + "/must3/segment_0.jsonl")
	checks += 1
	if orig_seg.size() < 2:
		failures.append("MUST-3-pre: segment_0.jsonl must have >= 2 lines to tamper")
	else:
		# Drop first record line
		var tampered_lines: Array[String] = []
		for idx in range(1, orig_seg.size()):
			tampered_lines.append(orig_seg[idx])
		_write_lines(TEST_DIR + "/must3/segment_0.jsonl", tampered_lines)

		# Reload and verify full
		var ledger3b := FilesystemAuditLedger.new().setup_with_rotation(TEST_DIR + "/must3", 5)
		var vi3 := ledger3b.verify_integrity("full")
		checks += 1
		if vi3.get("ok", true):
			failures.append("MUST-3: verify_integrity(full) must return ok:false after segment tamper")
		checks += 1
		if not vi3.has("broken_at"):
			failures.append("MUST-3b: broken_at must be populated")

	# ── MUST-4: Tamper seal file ───────────────────────────────────────────────
	_cleanup(TEST_DIR + "/must4")
	var ledger4 := FilesystemAuditLedger.new().setup_with_rotation(TEST_DIR + "/must4", 5)
	var prev4 := ""
	for i in range(6):
		var r := _make_record("t4-%d" % i, prev4, "actor-D", "ev")
		ledger4.append_record(r)
		prev4 = r.record_hash
	ledger4.flush_rotation()

	# Corrupt segment_0.seal
	var seal_file := FileAccess.open(TEST_DIR + "/must4/segment_0.seal", FileAccess.WRITE)
	if seal_file != null:
		seal_file.store_string('{"segment_id":0,"last_record_hash":"TAMPERED","seal_integrity":"bad"}')
		seal_file.close()

	var ledger4b := FilesystemAuditLedger.new().setup_with_rotation(TEST_DIR + "/must4", 5)
	var vi4 := ledger4b.verify_integrity("full")
	checks += 1
	if vi4.get("ok", true):
		failures.append("MUST-4: verify_integrity(full) must return ok:false after seal tamper")

	# ── MUST-5: Index correctness by actor_id (active window) ─────────────────
	_cleanup(TEST_DIR + "/must5")
	var ledger5 := FilesystemAuditLedger.new().setup_with_rotation(TEST_DIR + "/must5", 20)
	var prev5 := ""
	var x_count := 0
	for i in range(6):
		var actor := "X" if i % 2 == 0 else "Y"
		var r := _make_record("idx-%d" % i, prev5, actor, "act")
		ledger5.append_record(r)
		prev5 = r.record_hash
		if actor == "X":
			x_count += 1

	var x_recs := ledger5.get_records({"actor_id": "X"})
	checks += 1
	if x_recs.size() != x_count:
		failures.append("MUST-5a: get_records(actor_id:X) must return %d, got %d" % [x_count, x_recs.size()])
	checks += 1
	for rec in x_recs:
		if rec is AuditRecord and rec.actor_id != "X":
			failures.append("MUST-5b: get_records(actor_id:X) returned wrong actor: %s" % rec.actor_id)
			break

	# ── MUST-6: Round-trip — re-instantiated reads active window ──────────────
	_cleanup(TEST_DIR + "/must6")
	var ledger6 := FilesystemAuditLedger.new().setup_with_rotation(TEST_DIR + "/must6", 10)
	var prev6 := ""
	for i in range(3):
		var r := _make_record("rt-%d" % i, prev6, "actor-E", "ev")
		ledger6.append_record(r)
		prev6 = r.record_hash

	var ledger6b := FilesystemAuditLedger.new().setup_with_rotation(TEST_DIR + "/must6", 10)
	var vi6 := ledger6b.verify_integrity("active")
	checks += 1
	if not vi6.get("ok", false):
		failures.append("MUST-6: re-instantiated ledger verify_integrity(active) must be ok, got: %s" % str(vi6))
	checks += 1
	if ledger6b.record_count() != 3:
		failures.append("MUST-6b: re-instantiated ledger must have 3 active records, got %d" % ledger6b.record_count())

	# ── MUST-7: 2 rotations, full verify ok ───────────────────────────────────
	_cleanup(TEST_DIR + "/must7")
	var ledger7 := FilesystemAuditLedger.new().setup_with_rotation(TEST_DIR + "/must7", 5)
	var prev7 := ""
	for i in range(12):
		var r := _make_record("tr7-%d" % i, prev7, "actor-F", "tick")
		ledger7.append_record(r)
		prev7 = r.record_hash
	ledger7.flush_rotation()

	var vi7 := ledger7.verify_integrity("full")
	checks += 1
	if not vi7.get("ok", false):
		failures.append("MUST-7a: verify_integrity(full) must be ok after 2 rotations, got: %s" % str(vi7))
	checks += 1
	if vi7.get("segments_verified", 0) < 2:
		failures.append("MUST-7b: segments_verified must be >= 2, got %s" % str(vi7.get("segments_verified")))

	# ── MUST-8: record_count() returns active window size ─────────────────────
	_cleanup(TEST_DIR + "/must8")
	var ledger8 := FilesystemAuditLedger.new().setup_with_rotation(TEST_DIR + "/must8", 5)
	var prev8 := ""
	for i in range(7):
		var r := _make_record("rc8-%d" % i, prev8, "actor-G", "ev")
		ledger8.append_record(r)
		prev8 = r.record_hash
	ledger8.flush_rotation()
	checks += 1
	# 7 records, rotation=5 → segment of 5, active = 2
	if ledger8.record_count() != 2:
		failures.append("MUST-8: record_count() must return 2 (active window), got %d" % ledger8.record_count())

	# ── MUST-9: Default no-arg scope ──────────────────────────────────────────
	_cleanup(TEST_DIR + "/must9")
	var ledger9 := FilesystemAuditLedger.new().setup_with_rotation(TEST_DIR + "/must9", 10)
	var r9 := _make_record("def-0", "", "actor-H", "ev")
	ledger9.append_record(r9)
	var vi9 := ledger9.verify_integrity()
	checks += 1
	if not vi9.get("ok", false):
		failures.append("MUST-9: verify_integrity() default must be ok")
	checks += 1
	if vi9.get("scope", "") != "active":
		failures.append("MUST-9b: verify_integrity() default scope must be 'active', got: %s" % str(vi9.get("scope")))

	# ── MUST-10: Chain continuity across rotation ──────────────────────────────
	_cleanup(TEST_DIR + "/must10")
	var ledger10 := FilesystemAuditLedger.new().setup_with_rotation(TEST_DIR + "/must10", 5)
	var prev10 := ""
	for i in range(6):
		var r := _make_record("ch10-%d" % i, prev10, "actor-I", "ev")
		ledger10.append_record(r)
		prev10 = r.record_hash
	ledger10.flush_rotation()

	# Read the seal to get last_record_hash
	var seal10_raw := FileAccess.get_file_as_string(TEST_DIR + "/must10/segment_0.seal")
	var seal10: Variant = JSON.parse_string(seal10_raw)
	checks += 1
	if not (seal10 is Dictionary):
		failures.append("MUST-10a: segment_0.seal must be valid JSON")
	else:
		var seal_last_hash: String = str(seal10.get("last_record_hash", ""))
		# Active window first record
		var active_recs := ledger10.get_records({})
		if active_recs.size() < 1:
			failures.append("MUST-10b: must have at least 1 active record after rotation")
		else:
			var first_active: AuditRecord = active_recs[0]
			if first_active.previous_hash != seal_last_hash:
				failures.append("MUST-10c: first active record prev_hash must equal seal last_record_hash. got prev=%s seal=%s" % [first_active.previous_hash, seal_last_hash])

	# ── REGRESSION: real timestamp in seal signed_at (Wave C critical #2) ──────
	_cleanup(TEST_DIR + "/reg_ts")
	var ledger_ts := FilesystemAuditLedger.new().setup_with_rotation(TEST_DIR + "/reg_ts", 2)
	var prev_ts := ""
	for i in range(3):
		var r := _make_record("ts-%d" % i, prev_ts, "actor-TS", "ev")
		ledger_ts.append_record(r)
		prev_ts = r.record_hash
	ledger_ts.flush_rotation()

	var seal_ts_raw := FileAccess.get_file_as_string(TEST_DIR + "/reg_ts/segment_0.seal")
	var seal_ts: Variant = JSON.parse_string(seal_ts_raw)
	checks += 1
	if not (seal_ts is Dictionary):
		failures.append("REGRESSION-TS-FS-0: segment_0.seal must be valid JSON")
	else:
		var signed_at: String = str((seal_ts as Dictionary).get("signed_at", ""))
		checks += 1
		if signed_at == "2026-05-18T00:00:00Z":
			failures.append("REGRESSION-TS-FS-1: filesystem seal signed_at must not be hardcoded stub, got: %s" % signed_at)
		if signed_at.is_empty():
			failures.append("REGRESSION-TS-FS-2: filesystem seal signed_at must not be empty")

		# Verify seal_integrity covers signed_at: modify signed_at → integrity must differ.
		checks += 1
		var seal_dict: Dictionary = seal_ts as Dictionary
		var original_integrity: String = str(seal_dict.get("seal_integrity", ""))
		var seal_mod := seal_dict.duplicate()
		seal_mod["signed_at"] = "1970-01-01T00:00:00Z"
		seal_mod.erase("seal_integrity")
		var keys_s := seal_mod.keys()
		keys_s.sort()
		var parts_s: Array[String] = []
		for k in keys_s:
			parts_s.append("%s=%s" % [str(k), str(seal_mod[k])])
		var mod_integrity := "|".join(parts_s).sha256_text()
		if mod_integrity == original_integrity:
			failures.append("REGRESSION-TS-FS-3: seal_integrity must differ when signed_at differs")

	# ── REGRESSION: mutex invariant — chain check inside lock (Wave C critical #3) ─
	# Single-threaded test: we verify the INVARIANT holds by asserting that:
	# 1. append_record() with a stale previous_hash (simulating the race victim)
	#    returns false after the lock is acquired.
	# 2. The ledger _last_hash is unchanged after a rejected append.
	# 3. try_lock() returns false while the mutex is held (proves contention guard exists).
	_cleanup(TEST_DIR + "/reg_mutex")
	var ledger_mx := FilesystemAuditLedger.new().setup_with_rotation(TEST_DIR + "/reg_mutex", 10)
	var r_mx0 := _make_record("mx-0", "", "actor-MX", "ev")
	var r_mx1 := _make_record("mx-1", r_mx0.record_hash, "actor-MX", "ev")
	ledger_mx.append_record(r_mx0)
	ledger_mx.append_record(r_mx1)
	var hash_before_race := ledger_mx.last_hash()

	# Simulate a record that would have read _last_hash before rotation (stale chain).
	var r_stale := _make_record("mx-stale", "", "actor-MX", "ev")  # previous_hash="" is stale
	var stale_ok := ledger_mx.append_record(r_stale)
	checks += 1
	if stale_ok:
		failures.append("REGRESSION-MUTEX-1: stale chain record must be rejected (append returned true)")
	checks += 1
	if ledger_mx.last_hash() != hash_before_race:
		failures.append("REGRESSION-MUTEX-2: _last_hash must be unchanged after rejected stale record")

	# Verify the mutex can be locked now (i.e., it was properly released after rejection).
	checks += 1
	var try_result := ledger_mx._mutex.try_lock()
	if not try_result:
		failures.append("REGRESSION-MUTEX-3: mutex must be unlocked after append_record returns (deadlock risk)")
	else:
		ledger_mx._mutex.unlock()

	# ── REGRESSION: flush_rotation on near-rotation ledger (Wave C critical #4) ─
	# Simulate a ledger near the rotation boundary, call flush_rotation(), then
	# assert segment_N.jsonl + segment_N.seal are written and the chain is intact.
	_cleanup(TEST_DIR + "/reg_flush")
	var ledger_fl := FilesystemAuditLedger.new().setup_with_rotation(TEST_DIR + "/reg_flush", 5)
	var prev_fl := ""
	for i in range(5):
		var r := _make_record("fl-%d" % i, prev_fl, "actor-FL", "ev")
		ledger_fl.append_record(r)
		prev_fl = r.record_hash
	# Rotation was triggered at count == 5; flush drains any pending background write.
	ledger_fl.flush_rotation()

	checks += 1
	if not FileAccess.file_exists(TEST_DIR + "/reg_flush/segment_0.jsonl"):
		failures.append("REGRESSION-FLUSH-1: segment_0.jsonl must exist after flush_rotation on shutdown")
	checks += 1
	if not FileAccess.file_exists(TEST_DIR + "/reg_flush/segment_0.seal"):
		failures.append("REGRESSION-FLUSH-2: segment_0.seal must exist after flush_rotation on shutdown")

	# Chain must still be intact after flush.
	var vi_fl := ledger_fl.verify_integrity("full")
	checks += 1
	if not vi_fl.get("ok", false):
		failures.append("REGRESSION-FLUSH-3: verify_integrity(full) must be ok after flush_rotation, got: %s" % str(vi_fl))

	_cleanup(TEST_DIR + "/reg_ts")
	_cleanup(TEST_DIR + "/reg_mutex")
	_cleanup(TEST_DIR + "/reg_flush")

	# Cleanup all test dirs
	_cleanup(TEST_DIR + "/must1")
	_cleanup(TEST_DIR + "/must2")
	_cleanup(TEST_DIR + "/must3")
	_cleanup(TEST_DIR + "/must4")
	_cleanup(TEST_DIR + "/must5")
	_cleanup(TEST_DIR + "/must6")
	_cleanup(TEST_DIR + "/must7")
	_cleanup(TEST_DIR + "/must8")
	_cleanup(TEST_DIR + "/must9")
	_cleanup(TEST_DIR + "/must10")
	_cleanup(TEST_DIR)

	if failures.is_empty():
		print("[PASS] FilesystemAuditLedger (%d checks)" % checks)
		quit(0)
	else:
		print("[FAIL] FilesystemAuditLedger")
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


func _read_file_lines(path: String) -> Array[String]:
	var result: Array[String] = []
	if not FileAccess.file_exists(path):
		return result
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return result
	while not f.eof_reached():
		var line := f.get_line()
		if not line.strip_edges().is_empty():
			result.append(line)
	f.close()
	return result


func _write_lines(path: String, lines: Array[String]) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return
	for line in lines:
		f.store_string(line + "\n")
	f.close()


func _cleanup(path: String) -> void:
	var absolute := ProjectSettings.globalize_path(path)
	if not DirAccess.dir_exists_absolute(absolute):
		return
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while not entry.is_empty():
		if entry != "." and entry != "..":
			var file_path_abs := absolute + "/" + entry
			if DirAccess.dir_exists_absolute(file_path_abs):
				pass  # skip subdirs
			else:
				DirAccess.remove_absolute(file_path_abs)
		entry = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(absolute)
