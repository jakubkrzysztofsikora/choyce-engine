## Terrain3D must replace both the old ground visual and its flat collider,
## otherwise the player can alternate between two near-coincident surfaces.
extends SceneTree

const GameplayRuntimeScene = preload("res://src/adapters/inbound/gameplay/gameplay_runtime.tscn")

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
	var runtime := GameplayRuntimeScene.instantiate() as GameplayRuntime
	get_root().add_child(runtime)
	await process_frame
	runtime._set_legacy_ground_visual_visible(false)
	runtime._set_legacy_ground_collision_enabled(false)
	await physics_frame
	var mesh := runtime.get_node_or_null("GroundPlane/GroundMesh") as MeshInstance3D
	var collision := runtime.get_node_or_null("GroundPlane/GroundCollider") as CollisionShape3D
	_assert(mesh != null and not mesh.visible, "legacy ground mesh is hidden when Terrain3D renders")
	_assert(collision != null and collision.disabled, "legacy ground collider is disabled when Terrain3D collision is ready")
	runtime.queue_free()
	quit(_exit_code)
