class_name LiteLLMAdapterContractTest
extends PortContractTest


func run() -> Dictionary:
	_reset()

	var adapter := LiteLLMAdapter.new().setup()
	adapter.set_mock_mode(true)

	_assert_has_method(adapter, "complete")
	_assert_has_method(adapter, "complete_with_tools")
	_assert_has_method(adapter, "cancel")
	_assert_has_method(adapter, "get_last_provider")
	_assert_has_method(adapter, "get_last_selected_model")

	# --- complete() mock-mode ---
	var envelope := PromptEnvelope.new("Cześć Pablo!")
	var completion_out: Dictionary = {}
	adapter.complete(
		envelope,
		{},
		func(_token: String) -> void: pass,
		func(result: Dictionary) -> void:
			completion_out.merge(result, true)
	)

	var completion_text: String = str(completion_out.get("text", ""))
	_assert_string(completion_text, "LiteLLMAdapter.complete() — mock output")
	_assert_true(
		completion_text.contains("[litellm:"),
		"LiteLLMAdapter should return mock completions"
	)

	# --- simulate failure ---
	adapter.set_simulate_failure(true)
	var failure_out: Dictionary = {}
	adapter.complete(
		envelope,
		{},
		func(_token: String) -> void: pass,
		func(result: Dictionary) -> void:
			failure_out.merge(result, true)
	)
	var failure_text: String = str(failure_out.get("text", ""))
	_assert_true(
		failure_text.contains("Nie moge") or failure_text.contains("cannot"),
		"LiteLLMAdapter should return fallback text on failure"
	)

	return _build_result("LiteLLMAdapter")
