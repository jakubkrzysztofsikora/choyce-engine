extends Node

func _ready() -> void:
	# --- PLAYER 1 (SOLO & CO-OP P1 / DEVICE 0) ---
	_ensure_action("move_forward", [KEY_W, KEY_UP], _joy_axis(JOY_AXIS_LEFT_Y, -1.0), _joy_button(JOY_BUTTON_DPAD_UP))
	_ensure_action("move_back", [KEY_S, KEY_DOWN], _joy_axis(JOY_AXIS_LEFT_Y, 1.0), _joy_button(JOY_BUTTON_DPAD_DOWN))
	_ensure_action("move_left", [KEY_A, KEY_LEFT], _joy_axis(JOY_AXIS_LEFT_X, -1.0), _joy_button(JOY_BUTTON_DPAD_LEFT))
	_ensure_action("move_right", [KEY_D, KEY_RIGHT], _joy_axis(JOY_AXIS_LEFT_X, 1.0), _joy_button(JOY_BUTTON_DPAD_RIGHT))
	_ensure_action("jump", [KEY_SPACE], _joy_button(JOY_BUTTON_A))                                 # PS4 Cross (✕)
	_ensure_action("sprint", [KEY_SHIFT], _joy_button(JOY_BUTTON_LEFT_STICK))                       # PS4 L3
	_ensure_action("interact", [KEY_E], _joy_button(JOY_BUTTON_X))                                 # PS4 Square (☐)
	_ensure_action("attack", [KEY_J, KEY_F], _joy_button(JOY_BUTTON_RIGHT_SHOULDER), _joy_axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)) # PS4 R1 / R2
	_ensure_action("place_block", [KEY_K], _joy_button(JOY_BUTTON_X), _mouse_button(MOUSE_BUTTON_LEFT))  # PS4 Square (☐) or Left Click
	_ensure_action("break_block", [KEY_L], _joy_button(JOY_BUTTON_B), _mouse_button(MOUSE_BUTTON_RIGHT)) # PS4 Circle (◯) or Right Click
	_ensure_action("undo", [KEY_U], _joy_button(JOY_BUTTON_BACK))                                 # PS4 Share / Select
	_ensure_action("inventory", [KEY_I], _joy_button(JOY_BUTTON_Y))                               # PS4 Triangle (△)
	_ensure_action("silly_fart", [KEY_G], _joy_button(JOY_BUTTON_LEFT_SHOULDER))                  # PS4 L1
	_ensure_action("hotbar_1", [KEY_1], _joy_button(JOY_BUTTON_DPAD_LEFT))
	_ensure_action("hotbar_2", [KEY_2], _joy_button(JOY_BUTTON_DPAD_UP))
	_ensure_action("hotbar_3", [KEY_3], _joy_button(JOY_BUTTON_DPAD_RIGHT))
	_ensure_action("hotbar_4", [KEY_4], _joy_button(JOY_BUTTON_DPAD_DOWN))
	_ensure_action("hotbar_5", [KEY_5])

	# Vehicle actions (P1)
	_ensure_action("accelerate", [KEY_W, KEY_UP], _joy_axis(JOY_AXIS_TRIGGER_RIGHT, 1.0))
	_ensure_action("reverse", [KEY_S, KEY_DOWN], _joy_axis(JOY_AXIS_TRIGGER_LEFT, 1.0))
	_ensure_action("steer_left", [KEY_A, KEY_LEFT], _joy_axis(JOY_AXIS_LEFT_X, -1.0))
	_ensure_action("steer_right", [KEY_D, KEY_RIGHT], _joy_axis(JOY_AXIS_LEFT_X, 1.0))
	_ensure_action("brake", [KEY_SPACE, KEY_SHIFT], _joy_button(JOY_BUTTON_B))
	_ensure_action("exit_vehicle", [KEY_E, KEY_ESCAPE], _joy_button(JOY_BUTTON_Y))
	_ensure_action("blade_toggle", [KEY_Q], _joy_button(JOY_BUTTON_X))

	# Training actions (P1)
	# NOTE: train_jump/train_run/train_climb deliberately have NO key bindings.
	# They used to sit on J/K/L, shadowing attack/place_block/break_block — every
	# sword swing also fired a training action. Training happens via E at a
	# station/anchor (interaction_action path); the actions stay registered so
	# legacy code referencing them keeps working, just with no bound keys.
	_ensure_action("find_food", [KEY_H])
	_ensure_action("train_jump", [])
	_ensure_action("train_run", [])
	_ensure_action("train_climb", [])
	_ensure_action("train_push", [KEY_SEMICOLON])
	_ensure_action("train_pull", [KEY_APOSTROPHE])
	_ensure_action("train_balance", [KEY_O])

	# --- PLAYER 2 (CO-OP P2 / DEVICE 1 or KEYPAD) ---
	_ensure_action("p2_move_forward", [KEY_UP], _joy_axis(JOY_AXIS_LEFT_Y, -1.0, 1), _joy_button(JOY_BUTTON_DPAD_UP, 1))
	_ensure_action("p2_move_back", [KEY_DOWN], _joy_axis(JOY_AXIS_LEFT_Y, 1.0, 1), _joy_button(JOY_BUTTON_DPAD_DOWN, 1))
	_ensure_action("p2_move_left", [KEY_LEFT], _joy_axis(JOY_AXIS_LEFT_X, -1.0, 1), _joy_button(JOY_BUTTON_DPAD_LEFT, 1))
	_ensure_action("p2_move_right", [KEY_RIGHT], _joy_axis(JOY_AXIS_LEFT_X, 1.0, 1), _joy_button(JOY_BUTTON_DPAD_RIGHT, 1))
	_ensure_action("p2_jump", [KEY_KP_0, KEY_ENTER], _joy_button(JOY_BUTTON_A, 1))                # PS4 Cross (✕)
	_ensure_action("p2_sprint", [KEY_CTRL], _joy_button(JOY_BUTTON_LEFT_STICK, 1))                # PS4 L3
	_ensure_action("p2_attack", [KEY_KP_1, KEY_SLASH], _joy_button(JOY_BUTTON_RIGHT_SHOULDER, 1), _joy_axis(JOY_AXIS_TRIGGER_RIGHT, 1.0, 1))
	_ensure_action("p2_place_block", [KEY_KP_ADD], _joy_button(JOY_BUTTON_X, 1))                  # PS4 Square (☐)
	_ensure_action("p2_break_block", [KEY_KP_SUBTRACT], _joy_button(JOY_BUTTON_B, 1))              # PS4 Circle (◯)
	_ensure_action("p2_undo", [KEY_KP_MULTIPLY], _joy_button(JOY_BUTTON_BACK, 1))
	_ensure_action("p2_inventory", [KEY_KP_PERIOD], _joy_button(JOY_BUTTON_Y, 1))                 # PS4 Triangle (△)
	_ensure_action("p2_hotbar_1", [KEY_KP_2], _joy_button(JOY_BUTTON_DPAD_LEFT, 1))
	_ensure_action("p2_hotbar_2", [KEY_KP_3], _joy_button(JOY_BUTTON_DPAD_UP, 1))
	_ensure_action("p2_hotbar_3", [KEY_KP_4], _joy_button(JOY_BUTTON_DPAD_RIGHT, 1))
	_ensure_action("p2_hotbar_4", [KEY_KP_5], _joy_button(JOY_BUTTON_DPAD_DOWN, 1))
	_ensure_action("p2_hotbar_5", [KEY_KP_6])
	_ensure_action("p2_look_left", [KEY_KP_7], _joy_axis(JOY_AXIS_RIGHT_X, -1.0, 1))
	_ensure_action("p2_look_right", [KEY_KP_9], _joy_axis(JOY_AXIS_RIGHT_X, 1.0, 1))

	print("InputMap initialized with Keyboard + Mouse & PS4 Gamepad support")


func _ensure_action(action_name: String, keycodes: Array, ev1: InputEvent = null, ev2: InputEvent = null) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	for keycode in keycodes:
		var exists := false
		for existing in InputMap.action_get_events(action_name):
			if existing is InputEventKey and existing.keycode == keycode:
				exists = true
				break
		if not exists:
			var event := InputEventKey.new()
			event.keycode = keycode
			InputMap.action_add_event(action_name, event)
	if ev1 != null:
		_add_event_if_missing(action_name, ev1)
	if ev2 != null:
		_add_event_if_missing(action_name, ev2)


func _add_event_if_missing(action_name: String, event: InputEvent) -> void:
	for existing in InputMap.action_get_events(action_name):
		if existing.is_match(event, true):
			return
	InputMap.action_add_event(action_name, event)


func _joy_button(button_idx: JoyButton, device: int = 0) -> InputEventJoypadButton:
	var ev := InputEventJoypadButton.new()
	ev.button_index = button_idx
	ev.device = device
	return ev


func _joy_axis(axis_idx: JoyAxis, value: float, device: int = 0) -> InputEventJoypadMotion:
	var ev := InputEventJoypadMotion.new()
	ev.axis = axis_idx
	ev.axis_value = value
	ev.device = device
	return ev


func _mouse_button(button_idx: MouseButton) -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = button_idx
	ev.pressed = true
	return ev
