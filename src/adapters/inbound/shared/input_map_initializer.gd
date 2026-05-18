extends Node

func _ready() -> void:
    _ensure_action("move_forward", [KEY_W, KEY_UP])
    _ensure_action("move_back", [KEY_S, KEY_DOWN])
    _ensure_action("move_left", [KEY_A, KEY_LEFT])
    _ensure_action("move_right", [KEY_D, KEY_RIGHT])
    _ensure_action("jump", [KEY_SPACE])
    _ensure_action("sprint", [KEY_SHIFT])
    _ensure_action("interact", [KEY_E])
    print("InputMap initialized")

func _ensure_action(action_name: String, keycodes: Array) -> void:
    if not InputMap.has_action(action_name):
        InputMap.add_action(action_name)
    for keycode in keycodes:
        # Check if event already exists to avoid duplicates
        var exists := false
        for existing in InputMap.action_get_events(action_name):
            if existing is InputEventKey and existing.keycode == keycode:
                exists = true
                break
        if exists:
            continue
        var event := InputEventKey.new()
        event.keycode = keycode
        InputMap.action_add_event(action_name, event)
