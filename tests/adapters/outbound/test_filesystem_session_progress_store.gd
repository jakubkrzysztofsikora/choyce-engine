## Unit tests for FilesystemSessionProgressStore (VS-026)
## Run: godot --headless --script tests/adapters/outbound/test_filesystem_session_progress_store.gd

class_name TestFilesystemSessionProgressStore
extends SceneTree

const FilesystemSessionProgressStoreClass := preload("res://src/adapters/outbound/filesystem_session_progress_store.gd")
const ProgressStateClass := preload("res://src/domain/shared/progress_state.gd")


func _init() -> void:
	var failures: Array = []
	
	_test_basic_operations(failures)
	_test_serialization(failures)
	_test_clear_progress(failures)
	_test_list_player_progress(failures)
	
	if failures.is_empty():
		print("[test_filesystem_session_progress_store] OK")
		quit(0)
	else:
		printerr("[test_filesystem_session_progress_store] FAIL ", failures.size())
		for f in failures:
			printerr("  - ", f)
		quit(1)


func _test_basic_operations(failures: Array) -> void:
	var store = FilesystemSessionProgressStoreClass.new()
	if store == null:
		failures.append("FilesystemSessionProgressStore: failed to instantiate")
		return
	
	store.setup()
	
	# Test save and load
	var progress = ProgressStateClass.new()
	progress.collectibles = {"gold": 10, "silver": 5}
	progress.achievements = ["first_steps", "explorer"]
	progress.unlocks = ["sword", "shield"]
	progress.quest_progress = {"main_quest": 3, "side_quest": 1}
	progress.score = 1000
	
	var save_result = store.save_progress("test_profile", "test_world", progress)
	if not save_result:
		failures.append("FilesystemSessionProgressStore: save_progress returned false")
	
	# Load it back
	var loaded_progress = store.load_progress("test_profile", "test_world")
	if loaded_progress == null:
		failures.append("FilesystemSessionProgressStore: load_progress returned null")
		return
	
	# Verify all fields
	if loaded_progress.collectibles.size() != 2 or loaded_progress.collectibles.get("gold", 0) != 10:
		failures.append("FilesystemSessionProgressStore: collectibles not deserialized correctly")
	
	if loaded_progress.achievements.size() != 2 or not loaded_progress.achievements.has("first_steps"):
		failures.append("FilesystemSessionProgressStore: achievements not deserialized correctly")
	
	if loaded_progress.unlocks.size() != 2 or not loaded_progress.unlocks.has("sword"):
		failures.append("FilesystemSessionProgressStore: unlocks not deserialized correctly")
	
	if loaded_progress.quest_progress.size() != 2 or loaded_progress.quest_progress.get("main_quest", 0) != 3:
		failures.append("FilesystemSessionProgressStore: quest_progress not deserialized correctly")
	
	if loaded_progress.score != 1000:
		failures.append("FilesystemSessionProgressStore: score not deserialized correctly")


func _test_serialization(failures: Array) -> void:
	var store = FilesystemSessionProgressStoreClass.new()
	store.setup()
	
	# Test with empty progress
	var empty_progress = ProgressStateClass.new()
	var save_result = store.save_progress("test_profile_2", "test_world_2", empty_progress)
	if not save_result:
		failures.append("FilesystemSessionProgressStore: failed to save empty progress")
		return
	
	var loaded_empty = store.load_progress("test_profile_2", "test_world_2")
	if loaded_empty == null:
		failures.append("FilesystemSessionProgressStore: failed to load empty progress")
		return
	
	# Empty progress should have default values
	if loaded_empty.collectibles.size() != 0:
		failures.append("FilesystemSessionProgressStore: empty collectibles should be empty dict")
	
	if loaded_empty.achievements.size() != 0:
		failures.append("FilesystemSessionProgressStore: empty achievements should be empty array")


func _test_clear_progress(failures: Array) -> void:
	var store = FilesystemSessionProgressStoreClass.new()
	store.setup()
	
	# Save something
	var progress = ProgressStateClass.new()
	progress.score = 500
	store.save_progress("test_profile_3", "test_world_3", progress)
	
	# Verify it exists
	var loaded = store.load_progress("test_profile_3", "test_world_3")
	if loaded == null or loaded.score != 500:
		failures.append("FilesystemSessionProgressStore: failed to save for clear test")
		return
	
	# Clear it
	var clear_result = store.clear_progress("test_profile_3", "test_world_3")
	if not clear_result:
		failures.append("FilesystemSessionProgressStore: clear_progress returned false")
		return
	
	# Verify it's gone (should return empty progress)
	var loaded_after_clear = store.load_progress("test_profile_3", "test_world_3")
	if loaded_after_clear == null:
		failures.append("FilesystemSessionProgressStore: load_progress returned null after clear")
		return
	
	if loaded_after_clear.score != 0:
		failures.append("FilesystemSessionProgressStore: progress not cleared correctly")


func _test_list_player_progress(failures: Array) -> void:
	var store = FilesystemSessionProgressStoreClass.new()
	store.setup()
	
	# Save multiple worlds for one profile
	for i in range(3):
		var progress = ProgressStateClass.new()
		progress.score = (i + 1) * 100
		var save_result = store.save_progress("test_profile_4", "world_%d" % i, progress)
		if not save_result:
			failures.append("FilesystemSessionProgressStore: failed to save world_%d" % i)
			return
	
	# List all progress for the profile
	var list_result = store.list_player_progress("test_profile_4")
	if list_result.size() != 3:
		failures.append("FilesystemSessionProgressStore: list_player_progress returned %d results, expected 3" % list_result.size())
		return
	
	# Verify the results contain the expected worlds
	var found_worlds = []
	for item in list_result:
		found_worlds.append(item["world_id"])
	
	if not found_worlds.has("world_0") or not found_worlds.has("world_1") or not found_worlds.has("world_2"):
		failures.append("FilesystemSessionProgressStore: list_player_progress missing expected worlds")
