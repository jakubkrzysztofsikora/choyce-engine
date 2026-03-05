## Outbound port contract for consent and profile permission checks.
## Consent decisions are enforced by policy-aware application services.
class_name IdentityConsentPort
extends RefCounted


func has_consent(profile_id: String, consent_type: String) -> bool:
	push_error("IdentityConsentPort.has_consent() not implemented")
	return false


func request_consent(profile_id: String, consent_type: String) -> bool:
	push_error("IdentityConsentPort.request_consent() not implemented")
	return false
