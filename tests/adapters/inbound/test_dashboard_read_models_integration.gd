extends SceneTree


class StubLocalization:
	extends LocalizationPolicyPort

	func get_locale() -> String:
		return "pl-PL"

	func translate(key: String) -> String:
		var translations := {
			"ui.play.status.no_data": "Brak danych postepu dla aktywnego swiata.",
			"ui.play.status.template": "Postep: %d%% | Znajdzki: %d | Osiagniecia: %d",
			"ui.parent.audit.no_data": "Audyt: brak danych.",
			"ui.parent.audit.template": "Audyt 24h: %d zdarzen, %d interwencji",
			"ui.parent.ai.no_data": "AI: brak danych.",
			"ui.parent.ai.template": "AI 7d: %d zadan, %d%% skutecznosci, %d blokad",
		}
		return str(translations.get(key, key))

	func is_term_safe(_term: String) -> bool:
		return true


class StubSetParentalControls:
	extends SetParentalControlsPort

	func execute(_parent: PlayerProfile, _settings: Dictionary) -> bool:
		return true


class StubClock:
	extends ClockPort

	var _tick: int = 0

	func now_iso() -> String:
		_tick += 1
		return "2026-03-05T16:00:%02dZ" % _tick

	func now_msec() -> int:
		_tick += 1
		return 1772726400000 + _tick


class MockWorldEditedEvent:
	extends DomainEvent

	var project_id: String
	var title: String

	func _init(p_project_id: String, p_title: String, p_actor_id: String) -> void:
		super._init("WorldEdited", p_actor_id, "2026-03-05T16:00:00Z")
		project_id = p_project_id
		title = p_title


class MockSessionProgressUpdatedEvent:
	extends DomainEvent

	var project_id: String
	var progress_pct: int
	var collectibles_found: int
	var achievements_earned: int

	func _init(p_project_id: String, p_progress_pct: int = 0, p_actor_id: String = "", p_collectibles: int = 0, p_achievements: int = 0) -> void:
		super._init("SessionProgressUpdatedEvent", p_actor_id, "2026-03-05T16:01:00Z")
		project_id = p_project_id
		progress_pct = p_progress_pct
		collectibles_found = p_collectibles
		achievements_earned = p_achievements


class SafetyEventWithAdtech:
	extends DomainEvent

	var decision_type: String
	var policy_rule: String
	var trigger_context: String
	var safe_alternative_offered: bool
	var advertising_id: String
	var metadata: Dictionary

	func _init(p_actor_id: String) -> void:
		super._init("SafetyInterventionTriggered", p_actor_id, "2026-03-05T16:04:00Z")
		decision_type = "BLOCK"
		policy_rule = "MODERATION_BLOCK"
		trigger_context = "integration"
		safe_alternative_offered = true
		advertising_id = "ad-seed"
		metadata = {"gaid": "gaid-seed", "surface": "parent_dashboard"}


class MockAIAssistanceAppliedEvent:
	extends DomainEvent

	var action_id: String

	func _init(p_action_id: String, p_latency: float = 0.0, p_success: bool = true) -> void:
		super._init("AIAssistanceAppliedEvent", "kid-dashboard", "2026-03-05T16:05:00Z")
		action_id = p_action_id


class MockSafetyInterventionTriggeredEvent:
	extends DomainEvent

	var decision_type: String

	func _init() -> void:
		super._init("SafetyInterventionTriggeredEvent", "kid-dashboard", "2026-03-05T16:05:30Z")
		decision_type = "BLOCK"


var _exit_code: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var play_scene_variant: Variant = load("res://src/adapters/inbound/scenes/play/play_shell.tscn")
	var parent_scene_variant: Variant = load("res://src/adapters/inbound/scenes/parent/parent_zone_shell.tscn")
	if not (play_scene_variant is PackedScene) or not (parent_scene_variant is PackedScene):
		_fail("Dashboard scenes should load")
		return

	var navigator := ShellNavigator.new()
	var localization := StubLocalization.new()
	var kid := PlayerProfile.new("kid-dashboard", PlayerProfile.Role.KID)
	var parent := PlayerProfile.new("parent-dashboard", PlayerProfile.Role.PARENT)

	var kid_status := KidStatusReadModelAdapter.new()
	kid_status.update_from_event(MockWorldEditedEvent.new("world-dashboard-1", "Dashboard Test", kid.profile_id))
	kid_status.update_from_event(MockSessionProgressUpdatedEvent.new("world-dashboard-1", 42, kid.profile_id))
	kid_status.update_from_event(MockSessionProgressUpdatedEvent.new("world-dashboard-1", 0, kid.profile_id, 1, 0))
	kid_status.update_from_event(MockSessionProgressUpdatedEvent.new("world-dashboard-1", 0, kid.profile_id, 0, 1))

	var play_shell: PlayShell = (play_scene_variant as PackedScene).instantiate()
	get_root().add_child(play_shell)
	play_shell.setup(navigator, kid, localization, null, kid_status)
	play_shell.set_world_context("world-dashboard-1")
	await process_frame

	var play_status: Label = play_shell.get_node("Layout/Header/StatusSummary")
	_assert(
		play_status.text.find("42") >= 0 and play_status.text.find("1") >= 0,
		"PlayShell should render kid status summary from read model"
	)
	var leaked_status := kid_status.get_project_status("world-dashboard-1", "kid-other")
	_assert(leaked_status.is_empty(), "Kid status read model should enforce profile isolation")
	var minimized_status := kid_status.get_project_status("world-dashboard-1", kid.profile_id)
	_assert(
		not minimized_status.has("advertising_id"),
		"Kid status payload should not expose ad-tech identifiers"
	)

	var ledger := InMemoryAuditLedger.new().setup()
	var parent_audit := ParentAuditReadModelAdapter.new().setup(ledger, StubClock.new())
	parent_audit.register_family_link(parent.profile_id, kid.profile_id)
	var safety_event := SafetyEventWithAdtech.new(kid.profile_id)
	parent_audit.update_from_event(safety_event)

	var ai_performance := AIPerformanceReadModelAdapter.new()
	ai_performance.update_from_event(MockAIAssistanceAppliedEvent.new("paint", 120.0, true))
	ai_performance.update_from_event(MockSafetyInterventionTriggeredEvent.new())

	var parent_shell: ParentZoneShell = (parent_scene_variant as PackedScene).instantiate()
	get_root().add_child(parent_shell)
	parent_shell.setup(
		navigator,
		parent,
		localization,
		StubSetParentalControls.new(),
		parent_audit,
		ai_performance
	)
	await process_frame

	var audit_summary: Label = parent_shell.get_node("Layout/Header/AuditSummary")
	var ai_summary: Label = parent_shell.get_node("Layout/Header/AISummary")
	_assert(
		audit_summary.text.find("1") >= 0,
		"ParentZoneShell should render audit summary from parent read model"
	)
	_assert(
		ai_summary.text.find("1") >= 0,
		"ParentZoneShell should render AI summary from performance read model"
	)

	var timeline := parent_audit.get_timeline(parent.profile_id, "", "", 5)
	var adtech_redacted := false
	for row_variant in timeline:
		if not (row_variant is AuditRecord):
			continue
		var row: AuditRecord = row_variant
		if row.event_id == safety_event.event_id:
			adtech_redacted = true
			_assert(
				not row.payload.has("advertising_id"),
				"Parent audit timeline payload should redact ad-tech identifiers"
			)
	_assert(adtech_redacted, "Parent audit timeline should include sanitized safety event")

	var metrics := ai_performance.get_metrics("7d")
	_assert(not metrics.has("advertising_id"), "AI metrics should not expose ad-tech identifiers")

	play_shell.queue_free()
	parent_shell.queue_free()
	if _exit_code == 0:
		print("DASHBOARD_READ_MODELS_INTEGRATION_TEST: PASS")
	quit(_exit_code)


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	_fail(message)


func _fail(message: String) -> void:
	print("FAIL: %s" % message)
	_exit_code = 1
