class_name ElevenLabsTTSAdapterContractTest
extends PortContractTest


func run() -> Dictionary:
	_reset()
	var adapter := ElevenLabsTTSAdapter.new().setup()

	_assert_has_method(adapter, "synthesize")
	_assert_has_method(adapter, "resolve_voice_for_role")
	_assert_has_method(adapter, "get_last_request_metadata")

	var narration_audio := adapter.synthesize("Witaj w naszej grze!", "narration", "")
	_assert_packed_byte_array(
		narration_audio,
		"ElevenLabsTTSAdapter.synthesize(narration)"
	)
	_assert_true(
		narration_audio.size() > 0,
		"Narration synthesis should return non-empty audio bytes for non-empty text"
	)

	var narration_meta := adapter.get_last_request_metadata()
	_assert_true(
		str(narration_meta.get("language", "")) == "pl-PL",
		"Narration should default to Polish language"
	)
	_assert_true(
		str(narration_meta.get("voice_preset", "")) == "narrator_pl",
		"Narration role should resolve to approved Polish narrator preset"
	)

	var npc_audio := adapter.synthesize("Pomoge ci przejsc poziom.", "npc", "en-US")
	_assert_true(
		npc_audio.size() > 0,
		"NPC synthesis should produce audio bytes"
	)
	var npc_meta := adapter.get_last_request_metadata()
	_assert_true(
		str(npc_meta.get("language", "")) == "pl-PL",
		"NPC voice should still enforce Polish by default even if non-Polish requested"
	)
	_assert_true(
		str(npc_meta.get("voice_preset", "")) == "npc_helper_pl",
		"NPC role should resolve to approved Polish NPC preset"
	)

	var empty_audio := adapter.synthesize("", "narration", "pl-PL")
	_assert_packed_byte_array(
		empty_audio,
		"ElevenLabsTTSAdapter.synthesize(empty_text)"
	)
	_assert_true(
		empty_audio.size() == 0,
		"Empty narration text should return empty audio bytes"
	)

	return _build_result("ElevenLabsTTSAdapter")
