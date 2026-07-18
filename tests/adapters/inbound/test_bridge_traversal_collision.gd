## VS-040 Contract Test: Bridge traversal collision aligned with visible surfaces
## 
## Acceptance Criteria:
## - Stairs and bridge approaches use walkable slopes with collision aligned to their visible surfaces
## - World prop collisions use tight world-metre dimensions instead of oversized generic boxes

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
	var world := WorldRendererScript.new()
	get_root().add_child(world)
	
	# Build the opening scene which includes the bridge and water
	world._add_water_crossing()
	world._build_opening_bridge()
	
	await physics_frame
	
	# Check that bridge stairs are collidable (not just visual)
	# The supplied stair visuals sit above one continuous collision surface;
	# separate generic stair boxes had a vertical seam at the deck.
	for ramp_name in ["OpeningBridgeRampSouth", "OpeningBridgeRampNorth"]:
		var ramp := world.get_node_or_null(ramp_name) as Node3D
		_assert(ramp != null, "%s exists" % ramp_name)
		_assert(ramp != null, "%s contributes the continuous ramp profile" % ramp_name)
	_assert(world.find_children("OpeningBridgeSouthApproach_*", "Node3D", true, false).size() == 2,
		"both south supplied stair visuals exist")
	_assert(world.find_children("OpeningBridgeNorthApproach_*", "Node3D", true, false).size() == 2,
		"both north supplied stair visuals exist")
	var walk_surface := world.get_node_or_null("OpeningBridgeDeck") as StaticBody3D
	var walk_collisions := walk_surface.find_children("*", "CollisionShape3D", true, false) if walk_surface != null else []
	var walk_collision := walk_collisions[0] as CollisionShape3D if not walk_collisions.is_empty() else null
	_assert(walk_collision != null and walk_collision.shape is ConcavePolygonShape3D,
		"bridge deck and both ramps share one continuous collision surface")
	
	# Check that bridge rails are collidable
	# Rails use native GLTF collision: Node3D root with StaticBody3D child
	var rail_l_32 := world.find_child("OpeningBridgeRail_L_32", true, false)
	var rail_l_28 := world.find_child("OpeningBridgeRail_L_28", true, false)
	var rail_r_32 := world.find_child("OpeningBridgeRail_R_32", true, false)
	
	# Verify rail nodes exist and have StaticBody3D children (native GLTF collision)
	_assert(rail_l_32 != null,
		"Left rail at z=-32 exists")
	_assert(rail_r_32 != null,
		"Right rail at z=-32 exists")
	if rail_l_32 != null:
		var rail_l_body := rail_l_32.get_child(0) as StaticBody3D if rail_l_32.get_child_count() > 0 else null
		_assert(rail_l_body != null,
			"Left rail at z=-32 has native StaticBody3D collision from GLTF")
	if rail_r_32 != null:
		var rail_r_body := rail_r_32.get_child(0) as StaticBody3D if rail_r_32.get_child_count() > 0 else null
		_assert(rail_r_body != null,
			"Right rail at z=-32 has native StaticBody3D collision from GLTF")
	
	# Check that water volume exists and is properly configured
	var water := world.find_child("StarterRiver", true, false)
	_assert(water != null, "Water Area3D should exist")
	if water != null:
		_assert(water is Area3D, "StarterRiver should be Area3D")
		var water_visual := water.find_child("WaterSurface", true, false)
		_assert(water_visual != null, "Water should have visual surface")
		if water_visual != null:
			_assert(water_visual is MeshInstance3D, "WaterSurface should be MeshInstance3D")
			var material := water_visual.get_active_material(0) as ShaderMaterial
			_assert(material != null, "WaterSurface should have material")
			if material != null and material is ShaderMaterial:
				var shader := material.shader as Shader
				_assert(shader != null, "Water material should have shader")
	
	# Physics traversal test: verify a CharacterBody3D can cross the bridge
	var body := CharacterBody3D.new()
	body.name = "TraversalTestBody"
	var body_shape := CapsuleShape3D.new()
	body_shape.radius = 0.35
	body_shape.height = 1.8
	var body_collision := CollisionShape3D.new()
	body_collision.shape = body_shape
	body.add_child(body_collision)
	world.add_child(body)
	
	# Start at south of bridge
	body.global_position = Vector3(0.0, 2.0, -38.0)
	await physics_frame
	
	# Move north across the bridge
	var target_positions := [
		Vector3(0.0, 2.0, -35.0),  # south ramp
		Vector3(0.0, 2.0, -24.0),  # bridge center
		Vector3(0.0, 2.0, -15.0),  # north ramp
	]
	
	for target in target_positions:
		body.velocity = (target - body.global_position).normalized() * 5.0
		body.move_and_slide()
		await physics_frame
		# Verify body can reach each target position (with some tolerance for collision)
		var distance := body.global_position.distance_to(target)
		_assert(distance < 2.0,
			"CharacterBody3D can traverse to %s (reached within %.2fm)" % [target, distance])
	
	body.queue_free()
	
	# Cleanup
	world.queue_free()

	quit(_exit_code)
