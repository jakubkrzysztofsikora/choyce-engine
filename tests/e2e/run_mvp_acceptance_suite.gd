extends SceneTree

const SUITE_NAME := "MVPAcceptanceE2E"

class InMemoryProjectStore:
	extends ProjectStorePort

	var _projects: Dictionary = {}

	func save_project(project: Project) -> bool:
		if project == null or project.project_id.strip_edges().is_empty():
			return false
		_projects[project.project_id] = project
		return true

	func load_project(project_id: String) -> Project:
		var value: Variant = _projects.get(project_id, null)
		if value is Project:
			return value
		return null

	func list_projects() -> Array:
		var rows: Array = []
		for value in _projects.values():
			if value is Project:
				rows.append(value)
		return rows


class MockClock:
	extends ClockPort

	var _tick: int = 0

	func now_iso() -> String:
		_tick += 1
		return "2026-03-05T14:00:%02dZ" % _tick

	func now_msec() -> int:
		_tick += 1
		return 1772719200000 + _tick


class MockLLM:
	extends LLMPort

	var planned_tools: Array[ToolInvocation] = []
	var tool_calls: int = 0

	func complete(
		_envelope: PromptEnvelope,
		_options: Dictionary,
		_on_token: Callable,
		on_done: Callable
	) -> void:
		on_done.call({"text": "Oto bezpieczna sugestia.", "provider": "mock", "model": "mock-m", "stopped": false})

	## Phase 8a async signature; sync escape hatch via _sync variant.
	func complete_with_tools(_envelope: PromptEnvelope, on_done: Callable = Callable()) -> void:
		tool_calls += 1
		if on_done.is_valid():
			on_done.call(planned_tools)

	func complete_with_tools_sync(_envelope: PromptEnvelope) -> Array[ToolInvocation]:
		tool_calls += 1
		return planned_tools


class MockToolGateway:
	extends ToolExecutionGateway

	var execute_calls: int = 0
	var rollback_calls: int = 0
	var fail_on_tool: String = ""

	func execute(invocation: ToolInvocation, _context: Dictionary = {}) -> Dictionary:
		execute_calls += 1
		if not fail_on_tool.is_empty() and invocation.tool_name == fail_on_tool:
			return {"ok": false, "error": "forced tool failure"}
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


class MockSTT:
	extends SpeechToTextPort

	var transcript: String = ""

	func transcribe(_audio: PackedByteArray, _language: String = "pl-PL") -> String:
		return transcript


class MockIntentExtractor:
	extends IntentExtractorPort

	func extract_intent(transcript: String) -> String:
		return transcript


class MockLocalization:
	extends LocalizationPolicyPort

	func get_locale() -> String:
		return "pl-PL"

	func translate(key: String) -> String:
		return key

	func is_term_safe(_term: String) -> bool:
		return true


var _checks_run: int = 0
var _failures: Array[String] = []


func _init() -> void:
	var scenarios: Array[Dictionary] = []
	scenarios.append(_run_kid_parent_publish_journey())
	scenarios.append(_run_safety_and_rollback_journey())

	var passed := _failures.is_empty()
	for failure in _failures:
		print("[FAIL] %s" % failure)

	var report := {
		"suite": SUITE_NAME,
		"timestamp_utc": Time.get_datetime_string_from_system(true),
		"checks_run": _checks_run,
		"failed_checks": _failures.size(),
		"passed": passed,
		"scenarios": scenarios,
	}

	print("MVP_ACCEPTANCE_REPORT_JSON=%s" % JSON.stringify(report))
	print("MVP acceptance scenarios: %d  Checks: %d  Failed checks: %d" % [
		scenarios.size(),
		_checks_run,
		_failures.size(),
	])

	quit(0 if passed else 1)


func _run_kid_parent_publish_journey() -> Dictionary:
	var scenario_id := "kid_create_play_ai_publish_parent_approval"
	var scenario_failures: Array[String] = []

	var clock := MockClock.new()
	var project_store := InMemoryProjectStore.new()
	var create_service := CreateProjectService.new().setup(project_store, clock)
	var playtest_service := RunPlaytestService.new().setup(project_store, clock)

	var llm := MockLLM.new()
	var moderation := LocalModerationAdapter.new().setup("")
	var localization := MockLocalization.new()
	var bus := DomainEventBus.new(200)
	var tool_gateway := MockToolGateway.new()
	var ai_service := RequestAICreationHelpService.new().setup(
		llm,
		moderation,
		clock,
		localization,
		bus,
		tool_gateway
	)

	var publish_store := InMemoryPublishStore.new().setup()
	var policy := PublishingPolicy.new()
	var role_secret := "role-token-signing-key-32-bytes!!!".to_utf8_buffer()
	var role_guard := RoleTokenGuard.new().setup(clock, role_secret)
	var publish_service := PublishToFamilyLibraryService.new().setup(
		project_store,
		publish_store,
		moderation,
		clock,
		policy,
		bus,
		role_guard
	)
	var review_service := ReviewPublishRequestService.new().setup(
		publish_store,
		policy,
		clock,
		bus,
		role_guard
	)

	var kid := PlayerProfile.new("kid-e2e", PlayerProfile.Role.KID)
	var parent := PlayerProfile.new("parent-e2e", PlayerProfile.Role.PARENT)

	var project := create_service.execute("farm", kid)
	_expect(project != null, "Project should be created from template", scenario_failures)
	if project == null:
		return _scenario_result(scenario_id, scenario_failures, {})

	var world := project.get_world("%s_world_1" % project.project_id)
	_expect(world != null, "Created project should include default world", scenario_failures)
	if world != null:
		var node := SceneNode.new("node-e2e", SceneNode.NodeType.OBJECT)
		node.display_name = "Drzewko"
		world.add_node(node)
		var rule := GameRule.new("rule-e2e", GameRule.RuleType.EVENT_TRIGGER)
		rule.display_name = "Start"
		world.add_rule(rule)
		project_store.save_project(project)

	var session := playtest_service.execute(world.world_id, [kid])
	_expect(session != null, "Playtest session should start for playable world", scenario_failures)
	if session != null:
		_expect(session.mode == Session.SessionMode.PLAY, "Single-player playtest should run in PLAY mode", scenario_failures)

	llm.planned_tools = [ToolInvocation.new("paint", {"color": "zielony"}, "e2e-paint-1")]
	var ai_action := ai_service.execute("session-e2e-1", "Pokoloruj trawnik.", kid)
	_expect(
		ai_action.status == AIAssistantAction.ActionStatus.APPLIED,
		"Kid AI assist should apply low-impact action",
		scenario_failures
	)
	_expect(tool_gateway.execute_calls >= 1, "AI assist should execute planned tool", scenario_failures)

	var request := publish_service.execute(project.project_id, world.world_id, kid)
	_expect(request != null, "Kid publish request should be created", scenario_failures)
	if request != null:
		_expect(
			request.state == PublishRequest.PublishState.PENDING_REVIEW,
			"Kid publish request should wait for parent approval",
			scenario_failures
		)

	var denied := review_service.execute(request.request_id, true, parent, "")
	_expect(denied == null, "Parent approval should fail without role token", scenario_failures)

	parent.preferences["role_token"] = RoleToken.issue(parent, clock, role_secret, 60)
	var approved := review_service.execute(request.request_id, true, parent, "")
	_expect(approved != null, "Parent approval should succeed with valid role token", scenario_failures)
	if approved != null:
		_expect(
			approved.state == PublishRequest.PublishState.PUBLISHED,
			"Approved request should transition to published",
			scenario_failures
		)

	var published_rows := publish_store.list_published()
	_expect(
		published_rows.size() == 1,
		"Published library should contain approved world",
		scenario_failures
	)

	return _scenario_result(
		scenario_id,
		scenario_failures,
		{
			"tool_exec_calls": tool_gateway.execute_calls,
			"published_count": published_rows.size(),
			"ai_tool_calls": llm.tool_calls,
		}
	)


func _run_safety_and_rollback_journey() -> Dictionary:
	var scenario_id := "safety_refusals_and_rollback_kid_parent_paths"
	var scenario_failures: Array[String] = []

	var clock := MockClock.new()
	var bus := DomainEventBus.new(200)
	var localization := MockLocalization.new()
	var moderation := LocalModerationAdapter.new().setup("")
	var llm := MockLLM.new()
	var tool_gateway := MockToolGateway.new()
	var ai_service := RequestAICreationHelpService.new().setup(
		llm,
		moderation,
		clock,
		localization,
		bus,
		tool_gateway
	)

	var kid := PlayerProfile.new("kid-safe", PlayerProfile.Role.KID)
	var parent := PlayerProfile.new("parent-safe", PlayerProfile.Role.PARENT)

	var kid_refusal := ai_service.execute("session-safe-1", "zabij przeciwnika", kid)
	_expect(
		kid_refusal.status == AIAssistantAction.ActionStatus.REJECTED,
		"Kid unsafe prompt should be rejected by safety moderation",
		scenario_failures
	)

	# Phase 3 hex fix: VoiceInputModerationService no longer takes SpeechToTextPort.
	# Transcript passed directly to process() — STT is handled by ModeratingSttAdapter.
	var voice_service := VoiceInputModerationService.new().setup(
		moderation,
		MockIntentExtractor.new(),
		bus,
		clock
	)
	var parent_voice := voice_service.process("chce zabic wszystko", parent)
	_expect(
		not bool(parent_voice.get("allowed", true)),
		"Parent voice path should be safety-blocked on unsafe transcript",
		scenario_failures
	)

	llm.planned_tools = [
		ToolInvocation.new("scene_edit", {"op": 1}, "kid-rb-1"),
		ToolInvocation.new("paint", {"op": 2}, "kid-rb-2"),
	]
	tool_gateway.fail_on_tool = "paint"
	var kid_rollback := ai_service.execute("session-safe-2", "Dwie zmiany naraz.", kid)
	_expect(
		kid_rollback.status == AIAssistantAction.ActionStatus.REJECTED,
		"Kid transactional failure should reject the action",
		scenario_failures
	)
	_expect(
		tool_gateway.rollback_calls >= 1,
		"Kid transactional failure should trigger rollback",
		scenario_failures
	)

	var patch_gateway := MockToolGateway.new()
	var patch_log := EventSourcedActionLog.new()
	var patch_service := AIPatchWorkflowService.new().setup(clock, patch_gateway, patch_log, bus)
	var parent_action := AIAssistantAction.new("parent-action-1", "Importuj asset")
	parent_action.tool_invocations = [ToolInvocation.new("asset_import", {"asset_ref": "res://tree.glb"}, "parent-rb-1")]
	patch_service.track_action(parent_action)

	var applied := patch_service.apply(parent_action.action_id, parent)
	_expect(
		applied.status == AIAssistantAction.ActionStatus.APPLIED,
		"Parent action should apply before undo",
		scenario_failures
	)
	var reverted := patch_service.undo(parent_action.action_id, parent)
	_expect(
		reverted.status == AIAssistantAction.ActionStatus.REVERTED,
		"Parent undo should revert applied action",
		scenario_failures
	)
	_expect(
		patch_gateway.rollback_calls == 1,
		"Parent undo should execute rollback path",
		scenario_failures
	)

	return _scenario_result(
		scenario_id,
		scenario_failures,
		{
			"kid_rollbacks": tool_gateway.rollback_calls,
			"parent_rollbacks": patch_gateway.rollback_calls,
			"safety_interventions": bus.get_history("SafetyInterventionTriggered").size(),
		}
	)


func _scenario_result(id: String, failures: Array[String], metrics: Dictionary) -> Dictionary:
	return {
		"id": id,
		"passed": failures.is_empty(),
		"failures": failures,
		"metrics": metrics,
	}


func _expect(condition: bool, message: String, scenario_failures: Array[String]) -> void:
	_checks_run += 1
	if condition:
		return
	scenario_failures.append(message)
	_failures.append(message)
