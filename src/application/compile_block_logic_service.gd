## Application service: compiles visual block definitions into GameRule entities.
## Takes raw block data, validates it, and produces compiled rules that
## can drive gameplay. Emits RuleChangedEvent for each rule created or modified.
class_name CompileBlockLogicService
extends CompileBlockLogicToRulesPort

var _project_store: ProjectStorePort
var _clock: ClockPort
var _event_bus: DomainEventBus


func setup(
	project_store: ProjectStorePort,
	clock: ClockPort,
	event_bus: DomainEventBus = null
) -> CompileBlockLogicService:
	_project_store = project_store
	_clock = clock
	_event_bus = event_bus
	return self


## Returns Array[GameRule].
func execute(world_id: String, source_blocks: Array) -> Array:
	var project := _find_project_for_world(world_id)
	if project == null:
		return []

	var world := project.get_world(world_id)
	if world == null:
		return []

	var compiled_rules: Array = []

	for block_def in source_blocks:
		if not block_def is Dictionary:
			continue

		var block_data: Dictionary = block_def
		var rule_type_str: String = str(block_data.get("type", "EVENT_TRIGGER"))
		var rule_type := _parse_rule_type(rule_type_str)
		var generated_rule_id := "%s_rule_%d" % [world_id, compiled_rules.size()]
		var rule_id: String = str(block_data.get("rule_id", generated_rule_id))

		var rule := GameRule.new(rule_id, rule_type)
		rule.display_name = _resolve_display_name(block_data, generated_rule_id)

		var compilation := _compile_block(block_data, rule)
		rule.source_blocks = [{
			"block": block_data.duplicate(true),
			"script_bridge": compilation.get("script_bridge", {}),
		}]
		rule.compiled_logic = str(compilation.get("dsl", ""))
		rule.is_active = true

		compiled_rules.append(rule)
		_emit_rule_changed_event(world_id, rule)

	world.game_rules = compiled_rules
	project.updated_at = _clock.now_iso()
	_project_store.save_project(project)

	return compiled_rules


func _compile_block(block_def: Dictionary, rule: GameRule) -> Dictionary:
	var dsl := ""
	match rule.rule_type:
		GameRule.RuleType.EVENT_TRIGGER:
			var event_name := _string_value(block_def, ["event", "trigger", "on"], "world_event")
			var action_name := _string_value(block_def, ["action", "do"], "noop()")
			dsl = "on_%s:%s" % [event_name, action_name]
		GameRule.RuleType.TIMER:
			var interval := _int_value(block_def, ["interval_sec", "interval", "seconds"], 10)
			var timer_action := _string_value(block_def, ["action", "do"], "tick()")
			dsl = "every_%ds:%s" % [interval, timer_action]
		GameRule.RuleType.SCORING:
			var scoring_trigger := _string_value(block_def, ["event", "trigger"], "event")
			var score_delta := _int_value(block_def, ["score_delta", "value", "points"], 1)
			dsl = "on_%s:add_score(%d)" % [scoring_trigger, score_delta]
		GameRule.RuleType.WIN_CONDITION:
			var condition := _string_value(block_def, ["condition", "goal", "target"], "score>=100")
			dsl = "win_when(%s)" % condition
		GameRule.RuleType.ITEM_SPAWN:
			var item_id := _string_value(block_def, ["item_id", "item", "resource"], "coin")
			var spawn_interval := _int_value(block_def, ["spawn_interval_sec", "interval_sec", "interval"], 15)
			dsl = "spawn_%s_every_%ds" % [item_id, spawn_interval]
		_:
			dsl = "on_world_event:noop()"

	return {
		"dsl": dsl,
		"script_bridge": _build_script_bridge(rule, dsl),
	}


func _build_script_bridge(rule: GameRule, dsl: String) -> Dictionary:
	return {
		"editable_in_parent_mode": true,
		"script_language": "gdscript",
		"script_stub": _build_script_stub(rule.rule_id, dsl),
	}


func _build_script_stub(rule_id: String, dsl: String) -> String:
	var escaped_dsl := dsl.replace("\"", "\\\"")
	return "extends RefCounted\n\nconst RULE_ID := \"%s\"\nconst SOURCE_DSL := \"%s\"\n\nfunc execute(context: Dictionary) -> void:\n\t# Parent-mode editable bridge generated from block logic.\n\t# Keep child-safe defaults and add advanced behavior below.\n\tpass\n" % [rule_id, escaped_dsl]


func _parse_rule_type(type_str: String) -> GameRule.RuleType:
	match type_str.to_upper():
		"TIMER": return GameRule.RuleType.TIMER
		"SCORING", "SCORE": return GameRule.RuleType.SCORING
		"WIN_CONDITION", "CHECKPOINT", "PUZZLE": return GameRule.RuleType.WIN_CONDITION
		"ITEM_SPAWN", "SPAWN", "COLLECT", "RESOURCE", "GROWTH": return GameRule.RuleType.ITEM_SPAWN
		"EVENT_TRIGGER", "EVENT": return GameRule.RuleType.EVENT_TRIGGER
		_: return GameRule.RuleType.EVENT_TRIGGER


func _find_project_for_world(world_id: String) -> Project:
	for project in _project_store.list_projects():
		if project.get_world(world_id) != null:
			return project
	return null


func _emit_rule_changed_event(world_id: String, rule: GameRule) -> void:
	if _event_bus == null:
		return

	var event := RuleChangedEvent.new(rule.rule_id, "created", "", _clock.now_iso())
	var script_bridge := {}
	if not rule.source_blocks.is_empty() and rule.source_blocks[0] is Dictionary:
		script_bridge = rule.source_blocks[0].get("script_bridge", {})
	event.previous_state = {}
	event.new_state = {
		"world_id": world_id,
		"rule_type": int(rule.rule_type),
		"display_name": rule.display_name,
		"is_active": rule.is_active,
		"compiled_logic": rule.compiled_logic,
		"parent_script_bridge": script_bridge.get("editable_in_parent_mode", false),
	}
	_event_bus.emit(event)


func _resolve_display_name(block_data: Dictionary, fallback: String) -> String:
	var display_name := str(block_data.get("display_name", ""))
	if display_name.is_empty():
		display_name = str(block_data.get("display_name_pl", ""))
	if display_name.is_empty():
		return fallback
	return display_name


func _string_value(block_data: Dictionary, keys: Array, default_value: String) -> String:
	for key in keys:
		var value := str(block_data.get(str(key), "")).strip_edges()
		if not value.is_empty():
			return value
	return default_value


func _int_value(block_data: Dictionary, keys: Array, default_value: int) -> int:
	for key in keys:
		var raw_value: Variant = block_data.get(str(key), null)
		if raw_value == null:
			continue
		match typeof(raw_value):
			TYPE_INT:
				return int(raw_value)
			TYPE_FLOAT:
				return int(raw_value)
			TYPE_STRING:
				var text := str(raw_value).strip_edges()
				if text.is_valid_int():
					return text.to_int()
	return default_value
