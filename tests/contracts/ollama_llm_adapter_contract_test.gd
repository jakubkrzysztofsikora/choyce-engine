class_name OllamaLLMAdapterContractTest
extends PortContractTest


class MockConsentPort:
	extends IdentityConsentPort

	var _consents: Dictionary = {}

	func has_consent(profile_id: String, consent_type: String) -> bool:
		if not _consents.has(profile_id):
			return false
		var granted: Array = _consents[profile_id]
		return granted.has(consent_type)

	func request_consent(profile_id: String, consent_type: String) -> bool:
		if profile_id.strip_edges().is_empty() or consent_type.strip_edges().is_empty():
			return false
		if not _consents.has(profile_id):
			_consents[profile_id] = []
		var granted: Array = _consents[profile_id]
		if not granted.has(consent_type):
			granted.append(consent_type)
		_consents[profile_id] = granted
		return true


class MockCloudLLM:
	extends LLMPort

	func complete(_envelope: PromptEnvelope) -> String:
		return "CLOUD_COMPLETION"

	func complete_with_tools(_envelope: PromptEnvelope) -> Array[ToolInvocation]:
		return [ToolInvocation.new("logic_edit", {"operation": "cloud_apply"}, "cloud_1")]


func run() -> Dictionary:
	_reset()

	var consent := MockConsentPort.new()
	var cloud := MockCloudLLM.new()
	var adapter := OllamaLLMAdapter.new().setup(consent, cloud, true)

	_assert_has_method(adapter, "complete")
	_assert_has_method(adapter, "complete_with_tools")
	_assert_has_method(adapter, "get_model_catalog")
	_assert_has_method(adapter, "set_allow_cloud_fallback")
	_assert_has_method(adapter, "set_simulate_local_failure_for_tests")

	var envelope := PromptEnvelope.new("Dodaj drzewo obok domu.")
	envelope.context_tags = ["profile_id:kid-1"]
	var completion := adapter.complete(envelope)
	_assert_string(completion, "OllamaLLMAdapter.complete(envelope)")
	_assert_true(
		completion.contains("[ollama:"),
		"OllamaLLMAdapter should return local completion when local model succeeds"
	)
	_assert_true(
		adapter.get_last_selected_tier() == "small",
		"OllamaLLMAdapter should use small tier for simple completion prompts"
	)

	var tools_envelope := PromptEnvelope.new("Zmien kolor domku na zółty.")
	tools_envelope.context_tags = ["profile_id:kid-1"]
	tools_envelope.permitted_tools = ["paint", "scene_edit"]
	var tools := adapter.complete_with_tools(tools_envelope)
	_assert_tool_invocation_array(tools, "OllamaLLMAdapter.complete_with_tools(envelope)")
	_assert_true(
		tools.size() == 1 and tools[0].tool_name == "paint",
		"OllamaLLMAdapter should produce deterministic paint tool invocation"
	)
	_assert_true(
		adapter.get_last_selected_tier() == "medium",
		"OllamaLLMAdapter should use medium tier for tool planning"
	)

	adapter.set_simulate_local_failure_for_tests(true)
	var no_consent_completion := adapter.complete(envelope)
	_assert_true(
		no_consent_completion != "CLOUD_COMPLETION",
		"OllamaLLMAdapter should not use cloud fallback without consent"
	)
	_assert_true(
		adapter.get_last_provider() == "fallback",
		"OllamaLLMAdapter should report fallback provider without consent"
	)

	_assert_true(
		consent.request_consent("kid-1", "cloud_llm"),
		"MockConsentPort.request_consent should grant cloud_llm consent"
	)
	var with_consent_completion := adapter.complete(envelope)
	_assert_true(
		with_consent_completion == "CLOUD_COMPLETION",
		"OllamaLLMAdapter should use cloud fallback when consent is present"
	)
	_assert_true(
		adapter.get_last_provider() == "cloud",
		"OllamaLLMAdapter should report cloud provider when cloud fallback is used"
	)

	var cloud_tools := adapter.complete_with_tools(tools_envelope)
	_assert_true(
		cloud_tools.size() == 1 and cloud_tools[0].tool_name == "logic_edit",
		"OllamaLLMAdapter should return cloud tools when local planning fails and consent exists"
	)

	return _build_result("OllamaLLMAdapter")
