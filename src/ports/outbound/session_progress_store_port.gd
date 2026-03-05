## Outbound port contract for session progression persistence.
## The application layer depends on this for saving and restoring player progression
## across sessions (collectibles, achievements, unlocks, quest progress).
class_name SessionProgressStorePort
extends RefCounted


## Save progression state for a player+world combination.
## Used after session completion to persist unlock status and achievements.
func save_progress(profile_id: String, world_id: String, progress: ProgressState) -> bool:
	push_error("SessionProgressStorePort.save_progress() not implemented")
	return false


## Load progression state for a player+world combination.
## Returns empty ProgressState if no prior progress exists.
func load_progress(profile_id: String, world_id: String) -> ProgressState:
	push_error("SessionProgressStorePort.load_progress() not implemented")
	return ProgressState.new()


## Clear progression for a world (used by remix/reset flows).
## Returns true if successful, false if not found.
func clear_progress(profile_id: String, world_id: String) -> bool:
	push_error("SessionProgressStorePort.clear_progress() not implemented")
	return false


## Get all progression records for a player (for dashboard/history views).
func list_player_progress(profile_id: String) -> Array:
	push_error("SessionProgressStorePort.list_player_progress() not implemented")
	return []
