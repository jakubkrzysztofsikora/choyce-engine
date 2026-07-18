## Regression: the Adventure runtime gets a real Terrain3D surface that spans
## the promised map, with PBR texture assets and a safe extension fallback.
extends SceneTree

const TerrainAdapterScript = preload("res://src/adapters/inbound/gameplay/terrain3d_world_adapter.gd")

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
	_assert(adapter.terrain != null and is_equal_approx(adapter.terrain.scale.x * TerrainAdapterScript.HEIGHTMAP_RESOLUTION, TerrainAdapterScript.WORLD_SIZE_M), "Terrain3D surface spans the full 2.4km world extent")
	_assert(adapter.terrain != null and adapter.terrain.get("assets") != null, "Terrain3D surface receives local PBR texture assets")
	adapter.queue_free()
	camera.queue_free()
	quit(_exit_code)
