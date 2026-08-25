extends Node3D
## Spike stress level: shared-world proof + physics load.
## Builds everything in code so the spike has no authored .tscn dependencies.

@export var box_count: int = 200
@export var arena_half_extent: float = 22.0

const _SEED := 20260810


func _ready() -> void:
	_build_environment()
	_build_ground()
	_build_stress_boxes()


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

	# Stylized look pass: AgX tonemap + generous glow + SSAO + soft fog.
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.05
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 1.1
	env.ssao_enabled = true
	env.ssao_intensity = 1.6
	env.ssao_radius = 1.2
	env.fog_enabled = true
	env.fog_light_color = Color("#bfe3ff")
	env.fog_density = 0.008
	env.fog_sky_affect = 0.0

	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-48, -35, 0)
	sun.light_energy = 1.5
	sun.light_color = Color("#fff3d6")
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	add_child(sun)


func _build_ground() -> void:
	var ground := StaticBody3D.new()
	ground.name = "Ground"
	ground.collision_layer = Layers.WORLD_STATIC
	ground.collision_mask = 0

	var size := Vector3(arena_half_extent * 2.0, 1.0, arena_half_extent * 2.0)

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

	# Low walls so the boxes stay on screen.
	for i in 4:
		var wall := StaticBody3D.new()
		wall.collision_layer = Layers.WORLD_STATIC
		wall.collision_mask = 0
		var angle := TAU * float(i) / 4.0
		var dir := Vector3(cos(angle), 0, sin(angle))
		var wsize := Vector3(arena_half_extent * 2.0, 3.0, 1.0)
		var wcol := CollisionShape3D.new()
		var wbox := BoxShape3D.new()
		wbox.size = wsize
		wcol.shape = wbox
		wall.add_child(wcol)
		wall.position = dir * arena_half_extent
		wall.rotation.y = -angle
		add_child(wall)


func _build_stress_boxes() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _SEED
	var palette := [
		Color("#ff8a5c"), Color("#5cc8ff"), Color("#b6ff5c"),
		Color("#ffd95c"), Color("#e05cff"),
	]
	var holder := Node3D.new()
	holder.name = "StressBoxes"
	add_child(holder)

	for i in box_count:
		var body := RigidBody3D.new()
		body.collision_layer = Layers.PROP_DYNAMIC
		body.collision_mask = Layers.SOLID_WORLD | Layers.PROP_DYNAMIC | Layers.PLAYER_BODY
		body.mass = 2.0
		body.can_sleep = true

		var s := rng.randf_range(0.5, 1.1)
		var shape := CollisionShape3D.new()
		var bshape := BoxShape3D.new()
		bshape.size = Vector3(s, s, s)
		shape.shape = bshape
		body.add_child(shape)

		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(s, s, s)
		mi.mesh = bm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = palette[i % palette.size()]
		mat.roughness = 0.55
		mi.material_override = mat
		body.add_child(mi)

		body.position = Vector3(
			rng.randf_range(-12.0, 12.0),
			1.0 + float(i) * 0.22,
			rng.randf_range(-12.0, 12.0))
		body.rotation = Vector3(
			rng.randf_range(0, TAU), rng.randf_range(0, TAU), rng.randf_range(0, TAU))
		holder.add_child(body)
