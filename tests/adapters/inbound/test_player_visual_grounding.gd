## Regression: cosmetic poses must preserve the imported rig's real ground offset.
extends SceneTree

const PlayerControllerScript = preload("res://src/adapters/inbound/gameplay/player_controller.gd")
const CharacterScene = preload("res://data/models/kenney/toon_characters/Models/GLB format/character-male-a.glb")

var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _assert(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		print("FAIL: %s" % message)
		_failures += 1


func _run() -> void:
	var floor := StaticBody3D.new()
	floor.name = "Ground"
	var floor_collision := CollisionShape3D.new()
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(20.0, 0.5, 20.0)
	floor_collision.shape = floor_shape
	floor_collision.position.y = -0.25
	floor.add_child(floor_collision)
	get_root().add_child(floor)
	var player := PlayerControllerScript.new()
	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	collision.shape = capsule
	collision.position.y = 0.8
	player.add_child(collision)
	var rig := CharacterScene.instantiate() as Node3D
	rig.name = "CharacterMesh"
	player.add_child(rig)
	var camera := Camera3D.new()
	camera.name = "Camera3D"
	player.add_child(camera)
	get_root().add_child(player)
	await process_frame
	player.spawn_at(Vector3(0.0, 0.10, 0.0))
	for _frame in 45:
		await physics_frame
	_assert(player.is_on_floor(), "spawned controller settles onto the physical floor")
	_assert(is_equal_approx(player.global_position.y, 0.10),
		"controller root remains at the capsule's calibrated floor-contact height")

	var grounded_y := player._character_visual_ground_y
	_assert(not is_zero_approx(grounded_y), "imported rig calibrates a non-zero visual ground offset")
	player._trigger_punch_animation()
	_assert(is_equal_approx(player._character_mesh.position.y, grounded_y),
		"combat pose restores the calibrated visual ground instead of y=0")
	player._perform_silly_fart()
	await create_timer(0.3).timeout
	_assert(is_equal_approx(player._character_mesh.position.y, grounded_y),
		"fart pose returns to the calibrated visual ground")
	print("INFO: player_root_y=%.3f character_visual_y=%.3f visual_floor_y=%.3f" % [
		player.global_position.y,
		player._character_mesh.position.y,
		player._character_mesh.position.y + _lowest_visual_mesh_y(player._character_mesh),
	])
	player.queue_free()
	floor.queue_free()
	quit(_failures)


func _lowest_visual_mesh_y(character_root: Node3D) -> float:
	var lowest_y := INF
	for mesh_variant in character_root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := mesh_variant as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		var mesh_aabb := mesh_instance.mesh.get_aabb()
		for corner_index in range(8):
			var local_corner := mesh_aabb.get_endpoint(corner_index)
			var character_local_corner := character_root.to_local(mesh_instance.to_global(local_corner))
			lowest_y = minf(lowest_y, character_local_corner.y)
	return lowest_y
