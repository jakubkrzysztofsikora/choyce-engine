## ElevenLabs-style adapter for child-safe ambient audio generation.
## Keeps generation deterministic for tests while surfacing provider/license
## metadata for governance checks.
class_name ElevenLabsAudioGenerationAdapter
extends AudioGenerationPort

const DEFAULT_LANGUAGE := "pl-PL"
const DEFAULT_SFX_STYLE := "kid_safe_sfx_pl"
const DEFAULT_MUSIC_STYLE := "ambient_kids_pl"

var _api_key: String = ""
var _default_language: String = DEFAULT_LANGUAGE
var _enforce_non_lyrical: bool = true
var _last_generation_metadata: Dictionary = {}


func setup(
	api_key: String = "",
	default_language: String = DEFAULT_LANGUAGE,
	enforce_non_lyrical: bool = true
) -> ElevenLabsAudioGenerationAdapter:
	_api_key = api_key
	_default_language = default_language.strip_edges() if not default_language.strip_edges().is_empty() else DEFAULT_LANGUAGE
	_enforce_non_lyrical = enforce_non_lyrical
	_last_generation_metadata = {}
	return self


func generate_sfx(description: String) -> PackedByteArray:
	return _generate("sfx", description, DEFAULT_SFX_STYLE)


func generate_music(description: String) -> PackedByteArray:
	return _generate("music", description, DEFAULT_MUSIC_STYLE)


func get_last_generation_metadata() -> Dictionary:
	return _last_generation_metadata.duplicate(true)


func _generate(kind: String, description: String, style: String) -> PackedByteArray:
	var trimmed_description := description.strip_edges()
	if trimmed_description.is_empty():
		_last_generation_metadata = {
			"provider": "elevenlabs",
			"content_kind": kind,
			"style_preset": style,
			"language": _default_language,
			"is_lyrical": false,
			"license_id": "elevenlabs-default",
			"attribution": "Generated with ElevenLabs",
			"allow_publish": true,
			"is_empty": true,
		}
		return PackedByteArray()

	var non_lyrical_tag := "bez wokalu" if _enforce_non_lyrical else "wokal dozwolony"
	var prompt := "%s | %s | %s | %s" % [
		kind,
		style,
		_default_language,
		"%s (%s)" % [trimmed_description, non_lyrical_tag],
	]

	_last_generation_metadata = {
		"provider": "elevenlabs",
		"content_kind": kind,
		"style_preset": style,
		"language": _default_language,
		"is_lyrical": not _enforce_non_lyrical,
		"license_id": "elevenlabs-default",
		"attribution": "Generated with ElevenLabs",
		"allow_publish": true,
		"watermark_tag": "ai_audio",
		"api_key_configured": not _api_key.is_empty(),
	}

	return ("ELV_AUDIO|%s" % prompt).to_utf8_buffer()
