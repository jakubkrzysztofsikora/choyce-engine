## Application service implementing ManageProgressionPort.
## Coordinates progression saving, loading, world cloning, and remix workflows.
class_name ManageProgressionService
extends ManageProgressionPort


var _progress_store: SessionProgressStorePort
var _clone_service: CloneWorldService
var _remix_service: RemixWorldService
var _event_bus: DomainEventBus


func setup(
	progress_store: SessionProgressStorePort,
	event_bus: DomainEventBus = null
) -> ManageProgressionService:
	_progress_store = progress_store
	_event_bus = event_bus
	_clone_service = CloneWorldService.new()
	_remix_service = RemixWorldService.new().setup(progress_store, event_bus)
	return self


## Save completed session progression to persistent store.
func save_session_progress(session: Session) -> bool:
	if _progress_store == null or session == null:
		return false

	var saved = _progress_store.save_progress(
		session.player_ids[0] if session.player_ids.size() > 0 else "",
		session.world_id,
		session.progress
	)

	if saved and _event_bus != null:
		var event = SessionProgressUpdatedEvent.new(
			session.session_id,
			session.world_id,
			session.player_ids[0] if session.player_ids.size() > 0 else "",
			session.progress
		)
		_event_bus.emit(event)

	return saved


## Load prior progression for UI display and session initialization.
func load_world_progress(profile_id: String, world_id: String) -> ProgressState:
	if _progress_store == null:
		return ProgressState.new()

	return _progress_store.load_progress(profile_id, world_id)


## Clone world within project (for remix authoring workflow).
## Returns cloned world or null if failed.
func clone_world(project: Project, source_world: World, new_name: String = "") -> World:
	if _clone_service == null:
		return null

	return _clone_service.clone_world(source_world, project, new_name)


## Reset player progression on world for fast remix.
## Returns true if successful, false otherwise.
func remix_world_reset_progress(profile_id: String, world_id: String) -> bool:
	if _remix_service == null:
		return false

	return _remix_service.reset_player_progress(profile_id, world_id)
