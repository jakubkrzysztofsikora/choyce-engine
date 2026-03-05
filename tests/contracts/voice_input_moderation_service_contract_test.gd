class_name VoiceInputModerationServiceContractTest
extends PortContractTest


class MockClock:
	extends ClockPort

	var _tick: int = 0

	func now_iso() -> String:
		_tick += 1
		return "2026-03-02T19:00:%02dZ" % _tick

	func now_msec() -> int:
		_tick += 1
		return 1767438000000 + _tick


class MockSTT:
	extends SpeechToTextPort

	var _responses: Dictionary = {}
	var _default_response: String = "chcę zbudować sklep"

	func set_response_for_size(size: int, response: String) -> void:
		_responses[size] = response

	func transcribe(audio: PackedByteArray, _language: String) -> String:
		if audio.is_empty():
			return ""
		if _responses.has(audio.size()):
			return _responses[audio.size()]
		return _default_response


class MockModeration:
	extends ModerationPort

	var _blocked_terms: Dictionary = {}

	func add_blocked_term(term: String, category: String, alternative: String) -> void:
		_blocked_terms[term] = {"category": category, "alternative": alternative}

	func check_text(text: String, _age_band: AgeBand) -> ModerationResult:
		for term in _blocked_terms:
			if text.to_lower().contains(term):
				var info: Dictionary = _blocked_terms[term]
				var result := ModerationResult.new(
					ModerationResult.Verdict.BLOCK,
					"Blocked: %s" % term
				)
				result.category = info["category"]
				result.safe_alternative = info["alternative"]
				return result
		return ModerationResult.new(ModerationResult.Verdict.PASS, "")

	func check_image(_image_data: PackedByteArray, _age_band: AgeBand) -> ModerationResult:
		return ModerationResult.new(ModerationResult.Verdict.BLOCK, "Not implemented")


class MockIntentExtractor:
	extends RefCounted

	func extract_intent(raw_transcript: String) -> String:
		if raw_transcript.strip_edges().is_empty():
			return ""
		var lower := raw_transcript.to_lower()
		if lower.contains("zbudować") or lower.contains("buduj"):
			return "CREATE_OBJECT"
		if lower.contains("usunąć") or lower.contains("usuń"):
			return "DELETE_OBJECT"
		if lower.contains("pomoc"):
			return "REQUEST_HELP"
		return "GENERAL_QUERY"


func run() -> Dictionary:
	_reset()

	var clock := MockClock.new()
	var stt := MockSTT.new()
	var moderation := MockModeration.new()
	var intent_extractor := MockIntentExtractor.new()
	var event_bus := DomainEventBus.new()

	moderation.add_blocked_term("zabij", "violence", "Spróbuj czegoś spokojniejszego!")
	moderation.add_blocked_term("broń", "weapons", "Może zbuduj coś fajnego!")
	moderation.add_blocked_term("zakazane", "unsafe", "")

	var service := VoiceInputModerationService.new().setup(
		stt, moderation, intent_extractor, event_bus, clock
	)

	var kid := PlayerProfile.new("kid-1", PlayerProfile.Role.KID)
	var parent := PlayerProfile.new("parent-1", PlayerProfile.Role.PARENT)

	# 1. Empty audio → transcription failed
	var empty_result := service.process_voice_input(PackedByteArray(), kid)
	_assert_true(
		not empty_result.get("allowed", true),
		"Empty audio should not be allowed"
	)
	_assert_true(
		empty_result.get("reason", "") == "TRANSCRIPTION_FAILED",
		"Empty audio reason should be TRANSCRIPTION_FAILED"
	)

	# 2. Safe Polish transcript → allowed with intent
	var safe_audio := PackedByteArray()
	safe_audio.resize(50)
	safe_audio.fill(1)
	var safe_result := service.process_voice_input(safe_audio, kid)
	_assert_true(
		safe_result.get("allowed", false),
		"Safe transcript should be allowed"
	)
	_assert_true(
		safe_result.get("transcript", "") == "chcę zbudować sklep",
		"Transcript should be 'chcę zbudować sklep'"
	)
	_assert_true(
		safe_result.get("intent", "") == "CREATE_OBJECT",
		"Intent should be CREATE_OBJECT for 'zbudować'"
	)

	# 3. Unsafe transcript (violence) → blocked with safe alternative
	stt.set_response_for_size(100, "zabij potwora")
	var unsafe_audio := PackedByteArray()
	unsafe_audio.resize(100)
	unsafe_audio.fill(2)
	var unsafe_result := service.process_voice_input(unsafe_audio, kid)
	_assert_true(
		not unsafe_result.get("allowed", true),
		"Unsafe transcript should be blocked"
	)
	_assert_true(
		unsafe_result.get("reason", "") == "VOICE_MODERATION_BLOCK",
		"Unsafe reason should be VOICE_MODERATION_BLOCK"
	)
	_assert_true(
		unsafe_result.get("category", "") == "violence",
		"Blocked category should be 'violence'"
	)
	_assert_true(
		not (unsafe_result.get("safe_alternative", "") as String).strip_edges().is_empty(),
		"Blocked result should include safe alternative"
	)

	# 4. Blocked transcript emits SafetyInterventionTriggeredEvent
	var safety_events := event_bus.get_history("SafetyInterventionTriggered")
	_assert_true(
		safety_events.size() >= 1,
		"At least one SafetyInterventionTriggeredEvent should be emitted for blocked voice"
	)
	if safety_events.size() >= 1:
		var evt: SafetyInterventionTriggeredEvent = safety_events[0]
		_assert_true(
			evt.policy_rule == "VOICE_TRANSCRIPT_MODERATION_BLOCK",
			"Policy rule should be VOICE_TRANSCRIPT_MODERATION_BLOCK"
		)
		_assert_true(
			evt.decision_type == "BLOCK",
			"Decision type should be BLOCK"
		)
		_assert_true(
			evt.trigger_context.begins_with("[VOICE]"),
			"Trigger context should start with [VOICE] prefix"
		)
		_assert_true(
			evt.safe_alternative_offered,
			"Safe alternative should be offered"
		)

	# 5. Weapons term also blocked
	stt.set_response_for_size(75, "daj mi broń")
	var weapon_audio := PackedByteArray()
	weapon_audio.resize(75)
	weapon_audio.fill(3)
	var weapon_result := service.process_voice_input(weapon_audio, kid)
	_assert_true(
		not weapon_result.get("allowed", true),
		"Weapons transcript should be blocked"
	)
	_assert_true(
		weapon_result.get("category", "") == "weapons",
		"Blocked category should be 'weapons'"
	)

	# 6. Null actor is rejected
	var null_actor := service.process_voice_input(safe_audio, null)
	_assert_true(
		not null_actor.get("allowed", true),
		"Null actor should not be allowed"
	)
	_assert_true(
		null_actor.get("reason", "") == "INVALID_ACTOR",
		"Null actor reason should be INVALID_ACTOR"
	)

	# 7. Parent can also use voice input (moderation still applies)
	var parent_result := service.process_voice_input(safe_audio, parent)
	_assert_true(
		parent_result.get("allowed", false),
		"Parent should be allowed for safe transcript"
	)

	# 8. Service works without optional intent extractor
	var no_intent := VoiceInputModerationService.new().setup(
		stt, moderation, null, event_bus, clock
	)
	stt._default_response = "chcę zbudować sklep"
	var no_intent_result := no_intent.process_voice_input(safe_audio, kid)
	_assert_true(
		no_intent_result.get("allowed", false),
		"Service without intent extractor should still allow safe input"
	)
	_assert_true(
		no_intent_result.get("intent", "x") == "",
		"Intent should be empty without extractor"
	)

	# 9. Service works without event bus (no crash)
	var no_bus := VoiceInputModerationService.new().setup(
		stt, moderation, intent_extractor
	)
	stt.set_response_for_size(200, "zabij wszystko")
	var crash_audio := PackedByteArray()
	crash_audio.resize(200)
	crash_audio.fill(4)
	var no_bus_result := no_bus.process_voice_input(crash_audio, kid)
	_assert_true(
		not no_bus_result.get("allowed", true),
		"Blocked voice without event bus should still return blocked"
	)

	# 10. Result shape has all required keys
	var required_keys := ["allowed", "transcript", "intent", "moderation_verdict",
						  "reason", "category", "safe_alternative"]
	for key in required_keys:
		_assert_true(
			safe_result.has(key),
			"Result should contain key: %s" % key
		)

	# 11. Missing moderation safe alternative falls back to default and still marks event as offered
	stt.set_response_for_size(125, "to jest zakazane")
	var fallback_audio := PackedByteArray()
	fallback_audio.resize(125)
	fallback_audio.fill(5)
	var fallback_result := service.process_voice_input(fallback_audio, kid)
	_assert_true(
		not fallback_result.get("allowed", true),
		"Transcript with blocked term should be denied"
	)
	_assert_true(
		str(fallback_result.get("safe_alternative", "")).strip_edges() == "Spróbuj powiedzieć coś innego!",
		"Service should provide a default safe alternative when moderation omits one"
	)
	var fallback_events := event_bus.get_history("SafetyInterventionTriggered")
	if fallback_events.size() > 0:
		var latest: SafetyInterventionTriggeredEvent = fallback_events[fallback_events.size() - 1]
		_assert_true(
			latest.safe_alternative_offered,
			"Safety event should mark safe_alternative_offered when fallback text is used"
		)

	# 12. Service without setup should fail closed
	var unconfigured := VoiceInputModerationService.new()
	var unconfigured_result := unconfigured.process_voice_input(safe_audio, kid)
	_assert_true(
		unconfigured_result.get("reason", "") == "SERVICE_NOT_READY",
		"Unconfigured service should return SERVICE_NOT_READY"
	)

	return _build_result("VoiceInputModerationService")
