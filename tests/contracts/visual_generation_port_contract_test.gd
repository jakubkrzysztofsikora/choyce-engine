class_name VisualGenerationPortContractTest
extends PortContractTest


func run() -> Dictionary:
	_reset()
	var port := VisualGenerationPort.new()

	_assert_has_method(port, "generate_image")

	var result := port.generate_image("Przyjazny smok", "cartoon", "pl-PL")
	_assert_dictionary(result, "VisualGenerationPort.generate_image(prompt, style, language)")
	_assert_true(
		result.has("image_bytes"),
		"Visual generation payload should include image_bytes"
	)
	_assert_true(
		result.has("mime_type"),
		"Visual generation payload should include mime_type"
	)
	_assert_true(
		result.has("provider_asset_id"),
		"Visual generation payload should include provider_asset_id"
	)
	_assert_true(
		result.has("metadata"),
		"Visual generation payload should include metadata dictionary"
	)

	var empty := port.generate_image("", "", "")
	_assert_dictionary(empty, "VisualGenerationPort.generate_image(empty)")

	return _build_result("VisualGenerationPort")
