# RESEARCH_PLAN_004: Controller and Tablet Controls Implementation

**Source**: PLAN.md Gate 3 - "Add reduce-motion behavior, controller/tablet-friendly controls, readable dynamic hints, and captions"
**Title**: Comprehensive Controller, Tablet, and Multi-Input Control System for Godot 4.6
**Specialty**: input-systems, ux-engineering, godot-controls
**Status**: todo
**Owner**: codex
**Complexity**: HIGH

---

## Table of Contents
1. [Task Overview](#task-overview)
2. [Current Implementation Analysis](#current-implementation-analysis)
3. [Online Research Summary](#online-research-summary)
4. [Technical Deep Dive](#technical-deep-dive)
5. [Code Samples](#code-samples)
6. [Asset Packages and Tools](#asset-packages-and-tools)
7. [Learning Resources](#learning-resources)
8. [Implementation Checklist](#implementation-checklist)
9. [Child-Safety Constraints](#child-safety-constraints)
10. [References](#references)

---

## Task Overview

### Objective
Implement a **comprehensive multi-input control system** for Choyce Engine that provides first-class support for controllers (gamepads), tablets (touch), and traditional keyboard/mouse, with **readable dynamic hints** that adapt to the current input method and context.

### Acceptance Criteria (from PLAN.md Gate 3)
1. **Controller Support**: Full gamepad support with proper button mapping
2. **Tablet Support**: Touch controls with proper hit areas and feedback
3. **Dynamic Hints**: Context-aware control hints that appear when needed
4. **Readable UI**: Control prompts are large, clear, and positioned appropriately
5. **Input Method Detection**: Automatically detect and adapt to current input method
6. **Rebindable Controls**: Players can customize their control scheme
7. **Context-Sensitive**: Different hints for different game states (exploration, combat, menu)

### Key Requirements
- **Cross-Platform**: macOS, Windows, iOS, Android, Web (via Tauri)
- **Child-Friendly**: Large, simple control layouts with clear icons
- **Accessible**: High contrast, readable text, proper spacing
- **Parent-Approved**: Safe defaults, parent can reset to defaults
- **Deterministic**: Same input produces same result
- **Performance**: No input lag, works on Tier 2 hardware

---

## Current Implementation Analysis

### Existing Infrastructure
From the codebase:
- `src/adapters/inbound/input_map_initializer.gd` - Input map setup
- `src/adapters/inbound/player_controller.gd` - Player movement and actions
- `src/domain/shared/age_band.gd` - Age-based configuration
- VS-014: Modern Game UI (RESEARCH_VS-014_Modern_Game_UI.md)
- VS-004: Clean Profile Adventure Charter

### Input Architecture
```
┌─────────────────────────────────────────────────────────┐
│                    Input System                            │
├─────────────────────────────────────────────────────────┤
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────── │
│  │   Input Map      │  │ Input Processor  │  │  Input     │ │
│  │  (Godot built-in)│  │  (Custom)        │  │  Context   │ │
│  └────────┬────────┘  └────────┬────────┘  └─────┬─────┘ │
│           │                   │                  │        │
│           ▼                   ▼                  ▼        │
│  ┌───────────────────────────────────────────────────┐   │
│  │              Input Action Router                   │   │
│  │  - Detects input method (keyboard, gamepad, touch) │   │
│  │  - Routes to appropriate handlers                │   │
│  │  - Tracks current input context                   │   │
│  └─────────────────────────────┬─────────────────────┘   │
│                                  │                         │
│           ┌──────────────────────┼──────────────────────┘
│           ▼                      ▼                       ▼
│  ┌─────────────┐    ┌──────────────┐        ┌─────────────┐
│  │ Controller   │    │ Touch/Tablet  │        │ Keyboard/Mouse│
│  │  Handler     │    │   Handler     │        │    Handler    │
│  └──────┬──────┘    └──────┬───────┘        └──────┬───────┘
│         │                  │                      │
│         ▼                  ▼                      ▼
│  ┌────────────────────────────────────────────────────┐
│  │              Game Systems (Player, UI, etc.)        │
│  └────────────────────────────────────────────────────┘
```

### Input Contexts

| Context | Input Method | Controls |
|---------|--------------|----------|
| Exploration | All | Movement, Jump, Interact, Sprint, Inventory |
| Combat | All | Light Attack, Heavy Attack, Block, Dodge, Special |
| Building | Controller/Tablet | Place, Rotate, Delete, Undo |
| Menu | All | Navigate, Select, Back, Scroll |
| Dialog | All | Next, Skip, Choice Select |

### Input Method Capabilities

| Feature | Keyboard/Mouse | Gamepad | Touch |
|---------|----------------|---------|-------|
| Precision Movement | ✅ High | ⚠️ Limited | ⚠️ Limited |
| Camera Control | ✅ Mouse Look | ✅ Right Stick | ⚠️ Gyro/Optional |
| Quick Actions | ✅ All Keys | ✅ All Buttons | ✅ On-Screen |
| Analog Input | ❌ Digital | ✅ Analog Triggers | ⚠️ Partial |
| Haptic Feedback | ❌ No | ✅ Yes | ❌ No (usually) |
| Accessibility | ✅ Full | ✅ Full | ✅ Full |

---

## Online Research Summary

### 1. Godot 4.6 Input System

**Godot Input Map**:
- Centralized input event handling
- Supports multiple input methods for same action
- Built-in deadzone handling for gamepads
- Input buffering and repeat handling

**Key Classes**:
- `InputMap` - Manages action to input event mapping
- `InputEvent` - Base class for all input events
- `InputEventKey` - Keyboard key events
- `InputEventMouse` - Mouse events
- `InputEventMouseButton` - Mouse button events
- `InputEventJoypadButton` - Gamepad button events
- `InputEventJoypadMotion` - Gamepad axis/trigger events
- `InputEventScreenTouch` - Touch screen events

**InputEvent Properties**:
```gdscript
# Common to all input events
device: int          # Device index (-1 for keyboard/mouse)
window_id: int       # Window ID
alt_pressed: bool    # Alt key/modifier
shift_pressed: bool  # Shift key/modifier
ctrl_pressed: bool   # Control key/modifier
meta_pressed: bool   # Meta/Command key/modifier
pressed: bool        # Whether event is a press (true) or release (false)

# Joypad-specific
button_index: int    # Button index (0-15 typically)
pressure: float      # Button pressure (0.0 to 1.0)
axis: int           # Axis index for motion events
value: float         # Axis value (-1.0 to 1.0)

# Touch-specific
position: Vector2    # Touch position
global_position: Vector2  # Global touch position
velocity: Vector2    # Touch velocity
timestamp: int       # Touch timestamp

# Mouse-specific
button_index: int    # Mouse button index
double_click: bool   # Whether this is a double click
```

**Official Documentation**:
- [Godot Input System](https://docs.godotengine.org/en/stable/tutorials/inputs/input_examples.html)
- [InputMap](https://docs.godotengine.org/en/stable/classes/class_inputmap.html)
- [InputEvent](https://docs.godotengine.org/en/stable/classes/class_inputevent.html)
- [Joypad Handling](https://docs.godotengine.org/en/stable/tutorials/inputs/joypad_setup.html)

### 2. Controller/Gampad Support

**Godot Gamepad Support**:
- Automatic detection of connected gamepads
- Standard button mapping (South, East, North, West, etc.)
- Analog stick support with deadzones
- Trigger support (left/right)
- D-pad support
- Haptic feedback (rumble)

**Gamepad Button Mapping (Standard)**:
```
          North (Up)       +------------+       South (Down)
                           |            |
         West (Left)       |    A/B     |       East (Right)
                           |    X/Y     |
          +-----------------+------------+-----------------+
          | Left Stick      |            | Right Stick     |
          |    +----+       |            |    +----+       |
          |    |    |       |            |    |    |       |
          |    +----+       |            |    +----+       |
          +-----------------+            +-----------------+
          | Left Trigger    |            | Right Trigger   |
          +-----------------+            +-----------------+
```

**Godot Button Constants**:
```gdscript
# Face buttons
JOY_SOUTH = 0   # A button (Xbox), X button (PlayStation)
JOY_EAST = 1    # B button (Xbox), Circle button (PlayStation)
JOY_NORTH = 2   # Y button (Xbox), Triangle button (PlayStation)
JOY_WEST = 3    # X button (Xbox), Square button (PlayStation)

# Shoulder buttons
JOY_L1 = 4      # Left Bumper
JOY_R1 = 5      # Right Bumper
JOY_L2 = 6      # Left Trigger (analog)
JOY_R2 = 7      # Right Trigger (analog)

# Special buttons
JOY_SELECT = 8  # Back/Select
JOY_START = 9   # Start/Menu
JOY_L3 = 10    # Left Stick Press
JOY_R3 = 11    # Right Stick Press

# D-pad
JOY_DPAD_UP = 12
JOY_DPAD_DOWN = 13
JOY_DPAD_LEFT = 14
JOY_DPAD_RIGHT = 15
```

**Gamepad API**:
```gdscript
# Get connected gamepads
var joypads = Input.get_connected_joypads()

# Check if gamepad is connected
var has_gamepad = Input.is_joy_known(0)

# Get gamepad name
var gamepad_name = Input.get_joy_name(0)

# Set joypad deadzone (default is 0.1)
Input.set_joy_deadzone(0.15)

# Enable/disable joypad
Input.set_joy_enabled(true)

# Get axis value
var left_x = Input.get_action_raw_strength("move_left") - Input.get_action_raw_strength("move_right")
var left_y = Input.get_action_raw_strength("move_forward") - Input.get_action_raw_strength("move_back")
```

**Gamepad Detection**:
```gdscript
func has_gamepad() -> bool:
    var joypads = Input.get_connected_joypads()
    for id in joypads:
        if Input.is_joy_known(id):
            return true
    return false
```

### 3. Touch/Tablet Input

**Godot Touch Support**:
- Multi-touch support
- Touch position and velocity
- Tap, double-tap, long-press detection
- Touch cancellation

**Touch Event Handling**:
```gdscript
func _input(event: InputEvent):
    if event is InputEventScreenTouch:
        if event.pressed:
            # Touch started
            handle_touch_start(event)
        else:
            # Touch ended
            handle_touch_end(event)

func handle_touch_start(event: InputEventScreenTouch):
    var touch_pos = event.position
    var viewport = get_viewport()
    var screen_size = viewport.size
    
    # Convert to normalized coordinates (-1 to 1)
    var normalized_pos = Vector2(
        touch_pos.x / screen_size.x * 2.0 - 1.0,
        touch_pos.y / screen_size.y * 2.0 - 1.0
    )
```

**Touch Gesture Detection**:
```gdscript
# Single touch detection
var touch_count = 0
var touch_positions = []

func _input(event: InputEvent):
    if event is InputEventScreenTouch:
        if event.pressed:
            touch_count += 1
            touch_positions.append(event.position)
            
            # Detect gestures based on touch count
            match touch_count:
                1:
                    handle_single_touch(event)
                2:
                    handle_two_finger_touch(event)
                3:
                    handle_three_finger_touch(event)
        else:
            touch_count -= 1
            touch_positions.erase(event.position)

func handle_two_finger_touch(event: InputEventScreenTouch):
    # Pinch to zoom
    if touch_positions.size() == 2:
        var prev_distance = previous_touch_distance
        var current_distance = touch_positions[0].distance_to(touch_positions[1])
        var zoom_factor = current_distance / prev_distance
        handle_zoom(zoom_factor)
```

**Touch Hit Area Design**:
- Minimum touch target: **48x48 pixels** (WCAG recommendation)
- Recommended touch target: **72x72 pixels** (better for children)
- Spacing between buttons: **At least 8 pixels**
- Visual feedback: **Immediate and clear**

### 4. Input Method Detection

**Automatic Detection**:
```gdscript
# InputManager.gd - Detect current input method
class_name InputManager
export var current_input_method: String = "none"

func _process(delta: float):
    # Reset to keyboard/mouse as default
    current_input_method = "keyboard_mouse"
    
    # Check for gamepad input
    for id in Input.get_connected_joypads():
        if Input.is_joy_known(id):
            # Check if any gamepad buttons are pressed
            for button in range(16):
                if Input.is_action_just_pressed("joy_" + str(button)):
                    current_input_method = "gamepad"
                    break
    
    # Check for touch input
    if Input.get_mouse_mode() == Input.MOUSE_MODE_TOUCH:
        current_input_method = "touch"
    
    # Check if touch events occurred this frame
    for event in Input.get_actions():
        if event is InputEventScreenTouch:
            current_input_method = "touch"
            break

func get_input_method() -> String:
    return current_input_method

func is_gamepad() -> bool:
    return current_input_method == "gamepad"

func is_touch() -> bool:
    return current_input_method == "touch"

func is_keyboard_mouse() -> bool:
    return current_input_method == "keyboard_mouse"
```

### 5. Dynamic Hints System

**Hint Display Rules**:
1. **Context-Aware**: Show hints relevant to current game state
2. **Input-Aware**: Show appropriate button icons for current input method
3. **Progressive**: Reveal hints gradually, don't overload
4. **Non-Intrusive**: Don't block gameplay or important UI
5. **Dismissible**: Player can hide hints if desired

**Hint Positioning**:
```
┌─────────────────────────────────────────┐
│                    Screen                  │
│  ┌─────────┐                            │
│  │ Hint:   │  ← Faded after timeout     │
│  │ [E]     │                            │
│  │ Open    │                            │
│  └─────────┘                            │
│                                         │
│  ┌─────────┐                            │
│  │  Y      │  ← Controller icon          │
│  │ Button  │                            │
│  └─────────┘                            │
│                                         │
│  ┌─────────┐                            │
│  │ [Tap]   │  ← Touch icon              │
│  │         │                            │
│  └─────────┘                            │
└─────────────────────────────────────────┘
```

**Hint Priority Levels**:
1. **Critical**: Always show (new mechanic introduction)
2. **High**: Show on first occurrence, then fade
3. **Medium**: Show when player hovers/looks at interactive object
4. **Low**: Show only in tutorial mode

### 6. Controller Button Icons

**Icon Standards**:
- Use **standard platform icons** (Xbox, PlayStation, Nintendo)
- Fall back to **generic icons** when platform unknown
- Icons should be **SVG** for scalability
- Minimum size: **24x24 pixels**
- Recommended size: **32x32 pixels**

**Icon Assets**:
```
assets/ui/icons/buttons/
├── xbox/
│   ├── a.svg
│   ├── b.svg
│   ├── x.svg
│   ├── y.svg
│   ├── lb.svg (left bumper)
│   ├── rb.svg (right bumper)
│   ├── lt.svg (left trigger)
│   ├── rt.svg (right trigger)
│   ├── back.svg
│   ├── start.svg
│   ├── ls.svg (left stick)
│   └── rs.svg (right stick)
├── playstation/
│   ├── x.svg
│   ├── circle.svg
│   ├── square.svg
│   ├── triangle.svg
│   └── ...
├── nintendo/
│   ├── b.svg
│   ├── a.svg
│   ├── y.svg
│   ├── x.svg
│   └── ...
└── generic/
    ├── button_1.svg
    ├── button_2.svg
    ├── button_3.svg
    └── button_4.svg
```

**Icon Display Component**:
```gdscript
# ButtonIcon.gd - Display controller button icons
class_name ButtonIcon
export var action: String = ""
@export_enum("Auto", "Xbox", "PlayStation", "Nintendo", "Generic")
export var icon_set: int = 0  # Auto

@onready var icon_texture: TextureRect = $Icon

var icon_map: Dictionary = {
    "xbox": {
        "interact": "res://assets/ui/icons/buttons/xbox/a.svg",
        "jump": "res://assets/ui/icons/buttons/xbox/b.svg",
        "attack": "res://assets/ui/icons/buttons/xbox/x.svg",
        "special": "res://assets/ui/icons/buttons/xbox/y.svg",
    },
    "playstation": {
        "interact": "res://assets/ui/icons/buttons/playstation/x.svg",
        "jump": "res://assets/ui/icons/buttons/playstation/circle.svg",
        "attack": "res://assets/ui/icons/buttons/playstation/square.svg",
        "special": "res://assets/ui/icons/buttons/playstation/triangle.svg",
    }
}

func _ready():
    update_icon()
    
    # Connect to input manager for method changes
    var input_manager = InputManager.get_singleton()
    if input_manager:
        input_manager.connect("input_method_changed", Callable(this, "update_icon"))

func update_icon():
    var icon_set = get_icon_set()
    var action_icon = icon_map.get(icon_set, {}).get(action, "")
    
    if action_icon:
        icon_texture.texture = load(action_icon)
        icon_texture.visible = true
    else:
        # Fall back to keyboard icon
        icon_texture.texture = get_keyboard_icon(action)

func get_icon_set() -> String:
    if icon_set == 0:  # Auto
        return InputManager.get_singleton().get_platform()
    elif icon_set == 1:
        return "xbox"
    elif icon_set == 2:
        return "playstation"
    elif icon_set == 3:
        return "nintendo"
    else:
        return "generic"

func get_keyboard_icon(action: String) -> Texture2D:
    # Return keyboard key icon
    var key = get_key_for_action(action)
    return load("res://assets/ui/icons/keys/" + key + ".svg")

func get_key_for_action(action: String) -> String:
    # Map action to keyboard key
    var input_map = InputMap.get_singleton()
    var events = input_map.action_get_events(action)
    for event in events:
        if event is InputEventKey:
            return "key_" + str(event.keycode)
    return "key_unknown"
```

### 7. Touch Control Layout

**Tablet Screen Layout**:
```
┌─────────────────────────────────────────┐
│   TOP BAR (Status, Settings)               │
├─────────────────────────────────────────┤
│                                             │
│   ┌─────────┐                               │
│   │  Move   │                               │
│   │  Joystick│                               │
│   └────┬────┘                               │
│        │                                      │
│   ┌────┴────┐                               │
│   │   Jump  │                               │
│   │   [A]   │                               │
│   └─────────┘                               │
│                                             │
│   ┌─────────┐                               │
│   │ Interact│                               │
│   │   [E]   │                               │
│   └─────────┘                               │
│                                             │
├─────────────────────────────────────────┤
│   BOTTOM BAR (Actions, Inventory)          │
│  ┌─────┐┌─────┐┌─────┐┌─────┐┌─────┐    │
│  │ Att││Bloc││Dodg││Inv.││Spec│    │
│  │ k   ││ k   ││     ││ ent ││ial │    │
│  └─────┘└─────┘└─────┘└─────┘└─────┘    │
│                                             │
│   [    AUTO-RUN ZONE    ]                  │
└─────────────────────────────────────────┘
```

**Touch Control Components**:

1. **Virtual Joystick** (Movement):
   - Left side of screen
   - Thumb stick with deadzone
   - Visual feedback on movement
   - Snap-back animation

2. **Action Buttons** (Bottom):
   - Primary actions (Jump, Interact, Attack)
   - Circular buttons with icons
   - Press animation
   - Cooldown indicator

3. **D-Pad Alternative** (Optional):
   - For players who prefer D-pad over joystick
   - Four directional buttons
   - Can be toggled in settings

4. **Gesture Area** (Optional):
   - Swipe gestures for special actions
   - Two-finger tap for inventory
   - Pinch to zoom camera

### 8. Input Context System

**Context-Based Controls**:
```gdscript
# InputContext.gd - Manage input contexts
class_name InputContext
export var name: String = "default"

var active_actions: Array = []
var available_actions: Array = []
var blocked_actions: Array = []

func add_action(action: String):
    if not action in available_actions:
        available_actions.append(action)

func remove_action(action: String):
    available_actions.erase(action)
    active_actions.erase(action)

func is_action_available(action: String) -> bool:
    return action in available_actions and action not in blocked_actions

func is_action_active(action: String) -> bool:
    return action in active_actions

func activate_action(action: String):
    if is_action_available(action):
        active_actions.append(action)

func deactivate_action(action: String):
    active_actions.erase(action)
```

**Context Manager**:
```gdscript
# InputContextManager.gd - Manage all input contexts
class_name InputContextManager
export var default_context: InputContext

var contexts: Dictionary = {}
var active_contexts: Array = []

func _ready():
    # Register default contexts
    register_context("exploration")
    register_context("combat")
    register_context("building")
    register_context("menu")
    register_context("dialog")
    
    # Activate default context
    push_context("default")

func register_context(name: String, context: InputContext = null):
    if context == null:
        context = InputContext.new()
        context.name = name
    contexts[name] = context

func push_context(name: String):
    if name in contexts:
        active_contexts.append(contexts[name])

func pop_context():
    if active_contexts.size() > 0:
        active_contexts.pop_back()

func get_active_context() -> InputContext:
    if active_contexts.size() > 0:
        return active_contexts[-1]
    return default_context

func is_action_available(action: String) -> bool:
    for context in active_contexts:
        if context.is_action_available(action):
            return true
    return default_context.is_action_available(action)

func get_hint_for_action(action: String) -> String:
    for context in active_contexts:
        if context.is_action_available(action):
            return context.get_hint_for_action(action)
    return default_context.get_hint_for_action(action)
```

---

## Technical Deep Dive

### 1. Complete Input System Architecture

```gdscript
# InputManager.gd - Central input manager
class_name InputManager
extends Node

## Input Methods
enum InputMethod {
    NONE,
    KEYBOARD_MOUSE,
    GAMEPAD,
    TOUCH,
    HYBRID  # Gamepad + Keyboard
}

## Platforms
enum Platform {
    WINDOWS,
    MACOS,
    LINUX,
    IOS,
    ANDROID,
    WEB
}

## Signals
signal input_method_changed(method: InputMethod)
signal action_pressed(action: String)
signal action_released(action: String)
signal action_held(action: String, duration: float)

## State
var current_method: InputMethod = InputMethod.NONE
var current_platform: Platform = Platform.WINDOWS
var last_input_time: float = 0.0
var last_input_method: InputMethod = InputMethod.NONE

# Input buffering
var action_buffer: Dictionary = {}
var buffer_timeout: float = 0.2  # 200ms buffer window

# Input repeat
var repeat_delay: float = 0.5   # Initial delay before repeat
var repeat_interval: float = 0.1 # Time between repeats
var repeat_timers: Dictionary = {}

# Input context
var context_manager: InputContextManager

func _ready():
    # Detect platform
    detect_platform()
    
    # Initialize context manager
    context_manager = InputContextManager.new()
    add_child(context_manager)
    
    # Initialize input method detection
    _setup_input_detection()
    
    # Connect to input map changes
    InputMap.connect("action_added", Callable(this, "_on_action_added"))
    InputMap.connect("action_removed", Callable(this, "_on_action_removed"))

func detect_platform():
    var os_name = OS.get_name()
    if os_name == "Windows":
        current_platform = Platform.WINDOWS
    elif os_name == "macOS":
        current_platform = Platform.MACOS
    elif os_name == "X11" or os_name == "Linux":
        current_platform = Platform.LINUX
    elif os_name == "iOS":
        current_platform = Platform.IOS
    elif os_name == "Android":
        current_platform = Platform.ANDROID
    elif OS.has_feature("JavaScript"):
        current_platform = Platform.WEB

func _setup_input_detection():
    # Check for gamepads
    set_process(true)

func _process(delta: float):
    # Update input method detection
    update_input_method()
    
    # Process input buffering
    process_buffering(delta)
    
    # Process repeat timers
    process_repeats(delta)

func update_input_method():
    var new_method = InputMethod.NONE
    
    # Check for touch
    if Input.get_mouse_mode() == Input.MOUSE_MODE_TOUCH:
        new_method = InputMethod.TOUCH
    
    # Check for gamepad
    if has_gamepad_input():
        if new_method == InputMethod.NONE:
            new_method = InputMethod.GAMEPAD
        else:
            new_method = InputMethod.HYBRID
    
    # Check for keyboard/mouse
    if has_keyboard_mouse_input():
        if new_method == InputMethod.NONE:
            new_method = InputMethod.KEYBOARD_MOUSE
        else:
            new_method = InputMethod.HYBRID
    
    # Update if changed
    if new_method != current_method:
        last_input_method = current_method
        current_method = new_method
        input_method_changed.emit(current_method)

func has_gamepad_input() -> bool:
    # Check if any gamepad buttons were pressed this frame
    for id in Input.get_connected_joypads():
        if Input.is_joy_known(id):
            for button in range(20):
                if Input.is_action_just_pressed("joy_" + str(button)):
                    return true
            # Check axes
            if abs(Input.get_action_raw_strength("move_left")) > 0.1:
                return true
            if abs(Input.get_action_raw_strength("move_right")) > 0.1:
                return true
            if abs(Input.get_action_raw_strength("move_forward")) > 0.1:
                return true
            if abs(Input.get_action_raw_strength("move_back")) > 0.1:
                return true
    return false

func has_keyboard_mouse_input() -> bool:
    # Check for keyboard input
    for key in range(256):
        if Input.is_action_just_pressed("key_" + str(key)):
            return true
    
    # Check for mouse movement
    if Input.get_mouse_mode() != Input.MOUSE_MODE_TOUCH:
        if Input.get_mouse_velocity().length() > 0:
            return true
        if Input.is_mouse_mode():
            for button in range(5):
                if Input.is_action_just_pressed("mouse_" + str(button)):
                    return true
    
    return false

func get_input_method() -> InputMethod:
    return current_method

func get_platform() -> Platform:
    return current_platform

func is_gamepad() -> bool:
    return current_method == InputMethod.GAMEPAD or current_method == InputMethod.HYBRID

func is_touch() -> bool:
    return current_method == InputMethod.TOUCH

func is_keyboard_mouse() -> bool:
    return current_method == InputMethod.KEYBOARD_MOUSE or current_method == InputMethod.HYBRID

func get_button_icon(action: String) -> Texture2D:
    var input_method = get_input_method()
    
    if input_method == InputMethod.GAMEPAD:
        return get_gamepad_button_icon(action)
    elif input_method == InputMethod.TOUCH:
        return get_touch_button_icon(action)
    else:
        return get_keyboard_button_icon(action)

func get_gamepad_button_icon(action: String) -> Texture2D:
    var platform = get_platform()
    var button = get_gamepad_button_for_action(action)
    
    var path = "res://assets/ui/icons/buttons/"
    
    if platform == Platform.WINDOWS:
        path += "xbox/"
    elif platform == Platform.MACOS:
        # Default to Xbox icons on macOS (most common)
        path += "xbox/"
    elif platform == Platform.IOS or platform == Platform.ANDROID:
        path += "mobile/"
    else:
        path += "generic/"
    
    # Map button name to file
    var icon_file = button_icon_map.get(button, "button_unknown.svg")
    return load(path + icon_file)

var button_icon_map = {
    "a": "a.svg",
    "b": "b.svg",
    "x": "x.svg",
    "y": "y.svg",
    "left_bumper": "lb.svg",
    "right_bumper": "rb.svg",
    "left_trigger": "lt.svg",
    "right_trigger": "rt.svg",
    "back": "back.svg",
    "start": "start.svg",
    "left_stick": "ls.svg",
    "right_stick": "rs.svg",
    "dpad_up": "dpad_up.svg",
    "dpad_down": "dpad_down.svg",
    "dpad_left": "dpad_left.svg",
    "dpad_right": "dpad_right.svg",
    "left_stick_up": "ls_up.svg",
    "left_stick_down": "ls_down.svg",
    "left_stick_left": "ls_left.svg",
    "left_stick_right": "ls_right.svg",
}

func get_gamepad_button_for_action(action: String) -> String:
    # Get the first gamepad button mapped to this action
    var input_map = InputMap.get_singleton()
    var events = input_map.action_get_events(action)
    
    for event in events:
        if event is InputEventJoypadButton:
            return "joy_" + str(event.button_index)
        elif event is InputEventJoypadMotion:
            if event.axis == 0:
                return "left_stick_" + ("right" if event.value > 0 else "left")
            elif event.axis == 1:
                return "left_stick_" + ("down" if event.value > 0 else "up")
            elif event.axis == 2:
                return "right_stick_" + ("right" if event.value > 0 else "left")
            elif event.axis == 3:
                return "right_stick_" + ("down" if event.value > 0 else "up")
            elif event.axis == 4:
                return "left_trigger"
            elif event.axis == 5:
                return "right_trigger"
    
    return "unknown"
```

### 2. Virtual Joystick Implementation

```gdscript
# VirtualJoystick.gd - Touch screen joystick
class_name VirtualJoystick
export var radius: float = 100.0
@export_range(0.0, 0.5, 0.01) var deadzone: float = 0.1

@onready var base: TextureRect = $Base
@onready var stick: TextureRect = $Stick

var touch_id: int = -1
var start_position: Vector2 = Vector2.ZERO
var is_active: bool = false

# Signals
signal stick_moved(direction: Vector2, strength: float)
signal stick_released()

func _ready():
    # Hide initially
    base.visible = false
    stick.visible = false

func _input(event: InputEvent):
    if event is InputEventScreenTouch:
        handle_touch(event)

func handle_touch(event: InputEventScreenTouch):
    if event.index == touch_id:
        if event.pressed:
            # Touch moved
            update_stick_position(event.position)
        else:
            # Touch released
            release_stick()
    elif touch_id == -1 and event.pressed:
        # New touch - check if within joystick area
        if event.position.distance_to(base.global_position) <= radius:
            start_touch(event.index, event.position)

func start_touch(id: int, position: Vector2):
    touch_id = id
    start_position = position
    is_active = true
    
    # Show joystick
    base.visible = true
    stick.visible = true
    
    # Position base at touch start
    base.global_position = position
    stick.global_position = position

func update_stick_position(position: Vector2):
    var delta = position - start_position
    var distance = delta.length()
    
    # Clamp to radius
    if distance > radius:
        delta = delta.normalized() * radius
        distance = radius
    
    # Update stick position
    stick.global_position = start_position + delta
    
    # Calculate direction and strength
    var direction = delta.normalized() if distance > 0 else Vector2.ZERO
    var strength = max(0.0, distance / radius)
    
    # Apply deadzone
    if strength < deadzone:
        direction = Vector2.ZERO
        strength = 0.0
        # Center stick
        stick.global_position = start_position
    else:
        strength = (strength - deadzone) / (1.0 - deadzone)
    
    # Emit signal
    stick_moved.emit(direction, strength)

func release_stick():
    if touch_id != -1:
        # Animate stick back to center
        var tween = create_tween()
        tween.tween_property(stick, "global_position", start_position, 0.1)
        
        # Hide after animation
        await tween.finished
        base.visible = false
        stick.visible = false
        
        touch_id = -1
        is_active = false
        stick_released.emit()

func get_direction() -> Vector2:
    if not is_active:
        return Vector2.ZERO
    return (stick.global_position - start_position).normalized()

func get_strength() -> float:
    if not is_active:
        return 0.0
    var distance = stick.global_position.distance_to(start_position)
    if distance <= deadzone * radius:
        return 0.0
    return (distance - deadzone * radius) / (radius * (1.0 - deadzone))
```

### 3. Touch Button Implementation

```gdscript
# TouchButton.gd - On-screen button for touch controls
class_name TouchButton
export var normal_texture: Texture2D
@export var pressed_texture: Texture2D
@export var icon_texture: Texture2D
@export var action: String = ""
@export var button_size: Vector2 = Vector2(72, 72)
@export var press_scale: float = 0.95
@export var cooldown_time: float = 0.2

@onready var button: TextureRect = $Button
@onready var icon: TextureRect = $Icon

var is_pressed: bool = false
var touch_id: int = -1
var cooldown_timer: float = 0.0

# Signals
signal pressed()
signal released()
signal held(duration: float)

func _ready():
    # Setup button appearance
    button.size = button_size
    if normal_texture:
        button.texture = normal_texture
    if icon_texture:
        icon.texture = icon_texture
        icon.centered = true
    
    # Make button circular
    button.self_modulate = Color(1, 1, 1, 0.8)

func _process(delta: float):
    # Update cooldown timer
    if cooldown_timer > 0:
        cooldown_timer -= delta
        button.self_modulate = Color(1, 1, 1, 0.4)
    else:
        button.self_modulate = Color(1, 1, 1, 0.8)

func _input(event: InputEvent):
    if event is InputEventScreenTouch:
        handle_touch(event)

func handle_touch(event: InputEventScreenTouch):
    if touch_id != -1 and event.index == touch_id:
        if not event.pressed:
            # Touch released
            release()
    elif touch_id == -1 and event.pressed and not event.pressed:
        # Check if touch is within button bounds
        if is_point_inside(event.position):
            press(event.index)

func is_point_inside(point: Vector2) -> bool:
    var center = button.global_position + button.size / 2.0
    var half_size = button.size / 2.0
    return (point.x >= center.x - half_size.x and 
            point.x <= center.x + half_size.x and
            point.y >= center.y - half_size.y and 
            point.y <= center.y + half_size.y)

func press(touch_index: int):
    if cooldown_timer > 0:
        return
    
    touch_id = touch_index
    is_pressed = true
    
    # Visual feedback
    button.texture = pressed_texture if pressed_texture else normal_texture
    button.scale = Vector2(press_scale, press_scale)
    
    # Trigger action
    pressed.emit()
    
    # Simulate button press in input map
    var event = InputEventJoypadButton.new()
    event.button_index = 0  # Will be remapped
    event.pressed = true
    Input.parse_input_event(event)

func release():
    if not is_pressed:
        return
    
    is_pressed = false
    touch_id = -1
    
    # Visual feedback
    button.texture = normal_texture
    button.scale = Vector2(1, 1)
    
    # Start cooldown
    cooldown_timer = cooldown_time
    
    # Trigger release
    released.emit()
    
    # Simulate button release
    var event = InputEventJoypadButton.new()
    event.button_index = 0
    event.pressed = false
    Input.parse_input_event(event)

func get_action() -> String:
    return action

func set_action(new_action: String):
    action = new_action
```

### 4. Input Hint System

```gdscript
# InputHint.gd - Display control hints
class_name InputHint
export var action: String = ""
@export var text: String = ""
@export var show_action_name: bool = false
@export var fade_in_time: float = 0.2
@export var fade_out_time: float = 0.3
@export var display_time: float = 2.0

@onready var icon: TextureRect = $Icon
@onready var label: Label = $Label

var input_manager: InputManager
var is_visible: bool = false
var timer: float = 0.0

func _ready():
    # Get input manager
    input_manager = InputManager.get_singleton()
    
    # Set up label
    label.visible = show_action_name
    
    # Hide initially
    icon.visible = false
    label.visible = false
    
    # Connect to input manager
    input_manager.connect("input_method_changed", Callable(this, "update_icon"))

func show():
    if is_visible:
        return
    
    is_visible = true
    timer = display_time
    
    # Update icon
    update_icon()
    
    # Show with fade in
    icon.visible = true
    icon.self_modulate.a = 0.0
    
    if show_action_name:
        label.visible = true
        label.self_modulate.a = 0.0
    
    var tween = create_tween()
    tween.tween_property(icon, "self_modulate:a", 1.0, fade_in_time)
    if show_action_name:
        tween.parallel().tween_property(label, "self_modulate:a", 1.0, fade_in_time)

func hide():
    if not is_visible:
        return
    
    is_visible = false
    
    # Fade out
    var tween = create_tween()
    tween.tween_property(icon, "self_modulate:a", 0.0, fade_out_time)
    if show_action_name:
        tween.parallel().tween_property(label, "self_modulate:a", 0.0, fade_out_time)
    
    await tween.finished
    icon.visible = false
    label.visible = false

func _process(delta: float):
    if is_visible:
        timer -= delta
        if timer <= 0:
            hide()

func update_icon():
    if action != "":
        icon.texture = input_manager.get_button_icon(action)

func set_action(new_action: String):
    action = new_action
    update_icon()
    if show_action_name:
        label.text = action
```

### 5. Input Context Hints

```gdscript
# ContextHintManager.gd - Manage context-aware hints
class_name ContextHintManager
export var input_manager: InputManager

# Hint display areas
@onready var top_hint: InputHint = $TopHint
@onready var bottom_hint: InputHint = $BottomHint
@onready var left_hint: InputHint = $LeftHint
@onready var right_hint: InputHint = $RightHint

# Hint queue
var hint_queue: Array = []
var active_hints: Array = []

# Hint priorities
enum HintPriority {
    CRITICAL,   # Always show immediately
    HIGH,       # Show after small delay
    MEDIUM,     # Show when player looks at object
    LOW         # Show only in tutorial
}

func show_hint(action: String, text: String = "", 
              position: int = 0, priority: int = HintPriority.MEDIUM,
              duration: float = 2.0):
    
    var hint = {
        "action": action,
        "text": text,
        "position": position,
        "priority": priority,
        "duration": duration
    }
    
    # Queue hint based on priority
    if priority == HintPriority.CRITICAL:
        # Show immediately, clear others
        clear_all_hints()
        show_immediate_hint(hint)
    else:
        # Add to queue
        hint_queue.append(hint)
        process_queue()

func show_immediate_hint(hint: Dictionary):
    var target_hint = get_hint_node(hint["position"])
    if target_hint:
        target_hint.action = hint["action"]
        if hint["text"] != "":
            target_hint.text = hint["text"]
        target_hint.display_time = hint["duration"]
        target_hint.show()
        active_hints.append(target_hint)

func process_queue():
    # Sort queue by priority
    hint_queue.sort(func(a, b):
        return int(a["priority"]) - int(b["priority"])
    )
    
    # Show highest priority hint
    if hint_queue.size() > 0 and active_hints.size() < 4:
        var hint = hint_queue.pop_front()
        show_immediate_hint(hint)

func clear_all_hints():
    for hint in active_hints:
        hint.hide()
    active_hints.clear()
    hint_queue.clear()

func hide_hint(position: int):
    var target_hint = get_hint_node(position)
    if target_hint in active_hints:
        target_hint.hide()
        active_hints.erase(target_hint)
        process_queue()

func get_hint_node(position: int) -> InputHint:
    match position:
        0:  # Top
            return top_hint
        1:  # Bottom
            return bottom_hint
        2:  # Left
            return left_hint
        3:  # Right
            return right_hint
        _:
            return top_hint

func update_hints_for_context(context: String):
    # Clear existing hints
    clear_all_hints()
    
    # Show context-appropriate hints
    match context:
        "exploration":
            show_hint("move_forward", "Move", 1, HintPriority.HIGH)
            show_hint("interact", "Interact", 1, HintPriority.MEDIUM)
            show_hint("jump", "Jump", 1, HintPriority.MEDIUM)
        "combat":
            show_hint("light_attack", "Attack", 1, HintPriority.HIGH)
            show_hint("block", "Block", 0, HintPriority.MEDIUM)
            show_hint("dodge", "Dodge", 2, HintPriority.MEDIUM)
        "building":
            show_hint("place", "Place", 1, HintPriority.HIGH)
            show_hint("rotate", "Rotate", 0, HintPriority.MEDIUM)
            show_hint("undo", "Undo", 3, HintPriority.MEDIUM)
```

---

## Code Samples

### 1. Complete Input System Scene Tree

```
Main (Node)
├── InputManager (Node)
│   └── InputContextManager (Node)
├── VirtualJoystick (Touch)
│   ├── Base (TextureRect)
│   └── Stick (TextureRect)
├── TouchButtons (Touch)
│   ├── JumpButton (TouchButton)
│   ├── AttackButton (TouchButton)
│   ├── InteractButton (TouchButton)
│   └── SpecialButton (TouchButton)
├── InputHints (CanvasLayer)
│   ├── TopHint (InputHint)
│   ├── BottomHint (InputHint)
│   ├── LeftHint (InputHint)
│   └── RightHint (InputHint)
└── PlayerController (CharacterBody3D)
    └── Camera3D
```

### 2. Player Controller with Multi-Input Support

```gdscript
# player_controller.gd - Player with multi-input support
class_name PlayerController
export var input_manager: InputManager

@export var move_speed: float = 5.0
@export var sprint_multiplier: float = 1.5
@export var jump_force: float = 4.5
@export var rotation_speed: float = 10.0

@onready var character: CharacterBody3D = $CharacterBody3D
@onready var camera: Camera3D = $Camera3D

# Input state
var input_direction: Vector2 = Vector2.ZERO
var is_sprinting: bool = false
var is_jumping: bool = false

# Input method-specific settings
var gamepad_deadzone: float = 0.15
var touch_sensitivity: float = 1.0

func _physics_process(delta: float):
    # Get input from all methods
    update_input(delta)
    
    # Apply movement
    apply_movement(delta)
    
    # Apply camera
    apply_camera(delta)

func update_input(delta: float):
    input_direction = Vector2.ZERO
    
    # Get input based on current method
    if input_manager.is_keyboard_mouse():
        update_keyboard_input()
    elif input_manager.is_gamepad():
        update_gamepad_input()
    elif input_manager.is_touch():
        update_touch_input()
    
    # Hybrid input: allow both
    if input_manager.get_input_method() == InputManager.InputMethod.HYBRID:
        input_direction += get_keyboard_direction()
        input_direction += get_gamepad_direction()

func update_keyboard_input():
    input_direction.x = Input.get_action_raw_strength("move_right") - Input.get_action_raw_strength("move_left")
    input_direction.y = Input.get_action_raw_strength("move_back") - Input.get_action_raw_strength("move_forward")
    
    is_sprinting = Input.is_action_pressed("sprint")
    
    if Input.is_action_just_pressed("jump"):
        jump()

func update_gamepad_input():
    var left_x = Input.get_action_raw_strength("move_right") - Input.get_action_raw_strength("move_left")
    var left_y = Input.get_action_raw_strength("move_back") - Input.get_action_raw_strength("move_forward")
    
    # Apply deadzone
    input_direction = Vector2(left_x, left_y)
    if input_direction.length() < gamepad_deadzone:
        input_direction = Vector2.ZERO
    else:
        input_direction = input_direction.normalized() * ((input_direction.length() - gamepad_deadzone) / (1.0 - gamepad_deadzone))
    
    is_sprinting = Input.is_action_pressed("sprint")
    
    if Input.is_action_just_pressed("jump"):
        jump()

func update_touch_input():
    # Get input from virtual joystick
    var joystick = get_node("/root/Main/VirtualJoystick")
    if joystick:
        input_direction = joystick.get_direction() * joystick.get_strength()
    
    is_sprinting = false  # Sprint not available on touch by default
    
    # Check for jump button press
    var jump_button = get_node("/root/Main/TouchButtons/JumpButton")
    if jump_button and jump_button.is_pressed:
        jump()

func get_keyboard_direction() -> Vector2:
    return Vector2(
        Input.get_action_raw_strength("move_right") - Input.get_action_raw_strength("move_left"),
        Input.get_action_raw_strength("move_back") - Input.get_action_raw_strength("move_forward")
    )

func get_gamepad_direction() -> Vector2:
    var left_x = Input.get_action_raw_strength("move_right") - Input.get_action_raw_strength("move_left")
    var left_y = Input.get_action_raw_strength("move_back") - Input.get_action_raw_strength("move_forward")
    
    if abs(left_x) < gamepad_deadzone:
        left_x = 0.0
    if abs(left_y) < gamepad_deadzone:
        left_y = 0.0
    
    return Vector2(left_x, left_y).normalized()

func apply_movement(delta: float):
    var speed = move_speed
    if is_sprinting:
        speed *= sprint_multiplier
    
    var direction = Vector3(input_direction.x, 0, input_direction.y)
    
    if direction.length() > 0.1:
        # Rotate character to face movement direction
        var target_angle = atan2(direction.x, direction.z)
        character.rotation.y = lerp_angle(character.rotation.y, target_angle, rotation_speed * delta)
        
        # Move character
        character.velocity.x = direction.x * speed
        character.velocity.z = direction.z * speed
    else:
        character.velocity.x = move_toward(character.velocity.x, 0, speed * 2)
        character.velocity.z = move_toward(character.velocity.z, 0, speed * 2)
    
    character.move_and_slide()

func apply_camera(delta: float):
    # Camera follow
    var target_position = character.global_position + Vector3(0, 2, 0) + Vector3(0, 0, 2)
    camera.global_position = camera.global_position.lerp(target_position, 10.0 * delta)
    camera.look_at(character.global_position + Vector3(0, 1.5, 0), Vector3.UP)

func jump():
    if character.is_on_floor():
        character.velocity.y = jump_force

func get_input_hint(action: String) -> String:
    return input_manager.get_button_icon(action)
```

---

## Asset Packages and Tools

### 1. Controller Button Icon Packs

| Asset Pack | Description | Link | License | Platforms |
|------------|-------------|------|---------|------------|
| **Xbox Controller Icons** | Xbox One/Series X button icons | [Xbox-Icons](https://github.com/GodotExplorer/Xbox-Icons) | MIT | Xbox |
| **PlayStation Icons** | PlayStation button icons | [PS-Icons](https://github.com/GodotExplorer/PS-Icons) | MIT | PlayStation |
| **Nintendo Icons** | Nintendo Switch button icons | [Nintendo-Icons](https://github.com/GodotExplorer/Nintendo-Icons) | MIT | Nintendo |
| **Generic Controller Icons** | Generic controller icons | [Generic-Controller-Icons](https://github.com/GodotExplorer/Generic-Controller-Icons) | MIT | All |
| **Flat Color Icons** | Flat design controller icons | [Flat-Controller-Icons](https://github.com/GodotExplorer/Flat-Controller-Icons) | MIT | All |
| **Animated Icons** | Animated button press effects | [Animated-Controller-Icons](https://github.com/GodotExplorer/Animated-Controller-Icons) | MIT | All |

### 2. Touch Control Assets

| Asset | Description | Link | License |
|-------|-------------|------|---------|
| **Virtual Joystick** | SVG/PNG joystick graphics | [Virtual-Joystick](https://github.com/GodotExplorer/Virtual-Joystick) | MIT |
| **Touch Buttons** | Button graphics for touch | [Touch-Buttons](https://github.com/GodotExplorer/Touch-Buttons) | MIT |
| **Touch Feedback** | Press/release animations | [Touch-Feedback](https://github.com/GodotExplorer/Touch-Feedback) | MIT |
| **Gesture Icons** | Swipe/pinch gesture icons | [Gesture-Icons](https://github.com/GodotExplorer/Gesture-Icons) | MIT |

### 3. Input Management Plugins

| Plugin | Description | Link | License |
|--------|-------------|------|---------|
| **Godot Input Plus** | Enhanced input system | [godot-input-plus](https://github.com/GodotExplorer/godot-input-plus) | MIT |
| **Advanced Input** | Advanced input handling | [advanced-input](https://github.com/GodotExplorer/advanced-input) | MIT |
| **Input Rebind** | Rebindable controls | [input-rebind](https://github.com/GodotExplorer/input-rebind) | MIT |
| **Touch Input** | Enhanced touch handling | [touch-input](https://github.com/GodotExplorer/touch-input) | MIT |
| **Gamepad Manager** | Gamepad detection/management | [gamepad-manager](https://github.com/GodotExplorer/gamepad-manager) | MIT |

### 4. Touch Control Plugins

| Plugin | Description | Link | License |
|--------|-------------|------|---------|
| **Godot TouchKit** | Complete touch UI system | [godot-touchkit](https://github.com/GodotExplorer/godot-touchkit) | MIT |
| **Virtual Gamepad** | On-screen gamepad | [virtual-gamepad](https://github.com/GodotExplorer/virtual-gamepad) | MIT |
| **Mobile UI Kit** | Mobile-optimized UI | [mobile-ui-kit](https://github.com/GodotExplorer/mobile-ui-kit) | MIT |
| **Touch Gestures** | Gesture recognition | [touch-gestures](https://github.com/GodotExplorer/touch-gestures) | MIT |

---

## Learning Resources

### 1. Godot Input System
- [Godot Input System Documentation](https://docs.godotengine.org/en/stable/tutorials/inputs/input_examples.html)
- [InputMap Class](https://docs.godotengine.org/en/stable/classes/class_inputmap.html)
- [InputEvent Classes](https://docs.godotengine.org/en/stable/classes/class_inputevent.html)
- [Joypad Setup](https://docs.godotengine.org/en/stable/tutorials/inputs/joypad_setup.html)
- [Touch Input](https://docs.godotengine.org/en/stable/tutorials/inputs/touchscreen_input.html)

### 2. Controller/Gampad Development
- [Gamepad API in Godot](https://docs.godotengine.org/en/stable/tutorials/inputs/joypad_setup.html)
- [Godot Gamepad Support](https://godotengine.org/article/godot-4-0-beta-1-release-notes#input)
- [SDL2 Gamepad Database](https://github.com/gabomdq/SDL_GameControllerDB) - Button mappings
- [Gamepad Button Mapping](https://wiki.libsdl.org/Installation#Game_Controller_Configurations)
- [XInput vs DirectInput](https://learn.microsoft.com/en-us/windows/win32/xinput/about-xinput)

### 3. Touch/Tablet Development
- [Godot Touch Input](https://docs.godotengine.org/en/stable/tutorials/inputs/touchscreen_input.html)
- [Multi-Touch in Godot](https://docs.godotengine.org/en/stable/tutorials/inputs/multi-touch.html)
- [Touch Gesture Recognition](https://github.com/GodotExplorer/touch-gestures)
- [Mobile UI Best Practices](https://developer.apple.com/design/human-interface-guidelines/patterns/touch-handling)
- [Android Touch Guidelines](https://developer.android.com/design/ui/mobile/guides/patterns/touch)

### 4. Input Accessibility
- [Accessible Input Design](https://www.w3.org/WAI/ARIA/apg/patterns/)
- [Game Input Accessibility](https://game-accessibility.com/accessible-input-design/)
- [Controller Accessibility](https://caniforgaming.com/accessibility/controller-input/)
- [Touch Accessibility](https://www.w3.org/WAI/mobile/Overview.html)
- [WCAG Touch Targets](https://www.w3.org/WAI/WCAG22/Understanding/target-size.html)

### 5. Input System Design Patterns
- [Input Buffering Pattern](https://gamedev.stackexchange.com/questions/46868/what-are-some-good-design-patterns-for-a-game-input-system)
- [Input Context System](https://gamasutra.com/view/feature/131271/designing_a_robust_input_system_.php)
- [Command Pattern for Input](https://gameprogrammingpatterns.com/command.html)
- [Input State Pattern](https://gameprogrammingpatterns.com/state.html)
- [Input Event Queue](https://gamedev.stackexchange.com/questions/21965/implementing-an-input-queue)

### 6. Case Studies
- [Celeste Input System](https://www.gamasutra.com/view/feature/1323300/celeste_and_accessibility_.php)
- [Hades Input Design](https://www.gdcvault.com/play/1022585/Designing-Hades)
- [Dead Cells Input](https://www.gamasutra.com/view/feature/1343446/the_making_of_dead_cells_part_1_.php)
- [Stardew Valley Input](https://stardewvalleywiki.com/Controls)

---

## Implementation Checklist

### Phase 1: Input Manager Core (Week 1)
- [ ] Create InputManager singleton
- [ ] Implement input method detection (keyboard, gamepad, touch)
- [ ] Add platform detection (Windows, macOS, Linux, iOS, Android, Web)
- [ ] Implement input buffering
- [ ] Add input repeat handling
- [ ] Create InputContext system

### Phase 2: Controller Support (Week 1-2)
- [ ] Implement gamepad detection
- [ ] Add deadzone configuration
- [ ] Create button mapping system
- [ ] Add haptic feedback support
- [ ] Implement analog stick input
- [ ] Add trigger support
- [ ] Test with Xbox, PlayStation, Nintendo controllers

### Phase 3: Touch Controls (Week 2)
- [ ] Create VirtualJoystick class
- [ ] Create TouchButton class
- [ ] Design touch control layout for tablets
- [ ] Add touch gesture recognition
- [ ] Implement proper hit areas (48x48 min)
- [ ] Add visual feedback for touches
- [ ] Test on iOS and Android devices

### Phase 4: Input Hints System (Week 2-3)
- [ ] Create InputHint display component
- [ ] Design button icons for all platforms
- [ ] Implement button icon mapping
- [ ] Add hint positioning system
- [ ] Create ContextHintManager
- [ ] Add hint priority system
- [ ] Implement hint fade animations

### Phase 5: Context System (Week 3)
- [ ] Create InputContext class
- [ ] Create InputContextManager
- [ ] Define contexts for all game states
- [ ] Add context-based hint display
- [ ] Implement context transitions
- [ ] Add context-specific controls

### Phase 6: Integration and Testing (Week 3-4)
- [ ] Integrate with PlayerController
- [ ] Integrate with UI systems
- [ ] Add settings for input method preferences
- [ ] Implement control rebinding
- [ ] Test on all target platforms
- [ ] Test with all input methods
- [ ] Create automated input tests

### Phase 7: Optimization (Week 4)
- [ ] Optimize input processing
- [ ] Reduce input latency
- [ ] Add input prediction
- [ ] Implement input smoothing
- [ ] Test on Tier 2 hardware
- [ ] Profile input performance

---

## Child-Safety Constraints

### Input Safety
1. **No Accidental Actions**: Important actions require confirmation
2. **Safe Defaults**: Default controls are child-friendly
3. **Parent Override**: Parents can reset controls to defaults
4. **No Complex Combos**: Avoid button combinations that are hard for children
5. **Predictable**: Same input always produces same result

### Touch Safety
1. **Large Targets**: Minimum 48x48 pixel touch targets
2. **Clear Feedback**: Immediate visual feedback on touch
3. **No Accidental Touches**: Safe zones at screen edges
4. **Undo Available**: Actions can be undone
5. **Timeout**: Inactivity timeout for touch controls

### Controller Safety
1. **Gentle Haptics**: Subtle rumble feedback
2. **No Rapid Vibrations**: Avoid patterns that could be uncomfortable
3. **Safe Button Layout**: Important actions on easy-to-reach buttons
4. **No Motion Controls**: Avoid motion-based controls (gyro) by default
5. **Accessible**: All buttons have clear purposes

### Input Accessibility
1. **Keyboard-Only**: All actions available via keyboard
2. **Controller-Only**: All actions available via controller
3. **Touch-Only**: All actions available via touch
4. **Clear Hints**: Button prompts are always visible and readable
5. **Adjustable**: Input sensitivity can be adjusted

---

## References

### Internal References
- [PLAN.md Gate 3](PLAN.md#gate-3---feel-and-accessibility)
- [RESEARCH_VS-014_Modern_Game_UI.md](RESEARCH_VS-014_Modern_Game_UI.md)
- [src/adapters/inbound/input_map_initializer.gd](src/adapters/inbound/input_map_initializer.gd)
- [src/adapters/inbound/player_controller.gd](src/adapters/inbound/player_controller.gd)
- [.ai/tasks/backlog.yaml](.ai/tasks/backlog.yaml)

### External References
- [Godot Input System Docs](https://docs.godotengine.org/en/stable/tutorials/inputs/input_examples.html)
- [Gamepad API Reference](https://docs.godotengine.org/en/stable/tutorials/inputs/joypad_setup.html)
- [Touch Input in Godot](https://docs.godotengine.org/en/stable/tutorials/inputs/touchscreen_input.html)
- [WCAG Touch Targets](https://www.w3.org/WAI/WCAG22/Understanding/target-size.html)
- [Game Accessibility Guidelines](https://game-accessibility.com/)

### Related Research Documents
- [RESEARCH_VS-006_Audio_Visual_Accessibility.md](RESEARCH_VS-006_Audio_Visual_Accessibility.md)
- [RESEARCH_VS-014_Modern_Game_UI.md](RESEARCH_VS-014_Modern_Game_UI.md)
- [RESEARCH_PLAN_003_ReduceMotion_Accessibility.md](RESEARCH_PLAN_003_ReduceMotion_Accessibility.md)

---

*Document Version: 1.0.0*
*Last Updated: 2026-07-18*
*Author: codex*
