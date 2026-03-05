## ElevenLabs-style TTS adapter for narration and NPC voice generation.
## Enforces Polish voice presets by default and exposes metadata required
## for downstream governance checks.
class_name ElevenLabsTTSAdapter
extends TextToSpeechPort

const DEFAULT_LANGUAGE := "pl-PL"
const DEFAULT_VOICE_PRESETS := {
	"narration": "narrator_pl",
	"npc": "npc_helper_pl",
	"onboarding": "guide_pl",
	"accessibility": "narrator_pl",
}
const APPROVED_VOICES := {
	"narrator_pl": {
		"provider_voice_id": "pl_narrator_v1",
		"language": "pl-PL",
	},
	"npc_helper_pl": {
		"provider_voice_id": "pl_npc_helper_v1",
		"language": "pl-PL",
	},
	"guide_pl": {
		"provider_voice_id": "pl_guide_v1",
		"language": "pl-PL",
	},
}

var _api_key: String = ""
var _default_language: String = DEFAULT_LANGUAGE
var _allow_parent_language_override: bool = false
var _voice_presets: Dictionary = DEFAULT_VOICE_PRESETS.duplicate(true)
var _last_request_metadata: Dictionary = {}


func setup(
	api_key: String = "",
	voice_presets: Dictionary = {},
	default_language: String = DEFAULT_LANGUAGE,
	allow_parent_language_override: bool = false
) -> ElevenLabsTTSAdapter:
	_api_key = api_key
	_default_language = default_language.strip_edges() if not default_language.strip_edges().is_empty() else DEFAULT_LANGUAGE
	_allow_parent_language_override = allow_parent_language_override
	_voice_presets = DEFAULT_VOICE_PRESETS.duplicate(true)
	for key in voice_presets.keys():
		_voice_presets[str(key)] = str(voice_presets[key])
	_last_request_metadata = {}
	return self


func synthesize(text: String, voice_id: String, language: String) -> PackedByteArray:
	var trimmed_text := text.strip_edges()
	if trimmed_text.is_empty():
		_last_request_metadata = {
			"provider": "elevenlabs",
			"language": _default_language,
			"voice_preset": resolve_voice_for_role("narration"),
			"provider_voice_id": "",
			"license_id": "elevenlabs-default",
			"attribution": "Generated with ElevenLabs",
			"allow_publish": true,
			"allow_language_override": _allow_parent_language_override,
			"is_empty": true,
		}
		return PackedByteArray()

	var resolved_language := _resolve_language(language)
	var resolved_voice := _resolve_voice(voice_id, resolved_language)
	var payload := "ELV_TTS|%s|%s|%s" % [
		resolved_voice.get("provider_voice_id", ""),
		resolved_language,
		trimmed_text,
	]

	_last_request_metadata = {
		"provider": "elevenlabs",
		"language": resolved_language,
		"voice_preset": resolved_voice.get("voice_preset", "narrator_pl"),
		"provider_voice_id": resolved_voice.get("provider_voice_id", ""),
		"license_id": "elevenlabs-default",
		"attribution": "Generated with ElevenLabs",
		"allow_publish": true,
		"allow_language_override": _allow_parent_language_override,
		"api_key_configured": not _api_key.is_empty(),
	}
	return payload.to_utf8_buffer()


func resolve_voice_for_role(role: String, language: String = "") -> String:
	var resolved_language := _resolve_language(language)
	var normalized := role.strip_edges().to_lower()
	var mapped_role := _map_role_alias(normalized)
	var candidate := str(_voice_presets.get(mapped_role, _voice_presets.get("narration", "narrator_pl")))
	if _is_voice_allowed_for_language(candidate, resolved_language):
		return candidate
	return str(_voice_presets.get("narration", "narrator_pl"))


func get_voice_presets() -> Dictionary:
	return _voice_presets.duplicate(true)


func get_last_request_metadata() -> Dictionary:
	return _last_request_metadata.duplicate(true)


func _resolve_language(language: String) -> String:
	var normalized := language.strip_edges()
	if normalized.is_empty():
		return _default_language

	if normalized.begins_with("pl"):
		return "pl-PL"

	if _allow_parent_language_override:
		return normalized

	return "pl-PL"


func _resolve_voice(requested_voice: String, language: String) -> Dictionary:
	var selected_preset := ""
	var normalized := requested_voice.strip_edges().to_lower()
	if normalized.is_empty():
		selected_preset = resolve_voice_for_role("narration", language)
	else:
		var mapped_role := _map_role_alias(normalized)
		if _voice_presets.has(mapped_role):
			selected_preset = resolve_voice_for_role(mapped_role, language)
		elif APPROVED_VOICES.has(normalized) and _is_voice_allowed_for_language(normalized, language):
			selected_preset = normalized
		else:
			selected_preset = resolve_voice_for_role("narration", language)

	var voice_meta: Dictionary = APPROVED_VOICES.get(
		selected_preset,
		APPROVED_VOICES.get("narrator_pl", {})
	)
	return {
		"voice_preset": selected_preset,
		"provider_voice_id": str(voice_meta.get("provider_voice_id", "")),
	}


func _map_role_alias(role: String) -> String:
	match role:
		"narrator", "narration", "voiceover":
			return "narration"
		"npc", "npc_voice", "helper":
			return "npc"
		"guide", "onboarding":
			return "onboarding"
		"accessibility", "captions":
			return "accessibility"
		_:
			return role


func _is_voice_allowed_for_language(voice_preset: String, language: String) -> bool:
	if not APPROVED_VOICES.has(voice_preset):
		return false
	var voice_meta: Dictionary = APPROVED_VOICES.get(voice_preset, {})
	var voice_language := str(voice_meta.get("language", ""))
	if language.begins_with("pl"):
		return voice_language.begins_with("pl")
	return true
