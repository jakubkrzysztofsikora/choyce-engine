## Domain event: Onboarding (first-time user experience) completed.
## Emitted by OnboardingService when the player finishes all tutorial steps.
class_name OnboardingFinishedEvent
extends DomainEvent

var profile_id: String


func _init(p_profile_id: String = "", p_timestamp: String = "") -> void:
	super._init("OnboardingFinished", p_profile_id, p_timestamp)
	profile_id = p_profile_id
	payload = {"profile_id": profile_id}
