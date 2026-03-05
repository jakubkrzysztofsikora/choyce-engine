## Emitted when an applied AI action is reverted through undo workflow.
## Complements AIAssistanceApplied for audit trails and parent timeline views.
class_name AIAssistanceRevertedEvent
extends DomainEvent

var action_id: String
var reverted_tokens_count: int
var impact_level: String


func _init(p_action_id: String = "", p_actor: String = "", p_timestamp: String = "") -> void:
	super._init("AIAssistanceReverted", p_actor, p_timestamp)
	action_id = p_action_id
	reverted_tokens_count = 0
	impact_level = "LOW"
