class_name PromptTemplateRegistryPortContractTest
extends PortContractTest


func run() -> Dictionary:
	_reset()
	var port_script_variant: Variant = load("res://src/ports/outbound/prompt_template_registry_port.gd")
	_assert_true(port_script_variant is Script, "PromptTemplateRegistryPort script should load")
	if not (port_script_variant is Script):
		return _build_result("PromptTemplateRegistryPort")
	var port_script: Script = port_script_variant
	var port: Variant = port_script.new()

	_assert_has_method(port, "resolve_template")
	_assert_has_method(port, "list_versions")
	_assert_has_method(port, "get_regression_fixtures")

	var resolved: Dictionary = port.call("resolve_template",
		"ai_creation_help",
		"en-US",
		"kid",
		"CHILD_6_8"
	)
	_assert_dictionary(resolved, "PromptTemplateRegistryPort.resolve_template(...)")
	_assert_true(
		str(resolved.get("locale", "")) == "pl-PL",
		"Port fallback locale should stay Polish by default"
	)

	var versions: Array = port.call("list_versions", "ai_creation_help")
	_assert_array(versions, "PromptTemplateRegistryPort.list_versions(use_case)")

	var fixtures: Array = port.call("get_regression_fixtures", "ai_creation_help")
	_assert_array(fixtures, "PromptTemplateRegistryPort.get_regression_fixtures(use_case)")

	return _build_result("PromptTemplateRegistryPort")
