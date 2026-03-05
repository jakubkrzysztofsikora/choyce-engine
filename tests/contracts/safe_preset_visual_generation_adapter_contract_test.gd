class_name SafePresetVisualGenerationAdapterContractTest
extends PortContractTest


func run() -> Dictionary:
	_reset()
	var adapter := SafePresetVisualGenerationAdapter.new().setup()

	_assert_has_method(adapter, "generate_image")
	_assert_has_method(adapter, "get_allowed_styles")
	_assert_has_method(adapter, "get_last_generation_metadata")

	var allowed := adapter.get_allowed_styles()
	_assert_true(
		allowed.has("cartoon"),
		"Safe preset adapter should expose child-safe style presets"
	)

	var generated := adapter.generate_image("Przyjazny smok", "cartoon", "pl-PL")
	_assert_dictionary(generated, "SafePresetVisualGenerationAdapter.generate_image")
	_assert_true(
		generated.get("image_bytes", PackedByteArray()) is PackedByteArray,
		"Generated payload should include image bytes"
	)
	var bytes: PackedByteArray = generated.get("image_bytes", PackedByteArray())
	_assert_true(
		bytes.size() > 4 and bytes[0] == 137 and bytes[1] == 80 and bytes[2] == 78 and bytes[3] == 71,
		"Generated image should include PNG magic header for moderation checks"
	)
	_assert_true(
		str(generated.get("mime_type", "")) == "image/png",
		"Generated images should return image/png mime type"
	)

	var fallback_style := adapter.generate_image("Miasto", "unsupported_style", "en-US")
	var fallback_meta: Dictionary = fallback_style.get("metadata", {})
	_assert_true(
		str(fallback_meta.get("style_preset", "")) == "cartoon",
		"Unsupported styles should fall back to safe default"
	)
	_assert_true(
		str(fallback_meta.get("language", "")) == "pl-PL",
		"Non-Polish language requests should fall back to Polish by default"
	)

	var empty := adapter.generate_image("", "cartoon", "pl-PL")
	var empty_bytes: PackedByteArray = empty.get("image_bytes", PackedByteArray())
	_assert_true(empty_bytes.is_empty(), "Empty prompt should produce empty image bytes")

	return _build_result("SafePresetVisualGenerationAdapter")
