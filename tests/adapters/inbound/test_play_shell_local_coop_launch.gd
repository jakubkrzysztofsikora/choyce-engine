## Launch-level local co-op regression. This exercises PlayShell's actual
## two-player path, not only SplitScreenRuntime in isolation.
## Run: godot --headless --path . -s res://tests/adapters/inbound/test_play_shell_local_coop_launch.gd
extends SceneTree

const PLAY_SHELL_SCENE := preload("res://src/adapters/inbound/scenes/play/play_shell.tscn")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		_failures.append(message)
		printerr("FAIL: ", message)


func _run() -> void:
	var world := World.new("local_coop_launch_world", "Wspólny świat")
	world.scene_nodes.append(SceneNode.new("camp", SceneNode.NodeType.OBJECT))
	var shell := PLAY_SHELL_SCENE.instantiate() as PlayShell
	root.add_child(shell)
	await process_frame
	var profile := PlayerProfile.new("local_coop_kid", PlayerProfile.Role.KID)
	shell.setup(null, profile, MockLocalizationPolicy.new(), MockRunPlaytestPort.new(), null, func() -> World: return world)
	shell.set_world_context(world.world_id)
	var session := shell.call("_launch_playtest", true) as Session
	_expect(session != null and session.player_ids.size() == 2, "PlayShell creates a two-profile local co-op session")
	await process_frame
	await process_frame
	var split := shell.get("_split_screen") as SplitScreenRuntime
	_expect(split != null and split.get_node_or_null("P2Container/P2Viewport/Player2") is PlayerController, "PlayShell launches the shared-world Gniewko split-screen path")
	var runtime := shell.get("_gameplay_runtime") as GameplayRuntime
	if runtime != null:
		runtime.end_session()
	await process_frame
	_expect(shell.get("_split_screen") == null and shell.get("_gameplay_runtime") == null, "PlayShell tears down co-op without retaining a second-player wrapper")
	_expect(_action_has_key("move_forward", KEY_UP), "PlayShell co-op teardown restores solo controls")
	shell.queue_free()
	await process_frame
	if _failures.is_empty():
		print("[test_play_shell_local_coop_launch] OK")
		quit(0)
	else:
		printerr("[test_play_shell_local_coop_launch] FAIL count=", _failures.size())
		quit(1)


func _action_has_key(action: StringName, keycode: Key) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey and (event as InputEventKey).keycode == keycode:
			return true
	return false


class MockRunPlaytestPort extends RunPlaytestPort:
	func execute(world_id: String, players: Array) -> Session:
		var session := Session.new("local_coop_session", world_id)
		for player in players:
			if player is PlayerProfile:
				session.add_player((player as PlayerProfile).profile_id)
		return session


class MockLocalizationPolicy extends LocalizationPolicyPort:
	func translate(key: String) -> String:
		return key

	func is_term_safe(_term: String) -> bool:
		return true

	func get_preferred_term(term_key: String) -> String:
		return term_key

	func get_parent_term(term_key: String) -> String:
		return term_key
