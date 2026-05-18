## Tests for PlayShell direct-launch decoupling from CreateShell.
## MUST criteria:
##   M1 - setup_for_direct_launch wires _project_store
##   M2 - launch_world_by_id with null _project_store skips (no _active_world_id change)
##   M3 - launch_world_by_id with unknown project_id skips (no _active_world_id change)
##   M4 - launch_world_by_id with valid project + world sets _active_world_id and calls port
##   M5 - launch_world_by_id falls back to first world when world_id not matched
##   M6 - launch_world_by_id with no worlds skips
##   M7 - launch_world_by_id with null _run_playtest_port skips after world found
##   M8 - set_profile wires _profile
extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_setup_for_direct_launch_wires_store()
	await _test_null_store_returns_early()
	await _test_unknown_project_returns_early()
	await _test_valid_launch_sets_active_world_id()
	await _test_fallback_to_first_world()
	await _test_no_worlds_returns_early()
	await _test_null_run_playtest_port_returns_early()
	await _test_set_profile_wires_profile()
	print("ALL_PLAY_SHELL_DIRECT_LAUNCH_TESTS: PASS")
	quit(0)


## M1 - setup_for_direct_launch wires _project_store
func _test_setup_for_direct_launch_wires_store() -> void:
	var shell := PlayShell.new()
	get_root().add_child(shell)
	await process_frame
	var mock_store := MockProjectStore.new()
	shell.setup_for_direct_launch(mock_store)
	if shell._project_store != mock_store:
		print("FAIL M1: _project_store not wired after setup_for_direct_launch")
		shell.queue_free()
		quit(1)
		return
	print("PASS M1: _project_store wired")
	shell.queue_free()


## M2 - launch_world_by_id with null _project_store: _active_world_id unchanged
func _test_null_store_returns_early() -> void:
	var shell := PlayShell.new()
	get_root().add_child(shell)
	await process_frame
	# Do NOT call setup_for_direct_launch — store stays null
	var before_id: String = shell._active_world_id
	shell.launch_world_by_id("proj_1", "world_1")
	await process_frame
	if shell._active_world_id != before_id:
		print("FAIL M2: _active_world_id changed when store is null")
		shell.queue_free()
		quit(1)
		return
	print("PASS M2: null store returns early safely")
	shell.queue_free()


## M3 - launch_world_by_id with unknown project_id: _active_world_id unchanged
func _test_unknown_project_returns_early() -> void:
	var shell := PlayShell.new()
	get_root().add_child(shell)
	await process_frame
	var mock_store := MockProjectStore.new()
	mock_store.return_null = true
	shell.setup_for_direct_launch(mock_store)
	var before_id: String = shell._active_world_id
	shell.launch_world_by_id("bad_proj", "world_1")
	await process_frame
	if shell._active_world_id != before_id:
		print("FAIL M3: _active_world_id changed for unknown project")
		shell.queue_free()
		quit(1)
		return
	print("PASS M3: unknown project returns early")
	shell.queue_free()


## M4 - launch_world_by_id with valid project + matching world sets _active_world_id and calls port
func _test_valid_launch_sets_active_world_id() -> void:
	var shell := PlayShell.new()
	get_root().add_child(shell)
	await process_frame
	var mock_loc := MockLocalizationPolicy.new()
	var mock_port := MockRunPlaytestPort.new()
	var profile := PlayerProfile.new("kid_1", PlayerProfile.Role.KID)
	shell.setup(null, profile, mock_loc, mock_port)

	var world := World.new("world_abc", "Test World")
	world.scene_nodes.append(SceneNode.new("sn_1", "Skała", SceneNode.NodeType.OBJECT))

	var project := Project.new("proj_1", "My Project")
	project.add_world(world)

	var mock_store := MockProjectStore.new()
	mock_store.project = project
	shell.setup_for_direct_launch(mock_store)

	shell.launch_world_by_id("proj_1", "world_abc")
	await process_frame

	if shell._active_world_id != "world_abc":
		print("FAIL M4: _active_world_id not set; got: '%s'" % shell._active_world_id)
		shell.queue_free()
		quit(1)
		return
	if not mock_port.was_called:
		print("FAIL M4: run_playtest_port.execute not called")
		shell.queue_free()
		quit(1)
		return
	if mock_port.last_world_id != "world_abc":
		print("FAIL M4: port called with wrong world_id: '%s'" % mock_port.last_world_id)
		shell.queue_free()
		quit(1)
		return
	print("PASS M4: valid launch sets _active_world_id and calls port")
	shell.queue_free()


## M5 - launch_world_by_id falls back to first world when world_id not matched
func _test_fallback_to_first_world() -> void:
	var shell := PlayShell.new()
	get_root().add_child(shell)
	await process_frame
	var mock_loc := MockLocalizationPolicy.new()
	var mock_port := MockRunPlaytestPort.new()
	var profile := PlayerProfile.new("kid_1", PlayerProfile.Role.KID)
	shell.setup(null, profile, mock_loc, mock_port)

	var world := World.new("world_first", "First World")
	world.scene_nodes.append(SceneNode.new("sn_1", "Palma", SceneNode.NodeType.OBJECT))

	var project := Project.new("proj_1", "My Project")
	project.add_world(world)

	var mock_store := MockProjectStore.new()
	mock_store.project = project
	shell.setup_for_direct_launch(mock_store)

	shell.launch_world_by_id("proj_1", "non_existent_world")
	await process_frame

	if shell._active_world_id != "world_first":
		print("FAIL M5: fallback did not use first world; _active_world_id='%s'" % shell._active_world_id)
		shell.queue_free()
		quit(1)
		return
	print("PASS M5: fallback to first world works")
	shell.queue_free()


## M6 - launch_world_by_id with project that has no worlds returns early
func _test_no_worlds_returns_early() -> void:
	var shell := PlayShell.new()
	get_root().add_child(shell)
	await process_frame
	var mock_loc := MockLocalizationPolicy.new()
	var mock_port := MockRunPlaytestPort.new()
	var profile := PlayerProfile.new("kid_1", PlayerProfile.Role.KID)
	shell.setup(null, profile, mock_loc, mock_port)

	var project := Project.new("proj_empty", "Empty")
	# No worlds added

	var mock_store := MockProjectStore.new()
	mock_store.project = project
	shell.setup_for_direct_launch(mock_store)

	var before_id: String = shell._active_world_id
	shell.launch_world_by_id("proj_empty", "world_1")
	await process_frame

	if shell._active_world_id != before_id:
		print("FAIL M6: _active_world_id changed for project with no worlds")
		shell.queue_free()
		quit(1)
		return
	print("PASS M6: no worlds returns early")
	shell.queue_free()


## M7 - launch_world_by_id with null _run_playtest_port: stops after world found
func _test_null_run_playtest_port_returns_early() -> void:
	var shell := PlayShell.new()
	get_root().add_child(shell)
	await process_frame
	var mock_loc := MockLocalizationPolicy.new()
	var profile := PlayerProfile.new("kid_1", PlayerProfile.Role.KID)
	# setup with null run_playtest_port
	shell.setup(null, profile, mock_loc, null)

	var world := World.new("world_1", "Test")
	world.scene_nodes.append(SceneNode.new("sn_1", "Skała", SceneNode.NodeType.OBJECT))
	var project := Project.new("proj_1", "My Project")
	project.add_world(world)

	var mock_store := MockProjectStore.new()
	mock_store.project = project
	shell.setup_for_direct_launch(mock_store)

	# _active_world_id SHOULD be set (before port check), but _start_gameplay should NOT run
	# We confirm no crash occurs and the method handles the null gracefully.
	shell.launch_world_by_id("proj_1", "world_1")
	await process_frame

	# _active_world_id is set by design (world found), but no gameplay was started.
	# Just assert no exception was thrown (reaching here = pass).
	if shell._active_world_id != "world_1":
		print("FAIL M7: _active_world_id should be set even when port is null, got: '%s'" % shell._active_world_id)
		shell.queue_free()
		quit(1)
		return
	print("PASS M7: null run_playtest_port returns early after setting world_id")
	shell.queue_free()


## M8 - set_profile wires _profile
func _test_set_profile_wires_profile() -> void:
	var shell := PlayShell.new()
	get_root().add_child(shell)
	await process_frame
	var profile := PlayerProfile.new("kid_2", PlayerProfile.Role.KID)
	shell.set_profile(profile)
	if shell._profile != profile:
		print("FAIL M8: set_profile did not wire _profile")
		shell.queue_free()
		quit(1)
		return
	print("PASS M8: set_profile wires _profile")
	shell.queue_free()


# --- Mock helpers ---

class MockProjectStore extends ProjectStorePort:
	var project: Project = null
	var return_null: bool = false

	func load_project(_project_id: String) -> Project:
		if return_null:
			return null
		return project

	func list_projects() -> Array:
		if project == null:
			return []
		return [project]

	func save_project(_project: Project) -> bool:
		return true


class MockRunPlaytestPort extends RunPlaytestPort:
	var was_called: bool = false
	var last_world_id: String = ""

	func execute(world_id: String, _players: Array) -> Session:
		was_called = true
		last_world_id = world_id
		return Session.new("mock_session_1", world_id)


class MockLocalizationPolicy extends LocalizationPolicyPort:
	func translate(key: String) -> String:
		return key

	func is_term_safe(_term: String) -> bool:
		return true

	func get_preferred_term(term_key: String) -> String:
		return term_key

	func get_parent_term(term_key: String) -> String:
		return term_key

	func get_locale() -> String:
		return "pl-PL"
