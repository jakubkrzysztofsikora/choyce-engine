## Application test: ManageProgressionService
## Validates progression saving, loading, world cloning, and remix workflows.
class_name TestManageProgressionService
extends ApplicationTest


var _service: ManageProgressionService
var _mock_progress_store: MockSessionProgressStore
var _mock_event_bus: MockEventBus


func _init() -> void:
	_mock_progress_store = MockSessionProgressStore.new()
	_mock_event_bus = MockEventBus.new()
	_service = ManageProgressionService.new().setup(_mock_progress_store, _mock_event_bus)


func run() -> Dictionary:
	test_save_session_progress()
	test_load_world_progress()
	test_clone_world()
	test_remix_world_reset_progress()
	return _build_result("ManageProgressionService")


func test_save_session_progress() -> void:
	_mock_event_bus._emitted_events.clear()
	var session = Session.new("session-1", "world-1")
	session.player_ids.append("profile-1")
	session.progress.collectibles["coin"] = 5
	session.progress.achievements.append("first_collectible")

	var result = _service.save_session_progress(session)

	_assert_true(result, "Should save session progress")
	_assert_eq(_mock_progress_store._saved_count, 1, "Should call save_progress on store")
	_assert_eq(_mock_event_bus._emitted_events.size(), 1, "Should emit progress event")
	var event = _mock_event_bus._emitted_events[0]
	_assert_true(event is SessionProgressUpdatedEvent, "Should emit SessionProgressUpdatedEvent")


func test_load_world_progress() -> void:
	_mock_event_bus._emitted_events.clear()
	var progress = ProgressState.new()
	progress.collectibles["coin"] = 10
	_mock_progress_store.setup_progress("profile-1", "world-1", progress)

	var loaded = _service.load_world_progress("profile-1", "world-1")

	_assert_not_null(loaded, "Should load progress")
	_assert_eq(loaded.collectibles.get("coin", 0), 10, "Should preserve collectible count")


func test_clone_world() -> void:
	_mock_event_bus._emitted_events.clear()
	var project = Project.new("proj-1", "Test Project")
	var source_world = World.new("world-1", "Original")
	var node = SceneNode.new("node-1", SceneNode.NodeType.OBJECT)
	source_world.add_node(node)
	project.add_world(source_world)

	var cloned = _service.clone_world(project, source_world, "Clone")

	_assert_not_null(cloned, "Should return cloned world")
	_assert_ne(cloned.world_id, source_world.world_id, "Clone should have unique ID")
	_assert_eq(cloned.name, "Clone", "Clone should use provided name")
	_assert_eq(cloned.scene_nodes.size(), 1, "Clone should preserve node count")


func test_remix_world_reset_progress() -> void:
	_mock_event_bus._emitted_events.clear()
	_mock_progress_store.setup_progress("profile-1", "world-1", ProgressState.new())

	var result = _service.remix_world_reset_progress("profile-1", "world-1")

	_assert_true(result, "Should reset progression")
	_assert_eq(_mock_event_bus._emitted_events.size(), 1, "Should emit remix event")


# =============================================================================
# Mock implementations
# =============================================================================

class MockSessionProgressStore extends SessionProgressStorePort:
	var _progress_map: Dictionary = {}
	var _saved_count: int = 0

	func setup_progress(profile_id: String, world_id: String, progress: ProgressState) -> void:
		var key = "%s:%s" % [profile_id, world_id]
		_progress_map[key] = progress

	func save_progress(profile_id: String, world_id: String, progress: ProgressState) -> bool:
		_saved_count += 1
		var key = "%s:%s" % [profile_id, world_id]
		_progress_map[key] = progress
		return true

	func load_progress(profile_id: String, world_id: String) -> ProgressState:
		var key = "%s:%s" % [profile_id, world_id]
		return _progress_map.get(key, ProgressState.new())

	func clear_progress(profile_id: String, world_id: String) -> bool:
		var key = "%s:%s" % [profile_id, world_id]
		if key in _progress_map:
			_progress_map.erase(key)
			return true
		return false

	func list_player_progress(profile_id: String) -> Array:
		var results = []
		for key in _progress_map.keys():
			if key.begins_with(profile_id):
				results.append(_progress_map[key])
		return results


class MockEventBus extends DomainEventBus:
	var _emitted_events: Array = []

	func emit(event: DomainEvent) -> void:
		_emitted_events.append(event)
