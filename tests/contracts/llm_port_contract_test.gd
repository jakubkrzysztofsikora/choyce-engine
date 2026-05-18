class_name LLMPortContractTest
extends PortContractTest


func run() -> Dictionary:
	_reset()
	var port := LLMPort.new()

	_assert_has_method(port, "complete")
	_assert_has_method(port, "complete_with_tools")
	_assert_has_method(port, "complete_with_tools_sync")
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

	# complete_with_tools() is now void/async; base port fires on_done with empty array.
	var tools_result: Variant = null
	port.complete_with_tools(
		envelope,
		func(result: Array) -> void:
			tools_result = result
	)
	# Base port does NOT invoke on_done (push_error only), so we only verify the call
	# does not crash and the signature is accepted.
	_note_check()

	var tools_null_result: Variant = null
	port.complete_with_tools(
		null,
		func(result: Array) -> void:
			tools_null_result = result
	)
	_note_check()

	# complete_with_tools_sync() sync shim must return an Array[ToolInvocation].
	var sync_tools := port.complete_with_tools_sync(envelope)
	_assert_tool_invocation_array(sync_tools, "LLMPort.complete_with_tools_sync(envelope)")

	var provider := port.get_last_provider()
	_assert_string(provider, "LLMPort.get_last_provider()")

	# cancel() must not raise.
	port.cancel()

	return _build_result("LLMPort")
