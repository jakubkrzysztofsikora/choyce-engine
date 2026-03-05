## Application test: RemixWorldService
## Validates world progression reset and balance tweak application.
class_name TestRemixWorldService
extends ApplicationTest


var _service: RemixWorldService
var _mock_progress_store: MockSessionProgressStore
var _mock_event_bus: MockEventBus


func _init() -> void:
	_mock_progress_store = MockSessionProgressStore.new()
	_mock_event_bus = MockEventBus.new()
	_service = RemixWorldService.new().setup(_mock_progress_store, _mock_event_bus)


func run() -> Dictionary:
	test_reset_player_progress()
	test_reset_nonexistent_progress()
	test_reset_emits_event()
	test_apply_balance_tweaks_spawn_rate()
	test_apply_balance_tweaks_collectible_multiplier()
	return _build_result("RemixWorldService")


func test_reset_player_progress() -> void:
	_mock_event_bus._emitted_events.clear()
	_mock_progress_store.setup_progress("profile-1", "world-1", ProgressState.new())

	var result = _service.reset_player_progress("profile-1", "world-1")

	_assert_true(result, "Reset should succeed for existing progress")
	_assert_eq(_mock_progress_store._cleared_count, 1, "Should call clear_progress on store")


func test_reset_nonexistent_progress() -> void:
	_mock_event_bus._emitted_events.clear()
	var result = _service.reset_player_progress("profile-1", "nonexistent-world")

	_assert_false(result, "Reset should fail for nonexistent progress")


func test_reset_emits_event() -> void:
	_mock_event_bus._emitted_events.clear()
	_mock_progress_store.setup_progress("profile-1", "world-1", ProgressState.new())

	_service.reset_player_progress("profile-1", "world-1")

	_assert_eq(_mock_event_bus._emitted_events.size(), 1, "Should emit one event")
	var emitted_event = _mock_event_bus._emitted_events[0]
	_assert_true(emitted_event is WorldRemixedEvent, "Should emit WorldRemixedEvent")
	_assert_eq(emitted_event.world_id, "world-1", "Event should reference world ID")
	_assert_eq(emitted_event.profile_id, "profile-1", "Event should reference profile ID")


func test_apply_balance_tweaks_spawn_rate() -> void:
	_mock_event_bus._emitted_events.clear()
	var world = World.new("world-1", "Test")
	var spawn_rule = GameRule.new("rule-1", GameRule.RuleType.ITEM_SPAWN)
	world.add_rule(spawn_rule)

	var tweaks = {"spawn_rate": 1.5}
	var result = _service.apply_balance_tweaks(world, tweaks)

	_assert_true(result, "Should apply tweaks successfully")
	_assert_eq(spawn_rule.properties.get("spawn_rate"), 1.5, "Should update spawn_rate")


func test_apply_balance_tweaks_collectible_multiplier() -> void:
	_mock_event_bus._emitted_events.clear()
	var world = World.new("world-1", "Test")
	var score_rule = GameRule.new("rule-1", GameRule.RuleType.SCORING)
	world.add_rule(score_rule)

	var tweaks = {"collectible_multiplier": 2.0}
	var result = _service.apply_balance_tweaks(world, tweaks)

	_assert_true(result, "Should apply tweaks successfully")
	_assert_eq(score_rule.properties.get("collectible_multiplier"), 2.0, "Should update collectible_multiplier")


# =============================================================================
# Mock implementations
# =============================================================================

class MockSessionProgressStore extends SessionProgressStorePort:
	var _progress_map: Dictionary = {}
	var _cleared_count: int = 0

	func setup_progress(profile_id: String, world_id: String, progress: ProgressState) -> void:
		var key = "%s:%s" % [profile_id, world_id]
		_progress_map[key] = progress

	func save_progress(profile_id: String, world_id: String, progress: ProgressState) -> bool:
		var key = "%s:%s" % [profile_id, world_id]
		_progress_map[key] = progress
		return true

	func load_progress(profile_id: String, world_id: String) -> ProgressState:
		var key = "%s:%s" % [profile_id, world_id]
		return _progress_map.get(key, ProgressState.new())

	func clear_progress(profile_id: String, world_id: String) -> bool:
		var key = "%s:%s" % [profile_id, world_id]
		if key in _progress_map:
			_cleared_count += 1
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
