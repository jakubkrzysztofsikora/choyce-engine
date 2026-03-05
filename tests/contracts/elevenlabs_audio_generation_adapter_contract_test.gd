class_name ElevenLabsAudioGenerationAdapterContractTest
extends PortContractTest


func run() -> Dictionary:
	_reset()
	var adapter := ElevenLabsAudioGenerationAdapter.new().setup()

	_assert_has_method(adapter, "generate_sfx")
	_assert_has_method(adapter, "generate_music")
	_assert_has_method(adapter, "get_last_generation_metadata")

	var sfx := adapter.generate_sfx("Wesoly dzwiek nagrody")
	_assert_packed_byte_array(
		sfx,
		"ElevenLabsAudioGenerationAdapter.generate_sfx(description)"
	)
	_assert_true(
		sfx.size() > 0,
		"generate_sfx should return non-empty bytes for non-empty description"
	)
	var sfx_meta := adapter.get_last_generation_metadata()
	_assert_true(
		str(sfx_meta.get("content_kind", "")) == "sfx",
		"SFX metadata should identify content_kind as sfx"
	)
	_assert_true(
		str(sfx_meta.get("language", "")) == "pl-PL",
		"SFX metadata should use Polish default language"
	)
	_assert_true(
		not bool(sfx_meta.get("is_lyrical", true)),
		"SFX generation should be non-lyrical by default"
	)

	var music := adapter.generate_music("Spokojna muzyka tla dla farmy")
	_assert_packed_byte_array(
		music,
		"ElevenLabsAudioGenerationAdapter.generate_music(description)"
	)
	_assert_true(
		music.size() > 0,
		"generate_music should return non-empty bytes for non-empty description"
	)
	var music_meta := adapter.get_last_generation_metadata()
	_assert_true(
		str(music_meta.get("content_kind", "")) == "music",
		"Music metadata should identify content_kind as music"
	)
	_assert_true(
		not bool(music_meta.get("is_lyrical", true)),
		"Music generation should enforce non-lyrical defaults"
	)

	var empty := adapter.generate_music("")
	_assert_packed_byte_array(
		empty,
		"ElevenLabsAudioGenerationAdapter.generate_music(empty)"
	)
	_assert_true(
		empty.size() == 0,
		"Empty music description should return empty bytes"
	)

	return _build_result("ElevenLabsAudioGenerationAdapter")
