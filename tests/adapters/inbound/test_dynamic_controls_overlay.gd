extends SceneTree

const CONTROLS_OVERLAY := preload("res://src/adapters/inbound/gameplay/dynamic_controls_overlay.gd")

var _failures: Array[String] = []


func _init() -> void:
	print("--- STARTING DYNAMIC CONTROLS & PS4 GAMEPAD TEST SUITE ---")
	var initializer_script := load("res://src/adapters/inbound/shared/input_map_initializer.gd") as GDScript
	var initializer: Node = initializer_script.new()
	initializer._ready()
	initializer.free()

	_test_input_map_gamepad_bindings()
	_test_dynamic_controls_overlay_population()

	if _failures.is_empty():
		print("[test_dynamic_controls_overlay] ALL TESTS PASSED SUCCESSFULLY!")
		quit(0)
	else:
		printerr("[test_dynamic_controls_overlay] FAILED WITH ", _failures.size(), " ERRORS: ", _failures)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
		printerr("[FAIL] ", message)
	else:
		print("[PASS] ", message)


func _test_input_map_gamepad_bindings() -> void:
	# Ensure InputMap has key and gamepad events for jump
	_expect(InputMap.has_action("jump"), "InputMap should have action jump")
	var jump_events := InputMap.action_get_events("jump")
	var has_key := false
	var has_joy := false
	for ev in jump_events:
		if ev is InputEventKey:
			has_key = true
		elif ev is InputEventJoypadButton and ev.button_index == JOY_BUTTON_A:
			has_joy = true
	_expect(has_key, "jump action should have Keyboard key binding")
	_expect(has_joy, "jump action should have PS4 Cross (JOY_BUTTON_A) binding")

	# Ensure P2 has gamepad bindings
	_expect(InputMap.has_action("p2_jump"), "InputMap should have action p2_jump")
	var p2_jump_events := InputMap.action_get_events("p2_jump")
	var p2_has_joy := false
	for ev in p2_jump_events:
		if ev is InputEventJoypadButton and ev.device == 1:
			p2_has_joy = true
	_expect(p2_has_joy, "p2_jump action should have Device 1 Gamepad binding")


func _test_dynamic_controls_overlay_population() -> void:
	var overlay := CONTROLS_OVERLAY.new()
	root.add_child(overlay)

	overlay.open()
	_expect(overlay.visible == true, "Overlay should be visible on open()")

	var ps4_x_name := overlay._ps4_button_name(JOY_BUTTON_A)
	_expect(ps4_x_name.contains("Cross"), "JOY_BUTTON_A should format as PS4 Cross")

	var ps4_sq_name := overlay._ps4_button_name(JOY_BUTTON_X)
	_expect(ps4_sq_name.contains("Square"), "JOY_BUTTON_X should format as PS4 Square")

	var formatted_jump := overlay._format_ps4_events("jump")
	_expect(formatted_jump.contains("Cross"), "Formatted jump PS4 events should contain Cross")

	overlay.close()
	_expect(overlay.visible == false, "Overlay should hide on close()")
	overlay.queue_free()
