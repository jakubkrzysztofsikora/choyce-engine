## Runtime boundary for the vendored Terrain3D GDExtension.
##
## Terrain3D owns the visible, LOD terrain mesh and its material blending. The
## existing flat floor remains a short-lived safety collision underneath until
## character movement is fully migrated and captured in manual play evidence.
class_name Terrain3DWorldAdapter
extends Node3D

const WORLD_SIZE_M := 2400.0
const HEIGHTMAP_RESOLUTION := 512
const OPENING_RIVERBANK_RELIEF_NORMALIZED := 0.028
const OPENING_FLANK_HILL_NORMALIZED := 0.160
const FOREST_FLOOR: Texture2D = preload("res://data/textures/generated/forest-meadow-ground-v1.png")
const OPEN_MEADOW: Texture2D = preload("res://data/textures/generated/stylized-meadow-ground-v2.png")
const PBR_DIRT: Texture2D = preload("res://data/textures/pbr/ground003/Ground003_1K-JPG_Color.jpg")
const PBR_NORMAL: Texture2D = preload("res://data/textures/pbr/ground003/Ground003_1K-JPG_NormalGL.jpg")

var terrain: Node3D
var _dynamic_collision_ready := false
var _prepared_albedo: Dictionary = {}
var _prepared_normal: Texture2D


func build(seed_source: String) -> bool:
	_dynamic_collision_ready = false
	if not ClassDB.class_exists(&"Terrain3D"):
		push_warning("Terrain3D extension is unavailable; keeping the safe legacy floor")
		return false
	terrain = ClassDB.instantiate(&"Terrain3D") as Node3D
	if terrain == null:
		push_warning("Terrain3D could not create its runtime node")
		return false
	terrain.name = "Terrain3DAdventureSurface"
	# A 512-pixel heightfield at 4.6875 metres per vertex covers the full 2.4km
	# island. This must be Terrain3D's `vertex_spacing`, not a Node3D scale:
	# collision/data APIs operate in global metres and otherwise leave physics
	# behind at a tiny 512m-local region while the rendered mesh looks enormous.
	var horizontal_scale := WORLD_SIZE_M / float(HEIGHTMAP_RESOLUTION)
	terrain.scale = Vector3.ONE
	terrain.position.y = 0.012
	terrain.set("region_size", HEIGHTMAP_RESOLUTION)
	terrain.set("vertex_spacing", horizontal_scale)
	terrain.set("collision_mask", 1)
	add_child(terrain)

	_configure_materials()
	var data: Object = terrain.get("data") as Object
	if data == null:
		terrain.queue_free()
		terrain = null
		push_warning("Terrain3D data object was unavailable")
		return false
	var heights := _make_open_world_heightmap(seed_source)
	var controls := _make_biome_control_map(seed_source)
	if controls == null or controls.get_width() != HEIGHTMAP_RESOLUTION or controls.get_height() != HEIGHTMAP_RESOLUTION:
		push_warning("Terrain3D control map was not generated at the required resolution; keeping the safe legacy floor")
		terrain.queue_free()
		terrain = null
		return false
	# Keep the opening (the centre of the map) nearly flat for the already
	# authored house, bridge, NPCs and collider. Distant ridges add real mesh
	# depth, hide the horizon, and leave enough clearance for existing props.
	# `import_images` scale is vertical metres, not a normalisation factor. The
	# old 0.72 value capped the entire 5.76km² island below one metre and made
	# every distant biome read as a flat test board. Keep the first ~190m gentle
	# via the heightmap falloff, then let real 20–90m hills close the horizon.
	_heights_image = heights
	data.call("import_images", [heights, controls, null],
		Vector3(-WORLD_SIZE_M * 0.5, 0.0, -WORLD_SIZE_M * 0.5), 0.0, TERRAIN_HEIGHT_SCALE_M)
	_configure_dynamic_collision()
	return true


## Vertical metres Terrain3D maps the normalized 0..1 heightmap onto.
const TERRAIN_HEIGHT_SCALE_M := 90.0

## Source heightmap kept from build() for synchronous sampling.
var _heights_image: Image = null


## Synchronous, race-free terrain height for placement code. Terrain3D imports
## its data asynchronously, so data.get_height() can return stale/NaN values
## while the world is being built — anything grounded through that path got
## buried under (or floated above) the real surface once the import landed.
## This samples the exact source image the terrain renders from, so grounded
## props agree with the visible surface from frame one.
func sample_height(world_x: float, world_z: float) -> float:
	if _heights_image == null:
		return 0.0
	var fx := (world_x + WORLD_SIZE_M * 0.5) / WORLD_SIZE_M * float(HEIGHTMAP_RESOLUTION)
	var fz := (world_z + WORLD_SIZE_M * 0.5) / WORLD_SIZE_M * float(HEIGHTMAP_RESOLUTION)
	var px := clampi(int(floor(fx)), 0, HEIGHTMAP_RESOLUTION - 1)
	var pz := clampi(int(floor(fz)), 0, HEIGHTMAP_RESOLUTION - 1)
	# +0.012 matches the terrain node's own y offset set in build().
	return _heights_image.get_pixel(px, pz).r * TERRAIN_HEIGHT_SCALE_M + 0.012


func has_dynamic_collision() -> bool:
	return _dynamic_collision_ready


## Terrain3D's default dynamic-game mode is appropriate for a 5.76km² world,
## but runtime-imported height data needs an explicit collision rebuild. Without
## it, the mesh renders while the player only ever touches the legacy flat floor.
func _configure_dynamic_collision() -> void:
	var collision: Object = terrain.get("collision") as Object
	if collision == null:
		push_warning("Terrain3D collision controls are unavailable; keeping the safety floor")
		return
	# DYNAMIC_GAME (1): mesh-derived collision follows the active player camera
	# rather than allocating full-island physics meshes at boot.
	collision.set("mode", 1)
	collision.set("layer", 1)
	collision.set("mask", 1)
	collision.set("radius", 96)
	collision.call("build")
	collision.call("update", true)
	_dynamic_collision_ready = true


## Terrain3D stores texture choices in a separate uint32 control image. The
## old 5×5 anchor writes painted only 25 texels and the single-layer repair
## afterward made the entire island one olive board. Import a complete manual
## map with deterministic forest floor, meadow and earth strata instead. The
## first ~190m remains a calm, coherent forest-floor opening; distant rolling
## land gets a lighter meadow breakup while the highest ridges reveal earth.
func _make_biome_control_map(seed_source: String) -> Image:
	var util: Object = ClassDB.instantiate(&"Terrain3DUtil") as Object
	if util == null:
		push_warning("Terrain3DUtil is unavailable; using a zeroed control image")
		return Image.create_empty(HEIGHTMAP_RESOLUTION, HEIGHTMAP_RESOLUTION, false, Image.FORMAT_RF)
	var controls := Image.create_empty(HEIGHTMAP_RESOLUTION, HEIGHTMAP_RESOLUTION, false, Image.FORMAT_RF)
	var meadow_noise := FastNoiseLite.new()
	meadow_noise.seed = hash("terrain3d_meadow_%s" % seed_source)
	meadow_noise.frequency = 0.010
	meadow_noise.fractal_octaves = 3
	var earth_noise := FastNoiseLite.new()
	earth_noise.seed = hash("terrain3d_earth_%s" % seed_source)
	earth_noise.frequency = 0.026
	earth_noise.fractal_octaves = 2
	for x in range(HEIGHTMAP_RESOLUTION):
		for z in range(HEIGHTMAP_RESOLUTION):
			var local := Vector2(float(x) / HEIGHTMAP_RESOLUTION - 0.5, float(z) / HEIGHTMAP_RESOLUTION - 0.5)
			var distance_from_opening := local.length() * 2.0
			var meadow_amount := clampi(roundi((meadow_noise.get_noise_2d(float(x), float(z)) * 0.5 + 0.5) * 215.0), 20, 235)
			var base_id := 0 # dense forest floor / near opening
			var overlay_id := 1 # airy meadow in rolling distance
			var blend := 0
			if distance_from_opening > 0.19:
				blend = meadow_amount
			# Earth on only the highest, furthest irregular ridge tops breaks the
			# previous repeated green silhouette without turning the playable
			# opening into a brown terrain test.
			var earth_score := earth_noise.get_noise_2d(float(x), float(z)) * 0.5 + 0.5
			if distance_from_opening > 0.47 and earth_score > 0.68:
				overlay_id = 2
				blend = clampi(roundi((earth_score - 0.60) * 530.0), 70, 235)
			var packed_bits := int(util.call("enc_base", base_id)) \
				| int(util.call("enc_overlay", overlay_id)) \
				| int(util.call("enc_blend", blend)) \
				| int(util.call("enc_auto", false)) \
				| int(util.call("enc_uv_rotation", (x / 79 + z / 113) % 16))
			controls.set_pixel(x, z, Color(float(util.call("as_float", packed_bits)), 0.0, 0.0, 1.0))
	return controls


func _configure_materials() -> void:
	var assets: Object = ClassDB.instantiate(&"Terrain3DAssets") as Object
	if assets == null:
		return
	# Keep three related natural layers. The palette follows the research-backed
	# sage/earth family rather than multiplying every source into olive yellow.
	# A slightly quieter palette lets the house, water and characters carry the
	# composition instead of turning the whole 5km² island into one olive board.
	assets.call("set_texture", 0, _make_texture_asset("Forest floor", FOREST_FLOOR, Color(0.67, 0.74, 0.66), 0.32))
	assets.call("set_texture", 1, _make_texture_asset("Open meadow", OPEN_MEADOW, Color(0.64, 0.71, 0.66), 0.28))
	assets.call("set_texture", 2, _make_texture_asset("Ridge earth", PBR_DIRT, Color(0.58, 0.53, 0.48), 0.18))
	terrain.set("assets", assets)
	var material: Object = terrain.get("material") as Object
	if material == null:
		return
	material.set("auto_shader", true)
	material.call("set_shader_param", "auto_slope", 0.47)
	material.call("set_shader_param", "blend_sharpness", 0.72)
	material.call("set_shader_param", "dual_scale_near", 28.0)
	material.call("set_shader_param", "dual_scale_far", 170.0)
	material.call("set_shader_param", "world_noise_height", 0.0)


func _make_texture_asset(asset_name: String, albedo: Texture2D, tint: Color, uv_scale: float) -> Object:
	var asset: Object = ClassDB.instantiate(&"Terrain3DTextureAsset") as Object
	if asset == null:
		return null
	asset.set("name", asset_name)
	asset.set("albedo_texture", _prepare_albedo(albedo))
	asset.set("normal_texture", _prepare_normal())
	asset.set("albedo_color", tint)
	asset.set("normal_depth", 0.8)
	asset.set("roughness", 0.18)
	asset.set("uv_scale", uv_scale)
	asset.set("detiling_rotation", 0.14)
	return asset


## Terrain3D requires every material layer to use the same power-of-two image
## size and mip chains. Local art assets intentionally vary in source size, so
## normalize them once at this adapter boundary instead of mutating originals.
func _prepare_albedo(source: Texture2D) -> Texture2D:
	if source == null:
		return null
	var cache_key := source.resource_path
	if _prepared_albedo.has(cache_key):
		return _prepared_albedo[cache_key] as Texture2D
	var image := source.get_image()
	image.convert(Image.FORMAT_RGBA8)
	image.resize(1024, 1024, Image.INTERPOLATE_LANCZOS)
	image.generate_mipmaps()
	var prepared := ImageTexture.create_from_image(image)
	_prepared_albedo[cache_key] = prepared
	return prepared


func _prepare_normal() -> Texture2D:
	if _prepared_normal != null:
		return _prepared_normal
	var image := PBR_NORMAL.get_image()
	image.convert(Image.FORMAT_RGBA8)
	image.resize(1024, 1024, Image.INTERPOLATE_LANCZOS)
	image.generate_mipmaps()
	_prepared_normal = ImageTexture.create_from_image(image)
	return _prepared_normal


func _make_open_world_heightmap(seed_source: String) -> Image:
	var map := Image.create_empty(HEIGHTMAP_RESOLUTION, HEIGHTMAP_RESOLUTION, false, Image.FORMAT_RF)
	var macro := FastNoiseLite.new()
	macro.seed = hash("terrain3d_macro_%s" % seed_source)
	macro.frequency = 0.012
	macro.fractal_octaves = 4
	macro.fractal_gain = 0.5
	var ridge := FastNoiseLite.new()
	ridge.seed = hash("terrain3d_ridge_%s" % seed_source)
	ridge.frequency = 0.027
	ridge.fractal_octaves = 2
	for x in range(HEIGHTMAP_RESOLUTION):
		for z in range(HEIGHTMAP_RESOLUTION):
			var local := Vector2(float(x) / HEIGHTMAP_RESOLUTION - 0.5, float(z) / HEIGHTMAP_RESOLUTION - 0.5)
			var from_spawn := local.length() * 2.0
			# The central 170m remains calm for the home/bridge, then real relief
			# begins. Noise alone made a technically non-flat map that still read as
			# a uniform board, so broad deterministic landforms establish actual
			# travel geography: forested ridges, a cave hill, and distant mountains.
			var opening_falloff := smoothstep(0.14, 0.43, from_spawn)
			var land_noise := macro.get_noise_2d(float(x), float(z)) * 0.62 + ridge.get_noise_2d(float(x), float(z)) * 0.38
			var rolling_land := (land_noise * 0.5 + 0.5) * 0.28 * opening_falloff
			var forest_ridge := _landform(local, Vector2(-0.18, 0.13), Vector2(0.16, 0.12), 0.30)
			var cave_hill := _landform(local, Vector2(0.15, -0.18), Vector2(0.105, 0.09), 0.38)
			var north_mountain := _landform(local, Vector2(-0.12, -0.39), Vector2(0.18, 0.13), 0.62)
			var east_mountain := _landform(local, Vector2(0.36, -0.22), Vector2(0.15, 0.17), 0.70)
			var west_mountain := _landform(local, Vector2(-0.40, 0.20), Vector2(0.17, 0.16), 0.58)
			# The opening was deliberately held completely flat for the house and
			# bridge, but that also made the water a graphic strip laid on a lawn.
			# Add a shallow, walkable Terrain3D bank profile around the authored
			# river crossing. It stays zero at the bridge ramps and player spawn,
			# rises only beyond their clear corridor, and uses the same meander math
			# as the WorldRenderer river so visible terrain and water agree.
			var opening_riverbank := _opening_riverbank_relief(local)
			# The original safety plateau extended so far that the first live frame
			# stayed a lawn even though the five-square-kilometre island had distant
			# mountains. Two broad side hills begin beyond the camp/bridge corridor:
			# they make the nearby woodland feel like terrain a child can enter while
			# preserving flat, proven contacts at spawn, house, ramps and water.
			var opening_flank_hills := _opening_flank_hill_relief(local)
			var height := clampf(rolling_land + forest_ridge + cave_hill + north_mountain + east_mountain + west_mountain + opening_riverbank + opening_flank_hills, 0.0, 1.0)
			map.set_pixel(x, z, Color(height, 0.0, 0.0, 1.0))
	return map


## Terrain3D height is normalized before `import_images()` maps it to the
## 90-metre world scale. A 0.028 ridge creates a readable 2–2.5m outer bank;
## its 17m shoulder remains gentle enough for the child bridge approach and
## the existing dynamic collision.
func _opening_riverbank_relief(local: Vector2) -> float:
	var world_x := local.x * WORLD_SIZE_M
	var world_z := local.y * WORLD_SIZE_M
	# Match `WorldRenderer._river_bank_pair()` without coupling the visual-world
	# boundary to the adapter. At x=0 this remains z=-24, the authored bridge.
	var river_center_z := -24.0 + sin(world_x * 0.0031) * 18.0 + sin(world_x * 0.0087) * 5.0
	var bank_distance := absf(world_z - river_center_z)
	# The player start and the two bridge ramps must remain on their proven flat
	# contact. Relief begins outside the 10m channel, then reaches its readable
	# shoulder over the following 18m of natural shoreline.
	var bank_shoulder := smoothstep(12.5, 30.0, bank_distance)
	# Shape just the composed opening around the crossing. Farther out the normal
	# forest/mountain landforms own the terrain, avoiding a ruler-straight ridge
	# along the full 2.4km river.
	var crossing_window := 1.0 - smoothstep(120.0, 230.0, absf(world_x))
	# Keep the south spawn lawn flat while allowing the north bank to rise around
	# the house/forest approach. This prevents the grounded player from visually
	# sinking into Terrain3D before reaching the crossing.
	var south_spawn_clearance := 0.0 if world_z > -8.0 else 1.0
	return OPENING_RIVERBANK_RELIEF_NORMALIZED * bank_shoulder * crossing_window * south_spawn_clearance


## Broad, playable hills on both sides of the composed crossing.  This is not
## a prop ridge: Terrain3D supplies one continuous rendered and physical slope.
## The exact central corridor remains flat for the child spawn, camp route,
## bridge ramps and starter home while the flanks rise into the forest edge.
func _opening_flank_hill_relief(local: Vector2) -> float:
	var world_x := local.x * WORLD_SIZE_M
	var world_z := local.y * WORLD_SIZE_M
	# Hills sit 55–115m beyond the start and to either side of the 4m bridge
	# route. At the map's 90m vertical scale their peaks are about 14m high,
	# enough to break the lawn horizon but gentle across their 150m footprint.
	var west_hill := _landform(local, Vector2(-0.068, -0.064), Vector2(0.078, 0.075), OPENING_FLANK_HILL_NORMALIZED)
	var east_hill := _landform(local, Vector2(0.070, -0.072), Vector2(0.082, 0.078), OPENING_FLANK_HILL_NORMALIZED * 0.92)
	# A generous central exclusion keeps every authored contact at x≈0 intact;
	# the smooth edge avoids a collision step where a child leaves the route.
	var route_clearance := smoothstep(15.0, 34.0, absf(world_x))
	# Do not lift the immediate camp/spawn lawn, which ends around z=-8.
	var north_of_spawn := 1.0 - smoothstep(-25.0, -9.0, world_z)
	return (west_hill + east_hill) * route_clearance * north_of_spawn


## Elliptic macro landform in normalized map coordinates. Keeping this in the
## Terrain3D adapter makes visual relief and collision one source of truth;
## WorldRenderer only dresses the resulting slopes and never fakes mountains
## with oversized prop scatter.
func _landform(point: Vector2, center: Vector2, radius: Vector2, amplitude: float) -> float:
	var normalized := Vector2(
		(point.x - center.x) / maxf(radius.x, 0.001),
		(point.y - center.y) / maxf(radius.y, 0.001))
	var distance_squared := normalized.length_squared()
	if distance_squared >= 1.0:
		return 0.0
	var soft_peak := 1.0 - distance_squared
	return soft_peak * soft_peak * amplitude
