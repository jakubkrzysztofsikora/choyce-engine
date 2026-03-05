## Outbound port for versioned AI prompt templates and regression fixtures.
## Templates are resolved by use-case, locale, role, and age-band policy.
class_name PromptTemplateRegistryPort
extends RefCounted


func resolve_template(
	use_case: String,
	locale: String,
	role: String,
	age_band: String,
	version: String = "latest"
) -> Dictionary:
	push_error("PromptTemplateRegistryPort.resolve_template() not implemented")
	return {
		"template_id": "",
		"use_case": use_case,
		"version": "",
		"locale": "pl-PL",
		"role": role,
		"age_band": age_band,
		"system_prompt": "",
		"user_prefix": "",
	}


func list_versions(use_case: String) -> Array[String]:
	push_error("PromptTemplateRegistryPort.list_versions() not implemented")
	var versions: Array[String] = []
	return versions


func get_regression_fixtures(use_case: String = "") -> Array[Dictionary]:
	push_error("PromptTemplateRegistryPort.get_regression_fixtures() not implemented")
	var fixtures: Array[Dictionary] = []
	return fixtures
