class_name PolishLocalizationPolicyAdapterContractTest
extends PortContractTest


func run() -> Dictionary:
	_reset()
	var policy := PolishLocalizationPolicy.new()

	_assert_has_method(policy, "get_locale")
	_assert_has_method(policy, "translate")
	_assert_has_method(policy, "is_term_safe")

	var locale := policy.get_locale()
	_assert_string(locale, "PolishLocalizationPolicy.get_locale()")
	_assert_true(
		locale == "pl-PL",
		"PolishLocalizationPolicy should default to pl-PL"
	)

	var known_translation := policy.translate("ui.home.create")
	_assert_string(
		known_translation,
		"PolishLocalizationPolicy.translate(known_key)"
	)
	_assert_true(
		known_translation == "Tworz",
		"Known translation key should map to Polish label"
	)

	var unknown_translation := policy.translate("ui.unknown.key")
	_assert_string(
		unknown_translation,
		"PolishLocalizationPolicy.translate(unknown_key)"
	)
	_assert_true(
		unknown_translation == "ui.unknown.key",
		"Unknown translation should fallback to key"
	)

	_assert_false(
		policy.is_term_safe("narkotyk"),
		"Unsafe glossary term should be blocked"
	)
	_assert_true(
		policy.is_term_safe("przygoda"),
		"Safe Polish term should be allowed"
	)
	_assert_false(
		policy.is_term_safe(""),
		"Empty term should be treated as unsafe"
	)

	return _build_result("PolishLocalizationPolicyAdapter")
