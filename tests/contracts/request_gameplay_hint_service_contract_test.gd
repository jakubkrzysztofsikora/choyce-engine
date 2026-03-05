class_name RequestGameplayHintServiceContractTest
extends PortContractTest


class MockLLM:
	extends LLMPort

	var response: String = "Sprawdz najpierw wejscie do sklepu."
	var provider: String = "ollama-local"
	var complete_calls: int = 0
	var last_locale: String = ""

	func complete(envelope: PromptEnvelope) -> String:
		complete_calls += 1
		last_locale = envelope.language
		return response

	func complete_with_tools(_envelope: PromptEnvelope) -> Array[ToolInvocation]:
		return []

	func get_last_provider() -> String:
		return provider


class MockModeration:
	extends ModerationPort

	func check_text(_text: String, _age_band: AgeBand) -> ModerationResult:
		return ModerationResult.new(ModerationResult.Verdict.PASS, "")

	func check_image(_image_data: PackedByteArray, _age_band: AgeBand) -> ModerationResult:
		return ModerationResult.new(ModerationResult.Verdict.PASS, "")


class MockClock:
	extends ClockPort

	var _tick: int = 0

	func now_iso() -> String:
		_tick += 1
		return "2026-03-02T16:30:%02dZ" % _tick

	func now_msec() -> int:
		_tick += 1
		return 1767429000000 + _tick


class MockLocalization:
	extends LocalizationPolicyPort

	var locale: String = "pl-PL"

	func get_locale() -> String:
		return locale

	func translate(key: String) -> String:
		return key

	func is_term_safe(_term: String) -> bool:
		return true


func run() -> Dictionary:
	_reset()

	var llm := MockLLM.new()
	var failsafe := AIFailsafeController.new().setup(false)
	var service := RequestGameplayHintService.new().setup(
		llm,
		MockModeration.new(),
		MockClock.new(),
		MockLocalization.new(),
		DomainEventBus.new(),
		failsafe
	)
	var kid := PlayerProfile.new("kid-hint", PlayerProfile.Role.KID)

	var normal := service.execute(
		"session-normal",
		{"hint_level": 1, "quest_id": "q1", "situation": "Brak monet", "objective": "zdobadz monety"},
		kid
	)
	_assert_true(
		str(normal.get("hint_text", "")) == llm.response,
		"When model is available, hint service should return model hint output"
	)
	_assert_true(
		not str(normal.get("quest_suggestion", "")).strip_edges().is_empty(),
		"Hint response should include adaptive quest suggestion text"
	)
	_assert_true(
		not bool(normal.get("reveals_full_solution", true)),
		"Hint response should mark that full solution is not revealed by default"
	)

	llm.response = ""
	llm.provider = "fallback"
	var degraded := service.execute(
		"session-degraded",
		{"hint_level": 2, "quest_id": "q2", "objective": "otworz brame"},
		kid
	)
	_assert_true(
		not str(degraded.get("hint_text", "")).strip_edges().is_empty(),
		"When model is unavailable, rules-based helper hint should be returned"
	)

	llm.response = "Najpierw kliknij czerwony przycisk i wykonaj dokladna odpowiedz."
	llm.provider = "ollama-local"
	var guarded := service.execute(
		"session-guarded",
		{"hint_level": 2, "quest_id": "q-guard", "objective": "otworz brame"},
		kid
	)
	_assert_true(
		not str(guarded.get("hint_text", "")).to_lower().contains("najpierw kliknij"),
		"Scaffold guard should replace full-solution-style hint wording"
	)

	llm.response = "Spróbuj znaleźć stabilne podpory."
	var adaptive := service.execute(
		"session-adaptive",
		{
			"hint_level": 1,
			"quest_id": "q4",
			"situation": "Nie wiem co dalej",
			"objective": "zbuduj most",
			"recent_failures": 4,
			"stuck_seconds": 300,
		},
		kid
	)
	_assert_true(
		int(adaptive.get("hint_level", 0)) == 2,
		"Adaptive hinting should gently raise hint level when child is stuck"
	)
	var adaptive_diff: Dictionary = adaptive.get("difficulty_adjustment", {})
	_assert_true(
		float(adaptive_diff.get("difficulty_scalar", 0.0)) <= 0.9,
		"Adaptive difficulty should ease challenge after repeated failures"
	)
	_assert_true(
		not str(adaptive.get("quest_suggestion", "")).strip_edges().is_empty(),
		"Adaptive response should include a concrete mini-quest suggestion"
	)

	var calls_before := llm.complete_calls
	failsafe.enable("maintenance")
	llm.response = "Ten tekst nie powinien byc uzyty."
	llm.provider = "ollama-local"
	var forced := service.execute(
		"session-failsafe",
		{"hint_level": 3, "quest_id": "q3", "objective": "zbuduj most"},
		kid
	)
	_assert_true(
		not str(forced.get("hint_text", "")).strip_edges().is_empty(),
		"Failsafe mode should still return deterministic helper hint"
	)
	_assert_true(
		llm.complete_calls == calls_before,
		"Failsafe mode should bypass generative LLM calls"
	)

	# Parent override may use non-Polish locale; kid path remains Polish-first.
	var en_localization := MockLocalization.new()
	en_localization.locale = "en-US"
	var policy_store := InMemoryParentalPolicyStore.new().setup()
	policy_store.save_policy(
		"parent-hint",
		ParentalControlPolicy.new(
			60,
			30,
			ParentalControlPolicy.AIAccessLevel.CREATIVE_ONLY,
			false,
			true,
			false
		)
	)
	var locale_service := RequestGameplayHintService.new().setup(
		llm,
		MockModeration.new(),
		MockClock.new(),
		en_localization,
		DomainEventBus.new(),
		AIFailsafeController.new().setup(false),
		policy_store
	)
	var parent := PlayerProfile.new("parent-hint", PlayerProfile.Role.PARENT)
	parent.language = "en-US"
	locale_service.execute("session-parent-locale", {"hint_level": 1, "situation": "Need help"}, parent)
	_assert_true(
		llm.last_locale == "en-US",
		"Parent with override enabled should use non-Polish prompt locale"
	)

	var kid_override := PlayerProfile.new("kid-hint-2", PlayerProfile.Role.KID)
	kid_override.language = "en-US"
	locale_service.execute("session-kid-locale", {"hint_level": 1, "situation": "Need help"}, kid_override)
	_assert_true(
		llm.last_locale == "pl-PL",
		"Kid hint prompts should remain Polish even when parent override exists"
	)

	return _build_result("RequestGameplayHintService")
