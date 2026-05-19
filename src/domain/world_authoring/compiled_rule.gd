## Runtime-executable form of a GameRule. Produced by RuleCompilerService
## from the `compiled_logic` DSL string. Pure data — no Godot types,
## no Callables (per hex-arch review 2026-05-19, Adversary 1 finding C2).
##
## Trigger fires when the matching world event arrives (or every N seconds
## for periodic triggers). Action then runs against the current
## RulesRuntimePort context.
class_name CompiledRule
extends RefCounted

enum TriggerKind {
	EVERY_N_SECONDS,        ## interval timer; params.interval: float
	ON_EVENT,               ## generic named event; params.event_name: String
	ON_COLLECT_COUNT,       ## inventory threshold; params.item: String, params.count: int
	ON_SCORE_THRESHOLD,     ## score >= threshold; params.threshold: int
	ON_HAPPINESS_THRESHOLD, ## happiness >= threshold; params.threshold: int
	ON_TICK,                ## fires every frame; params.event_name: String (for filter)
}

enum ActionKind {
	ADD_SCORE,              ## params.amount: int
	SPAWN_ITEM,             ## params.item: String, params.count: int
	WIN_LEVEL,              ## no params; emits SessionEndedEvent(win=true)
	UNLOCK_AREA,            ## params.zone_id: String
	OPEN_GATE,              ## no params
	SET_RESPAWN_POINT,      ## no params; uses player current position
	CUSTOM_CALLBACK,        ## params.callback_name: String (advance_crop_stage etc.)
}

var rule_id: String
var trigger: TriggerKind
var trigger_params: Dictionary
var action: ActionKind
var action_params: Dictionary
## Set to false after a one-shot trigger fires (win, unlock_area).
## Periodic triggers stay enabled.
var enabled: bool


func _init(p_rule_id: String = "") -> void:
	rule_id = p_rule_id
	trigger = TriggerKind.ON_EVENT
	trigger_params = {}
	action = ActionKind.ADD_SCORE
	action_params = {}
	enabled = true


## Returns true if this trigger fires repeatedly (never disables itself
## after first fire). Periodic timers and collect-threshold-while-true
## belong here; one-shot wins / unlock_area do not.
func is_periodic() -> bool:
	return trigger == TriggerKind.EVERY_N_SECONDS or trigger == TriggerKind.ON_TICK


## One-shot triggers disable themselves after first fire so they don't
## re-fire on every subsequent matching event.
func is_one_shot() -> bool:
	if is_periodic():
		return false
	return action == ActionKind.WIN_LEVEL \
		or action == ActionKind.UNLOCK_AREA \
		or action == ActionKind.OPEN_GATE
