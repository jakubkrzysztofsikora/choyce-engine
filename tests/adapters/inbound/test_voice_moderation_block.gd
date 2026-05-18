## tests/adapters/inbound/test_voice_moderation_block.gd
## FR-022 critical fix: voice overlay must NOT call AI port when ModeratingSttAdapter
## returns BLOCKED or when STT fails (empty transcript, no block).
##
## Test cases:
##   1. STT returns "" + last_result.blocked=true  → blocked toast shown, AI NOT called
##   2. STT returns "" + last_result={}            → no-speech toast shown, AI NOT called
##   3. STT returns "stwórz drzewo" + last_result.blocked=false → AI called with transcript
extends SceneTree

const VoiceAssistantOverlay = preload("res://src/adapters/inbound/shared/ui/voice_assistant_overlay.gd")
const SpeechToTextPort = preload("res://src/ports/outbound/speech_to_text_port.gd")
const RequestAICreationHelpPort = preload("res://src/ports/inbound/request_ai_creation_help_port.gd")
const AIAssistantAction = preload("res://src/domain/ai_orchestration/ai_assistant_action.gd")
const PlayerProfile = preload("res://src/domain/gameplay/player_profile.gd")

# ---------------------------------------------------------------------------
# Mock STT with last_result side-channel (mimics ModeratingSttAdapter shape)
# ---------------------------------------------------------------------------

class MockModeratingStt extends SpeechToTextPort:
	var _return_transcript: String = ""
	var last_result: Dictionary = {}

	func setup_scenario(transcript: String, result: Dictionary) -> void:
		_return_transcript = transcript
		last_result = result

	func transcribe(_audio: PackedByteArray, _lang: String) -> String:
		return _return_transcript


# ---------------------------------------------------------------------------
# Mock AI help port — counts calls and records prompt
# ---------------------------------------------------------------------------

class MockAIHelp extends RequestAICreationHelpPort:
	var execute_call_count := 0
	var last_prompt: String = ""

	func execute(_session_id: String, prompt: String, _actor: PlayerProfile, _preview: bool = false) -> AIAssistantAction:
		execute_call_count += 1
		last_prompt = prompt
		var action := AIAssistantAction.new("act_test", prompt)
		action.status = AIAssistantAction.ActionStatus.PROPOSED
		return action

	func execute_pending_action(action: AIAssistantAction, _actor: PlayerProfile) -> AIAssistantAction:
		action.status = AIAssistantAction.ActionStatus.APPLIED
		return action


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

var _exit_code := 0


func _init() -> void:
	call_deferred("_run_tests")


func _assert(condition: bool, message: String) -> void:
	if not condition:
		print("FAIL: %s" % message)
		_exit_code = 1
	else:
		print("PASS: %s" % message)


func _make_overlay(stt: MockModeratingStt, ai: MockAIHelp) -> VoiceAssistantOverlay:
	var overlay := VoiceAssistantOverlay.new()
	get_root().add_child(overlay)
	var profile := PlayerProfile.new("kid_test", PlayerProfile.Role.KID)
	overlay.setup(stt, ai, profile, "session_test")
	# Unlock the ports_ready gate so _on_record_pressed proceeds past the gate.
	overlay.notify_ports_ready()
	return overlay


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

func _run_tests() -> void:
	print("=== FR-022: voice overlay moderation block tests ===")

	await _test_blocked_transcript_does_not_call_ai()
	await _test_blocked_transcript_shows_blocked_toast()
	await _test_empty_not_blocked_does_not_call_ai()
	await _test_empty_not_blocked_shows_no_speech_toast()
	await _test_safe_transcript_calls_ai_with_correct_prompt()

	quit(_exit_code)


## 1. STT BLOCKED → AI port NOT called.
func _test_blocked_transcript_does_not_call_ai() -> void:
	var stt := MockModeratingStt.new()
	stt.setup_scenario("", {"blocked": true, "reason": "jailbreak_attempt", "allowed": false})
	var ai := MockAIHelp.new()
	var overlay := _make_overlay(stt, ai)

	overlay.call("_on_record_pressed")
	await create_timer(1.5).timeout

	_assert(
		ai.execute_call_count == 0,
		"BLOCKED transcript: AI port execute NOT called"
	)

	overlay.queue_free()
	await process_frame


## 2. STT BLOCKED → blocked toast label visible with correct text.
func _test_blocked_transcript_shows_blocked_toast() -> void:
	var stt := MockModeratingStt.new()
	stt.setup_scenario("", {"blocked": true, "reason": "jailbreak_attempt", "allowed": false})
	var ai := MockAIHelp.new()
	var overlay := _make_overlay(stt, ai)

	overlay.call("_on_record_pressed")
	await create_timer(1.5).timeout

	var status_label = overlay.get("_status_label")
	_assert(
		status_label != null,
		"BLOCKED transcript: _status_label node exists on overlay"
	)
	if status_label != null:
		_assert(
			status_label.visible == true,
			"BLOCKED transcript: _status_label is visible after blocked result"
		)
		# When no localization port is injected, _t() returns the key itself.
		# The label text should be either the Polish string or the fallback key.
		var text: String = str(status_label.text)
		_assert(
			text == "Spróbuj inaczej." or text == "voice.blocked_try_again",
			"BLOCKED transcript: status label shows blocked message (got: %s)" % text
		)

	overlay.queue_free()
	await process_frame


## 3. STT empty, NOT blocked (genuine no-speech) → AI port NOT called.
func _test_empty_not_blocked_does_not_call_ai() -> void:
	var stt := MockModeratingStt.new()
	stt.setup_scenario("", {})
	var ai := MockAIHelp.new()
	var overlay := _make_overlay(stt, ai)

	overlay.call("_on_record_pressed")
	await create_timer(1.5).timeout

	_assert(
		ai.execute_call_count == 0,
		"No-speech (empty, unblocked): AI port execute NOT called"
	)

	overlay.queue_free()
	await process_frame


## 4. STT empty, NOT blocked → no-speech toast shown.
func _test_empty_not_blocked_shows_no_speech_toast() -> void:
	var stt := MockModeratingStt.new()
	stt.setup_scenario("", {})
	var ai := MockAIHelp.new()
	var overlay := _make_overlay(stt, ai)

	overlay.call("_on_record_pressed")
	await create_timer(1.5).timeout

	var status_label = overlay.get("_status_label")
	_assert(
		status_label != null,
		"No-speech: _status_label node exists on overlay"
	)
	if status_label != null:
		_assert(
			status_label.visible == true,
			"No-speech: _status_label is visible after empty non-blocked result"
		)
		var text: String = str(status_label.text)
		_assert(
			text == "Nie usłyszałem cię. Spróbuj jeszcze raz." or text == "voice.no_speech",
			"No-speech: status label shows no-speech message (got: %s)" % text
		)

	overlay.queue_free()
	await process_frame


## 5. Safe non-empty transcript → AI called with the actual transcript.
func _test_safe_transcript_calls_ai_with_correct_prompt() -> void:
	var stt := MockModeratingStt.new()
	stt.setup_scenario("stwórz drzewo", {"blocked": false, "allowed": true})
	var ai := MockAIHelp.new()
	var overlay := _make_overlay(stt, ai)

	overlay.call("_on_record_pressed")
	await create_timer(1.5).timeout

	_assert(
		ai.execute_call_count == 1,
		"Safe transcript: AI port execute called exactly once"
	)
	_assert(
		ai.last_prompt == "stwórz drzewo",
		"Safe transcript: AI port called with exact transcript (got: %s)" % ai.last_prompt
	)

	overlay.queue_free()
	await process_frame
