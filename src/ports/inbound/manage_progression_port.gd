## Inbound use-case port: Manage session progression and world cloning.
## Allows UI to save session results, load prior progress, clone worlds, and reset progression.
class_name ManageProgressionPort
extends RefCounted


## Save completed session progression (collectibles, achievements, unlocks).
func save_session_progress(session: Session) -> bool:
	push_error("ManageProgressionPort.save_session_progress() not implemented")
	return false


## Load prior progression for player on world (for UI display and session bootstrap).
func load_world_progress(profile_id: String, world_id: String) -> ProgressState:
	push_error("ManageProgressionPort.load_world_progress() not implemented")
	return ProgressState.new()


## Clone world within project for remix workflow.
## Returns cloned world if successful, null otherwise.
func clone_world(project: Project, source_world: World, new_name: String = "") -> World:
	push_error("ManageProgressionPort.clone_world() not implemented")
	return null


## Reset player progression on world for fast remix (resets without re-authoring world).
## Returns true if successful, false if no prior progress exists.
func remix_world_reset_progress(profile_id: String, world_id: String) -> bool:
	push_error("ManageProgressionPort.remix_world_reset_progress() not implemented")
	return false
