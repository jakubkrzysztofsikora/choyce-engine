## Application test: ManageEconomyService
## Validates economy parameter editing, diff generation, and auditable saves.
class_name TestManageEconomyService
extends ApplicationTest


var _service: ManageEconomyService
var _mock_economy_store: MockGameEconomyStore
var _mock_event_bus: MockEventBus


func _init() -> void:
	_mock_economy_store = MockGameEconomyStore.new()
	_mock_event_bus = MockEventBus.new()
	_service = ManageEconomyService.new().setup(_mock_economy_store, _mock_event_bus)


func run() -> Dictionary:
	test_load_default_economy()
	test_load_saved_economy()
	test_adjust_single_parameter()
	test_adjust_out_of_bounds_parameter()
	test_get_economy_diff()
	test_save_economy_emits_event()
	test_reset_economy_to_defaults()
	return _build_result("ManageEconomyService")


func test_load_default_economy() -> void:
	var economy = _service.load_world_economy("world-1")

	_assert_not_null(economy, "Should load/create economy")
	_assert_eq(economy.world_id, "world-1", "Economy should have correct world ID")
	_assert_true(economy.prices.size() > 0, "Should have default prices")
	_assert_true(economy.spawn_rates.size() > 0, "Should have default spawn rates")
	_assert_true(economy.progression_multipliers.size() > 0, "Should have default multipliers")


func test_load_saved_economy() -> void:
	var original = GameEconomy.new("world-1")
	original.set_parameter("prices", "cosmetic_hat", 150.0)
	_mock_economy_store.save_economy("world-1", original)

	var loaded = _service.load_world_economy("world-1")

	_assert_not_null(loaded, "Should load saved economy")
	var param = loaded.get_parameter("prices", "cosmetic_hat")
	_assert_eq(param.current_value, 150.0, "Should preserve adjusted value")


func test_adjust_single_parameter() -> void:
	var result = _service.adjust_parameter("world-1", "spawn_rates", "coin_spawn_rate", 2.0)

	_assert_true(result, "Should successfully adjust parameter")


func test_adjust_out_of_bounds_parameter() -> void:
	var result = _service.adjust_parameter("world-1", "spawn_rates", "coin_spawn_rate", 100.0)

	_assert_false(result, "Should reject out-of-bounds value")


func test_get_economy_diff() -> void:
	_mock_economy_store._economies.clear()
	var economy = _service.load_world_economy("world-2")
	_mock_economy_store.save_economy("world-2", economy)

	economy.set_parameter("prices", "cosmetic_hat", 200.0)
	economy.set_parameter("spawn_rates", "npc_spawn_rate", 2.5)
	_mock_economy_store.save_economy("world-2", economy)

	var diff = _service.get_economy_diff("world-2")

	_assert_eq(diff.size(), 2, "Should detect 2 modifications")
	_assert_true(_contains_adjustment(diff, "prices", "cosmetic_hat"), "Should include price adjustment")
	_assert_true(_contains_adjustment(diff, "spawn_rates", "npc_spawn_rate"), "Should include spawn rate adjustment")


func test_save_economy_emits_event() -> void:
	_mock_event_bus._emitted_events.clear()
	var economy = GameEconomy.new("world-1")
	economy.set_parameter("progression_multipliers", "coin_multiplier", 1.5)

	var result = _service.save_economy("world-1", economy)

	_assert_true(result, "Should save economy")
	_assert_eq(_mock_event_bus._emitted_events.size(), 1, "Should emit audit event")
	var event = _mock_event_bus._emitted_events[0]
	_assert_true(event is EconomyAdjustedEvent, "Should emit EconomyAdjustedEvent")


func test_reset_economy_to_defaults() -> void:
	_mock_event_bus._emitted_events.clear()
	var economy = _service.load_world_economy("world-1")
	economy.set_parameter("prices", "cosmetic_outfit", 750.0)

	var result = _service.reset_economy_to_defaults("world-1")

	_assert_true(result, "Should reset economy")
	var reset_economy = _service.load_world_economy("world-1")
	var param = reset_economy.get_parameter("prices", "cosmetic_outfit")
	_assert_eq(param.current_value, 500.0, "Should restore default value")


func _contains_adjustment(diff: Array, category: String, name: String) -> bool:
	for item in diff:
		if item.get("category") == category and item.get("name") == name:
			return true
	return false


# =============================================================================
# Mock implementations
# =============================================================================

class MockGameEconomyStore extends GameEconomyStorePort:
	var _economies: Dictionary = {}

	func save_economy(world_id: String, economy: GameEconomy) -> bool:
		_economies[world_id] = economy
		return true

	func load_economy(world_id: String) -> GameEconomy:
		return _economies.get(world_id)

	func list_economies() -> Array:
		return _economies.values()

	func delete_economy(world_id: String) -> bool:
		if world_id in _economies:
			_economies.erase(world_id)
			return true
		return false


class MockEventBus extends DomainEventBus:
	var _emitted_events: Array = []

	func emit(event: DomainEvent) -> void:
		_emitted_events.append(event)
