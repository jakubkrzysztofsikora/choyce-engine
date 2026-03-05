class_name InRepoPromptTemplateRegistryAdapterContractTest
extends PortContractTest


func run() -> Dictionary:
	_reset()
	var registry_script_variant: Variant = load("res://src/adapters/outbound/in_repo_prompt_template_registry.gd")
	_assert_true(registry_script_variant is Script, "InRepoPromptTemplateRegistry script should load")
	if not (registry_script_variant is Script):
		return _build_result("InRepoPromptTemplateRegistryAdapter")
	var registry_script: Script = registry_script_variant
	var registry: Variant = registry_script.new().setup(
		"res://data/ai/prompt_templates.json",
		"res://data/ai/prompt_regression_fixtures.json"
	)

	var kid_resolved: Dictionary = registry.call("resolve_template",
		"ai_creation_help",
		"en-US",
		"kid",
		"CHILD_6_8"
	)
	_assert_true(
		str(kid_resolved.get("locale", "")) == "pl-PL",
		"Kid prompt resolution should enforce Polish locale"
	)
	_assert_true(
		str(kid_resolved.get("version", "")) == "1.1.0",
		"Latest kid template version should be selected by default"
	)
	_assert_true(
		str(kid_resolved.get("system_prompt", "")).to_lower().contains("odwracalne"),
		"Kid template should come from the latest prompt revision"
	)

	var parent_resolved: Dictionary = registry.call("resolve_template",
		"ai_creation_help",
		"en-US",
		"parent",
		"PARENT"
	)
	_assert_true(
		str(parent_resolved.get("locale", "")) == "en-US",
		"Parent template may use non-Polish locale when requested"
	)
	_assert_true(
		str(parent_resolved.get("system_prompt", "")).to_lower().contains("family co-creation"),
		"Parent English template should be resolved when available"
	)

	var pinned: Dictionary = registry.call("resolve_template",
		"ai_creation_help",
		"pl-PL",
		"kid",
		"CHILD_6_8",
		"1.0.0"
	)
	_assert_true(
		str(pinned.get("version", "")) == "1.0.0",
		"Explicit template version should be respected"
	)

	var versions: Array = registry.call("list_versions", "ai_creation_help")
	_assert_true(
		versions.size() >= 2,
		"Version listing should expose multiple revisions for ai_creation_help"
	)
	_assert_true(
		str(versions[0]) == "1.1.0",
		"Version listing should be sorted from newest to oldest"
	)

	var fixtures: Array = registry.call("get_regression_fixtures", "ai_creation_help")
	_assert_true(
		fixtures.size() >= 2,
		"Regression fixture list should return use-case scoped fixtures"
	)

	return _build_result("InRepoPromptTemplateRegistryAdapter")
