## Runtime boundary for the vendored Terrain3D GDExtension.
##
## Terrain3D owns the visible, LOD terrain mesh and its material blending. The
## existing flat floor remains a short-lived safety collision underneath until
## character movement is fully migrated and captured in manual play evidence.
class_name Terrain3DWorldAdapter
extends Node3D

const WORLD_SIZE_M := 2400.0
const HEIGHTMAP_RESOLUTION := 512
const PBR_GRASS: Texture2D = preload("res://data/textures/generated/forest-meadow-ground-v1.png")
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
	# Keep the opening (the centre of the map) nearly flat for the already
	# authored house, bridge, NPCs and collider. Distant ridges add real mesh
	# depth, hide the horizon, and leave enough clearance for existing props.
	data.call("import_images", [heights, null, null],
		Vector3(-WORLD_SIZE_M * 0.5, 0.0, -WORLD_SIZE_M * 0.5), 0.0, 0.72)
	_configure_dynamic_collision()
	return true


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


func _configure_materials() -> void:
	var assets: Object = ClassDB.instantiate(&"Terrain3DAssets") as Object
	if assets == null:
		return
	assets.call("set_texture", 0, _make_texture_asset("Meadow", PBR_GRASS, Color(0.76, 0.88, 0.72), 0.10))
	assets.call("set_texture", 1, _make_texture_asset("Earth", PBR_DIRT, Color(0.72, 0.62, 0.48), 0.055))
	terrain.set("assets", assets)
	var material: Object = terrain.get("material") as Object
	if material == null:
		return
	material.set("auto_shader", true)
	material.call("set_shader_param", "auto_slope", 0.47)
	material.call("set_shader_param", "blend_sharpness", 0.72)
	material.call("set_shader_param", "dual_scale_near", 42.0)
	material.call("set_shader_param", "dual_scale_far", 260.0)
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
			# First 250-ish metres are intentionally gentle; broad hills accumulate
			# farther out, creating long-distance views without lifting the house.
			var opening_falloff := smoothstep(0.16, 0.72, from_spawn)
			var land_noise := macro.get_noise_2d(float(x), float(z)) * 0.65 + ridge.get_noise_2d(float(x), float(z)) * 0.35
			var height := clampf((land_noise * 0.5 + 0.5) * opening_falloff, 0.0, 1.0)
			map.set_pixel(x, z, Color(height, 0.0, 0.0, 1.0))
	return map
