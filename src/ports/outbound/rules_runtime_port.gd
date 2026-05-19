## Outbound port: registers a set of CompiledRule instances and ticks
## them each frame. The adapter (GodotRulesRuntimeAdapter) owns the
## clock + per-frame context + event dispatch. Application services
## hand rules over and forget them.
##
## Per Adversary 1 (hex-arch review 2026-05-19), no Godot types cross
## this port. Events flow in via plain Dictionary payloads. Actions
## flow out via DomainEventBus signals on the adapter side.
class_name RulesRuntimePort
extends RefCounted


## Register the active rule set for a world. Replaces any previously
## registered rules. Empty array clears the runtime.
func register_rules(rules: Array) -> void:
	_unimplemented("register_rules")


## Advance time by `delta` seconds. Periodic triggers may fire here.
## Called by the adapter's _process / _physics_process.
func tick(delta: float) -> void:
	_unimplemented("tick")


## Notify the runtime of a discrete world event. event_name is the
## DSL event identifier (e.g. "collect_carrot", "reach_flag",
## "happiness_tick"). payload may carry counts / zone ids / etc.
func on_event(event_name: String, payload: Dictionary = {}) -> void:
	_unimplemented("on_event")


## Update a mutable scalar in the rule-eval context. Used for
## inventory counts, score, happiness, blocks_placed. Adapter
## inspects these when evaluating ON_*_THRESHOLD triggers.
func set_context_value(key: String, value: Variant) -> void:
	_unimplemented("set_context_value")


## Read a context value (mostly for tests). Returns null if unset.
func get_context_value(key: String) -> Variant:
	_unimplemented("get_context_value")
	return null


## Clear all rules + context. Called on session end / world unload.
func reset() -> void:
	_unimplemented("reset")


func _unimplemented(method_name: String) -> void:
	push_error("RulesRuntimePort.%s called on abstract base — wire a concrete adapter" % method_name)
