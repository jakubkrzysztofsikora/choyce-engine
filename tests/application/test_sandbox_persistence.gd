## Headless test: sandbox persistence roundtrip.
## Run with:  godot4 --headless --script res://tests/application/test_sandbox_persistence.gd
extends SceneTree

const TEST_ROOT := "user://test_sandbox_saves"
var _pass_count: int = 0
var _fail_count: int = 0


func _init() -> void:
	call_deferred("_run_tests")


class StubClock extends ClockPort:
	var _msec: int = 1752796800000

	func now_iso() -> String:
		return "2026-07-18T00:00:00Z"

	func now_msec() -> int:
		return _msec


func _assert(condition: bool, message: String) -> void:
	if not condition:
		print("FAIL: %s" % message)
		_fail_count += 1
	else:
		print("PASS: %s" % message)
		_pass_count += 1


func _make_state() -> SandboxState:
	var state := SandboxState.new()
	state.world_id = "world_test_1"
	state.player_position = Vector3(10.5, 2.0, -3.25)
	state.inventory = {"wood": 5, "stone": 12}
	state.placed_blocks = [
		{"cell": Vector3i(1, 2, 3), "kind": "wood_oak"},
		{"cell": Vector3i(4, 0, -1), "kind": "glow"},
	]
	state.progression.collectibles = {"shell": 2}
	state.progression.achievements = ["first_steps"]
	state.progression.unlocks = ["door_key"]
	state.progression.quest_progress = {"quest_1": 0.5}
	state.progression.score = 1500
	return state


func _cleanup() -> void:
	var file_path := TEST_ROOT + "/current.json"
	var absolute_file := ProjectSettings.globalize_path(file_path)
	if FileAccess.file_exists(file_path):
		DirAccess.remove_absolute(absolute_file)
	var absolute_root := ProjectSettings.globalize_path(TEST_ROOT)
	if DirAccess.dir_exists_absolute(absolute_root):
		DirAccess.remove_absolute(absolute_root)


func _run_tests() -> void:
	print("=== SandboxState Persistence Tests ===")
	_cleanup()

	_test_roundtrip_serialisation()
	_test_empty_state_guards()
	_test_save_and_load()
	_test_has_save()
	_test_clear_save()
	_test_load_nonexistent()
	_test_load_corrupt_json()
	_test_service_stamps_time()

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
	var state := _make_state()
	var d := state.to_dict()
	var restored := SandboxState.from_dict(d)

	_assert(restored != null, "from_dict should return a state")
	if restored == null:
		return

	_assert(restored.world_id == state.world_id, "world_id roundtrips")
	_assert(restored.player_position.is_equal_approx(state.player_position), "player_position roundtrips")
	_assert(int(restored.inventory.get("wood", 0)) == 5, "inventory wood count roundtrips")
	_assert(restored.placed_blocks.size() == 2, "placed_blocks count roundtrips")
	_assert(restored.progression.score == 1500, "score roundtrips")
	_assert(restored.progression.achievements.has("first_steps"), "achievements roundtrip")
	_assert(restored.progression.unlocks.has("door_key"), "unlocks roundtrip")
	_assert(int(restored.saved_at_unix) == int(state.saved_at_unix), "saved_at_unix roundtrips")


func _test_empty_state_guards() -> void:
	print("--- empty state guards ---")
	var empty := SandboxState.new()
	_assert(empty.is_empty(), "new state is empty")
	_assert(not _make_state().is_empty(), "populated state is not empty")


func _test_save_and_load() -> void:
	print("--- save and load ---")
	var store := FilesystemSandboxStore.new().setup(TEST_ROOT)
	var state := _make_state()

	var saved := store.save_state(state)
	_assert(saved, "save_state returns true")

	var loaded := store.load_state()
	_assert(loaded != null, "load_state returns a state")
	if loaded == null:
		return

	_assert(loaded.world_id == state.world_id, "loaded world_id matches")
	_assert(loaded.player_position.is_equal_approx(Vector3(10.5, 2.0, -3.25)), "loaded position matches")
	_assert(loaded.placed_blocks.size() == 2, "loaded blocks count matches")
	_assert(loaded.progression.score == 1500, "loaded score matches")


func _test_has_save() -> void:
	print("--- has_save ---")
	var store := FilesystemSandboxStore.new().setup(TEST_ROOT)
	_assert(store.has_save(), "has_save returns true after save")


func _test_clear_save() -> void:
	print("--- clear_save ---")
	var store := FilesystemSandboxStore.new().setup(TEST_ROOT)
	_assert(store.clear_save(), "clear_save returns true")
	_assert(not store.has_save(), "has_save returns false after clear")
	_assert(store.clear_save(), "clear of already-cleared save returns true")


func _test_load_nonexistent() -> void:
	print("--- load nonexistent ---")
	var store := FilesystemSandboxStore.new().setup(TEST_ROOT)
	var result := store.load_state()
	_assert(result != null, "load_state returns a state object")
	_assert(result.is_empty(), "load of nonexistent save returns empty state")


func _test_load_corrupt_json() -> void:
	print("--- load corrupt JSON ---")
	var store := FilesystemSandboxStore.new().setup(TEST_ROOT)

	var file_path := TEST_ROOT + "/current.json"
	var absolute := ProjectSettings.globalize_path(file_path)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEST_ROOT))
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	_assert(file != null, "can create corrupt test file")
	if file != null:
		file.store_string("{{{NOT VALID JSON}}}")
		file.close()

	var result := store.load_state()
	_assert(result != null, "load_state returns a state for corrupt file")
	_assert(result.is_empty(), "load of corrupt file returns empty state")

	if FileAccess.file_exists(file_path):
		DirAccess.remove_absolute(absolute)


func _test_service_stamps_time() -> void:
	print("--- service stamps saved_at_unix ---")
	var store := FilesystemSandboxStore.new().setup(TEST_ROOT)
	var clock := StubClock.new()
	var service := SandboxPersistenceService.new()
	service.setup(store, clock)

	var state := _make_state()
	state.saved_at_unix = 0

	var ok := service.save_sandbox(state)
	_assert(ok, "service.save_sandbox returns true")
	_assert(state.saved_at_unix == 1752796800000, "service stamps saved_at_unix from clock")

	var loaded := service.load_sandbox()
	_assert(loaded != null, "service.load_sandbox returns state")
	if loaded != null:
		_assert(loaded.saved_at_unix == 1752796800000, "loaded saved_at_unix matches stamped value")

	_assert(service.has_saved_sandbox(), "service.has_saved_sandbox returns true")
	_assert(service.clear_sandbox(), "service.clear_sandbox returns true")
	_assert(not service.has_saved_sandbox(), "service.has_saved_sandbox returns false after clear")
