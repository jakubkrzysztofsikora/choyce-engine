## Regression: the Adventure runtime gets a real Terrain3D surface that spans
## the promised map, with PBR texture assets and a safe extension fallback.
extends SceneTree

const TerrainAdapterScript = preload("res://src/adapters/inbound/gameplay/terrain3d_world_adapter.gd")
const WorldRenderer = preload("res://src/adapters/inbound/gameplay/world_renderer.gd")

var _exit_code := 0


func _init() -> void:
	call_deferred("_run")


func _assert(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		print("FAIL: %s" % message)
		_exit_code = 1


func _run() -> void:
	var camera := Camera3D.new()
	camera.make_current()
	get_root().add_child(camera)
	var adapter := TerrainAdapterScript.new()
	get_root().add_child(adapter)
	_assert(adapter.build("terrain3d-regression"), "Terrain3D adapter builds the Adventure surface")
	await process_frame
	_assert(adapter.terrain != null and adapter.terrain.name == "Terrain3DAdventureSurface", "Adventure owns an explicit Terrain3D surface")
	_assert(adapter.terrain != null and is_equal_approx(float(adapter.terrain.get("vertex_spacing")) * TerrainAdapterScript.HEIGHTMAP_RESOLUTION, TerrainAdapterScript.WORLD_SIZE_M), "Terrain3D surface spans the full 2.4km world extent in collision-aware global metres")
	_assert(adapter.terrain != null and adapter.terrain.get("assets") != null, "Terrain3D surface receives local PBR texture assets")
	var controls := adapter._make_biome_control_map("terrain3d-regression")
	var util: Object = ClassDB.instantiate(&"Terrain3DUtil") as Object
	var overlay_layers: Dictionary = {}
	var blend_levels: Dictionary = {}
	for x in range(0, TerrainAdapterScript.HEIGHTMAP_RESOLUTION, 16):
		for z in range(0, TerrainAdapterScript.HEIGHTMAP_RESOLUTION, 16):
			var packed := int(util.call("as_uint", controls.get_pixel(x, z).r))
			overlay_layers[int(util.call("get_overlay", packed))] = true
			blend_levels[int(util.call("get_blend", packed))] = true
	_assert(overlay_layers.size() >= 2 and blend_levels.size() >= 3,
		"Terrain3D control map carries deterministic biome material variation beyond one olive layer")
	var heightmap := adapter._make_open_world_heightmap("terrain3d-regression")
	var opening_height := heightmap.get_pixel(256, 256).r
	var mountain_height := heightmap.get_pixel(440, 143).r
	_assert(mountain_height > opening_height + 0.30,
		"Terrain3D heightmap contains a safe low opening and readable distant mountain relief")
	_assert(adapter.has_dynamic_collision(), "Terrain3D dynamic collision is explicitly built for the playable surface")
	camera.global_position = Vector3(300.0, 20.0, 300.0)
	await physics_frame
	await physics_frame
	var space := get_root().get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(Vector3(300.0, 80.0, 300.0), Vector3(300.0, -80.0, 300.0))
	var hit := space.intersect_ray(query)
	var collider := hit.get("collider", null) as Node
	_assert(collider != null and (collider == adapter.terrain or adapter.terrain.is_ancestor_of(collider)),
		"ray hit belongs to Terrain3D, not an unrelated fallback floor")
	var renderer := WorldRenderer.new()
	get_root().add_child(renderer)
	var renderer_adapter := TerrainAdapterScript.new()
	renderer_adapter.name = "Terrain3DWorldAdapter"
	renderer.add_child(renderer_adapter)
	_assert(renderer_adapter.build("terrain3d-prop-grounding"), "Terrain3D builds for prop-grounding lookup")
	var placement := Vector3(300.0, 1.4, 300.0)
	var data: Object = renderer_adapter.terrain.get("data") as Object
	var terrain_y := float(data.call("get_height", Vector3(placement.x, 0.0, placement.z)))
	_assert(is_equal_approx(renderer._terrain_grounded_position(placement).y, placement.y + terrain_y),
		"collidable props use sampled Terrain3D height instead of the flat legacy floor")
	renderer.queue_free()
	adapter.queue_free()
	camera.queue_free()
	quit(_exit_code)
