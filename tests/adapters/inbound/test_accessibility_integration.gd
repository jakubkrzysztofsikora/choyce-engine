extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var root := Control.new()
	var play_button := Button.new()
	play_button.text = "Play"
	root.add_child(play_button)
	get_root().add_child(root)

	var adapter := GodotAccessibilityAdapter.new().setup(root)
	adapter.apply_baseline_contrast()

	if root.theme == null:
		print("FAIL: Baseline contrast should assign a theme")
		_cleanup_and_exit(root, 1)
		return
	if not root.theme.has_stylebox("normal", "Button"):
		print("FAIL: Baseline contrast should define button normal style")
		_cleanup_and_exit(root, 1)
		return

	adapter.set_dyslexia_font(true)
	if root.theme.default_font == null:
		print("FAIL: Dyslexia mode should apply a font override")
		_cleanup_and_exit(root, 1)
		return

	adapter.set_motor_scale(1.25)
	if play_button.custom_minimum_size.x < 56.0 or play_button.custom_minimum_size.y < 56.0:
		print("FAIL: Motor mode should increase touch targets to minimum size")
		_cleanup_and_exit(root, 1)
		return

	adapter.set_captions_enabled(true)
	adapter.show_caption("Test captions", 0.2)

	var overlay_found := false
	for child in root.get_children():
		if child is CaptionsOverlay:
			overlay_found = true
			var overlay: CaptionsOverlay = child
			await process_frame
			if not overlay.visible:
				print("FAIL: Captions overlay should become visible after show_caption")
				_cleanup_and_exit(root, 1)
				return
			break

	if not overlay_found:
		print("FAIL: Captions overlay was not added to root control")
		_cleanup_and_exit(root, 1)
		return

	print("ACCESSIBILITY_INTEGRATION_TEST: PASS")
	_cleanup_and_exit(root, 0)


func _cleanup_and_exit(root: Control, code: int) -> void:
	if root != null:
		root.queue_free()
	quit(code)
