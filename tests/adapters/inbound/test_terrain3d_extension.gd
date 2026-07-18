## Smoke check for the vendored Terrain3D native extension. It deliberately
## validates the real runtime class, not only the presence of copied files.
extends SceneTree

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
	_assert(ClassDB.class_exists(&"Terrain3D"), "Terrain3D native runtime class is registered")
	_assert(ClassDB.class_exists(&"Terrain3DCollision"), "Terrain3D collision API is registered")
	var terrain := ClassDB.instantiate(&"Terrain3D") as Node3D
	_assert(terrain != null, "Terrain3D creates a renderable Node3D instance")
	if terrain != null:
		get_root().add_child(terrain)
		var collision = terrain.get("collision")
		_assert(collision != null, "Terrain3D exposes terrain collision controls")
		if collision != null:
			print("Terrain3D collision class=%s mode=%s" % [collision.get_class(), collision.get("mode")])
		terrain.queue_free()
	quit(_exit_code)
