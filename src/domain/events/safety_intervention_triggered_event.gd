## Emitted when a safety policy blocks or escalates content.
## Logged to the tamper-evident audit ledger and surfaced
## in the parent audit timeline dashboard.
class_name SafetyInterventionTriggeredEvent
extends DomainEvent

var decision_id: String
var decision_type: String  # "BLOCK" or "ESCALATE_TO_PARENT"
var policy_rule: String
var trigger_context: String
var safe_alternative_offered: bool


func _init(p_decision_id: String = "", p_actor: String = "", p_timestamp: String = "") -> void:
	super._init("SafetyInterventionTriggered", p_actor, p_timestamp)
	decision_id = p_decision_id
	decision_type = ""
	policy_rule = ""
	trigger_context = ""
	safe_alternative_offered = false
