## Regression coverage for the retired opening nutrition overlay.  The scene
## must remain a typed NutritionHUD (so GameplayRuntime._ready does not abort)
## while its old developer-style panel stays hidden until a later inventory UI
## deliberately owns it.
extends SceneTree

const NutritionHUDScene = preload("res://src/adapters/inbound/scenes/hud/nutrition_hud.tscn")
const NutritionHUDScript = preload("res://src/adapters/inbound/scenes/hud/nutrition_hud.gd")
const GameplayRuntime = preload("res://src/adapters/inbound/gameplay/gameplay_runtime.gd")
const TrainingManager = preload("res://src/adapters/inbound/gameplay/training_manager.gd")

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
	var hud := NutritionHUDScene.instantiate()
	get_root().add_child(hud)
	await process_frame
	var legacy_panel := hud.get_node_or_null("Panel") as Panel
	_assert(hud.get_script() == NutritionHUDScript,
		"NutritionHUD scene root owns its controller script and satisfies the typed runtime contract")
	_assert(legacy_panel != null and not legacy_panel.visible,
		"legacy text-heavy nutrition panel is hidden from the Adventure opening frame")
	var imported_character_root := Node3D.new()
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	imported_character_root.add_child(mesh)
	var runtime := GameplayRuntime.new()
	_assert(runtime._find_first_mesh_instance(imported_character_root) == mesh,
		"runtime resolves the first real mesh inside an imported character Node3D hierarchy")
	var training := TrainingManager.new()
	get_root().add_child(training)
	await process_frame
	training.set_player_mesh(mesh)
	_assert(training.player_mesh == mesh,
		"body-progression setup safely accepts a ready-made mesh without authored blend shapes")
	training.queue_free()
	runtime.queue_free()
	imported_character_root.queue_free()
	hud.queue_free()
	await process_frame
	quit(_exit_code)
