extends Node

func _ready() -> void:
    _ensure_action("move_forward", [KEY_W, KEY_UP])
    _ensure_action("move_back", [KEY_S, KEY_DOWN])
    _ensure_action("move_left", [KEY_A, KEY_LEFT])
    _ensure_action("move_right", [KEY_D, KEY_RIGHT])
    _ensure_action("jump", [KEY_SPACE])
    _ensure_action("sprint", [KEY_SHIFT])
    _ensure_action("interact", [KEY_E])
    # Roblox-style combat + build inputs for 7yo player.
    _ensure_action("attack", [KEY_J, KEY_F])         # left-click also wired in player_controller
    _ensure_action("place_block", [KEY_K])           # voxel build / drop block from hotbar
    _ensure_action("break_block", [KEY_L])           # mine / destroy block
    _ensure_action("hotbar_1", [KEY_1])
    _ensure_action("hotbar_2", [KEY_2])
    _ensure_action("hotbar_3", [KEY_3])
    _ensure_action("hotbar_4", [KEY_4])
    _ensure_action("hotbar_5", [KEY_5])
    # Player 2 (local split-screen co-op) — right-hand keys so both kids share
    # one keyboard. Arrows move, RCtrl attacks, RShift sprints, Enter jumps.
    _ensure_action("p2_move_forward", [KEY_UP])
    _ensure_action("p2_move_back", [KEY_DOWN])
    _ensure_action("p2_move_left", [KEY_LEFT])
    _ensure_action("p2_move_right", [KEY_RIGHT])
    _ensure_action("p2_jump", [KEY_KP_0, KEY_ENTER])
    _ensure_action("p2_sprint", [KEY_CTRL])
    _ensure_action("p2_attack", [KEY_KP_1, KEY_SLASH])
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
