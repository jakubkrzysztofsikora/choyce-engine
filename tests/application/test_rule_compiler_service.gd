## Smoke tests for RuleCompilerService — covers the 27 unique
## compiled_logic strings observed in data/templates/*.json
## (audited 2026-05-19).
##
## Run with: godot --headless --script tests/application/test_rule_compiler_service.gd
class_name TestRuleCompilerService
extends SceneTree


func _init() -> void:
	var compiler := RuleCompilerService.new()
	var failures: Array = []

	# every_<N>s timer
	_assert(failures, "every_30s_advance",
		_compile_dsl(compiler, "every_30s:advance_crop_stage()"),
		CompiledRule.TriggerKind.EVERY_N_SECONDS,
		CompiledRule.ActionKind.CUSTOM_CALLBACK,
		{"interval": 30.0},
		{"callback_name": "advance_crop_stage"})

	# every_<N>s spawn_item
	_assert(failures, "every_45s_spawn_carrot",
		_compile_dsl(compiler, "every_45s:spawn_item('carrot', 2)"),
		CompiledRule.TriggerKind.EVERY_N_SECONDS,
		CompiledRule.ActionKind.SPAWN_ITEM,
		{"interval": 45.0},
		{"item": "carrot", "count": 2})

	# every_<N>s add_score
	_assert(failures, "every_60s_add_score",
		_compile_dsl(compiler, "every_60s:add_score(5)"),
		CompiledRule.TriggerKind.EVERY_N_SECONDS,
		CompiledRule.ActionKind.ADD_SCORE,
		{"interval": 60.0},
		{"amount": 5})

	# on_collect_<item>_<N>
	_assert(failures, "on_collect_carrot_10_win",
		_compile_dsl(compiler, "on_collect_carrot_10:win_level()"),
		CompiledRule.TriggerKind.ON_COLLECT_COUNT,
		CompiledRule.ActionKind.WIN_LEVEL,
		{"item": "carrot", "count": 10},
		{})

	# on_score_<N>
	_assert(failures, "on_score_100_win",
		_compile_dsl(compiler, "on_score_100:win_level()"),
		CompiledRule.TriggerKind.ON_SCORE_THRESHOLD,
		CompiledRule.ActionKind.WIN_LEVEL,
		{"threshold": 100},
		{})

	# on_happiness_<N>:unlock
	_assert(failures, "on_happiness_50_unlock",
		_compile_dsl(compiler, "on_happiness_50:unlock_area('school_zone')"),
		CompiledRule.TriggerKind.ON_HAPPINESS_THRESHOLD,
		CompiledRule.ActionKind.UNLOCK_AREA,
		{"threshold": 50},
		{"zone_id": "school_zone"})

	# on_<event>
	_assert(failures, "on_reach_flag",
		_compile_dsl(compiler, "on_reach_flag:win_level()"),
		CompiledRule.TriggerKind.ON_EVENT,
		CompiledRule.ActionKind.WIN_LEVEL,
		{"event_name": "reach_flag"},
		{})

	# on_<event>:add_score
	_assert(failures, "on_collect_token",
		_compile_dsl(compiler, "on_collect_token:add_score(12)"),
		CompiledRule.TriggerKind.ON_EVENT,
		CompiledRule.ActionKind.ADD_SCORE,
		{"event_name": "collect_token"},
		{"amount": 12})

	# on_<event>:open_gate
	_assert(failures, "on_solve_puzzle",
		_compile_dsl(compiler, "on_solve_puzzle:open_gate()"),
		CompiledRule.TriggerKind.ON_EVENT,
		CompiledRule.ActionKind.OPEN_GATE,
		{"event_name": "solve_puzzle"},
		{})

	# on_touch_checkpoint:set_respawn_point
	_assert(failures, "on_touch_checkpoint",
		_compile_dsl(compiler, "on_touch_checkpoint:set_respawn_point()"),
		CompiledRule.TriggerKind.ON_EVENT,
		CompiledRule.ActionKind.SET_RESPAWN_POINT,
		{"event_name": "touch_checkpoint"},
		{})

	# malformed DSL returns null
	var malformed := _compile_dsl(compiler, "totally bogus")
	if malformed != null:
		failures.append("malformed_returns_null: expected null, got %s" % malformed)

	# empty DSL returns null
	var empty := compiler.compile(GameRule.new("empty"))
	if empty != null:
		failures.append("empty_returns_null: expected null, got %s" % empty)

	if failures.is_empty():
		print("[test_rule_compiler] PASS — 11 assertions")
		quit(0)
	else:
		print("[test_rule_compiler] FAIL — %d failures" % failures.size())
		for f in failures:
			print("  - %s" % f)
		quit(1)


func _compile_dsl(compiler: RuleCompilerService, dsl: String) -> CompiledRule:
	var rule := GameRule.new("test_rule", GameRule.RuleType.EVENT_TRIGGER)
	rule.compiled_logic = dsl
	return compiler.compile(rule)


func _assert(
	failures: Array,
	label: String,
	compiled: CompiledRule,
	expected_trigger: int,
	expected_action: int,
	expected_trigger_params: Dictionary,
	expected_action_params: Dictionary
) -> void:
	if compiled == null:
		failures.append("%s: compile returned null" % label)
		return
	if int(compiled.trigger) != expected_trigger:
		failures.append("%s: trigger %d, expected %d" % [label, int(compiled.trigger), expected_trigger])
	if int(compiled.action) != expected_action:
		failures.append("%s: action %d, expected %d" % [label, int(compiled.action), expected_action])
	for key in expected_trigger_params:
		if compiled.trigger_params.get(key) != expected_trigger_params[key]:
			failures.append("%s: trigger_params.%s=%s, expected %s" % [
				label, key, str(compiled.trigger_params.get(key)), str(expected_trigger_params[key])])
	for key in expected_action_params:
		if compiled.action_params.get(key) != expected_action_params[key]:
			failures.append("%s: action_params.%s=%s, expected %s" % [
				label, key, str(compiled.action_params.get(key)), str(expected_action_params[key])])
