## Domain event: The active onboarding step changed.
## Emitted by OnboardingService when the flow transitions to a new step.
class_name OnboardingStepChangedEvent
extends DomainEvent

var step_id: String
var instruction_key: String


func _init(p_step_id: String = "", p_instruction_key: String = "", p_actor: String = "", p_timestamp: String = "") -> void:
	super._init("OnboardingStepChanged", p_actor, p_timestamp)
	step_id = p_step_id
	instruction_key = p_instruction_key
	payload = {
		"step_id": step_id,
		"instruction_key": instruction_key,
	}
