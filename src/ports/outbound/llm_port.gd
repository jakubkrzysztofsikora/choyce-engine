## Outbound port contract for language model completion and tool-calling.
## Adapters implement this interface (Ollama by default) while keeping
## domain and use-case code independent from concrete providers.
## Adapter guidance:
## - Serialize tool schemas deterministically from ToolInvocation contracts.
## - Reject malformed or partial tool-call responses before returning results.
## - Enforce provider timeout and retry policy at the adapter boundary.
##
## Streaming contract:
## - complete() is fire-and-forget. Callers pass two Callables and return immediately.
## - on_token(text: String) — receives coalesced partial token chunks; called at most
##   once per frame (30 Hz flush). Callers MUST NOT block inside this callback.
## - on_done(result: Dictionary) — called exactly once when the request completes,
##   with {"text": String, "provider": String, "model": String, "stopped": bool}.
##   Callers MUST NOT block inside this callback.
## - Application services MUST NOT import or await any Godot signal directly;
##   they depend only on these Callable arguments.
class_name LLMPort
extends RefCounted


## Async streaming completion. Calls on_token with partial text during generation;
## calls on_done once with the final result dict when finished or cancelled.
## options may include {"temperature": float, "max_tokens": int}.
func complete(
	_envelope: PromptEnvelope,
	_options: Dictionary,
	_on_token: Callable,
	_on_done: Callable
) -> void:
	push_error("LLMPort.complete() not implemented")


## Async structured tool-call planning. Callers pass on_done; the adapter runs
## the HTTP request on a worker thread and invokes on_done(Array[ToolInvocation])
## via call_deferred. Tool-call planning still returns an atomic structured
## response (no streaming), but the call itself is non-blocking.
func complete_with_tools(_envelope: PromptEnvelope, _on_done: Callable = Callable()) -> void:
	push_error("LLMPort.complete_with_tools() not implemented")


## Synchronous escape hatch retained for end-to-end pipelines that capture the
## tool list inline (e.g. RequestAICreationHelpService validation pipeline).
## Prefer the async complete_with_tools(envelope, on_done) for new code.
func complete_with_tools_sync(_envelope: PromptEnvelope) -> Array[ToolInvocation]:
	push_error("LLMPort.complete_with_tools_sync() not implemented")
	var invocations: Array[ToolInvocation] = []
	return invocations


## Cancel the in-flight streaming request (if any).
## Drains the token ring buffer and fires on_done with stopped=true.
func cancel() -> void:
	pass


## Optional provider tag for observability/fallback detection.
## Adapters should return stable values such as:
## "ollama-local", "cloud", "fallback", or "" when unavailable.
func get_last_provider() -> String:
	return ""


## Optional model name for provenance/audit. Returns empty string when unavailable.
func get_last_selected_model() -> String:
	return ""
