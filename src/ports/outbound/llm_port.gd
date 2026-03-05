## Outbound port contract for language model completion and tool-calling.
## Adapters implement this interface (Ollama by default) while keeping
## domain and use-case code independent from concrete providers.
## Adapter guidance:
## - Serialize tool schemas deterministically from ToolInvocation contracts.
## - Reject malformed or partial tool-call responses before returning results.
## - Enforce provider timeout and retry policy at the adapter boundary.
class_name LLMPort
extends RefCounted


func complete(envelope: PromptEnvelope) -> String:
	push_error("LLMPort.complete() not implemented")
	return ""


func complete_with_tools(envelope: PromptEnvelope) -> Array[ToolInvocation]:
	push_error("LLMPort.complete_with_tools() not implemented")
	var invocations: Array[ToolInvocation] = []
	return invocations


## Optional provider tag for observability/fallback detection.
## Adapters should return stable values such as:
## "ollama-local", "cloud", "fallback", or "" when unavailable.
func get_last_provider() -> String:
	return ""
