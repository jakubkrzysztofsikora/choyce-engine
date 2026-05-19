# Godot 4 Input / Control-Mapping Patterns for Kid-Friendly Action Games

**Date**: 2026-05-19  
**Target player**: 7-year-old, Roblox/Minecraft familiarity  
**Platforms**: Desktop KB+M, Xbox/PS controller, tablet touch

---

## Canonical Input Map v2 (choyce-engine)

| Action | KB+M default | Controller default | Touch default |
|---|---|---|---|
| move_forward | W | Left stick up | Virtual stick up |
| move_back | S | Left stick down | Virtual stick down |
| move_left | A | Left stick left | Virtual stick left |
| move_right | D | Left stick right | Virtual stick right |
| jump | Space | A (Xbox) / Cross (PS) | Jump button bottom-right |
| sprint | Shift (hold) | Left stick click | Sprint toggle button |
| interact | E | X (Xbox) / Square (PS) | Interact button |
| break_block | LMB | Right trigger | Tap block |
| place_block | RMB | Left trigger | Long-press / place button |
| attack | LMB combat | Right trigger combat | Attack button combat |
| hotbar_1-5 | 1-5 | D-pad left/right | Hotbar strip bottom |
| camera_look | RMB drag | Right stick | Two-finger drag |
| cam_zoom_in | Scroll up | D-pad up build | Pinch out |
| cam_zoom_out | Scroll down | D-pad down build | Pinch in |
| menu_back | Escape | B (Xbox) / Circle (PS) | Back button top-left |

**Key change from v1**: LMB = break_block (Minecraft convention). RMB = place_block. Attack aliases LMB/right-trigger resolved by GameModeService. No modal switch button needed.

---

## 1. InputMap Rebinding + save to user://

Core pattern (GoTut + GDQuest):

    InputMap.action_erase_events(action_name)
    InputMap.action_add_event(action_name, new_event)
    cfg.set_value(action, "type", "key")
    cfg.set_value(action, "code", ev.physical_keycode)
    cfg.save("user://keybinds.cfg")

Duplicate-binding guard: iterate InputMap.get_actions(), build reverse map event.as_text() -> action, erase from colliding action first.
Rebind UI: parent zone Controls tab. Parent sets; kid plays. Actions list = all entries in canonical map.

Sources: [GoTut](https://www.gotut.net/custom-key-bindings-in-godot-4/) | [GDQuest cheatsheet](https://school.gdquest.com/cheatsheets/input)

---

## 2. Joypad Device Detection + Prompt Swap

    func _ready():
        _determine_controller(0, false)
        Input.joy_connection_changed.connect(_determine_controller)

    func _determine_controller(device, connected):
        var joys = Input.get_connected_joypads()
        controller_used = "" if joys.is_empty() else Input.get_joy_name(joys[-1])

Pattern-match "Xbox" / "PS" / "" -> icon set. Windows bug (Godot 4.4-4.5.x): hot-plug after game start may not fire signal. Fallback: poll every 2s in _process.

Sources: [Inglo Games](https://inglo-games.github.io/2025/06/03/input-prompts.html) | [Godot docs](https://docs.godotengine.org/en/stable/tutorials/inputs/controllers_gamepads_joysticks.html) | [Issue 112802](https://github.com/godotengine/godot/issues/112802)

---

## 3. Controller Deadzone + Sensitivity Curve

Radial deadzone 0.28 + exponent curve 2.0 for kid thumbs:

    var stick = Vector2(Input.get_joy_axis(0, JOY_AXIS_LEFT_X), Input.get_joy_axis(0, JOY_AXIS_LEFT_Y))
    const DZ = 0.28
    if stick.length() < DZ:
        stick = Vector2.ZERO
    else:
        stick = stick.normalized() * ((stick.length() - DZ) / (1.0 - DZ))
        stick = stick.normalized() * pow(stick.length(), 2.0)

Keep InputMap action deadzone at 0.5 for digital buttons. Use raw get_joy_axis only for analog movement.

Sources: [Godot proposal 7069](https://github.com/godotengine/godot-proposals/issues/7069)

---

## 4. Touch Controls

Plugin: [MarcoFazioRandom/Virtual-Joystick-Godot](https://github.com/MarcoFazioRandom/Virtual-Joystick-Godot) - MIT, Godot 4.2+.
API: joystick.output (Vector2) + joystick.is_pressed. Set use_input_actions = true to fire move_* actions directly.

Layout for 7yo tablet: left half = Dynamic joystick 120px thumb. Right half = jump + interact + break buttons, 80px+ (10mm minimum). Break/place toggle center-bottom.

Project settings: Emulate Touch from Mouse ON, Emulate Mouse from Touch OFF.

---

## 5. Adaptive HUD Hints Spec

Autoload InputDeviceTracker singleton. In _input(): detect InputEventKey/MouseButton -> KEYBOARD, InputEventJoypad* -> GAMEPAD, InputEventScreenTouch -> TOUCH. Emit device_changed signal on state change.

HUD CanvasLayer always-on. Top-3 actions for current mode. Each entry: BBCode [img=32x32]{glyph}[/img] + label in RichTextLabel. Fade out 8s after last device switch.

Icon pack: Kenney Input Prompts (CC0). Xbox / PS / KB / touch-circle icon sets.

Plugin alternative: [G.U.I.D.E](https://godotneers.github.io/G.U.I.D.E/) for complex multi-device prompt combos.

---

## 6. Auto-Attack (Brotato Pattern)

Timer-driven auto-attack in combat mode. Player input = movement only. Timer fires -> find nearest enemy via get_nodes_in_group, deal damage. No attack button. Best for 7yo. Can be parent-toggled via ParentalControlPolicy.

Sources: [DarkRewar SurvivorsStarterKit](https://www.blog.brightcoding.dev/2026/05/17/darkrewars-survivorsstarterkit-build-a-vampire-survivors-clone-in-godot-4-c)

---

## 7. Roblox-Style Camera

SpringArm3D inside yaw pivot. When MOUSE_BUTTON_RIGHT held: capture mouse, rotate yaw/pitch by event.relative. Clamp pitch [-80, 20] deg. Scroll wheel adjusts spring_length (2m-15m).

Sources: [KidsCanCode camera gimbal](https://kidscancode.org/godot_recipes/4.x/3d/camera_gimbal/index.html) | [ohmcodes SimpleCameraMovement](https://github.com/ohmcodes/Godot.SimpleCameraMovement)

---

## 8. Minecraft Bedrock / Voxel Controls

Reference: [Zylann/voxelgame](https://github.com/Zylann/voxelgame) blocky_game/ (Godot 4.4, MIT). Patch player script to read InputMap actions. Controller: right trigger = break_block, left trigger = place_block. Touch: MarcoFazioRandom joystick + large break/place buttons on right side.

---

## Rebind UI Spec (Parent Zone)

Parent Zone -> new Controls tab. VBoxContainer, one row per action. Row: Label + Button (current binding) + Reset. Clicking button enters listen-mode; next event replaces binding. Save button -> user://keybinds.cfg. Restore Defaults reloads from ProjectSettings.

Scope v1: KB+M only. Controller remapping deferred.

---

## Logic Gates: Build vs Combat Mode

Single input set. GameModeService infers from equipped item (block vs weapon):
- LMB / right trigger -> break_block (build) or attack (combat)
- RMB / left trigger -> place_block (build) or block/dodge (combat)
- Hotbar and sprint active in both modes
- No mode-switch button -> zero 7yo cognitive load

Matches Minecraft Bedrock parity.

---

## All Sources

- [GoTut custom key bindings](https://www.gotut.net/custom-key-bindings-in-godot-4/)
- [GDQuest input remapping](https://www.gdquest.com/tutorial/godot/ui/user-interface-tutorials/chapter/08-input-remapping/)
- [GDQuest input cheatsheet](https://school.gdquest.com/cheatsheets/input)
- [KidsCanCode input actions](https://kidscancode.org/godot_recipes/4.x/input/input_actions/)
- [Inglo Games dynamic prompts](https://inglo-games.github.io/2025/06/03/input-prompts.html)
- [Godot docs controllers](https://docs.godotengine.org/en/stable/tutorials/inputs/controllers_gamepads_joysticks.html)
- [Godot issue 112802 Windows hot-plug](https://github.com/godotengine/godot/issues/112802)
- [MarcoFazioRandom Virtual-Joystick-Godot MIT](https://github.com/MarcoFazioRandom/Virtual-Joystick-Godot)
- [G.U.I.D.E plugin](https://godotneers.github.io/G.U.I.D.E/)
- [Godot proposal 7069 deadzone](https://github.com/godotengine/godot-proposals/issues/7069)
- [KidsCanCode camera gimbal](https://kidscancode.org/godot_recipes/4.x/3d/camera_gimbal/index.html)
- [Zylann/voxelgame Godot 4.4](https://github.com/Zylann/voxelgame)
- [DarkRewar SurvivorsStarterKit](https://www.blog.brightcoding.dev/2026/05/17/darkrewars-survivorsstarterkit-build-a-vampire-survivors-clone-in-godot-4-c)
- [gamedevartisan input remapping](https://gamedevartisan.com/tutorials/godot-fundamentals/input-remapping)
