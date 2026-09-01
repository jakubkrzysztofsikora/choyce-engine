## Regression: visible-cursor world clicks recapture P1 without gameplay input.
## Run: godot --headless --path . --script tests/gameplay/test_sandbox_player_mouse_input.gd
extends SceneTree

const PlayerScript := preload("res://gameplay/player/sandbox_player.gd")
const ProfileScript := preload("res://core/resources/player_profile.gd")

var _exit_code := 0


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
	var p1 := _spawn_player(MultiplayerInputSystem.KEYBOARD_DEVICE)
	var p2 := _spawn_player(0)
	# Seed representative Kit state without requiring a full scene tree/runtime.
	p1._build = BuildController.new()
	p1._build.active = true
	p1._build.mode = BuildController.Mode.SURFACE
	p1._build.selected_index = 2
	p1._build.yaw = 0.7
	p1._held = GrabComponent.new()
	p1._throw_charge = 0.65
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

	if DisplayServer.get_name() != "headless":
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		var kit_state_before := _kit_input_state(p1)
		p1._unhandled_input(click)
		_check(Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED,
			"P1 visible world click recaptures cursor")
		_check(_kit_input_state(p1) == kit_state_before,
			"P1 recapture click leaves build/grab/throw/interaction state unchanged")
		var yaw_before: float = p1._yaw
		var motion := InputEventMouseMotion.new()
		motion.relative = Vector2(32.0, 0.0)
		p1._unhandled_input(motion)
		_check(not is_equal_approx(p1._yaw, yaw_before),
			"P1 captured mouse motion changes yaw")
	else:
		print("SKIP: cursor capture requires a windowed display backend")

	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	p1.free()
	p2.free()
	quit(_exit_code)
