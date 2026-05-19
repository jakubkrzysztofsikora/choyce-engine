## Godot-side runtime for compiled gameplay rules.
##
## Owns the per-frame clock, accumulator timers for EVERY_N_SECONDS
## triggers, and the mutable context dictionary that ON_*_THRESHOLD
## triggers evaluate against. Translates fired actions into emit calls
## on the `rules_action` signal so GameplayRuntime can dispatch them
## without this adapter knowing about score / inventory / win-flow.
##
## Per Adversary 1 (hex-arch review 2026-05-19): adapter does NOT call
## into application services. It only emits structured events. The
## application listens.
class_name GodotRulesRuntimeAdapter
extends RulesRuntimePort


## Emitted whenever a CompiledRule's action fires. The receiver
## (GameplayRuntime) dispatches based on action_kind.
##   rule_id:     String  — the source rule
##   action_kind: int     — CompiledRule.ActionKind
##   params:      Dict    — action_params from the CompiledRule
signal rules_action(rule_id: String, action_kind: int, params: Dictionary)


var _rules: Array = []                       # Array[CompiledRule]
var _timer_accumulators: Dictionary = {}     # rule_id -> float seconds accrued
var _context: Dictionary = {                 # mutable game state
	"score": 0,
	"inventory": {},                          # item -> count
	"happiness": 0,
	"quest": {},                              # quest_id -> state
	"blocks_placed": 0,
	"in_zone": {},                            # zone_id -> bool
	"time": 0.0,
}


func register_rules(rules: Array) -> void:
	_rules.clear()
	_timer_accumulators.clear()
	for r in rules:
		if not (r is CompiledRule):
			continue
		_rules.append(r)
		if r.trigger == CompiledRule.TriggerKind.EVERY_N_SECONDS:
			_timer_accumulators[r.rule_id] = 0.0


func tick(delta: float) -> void:
	_context["time"] = float(_context.get("time", 0.0)) + delta
	for r: CompiledRule in _rules:
		if not r.enabled:
			continue
		if r.trigger == CompiledRule.TriggerKind.EVERY_N_SECONDS:
			_tick_periodic(r, delta)
		elif r.trigger == CompiledRule.TriggerKind.ON_SCORE_THRESHOLD:
			if int(_context.get("score", 0)) >= int(r.trigger_params.get("threshold", 0)):
				_fire(r)
		elif r.trigger == CompiledRule.TriggerKind.ON_HAPPINESS_THRESHOLD:
			if int(_context.get("happiness", 0)) >= int(r.trigger_params.get("threshold", 0)):
				_fire(r)


func on_event(event_name: String, payload: Dictionary = {}) -> void:
	for r: CompiledRule in _rules:
		if not r.enabled:
			continue
		match r.trigger:
			CompiledRule.TriggerKind.ON_EVENT:
				if String(r.trigger_params.get("event_name", "")) == event_name:
					_fire(r)
			CompiledRule.TriggerKind.ON_COLLECT_COUNT:
				if event_name != "inventory_changed":
					continue
				var item := String(r.trigger_params.get("item", ""))
				var threshold := int(r.trigger_params.get("count", 0))
				var inv: Dictionary = _context.get("inventory", {})
				if int(inv.get(item, 0)) >= threshold:
					_fire(r)


func set_context_value(key: String, value: Variant) -> void:
	_context[key] = value


func get_context_value(key: String) -> Variant:
	return _context.get(key, null)


func reset() -> void:
	_rules.clear()
	_timer_accumulators.clear()
	_context = {
		"score": 0,
		"inventory": {},
		"happiness": 0,
		"quest": {},
		"blocks_placed": 0,
		"in_zone": {},
		"time": 0.0,
	}


# ---- helpers ----

func _tick_periodic(rule: CompiledRule, delta: float) -> void:
	var interval := float(rule.trigger_params.get("interval", 0.0))
	if interval <= 0.0:
		return
	var acc := float(_timer_accumulators.get(rule.rule_id, 0.0)) + delta
	if acc >= interval:
		acc = 0.0
		_emit_action(rule)
	_timer_accumulators[rule.rule_id] = acc


func _fire(rule: CompiledRule) -> void:
	_emit_action(rule)
	if rule.is_one_shot():
		rule.enabled = false


func _emit_action(rule: CompiledRule) -> void:
	emit_signal("rules_action", rule.rule_id, int(rule.action), rule.action_params)
