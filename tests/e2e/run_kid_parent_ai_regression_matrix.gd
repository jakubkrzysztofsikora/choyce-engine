extends SceneTree

const SUITE_NAME := "KidParentAIJourneyRegressionMatrix"


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
		return "2026-03-05T15:30:%02dZ" % _tick

	func now_msec() -> int:
		_tick += 1
		return 1772724600000 + _tick


class MockLLM:
	extends LLMPort

	var planned_tools: Array[ToolInvocation] = []
	var tool_calls: int = 0
	var completion_calls: int = 0

	func complete(_envelope: PromptEnvelope) -> String:
		completion_calls += 1
		return "To bezpieczna, krokowa sugestia dla rodziny."

	func complete_with_tools(_envelope: PromptEnvelope) -> Array[ToolInvocation]:
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


class MockLocalization:
	extends LocalizationPolicyPort

	func get_locale() -> String:
		return "pl-PL"

	func translate(key: String) -> String:
		return key

	func is_term_safe(_term: String) -> bool:
		return true


class FamilyShareFixture:
	extends RefCounted

	var _families: Dictionary = {}

	func add_family(family_id: String, member_ids: Array) -> void:
		if family_id.strip_edges().is_empty():
			return
		var normalized: Array[String] = []
		for member_variant in member_ids:
			var member_id := str(member_variant).strip_edges()
			if member_id.is_empty():
				continue
			if not normalized.has(member_id):
				normalized.append(member_id)
		_families[family_id] = normalized

	func visible_entries_for_actor(actor_id: String, published_rows: Array) -> Array:
		var actor_family := _resolve_family(actor_id)
		if actor_family.is_empty():
			return []

		var visible: Array = []
		for row_variant in published_rows:
			if not (row_variant is PublishRequest):
				continue
			var row: PublishRequest = row_variant
			if row.state != PublishRequest.PublishState.PUBLISHED:
				continue
			if row.visibility == PublishRequest.Visibility.PRIVATE:
				continue
			var requester_family := _resolve_family(row.requester_id)
			if requester_family == actor_family:
				visible.append(row)
		return visible

	func _resolve_family(actor_id: String) -> String:
		var clean_actor := actor_id.strip_edges()
		if clean_actor.is_empty():
			return ""
		for family_id_variant in _families.keys():
			var family_id := str(family_id_variant)
			var members_variant: Variant = _families.get(family_id, [])
			if members_variant is Array:
				var members: Array = members_variant
				if members.has(clean_actor):
					return family_id
		return ""


var _checks_run: int = 0
var _failures: Array[String] = []


func _init() -> void:
	var groups: Array[Dictionary] = []
	groups.append(_run_core_journeys_group())
	groups.append(_run_safety_policy_group())
	groups.append(_run_rollback_and_failsafe_group())

	var passed := _failures.is_empty()
	for failure in _failures:
		print("[FAIL] %s" % failure)

	var report := {
		"suite": SUITE_NAME,
		"timestamp_utc": Time.get_datetime_string_from_system(true),
		"checks_run": _checks_run,
		"failed_checks": _failures.size(),
		"passed": passed,
		"groups": groups,
	}

	print("KID_PARENT_AI_MATRIX_REPORT_JSON=%s" % JSON.stringify(report))
	print("Journey matrix groups: %d  Checks: %d  Failed checks: %d" % [
		groups.size(),
		_checks_run,
		_failures.size(),
	])

	quit(0 if passed else 1)


func _run_core_journeys_group() -> Dictionary:
	var scenarios: Array[Dictionary] = []
	scenarios.append(_scenario_create_play_ai_publish_family_share())
	return _group_result("core_journeys", scenarios)


func _run_safety_policy_group() -> Dictionary:
	var scenarios: Array[Dictionary] = []
	scenarios.append(_scenario_policy_restricted_and_moderation_blocks())
	return _group_result("safety_policy_gates", scenarios)


func _run_rollback_and_failsafe_group() -> Dictionary:
	var scenarios: Array[Dictionary] = []
	scenarios.append(_scenario_transactional_rollback_on_tool_failure())
	scenarios.append(_scenario_failsafe_mode_blocks_generation())
	return _group_result("rollback_and_failsafe", scenarios)


func _scenario_create_play_ai_publish_family_share() -> Dictionary:
	var scenario_id := "create_play_ai_publish_parent_approval_family_sharing"
	var scenario_failures: Array[String] = []

	var clock := MockClock.new()
	var bus := DomainEventBus.new(300)
	var project_store := InMemoryProjectStore.new()
	var create_service := CreateProjectService.new().setup(project_store, clock)
	var playtest_service := RunPlaytestService.new().setup(project_store, clock)

	var llm := MockLLM.new()
	var tool_gateway := MockToolGateway.new()
	var moderation := LocalModerationAdapter.new().setup("")
	var localization := MockLocalization.new()
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

	var kid := PlayerProfile.new("kid-main", PlayerProfile.Role.KID)
	var sibling := PlayerProfile.new("kid-sibling", PlayerProfile.Role.KID)
	var parent := PlayerProfile.new("parent-main", PlayerProfile.Role.PARENT)
	var outsider := PlayerProfile.new("kid-outsider", PlayerProfile.Role.KID)

	var project := create_service.execute("farm", kid)
	_expect(project != null, "Core journey should create a project", scenario_failures)
	if project == null:
		return _scenario_result(scenario_id, scenario_failures, {})

	var world := project.get_world("%s_world_1" % project.project_id)
	_expect(world != null, "Core journey should include a default world", scenario_failures)
	if world != null:
		world.name = "Rodzinna farma"
		var decorative := SceneNode.new("node-core-tree", SceneNode.NodeType.OBJECT)
		decorative.display_name = "Drzewko"
		world.add_node(decorative)
		project_store.save_project(project)

	var co_play_session := playtest_service.execute(world.world_id, [kid, parent])
	_expect(co_play_session != null, "Core journey should start co-op playtest", scenario_failures)
	if co_play_session != null:
		_expect(
			co_play_session.mode == Session.SessionMode.CO_OP,
			"Co-play journey should run as CO_OP session",
			scenario_failures
		)

	llm.planned_tools = [ToolInvocation.new("paint", {"palette": "pastel"}, "core-tool-1")]
	var ai_action := ai_service.execute("core-session-1", "Dodaj spokojne kolory.", kid)
	_expect(
		ai_action.status == AIAssistantAction.ActionStatus.APPLIED,
		"Core journey AI assist should apply safe low-impact tools",
		scenario_failures
	)
	_expect(
		tool_gateway.execute_calls == 1,
		"Core journey should execute exactly one deterministic tool call",
		scenario_failures
	)

	var request := publish_service.execute(project.project_id, world.world_id, kid)
	_expect(request != null, "Core journey should create publish request", scenario_failures)
	if request != null:
		_expect(
			request.state == PublishRequest.PublishState.PENDING_REVIEW,
			"Kid publish should remain pending parent review",
			scenario_failures
		)
		_expect(
			policy.is_visibility_allowed(kid, PublishRequest.Visibility.FAMILY),
			"Kid policy should allow FAMILY visibility",
			scenario_failures
		)
		_expect(
			request.set_visibility(PublishRequest.Visibility.FAMILY),
			"Pending publish request should support FAMILY visibility before publish",
			scenario_failures
		)
		publish_store.save_request(request)

	var denied := review_service.execute(request.request_id, true, parent, "")
	_expect(denied == null, "Parent approval should fail without role token", scenario_failures)

	parent.preferences["role_token"] = RoleToken.issue(parent, clock, role_secret, 60)
	var approved := review_service.execute(request.request_id, true, parent, "")
	_expect(approved != null, "Parent approval should succeed with valid token", scenario_failures)
	if approved != null:
		_expect(
			approved.state == PublishRequest.PublishState.PUBLISHED,
			"Approved request should transition to PUBLISHED",
			scenario_failures
		)
		_expect(
			approved.is_visible_to_family(),
			"Family visibility request should become visible after publish",
			scenario_failures
		)

	var sharing := FamilyShareFixture.new()
	sharing.add_family("family-main", [kid.profile_id, sibling.profile_id, parent.profile_id])
	sharing.add_family("family-other", [outsider.profile_id])
	var published_rows := publish_store.list_published()
	var sibling_visible := sharing.visible_entries_for_actor(sibling.profile_id, published_rows)
	var outsider_visible := sharing.visible_entries_for_actor(outsider.profile_id, published_rows)
	_expect(
		sibling_visible.size() == 1,
		"Family member should see published FAMILY entry",
		scenario_failures
	)
	_expect(
		outsider_visible.is_empty(),
		"Outside-family profile should not see FAMILY entry",
		scenario_failures
	)

	return _scenario_result(
		scenario_id,
		scenario_failures,
		{
			"tool_exec_calls": tool_gateway.execute_calls,
			"published_count": published_rows.size(),
			"sibling_visible_count": sibling_visible.size(),
			"outsider_visible_count": outsider_visible.size(),
		}
	)


func _scenario_policy_restricted_and_moderation_blocks() -> Dictionary:
	var scenario_id := "policy_restricted_actions_and_moderation_fail_path"
	var scenario_failures: Array[String] = []

	var clock := MockClock.new()
	var bus := DomainEventBus.new(300)
	var moderation := LocalModerationAdapter.new().setup("")
	var localization := MockLocalization.new()
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

	var kid := PlayerProfile.new("kid-policy", PlayerProfile.Role.KID)
	llm.planned_tools = [ToolInvocation.new("script_edit", {"line": 1}, "restricted-1")]
	var restricted_action := ai_service.execute("policy-session-1", "Dodaj skrypt.", kid)
	_expect(
		restricted_action.status == AIAssistantAction.ActionStatus.REJECTED,
		"Kid policy should reject disallowed tool invocation",
		scenario_failures
	)
	_expect(
		restricted_action.explanation.find("not allowed") >= 0,
		"Rejected restricted tool should include policy reason",
		scenario_failures
	)
	_expect(
		tool_gateway.execute_calls == 0,
		"Restricted tool rejection should block execution path",
		scenario_failures
	)

	var unsafe_prompt_action := ai_service.execute("policy-session-2", "zabij wszystko", kid)
	_expect(
		unsafe_prompt_action.status == AIAssistantAction.ActionStatus.REJECTED,
		"Unsafe prompt should be blocked by moderation",
		scenario_failures
	)
	_expect(
		bus.get_history("SafetyInterventionTriggered").size() >= 1,
		"Safety intervention event should be recorded for blocked prompt",
		scenario_failures
	)

	var project_store := InMemoryProjectStore.new()
	var project := Project.new("project-policy", "Policy Project")
	var world := World.new("world-policy", "zabij przeciwnika")
	var rule := GameRule.new("rule-policy", GameRule.RuleType.EVENT_TRIGGER)
	rule.display_name = "Start"
	world.add_rule(rule)
	project.add_world(world)
	project_store.save_project(project)

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

	var publish_result := publish_service.execute(project.project_id, world.world_id, kid)
	_expect(
		publish_result != null,
		"Moderation fail path should still return a publish request record",
		scenario_failures
	)
	if publish_result != null:
		_expect(
			publish_result.state == PublishRequest.PublishState.REJECTED,
			"Unsafe publish metadata should be rejected before review stage",
			scenario_failures
		)
		_expect(
			not publish_result.rejection_reason.strip_edges().is_empty(),
			"Rejected publish request should contain moderation reason",
			scenario_failures
		)

	return _scenario_result(
		scenario_id,
		scenario_failures,
		{
			"safety_events": bus.get_history("SafetyInterventionTriggered").size(),
			"blocked_tool_exec_calls": tool_gateway.execute_calls,
			"publish_state": publish_result.state if publish_result != null else -1,
		}
	)


func _scenario_transactional_rollback_on_tool_failure() -> Dictionary:
	var scenario_id := "rollback_on_multi_tool_failure"
	var scenario_failures: Array[String] = []

	var clock := MockClock.new()
	var bus := DomainEventBus.new(200)
	var moderation := LocalModerationAdapter.new().setup("")
	var localization := MockLocalization.new()
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

	var kid := PlayerProfile.new("kid-rollback", PlayerProfile.Role.KID)
	llm.planned_tools = [
		ToolInvocation.new("scene_edit", {"op": 1}, "rollback-1"),
		ToolInvocation.new("paint", {"op": 2}, "rollback-2"),
	]
	tool_gateway.fail_on_tool = "paint"

	var action := ai_service.execute("rollback-session-1", "Wykonaj dwie zmiany.", kid)
	_expect(
		action.status == AIAssistantAction.ActionStatus.REJECTED,
		"Transactional failure should reject AI action",
		scenario_failures
	)
	_expect(
		tool_gateway.rollback_calls >= 1,
		"Transactional failure should execute rollback",
		scenario_failures
	)

	return _scenario_result(
		scenario_id,
		scenario_failures,
		{
			"execute_calls": tool_gateway.execute_calls,
			"rollback_calls": tool_gateway.rollback_calls,
		}
	)


func _scenario_failsafe_mode_blocks_generation() -> Dictionary:
	var scenario_id := "failsafe_mode_blocks_generation_and_provides_fallback"
	var scenario_failures: Array[String] = []

	var clock := MockClock.new()
	var bus := DomainEventBus.new(200)
	var moderation := LocalModerationAdapter.new().setup("")
	var localization := MockLocalization.new()
	var llm := MockLLM.new()
	var tool_gateway := MockToolGateway.new()
	var failsafe := AIFailsafeController.new().setup(true, "model_unavailable")
	var ai_service := RequestAICreationHelpService.new().setup(
		llm,
		moderation,
		clock,
		localization,
		bus,
		tool_gateway,
		null,
		failsafe
	)

	var kid := PlayerProfile.new("kid-failsafe", PlayerProfile.Role.KID)
	llm.planned_tools = [ToolInvocation.new("paint", {"color": "green"}, "failsafe-tool-1")]
	var action := ai_service.execute("failsafe-session-1", "Dodaj dekoracje.", kid)
	_expect(
		action.status == AIAssistantAction.ActionStatus.REJECTED,
		"Failsafe mode should reject generative action request",
		scenario_failures
	)
	_expect(
		action.explanation.find("Tryb awaryjny AI") >= 0,
		"Failsafe rejection should provide explicit fallback explanation",
		scenario_failures
	)
	_expect(
		llm.tool_calls == 0 and tool_gateway.execute_calls == 0,
		"Failsafe mode should avoid LLM tool planning and execution",
		scenario_failures
	)
	_expect(
		bus.get_history("SafetyInterventionTriggered").size() >= 1,
		"Failsafe mode should emit safety intervention event",
		scenario_failures
	)

	var hint := failsafe.rules_based_hint({"objective": "postaw plot"}, 2)
	_expect(
		not hint.strip_edges().is_empty(),
		"Failsafe fallback should provide deterministic rules-based hint",
		scenario_failures
	)

	return _scenario_result(
		scenario_id,
		scenario_failures,
		{
			"safety_events": bus.get_history("SafetyInterventionTriggered").size(),
			"llm_tool_calls": llm.tool_calls,
			"tool_exec_calls": tool_gateway.execute_calls,
		}
	)


func _group_result(group_id: String, scenarios: Array[Dictionary]) -> Dictionary:
	var failed_scenarios: Array[String] = []
	for scenario in scenarios:
		if not bool(scenario.get("passed", false)):
			failed_scenarios.append(str(scenario.get("id", "unknown")))

	return {
		"id": group_id,
		"passed": failed_scenarios.is_empty(),
		"scenario_count": scenarios.size(),
		"failed_scenarios": failed_scenarios,
		"scenarios": scenarios,
	}


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
