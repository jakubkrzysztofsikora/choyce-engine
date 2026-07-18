## The launch menu must retain the real 3D cinematic as key art, not dissolve
## to the old placeholder gradient once the seven-second attract beat ends.
extends SceneTree

const LauncherOverlay = preload("res://src/adapters/inbound/scenes/launcher/launcher_overlay.gd")

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
	var launcher := LauncherOverlay.new()
	get_root().add_child(launcher)
	await process_frame
	_assert(launcher._cinematic_container != null and launcher._cinematic_container.visible,
		"launcher begins with a rendered 3D cinematic layer")
	launcher._reveal_menu()
	await process_frame
	var menu_column := launcher._root.get_node_or_null("CenterColumn") as Control
	_assert(launcher._cinematic_container != null and launcher._cinematic_container.visible \
		and launcher._cinematic_container.modulate.a > 0.99,
		"menu retains the final 3D cinematic frame instead of fading to a placeholder")
	_assert(launcher._cinematic_viewport.render_target_update_mode == SubViewport.UPDATE_ONCE,
		"settled launcher freezes the cinematic background after its final frame")
	_assert(launcher._menu_vignette != null and menu_column != null \
		and launcher._root.get_child(-1) == menu_column,
		"vignette sits behind launcher controls while controls stay above 3D key art")
	_assert(launcher._play_btn.focus_mode == Control.FOCUS_CLICK and not launcher._play_btn.has_focus(),
		"launcher waits for an intentional Play click instead of focusing and auto-starting")
	launcher.queue_free()
	await process_frame
	quit(_exit_code)
