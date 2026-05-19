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

# Polish display-name → glTF prop. Kenney CC0 textured GLBs are used where
# available (data/models/kenney/survival_kit/Models/GLB format/). The Blender-
# authored fallbacks under data/models/props/ are placeholder-white per
# Blender review C3 — kept for props with no Kenney equivalent on disk
# (palms, mushrooms, eggs, etc. — would need Kenney Nature Kit). Per-name
# colour tints in PROP_TINT_BY_NAME compensate for white placeholders.
const KENNEY_SK := "res://data/models/kenney/survival_kit/Models/GLB format/"

const PROP_GLTF_MAP: Dictionary = {
	# --- universal / shared ---
	"skała":           KENNEY_SK + "rock-a.glb",
	"trawa":           KENNEY_SK + "grass.glb",
	"start":           KENNEY_SK + "campfire-pit.glb",  # spawn-point landmark
	"płot":            KENNEY_SK + "fence.glb",
	"znajdźka":        "res://data/models/props/coin.gltf",
	# --- adventure / island world ---
	"skrzynia":        KENNEY_SK + "chest.glb",
	"palma":           "res://data/models/props/palm.gltf",  # no kenney palm on disk
	"łódka":           "res://data/models/props/boat.gltf",
	"flaga":           "res://data/models/props/flag_pole.gltf",
	"most":            "res://data/models/props/rope_bridge.gltf",
	"moneta":          "res://data/models/props/coin.gltf",
	"rozgwiazda":      "res://data/models/props/starfish.gltf",
	"perła":           "res://data/models/props/pearl.gltf",
	# --- farm world ---
	"stodoła":         "res://data/models/props/barn.gltf",
	"jabłoń":          KENNEY_SK + "tree-autumn.glb",  # textured fallback
	"beli siana":      KENNEY_SK + "barrel.glb",       # hay-bale silhouette substitute
	"wiatrak":         "res://data/models/props/windmill.gltf",
	"kura":            "res://data/models/props/chicken.gltf",
	"koryto":          KENNEY_SK + "bucket.glb",
	"jabłko":          "res://data/models/props/apple.gltf",
	"jajko":           "res://data/models/props/egg.gltf",
	# --- forest world ---
	"dąb":             KENNEY_SK + "tree-autumn-tall.glb",
	"grzyb":           "res://data/models/props/mushroom_large.gltf",
	"grzyb mały":      "res://data/models/props/mushroom_small.gltf",
	"kłoda":           KENNEY_SK + "tree-log.glb",
	"kamień z mchem":  KENNEY_SK + "rock-b.glb",
	"kwiaty":          KENNEY_SK + "patch-grass.glb",
	"świetlik":        "res://data/models/props/firefly_jar.gltf",
	"słoik świetlików": "res://data/models/props/firefly_jar.gltf",
	"żołądź":          "res://data/models/props/glowing_acorn.gltf",
	"skała z mchem":   KENNEY_SK + "rock-c.glb",
}


## Returns a new ShaderMaterial using the toon cel shader, tinted with
## base_color. The shadow_color is automatically derived (darkened 35 %).
func _make_toon_material(base_color: Color) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = TOON_CEL_SHADER
	mat.set_shader_parameter("albedo", base_color)
	mat.set_shader_parameter("light_steps", 2.0)
	mat.set_shader_parameter("shadow_color", base_color.darkened(0.35))
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
		var existing_mat := mi.get_surface_override_material(0)
		if existing_mat == null and mi.mesh != null:
			existing_mat = mi.get_active_material(0)
		if existing_mat is StandardMaterial3D:
			color = existing_mat.albedo_color
		# Override placeholder near-white (all rgb >= 0.7) with the name-keyed
		# tint so kids see something colored. Real authored colors pass through.
		if fallback_tint != null and color.r >= 0.7 and color.g >= 0.7 and color.b >= 0.7:
			color = fallback_tint
		mi.material_override = _make_toon_material(color)


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
