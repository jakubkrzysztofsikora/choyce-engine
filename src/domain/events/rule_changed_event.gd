## Emitted when a game rule is created, modified, or deactivated.
## Used to trigger recompilation of block logic and to update
## the parent audit timeline.
class_name RuleChangedEvent
extends DomainEvent

var rule_id: String
var change_type: String  # "created", "modified", "deactivated", "activated"
var previous_state: Dictionary
var new_state: Dictionary


func _init(p_rule_id: String = "", p_change_type: String = "", p_actor: String = "", p_timestamp: String = "") -> void:
	super._init("RuleChanged", p_actor, p_timestamp)
	rule_id = p_rule_id
	change_type = p_change_type
	previous_state = {}
	new_state = {}
