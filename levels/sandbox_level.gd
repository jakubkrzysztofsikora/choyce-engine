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
const MEADOW_ALBEDO: Texture2D = preload("res://data/textures/pbr/ground003/Ground003_1K-JPG_Color.jpg")
const MEADOW_NORMAL: Texture2D = preload("res://data/textures/pbr/ground003/Ground003_1K-JPG_NormalGL.jpg")
const MEADOW_ROUGHNESS: Texture2D = preload("res://data/textures/pbr/ground003/Ground003_1K-JPG_Roughness.jpg")
const VILLAGE := "res://data/models/quaternius/medieval_village/"
const NATURE := "res://data/models/quaternius/nature/"
const NATURE_KIT := "res://data/models/kenney/nature_kit/GLB/"
const SURVIVAL_KIT := "res://data/models/kenney/survival_kit/Models/GLB format/"
const GYM_SPAWNER_3D := preload("res://src/adapters/inbound/gameplay/gym_spawner_3d.gd")
const HOMESTEAD_SPAWNER_3D := preload("res://src/adapters/inbound/gameplay/homestead_spawner_3d.gd")
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
	_build_starter_clearing(village_land)
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
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var proc := ProceduralSkyMaterial.new()
	proc.sky_top_color = Color("#3fa9ff")
	proc.sky_horizon_color = Color("#cfeaff")
	proc.ground_bottom_color = Color("#4a7a3f")
	proc.ground_horizon_color = Color("#cfeaff")
	sky.sky_material = proc
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 1.0

	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.05
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 1.1
	env.ssao_enabled = true
	env.ssao_intensity = 1.6
	env.fog_enabled = true
	env.fog_light_color = Color("#bfe3ff")
	env.fog_density = 0.006
	env.fog_sky_affect = 0.0

	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-48, -35, 0)
	sun.light_energy = 1.5
	sun.light_color = Color("#fff3d6")
	sun.shadow_enabled = true
	# Cascade count is the highest-leverage split-screen knob (Spike A: 4 views
	# produced 10.8x the primitives at identical total pixels). GraphicsProfile
	# drives this at runtime; the value here is only the 1-player default.
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 120.0
	add_child(sun)


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
		wbox.size = Vector3(half * 2.0, 4.0, 1.0)
		wcol.shape = wbox
		wall.add_child(wcol)
		wall.position = dir * half
		wall.rotation.y = -angle
		add_child(wall)


## A compact Choyce countryside: real imported houses and trees compose the
## Kit's shared World3D without changing its build, grab, or persistence APIs.
func _build_village_land() -> Node3D:
	var land := Node3D.new()
	land.name = "VillageLand"
	add_child(land)
	var meadow := get_node_or_null("Ground/TexturedMeadow") as MeshInstance3D
	if meadow != null:
		meadow.reparent(land)

	var houses := Node3D.new()
	houses.name = "VillageHouses"
	land.add_child(houses)
	_build_house(houses, "WillowCottage", Vector3(-13.0, 0.0, -16.0), 0.0)
	_build_house(houses, "MarketHouse", Vector3(14.0, 0.0, -19.0), PI)
	_build_house(houses, "HillCottage", Vector3(24.0, 0.0, 11.0), -PI * 0.5)

	var woodland := Node3D.new()
	woodland.name = "Woodland"
	land.add_child(woodland)
	var trees := ["CommonTree_4.fbx", "CommonTree_1.fbx", "BirchTree_1.fbx", "PineTree_1.fbx"]
	var tree_positions := [
		Vector3(-42, 0, -38), Vector3(-33, 0, -29), Vector3(-46, 0, -12),
		Vector3(-38, 0, 15), Vector3(-48, 0, 31), Vector3(-25, 0, 36),
		Vector3(38, 0, -37), Vector3(47, 0, -25), Vector3(40, 0, -8),
		Vector3(46, 0, 14), Vector3(37, 0, 30), Vector3(18, 0, 39),
		Vector3(-5, 0, 43), Vector3(-18, 0, 34), Vector3(30, 0, -31),
	]
	for index in tree_positions.size():
		_add_imported_visual(woodland, "Tree%02d" % index, NATURE + trees[index % trees.size()],
			tree_positions[index], Vector3.ONE, float(index % 4) * 0.7)

	var npcs := Node3D.new()
	npcs.name = "FriendlyNPCs"
	land.add_child(npcs)
	_build_friendly_npc(npcs, "Hania", Vector3(-3.4, 0.0, -4.7), 0)
	_build_friendly_npc(npcs, "Bartek", Vector3(3.3, 0.0, -4.9), 1)
	_build_friendly_npc(npcs, "Lena", Vector3(5.8, 0.0, -3.4), 2)
	return land


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
	var npc := StaticBody3D.new()
	npc.name = npc_name
	npc.position = npc_position
	npc.collision_layer = Layers.NPC_BODY
	parent.add_child(npc)
	_add_imported_visual(npc, "CharacterVisual", NPC_MODELS[model_index], Vector3(0, -0.1, 0), Vector3.ONE * 0.92, PI)
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
	# North edge of the meadow: clear of the houses, path and clearing.
	gym.spawn_gym(Vector3(0.0, 0.0, -38.0))
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
	return visual


func _apply_village_materials(root: Node, fallback: Color) -> void:
	if root is MeshInstance3D:
		_apply_village_material_to_mesh(root as MeshInstance3D, fallback)
	for node in root.find_children("*", "MeshInstance3D", true, false):
		_apply_village_material_to_mesh(node as MeshInstance3D, fallback)


func _apply_village_material_to_mesh(mesh: MeshInstance3D, fallback: Color) -> void:
	var source_mesh := mesh.mesh
	if source_mesh != null:
		for surface_index in source_mesh.get_surface_count():
			var source := mesh.get_active_material(surface_index) as StandardMaterial3D
			if source != null and source.albedo_texture != null:
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
