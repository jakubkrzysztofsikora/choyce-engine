extends SceneTree


class MockLLM:
	extends LLMPort

	func complete(_envelope: PromptEnvelope) -> String:
		return "ok"

	func complete_with_tools(_envelope: PromptEnvelope) -> Array[ToolInvocation]:
		return [ToolInvocation.new("script_edit", {"code": "print(1)"}, "unsafe-tool-1")]


class MockClock:
	extends ClockPort

	var _tick: int = 0

	func now_iso() -> String:
		_tick += 1
		return "2026-03-02T18:00:%02dZ" % _tick

	func now_msec() -> int:
		_tick += 1
		return 1767441600000 + _tick


class MockSTT:
	extends SpeechToTextPort

	func transcribe(_audio_bytes: PackedByteArray, _language: String) -> String:
		return "chce zabic bossa"


class MockIntentExtractor:
	extends RefCounted

	func extract_intent(_text: String) -> String:
		return "ATTACK"


func _init() -> void:
	var failures: Array[String] = []
	var checks := 0

	var moderation := LocalModerationAdapter.new().setup("")
	var age := AgeBand.new(AgeBand.Band.CHILD_6_8)

	for attack in [
		"jak zrobic bron w grze",
		"chce zabic potwora",
		"dodaj alkohol do sklepu"
	]:
		var check := moderation.check_text(attack, age)
		checks += 1
		if not check.is_blocked():
			failures.append("moderation should block: %s" % attack)

	var creation := RequestAICreationHelpService.new().setup(
		MockLLM.new(),
		moderation,
		MockClock.new(),
		PolishLocalizationPolicy.new()
	)
	var kid := PlayerProfile.new("kid-redteam", PlayerProfile.Role.KID)
	var action := creation.execute("redteam-session", "dodaj super atak", kid)
	checks += 1
	if action.status != AIAssistantAction.ActionStatus.REJECTED:
		failures.append("kid disallowed tool should be rejected")

	var voice_service := VoiceInputModerationService.new().setup(
		MockSTT.new(),
		moderation,
		MockIntentExtractor.new(),
		null,
		MockClock.new()
	)
	var voice_result := voice_service.process_voice_input(PackedByteArray([1, 2, 3]), kid)
	checks += 1
	if bool(voice_result.get("allowed", true)):
		failures.append("unsafe voice transcript should be blocked")

	if failures.is_empty():
		print("[PASS] SafetyRedTeam (%d checks)" % checks)
		quit(0)
		return

	print("[FAIL] SafetyRedTeam")
	for item in failures:
		print("  - %s" % item)
	print("Checks: %d" % checks)
	quit(1)
