class_name RunPlaytestServiceContractTest
extends PortContractTest


class MockProjectStore:
	extends ProjectStorePort

	var _projects: Array = []

	func save_project(project: Project) -> bool:
		for i in range(_projects.size()):
			var existing: Variant = _projects[i]
			if existing is Project and (existing as Project).project_id == project.project_id:
				_projects[i] = project
				return true
		_projects.append(project)
		return true

	func load_project(project_id: String) -> Project:
		for project_variant in _projects:
			if project_variant is Project:
				var project: Project = project_variant
				if project.project_id == project_id:
					return project
		return null

	func list_projects() -> Array:
		return _projects


class MockClock:
	extends ClockPort

	var _tick: int = 0

	func now_iso() -> String:
		_tick += 1
		return "2026-03-02T18:00:%02dZ" % _tick

	func now_msec() -> int:
		_tick += 1
		return 1767434400000 + _tick


func run() -> Dictionary:
	_reset()

	var store := MockProjectStore.new()
	var service := RunPlaytestService.new().setup(store, MockClock.new())
	var kid := PlayerProfile.new("kid-1", PlayerProfile.Role.KID)
	# Local co-op baseline allows a parent profile as the second local participant.
	var parent := PlayerProfile.new("parent-1", PlayerProfile.Role.PARENT)

	var playable_project := Project.new("project-playtest", "Playtest")
	var playable_world := World.new("world-playtest", "Plac zabaw")
	playable_world.add_node(SceneNode.new("node-1", SceneNode.NodeType.OBJECT))
	playable_project.add_world(playable_world)
	store.save_project(playable_project)

	var solo_session := service.execute("world-playtest", [kid])
	_assert_true(solo_session != null, "Solo playtest should start from current world")
	_assert_true(
		solo_session.mode == Session.SessionMode.PLAY,
		"Single-player launch should use PLAY mode"
	)
	_assert_true(
		solo_session.player_ids.size() == 1 and solo_session.player_ids[0] == kid.profile_id,
		"Solo playtest should include exactly one player"
	)

	var coop_session := service.execute("world-playtest", [kid, parent])
	_assert_true(coop_session != null, "Co-op playtest should start for two local players")
	_assert_true(
		coop_session.mode == Session.SessionMode.CO_OP,
		"Two-player launch should use CO_OP mode baseline"
	)
	_assert_true(
		coop_session.player_ids.size() == 2,
		"Co-op playtest should include two players"
	)

	var missing_world := service.execute("unknown-world", [kid])
	_assert_true(
		missing_world == null,
		"Playtest launch should fail for unknown world id"
	)

	var empty_project := Project.new("project-empty", "Empty")
	var empty_world := World.new("world-empty", "Pusty")
	empty_project.add_world(empty_world)
	store.save_project(empty_project)
	var empty_launch := service.execute("world-empty", [kid])
	_assert_true(
		empty_launch == null,
		"Playtest should not launch for worlds without nodes/rules baseline content"
	)

	return _build_result("RunPlaytestService")
