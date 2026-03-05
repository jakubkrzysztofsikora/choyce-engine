## Child-safe visual generation adapter with fixed style presets.
## This adapter represents a provider boundary (e.g., local diffusion/cloud API)
## while keeping deterministic output behavior for tests.
class_name SafePresetVisualGenerationAdapter
extends VisualGenerationPort

const DEFAULT_LANGUAGE := "pl-PL"
const SAFE_STYLE_PRESETS := [
	"cartoon",
	"storybook",
	"lowpoly",
	"pixel_fantasy",
	"watercolor",
]

var _api_key: String = ""
var _default_language: String = DEFAULT_LANGUAGE
var _allowed_styles: Array[String] = []
var _last_generation_metadata: Dictionary = {}


func setup(
	api_key: String = "",
	default_language: String = DEFAULT_LANGUAGE,
	allowed_styles: Array[String] = []
) -> SafePresetVisualGenerationAdapter:
	_api_key = api_key
	_default_language = default_language.strip_edges() if not default_language.strip_edges().is_empty() else DEFAULT_LANGUAGE
	_allowed_styles = []
	var source: Array = []
	if allowed_styles.is_empty():
		source = SAFE_STYLE_PRESETS
	else:
		source = allowed_styles
	for style in source:
		var normalized := str(style).strip_edges().to_lower()
		if normalized.is_empty():
			continue
		if not _allowed_styles.has(normalized):
			_allowed_styles.append(normalized)
	_last_generation_metadata = {}
	return self


func generate_image(prompt: String, style_preset: String, language: String) -> Dictionary:
	var trimmed_prompt := prompt.strip_edges()
	if trimmed_prompt.is_empty():
		_last_generation_metadata = {
			"provider": "safe_preset_generator",
			"style_preset": _resolve_style(style_preset),
			"language": _resolve_language(language),
			"is_empty": true,
		}
		return {
			"image_bytes": PackedByteArray(),
			"mime_type": "image/png",
			"provider_asset_id": "",
			"metadata": _last_generation_metadata.duplicate(true),
		}

	var resolved_style := _resolve_style(style_preset)
	var resolved_language := _resolve_language(language)
	var provider_asset_id := "img_%d" % absi(("%s|%s|%s" % [trimmed_prompt, resolved_style, resolved_language]).hash())
	var image_bytes := _build_png_like_bytes("%s|%s" % [trimmed_prompt, resolved_style])

	_last_generation_metadata = {
		"provider": "safe_preset_generator",
		"style_preset": resolved_style,
		"language": resolved_language,
		"provider_asset_id": provider_asset_id,
		"api_key_configured": not _api_key.is_empty(),
	}
	return {
		"image_bytes": image_bytes,
		"mime_type": "image/png",
		"provider_asset_id": provider_asset_id,
		"metadata": _last_generation_metadata.duplicate(true),
	}


func get_allowed_styles() -> Array[String]:
	return _allowed_styles.duplicate()


func get_last_generation_metadata() -> Dictionary:
	return _last_generation_metadata.duplicate(true)


func _resolve_style(style_preset: String) -> String:
	var normalized := style_preset.strip_edges().to_lower()
	if normalized.is_empty():
		return _allowed_styles[0] if not _allowed_styles.is_empty() else "cartoon"
	if _allowed_styles.has(normalized):
		return normalized
	return _allowed_styles[0] if not _allowed_styles.is_empty() else "cartoon"


func _resolve_language(language: String) -> String:
	var normalized := language.strip_edges()
	if normalized.is_empty():
		return _default_language
	if normalized.begins_with("pl"):
		return "pl-PL"
	return _default_language


func _build_png_like_bytes(seed: String) -> PackedByteArray:
	var bytes := PackedByteArray()
	bytes.resize(256)
	bytes.fill(0)
	# PNG signature for moderation format checks.
	bytes[0] = 137
	bytes[1] = 80
	bytes[2] = 78
	bytes[3] = 71
	var encoded := seed.to_utf8_buffer()
	for i in range(mini(encoded.size(), 200)):
		bytes[8 + i] = encoded[i]
	return bytes
