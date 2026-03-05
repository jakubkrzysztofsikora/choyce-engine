## Local-first Ollama LLM adapter with model-tier selection and consent-gated cloud fallback.
## Keeps provider details behind LLMPort while exposing deterministic tool-call planning.
class_name OllamaLLMAdapter
extends LLMPort

const DEFAULT_MODEL_CATALOG_PATH := "res://data/ai/model_catalog.json"
const DEFAULT_MODEL_CATALOG := {
	"small": "qwen2.5:3b-instruct",
	"medium": "qwen2.5:7b-instruct",
	"multimodal": "llava:7b",
}

var _model_catalog: Dictionary = DEFAULT_MODEL_CATALOG.duplicate(true)
var _consent_port: IdentityConsentPort
var _cloud_adapter: LLMPort
var _allow_cloud_fallback: bool = false
var _simulate_local_failure: bool = false
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

	var prefix := "Jasne! " if envelope.is_polish() else "Sure! "
	var preview := prompt
	if preview.length() > 96:
		preview = "%s..." % preview.substr(0, 96)
	return "%s[ollama:%s] %s" % [prefix, _last_selected_model, preview]


func _plan_tools_locally(envelope: PromptEnvelope) -> Array[ToolInvocation]:
	var invocations: Array[ToolInvocation] = []
	if _simulate_local_failure:
		return invocations
	if envelope.permitted_tools.is_empty():
		return invocations

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
	invocation.is_idempotent = tool_name in ["paint", "logic_edit"]
	invocation.requires_approval = tool_name in ["logic_edit", "script_edit", "asset_import"]
	invocations.append(invocation)
	return invocations


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
