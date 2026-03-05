## Base class for all domain events.
## Domain events are emitted within bounded contexts to signal
## significant state changes. They feed the event bus, CQRS read
## models, and the tamper-evident audit ledger.
class_name DomainEvent
extends RefCounted

## Monotonically increasing counter used to generate unique event IDs.
## Acts as a static-like class variable shared across all DomainEvent instances.
static var _next_sequence: int = 0

var event_id: String
var event_type: String
var timestamp: String  # ISO 8601
var actor_id: String
var payload: Dictionary


## p_timestamp is optional; callers that have access to a ClockPort should
## inject the authoritative ISO 8601 timestamp. When omitted (empty string),
## the event is created without a timestamp — the infrastructure layer
## (e.g., EventBus adapter) is expected to stamp it before persistence.
func _init(p_type: String = "", p_actor_id: String = "", p_timestamp: String = "") -> void:
	event_type = p_type
	event_id = _generate_event_id(event_type)
	timestamp = p_timestamp
	actor_id = p_actor_id
	payload = {}


static func _generate_event_id(p_event_type: String) -> String:
	var seq := _next_sequence
	_next_sequence += 1
	return "%s-%d" % [p_event_type, seq]
