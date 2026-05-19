## Wave C: Tests for RequestAICreationHelpService on_progress optional Callable.
## MUST criteria:
##   M1 - execute() accepts optional on_progress: Callable parameter (5th positional or named)
##   M2 - when on_progress is provided, LLM token callbacks are forwarded to on_progress
##   M3 - when on_progress is omitted (Callable()), tokens are silently discarded (no error)
##   M4 - on_progress does not change the return type or value of execute()
extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_execute_accepts_on_progress_param()
	_test_tokens_forwarded_when_on_progress_provided()
	_test_tokens_discarded_when_on_progress_omitted()
	_test_return_value_unchanged_with_on_progress()
	print("ALL_REQUEST_AI_CREATION_HELP_ON_PROGRESS_TESTS: PASS")
	quit(0)


## M1 - execute() signature accepts on_progress Callable param without error
func _test_execute_accepts_on_progress_param() -> void:
	var service := _build_service(MockLLMCapturingTokens.new())
	var kid := PlayerProfile.new("kid_1", PlayerProfile.Role.KID)
	var tokens_received: Array[String] = []
	# Should not error — just passing the callable
	var _action := service.execute(
		"session-1",
		"Dodaj drzewo.",
		kid,
		false,
		Callable(),
		func(t: String) -> void: tokens_received.append(t)
	)
	print("PASS M1: execute() accepted on_progress param without error")


## M2 - tokens from LLM on_token forwarded to on_progress when provided
func _test_tokens_forwarded_when_on_progress_provided() -> void:
	var mock_llm := MockLLMCapturingTokens.new()
	mock_llm.emit_tokens = ["To ", "be", "dzie ", "zmia", "na."]
	var service := _build_service(mock_llm)
	var kid := PlayerProfile.new("kid_1", PlayerProfile.Role.KID)
	var tokens_received: Array[String] = []
	service.execute(
		"session-1",
		"Dodaj drzewo.",
		kid,
		false,
		Callable(),
		func(t: String) -> void: tokens_received.append(t)
	)
	if tokens_received.size() != mock_llm.emit_tokens.size():
		print("FAIL M2: expected %d tokens forwarded, got %d: %s" % [
			mock_llm.emit_tokens.size(), tokens_received.size(), str(tokens_received)
		])
		quit(1)
		return
	print("PASS M2: all %d LLM tokens forwarded to on_progress" % tokens_received.size())


## M3 - omitting on_progress (default Callable()) causes no error, tokens discarded
func _test_tokens_discarded_when_on_progress_omitted() -> void:
	var mock_llm := MockLLMCapturingTokens.new()
	mock_llm.emit_tokens = ["Zmiana ", "zatwierdzona."]
	var service := _build_service(mock_llm)
	var kid := PlayerProfile.new("kid_1", PlayerProfile.Role.KID)
	# No on_progress — should not crash
	var _action := service.execute("session-1", "Dodaj drzewo.", kid)
	print("PASS M3: tokens discarded silently when on_progress omitted")


## M4 - return value (AIAssistantAction) unaffected by on_progress presence
func _test_return_value_unchanged_with_on_progress() -> void:
	var service := _build_service(MockLLMCapturingTokens.new())
	var kid := PlayerProfile.new("kid_1", PlayerProfile.Role.KID)

	var action_without := service.execute("session-1", "Dodaj drzewo.", kid)
	var action_with := service.execute(
		"session-2",
		"Dodaj drzewo.",
		kid,
		false,
		Callable(),
		func(_t: String) -> void: pass
	)

	if not (action_without is AIAssistantAction):
		print("FAIL M4: action_without is not AIAssistantAction: %s" % str(action_without))
		quit(1)
		return
	if not (action_with is AIAssistantAction):
		print("FAIL M4: action_with is not AIAssistantAction: %s" % str(action_with))
		quit(1)
		return
	print("PASS M4: execute() returns AIAssistantAction regardless of on_progress")


func _build_service(mock_llm: LLMPort) -> RequestAICreationHelpService:
	var moderation := MockModeration.new()
	var clock := MockClock.new()
	var localization := MockLocalization.new()
	return RequestAICreationHelpService.new().setup(
		mock_llm,
		moderation,
		clock,
		localization
	)


class MockLLMCapturingTokens extends LLMPort:
	var emit_tokens: Array[String] = []

	func complete(
		_envelope: PromptEnvelope,
		_options: Dictionary,
		on_token: Callable,
		on_done: Callable
	) -> void:
		for token in emit_tokens:
			if on_token.is_valid():
				on_token.call(token)
		on_done.call({"text": "Zmiana zatwierdzona.", "provider": "mock", "model": "mock", "stopped": false})

	## Phase 8a async signature; sync escape hatch via _sync variant.
	func complete_with_tools(_envelope: PromptEnvelope, on_done: Callable = Callable()) -> void:
		var tools := [ToolInvocation.new("paint", {"color": "niebieski"}, "t1")]
		if on_done.is_valid():
			on_done.call(tools)

	func complete_with_tools_sync(_envelope: PromptEnvelope) -> Array[ToolInvocation]:
		return [ToolInvocation.new("paint", {"color": "niebieski"}, "t1")]


class MockModeration extends ModerationPort:
	func check_text(_text: String, _age_band: AgeBand) -> ModerationResult:
		return ModerationResult.new(ModerationResult.Verdict.PASS, "")

	func check_image(_image_data: PackedByteArray, _age_band: AgeBand) -> ModerationResult:
		return ModerationResult.new(ModerationResult.Verdict.PASS, "")


class MockClock extends ClockPort:
	var _tick: int = 0

	func now_iso() -> String:
		return "2026-05-18T00:00:%02dZ" % _tick

	func now_msec() -> int:
		_tick += 1
		return 1747526400000 + _tick


class MockLocalization extends LocalizationPolicyPort:
	func get_locale() -> String:
		return "pl-PL"

	func translate(key: String) -> String:
		return key

	func is_term_safe(_term: String) -> bool:
		return true

	func get_preferred_term(term_key: String) -> String:
		return term_key

	func get_parent_term(term_key: String) -> String:
		return term_key
