class_name LocalizationPolicyPortContractTest
extends PortContractTest


func run() -> Dictionary:
	_reset()
	var port := LocalizationPolicyPort.new()

	_assert_has_method(port, "get_locale")
	_assert_has_method(port, "translate")
	_assert_has_method(port, "is_term_safe")

	var locale := port.get_locale()
	_assert_string(locale, "LocalizationPolicyPort.get_locale()")

	var translated := port.translate("ui.home.create")
	_assert_string(translated, "LocalizationPolicyPort.translate(key)")

	var translated_empty := port.translate("")
	_assert_string(translated_empty, "LocalizationPolicyPort.translate(empty_key)")

	var term_safe := port.is_term_safe("bezpieczny")
	_assert_false(term_safe, "LocalizationPolicyPort.is_term_safe(term)")

	var term_safe_empty := port.is_term_safe("")
	_assert_false(
		term_safe_empty,
		"LocalizationPolicyPort.is_term_safe(empty_term)"
	)

	return _build_result("LocalizationPolicyPort")
