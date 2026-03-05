## Outbound port contract for input and output content moderation.
## Implementations can combine local rules and model-based checks.
class_name ModerationPort
extends RefCounted


func check_text(text: String, age_band: AgeBand) -> ModerationResult:
	push_error("ModerationPort.check_text() not implemented")
	return ModerationResult.new(
		ModerationResult.Verdict.BLOCK,
		"ModerationPort.check_text() not implemented"
	)


func check_image(image_data: PackedByteArray, age_band: AgeBand) -> ModerationResult:
	push_error("ModerationPort.check_image() not implemented")
	return ModerationResult.new(
		ModerationResult.Verdict.BLOCK,
		"ModerationPort.check_image() not implemented"
	)
