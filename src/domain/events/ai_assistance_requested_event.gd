## Emitted when a user (kid or parent) requests AI help.
## Captures the prompt envelope and intent for audit observability.
class_name AIAssistanceRequestedEvent
extends DomainEvent

var session_id: String
var prompt_envelope: PromptEnvelope
var intent_summary: String


func _init(p_session_id: String = "", p_actor: String = "", p_timestamp: String = "") -> void:
	super._init("AIAssistanceRequested", p_actor, p_timestamp)
	session_id = p_session_id
	prompt_envelope = PromptEnvelope.new()
	intent_summary = ""
