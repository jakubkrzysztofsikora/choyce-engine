## In-domain event bus for cross-context communication.
## Keeps event routing inside the domain boundary without requiring Node/scene APIs.
class_name DomainEventBus
extends RefCounted

var _subscribers_by_type: Dictionary = {}
var _subscribers_all: Array[Callable] = []
var _history: Array[DomainEvent] = []
var _max_history: int = 500


func _init(max_history: int = 500) -> void:
	setup(max_history)


func setup(max_history: int = 500) -> DomainEventBus:
	_subscribers_by_type = {}
	_subscribers_all = []
	_history = []
	_max_history = maxi(1, max_history)
	return self


func subscribe(event_type: String, handler: Callable) -> bool:
	if event_type.strip_edges().is_empty() or not handler.is_valid():
		return false

	var key := event_type.strip_edges()
	if not _subscribers_by_type.has(key):
		_subscribers_by_type[key] = []

	var subscribers: Array = _subscribers_by_type[key]
	for existing in subscribers:
		if existing == handler:
			return true

	subscribers.append(handler)
	_subscribers_by_type[key] = subscribers
	return true


func subscribe_all(handler: Callable) -> bool:
	if not handler.is_valid():
		return false
	for existing in _subscribers_all:
		if existing == handler:
			return true
	_subscribers_all.append(handler)
	return true


func unsubscribe(event_type: String, handler: Callable) -> bool:
	var key := event_type.strip_edges()
	if key.is_empty() or not _subscribers_by_type.has(key):
		return false

	var subscribers: Array = _subscribers_by_type[key]
	for i in range(subscribers.size()):
		if subscribers[i] == handler:
			subscribers.remove_at(i)
			_subscribers_by_type[key] = subscribers
			return true
	return false


func unsubscribe_all(handler: Callable) -> bool:
	for i in range(_subscribers_all.size()):
		if _subscribers_all[i] == handler:
			_subscribers_all.remove_at(i)
			return true
	return false


func emit(event: DomainEvent) -> void:
	if event == null:
		return

	_record(event)

	for handler in _subscribers_all:
		if handler.is_valid():
			handler.call(event)

	var key := event.event_type.strip_edges()
	if _subscribers_by_type.has(key):
		var subscribers: Array = _subscribers_by_type[key]
		for handler in subscribers:
			if handler.is_valid():
				handler.call(event)


func get_history(event_type: String = "") -> Array[DomainEvent]:
	var key := event_type.strip_edges()
	if key.is_empty():
		return _history.duplicate()

	var filtered: Array[DomainEvent] = []
	for event in _history:
		if event.event_type == key:
			filtered.append(event)
	return filtered


func clear_history() -> void:
	_history = []


func subscriber_count(event_type: String = "") -> int:
	var key := event_type.strip_edges()
	if key.is_empty():
		return _subscribers_all.size()
	if not _subscribers_by_type.has(key):
		return 0
	var subscribers: Array = _subscribers_by_type[key]
	return subscribers.size()


func _record(event: DomainEvent) -> void:
	_history.append(event)
	if _history.size() <= _max_history:
		return

	var overflow := _history.size() - _max_history
	for _i in range(overflow):
		_history.remove_at(0)
