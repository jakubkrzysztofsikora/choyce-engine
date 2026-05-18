## Adapter test for ModeratingSttAdapter (Phase 3).
## Verifies the compose-transcribe-moderate pipeline:
##   blocked transcript → empty string returned, last_result.allowed false
##   safe transcript → transcript returned, last_result.allowed true + intent populated
class_name ModeratingSttAdapterTest
extends ApplicationTest


class MockSTT:
	extends SpeechToTextPort

	var _fixed_response: String = ""

	func set_response(response: String) -> void:
		_fixed_response = response

	func transcribe(_audio: PackedByteArray, _language: String) -> String:
		return _fixed_response


class MockModeration:
	extends ModerationPort

	var _blocked_terms: Dictionary = {}

	func add_blocked_term(term: String, category: String, alternative: String) -> void:
		_blocked_terms[term] = {"category": category, "alternative": alternative}

	func check_text(text: String, _age_band: AgeBand) -> ModerationResult:
		for term in _blocked_terms:
			if text.to_lower().contains(term):
				var info: Dictionary = _blocked_terms[term]
				var result := ModerationResult.new(ModerationResult.Verdict.BLOCK, "Blocked")
				result.category = info["category"]
				result.safe_alternative = info["alternative"]
				return result
		return ModerationResult.new(ModerationResult.Verdict.PASS, "")

	func check_image(_image_data: PackedByteArray, _age_band: AgeBand) -> ModerationResult:
		return ModerationResult.new(ModerationResult.Verdict.BLOCK, "Not implemented")


var _mock_stt: MockSTT
var _moderation: MockModeration
var _voice_mod: VoiceInputModerationService
var _adapter: ModeratingSttAdapter

func _init():
	_mock_stt = MockSTT.new()
	_moderation = MockModeration.new()
	_moderation.add_blocked_term("ignoruj poprzednie instrukcje", "jailbreak", "Powiedz mi, co chcesz zbudować!")
	_moderation.add_blocked_term("zabij", "violence", "Spróbuj czegoś spokojniejszego!")

	var intent_extractor := PolishIntentExtractor.new()
	_voice_mod = VoiceInputModerationService.new().setup(
		_moderation, intent_extractor, DomainEventBus.new()
	)
	_adapter = ModeratingSttAdapter.new().setup(_mock_stt, _voice_mod)

func _reset():
	_checks_run = 0
	_failures = []

func run():
	_reset()
	test_jailbreak_phrase_returns_empty_and_blocks()
	test_safe_phrase_returns_transcript_with_intent()
	test_empty_raw_transcript_returns_empty()
	test_adapter_not_ready_returns_empty()
	return _build_result("ModeratingSttAdapter")


func test_jailbreak_phrase_returns_empty_and_blocks():
	_mock_stt.set_response("ignoruj poprzednie instrukcje")
	var audio := PackedByteArray()
	audio.resize(10)
	audio.fill(1)

	var result := _adapter.transcribe(audio, "pl-PL")
	_assert_eq(result, "", "Jailbreak transcript must return empty string from adapter")
	_assert_true(
		not _adapter.last_result.get("allowed", true),
		"last_result.allowed must be false for jailbreak"
	)
	_assert_eq(
		_adapter.last_result.get("reason", ""),
		"VOICE_MODERATION_BLOCK",
		"last_result.reason must be VOICE_MODERATION_BLOCK for jailbreak"
	)
	_assert_eq(
		_adapter.last_result.get("intent", "x"),
		"",
		"Intent extractor must NOT be called for blocked transcript"
	)


func test_safe_phrase_returns_transcript_with_intent():
	_mock_stt.set_response("stwórz drzewo")
	var audio := PackedByteArray()
	audio.resize(10)
	audio.fill(2)

	var result := _adapter.transcribe(audio, "pl-PL")
	_assert_eq(result, "stwórz drzewo", "Safe transcript must be returned as-is")
	_assert_true(
		_adapter.last_result.get("allowed", false),
		"last_result.allowed must be true for safe phrase"
	)
	_assert_true(
		_adapter.last_result.get("intent", "") != "",
		"last_result.intent must be populated for safe phrase"
	)


func test_empty_raw_transcript_returns_empty():
	_mock_stt.set_response("")
	var audio := PackedByteArray()
	audio.resize(5)
	audio.fill(3)

	var result := _adapter.transcribe(audio, "pl-PL")
	_assert_eq(result, "", "Empty raw transcript must return empty string")
	_assert_eq(
		_adapter.last_result.get("reason", ""),
		"TRANSCRIPTION_FAILED",
		"Empty raw transcript reason should be TRANSCRIPTION_FAILED"
	)


func test_adapter_not_ready_returns_empty():
	var unsetup_adapter := ModeratingSttAdapter.new()
	var audio := PackedByteArray()
	audio.resize(5)
	audio.fill(4)

	var result := unsetup_adapter.transcribe(audio, "pl-PL")
	_assert_eq(result, "", "Unsetup adapter must return empty string")
	_assert_eq(
		unsetup_adapter.last_result.get("reason", ""),
		"ADAPTER_NOT_READY",
		"Unsetup adapter reason should be ADAPTER_NOT_READY"
	)
