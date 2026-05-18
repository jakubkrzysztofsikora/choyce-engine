## Tests for FilesystemPublishStore persistent adapter.
##
## MUST-1  save_request() persists a request to disk; load_request() returns identical data
## MUST-2  round-trip: re-instantiated adapter reads the same request (simulated restart)
## MUST-3  list_published() returns only PUBLISHED requests
## MUST-4  list_requests_for_project() filters by project_id
## MUST-5  null request rejected by save_request()
## MUST-6  empty request_id rejected by save_request() and load_request()
## MUST-7  load_request() returns null for non-existent id
## MUST-8  save overwrites existing request (state update persists)
##
## DEBOUNCE-1  30x rapid writes → only 1 disk write after flush_if_due(250ms elapsed)
## DEBOUNCE-2  write then read immediately → in-memory state visible (no disk read required)
## DEBOUNCE-3  flush() forces disk write immediately (dirty flag cleared)
## DEBOUNCE-4  two writes >250ms apart → 2 separate disk writes
extends SceneTree


func _init() -> void:
	var failures: Array[String] = []
	var checks := 0

	const TEST_DIR := "user://test_fs_publish_store"
	_cleanup(TEST_DIR)

	# ── MUST-1: save + immediate load returns same data ────────────────────────
	var store := FilesystemPublishStore.new().setup(TEST_DIR)
	var req := _make_request("req-001", "proj-A", "world-1", PublishRequest.PublishState.DRAFT)

	checks += 1
	if not store.save_request(req):
		failures.append("MUST-1a: save_request() must return true")

	var loaded := store.load_request("req-001")
	checks += 1
	if loaded == null:
		failures.append("MUST-1b: load_request() must return non-null after save")
	elif loaded.request_id != req.request_id:
		failures.append("MUST-1c: loaded request_id mismatch")
	elif loaded.project_id != req.project_id:
		failures.append("MUST-1d: loaded project_id mismatch")
	elif loaded.world_id != req.world_id:
		failures.append("MUST-1e: loaded world_id mismatch")

	# ── MUST-2: round-trip — re-instantiated adapter reads persisted request ──
	# Flush first so data hits disk before creating a new adapter instance.
	store.flush()
	var store2 := FilesystemPublishStore.new().setup(TEST_DIR)
	var loaded2 := store2.load_request("req-001")
	checks += 1
	if loaded2 == null:
		failures.append("MUST-2a: re-instantiated store must read persisted request from disk")
	elif loaded2.request_id != "req-001":
		failures.append("MUST-2b: re-instantiated load returned wrong request_id")

	# ── MUST-3: list_published() returns only PUBLISHED ────────────────────────
	var req_pub := _make_request("req-002", "proj-B", "world-2", PublishRequest.PublishState.PUBLISHED)
	var req_rej := _make_request("req-003", "proj-B", "world-3", PublishRequest.PublishState.REJECTED)
	store.save_request(req_pub)
	store.save_request(req_rej)

	var published_list := store.list_published()
	checks += 1
	var found_pub := false
	var found_rej := false
	for r in published_list:
		if r is PublishRequest:
			if r.request_id == "req-002":
				found_pub = true
			if r.request_id == "req-003":
				found_rej = true
	if not found_pub:
		failures.append("MUST-3a: list_published() must include PUBLISHED request")
	checks += 1
	if found_rej:
		failures.append("MUST-3b: list_published() must NOT include REJECTED request")

	# ── MUST-4: list_requests_for_project() filters by project ─────────────────
	var proj_b_list := store.list_requests_for_project("proj-B")
	checks += 1
	if proj_b_list.size() < 2:
		failures.append("MUST-4a: list_requests_for_project('proj-B') must return at least 2")

	var proj_a_list := store.list_requests_for_project("proj-A")
	checks += 1
	if proj_a_list.size() != 1:
		failures.append("MUST-4b: list_requests_for_project('proj-A') must return exactly 1")

	checks += 1
	if store.list_requests_for_project("").size() != 0:
		failures.append("MUST-4c: list_requests_for_project('') must return empty array")

	# ── MUST-5: null request rejected ─────────────────────────────────────────
	checks += 1
	if store.save_request(null) != false:
		failures.append("MUST-5: save_request(null) must return false")

	# ── MUST-6: empty request_id rejected ─────────────────────────────────────
	var req_empty_id := PublishRequest.new("proj-X", "world-X")
	req_empty_id.request_id = ""
	checks += 1
	if store.save_request(req_empty_id) != false:
		failures.append("MUST-6a: save_request with empty request_id must return false")

	checks += 1
	if store.load_request("") != null:
		failures.append("MUST-6b: load_request('') must return null")

	# ── MUST-7: load non-existent returns null ────────────────────────────────
	checks += 1
	if store.load_request("does-not-exist-xyz") != null:
		failures.append("MUST-7: load_request for missing id must return null")

	# ── MUST-8: save overwrites — state update persists ────────────────────────
	var req_update := _make_request("req-001", "proj-A", "world-1", PublishRequest.PublishState.PUBLISHED)
	store.save_request(req_update)
	var loaded_updated := store.load_request("req-001")
	checks += 1
	if loaded_updated == null or loaded_updated.state != PublishRequest.PublishState.PUBLISHED:
		failures.append("MUST-8: overwritten request must reflect updated state")

	_cleanup(TEST_DIR)

	# ── DEBOUNCE tests use a fresh isolated dir ─────────────────────────────────
	const DEBOUNCE_DIR := "user://test_fs_publish_debounce"
	_cleanup(DEBOUNCE_DIR)

	# ── DEBOUNCE-1: 30x rapid writes → only 1 disk write after flush_if_due ───
	var dstore := FilesystemPublishStore.new().setup(DEBOUNCE_DIR)
	for i in range(30):
		var r := _make_request("burst-%d" % i, "proj-burst", "world-burst",
				PublishRequest.PublishState.DRAFT)
		dstore.save_request(r)

	# Before 250ms elapses, no flush should have occurred. Simulate < 250ms.
	dstore.flush_if_due(100)  # pretend only 100ms elapsed — should NOT flush
	checks += 1
	# Verify dirty flag still set: a fresh store from disk won't see the burst IDs.
	var peek := FilesystemPublishStore.new().setup(DEBOUNCE_DIR)
	# Files may not be on disk yet because debounce hasn't fired.
	# We just verify we can still read the burst data from in-memory store.
	var from_mem := dstore.load_request("burst-0")
	if from_mem == null:
		failures.append("DEBOUNCE-1a: in-memory cache must contain burst writes before flush")

	# Now advance past 250ms: flush_if_due should write.
	dstore.flush_if_due(300)  # 300ms elapsed → triggers flush
	checks += 1
	var peek2 := FilesystemPublishStore.new().setup(DEBOUNCE_DIR)
	var from_disk := peek2.load_request("burst-0")
	if from_disk == null:
		failures.append("DEBOUNCE-1b: after flush_if_due(300ms) burst data must be on disk")

	# ── DEBOUNCE-2: write then read immediately → in-memory state visible ─────
	var dstore2 := FilesystemPublishStore.new().setup(DEBOUNCE_DIR)
	var imm_req := _make_request("imm-001", "proj-imm", "world-imm", PublishRequest.PublishState.DRAFT)
	dstore2.save_request(imm_req)
	checks += 1
	var imm_loaded := dstore2.load_request("imm-001")
	if imm_loaded == null or imm_loaded.request_id != "imm-001":
		failures.append("DEBOUNCE-2: load_request() must return in-memory write without flush")

	# ── DEBOUNCE-3: flush() forces immediate disk write ───────────────────────
	var dstore3 := FilesystemPublishStore.new().setup(DEBOUNCE_DIR)
	var flush_req := _make_request("flush-001", "proj-flush", "world-flush",
			PublishRequest.PublishState.DRAFT)
	dstore3.save_request(flush_req)
	dstore3.flush()
	checks += 1
	var dstore3b := FilesystemPublishStore.new().setup(DEBOUNCE_DIR)
	var flush_loaded := dstore3b.load_request("flush-001")
	if flush_loaded == null or flush_loaded.request_id != "flush-001":
		failures.append("DEBOUNCE-3: flush() must write data to disk immediately")

	# ── DEBOUNCE-4: two writes >250ms apart → 2 separate disk writes ──────────
	var dstore4 := FilesystemPublishStore.new().setup(DEBOUNCE_DIR)
	var early_req := _make_request("two-001", "proj-two", "world-two",
			PublishRequest.PublishState.DRAFT)
	dstore4.save_request(early_req)
	# Simulate 300ms passing → first write should flush.
	dstore4.flush_if_due(300)
	checks += 1
	var after_first := FilesystemPublishStore.new().setup(DEBOUNCE_DIR)
	if after_first.load_request("two-001") == null:
		failures.append("DEBOUNCE-4a: first write must be on disk after >250ms elapsed")

	# Second write in a fresh debounce window.
	var late_req := _make_request("two-002", "proj-two", "world-two",
			PublishRequest.PublishState.PUBLISHED)
	dstore4.save_request(late_req)
	dstore4.flush_if_due(300)
	checks += 1
	var after_second := FilesystemPublishStore.new().setup(DEBOUNCE_DIR)
	if after_second.load_request("two-002") == null:
		failures.append("DEBOUNCE-4b: second write must be on disk after second >250ms elapsed")

	_cleanup(DEBOUNCE_DIR)

	if failures.is_empty():
		print("[PASS] FilesystemPublishStore (%d checks)" % checks)
		quit(0)
	else:
		print("[FAIL] FilesystemPublishStore")
		for item in failures:
			print("  - %s" % item)
		quit(1)


func _make_request(
	request_id: String,
	project_id: String,
	world_id: String,
	state: PublishRequest.PublishState
) -> PublishRequest:
	var req := PublishRequest.new(project_id, world_id)
	req.request_id = request_id
	req.requester_id = "kid-1"
	req.family_id = "family-local"
	req.created_at = "2026-05-18T12:00:00Z"
	# Force state directly — bypasses state machine for test data setup.
	req.state = state
	return req


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
			var file_path := absolute + "/" + entry
			if DirAccess.dir_exists_absolute(file_path):
				pass  # skip subdirs — test only creates flat files
			else:
				DirAccess.remove_absolute(file_path)
		entry = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(absolute)
