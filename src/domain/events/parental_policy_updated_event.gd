## Domain event emitted when a parent changes their child's control policy.
## Captures the previous and new policy states plus the change type for
## the audit timeline and read model projections.
class_name ParentalPolicyUpdatedEvent
extends DomainEvent

var previous_policy: Dictionary
var new_policy: Dictionary
var change_type: String  # "initial_setup", "update", "reset_to_defaults"


func _init(p_actor_id: String = "", p_timestamp: String = "") -> void:
	super._init("ParentalPolicyUpdated", p_actor_id, p_timestamp)
	previous_policy = {}
	new_policy = {}
	change_type = ""
