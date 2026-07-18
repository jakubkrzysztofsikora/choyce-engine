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
	_test_homestead_has_complete_shell_and_playable_collision()
	quit(_exit_code)


func _test_supplied_visual_assets_exist() -> void:
	for asset_path in [
		VILLAGE + "Wall_Plaster_Window_Wide_Flat.gltf",
		VILLAGE + "Wall_Plaster_Door_Flat.gltf",
		VILLAGE + "Wall_Plaster_Straight.gltf",
		VILLAGE + "Roof_RoundTiles_8x10.gltf",
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

	for bay in range(5):
		_assert(renderer.get_node_or_null("HomeFacade_%d" % bay) != null,
			"street facade contains bay %d" % bay)
		_assert(renderer.get_node_or_null("HomeBack_%d" % bay) != null,
			"back facade contains bay %d" % bay)
		_assert(renderer.get_node_or_null("HomeLeft_%d" % bay) != null,
			"left facade contains bay %d" % bay)
		_assert(renderer.get_node_or_null("HomeRight_%d" % bay) != null,
			"right facade contains bay %d" % bay)
	_assert(renderer.get_node_or_null("HomeGabledRoof") != null,
		"home has a full gabled roof rather than a flat debug slab")
	_assert(renderer.get_node_or_null("HomeChimney") != null, "home has a chimney silhouette")

	var door := renderer.get_node_or_null("HomeDoor") as StaticBody3D
	_assert(door != null and door.is_in_group("world_interactable"),
		"front door remains an interactable physical object")
	var door_visual := door.get_node_or_null("HomeDoorVisual") as Node3D if door != null else null
	_assert(door_visual != null and door_visual.position.x > 1.0,
		"front door visual is offset from its hinge rather than rotating around its centre")
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

	renderer.queue_free()


func _has_collision(node: Node) -> bool:
	if node is not CollisionObject3D:
		return false
	for child in node.get_children():
		if child is CollisionShape3D and (child as CollisionShape3D).shape != null:
			return true
	return false


func _collision_width(node: Node) -> float:
	if node == null:
		return 0.0
	for child in node.get_children():
		if child is CollisionShape3D and (child as CollisionShape3D).shape is BoxShape3D:
			return ((child as CollisionShape3D).shape as BoxShape3D).size.x
	return 0.0
