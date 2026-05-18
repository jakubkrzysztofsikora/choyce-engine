## Local-first Ollama LLM adapter with model-tier selection and consent-gated cloud fallback.
## Keeps provider details behind LLMPort while exposing deterministic tool-call planning.
##
## HTTP mode: set_mock_mode(false) to talk to a real Ollama instance at localhost:11434.
## Mock mode: enabled by default for testability without a running server.
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
const LOCAL_TIMEOUT_MS := 30000
const CLOUD_TIMEOUT_MS := 60000

var _model_catalog: Dictionary = DEFAULT_MODEL_CATALOG.duplicate(true)
var _consent_port: IdentityConsentPort
var _cloud_adapter: LLMPort
var _allow_cloud_fallback: bool = false
var _simulate_local_failure: bool = false
var _mock_mode: bool = false
var _last_selected_tier: String = ""
var _last_selected_model: String = ""
var _last_provider: String = "none"


func setup(
	consent_port: IdentityConsentPort = null,
	cloud_adapter: LLMPort = null,
	allow_cloud_fallback: bool = false,
	model_catalog: Dictionary = {},
	model_catalog_path: String = DEFAULT_MODEL_CATALOG_PATH
) -> OllamaLLMAdapter:
	_consent_port = consent_port
	_cloud_adapter = cloud_adapter
	_allow_cloud_fallback = allow_cloud_fallback
	_model_catalog = DEFAULT_MODEL_CATALOG.duplicate(true)

	if not model_catalog_path.strip_edges().is_empty():
		_load_model_catalog(model_catalog_path)

	if not model_catalog.is_empty():
		_model_catalog = model_catalog.duplicate(true)

	return self


func complete(envelope: PromptEnvelope) -> String:
	if envelope == null:
		return ""

	var tier := _select_completion_tier(envelope)
	_record_model_selection(tier)

	var local_response := _complete_local(envelope)
	if not local_response.is_empty():
		_last_provider = "ollama-local"
		return local_response

	var profile_id := _extract_profile_id(envelope)
	if _can_escalate_to_cloud(profile_id) and _cloud_adapter != null:
		_last_provider = "cloud"
		return _cloud_adapter.complete(envelope)

	_last_provider = "fallback"
	return _fallback_text(envelope)


func complete_with_tools(envelope: PromptEnvelope) -> Array[ToolInvocation]:
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
		return _normalize_tool_invocations(_cloud_adapter.complete_with_tools(envelope))

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


func _complete_local(envelope: PromptEnvelope) -> String:
	if _simulate_local_failure:
		return ""

	var prompt := envelope.prompt_text.strip_edges()
	if prompt.is_empty():
		return ""

	if _mock_mode:
		var prefix := "Jasne! " if envelope.is_polish() else "Sure! "
		var preview := prompt
		if preview.length() > 96:
			preview = "%s..." % preview.substr(0, 96)
		return "%s[ollama:%s] %s" % [prefix, _last_selected_model, preview]

	# Real HTTP path
	var body: Dictionary
	var path := "/api/generate"

	if not envelope.system_prompt.strip_edges().is_empty():
		# Use chat endpoint when a system prompt is present
		path = "/api/chat"
		body = {
			"model": _last_selected_model,
			"messages": [
				{"role": "system", "content": envelope.system_prompt.strip_edges()},
				{"role": "user", "content": prompt},
			],
			"stream": false,
			"options": {"temperature": 0.7},
		}
	else:
		body = {
			"model": _last_selected_model,
			"prompt": prompt,
			"stream": false,
			"options": {"temperature": 0.7},
		}

	var response := _http_post(DEFAULT_HOST, DEFAULT_PORT, path, body, LOCAL_TIMEOUT_MS)
	if response.has("error"):
		push_error("OllamaLLMAdapter._complete_local HTTP error: %s" % response.get("error"))
		return ""

	var text := ""
	if path == "/api/chat":
		var message: Dictionary = response.get("message", {})
		text = str(message.get("content", "")).strip_edges()
	else:
		text = str(response.get("response", "")).strip_edges()

	return text


func _plan_tools_locally(envelope: PromptEnvelope) -> Array[ToolInvocation]:
	var invocations: Array[ToolInvocation] = []
	if _simulate_local_failure:
		return invocations
	if envelope.permitted_tools.is_empty():
		return invocations

	if _mock_mode:
		return _plan_tools_locally_heuristic(envelope)

	# Structured JSON prompt approach
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

	var response := _http_post(DEFAULT_HOST, DEFAULT_PORT, "/api/generate", body, LOCAL_TIMEOUT_MS)
	if response.has("error"):
		push_error("OllamaLLMAdapter._plan_tools_locally HTTP error: %s" % response.get("error"))
		return _plan_tools_locally_heuristic(envelope)

	var raw_text := str(response.get("response", "")).strip_edges()
	if raw_text.is_empty():
		return _plan_tools_locally_heuristic(envelope)

	# Try to extract JSON from possible markdown fences
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


func _http_post(host: String, port: int, path: String, body: Dictionary, timeout_ms: int = LOCAL_TIMEOUT_MS) -> Dictionary:
	var client := HTTPClient.new()
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
		# Still read body for error details
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
	if envelope.is_polish():
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
