## Unit tests for SandboxState persistence + round-trip + corrupt fallback.
## Run: godot --headless --script tests/domain/test_sandbox_state.gd
class_name TestSandboxState
extends SceneTree

const _SANDBOX_STATE := preload("res://src/domain/gameplay/sandbox_state.gd")
const _SANDBOX_STORE := preload("res://src/adapters/outbound/filesystem_sandbox_store.gd")


func _init() -> void:
	var failures: Array = []

	_test_defaults(failures)
	_test_full_round_trip(failures)
	_test_minimal_round_trip(failures)
	_test_corrupt_falls_back(failures)
	_test_empty_does_not_save(failures)
	_test_clear_removes_file(failures)
	_test_progress_round_trips(failures)
	_test_placed_blocks_round_trip(failures)

	if failures.is_empty():
		print("[test_sandbox_state] OK")
		quit(0)
	else:
		printerr("[test_sandbox_state] FAIL ", failures.size())
		for f in failures:
			printerr("  - ", f)
		quit(1)


func _make_store(suffix: String) -> FilesystemSandboxStore:
	var root := "user://test_sandbox_state_%s" % suffix
	var path := "%s/current.json" % root
	var absolute := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(absolute)
	var absolute_root := ProjectSettings.globalize_path(root)
	if DirAccess.dir_exists_absolute(absolute_root):
		DirAccess.remove_absolute(absolute_root)
	return _SANDBOX_STORE.new().setup(root)


func _cleanup_store(suffix: String) -> void:
	var root := "user://test_sandbox_state_%s" % suffix
	var path := "%s/current.json" % root
	var absolute := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(absolute)
	var absolute_root := ProjectSettings.globalize_path(root)
	if DirAccess.dir_exists_absolute(absolute_root):
		DirAccess.remove_absolute(absolute_root)


func _check(condition: bool, message: String, failures: Array) -> void:
	if not condition:
		failures.append(message)


func _make_state() -> SandboxState:
	var s: SandboxState = SandboxState.new()
	s.world_id = "adventure_island_001"
	s.player_position = Vector3(12.5, 1.8, -7.25)
	s.inventory = {"wood_oak": 4, "stone": 2, "meal": 1}
	s.placed_blocks = [
		{"cell": Vector3i(3, 0, 3), "kind": "grass"},
		{"cell": Vector3i(4, 0, 3), "kind": "dirt"},
	]
	s.progression.score = 120
	s.progression.collectibles = {"shell": 7, "pearl": 2}
	s.progression.achievements = ["first_steps", "builder"]
	s.progression.unlocks = ["recipe_kitchen"]
	s.progression.quest_progress = {"main_quest": 3}
	return s


func _test_defaults(failures: Array) -> void:
	var store := _make_store("defaults")
	var s := store.load_state()
	_check(s.is_empty(), "defaults_not_empty", failures)
	_cleanup_store("defaults")


func _test_full_round_trip(failures: Array) -> void:
	var store := _make_store("full")
	var src := _make_state()
	_check(store.save_state(src), "full_save_returned_false", failures)
	var loaded := store.load_state()
	_check(loaded.world_id == "adventure_island_001", "full_world_id", failures)
	_check(loaded.player_position == Vector3(12.5, 1.8, -7.25), "full_pos", failures)
	_check(int(loaded.inventory.get("wood_oak", -1)) == 4, "full_inv", failures)
	_check(loaded.placed_blocks.size() == 2, "full_blocks_count", failures)
	_check(loaded.progression.score == 120, "full_score", failures)
	_check(int(loaded.progression.collectibles.get("shell", -1)) == 7, "full_collectibles", failures)
	_check("first_steps" in loaded.progression.achievements, "full_achievements", failures)
	_cleanup_store("full")


func _test_minimal_round_trip(failures: Array) -> void:
	var store := _make_store("minimal")
	var src: SandboxState = SandboxState.new()
	src.world_id = "minimal_world"
	_check(store.save_state(src), "minimal_save_returned_false", failures)
	var loaded := store.load_state()
	_check(loaded.world_id == "minimal_world", "minimal_world_id", failures)
	_cleanup_store("minimal")


func _test_corrupt_falls_back(failures: Array) -> void:
	var store := _make_store("corrupt")
	var path := "user://test_sandbox_state_corrupt/current.json"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://test_sandbox_state_corrupt"))
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("{ this is not valid json")
	f.close()
	var s := store.load_state()
	_check(s.is_empty(), "corrupt_fallback_not_empty", failures)
	_cleanup_store("corrupt")


func _test_empty_does_not_save(failures: Array) -> void:
	var store := _make_store("empty")
	var s: SandboxState = SandboxState.new()
	_check(not store.save_state(s), "empty_should_not_save", failures)
	_check(not store.has_save(), "empty_should_not_create_file", failures)
	_cleanup_store("empty")


func _test_clear_removes_file(failures: Array) -> void:
	var store := _make_store("clear")
	var src := _make_state()
	store.save_state(src)
	_check(store.has_save(), "clear_precursor", failures)
	_check(store.clear_save(), "clear_returned_false", failures)
	_check(not store.has_save(), "clear_still_exists", failures)
	_cleanup_store("clear")


func _test_progress_round_trips(failures: Array) -> void:
	var store := _make_store("progress")
	var src := _make_state()
	src.progression.quest_progress = {"main_quest": 5, "side_quest": 2}
	store.save_state(src)
	var loaded := store.load_state()
	_check(int(loaded.progression.quest_progress.get("main_quest", -1)) == 5, "progress_main", failures)
	_check(int(loaded.progression.quest_progress.get("side_quest", -1)) == 2, "progress_side", failures)
	_check(loaded.progression.has_achievement("first_steps"), "progress_achievement", failures)
	_check(loaded.progression.is_quest_complete("main_quest", 4), "progress_quest_complete", failures)
	_cleanup_store("progress")


func _test_placed_blocks_round_trip(failures: Array) -> void:
	var store := _make_store("blocks")
	var src := _make_state()
	src.placed_blocks = [
		{"cell": Vector3i(10, 0, 20), "kind": "wood_oak"},
		{"cell": Vector3i(-5, 0, 15), "kind": "stone"},
		{"cell": Vector3i(0, 0, 0), "kind": "grass"},
	]
	store.save_state(src)
	var loaded := store.load_state()
	_check(loaded.placed_blocks.size() == 3, "blocks_size", failures)
	var first: Dictionary = loaded.placed_blocks[0]
	_check(first.get("kind", "") == "wood_oak", "blocks_first_kind", failures)
	var cell: Variant = first.get("cell", null)
	_check(cell is Vector3i, "blocks_cell_is_vector3i", failures)
	if cell is Vector3i:
		_check(cell == Vector3i(10, 0, 20), "blocks_first_cell", failures)
	_cleanup_store("blocks")