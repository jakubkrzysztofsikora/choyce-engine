class_name TextToSpeechPortContractTest
extends PortContractTest


func run() -> Dictionary:
	_reset()
	var port := TextToSpeechPort.new()

	_assert_has_method(port, "synthesize")
	_assert_has_method(port, "resolve_voice_for_role")
	_assert_has_method(port, "get_last_request_metadata")

	var audio := port.synthesize("Witaj w grze!", "narrator_pl", "pl-PL")
	_assert_packed_byte_array(audio, "TextToSpeechPort.synthesize(text, voice, lang)")

	var empty_audio := port.synthesize("", "", "")
	_assert_packed_byte_array(empty_audio, "TextToSpeechPort.synthesize(empty, empty, empty)")

	var resolved_role := port.resolve_voice_for_role("narration", "pl-PL")
	_assert_string(resolved_role, "TextToSpeechPort.resolve_voice_for_role(role, language)")

	var metadata := port.get_last_request_metadata()
	_assert_dictionary(metadata, "TextToSpeechPort.get_last_request_metadata()")

	return _build_result("TextToSpeechPort")
