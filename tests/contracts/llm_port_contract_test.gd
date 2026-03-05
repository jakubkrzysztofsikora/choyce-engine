class_name LLMPortContractTest
extends PortContractTest


func run() -> Dictionary:
	_reset()
	var port := LLMPort.new()

	_assert_has_method(port, "complete")
	_assert_has_method(port, "complete_with_tools")
	_assert_has_method(port, "get_last_provider")

	var envelope := PromptEnvelope.new("Zaproponuj prosty quest.")
	var completion := port.complete(envelope)
	_assert_string(completion, "LLMPort.complete(envelope)")

	var completion_null := port.complete(null)
	_assert_string(completion_null, "LLMPort.complete(null)")

	var tools := port.complete_with_tools(envelope)
	_assert_tool_invocation_array(tools, "LLMPort.complete_with_tools(envelope)")

	var tools_null := port.complete_with_tools(null)
	_assert_tool_invocation_array(tools_null, "LLMPort.complete_with_tools(null)")

	var provider := port.get_last_provider()
	_assert_string(provider, "LLMPort.get_last_provider()")

	return _build_result("LLMPort")
