class_name CompileBlockLogicServiceContractTest
extends PortContractTest


class MockProjectStore:
	extends ProjectStorePort

	var _project: Project
	var save_calls: int = 0

	func _init(project: Project) -> void:
		_project = project

	func save_project(project: Project) -> bool:
		_project = project
		save_calls += 1
		return true

	func load_project(project_id: String) -> Project:
		if _project != null and _project.project_id == project_id:
			return _project
		return null

	func list_projects() -> Array:
		if _project == null:
			return []
		return [_project]


class MockClock:
	extends ClockPort

	func now_iso() -> String:
		return "2026-03-02T12:50:00Z"

	func now_msec() -> int:
		return 1767415800000


func run() -> Dictionary:
	_reset()

	var world := World.new("world-1", "Test World")
	var project := Project.new("project-1", "Test Project")
	project.add_world(world)

	var store := MockProjectStore.new(project)
	var bus := DomainEventBus.new(50)
	var service := CompileBlockLogicService.new().setup(store, MockClock.new(), bus)

	var blocks := [
		{
			"rule_id": "rule-event",
			"type": "EVENT_TRIGGER",
			"display_name_pl": "Po kliknięciu",
			"event": "tap",
			"action": "spawn_confetti()",
		},
		{
			"rule_id": "rule-timer",
			"type": "TIMER",
			"display_name_pl": "Timer monet",
			"interval_sec": 10,
			"action": "add_score(1)",
		},
		{
			"rule_id": "rule-score",
			"type": "SCORE",
			"display_name_pl": "Punkty za zbiórkę",
			"event": "collect_coin",
			"score_delta": 7,
		},
		{
			"rule_id": "rule-win",
			"type": "WIN_CONDITION",
			"display_name_pl": "Warunek wygranej",
			"condition": "score>=100",
		},
		{
			"rule_id": "rule-spawn",
			"type": "ITEM_SPAWN",
			"display_name_pl": "Spawn monet",
			"item_id": "coin",
			"spawn_interval_sec": 5,
		},
	]

	var rules := service.execute("world-1", blocks)
	_assert_array(rules, "CompileBlockLogicService.execute()")
	_assert_true(rules.size() == 5, "Should compile 5 rules")
	_assert_true(store.save_calls == 1, "Compiled world should be persisted once")

	_assert_true(
		rules[0].rule_type == GameRule.RuleType.EVENT_TRIGGER,
		"EVENT_TRIGGER block should map to EVENT_TRIGGER rule type"
	)
	_assert_true(
		rules[1].rule_type == GameRule.RuleType.TIMER,
		"TIMER block should map to TIMER rule type"
	)
	_assert_true(
		rules[2].rule_type == GameRule.RuleType.SCORING,
		"SCORE alias should map to SCORING rule type"
	)
	_assert_true(
		rules[3].rule_type == GameRule.RuleType.WIN_CONDITION,
		"WIN_CONDITION block should map to WIN_CONDITION rule type"
	)
	_assert_true(
		rules[4].rule_type == GameRule.RuleType.ITEM_SPAWN,
		"ITEM_SPAWN block should map to ITEM_SPAWN rule type"
	)

	_assert_true(
		rules[1].compiled_logic.contains("every_10s"),
		"Timer block should compile to timer DSL"
	)
	_assert_true(
		rules[2].compiled_logic.contains("add_score(7)"),
		"Scoring block should compile to scoring DSL"
	)
	_assert_true(
		rules[4].compiled_logic.contains("spawn_coin_every_5s"),
		"Spawn block should compile to spawn DSL"
	)

	var bridge: Dictionary = rules[0].source_blocks[0].get("script_bridge", {})
	_assert_true(
		bridge.get("editable_in_parent_mode", false),
		"Compiled rule should include parent-mode script bridge metadata"
	)
	_assert_true(
		str(bridge.get("script_stub", "")).contains("SOURCE_DSL"),
		"Compiled rule should include editable script stub"
	)

	var rule_events := bus.get_history("RuleChanged")
	_assert_true(
		rule_events.size() == 5,
		"Each compiled rule should emit RuleChanged event"
	)

	return _build_result("CompileBlockLogicService")
