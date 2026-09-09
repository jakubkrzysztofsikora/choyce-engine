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


func _has_authored_texture(root: Node) -> bool:
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		for surface_index in mesh.mesh.get_surface_count() if mesh.mesh != null else 0:
			var active := mesh.get_active_material(surface_index) as Material
			if active is StandardMaterial3D and (active as StandardMaterial3D).albedo_texture != null:
				return true
			if active is ShaderMaterial and (active as ShaderMaterial).get_shader_parameter("albedo_texture") is Texture2D:
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
	var flat_renderer: Node = load("res://src/adapters/inbound/gameplay/world_renderer.gd").new()
	get_root().add_child(flat_renderer)
	_check(flat_renderer.has_method("set_terrain_sampling_required"),
		"WorldRenderer exposes an explicit terrain requirement boundary for flat sandbox presentation")
	flat_renderer.set_terrain_sampling_required(false)
	var flat_position: Vector3 = flat_renderer.call("_terrain_grounded_position", Vector3(0.0, 2.0, 0.0))
	_check(is_equal_approx(flat_position.y, 2.0),
		"Flat sandbox presentation preserves authored Y without requiring Terrain3D")
	flat_renderer.queue_free()

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
	var hero_animator := player.get_node_or_null("HeroVisual/AnimationPlayer") as AnimationPlayer
	_check(hero_animator != null and hero_animator.has_animation("idle")
		and hero_animator.has_animation("walk"),
		"Sandbox hero uses an imported animated character rig")
	var hero_tree := player.get_node_or_null("HeroVisual/AnimationTree") as AnimationTree
	_check(hero_tree != null and hero_tree.active and hero_tree.tree_root is AnimationNodeStateMachine,
		"Sandbox hero uses an AnimationTree locomotion state machine")
	var hero_root := player.get_node_or_null("HeroVisual")
	var hero_mesh := hero_root.find_child("body-mesh", true, false) as MeshInstance3D if hero_root != null else null
	var hero_material := hero_mesh.get_active_material(0) as StandardMaterial3D if hero_mesh != null else null
	_check(hero_material != null and hero_material.albedo_texture != null,
		"Sandbox hero preserves its authored texture atlas")
	var authored := level.get_node_or_null("AuthoredVillagePresentation")
	_check(authored != null,
		"Sandbox level mounts the shared authored countryside renderer")
	var meadow := authored.get_node_or_null("TexturedMeadow") if authored != null else null
	_check(meadow != null,
		"Sandbox level uses a textured meadow instead of a colored ground box")
	var authored_meshes := authored.find_children("*", "MeshInstance3D", true, false) if authored != null else []
	_check(authored_meshes.size() >= 40,
		"Sandbox level mounts a substantial authored opening composition")
	var authored_trees := authored.find_children("opening_grove_tree_*", "StaticBody3D", true, false) if authored != null else []
	_check(authored_trees.size() >= 12,
		"Sandbox level mounts an authored woodland around the clearing")
	_check(level.get_node_or_null("AuthoredVillagePresentation/FriendlyNPCs") != null
		and level.get_node_or_null("AuthoredVillagePresentation/FriendlyNPCs").get_child_count() >= 3,
		"Sandbox level mounts friendly village NPCs")
	var camp := authored.get_node_or_null("OpeningBasecampTent") if authored != null else null
	_check(camp != null and _has_authored_texture(camp),
		"Authored opening shelter preserves an imported texture")
	var tree := authored.find_child("opening_grove_tree_0", true, false) if authored != null else null
	_check(tree != null and _has_authored_texture(tree),
		"Authored woodland asset preserves an imported texture")
	var mixed_root := Node3D.new()
	var mixed_mesh := _mixed_material_mesh()
	mixed_root.add_child(mixed_mesh)
	level._apply_village_materials(mixed_root, Color("#75452e"))
	_check(mixed_mesh.material_override == null,
		"Mixed-surface asset preserves its authored textured surface")
	# This probe owns an ArrayMesh plus two material resources outside the scene
	# tree; free it explicitly so the dummy renderer audit stays leak-free.
	mixed_root.free()
	_check(authored != null and authored.get_node_or_null("OpeningBasecampFire") != null,
		"Sandbox level provides an authored starter clearing")
	_check(authored != null and authored.find_child("OpeningTrailForestJoin", true, false) != null,
		"Starter clearing has a readable path through the opening")
	_check(authored != null and authored.find_child("SandboxArrivalTrail", true, false) != null,
		"Sandbox start connects to the authored courtyard with a near arrival trail")
	var foliage_clusters := authored.find_children("SandboxFoliageCluster_*", "MultiMeshInstance3D", true, false) if authored != null else []
	_check(foliage_clusters.size() >= 4,
		"Sandbox opening uses clustered MultiMesh foliage dressing")
	_check(authored != null and authored.get_node_or_null("OpeningBasecampChest") != null
		and authored.get_node_or_null("OpeningBasecampBarrel") != null,
		"Sandbox level groups bounded authored starter props near the village")
	_check(crate.get_node_or_null("PropVisual") != null,
		"Sandbox crate mounts a ready asset-pack visual")
	_check(barrel.get_node_or_null("PropVisual") != null,
		"Sandbox barrel mounts a ready asset-pack visual")
	_check(crate.get_node_or_null("GrabComponent") != null
		and barrel.get_node_or_null("InteractableComponent") != null,
		"Ready asset-pack props retain the proven sandbox interaction components")

	var gym := level.get_node_or_null("AuthoredVillagePresentation/VillageGym")
	_check(gym != null, "Sandbox level mounts the village gym")
	var stations: Array = gym.find_children("TrainArea_*", "Area3D", true, false) if gym != null else []
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
	var homestead := level.get_node_or_null("AuthoredVillagePresentation/HomesteadEdge")
	_check(homestead != null and not homestead.get_children().is_empty(),
		"Sandbox level mounts a homestead edge with at least one compound")
	var npc_visuals := get_nodes_in_group("npc_visual") if homestead != null else []
	_check(not npc_visuals.is_empty(), "Homestead NPCs mount visible character meshes")
	var animated_village_npcs := 0
	for npc in authored.get_node_or_null("FriendlyNPCs").get_children() if authored != null and authored.get_node_or_null("FriendlyNPCs") != null else []:
		var npc_animator := npc.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if npc_animator != null and npc_animator.is_playing():
			animated_village_npcs += 1
	_check(animated_village_npcs == 3,
		"All friendly village NPCs start their imported idle animation")
	var pond := level.get_node_or_null("AuthoredVillagePresentation/VillagePond")
	var pond_water := pond.get_node_or_null("PondWater") as MeshInstance3D if pond != null else null
	_check(pond_water != null and pond_water.get_active_material(0) is ShaderMaterial,
		"Village pond uses the adventure water shader")
	var pond_volume := pond.get_node_or_null("PondWaterVolume") as Area3D if pond != null else null
	_check(pond_volume != null and pond_volume.is_in_group("water_volume")
		and pond_volume.collision_layer == 0
		and pond.find_children("*", "StaticBody3D", true, false).is_empty(),
		"Pond water is detection-only and never solid")

	# This is a short-lived headless scene; free the large imported trees
	# synchronously so the dummy renderer can release their RIDs before exit.
	player.free()
	level.free()
	crate.free()
	barrel.free()
	await process_frame
	await process_frame
	quit(1 if _failed else 0)
