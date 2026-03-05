class_name AudioGenerationPortContractTest
extends PortContractTest


func run() -> Dictionary:
	_reset()
	var port := AudioGenerationPort.new()

	_assert_has_method(port, "generate_sfx")
	_assert_has_method(port, "generate_music")
	_assert_has_method(port, "get_last_generation_metadata")

	var sfx := port.generate_sfx("Wesoły dźwięk nagrody")
	_assert_packed_byte_array(sfx, "AudioGenerationPort.generate_sfx(description)")

	var music := port.generate_music("Spokojna muzyka w tle")
	_assert_packed_byte_array(music, "AudioGenerationPort.generate_music(description)")

	var sfx_empty := port.generate_sfx("")
	_assert_packed_byte_array(sfx_empty, "AudioGenerationPort.generate_sfx(empty)")

	var music_empty := port.generate_music("")
	_assert_packed_byte_array(music_empty, "AudioGenerationPort.generate_music(empty)")

	var metadata := port.get_last_generation_metadata()
	_assert_dictionary(metadata, "AudioGenerationPort.get_last_generation_metadata()")

	return _build_result("AudioGenerationPort")
