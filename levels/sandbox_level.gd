extends Node3D
## Sandbox demo level. Builds environment, registers the block palette, and
## spawns fully-componented props.
##
## Everything here is procedural so the kit is runnable and verifiable before a
## single asset is imported. Swap the factories for authored .tscn files and
## nothing else in the project changes.

@export var crate_count: int = 40
@export var style: StyleGuide

const _SEED := 20260810
const MEADOW_ALBEDO: Texture2D = preload("res://data/textures/generated/forest-meadow-ground-v1.png")
const MEADOW_NORMAL: Texture2D = preload("res://data/textures/pbr/ground003/Ground003_1K-JPG_NormalGL.jpg")
const MEADOW_ROUGHNESS: Texture2D = preload("res://data/textures/pbr/ground003/Ground003_1K-JPG_Roughness.jpg")
const FOREST_CANOPY_ALBEDO: Texture2D = preload("res://data/textures/generated/forest-canopy-stylized-v2.png")
const VILLAGE := "res://data/models/quaternius/medieval_village/"
const NATURE := "res://data/models/quaternius/nature/"
const NATURE_KIT := "res://data/models/kenney/nature_kit/GLB/"
const SURVIVAL_KIT := "res://data/models/kenney/survival_kit/Models/GLB format/"
const GYM_SPAWNER_3D := preload("res://src/adapters/inbound/gameplay/gym_spawner_3d.gd")
const HOMESTEAD_SPAWNER_3D := preload("res://src/adapters/inbound/gameplay/homestead_spawner_3d.gd")
const AUTHORED_RENDERER := preload("res://src/adapters/inbound/gameplay/world_renderer.gd")
const SANDBOX_COMPANION := preload("res://src/adapters/inbound/gameplay/sandbox_companion.gd")
const ADVENTURE_WATER_SHADER: Shader = preload("res://src/adapters/inbound/gameplay/shaders/adventure_water.gdshader")
const WATER_DUDV: Texture2D = preload("res://data/textures/water/simplewater_dudv.png")
const NPC_MODELS := [
	"res://data/models/kenney/toon_characters/Models/GLB format/character-female-a.glb",
	"res://data/models/kenney/toon_characters/Models/GLB format/character-male-c.glb",
	"res://data/models/kenney/toon_characters/Models/GLB format/character-female-c.glb",
]
const VILLAGE_PLASTER := Color("#d7b98a")
const VILLAGE_WOOD := Color("#79502f")
const VILLAGE_ROOF := Color("#9d4e3c")
const VILLAGE_FOLIAGE := Color("#4f7f38")
const VILLAGE_STONE := Color("#83776a")


func _ready() -> void:
	if style == null:
		style = StyleGuide.new()
	_build_environment()
	_build_ground()
	var village_land := _build_village_land()
	_build_village_gym(village_land)
	_build_homestead_edge(village_land)
	_build_pond(village_land)
	_register_palette()
	_wire_systems()


func _wire_systems() -> void:
	# Both of these MUST be handed this level, not the main window. In
	# split-screen the gameplay World3D is not the window's world, so anything
	# that spawns nodes (FX) or queries space (Build) needs the right root.
	if FXPool.instance:
		FXPool.instance.set_host(self)
	if BuildSystem.instance:
		BuildSystem.instance.set_world_root(self)


func _build_environment() -> void:
	WorldRenderer.apply_sandbox_environment(self)


func _build_ground() -> void:
	var half := 58.0
	var ground := StaticBody3D.new()
	ground.name = "Ground"
	ground.collision_layer = Layers.WORLD_STATIC
	ground.collision_mask = 0

	var size := Vector3(half * 2.0, 1.0, half * 2.0)
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	col.shape = box
	col.position = Vector3(0, -0.5, 0)
	ground.add_child(col)

	var mi := MeshInstance3D.new()
	mi.name = "TexturedMeadow"
	var bm := PlaneMesh.new()
	bm.size = Vector2(size.x, size.z)
	bm.subdivide_width = 24
	bm.subdivide_depth = 24
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = MEADOW_ALBEDO
	mat.normal_enabled = true
	mat.normal_texture = MEADOW_NORMAL
	mat.roughness_texture = MEADOW_ROUGHNESS
	mat.roughness = 0.9
	# Repeat the ground detail at a play-scale frequency; the former broad
	# tiling read as a single flat green surface from the opening camera.
	mat.uv1_scale = Vector3(18.0, 18.0, 1.0)
	mi.material_override = mat
	ground.add_child(mi)
	add_child(ground)

	for i in 4:
		var wall := StaticBody3D.new()
		wall.collision_layer = Layers.WORLD_STATIC
		wall.collision_mask = 0
		var angle := TAU * float(i) / 4.0
		var dir := Vector3(cos(angle), 0, sin(angle))
		var wcol := CollisionShape3D.new()
		var wbox := BoxShape3D.new()
		wbox.size = Vector3(1.0, 4.0, half * 2.0)
		wcol.shape = wbox
		wall.add_child(wcol)
		wall.position = dir * half
		wall.rotation.y = -angle
		add_child(wall)


## A compact Choyce countryside: real imported houses and trees compose the
## Kit's shared World3D without changing its build, grab, or persistence APIs.
func _build_village_land() -> Node3D:
	# Reuse the Adventure renderer's authored opening instead of rebuilding raw
	# wall panels and unshaded prop fragments here. Sandbox-specific systems still
	# add their own interaction nodes below this shared presentation root.
	var land: Node3D = AUTHORED_RENDERER.new()
	land.name = "AuthoredVillagePresentation"
	add_child(land)
	var meadow := get_node_or_null("Ground/TexturedMeadow") as MeshInstance3D
	if meadow != null:
		meadow.reparent(land)
	land.build_sandbox_opening()
	_build_opening_slice_content(land)
	_build_navigation_slice()

	var npcs := Node3D.new()
	npcs.name = "FriendlyNPCs"
	land.add_child(npcs)
	_build_friendly_npc(npcs, "Hania", Vector3(-2.4, 0.0, -27.0), 0)
	_build_friendly_npc(npcs, "Bartek", Vector3(3.6, 0.0, -31.5), 1)
	_build_friendly_npc(npcs, "Lena", Vector3(15.0, 0.0, -29.0), 2)
	return land


func _build_opening_slice_content(land: Node3D) -> void:
	# Keep the first resource actions inside the authored opening instead of
	# sending the player hundreds of metres into the Adventure world.
	var wood: Node3D = land.add_sandbox_visual_asset("OpeningSliceWoodVisual",
		Vector3(2.0, 0.0, -19.0), Vector3.ONE * 1.35, 0.25,
		"res://data/models/quaternius/nature/WoodLog_Moss.fbx", true,
		Vector3(1.8, 0.9, 1.2))
	var wood_anchor: Area3D = land.add_sandbox_interaction_anchor("OpeningSliceWood",
		Vector3(2.0, 0.35, -19.0), "E  Zbierz drewno", "gather_wood")
	wood_anchor.set_meta("resource_item_id", "wood_oak")
	wood_anchor.set_meta("resource_action", "gather_wood")
	wood_anchor.set_meta("resource_visual", wood)
	wood_anchor.set_meta("slice_role", "wood")
	for index in range(2):
		var wood_position := Vector3(3.5 + float(index), 0.0, -18.0)
		var extra_wood: Node3D = land.add_sandbox_visual_asset("OpeningSliceWoodVisual%d" % index,
			wood_position, Vector3.ONE * 1.1, -0.2, "res://data/models/quaternius/nature/WoodLog_Moss.fbx",
			true, Vector3(1.5, 0.8, 1.0))
		var extra_anchor: Area3D = land.add_sandbox_interaction_anchor("OpeningSliceWood%d" % index,
			wood_position + Vector3(0.0, 0.35, 0.0), "E  Zbierz drewno", "gather_wood")
		extra_anchor.set_meta("resource_item_id", "wood_oak")
		extra_anchor.set_meta("resource_action", "gather_wood")
		extra_anchor.set_meta("resource_visual", extra_wood)
		extra_anchor.set_meta("slice_role", "wood")

	var stone: Node3D = land.add_sandbox_visual_asset("OpeningSliceStoneVisual",
		Vector3(10.0, 0.0, -19.0), Vector3.ONE * 1.15, -0.2,
		"res://data/models/quaternius/nature/Rock_Moss_4.fbx", true,
		Vector3(1.4, 1.0, 1.4))
	var stone_anchor: Area3D = land.add_sandbox_interaction_anchor("OpeningSliceStone",
		Vector3(10.0, 0.35, -19.0), "E  Wydobądź kamień", "gather_stone")
	stone_anchor.set_meta("resource_item_id", "ore_iron")
	stone_anchor.set_meta("resource_action", "gather_stone")
	stone_anchor.set_meta("resource_visual", stone)
	stone_anchor.set_meta("slice_role", "stone")

	var repair_anchor: Area3D = land.add_sandbox_interaction_anchor("OpeningSliceHouseRepair",
		Vector3(6.0, 0.35, -27.0), "E  Napraw dom", "repair_house")
	repair_anchor.set_meta("slice_role", "repair")
	var reward_anchor: Area3D = land.add_sandbox_interaction_anchor("OpeningSliceReward",
		Vector3(6.0, 0.35, -31.0), "E  Odbierz nagrodę", "claim_reward")
	reward_anchor.set_meta("slice_role", "reward")


func _build_navigation_slice() -> void:
	# A small explicit navigation surface gives agents and future NPC motion a
	# stable contract without requiring Terrain3D baking for the first slice.
	var region := NavigationRegion3D.new()
	region.name = "OpeningSliceNavigationRegion"
	region.add_to_group("navigation_region")
	var mesh := NavigationMesh.new()
	mesh.vertices = PackedVector3Array([
		Vector3(-32.0, 0.02, -52.0), Vector3(32.0, 0.02, -52.0),
		Vector3(32.0, 0.02, 4.0), Vector3(-32.0, 0.02, 4.0),
	])
	mesh.add_polygon(PackedInt32Array([0, 1, 2, 3]))
	region.navigation_mesh = mesh
	add_child(region)


func _build_starter_clearing(land: Node3D) -> void:
	var clearing := Node3D.new()
	clearing.name = "StarterClearing"
	land.add_child(clearing)
	_add_imported_visual(clearing, "ClearingTreeWest", NATURE + "CommonTree_4.fbx",
		Vector3(-10.5, 0.0, -8.5), Vector3.ONE * 1.25, 0.25)
	_add_imported_visual(clearing, "ClearingTreeEast", NATURE + "BirchTree_1.fbx",
		Vector3(11.5, 0.0, -9.0), Vector3.ONE * 1.2, -0.3)
	_add_imported_visual(clearing, "ClearingTreeNorthWest", NATURE + "PineTree_1.fbx",
		Vector3(-17.0, 0.0, -15.0), Vector3.ONE * 1.3, 0.1)
	_add_imported_visual(clearing, "ClearingTreeNorthEast", NATURE + "CommonTree_1.fbx",
		Vector3(17.5, 0.0, -15.5), Vector3.ONE * 1.25, -0.25)
	_add_imported_visual(clearing, "ClearingTreeNearWest", NATURE + "CommonTree_1.fbx",
		Vector3(-8.0, 0.0, -4.5), Vector3.ONE * 1.1, 0.35)
	_add_imported_visual(clearing, "ClearingTreeNearEast", NATURE + "PineTree_1.fbx",
		Vector3(8.5, 0.0, -5.0), Vector3.ONE * 1.0, -0.2)

	var path := Node3D.new()
	path.name = "MeadowPath"
	land.add_child(path)
	for index in 6:
		_add_imported_visual(path, "PathTile%02d" % index, NATURE_KIT + "ground_pathStraight.glb",
			Vector3(0.0, 0.01, 5.5 - float(index) * 3.0), Vector3.ONE, 0.0)

	_add_imported_visual(clearing, "Campfire", SURVIVAL_KIT + "campfire-pit.glb",
		Vector3(0.0, 0.0, -3.3), Vector3.ONE * 2.0, 0.2)
	_add_imported_visual(clearing, "CampfireLogs", NATURE_KIT + "campfire_logs.glb",
		Vector3(0.0, 0.02, -3.3), Vector3.ONE * 1.55, 0.2)
	_add_campfire_flame(clearing, Vector3(0.0, 0.62, -3.3))
	_add_campfire_light(clearing, Vector3(0.0, 1.25, -3.3))
	_add_imported_visual(clearing, "FenceWest", NATURE_KIT + "fence_simple.glb",
		Vector3(-6.0, 0.0, -4.2), Vector3.ONE * 1.2, PI * 0.5)
	_add_imported_visual(clearing, "FenceEast", NATURE_KIT + "fence_simple.glb",
		Vector3(6.0, 0.0, -4.2), Vector3.ONE * 1.2, PI * 0.5)
	_add_imported_visual(clearing, "ClearingRock", NATURE_KIT + "rock_largeA.glb",
		Vector3(5.1, 0.0, 1.6), Vector3.ONE * 1.1, 0.4)
	_add_imported_visual(clearing, "ClearingBush", NATURE_KIT + "plant_bush.glb",
		Vector3(-5.4, 0.0, 1.0), Vector3.ONE * 1.25, 0.0)

	var props := Node3D.new()
	props.name = "StarterProps"
	land.add_child(props)
	_add_starter_prop(props, PropFactory.make_crate(), Vector3(-1.2, 0.7, -3.8), 0.3)
	_add_starter_prop(props, PropFactory.make_crate(0.72), Vector3(-0.3, 0.65, -3.5), -0.2)
	_add_starter_prop(props, PropFactory.make_barrel(), Vector3(1.2, 0.75, -3.6), 0.0)
	_add_starter_prop(props, PropFactory.make_barrel(), Vector3(2.1, 0.75, -3.3), 0.3)


func _add_starter_prop(parent: Node3D, prop: RigidBody3D, prop_position: Vector3, rotation_y: float) -> void:
	parent.add_child(prop)
	prop.position = prop_position
	prop.rotation.y = rotation_y


func _add_campfire_light(parent: Node3D, light_position: Vector3) -> void:
	var light := OmniLight3D.new()
	light.name = "CampfireLight"
	light.position = light_position
	light.light_color = Color("#ffb05a")
	light.light_energy = 3.0
	light.omni_range = 9.0
	light.shadow_enabled = true
	parent.add_child(light)


func _add_campfire_flame(parent: Node3D, flame_position: Vector3) -> void:
	var flame := MeshInstance3D.new()
	flame.name = "CampfireFlame"
	flame.position = flame_position
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.06
	mesh.bottom_radius = 0.32
	mesh.height = 1.25
	mesh.radial_segments = 6
	flame.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("#ff8a2a")
	material.emission_enabled = true
	material.emission = Color("#ff6b1a")
	material.emission_energy_multiplier = 2.5
	flame.material_override = material
	parent.add_child(flame)


func _build_house(parent: Node3D, house_name: String, center: Vector3, rotation_y: float) -> void:
	var house := Node3D.new()
	house.name = house_name
	house.position = center
	house.rotation.y = rotation_y
	parent.add_child(house)
	for bay in range(-1, 2):
		var wall_path := VILLAGE + ("Wall_Plaster_Door_Flat.gltf" if bay == 0 else "Wall_Plaster_Window_Wide_Flat.gltf")
		_add_imported_visual(house, "FrontWall%d" % bay, wall_path, Vector3(float(bay) * 2.0, 0, 2.0), Vector3.ONE, 0.0)
		_add_imported_visual(house, "BackWall%d" % bay, VILLAGE + "Wall_Plaster_Straight.gltf", Vector3(float(bay) * 2.0, 0, -2.0), Vector3.ONE, PI)
	_add_imported_visual(house, "Roof", VILLAGE + "Roof_RoundTiles_6x8.gltf", Vector3(0, 3.1, 0), Vector3(0.82, 0.72, 0.72), 0.0)
	_add_imported_visual(house, "Chimney", VILLAGE + "Prop_Chimney.gltf", Vector3(1.6, 4.25, 0.2), Vector3.ONE, 0.0)
	var collision := StaticBody3D.new()
	collision.name = "HouseCollision"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(6.0, 3.2, 4.0)
	shape.shape = box
	shape.position.y = 1.6
	collision.add_child(shape)
	house.add_child(collision)


func _build_friendly_npc(parent: Node3D, npc_name: String, npc_position: Vector3, model_index: int) -> void:
	var npc := SANDBOX_COMPANION.new()
	npc.name = npc_name
	npc.position = npc_position
	npc.collision_layer = Layers.NPC_BODY
	npc.target_position = Vector3(6.0, 0.0, -23.0)
	parent.add_child(npc)
	var character_visual := _add_imported_visual(npc, "CharacterVisual", NPC_MODELS[model_index],
		Vector3(0, -0.1, 0), Vector3.ONE * 0.92, PI)
	_start_imported_idle_animation(character_visual)
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.28
	capsule.height = 1.25
	collision.shape = capsule
	collision.position.y = 0.62
	npc.add_child(collision)
	var interaction := InteractableComponent.new()
	interaction.name = "InteractableComponent"
	interaction.prompt_text = "Porozmawiaj z %s" % npc_name
	interaction.interaction_range = 2.8
	npc.add_child(interaction)
	var label := Label3D.new()
	label.name = "NameLabel"
	label.text = npc_name
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position.y = 1.9
	label.pixel_size = 0.004
	label.outline_size = 4
	npc.add_child(label)
	var navigation_agent := NavigationAgent3D.new()
	navigation_agent.name = "GuideNavigationAgent"
	navigation_agent.add_to_group("navigation_agent")
	navigation_agent.path_height_offset = 0.0
	navigation_agent.target_position = npc.target_position
	npc.add_child(navigation_agent)
	npc.navigation_agent = navigation_agent


func _start_imported_idle_animation(root: Node3D) -> void:
	if root == null:
		return
	var animator := root.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if animator == null:
		return
	for animation_name in ["idle", "Idle", "static"]:
		if not animator.has_animation(animation_name):
			continue
		var animation := animator.get_animation(animation_name)
		animation.loop_mode = Animation.LOOP_LINEAR
		animator.play(animation_name)
		return


## --- Village gym: real GLB equipment, trained through sandbox components ----
##
## GymSpawner3D builds the compound (rubber floor, 5 stations, collision). Its
## native trigger contract (Area3D + metadata) targets the Adventure runtime's
## E-key loop, which does not exist in the sandbox — so each station here gets
## an InteractableComponent on the INTERACT_TRIGGER layer instead, and the
## InteractionSystem raycast drives GymSpawner3D.perform_workout directly.
## Progression lands in the shared TrainingStats handed over by
## GameplayRuntime._start_sandbox_kit_session (setup() DI).

var _gym_spawner: Node3D = null

func _build_village_gym(land: Node3D) -> void:
	var gym: Node3D = GYM_SPAWNER_3D.new()
	gym.name = "VillageGym"
	land.add_child(gym)
	# Keep the training compound in the west meadow so the authored house and
	# bridge remain the opening focal point.
	gym.spawn_gym(Vector3(-34.0, 0.0, -26.0))
	_gym_spawner = gym
	for area in gym.find_children("TrainArea_*", "Area3D", true, false):
		_wire_gym_station(area as Area3D)


func _wire_gym_station(area: Area3D) -> void:
	# InteractionSystem raycasts include INTERACT_TRIGGER areas; the station's
	# default layer-1 area would be invisible to it. Trigger-only, no mask.
	area.collision_layer = Layers.INTERACT_TRIGGER
	area.collision_mask = 0
	# The sphere inherits the gym pack's 0.45 scale (2.0 -> 0.9m world): widen it
	# so a child's aim ray lands reliably while standing at the machine.
	for shape_node in area.find_children("*", "CollisionShape3D", true, false):
		var sphere := (shape_node as CollisionShape3D).shape as SphereShape3D
		if sphere != null:
			sphere.radius = 3.2
	var interaction := InteractableComponent.new()
	interaction.name = "InteractableComponent"
	interaction.prompt_text = String(area.get_meta("prompt_text", "Trenuj"))
	interaction.interaction_range = 3.5
	area.add_child(interaction)
	interaction.interacted.connect(_on_gym_station_interacted.bind(area))


func _on_gym_station_interacted(_player_id: int, area: Area3D) -> void:
	if _gym_spawner == null or not is_instance_valid(area):
		return
	var type_name := String(area.get_meta("training_type_name", "STRENGTH"))
	var result: Dictionary = _gym_spawner.perform_workout(type_name)
	if not bool(result.get("success", false)):
		return
	# Per-station progress label above the machine. Lives inside the scaled gym
	# pack like the spawner's own name labels.
	var label := area.get_node_or_null("ProgressLabel") as Label3D
	if label == null:
		label = Label3D.new()
		label.name = "ProgressLabel"
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.position = Vector3(0, 2.6, 0)
		label.font_size = 24
		label.outline_size = 4
		label.outline_modulate = Color(0, 0, 0, 0.85)
		area.add_child(label)
	var percent := int(roundf(float(result.get("progress", 0.0)) * 100.0))
	label.text = "%d%% · Poziom %d" % [percent, int(result.get("level", 0))]
	if bool(result.get("leveled_up", false)):
		label.modulate = Color("#ffd94d")
	else:
		label.modulate = Color.WHITE


## --- Homestead edge: one authored compound, kid-safe villager + animals -----

func _build_homestead_edge(land: Node3D) -> void:
	var spawner: Node3D = HOMESTEAD_SPAWNER_3D.new()
	spawner.name = "HomesteadEdge"
	land.add_child(spawner)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260901
	# South-east corner, clear of the village houses and the clearing.
	spawner.spawn_random_homestead(Vector3(36.0, 0.0, 34.0), 0, rng)
	# The placement service scatters follow-up compounds 12-40m out — on a
	# 116m meadow that can land outside the walls, so keep a second compound
	# only when it stays inside the playable square and off existing content.
	var second: Node3D = spawner.spawn_random_homestead(Vector3(36.0, 0.0, 34.0), 6, rng)
	if second != null and not _compound_fits_meadow(second):
		second.queue_free()
		var specs: Array = spawner.get_spawned_specs()
		if not specs.is_empty():
			specs.pop_back()


func _compound_fits_meadow(compound: Node3D) -> bool:
	var p := compound.global_position
	if absf(p.x) > 48.0 or absf(p.z) > 48.0:
		return false
	# Keep compounds off the clearing (origin), gym (north) and pond (west).
	for reserved in [Vector2(0, -4), Vector2(0, -38), Vector2(-32, 20)]:
		if Vector2(p.x, p.z).distance_to(reserved) < 14.0:
			return false
	return true


## --- Village pond: shader water, visual only (no swim physics in the kit) ---
##
## Reuses the Adventure water shader on a flat subdivided plane — the meadow
## has no Terrain3D, so the river's terrain-conforming ribbon would be wasted
## here. The Area3D volume is detection-only (layer 0): solid water collision
## is what turned the Adventure river into a walkable floor once before.

func _build_pond(land: Node3D) -> void:
	var pond := Node3D.new()
	pond.name = "VillagePond"
	pond.position = Vector3(-32.0, 0.0, 20.0)
	land.add_child(pond)

	var water := MeshInstance3D.new()
	water.name = "PondWater"
	var plane := PlaneMesh.new()
	plane.size = Vector2(14.0, 9.0)
	plane.subdivide_width = 28
	plane.subdivide_depth = 18
	water.mesh = plane
	water.position.y = 0.06
	var material := ShaderMaterial.new()
	material.shader = ADVENTURE_WATER_SHADER
	material.set_shader_parameter("dudv_map", WATER_DUDV)
	water.material_override = material
	pond.add_child(water)

	var volume := Area3D.new()
	volume.name = "PondWaterVolume"
	volume.add_to_group("water_volume")
	volume.collision_layer = 0
	volume.collision_mask = Layers.PLAYER_BODY
	volume.monitoring = true
	var volume_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(13.0, 1.2, 8.0)
	volume_shape.shape = box
	volume_shape.position = Vector3(0, -0.3, 0)
	volume.add_child(volume_shape)
	pond.add_child(volume)

	_add_imported_visual(pond, "PondRockA", NATURE_KIT + "rock_largeA.glb",
		Vector3(-7.6, 0.0, 1.5), Vector3.ONE * 0.9, 0.7)
	_add_imported_visual(pond, "PondRockB", NATURE_KIT + "rock_smallB.glb",
		Vector3(6.8, 0.0, -4.2), Vector3.ONE * 1.1, -0.4)
	_add_imported_visual(pond, "PondBush", NATURE_KIT + "plant_bush.glb",
		Vector3(7.3, 0.0, 3.6), Vector3.ONE * 1.3, 0.0)


func _add_imported_visual(parent: Node3D, node_name: String, path: String, visual_position: Vector3,
		visual_scale: Vector3, rotation_y: float) -> Node3D:
	var scene := load(path) as PackedScene
	if scene == null:
		push_warning("SandboxLevel: missing authored visual %s" % path)
		return null
	var visual := scene.instantiate() as Node3D
	if visual == null:
		return null
	visual.name = node_name
	visual.position = visual_position
	visual.scale = visual_scale
	visual.rotation.y = rotation_y
	parent.add_child(visual)
	_apply_village_materials(visual, _fallback_colour_for_visual(node_name))
	if node_name.to_lower().contains("tree") or node_name.to_lower().contains("grove"):
		_apply_tree_texture_fallback(visual)
	return visual


func _apply_tree_texture_fallback(root: Node) -> void:
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		var material := mesh.material_override as StandardMaterial3D
		if material == null or material.albedo_texture != null:
			continue
		material.albedo_texture = FOREST_CANOPY_ALBEDO
		material.uv1_scale = Vector3(2.5, 2.5, 2.5)


func _apply_village_materials(root: Node, fallback: Color) -> void:
	if root is MeshInstance3D:
		_apply_village_material_to_mesh(root as MeshInstance3D, fallback)
	for node in root.find_children("*", "MeshInstance3D", true, false):
		_apply_village_material_to_mesh(node as MeshInstance3D, fallback)


func _apply_village_material_to_mesh(mesh: MeshInstance3D, fallback: Color) -> void:
	var source_mesh := mesh.mesh
	if source_mesh == null:
		return
	var has_textured_surface := false
	var missing_surface_indices: Array[int] = []
	for surface_index in source_mesh.get_surface_count():
		var source := mesh.get_active_material(surface_index) as StandardMaterial3D
		if source != null and source.albedo_texture != null:
			has_textured_surface = true
		elif source == null:
			missing_surface_indices.append(surface_index)
	# Preserve authored textured surfaces, but never leave an imported material slot
	# null: Forward+ and the dummy renderer both query every surface during capture.
	if not missing_surface_indices.is_empty():
		for surface_index in missing_surface_indices:
			var rescue := StandardMaterial3D.new()
			rescue.albedo_color = fallback
			rescue.roughness = 0.78
			mesh.set_surface_override_material(surface_index, rescue)
	if has_textured_surface:
		return
	var material := StandardMaterial3D.new()
	material.albedo_color = fallback
	material.roughness = 0.78
	mesh.material_override = material


func _fallback_colour_for_visual(node_name: String) -> Color:
	var key := node_name.to_lower()
	if key.contains("campfire"):
		return Color("#d06a36")
	if key.contains("roof"):
		return VILLAGE_ROOF
	if key.contains("chimney") or key.contains("rock") or key.contains("stone"):
		return VILLAGE_STONE
	if key.contains("tree") or key.contains("grass") or key.contains("bush"):
		return VILLAGE_FOLIAGE
	if key.contains("wall") or key.contains("house") or key.contains("cottage"):
		return VILLAGE_PLASTER
	return VILLAGE_WOOD


func _register_palette() -> void:
	var build := BuildSystem.instance
	if build == null:
		return
	for scene in BlockFactory.default_palette():
		build.register_block(scene)


func _spawn_props() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _SEED
	var holder := Node3D.new()
	holder.name = "Props"
	add_child(holder)

	var palette := [
		Color("#d8a05a"), Color("#c1524a"), Color("#5cc8ff"),
		Color("#b6ff5c"), Color("#e0b0ff"),
	]

	for i in crate_count:
		var prop: RigidBody3D
		if i % 5 == 0:
			prop = PropFactory.make_barrel(palette[i % palette.size()])
		else:
			prop = PropFactory.make_crate(
				rng.randf_range(0.6, 1.0), palette[i % palette.size()])
		holder.add_child(prop)
		prop.global_position = Vector3(
			rng.randf_range(-14.0, 14.0), 1.2 + float(i) * 0.15, rng.randf_range(-14.0, 14.0))
		prop.rotation.y = rng.randf_range(0.0, TAU)


## Places a few blocks through the real BuildSystem API so the build path,
## chunking and cold bake are exercised from frame one rather than only when a
## human happens to press the button.
func _seed_starter_structure() -> void:
	var build := BuildSystem.instance
	if build == null or build.palette.is_empty():
		return
	var id := build.palette[1] if build.palette.size() > 1 else build.palette[0]
	for x in 5:
		for y in 3:
			var pos := Vector3(-8.0 + float(x), 0.5 + float(y), -10.0)
			build.place(id, Transform3D(Basis.IDENTITY, pos), -1, Color.WHITE, false)
