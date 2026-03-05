class_name ModerationPortContractTest
extends PortContractTest


func run() -> Dictionary:
	_reset()
	var port := ModerationPort.new()

	_assert_has_method(port, "check_text")
	_assert_has_method(port, "check_image")

	var age_band := AgeBand.new()
	var text_result := port.check_text("Bezpieczny opis", age_band)
	_assert_moderation_blocked(
		text_result,
		"ModerationPort.check_text(text, age_band)"
	)

	var text_result_null := port.check_text("", null)
	_assert_moderation_blocked(
		text_result_null,
		"ModerationPort.check_text(empty, null)"
	)

	var image_result := port.check_image(PackedByteArray(), age_band)
	_assert_moderation_blocked(
		image_result,
		"ModerationPort.check_image(empty_bytes, age_band)"
	)

	var image_result_null := port.check_image(PackedByteArray(), null)
	_assert_moderation_blocked(
		image_result_null,
		"ModerationPort.check_image(empty_bytes, null)"
	)

	return _build_result("ModerationPort")
