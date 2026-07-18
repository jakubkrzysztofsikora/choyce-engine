## Regression: the authored opening must be a playable route, not a pretty
## arrangement of separate colliders. A child-scale capsule walks spawn → bridge
## → bridge-facing door → home interior after opening the physical door.
extends SceneTree

const WorldRendererScript = preload("res://src/adapters/inbound/gameplay/world_renderer.gd")

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
	ground.name = "TraversalGround"
	var ground_collision := CollisionShape3D.new()
	var ground_shape := BoxShape3D.new()
	ground_shape.size = Vector3(180.0, 0.2, 180.0)
	ground_collision.shape = ground_shape
	ground_collision.position.y = -0.1
	ground.add_child(ground_collision)
	get_root().add_child(ground)

	var world := WorldRendererScript.new()
	get_root().add_child(world)
	world._build_opening_bridge()
	world._build_starter_homestead()
	world._build_opening_courtyard()
	var door := world.get_node_or_null("HomeDoor") as StaticBody3D
	_assert(door != null and door.position.z > -41.0 and door.position.z < -39.0,
		"home door faces the bridge-side approach")
	world.toggle_door(door)
	await create_timer(0.42).timeout
	await physics_frame

	var walker := CharacterBody3D.new()
	walker.name = "RouteTraversalCapsule"
	walker.floor_snap_length = 0.35
	walker.floor_max_angle = deg_to_rad(52.0)
	walker.safe_margin = 0.025
	var walker_collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.32
	capsule.height = 1.45
	walker_collision.shape = capsule
	walker.add_child(walker_collision)
	walker.position = Vector3(0.0, 1.1, 0.0)
	get_root().add_child(walker)
	for settle in 12:
		walker.velocity.y = -2.0
		walker.move_and_slide()
		await physics_frame

	# 36m at the deliberately child-friendly 4m/s walk speed needs over nine
	# seconds including floor snap and the two ramps; do not mistake a too-short
	# test budget for a collision failure.
	var crossed := await _walk_to(walker, Vector3(0.0, 0.0, -35.8), 660)
	_assert(crossed, "child-scale capsule reaches the north bridge exit")
	# Follow the authored courtyard turn before heading through the door. A direct
	# diagonal through the facade would be a test bug, not the intended route.
	var reached_doorway := await _walk_to(walker, Vector3(12.0, 0.0, -37.2), 260)
	_assert(reached_doorway, "courtyard route reaches the bridge-facing doorway")
	var entered := await _walk_to(walker, Vector3(12.0, 0.0, -44.0), 180)
	_assert(entered, "opened bridge-facing door leads into the home interior")

	walker.queue_free()
	world.queue_free()
	ground.queue_free()
	quit(_exit_code)


func _walk_to(walker: CharacterBody3D, target: Vector3, max_frames: int) -> bool:
	for frame in max_frames:
		var horizontal := Vector2(target.x - walker.global_position.x, target.z - walker.global_position.z)
		if horizontal.length() < 0.75:
			return true
		var direction := horizontal.normalized()
		walker.velocity.x = direction.x * 4.0
		walker.velocity.z = direction.y * 4.0
		if not walker.is_on_floor():
			walker.velocity.y = maxf(walker.velocity.y - 0.32, -8.0)
		else:
			walker.velocity.y = -0.2
		walker.move_and_slide()
		await physics_frame
	return Vector2(target.x - walker.global_position.x, target.z - walker.global_position.z).length() < 0.75
