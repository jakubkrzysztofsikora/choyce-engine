## Application service: launches a playtest session from the current world state.
## Validates that the world is playable, creates a Session entity, and
## initializes progression tracking.
class_name RunPlaytestService
extends RunPlaytestPort

var _project_store: ProjectStorePort
var _clock: ClockPort


func setup(project_store: ProjectStorePort, clock: ClockPort) -> RunPlaytestService:
	_project_store = project_store
	_clock = clock
	return self


## players: Array[PlayerProfile]
func execute(world_id: String, players: Array) -> Session:
	var project := _find_project_for_world(world_id)
	if project == null:
		return null

	var world := project.get_world(world_id)
	if world == null:
		return null

	if world.game_rules.is_empty() and world.scene_nodes.is_empty():
		return null

	var session := Session.new(
		"%s_session_%s" % [world_id, _clock.now_msec()],
		world_id
	)
	session.started_at = _clock.now_iso()
	session.is_active = true

	if players.size() > 1:
		session.mode = Session.SessionMode.CO_OP
	else:
		session.mode = Session.SessionMode.PLAY

	for player in players:
		session.add_player(player.profile_id)

	return session


func _find_project_for_world(world_id: String) -> Project:
	for project in _project_store.list_projects():
		if project.get_world(world_id) != null:
			return project
	return null
