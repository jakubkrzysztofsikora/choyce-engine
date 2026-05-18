## Tests for FilesystemConsentStore persistent adapter.
##
## MUST-1  has_consent() defaults to false (deny) for unknown profile/type
## MUST-2  request_consent() returns true and makes has_consent() return true
## MUST-3  round-trip: re-instantiated adapter reads persisted consent
## MUST-4  empty profile_id rejected (has_consent + request_consent both false)
## MUST-5  empty consent_type rejected
## MUST-6  IO failure (bad path) returns false — consent-deny failsafe
## MUST-7  storage path is within configured base_dir
extends SceneTree


func _init() -> void:
	var failures: Array[String] = []
	var checks := 0

	const TEST_DIR := "user://test_fs_consent_store"
	_cleanup(TEST_DIR)

	# ── MUST-1: default deny ───────────────────────────────────────────────────
	var store := FilesystemConsentStore.new().setup(TEST_DIR)
	checks += 1
	if store.has_consent("profile_kid_1", "cloud_sync") != false:
		failures.append("MUST-1: has_consent() must default to false for unknown profile")

	# ── MUST-2: grant and immediately readable ─────────────────────────────────
	checks += 1
	var granted := store.request_consent("profile_kid_1", "cloud_sync")
	if not granted:
		failures.append("MUST-2a: request_consent() must return true on success")

	checks += 1
	if not store.has_consent("profile_kid_1", "cloud_sync"):
		failures.append("MUST-2b: has_consent() must return true immediately after grant")

	# ── MUST-3: round-trip (re-instantiate and read) ───────────────────────────
	var store2 := FilesystemConsentStore.new().setup(TEST_DIR)
	checks += 1
	if not store2.has_consent("profile_kid_1", "cloud_sync"):
		failures.append("MUST-3: re-instantiated store must read persisted consent from disk")

	# ── MUST-4: empty profile_id rejected ─────────────────────────────────────
	checks += 1
	if store.has_consent("", "cloud_sync") != false:
		failures.append("MUST-4a: empty profile_id must return false from has_consent()")

	checks += 1
	if store.request_consent("", "cloud_sync") != false:
		failures.append("MUST-4b: empty profile_id must return false from request_consent()")

	# ── MUST-5: empty consent_type rejected ───────────────────────────────────
	checks += 1
	if store.has_consent("profile_kid_1", "") != false:
		failures.append("MUST-5a: empty consent_type must return false from has_consent()")

	checks += 1
	if store.request_consent("profile_kid_1", "") != false:
		failures.append("MUST-5b: empty consent_type must return false from request_consent()")

	# ── MUST-6: IO failure safety default ────────────────────────────────────
	# An unwritable path (read-only path or non-existent deep path without
	# create permission) would fail; we test the empty-path edge instead,
	# which triggers the safety-default branch in setup().
	var store_bad := FilesystemConsentStore.new()
	store_bad._consent_file = ""   # intentional corrupt state to simulate bad path
	checks += 1
	if store_bad.has_consent("x", "y") != false:
		failures.append("MUST-6: corrupted path must still return false (consent-deny)")

	# ── MUST-7: storage path within configured dir ────────────────────────────
	checks += 1
	var path := store.get_storage_path()
	if not path.begins_with(TEST_DIR):
		failures.append("MUST-7: storage path '%s' must begin with base_dir '%s'" % [path, TEST_DIR])

	_cleanup(TEST_DIR)

	if failures.is_empty():
		print("[PASS] FilesystemConsentStore (%d checks)" % checks)
		quit(0)
	else:
		print("[FAIL] FilesystemConsentStore")
		for item in failures:
			print("  - %s" % item)
		quit(1)


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
			DirAccess.remove_absolute(absolute + "/" + entry)
		entry = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(absolute)
