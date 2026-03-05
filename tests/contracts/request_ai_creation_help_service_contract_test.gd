class_name RequestAICreationHelpServiceContractTest
extends PortContractTest


class MockLLM:
	extends LLMPort

	var planned_tools: Array[ToolInvocation] = []
	var complete_calls: int = 0
	var tool_calls: int = 0
	var last_complete_locale: String = ""
	var last_tool_locale: String = ""

	func complete(envelope: PromptEnvelope) -> String:
		complete_calls += 1
		last_complete_locale = envelope.language
		return "To bedzie bezpieczna zmiana."

	func complete_with_tools(envelope: PromptEnvelope) -> Array[ToolInvocation]:
		tool_calls += 1
		last_tool_locale = envelope.language
		return planned_tools


class MockModeration:
	extends ModerationPort

	func check_text(text: String, _age_band: AgeBand) -> ModerationResult:
		if text.to_lower().contains("unsafe"):
			var blocked := ModerationResult.new(ModerationResult.Verdict.BLOCK, "unsafe")
			blocked.safe_alternative = "Wybierz bezpieczniejszy pomysl."
			return blocked
		return ModerationResult.new(ModerationResult.Verdict.PASS, "")

	func check_image(_image_data: PackedByteArray, _age_band: AgeBand) -> ModerationResult:
		return ModerationResult.new(ModerationResult.Verdict.PASS, "")


class MockClock:
	extends ClockPort

	var _tick: int = 0

	func now_iso() -> String:
		return "2026-03-02T13:00:%02dZ" % _tick

	func now_msec() -> int:
		_tick += 1
		return 1767416400000 + _tick


class MockLocalization:
	extends LocalizationPolicyPort

	var locale: String = "pl-PL"

	func get_locale() -> String:
		return locale

	func translate(key: String) -> String:
		return key

	func is_term_safe(_term: String) -> bool:
		return true


class MockToolGateway:
	extends ToolExecutionGateway

	var execute_calls: int = 0
	var rollback_calls: int = 0
	var fail_on_tool: String = ""

	func execute(invocation: ToolInvocation, _context: Dictionary = {}) -> Dictionary:
		execute_calls += 1
		if not fail_on_tool.is_empty() and invocation.tool_name == fail_on_tool:
			return {"ok": false, "error": "forced failure"}
		return {
			"ok": true,
			"undo_token": {
				"tool_name": invocation.tool_name,
				"token_id": "undo_%d" % execute_calls,
			}
		}

	func rollback(_undo_token: Dictionary, _context: Dictionary = {}) -> bool:
		rollback_calls += 1
		return true


func run() -> Dictionary:
	_reset()

	var llm := MockLLM.new()
	var moderation := MockModeration.new()
	var clock := MockClock.new()
	var localization := MockLocalization.new()
	var gateway := MockToolGateway.new()
	var bus := DomainEventBus.new(100)
	var service := RequestAICreationHelpService.new().setup(
		llm,
		moderation,
		clock,
		localization,
		bus,
		gateway
	)

	var kid := PlayerProfile.new("kid-1", PlayerProfile.Role.KID)
	llm.planned_tools = [ToolInvocation.new("paint", {"color": "zolty"}, "t1")]
	var low_impact := service.execute("session-1", "Pokoloruj domek.", kid)
	_assert_true(
		low_impact.status == AIAssistantAction.ActionStatus.APPLIED,
		"Low-impact action should execute transactionally and be marked APPLIED"
	)
	_assert_true(
		low_impact.provenance != null,
		"Applied AI action should carry provenance metadata"
	)
	if low_impact.provenance != null:
		_assert_true(
			low_impact.provenance.source == ProvenanceData.SourceType.AI_TEXT,
			"AI action provenance should mark AI_TEXT source"
		)
		_assert_true(
			low_impact.provenance.audit_id == low_impact.action_id,
			"AI action provenance should link to applied audit event id"
		)
	if not low_impact.tool_invocations.is_empty() and low_impact.tool_invocations[0] is ToolInvocation:
		var first_tool: ToolInvocation = low_impact.tool_invocations[0]
		_assert_true(
			str(first_tool.provenance.get("audit_id", "")) == low_impact.action_id,
			"Tool invocation provenance should inherit action audit linkage"
		)
	_assert_true(gateway.execute_calls == 1, "Low-impact action should execute one tool")
	_assert_true(
		bus.get_history("AIAssistanceApplied").size() == 1,
		"AIAssistanceApplied event should be emitted for applied low-impact action"
	)
	var applied_events: Array[DomainEvent] = bus.get_history("AIAssistanceApplied")
	if not applied_events.is_empty():
		_assert_true(
			applied_events[0].event_id == low_impact.action_id,
			"AIAssistanceApplied event id should match provenance audit linkage"
		)

	var parent := PlayerProfile.new("parent-1", PlayerProfile.Role.PARENT)
	llm.planned_tools = [
		ToolInvocation.new("scene_edit", {"op": 1}, "p1"),
		ToolInvocation.new("scene_edit", {"op": 2}, "p2"),
		ToolInvocation.new("scene_edit", {"op": 3}, "p3"),
		ToolInvocation.new("scene_edit", {"op": 4}, "p4"),
		ToolInvocation.new("scene_edit", {"op": 5}, "p5"),
		ToolInvocation.new("scene_edit", {"op": 6}, "p6"),
	]
	var execute_before := gateway.execute_calls
	var high_impact := service.execute("session-2", "Zrob duzo zmian naraz.", parent)
	_assert_true(
		high_impact.requires_parent_approval,
		"High-impact actions should require parent approval"
	)
	_assert_true(
		high_impact.status == AIAssistantAction.ActionStatus.PROPOSED,
		"High-impact actions should remain PROPOSED until explicit approval"
	)
	_assert_true(
		gateway.execute_calls == execute_before,
		"High-impact actions should not execute before approval"
	)

	llm.planned_tools = [ToolInvocation.new("script_edit", {"code": "print(1)"}, "bad1")]
	var rejected := service.execute("session-3", "Zmien kod.", kid)
	_assert_true(
		rejected.status == AIAssistantAction.ActionStatus.REJECTED,
		"Disallowed tools should be blocked at validation stage"
	)
	_assert_true(
		bus.get_history("SafetyInterventionTriggered").size() >= 1,
		"Validation block should emit safety intervention event"
	)

	llm.planned_tools = [
		ToolInvocation.new("scene_edit", {"op": "ok"}, "tx1"),
		ToolInvocation.new("paint", {"op": "fail"}, "tx2"),
	]
	gateway.fail_on_tool = "paint"
	var tx_failure := service.execute("session-4", "Dwie zmiany.", kid)
	_assert_true(
		tx_failure.status == AIAssistantAction.ActionStatus.REJECTED,
		"Transaction failure should reject action"
	)
	_assert_true(
		gateway.rollback_calls >= 1,
		"Transaction failure should rollback previously executed tools"
	)

	var failsafe := AIFailsafeController.new().setup(true, "maintenance")
	var failsafe_service := RequestAICreationHelpService.new().setup(
		llm,
		moderation,
		clock,
		localization,
		bus,
		gateway,
		null,
		failsafe
	)
	var tool_calls_before := llm.tool_calls
	var disabled := failsafe_service.execute("session-5", "Dodaj nowe zadanie.", kid)
	_assert_true(
		disabled.status == AIAssistantAction.ActionStatus.REJECTED,
		"Failsafe mode should reject generative AI creation actions"
	)
	_assert_true(
		disabled.explanation.to_lower().contains("tryb awaryjny"),
		"Failsafe rejection should explain that emergency mode is active"
	)
	_assert_true(
		llm.tool_calls == tool_calls_before,
		"Failsafe mode should bypass LLM tool-planning calls"
	)
	_assert_true(
		bus.get_history("SafetyInterventionTriggered").size() >= 2,
		"Failsafe rejection should emit a safety intervention event"
	)

	llm.planned_tools = [
		ToolInvocation.new(
			"visual_generate",
			{
				"project_id": "project-1",
				"world_id": "world-1",
				"prompt": "photoreal human portrait",
				"style_preset": "cartoon",
			},
			"visual-kid-1"
		)
	]
	var visual_blocked := service.execute("session-6", "Wygeneruj obraz postaci.", kid)
	_assert_true(
		visual_blocked.status == AIAssistantAction.ActionStatus.REJECTED,
		"Kid visual generation should reject photoreal-human requests during tool validation"
	)
	_assert_true(
		visual_blocked.explanation.to_lower().contains("photoreal"),
		"Visual validation rejection should explain photoreal-human policy block"
	)

	# Polish-first wrappers with parent-controlled override.
	var en_localization := MockLocalization.new()
	en_localization.locale = "en-US"
	var policy_store := InMemoryParentalPolicyStore.new().setup()
	policy_store.save_policy(
		"parent-override",
		ParentalControlPolicy.new(
			60,
			30,
			ParentalControlPolicy.AIAccessLevel.CREATIVE_ONLY,
			false,
			true,
			false
		)
	)
	var locale_service := RequestAICreationHelpService.new().setup(
		llm,
		moderation,
		clock,
		en_localization,
		bus,
		gateway,
		null,
		null,
		policy_store
	)
	var parent_override := PlayerProfile.new("parent-override", PlayerProfile.Role.PARENT)
	parent_override.language = "en-US"
	llm.planned_tools = [ToolInvocation.new("paint", {"color": "blue"}, "locale-parent")]
	locale_service.execute("session-locale-parent", "Zmien kolor.", parent_override)
	_assert_true(
		llm.last_tool_locale == "en-US",
		"Parent with language override enabled should use non-Polish prompt locale"
	)

	var kid_locale := PlayerProfile.new("kid-locale", PlayerProfile.Role.KID)
	kid_locale.language = "en-US"
	llm.planned_tools = [ToolInvocation.new("paint", {"color": "green"}, "locale-kid")]
	locale_service.execute("session-locale-kid", "Pokoloruj trawe.", kid_locale)
	_assert_true(
		llm.last_tool_locale == "pl-PL",
		"Kid prompts should stay Polish even when global locale is non-Polish"
	)

	return _build_result("RequestAICreationHelpService")
