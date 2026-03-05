## Emitted when an AI-proposed action is applied to the world.
## Carries the action details, tool invocations, and the reversible
## patch for undo support. Part of the mandatory audit trail.
class_name AIAssistanceAppliedEvent
extends DomainEvent

var action_id: String
var tool_invocations_count: int
var impact_level: String
var was_parent_approved: bool
var reversible_patch_keys: Array[String]


func _init(p_action_id: String = "", p_actor: String = "", p_timestamp: String = "") -> void:
	super._init("AIAssistanceApplied", p_actor, p_timestamp)
	action_id = p_action_id
	tool_invocations_count = 0
	impact_level = "LOW"
	was_parent_approved = false
	reversible_patch_keys = []
