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

	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	var place_event := InputEventMouseButton.new()
	place_event.button_index = MOUSE_BUTTON_RIGHT
	place_event.pressed = true
	player._input(place_event)
	var ray_hit := player._build_raycast()
	_assert(not ray_hit.is_empty(), "third-person build ray finds ground")
	await physics_frame
	var release_event := InputEventMouseButton.new()
	release_event.button_index = MOUSE_BUTTON_RIGHT
	release_event.pressed = false
	player._input(release_event)
	_assert(grid.block_count() == 1, "captured right-click places selected build block")

	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	player.queue_free()
	grid.queue_free()
	ground.queue_free()
	quit(_exit_code)
