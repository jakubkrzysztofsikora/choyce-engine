class_name LLMPortContractTest
extends PortContractTest


func run() -> Dictionary:
	_reset()
	var port := LLMPort.new()

	_assert_has_method(port, "complete")
	_assert_has_method(port, "complete_with_tools")
	_assert_has_method(port, "cancel")
	_assert_has_method(port, "get_last_provider")
	_assert_has_method(port, "get_last_selected_model")

	# complete() is void — verify it accepts the new streaming signature.
	var on_done_called := false
	var envelope := PromptEnvelope.new("Zaproponuj prosty quest.")
	port.complete(
		envelope,
		{},
		func(_token: String) -> void: pass,
		func(_result: Dictionary) -> void:
			on_done_called = true
	)
	# Base port pushes an error and does NOT invoke on_done — that is acceptable
	# (subclasses provide real implementation).

	var tools := port.complete_with_tools(envelope)
	_assert_tool_invocation_array(tools, "LLMPort.complete_with_tools(envelope)")

	var tools_null := port.complete_with_tools(null)
	_assert_tool_invocation_array(tools_null, "LLMPort.complete_with_tools(null)")

	var provider := port.get_last_provider()
	_assert_string(provider, "LLMPort.get_last_provider()")

	# cancel() must not raise.
	port.cancel()

	return _build_result("LLMPort")
