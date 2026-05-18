## Local-first Ollama LLM adapter with model-tier selection and consent-gated cloud fallback.
## Keeps provider details behind LLMPort while exposing deterministic tool-call planning.
##
## Non-streaming note: complete() uses HTTPRequest.use_threads=true to avoid blocking the main
## thread, but HTTPRequest.request_completed delivers the FULL body in one signal — incremental
## token delivery is not supported by this adapter. on_token is called at most once (with the
## full accumulated text) immediately before on_done. Callers that display streaming UI should
## treat on_token as an optional hint; on_done is the authoritative completion signal.
##
## To receive true per-token streaming, replace this adapter with one that uses raw HTTPClient
## on a Thread and polls read_response_body_chunk() per iteration.
##
## Mock mode (enabled by default for unit tests): on_done is called synchronously in the same
## frame with a deterministic response — no Node or HTTP required.
class_name OllamaLLMAdapter
extends LLMPort

const DEFAULT_MODEL_CATALOG_PATH := "res://data/ai/model_catalog.json"
const DEFAULT_MODEL_CATALOG := {
	"small": "qwen2.5:3b-instruct",
	"medium": "qwen2.5:7b-instruct",
	"multimodal": "llava:7b",
}
const DEFAULT_HOST := "localhost"
const DEFAULT_PORT := 11434
const LOCAL_TIMEOUT_SEC := 30
const CLOUD_TIMEOUT_SEC := 60
## Maximum unread token buffer size in bytes before oldest tokens are dropped.
const TOKEN_BUFFER_MAX_BYTES := 4096
## Flush interval in seconds (approximately 30 Hz).
const FLUSH_INTERVAL_SEC := 1.0 / 30.0

var _model_catalog: Dictionary = DEFAULT_MODEL_CATALOG.duplicate(true)
var _consent_port: IdentityConsentPort
var _cloud_adapter: LLMPort
var _allow_cloud_fallback: bool = false
var _simulate_local_failure: bool = false
var _mock_mode: bool = false
var _last_selected_tier: String = ""
var _last_selected_model: String = ""
var _last_provider: String = "none"

## Active streaming state — cleared when on_done is called.
var _active_on_token: Callable
var _active_on_done: Callable
var _active_envelope: PromptEnvelope

## Token ring buffer: accumulated partial token text awaiting the next flush tick.
var _token_buffer: PackedStringArray = PackedStringArray()
var _token_buffer_bytes: int = 0

## Helper Node that owns the HTTPRequest and drives _process ticks.
## Created lazily on first real (non-mock) complete() call.
var _helper: _OllamaHelperNode = null

## Parent node to attach the helper to. Injected via setup(); falls back to scene root.
var _parent_node: Node = null

## Accumulated full response text for on_done.
var _full_response_text: String = ""

## Whether a request is currently in flight.
var _request_active: bool = false


func setup(
	consent_port: IdentityConsentPort = null,
	cloud_adapter: LLMPort = null,
	allow_cloud_fallback: bool = false,
	model_catalog: Dictionary = {},
	model_catalog_path: String = DEFAULT_MODEL_CATALOG_PATH,
	parent_node: Node = null
) -> OllamaLLMAdapter:
	_consent_port = consent_port
	_cloud_adapter = cloud_adapter
	_allow_cloud_fallback = allow_cloud_fallback
	_parent_node = parent_node
	_model_catalog = DEFAULT_MODEL_CATALOG.duplicate(true)

	if not model_catalog_path.strip_edges().is_empty():
		_load_model_catalog(model_catalog_path)

	if not model_catalog.is_empty():
		_model_catalog = model_catalog.duplicate(true)

	return self


## Async completion via HTTPRequest (non-incremental).
## In mock mode: on_done is invoked synchronously with a deterministic text.
## In real mode: starts HTTPRequest on a background thread (use_threads=true). on_token is
## called once with the full response text immediately before on_done fires. No incremental
## token delivery occurs — HTTPRequest.request_completed delivers the full body in one shot.
func complete(
	envelope: PromptEnvelope,
	_options: Dictionary,
	on_token: Callable,
	on_done: Callable
) -> void:
	if envelope == null:
		on_done.call({"text": "", "provider": "fallback", "model": "", "stopped": false})
		return

	var tier := _select_completion_tier(envelope)
	_record_model_selection(tier)

	if _simulate_local_failure:
		var profile_id := _extract_profile_id(envelope)
		if _can_escalate_to_cloud(profile_id) and _cloud_adapter != null:
			_last_provider = "cloud"
			_cloud_adapter.complete(envelope, _options, on_token, on_done)
			return
		_last_provider = "fallback"
		var fallback := _fallback_text(envelope)
		on_done.call({"text": fallback, "provider": "fallback", "model": _last_selected_model, "stopped": false})
		return

	if _mock_mode:
		_last_provider = "ollama-local"
		var prefix := "Jasne! " if envelope.is_polish() else "Sure! "
		var preview := envelope.prompt_text
		if preview.length() > 96:
			preview = "%s..." % preview.substr(0, 96)
		var text := "%s[ollama:%s] %s" % [prefix, _last_selected_model, preview]
		on_done.call({"text": text, "provider": "ollama-local", "model": _last_selected_model, "stopped": false})
		return

	# Real async path.
	_last_provider = "ollama-local"
	_active_on_token = on_token
	_active_on_done = on_done
	_active_envelope = envelope
	_full_response_text = ""
	_token_buffer = PackedStringArray()
	_token_buffer_bytes = 0
	_request_active = true

	_ensure_helper()
	_helper.start_request(envelope, _last_selected_model)


## Cancel in-flight request. Drains buffer, fires on_done with stopped=true.
func cancel() -> void:
	if not _request_active:
		return
	if _helper != null:
		_helper.cancel_request()
	_drain_buffer()
	_finish_request(true)


## Async tool-call planning — runs HTTP work on a WorkerThreadPool task to avoid blocking
## the main thread. on_done is called (via call_deferred) with Array[ToolInvocation] result.
##
## NOTE: This overrides the sync LLMPort.complete_with_tools() signature. The call site in
## RequestAICreationHelpService:193 uses the old sync signature and must be updated by the
## WC4 fix agent to pass an on_done Callable instead of capturing the return value.
func complete_with_tools(envelope: PromptEnvelope, on_done: Callable = Callable()) -> void:
	var invocations: Array[ToolInvocation] = []
	if envelope == null:
		if on_done.is_valid():
			on_done.call(invocations)
		return

	var tier := _select_tool_tier(envelope)
	_record_model_selection(tier)

	# Heuristic path (mock or empty permitted_tools) is fast — no I/O, run inline.
	if _mock_mode or _simulate_local_failure:
		var local_tools := _plan_tools_locally(envelope)
		if not local_tools.is_empty():
			_last_provider = "ollama-local"
			if on_done.is_valid():
				on_done.call(local_tools)
			return
		var profile_id := _extract_profile_id(envelope)
		if _can_escalate_to_cloud(profile_id) and _cloud_adapter != null:
			_last_provider = "cloud"
			var cloud_raw: Array = []
			if _cloud_adapter.has_method("complete_with_tools_sync"):
				cloud_raw = _cloud_adapter.complete_with_tools_sync(envelope)
			var cloud_invocations := _normalize_tool_invocations(cloud_raw)
			if on_done.is_valid():
				on_done.call(cloud_invocations)
			return
		_last_provider = "fallback"
		if on_done.is_valid():
			on_done.call(invocations)
		return

	# Real HTTP path — delegate to WorkerThreadPool to keep main thread free.
	var adapter_ref := self
	WorkerThreadPool.add_task(func() -> void:
		var result := adapter_ref._complete_with_tools_sync_internal(envelope)
		if on_done.is_valid():
			on_done.call.call_deferred(result)
	)


## Synchronous helper called from WorkerThreadPool thread. Must not touch Node/scene APIs.
func _complete_with_tools_sync_internal(envelope: PromptEnvelope) -> Array[ToolInvocation]:
	var invocations: Array[ToolInvocation] = []

	var local_tools := _plan_tools_locally(envelope)
	if not local_tools.is_empty():
		_last_provider = "ollama-local"
		return local_tools

	var profile_id := _extract_profile_id(envelope)
	if _can_escalate_to_cloud(profile_id) and _cloud_adapter != null:
		_last_provider = "cloud"
		if _cloud_adapter.has_method("complete_with_tools_sync"):
			return _normalize_tool_invocations(_cloud_adapter.complete_with_tools_sync(envelope))

	_last_provider = "fallback"
	return invocations


## Sync shim for cloud adapter calls from worker thread. Cloud adapters may still be sync.
func complete_with_tools_sync(envelope: PromptEnvelope) -> Array[ToolInvocation]:
	var invocations: Array[ToolInvocation] = []
	if envelope == null:
		return invocations
	var tier := _select_tool_tier(envelope)
	_record_model_selection(tier)
	var local_tools := _plan_tools_locally(envelope)
	if not local_tools.is_empty():
		_last_provider = "ollama-local"
		return local_tools
	var profile_id := _extract_profile_id(envelope)
	if _can_escalate_to_cloud(profile_id) and _cloud_adapter != null:
		_last_provider = "cloud"
		if _cloud_adapter.has_method("complete_with_tools_sync"):
			return _normalize_tool_invocations(_cloud_adapter.complete_with_tools_sync(envelope))
	_last_provider = "fallback"
	return invocations


func set_allow_cloud_fallback(enabled: bool) -> void:
	_allow_cloud_fallback = enabled


func set_simulate_local_failure_for_tests(enabled: bool) -> void:
	_simulate_local_failure = enabled


func set_mock_mode(enabled: bool) -> void:
	_mock_mode = enabled


func get_model_catalog() -> Dictionary:
	return _model_catalog.duplicate(true)


func get_last_selected_tier() -> String:
	return _last_selected_tier


func get_last_selected_model() -> String:
	return _last_selected_model


func get_last_provider() -> String:
	return _last_provider


## Called by helper Node on each received streaming chunk (raw body bytes for that chunk).
func _on_chunk_received(chunk_text: String) -> void:
	# Ollama streams one JSON object per line; each has {"response": "...", "done": false}
	# or {"response": "", "done": true} at end.
	for line in chunk_text.split("\n"):
		var trimmed := line.strip_edges()
		if trimmed.is_empty():
			continue
		var parsed: Variant = JSON.parse_string(trimmed)
		if not parsed is Dictionary:
			continue
		var parsed_dict: Dictionary = parsed
		var token := str(parsed_dict.get("response", parsed_dict.get("content", ""))).strip_edges()
		if token.is_empty():
			continue

		# Ring buffer overflow policy: drop oldest if buffer exceeds 4 KB.
		var token_bytes := token.length()
		if _token_buffer_bytes + token_bytes > TOKEN_BUFFER_MAX_BYTES:
			if _token_buffer.size() > 0:
				var dropped := _token_buffer[0]
				_token_buffer.remove_at(0)
				_token_buffer_bytes -= dropped.length()
				push_warning("OllamaLLMAdapter: token buffer overflow — oldest token dropped (%d bytes)" % dropped.length())

		_token_buffer.append(token)
		_token_buffer_bytes += token_bytes
		_full_response_text += token


## Called by helper Node on the flush tick (30 Hz).
func _on_flush_tick() -> void:
	if not _request_active:
		return
	_drain_buffer()


## Called by helper Node when request_completed signal fires.
func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	# Flush any remaining buffered tokens.
	_drain_buffer()

	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		push_error("OllamaLLMAdapter: HTTP error result=%d code=%d" % [result, response_code])
		if _full_response_text.is_empty():
			_full_response_text = _fallback_text(_active_envelope)

	if _full_response_text.is_empty() and body.size() > 0:
		# Non-streaming fallback: parse the complete body.
		var body_text := body.get_string_from_utf8()
		for line in body_text.split("\n"):
			var trimmed := line.strip_edges()
			if trimmed.is_empty():
				continue
			var parsed: Variant = JSON.parse_string(trimmed)
			if not parsed is Dictionary:
				continue
			var parsed_dict: Dictionary = parsed
			var path := _last_selected_path()
			if path == "/api/chat":
				var message: Dictionary = parsed_dict.get("message", {})
				_full_response_text += str(message.get("content", "")).strip_edges()
			else:
				_full_response_text += str(parsed_dict.get("response", "")).strip_edges()

	_finish_request(false)


## Drain all pending buffered tokens via a single on_token call.
func _drain_buffer() -> void:
	if _token_buffer.is_empty():
		return
	if not _active_on_token.is_valid():
		return
	var combined := "".join(Array(_token_buffer))
	_token_buffer = PackedStringArray()
	_token_buffer_bytes = 0
	_active_on_token.call(combined)


## Finalise the request: clear state and invoke on_done.
## Non-streaming adapter: if on_token is valid and the response has text, on_token is called
## once with the full accumulated text immediately before on_done fires.
func _finish_request(stopped: bool) -> void:
	_request_active = false
	var result_text := _full_response_text
	var provider := _last_provider
	var model := _last_selected_model

	_full_response_text = ""
	_active_envelope = null

	var token_cb := _active_on_token
	var done_cb := _active_on_done
	_active_on_done = Callable()
	_active_on_token = Callable()

	# Deliver full text as single on_token call before on_done (non-streaming contract).
	if token_cb.is_valid() and not result_text.is_empty():
		token_cb.call(result_text)

	if done_cb.is_valid():
		done_cb.call({"text": result_text, "provider": provider, "model": model, "stopped": stopped})


## Ensure the HTTPRequest helper node exists and is in the scene tree.
func _ensure_helper() -> void:
	if _helper != null:
		return
	_helper = _OllamaHelperNode.new()
	_helper.adapter = self

	if _parent_node != null:
		_parent_node.add_child(_helper)
	else:
		# Defer add to root so this works even before _ready().
		var main_loop := Engine.get_main_loop()
		if main_loop != null and main_loop.root != null:
			main_loop.root.call_deferred("add_child", _helper)


func _select_completion_tier(envelope: PromptEnvelope) -> String:
	var prompt := envelope.prompt_text.strip_edges()
	if prompt.length() > 180:
		return "medium"
	var normalized := prompt.to_lower()
	if normalized.contains("skrypt") or normalized.contains("zaplanuj"):
		return "medium"
	return "small"


func _select_tool_tier(envelope: PromptEnvelope) -> String:
	if not envelope.permitted_tools.is_empty():
		return "medium"
	return _select_completion_tier(envelope)


func _record_model_selection(tier: String) -> void:
	_last_selected_tier = tier
	_last_selected_model = str(_model_catalog.get(tier, _model_catalog.get("small", "unknown")))


func _last_selected_path() -> String:
	if _active_envelope != null and not _active_envelope.system_prompt.strip_edges().is_empty():
		return "/api/chat"
	return "/api/generate"


func _plan_tools_locally(envelope: PromptEnvelope) -> Array[ToolInvocation]:
	var invocations: Array[ToolInvocation] = []
	if _simulate_local_failure:
		return invocations
	if envelope.permitted_tools.is_empty():
		return invocations

	if _mock_mode:
		return _plan_tools_locally_heuristic(envelope)

	# Structured JSON prompt approach — synchronous HTTP (tool calls require atomic JSON).
	var tools_list := ", ".join(envelope.permitted_tools)
	var system_prompt := "You are a tool selection assistant. Given a user request, select the appropriate tools " \
		+ "from the permitted list and return ONLY a JSON object in this exact format:\n" \
		+ "{\"tools\": [{\"name\": \"tool_name\", \"arguments\": {\"key\": \"value\"}}]}\n" \
		+ "Permitted tools: %s\n" \
		+ "Do not include any explanation, markdown, or extra text." % tools_list

	var body := {
		"model": _last_selected_model,
		"prompt": envelope.prompt_text.strip_edges(),
		"system": system_prompt,
		"stream": false,
		"options": {"temperature": 0.1},
	}

	if _supports_json_mode(_last_selected_model):
		body["format"] = "json"

	var response := _http_post_sync(DEFAULT_HOST, DEFAULT_PORT, "/api/generate", body, LOCAL_TIMEOUT_SEC)
	if response.has("error"):
		push_error("OllamaLLMAdapter._plan_tools_locally HTTP error: %s" % response.get("error"))
		return _plan_tools_locally_heuristic(envelope)

	var raw_text := str(response.get("response", "")).strip_edges()
	if raw_text.is_empty():
		return _plan_tools_locally_heuristic(envelope)

	var json_text := _extract_json_block(raw_text)
	var parsed: Variant = JSON.parse_string(json_text)
	if parsed == null or not parsed is Dictionary:
		return _plan_tools_locally_heuristic(envelope)

	var parsed_dict: Dictionary = parsed
	var tools_array: Array = parsed_dict.get("tools", [])
	if tools_array.is_empty():
		return _plan_tools_locally_heuristic(envelope)

	for tool_item in tools_array:
		if not tool_item is Dictionary:
			continue
		var tool_dict: Dictionary = tool_item
		var tool_name := str(tool_dict.get("name", "")).strip_edges()
		if tool_name.is_empty():
			continue
		if not envelope.permitted_tools.has(tool_name):
			continue

		var arguments: Dictionary = {}
		var args_variant: Variant = tool_dict.get("arguments", {})
		if args_variant is Dictionary:
			arguments = args_variant

		var invocation := ToolInvocation.new(
			tool_name,
			arguments,
			_build_invocation_id(tool_name, envelope.prompt_text)
		)
		_configure_invocation_flags(invocation)
		invocations.append(invocation)

	return invocations


func _plan_tools_locally_heuristic(envelope: PromptEnvelope) -> Array[ToolInvocation]:
	var invocations: Array[ToolInvocation] = []
	var normalized := envelope.prompt_text.to_lower()
	var tool_name := ""
	var arguments := {}

	if normalized.contains("kolor") and envelope.permitted_tools.has("paint"):
		tool_name = "paint"
		arguments = {"color": "zolty"}
	elif normalized.contains("skopi") and envelope.permitted_tools.has("duplicate"):
		tool_name = "duplicate"
		arguments = {"target": "selected_node"}
	elif (normalized.contains("regu") or normalized.contains("timer")) and envelope.permitted_tools.has("logic_edit"):
		tool_name = "logic_edit"
		arguments = {"operation": "add_timer", "interval_sec": 10}
	elif envelope.permitted_tools.has("scene_edit"):
		tool_name = "scene_edit"
		arguments = {"operation": "add_object", "type": "tree"}

	if tool_name.is_empty():
		return invocations

	var invocation := ToolInvocation.new(
		tool_name,
		arguments,
		_build_invocation_id(tool_name, envelope.prompt_text)
	)
	_configure_invocation_flags(invocation)
	invocations.append(invocation)
	return invocations


func _configure_invocation_flags(invocation: ToolInvocation) -> void:
	match invocation.tool_name:
		"paint", "scene_edit":
			invocation.is_idempotent = true
			invocation.requires_approval = false
		"logic_edit", "script_edit", "asset_import":
			invocation.is_idempotent = false
			invocation.requires_approval = true
		_:
			invocation.is_idempotent = false
			invocation.requires_approval = false


func _supports_json_mode(model_name: String) -> bool:
	var normalized := model_name.to_lower()
	return normalized.contains("qwen") or normalized.contains("llama") or normalized.contains("mistral")


## Synchronous HTTP POST — used only for complete_with_tools (structured JSON output).
## NOT used for streaming complete(); that path goes through HTTPRequest Node.
func _http_post_sync(host: String, port: int, path: String, body: Dictionary, timeout_sec: int = LOCAL_TIMEOUT_SEC) -> Dictionary:
	var client := HTTPClient.new()
	var timeout_ms := timeout_sec * 1000
	var start_time := Time.get_ticks_msec()

	var err := client.connect_to_host(host, port)
	if err != OK:
		client.close()
		return {"error": "Failed to connect to %s:%d (err=%d)" % [host, port, err]}

	while client.get_status() == HTTPClient.STATUS_CONNECTING or client.get_status() == HTTPClient.STATUS_RESOLVING:
		if Time.get_ticks_msec() - start_time > timeout_ms:
			client.close()
			return {"error": "Connection timeout to %s:%d" % [host, port]}
		client.poll()
		OS.delay_msec(1)

	if client.get_status() != HTTPClient.STATUS_CONNECTED:
		client.close()
		return {"error": "Could not connect to %s:%d (status=%d)" % [host, port, client.get_status()]}

	var body_json := JSON.stringify(body)
	var headers := ["Content-Type: application/json"]
	err = client.request(HTTPClient.METHOD_POST, path, headers, body_json)
	if err != OK:
		client.close()
		return {"error": "HTTP request failed (err=%d)" % err}

	while client.get_status() == HTTPClient.STATUS_REQUESTING:
		if Time.get_ticks_msec() - start_time > timeout_ms:
			client.close()
			return {"error": "Request timeout to %s:%d" % [host, port]}
		client.poll()
		OS.delay_msec(1)

	var response_status := client.get_response_code()
	if response_status < 200 or response_status >= 300:
		var error_body := ""
		while client.get_status() == HTTPClient.STATUS_BODY:
			client.poll()
			var chunk := client.read_response_body_chunk()
			if chunk.size() == 0:
				if Time.get_ticks_msec() - start_time > timeout_ms:
					break
				OS.delay_msec(1)
			else:
				error_body += chunk.get_string_from_utf8()
		client.close()
		return {"error": "HTTP %d: %s" % [response_status, error_body.strip_edges()]}

	var response_body := ""
	while client.get_status() == HTTPClient.STATUS_BODY:
		if Time.get_ticks_msec() - start_time > timeout_ms:
			client.close()
			return {"error": "Response read timeout from %s:%d" % [host, port]}
		client.poll()
		var chunk := client.read_response_body_chunk()
		if chunk.size() == 0:
			OS.delay_msec(1)
		else:
			response_body += chunk.get_string_from_utf8()

	client.close()

	var parsed: Variant = JSON.parse_string(response_body)
	if parsed == null:
		return {"error": "Failed to parse JSON response"}
	if parsed is Dictionary:
		return parsed
	return {"error": "Unexpected JSON response type"}


func _extract_json_block(text: String) -> String:
	var trimmed := text.strip_edges()
	if trimmed.begins_with("```"):
		var lines := trimmed.split("\n")
		var start_idx := 0
		if lines[0].begins_with("```"):
			start_idx = 1
		var end_idx := lines.size() - 1
		while end_idx > start_idx and not lines[end_idx].begins_with("```"):
			end_idx -= 1
		var inner_lines: Array[String] = []
		for i in range(start_idx, end_idx):
			inner_lines.append(lines[i])
		return "\n".join(inner_lines).strip_edges()
	return trimmed


func _build_invocation_id(tool_name: String, prompt_text: String) -> String:
	var seed := "%s|%s" % [tool_name, prompt_text]
	return "ollama_%s_%d" % [tool_name, absi(seed.hash())]


func _extract_profile_id(envelope: PromptEnvelope) -> String:
	for tag_value in envelope.context_tags:
		var tag := str(tag_value).strip_edges()
		if tag.begins_with("profile_id:"):
			return tag.trim_prefix("profile_id:").strip_edges()
		if tag.begins_with("profile:"):
			return tag.trim_prefix("profile:").strip_edges()
	return ""


func _can_escalate_to_cloud(profile_id: String) -> bool:
	if not _allow_cloud_fallback:
		return false
	if _consent_port == null:
		return false
	if profile_id.strip_edges().is_empty():
		return false
	return _consent_port.has_consent(profile_id, "cloud_llm")


func _fallback_text(envelope: PromptEnvelope) -> String:
	if envelope != null and envelope.is_polish():
		return "Nie moge teraz skorzystac z modelu. Sprobuj prostszej prosby."
	return "Model is unavailable right now. Try a simpler request."


func _normalize_tool_invocations(raw: Array) -> Array[ToolInvocation]:
	var invocations: Array[ToolInvocation] = []
	for item in raw:
		if item is ToolInvocation:
			invocations.append(item)
	return invocations


func _load_model_catalog(path: String) -> void:
	if not FileAccess.file_exists(path):
		return

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return

	var candidate: Dictionary = parsed
	if candidate.has("small") and candidate.has("medium"):
		_model_catalog = candidate.duplicate(true)


## Inner helper Node that owns the HTTPRequest and drives the flush timer.
## Exists entirely within the adapter boundary — application code never sees it.
class _OllamaHelperNode:
	extends Node

	var adapter: OllamaLLMAdapter
	var _http_request: HTTPRequest
	var _flush_accumulator: float = 0.0
	var _request_active: bool = false

	func _ready() -> void:
		_http_request = HTTPRequest.new()
		_http_request.use_threads = true
		add_child(_http_request)
		_http_request.request_completed.connect(_on_request_completed)

	func start_request(envelope: PromptEnvelope, model: String) -> void:
		if _http_request == null:
			push_error("_OllamaHelperNode: HTTPRequest not ready")
			return

		var path: String
		var body: Dictionary

		if not envelope.system_prompt.strip_edges().is_empty():
			path = "/api/chat"
			body = {
				"model": model,
				"messages": [
					{"role": "system", "content": envelope.system_prompt.strip_edges()},
					{"role": "user", "content": envelope.prompt_text.strip_edges()},
				],
				"stream": true,
				"options": {"temperature": 0.7},
			}
		else:
			path = "/api/generate"
			body = {
				"model": model,
				"prompt": envelope.prompt_text.strip_edges(),
				"stream": true,
				"options": {"temperature": 0.7},
			}

		var url := "http://%s:%d%s" % [OllamaLLMAdapter.DEFAULT_HOST, OllamaLLMAdapter.DEFAULT_PORT, path]
		var headers := ["Content-Type: application/json"]
		var body_json := JSON.stringify(body)

		_http_request.timeout = OllamaLLMAdapter.LOCAL_TIMEOUT_SEC
		_request_active = true
		var err := _http_request.request(url, headers, HTTPClient.METHOD_POST, body_json)
		if err != OK:
			_request_active = false
			push_error("_OllamaHelperNode: request failed err=%d" % err)
			if adapter != null:
				adapter._on_request_completed(HTTPRequest.RESULT_CONNECTION_ERROR, 0, PackedStringArray(), PackedByteArray())

	func cancel_request() -> void:
		if _http_request != null:
			_http_request.cancel_request()
		_request_active = false

	func _process(delta: float) -> void:
		if not _request_active:
			return
		if adapter == null:
			return
		_flush_accumulator += delta
		if _flush_accumulator >= OllamaLLMAdapter.FLUSH_INTERVAL_SEC:
			_flush_accumulator = 0.0
			adapter._on_flush_tick()

	func _on_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
		_request_active = false
		if adapter != null:
			adapter._on_request_completed(result, response_code, headers, body)
