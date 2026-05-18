extends ApplicationTest

const ProjectScn = preload("res://src/domain/world_authoring/project.gd")
const FilesystemProjectStoreScn = preload("res://src/adapters/outbound/filesystem_project_store.gd")
const EventSourcedActionLogScn = preload("res://src/application/event_sourced_action_log.gd")
const WorldScn = preload("res://src/domain/world_authoring/world.gd")
const SceneNodeScn = preload("res://src/domain/world_authoring/scene_node.gd")
const WorldEditedEventScn = preload("res://src/domain/events/world_edited_event.gd")

var _temp_dir: String = "user://test_persistence_resilience"

func run() -> Dictionary:
	# _test_autosave_cadence_resilience() # Skip for now, focus on crash recovery
	_test_crash_recovery_replay()
	return _build_result("PersistenceResilience")

func _cleanup() -> void:
	var dir = DirAccess.open("user://")
	if dir and dir.dir_exists("test_persistence_resilience"):
		# Cleanup not easily recursive without loop.
		pass

func _test_autosave_cadence_resilience() -> void:
	pass

func _test_crash_recovery_replay() -> void:
	# 1. Setup Logic and Store
	var project_id = "proj_resilience_01"
	var store = FilesystemProjectStoreScn.new(_temp_dir)
	var log_service = EventSourcedActionLogScn.new()
	
	# 2. Create Project and World
	var project = ProjectScn.new(project_id, "Resilience Project")
	var world = WorldScn.new("world_01", "Main World")
	project.add_world(world)
	store.save_project(project) # Initial save

	# 3. Perform Actions and Record them
	var node_a = SceneNodeScn.new("node_a", int(SceneNodeScn.NodeType.OBJECT))
	world.add_node(node_a)
	
	var event = WorldEditedEventScn.new(world.world_id, "node_added", "actor_1", "1000")
	event.target_node_id = "node_a"
	event.new_state = {"node_id": "node_a", "display_name": "Node A"}
	var record_ok = log_service.record_world_edit(event)
	_assert_true(record_ok, "Event recorded in memory")
	
	# 4. Save (Autosave simulation)
	store.save_project(project)
	# This part simulates what OfflineAutosaveService now does:
	var log_data = log_service.export_state()
	var log_saved = store.save_action_log(project_id, log_data)
	_assert_true(log_saved, "Action log saved to filesystem")
	
	# 5. "Crash" and Reload
	var loaded_project = store.load_project(project_id)
	_assert_ne(loaded_project, null, "Project loaded after crash sim")
	var loaded_world = loaded_project.get_world("world_01")
	type_check(loaded_world, WorldScn, "World loaded correctly")
	
	var loaded_node = loaded_world.find_node("node_a")
	_assert_ne(loaded_node, null, "Action A persisted (Snapshot persistence)")

	# 6. Verify Log Persistence
	var loaded_log_data = store.load_action_log(project_id)
	_assert_false(loaded_log_data.is_empty(), "Log data loaded from disk")
	
	var restored_log = EventSourcedActionLogScn.new()
	restored_log.import_state(loaded_log_data)
	
	_assert_eq(restored_log.get_entry_count(world.world_id), 1, "Restored log has 1 entry")
	
	# Verify undo works on restored log
	var undo_result = restored_log.undo(world.world_id)
	_assert_true(undo_result.get("ok", false), "Undo successful on restored log")
	var undo_cursor = undo_result.get("cursor", -1)
	_assert_eq(undo_cursor, 0, "Undo moved cursor to 0")

func type_check(obj: Object, expected_type: Variant, msg: String) -> void:
	_assert_true(is_instance_of(obj, expected_type), msg)
