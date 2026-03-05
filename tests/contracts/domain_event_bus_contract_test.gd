class_name DomainEventBusContractTest
extends PortContractTest

class EventCollector:
	extends RefCounted

	var events: Array[DomainEvent] = []

	func on_event(event: DomainEvent) -> void:
		events.append(event)


func run() -> Dictionary:
	_reset()
	var bus := DomainEventBus.new(3)

	_assert_has_method(bus, "subscribe")
	_assert_has_method(bus, "subscribe_all")
	_assert_has_method(bus, "unsubscribe")
	_assert_has_method(bus, "emit")
	_assert_has_method(bus, "get_history")

	var world_collector := EventCollector.new()
	var all_collector := EventCollector.new()
	_assert_true(
		bus.subscribe("WorldEdited", Callable(world_collector, "on_event")),
		"DomainEventBus.subscribe(WorldEdited, handler) should return true"
	)
	_assert_true(
		bus.subscribe_all(Callable(all_collector, "on_event")),
		"DomainEventBus.subscribe_all(handler) should return true"
	)

	bus.emit(WorldEditedEvent.new("w1", "node_added", "kid-1", "2026-03-02T12:00:00Z"))
	bus.emit(RuleChangedEvent.new("r1", "created", "kid-1", "2026-03-02T12:00:01Z"))
	bus.emit(AIAssistanceRequestedEvent.new("s1", "kid-1", "2026-03-02T12:00:02Z"))
	bus.emit(SafetyInterventionTriggeredEvent.new("d1", "kid-1", "2026-03-02T12:00:03Z"))

	_assert_true(
		world_collector.events.size() == 1,
		"World event collector should receive only matching event type"
	)
	_assert_true(
		all_collector.events.size() == 4,
		"Wildcard collector should receive all emitted events"
	)

	var full_history := bus.get_history()
	_assert_array(full_history, "DomainEventBus.get_history()")
	_assert_true(full_history.size() == 3, "History should honor max history cap")

	var world_history := bus.get_history("WorldEdited")
	_assert_array(world_history, "DomainEventBus.get_history(WorldEdited)")
	_assert_true(
		world_history.is_empty(),
		"Capped history should trim oldest entries when over max history"
	)

	_assert_true(
		bus.unsubscribe("WorldEdited", Callable(world_collector, "on_event")),
		"DomainEventBus.unsubscribe(WorldEdited, handler) should return true"
	)
	bus.emit(WorldEditedEvent.new("w2", "node_removed", "kid-1", "2026-03-02T12:00:04Z"))
	_assert_true(
		world_collector.events.size() == 1,
		"Unsubscribed collector should no longer receive events"
	)

	return _build_result("DomainEventBus")
