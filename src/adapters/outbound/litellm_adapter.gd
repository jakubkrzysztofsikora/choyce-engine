## LiteLLM LLM adapter implementing LLMPort.
## Communicates with an OpenAI-compatible LiteLLM proxy server.
class_name LiteLLMAdapter
extends LLMPort

const DEFAULT_BASE_URL := "https://litellm.tail5d39b4.ts.net"
const DEFAULT_API_KEY := "Bearer sk-litellm-3828843d6a0fc5437a754211622c7ef97e5ea4b6d640e12b3"
const DEFAULT_MODEL := "claude-3-5-sonnet-20241022"
const TIMEOUT_SEC := 30

var _base_url: String = DEFAULT_BASE_URL
var _custom_headers: Array[String] = []
var _default_model: String = DEFAULT_MODEL
var _mock_mode: bool = false
var _simulate_failure: bool = false

var _active_on_token: Callable
var _active_on_done: Callable
var _active_envelope: PromptEnvelope

var _helper: _LiteLLMHelperNode = null
var _parent_node: Node = null
var _request_active: bool = false
var _full_response_text: String = ""


func setup(
	p_base_url: String = "",
	p_default_model: String = "",
	p_parent_node: Node = null
) -> LiteLLMAdapter:
	_base_url = p_base_url if not p_base_url.strip_edges().is_empty() else OS.get_environment("ANTHROPIC_BASE_URL")
	if _base_url.strip_edges().is_empty():
		_base_url = DEFAULT_BASE_URL

	_default_model = p_default_model if not p_default_model.strip_edges().is_empty() else DEFAULT_MODEL
	_parent_node = p_parent_node

	# Parse custom headers
	_custom_headers.clear()
	var env_headers := OS.get_environment("ANTHROPIC_CUSTOM_HEADERS")
	if not env_headers.strip_edges().is_empty():
		for item in env_headers.split(","):
			var cleaned := item.strip_edges()
			if not cleaned.is_empty() and cleaned.contains(":"):
				_custom_headers.append(cleaned)
	else:
		_custom_headers.append("x-litellm-api-key: %s" % DEFAULT_API_KEY)

	return self


func set_mock_mode(enabled: bool) -> void:
	_mock_mode = enabled


func set_simulate_failure(enabled: bool) -> void:
	_simulate_failure = enabled


func complete(
	envelope: PromptEnvelope,
	_options: Dictionary,
	on_token: Callable,
	on_done: Callable
) -> void:
	if envelope == null:
		if on_done.is_valid():
			on_done.call({"text": "", "provider": "litellm", "model": _default_model, "stopped": false})
		return

	if _simulate_failure:
		if on_done.is_valid():
			on_done.call({"text": _fallback_text(envelope), "provider": "litellm", "model": _default_model, "stopped": false})
		return

	if _mock_mode:
		var prefix := "Jasne! " if envelope.is_polish() else "Sure! "
		var preview := envelope.prompt_text
		if preview.length() > 96:
			preview = "%s..." % preview.substr(0, 96)
		var text := "%s[litellm:%s] %s" % [prefix, _default_model, preview]
		if on_done.is_valid():
			on_done.call({"text": text, "provider": "litellm", "model": _default_model, "stopped": false})
		return

	_active_on_token = on_token
	_active_on_done = on_done
	_active_envelope = envelope
	_full_response_text = ""
	_request_active = true

	_ensure_helper()
	_helper.start_request(envelope, _base_url, _custom_headers, _default_model)


func cancel() -> void:
	if not _request_active:
		return
	if _helper != null:
		_helper.cancel_request()
	_finish_request(true)


func complete_with_tools(envelope: PromptEnvelope, on_done: Callable = Callable()) -> void:
	var adapter_ref := self
	WorkerThreadPool.add_task(func() -> void:
		var result := adapter_ref.complete_with_tools_sync(envelope)
		if on_done.is_valid():
			on_done.call.call_deferred(result)
	)


func complete_with_tools_sync(_envelope: PromptEnvelope) -> Array[ToolInvocation]:
	return []


func get_last_provider() -> String:
	return "litellm"


func get_last_selected_model() -> String:
	return _default_model


func _fallback_text(envelope: PromptEnvelope) -> String:
	if envelope != null and envelope.is_polish():
		return "Nie moge teraz odpowiedziec. Sprobuj pozniej."
	return "I cannot answer right now. Try again later."


func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		push_error("LiteLLMAdapter: HTTP error result=%d code=%d" % [result, response_code])
		if _full_response_text.is_empty():
			_full_response_text = _fallback_text(_active_envelope)
	else:
		var body_text := body.get_string_from_utf8()
		var json := JSON.new()
		if json.parse(body_text) == OK and json.data is Dictionary:
			var dict: Dictionary = json.data
			var choices: Array = dict.get("choices", [])
			if not choices.is_empty() and choices[0] is Dictionary:
				var message: Dictionary = choices[0].get("message", {})
				_full_response_text = str(message.get("content", "")).strip_edges()

		if _full_response_text.is_empty():
			_full_response_text = _fallback_text(_active_envelope)

	_finish_request(false)


func _finish_request(stopped: bool) -> void:
	_request_active = false
	var result_text := _full_response_text
	var model := _default_model

	_full_response_text = ""
	_active_envelope = null

	var token_cb := _active_on_token
	var done_cb := _active_on_done
	_active_on_done = Callable()
	_active_on_token = Callable()

	if token_cb.is_valid() and not result_text.is_empty():
		token_cb.call(result_text)

	if done_cb.is_valid():
		done_cb.call({"text": result_text, "provider": "litellm", "model": model, "stopped": stopped})


func _ensure_helper() -> void:
	if _helper != null:
		return
	_helper = _LiteLLMHelperNode.new()
	_helper.adapter = self

	if _parent_node != null:
		_parent_node.add_child(_helper)
	else:
		var main_loop := Engine.get_main_loop()
		if main_loop != null and main_loop.root != null:
			main_loop.root.call_deferred("add_child", _helper)


class _LiteLLMHelperNode:
	extends Node

	var adapter: LiteLLMAdapter
	var _http_request: HTTPRequest
	var _request_active: bool = false

	func _ready() -> void:
		_http_request = HTTPRequest.new()
		_http_request.use_threads = true
		add_child(_http_request)
		_http_request.request_completed.connect(_on_request_completed)

	func start_request(envelope: PromptEnvelope, base_url: String, custom_headers: Array[String], model: String) -> void:
		if _http_request == null:
			push_error("_LiteLLMHelperNode: HTTPRequest not ready")
			return

		var messages := []
		if not envelope.system_prompt.strip_edges().is_empty():
			messages.append({"role": "system", "content": envelope.system_prompt.strip_edges()})
		messages.append({"role": "user", "content": envelope.prompt_text.strip_edges()})

		var body := {
			"model": model,
			"messages": messages,
			"temperature": 0.7,
			"max_tokens": envelope.max_tokens,
		}

		var url := "%s/v1/chat/completions" % base_url.trim_suffix("/")
		var headers := ["Content-Type: application/json"]
		for header in custom_headers:
			headers.append(header)

		var body_json := JSON.stringify(body)

		_http_request.timeout = LiteLLMAdapter.TIMEOUT_SEC
		_request_active = true
		var err := _http_request.request(url, headers, HTTPClient.METHOD_POST, body_json)
		if err != OK:
			_request_active = false
			push_error("_LiteLLMHelperNode: request failed err=%d" % err)
			if adapter != null:
				adapter._on_request_completed(HTTPRequest.RESULT_CONNECTION_ERROR, 0, PackedStringArray(), PackedByteArray())

	func cancel_request() -> void:
		if _http_request != null:
			_http_request.cancel_request()
		_request_active = false

	func _on_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
		_request_active = false
		if adapter != null:
			adapter._on_request_completed(result, response_code, headers, body)
