## Regression: visible-cursor world clicks recapture P1 without gameplay input.
## Run: godot --headless --path . --script tests/gameplay/test_sandbox_player_mouse_input.gd
extends SceneTree

const PlayerScript := preload("res://gameplay/player/sandbox_player.gd")
const ProfileScript := preload("res://core/resources/player_profile.gd")

var _exit_code := 0


class RecordingBuildController extends BuildController:
	var placement_attempts: int = 0

	func try_place() -> bool:
		placement_attempts += 1
		return true


func _init() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		print("FAIL: %s" % message)
		_exit_code = 1


func _spawn_player(device_id: int) -> Node:
	var player := PlayerScript.new()
	var profile := ProfileScript.make(0 if device_id == MultiplayerInputSystem.KEYBOARD_DEVICE else 1,
		device_id)
	player.setup(profile)
	player.tuning = PlayerTuning.new()
	return player


func _kit_input_state(player: Node) -> Dictionary:
	var build: BuildController = player._build
	var interaction = InteractionSystem.instance.focused_for(player.profile.player_id) \
		if InteractionSystem.instance else null
	return {
		"build_active": build.active if build else false,
		"build_mode": build.mode if build else -1,
		"build_selection": build.selected_index if build else -1,
		"build_yaw": build.yaw if build else 0.0,
		"held": player._held,
		"throw_charge": player._throw_charge,
		"interaction": interaction,
	}


func _run() -> void:
	MultiplayerInputSystem.instance.ensure_device(0)
	var p1 := _spawn_player(MultiplayerInputSystem.KEYBOARD_DEVICE)
	var p2 := _spawn_player(0)
	get_root().add_child(p1)
	get_root().add_child(p2)
	await physics_frame
	var original_build: BuildController = p1._build
	p1.remove_child(original_build)
	original_build.free()
	var build := RecordingBuildController.new()
	build.active = true
	build.mode = BuildController.Mode.SURFACE
	build.selected_index = 2
	build.yaw = 0.7
	p1.add_child(build)
	p1._build = build
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	var p2_yaw_before: float = p2._yaw
	var p2_click := InputEventMouseButton.new()
	p2_click.button_index = MOUSE_BUTTON_LEFT
	p2_click.pressed = true
	p2._unhandled_input(p2_click)
	_check(Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE,
		"P2 raw mouse click leaves cursor mode unchanged")
	_check(is_equal_approx(p2._yaw, p2_yaw_before),
		"P2 raw mouse input leaves yaw unchanged")
	var p2_motion := InputEventMouseMotion.new()
	p2_motion.relative = Vector2(32.0, 0.0)
	p2._unhandled_input(p2_motion)
	_check(is_equal_approx(p2._yaw, p2_yaw_before),
		"P2 raw mouse motion leaves yaw unchanged")

	var click := InputEventMouseButton.new()
	click.device = 0
	click.button_index = MOUSE_BUTTON_LEFT
	click.button_mask = MOUSE_BUTTON_MASK_LEFT
	click.pressed = true
	var kit_state_before := _kit_input_state(p1)
	Input.action_release(&"-1build_place")
	await process_frame
	# Script-mode tests seed the same action edge Godot derives from the mouse,
	# then dispatch the real mouse event through the root viewport.
	Input.action_press(&"-1build_place")
	get_root().push_input(click)
	_check(Input.is_action_just_pressed(&"-1build_place"),
		"recapture regression includes the keyboard player's build-place edge")
	await physics_frame
	await process_frame
	_check(build.placement_attempts == 0,
		"P1 dispatched recapture click cannot execute active build placement")
	_check(_kit_input_state(p1) == kit_state_before,
		"P1 dispatched recapture click leaves build/grab/throw/interaction state unchanged")
	_check(not Input.is_action_pressed(&"-1grab")
		and not Input.is_action_pressed(&"-1attack")
		and not Input.is_action_pressed(&"-1interact"),
		"P1 dispatched recapture click does not activate grab, attack, or interact")

	if DisplayServer.get_name() != "headless":
		_check(Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED,
			"P1 visible world click recaptures cursor")
		var yaw_before: float = p1._yaw
		var motion := InputEventMouseMotion.new()
		motion.relative = Vector2(32.0, 0.0)
		p1._unhandled_input(motion)
		_check(not is_equal_approx(p1._yaw, yaw_before),
			"P1 captured mouse motion changes yaw")
	else:
		print("SKIP: cursor capture requires a windowed display backend")
	var release := InputEventMouseButton.new()
	release.device = 0
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	get_root().push_input(release)
	Input.action_release(&"-1build_place")
	await physics_frame
	await process_frame
	Input.action_press(&"-1build_place")
	await physics_frame
	await process_frame
	_check(build.placement_attempts == 1,
		"the next captured LMB build-place edge executes normally")
	Input.action_release(&"-1build_place")
	await physics_frame
	await process_frame

	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	p1.queue_free()
	p2.queue_free()
	quit(_exit_code)
