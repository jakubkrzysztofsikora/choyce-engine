class_name WorldRenderer
extends Node3D

# Toon cel shader — applied to every MeshInstance3D rendered by this adapter
# (both glTF prop instances and primitive-mesh fallbacks).
const TOON_CEL_SHADER: Shader = preload("res://src/adapters/inbound/gameplay/shaders/toon_cel.gdshader")
const FOREST_FOLIAGE_SHADER: Shader = preload("res://src/adapters/inbound/gameplay/shaders/forest_foliage.gdshader")
const ENVIRONMENT_DETAIL_SHADER: Shader = preload("res://src/adapters/inbound/gameplay/shaders/environment_detail.gdshader")
const ADVENTURE_WATER_SHADER: Shader = preload("res://src/adapters/inbound/gameplay/shaders/adventure_water.gdshader")
const SIMPLE_WATER_DUDV: Texture2D = preload("res://data/textures/water/simplewater_dudv.png")
const ADVENTURE_PATH_SHADER: Shader = preload("res://src/adapters/inbound/gameplay/shaders/adventure_path.gdshader")
const PBR_DETAIL_ALBEDO: Texture2D = preload("res://data/textures/pbr/ground003/Ground003_1K-JPG_Color.jpg")
const PBR_DETAIL_NORMAL: Texture2D = preload("res://data/textures/pbr/ground003/Ground003_1K-JPG_NormalGL.jpg")
const PBR_DETAIL_ROUGHNESS: Texture2D = preload("res://data/textures/pbr/ground003/Ground003_1K-JPG_Roughness.jpg")
# Purpose-built stylized albedo: the former photographic hedge texture clashed
# with the rounded low-poly canopy mesh and made the opening look like mixed
# asset packs. This tile retains readable leaf clusters at child camera scale.
const FOREST_CANOPY_LEAVES: Texture2D = preload("res://data/textures/generated/forest-canopy-stylized-v2.png")
# CC0 ambientCG Bark012 replaces the former modular wood-trim atlas. That
# atlas has horizontal boards and was visibly striping every living tree trunk
# in the opening view; this is a purpose-built vertical bark PBR albedo.
const FOREST_BARK_ALBEDO: Texture2D = preload("res://data/textures/pbr/bark012/Bark012_1K-JPG_Color.jpg")
const OPENING_OAK_TREE := "res://data/models/props/oak_tree.gltf"
# The Ultimate Nature Pack is already present in the repository and licensed
# CC0.  Its authored branch silhouettes break the repeated lollipop-oak
# horizon without importing another unreviewed art pack.  Keep the curated oak
# nearest the player; these variants are restricted to the traversable forest
# beyond the bridge, where their taller crowns establish genuine travel scale.
const OPENING_FOREST_TREE_PATHS := [
	"res://data/models/quaternius/nature/CommonTree_1.fbx",
	"res://data/models/quaternius/nature/CommonTree_3.fbx",
	"res://data/models/quaternius/nature/PineTree_1.fbx",
	"res://data/models/quaternius/nature/BirchTree_1.fbx",
]
# Keep the bridge-side clearing in the same CC0 Quaternius family as the
# house, forest and rocks.  The former spherical `oak_tree.gltf` had a dense
# repeating leaf tile that dominated the actual opening camera as a toy
# lollipop silhouette.  These authored branch forms give the player a real
# woodland edge before they reach the bridge without importing a new pack.
const OPENING_NEAR_FOREST_TREE_PATHS := [
	"res://data/models/quaternius/nature/CommonTree_4.fbx",
	"res://data/models/quaternius/nature/CommonTree_1.fbx",
	"res://data/models/quaternius/nature/PineTree_4.fbx",
	"res://data/models/quaternius/nature/BirchTree_1.fbx",
]
# Per-source trunk profiles keep the forest's physical contact at the trunk,
# rather than a generic 1.65m box that can extend beyond birch and conifer
# geometry. Values are world-space and remain stable when the visual root is
# scaled because `_add_visual_asset()` inverse-scales the collision child.
const OPENING_FOREST_TREE_COLLISION_PROFILES := {
	"res://data/models/quaternius/nature/CommonTree_1.fbx": Vector3(1.20, 10.0, 1.20),
	"res://data/models/quaternius/nature/CommonTree_3.fbx": Vector3(0.92, 11.5, 0.92),
	"res://data/models/quaternius/nature/PineTree_1.fbx": Vector3(0.88, 10.5, 0.88),
	"res://data/models/quaternius/nature/BirchTree_1.fbx": Vector3(0.72, 12.0, 0.72),
	"res://data/models/quaternius/nature/CommonTree_4.fbx": Vector3(1.12, 10.8, 1.12),
	"res://data/models/quaternius/nature/PineTree_4.fbx": Vector3(0.86, 11.2, 0.86),
}
const TERRAIN3D_WORLD_ADAPTER := preload("res://src/adapters/inbound/gameplay/terrain3d_world_adapter.gd")
const WORLD_HALF_EXTENT_M := 1200.0 # 2.4km × 2.4km = 5.76km² playable sandbox.
const OPENING_COMPOSED_RADIUS_M := 380.0
const PROCEDURAL_CHUNK_SIZE_M := 160.0
const PROCEDURAL_ACTIVE_RADIUS := 2
const PROCEDURAL_UNLOAD_RADIUS := 3
const PROCEDURAL_GENERATOR_VERSION := "adventure_sandbox_v2"
# Streaming is deliberately budgeted in this adapter: the gameplay physics
# tick requests work, but never synchronously instantiates a new biome strip.
const PROCEDURAL_BUILD_CELLS_PER_FRAME := 3
const PROCEDURAL_BUILD_BUDGET_USEC := 3500
const PROCEDURAL_DISPOSALS_PER_FRAME := 1
const RIVER_SEGMENT_COUNT := 96
# Render the river more densely than its swim-volume collision. The previous
# two-vertices-across, 33m-long strips left a water shader with no geometry to
# deform, which made the river read as a static blue runway in the real camera.
# This is still only a few thousand triangles, while gameplay retains the
# cheaper 96 overlapping collision volumes.
const RIVER_RENDER_SEGMENT_COUNT := 192
const RIVER_RENDER_WIDTH_SUBDIVISIONS := 12
const RIVER_HALF_LENGTH_M := 1600.0
const RIVER_SHORE_WIDTH_M := 2.35

# Choyce unified color palette (Visual Art Direction - VS-012)
# Warm Beige: Ground, stone
const CHOYCE_WARM_BEIGE := Color(0xD4C4A8FF)
# Soft Green: Grass, foliage
const CHOYCE_SOFT_GREEN := Color(0x8FA68AFF)
# Sky Blue: Water, sky
const CHOYCE_SKY_BLUE := Color(0xB8D8D8FF)
# Wood Brown: Trees, furniture
const CHOYCE_WOOD_BROWN := Color(0x8B6B51FF)
# Roof Red: Architecture accents
const CHOYCE_ROOF_RED := Color(0xA66B5AFF)
# Accent Orange: Interactive elements
const CHOYCE_ACCENT_ORANGE := Color(0xE8A862FF)
# Water shore gradient colors. These must stay materially darker than the sky;
# the former pale palette made the river render as a white floor in direct play.
const CHOYCE_WATER_SHALLOW := Color(0.012, 0.145, 0.19, 1.0)
const CHOYCE_WATER_MEDIUM := Color(0.018, 0.19, 0.25, 1.0)
const CHOYCE_WATER_DEEP := Color(0.003, 0.045, 0.085, 1.0)

var _spawn_points: Array[Vector3] = []
var _procedural_seed_source := ""
var _procedural_chunk_root: Node3D
var _procedural_chunks: Dictionary = {}
var _procedural_build_queue: Array[Vector2i] = []
var _procedural_build_jobs: Dictionary = {}
var _procedural_disposal_queue: Array[Node3D] = []
var _last_streamed_chunk := Vector2i(999999, 999999)
var _has_runtime_terrain_surface := false
var _has_runtime_terrain_collision := false
# Incremented each time a new Terrain3D surface is successfully imported.
# Lets callers (and collision-probe guards) reject results from a stale session.
var _terrain_import_session_token := 0

# VS-025: Food database for foraging
@export var food_database: FoodDatabase = null

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
	_has_runtime_terrain_surface = false
	_has_runtime_terrain_collision = false


## GameplayRuntime keeps the legacy flat collider as a safety floor. Its
## visible mesh must be hidden only when Terrain3D has successfully built,
## otherwise two almost-coincident ground surfaces shimmer while walking.
func has_runtime_terrain_surface() -> bool:
	return _has_runtime_terrain_surface


func has_runtime_terrain_collision() -> bool:
	return _has_runtime_terrain_collision


func get_runtime_terrain_adapter() -> Node3D:
	return get_node_or_null("Terrain3DWorldAdapter") as Node3D


## The Terrain3D extension schedules dynamic collision asynchronously.  A
## successful `build()` request only means it accepted work; it does *not* mean
## that physics already exposes the local heightfield.  GameplayRuntime calls
## this after a couple of physics frames, excluding its hidden legacy safety
## floor, before it is allowed to remove that floor from character physics.
func get_terrain_import_session_token() -> int:
	return _terrain_import_session_token


func verify_runtime_terrain_contacts(
		samples: Array[Vector3],
		excluded_bodies: Array[RID] = [],
		expected_adapter: Node3D = null,
		expected_session_token: int = 0
	) -> bool:
	if not _has_runtime_terrain_collision:
		return false
	if expected_session_token != 0 and expected_session_token != _terrain_import_session_token:
		return false
	var terrain_adapter := get_runtime_terrain_adapter()
	if terrain_adapter == null:
		return false
	if expected_adapter != null and terrain_adapter != expected_adapter:
		return false
	var terrain_node: Node = terrain_adapter.get("terrain") as Node
	if terrain_node == null or not is_instance_valid(terrain_node):
		return false
	var world_3d := get_world_3d()
	if world_3d == null:
		return false
	var space_state := world_3d.direct_space_state
	for sample in samples:
		# The start clearing contains a player, campfire and house collider. A
		# vertical ray must prove the terrain *under* that authored dressing, not
		# reject valid ground merely because a gameplay object is above it.
		var ray_exclusions: Array[RID] = []
		ray_exclusions.append_array(excluded_bodies)
		var terrain_hit := false
		for _layer in 8:
			var query := PhysicsRayQueryParameters3D.create(
				sample + Vector3(0.0, 12.0, 0.0), sample + Vector3(0.0, -12.0, 0.0), 1, ray_exclusions)
			query.collide_with_areas = false
			query.collide_with_bodies = true
			var hit := space_state.intersect_ray(query)
			if hit.is_empty():
				break
			if _belongs_to_terrain_runtime(hit.get("collider", null), terrain_node):
				terrain_hit = true
				break
			var obstacle := hit.get("collider", null) as CollisionObject3D
			if obstacle == null:
				break
			ray_exclusions.append(obstacle.get_rid())
		if not terrain_hit:
			print("[terrain] no Terrain3D collision below composed contact sample %s" % sample)
			return false
	return true


func _belongs_to_terrain_runtime(candidate: Variant, terrain_node: Node) -> bool:
	var node := candidate as Node
	while node != null:
		if node == terrain_node:
			return true
		node = node.get_parent()
	return false

func get_spawn_position(index: int = 0) -> Vector3:
	if _spawn_points.is_empty():
		# The permanent safety floor and the Terrain3D opening both meet at y=0.
		# A 2m fallback made any template import hiccup visibly launch the child
		# above the rendered meadow, and hid the real spawn-marker regression.
		return Vector3.ZERO
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
	# The Nature Kit palm's banded trunk reads as a broken UV sheet at third-
	# person distance. This locally supplied compact palm has a coherent trunk
	# and leaf silhouette at human scale; beach size now comes from clusters,
	# not a single oversized prop.
	"palma":           "res://data/models/props/palm.gltf",
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
	var shadow := CHOYCE_SKY_BLUE if tex != null else base_color.darkened(0.35)
	mat.set_shader_parameter("shadow_color", shadow)
	return mat


## Keep leaf and bark surfaces distinct for reusable foliage models.  A
## MeshInstance material override would flatten a multi-surface tree into one
## colour, which is why the earlier procedural forest lost its trunk/foliage
## separation.  Source meshes that name their material slots retain their
## silhouette while sharing our local leaf and bark texture language.
func _apply_named_foliage_surface_materials(mi: MeshInstance3D, use_readable_forest_foliage: bool = false, foliage_tint: Color = Color.WHITE) -> bool:
	if mi.mesh == null:
		return false
	var applied := false
	for surface_index in mi.mesh.get_surface_count():
		var source_mat := mi.get_surface_override_material(surface_index)
		if source_mat == null:
			source_mat = mi.get_active_material(surface_index)
		var material_key := ""
		if source_mat != null:
			material_key = source_mat.resource_name.to_lower()
		if material_key.contains("leaf") or material_key.contains("foliage") \
			or material_key.contains("canopy") or material_key.contains("green"):
			var foliage_material := _make_readable_forest_foliage_material(foliage_tint) if use_readable_forest_foliage else _make_toon_material(Color.WHITE, FOREST_CANOPY_LEAVES)
			mi.set_surface_override_material(surface_index, foliage_material)
			applied = true
		elif material_key.contains("bark") or material_key.contains("wood") or material_key.contains("trunk"):
			mi.set_surface_override_material(surface_index, _make_bark_toon_material())
			applied = true
	return applied


## The imported CC0 bark photo is intentionally light enough to work across
## many renderers. Multiply it into the Adventure's natural wood range so it
## does not turn all trunks into pale, noisy columns beside the stylized grass.
func _make_bark_toon_material() -> ShaderMaterial:
	var mat := _make_toon_material(Color.WHITE, FOREST_BARK_ALBEDO)
	mat.set_shader_parameter("albedo", Color(0.42, 0.31, 0.19, 1.0))
	mat.set_shader_parameter("shadow_color", Color(0.16, 0.10, 0.055, 1.0))
	return mat


## Imported Quaternius crowns have multi-directional low-poly normals. Their
## readable material deliberately has a small ambient leaf floor, avoiding the
## black silhouette failure in direct play while retaining the shared textured
## leaf language instead of falling back to flat debug-green geometry.
func _make_readable_forest_foliage_material(variant_tint: Color = Color.WHITE) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = FOREST_FOLIAGE_SHADER
	mat.set_shader_parameter("albedo_texture", FOREST_CANOPY_LEAVES)
	# Keep branch silhouettes readable from the sunlit clearing. The earlier
	# dark floor made the ready-made CC0 crowns read as unrendered black blocks;
	# this is intentionally muted, not a neon-green fill.
	mat.set_shader_parameter("foliage_floor", Color(0.20, 0.35, 0.16, 1.0))
	mat.set_shader_parameter("foliage_tint", Color(1.02, 1.10, 0.92, 1.0) * variant_tint)
	mat.set_shader_parameter("texture_detail", 0.56)
	mat.set_shader_parameter("minimum_light", 0.52)
	return mat


func _forest_foliage_tint_for_asset(name_key: String) -> Color:
	var key := name_key.to_lower()
	if key.contains("pinetree_"):
		return Color(0.82, 0.98, 0.88, 1.0)
	if key.contains("birchtree_"):
		return Color(1.05, 1.10, 0.92, 1.0)
	if key.contains("commontree_3"):
		return Color(0.90, 1.02, 0.82, 1.0)
	return Color(1.0, 1.0, 1.0, 1.0)


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
	if key.contains("rock") or key.contains("skał") or key.contains("kamień") or key.contains("hill") or key.contains("mountain") or key.contains("gór") or key.contains("klif") or key.contains("cliff") or key.contains("openingbridgeshore"):
		return {"scale": 2.8, "strength": 0.52, "normal": 0.52, "roughness": 0.82}
	if key.contains("house") or key.contains("dom") or key.contains("mill") or key.contains("młyn") or key.contains("tartak") or key.contains("market") or key.contains("bridge") or key.contains("most"):
		return {"scale": 3.8, "strength": 0.34, "normal": 0.26, "roughness": 0.70}
	if key.contains("path") or key.contains("ground") or key.contains("terrain"):
		return {"scale": 4.4, "strength": 0.58, "normal": 0.40, "roughness": 0.82}
	return {"scale": 2.2, "strength": 0.24, "normal": 0.20, "roughness": 0.66}


func _uses_environment_detail(name_key: String) -> bool:
	var key := name_key.to_lower()
	return key.contains("rock") or key.contains("skał") \
		or key.contains("kamień") or key.contains("hill") or key.contains("mountain") or key.contains("gór") or key.contains("klif") \
		or key.contains("cliff") or key.contains("openingbridgeshore") or key.contains("house") or key.contains("dom") or key.contains("mill") \
		or key.contains("młyn") or key.contains("tartak") or key.contains("market") or key.contains("bridge") \
		or key.contains("most") or key.contains("opening_path") or key.contains("terrain")


## Polish display-name → fallback tint. Used when the glTF's authored material
## is a placeholder near-white (Blender review C3: all 26 props share
## baseColorFactor [0.8, 0.8, 0.8, 1]). W2.2 will fix Blender materials at
## source; until then kids see colored props instead of monochrome blobs.
const PROP_TINT_BY_NAME: Dictionary = {
	"palma": CHOYCE_SOFT_GREEN,              # palm leaves green -> foliage
	"skała": CHOYCE_WARM_BEIGE,              # rock gray -> ground/stone
	"skała z mchem": CHOYCE_SOFT_GREEN,      # rock with moss -> foliage
	"kamień z mchem": CHOYCE_SOFT_GREEN,     # stone with moss -> foliage
	"skrzynia": CHOYCE_WOOD_BROWN,           # chest wood brown
	"moneta": CHOYCE_ACCENT_ORANGE,          # coin gold -> interactive accent
	"znajdźka": CHOYCE_ACCENT_ORANGE,        # find/treasure -> interactive accent
	"perła": Color(0.92, 0.92, 0.96),        # pearl white-blue (keep - special item)
	"rozgwiazda": CHOYCE_ACCENT_ORANGE,      # starfish orange -> accent
	"łódka": CHOYCE_WOOD_BROWN,             # boat wood
	"flaga": CHOYCE_ROOF_RED,                # flag red -> architecture accent
	"most": CHOYCE_WOOD_BROWN,               # bridge wood
	"trawa": CHOYCE_SOFT_GREEN,              # grass green -> foliage
	"płot": CHOYCE_WOOD_BROWN,              # fence wood
	"stodoła": CHOYCE_ROOF_RED,              # barn red -> architecture accent
	"jabłoń": CHOYCE_SOFT_GREEN,             # apple tree green -> foliage
	"jabłko": CHOYCE_ACCENT_ORANGE,         # apple red -> accent (more vibrant)
	"jajko": Color(0.95, 0.92, 0.80),        # egg cream (keep - food item)
	"kura": Color(0.95, 0.92, 0.85),         # chicken white (keep - animal)
	"beli siana": CHOYCE_ACCENT_ORANGE,      # hay gold -> accent
	"wiatrak": CHOYCE_WARM_BEIGE,            # windmill white -> neutral/warm
	"koryto": CHOYCE_WOOD_BROWN,             # trough wood
	"dąb": CHOYCE_SOFT_GREEN,                # oak green -> foliage
	"grzyb": CHOYCE_SOFT_GREEN,              # mushroom red cap -> foliage (less scary)
	"grzyb mały": CHOYCE_SOFT_GREEN,         # small mushroom -> foliage
	"kłoda": CHOYCE_WOOD_BROWN,              # log brown
	"kwiaty": CHOYCE_SOFT_GREEN,
	"OpeningBridge": CHOYCE_WOOD_BROWN,      # bridge wood
	"świetlik": Color(0.95, 0.95, 0.55),    # firefly yellow
	"słoik świetlików": Color(0.95, 0.95, 0.55),
	"żołądź": Color(0.85, 0.65, 0.30),      # acorn brown-gold
	"start": CHOYCE_ACCENT_ORANGE,       # spawn crystal -> accent orange
}


## Walk all MeshInstance3D descendants of a glTF prop instance and apply the
## toon material, preserving the original StandardMaterial3D albedo_color
## unless the glTF's authored material is a placeholder near-white — in that
## case override with a kid-friendly tint keyed on the SceneNode display_name.
func _apply_toon_to_prop(root: Node, display_name: String = "") -> void:
	var name_key := String(display_name).strip_edges().to_lower()
	var fallback_tint: Variant = PROP_TINT_BY_NAME.get(name_key, null)
	var force_opening_palette := false
	var force_farm_animal_palette := false
	var force_bridge_stair_palette := false
	var is_opening_tree := false
	var is_foliage_asset := name_key.contains("tree") or name_key.contains("bush") \
		or name_key.contains("palm") or name_key.contains("grass") or name_key.contains("flower")
	var is_quaternius_forest_tree := name_key.contains("commontree_") \
		or name_key.contains("pinetree_") or name_key.contains("birchtree_")
	var forest_foliage_tint := _forest_foliage_tint_for_asset(name_key)
	# Curated opening assets are loaded by their concrete kit paths rather than
	# generic display names. The Nature Kit source uses near-white palette
	# swatches for several of these meshes, so give those known prefixes the
	# same restrained material language as their mapped world counterparts.
	if name_key.begins_with("opening_grove_tree") \
		or name_key.begins_with("openingforestmass") \
		or name_key.begins_with("opening_backdrop_tree") \
		or name_key.begins_with("openingforestgatewaytree"):
		fallback_tint = CHOYCE_SOFT_GREEN
		is_opening_tree = true
		# Preserve the authored leaf/trunk palette on the higher-fidelity Nature
		# MegaKit trees. Only genuinely near-white source meshes receive a tint.
		# Flattening every subtree to one green material made the forest look like
		# dark plastic blocks in the opening screenshot.
	elif name_key.begins_with("opening_grove_bush"):
		fallback_tint = CHOYCE_SOFT_GREEN
		force_opening_palette = true
	elif name_key.begins_with("opening_grove_flower"):
		fallback_tint = CHOYCE_ACCENT_ORANGE
		force_opening_palette = true
	elif name_key.begins_with("opening_fence"):
		# The supplied fence ships with a chalk-white palette swatch.  It was
		# reading as an unlit editor primitive at the edge of the opening.
		fallback_tint = CHOYCE_WOOD_BROWN
		force_opening_palette = true
	elif name_key.begins_with("opening_campfire"):
		fallback_tint = CHOYCE_WARM_BEIGE
		force_opening_palette = true
	elif name_key.begins_with("opening_path"):
		fallback_tint = CHOYCE_WARM_BEIGE
		force_opening_palette = true
	elif name_key.begins_with("openingbridgeshore"):
		# The supplied cliff modules have a chalk-white palette swatch in this
		# import path. In the opening frame that became a literal white cube by
		# the bridge. Treat these authored shoreline rocks as stone and give them
		# the same textured earth/rock language as the surrounding riverbank.
		fallback_tint = CHOYCE_WARM_BEIGE.darkened(0.20)
		force_opening_palette = true
	elif name_key.begins_with("openingriverbankthicket"):
		# The tall-plant source rendered as cyan crystal-like swatches in direct
		# play. These bank clusters deliberately use only the existing bush/rock
		# family and a constrained natural tint instead of neon decoration.
		fallback_tint = CHOYCE_SOFT_GREEN.darkened(0.08)
		force_opening_palette = true
	elif name_key.begins_with("openingriverbankbush"):
		# The base riverbank bush uses the same broken turquoise sample atlas as
		# the removed card layers. Bind it to the grounded thicket palette too.
		fallback_tint = CHOYCE_SOFT_GREEN.darkened(0.08)
		force_opening_palette = true
	elif name_key.begins_with("opening_grove_grass") \
		or name_key.begins_with("openingriverbanklowbush"):
		# Several imported bush/leaf cards carry a saturated turquoise palette swatch
		# rather than a usable albedo. `opening_grove_grass_*` was accidentally
		# excluded by the former `...grass_foreground` prefix, leaving the first
		# frame dotted with cyan crystal-like clumps. Bind every opening grass
		# instance to the same restrained foliage family as the trees.
		fallback_tint = CHOYCE_SOFT_GREEN.darkened(0.12)
		force_opening_palette = true
	elif name_key.contains("chicken") or name_key.contains("kura"):
		# The supplied low-poly chicken has a near-white flat material and no
		# texture. Against the grass it read as a glowing broken pickup rather
		# than wildlife, especially around the opening fence. Give every reuse of
		# this source a restrained brown-and-cream farm-animal palette.
		fallback_tint = CHOYCE_WOOD_BROWN
		force_farm_animal_palette = true
	elif name_key.contains("openingbridge") and name_key.contains("stair"):
		# The otherwise useful modular stair source imports as chalk-white here.
		# Lock it to the bridge's dark weathered wood family rather than leaving a
		# bright prefab fragment in the centre of the opening composition.
		fallback_tint = CHOYCE_WOOD_BROWN
		force_bridge_stair_palette = true
	elif name_key.contains("openingbridgedecktile") or name_key.contains("openingbridgesouthapproach") or name_key.contains("openingbridgenorthapproach"):
		# Bridge deck tiles and approach stairs use the same Quaternius Village
		# kit as the starter home. Apply the Choyce wood palette to maintain
		# material consistency across the bridge structure.
		fallback_tint = CHOYCE_WOOD_BROWN
		force_bridge_stair_palette = true
	elif name_key.contains("openingbridgerail"):
		# Bridge rail segments should also match the wood palette.
		fallback_tint = CHOYCE_WOOD_BROWN
		force_bridge_stair_palette = true
	# owned=false so programmatically-instanced glTF nodes (no SceneTree owner) are found.
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = node
		var mesh_key := String(node.name).to_lower()
		# The focal grove uses a separate oak trunk/canopy scene.  Keep the wood
		# as wood, but give only canopy meshes a dense leaf material instead of
		# tinting the whole tree dark brown.  This keeps the forest legible at
		# third-person distance without changing shared source assets.
		# Quaternius forest trees (FBX) need the forest_foliage shader with cull_disabled
		# to prevent black underside artefacts; the oak (GLTF) can use the toon shader.
		if is_opening_tree and not is_quaternius_forest_tree and (mesh_key.contains("canopy") or mesh_key.contains("leaf")):
			mi.material_override = _make_toon_material(Color.WHITE, FOREST_CANOPY_LEAVES)
			continue
		if is_opening_tree and not is_quaternius_forest_tree and mesh_key.contains("trunk"):
			mi.material_override = _make_bark_toon_material()
			continue
		# Curated opening foliage with known broken palette swatches must reach the
		# restrained fallback below. The generic named-foliage pass otherwise
		# returns early and preserves the cyan card colour seen in the live frame.
		if is_foliage_asset and not force_opening_palette \
			and _apply_named_foliage_surface_materials(mi, is_quaternius_forest_tree, forest_foliage_tint):
			continue
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
		if tex != null and not force_opening_palette and not force_farm_animal_palette and not force_bridge_stair_palette:
			continue
		# When the model carries a real texture atlas, use it — don't flatten
		# to a name-tint. The name-keyed tint only rescues genuinely untextured
		# placeholder props (near-white baseColorFactor, no texture).
		if fallback_tint != null and (force_opening_palette or force_farm_animal_palette or force_bridge_stair_palette or (color.r >= 0.7 and color.g >= 0.7 and color.b >= 0.7)):
			color = fallback_tint
		if is_opening_tree:
			# Nature MegaKit gives foliage and wood separate material slots, but
			# their source Kd values are nearly black. Lift each into a readable,
			# natural leaf/trunk family without painting the entire tree one colour.
			if color.g >= color.r * 0.82 and color.g >= color.b * 0.92:
				# Foliage - use softer green from Choyce palette
				color = CHOYCE_SOFT_GREEN.darkened(0.3)
			else:
				# Trunk - use wood brown from Choyce palette
				color = CHOYCE_WOOD_BROWN
		if force_opening_palette or force_farm_animal_palette or force_bridge_stair_palette:
			# The source's white texture is what made the chicken read as a broken
			# glowing pickup at normal third-person distance; the stair has the same
			# failure mode against the river. Use a coherent material and silhouette.
			tex = null
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
		if _apply_named_foliage_surface_materials(mi):
			continue
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
	_build_opening_flank_groundcover(seed_source)
	_build_opening_basecamp_tableau()

	# The first thirty metres must already feel like a place, not a runway.
	# Use a visible house, yard, well, crops and a physical sign for the guide.
	_build_starter_homestead()
	_build_opening_sightline_layer()
	_build_opening_courtyard()
	_build_opening_forest_mass(seed_source)
	_build_opening_harvest_trail()
	# The sign and chicken belong in the lived-in north-bank courtyard, not as
	# unexplained tiny objects beside the player's spawn.
	_add_visual_asset("drogowskaz", Vector3(-10.5, 0, -37.5), Vector3.ONE * 0.9, 0.0)
	var opening_fence := SceneNode.new("adventure_opening_fence", SceneNode.NodeType.DECORATION)
	opening_fence.display_name = "Płot"
	opening_fence.position = Vector3(20.0, 0, -42.5)
	opening_fence.scale = Vector3.ONE * 1.15
	_create_node(opening_fence)
	var opening_animal := SceneNode.new("adventure_opening_chicken", SceneNode.NodeType.DECORATION)
	opening_animal.display_name = "Kura"
	opening_animal.position = Vector3(18.4, 0, -40.2)
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
	_has_runtime_terrain_surface = surface.build(seed_source)
	_has_runtime_terrain_collision = _has_runtime_terrain_surface and surface.has_dynamic_collision()
	if _has_runtime_terrain_surface:
		_terrain_import_session_token += 1
	else:
		surface.queue_free()


## A place to begin, not an empty arena.  This intentionally compact camp is
## assembled from the supplied Survival Kit and lives off the central bridge
## lane: it frames the first view, gives the guide and bird a believable place
## to stand, and teaches the child that storage, rest and crafting belong to
## the sandbox before the larger world opens up.
func _build_opening_basecamp_tableau() -> void:
	const CAMP := "res://data/models/kenney/survival_kit/Models/GLB format/"
	# Keep the 4m central route clear from spawn to bridge.  The camp sits left
	# of that line, where its firelight and tent silhouette create depth without
	# becoming an invisible obstacle in the first ten seconds of play.
	_add_visual_asset("OpeningBasecampTent", Vector3(-12.4, 0.0, -8.8),
		Vector3.ONE * 2.35, -0.38, CAMP + "tent.glb", true, Vector3(3.3, 2.05, 3.15))
	_add_visual_asset("OpeningBasecampHalfTent", Vector3(-15.6, 0.0, -6.2),
		Vector3.ONE * 2.05, -0.78, CAMP + "tent-canvas-half.glb", true, Vector3(2.55, 1.55, 2.15))
	_add_visual_asset("OpeningBasecampFire", Vector3(-8.3, 0.0, -9.5),
		Vector3.ONE * 1.48, 0.15, CAMP + "campfire-pit.glb", true, Vector3(1.15, 0.42, 1.15))
	_add_visual_asset("OpeningBasecampChest", Vector3(-13.5, 0.0, -12.2),
		Vector3.ONE * 1.34, 0.45, CAMP + "chest.glb", true, Vector3(1.26, 0.92, 0.92))
	_add_visual_asset("OpeningBasecampBarrel", Vector3(-10.9, 0.0, -12.3),
		Vector3.ONE * 1.22, -0.20, CAMP + "barrel.glb", true, Vector3(0.82, 1.14, 0.82))
	# Two low logs make the fire read as a camp circle. They use close-fit
	# collision, so a child naturally walks around instead of through furniture.
	_add_visual_asset("OpeningBasecampLogWest", Vector3(-9.9, 0.0, -8.0),
		Vector3.ONE * 1.42, 1.20, CAMP + "tree-log-small.glb", true, Vector3(1.55, 0.46, 0.52))
	_add_visual_asset("OpeningBasecampLogSouth", Vector3(-7.1, 0.0, -11.3),
		Vector3.ONE * 1.42, -0.20, CAMP + "tree-log-small.glb", true, Vector3(1.55, 0.46, 0.52))
	var firelight := OmniLight3D.new()
	firelight.name = "OpeningBasecampFirelight"
	firelight.position = _terrain_grounded_position(Vector3(-8.3, 0.0, -9.5)) + Vector3(0.0, 1.15, 0.0)
	firelight.light_color = Color(1.0, 0.40, 0.14)
	firelight.light_energy = 1.15
	firelight.omni_range = 7.2
	firelight.shadow_enabled = false
	add_child(firelight)


## A forest starts at ankle height, not with a row of canopy meshes. Build
## deterministic flank clusters so each fresh session is navigable and familiar
## while the 4m bridge lane and camp circle remain deliberately clear.
func _build_opening_flank_groundcover(seed_source: String) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s_opening_flank_groundcover_v1" % seed_source)
	var grass_path := KENNEY_NK + "grass_leafsLarge.glb"
	var bush_path := KENNEY_NK + "plant_bushDetailed.glb"
	var mushroom_path := KENNEY_NK + "mushroom_tanGroup.glb"
	for index in range(44):
		var side := -1.0 if index % 2 == 0 else 1.0
		# Nothing comes within 7m of the bridge centre; positions are clustered
		# rather than a uniform scatter so there are readable little clearings.
		var position := Vector3(
			side * rng.randf_range(8.5, 29.0),
			0.0,
			rng.randf_range(-4.0, -26.0))
		if position.distance_to(Vector3(-8.3, 0.0, -9.5)) < 4.8:
			continue # retain the campfire seating circle
		if index % 5 == 0:
			_add_visual_asset("opening_grove_bush_flank_%02d" % index, position,
				Vector3.ONE * rng.randf_range(1.28, 1.68), rng.randf_range(0.0, TAU),
				bush_path, true, Vector3(1.28, 1.10, 1.12))
		elif index % 7 == 0:
			_add_visual_asset("opening_grove_flower_flank_%02d" % index, position,
				Vector3.ONE * rng.randf_range(0.95, 1.25), rng.randf_range(0.0, TAU),
				mushroom_path, false)
		else:
			_add_visual_asset("opening_grove_grass_flank_%02d" % index, position,
				Vector3.ONE * rng.randf_range(1.08, 1.62), rng.randf_range(0.0, TAU),
				grass_path, false)


func _build_opening_grove() -> void:
	# The first view is deliberately hand-composed from the locally installed
	# Kenney Nature Kit. The previous golden-spiral scatter made a technically
	# populated but unreadable field, and mixed in oversized purple FBX trees.
	# This gives the player a dirt path, a bridge route ahead, and two natural
	# branches into the village/forest without placing opaque obstacles in the
	# centre of the camera.
	# The imported 1m path tiles became chunky, repeated brown bands when
	# enlarged for child-scale traversal. Continuous textured trail meshes make
	# each route read as ground rather than as a row of tabletop props.
	# The river occupies z=-33..-15, so the trails stop at each bank and the
	# bridge remains the only crossing cue.
	# The bridge itself is the clear crossing landmark. Its former long flat
	# decals read as brown runway rectangles in the third-person opening shot.
	# Reach the door on the south facade, never the colliding left wall. The path
	# first turns outside the home footprint, then approaches the real doorway.
	# The bridge must visibly arrive at the home-yard, not point into an empty
	# lawn while the only real building sits at the edge of the frame.
	_add_opening_dirt_trail("OpeningTrailHomeApproach", Vector3(5.45, 0.035, -37.0), 2.7, 13.0, 2.07)
	# Aim at the centre of the 2.2m doorway, never the hinge/left wall.
	_add_opening_dirt_trail("OpeningTrailHomeFront", Vector3(12.0, 0.035, -40.1), 2.7, 3.2, 0.0)
	_add_opening_dirt_trail("OpeningTrailHomeDoor", Vector3(12.0, 0.035, -40.1), 2.35, 2.1)
	# The two near branches establish discovery routes.
	# Start each side route beyond the opening, then angle it toward its landmark.
	# Joining both at x=0 formed a flat brown crossbar through the camera view.
	_add_opening_dirt_trail("OpeningTrailForestJoin", Vector3(-6.0, 0.035, -12.6), 2.45, 14.0, -PI * 0.5)
	_add_opening_dirt_trail("OpeningTrailForest", Vector3(-14.0, 0.035, -13.2), 2.35, 10.0, -1.85)
	_add_opening_dirt_trail("OpeningTrailVillage", Vector3(14.0, 0.035, -7.0), 2.35, 8.0, 1.30)

	# The immediate camera frame uses the same ready-made Quaternius tree family
	# as the deep forest and medieval home. Their varied branch silhouettes avoid
	# the patterned spherical toy-oak that previously filled the first frame.
	var near_tree_types := OPENING_NEAR_FOREST_TREE_PATHS

	var bush_path := KENNEY_NK + "plant_bushDetailed.glb"
	var tree_positions := [
		# Immediate clearing: frame the player start without blocking routes
		[Vector3(-13.5, 0, -12), 1.95], [Vector3(13.5, 0, -13), 2.05],
		[Vector3(-20.5, 0, -5.5), 2.30], [Vector3(20.0, 0, -6.0), 2.18],
		[Vector3(-26.5, 0, -8.5), 2.62], [Vector3(27.5, 0, -10.2), 2.48],
		[Vector3(-31.5, 0, -15.0), 2.82], [Vector3(32.5, 0, -17.0), 2.72],
		# Near river bank: establish woodland edge closer to bridge
		[Vector3(-18, 0, -22), 2.15], [Vector3(19, 0, -24), 2.20],
		[Vector3(-24, 0, -26), 2.40], [Vector3(25, 0, -27), 2.35],
		# Keep the forest-route corridor open; this tree previously sat inside it.
		[Vector3(-27, 0, -22), 2.35], [Vector3(24, 0, -25), 2.30],
		[Vector3(-38, 0, -29), 2.85], [Vector3(38, 0, -32), 2.78],
		# Far frame: taller silhouettes create a middle ground on both banks,
		# while the bridge centre remains a bright, clear destination.
		[Vector3(-34, 0, -44), 2.80], [Vector3(35, 0, -48), 2.75],
		[Vector3(-48, 0, -52), 3.05], [Vector3(47, 0, -56), 3.12],
		[Vector3(-60, 0, -64), 3.25], [Vector3(58, 0, -68), 3.18],
		# Additional trees to fill the gap between river and deep forest
		[Vector3(-30, 0, -38), 2.55], [Vector3(31, 0, -39), 2.50],
		[Vector3(-42, 0, -46), 2.70], [Vector3(43, 0, -47), 2.65],
	]
	for i in tree_positions.size():
		var entry: Array = tree_positions[i]
		var tree_path: String = String(near_tree_types[i % near_tree_types.size()])
		# The supplied trees are 1.5–3.6m at unit scale. A child needs a true
		# 7–14m woodland edge rather than potted scenery beside the player.
		var scale := float(entry[1]) * 1.24
		var collision_size := OPENING_FOREST_TREE_COLLISION_PROFILES.get(tree_path,
			Vector3(1.0, 10.0, 1.0)) as Vector3
		_add_visual_asset("opening_grove_tree_%d" % i, entry[0], Vector3.ONE * scale,
			float(i) * 0.71, tree_path, true, collision_size)
	var bush_positions := [
		# Immediate clearing: denser layering around the player start
		Vector3(-5.5, 0, -5), Vector3(5.5, 0, -6),
		Vector3(-3.0, 0, -8), Vector3(3.0, 0, -9),
		Vector3(-8.0, 0, -3), Vector3(8.0, 0, -4),
		# Mid-ground: frame the routes
		Vector3(-9, 0, -18), Vector3(9, 0, -15),
		Vector3(-18, 0, -20), Vector3(18, 0, -22),
		# North of river: soften the transition to forest
		Vector3(-26, 0, -35), Vector3(25, 0, -36),
		Vector3(-12, 0, -30), Vector3(12, 0, -28),
		Vector3(-20, 0, -28), Vector3(22, 0, -32),
	]
	for i in bush_positions.size():
		_add_visual_asset("opening_grove_bush_%d" % i, bush_positions[i], Vector3.ONE * 1.45,
			float(i) * 0.48, bush_path, true, Vector3(1.5, 1.3, 1.5))
	
	# Add dense grass clusters in the immediate foreground
	var grass_path := KENNEY_NK + "grass_large.glb"
	var grass_positions := [
		Vector3(-4.0, 0, -7), Vector3(4.0, 0, -7.5), Vector3(-6.0, 0, -10),
		Vector3(6.0, 0, -11), Vector3(-10.0, 0, -12), Vector3(10.0, 0, -13),
		Vector3(-14.0, 0, -16), Vector3(14.0, 0, -17), Vector3(-2.0, 0, -3),
		Vector3(2.0, 0, -4), Vector3(-16.0, 0, -25), Vector3(16.0, 0, -26),
	]
	for i in grass_positions.size():
		_add_visual_asset("opening_grove_grass_%d" % i, grass_positions[i], Vector3.ONE * 1.2,
			float(i) * 0.37, grass_path, false)
	
	# Add flower accents for color variation
	var flower_paths := [
		KENNEY_NK + "flower_purpleA.glb",
		KENNEY_NK + "flower_redB.glb",
		KENNEY_NK + "flower_yellowC.glb",
	]
	var flower_positions := [
		Vector3(-7.0, 0, -6), Vector3(7.0, 0, -8), Vector3(-11.0, 0, -14),
		Vector3(11.0, 0, -16), Vector3(-3.0, 0, -2), Vector3(3.0, 0, -4),
	]
	for i in flower_positions.size():
		_add_visual_asset("opening_grove_flower_%d" % i, flower_positions[i], Vector3.ONE * 1.1,
			float(i) * 0.52, flower_paths[i % flower_paths.size()], false)
	
	_add_visual_asset("opening_campfire", Vector3(-7.5, 0, -10.5), Vector3.ONE * 1.15,
		0.0, KENNEY_NK + "campfire_stones.glb", true, Vector3(1.6, 0.8, 1.6))
	_add_visual_asset("opening_fence_left", Vector3(-6.6, 0, -4.2), Vector3.ONE * 1.2,
		0.0, KENNEY_NK + "fence_simple.glb", true, Vector3(3.0, 1.2, 0.35))
	_add_visual_asset("opening_fence_right", Vector3(6.6, 0, -4.2), Vector3.ONE * 1.2,
		PI, KENNEY_NK + "fence_simple.glb", true, Vector3(3.0, 1.2, 0.35))
	_build_opening_undergrowth()

	# VS-025: Add food spawning nodes near the opening grove
	_build_food_spawn_points()


## Fill the foreground with low, irregular layers so the player starts in a
## clearing inside a woodland rather than on a green plane with trees parked at
## its edge.  These clusters deliberately leave the NPC, campfire, house door
## and bridge approaches clear; the plants are visual dressing, while only the
## larger bushes carry a compact, matching collision footprint.
func _build_opening_undergrowth() -> void:
	var bush_path := KENNEY_NK + "plant_bushLarge.glb"
	var rock_path := KENNEY_NK + "rock_smallFlatC.glb"
	var thickets := [
		# Immediate foreground: dense layering around player
		[Vector3(-15.0, 0.0, -3.0), 1.18, 0.20],
		[Vector3(15.5, 0.0, -3.6), 1.10, -0.55],
		[Vector3(-12.0, 0.0, -2.5), 1.15, 0.45],
		[Vector3(12.0, 0.0, -2.8), 1.12, -0.40],
		# Mid-ground: along the routes
		[Vector3(-21.0, 0.0, -15.5), 1.34, 1.05],
		[Vector3(21.4, 0.0, -17.0), 1.28, -1.18],
		[Vector3(-18.0, 0.0, -9.0), 1.25, 0.80],
		[Vector3(18.0, 0.0, -11.0), 1.22, -0.75],
		# Near river: soften the bank transition
		[Vector3(-28.5, 0.0, -26.0), 1.42, 0.63],
		[Vector3(27.0, 0.0, -28.0), 1.36, -0.91],
		[Vector3(-24.0, 0.0, -22.0), 1.30, 1.20],
		[Vector3(24.0, 0.0, -24.0), 1.28, -1.05],
		# Far undergrowth: fill the gap to forest
		[Vector3(-34.0, 0.0, -42.0), 1.56, 1.72],
		[Vector3(34.0, 0.0, -44.0), 1.52, -2.10],
		[Vector3(-29.0, 0.0, -34.0), 1.45, 0.95],
		[Vector3(29.0, 0.0, -36.0), 1.40, -1.10],
	]
	for index in thickets.size():
		var entry: Array = thickets[index]
		var position: Vector3 = entry[0]
		var scale := float(entry[1])
		var rotation := float(entry[2])
		_add_visual_asset("opening_grove_bush_foreground_%d" % index, position,
			Vector3.ONE * scale, rotation, bush_path, true,
			Vector3(1.18 * scale, 0.95, 1.12 * scale))
		# `grass_leafsLarge` is a sample-card mesh with a saturated cyan atlas.
		# At third-person distance it read as a floating UI shard rather than flora.
		# The grounded bush-and-rock layer leaves a readable clearing and route edge.
		if index % 2 == 0:
			_add_visual_asset("opening_grove_rock_foreground_%d" % index,
				position + Vector3(1.12, -0.06, -0.76), Vector3.ONE * 0.72,
				rotation - 0.38, rock_path, true, Vector3(0.82, 0.40, 0.68))


func _add_opening_dirt_trail(node_name: String, trail_position: Vector3, width: float, length: float, rotation_y: float = 0.0) -> void:
	var trail := MeshInstance3D.new()
	trail.name = node_name
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(width, length)
	mesh.subdivide_width = 2
	mesh.subdivide_depth = maxi(2, roundi(length * 0.35))
	trail.mesh = mesh
	# Ground the trail to the terrain to avoid floating plane overlay appearance
	trail.position = _terrain_grounded_position(trail_position)
	trail.rotation.y = rotation_y
	trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# A feathered PBR edge prevents this curated route from reading as a hard
	# brown rectangle stamped over the Terrain3D grass.
	var material := ShaderMaterial.new()
	material.shader = ADVENTURE_PATH_SHADER
	material.set_shader_parameter("detail_albedo", PBR_DETAIL_ALBEDO)
	material.set_shader_parameter("detail_normal", PBR_DETAIL_NORMAL)
	material.set_shader_parameter("detail_roughness", PBR_DETAIL_ROUGHNESS)
	# The old warm-beige tint multiplied into the photographic earth texture and
	# rendered as a pale runway. A compact courtyard needs visibly packed soil.
	material.set_shader_parameter("earth_color", Color(0.34, 0.24, 0.14, 1.0))
	material.set_shader_parameter("detail_scale", 3.2)
	trail.material_override = material
	add_child(trail)


## A compact north-bank courtyard turns the bridge exit into a legible place:
## it has a ground surface, a front-facing home, utility silhouettes and an
## alternate forest route. It is intentionally one authored 30–50m beat, not
## a new procedural scatter layer.
func _build_opening_courtyard() -> void:
	var courtyard := MeshInstance3D.new()
	courtyard.name = "OpeningBridgeCourtyard"
	var mesh := CylinderMesh.new()
	mesh.top_radius = 8.2
	mesh.bottom_radius = 8.0
	mesh.height = 0.035
	mesh.radial_segments = 20
	courtyard.mesh = mesh
	courtyard.position = _terrain_grounded_position(Vector3(9.0, 0.035, -39.5))
	courtyard.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := ShaderMaterial.new()
	material.shader = ADVENTURE_PATH_SHADER
	material.set_shader_parameter("detail_albedo", PBR_DETAIL_ALBEDO)
	material.set_shader_parameter("detail_normal", PBR_DETAIL_NORMAL)
	material.set_shader_parameter("detail_roughness", PBR_DETAIL_ROUGHNESS)
	material.set_shader_parameter("earth_color", Color(0.30, 0.20, 0.11, 1.0))
	material.set_shader_parameter("detail_scale", 2.6)
	material.set_shader_parameter("edge_feather", 0.08)
	courtyard.material_override = material
	add_child(courtyard)

	# Use the same textured village family as the enterable house. These are
	# landmark silhouettes with compact, matching physical footprints—not random
	# decorations sprinkled into the lawn.
	_add_visual_asset("OpeningCourtyardWagon", Vector3(18.8, 0.0, -36.5), Vector3.ONE * 1.12,
		-0.55, QUATERNIUS_VILLAGE + "Prop_Wagon.gltf", true, Vector3(2.5, 1.5, 1.65))
	_add_visual_asset("OpeningCourtyardCrate", Vector3(17.0, 0.0, -42.2), Vector3.ONE * 1.05,
		0.28, QUATERNIUS_VILLAGE + "Prop_Crate.gltf", true, Vector3(0.92, 0.86, 0.92))
	for index in 2:
		_add_visual_asset("OpeningCourtyardFence_%d" % index,
			Vector3(20.4, 0.0, -36.7 - float(index) * 5.9), Vector3.ONE,
			PI * 0.5, QUATERNIUS_VILLAGE + "Prop_WoodenFence_Extension2.gltf", true,
			Vector3(0.34, 1.25, 3.2))

	# The first trial used a plaster wall arch here; the live frame showed it as
	# an unrelated bare prefab. Use the same Quaternius nature family as the
	# opening grove instead. Two real trunks make a natural, colliding forest threshold
	# while leaving an honest four-metre walking gap.
	var gateway_left_path := "res://data/models/quaternius/nature/CommonTree_4.fbx"
	var gateway_right_path := "res://data/models/quaternius/nature/PineTree_4.fbx"
	var gateway_left_scale := 3.15
	var gateway_right_scale := 3.35
	_add_visual_asset("OpeningForestGatewayTreeL", Vector3(-18.0, 0.0, -42.2), Vector3.ONE * gateway_left_scale,
		0.18, gateway_left_path, true,
		OPENING_FOREST_TREE_COLLISION_PROFILES[gateway_left_path] as Vector3)
	_add_visual_asset("OpeningForestGatewayTreeR", Vector3(-12.0, 0.0, -42.2), Vector3.ONE * gateway_right_scale,
		-0.32, gateway_right_path, true,
		OPENING_FOREST_TREE_COLLISION_PROFILES[gateway_right_path] as Vector3)
	_add_opening_dirt_trail("OpeningTrailForestGateway", Vector3(-8.2, 0.035, -39.4),
		2.65, 14.0, -1.96)


## The starting camera looks down the bridge route (-Z).  Keep a human-scale
## shelter in its forward-right third and close the far bank with a proper
## treeline/landmark layer; otherwise the 2.4km terrain correctly exists but
## reads as a tiny empty test field in the first screenshot.
func _build_opening_sightline_layer() -> void:
	# A small yard creates a middle-distance destination before the child reaches
	# the house. It is deliberately outside the central bridge lane.
	_add_visual_asset("OpeningYardWell", Vector3(21.0, 0.0, -43.0), Vector3.ONE * 1.8,
		0.2, KAYKIT_BUILDER + "well.gltf.glb", true, Vector3(2.3, 2.0, 2.3))
	_add_visual_asset("OpeningYardFarm", Vector3(27.0, 0.0, -53.0), Vector3.ONE * 1.6,
		0.0, KAYKIT_BUILDER + "farm_plot.gltf.glb", true, Vector3(5.0, 0.8, 4.0))
	_add_visual_asset("OpeningYardFence", Vector3(21.0, 0.0, -54.0), Vector3.ONE * 2.4,
		PI * 0.5, KENNEY_NK + "fence_simple.glb", true, Vector3(0.35, 1.4, 4.8))

	# The large forest silhouette sits beyond the river and frames, rather than
	# blocks, the bridge. These are view-only trees: collision belongs to the
	# traversable forest farther out, not to a distant backdrop.  They are placed
	# as irregular masses rather than a ruler-straight tree grid, which was making
	# the large island read like a miniature test board from the opening camera.
	var backdrop_tree_paths := OPENING_FOREST_TREE_PATHS
	var backdrop_clusters := [
		Vector3(-118.0, 0.0, -118.0), Vector3(-72.0, 0.0, -126.0),
		Vector3(42.0, 0.0, -126.0), Vector3(104.0, 0.0, -120.0),
	]
	var backdrop_rng := RandomNumberGenerator.new()
	backdrop_rng.seed = hash("%s_opening_backdrop_clusters" % PROCEDURAL_GENERATOR_VERSION)
	for cluster_index in backdrop_clusters.size():
		var cluster_center: Vector3 = backdrop_clusters[cluster_index]
		var tree_count := 2 + cluster_index % 2
		for tree_index in tree_count:
			var position := cluster_center + Vector3(
				backdrop_rng.randf_range(-12.0, 12.0), 0.0,
				backdrop_rng.randf_range(-8.0, 8.0))
			# Keep the bridge and home routes visible; density frames the journey,
			# it must not create a wall directly in front of the child.
			if absf(position.x) < 12.0 and position.z > -96.0:
				continue
			# These are a distant forest mass, not toy trees standing on the
			# horizon. Their true 12–20m silhouette supplies travel scale without
			# colliding with the bridge route.
			var scale := backdrop_rng.randf_range(1.20, 1.90)
			var backdrop_tree := _add_visual_asset(
				"opening_backdrop_tree_%d_%d" % [cluster_index, tree_index], position,
				Vector3.ONE * scale, backdrop_rng.randf_range(0.0, TAU),
				String(backdrop_tree_paths[backdrop_rng.randi_range(0, backdrop_tree_paths.size() - 1)]), false)
			if backdrop_tree != null:
				var green := CHOYCE_SOFT_GREEN.darkened(0.4) if position.z < -100.0 else CHOYCE_SOFT_GREEN.darkened(0.2)
				_apply_toon_tint(backdrop_tree, green)

	# The physical Terrain3D mountains now provide the distant silhouette. Keep
	# one human-scale windmill destination instead of a giant floating kit prop.
	_add_visual_asset("OpeningDistantWindmill", Vector3(78.0, 0.0, -118.0),
		Vector3.ONE * 1.25, -0.18, KAYKIT_BUILDER + "mill.gltf.glb", false)
	_add_route_lantern("BridgeSouthLantern", Vector3(-3.25, 0.0, -14.5))
	_add_route_lantern("BridgeNorthLantern", Vector3(3.25, 0.0, -33.5))
	_add_route_lantern("HomeLantern", Vector3(9.0, 0.0, -52.0))


## Terrain3D gives the island genuine rolling relief, but a child-height camera
## needs a few textured, dimensional anchors to read that scale. These
## deliberately asymmetric outcrops sit outside the 36m bridge lane and the
## home approach; they turn the far banks into a rocky woodland edge rather
## than a smooth green stage while keeping all collision close to the rendered
## mass instead of creating a broad invisible wall.
## The opening needs a real forest volume behind the curated bridge, not a few
## decorative tree silhouettes on a flat horizon.  This deterministic mass is
## deliberately wide and deep (rather than a narrow hedge): it gives the
## player a believable woodland edge to walk into after reaching the north
## bank, provides scale for the 5.76km² terrain, and hides the technical map
## boundary from the first third-person frame.  The central 36m route remains
## open for the house/bridge composition.
func _build_opening_forest_mass(seed_source: String) -> void:
	# A forest is read through overlapping canopy layers and irregular edges, not
	# a uniform scatter across a huge rectangle.  The previous 54 trees were
	# technically broad, but far enough apart that the live camera still saw a
	# lawn with isolated props.  These eight seeded groves make a continuous
	# woodland that starts just beyond the homestead, widens into the horizon,
	# and leaves the bridge / two paths as intentional discovery corridors.
	const FOREST_MASS_TREES_PER_CLUSTER := 12
	var forest_rng := RandomNumberGenerator.new()
	forest_rng.seed = hash("%s_opening_forest_mass_v3" % seed_source)
	# Do not reuse the close-up oak in every forest layer: the same rounded
	# canopy repeated at any distance was the main reason the world read as a
	# toy board. These ready-made CC0 trees have distinct broadleaf, birch and
	# conifer silhouettes while the named-surface material pass keeps foliage
	# and bark in the opening's restrained palette.
	var tree_paths := OPENING_FOREST_TREE_PATHS
	var forest_clusters: Array[Vector3] = [
		# The first forest masses begin just beyond the north bank (z=-33).
		# Bring them closer to fill the gap and frame the bridge exit into woodland.
		# 10-15m behind the river creates a credible tree line without crowding the crossing.
		# Close forest: directly behind the river bank (z=-33) for immediate framing
		Vector3(-29.0, 0.0, -36.0), Vector3(-29.0, 0.0, -39.0),
		Vector3(30.0, 0.0, -37.0), Vector3(30.0, 0.0, -40.0),
		# Mid forest: transition zone
		Vector3(-29.0, 0.0, -46.0), Vector3(-29.0, 0.0, -56.0),
		Vector3(30.0, 0.0, -48.0),
		Vector3(-56.0, 0.0, -72.0), Vector3(57.0, 0.0, -74.0),
		Vector3(-88.0, 0.0, -106.0), Vector3(88.0, 0.0, -109.0),
		Vector3(-124.0, 0.0, -148.0), Vector3(124.0, 0.0, -150.0),
		Vector3(-164.0, 0.0, -192.0), Vector3(164.0, 0.0, -195.0),
		Vector3(164.0, 0.0, -205.0),
		# Additional near clusters to establish immediate woodland edge
		Vector3(-42.0, 0.0, -41.0), Vector3(42.0, 0.0, -43.0),
		Vector3(-42.0, 0.0, -52.0), Vector3(42.0, 0.0, -54.0),
	]
	for cluster_index in forest_clusters.size():
		var cluster_center := forest_clusters[cluster_index]
		for tree_index in range(FOREST_MASS_TREES_PER_CLUSTER):
			# The more distant groves have a larger footprint.  That creates a
			# believable woodland boundary instead of identical circular clumps.
			# distance_factor: 0.0 for clusters at z=-35, 1.0 for clusters at z=-55
			var distance_factor := minf(1.0, maxf(0.0, (-cluster_center.z - 35.0) / 20.0))
			var spread_x := forest_rng.randf_range(8.0, 10.0 + distance_factor * 12.0)
			# Z spread: toward river (south/positive Z) is limited to 3m for close clusters,
			# away from river (north/negative Z) extends up to 18m for distant clusters.
			# This keeps trees north of the river (z <= -33) while allowing natural spread.
			var spread_z_south := minf(3.0 + distance_factor * 7.0, 10.0)  # limit toward river
			var spread_z_north := 10.0 + distance_factor * 8.0  # spread away from river
			var position := cluster_center + Vector3(
				forest_rng.randf_range(-spread_x, spread_x), 0.0,
				forest_rng.randf_range(-spread_z_north, spread_z_south))
			# Clamp to keep forest trees north of the river (z <= -33). The north bank is at z=-33.
			position.z = minf(position.z, -33.0)
			# Never close the child-scale 20m bridge approach; the deeper silhouette
			# can connect behind it without becoming an invisible collision wall.
			if absf(position.x) < 18.0 and position.z > -132.0:
				continue
			# These source trees are 1.5–3.6m at unit scale. The forest must read
			# as a large place a child can enter, so scale its interior canopy to a
			# 7–14m adult range instead of shrinking it below the player/house.
			var scale := forest_rng.randf_range(2.45, 3.95)
			var tree_path := String(tree_paths[forest_rng.randi_range(0, tree_paths.size() - 1)])
			# Collision profiles are already world-space trunk measurements.
			# `_add_visual_asset()` inverse-scales the collision child, so multiplying
			# this by the decorative canopy scale created 3–5m invisible walls around
			# otherwise enterable trees. Keep the physical contact at the bark.
			var trunk_collision := OPENING_FOREST_TREE_COLLISION_PROFILES.get(tree_path, Vector3(1.0, 11.0, 1.0)) as Vector3
			var tree := _add_visual_asset(
				"OpeningForestMass_%02d_%02d" % [cluster_index, tree_index],
				position,
				Vector3.ONE * scale,
				forest_rng.randf_range(0.0, TAU),
				tree_path,
				true,
				trunk_collision)
			if tree != null:
				# Dense trunks stay physically honest for gathering/navigation while
				# foliage remains an authored visual layer on the ready-made model.
				tree.set_meta("forest_mass", true)


## Teach one simple sandbox loop beyond the bridge: see a real log and rock,
## use the matching pictured tool, collect material, then build or craft at
## the nearby home. They are ready-made Quaternius meshes with tight physical
## footprints, never the rejected cube-tree/ore placeholders.
func _build_opening_harvest_trail() -> void:
	_add_opening_harvest_resource(
		"OpeningHarvestWood", "wood_oak", Vector3(-23.5, 0.0, -55.5),
		QUATERNIUS_NATURE + "WoodLog_Moss.fbx", Vector3(1.75, 1.75, 1.75),
		Vector3(2.35, 1.28, 1.18), "Znajdź drewno", "gather_wood")
	_add_opening_harvest_resource(
		"OpeningHarvestStone", "ore_iron", Vector3(-8.2, 0.0, -61.0),
		QUATERNIUS_NATURE + "Rock_Moss_4.fbx", Vector3(1.55, 1.55, 1.55),
		Vector3(1.60, 1.36, 1.48), "Rozbij skałę", "gather_stone")


func _add_opening_harvest_resource(node_name: String, item_id: String, position: Vector3,
		asset_path: String, asset_scale: Vector3, collision_size: Vector3,
		prompt: String, action: String) -> void:
	var visual := _add_visual_asset(node_name, position, asset_scale, 0.35,
		asset_path, true, collision_size)
	var anchor := _add_interaction_anchor(node_name + "Anchor", position + Vector3(0.0, 0.35, 0.0),
		"E  %s" % prompt, action)
	anchor.set_meta("resource_item_id", item_id)
	anchor.set_meta("resource_visual", visual)
	anchor.set_meta("resource_action", action)


## Small warm pools make the route readable during the Sky3D night without
## turning daytime into a flat over-lit scene. They also make the bridge, home
## and cave recognizable landmarks from a child-height third-person camera.
func _add_route_lantern(node_name: String, position: Vector3) -> void:
	var light := OmniLight3D.new()
	light.name = node_name
	light.position = _terrain_grounded_position(position) + Vector3(0.0, 2.1, 0.0)
	light.light_color = Color(1.0, 0.62, 0.32)
	light.light_energy = 1.35
	light.omni_range = 8.5
	light.shadow_enabled = false
	add_child(light)


func _build_adventure_regions(seed_source: String) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(seed_source)

	# These are actual regional destinations, not the first-frame prop palette.
	# The old 40 m placements overlaid every biome in one sightline and made the
	# 5.76 km² island look like a tiny test board.  Each region is now a real
	# walk/ride away, while the composed bridge + starter home remain readable.
	var village_center := Vector3(300, 0, 250)
	var forest_center := Vector3(-400, 0, 250)
	var beach_center := Vector3(-320, 0, -350)
	var cave_center := Vector3(360, 0, -400)

	# Houses and a little village — destination geometry first, then props.
	_add_visual_asset("dom", village_center + Vector3(-5, 0, -5), Vector3.ONE * 1.95, 0.2)
	_add_visual_asset("młyn", village_center + Vector3(7, 0, 3), Vector3.ONE * 1.7, -0.45)
	_add_visual_asset("studnia", village_center + Vector3(1, 0, 2), Vector3.ONE * 1.3, 0.0)
	_add_visual_asset("gospodarstwo", village_center + Vector3(6, 0, -6), Vector3.ONE * 1.35, 0.0)
	_spawn_region_props("village", village_center, 22.0,
		["Stodoła", "Wiatrak", "Płot", "Koryto", "Skrzynia", "Trawa duża"], 16, rng)
	_spawn_region_props("village_animals", village_center, 17.0, ["Kura"], 5, rng, true)
	_add_visual_asset("drogowskaz", village_center + Vector3(-12, 0, 2), Vector3.ONE * 0.9, 1.2)
	
	# VS-025: Add training equipment interaction areas
	_build_training_equipment()
	
	# VS-025: Add procedural food spawning in regions
	_build_procedural_food(rng)

	# A dense forest region gives the kid a reason to leave the central trail.
	# The sign and first resources remain close enough to invite discovery, but
	# the actual woods stretch hundreds of metres north-west instead of ending
	# after one decorative grove.
	_add_visual_asset("las", Vector3(-82, 0, 62), Vector3.ONE * 2.8, 0.0)
	_build_dense_forest_region(seed_source, forest_center)
	_spawn_region_props("forest", forest_center + Vector3(125, 0, -40), 22.0,
		["Dąb", "Dąb", "Kłoda", "Skała", "Grzyb", "Kwiaty", "Trawa duża"], 20, rng)
	_add_gatherable_resource("forest_wood_1", "wood_oak", forest_center + Vector3(24, 0, -14), "Kłoda", "Zbierz drewno", "gather_wood")
	_add_gatherable_resource("forest_wood_2", "wood_oak", forest_center + Vector3(32, 0, -2), "Kłoda", "Zbierz drewno", "gather_wood")
	_add_gatherable_resource("forest_wood_3", "wood_oak", forest_center + Vector3(18, 0, -25), "Dąb", "Zetnij drzewo", "gather_wood")
	_add_visual_asset("drogowskaz", forest_center + Vector3(110, 0, -38), Vector3.ONE * 0.9, -1.2)

	# A bright beach/lagoon region with authored sand/water tiles, boats,
	# shells, and palms.
	_add_visual_asset("łódka", beach_center + Vector3(-10, 0.15, 0), Vector3.ONE * 1.25, 0.4)
	_spawn_region_props("beach", beach_center, 24.0,
		["Palma", "Palma", "Rozgwiazda", "Perła", "Skała", "Skały piaskowe", "Trawa duża"], 18, rng)
	_add_visual_asset("drogowskaz", beach_center + Vector3(12, 0, 0), Vector3.ONE * 0.9, 0.0)

	# Cave entrance / ruins region. Use the Nature Kit's actual cave arch and a
	# side-bounded approach rather than calling a couple of rocks a cave. The
	# mouth stays physically open, leading into a small sheltered ore chamber.
	_build_cave_approach(cave_center)
	_spawn_region_props("cave", cave_center + Vector3(0, 0, 6), 16.0,
		["Mur", "Mur", "Kolumna", "Pochodnia", "Beczka", "Pajęczyna", "Skrzynia Skarbów", "Skała"], 16, rng)
	_add_gatherable_resource("cave_iron_1", "ore_iron", cave_center + Vector3(-6, 0, -6), "Skała z mchem", "Wydobądź kamień", "gather_stone")
	_add_gatherable_resource("cave_iron_2", "ore_iron", cave_center + Vector3(8, 0, -6), "Skała z mchem", "Wydobądź kamień", "gather_stone")
	_add_gatherable_resource("cave_iron_3", "ore_iron", cave_center + Vector3(13, 0, 8), "Skała z mchem", "Wydobądź kamień", "gather_stone")
	_add_visual_asset("drogowskaz", cave_center + Vector3(-12, 0, 6), Vector3.ONE * 0.9, 0.0)


func _build_cave_approach(center: Vector3) -> void:
	var cave_arch := KENNEY_NK + "cliff_cave_rock.glb"
	var cave_wall := KENNEY_NK + "cliff_blockCave_rock.glb"
	# The front arch is visual-only: its source mesh contains the opening. Narrow
	# side collisions preserve the walkable mouth instead of an invisible box
	# blocking a prop that visibly invites the player inside.
	_add_visual_asset("CaveEntranceArch", center, Vector3.ONE * 3.5, PI,
		cave_arch, false)
	_add_visual_asset("CaveApproachLeft", center + Vector3(-6.2, 0.0, 2.0), Vector3.ONE * 2.8,
		PI * 0.5, cave_wall, true, Vector3(2.0, 5.2, 5.0))
	_add_visual_asset("CaveApproachRight", center + Vector3(6.2, 0.0, 2.0), Vector3.ONE * 2.8,
		-PI * 0.5, cave_wall, true, Vector3(2.0, 5.2, 5.0))
	_add_visual_asset("CaveRearWall", center + Vector3(0.0, 0.0, 7.4), Vector3.ONE * 2.4,
		0.0, cave_wall, true, Vector3(10.0, 5.0, 1.2))
	# A low roof completes an immediately explorable chamber behind the opening.
	# Side/rear bodies above remain the authoritative collision contract.
	_add_visual_asset("CaveChamberRoof", center + Vector3(0.0, 4.0, 4.0), Vector3(4.6, 1.8, 3.6),
		0.0, KENNEY_NK + "cliff_top_rock.glb", false)
	_add_route_lantern("CaveLantern", center + Vector3(0.0, 0.0, 3.8))


func _add_gatherable_resource(id: String, item_id: String, position: Vector3, prop_name: String, prompt: String, action: String) -> void:
	var is_tree := action == "gather_wood"
	var is_food := item_id.begins_with("food_") or prop_name in ["Jabłko", "Jajko"]
	# Do not make an apple or egg share the rock/resource scale. Besides looking
	# absurd in the opening, the old 1.8m box made a tiny pickup feel like an
	# invisible wall. Food gets a hand-sized mesh and a tight collision proxy;
	# the forgiving interaction Area remains larger for young players.
	var scale := Vector3.ONE * (2.15 if is_tree else (0.46 if is_food else 1.25))
	var collision_size := Vector3(1.25, 3.8, 1.25) if is_tree else (Vector3(0.42, 0.42, 0.42) if is_food else Vector3(1.8, 1.4, 1.8))
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
	for gx in range(-16, 17):
		for gz in range(-12, 13):
			var fx := float(gx)
			var fz := float(gz)
			# Keep one generous diagonal trail plus irregular clearings. This is
			# dense enough to feel like a forest, but never a collision maze.
			if absf(fz - fx * 0.42) < 1.25 or (gx * 13 + gz * 7) % 29 == 0:
				continue
			var tree_position := center + Vector3(
				fx * 16.0 + rng.randf_range(-5.5, 5.5),
				0.0,
				fz * 16.0 + rng.randf_range(-5.5, 5.5))
			# Forest-region trees must dwarf the 1.8m player and overlap into a real
			# canopy. Their collision remains trunk-sized via _add_visual_asset.
			var tree_scale := rng.randf_range(3.2, 4.8)
			_add_visual_asset("dense_forest_tree_%d_%d" % [gx, gz], tree_position,
				Vector3.ONE * tree_scale, rng.randf_range(0.0, TAU),
				_prop_path_for_name("Dąb"), true, Vector3(1.55, 4.2, 1.55))
			if (gx + gz) % 2 == 0:
				_add_visual_asset("dense_forest_understory_%d_%d" % [gx, gz],
					tree_position + Vector3(3.0, 0.0, -2.5),
					Vector3.ONE * rng.randf_range(0.7, 1.1), rng.randf_range(0.0, TAU),
					_prop_path_for_name("Trawa duża"), true, Vector3(1.2, 1.0, 1.2))


func _build_food_spawn_points() -> void:
	# Food supports the sandbox loop, but raw apple/egg meshes around the player
	# spawn were reading as random bright render artefacts in the composition.
	# Keep the first discoveries a short walk down each route, not in the opening
	# hero frame or beside the wildlife/fence silhouette.
	_add_gatherable_resource("food_apple_1", "food_apple", Vector3(-360.0, 0, 212.0),
		"Jabłko", "Znajdź jabłko", "find_food")
	_add_gatherable_resource("food_apple_2", "food_apple", Vector3(-340.0, 0, 236.0),
		"Jabłko", "Znajdź jabłko", "find_food")
	_add_gatherable_resource("food_egg_1", "food_egg", Vector3(292.0, 0, 258.0),
		"Jajko", "Znajdź jajko", "find_food")
	
	# More food in the village area
	_add_gatherable_resource("food_apple_3", "food_apple", Vector3(292.0, 0, 244.0),
		"Jabłko", "Znajdź jabłko", "find_food")
	
	_add_gatherable_resource("food_egg_2", "food_egg", Vector3(302.0, 0, 252.0),
		"Jajko", "Znajdź jajko", "find_food")
	
	_add_gatherable_resource("food_apple_4", "food_apple", Vector3(310.0, 0, 242.0),
		"Jabłko", "Znajdź jabłko", "find_food")


func _build_training_equipment() -> void:
	# VS-025: Add training equipment interaction areas
	# These create Area3D zones that trigger training when the player enters
	# and presses the appropriate action
	
	# Jump training area near the opening
	_add_interaction_anchor("train_jump_1", Vector3(-15.0, 0, -5.0), "E  Trenuj skok", "train_jump")
	
	# Run training area (open space)
	_add_interaction_anchor("train_run_1", Vector3(20.0, 0, -5.0), "E  Trenuj bieg", "train_run")
	
	# Climb training area near the forest
	_add_interaction_anchor("train_climb_1", Vector3(-30.0, 0, 20.0), "E  Trenuj wspinaczkę", "train_climb")
	
	# Push training area near the village
	_add_interaction_anchor("train_push_1", Vector3(40.0, 0, 30.0), "E  Trenuj pchanie", "train_push")
	
	# Pull training area
	_add_interaction_anchor("train_pull_1", Vector3(45.0, 0, 45.0), "E  Trenuj ciągnięcie", "train_pull")
	
	# Balance training area
	_add_interaction_anchor("train_balance_1", Vector3(35.0, 0, 48.0), "E  Trenuj równowagę", "train_balance")


func _build_procedural_food(rng: RandomNumberGenerator) -> void:
	# VS-025: Add procedural food spawning in the forest region
	# Spawns additional food items procedurally
	
	var food_positions := [
		Vector3(-370.0, 0, 220.0),
		Vector3(-380.0, 0, 240.0),
		Vector3(-365.0, 0, 205.0),
		Vector3(-390.0, 0, 225.0)
	]
	
	var food_types := ["Jabłko", "Jajko"]
	
	for i in food_positions.size():
		var pos: Vector3 = food_positions[i] as Vector3
		var food_type: String = String(food_types[rng.randi_range(0, food_types.size() - 1)])
		var food_id := "food_%s_%d" % [food_type.to_lower(), i + 10]
		var item_id := "food_%s" % food_type.to_lower()
		var prompt := "Znajdź %s" % food_type.to_lower()
		_add_gatherable_resource(food_id, item_id, pos, food_type, prompt, "find_food")


func _build_adventure_route() -> void:
	# A bridge, camp, and a visible guide destination make the route feel
	# authored even before the player discovers the four regional biomes. The
	# player walks directly on the continuous world floor rather than on tile
	# plates that reveal the construction grid.
	_add_water_crossing()
	_build_opening_bridge()
	_add_visual_asset("obóz bazowy", Vector3(0, 0, -12), Vector3.ONE * 1.25, 0.0)
	_add_visual_asset("drogowskaz", Vector3(-4, 0, -8), Vector3.ONE * 0.9, 0.35)


## A physical, clearly readable river crossing. The supplied covered-bridge
## mesh is a tiny decorative prop whose stretched roof read as a grey block;
## this has an actual 20m deck, planks and rails at child walking scale.
func _build_opening_bridge() -> void:
	# The single ready-made bridge model is a tiny decorative asset and failed to
	# render reliably at this river span.  Build a physical, PBR modular bridge
	# from the same supplied Quaternius kit as the starter home instead: every
	# deck tile and rail is visible at child walking scale and matches collision.
	var floor_tile := QUATERNIUS_VILLAGE + "Floor_WoodLight.gltf"
	var fence_segment := QUATERNIUS_VILLAGE + "Prop_WoodenFence_Extension2.gltf"
	var approach_stair := QUATERNIUS_VILLAGE + "Stairs_Exterior_NoFirstStep.gltf"
	for x in [-1.0, 1.0]:
		for z in range(-33, -13, 2):
			_add_visual_asset("OpeningBridgeDeckTile_%d_%d" % [int(x), abs(z)],
				Vector3(x, 0.69, float(z)), Vector3.ONE, 0.0, floor_tile, false)
	# A child capsule stopped on the former decorative step mesh before reaching
	# the deck: its generic proxy had a vertical lip. These shallow visible wood
	# ramps share the exact convex collision surface, so the bridge can be walked
	# in either direction without an invisible helper or a step-sized wall.
	# Overlap each high end 70cm into the deck. Meeting the deck exactly at its
	# vertical collision face left a capsule perched at the seam; the overlap
	# makes the ramp surface authoritative before the child reaches that edge.
	_add_opening_bridge_ramp("OpeningBridgeRampSouth", Vector3(0.0, 0.0, -12.8), true, true)
	_add_opening_bridge_ramp("OpeningBridgeRampNorth", Vector3(0.0, 0.0, -35.2), false, true)
	_add_opening_bridge_walk_surface()
	# The supplied stair model gives the shallow ramps a finished wooden silhouette.
	# It stays visual-only because the continuous walk surface below is the one
	# physical contract; duplicating its generic box was the original blocker.
	for x in [-1.1, 1.1]:
		_add_visual_asset("OpeningBridgeSouthApproach_%s" % str(x), Vector3(x, -0.31, -11.9),
			Vector3(1.0, 1.0, 1.8), 0.0, approach_stair, false)
		_add_visual_asset("OpeningBridgeNorthApproach_%s" % str(x), Vector3(x, -0.31, -36.1),
			Vector3(1.0, 1.0, 1.8), PI, approach_stair, false)
	for side in [-1.0, 1.0]:
		for z in [-32.0, -28.0, -24.0, -20.0, -16.0]:
			# Rail segments carry their own collision; no separate invisible box needed.
			# This ensures collision matches the visible fence geometry per VS-040.
			# Each visible rail owns a narrow matching physical profile.  Keep the
			# central deck fully walkable while stopping a child from stepping through
			# an apparently solid fence into the river.
			_add_visual_asset("OpeningBridgeRail_%s_%d" % ["L" if side < 0.0 else "R", abs(int(z))],
				Vector3(side * 1.92, 0.69, z), Vector3.ONE, PI * 0.5, fence_segment, true,
				Vector3(3.55, 1.18, 0.22))
	_build_opening_bridge_shoreline()


## The opening river is intentionally straight for streamed-world simplicity,
## but the bridge view must not expose two bare rectangular banks. These few
## asymmetric clusters are curated local shoreline dressing; the long-distance
## river bank remains a low-cost procedural system outside the hero frame.
func _build_opening_bridge_shoreline() -> void:
	# These sit inside the first camera frame, so use actual irregular rock
	# meshes. The earlier cliff-block variants were square construction modules;
	# even with a texture they read as a beige debug cube beside the bridge.
	var stone_paths := [
		KENNEY_NK + "rock_largeD.glb",
		KENNEY_NK + "rock_largeC.glb",
		KENNEY_NK + "rock_largeF.glb",
	]
	var clusters := [
		[Vector3(-4.5, -0.10, -13.7), 1.05, 0.30, 0],
		[Vector3(4.8, -0.08, -14.3), 0.82, -1.05, 2],
		[Vector3(-5.2, -0.10, -35.0), 0.95, 2.20, 1],
		[Vector3(4.6, -0.08, -34.7), 1.16, 0.72, 0],
		[Vector3(-7.5, -0.10, -17.0), 0.64, 1.48, 2],
		[Vector3(7.2, -0.10, -31.6), 0.70, -0.40, 2],
	]
	for index in clusters.size():
		var entry: Array = clusters[index]
		var position: Vector3 = entry[0]
		var scale := float(entry[1])
		var rotation := float(entry[2])
		var path := String(stone_paths[int(entry[3])])
		_add_visual_asset("OpeningBridgeShore_%d" % index, position,
			Vector3.ONE * scale, rotation, path, true, Vector3(1.5 * scale, 1.1 * scale, 1.5 * scale))
	_build_opening_riverbank_habitat()


## Keep the bridge as a strong, readable route, but give both banks enough
## irregular, tactile detail that the water reads as a place in the world rather
## than a blue strip between two empty grass fields.  Positions deliberately
## sit outside the 4.4m bridge/ramp corridor and all solid pieces use their
## actual footprint rather than the old oversized generic collider.
func _build_opening_riverbank_habitat() -> void:
	var rock_path := KENNEY_NK + "rock_smallFlatC.glb"
	var large_rock_paths := [
		KENNEY_NK + "rock_largeB.glb",
		KENNEY_NK + "rock_largeE.glb",
	]
	var log_path := KENNEY_NK + "log_large.glb"
	var bush_path := KENNEY_NK + "plant_bushLarge.glb"
	var solid_details := [
		# south bank — framed on the outside of the player-to-bridge approach
		["OpeningRiverbankRockSouthWest", Vector3(-7.4, -0.06, -13.1), 0.92, 0.42, rock_path, Vector3(1.15, 0.62, 0.92)],
		["OpeningRiverbankLogSouthEast", Vector3(7.8, -0.05, -12.4), 0.95, -0.80, log_path, Vector3(1.55, 0.72, 0.72)],
		["OpeningRiverbankRockSouthEast", Vector3(10.2, -0.08, -11.6), 0.76, 1.40, rock_path, Vector3(0.95, 0.52, 0.80)],
		# north bank — placed beyond the ramp, leaving the house/yard route clear
		["OpeningRiverbankLogNorthWest", Vector3(-8.4, -0.05, -36.5), 1.02, 0.86, log_path, Vector3(1.65, 0.72, 0.72)],
		# Keep the north-east rock clear of the actual bridge-to-door courtyard
		# turn. Its old x=7.9 footprint forced the player into the house wall.
		["OpeningRiverbankRockNorthEast", Vector3(16.5, -0.08, -35.8), 0.98, -0.36, rock_path, Vector3(1.18, 0.66, 0.95)],
		["OpeningRiverbankRockNorthFar", Vector3(-13.2, -0.08, -39.5), 0.84, 2.08, rock_path, Vector3(1.0, 0.56, 0.86)],
	]
	for entry_variant in solid_details:
		var entry: Array = entry_variant
		_add_visual_asset(String(entry[0]), entry[1], Vector3.ONE * float(entry[2]),
			float(entry[3]), String(entry[4]), true, entry[5])

	var foliage_positions := [
		Vector3(-10.1, 0.0, -11.5), Vector3(10.5, 0.0, -11.7),
		Vector3(-12.7, 0.0, -10.8), Vector3(12.0, 0.0, -10.9),
		Vector3(-11.2, 0.0, -38.2), Vector3(11.0, 0.0, -38.0),
		Vector3(-15.5, 0.0, -39.0), Vector3(14.4, 0.0, -39.4),
	]
	for index in foliage_positions.size():
		var position: Vector3 = foliage_positions[index]
		# Dense bushes establish the bank edge; the surrounding cards add visual
		# texture without producing a wall of physics around a child-scale path.
		_add_visual_asset("OpeningRiverbankBush_%d" % index, position,
			Vector3.ONE * (1.05 + float(index % 3) * 0.12), float(index) * 0.74,
			bush_path, true, Vector3(1.10, 1.0, 1.10))

	# A riverbank needs a dense low/mid/vertical plant sequence, not a handful
	# of single props on a flat lawn. These larger asymmetric thickets begin in
	# the visible foreground and continue across both banks, but all remain
	# outside the 4.4m deck/ramp corridor. The anchored bush and rock carry
	# modest matching contact, while surrounding grass/flowers stay walk-through
	# dressing rather than forming a frustrating invisible wall.
	var bank_thickets := [
		[Vector3(-10.2, 0.0, -7.8), 1.72, 0.30, 0],
		[Vector3(10.6, 0.0, -8.6), 1.86, -0.58, 1],
		[Vector3(-12.8, 0.0, -10.6), 1.95, 1.12, 0],
		[Vector3(13.6, 0.0, -10.8), 1.78, -1.46, 1],
		[Vector3(-13.5, 0.0, -39.2), 2.10, 0.72, 1],
		[Vector3(13.0, 0.0, -40.4), 1.92, -1.02, 0],
		[Vector3(-19.0, 0.0, -43.5), 2.18, 1.84, 0],
		[Vector3(19.8, 0.0, -45.0), 2.06, -2.22, 1],
	]
	for index in bank_thickets.size():
		var entry: Array = bank_thickets[index]
		var thicket_position: Vector3 = entry[0]
		var thicket_scale := float(entry[1])
		var thicket_rotation := float(entry[2])
		var large_rock_path := String(large_rock_paths[int(entry[3])])
		_add_visual_asset("OpeningRiverbankThicketBush_%d" % index,
			thicket_position, Vector3.ONE * thicket_scale, thicket_rotation,
			bush_path, true, Vector3(1.28 * thicket_scale, 1.10, 1.12 * thicket_scale))
		_add_visual_asset("OpeningRiverbankThicketRock_%d" % index,
			thicket_position + Vector3(1.34, -0.08, 0.58), Vector3.ONE * (thicket_scale * 0.58),
			thicket_rotation + 1.08, large_rock_path, true,
			Vector3(1.15 * thicket_scale, 0.78 * thicket_scale, 0.94 * thicket_scale))


func _add_opening_bridge_ramp(node_name: String, ramp_position: Vector3, rises_toward_negative_z: bool, visual_only: bool = false) -> void:
	var ramp := Node3D.new() if visual_only else StaticBody3D.new()
	ramp.name = node_name
	ramp.position = ramp_position
	# A rotated BoxShape3D still has a vertical 22cm leading face. CharacterBody3D
	# treats that as a wall. Use a proper convex wedge, whose low end meets the
	# terrain at 2cm and whose high end meets the raised deck at 69cm.
	var half_width := 2.2
	var half_length := 1.9
	var deck_height := 0.69
	var low_height := 0.02
	var negative_z_height := deck_height if rises_toward_negative_z else low_height
	var positive_z_height := low_height if rises_toward_negative_z else deck_height
	var points := PackedVector3Array([
		Vector3(-half_width, 0.0, -half_length),
		Vector3(half_width, 0.0, -half_length),
		Vector3(-half_width, 0.0, half_length),
		Vector3(half_width, 0.0, half_length),
		Vector3(-half_width, negative_z_height, -half_length),
		Vector3(half_width, negative_z_height, -half_length),
		Vector3(-half_width, positive_z_height, half_length),
		Vector3(half_width, positive_z_height, half_length),
	])
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = _create_opening_bridge_ramp_mesh(points)
	# The supplied stair mesh above owns the finished visible silhouette. This
	# helper contributes the continuous collision profile only; showing its raw
	# wedge made the bridge look like an unfinished construction block.
	mesh_instance.visible = false
	ramp.add_child(mesh_instance)
	if not visual_only:
		var collision := CollisionShape3D.new()
		var shape := ConvexPolygonShape3D.new()
		shape.points = points
		collision.shape = shape
		ramp.add_child(collision)
	add_child(ramp)


## One continuous collision skin covers both visible ramps and the deck. Three
## separate boxes/wedges necessarily exposed a vertical face at their joins;
## a concave static surface has the exact same continuous profile a walker sees.
func _add_opening_bridge_walk_surface() -> void:
	var body := StaticBody3D.new()
	body.name = "OpeningBridgeDeck"
	var faces := PackedVector3Array()
	var half_width := 2.0
	var sections := [
		[-10.9, 0.0, -14.7, 0.69],
		[-14.7, 0.69, -33.3, 0.69],
		[-33.3, 0.69, -37.1, 0.0],
	]
	for section_variant in sections:
		var section: Array = section_variant
		var near_z := float(section[0])
		var near_y := float(section[1])
		var far_z := float(section[2])
		var far_y := float(section[3])
		var near_left := Vector3(-half_width, near_y, near_z)
		var near_right := Vector3(half_width, near_y, near_z)
		var far_left := Vector3(-half_width, far_y, far_z)
		var far_right := Vector3(half_width, far_y, far_z)
		faces.append_array(PackedVector3Array([near_left, far_left, near_right, near_right, far_left, far_right]))
	var collision := CollisionShape3D.new()
	var shape := ConcavePolygonShape3D.new()
	shape.data = faces
	collision.shape = shape
	body.add_child(collision)
	add_child(body)


func _create_opening_bridge_ramp_mesh(points: PackedVector3Array) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var triangles := [
		[0, 2, 3], [0, 3, 1], # bottom
		[4, 5, 7], [4, 7, 6], # sloped top
		[0, 1, 5], [0, 5, 4], # negative-Z end
		[2, 6, 7], [2, 7, 3], # positive-Z end
		[0, 4, 6], [0, 6, 2], # left side
		[1, 3, 7], [1, 7, 5], # right side
	]
	for triangle in triangles:
		for vertex_index in triangle:
			surface.add_vertex(points[int(vertex_index)])
	surface.generate_normals()
	return surface.commit()


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
	ocean.material_override = _make_toon_material(CHOYCE_WATER_DEEP)
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


## Evidence and cinematic hand-offs must wait until the opening's initially
## streamed envelope is complete. A shell switch or fixed short timeout can
## otherwise capture an empty field while its nearby cells still stream in.
func is_opening_generation_settled() -> bool:
	return _procedural_build_queue.is_empty() and _procedural_build_jobs.is_empty()


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
			# A large forest comes from broad irregular clusters, not 15m copies
			# of a single diorama tree. The old 2.25–3.35 multiplier produced
			# canopies above the camera and collision that felt disconnected from
			# their trunk. Keep a readable 3–7m individual range instead.
			# Calibrate the kit's diorama source to a real 8–14m tree canopy. The
			# collider below stays trunk-sized, so density adds atmosphere rather
			# than broad invisible walls.
			scale *= rng.randf_range(2.8, 4.4)
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
		# A 32m cell needs a canopy cluster, not one decorative tree.
		return rng.randi_range(5, 7)
	if biome_value < -0.38:
		return 2 if detail_value < 0.15 else 3
	return rng.randi_range(3, 4)


func _is_reserved_adventure_region(position: Vector3) -> bool:
	# The first 380m is a deliberately authored journey. The initial streaming
	# envelope is wider than the camera's immediate field; allowing generic
	# chunks to decorate its outer cells covered the horizon in tiny unrelated
	# props. Macro scatter begins only once the player has reached a real route.
	if position.length() < OPENING_COMPOSED_RADIUS_M:
		return true
	for region in [
		[Vector3(300, 0, 250), 62.0],
		[Vector3(-400, 0, 250), 280.0],
		[Vector3(-320, 0, -350), 62.0],
		[Vector3(360, 0, -400), 58.0],
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
	# Put the only enterable first-slice home at the north end of the bridge. It
	# stays to the right of the 4m bridge lane, but is now the clear destination
	# in the opening view rather than a tiny isolated prop at screen-right.
	var center := Vector3(12, 0, -46)
	# The bridge approaches from +Z, so the working doorway/facade belongs on
	# that side. The former layout put a sealed rear wall directly in front of a
	# child who had just crossed the bridge.
	_add_box_obstacle("HomeBackWall", center + Vector3(0, 2.2, -5.85), Vector3(12.5, 4.4, 0.32), Color.TRANSPARENT, false)
	_add_box_obstacle("HomeLeftWall", center + Vector3(-6.1, 2.2, 0), Vector3(0.32, 4.4, 11.7), Color.TRANSPARENT, false)
	_add_box_obstacle("HomeRightWall", center + Vector3(6.1, 2.2, 0), Vector3(0.32, 4.4, 11.7), Color.TRANSPARENT, false)
	# Match the full visible facade: two 5m physical wings leave only the 2.2m
	# central doorway passable. The old 3.1m wings left two invisible side gaps
	# under window bays, which made the house feel inconsistent to navigate.
	_add_box_obstacle("HomeFrontWallL", center + Vector3(-3.6, 2.2, 5.85), Vector3(5.0, 4.4, 0.32), Color.TRANSPARENT, false)
	_add_box_obstacle("HomeFrontWallR", center + Vector3(3.6, 2.2, 5.85), Vector3(5.0, 4.4, 0.32), Color.TRANSPARENT, false)
	_add_box_obstacle("HomeFloor", center + Vector3(0, -0.10, 0), Vector3(12.2, 0.18, 11.4), Color.TRANSPARENT, false)

	# Make the body origin the hinge, then offset its collision and rendered mesh
	# into the doorway. Opening it now swings like a real door instead of
	# rotating around its centre.
	# The village doorway begins at the door-wall's 0.65m stone threshold and
	# reaches its 3.12m lintel. Keep the physical leaf exactly inside that real
	# opening rather than leaving an invisible 3.2m rectangle around it.
	var door := _add_box_obstacle("HomeDoor", center + Vector3(-1.1, 1.886, 5.90), Vector3(2.2, 2.48, 0.22), Color.TRANSPARENT, false)
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
	# The interaction volume is centered on the real north chair, while the
	# explicit seat transform puts the character's capsule above the chair seat.
	# The old generic +Z offset selected empty table-space and then lowered the
	# character into the furniture collision.
	var seat_anchor := _add_interaction_anchor("home_sit", center + Vector3(2.45, 0.45, 3.30), "E  Usiądź przy stole", "sit")
	seat_anchor.set_meta("seat_position", center + Vector3(2.45, 0.82, 3.30))


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
	# human-scale front that faces the bridge approach.
	for bay in range(5):
		var front_path := door_wall if bay == 2 else window_wall
		_add_visual_asset("HomeFacade_%d" % bay,
			center + Vector3(-4.0 + float(bay) * 2.0, 0.0, 5.72),
			Vector3.ONE, 0.0, front_path, false)
	# The five central bays are 10m wide but the physical home is 12m-class.
	# Close both edge strips with matched wall modules so there are no visible
	# daylight slits at the corners or player-sized walk-through gaps.
	for side in [-1.0, 1.0]:
		_add_visual_asset("HomeFacadeEdge_%s" % ("Left" if side < 0.0 else "Right"),
			center + Vector3(side * 5.5, 0.0, 5.72), Vector3.ONE, 0.0, solid_wall, false)
	# Back and side walls turn the house into a coherent volume instead of a
	# front-only set. These meshes are 2m modular bays with source PBR maps.
	for bay in range(5):
		_add_visual_asset("HomeBack_%d" % bay,
			center + Vector3(-4.0 + float(bay) * 2.0, 0.0, -5.72),
			Vector3.ONE, PI, solid_wall, false)
	for side in [-1.0, 1.0]:
		_add_visual_asset("HomeBackEdge_%s" % ("Left" if side < 0.0 else "Right"),
			center + Vector3(side * 5.5, 0.0, -5.72), Vector3.ONE, PI, solid_wall, false)
	for bay in range(5):
		var z := -4.0 + float(bay) * 2.0
		_add_visual_asset("HomeLeft_%d" % bay,
			center + Vector3(-5.72, 0.0, z), Vector3.ONE, PI * 0.5, solid_wall, false)
		_add_visual_asset("HomeRight_%d" % bay,
			center + Vector3(5.72, 0.0, z), Vector3.ONE, -PI * 0.5, solid_wall, false)
	for side in [-1.0, 1.0]:
		_add_visual_asset("HomeLeftEnd_%s" % ("Front" if side < 0.0 else "Back"),
			center + Vector3(-5.72, 0.0, side * 5.5), Vector3.ONE, PI * 0.5, solid_wall, false)
		_add_visual_asset("HomeRightEnd_%s" % ("Front" if side < 0.0 else "Back"),
			center + Vector3(5.72, 0.0, side * 5.5), Vector3.ONE, -PI * 0.5, solid_wall, false)
	# Roof_RoundTiles_8x12 is a 6.4m tall source module. At unit height it was
	# towering over the 3.1m walls and leaving an exposed, dark gable plane.
	# Calibrate it to this 12m-class shell and use the kit's matching front caps
	# at both ends, so the house reads as a finished dwelling rather than a roof
	# balanced on a set of disconnected wall tiles.
	var roof_front := QUATERNIUS_VILLAGE + "Roof_Front_Brick8.gltf"
	_add_visual_asset("HomeGabledRoof", center + Vector3(0.0, 3.20, 0.0), Vector3(1.24, 0.72, 0.84),
		0.0, QUATERNIUS_VILLAGE + "Roof_RoundTiles_8x12.gltf", false)
	_add_visual_asset("HomeRoofFront", center + Vector3(0.0, 3.08, -5.94), Vector3(1.42, 0.75, 1.0),
		PI, roof_front, false)
	_add_visual_asset("HomeRoofBack", center + Vector3(0.0, 3.08, 5.94), Vector3(1.42, 0.75, 1.0),
		0.0, roof_front, false)
	_add_visual_asset("HomeChimney", center + Vector3(3.1, 4.82, 0.6), Vector3.ONE,
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
	# Door_2's imported mesh extends 4cm left of its nominal hinge. Offset its
	# visual pivot by that authored overhang and trim width from 2.228m to the
	# exact 2.2m physical opening. The rendered leaf and its collision therefore
	# agree at the jamb instead of visibly clipping through the wall.
	visual.position = Vector3(0.084, -1.283, 0.0)
	visual.scale = Vector3(1.975, 1.18, 1.0)
	visual.rotation.y = 0.0
	door.add_child(visual)
	_apply_toon_to_prop(visual, "home wooden door")
	door.set_meta("door_visual", visual)


func _add_water_crossing() -> void:
	var water := Area3D.new()
	water.name = "StarterRiver"
	water.add_to_group("water_volume")
	water.monitoring = true
	# A straight PlaneMesh made the river a blue runway that visibly stopped in
	# the middle of open terrain. This ribbon follows a gentle, deterministic
	# meander from one outer-ocean edge to the other, while crossing the bridge
	# exactly at x=0,z=-24. It has real bank variation without a costly fluid sim.
	var mesh := _create_meandering_river_mesh()
	var visual := MeshInstance3D.new()
	visual.name = "WaterSurface"
	visual.mesh = mesh
	var water_material := ShaderMaterial.new()
	water_material.shader = ADVENTURE_WATER_SHADER
	# Apply Choyce water color palette: shallow -> medium -> deep
	# These runtime values deliberately match the shader's natural turquoise
	# palette. Do not leave the old near-black prototype override here: uniforms
	# take precedence over shader defaults and were hiding the repaired surface.
	# Using the official Choyce palette from VS-012 research.
	water_material.set_shader_parameter("shallow_color", CHOYCE_WATER_SHALLOW)
	water_material.set_shader_parameter("deep_color", CHOYCE_WATER_DEEP)
	water_material.set_shader_parameter("dudv_map", SIMPLE_WATER_DUDV)
	# The generated ribbon's UV spans 3.2km. Shader flow therefore uses local
	# world metres rather than this normalized UV. Increased tiling and strength
	# for more visible water motion as per VS-012 acceptance criteria.
	water_material.set_shader_parameter("dudv_tiling", 0.16)
	water_material.set_shader_parameter("dudv_strength", 0.050)
	# Expose the wave constants at runtime so tests and downstream systems can
	# read a complete authored material contract without relying on shader defaults.
	water_material.set_shader_parameter("wave_height", 0.012)
	water_material.set_shader_parameter("wave_speed", 0.70)
	# Port the useful visual principle from the supplied MIT Simple Water asset:
	# moving distortion plus restrained sky reflection. Keep it fully opaque so
	# entering the volume cannot make the water disappear through sort artifacts.
	water_material.set_shader_parameter("foam_color", Color(0.14, 0.34, 0.33, 1.0))
	water_material.set_shader_parameter("sky_reflection_color", Color(0.08, 0.22, 0.28, 1.0))
	visual.material_override = water_material
	water.add_child(visual)
	# The surface must be a render-only child. The Area3D below is exclusively
	# for wading/swimming; it cannot hide, displace or otherwise own this mesh.
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# A single straight 22m collision box at z=-24 used to make the player swim
	# beside visible water anywhere the 3.2km ribbon meandered. Build the Area's
	# physical shapes from the exact same bank pairs as the mesh. Consecutive
	# boxes overlap slightly, so a CharacterBody cannot flicker between wet/dry
	# state while crossing a segment seam.
	_build_meandering_water_volumes(water)
	# Keep the slight vertical lift used by the opaque water shader, but do not
	# translate Z: `_create_meandering_river_mesh()` owns those coordinates.
	water.position = Vector3(0, 0.10, 0)
	water.collision_layer = 0
	water.collision_mask = 1
	water.body_entered.connect(_on_water_body_entered)
	water.body_exited.connect(_on_water_body_exited)
	add_child(water)
	_build_meandering_river_shoreline()
	# Do not line the entire 2.3 km river with identical, collidable rocks.
	# That was a visible picket fence in the opening shot and created dozens of
	# false-looking collision obstacles. The composed bridge shoreline above is
	# detailed by hand; streamed biomes supply their own local banks farther out.


func _create_meandering_river_mesh() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Unlike the physics volume, this mesh is tessellated both along and across
	# the current. It gives the local SimpleWater-inspired waves a real surface
	# to travel over instead of relying on a broad per-fragment colour trick.
	for segment in range(RIVER_RENDER_SEGMENT_COUNT):
		var t0 := float(segment) / float(RIVER_RENDER_SEGMENT_COUNT)
		var t1 := float(segment + 1) / float(RIVER_RENDER_SEGMENT_COUNT)
		var pair0 := _river_bank_pair(lerpf(-RIVER_HALF_LENGTH_M, RIVER_HALF_LENGTH_M, t0))
		var pair1 := _river_bank_pair(lerpf(-RIVER_HALF_LENGTH_M, RIVER_HALF_LENGTH_M, t1))
		var left0: Vector3 = pair0[0]
		var right0: Vector3 = pair0[1]
		var left1: Vector3 = pair1[0]
		var right1: Vector3 = pair1[1]
		for strip in range(RIVER_RENDER_WIDTH_SUBDIVISIONS):
			var v0 := float(strip) / float(RIVER_RENDER_WIDTH_SUBDIVISIONS)
			var v1 := float(strip + 1) / float(RIVER_RENDER_WIDTH_SUBDIVISIONS)
			var near0 := left0.lerp(right0, v0)
			var far0 := left0.lerp(right0, v1)
			var near1 := left1.lerp(right1, v0)
			var far1 := left1.lerp(right1, v1)
			# Counter-clockwise from above: real upward normals matter for the
			# reflection tint, editor previews and any later lit material upgrade.
			surface.set_uv(Vector2(t0, v0)); surface.add_vertex(near0)
			surface.set_uv(Vector2(t1, v0)); surface.add_vertex(near1)
			surface.set_uv(Vector2(t0, v1)); surface.add_vertex(far0)
			surface.set_uv(Vector2(t1, v0)); surface.add_vertex(near1)
			surface.set_uv(Vector2(t1, v1)); surface.add_vertex(far1)
			surface.set_uv(Vector2(t0, v1)); surface.add_vertex(far0)
	surface.generate_normals()
	return surface.commit()


## Add overlapping shallow-water volumes along the rendered river. Each box is
## tangent-aligned to a mesh strip and spans its sampled bank pair, making the
## gameplay water state authoritative at the bridge and throughout the wider
## sandbox instead of only at the initial crossing.
func _build_meandering_water_volumes(water: Area3D) -> void:
	if water == null:
		return
	for segment in range(RIVER_SEGMENT_COUNT):
		var t0 := float(segment) / float(RIVER_SEGMENT_COUNT)
		var t1 := float(segment + 1) / float(RIVER_SEGMENT_COUNT)
		var pair0 := _river_bank_pair(lerpf(-RIVER_HALF_LENGTH_M, RIVER_HALF_LENGTH_M, t0))
		var pair1 := _river_bank_pair(lerpf(-RIVER_HALF_LENGTH_M, RIVER_HALF_LENGTH_M, t1))
		var left0: Vector3 = pair0[0]
		var right0: Vector3 = pair0[1]
		var left1: Vector3 = pair1[0]
		var right1: Vector3 = pair1[1]
		var center0 := (left0 + right0) * 0.5
		var center1 := (left1 + right1) * 0.5
		var tangent := (center1 - center0).normalized()
		var midpoint := (center0 + center1) * 0.5
		var width := maxf((left0.distance_to(right0) + left1.distance_to(right1)) * 0.5, 1.0)
		var shape := BoxShape3D.new()
		shape.size = Vector3(center0.distance_to(center1) + 0.80, 1.15, width + 0.35)
		var volume := CollisionShape3D.new()
		volume.name = "WaterVolumeSegment_%02d" % segment
		volume.shape = shape
		# Water's parent has a +0.10m visual lift; retain the old -0.47m local
		# offset so each volume's top lies just below the rendered surface.
		volume.position = Vector3(midpoint.x, -0.47, midpoint.z)
		volume.rotation.y = atan2(tangent.z, tangent.x)
		water.add_child(volume)


## The river surface follows a curve, so its banks must be generated from the
## same samples.  A narrow wet-earth ribbon overlays the flat terrain at each
## edge, removing the hard water/grass seam while preserving the water's full
## collision width. It is non-colliding: roots, rocks and the terrain remain
## the authoritative walkable shoreline.
func _build_meandering_river_shoreline() -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for segment in range(RIVER_SEGMENT_COUNT):
		var t0 := float(segment) / float(RIVER_SEGMENT_COUNT)
		var t1 := float(segment + 1) / float(RIVER_SEGMENT_COUNT)
		var pair0 := _river_bank_pair(lerpf(-RIVER_HALF_LENGTH_M, RIVER_HALF_LENGTH_M, t0))
		var pair1 := _river_bank_pair(lerpf(-RIVER_HALF_LENGTH_M, RIVER_HALF_LENGTH_M, t1))
		var center0 := (pair0[0] + pair0[1]) * 0.5
		var center1 := (pair1[0] + pair1[1]) * 0.5
		var left0: Vector3 = pair0[0]
		var right0: Vector3 = pair0[1]
		var left1: Vector3 = pair1[0]
		var right1: Vector3 = pair1[1]
		var left_outer0 := left0 + (left0 - center0).normalized() * RIVER_SHORE_WIDTH_M
		var left_outer1 := left1 + (left1 - center1).normalized() * RIVER_SHORE_WIDTH_M
		var right_outer0 := right0 + (right0 - center0).normalized() * RIVER_SHORE_WIDTH_M
		var right_outer1 := right1 + (right1 - center1).normalized() * RIVER_SHORE_WIDTH_M
		_add_river_shore_quad(surface, left0, left_outer0, left1, left_outer1, t0, t1)
		_add_river_shore_quad(surface, right_outer0, right0, right_outer1, right1, t0, t1)
	var shoreline := MeshInstance3D.new()
	shoreline.name = "StarterRiverWetBanks"
	shoreline.mesh = surface.commit()
	# The shoreline is world-space geometry. It must not receive the old global
	# +20cm lift: only its water-facing vertices rise to the water surface, while
	# its outer edge samples the real Terrain3D height.
	shoreline.position.y = 0.0
	shoreline.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := StandardMaterial3D.new()
	material.albedo_texture = PBR_DETAIL_ALBEDO
	material.normal_texture = PBR_DETAIL_NORMAL
	material.roughness_texture = PBR_DETAIL_ROUGHNESS
	# Use Choyce warm beige palette for wet banks to match the terrain
	material.albedo_color = CHOYCE_WARM_BEIGE.darkened(0.15)
	material.roughness = 0.80
	material.uv1_scale = Vector3(0.18, 0.18, 0.18)
	shoreline.material_override = material
	add_child(shoreline)


func _add_river_shore_quad(surface: SurfaceTool, inner0: Vector3, outer0: Vector3, inner1: Vector3, outer1: Vector3, t0: float, t1: float) -> void:
	# Inner edge at water surface (y=0.203, matching the water mesh at y=0.10 + 0.103).
	# Outer edge at exact terrain height to prevent floating. This grounds the
	# wet-bank ribbon to the real world surface outside the flat opening.
	inner0.y = 0.203
	outer0.y = _terrain_grounded_position(Vector3(outer0.x, 0.0, outer0.z)).y
	inner1.y = 0.203
	outer1.y = _terrain_grounded_position(Vector3(outer1.x, 0.0, outer1.z)).y
	surface.set_uv(Vector2(t0 * 28.0, 0.0)); surface.add_vertex(inner0)
	surface.set_uv(Vector2(t0 * 28.0, 1.0)); surface.add_vertex(outer0)
	surface.set_uv(Vector2(t1 * 28.0, 0.0)); surface.add_vertex(inner1)
	surface.set_uv(Vector2(t1 * 28.0, 0.0)); surface.add_vertex(inner1)
	surface.set_uv(Vector2(t0 * 28.0, 1.0)); surface.add_vertex(outer0)
	surface.set_uv(Vector2(t1 * 28.0, 1.0)); surface.add_vertex(outer1)


func _river_bank_pair(x: float) -> Array[Vector3]:
	# sin(0)=0 keeps the authored bridge and crossing centred at z=-24. The
	# secondary term breaks the ruler-straight silhouette without narrow turns.
	var center_z := -24.0 + sin(x * 0.0031) * 18.0 + sin(x * 0.0087) * 5.0
	var derivative := cos(x * 0.0031) * 18.0 * 0.0031 + cos(x * 0.0087) * 5.0 * 0.0087
	var tangent := Vector3(1.0, 0.0, derivative).normalized()
	var side := Vector3(-tangent.z, 0.0, tangent.x)
	var half_width := 9.4 + sin(x * 0.0101) * 1.35 + sin(x * 0.0043 + 1.7) * 0.75
	var center := Vector3(x, 0.10, center_z)
	return [center + side * half_width, center - side * half_width]


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
	# Keep the authoritative leaf collision as a direct child. Object metadata
	# is not a reliable Node reference across serialization/lifetime boundaries.
	var collision := _first_collision_shape(door)
	if collision != null:
		collision.set_deferred("disabled", next_open)
	var target_rotation := -PI * 0.48 if next_open else 0.0
	var tween := create_tween()
	tween.tween_property(door, "rotation:y", target_rotation, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	door.set_meta("interaction_prompt", "E  Zamknij drzwi" if next_open else "E  Otwórz drzwi")


func _first_collision_shape(node: Node) -> CollisionShape3D:
	if node == null:
		return null
	for child in node.get_children():
		if child is CollisionShape3D:
			return child as CollisionShape3D
	return null


func _add_visual_asset(
		node_name: String,
		asset_position: Vector3,
		asset_scale: Vector3 = Vector3.ONE,
		rotation_y: float = 0.0,
		asset_path: String = "",
		collidable: bool = true,
		collision_size: Vector3 = Vector3(1.5, 2.0, 1.5),
		parent_node: Node = null,
		ground_to_terrain: bool = false
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
	var collision: CollisionShape3D = null
	var effective_collision_size := collision_size
	# `_apply_toon_to_prop` preserves a valid source texture atlas. Otherwise it
	# applies the PBR detail layer above—important for KayKit Builder's flat
	# palette hills/mountains/houses, which previously looked unrendered.
	if node_name.begins_with("coast_cliff") or node_name.begins_with("coast_corner"):
		_apply_toon_tint(instance, CHOYCE_WARM_BEIGE)
		_set_coast_visibility_range(instance)
	else:
		# Asset names supply the material class for procedural aliases such as
		# river_bank_42, whose node name does not itself mention "rock".
		_apply_toon_to_prop(instance, "%s %s" % [node_name, path.get_file()])
	if collidable:
		collision = CollisionShape3D.new()
		var shape := BoxShape3D.new()
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
	root.set_meta("authored_ground_y", asset_position.y)
	root.set_meta("terrain_grounded", collidable or ground_to_terrain)
	root.position = _terrain_grounded_position(asset_position) if collidable or ground_to_terrain else asset_position
	root.rotation.y = rotation_y
	root.scale = asset_scale
	# Forest trees must behave like trees: a close axe swing can fell them.
	# Do not give the same behavior to decorative bushes/props merely because a
	# node name contains "tree"; only imported Quaternius tree assets get this
	# lightweight harvest contract.
	if collidable and _is_harvestable_tree_asset(path):
		root.add_to_group("harvestable_tree")
		root.set_meta("interaction_action", "gather_wood")
		root.set_meta("resource_action", "gather_wood")
		root.set_meta("resource_item_id", "wood_oak")
	var container: Node = parent_node if parent_node != null else self
	container.add_child(root)
	if collidable and instance is Node3D and collision != null:
		_align_collidable_asset_to_ground(root, instance as Node3D, collision, effective_collision_size)
	return root


func _is_harvestable_tree_asset(asset_path: String) -> bool:
	var filename := asset_path.get_file().to_lower()
	return asset_path.contains("/quaternius/nature/") and filename.contains("tree")


## Terrain3D owns the visible island height away from the intentionally flat
## opening. Ground every collidable prop to its sampled world height before
## normalizing the source-model pivot, keeping both render mesh and collider
## together on a hill instead of at the old y=0 safety floor.
func _terrain_grounded_position(asset_position: Vector3) -> Vector3:
	var grounded := asset_position
	var terrain_adapter := get_node_or_null("Terrain3DWorldAdapter")
	if terrain_adapter == null:
		return grounded
	var terrain: Object = terrain_adapter.get("terrain") as Object
	if terrain == null:
		return grounded
	var data: Object = terrain.get("data") as Object
	if data == null or not data.has_method("get_height"):
		return grounded
	var sampled := float(data.call("get_height", Vector3(asset_position.x, 0.0, asset_position.z)))
	if not is_nan(sampled):
		grounded.y += sampled
	return grounded


## Source GLBs do not share a common vertical pivot convention: several of the
## supplied home props place their geometry well below y=0. Normalize only
## collidable gameplay props at this adapter boundary, and move their collider
## with the mesh. That removes both sunken/floating furniture and the matching
## invisible half-buried collision boxes without disturbing architectural
## modules such as roofs and wall panels that use deliberate authored offsets.
func _align_collidable_asset_to_ground(
		root: Node3D,
		visual: Node3D,
		collision: CollisionShape3D,
		effective_collision_size: Vector3
	) -> void:
	root.force_update_transform()
	var lowest_local_y := INF
	for mesh_variant in visual.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := mesh_variant as MeshInstance3D
		var bounds := mesh_instance.get_aabb()
		for x in [bounds.position.x, bounds.end.x]:
			for y in [bounds.position.y, bounds.end.y]:
				for z in [bounds.position.z, bounds.end.z]:
					var root_local := root.to_local(mesh_instance.global_transform * Vector3(x, y, z))
					lowest_local_y = minf(lowest_local_y, root_local.y)
	if lowest_local_y < INF:
		visual.position.y -= lowest_local_y
	# Collision shapes are deliberately inverse-scaled above, so this local
	# offset produces a world-space box whose base is exactly at the prop's
	# placement surface even when the visual root is enlarged.
	collision.position.y = effective_collision_size.y * 0.5 / maxf(absf(root.scale.y), 0.001)


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
	mat.set_shader_parameter("base_color", base_color.lerp(CHOYCE_SOFT_GREEN, 0.20))
	return mat

func _create_light_node(node: SceneNode) -> Node3D:
	var light_type: String = node.properties.get("light_type", "omni")
	if light_type == "directional":
		var light := DirectionalLight3D.new()
		light.shadow_enabled = true
		light.shadow_blur = 1.5
		# Enable contact shadows for better object grounding (VS-012 adversarial review)
		light.contact_shadow_enabled = true
		light.contact_shadow_length = 0.5
		light.contact_shadow_bias = 0.1
		return light
	else:
		var light := OmniLight3D.new()
		light.omni_range = node.properties.get("range", 10.0)
		light.light_energy = node.properties.get("energy", 1.0)
		light.light_color = CHOYCE_ACCENT_ORANGE
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
			env.background_color = CHOYCE_WATER_DEEP
	else:
		# Non-combat default: soft procedural sky already used elsewhere.
		env.background_mode = Environment.BG_COLOR
		env.background_color = CHOYCE_SKY_BLUE
	var we := WorldEnvironment.new()
	we.environment = env
	we.name = "VoxelWorldEnvironment"
	add_child(we)


# VS-025: Get the food database reference
func get_food_database() -> FoodDatabase:
	return food_database
