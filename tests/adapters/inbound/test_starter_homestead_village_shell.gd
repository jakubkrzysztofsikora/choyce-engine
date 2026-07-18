## Regression coverage for the adult-scale, enterable starter house.
## The visual shell uses the CC0 Quaternius Village MegaKit while collision
## remains explicit gameplay geometry. Keep both sides present: a pretty house
## without collision is not playable, and invisible collision alone regresses
## back to a debug-box house.
extends SceneTree

const WorldRenderer = preload("res://src/adapters/inbound/gameplay/world_renderer.gd")

const VILLAGE := "res://data/models/quaternius/medieval_village/"
const INTERIORS := "res://data/models/third_party/poly_pizza_zsky/"

var _exit_code := 0


func _init() -> void:
	call_deferred("_run_tests")


func _assert(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		print("FAIL: %s" % message)
		_exit_code = 1


func _run_tests() -> void:
	print("=== starter homestead: modular village shell tests ===")
	_test_supplied_visual_assets_exist()
	await _test_homestead_has_complete_shell_and_playable_collision()
	quit(_exit_code)


func _test_supplied_visual_assets_exist() -> void:
	for asset_path in [
		VILLAGE + "Wall_Plaster_Window_Wide_Flat.gltf",
		VILLAGE + "Wall_Plaster_Door_Flat.gltf",
		VILLAGE + "Wall_Plaster_Straight.gltf",
		VILLAGE + "Floor_WoodDark.gltf",
		VILLAGE + "Roof_RoundTiles_8x12.gltf",
		VILLAGE + "Prop_Chimney.gltf",
		VILLAGE + "Door_2_Flat.gltf",
		INTERIORS + "Double Bed.glb",
		INTERIORS + "Wood Kitchen Table.glb",
		INTERIORS + "Gas Stove.glb",
	]:
		_assert(ResourceLoader.exists(asset_path), "required sourced asset exists: %s" % asset_path.get_file())


func _test_homestead_has_complete_shell_and_playable_collision() -> void:
	var renderer := WorldRenderer.new()
	get_root().add_child(renderer)
	renderer._build_starter_homestead()
	await process_frame

	for bay in range(5):
		_assert(renderer.get_node_or_null("HomeFacade_%d" % bay) != null,
			"street facade contains bay %d" % bay)
		_assert(renderer.get_node_or_null("HomeBack_%d" % bay) != null,
			"back facade contains bay %d" % bay)
		_assert(renderer.get_node_or_null("HomeLeft_%d" % bay) != null,
			"left facade contains bay %d" % bay)
		_assert(renderer.get_node_or_null("HomeRight_%d" % bay) != null,
			"right facade contains bay %d" % bay)
	for edge_name in [
		"HomeFacadeEdge_Left", "HomeFacadeEdge_Right",
		"HomeBackEdge_Left", "HomeBackEdge_Right",
		"HomeLeftEnd_Front", "HomeLeftEnd_Back",
		"HomeRightEnd_Front", "HomeRightEnd_Back",
	]:
		_assert(renderer.get_node_or_null(edge_name) != null,
			"house closes its 12m shell at %s" % edge_name)
	_assert(renderer.get_node_or_null("HomeGabledRoof") != null,
		"home has a full gabled roof rather than a flat debug slab")
	_assert(renderer.get_node_or_null("HomeChimney") != null, "home has a chimney silhouette")
	# The individual tiles deliberately do not join a gameplay group: they are
	# decorative PBR surfaces while HomeFloor owns the physical surface.
	var floor_tile_count := 0
	for x in range(-5, 6, 2):
		for z in range(-5, 6, 2):
			if renderer.get_node_or_null("HomeFloorTile_%d_%d" % [x, z]) != null:
				floor_tile_count += 1
	_assert(floor_tile_count == 36, "home has a complete 6x6 textured wood floor")

	var door := renderer.get_node_or_null("HomeDoor") as StaticBody3D
	_assert(door != null and door.is_in_group("world_interactable"),
		"front door remains an interactable physical object")
	var door_visual := door.get_node_or_null("HomeDoorVisual") as Node3D if door != null else null
	_assert(door_visual != null and is_zero_approx(door_visual.position.x)
		and is_equal_approx(door_visual.scale.x, 2.0)
		and is_equal_approx(door_visual.scale.y, 1.18),
		"front door starts at its real hinge and fills the village doorway")
	var door_bounds := _world_mesh_bounds(door_visual)
	_assert(door_bounds.z > 0.60 and door_bounds.z < 0.70 and door_bounds.w > 3.08 and door_bounds.w < 3.18,
		"door mesh spans the wall's real threshold-to-lintel height")
	_assert(door_bounds.x > 22.75 and door_bounds.x < 23.00 and door_bounds.y > 24.95 and door_bounds.y < 25.20,
		"door mesh stays inside the physical 2.2m doorway horizontally")
	renderer.toggle_door(door)
	await create_timer(0.42).timeout
	await physics_frame
	await process_frame
	var opened_door_bounds := _world_mesh_bounds(door_visual)
	var door_collision := _first_collision_shape(door)
	_assert(bool(door.get_meta("door_open", false)), "door records its open state")
	_assert(door_collision != null, "door keeps a direct physical-leaf reference")
	_assert(door_collision != null and door_collision.disabled,
		"opening the door releases only its matching physical leaf")
	_assert(opened_door_bounds.y < door_bounds.y - 0.70,
		"open door rotates from the same left hinge instead of a detached centre pivot")
	for wall_name in ["HomeBackWall", "HomeLeftWall", "HomeRightWall", "HomeFrontWallL", "HomeFrontWallR", "HomeFloor"]:
		_assert(_has_collision(renderer.get_node_or_null(wall_name)), "%s has explicit collision" % wall_name)
	_assert(_collision_width(renderer.get_node_or_null("HomeFrontWallL")) >= 5.0
		and _collision_width(renderer.get_node_or_null("HomeFrontWallR")) >= 5.0,
		"front-wall collision covers the visual window wings without side walk-through gaps")
	for furniture_name in [
		"HomeDoubleBed", "HomeKitchenTable", "HomeChairNorth", "HomeChairSouth",
		"HomeStove", "HomeFridge", "HomeSink", "HomeCouch", "HomeBookshelf", "HomeFloorLamp",
	]:
		_assert(_has_collision(renderer.get_node_or_null(furniture_name)),
			"%s has object-sized collision" % furniture_name)
		_assert(absf(_lowest_mesh_y(renderer.get_node_or_null(furniture_name) as Node3D)) < 0.03,
			"%s visual rests on its floor surface" % furniture_name)
		_assert(absf(_collision_bottom_y(renderer.get_node_or_null(furniture_name))) < 0.03,
			"%s collision begins at the same floor surface" % furniture_name)
	var seat_anchor := renderer.get_node_or_null("home_sit") as Area3D
	var seat_position: Variant = seat_anchor.get_meta("seat_position", null) if seat_anchor != null else null
	_assert(seat_position is Vector3 and (seat_position as Vector3).y > 0.70,
		"sit interaction carries an explicit above-chair seat transform")

	renderer.queue_free()


func _has_collision(node: Node) -> bool:
	if node is not CollisionObject3D:
		return false
	for child in node.get_children():
		if child is CollisionShape3D and (child as CollisionShape3D).shape != null:
			return true
	return false


func _first_collision_shape(node: Node) -> CollisionShape3D:
	if node == null:
		return null
	for child in node.get_children():
		if child is CollisionShape3D:
			return child as CollisionShape3D
	return null


func _collision_width(node: Node) -> float:
	if node == null:
		return 0.0
	for child in node.get_children():
		if child is CollisionShape3D and (child as CollisionShape3D).shape is BoxShape3D:
			return ((child as CollisionShape3D).shape as BoxShape3D).size.x
	return 0.0


func _lowest_mesh_y(root: Node3D) -> float:
	if root == null:
		return INF
	var bottom := INF
	for child_variant in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child_variant as MeshInstance3D
		var bounds := mesh_instance.get_aabb()
		for x in [bounds.position.x, bounds.end.x]:
			for y in [bounds.position.y, bounds.end.y]:
				for z in [bounds.position.z, bounds.end.z]:
					bottom = minf(bottom, (mesh_instance.global_transform * Vector3(x, y, z)).y)
	return bottom


func _collision_bottom_y(node: Node) -> float:
	if not node is CollisionObject3D:
		return INF
	for child_variant in node.get_children():
		var collision := child_variant as CollisionShape3D
		if collision == null or not collision.shape is BoxShape3D:
			continue
		var box := collision.shape as BoxShape3D
		var world_height := box.size.y * collision.global_transform.basis.get_scale().y
		return collision.global_position.y - world_height * 0.5
	return INF


## x=min x, y=max x, z=min y, w=max y. We only need horizontal and vertical
## boundaries here, so a compact Vector4 keeps the test output readable.
func _world_mesh_bounds(root: Node3D) -> Vector4:
	if root == null:
		return Vector4(INF, -INF, INF, -INF)
	var min_x := INF
	var max_x := -INF
	var min_y := INF
	var max_y := -INF
	for child_variant in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child_variant as MeshInstance3D
		var bounds := mesh_instance.get_aabb()
		for x in [bounds.position.x, bounds.end.x]:
			for y in [bounds.position.y, bounds.end.y]:
				for z in [bounds.position.z, bounds.end.z]:
					var world_point := mesh_instance.global_transform * Vector3(x, y, z)
					min_x = minf(min_x, world_point.x)
					max_x = maxf(max_x, world_point.x)
					min_y = minf(min_y, world_point.y)
					max_y = maxf(max_y, world_point.y)
	return Vector4(min_x, max_x, min_y, max_y)
