## Focused regression coverage for the opening HUD: first-frame controls must
## stay compact, while the build undo affordance becomes visible only after a
## world edit. This test deliberately avoids the complete main scene so it is
## independent of launcher/evidence-capture composition.
extends SceneTree

const GameplayRuntime = preload("res://src/adapters/inbound/gameplay/gameplay_runtime.gd")


class TestGameplayRuntime extends GameplayRuntime:
	func _ready() -> void:
		pass


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
	var runtime := TestGameplayRuntime.new()
	get_root().add_child(runtime)
	await process_frame
	runtime._build_hud()
	var hud := runtime.get_node_or_null("HUD") as CanvasLayer
	var menu := hud.get_node_or_null("AdventureMenuBtn") as MenuButton if hud != null else null
	var undo := hud.get_node_or_null("UndoBtn") as Button if hud != null else null
	_assert(menu != null, "opening HUD uses one compact game menu")
	_assert(hud != null and hud.get_node_or_null("BackBtn") == null and hud.get_node_or_null("CustomizeBtn") == null,
		"opening HUD removes the persistent back/customize button strip")
	_assert(menu != null and menu.get_popup().item_count == 2,
		"compact menu keeps appearance and safe-return actions reachable")
	_assert(undo != null and not undo.visible, "undo is hidden before the child builds")
	runtime._set_undo_button_visible(true)
	_assert(undo != null and undo.visible, "undo becomes available after a build edit")
	runtime.queue_free()
	await process_frame
	quit(_exit_code)
