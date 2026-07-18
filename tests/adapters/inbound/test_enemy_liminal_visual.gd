## Regression: Adventure enemies must use a grounded creature model, not the
## green/pink primitive placeholders from the early prototype.
extends SceneTree

const EnemyControllerScript = preload("res://src/adapters/inbound/gameplay/enemy_controller.gd")

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
	var player := Node3D.new()
	get_root().add_child(player)
	var enemy := EnemyControllerScript.new()
	enemy.setup(EnemyDefinition.slime_green(), player)
	get_root().add_child(enemy)
	await process_frame
	_assert(enemy.get_node_or_null("LiminalWatcherVisual") != null, "enemy uses the bundled liminal creature model")
	_assert(enemy._mesh != null and not enemy._mesh.visible, "legacy coloured primitive is hidden when model loading succeeds")
	var model := enemy.get_node_or_null("LiminalWatcherVisual") as Node3D
	_assert(model != null and model.get_child_count() >= 2, "model includes anchored visual detail")
	_assert(enemy._collision != null, "model encounter retains a physical collision shape")
	enemy.queue_free()
	player.queue_free()
	await process_frame
	quit(_exit_code)
