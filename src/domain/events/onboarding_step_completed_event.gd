## Domain event: An onboarding step was completed.
## Emitted by OnboardingService when the player fulfills a step's requirement.
class_name OnboardingStepCompletedEvent
extends DomainEvent

var step_id: String


func _init(p_step_id: String = "", p_actor: String = "", p_timestamp: String = "") -> void:
	super._init("OnboardingStepCompleted", p_actor, p_timestamp)
	step_id = p_step_id
	payload = {"step_id": step_id}
