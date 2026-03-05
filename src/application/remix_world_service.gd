## Application service for remixing/resetting worlds.
## Fast remix clears player progression while preserving world authoring.
## Supports optional balance tweaks and difficulty adjustments.
class_name RemixWorldService
extends RefCounted


var _progress_store: SessionProgressStorePort
var _event_bus: DomainEventBus
var _clock_port: ClockPort


func setup(progress_store: SessionProgressStorePort, event_bus: DomainEventBus = null, clock_port: ClockPort = null) -> RemixWorldService:
	_progress_store = progress_store
	_event_bus = event_bus
	_clock_port = clock_port
	return self


## Reset progression for a player on a world (fast remix).
## Returns true if successful, false if player has no progress to clear.
func reset_player_progress(profile_id: String, world_id: String) -> bool:
	if _progress_store == null:
		return false

	var cleared = _progress_store.clear_progress(profile_id, world_id)

	if cleared and _event_bus != null:
		var timestamp = _clock_port.now_iso8601() if _clock_port != null else ""
		var event = WorldRemixedEvent.new(world_id, profile_id, timestamp)
		_event_bus.emit(event)

	return cleared


## Reset all progression for a world (affects all players).
## Useful for balance updates or when restarting gameplay loops.
## Returns count of cleared progress records.
func reset_world_for_all_players(profile_id: String, world_id: String) -> int:
	# Note: Requires bulk clear capability in SessionProgressStorePort
	# For now, this is a placeholder for future enhancement
	push_warning("RemixWorldService.reset_world_for_all_players() requires SessionProgressStorePort.clear_world_all_players()")
	return 0


## Optional: Adjust difficulty/economy on world rules for remix session.
## This allows parents to tweak balance before next play without re-authoring.
func apply_balance_tweaks(world: World, tweaks: Dictionary) -> bool:
	if world == null or tweaks.is_empty():
		return false

	# Example tweaks: {"collectible_multiplier": 2.0, "spawn_rate": 1.5, ...}
	for rule in world.game_rules:
		if rule.rule_type == GameRule.RuleType.ITEM_SPAWN and "spawn_rate" in tweaks:
			# Rules can adjust spawn parameters
			rule.properties["spawn_rate"] = tweaks["spawn_rate"]
		elif rule.rule_type == GameRule.RuleType.SCORING and "collectible_multiplier" in tweaks:
			rule.properties["collectible_multiplier"] = tweaks["collectible_multiplier"]

	return true
