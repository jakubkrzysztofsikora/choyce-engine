class_name MultiplayerInputSystem
extends Node
## Autoload: MultiplayerInput  (reach it as MultiplayerInputSystem.instance)
##
## Deliberately NOT referenced via the bare autoload identifier: the class_name +
## static instance pair resolves at compile time regardless of whether the editor
## has refreshed its autoload globals. The bare identifier does not.
##
## Routes input from N physical devices to N logical players.
##
## Approach (same as matjlars/godot-multiplayer-input, reimplemented here so the
## kit has no external dependency for the riskiest system): every base action in
## the InputMap is duplicated per device, namespaced "<device><action>".
## Device -1 == keyboard/mouse. Devices 0..7 == joypads.
##
## Usage:
##   MultiplayerInput.get_vector(device, "move_left","move_right","move_fwd","move_back")
##   MultiplayerInput.is_action_pressed(device, "jump")
##   MultiplayerInput.is_action_just_pressed(device, "interact")

static var instance: MultiplayerInputSystem

const KEYBOARD_DEVICE := -1

## Base actions that get per-device copies. ui_* is deliberately excluded.
var _base_actions: PackedStringArray = []
var _known_devices: Array[int] = []

signal device_connected(device: int)
signal device_disconnected(device: int)


func _ready() -> void:
	instance = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	_collect_base_actions()
	_register_device(KEYBOARD_DEVICE)
	for joy_id in Input.get_connected_joypads():
		_register_device(joy_id)
	Input.joy_connection_changed.connect(_on_joy_connection_changed)


func _collect_base_actions() -> void:
	_base_actions.clear()
	for action in InputMap.get_actions():
		var name := String(action)
		if name.begins_with("ui_"):
			continue
		# Skip already-namespaced copies if _ready somehow runs twice.
		if name.length() > 0 and (name[0].is_valid_int() or name.begins_with("-1")):
			continue
		_base_actions.append(name)


func _on_joy_connection_changed(device: int, connected: bool) -> void:
	if connected:
		_register_device(device)
		device_connected.emit(device)
	else:
		device_disconnected.emit(device)


## Public: guarantees a device has its namespaced action set, even if no
## physical joypad with that id is present (used by tests and hotseat harnesses).
func ensure_device(device: int) -> void:
	_register_device(device)


func _register_device(device: int) -> void:
	if device in _known_devices:
		return
	_known_devices.append(device)
	for base in _base_actions:
		var action := _namespaced(device, base)
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action, InputMap.action_get_deadzone(base))
		for ev in InputMap.action_get_events(base):
			var copy := ev.duplicate()
			if copy is InputEventJoypadButton or copy is InputEventJoypadMotion:
				if device == KEYBOARD_DEVICE:
					continue  # keyboard player gets no joypad bindings
				copy.device = device
				InputMap.action_add_event(action, copy)
			else:
				if device != KEYBOARD_DEVICE:
					continue  # joypad players get no keyboard bindings
				InputMap.action_add_event(action, copy)


static func _namespaced(device: int, action: StringName) -> StringName:
	return StringName(str(device) + String(action))


func devices() -> Array[int]:
	return _known_devices.duplicate()


## --- Input singleton mirror -------------------------------------------------

func is_action_pressed(device: int, action: StringName) -> bool:
	return Input.is_action_pressed(_namespaced(device, action))


func is_action_just_pressed(device: int, action: StringName) -> bool:
	return Input.is_action_just_pressed(_namespaced(device, action))


func is_action_just_released(device: int, action: StringName) -> bool:
	return Input.is_action_just_released(_namespaced(device, action))


func get_action_strength(device: int, action: StringName) -> float:
	return Input.get_action_strength(_namespaced(device, action))


func get_axis(device: int, neg: StringName, pos: StringName) -> float:
	return Input.get_axis(_namespaced(device, neg), _namespaced(device, pos))


func get_vector(device: int, neg_x: StringName, pos_x: StringName,
		neg_y: StringName, pos_y: StringName, deadzone: float = -1.0) -> Vector2:
	return Input.get_vector(
		_namespaced(device, neg_x), _namespaced(device, pos_x),
		_namespaced(device, neg_y), _namespaced(device, pos_y), deadzone)


## Returns the device id of whoever pressed `action` this frame, or -99 if nobody.
func first_device_pressing(action: StringName) -> int:
	for device in _known_devices:
		if is_action_just_pressed(device, action):
			return device
	return -99
