class_name SpeechToTextPortContractTest
extends PortContractTest


func run() -> Dictionary:
	_reset()
	var port := SpeechToTextPort.new()

	_assert_has_method(port, "transcribe")

	var transcript := port.transcribe(PackedByteArray(), "pl-PL")
	_assert_string(transcript, "SpeechToTextPort.transcribe(empty_audio, pl-PL)")

	var transcript_empty_lang := port.transcribe(PackedByteArray(), "")
	_assert_string(
		transcript_empty_lang,
		"SpeechToTextPort.transcribe(empty_audio, empty_language)"
	)

	return _build_result("SpeechToTextPort")
