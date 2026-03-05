class_name PromptTemplatePolicyIntegrationContractTest
extends PortContractTest


class MockLLM:
	extends LLMPort

	var planned_tools: Array[ToolInvocation] = [ToolInvocation.new("paint", {"color": "zielony"}, "tool-1")]
	var last_tool_prompt: String = ""
	var last_tool_locale: String = ""
	var last_complete_prompt: String = ""
	var last_complete_locale: String = ""

	func complete(envelope: PromptEnvelope) -> String:
		last_complete_prompt = envelope.prompt_text
		last_complete_locale = envelope.language
		return "Bezpieczna odpowiedz."

	func complete_with_tools(envelope: PromptEnvelope) -> Array[ToolInvocation]:
		last_tool_prompt = envelope.prompt_text
		last_tool_locale = envelope.language
		return planned_tools


class MockModeration:
	extends ModerationPort

	func check_text(_text: String, _age_band: AgeBand) -> ModerationResult:
		return ModerationResult.new(ModerationResult.Verdict.PASS, "")

	func check_image(_image_data: PackedByteArray, _age_band: AgeBand) -> ModerationResult:
		return ModerationResult.new(ModerationResult.Verdict.PASS, "")


class MockClock:
	extends ClockPort

	var _tick: int = 0

	func now_iso() -> String:
		_tick += 1
		return "2026-03-02T17:30:%02dZ" % _tick

	func now_msec() -> int:
		_tick += 1
		return 1767439800000 + _tick


class MockLocalization:
	extends LocalizationPolicyPort

	var locale: String = "en-US"

	func get_locale() -> String:
		return locale

	func translate(key: String) -> String:
		return key

	func is_term_safe(_term: String) -> bool:
		return true


func run() -> Dictionary:
	_reset()

	var llm := MockLLM.new()
	var moderation := MockModeration.new()
	var clock := MockClock.new()
	var localization := MockLocalization.new()
	var policy_store := InMemoryParentalPolicyStore.new().setup()
	var registry_script_variant: Variant = load("res://src/adapters/outbound/in_repo_prompt_template_registry.gd")
	_assert_true(registry_script_variant is Script, "InRepoPromptTemplateRegistry script should load")
	if not (registry_script_variant is Script):
		return _build_result("PromptTemplatePolicyIntegration")
	var registry_script: Script = registry_script_variant
	var registry: Variant = registry_script.new().setup(
		"res://data/ai/prompt_templates.json",
		"res://data/ai/prompt_regression_fixtures.json"
	)

	policy_store.save_policy(
		"parent-template",
		ParentalControlPolicy.new(
			60,
			30,
			ParentalControlPolicy.AIAccessLevel.CREATIVE_ONLY,
			false,
			true,
			false
		)
	)

	var creation_service := RequestAICreationHelpService.new().setup(
		llm,
		moderation,
		clock,
		localization,
		null,
		null,
		null,
		null,
		policy_store,
		null,
		registry
	)

	var kid := PlayerProfile.new("kid-template", PlayerProfile.Role.KID)
	kid.language = "en-US"
	creation_service.execute("session-kid", "Dodaj drzewo", kid)
	_assert_true(
		llm.last_tool_locale == "pl-PL",
		"Kid creation flow should keep Polish locale even when global locale is non-Polish"
	)
	_assert_true(
		llm.last_tool_prompt.to_lower().contains("pomagasz dziecku tworzyc bezpieczna gre"),
		"Kid creation prompt should use Polish kid template"
	)

	var parent := PlayerProfile.new("parent-template", PlayerProfile.Role.PARENT)
	parent.language = "en-US"
	creation_service.execute("session-parent", "Tune spawn rate", parent)
	_assert_true(
		llm.last_tool_locale == "en-US",
		"Parent creation flow should allow override locale when parental policy enables it"
	)
	_assert_true(
		llm.last_tool_prompt.to_lower().contains("family co-creation assistant"),
		"Parent creation prompt should use English parent template"
	)

	var hint_service := RequestGameplayHintService.new().setup(
		llm,
		moderation,
		clock,
		localization,
		null,
		null,
		policy_store,
		null,
		registry
	)

	hint_service.execute("hint-kid", {"hint_level": 1, "situation": "Brak monet"}, kid)
	_assert_true(
		llm.last_complete_locale == "pl-PL",
		"Kid hint flow should keep Polish locale"
	)
	_assert_true(
		llm.last_complete_prompt.to_lower().contains("jestes pomocnym towarzyszem gry"),
		"Kid hint prompt should use Polish gameplay hint template"
	)

	hint_service.execute("hint-parent", {"hint_level": 1, "situation": "Need help"}, parent)
	_assert_true(
		llm.last_complete_locale == "en-US",
		"Parent hint flow should allow override locale"
	)
	_assert_true(
		llm.last_complete_prompt.to_lower().contains("you are a gameplay mentor"),
		"Parent hint prompt should use English gameplay hint template"
	)

	return _build_result("PromptTemplatePolicyIntegration")
