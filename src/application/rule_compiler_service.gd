## Application service: parses GameRule.compiled_logic DSL strings into
## CompiledRule instances ready for the runtime to execute.
##
## DSL grammar (matches the strings produced by CompileBlockLogicService
## and the 5 starter template JSONs, audited 2026-05-19):
##
##   every_<N>s:<action>
##   on_collect_<item>_<N>:<action>
##   on_score_<N>:<action>
##   on_happiness_<N>:<action>
##   on_happiness_tick:<action>
##   on_<event_name>:<action>
##
##   <action> := add_score(<int>)
##             | spawn_item('<item>', <int>)
##             | win_level()
##             | unlock_area('<zone>')
##             | open_gate()
##             | set_respawn_point()
##             | <name>()                  -- treated as CUSTOM_CALLBACK
##
## Unrecognized inputs return null and log a warning; the runtime
## simply skips them. This is fail-open by design — kids' worlds
## should not crash because the parent block editor emitted a
## malformed string.
class_name RuleCompilerService
extends RefCounted


## Compile a single GameRule (already produced by
## CompileBlockLogicService) into a runtime-ready CompiledRule.
## Returns null on parse failure.
func compile(rule: GameRule) -> CompiledRule:
	if rule == null or rule.compiled_logic == "":
		return null
	var dsl: String = rule.compiled_logic.strip_edges()
	if dsl.find(":") == -1:
		push_warning("RuleCompiler: missing ':' separator — %s" % dsl)
		return null

	var parts: PackedStringArray = dsl.split(":", true, 1)
	var trigger_str: String = parts[0]
	var action_str: String = parts[1]

	var compiled := CompiledRule.new(rule.rule_id)
	if not _parse_trigger(trigger_str, compiled):
		push_warning("RuleCompiler: unknown trigger '%s'" % trigger_str)
		return null
	if not _parse_action(action_str, compiled):
		push_warning("RuleCompiler: unknown action '%s'" % action_str)
		return null
	return compiled


## Compile a whole world's rules in one call. Skips null results.
func compile_all(rules: Array) -> Array:
	var out: Array = []
	for r in rules:
		if not (r is GameRule):
			continue
		var compiled := compile(r as GameRule)
		if compiled != null:
			out.append(compiled)
	return out


# ---- internals ----

func _parse_trigger(s: String, rule: CompiledRule) -> bool:
	# every_<N>s
	var re_every := RegEx.new()
	re_every.compile("^every_(\\d+)s$")
	var m := re_every.search(s)
	if m != null:
		rule.trigger = CompiledRule.TriggerKind.EVERY_N_SECONDS
		rule.trigger_params = {"interval": float(m.get_string(1))}
		return true

	# on_collect_<item>_<N>
	var re_collect := RegEx.new()
	re_collect.compile("^on_collect_([a-z_]+)_(\\d+)$")
	m = re_collect.search(s)
	if m != null:
		rule.trigger = CompiledRule.TriggerKind.ON_COLLECT_COUNT
		rule.trigger_params = {
			"item": m.get_string(1),
			"count": int(m.get_string(2)),
		}
		return true

	# on_score_<N>
	var re_score := RegEx.new()
	re_score.compile("^on_score_(\\d+)$")
	m = re_score.search(s)
	if m != null:
		rule.trigger = CompiledRule.TriggerKind.ON_SCORE_THRESHOLD
		rule.trigger_params = {"threshold": int(m.get_string(1))}
		return true

	# on_happiness_<N>
	var re_happy := RegEx.new()
	re_happy.compile("^on_happiness_(\\d+)$")
	m = re_happy.search(s)
	if m != null:
		rule.trigger = CompiledRule.TriggerKind.ON_HAPPINESS_THRESHOLD
		rule.trigger_params = {"threshold": int(m.get_string(1))}
		return true

	# on_<event_name> (catch-all for named events)
	var re_event := RegEx.new()
	re_event.compile("^on_([a-z_]+)$")
	m = re_event.search(s)
	if m != null:
		rule.trigger = CompiledRule.TriggerKind.ON_EVENT
		rule.trigger_params = {"event_name": m.get_string(1)}
		return true

	return false


func _parse_action(s: String, rule: CompiledRule) -> bool:
	# add_score(<int>)
	var re_add := RegEx.new()
	re_add.compile("^add_score\\((\\d+)\\)$")
	var m := re_add.search(s)
	if m != null:
		rule.action = CompiledRule.ActionKind.ADD_SCORE
		rule.action_params = {"amount": int(m.get_string(1))}
		return true

	# spawn_item('<item>', <int>)
	var re_spawn := RegEx.new()
	re_spawn.compile("^spawn_item\\(\\s*'([a-z_]+)'\\s*,\\s*(\\d+)\\s*\\)$")
	m = re_spawn.search(s)
	if m != null:
		rule.action = CompiledRule.ActionKind.SPAWN_ITEM
		rule.action_params = {
			"item": m.get_string(1),
			"count": int(m.get_string(2)),
		}
		return true

	# unlock_area('<zone>')
	var re_unlock := RegEx.new()
	re_unlock.compile("^unlock_area\\(\\s*'([a-z_]+)'\\s*\\)$")
	m = re_unlock.search(s)
	if m != null:
		rule.action = CompiledRule.ActionKind.UNLOCK_AREA
		rule.action_params = {"zone_id": m.get_string(1)}
		return true

	# win_level() / open_gate() / set_respawn_point() / <name>()
	var re_nullary := RegEx.new()
	re_nullary.compile("^([a-z_]+)\\(\\)$")
	m = re_nullary.search(s)
	if m != null:
		var name := m.get_string(1)
		match name:
			"win_level":
				rule.action = CompiledRule.ActionKind.WIN_LEVEL
			"open_gate":
				rule.action = CompiledRule.ActionKind.OPEN_GATE
			"set_respawn_point":
				rule.action = CompiledRule.ActionKind.SET_RESPAWN_POINT
			_:
				rule.action = CompiledRule.ActionKind.CUSTOM_CALLBACK
				rule.action_params = {"callback_name": name}
		return true

	return false
