## Outbound port contract for localization and terminology policy.
## Adapters provide locale, translations, and glossary safety checks.
class_name LocalizationPolicyPort
extends RefCounted


func get_locale() -> String:
	push_error("LocalizationPolicyPort.get_locale() not implemented")
	return "pl-PL"


func translate(key: String) -> String:
	push_error("LocalizationPolicyPort.translate() not implemented")
	return key


func is_term_safe(term: String) -> bool:
	push_error("LocalizationPolicyPort.is_term_safe() not implemented")
	return false
