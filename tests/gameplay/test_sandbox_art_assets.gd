extends SceneTree

const PlayerScript := preload("res://gameplay/player/sandbox_player.gd")
const ProfileScript := preload("res://core/resources/player_profile.gd")
const SandboxLevelScript := preload("res://levels/sandbox_level.gd")
const PropFactoryScript := preload("res://gameplay/props/prop_factory.gd")

var _failed := false


func _init() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failed = true
		print("FAIL: %s" % message)


func _has_textured_or_fallback_material(root: Node) -> bool:
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		var override := mesh.material_override as StandardMaterial3D
		var active := mesh.get_active_material(0) as StandardMaterial3D
		if override != null or (active != null and active.albedo_texture != null):
			return true
	return false


func _triangle_surface(offset: float) -> Array:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([
		Vector3(offset, 0.0, 0.0), Vector3(offset + 1.0, 0.0, 0.0), Vector3(offset, 1.0, 0.0),
	])
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.FORWARD, Vector3.FORWARD, Vector3.FORWARD])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2.ZERO, Vector2.RIGHT, Vector2.UP])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2])
	return arrays


func _mixed_material_mesh() -> MeshInstance3D:
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _triangle_surface(0.0))
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _triangle_surface(2.0))
	var plain := StandardMaterial3D.new()
	plain.albedo_color = Color("#eeeeee")
	mesh.surface_set_material(0, plain)
	var textured := StandardMaterial3D.new()
	textured.albedo_texture = load("res://data/textures/pbr/ground003/Ground003_1K-JPG_Color.jpg") as Texture2D
	mesh.surface_set_material(1, textured)
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	return instance


func _run() -> void:
	var player := PlayerScript.new()
	player.setup(ProfileScript.make(0, MultiplayerInputSystem.KEYBOARD_DEVICE))
	get_root().add_child(player)
	var level := SandboxLevelScript.new()
	get_root().add_child(level)
	var crate := PropFactoryScript.make_crate()
	var barrel := PropFactoryScript.make_barrel()
	get_root().add_child(crate)
	get_root().add_child(barrel)
	await process_frame

	_check(player.get_node_or_null("HeroVisual") != null,
		"Sandbox player mounts an imported hero visual instead of a capsule")
	var accent := player.get_node_or_null("HeroVisual/ProfileAccent") as MeshInstance3D
	var accent_material := accent.material_override as StandardMaterial3D if accent != null else null
	_check(accent_material != null and accent_material.albedo_color.is_equal_approx(player.profile.colour),
		"Imported hero retains the player's visible profile-colour accent")
	_check(level.get_node_or_null("VillageLand") != null,
		"Sandbox level mounts the authored countryside root")
	_check(level.get_node_or_null("VillageLand/TexturedMeadow") != null,
		"Sandbox level uses a textured meadow instead of a colored ground box")
	_check(level.get_node_or_null("VillageLand/VillageHouses") != null
		and level.get_node_or_null("VillageLand/VillageHouses").get_child_count() >= 3,
		"Sandbox level mounts a readable village with multiple houses")
	_check(level.get_node_or_null("VillageLand/Woodland") != null
		and level.get_node_or_null("VillageLand/Woodland").get_child_count() >= 12,
		"Sandbox level mounts an authored woodland around the clearing")
	_check(level.get_node_or_null("VillageLand/FriendlyNPCs") != null
		and level.get_node_or_null("VillageLand/FriendlyNPCs").get_child_count() >= 3,
		"Sandbox level mounts friendly village NPCs")
	var cottage := level.get_node_or_null("VillageLand/VillageHouses/WillowCottage")
	_check(cottage != null and _has_textured_or_fallback_material(cottage),
		"Village house preserves its imported texture atlas")
	var tree := level.get_node_or_null("VillageLand/Woodland/Tree00")
	_check(tree != null and _has_textured_or_fallback_material(tree),
		"Untextured woodland asset receives a readable fallback material")
	var mixed_root := Node3D.new()
	var mixed_mesh := _mixed_material_mesh()
	mixed_root.add_child(mixed_mesh)
	level._apply_village_materials(mixed_root, Color("#75452e"))
	_check(mixed_mesh.material_override == null,
		"Mixed-surface asset preserves its authored textured surface")
	_check(level.get_node_or_null("VillageLand/StarterClearing") != null,
		"Sandbox level provides an authored starter clearing")
	var clearing := level.get_node_or_null("VillageLand/StarterClearing")
	_check(clearing != null and clearing.get_node_or_null("ClearingTreeWest") != null
		and clearing.get_node_or_null("ClearingTreeEast") != null
		and clearing.get_node_or_null("ClearingTreeNorthWest") != null
		and clearing.get_node_or_null("ClearingTreeNorthEast") != null,
		"Starter clearing has a readable woodland frame around the camp")
	_check(level.get_node_or_null("VillageLand/MeadowPath") != null,
		"Sandbox level provides a visible path through the clearing")
	var starter_props := level.get_node_or_null("VillageLand/StarterProps")
	_check(starter_props != null and starter_props.get_child_count() >= 4,
		"Sandbox level groups bounded starter props near the village")
	_check(crate.get_node_or_null("PropVisual") != null,
		"Sandbox crate mounts a ready asset-pack visual")
	_check(barrel.get_node_or_null("PropVisual") != null,
		"Sandbox barrel mounts a ready asset-pack visual")
	_check(crate.get_node_or_null("GrabComponent") != null
		and barrel.get_node_or_null("InteractableComponent") != null,
		"Ready asset-pack props retain the proven sandbox interaction components")

	var gym := level.get_node_or_null("VillageLand/VillageGym")
	_check(gym != null, "Sandbox level mounts the village gym")
	var stations := gym.find_children("TrainArea_*", "Area3D", true, false) if gym != null else []
	_check(stations.size() == 5, "Village gym exposes five training stations")
	var wired := 0
	for station in stations:
		var comp := Components.get_comp(station, Components.INTERACTABLE) as InteractableComponent
		if comp != null and (station as Area3D).collision_layer == Layers.INTERACT_TRIGGER:
			wired += 1
	_check(wired == 5, "All gym stations are sandbox-interactable on the trigger layer")
	if not stations.is_empty():
		var station := stations[0] as Area3D
		var comp := Components.get_comp(station, Components.INTERACTABLE) as InteractableComponent
		comp.do_interact(0)
		_check(station.get_node_or_null("ProgressLabel") != null,
			"Interacting with a gym station trains and shows progress")
	var homestead := level.get_node_or_null("VillageLand/HomesteadEdge")
	_check(homestead != null and not homestead.get_children().is_empty(),
		"Sandbox level mounts a homestead edge with at least one compound")
	var npc_visuals := get_nodes_in_group("npc_visual") if homestead != null else []
	_check(not npc_visuals.is_empty(), "Homestead NPCs mount visible character meshes")
	var pond := level.get_node_or_null("VillageLand/VillagePond")
	var pond_water := pond.get_node_or_null("PondWater") as MeshInstance3D if pond != null else null
	_check(pond_water != null and pond_water.get_active_material(0) is ShaderMaterial,
		"Village pond uses the adventure water shader")
	var pond_volume := pond.get_node_or_null("PondWaterVolume") as Area3D if pond != null else null
	_check(pond_volume != null and pond_volume.is_in_group("water_volume")
		and pond_volume.collision_layer == 0
		and pond.find_children("*", "StaticBody3D", true, false).is_empty(),
		"Pond water is detection-only and never solid")

	player.queue_free()
	level.queue_free()
	crate.queue_free()
	barrel.queue_free()
	quit(1 if _failed else 0)
