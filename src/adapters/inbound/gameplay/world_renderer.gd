class_name WorldRenderer
extends Node3D

# Toon cel shader — applied to every MeshInstance3D rendered by this adapter
# (both glTF prop instances and primitive-mesh fallbacks).
const TOON_CEL_SHADER: Shader = preload("res://src/adapters/inbound/gameplay/shaders/toon_cel.gdshader")
const ENVIRONMENT_DETAIL_SHADER: Shader = preload("res://src/adapters/inbound/gameplay/shaders/environment_detail.gdshader")
const PBR_DETAIL_ALBEDO: Texture2D = preload("res://data/textures/pbr/ground003/Ground003_1K-JPG_Color.jpg")
const PBR_DETAIL_NORMAL: Texture2D = preload("res://data/textures/pbr/ground003/Ground003_1K-JPG_NormalGL.jpg")
const PBR_DETAIL_ROUGHNESS: Texture2D = preload("res://data/textures/pbr/ground003/Ground003_1K-JPG_Roughness.jpg")
const TERRAIN3D_WORLD_ADAPTER := preload("res://src/adapters/inbound/gameplay/terrain3d_world_adapter.gd")
const WORLD_HALF_EXTENT_M := 1200.0 # 2.4km × 2.4km = 5.76km² playable sandbox.
const PROCEDURAL_CHUNK_SIZE_M := 160.0
const PROCEDURAL_ACTIVE_RADIUS := 2
const PROCEDURAL_UNLOAD_RADIUS := 3
const PROCEDURAL_GENERATOR_VERSION := "adventure_sandbox_v2"
# Streaming is deliberately budgeted in this adapter: the gameplay physics
# tick requests work, but never synchronously instantiates a new biome strip.
const PROCEDURAL_BUILD_CELLS_PER_FRAME := 3
const PROCEDURAL_BUILD_BUDGET_USEC := 3500
const PROCEDURAL_DISPOSALS_PER_FRAME := 1

var _spawn_points: Array[Vector3] = []
var _procedural_seed_source := ""
var _procedural_chunk_root: Node3D
var _procedural_chunks: Dictionary = {}
var _procedural_build_queue: Array[Vector2i] = []
var _procedural_build_jobs: Dictionary = {}
var _procedural_disposal_queue: Array[Node3D] = []
var _last_streamed_chunk := Vector2i(999999, 999999)

func render_world(world: World) -> void:
	clear_world()
	_spawn_points.clear()
	var t0 := Time.get_ticks_msec()
	var prop_count := 0
	var fallback_count := 0
	# GameplayRuntime owns the Adventure floor as a single PBR StaticBody3D.
	# The template's legacy 2.4km TERRAIN box was also being rendered here,
	# sitting 25cm above it and visually burying every path, water, and ground
	# detail added by this adapter. Keep the authored data for other templates,
	# but never create that duplicate floor in the canonical Adventure runtime.
	var scene_owns_adventure_floor := world.theme in ["adventure", "tropical_fantasy"]
	for node_variant in world.scene_nodes:
		if not (node_variant is SceneNode):
			continue
		var node: SceneNode = node_variant
		if scene_owns_adventure_floor and node.node_type == SceneNode.NodeType.TERRAIN:
			continue
		var path := _prop_path_for(node)
		if not path.is_empty():
			prop_count += 1
		else:
			fallback_count += 1
		_create_node(node)
		for child in node.children:
			if child is SceneNode:
				_create_node(child)
	if world.theme in ["adventure", "tropical_fantasy"]:
		_build_adventure_dressing(world.world_id)
	print("[world_renderer] %d props loaded, %d primitive fallbacks in %d ms" %
		[prop_count, fallback_count, Time.get_ticks_msec() - t0])

func clear_world() -> void:
	for child in get_children():
		child.queue_free()
		_spawn_points.clear()
	_procedural_seed_source = ""
	_procedural_chunk_root = null
	_procedural_chunks.clear()
	_procedural_build_queue.clear()
	_procedural_build_jobs.clear()
	_procedural_disposal_queue.clear()
	_last_streamed_chunk = Vector2i(999999, 999999)

func get_spawn_position(index: int = 0) -> Vector3:
	if _spawn_points.is_empty():
		return Vector3(0, 2, 0)
	if index < 0 or index >= _spawn_points.size():
		return _spawn_points[0]
	return _spawn_points[index]


## Called by GameplayRuntime as the player crosses macro-cell boundaries.
## This keeps a 5.76km² world populated without instantiating its full prop
## count at boot. The seed stays deterministic per world, while chunks outside
## the local exploration envelope are safely reclaimed.
func set_exploration_focus(position: Vector3) -> void:
	if _procedural_seed_source.is_empty() or _procedural_chunk_root == null:
		return
	var focus_chunk := Vector2i(
		floori(position.x / PROCEDURAL_CHUNK_SIZE_M),
		floori(position.z / PROCEDURAL_CHUNK_SIZE_M))
	if focus_chunk == _last_streamed_chunk:
		return
	_last_streamed_chunk = focus_chunk
	for cx in range(focus_chunk.x - PROCEDURAL_ACTIVE_RADIUS, focus_chunk.x + PROCEDURAL_ACTIVE_RADIUS + 1):
		for cz in range(focus_chunk.y - PROCEDURAL_ACTIVE_RADIUS, focus_chunk.y + PROCEDURAL_ACTIVE_RADIUS + 1):
			var chunk_key := Vector2i(cx, cz)
			if _is_chunk_outside_world(chunk_key) or _procedural_chunks.has(chunk_key):
				continue
			_queue_procedural_chunk(chunk_key)
	_sort_procedural_build_queue(focus_chunk)
	for key_variant in _procedural_chunks.keys():
		var chunk_key: Vector2i = key_variant
		if maxi(absi(chunk_key.x - focus_chunk.x), absi(chunk_key.y - focus_chunk.y)) <= PROCEDURAL_UNLOAD_RADIUS:
			continue
		var chunk: Node3D = _procedural_chunks.get(chunk_key, null)
		if chunk != null and is_instance_valid(chunk):
			# Reclaiming a fully decorated chunk can be expensive too. Movement
			# only schedules it; _process releases one old chunk per frame.
			_procedural_disposal_queue.append(chunk)
		_procedural_chunks.erase(chunk_key)
		_procedural_build_jobs.erase(chunk_key)
		_procedural_build_queue.erase(chunk_key)


func _sort_procedural_build_queue(focus_chunk: Vector2i) -> void:
	_procedural_build_queue.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var a_offset := a - focus_chunk
		var b_offset := b - focus_chunk
		var a_distance := a_offset.x * a_offset.x + a_offset.y * a_offset.y
		var b_distance := b_offset.x * b_offset.x + b_offset.y * b_offset.y
		return a_distance < b_distance)


func _is_chunk_outside_world(chunk_key: Vector2i) -> bool:
	# Only generate a chunk when its entire square lies on the world floor.
	# Testing just the center admitted an outer strip whose props spilled beyond
	# the terrain slab behind the coast wall.
	var min_x := float(chunk_key.x) * PROCEDURAL_CHUNK_SIZE_M
	var min_z := float(chunk_key.y) * PROCEDURAL_CHUNK_SIZE_M
	var max_x := min_x + PROCEDURAL_CHUNK_SIZE_M
	var max_z := min_z + PROCEDURAL_CHUNK_SIZE_M
	return min_x < -WORLD_HALF_EXTENT_M or min_z < -WORLD_HALF_EXTENT_M \
		or max_x > WORLD_HALF_EXTENT_M or max_z > WORLD_HALF_EXTENT_M

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
const KAYKIT_BUILDER := "res://data/models/kaykit/builder/objects/"
const KAYKIT_TILES := "res://data/models/kaykit/builder/tiles_square/"
# Quaternius-style character rigs (CC0 via Poly Pizza).
const QUATERNIUS := "res://data/models/quaternius/"
const QUATERNIUS_NATURE := QUATERNIUS + "nature/"
const QUATERNIUS_VILLAGE := QUATERNIUS + "medieval_village/"
# Curated, credited CC-BY house-interior assets. Keep this separate from the
# CC0 kits so distribution credits remain explicit and auditable.
const POLY_PIZZA_ZSKY := "res://data/models/third_party/poly_pizza_zsky/"

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
	"skrzynia skarbów": KENNEY_SK + "chest.glb",
	"most linowy": KENNEY_NK + "bridge_woodRoundNarrow.glb",
	"wieża odkrywców": KAYKIT + "kolumna.glb",
	"kamienna brama": KAYKIT + "mur.glb",
	"obóz bazowy": KENNEY_SK + "campfire-pit.glb",
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
	"dąb":             KENNEY_NK + "tree_default.glb",
	"grzyb":           KENNEY_NK + "mushroom_redTall.glb",
	"grzyb mały":      KENNEY_NK + "mushroom_red.glb",
	"kłoda":           KENNEY_NK + "stump_old.glb",
	"kamień z mchem":  KENNEY_NK + "rock_tallI.glb",
	"kwiaty":          KENNEY_NK + "flower_redA.glb",
	"świetlik":        "res://data/models/props/firefly_jar.gltf",
	"słoik świetlików": "res://data/models/props/firefly_jar.gltf",
	"żołądź":          KENNEY_FK + "egg.glb",  # acorn-like substitute
	"skała z mchem":   KENNEY_NK + "rock_tallJ.glb",
	# --- authored settlement / route pieces from KayKit Builder ---
	"dom":             KAYKIT_BUILDER + "house.gltf.glb",
	"młyn":            KAYKIT_BUILDER + "mill.gltf.glb",
	"tartak":          KAYKIT_BUILDER + "lumbermill.gltf.glb",
	"studnia":         KAYKIT_BUILDER + "well.gltf.glb",
	"las":             KENNEY_NK + "tree_pineTallA_detailed.glb",
	"gospodarstwo":    KAYKIT_BUILDER + "farm_plot.gltf.glb",
	"góra":            KAYKIT_BUILDER + "mountain.gltf.glb",
	"most zadaszony":  KAYKIT_BUILDER + "bridge_roofed.gltf.glb",
	"targ":            KAYKIT_BUILDER + "market.gltf.glb",
	"wieża strażnicza": KAYKIT_BUILDER + "watchtower.gltf.glb",
	"drogowskaz":      KENNEY_SK + "signpost.glb",
	"trawa duża":      KENNEY_NK + "grass_large.glb",
	"skały piaskowe":  KENNEY_PK + "rocks-sand-a.glb",
	"klif":            KENNEY_NK + "cliff_blockCave_rock.glb",
	"ryba":            KENNEY_SK + "fish.glb",
	"ryba duża":       KENNEY_SK + "fish-large.glb",
	"stół warsztatowy": KENNEY_SK + "workbench.glb",
	"łóżko":           KENNEY_SK + "bedroll.glb",
	"beczka duża":     KENNEY_SK + "barrel.glb",
	"zupa":            KENNEY_FK + "bowl-soup.glb",
	"jabłko kuchenne": KENNEY_FK + "apple.glb",
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


func _make_environment_detail_material(base_color: Color, profile: Dictionary) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = ENVIRONMENT_DETAIL_SHADER
	mat.set_shader_parameter("albedo", base_color)
	mat.set_shader_parameter("detail_albedo", PBR_DETAIL_ALBEDO)
	mat.set_shader_parameter("detail_normal", PBR_DETAIL_NORMAL)
	mat.set_shader_parameter("detail_roughness", PBR_DETAIL_ROUGHNESS)
	mat.set_shader_parameter("detail_scale", float(profile.get("scale", 2.0)))
	mat.set_shader_parameter("detail_strength", float(profile.get("strength", 0.30)))
	mat.set_shader_parameter("normal_strength", float(profile.get("normal", 0.28)))
	mat.set_shader_parameter("roughness_strength", float(profile.get("roughness", 0.62)))
	return mat


func _environment_detail_profile(name_key: String) -> Dictionary:
	var key := name_key.to_lower()
	if key.contains("rock") or key.contains("skał") or key.contains("kamień") or key.contains("hill") or key.contains("mountain") or key.contains("gór") or key.contains("klif") or key.contains("cliff"):
		return {"scale": 2.8, "strength": 0.52, "normal": 0.52, "roughness": 0.82}
	if key.contains("house") or key.contains("dom") or key.contains("mill") or key.contains("młyn") or key.contains("tartak") or key.contains("market") or key.contains("bridge") or key.contains("most"):
		return {"scale": 3.8, "strength": 0.34, "normal": 0.26, "roughness": 0.70}
	if key.contains("tree") or key.contains("dąb") or key.contains("palm") or key.contains("palma") or key.contains("bush") or key.contains("las") or key.contains("trawa") or key.contains("flower") or key.contains("kwiat"):
		return {"scale": 5.6, "strength": 0.12, "normal": 0.12, "roughness": 0.58}
	if key.contains("path") or key.contains("ground") or key.contains("terrain"):
		return {"scale": 4.4, "strength": 0.58, "normal": 0.40, "roughness": 0.82}
	return {"scale": 2.2, "strength": 0.24, "normal": 0.20, "roughness": 0.66}


func _uses_environment_detail(name_key: String) -> bool:
	var key := name_key.to_lower()
	return key.contains("tree") or key.contains("dąb") or key.contains("palm") or key.contains("palma") \
		or key.contains("bush") or key.contains("las") or key.contains("rock") or key.contains("skał") \
		or key.contains("kamień") or key.contains("hill") or key.contains("mountain") or key.contains("gór") or key.contains("klif") \
		or key.contains("cliff") or key.contains("house") or key.contains("dom") or key.contains("mill") \
		or key.contains("młyn") or key.contains("tartak") or key.contains("market") or key.contains("bridge") \
		or key.contains("most") or key.contains("opening_path") or key.contains("terrain")


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
	var force_opening_palette := false
	# Curated opening assets are loaded by their concrete kit paths rather than
	# generic display names. The Nature Kit source uses near-white palette
	# swatches for several of these meshes, so give those known prefixes the
	# same restrained material language as their mapped world counterparts.
	if name_key.begins_with("opening_grove_tree"):
		fallback_tint = Color(0.20, 0.38, 0.22)
		force_opening_palette = true
	elif name_key.begins_with("opening_grove_bush"):
		fallback_tint = Color(0.27, 0.48, 0.24)
		force_opening_palette = true
	elif name_key.begins_with("opening_grove_flower"):
		fallback_tint = Color(0.92, 0.70, 0.20)
		force_opening_palette = true
	elif name_key.begins_with("opening_path"):
		fallback_tint = Color(0.49, 0.34, 0.18)
		force_opening_palette = true
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
		# Real kit materials carry a texture atlas, normal detail and carefully
		# authored roughness. Replacing them with the prototype toon shader was
		# the reason trees and buildings looked half-rendered. Preserve them.
		if tex != null:
			continue
		# When the model carries a real texture atlas, use it — don't flatten
		# to a name-tint. The name-keyed tint only rescues genuinely untextured
		# placeholder props (near-white baseColorFactor, no texture).
		if tex == null and fallback_tint != null and (force_opening_palette or (color.r >= 0.7 and color.g >= 0.7 and color.b >= 0.7)):
			color = fallback_tint
		if _uses_environment_detail(name_key):
			mi.material_override = _make_environment_detail_material(color, _environment_detail_profile(name_key))
		else:
			mi.material_override = _make_toon_material(color, tex)


func _apply_toon_tint(root: Node, color: Color) -> void:
	# Some Nature Kit cliff source materials use high-contrast palette swatches.
	# A coastline needs one calm, readable stone language, so intentionally tint
	# that large background set instead of carrying neon sample colours across
	# the horizon.
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = node
		mi.material_override = _make_toon_material(color)


func _set_coast_visibility_range(root: Node) -> void:
	# Coast geometry is important when approached, but rendering a low-detail
	# ring at 1.1km creates an obvious ruler-straight horizon stripe. Let fog
	# carry the distant view and reveal the actual cliffs during the walk there.
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = node
		mi.visibility_range_end = 900.0
		mi.visibility_range_end_margin = 120.0
		mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF


func _create_node(node: SceneNode) -> Node3D:
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
		_normalize_collision_to_world_size(godot_node, node.scale)
	return godot_node


func _normalize_collision_to_world_size(root: Node3D, visual_scale: Vector3) -> void:
	# SceneNode scale belongs to the model, not its proxy. Without this, every
	# generated prop multiplied its collision box by the visual scale a second
	# time: trees stopped the player at their canopy and buildings created huge
	# invisible square walls. Collision dimensions are authored in world metres.
	for child in root.find_children("*", "CollisionShape3D", true, false):
		var collision := child as CollisionShape3D
		collision.scale = Vector3(
			1.0 / maxf(absf(visual_scale.x), 0.001),
			1.0 / maxf(absf(visual_scale.y), 0.001),
			1.0 / maxf(absf(visual_scale.z), 0.001)
		)


func _prop_path_for(node: SceneNode) -> String:
	if node == null:
		return ""
	var key: String = String(node.display_name).strip_edges().to_lower()
	if key.is_empty():
		return ""
	var path: String = PROP_GLTF_MAP.get(key, "")
	if path.is_empty():
		path = PROP_GLTF_MAP.get(key.replace(" ", "_"), "")
	return path


func _build_adventure_dressing(seed_source: String = "adventure") -> void:
	# The island is deliberately assembled from authored CC0 kit pieces. The
	# ground stays continuous; authored structures and nature props provide
	# composition without exposing a repeating square editor grid.
	_build_terrain3d_surface(seed_source)
	_build_adventure_route()
	_build_opening_grove()

	# The first thirty metres must already feel like a place, not a runway.
	# Use a visible house, yard, well, crops and a physical sign for the guide.
	_build_starter_homestead()
	_add_visual_asset("drogowskaz", Vector3(5.5, 0, -5.5), Vector3.ONE * 0.9, 0.0)
	var opening_fence := SceneNode.new("adventure_opening_fence", SceneNode.NodeType.DECORATION)
	opening_fence.display_name = "Płot"
	opening_fence.position = Vector3(7.0, 0, -5.0)
	opening_fence.scale = Vector3.ONE * 1.15
	_create_node(opening_fence)
	var opening_animal := SceneNode.new("adventure_opening_chicken", SceneNode.NodeType.DECORATION)
	opening_animal.display_name = "Kura"
	opening_animal.position = Vector3(6.5, 0, -4.5)
	var chicken := _create_node(opening_animal)
	if chicken != null:
		chicken.add_to_group("adventure_fauna")
		chicken.set_meta("fauna_base_y", chicken.global_position.y)

	# Large silhouettes close the horizon instead of exposing a square map edge.
	_build_horizon_dressing()
	_build_world_boundary(seed_source)
	_build_procedural_island(seed_source)
	_build_adventure_regions(seed_source)


func _build_terrain3d_surface(seed_source: String) -> void:
	var surface = TERRAIN3D_WORLD_ADAPTER.new()
	surface.name = "Terrain3DWorldAdapter"
	add_child(surface)
	if not surface.build(seed_source):
		surface.queue_free()


func _build_opening_grove() -> void:
	# The first view is deliberately hand-composed from the locally installed
	# Kenney Nature Kit. The previous golden-spiral scatter made a technically
	# populated but unreadable field, and mixed in oversized purple FBX trees.
	# This gives the player a dirt path, a bridge route ahead, and two natural
	# branches into the village/forest without placing opaque obstacles in the
	# centre of the camera.
	var path := KENNEY_NK + "ground_pathStraight.glb"
	# The river occupies z=-33..-15. Stop the trail at each bank and let the
	# bridge be the only crossing cue rather than drawing dirt beneath water.
	for z in range(-6, -15, -2):
		_add_visual_asset("opening_path_%d" % abs(z), Vector3(0.0, 0.08, float(z)),
			Vector3.ONE, 0.0, path, false)
	for z in range(-36, -49, -2):
		_add_visual_asset("opening_path_far_%d" % abs(z), Vector3(0.0, 0.08, float(z)),
			Vector3.ONE, 0.0, path, false)
	for x in range(-2, -27, -2):
		_add_visual_asset("opening_path_forest_%d" % abs(x), Vector3(float(x), 0.08, -10.0),
			Vector3.ONE, PI * 0.5, path, false)
	for x in range(2, 27, 2):
		_add_visual_asset("opening_path_village_%d" % x, Vector3(float(x), 0.08, -10.0),
			Vector3.ONE, PI * 0.5, path, false)

	var tree_path := KENNEY_NK + "tree_default.glb"
	var pine_path := KENNEY_NK + "tree_pineRoundA.glb"
	var bush_path := KENNEY_NK + "plant_bushLarge.glb"
	var flower_path := KENNEY_NK + "flower_yellowA.glb"
	var tree_positions := [
		[Vector3(-7.5, 0, -5), 2.15, tree_path], [Vector3(7.5, 0, -6), 2.25, pine_path],
		[Vector3(-15, 0, -12), 2.35, pine_path], [Vector3(15, 0, -13), 2.15, tree_path],
		[Vector3(-22, 0, -25), 2.4, tree_path], [Vector3(22, 0, -27), 2.3, pine_path],
		[Vector3(-31, 0, -39), 2.55, pine_path], [Vector3(31, 0, -42), 2.45, tree_path],
	]
	for i in tree_positions.size():
		var entry: Array = tree_positions[i]
		_add_visual_asset("opening_grove_tree_%d" % i, entry[0], Vector3.ONE * float(entry[1]),
			float(i) * 0.71, String(entry[2]), true, Vector3(1.45, 3.6, 1.45))
	var bush_positions := [
		Vector3(-5.5, 0, -5), Vector3(5.5, 0, -6), Vector3(-9, 0, -14), Vector3(9, 0, -15),
		Vector3(-18, 0, -20), Vector3(18, 0, -22), Vector3(-26, 0, -35), Vector3(25, 0, -36),
	]
	for i in bush_positions.size():
		_add_visual_asset("opening_grove_bush_%d" % i, bush_positions[i], Vector3.ONE * 1.45,
			float(i) * 0.48, bush_path, true, Vector3(1.5, 1.3, 1.5))
		_add_visual_asset("opening_grove_flower_%d" % i,
			bush_positions[i] + Vector3(1.2, 0.0, 0.8), Vector3.ONE * 0.9,
			float(i) * 0.32, flower_path, false)
	_add_visual_asset("opening_campfire", Vector3(-7.5, 0, -10.5), Vector3.ONE * 1.15,
		0.0, KENNEY_NK + "campfire_stones.glb", true, Vector3(1.6, 0.8, 1.6))
	_add_visual_asset("opening_fence_left", Vector3(-6.6, 0, -4.2), Vector3.ONE * 1.2,
		0.0, KENNEY_NK + "fence_simple.glb", true, Vector3(3.0, 1.2, 0.35))
	_add_visual_asset("opening_fence_right", Vector3(6.6, 0, -4.2), Vector3.ONE * 1.2,
		PI, KENNEY_NK + "fence_simple.glb", true, Vector3(3.0, 1.2, 0.35))


func _build_adventure_regions(seed_source: String) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(seed_source)

	# Houses and a little village — destination geometry first, then props.
	_add_visual_asset("dom", Vector3(39, 0, 37), Vector3.ONE * 1.95, 0.2)
	_add_visual_asset("młyn", Vector3(51, 0, 45), Vector3.ONE * 1.7, -0.45)
	_add_visual_asset("studnia", Vector3(45, 0, 44), Vector3.ONE * 1.3, 0.0)
	_add_visual_asset("gospodarstwo", Vector3(50, 0, 36), Vector3.ONE * 1.35, 0.0)
	_spawn_region_props("village", Vector3(44, 0, 42), 14.0,
		["Stodoła", "Wiatrak", "Płot", "Koryto", "Skrzynia", "Trawa duża"], 22, rng)
	_spawn_region_props("village_animals", Vector3(44, 0, 42), 10.0, ["Kura"], 6, rng, true)
	_add_visual_asset("drogowskaz", Vector3(35, 0, 42), Vector3.ONE * 0.9, 1.2)

	# A dense forest region gives the kid a reason to leave the central trail.
	# The sign and first resources remain close enough to invite discovery, but
	# the actual woods stretch hundreds of metres north-west instead of ending
	# after one decorative grove.
	_add_visual_asset("las", Vector3(-82, 0, 62), Vector3.ONE * 2.8, 0.0)
	_build_dense_forest_region(seed_source, Vector3(-220, 0, 120))
	_spawn_region_props("forest", Vector3(-44, 0, 38), 15.0,
		["Dąb", "Dąb", "Kłoda", "Skała", "Grzyb", "Kwiaty", "Trawa duża"], 36, rng)
	_add_gatherable_resource("forest_wood_1", "wood_oak", Vector3(-55, 0, 46), "Kłoda", "Zbierz drewno", "gather_wood")
	_add_gatherable_resource("forest_wood_2", "wood_oak", Vector3(-49, 0, 55), "Kłoda", "Zbierz drewno", "gather_wood")
	_add_gatherable_resource("forest_wood_3", "wood_oak", Vector3(-62, 0, 35), "Dąb", "Zetnij drzewo", "gather_wood")
	_add_visual_asset("drogowskaz", Vector3(-34, 0, 38), Vector3.ONE * 0.9, -1.2)

	# A bright beach/lagoon region with authored sand/water tiles, boats,
	# shells, and palms.
	_add_visual_asset("łódka", Vector3(-54, 0.15, -27), Vector3.ONE * 1.25, 0.4)
	_spawn_region_props("beach", Vector3(-44, 0, -28), 15.0,
		["Palma", "Palma", "Rozgwiazda", "Perła", "Skała", "Skały piaskowe", "Trawa duża"], 30, rng)
	_add_visual_asset("drogowskaz", Vector3(-34, 0, -28), Vector3.ONE * 0.9, 0.0)

	# Cave entrance / ruins region. The dark props and cliff pieces create a
	# clear visual promise of something hidden without a new cave system.
	_add_visual_asset("klif", Vector3(42, 0, -42), Vector3.ONE * 2.8, 0.0)
	_add_visual_asset("klif", Vector3(51, 0, -39), Vector3.ONE * 2.1, -0.5)
	_spawn_region_props("cave", Vector3(42, 0, -36), 10.0,
		["Mur", "Mur", "Kolumna", "Pochodnia", "Beczka", "Pajęczyna", "Skrzynia Skarbów", "Skała"], 24, rng)
	_add_gatherable_resource("cave_iron_1", "ore_iron", Vector3(36, 0, -48), "Skała z mchem", "Wydobądź kamień", "gather_stone")
	_add_gatherable_resource("cave_iron_2", "ore_iron", Vector3(50, 0, -48), "Skała z mchem", "Wydobądź kamień", "gather_stone")
	_add_gatherable_resource("cave_iron_3", "ore_iron", Vector3(55, 0, -34), "Skała z mchem", "Wydobądź kamień", "gather_stone")
	_add_visual_asset("drogowskaz", Vector3(32, 0, -36), Vector3.ONE * 0.9, 0.0)


func _add_gatherable_resource(id: String, item_id: String, position: Vector3, prop_name: String, prompt: String, action: String) -> void:
	var is_tree := action == "gather_wood"
	var scale := Vector3.ONE * (2.15 if is_tree else 1.25)
	var collision_size := Vector3(1.25, 3.8, 1.25) if is_tree else Vector3(1.8, 1.4, 1.8)
	var visual := _add_visual_asset("resource_%s" % id, position, scale, 0.0,
		_prop_path_for_name(prop_name), true, collision_size)
	var anchor := _add_interaction_anchor(id, position + Vector3(0.0, 0.15, 0.0), "E  %s" % prompt, action)
	anchor.set_meta("resource_item_id", item_id)
	anchor.set_meta("resource_visual", visual)
	anchor.set_meta("resource_id", id)
	anchor.set_meta("resource_prop_name", prop_name)
	anchor.set_meta("resource_position", position)
	anchor.set_meta("resource_prompt", prompt)
	anchor.set_meta("resource_action", action)


func respawn_gatherable_resource(resource_data: Dictionary) -> void:
	var id := String(resource_data.get("resource_id", ""))
	var item_id := String(resource_data.get("resource_item_id", ""))
	var prop_name := String(resource_data.get("resource_prop_name", ""))
	var prompt := String(resource_data.get("resource_prompt", ""))
	var action := String(resource_data.get("resource_action", ""))
	var position: Variant = resource_data.get("resource_position", Vector3.ZERO)
	if id.is_empty() or item_id.is_empty() or prop_name.is_empty() or not (position is Vector3):
		return
	_add_gatherable_resource(id, item_id, position as Vector3, prop_name, prompt, action)


func _build_dense_forest_region(seed_source: String, center: Vector3) -> void:
	# The regional forest is intentionally a 400m × 300m walkable biome, not a
	# decorative prefab. The clearings and diagonal trail create orientation,
	# while the tree mass is large enough that the player cannot cross it in a
	# few seconds or see straight through it from the starter yard.
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s_dense_forest" % seed_source)
	for gx in range(-12, 13):
		for gz in range(-9, 10):
			var fx := float(gx)
			var fz := float(gz)
			# Keep one generous diagonal trail plus irregular clearings. This is
			# dense enough to feel like a forest, but never a collision maze.
			if absf(fz - fx * 0.42) < 1.0 or (gx * 13 + gz * 7) % 23 == 0:
				continue
			var tree_position := center + Vector3(
				fx * 16.0 + rng.randf_range(-4.0, 4.0),
				0.0,
				fz * 16.0 + rng.randf_range(-4.0, 4.0))
			var tree_scale := rng.randf_range(1.45, 2.15)
			_add_visual_asset("dense_forest_tree_%d_%d" % [gx, gz], tree_position,
				Vector3.ONE * tree_scale, rng.randf_range(0.0, TAU),
				_prop_path_for_name("Dąb"), true, Vector3(1.55, 3.8, 1.55))
			if (gx + gz) % 3 == 0:
				_add_visual_asset("dense_forest_understory_%d_%d" % [gx, gz],
					tree_position + Vector3(3.0, 0.0, -2.5),
					Vector3.ONE * rng.randf_range(0.7, 1.1), rng.randf_range(0.0, TAU),
					_prop_path_for_name("Trawa duża"), true, Vector3(1.2, 1.0, 1.2))


func _build_adventure_route() -> void:
	# A bridge, camp, and a visible guide destination make the route feel
	# authored even before the player discovers the four regional biomes. The
	# player walks directly on the continuous world floor rather than on tile
	# plates that reveal the construction grid.
	_add_water_crossing()
	_add_visual_asset("most zadaszony", Vector3(0, 0.9, -24), Vector3.ONE * 2.0, 0.0, "", true, Vector3(8.0, 2.4, 5.0))
	_add_visual_asset("obóz bazowy", Vector3(0, 0, -12), Vector3.ONE * 1.25, 0.0)
	_add_visual_asset("drogowskaz", Vector3(-4, 0, -8), Vector3.ONE * 0.9, 0.35)


func _build_horizon_dressing() -> void:
	# The playable floor is large, but a kid should not see its edge. Imported
	# mountain silhouettes and a few cliff anchors provide depth and conceal the
	# far boundary under the environment fog.
	for i in 40:
		var angle := float(i) * TAU / 40.0
		var radius := 1080.0 + float(i % 3) * 36.0
		var position := Vector3(cos(angle) * radius, -1.0, sin(angle) * radius)
		var scale := Vector3.ONE * (4.0 + float(i % 4) * 0.7)
		_add_visual_asset("horizon_mountain_%d" % i, position, scale, -angle, KAYKIT_BUILDER + "mountain.gltf.glb", false)
	for i in 28:
		var angle := float(i) * TAU / 28.0 + 0.2
		var radius := 980.0
		_add_visual_asset("horizon_cliff_%d" % i,
			Vector3(cos(angle) * radius, -0.1, sin(angle) * radius),
			Vector3.ONE * (3.0 + float(i % 2) * 0.6), angle,
			KENNEY_NK + "cliff_block_rock.glb", false)


func _build_world_boundary(seed_source: String = "") -> void:
	# The floor remains 2.4km square for the promised 5.76km² sandbox, but its
	# final metres are now an actual ocean-and-cliff coast. The collision strips
	# sit inside that visible cliff mass rather than behaving like a hidden box.
	_add_outer_ocean()
	var coast := Node3D.new()
	coast.name = "CliffCoastCollision"
	add_child(coast)
	_build_cliff_coast_belt(seed_source, coast)


func _add_outer_ocean() -> void:
	# One low-cost ocean sheet is visible only beyond the land slab. It prevents
	# the old eternal chasm from appearing when a player reaches the shoreline.
	var ocean := MeshInstance3D.new()
	ocean.name = "OuterOcean"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(3000.0, 0.16, 3000.0)
	ocean.mesh = mesh
	ocean.position = Vector3(0.0, -0.42, 0.0)
	ocean.material_override = _make_toon_material(Color(0.055, 0.19, 0.29))
	add_child(ocean)


func _build_cliff_coast_belt(seed_source: String, collision_root: Node3D) -> void:
	# Reuse the locally installed Kenney Nature Kit so the coast shares the
	# foreground toon/material language. These are deliberately broad, varied
	# low-poly cliff faces—not tiny rocks scattered along an invisible wall.
	var cliff_paths := [
		KENNEY_NK + "cliff_block_rock.glb",
		KENNEY_NK + "cliff_blockSlope_rock.glb",
		KENNEY_NK + "cliff_large_rock.glb",
		KENNEY_NK + "cliff_cornerLarge_rock.glb",
	]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s_%s_cliff_coast" % [PROCEDURAL_GENERATOR_VERSION, seed_source])
	var segment_count := 34
	var segment_spacing := 67.0
	for side in range(4):
		for segment in range(segment_count):
			var along := (float(segment) - float(segment_count - 1) * 0.5) * segment_spacing
			var inward_jitter := rng.randf_range(-8.0, 4.0)
			var position := Vector3.ZERO
			var rotation_y := 0.0
			match side:
				0:
					position = Vector3(along, 0.0, -1128.0 + inward_jitter)
					rotation_y = 0.0
				1:
					position = Vector3(along, 0.0, 1128.0 - inward_jitter)
					rotation_y = PI
				2:
					position = Vector3(-1128.0 + inward_jitter, 0.0, along)
					rotation_y = PI * 0.5
				_:
					position = Vector3(1128.0 - inward_jitter, 0.0, along)
					rotation_y = -PI * 0.5
			var asset_path: String = cliff_paths[(segment + side * 3) % cliff_paths.size()]
			var cliff_scale := Vector3(
				rng.randf_range(48.0, 60.0),
				rng.randf_range(8.0, 14.0),
				rng.randf_range(36.0, 48.0))
			_add_visual_asset("coast_cliff_%d_%d" % [side, segment], position,
				cliff_scale, rotation_y + rng.randf_range(-0.18, 0.18), asset_path, false)
			# One primitive collision segment covers each neighbouring pair of
			# visible cliffs. It is placed in their mass, not kilometres behind as
			# an invisible rectangular fence, while keeping physics cost bounded.
			if segment % 2 == 0:
				_add_coast_collision_segment(collision_root, side, position, segment_spacing)
	# Four larger corner anchors remove the last straight-line read at a diagonal.
	for corner in [Vector3(-1128, 0, -1128), Vector3(1128, 0, -1128), Vector3(-1128, 0, 1128), Vector3(1128, 0, 1128)]:
		_add_visual_asset("coast_corner_%d_%d" % [int(corner.x), int(corner.z)],
			corner, Vector3(60.0, 18.0, 60.0), rng.randf_range(0.0, TAU),
			KENNEY_NK + "cliff_cornerLarge_rock.glb", false)
		_add_coast_corner_collision(collision_root, corner)


func _add_coast_collision_segment(parent: Node3D, side: int, cliff_position: Vector3, spacing: float) -> void:
	var body := StaticBody3D.new()
	body.name = "CoastSegment_%d_%d" % [side, parent.get_child_count()]
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(spacing * 2.05, 18.0, 44.0) if side < 2 else Vector3(44.0, 18.0, spacing * 2.05)
	collision.shape = shape
	collision.position = cliff_position + (Vector3(spacing * 0.5, 9.0, 0.0) if side < 2 else Vector3(0.0, 9.0, spacing * 0.5))
	body.add_child(collision)
	parent.add_child(body)


func _add_coast_corner_collision(parent: Node3D, corner: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = "CoastCorner_%d_%d" % [int(corner.x), int(corner.z)]
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(72.0, 22.0, 72.0)
	collision.shape = shape
	collision.position = corner + Vector3(0.0, 11.0, 0.0)
	body.add_child(collision)
	parent.add_child(body)


func _build_procedural_island(seed_source: String) -> void:
	# Deterministic chunks: same world id produces the same biomes, but only
	# the nearby 5×5 chunk envelope is resident. This makes a 5.76km² sandbox
	# viable on a laptop instead of booting thousands of distant prop nodes.
	_procedural_seed_source = seed_source
	_procedural_chunk_root = Node3D.new()
	_procedural_chunk_root.name = "ProceduralChunks"
	add_child(_procedural_chunk_root)
	set_exploration_focus(Vector3.ZERO)


## Reserves an immediately-addressable chunk root, but leaves decoration work
## to _advance_procedural_generation. This is the important separation that
## keeps GameplayRuntime's physics callback from creating hundreds of nodes.
func _queue_procedural_chunk(chunk_key: Vector2i) -> void:
	if _procedural_chunk_root == null:
		return
	if _procedural_chunks.has(chunk_key):
		return
	var chunk := Node3D.new()
	chunk.name = "Chunk_%d_%d" % [chunk_key.x, chunk_key.y]
	_procedural_chunk_root.add_child(chunk)
	_procedural_chunks[chunk_key] = chunk

	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s_%s_chunk_%d_%d" % [PROCEDURAL_GENERATOR_VERSION, _procedural_seed_source, chunk_key.x, chunk_key.y])
	var biome_noise := FastNoiseLite.new()
	biome_noise.seed = hash("%s_%s_biomes" % [PROCEDURAL_GENERATOR_VERSION, _procedural_seed_source])
	biome_noise.frequency = 0.0038
	biome_noise.fractal_octaves = 3
	var detail_noise := FastNoiseLite.new()
	detail_noise.seed = hash("%s_%s_detail" % [PROCEDURAL_GENERATOR_VERSION, _procedural_seed_source])
	detail_noise.frequency = 0.022
	_procedural_build_jobs[chunk_key] = {
		"chunk": chunk,
		"rng": rng,
		"biome_noise": biome_noise,
		"detail_noise": detail_noise,
		"cell_index": 0,
	}
	_procedural_build_queue.append(chunk_key)


func _advance_procedural_generation() -> void:
	for i in range(PROCEDURAL_DISPOSALS_PER_FRAME):
		if _procedural_disposal_queue.is_empty():
			break
		var stale_chunk: Node3D = _procedural_disposal_queue.pop_front()
		if stale_chunk != null and is_instance_valid(stale_chunk):
			stale_chunk.queue_free()
	var start_usec := Time.get_ticks_usec()
	var cells_built := 0
	while not _procedural_build_queue.is_empty() and cells_built < PROCEDURAL_BUILD_CELLS_PER_FRAME:
		if Time.get_ticks_usec() - start_usec >= PROCEDURAL_BUILD_BUDGET_USEC:
			break
		var chunk_key := _procedural_build_queue[0]
		var job_variant: Variant = _procedural_build_jobs.get(chunk_key, null)
		if not (job_variant is Dictionary):
			_procedural_build_queue.pop_front()
			continue
		var job: Dictionary = job_variant
		var chunk: Node3D = job.get("chunk", null)
		if chunk == null or not is_instance_valid(chunk):
			_procedural_build_jobs.erase(chunk_key)
			_procedural_build_queue.pop_front()
			continue
		_spawn_procedural_cell(chunk_key, job)
		job["cell_index"] = int(job.get("cell_index", 0)) + 1
		cells_built += 1
		if int(job["cell_index"]) >= 25:
			_procedural_build_jobs.erase(chunk_key)
			_procedural_build_queue.pop_front()
		else:
			_procedural_build_jobs[chunk_key] = job


func _spawn_procedural_cell(chunk_key: Vector2i, job: Dictionary) -> void:
	var cell_index := int(job.get("cell_index", 0))
	var gx := cell_index / 5
	var gz := cell_index % 5
	var rng: RandomNumberGenerator = job["rng"]
	var biome_noise: FastNoiseLite = job["biome_noise"]
	var detail_noise: FastNoiseLite = job["detail_noise"]
	var chunk: Node3D = job["chunk"]
	var base := Vector3(float(chunk_key.x) * PROCEDURAL_CHUNK_SIZE_M, 0.0, float(chunk_key.y) * PROCEDURAL_CHUNK_SIZE_M)
	var cell := base + Vector3(16.0 + float(gx) * 32.0, 0.0, 16.0 + float(gz) * 32.0)
	if _is_reserved_adventure_region(cell) or cell.length() < 120.0:
		return
	var biome_value := biome_noise.get_noise_2d(cell.x, cell.z)
	var detail_value := detail_noise.get_noise_2d(cell.x, cell.z)
	var candidates: Array = _procedural_candidates_for_biome(biome_value)
	var scatter_count := _procedural_scatter_count(biome_value, detail_value, rng)
	for scatter_index in scatter_count:
		var prop_name := String(candidates[rng.randi_range(0, candidates.size() - 1)])
		var prop_position := cell + Vector3(rng.randf_range(-12.0, 12.0), 0.0, rng.randf_range(-12.0, 12.0))
		var scale := rng.randf_range(0.78, 1.35)
		if prop_name == "Dąb" or prop_name == "Palma":
			# Source trees are diorama pieces; calibrate to a walk-under canopy,
			# not a garden shrub beside the 1.8m player.
			scale *= rng.randf_range(2.25, 3.35)
		# The parent StaticBody3D receives the visual scale, so this local shape
		# stays at the unscaled trunk size and follows the rendered tree exactly.
		var collision_size := Vector3(1.55, 3.8, 1.55) if prop_name == "Dąb" else Vector3(2.0, 5.5, 2.0)
		_add_visual_asset("chunk_%d_%d_%d_%d" % [chunk_key.x, chunk_key.y, gx, gz * 8 + scatter_index],
			prop_position, Vector3.ONE * scale, rng.randf_range(0.0, TAU),
			_prop_path_for_name(prop_name), true, collision_size, chunk)
	if biome_value > 0.52 and rng.randf() < 0.18:
		_add_visual_asset("chunk_hill_%d_%d_%d_%d" % [chunk_key.x, chunk_key.y, gx, gz],
			cell + Vector3(0.0, 0.0, 5.0), Vector3.ONE * rng.randf_range(2.4, 4.0),
			rng.randf_range(0.0, TAU), KAYKIT_BUILDER + "detail_hill.gltf.glb", true, Vector3(8.0, 5.0, 8.0), chunk)
	if rng.randf() < 0.035 and biome_value > -0.10:
		var building := "dom" if rng.randf() < 0.65 else "młyn"
		_add_visual_asset("chunk_%s_%d_%d_%d_%d" % [building, chunk_key.x, chunk_key.y, gx, gz],
			cell + Vector3(4.0, 0.0, -3.0), Vector3.ONE * rng.randf_range(1.5, 2.0),
			rng.randf_range(0.0, TAU), _prop_path_for_name(building), true, Vector3(8.0, 5.0, 8.0), chunk)
	if rng.randf() < 0.055:
		var animal := _add_visual_asset("chunk_fauna_%d_%d_%d_%d" % [chunk_key.x, chunk_key.y, gx, gz],
			cell + Vector3(rng.randf_range(-6.0, 6.0), 0.0, rng.randf_range(-6.0, 6.0)),
			Vector3.ONE * rng.randf_range(0.85, 1.05), rng.randf_range(0.0, TAU),
			_prop_path_for_name("kura"), true, Vector3(0.8, 0.7, 0.8), chunk)
		if animal != null:
			animal.add_to_group("adventure_fauna")
			animal.set_meta("fauna_base_y", animal.global_position.y)


func _procedural_candidates_for_biome(biome_value: float) -> Array:
	if biome_value < -0.38:
		return ["Palma", "Palma", "Skała", "Rozgwiazda", "Skały piaskowe", "Trawa duża"]
	if biome_value > 0.34:
		return ["Dąb", "Dąb", "Dąb", "Kłoda", "Grzyb", "Skała z mchem", "Trawa duża"]
	return ["Dąb", "Trawa duża", "Kwiaty", "Skała", "Kłoda"]


func _procedural_scatter_count(biome_value: float, detail_value: float, rng: RandomNumberGenerator) -> int:
	if biome_value > 0.34:
		return rng.randi_range(2, 4)
	if biome_value < -0.38:
		return 1 if detail_value < 0.15 else 2
	return rng.randi_range(1, 2)


func _is_reserved_adventure_region(position: Vector3) -> bool:
	for region in [
		[Vector3(44, 0, 42), 25.0],
		[Vector3(-44, 0, 38), 25.0],
		[Vector3(-44, 0, -28), 27.0],
		[Vector3(42, 0, -36), 23.0],
	]:
		if position.distance_to(region[0]) < float(region[1]):
			return true
	return false


func _build_starter_homestead() -> void:
	# One complete house is more valuable to the vertical slice than dozens of
	# sealed facades. The exterior remains a ready-made KayKit asset; the room
	# shell, doorway, furniture and interaction anchors make it genuinely
	# enterable and usable.
	# This must read as a real family-sized shelter beside a 1.8m child, not a
	# tabletop prop. The ready-made house is used as a textured exterior shell;
	# the dimensions below establish a 12m × 11m interior, a full-height door,
	# and furniture with adult-scale clearance around it.
	var center := Vector3(24, 0, 12)
	_add_box_obstacle("HomeBackWall", center + Vector3(0, 2.2, 5.85), Vector3(12.5, 4.4, 0.32), Color.TRANSPARENT, false)
	_add_box_obstacle("HomeLeftWall", center + Vector3(-6.1, 2.2, 0), Vector3(0.32, 4.4, 11.7), Color.TRANSPARENT, false)
	_add_box_obstacle("HomeRightWall", center + Vector3(6.1, 2.2, 0), Vector3(0.32, 4.4, 11.7), Color.TRANSPARENT, false)
	# Match the full visible facade: two 5m physical wings leave only the 2.2m
	# central doorway passable. The old 3.1m wings left two invisible side gaps
	# under window bays, which made the house feel inconsistent to navigate.
	_add_box_obstacle("HomeFrontWallL", center + Vector3(-3.6, 2.2, -5.85), Vector3(5.0, 4.4, 0.32), Color.TRANSPARENT, false)
	_add_box_obstacle("HomeFrontWallR", center + Vector3(3.6, 2.2, -5.85), Vector3(5.0, 4.4, 0.32), Color.TRANSPARENT, false)
	_add_box_obstacle("HomeFloor", center + Vector3(0, -0.10, 0), Vector3(12.2, 0.18, 11.4), Color.TRANSPARENT, false)

	# Make the body origin the hinge, then offset its collision and rendered mesh
	# into the doorway. Opening it now swings like a real door instead of
	# rotating around its centre.
	var door := _add_box_obstacle("HomeDoor", center + Vector3(-1.1, 1.6, -5.90), Vector3(2.2, 3.2, 0.22), Color.TRANSPARENT, false)
	if door != null:
		var door_collision := door.get_node_or_null("CollisionShape3D") as CollisionShape3D
		if door_collision != null:
			door_collision.position.x = 1.1
		door.add_to_group("world_interactable")
		door.set_meta("interaction_id", "home_door")
		door.set_meta("interaction_prompt", "E  Otwórz drzwi")
		door.set_meta("interaction_action", "door")
		door.set_meta("door_open", false)
		door.set_meta("door_closed_position", door.position)
		door.set_meta("door_collision", door_collision)
	_build_modular_starter_house_shell(center, door)

	# Real, adult-scale furniture replaces the placeholder bedroll/workbench.
	# Each collision box describes the rendered object in world metres and is
	# therefore deliberately independent of source GLB scale.
	_add_visual_asset("HomeDoubleBed", center + Vector3(-3.7, 0.0, 2.9), Vector3.ONE,
		0.10, POLY_PIZZA_ZSKY + "Double Bed.glb", true, Vector3(2.25, 0.82, 2.12))
	_add_visual_asset("HomeKitchenTable", center + Vector3(2.45, 0.0, 2.15), Vector3.ONE,
		-0.20, POLY_PIZZA_ZSKY + "Wood Kitchen Table.glb", true, Vector3(1.85, 0.82, 1.22))
	_add_visual_asset("HomeChairNorth", center + Vector3(2.45, 0.0, 3.30), Vector3.ONE,
		PI, POLY_PIZZA_ZSKY + "Wood Kitchen Chair.glb", true, Vector3(0.64, 0.94, 0.64))
	_add_visual_asset("HomeChairSouth", center + Vector3(2.45, 0.0, 1.02), Vector3.ONE,
		0.0, POLY_PIZZA_ZSKY + "Wood Kitchen Chair.glb", true, Vector3(0.64, 0.94, 0.64))
	_add_visual_asset("HomeStove", center + Vector3(4.82, 0.0, -2.75), Vector3.ONE,
		-PI * 0.5, POLY_PIZZA_ZSKY + "Gas Stove.glb", true, Vector3(1.08, 1.08, 0.78))
	_add_visual_asset("HomeFridge", center + Vector3(4.85, 0.0, -4.22), Vector3.ONE,
		-PI * 0.5, POLY_PIZZA_ZSKY + "Fridge.glb", true, Vector3(0.92, 1.92, 0.88))
	_add_visual_asset("HomeSink", center + Vector3(4.86, 0.0, -1.26), Vector3.ONE,
		-PI * 0.5, POLY_PIZZA_ZSKY + "Wooden Kitchen Sink.glb", true, Vector3(1.18, 0.98, 0.76))
	_add_visual_asset("HomeCouch", center + Vector3(-1.0, 0.0, -3.85), Vector3.ONE,
		0.0, POLY_PIZZA_ZSKY + "Three Seater Couch.glb", true, Vector3(2.35, 1.04, 0.94))
	_add_visual_asset("HomeBookshelf", center + Vector3(-4.92, 0.0, -2.45), Vector3.ONE,
		PI * 0.5, POLY_PIZZA_ZSKY + "Large Book Shelf.glb", true, Vector3(1.06, 1.92, 0.38))
	_add_visual_asset("HomeFloorLamp", center + Vector3(-0.15, 0.0, -3.35), Vector3.ONE,
		0.0, POLY_PIZZA_ZSKY + "Floor Lamp.glb", true, Vector3(0.46, 1.72, 0.46))
	_add_interaction_anchor("home_cook", center + Vector3(2.8, 0.0, 1.1), "E  Ugotuj posiłek", "cook")
	_add_interaction_anchor("home_sit", center + Vector3(2.45, 0.0, 0.35), "E  Usiądź przy stole", "sit")


## Assemble an actual 10m-class textured house from the Quaternius Village
## MegaKit rather than scaling a small prefab until it becomes blurry. The
## invisible wall bodies above remain the authoritative room collision while
## these source meshes give the house a door, windows, roof, and chimney.
func _build_modular_starter_house_shell(center: Vector3, door: StaticBody3D) -> void:
	var window_wall := QUATERNIUS_VILLAGE + "Wall_Plaster_Window_Wide_Flat.gltf"
	var solid_wall := QUATERNIUS_VILLAGE + "Wall_Plaster_Straight.gltf"
	var door_wall := QUATERNIUS_VILLAGE + "Wall_Plaster_Door_Flat.gltf"
	var floor_tile := QUATERNIUS_VILLAGE + "Floor_WoodDark.gltf"
	# The kit floor is a 2m square. A full 6×6 field turns the room into an
	# actual interior rather than grass/terrain showing underneath the furniture;
	# the single HomeFloor physics body above remains the collision authority.
	for x in range(-5, 6, 2):
		for z in range(-5, 6, 2):
			_add_visual_asset("HomeFloorTile_%d_%d" % [x, z],
				center + Vector3(float(x), 0.02, float(z)), Vector3.ONE,
				0.0, floor_tile, false)
	# Street facade: four window bays and a true central doorway establish a
	# human-scale front that reads from the opening trail.
	for bay in range(5):
		var front_path := door_wall if bay == 2 else window_wall
		_add_visual_asset("HomeFacade_%d" % bay,
			center + Vector3(-4.0 + float(bay) * 2.0, 0.0, -5.72),
			Vector3.ONE, PI, front_path, false)
	# Back and side walls turn the house into a coherent volume instead of a
	# front-only set. These meshes are 2m modular bays with source PBR maps.
	for bay in range(5):
		_add_visual_asset("HomeBack_%d" % bay,
			center + Vector3(-4.0 + float(bay) * 2.0, 0.0, 5.72),
			Vector3.ONE, 0.0, solid_wall, false)
	for bay in range(5):
		var z := -4.0 + float(bay) * 2.0
		_add_visual_asset("HomeLeft_%d" % bay,
			center + Vector3(-5.72, 0.0, z), Vector3.ONE, PI * 0.5, solid_wall, false)
		_add_visual_asset("HomeRight_%d" % bay,
			center + Vector3(5.72, 0.0, z), Vector3.ONE, -PI * 0.5, solid_wall, false)
	# One authored 10m gabled roof avoids a flat slab silhouette and keeps the
	# home visible above the opening grove without making it a miniature.
	_add_visual_asset("HomeGabledRoof", center + Vector3(0.0, 3.05, 0.0), Vector3.ONE,
		0.0, QUATERNIUS_VILLAGE + "Roof_RoundTiles_8x10.gltf", false)
	_add_visual_asset("HomeChimney", center + Vector3(3.1, 5.1, 0.6), Vector3.ONE,
		0.0, QUATERNIUS_VILLAGE + "Prop_Chimney.gltf", false)
	if door == null:
		return
	var packed := load(QUATERNIUS_VILLAGE + "Door_2_Flat.gltf") as PackedScene
	if packed == null:
		return
	var visual := packed.instantiate() as Node3D
	if visual == null:
		return
	visual.name = "HomeDoorVisual"
	visual.position = Vector3(1.1, -1.60, 0.0)
	visual.rotation.y = PI
	door.add_child(visual)
	_apply_toon_to_prop(visual, "home wooden door")
	door.set_meta("door_visual", visual)


func _add_water_crossing() -> void:
	var water := Area3D.new()
	water.name = "StarterRiver"
	water.add_to_group("water_volume")
	water.monitoring = true
	var mesh := BoxMesh.new()
	# A long, readable river continues beyond the opening bridge so it reads as
	# geography rather than a blue test strip. The authored floor remains under
	# it as a shallow safe-water bed for this kid-friendly prototype.
	# Give the bridge a readable waterway in the opening frame. The previous
	# 14m strip was so thin from the third-person camera that it read as a line.
	mesh.size = Vector3(2300.0, 0.12, 18.0)
	var visual := MeshInstance3D.new()
	visual.name = "WaterSurface"
	visual.mesh = mesh
	var water_material := StandardMaterial3D.new()
	water_material.albedo_color = Color(0.08, 0.34, 0.48, 0.72)
	water_material.roughness = 0.2
	water_material.metallic = 0.08
	water_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	visual.material_override = water_material
	water.add_child(visual)
	var water_collision := CollisionShape3D.new()
	water_collision.name = "WaterVolumeShape"
	var water_shape := BoxShape3D.new()
	water_shape.size = Vector3(2300.0, 1.5, 18.0)
	water_collision.shape = water_shape
	water_collision.position.y = -0.62
	water.add_child(water_collision)
	water.position = Vector3(0, 0.10, -24)
	water.body_entered.connect(_on_water_body_entered)
	water.body_exited.connect(_on_water_body_exited)
	add_child(water)
	for x in range(-1120, 1121, 36):
		for side in [-1.0, 1.0]:
			_add_visual_asset("river_bank_%s_%s" % [str(x), str(side)],
				Vector3(float(x), 0.0, -24.0 + side * 11.0),
				Vector3.ONE * (1.05 + float(abs(x) % 3) * 0.08),
				float(x) * 0.03, KENNEY_NK + "rock_tallH.glb", true, Vector3(2.0, 1.8, 2.0))


func _on_water_body_entered(body: Node3D) -> void:
	if body != null and body.has_method("set_in_water"):
		body.call("set_in_water", true)


func _on_water_body_exited(body: Node3D) -> void:
	if body != null and body.has_method("set_in_water"):
		body.call("set_in_water", false)


func _add_interaction_anchor(id: String, anchor_position: Vector3, prompt: String, action: String) -> Area3D:
	var anchor := Area3D.new()
	anchor.name = id
	anchor.position = anchor_position
	anchor.add_to_group("world_interactable")
	anchor.set_meta("interaction_id", id)
	anchor.set_meta("interaction_prompt", prompt)
	anchor.set_meta("interaction_action", action)
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 1.8
	shape.shape = sphere
	anchor.add_child(shape)
	add_child(anchor)
	return anchor


func _add_box_obstacle(node_name: String, obstacle_position: Vector3, obstacle_size: Vector3, color: Color, visible: bool = true) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = obstacle_position
	if visible:
		var mesh_instance := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = obstacle_size
		mesh_instance.mesh = mesh
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = 0.88
		mesh_instance.material_override = material
		body.add_child(mesh_instance)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = obstacle_size
	collision.shape = shape
	body.add_child(collision)
	add_child(body)
	return body


func toggle_door(door: Node3D) -> void:
	if door == null or not is_instance_valid(door):
		return
	var is_open := bool(door.get_meta("door_open", false))
	var next_open := not is_open
	door.set_meta("door_open", next_open)
	var collision := door.get_meta("door_collision", null) as CollisionShape3D
	if collision != null:
		collision.set_deferred("disabled", next_open)
	var target_rotation := -PI * 0.48 if next_open else 0.0
	var tween := create_tween()
	tween.tween_property(door, "rotation:y", target_rotation, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	door.set_meta("interaction_prompt", "E  Zamknij drzwi" if next_open else "E  Otwórz drzwi")


func _add_visual_asset(
		node_name: String,
		asset_position: Vector3,
		asset_scale: Vector3 = Vector3.ONE,
		rotation_y: float = 0.0,
		asset_path: String = "",
		collidable: bool = true,
		collision_size: Vector3 = Vector3(1.5, 2.0, 1.5),
		parent_node: Node = null
	) -> Node3D:
	var path := asset_path
	if path.is_empty():
		path = _prop_path_for_name(node_name)
	if path.is_empty() or not ResourceLoader.exists(path):
		push_warning("WorldRenderer: visual asset missing for '%s' (%s)" % [node_name, path])
		return null
	var loaded: Resource = ResourceLoader.load(path)
	var instance: Node = loaded.instantiate() if loaded is PackedScene else null
	if instance == null:
		push_warning("WorldRenderer: visual asset '%s' is not instantiable" % path)
		return null
	var root: Node3D = StaticBody3D.new() if collidable else Node3D.new()
	root.name = node_name.replace(" ", "_")
	root.add_child(instance)
	# `_apply_toon_to_prop` preserves a valid source texture atlas. Otherwise it
	# applies the PBR detail layer above—important for KayKit Builder's flat
	# palette hills/mountains/houses, which previously looked unrendered.
	if node_name.begins_with("coast_cliff") or node_name.begins_with("coast_corner"):
		_apply_toon_tint(instance, Color(0.33, 0.39, 0.35))
		_set_coast_visibility_range(instance)
	else:
		# Asset names supply the material class for procedural aliases such as
		# river_bank_42, whose node name does not itself mention "rock".
		_apply_toon_to_prop(instance, "%s %s" % [node_name, path.get_file()])
	if collidable:
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		var effective_collision_size := collision_size
		var collision_key := node_name.to_lower()
		if collision_size == Vector3(1.5, 2.0, 1.5):
			if collision_key.contains("dom") or collision_key.contains("house"):
				effective_collision_size = Vector3(8.0, 5.0, 8.0)
			elif collision_key.contains("młyn") or collision_key.contains("mill"):
				effective_collision_size = Vector3(6.0, 7.0, 6.0)
			elif collision_key.contains("las"):
				effective_collision_size = Vector3(5.0, 5.0, 5.0)
		shape.size = effective_collision_size
		collision.shape = shape
		# `root` is scaled to make the visual readable at world scale. Collision
		# dimensions are specified in world metres, so cancel that inherited
		# scale instead of turning a 1.5m tree trunk into an invisible 5m wall.
		collision.scale = Vector3(
			1.0 / maxf(absf(asset_scale.x), 0.001),
			1.0 / maxf(absf(asset_scale.y), 0.001),
			1.0 / maxf(absf(asset_scale.z), 0.001)
		)
		root.add_child(collision)
	root.position = asset_position
	root.rotation.y = rotation_y
	root.scale = asset_scale
	var container: Node = parent_node if parent_node != null else self
	container.add_child(root)
	return root


func _prop_path_for_name(display_name: String) -> String:
	var key := display_name.strip_edges().to_lower()
	return PROP_GLTF_MAP.get(key, "")


func _add_tile_field(
	center: Vector3,
	half_x: int,
	half_z: int,
	paths: Array,
	rng: RandomNumberGenerator,
	y_offset: float = 0.0
) -> void:
	if paths.is_empty():
		return
	for x in range(-half_x, half_x + 1):
		for z in range(-half_z, half_z + 1):
			var path := String(paths[rng.randi_range(0, paths.size() - 1)])
			_add_visual_asset("terrain_tile", center + Vector3(float(x) * 10.0, y_offset, float(z) * 10.0), Vector3.ONE, 0.0, path, false)


func _spawn_region_props(
	region_id: String,
	center: Vector3,
	radius: float,
	prop_names: Array,
	count: int,
	rng: RandomNumberGenerator,
	fauna: bool = false
) -> void:
	if prop_names.is_empty():
		return
	for i in count:
		var angle := rng.randf_range(0.0, TAU)
		var distance := rng.randf_range(radius * 0.35, radius)
		var node := SceneNode.new("adventure_%s_%d" % [region_id, i], SceneNode.NodeType.DECORATION)
		node.display_name = String(prop_names[rng.randi_range(0, prop_names.size() - 1)])
		node.position = center + Vector3(cos(angle) * distance, 0, sin(angle) * distance)
		var uniform_scale := rng.randf_range(0.85, 1.45)
		if node.display_name in ["Stodoła", "Wiatrak"]:
			uniform_scale *= 1.45
		elif node.display_name in ["Dąb", "Palma", "Las"]:
			uniform_scale *= 1.22
		node.scale = Vector3.ONE * uniform_scale
		var created := _create_node(node)
		if fauna and created != null:
			created.add_to_group("adventure_fauna")
			created.set_meta("fauna_base_y", created.global_position.y)


func _add_region_patch(patch_position: Vector3, size: Vector3, color: Color) -> void:
	# A dirt route is real walkable geometry, not a decal that can disagree with
	# the scene's physics. It remains almost flush with the ground but has its
	# own material and collision surface.
	var patch := StaticBody3D.new()
	patch.name = "RegionPatch_%s_%s" % [str(int(patch_position.x)), str(int(patch_position.z))]
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	visual.mesh = mesh
	visual.material_override = _make_toon_material(color)
	patch.add_child(visual)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	patch.add_child(collision)
	patch.position = patch_position
	add_child(patch)


func _process(delta: float) -> void:
	# Generation is adapter-local visual work. It consumes a tiny per-frame
	# budget here, never from GameplayRuntime's movement/physics callback.
	_advance_procedural_generation()
	# Small deterministic fauna motion makes the island feel inhabited while
	# remaining cheap and local to this inbound rendering adapter.
	var t := float(Time.get_ticks_msec()) / 1000.0
	for fauna in get_tree().get_nodes_in_group("adventure_fauna"):
		if not (fauna is Node3D) or not is_instance_valid(fauna):
			continue
		var animal: Node3D = fauna
		var base_y := float(animal.get_meta("fauna_base_y", animal.global_position.y))
		animal.global_position.y = base_y + sin(t * 2.0 + float(animal.get_instance_id() % 11)) * 0.04
		animal.rotate_y(delta * 0.35)


func _add_landmark_label(text: String, label_position: Vector3, color: Color) -> void:
	# World landmarks are now communicated by authored buildings, signs and
	# silhouettes. Floating debug-style labels made the scene read like an
	# editor overlay and are intentionally disabled for the playable slice.
	return


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
	var intent := _property_vector3(node.properties, "size", Vector3(1.8, 2.0, 1.8))
	shape.size = Vector3(maxf(absf(intent.x), 1.2), maxf(absf(intent.y), 1.2), maxf(absf(intent.z), 1.2))
	col.shape = shape
	body.add_child(col)
	return body

func _create_object_node(node: SceneNode) -> Node3D:
	var static_body := StaticBody3D.new()
	var mesh_instance := MeshInstance3D.new()
	var collision := CollisionShape3D.new()

	var mesh := _resolve_mesh(node.properties)
	mesh_instance.mesh = mesh

	var color_hint := _property_color(node.properties, "color", Color.WHITE)
	mesh_instance.material_override = _make_toon_material(color_hint)

	mesh_instance.scale = _property_vector3(node.properties, "size", Vector3.ONE)

	var shape := BoxShape3D.new()
	shape.size = _property_vector3(node.properties, "size", Vector3.ONE)
	collision.shape = shape

	static_body.add_child(mesh_instance)
	static_body.add_child(collision)
	return static_body

func _create_terrain_node(node: SceneNode) -> Node3D:
	var static_body := StaticBody3D.new()
	var mesh_instance := MeshInstance3D.new()
	var collision := CollisionShape3D.new()

	var terrain_size := _property_vector3(node.properties, "size", Vector3(50, 0.5, 50))
	var mesh := BoxMesh.new()
	mesh.size = terrain_size
	mesh_instance.mesh = mesh

	var color_hint := _property_color(node.properties, "color", Color.WHITE)
	mesh_instance.material_override = _make_terrain_material(color_hint)

	var shape := BoxShape3D.new()
	shape.size = terrain_size
	collision.shape = shape

	static_body.add_child(mesh_instance)
	static_body.add_child(collision)
	return static_body


func _make_terrain_material(base_color: Color) -> ShaderMaterial:
	# A restrained procedural surface keeps the island from reading as a flat
	# neon rectangle while avoiding a heavyweight texture dependency.
	var shader := Shader.new()
	shader.code = """
	shader_type spatial;
	render_mode diffuse_burley, specular_schlick_ggx;
	uniform vec4 base_color : source_color;
	void fragment() {
		vec2 p = UV * vec2(72.0, 72.0);
		float n = sin(p.x * 1.71 + sin(p.y * 0.43)) * 0.5 + 0.5;
		float grain = sin((p.x + p.y) * 4.7) * 0.035;
		vec3 dark = base_color.rgb * 0.78;
		vec3 light = base_color.rgb * 1.06;
		ALBEDO = mix(dark, light, clamp(n * 0.55 + 0.35 + grain, 0.0, 1.0));
		ROUGHNESS = 0.94;
	}
	"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("base_color", base_color.lerp(Color(0.48, 0.56, 0.42), 0.20))
	return mat

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
	area.name = node.node_id if not node.node_id.is_empty() else node.display_name
	for metadata_key in ["trigger_type", "item_name", "zone_id", "checkpoint_id"]:
		if node.properties.has(metadata_key):
			area.set_meta(metadata_key, node.properties[metadata_key])
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = _property_vector3(node.properties, "size", Vector3.ONE)
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
	var body := StaticBody3D.new()
	var mesh_instance := MeshInstance3D.new()
	var mesh := _resolve_mesh(node.properties)
	mesh_instance.mesh = mesh

	var color_hint := _property_color(node.properties, "color", Color.WHITE)
	mesh_instance.material_override = _make_toon_material(color_hint)

	mesh_instance.scale = _property_vector3(node.properties, "size", Vector3.ONE)

	body.add_child(mesh_instance)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	var authored_size := _property_vector3(node.properties, "size", Vector3.ONE)
	shape.size = Vector3(maxf(absf(authored_size.x), 0.6), maxf(absf(authored_size.y), 0.6), maxf(absf(authored_size.z), 0.6))
	collision.shape = shape
	body.add_child(collision)
	return body

func _resolve_mesh(properties: Dictionary) -> PrimitiveMesh:
	var mesh_type: String = properties.get("mesh_type", "box")
	match mesh_type:
		"sphere":
			return SphereMesh.new()
		"cylinder":
			return CylinderMesh.new()
		"box", _:
			return BoxMesh.new()


func _property_vector3(properties: Dictionary, key: String, fallback: Vector3) -> Vector3:
	var raw: Variant = properties.get(key, fallback)
	if raw is Vector3:
		return raw
	if raw is Array and (raw as Array).size() >= 3:
		var values: Array = raw
		return Vector3(float(values[0]), float(values[1]), float(values[2]))
	return fallback


func _property_color(properties: Dictionary, key: String, fallback: Color) -> Color:
	var raw: Variant = properties.get(key, fallback)
	if raw is Color:
		return raw
	if raw is String and Color.html_is_valid(raw as String):
		return Color.html(raw as String)
	if raw is Array and (raw as Array).size() >= 3:
		var values: Array = raw
		var alpha := float(values[3]) if values.size() >= 4 else 1.0
		return Color(float(values[0]), float(values[1]), float(values[2]), alpha)
	return fallback


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
