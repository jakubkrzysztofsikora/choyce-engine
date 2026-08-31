## Regression: right-click must place the currently selected creative block.
extends SceneTree

const PlayerControllerScript = preload("res://src/adapters/inbound/gameplay/player_controller.gd")
const BuildGridScript = preload("res://src/adapters/inbound/gameplay/build_grid.gd")

var _exit_code := 0


func _init() -> void:
	call_deferred("_run")


func _assert(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		print("FAIL: %s" % message)
		_exit_code = 1


func _run() -> void:
	var ground := StaticBody3D.new()
	var ground_collision := CollisionShape3D.new()
	var ground_shape := BoxShape3D.new()
	ground_shape.size = Vector3(30.0, 0.5, 30.0)
	ground_collision.shape = ground_shape
	ground_collision.position.y = -0.25
	ground.add_child(ground_collision)
	get_root().add_child(ground)

	var player := PlayerControllerScript.new()
	player.position = Vector3.ZERO
	var camera := Camera3D.new()
	camera.name = "Camera3D"
	camera.position = Vector3(0.0, 1.7, 4.2)
	camera.rotation.x = -0.43
	player.add_child(camera)
	get_root().add_child(player)
	var grid := BuildGridScript.new()
	get_root().add_child(grid)
	player.setup_build_grid(grid)
	player._select_hotbar_slot(2) # grass follows axe + pickaxe in the creative hotbar
	await physics_frame
	_assert(is_equal_approx(camera.fov, 50.0),
		"third-person controller preserves the composed 50-degree opening lens")

	# ESC releases capture for HUD use. Clicking empty 3D space must reliably
	# recapture it before mouselook can resume. The headless display backend
	# intentionally cannot capture a system cursor, so this OS integration
	# assertion runs only when Godot owns a real window.
	if DisplayServer.get_name() != "headless":
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		var recapture_event := InputEventMouseButton.new()
		recapture_event.button_index = MOUSE_BUTTON_LEFT
		recapture_event.pressed = true
		player._unhandled_input(recapture_event)
		_assert(Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED,
			"left click in the 3D view recaptures the cursor after it is released")
		_assert(not Input.is_action_pressed("attack"),
			"the recapture click does not also trigger an attack")
		var yaw_before_mouse_look := player.rotation.y
		var mouse_motion := InputEventMouseMotion.new()
		mouse_motion.relative = Vector2(40.0, 0.0)
		player._unhandled_input(mouse_motion)
		_assert(not is_equal_approx(player.rotation.y, yaw_before_mouse_look),
			"captured mouse motion changes third-person camera yaw")
	else:
		print("SKIP: cursor capture requires a windowed display backend")

	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	var place_event := InputEventMouseButton.new()
	place_event.button_index = MOUSE_BUTTON_RIGHT
	place_event.pressed = true
	player._unhandled_input(place_event)
	var ray_hit := player._build_raycast()
	_assert(not ray_hit.is_empty(), "third-person build ray finds ground")
	await physics_frame
	var release_event := InputEventMouseButton.new()
	release_event.button_index = MOUSE_BUTTON_RIGHT
	release_event.pressed = false
	player._unhandled_input(release_event)
	_assert(grid.block_count() == 1, "captured right-click places selected build block")

	# Furniture interaction must not create a collisionless fall-through state.
	# The visible sit pose may move, but the physical controller remains part of
	# the real world and the general void recovery still catches a bad tile.
	var collision_layer_before := player.collision_layer
	var collision_mask_before := player.collision_mask
	player.play_sit_at(Vector3(1.2, 0.8, -0.4))
	_assert(player.collision_layer == collision_layer_before and player.collision_mask == collision_mask_before,
		"sitting keeps the player collision enabled")
	player.global_position.y = PlayerControllerScript.VOID_RECOVERY_Y - 2.0
	player._physics_process(1.0 / 60.0)
	_assert(player.global_position.y > PlayerControllerScript.VOID_RECOVERY_Y,
		"a bad furniture or terrain position recovers instead of falling forever")

	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	player.queue_free()
	grid.queue_free()
	ground.queue_free()
	quit(_exit_code)
