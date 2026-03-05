class_name PolishFirstLanguagePolicyServiceContractTest
extends PortContractTest


class MockLocalization:
	extends LocalizationPolicyPort

	var locale: String = "pl-PL"

	func get_locale() -> String:
		return locale

	func translate(key: String) -> String:
		return key

	func is_term_safe(_term: String) -> bool:
		return true


func run() -> Dictionary:
	_reset()

	var service_script_variant: Variant = load("res://src/application/polish_first_language_policy_service.gd")
	_assert_true(service_script_variant is Script, "Language policy service script should load")
	if not (service_script_variant is Script):
		return _build_result("PolishFirstLanguagePolicyService")
	var service_script: Script = service_script_variant

	var localization := MockLocalization.new()
	localization.locale = "en-US"
	var policy_store := InMemoryParentalPolicyStore.new().setup()
	var service: Variant = service_script.new().setup(localization, policy_store)

	var kid := PlayerProfile.new("kid-lang", PlayerProfile.Role.KID)
	kid.language = "en-US"
	_assert_true(
		str(service.call("resolve_locale", kid)) == "pl-PL",
		"Kid locale should stay Polish even when profile locale is non-Polish"
	)

	var parent := PlayerProfile.new("parent-lang", PlayerProfile.Role.PARENT)
	parent.language = "en-US"
	_assert_true(
		str(service.call("resolve_locale", parent)) == "pl-PL",
		"Parent should remain Polish without explicit language override"
	)

	policy_store.save_policy(
		"parent-lang",
		ParentalControlPolicy.new(
			60,
			30,
			ParentalControlPolicy.AIAccessLevel.CREATIVE_ONLY,
			false,
			true,
			false
		)
	)
	_assert_true(
		str(service.call("resolve_locale", parent)) == "en-US",
		"Parent override should permit non-Polish locale"
	)

	parent.language = ""
	localization.locale = "de-DE"
	_assert_true(
		str(service.call("resolve_locale", parent)) == "de-DE",
		"When override is enabled and parent language is empty, localization locale should be used"
	)

	return _build_result("PolishFirstLanguagePolicyService")
