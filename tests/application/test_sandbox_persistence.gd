## Headless test: sandbox persistence roundtrip.
## Run with:  godot4 --headless --script res://tests/application/test_sandbox_persistence.gd
extends SceneTree

const TEST_ROOT := "user://test_sandbox_saves"
var _pass_count: int = 0
var _fail_count: int = 0


func _init() -> void:
	call_deferred("_run_tests")


# ---------------------------------------------------------------------------
# Minimal stub clock that returns a fixed ISO string.
# ---------------------------------------------------------------------------
class StubClock extends ClockPort:
	var _iso: String = "2026-07-18T00:00:00Z"
	var _msec: int = 1752796800000

	func now_iso() -> String:
		return _iso

	func now_msec() -> int:
		return _msec


# ---------------------------------------------------------------------------
# Assertion helper
# ---------------------------------------------------------------------------
func _assert(condition: bool, message: String) -> void:
	if not condition:
		print("FAIL: %s" % message)
		_fail_count += 1
	else:
		print("PASS: %s" % message)
		_pass_count += 1


# ---------------------------------------------------------------------------
# Factory for a known-good snapshot
# ---------------------------------------------------------------------------
func _make_snapshot() -> SandboxSnapshot:
	var snap := SandboxSnapshot.new()
	snap.player_position = Vector3(10.5, 2.0, -3.25)
	snap.player_health_current = 80
	snap.player_health_max = 120
	snap.inventory_items = {"wood": 5, "stone": 12}
	snap.placed_blocks = [
		{"cell": [1.0, 2.0, 3.0], "kind_id": "wood_oak"},
		{"cell": [4.0, 0.0, -1.0], "kind_id": "glow"},
	]
	snap.score = 1500
	snap.weapon_index = 2
	snap.xp_level = 3
	snap.xp_current = 450
	snap.wave_number = 7
	snap.session_elapsed_sec = 123.456
	snap.world_id = "world_test_1"
	snap.project_id = "project_test_1"
	snap.profile_id = "profile_test_1"
	snap.saved_at_iso = "2026-07-18T00:00:00Z"
	return snap


# ---------------------------------------------------------------------------
# Cleanup helper – remove all files under TEST_ROOT
# ---------------------------------------------------------------------------
func _cleanup() -> void:
	var absolute := ProjectSettings.globalize_path(TEST_ROOT)
	if not DirAccess.dir_exists_absolute(absolute):
		return
	# Remove known test artefacts.
	var profile_dir := TEST_ROOT + "/profile_test_1"
	var dir := DirAccess.open(profile_dir)
	if dir != null:
		dir.list_dir_begin()
		var entry := dir.get_next()
		while not entry.is_empty():
			if not dir.current_is_dir():
				dir.remove(entry)
			entry = dir.get_next()
		dir.list_dir_end()
	# Remove the profile directory and root.
	var root_dir := DirAccess.open(TEST_ROOT)
	if root_dir != null:
		root_dir.remove("profile_test_1")
	DirAccess.remove_absolute(absolute)


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------
func _run_tests() -> void:
	print("=== SandboxSnapshot Persistence Tests ===")
	_cleanup()

	_test_roundtrip_serialisation()
	_test_is_valid_guards()
	_test_save_and_load()
	_test_has_snapshot()
	_test_clear_snapshot()
	_test_load_nonexistent()
	_test_load_corrupt_json()
	_test_service_stamps_time()
	_test_list_snapshots()

	_cleanup()

	print("=== Results: %d passed, %d failed ===" % [_pass_count, _fail_count])
	if _fail_count > 0:
		print("SANDBOX_PERSISTENCE_TEST: FAIL")
		quit(1)
	else:
		print("SANDBOX_PERSISTENCE_TEST: PASS")
		quit(0)


func _test_roundtrip_serialisation() -> void:
	print("--- roundtrip serialisation ---")
	var snap := _make_snapshot()
	var d := snap.to_dict()
	var restored := SandboxSnapshot.from_dict(d)

	_assert(restored != null, "from_dict should return a snapshot")
	if restored == null:
		return

	_assert(restored.player_position.is_equal_approx(snap.player_position),
		"player_position roundtrips")
	_assert(restored.player_health_current == snap.player_health_current,
		"player_health_current roundtrips")
	_assert(restored.player_health_max == snap.player_health_max,
		"player_health_max roundtrips")
	_assert(restored.inventory_items.size() == snap.inventory_items.size(),
		"inventory_items size roundtrips")
	_assert(int(restored.inventory_items.get("wood", 0)) == 5,
		"inventory wood count roundtrips")
	_assert(int(restored.inventory_items.get("stone", 0)) == 12,
		"inventory stone count roundtrips")
	_assert(restored.placed_blocks.size() == 2,
		"placed_blocks count roundtrips")
	_assert(restored.score == 1500, "score roundtrips")
	_assert(restored.weapon_index == 2, "weapon_index roundtrips")
	_assert(restored.xp_level == 3, "xp_level roundtrips")
	_assert(restored.xp_current == 450, "xp_current roundtrips")
	_assert(restored.wave_number == 7, "wave_number roundtrips")
	_assert(is_equal_approx(restored.session_elapsed_sec, 123.456),
		"session_elapsed_sec roundtrips")
	_assert(restored.world_id == "world_test_1", "world_id roundtrips")
	_assert(restored.project_id == "project_test_1", "project_id roundtrips")
	_assert(restored.profile_id == "profile_test_1", "profile_id roundtrips")
	_assert(restored.saved_at_iso == "2026-07-18T00:00:00Z",
		"saved_at_iso roundtrips")
	_assert(restored.format_version == SandboxSnapshot.CURRENT_FORMAT_VERSION,
		"format_version roundtrips")


func _test_is_valid_guards() -> void:
	print("--- is_valid guards ---")
	var snap := _make_snapshot()
	_assert(snap.is_valid(), "fully populated snapshot is valid")

	var bad := SandboxSnapshot.new()
	bad.project_id = "p"
	_assert(not bad.is_valid(), "empty world_id makes snapshot invalid")

	var bad2 := SandboxSnapshot.new()
	bad2.world_id = "w"
	_assert(not bad2.is_valid(), "empty project_id makes snapshot invalid")

	var bad3 := SandboxSnapshot.new()
	bad3.world_id = "  "
	bad3.project_id = "p"
	_assert(not bad3.is_valid(), "whitespace-only world_id is invalid")


func _test_save_and_load() -> void:
	print("--- save and load ---")
	var store := FilesystemSandboxStore.new(TEST_ROOT)
	var snap := _make_snapshot()

	var saved := store.save_snapshot(snap)
	_assert(saved, "save_snapshot returns true")

	var loaded := store.load_snapshot("profile_test_1", "project_test_1")
	_assert(loaded != null, "load_snapshot returns a snapshot")
	if loaded == null:
		return

	_assert(loaded.score == 1500, "loaded score matches")
	_assert(loaded.player_position.is_equal_approx(Vector3(10.5, 2.0, -3.25)),
		"loaded position matches")
	_assert(loaded.placed_blocks.size() == 2, "loaded blocks count matches")
	_assert(loaded.world_id == "world_test_1", "loaded world_id matches")


func _test_has_snapshot() -> void:
	print("--- has_snapshot ---")
	var store := FilesystemSandboxStore.new(TEST_ROOT)
	_assert(store.has_snapshot("profile_test_1", "project_test_1"),
		"has_snapshot returns true after save")
	_assert(not store.has_snapshot("profile_test_1", "nonexistent"),
		"has_snapshot returns false for unknown project")


func _test_clear_snapshot() -> void:
	print("--- clear_snapshot ---")
	var store := FilesystemSandboxStore.new(TEST_ROOT)
	# Ensure the file exists first.
	_assert(store.has_snapshot("profile_test_1", "project_test_1"),
		"snapshot exists before clear")

	var cleared := store.clear_snapshot("profile_test_1", "project_test_1")
	_assert(cleared, "clear_snapshot returns true")
	_assert(not store.has_snapshot("profile_test_1", "project_test_1"),
		"has_snapshot returns false after clear")

	# Clearing a non-existent file should still return true.
	_assert(store.clear_snapshot("profile_test_1", "project_test_1"),
		"clear of already-cleared snapshot returns true")


func _test_load_nonexistent() -> void:
	print("--- load nonexistent ---")
	var store := FilesystemSandboxStore.new(TEST_ROOT)
	var result := store.load_snapshot("no_such_profile", "no_such_project")
	_assert(result == null, "load of nonexistent file returns null")


func _test_load_corrupt_json() -> void:
	print("--- load corrupt JSON ---")
	var store := FilesystemSandboxStore.new(TEST_ROOT)

	# Write deliberately corrupt JSON to the expected path.
	var profile_dir := TEST_ROOT + "/profile_corrupt"
	var absolute := ProjectSettings.globalize_path(profile_dir)
	DirAccess.make_dir_recursive_absolute(absolute)
	var path := profile_dir + "/project_bad.json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	_assert(file != null, "can create corrupt test file")
	if file != null:
		file.store_string("{{{NOT VALID JSON}}}")
		file.close()

	var result := store.load_snapshot("profile_corrupt", "project_bad")
	_assert(result == null, "load of corrupt JSON returns null")

	# Clean up.
	var dir := DirAccess.open(profile_dir)
	if dir != null:
		dir.remove("project_bad.json")
	var root := DirAccess.open(TEST_ROOT)
	if root != null:
		root.remove("profile_corrupt")


func _test_service_stamps_time() -> void:
	print("--- service stamps saved_at_iso ---")
	var store := FilesystemSandboxStore.new(TEST_ROOT)
	var clock := StubClock.new()
	var service := SandboxPersistenceService.new()
	service.setup(store, clock)

	var snap := _make_snapshot()
	snap.saved_at_iso = ""  # Clear so we can verify the service sets it.

	var ok := service.save_sandbox(snap)
	_assert(ok, "service.save_sandbox returns true")
	_assert(snap.saved_at_iso == "2026-07-18T00:00:00Z",
		"service stamps saved_at_iso from clock")

	var loaded := service.load_sandbox("profile_test_1", "project_test_1")
	_assert(loaded != null, "service.load_sandbox returns snapshot")
	if loaded != null:
		_assert(loaded.saved_at_iso == "2026-07-18T00:00:00Z",
			"loaded saved_at_iso matches stamped value")

	_assert(service.has_saved_sandbox("profile_test_1", "project_test_1"),
		"service.has_saved_sandbox returns true")

	_assert(service.clear_sandbox("profile_test_1", "project_test_1"),
		"service.clear_sandbox returns true")
	_assert(not service.has_saved_sandbox("profile_test_1", "project_test_1"),
		"service.has_saved_sandbox returns false after clear")


func _test_list_snapshots() -> void:
	print("--- list_snapshots ---")
	var store := FilesystemSandboxStore.new(TEST_ROOT)

	# Save two snapshots under the same profile.
	var snap1 := _make_snapshot()
	snap1.project_id = "proj_a"
	store.save_snapshot(snap1)

	var snap2 := _make_snapshot()
	snap2.project_id = "proj_b"
	store.save_snapshot(snap2)

	var listed := store.list_snapshots("profile_test_1")
	_assert(listed.size() == 2, "list_snapshots returns 2 entries")

	# Clean up.
	store.clear_snapshot("profile_test_1", "proj_a")
	store.clear_snapshot("profile_test_1", "proj_b")
