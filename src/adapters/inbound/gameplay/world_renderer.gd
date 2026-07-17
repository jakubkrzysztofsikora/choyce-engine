class_name WorldRenderer
extends Node3D

# Toon cel shader — applied to every MeshInstance3D rendered by this adapter
# (both glTF prop instances and primitive-mesh fallbacks).
const TOON_CEL_SHADER: Shader = preload("res://src/adapters/inbound/gameplay/shaders/toon_cel.gdshader")

var _spawn_points: Array[Vector3] = []

func render_world(world: World) -> void:
	clear_world()
	_spawn_points.clear()
	var t0 := Time.get_ticks_msec()
	var prop_count := 0
	var fallback_count := 0
	for node_variant in world.scene_nodes:
		if not (node_variant is SceneNode):
			continue
		var node: SceneNode = node_variant
		var path := _prop_path_for(node)
		if not path.is_empty():
			prop_count += 1
		else:
			fallback_count += 1
		_create_node(node)
		for child in node.children:
			if child is SceneNode:
				_create_node(child)
	print("[world_renderer] %d props loaded, %d primitive fallbacks in %d ms" %
		[prop_count, fallback_count, Time.get_ticks_msec() - t0])

func clear_world() -> void:
	for child in get_children():
		child.queue_free()
	_spawn_points.clear()

func get_spawn_position(index: int = 0) -> Vector3:
	if _spawn_points.is_empty():
		return Vector3(0, 2, 0)
	if index < 0 or index >= _spawn_points.size():
		return _spawn_points[0]
	return _spawn_points[index]

# Polish display-name → glTF prop. Kenney CC0 textured packs used wherever
# possible:
#   survival_kit (sk)    — chests, rocks, fences, logs, autumn trees
#   nature_kit (nk)      — palms, mushrooms, flowers, wheat, stone columns
#   pirate_kit (pk)      — boats, flags, treasure
#   food_kit (fk)        — apples, eggs, fruit
#   mini_characters (mc) — kid/parent NPC variations
const KENNEY_SK := "res://data/models/kenney/survival_kit/Models/GLB format/"
const KENNEY_NK := "res://data/models/kenney/nature_kit/GLB/"
const KENNEY_PK := "res://data/models/kenney/pirate_kit/GLB/"
const KENNEY_FK := "res://data/models/kenney/food_kit/GLB/"
# KayKit-style dungeon props (CC0 via Poly Pizza, per
# thoughts/shared/research/free-assets-2026-05-21.md).
const KAYKIT := "res://data/models/kaykit/"
# Quaternius-style character rigs (CC0 via Poly Pizza).
const QUATERNIUS := "res://data/models/quaternius/"

# Polish role-key → character rig path. Used by gameplay code that needs
# to spawn an NPC/player avatar by role (e.g. enemy_controller). Keys MUST
# stay lowercase a-z + Polish diacritics + underscore — see CLAUDE.md memory.
const CHARACTER_GLTF: Dictionary = {
	"ninja":      QUATERNIUS + "ninja.glb",
	"wojownik":   QUATERNIUS + "wojownik.glb",
	"szkielet":   QUATERNIUS + "szkielet.glb",
	"mag":        QUATERNIUS + "mag.glb",
}

const PROP_GLTF_MAP: Dictionary = {
	# --- dungeon world (KayKit-style CC0 via Poly Pizza) ---
	"mur":             KAYKIT + "mur.glb",
	"kolumna":         KAYKIT + "kolumna.glb",
	"kamienna_płyta":  KAYKIT + "kamienna_plyta.glb",
	"pochodnia":       KAYKIT + "pochodnia.glb",
	"beczka":          KAYKIT + "beczka.glb",
	"pajęczyna":       KAYKIT + "pajeczyna.glb",
	"skrzynia_skarbów": KAYKIT + "skrzynia_skarbow.glb",
	# --- universal / shared ---
	"skała":           KENNEY_NK + "rock_tallH.glb",
	"trawa":           KENNEY_NK + "grass.glb",
	"start":           KENNEY_SK + "campfire-pit.glb",  # spawn-point landmark
	"płot":            KENNEY_NK + "fence_simple.glb",
	"znajdźka":        KENNEY_FK + "apple.glb",  # collectible apple
	# --- adventure / island world ---
	"skrzynia":        KENNEY_SK + "chest.glb",
	"palma":           KENNEY_NK + "tree_palmTall.glb",
	"łódka":           KENNEY_PK + "boat-row-small.glb",
	"flaga":           KENNEY_PK + "flag-pirate-high.glb",
	"most":            KENNEY_NK + "bridge_woodRoundNarrow.glb",
	"moneta":          "res://data/models/props/coin.gltf",  # gold coin
	"rozgwiazda":      "res://data/models/props/starfish.gltf",  # no kenney sea-life
	"perła":           "res://data/models/props/pearl.gltf",
	# --- farm world ---
	"stodoła":         "res://data/models/props/barn.gltf",  # no kenney barn
	"jabłoń":          KENNEY_NK + "tree_palmDetailedShort.glb",  # short fruit tree stand-in
	"beli siana":      KENNEY_NK + "crops_wheatStageB.glb",
	"wiatrak":         "res://data/models/props/windmill.gltf",
	"kura":            "res://data/models/props/chicken.gltf",
	"koryto":          KENNEY_SK + "bucket.glb",
	"jabłko":          KENNEY_FK + "apple.glb",
	"jajko":           KENNEY_FK + "egg.glb",
	# --- forest world ---
	"dąb":             KENNEY_NK + "tree_tall_dark.glb",
	"grzyb":           KENNEY_NK + "mushroom_redTall.glb",
	"grzyb mały":      KENNEY_NK + "mushroom_red.glb",
	"kłoda":           KENNEY_NK + "stump_old.glb",
	"kamień z mchem":  KENNEY_NK + "rock_tallI.glb",
	"kwiaty":          KENNEY_NK + "flower_redA.glb",
	"świetlik":        "res://data/models/props/firefly_jar.gltf",
	"słoik świetlików": "res://data/models/props/firefly_jar.gltf",
	"żołądź":          KENNEY_FK + "egg.glb",  # acorn-like substitute
	"skała z mchem":   KENNEY_NK + "rock_tallJ.glb",
}


## Returns a new ShaderMaterial using the toon cel shader. When the source
## model carries an albedo_texture it is passed through and the color tint is
## forced to white so the texture shows at full fidelity (the shader multiplies
## albedo * texture) — this is the fix for textured models rendering as flat
## "blobs". For genuinely untextured primitives (tex == null) the base_color
## tint drives the look as before.
func _make_toon_material(base_color: Color, tex: Texture2D = null) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = TOON_CEL_SHADER
	var tint := Color.WHITE if tex != null else base_color
	mat.set_shader_parameter("albedo", tint)
	if tex != null:
		mat.set_shader_parameter("albedo_texture", tex)
	mat.set_shader_parameter("light_steps", 2.0)
	# Shadow band derived from the effective look: for textured props a light
	# cool shadow reads better than a darkened flat tint.
	var shadow := Color(0.72, 0.74, 0.82) if tex != null else base_color.darkened(0.35)
	mat.set_shader_parameter("shadow_color", shadow)
	return mat


## Polish display-name → fallback tint. Used when the glTF's authored material
## is a placeholder near-white (Blender review C3: all 26 props share
## baseColorFactor [0.8, 0.8, 0.8, 1]). W2.2 will fix Blender materials at
## source; until then kids see colored props instead of monochrome blobs.
const PROP_TINT_BY_NAME: Dictionary = {
	"palma": Color(0.32, 0.62, 0.25),       # palm leaves green
	"skała": Color(0.55, 0.55, 0.58),       # rock gray
	"skała z mchem": Color(0.40, 0.55, 0.30),
	"kamień z mchem": Color(0.42, 0.55, 0.30),
	"skrzynia": Color(0.55, 0.35, 0.18),    # chest wood brown
	"moneta": Color(0.95, 0.75, 0.20),      # coin gold
	"znajdźka": Color(0.95, 0.75, 0.20),
	"perła": Color(0.92, 0.92, 0.96),       # pearl white-blue
	"rozgwiazda": Color(0.95, 0.55, 0.30),  # starfish orange
	"łódka": Color(0.45, 0.30, 0.18),       # boat wood
	"flaga": Color(0.85, 0.20, 0.20),       # flag red
	"most": Color(0.55, 0.40, 0.25),        # bridge wood
	"trawa": Color(0.45, 0.75, 0.30),       # grass green
	"płot": Color(0.65, 0.50, 0.30),        # fence wood
	"stodoła": Color(0.75, 0.25, 0.20),     # barn red
	"jabłoń": Color(0.30, 0.55, 0.25),      # apple tree green
	"jabłko": Color(0.85, 0.20, 0.20),      # apple red
	"jajko": Color(0.95, 0.92, 0.80),       # egg cream
	"kura": Color(0.95, 0.92, 0.85),        # chicken white
	"beli siana": Color(0.85, 0.70, 0.30),  # hay gold
	"wiatrak": Color(0.85, 0.85, 0.85),     # windmill white
	"koryto": Color(0.55, 0.42, 0.28),      # trough wood
	"dąb": Color(0.30, 0.50, 0.22),         # oak green
	"grzyb": Color(0.80, 0.20, 0.20),       # mushroom red cap
	"grzyb mały": Color(0.85, 0.45, 0.20),
	"kłoda": Color(0.50, 0.35, 0.22),       # log brown
	"kwiaty": Color(0.95, 0.55, 0.85),      # flowers pink
	"świetlik": Color(0.95, 0.95, 0.55),    # firefly yellow
	"słoik świetlików": Color(0.95, 0.95, 0.55),
	"żołądź": Color(0.85, 0.65, 0.30),      # acorn brown-gold
	"start": Color(0.40, 0.85, 0.95),       # spawn crystal cyan
}


## Walk all MeshInstance3D descendants of a glTF prop instance and apply the
## toon material, preserving the original StandardMaterial3D albedo_color
## unless the glTF's authored material is a placeholder near-white — in that
## case override with a kid-friendly tint keyed on the SceneNode display_name.
func _apply_toon_to_prop(root: Node, display_name: String = "") -> void:
	var name_key := String(display_name).strip_edges().to_lower()
	var fallback_tint: Variant = PROP_TINT_BY_NAME.get(name_key, null)
	# owned=false so programmatically-instanced glTF nodes (no SceneTree owner) are found.
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = node
		var color := Color.WHITE
		var tex: Texture2D = null
		var existing_mat := mi.get_surface_override_material(0)
		if existing_mat == null and mi.mesh != null:
			existing_mat = mi.get_active_material(0)
		if existing_mat is StandardMaterial3D:
			var std := existing_mat as StandardMaterial3D
			color = std.albedo_color
			tex = std.albedo_texture
		# When the model carries a real texture atlas, use it — don't flatten
		# to a name-tint. The name-keyed tint only rescues genuinely untextured
		# placeholder props (near-white baseColorFactor, no texture).
		if tex == null and fallback_tint != null and color.r >= 0.7 and color.g >= 0.7 and color.b >= 0.7:
			color = fallback_tint
		mi.material_override = _make_toon_material(color, tex)


func _create_node(node: SceneNode) -> void:
	var godot_node: Node3D = null

	# Wave V3: prefer a hand-authored glTF prop when the display name matches.
	var prop_path: String = _prop_path_for(node)
	if not prop_path.is_empty():
		godot_node = _create_prop_node(prop_path, node)

	if godot_node == null:
		match node.node_type:
			SceneNode.NodeType.OBJECT:
				godot_node = _create_object_node(node)
			SceneNode.NodeType.TERRAIN:
				godot_node = _create_terrain_node(node)
			SceneNode.NodeType.LIGHT:
				godot_node = _create_light_node(node)
			SceneNode.NodeType.SPAWN_POINT:
				godot_node = _create_spawn_point_node(node)
			SceneNode.NodeType.TRIGGER:
				godot_node = _create_trigger_node(node)
			SceneNode.NodeType.DECORATION:
				godot_node = _create_decoration_node(node)

	if godot_node != null:
		add_child(godot_node)
		godot_node.position = node.position
		godot_node.rotation = node.rotation
		godot_node.scale = node.scale


func _prop_path_for(node: SceneNode) -> String:
	if node == null:
		return ""
	var key: String = String(node.display_name).strip_edges().to_lower()
	if key.is_empty():
		return ""
	return PROP_GLTF_MAP.get(key, "")


func _create_prop_node(gltf_path: String, node: SceneNode) -> Node3D:
	var loaded: Resource = ResourceLoader.load(gltf_path)
	if loaded == null:
		push_warning("WorldRenderer: glTF prop not found at %s — falling back to primitive." % gltf_path)
		return null
	var instance: Node = loaded.instantiate() if loaded is PackedScene else null
	if instance == null:
		push_warning("WorldRenderer: %s is not a PackedScene — using primitive." % gltf_path)
		return null
	# Wrap in StaticBody3D so kid characters can stand on / collide with the prop.
	var body := StaticBody3D.new()
	body.name = node.display_name if node != null else "Prop"
	body.add_child(instance)
	# Apply toon cel shader to every MeshInstance3D inside the glTF scene.
	# Pass display_name so placeholder near-white materials get a kid-friendly
	# tint until W2.2 fixes the Blender source materials.
	_apply_toon_to_prop(instance, node.display_name if node != null else "")
	# A loose collider sized to the node's bounding intent — keeps it cheap.
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.0, 1.0, 1.0)
	col.shape = shape
	body.add_child(col)
	return body

func _create_object_node(node: SceneNode) -> Node3D:
	var static_body := StaticBody3D.new()
	var mesh_instance := MeshInstance3D.new()
	var collision := CollisionShape3D.new()

	var mesh := _resolve_mesh(node.properties)
	mesh_instance.mesh = mesh

	var color_hint: Color = node.properties.get("color", Color.WHITE)
	mesh_instance.material_override = _make_toon_material(color_hint)

	var size: Variant = node.properties.get("size", Vector3.ONE)
	if size is Vector3:
		mesh_instance.scale = size

	var shape := BoxShape3D.new()
	shape.size = Vector3(1, 1, 1)
	collision.shape = shape

	static_body.add_child(mesh_instance)
	static_body.add_child(collision)
	return static_body

func _create_terrain_node(node: SceneNode) -> Node3D:
	var static_body := StaticBody3D.new()
	var mesh_instance := MeshInstance3D.new()
	var collision := CollisionShape3D.new()

	var mesh := BoxMesh.new()
	mesh.size = Vector3(50, 0.5, 50)
	mesh_instance.mesh = mesh

	var color_hint: Color = node.properties.get("color", Color.WHITE)
	mesh_instance.material_override = _make_toon_material(color_hint)

	var shape := BoxShape3D.new()
	shape.size = Vector3(50, 0.5, 50)
	collision.shape = shape

	static_body.add_child(mesh_instance)
	static_body.add_child(collision)
	return static_body

func _create_light_node(node: SceneNode) -> Node3D:
	var light_type: String = node.properties.get("light_type", "omni")
	if light_type == "directional":
		var light := DirectionalLight3D.new()
		light.shadow_enabled = true
		light.shadow_blur = 1.5
		return light
	else:
		var light := OmniLight3D.new()
		light.omni_range = node.properties.get("range", 10.0)
		light.light_energy = node.properties.get("energy", 1.0)
		light.light_color = Color(1.0, 0.95, 0.85)
		return light

func _create_spawn_point_node(node: SceneNode) -> Node3D:
	_spawn_points.append(node.position)
	var marker := Marker3D.new()
	marker.name = "SpawnPoint"
	
	# Add glow effect
	var glow := OmniLight3D.new()
	glow.name = "SpawnGlow"
	glow.omni_range = 3.0
	glow.light_energy = 0.8
	glow.light_color = Color(0.4, 0.8, 1.0)
	marker.add_child(glow)
	
	var particles := GPUParticles3D.new()
	particles.name = "SpawnParticles"
	particles.amount = 16
	particles.lifetime = 1.5
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.3
	pm.gravity = Vector3(0, 0.5, 0)
	pm.scale_min = 0.3
	pm.scale_max = 0.8
	pm.color = Color(0.4, 0.8, 1.0, 0.6)
	particles.process_material = pm
	var p_mesh := SphereMesh.new()
	p_mesh.radius = 0.04
	p_mesh.height = 0.08
	particles.draw_pass_1 = p_mesh
	marker.add_child(particles)
	
	return marker

func _create_trigger_node(node: SceneNode) -> Node3D:
	var area := Area3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1, 1, 1)
	collision.shape = shape
	area.add_child(collision)
	
	# Add glow effect for collectible feel
	var glow := OmniLight3D.new()
	glow.name = "TriggerGlow"
	glow.omni_range = 2.5
	glow.light_energy = 0.6
	glow.light_color = Color(1.0, 0.85, 0.3)
	area.add_child(glow)
	
	var particles := GPUParticles3D.new()
	particles.name = "TriggerParticles"
	particles.amount = 12
	particles.lifetime = 2.0
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.4
	pm.gravity = Vector3(0, 0.3, 0)
	pm.scale_min = 0.2
	pm.scale_max = 0.6
	pm.color = Color(1.0, 0.9, 0.4, 0.5)
	particles.process_material = pm
	var p_mesh := SphereMesh.new()
	p_mesh.radius = 0.03
	p_mesh.height = 0.06
	particles.draw_pass_1 = p_mesh
	area.add_child(particles)
	
	return area

func _create_decoration_node(node: SceneNode) -> Node3D:
	var mesh_instance := MeshInstance3D.new()
	var mesh := _resolve_mesh(node.properties)
	mesh_instance.mesh = mesh

	var color_hint: Color = node.properties.get("color", Color.WHITE)
	mesh_instance.material_override = _make_toon_material(color_hint)

	var size: Variant = node.properties.get("size", Vector3.ONE)
	if size is Vector3:
		mesh_instance.scale = size

	return mesh_instance

func _resolve_mesh(properties: Dictionary) -> PrimitiveMesh:
	var mesh_type: String = properties.get("mesh_type", "box")
	match mesh_type:
		"sphere":
			return SphereMesh.new()
		"cylinder":
			return CylinderMesh.new()
		"box", _:
			return BoxMesh.new()


# Builds and applies a WorldEnvironment for the given play mode.
# `mode` is "combat" (Shanghai Bund neon HDRI sky) or anything else
# (returns a soft procedural sky — keeps create/landing modes untouched).
# Idempotent: removes any existing WorldEnvironment child first.
const _COMBAT_HDRI_PATH := "res://data/textures/voxel/polyhaven_hdri/shanghai_bund_2k.hdr"

func _setup_world_environment(mode: String = "combat") -> void:
	for child in get_children():
		if child is WorldEnvironment:
			child.queue_free()
	var env := Environment.new()
	if mode == "combat" and ResourceLoader.exists(_COMBAT_HDRI_PATH):
		var hdri_tex := ResourceLoader.load(_COMBAT_HDRI_PATH) as Texture2D
		if hdri_tex != null:
			var sky_mat := PanoramaSkyMaterial.new()
			sky_mat.panorama = hdri_tex
			var sky := Sky.new()
			sky.sky_material = sky_mat
			env.background_mode = Environment.BG_SKY
			env.sky = sky
			env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
			env.ambient_light_energy = 0.6
		else:
			env.background_mode = Environment.BG_COLOR
			env.background_color = Color(0.05, 0.02, 0.10)
	else:
		# Non-combat default: soft procedural sky already used elsewhere.
		env.background_mode = Environment.BG_COLOR
		env.background_color = Color(0.40, 0.55, 0.75)
	var we := WorldEnvironment.new()
	we.environment = env
	we.name = "VoxelWorldEnvironment"
	add_child(we)
