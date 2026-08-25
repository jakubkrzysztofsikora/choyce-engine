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


func _ready() -> void:
	if style == null:
		style = StyleGuide.new()
	_build_environment()
	_build_ground()
	_register_palette()
	_spawn_props()
	_wire_systems()
	_seed_starter_structure()


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
	var half := 26.0
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
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = Vector3(0, -0.5, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("#7fb35e")
	mat.roughness = 0.95
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
