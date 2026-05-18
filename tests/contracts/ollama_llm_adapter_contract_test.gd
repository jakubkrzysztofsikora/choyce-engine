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

	func complete(
		envelope: PromptEnvelope,
		_options: Dictionary,
		_on_token: Callable,
		on_done: Callable
	) -> void:
		on_done.call({"text": "CLOUD_COMPLETION", "provider": "cloud", "model": "cloud-model", "stopped": false})

	func complete_with_tools(_envelope: PromptEnvelope) -> Array[ToolInvocation]:
		return [ToolInvocation.new("logic_edit", {"operation": "cloud_apply"}, "cloud_1")]


func run() -> Dictionary:
	_reset()

	var consent := MockConsentPort.new()
	var cloud := MockCloudLLM.new()
	var adapter := OllamaLLMAdapter.new().setup(consent, cloud, true)
	adapter.set_mock_mode(true)

	_assert_has_method(adapter, "complete")
	_assert_has_method(adapter, "complete_with_tools")
	_assert_has_method(adapter, "cancel")
	_assert_has_method(adapter, "get_model_catalog")
	_assert_has_method(adapter, "set_allow_cloud_fallback")
	_assert_has_method(adapter, "set_simulate_local_failure_for_tests")

	# --- complete() mock-mode: on_done called synchronously ---
	var envelope := PromptEnvelope.new("Dodaj drzewo obok domu.")
	envelope.context_tags = ["profile_id:kid-1"]

	var completion_text := ""
	adapter.complete(
		envelope,
		{},
		func(_token: String) -> void: pass,
		func(result: Dictionary) -> void:
			completion_text = result.get("text", "")
	)
	_assert_string(completion_text, "OllamaLLMAdapter.complete() — mock on_done text")
	_assert_true(
		completion_text.contains("[ollama:"),
		"OllamaLLMAdapter should return local completion when local model succeeds"
	)
	_assert_true(
		adapter.get_last_selected_tier() == "small",
		"OllamaLLMAdapter should use small tier for simple completion prompts"
	)

	# --- complete_with_tools ---
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

	# --- simulate_local_failure with no consent: fallback ---
	adapter.set_simulate_local_failure_for_tests(true)
	var fallback_text := ""
	var fallback_provider := ""
	adapter.complete(
		envelope,
		{},
		func(_token: String) -> void: pass,
		func(result: Dictionary) -> void:
			fallback_text = result.get("text", "")
			fallback_provider = result.get("provider", "")
	)
	_assert_true(
		fallback_text != "CLOUD_COMPLETION",
		"OllamaLLMAdapter should not use cloud fallback without consent"
	)
	_assert_true(
		adapter.get_last_provider() == "fallback",
		"OllamaLLMAdapter should report fallback provider without consent"
	)

	# --- simulate_local_failure with cloud consent: cloud called ---
	_assert_true(
		consent.request_consent("kid-1", "cloud_llm"),
		"MockConsentPort.request_consent should grant cloud_llm consent"
	)
	var cloud_text := ""
	var cloud_provider_from_done := ""
	adapter.complete(
		envelope,
		{},
		func(_token: String) -> void: pass,
		func(result: Dictionary) -> void:
			cloud_text = result.get("text", "")
			cloud_provider_from_done = result.get("provider", "")
	)
	_assert_true(
		cloud_text == "CLOUD_COMPLETION",
		"OllamaLLMAdapter should use cloud fallback when consent is present"
	)
	_assert_true(
		adapter.get_last_provider() == "cloud",
		"OllamaLLMAdapter should report cloud provider when cloud fallback is used"
	)

	# --- cloud complete_with_tools ---
	var cloud_tools := adapter.complete_with_tools(tools_envelope)
	_assert_true(
		cloud_tools.size() == 1 and cloud_tools[0].tool_name == "logic_edit",
		"OllamaLLMAdapter should return cloud tools when local planning fails and consent exists"
	)

	# --- cancel() in mock mode does not crash ---
	adapter.set_simulate_local_failure_for_tests(false)
	adapter.cancel()

	return _build_result("OllamaLLMAdapter")
