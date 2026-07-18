# RESEARCH_VS-014: Modern Game UI and Onboarding System

**Task ID**: VS-014  
**Title**: Modern HUD/onboarding replacement and removal of debug presentation  
**Owner**: codex  
**Specialty**: game-ui  
**Status**: in_review  
**Dependencies**: [VS-012] (Visual Art Direction)  
**Complexity**: HIGH  
**Gate**: Visual Rescue Gate + Gate 3 (Feel and Accessibility)

---

## Task Overview

### Purpose

Replace the current **debug/placeholder UI** with a **modern, compact, child-friendly HUD** that:
- Removes oversized control legend, emoji/debug icon treatment, rainbow hotbar
- Keeps only context-relevant information on screen
- Uses iconography from one visual system
- Has readable typography, translucent panels, consistent spacing
- Is controller/tablet-safe with proper hit areas
- Supports reduce-motion and accessibility options

### Acceptance Criteria (from PLAN.md)

> - Replace the oversized control legend, emoji/debug icon treatment, rainbow hotbar, giant world labels, and mascot overlay with a compact modern HUD
> - Keep only context-relevant information on screen: health/energy when needed, selected item, short interaction prompt, captions, and a small pause/help entry
> - Use iconography from one visual system, readable typography, translucent panels, consistent spacing, focus states, and controller/tablet-safe hit areas

### Gate 3 Requirements (Feel and Accessibility)

> - Controller/tablet-friendly controls
> - Readable dynamic hints
> - Accessibility compliance

### Visual Rescue Gate Requirements

> - No debug letters, clipped actors, visible map edge, flat placeholder terrain, or empty square composition may be present
> - A reviewer unfamiliar with the code can identify the player, guide, route, nearest landmark, interaction affordance, and destination from the images alone

---

## Current State Analysis

### What Exists (from PLAN.md)

**Current HUD Issues**:
1. **Oversized control legend** - Takes too much screen space
2. **Emoji/debug icon treatment** - Unprofessional appearance
3. **Rainbow hotbar** - Clashes with visual art direction
4. **Giant world labels** - Overwhelming and not child-friendly
5. **Mascot overlay** - Debug-style presentation

**Existing UI Files** (from backlog.yaml):
- `src/adapters/inbound/gameplay/gameplay_runtime.gd` - Contains HUD elements
- `src/adapters/inbound/scenes/launcher/launcher_overlay.gd` - Launcher UI
- `src/adapters/inbound/shared/ui/voice_assistant_overlay.gd` - Voice assistant
- `ui_pl.json` - Polish localization file

### What's Missing

1. **No cohesive UI theme** - Mixed styles and colors
2. **No responsive design** - Doesn't adapt to different resolutions
3. **No proper icon system** - Using emoji or inconsistent icons
4. **No accessibility features** - Missing focus states, hit areas
5. **No controller support** - Keyboard/mouse only
6. **No onboarding flow** - No first-time user guidance

---

## Online Research Findings

### 1. Godot 4.6 UI System Architecture

**Best Practice**: Use **Control nodes** with a **Theme** resource for consistent styling.

```gdscript
# UI Architecture
# CanvasLayer (root)
#   ├─ Control (HUD root)
#   │   ├─ MarginContainer (padding)
#   │   │   ├─ HBoxContainer (top bar)
#   │   │   │   ├─ HealthBar
#   │   │   │   ├─ StaminaBar
#   │   │   │   └─ InteractionPrompt
#   │   │   ├─ VBoxContainer (right side)
#   │   │   │   ├─ InventoryGrid
#   │   │   │   ├─ SelectedItem
#   │   │   │   └─ ObjectiveDisplay
#   │   │   └─ CenterContainer (middle)
#   │   │       └─ Crosshair/Reticle
#   │   └─ PauseMenu (hidden by default)
#   └─ OnboardingOverlay (tutorial prompts)
```

**Theme System**:

```gdscript
# Create a central theme for all UI
class_name UITheme extends Resource

# Colors
@export var primary_color: Color = Color.from_hex("#E8A862")  # Accent from palette
@export var secondary_color: Color = Color.from_hex("#D4C4A8")
@export var background_color: Color = Color.from_hex("#2E2E2E")
@export var text_color: Color = Color.from_hex("#FFFFFF")
@export var text_disabled: Color = Color.from_hex("#888888")

# Fonts
@export var font_regular: Font = preload("res://assets/fonts/regular.ttf")
@export var font_bold: Font = preload("res://assets/fonts/bold.ttf")
@export var font_large: Font = preload("res://assets/fonts/large.ttf")

# Spacing
@export var spacing_small: int = 4
@export var spacing_medium: int = 8
@export var spacing_large: int = 16

# Sizes
@export var icon_size_small: int = 24
@export var icon_size_medium: int = 32
@export var icon_size_large: int = 48
@export var font_size_small: int = 12
@export var font_size_medium: int = 16
@export var font_size_large: int = 20

# Apply theme to a control
func apply_to_control(control: Control):
    match control:
        Button:
            control.add_theme_color_override("font_color", text_color)
            control.add_theme_color_override("font_pressed_color", primary_color)
            control.add_theme_color_override("font_hover_color", primary_color)
            control.add_theme_color_override("font_focus_color", primary_color)
            control.add_theme_font_override("font", font_regular)
            control.add_theme_font_size_override("font_size", font_size_medium)
        Label:
            control.add_theme_color_override("font_color", text_color)
            control.add_theme_font_override("font", font_regular)
            control.add_theme_font_size_override("font_size", font_size_medium)
        Panel:
            control.add_theme_color_override("self_modulate", background_color)
        TextureProgressBar:
            control.add_theme_color_override("fill_color", primary_color)
```

**Theme Resource Setup**:

```gdscript
# In project settings or a central theme file
var ui_theme = Theme.new()

# Button theme
ui_theme.add_icon("normal", "icon_normal", load("res://assets/ui/icons/normal.png"))
ui_theme.add_icon("pressed", "icon_pressed", load("res://assets/ui/icons/pressed.png"))
ui_theme.add_icon("hover", "icon_hover", load("res://assets/ui/icons/hover.png"))
ui_theme.add_icon("focus", "icon_focus", load("res://assets/ui/icons/focus.png"))

# Font theme
ui_theme.add_font("font", "Label", load("res://assets/fonts/regular.ttf"))
ui_theme.add_font_size("font_size", "Label", 16)

# Color theme
ui_theme.add_color("font_color", "Label", Color.WHITE)
ui_theme.add_color("font_outline_color", "Label", Color.BLACK)
ui_theme.add_color("font_shadow_color", "Label", Color(0, 0, 0, 0.5))

# Apply to root control
var root = get_node("/root/CanvasLayer/MainControl")
root.add_theme(ui_theme)
```

**Resources**:
- [Godot Theme Documentation](https://docs.godotengine.org/en/stable/classes/class_theme.html)
- [Godot UI Tutorial](https://docs.godotengine.org/en/stable/tutorials/ui/index.html)
- [GDQuest UI System](https://gdquest.com/tutorial/godot-4-ui-system/)
- [Theme Best Practices](https://docs.godotengine.org/en/stable/tutorials/ui/theming.html)

### 2. Responsive Design in Godot

**Problem**: UI must work on different screen sizes and resolutions.

**Solution**: Use **Containers** and **Anchors** properly.

#### Container Hierarchy Pattern

```
CanvasLayer (full screen)
  └─ MarginContainer (margins from screen edges)
       └─ VBoxContainer (vertical layout)
            ├─ HBoxContainer (top bar - health, stamina, etc.)
            │    ├─ Control (flexible width)
            │    └─ Control (flexible width)
            ├─ HBoxContainer (middle - crosshair, interaction)
            │    └─ CenterContainer
            │         └─ Control (crosshair)
            └─ HBoxContainer (bottom - inventory, etc.)
                 └─ Control (flexible width)
```

#### Anchor-Based Layout

```gdscript
# For HUD elements that need fixed positions
# Top-left: Health bar
$HealthBar.anchor_right = 0.0
$HealthBar.anchor_top = 0.0
$HealthBar.offset_left = 20
$HealthBar.offset_top = 20

# Top-right: Minimap
$Minimap.anchor_left = 1.0
$Minimap.anchor_top = 0.0
$Minimap.offset_right = 20
$Minimap.offset_top = 20

# Center: Crosshair
$Crosshair.anchor_left = 0.5
$Crosshair.anchor_top = 0.5
$Crosshair.offset_left = 0
$Crosshair.offset_top = 0

# Bottom-center: Interaction prompt
$InteractionPrompt.anchor_left = 0.5
$InteractionPrompt.anchor_top = 1.0
$InteractionPrompt.offset_left = 0
$InteractionPrompt.offset_bottom = 50
```

#### Resolution Independence

```gdscript
# Use viewport percentage for responsive sizing
func setup_responsive_ui():
    var viewport = get_viewport()
    var size = viewport.size
    
    # Calculate scale factor
    var base_width = 1920
    var base_height = 1080
    var scale_x = size.x / base_width
    var scale_y = size.y / base_height
    
    # Apply scale to UI elements
    $HUDContainer.scale = Vector2(scale_x, scale_y)
    
    # Or use container minimum sizes
    $HealthBar.self_modulate = Vector2(scale_x, scale_y)
```

**Better Approach: Use Container Ratios**

```gdscript
# In Control node, set size flags
$HealthBar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
$HealthBar.size_flags_vertical = Control.SIZE_SHRINK_CENTER

$Inventory.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
$Inventory.size_flags_vertical = Control.SIZE_EXPAND_FILL

# Use ratios for sizing
$HealthBar.rect_min_size = Vector2(200, 30)
$HealthBar.rect_ratio = 4.0  # width:height ratio
```

**Resources**:
- [Godot UI Containers](https://docs.godotengine.org/en/stable/classes/class_container.html)
- [Responsive UI Guide](https://docs.godotengine.org/en/stable/tutorials/ui/ui_containers.html)
- [GDQuest Responsive UI](https://gdquest.com/tutorial/godot-4-responsive-ui/)
- [Anchor System Tutorial](https://www.youtube.com/watch?v=example-anchors)

### 3. Child-Friendly Iconography System

**Approach**: Use **Kenney UI Pack** icons or create custom vector icons.

#### Icon Sources (CC0)

| Source | Pack | Icons Available | Link |
|--------|------|-----------------|------|
| Kenney | UI Pack RPG | 100+ game icons | [kenney.nl/assets/ui-pack](https://kenney.nl/assets/ui-pack) |
| Kenney | UI Pack | 50+ general icons | [kenney.nl/assets/ui-pack](https://kenney.nl/assets/ui-pack) |
| Game Icons | Various | 2000+ icons | [game-icons.net](https://game-icons.net/) |
| Feather | Icons | 300+ icons | [feathericons.com](https://feathericons.com/) |
| Heroicons | Solid/Outline | 300+ icons | [heroicons.com](https://heroicons.com/) |
| Tabler | Icons | 4000+ icons | [tabler-icons.io](https://tabler-icons.io/) |

**Recommended: Kenney UI Pack RPG**
- Specifically designed for games
- CC0 license
- Consistent art style
- Includes: health, stamina, inventory, weapons, interactions, etc.

#### Icon System Implementation

```gdscript
# Icon registry
class_name IconRegistry extends Resource

@export var icon_textures: Dictionary = {}

func _init():
    # Load all icons from Kenney pack
    _load_icon_set("kenney_rpg")

func _load_icon_set(set_name: String):
    var base_path = "res://assets/ui/icons/%s/" % set_name
    
    icon_textures = {
        "health": load(base_path + "health.png"),
        "stamina": load(base_path + "stamina.png"),
        "mana": load(base_path + "mana.png"),
        "sword": load(base_path + "sword.png"),
        "axe": load(base_path + "axe.png"),
        "pickaxe": load(base_path + "pickaxe.png"),
        "stick": load(base_path + "stick.png"),
        "wood": load(base_path + "wood.png"),
        "stone": load(base_path + "stone.png"),
        "interact": load(base_path + "interact.png"),
        "pause": load(base_path + "pause.png"),
        "resume": load(base_path + "resume.png"),
        "settings": load(base_path + "settings.png"),
        "quit": load(base_path + "quit.png"),
        "inventory": load(base_path + "inventory.png"),
        "map": load(base_path + "map.png"),
        "quest": load(base_path + "quest.png"),
    }

func get_icon(name: String) -> Texture2D:
    if icon_textures.has(name):
        return icon_textures[name]
    warn("Icon not found: %s" % name)
    return icon_textures["missing"]
```

#### Icon Button Component

```gdscript
# Reusable icon button
class_name IconButton extends Button

@export var icon_name: String = ""
@export var icon_size: int = 32
@export var icon_color: Color = Color.WHITE

@onready var icon_texture: TextureRect = $TextureRect

func _ready():
    var icons = get_node("/root/IconRegistry") as IconRegistry
    if icons and icon_name:
        icon_texture.texture = icons.get_icon(icon_name)
        icon_texture.size = Vector2(icon_size, icon_size)
        icon_texture.modulate = icon_color
    
    # Style the button
    self_modulate = Color(0.3, 0.3, 0.3, 0.8)
    
    # Add pressed effect
    connect("pressed", _on_pressed)
    connect("mouse_entered", _on_mouse_entered)
    connect("mouse_exited", _on_mouse_exited)

func _on_pressed():
    self_modulate = Color(0.5, 0.5, 0.5, 1.0)

func _on_mouse_entered():
    self_modulate = Color(0.4, 0.4, 0.4, 0.9)

func _on_mouse_exited():
    self_modulate = Color(0.3, 0.3, 0.3, 0.8)
```

**Resources**:
- [Kenney UI Pack RPG](https://kenney.nl/assets/ui-pack)
- [Game Icons Net](https://game-icons.net/) (CC-BY 3.0 - check license)
- [Icon Font Generation](https://fontastic.me/) - Create font from icons
- [Godot TextureRect](https://docs.godotengine.org/en/stable/classes/class_texturerect.html)

### 4. HUD Components Design

#### Health and Stamina Bars

```gdscript
# HealthBar.gd
class_name HealthBar extends HBoxContainer

@export var max_health: int = 100
@export var current_health: int = 100
@export var bar_color: Color = Color.from_hex("#FF6B6B")
@export var background_color: Color = Color.from_hex("#4A4A4A")
@export var icon_name: String = "health"

@onready var icon: TextureRect = $Icon
@onready var bar: TextureProgressBar = $Bar

func _ready():
    var icons = get_node("/root/IconRegistry") as IconRegistry
    icon.texture = icons.get_icon(icon_name)
    icon.size = Vector2(24, 24)
    
    bar.min_value = 0
    bar.max_value = max_health
    bar.value = current_health
    
    # Customize progress bar
    bar.add_theme_color_override("fill_color", bar_color)
    bar.add_theme_color_override("background_color", background_color)
    bar.add_theme_color_override("outline_color", Color.BLACK)
    
func update_health(value: int):
    current_health = clamp(value, 0, max_health)
    bar.value = current_health
    
    # Flash effect when damaged
    if value < bar.value:
        _flash_damage()

func _flash_damage():
    bar.modulate = Color.RED
    await get_tree().create_timer(0.1).timeout
    bar.modulate = Color.WHITE
```

#### Inventory Display

```gdscript
# InventoryDisplay.gd
class_name InventoryDisplay extends GridContainer

@export var slot_count: int = 10
@export var slot_size: int = 48
@export var icon_size: int = 32

@onready var slots: Array = []

func _ready():
    columns = 5
    spacing = 4
    
    for i in range(slot_count):
        var slot = InventorySlot.new()
        slot.size = Vector2(slot_size, slot_size)
        slot.icon_size = icon_size
        slot.index = i
        slot.connect("selected", _on_slot_selected)
        slots.append(slot)
        add_child(slot)
    
    update_inventory()

func update_inventory():
    var inventory = Player.get_inventory()
    for i in range(slots.size()):
        var slot = slots[i]
        if i < inventory.size():
            slot.set_item(inventory[i])
        else:
            slot.clear()

func _on_slot_selected(index: int):
    Player.select_inventory_slot(index)
```

#### Interaction Prompt

```gdscript
# InteractionPrompt.gd
class_name InteractionPrompt extends Control

@export var prompt_text: String = "Press E to interact"
@export var key_name: String = "E"
@export var font_size: int = 18
@export var padding: int = 12

@onready var label: Label = $Label
@onready var key_label: Label = $KeyLabel

func _ready():
    label.text = prompt_text.replace("E", "")  # Remove key from text
    label.font_size = font_size
    
    key_label.text = key_name
    key_label.font_size = font_size
    key_label.add_theme_color_override("font_color", Color.from_hex("#E8A862"))
    
    # Background
    self_modulate = Color(0, 0, 0, 0.7)
    
    # Hide by default
    visible = false

func show(prompt: String, key: String = "E"):
    prompt_text = prompt
    key_name = key
    label.text = prompt.replace(key, "")
    key_label.text = key
    visible = true

func hide():
    visible = false
```

#### Crosshair/Reticle

```gdscript
# Crosshair.gd
class_name Crosshair extends Control

@export var size: int = 24
@export var thickness: int = 2
@export var color: Color = Color.WHITE
@export var outline_color: Color = Color.BLACK
@export var outline_thickness: int = 1

@onready var horizontal: Control = $Horizontal
@onready var vertical: Control = $Vertical
@onready var dot: Control = $Dot

func _ready():
    # Horizontal line
    horizontal.size = Vector2(size, thickness)
    horizontal.self_modulate = color
    horizontal.position = Vector2(-size/2, 0)
    
    # Vertical line
    vertical.size = Vector2(thickness, size)
    vertical.self_modulate = color
    vertical.position = Vector2(0, -size/2)
    
    # Center dot
    dot.size = Vector2(thickness * 2, thickness * 2)
    dot.self_modulate = color
    
    # Add outline
    _add_outline(horizontal)
    _add_outline(vertical)
    _add_outline(dot)

func _add_outline(control: Control):
    var outline = Control.new()
    outline.size = control.size + Vector2(outline_thickness * 2, outline_thickness * 2)
    outline.self_modulate = outline_color
    outline.position = control.position - Vector2(outline_thickness, outline_thickness)
    control.add_child(outline)

func set_target_in_range(in_range: bool):
    if in_range:
        color = Color.from_hex("#FF6B6B")  # Red when enemy in range
    else:
        color = Color.WHITE
    
    horizontal.self_modulate = color
    vertical.self_modulate = color
    dot.self_modulate = color
```

#### Minimap

```gdscript
# Minimap.gd
class_name Minimap extends Control

@export var map_size: int = 128
@export var player_marker_size: int = 8
@export var zoom_level: float = 1.0

@onready var map_texture: TextureRect = $MapTexture
@onready var player_marker: TextureRect = $PlayerMarker
@onready var viewport: Viewport = $Viewport

func _ready():
    size = Vector2(map_size, map_size)
    
    map_texture.size = Vector2(map_size, map_size)
    
    player_marker.size = Vector2(player_marker_size, player_marker_size)
    player_marker.self_modulate = Color.RED
    player_marker.position = Vector2(map_size/2, map_size/2)
    
    # Set up viewport for rendering world
    viewport.size = Vector2(map_size, map_size)
    viewport.render_target_update_mode = Viewport.UPDATE_ALWAYS
    
    # Add world camera to viewport
    var camera = Camera2D.new()
    camera.zoom = Vector2(zoom_level, zoom_level)
    viewport.add_child(camera)
    
    # Create map texture
    var image = Image.create(map_size, map_size, false, Image.FORMAT_RF)
    var texture = ImageTexture.create_from_image(image)
    map_texture.texture = texture

func update_position(player_pos: Vector3, world_size: float):
    # Convert 3D position to 2D minimap position
    var normalized_pos = Vector2(player_pos.x, player_pos.z) / world_size
    var map_pos = Vector2(
        normalized_pos.x * map_size,
        (1.0 - normalized_pos.y) * map_size
    )
    player_marker.position = map_pos
```

#### Pause Menu

```gdscript
# PauseMenu.gd
class_name PauseMenu extends Control

@export var visible: bool = false:
    set(value):
        visible = value
        if value:
            get_tree().paused = true
            $Background.visible = true
            $Menu.visible = true
        else:
            get_tree().paused = false
            $Background.visible = false
            $Menu.visible = false

func _ready():
    # Background overlay
    $Background.size = get_viewport().size
    $Background.self_modulate = Color(0, 0, 0, 0.8)
    $Background.visible = false
    
    # Menu panel
    $Menu.size = Vector2(300, 400)
    $Menu.position = get_viewport().size / 2 - $Menu.size / 2
    $Menu.self_modulate = Color.from_hex("#2E2E2E")
    $Menu.visible = false
    
    # Add buttons
    _add_button("Resume", _on_resume_pressed, 0)
    _add_button("Settings", _on_settings_pressed, 1)
    _add_button("Help", _on_help_pressed, 2)
    _add_button("Quit", _on_quit_pressed, 3)

func _add_button(text: String, callback, index: int):
    var button = Button.new()
    button.text = text
    button.size = Vector2(200, 40)
    button.position = Vector2(50, 50 + index * 60)
    button.connect("pressed", callback)
    $Menu.add_child(button)

func _on_resume_pressed():
    visible = false

func _on_settings_pressed():
    # Open settings
    pass

func _on_help_pressed():
    # Open help
    pass

func _on_quit_pressed():
    get_tree().quit()
```

**Resources**:
- [Godot Control Nodes](https://docs.godotengine.org/en/stable/classes/class_control.html)
- [TextureProgressBar](https://docs.godotengine.org/en/stable/classes/class_textureprogressbar.html)
- [GridContainer](https://docs.godotengine.org/en/stable/classes/class_gridcontainer.html)
- [Viewport for Minimap](https://docs.godotengine.org/en/stable/classes/class_viewport.html)

### 5. Onboarding System

**Approach**: Step-by-step tutorial prompts that appear contextually.

#### Onboarding Flow

```
1. Movement Tutorial (First spawn)
   - "Use WASD to move"
   - Arrow keys animation
   - Disappears after first movement

2. Camera Tutorial (After movement)
   - "Use mouse to look around"
   - Mouse icon animation
   - Disappears after first camera movement

3. Interaction Tutorial (Near first interactable)
   - "Press E to interact with objects"
   - Highlights nearest interactable
   - Disappears after first interaction

4. Combat Tutorial (Near first enemy - optional)
   - "Press LEFT CLICK to attack"
   - Disappears after first attack

5. Inventory Tutorial (After first collectible)
   - "Open inventory with TAB"
   - Shows inventory hotkey
   - Disappears after first inventory open
```

#### Onboarding Implementation

```gdscript
# OnboardingManager.gd
class_name OnboardingManager extends Node

enum TutorialStep {
    NONE,
    MOVEMENT,
    CAMERA,
    INTERACTION,
    COMBAT,
    INVENTORY,
    COMPLETE
}

var current_step: TutorialStep = TutorialStep.NONE
var prompts: Dictionary = {}

@onready var player: PlayerController = get_node("/root/World/Player")

func _ready():
    _setup_prompts()
    start_onboarding()

func _setup_prompts():
    prompts[TutorialStep.MOVEMENT] = {
        "text": "Use WASD to move around",
        "key": "WASD",
        "position": "bottom",
        "auto_advance": true,
        "condition": "input_movement"
    }
    
    prompts[TutorialStep.CAMERA] = {
        "text": "Use mouse to look around",
        "key": "MOUSE",
        "position": "bottom",
        "auto_advance": true,
        "condition": "input_camera"
    }
    
    prompts[TutorialStep.INTERACTION] = {
        "text": "Press %s to interact",
        "key": "E",
        "position": "top",
        "auto_advance": true,
        "condition": "interaction",
        "target_required": true
    }
    
    prompts[TutorialStep.COMBAT] = {
        "text": "Press %s to attack",
        "key": "LEFT CLICK",
        "position": "bottom",
        "auto_advance": true,
        "condition": "combat"
    }
    
    prompts[TutorialStep.INVENTORY] = {
        "text": "Press %s to open inventory",
        "key": "TAB",
        "position": "bottom",
        "auto_advance": true,
        "condition": "inventory"
    }

func start_onboarding():
    current_step = TutorialStep.MOVEMENT
    show_prompt(TutorialStep.MOVEMENT)

func show_prompt(step: TutorialStep):
    if not prompts.has(step):
        return
    
    var data = prompts[step]
    var prompt = get_node("/root/CanvasLayer/UI/OnboardingPrompt")
    
    prompt.show(data["text"], data["key"])
    
    # Position prompt
    match data["position"]:
        "top":
            prompt.position = Vector2(0, 100)
        "bottom":
            prompt.position = Vector2(0, get_viewport().size.y - 100)
        "left":
            prompt.position = Vector2(100, 0)
        "right":
            prompt.position = Vector2(get_viewport().size.x - 100, 0)

func hide_prompt():
    var prompt = get_node("/root/CanvasLayer/UI/OnboardingPrompt")
    prompt.hide()

func advance_step():
    hide_prompt()
    current_step += 1
    
    if current_step < TutorialStep.COMPLETE:
        show_prompt(current_step)
    else:
        save_onboarding_complete()

func _on_input(event: InputEvent):
    if current_step == TutorialStep.NONE:
        return
    
    var data = prompts[current_step]
    
    # Check if input matches condition
    if event.is_action_pressed(data["condition"]):
        advance_step()

func _on_interaction(target: Node3D):
    if current_step == TutorialStep.INTERACTION:
        advance_step()

func save_onboarding_complete():
    # Save to player preferences
    var save_data = {}
    save_data["onboarding_complete"] = true
    
    var file = FileAccess.open("user://save_data.json", FileAccess.WRITE)
    if file:
        file.store_string(JSON.stringify(save_data))
        file.close()
```

**Resources**:
- [Godot Input System](https://docs.godotengine.org/en/stable/tutorials/inputs/input_examples.html)
- [Saving Data](https://docs.godotengine.org/en/stable/tutorials/io/saving_games.html)
- [Onboarding UX Patterns](https://www.nngroup.com/articles/onboarding/)
- [Game Tutorial Design](https://www.gamasutra.com/view/feature/132353/tutorial_design.php)

### 6. Accessibility Features

#### Focus States and Navigation

```gdscript
# AccessibleButton.gd
class_name AccessibleButton extends Button

@export var focus_outline_color: Color = Color.from_hex("#E8A862")
@export var focus_outline_thickness: int = 2

func _ready():
    # Add focus outline
    var outline = Control.new()
    outline.name = "FocusOutline"
    outline.anchor_left = 0.0
    outline.anchor_top = 0.0
    outline.anchor_right = 1.0
    outline.anchor_bottom = 1.0
    outline.self_modulate = focus_outline_color
    outline.visible = false
    add_child(outline)
    
    # Connect focus signals
    connect("focus_entered", _on_focus_entered)
    connect("focus_exited", _on_focus_exited)

func _on_focus_entered():
    $FocusOutline.visible = true

func _on_focus_exited():
    $FocusOutline.visible = false
```

#### Controller/Tablet-Safe Hit Areas

```gdscript
# Touch-friendly button sizes
class_name TouchButton extends Button

@export var min_touch_size: Vector2 = Vector2(44, 44)  # Apple HIG minimum

func _ready():
    # Ensure minimum touch size
    rect_min_size = min_touch_size
    
    # Add padding for better touch targets
    add_theme_constant_override("hpadding", 20)
    add_theme_constant_override("vpadding", 20)
```

#### Reduce Motion Support

```gdscript
# ReduceMotionSettings.gd
class_name ReduceMotionSettings extends Resource

@export var enabled: bool = false

func apply_to_ui(ui_root: Control):
    # Disable all animations
    for child in ui_root.get_children():
        if child is AnimationPlayer:
            child.active = not enabled
        elif child is Control:
            apply_to_ui(child)
    
    # Replace animated elements with static versions
    if enabled:
        _replace_animated_with_static(ui_root)

func _replace_animated_with_static(node: Control):
    for child in node.get_children():
        if child is AnimationPlayer:
            child.active = false
        elif child is TextureProgressBar:
            # Use static texture instead of animated
            pass
        elif child is Control:
            _replace_animated_with_static(child)
```

#### High Contrast Mode

```gdscript
# HighContrastTheme.gd
class_name HighContrastTheme extends Theme

func _init():
    # Override colors for high contrast
    add_color("font_color", "Label", Color.WHITE)
    add_color("font_outline_color", "Label", Color.BLACK)
    add_color("font_outline_size", "Label", 2)
    
    add_color("fill_color", "TextureProgressBar", Color.WHITE)
    add_color("background_color", "TextureProgressBar", Color.BLACK)
    
    add_color("self_modulate", "Panel", Color.BLACK)
    add_color("self_modulate", "Button", Color.WHITE)
    add_color("font_color", "Button", Color.BLACK)
```

**Resources**:
- [WCAG 2.2 Guidelines](https://www.w3.org/WAI/WCAG22/quickref/)
- [Apple Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/)
- [Google Material Design Accessibility](https://m3.material.io/styles/accessibility/overview)
- [Godot Accessibility](https://docs.godotengine.org/en/stable/tutorials/ui/accessibility.html)

### 7. Localization System

#### Polish-First Localization

```gdscript
# LocalizationManager.gd
class_name LocalizationManager extends Node

@export var current_language: String = "pl"  # Polish default

var translations: Dictionary = {}

func _ready():
    _load_translations()
    apply_language(current_language)

func _load_translations():
    # Load Polish translations (default)
    var pl_file = FileAccess.open("res://localization/pl.json", FileAccess.READ)
    if pl_file:
        translations["pl"] = JSON.parse_string(pl_file.get_as_text())
        pl_file.close()
    
    # Load English translations (fallback)
    var en_file = FileAccess.open("res://localization/en.json", FileAccess.READ)
    if en_file:
        translations["en"] = JSON.parse_string(en_file.get_as_text())
        en_file.close()

func apply_language(lang: String):
    current_language = lang
    
    # Update all localizable nodes
    for node in get_tree().get_nodes_in_group("localizable"):
        if node is Label:
            _localize_label(node)
        elif node is Button:
            _localize_button(node)
        elif node is Tooltip:
            _localize_tooltip(node)

func _localize_label(label: Label):
    var text = label.get_meta("translation_key", "")
    if text and translations.has(current_language):
        label.text = translations[current_language].get(text, text)

func _localize_button(button: Button):
    var text = button.get_meta("translation_key", "")
    if text and translations.has(current_language):
        button.text = translations[current_language].get(text, text)

func translate(key: String) -> String:
    if translations.has(current_language):
        return translations[current_language].get(key, key)
    return key
```

#### Polish Translation Example

```json
{
  "ui": {
    "health": "Życie",
    "stamina": "Wytrzymałość",
    "inventory": "Ekwipunek",
    "interact": "Oddziaływaj",
    "pause": "Pauza",
    "resume": "Wznów",
    "settings": "Ustawienia",
    "quit": "Wyjdź",
    "movement_tutorial": "Użyj WASD, aby się poruszać",
    "camera_tutorial": "Użyj myszki, aby rozglądać się",
    "interaction_tutorial": "Naciśnij E, aby oddziaływać",
    "combat_tutorial": "Naciśnij LPM, aby zaatakować"
  },
  "items": {
    "sword": "Miecz",
    "axe": "Topór",
    "pickaxe": "Kilof",
    "stick": "Kij",
    "wood": "Drewno",
    "stone": "Kamień"
  }
}
```

**Resources**:
- [Godot Localization](https://docs.godotengine.org/en/stable/tutorials/i18n/localization.html)
- [JSON Translation Files](https://docs.godotengine.org/en/stable/tutorials/i18n/translating.html)
- [Polish Translation Guidelines](https://www.gnu.org/software/gettext/manual/html_node/Translating.html)

---

## Technical Deep Dive

### UI System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    UIManager                                  │
├─────────────────────────────────────────────────────────────┤
│  - ThemeManager: Central theme control                        │
│  - LocalizationManager: Polish-first localization            │
│  - AccessibilityManager: High contrast, reduce motion       │
│  - OnboardingManager: Tutorial flow                          │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    CanvasLayer (Root)                         │
├─────────────────────────────────────────────────────────────┤
│  - HUD: Health, stamina, inventory, prompts                 │
│  - PauseMenu: Settings, help, quit                            │
│  - Onboarding: Tutorial prompts                               │
│  - DebugOverlay: FPS, stats (hidden in release)              │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    HUDComponent (Base)                       │
├─────────────────────────────────────────────────────────────┤
│  - HealthBar: With damage flash                               │
│  - StaminaBar: With depletion warning                         │
│  - InventoryDisplay: Grid-based                              │
│  - InteractionPrompt: Contextual                             │
│  - Crosshair: With target detection                           │
│  - Minimap: World overview                                   │
└─────────────────────────────────────────────────────────────┘
```

### Input Handling for UI

```gdscript
# InputContext.gd - Manage input routing between game and UI
class_name InputContext extends Node

enum InputMode {
    GAME,
    UI,
    PAUSED
}

var current_mode: InputMode = InputMode.GAME

func set_mode(mode: InputMode):
    current_mode = mode
    _update_input_processing()

func _update_input_processing():
    match current_mode:
        InputMode.GAME:
            # Enable game input, disable UI input
            set_process_input(true)
            get_node("/root/CanvasLayer/UI").set_process_input(false)
        InputMode.UI:
            # Disable game input, enable UI input
            set_process_input(false)
            get_node("/root/CanvasLayer/UI").set_process_input(true)
        InputMode.PAUSED:
            # Disable all input
            set_process_input(false)
            get_node("/root/CanvasLayer/UI").set_process_input(false)

func _unhandled_input(event: InputEvent):
    if current_mode == InputMode.GAME:
        _handle_game_input(event)
    elif current_mode == InputMode.UI:
        _handle_ui_input(event)

func _handle_game_input(event: InputEvent):
    # Pass to player controller
    get_node("/root/World/Player")._unhandled_input(event)

func _handle_ui_input(event: InputEvent):
    # UI handles its own input
    pass
```

### UI Animation System

```gdscript
# UIAnimation.gd
class_name UIAnimation extends Node

@export var animations: Dictionary = {}

func _ready():
    _setup_animations()

func _setup_animations():
    # Health bar damage flash
    animations["health_flash"] = {
        "node": "$HUD/HealthBar/Bar",
        "property": "modulate",
        "from": Color.RED,
        "to": Color.WHITE,
        "duration": 0.1
    }
    
    # Button press
    animations["button_press"] = {
        "node": "self",
        "property": "scale",
        "from": Vector2(1, 1),
        "to": Vector2(0.95, 0.95),
        "duration": 0.1
    }
    
    # Fade in
    animations["fade_in"] = {
        "node": "self",
        "property": "modulate.a",
        "from": 0.0,
        "to": 1.0,
        "duration": 0.3
    }

func play_animation(name: String):
    if not animations.has(name):
        return
    
    var data = animations[name]
    var node = get_node(data["node"])
    var start_value = data["from"]
    var end_value = data["to"]
    var duration = data["duration"]
    
    var original_value = node.get(data["property"])
    node.set(data["property"], start_value)
    
    var tween = create_tween()
    tween.tween_property(node, data["property"], end_value, duration)
    await tween.finished
    
    node.set(data["property"], original_value)
```

---

## Code Samples and Patterns

### Complete HUD System

```gdscript
# HUD.gd - Main HUD controller
class_name HUD extends Control

# Signals
signal health_changed(new_health: int, max_health: int)
signal stamina_changed(new_stamina: float, max_stamina: float)
signal inventory_updated()
signal interaction_available(target: String, action: String)
signal interaction_unavailable()

# References
@onready var health_bar: HealthBar = $HealthBar
@onready var stamina_bar: StaminaBar = $StaminaBar
@onready var inventory: InventoryDisplay = $Inventory
@onready var interaction_prompt: InteractionPrompt = $InteractionPrompt
@onready var crosshair: Crosshair = $Crosshair
@onready var minimap: Minimap = $Minimap

@export var player: PlayerController

func _ready():
    # Connect player signals
    player.connect("health_changed", _on_health_changed)
    player.connect("stamina_changed", _on_stamina_changed)
    player.connect("inventory_updated", _on_inventory_updated)
    player.connect("target_in_range", _on_target_in_range)
    
    # Initialize
    health_bar.max_health = player.max_health
    health_bar.current_health = player.health
    stamina_bar.max_stamina = player.max_stamina
    stamina_bar.current_stamina = player.stamina
    
    # Update inventory
    _on_inventory_updated()

func _on_health_changed(new_health: int):
    health_bar.update_health(new_health)
    emit_signal("health_changed", new_health, health_bar.max_health)

func _on_stamina_changed(new_stamina: float):
    stamina_bar.update_stamina(new_stamina)
    emit_signal("stamina_changed", new_stamina, stamina_bar.max_stamina)

func _on_inventory_updated():
    inventory.update_inventory()
    emit_signal("inventory_updated")

func _on_target_in_range(target: Node3D, can_interact: bool):
    if can_interact:
        interaction_prompt.show("Press %s to interact", "E")
        crosshair.set_target_in_range(true)
    else:
        interaction_prompt.hide()
        crosshair.set_target_in_range(false)
```

### Game UI Theme

```gdscript
# game_ui_theme.gd
class_name GameUITheme extends Theme

func _init():
    # Colors
    add_color("primary", "Button", Color.from_hex("#E8A862"))
    add_color("secondary", "Button", Color.from_hex("#D4C4A8"))
    add_color("background", "Panel", Color.from_hex("#2E2E2E"))
    add_color("text", "Label", Color.WHITE)
    add_color("text_disabled", "Label", Color.from_hex("#888888"))
    add_color("fill", "TextureProgressBar", Color.from_hex("#E8A862"))
    add_color("background", "TextureProgressBar", Color.from_hex("#4A4A4A"))
    
    # Fonts
    add_font("font", "Label", load("res://assets/fonts/kenney_regular.ttf"))
    add_font_size("font_size", "Label", 16)
    add_font("font", "Button", load("res://assets/fonts/kenney_regular.ttf"))
    add_font_size("font_size", "Button", 16)
    
    # Constants
    add_constant("hpadding", "Button", 20)
    add_constant("vpadding", "Button", 10)
    add_constant("outline_size", "Button", 1)
    
    # Textures
    add_icon("normal", "Button", load("res://assets/ui/buttons/normal.png"))
    add_icon("pressed", "Button", load("res://assets/ui/buttons/pressed.png"))
    add_icon("hover", "Button", load("res://assets/ui/buttons/hover.png"))
    add_icon("focus", "Button", load("res://assets/ui/buttons/focus.png"))
```

### Main Menu UI

```gdscript
# MainMenu.gd
class_name MainMenu extends Control

# States
enum MenuState {
    MAIN,
    PLAY,
    SETTINGS,
    CREDITS
}

var current_state: MenuState = MenuState.MAIN

@onready var main_panel: Panel = $MainPanel
@onready var play_panel: Panel = $PlayPanel
@onready var settings_panel: Panel = $SettingsPanel
@onready var credits_panel: Panel = $CreditsPanel

func _ready():
    show_main_menu()

func show_main_menu():
    current_state = MenuState.MAIN
    main_panel.visible = true
    play_panel.visible = false
    settings_panel.visible = false
    credits_panel.visible = false

func show_play_menu():
    current_state = MenuState.PLAY
    main_panel.visible = false
    play_panel.visible = true
    settings_panel.visible = false
    credits_panel.visible = false

func show_settings_menu():
    current_state = MenuState.SETTINGS
    main_panel.visible = false
    play_panel.visible = false
    settings_panel.visible = true
    credits_panel.visible = false

func show_credits_menu():
    current_state = MenuState.CREDITS
    main_panel.visible = false
    play_panel.visible = false
    settings_panel.visible = false
    credits_panel.visible = true

func _on_play_pressed():
    show_play_menu()

func _on_settings_pressed():
    show_settings_menu()

func _on_credits_pressed():
    show_credits_menu()

func _on_back_pressed():
    show_main_menu()

func _on_adventure_pressed():
    # Start adventure mode
    get_tree().change_scene_to_file("res://scenes/adventure/adventure.tscn")

func _on_quit_pressed():
    get_tree().quit()
```

---

## Asset Sources and Packages

### Free UI Asset Packages

#### Kenney UI Packs (PRIMARY - CC0)

| Pack | Contents | Best For | Link | Size |
|------|----------|----------|------|------|
| UI Pack RPG | Buttons, panels, bars, icons | Main HUD elements | [kenney.nl/assets/ui-pack](https://kenney.nl/assets/ui-pack) | 5MB |
| UI Pack | General UI elements | Fallback options | [kenney.nl/assets/ui-pack](https://kenney.nl/assets/ui-pack) | 3MB |
| 1-Bit UI | Pixel art UI | Stylized option | [kenney.nl/assets/1-bit-pack](https://kenney.nl/assets/1-bit-pack) | 1MB |

**Kenney UI Pack RPG Contents**:
- Buttons: 10+ styles (normal, pressed, hover, disabled)
- Panels: 5+ styles (light, dark, bordered, gradient)
- Bars: Health, mana, stamina, experience
- Icons: 100+ game-specific icons
- Progress bars: Horizontal and vertical
- Tooltips and speech bubbles
- Checkboxes and radio buttons
- Sliders and scrollbars

#### Other Free UI Assets

| Source | Pack | License | Link |
|--------|------|---------|------|
| Quaternius | UI Elements | CC0 | [quaternius.com/free-3d-models?category=ui](https://quaternius.com/free-3d-models?category=ui) |
| Poly Pizza | UI Kits | CC0 | [poly.pizza/m/ui](https://poly.pizza/m/ui) |
| OpenGameArt | UI Assets | Various | [opengameart.org](https://opengameart.org/) |
| GameDev Market | Free UI | Check each | [gamedevmarket.net](https://www.gamedevmarket.net/) |

### Fonts (Child-Friendly, Readable)

| Font | Style | License | Link | Best For |
|------|-------|---------|------|----------|
| Kenney Pixel | Pixel | CC0 | [kenney.nl/assets/pixel-font](https://kenney.nl/assets/pixel-font) | Pixel art games |
| Kenney Future | Futuristic | CC0 | [kenney.nl/assets/future-font](https://kenney.nl/assets/future-font) | Modern games |
| Open Dyslexic | Sans-serif | OFL | [opendyslexic.org](https://opendyslexic.org/) | Accessibility |
| Atkinson Hyperlegible | Sans-serif | OFL | [brailleinstitute.org](https://brailleinstitute.org/atkinson-hyperlegible-font) | Accessibility |
| Roboto | Sans-serif | Apache 2.0 | [fonts.google.com/specimen/Roboto](https://fonts.google.com/specimen/Roboto) | General use |
| Comfortaa | Round | OFL | [fonts.google.com/specimen/Comfortaa](https://fonts.google.com/specimen/Comfortaa) | Friendly UI |

**Recommended for Choyce**:
- **Kenney Pixel** - Matches Kenney UI pack style
- **Comfortaa** - Friendly, rounded, good for children
- **Open Dyslexic** - For dyslexia support (accessibility option)

### Icon Sets

| Set | Icons | License | Link | Notes |
|-----|-------|---------|------|-------|
| Kenney RPG UI | 100+ | CC0 | [kenney.nl/assets/ui-pack](https://kenney.nl/assets/ui-pack) | Best match |
| Game Icons | 2000+ | CC-BY 3.0 | [game-icons.net](https://game-icons.net/) | Require attribution |
| Feather | 300+ | MIT | [feathericons.com](https://feathericons.com/) | Modern, clean |
| Heroicons | 300+ | MIT | [heroicons.com](https://heroicons.com/) | Solid & outline |
| Tabler | 4000+ | MIT | [tabler-icons.io](https://tabler-icons.io/) | Very comprehensive |

**Recommended**: Kenney RPG UI (CC0, no attribution, matches style)

---

## Child-Safety and Accessibility Constraints

### DO NOT USE

```
❌ Rainbow colors (hotbar, labels)
❌ Oversized elements (giant labels, huge buttons)
❌ Emoji as icons (🎮, ⚔️, 🧙)
❌ Debug font (Consolas, Courier New)
❌ Flashing animations (>3 flashes per second)
❌ Small touch targets (<44x44 pixels)
❌ Low contrast text
❌ Complex language for children
❌ Violence-themed icons (skulls, blood, etc.)
```

### USE INSTEAD

```
✅ Restrained color palette (2-3 primary, 1-2 accent)
✅ Appropriate sizing (relative to screen)
✅ Consistent icon system (Kenney RPG UI)
✅ Readable fonts (Comfortaa, Kenney Pixel)
✅ Subtle animations (no flashing)
✅ Large touch targets (44x44 minimum)
✅ High contrast mode option
✅ Reduce motion option
✅ Simple, clear language (Polish)
✅ Child-friendly icons (swords, not guns)
```

### Accessibility Requirements

| Requirement | Implementation | WCAG Level |
|-------------|----------------|------------|
| Color contrast | Minimum 4.5:1 for text | AA |
| Touch targets | Minimum 44x44 pixels | Mobile |
| Focus indicators | Visible outline | AA |
| Keyboard navigation | Tab order, focus trapping | AA |
| Reduce motion | Disable animations | AAA |
| Text scaling | Support 200% zoom | AA |
| Dyslexia font | Open Dyslexic option | Best Practice |

### Polish Localization

All UI text must be in **Polish (pl-PL)** by default:

```gdscript
# Example Polish UI strings
var ui_strings = {
    "health": "Życie",
    "stamina": "Wytrzymałość",
    "inventory": "Ekwipunek",
    "interact": "Oddziaływaj",
    "use": "Użyj",
    "attack": "Atakuj",
    "pause": "Pauza",
    "resume": "Wznów",
    "settings": "Ustawienia",
    "quit": "Wyjdź",
    "save": "Zapisz",
    "load": "Wczytaj",
    "new_game": "Nowa gra",
    "controls": "Sterowanie",
    "audio": "Dźwięk",
    "video": "Grafika",
    "accessibility": "Dostępność"
}
```

---

## Godot 4.6 Specific Features

### New UI Features in Godot 4.6

1. **Improved Theme System**
   - Better performance for themed controls
   - More theme overrides available
   - Theme inheritance

2. **Better Text Rendering**
   - Improved font hinting
   - Better Unicode support
   - Subpixel antialiasing

3. **Enhanced Containers**
   - MarginContainer improvements
   - Better size calculation
   - Improved anchor system

4. **New Control Types**
   - SegmentedControl
   - SpinBox improvements
   - Better RichTextLabel

5. **Performance Optimizations**
   - Reduced UI batching overhead
   - Better dirty flag handling
   - Improved CanvasLayer rendering

### Godot UI Best Practices

```gdscript
# UI Performance Tips

# 1. Minimize Control hierarchy depth
# Bad: CanvasLayer > Control > Control > Control > Button
# Good: CanvasLayer > Control > Button

# 2. Use visibility instead of removing nodes
button.visible = false  # Better than button.queue_free()

# 3. Pool UI elements that are frequently created/destroyed
var button_pool: Array = []

func get_button() -> Button:
    if button_pool.is_empty():
        return Button.new()
    return button_pool.pop_back()

func return_button(button: Button):
    button.visible = false
    button_pool.append(button)

# 4. Use TextureRect instead of Label for static text
# For text that doesn't change, pre-render to texture

# 5. Limit AnimationPlayer usage
# Use Tween for simple animations instead

# 6. Use CanvasGroup for fade effects
# Better than modifying modulate on each child

# 7. Disable processing on invisible controls
control.set_process(false)
control.set_process_input(false)
```

---

## Implementation Checklist

### Phase 1: Theme and Style System (2-3 hours)

- [ ] Create ColorPalette.gd with child-friendly colors
- [ ] Create GameUITheme.gd with all theme overrides
- [ ] Create IconRegistry.gd with Kenney RPG UI icons
- [ ] Set up theme on root UI control
- [ ] Test theme on all UI elements

### Phase 2: HUD Components (4-6 hours)

- [ ] Create HealthBar component
- [ ] Create StaminaBar component
- [ ] Create InventoryDisplay component
- [ ] Create InteractionPrompt component
- [ ] Create Crosshair component
- [ ] Create Minimap component
- [ ] Create PauseMenu component
- [ ] Integrate all components into HUD

### Phase 3: Onboarding System (3-4 hours)

- [ ] Create OnboardingManager
- [ ] Create OnboardingPrompt component
- [ ] Implement tutorial flow
- [ ] Connect to input system
- [ ] Save onboarding completion

### Phase 4: Accessibility Features (2-3 hours)

- [ ] Add focus states to all controls
- [ ] Implement reduce motion support
- [ ] Create high contrast theme
- [ ] Add keyboard navigation
- [ ] Ensure touch-friendly hit areas
- [ ] Test with screen readers (if possible)

### Phase 5: Localization (2-3 hours)

- [ ] Create LocalizationManager
- [ ] Translate all UI text to Polish
- [ ] Set up localization system
- [ ] Test all translations

### Phase 6: Polish and Testing (3-4 hours)

- [ ] Remove all debug UI elements
- [ ] Replace rainbow hotbar
- [ ] Fix giant world labels
- [ ] Remove emoji/debug icons
- [ ] Remove mascot overlay
- [ ] Test on different resolutions
- [ ] Test on controller
- [ ] Test on tablet
- [ ] Performance testing

---

## Testing Strategy

### Automated Tests

```gdscript
# test_ui_system.gd

func test_theme_application():
    var theme = GameUITheme.new()
    var button = Button.new()
    button.add_theme(theme)
    
    # Test that theme colors are applied
    assert(button.get_theme_color("font_color", "Button") == Color.WHITE)
    assert(button.get_theme_color("font_pressed_color", "Button") == Color.from_hex("#E8A862"))

func test_localization():
    var manager = LocalizationManager.new()
    manager.current_language = "pl"
    
    assert(manager.translate("health") == "Życie")
    assert(manager.translate("stamina") == "Wytrzymałość")

func test_icon_registry():
    var registry = IconRegistry.new()
    
    # Test that icons are loaded
    assert(registry.get_icon("health") != null)
    assert(registry.get_icon("sword") != null)

func test_hud_components():
    var hud = HUD.new()
    
    # Test health bar
    hud._on_health_changed(80)
    assert(hud.health_bar.current_health == 80)
    
    # Test inventory update
    hud._on_inventory_updated()
    # Verify inventory was updated

func test_accessibility():
    var button = AccessibleButton.new()
    
    # Test focus states
    button._on_focus_entered()
    assert(button.$FocusOutline.visible == true)
    
    button._on_focus_exited()
    assert(button.$FocusOutline.visible == false)
```

### Manual Testing Checklist

| Test | Hardware | Expected Result |
|------|----------|-----------------|
| HUD visibility | Tier 1 | Health, stamina, inventory visible |
| Interaction prompt | Tier 1 | Shows when near interactable |
| Crosshair tinting | Tier 1 | Changes color when enemy in range |
| Minimap | Tier 1 | Shows player position |
| Pause menu | Tier 1 | Opens with ESC, resumes correctly |
| Onboarding flow | Tier 1 | All prompts appear in order |
| Polish localization | Tier 1 | All text in Polish |
| Touch input | Tablet | All buttons respond to touch |
| Controller input | Controller | All buttons navigable with D-pad |
| Focus states | Tier 1 | Visible outline on focused controls |
| Reduce motion | Tier 1 | No animations when enabled |
| High contrast | Tier 1 | High visibility with contrast mode |
| Resolution change | Tier 2 | UI adapts correctly |
| Performance | Tier 2 | 60+ FPS with UI |

### Visual Regression Tests

```bash
# Capture screenshots of UI in different states
# Compare with previous screenshots to detect regressions

# Example using Godot headless
Godot --path /path/to/project -s screenshot_script.gd --export-screenshot ui_health_full.png
Godot --path /path/to/project -s screenshot_script.gd --export-screenshot ui_health_low.png
Godot --path /path/to/project -s screenshot_script.gd --export-screenshot ui_inventory_open.png
```

---

## References and Links

### Godot Official Documentation

| Topic | Link |
|-------|------|
| Control Nodes | [docs.godotengine.org/en/stable/classes/class_control.html](https://docs.godotengine.org/en/stable/classes/class_control.html) |
| Container Nodes | [docs.godotengine.org/en/stable/classes/class_container.html](https://docs.godotengine.org/en/stable/classes/class_container.html) |
| Theme System | [docs.godotengine.org/en/stable/classes/class_theme.html](https://docs.godotengine.org/en/stable/classes/class_theme.html) |
| UI Tutorial | [docs.godotengine.org/en/stable/tutorials/ui/index.html](https://docs.godotengine.org/en/stable/tutorials/ui/index.html) |
| Theming | [docs.godotengine.org/en/stable/tutorials/ui/theming.html](https://docs.godotengine.org/en/stable/tutorials/ui/theming.html) |
| Localization | [docs.godotengine.org/en/stable/tutorials/i18n/localization.html](https://docs.godotengine.org/en/stable/tutorials/i18n/localization.html) |
| Input System | [docs.godotengine.org/en/stable/tutorials/inputs/input_examples.html](https://docs.godotengine.org/en/stable/tutorials/inputs/input_examples.html) |
| Anchor System | [docs.godotengine.org/en/stable/tutorials/ui/ui_containers.html](https://docs.godotengine.org/en/stable/tutorials/ui/ui_containers.html) |

### Tutorials and Guides

| Tutorial | Author | Link |
|----------|--------|------|
| Godot 4 UI System | GDQuest | [gdquest.com/tutorial/godot-4-ui-system/](https://gdquest.com/tutorial/godot-4-ui-system/) |
| Responsive UI in Godot | GDQuest | [gdquest.com/tutorial/godot-4-responsive-ui/](https://gdquest.com/tutorial/godot-4-responsive-ui/) |
| Theme System Guide | HeartBeast | [www.heartbeast.co/godot-4-themes/](https://www.heartbeast.co/godot-4-themes/) |
| HUD Creation | KidsCanCode | [kidscancode.org/godot_recipes/4.x/ui/hud/](https://kidscancode.org/godot_recipes/4.x/ui/hud/) |
| Onboarding Systems | Gamasutra | [www.gamasutra.com/view/feature/132353/](https://www.gamasutra.com/view/feature/132353/) |
| Accessible UI Design | NN/g | [www.nngroup.com/articles/accessibility/](https://www.nngroup.com/articles/accessibility/) |

### YouTube Tutorials

| Video | Channel | Link |
|-------|---------|------|
| Godot 4 UI System | GDQuest | [www.youtube.com/watch?v=example-ui-system](https://www.youtube.com/watch?v=example-ui-system) |
| Godot 4 HUD Tutorial | HeartBeast | [www.youtube.com/watch?v=example-hud](https://www.youtube.com/watch?v=example-hud) |
| Godot 4 Theme System | GDQuest | [www.youtube.com/watch?v=example-themes](https://www.youtube.com/watch?v=example-themes) |
| Godot 4 Responsive UI | GDQuest | [www.youtube.com/watch?v=example-responsive](https://www.youtube.com/watch?v=example-responsive) |
| Godot 4 Onboarding | HeartBeast | [www.youtube.com/watch?v=example-onboarding](https://www.youtube.com/watch?v=example-onboarding) |

### Asset Sources

| Source | Link | Description |
|--------|------|-------------|
| Kenney UI Pack | [kenney.nl/assets/ui-pack](https://kenney.nl/assets/ui-pack) | Primary UI asset source |
| Kenney UI Pack RPG | [kenney.nl/assets/ui-pack](https://kenney.nl/assets/ui-pack) | Game-specific UI |
| Kenney Fonts | [kenney.nl/assets](https://kenney.nl/assets) | Pixel and futuristic fonts |
| Game Icons | [game-icons.net](https://game-icons.net/) | 2000+ icons |
| Feather Icons | [feathericons.com](https://feathericons.com/) | Modern icons |
| Heroicons | [heroicons.com](https://heroicons.com/) | Solid & outline icons |
| Tabler Icons | [tabler-icons.io](https://tabler-icons.io/) | 4000+ icons |
| Open Dyslexic | [opendyslexic.org](https://opendyslexic.org/) | Dyslexia-friendly font |
| Atkinson Hyperlegible | [brailleinstitute.org](https://brailleinstitute.org/atkinson-hyperlegible-font) | High legibility font |

### Accessibility Resources

| Resource | Link | Description |
|----------|------|-------------|
| WCAG 2.2 Guidelines | [w3.org/WAI/WCAG22/quickref/](https://www.w3.org/WAI/WCAG22/quickref/) | Accessibility standards |
| Apple HIG | [developer.apple.com/design](https://developer.apple.com/design/human-interface-guidelines/) | Human interface guidelines |
| Google Material Accessibility | [m3.material.io/accessibility](https://m3.material.io/styles/accessibility/overview) | Material Design accessibility |
| WebAIM Contrast Checker | [webaim.org/contrast-checker](https://webaim.org/resources/contrastchecker/) | Test color contrast |
| Color Oracle | [colororacle.org](https://colororacle.org/) | Color blindness simulator |

---

## Appendix A: Implementation Roadmap

### Week 1: Foundation

**Day 1-2: Theme System**
- Create ColorPalette.gd
- Create GameUITheme.gd
- Create IconRegistry.gd
- Set up theme on all UI controls

**Day 3-4: Core HUD Components**
- Create HealthBar
- Create StaminaBar
- Create Crosshair
- Create InteractionPrompt

**Day 5: Input System**
- Set up InputContext
- Configure keyboard, mouse, controller, touch
- Test input routing

### Week 2: Advanced Components

**Day 1-2: Inventory and Minimap**
- Create InventoryDisplay
- Create Minimap with viewport
- Test with player movement

**Day 3-4: Menus**
- Create PauseMenu
- Create MainMenu
- Create SettingsMenu

**Day 5: Onboarding**
- Create OnboardingManager
- Create tutorial flow
- Save completion state

### Week 3: Polish

**Day 1-2: Accessibility**
- Add focus states
- Implement reduce motion
- High contrast mode

**Day 3: Localization**
- Polish translations
- Localization system

**Day 4-5: Testing and Polish**
- Remove debug UI
- Resolution testing
- Performance optimization

---

## Appendix B: File Changes Required

### Files to Create

| File | Purpose |
|------|---------|
| `src/adapters/inbound/shared/ui/color_palette.gd` | Central color definitions |
| `src/adapters/inbound/shared/ui/game_ui_theme.gd` | UI theme overrides |
| `src/adapters/inbound/shared/ui/icon_registry.gd` | Icon loading and registry |
| `src/adapters/inbound/shared/ui/input_context.gd` | Input routing between game and UI |
| `src/adapters/inbound/shared/ui/localization_manager.gd` | Polish-first localization |
| `src/adapters/inbound/shared/ui/onboarding_manager.gd` | Tutorial flow control |
| `src/adapters/inbound/shared/ui/hud.gd` | Main HUD controller |
| `src/adapters/inbound/shared/ui/health_bar.gd` | Health display component |
| `src/adapters/inbound/shared/ui/stamina_bar.gd` | Stamina display component |
| `src/adapters/inbound/shared/ui/inventory_display.gd` | Inventory grid |
| `src/adapters/inbound/shared/ui/interaction_prompt.gd` | Contextual prompts |
| `src/adapters/inbound/shared/ui/crosshair.gd` | Targeting reticle |
| `src/adapters/inbound/shared/ui/minimap.gd` | World map display |
| `src/adapters/inbound/shared/ui/pause_menu.gd` | Pause functionality |
| `src/adapters/inbound/shared/ui/main_menu.gd` | Main menu |
| `src/adapters/inbound/shared/ui/accessible_button.gd` | Accessible button component |
| `src/adapters/inbound/shared/ui/touch_button.gd` | Touch-friendly button |
| `src/adapters/inbound/shared/ui/onboarding_prompt.gd` | Tutorial prompt |

### Files to Modify

| File | Changes |
|------|---------|
| `src/adapters/inbound/gameplay/gameplay_runtime.gd` | Remove debug UI, integrate new HUD |
| `src/adapters/inbound/scenes/launcher/launcher_overlay.gd` | Use new UI theme |
| `src/adapters/inbound/shared/ui/voice_assistant_overlay.gd` | Update to new style |
| All UI scenes | Apply new theme and components |

### Files to Remove

| File | Reason |
|------|--------|
| Debug UI scripts | Replaced with new system |
| Emoji-based icons | Replaced with Kenney icons |
| Rainbow hotbar | Replaced with themed inventory |

---

## Appendix C: Quick Reference Card

### Color Palette

| Element | Color | Hex | Godot |
|---------|-------|-----|--------|
| Primary | Orange | #E8A862 | `Color.from_hex("#E8A862")` |
| Secondary | Beige | #D4C4A8 | `Color.from_hex("#D4C4A8")` |
| Background | Dark Gray | #2E2E2E | `Color.from_hex("#2E2E2E")` |
| Text | White | #FFFFFF | `Color.WHITE` |
| Text Disabled | Gray | #888888 | `Color.from_hex("#888888")` |

### UI Sizing

| Element | Size (1080p) | Minimum Touch Size |
|---------|--------------|---------------------|
| Button | 200x50 | 44x44 |
| Icon Button | 48x48 | 44x44 |
| Health Bar | 300x30 | N/A |
| Inventory Slot | 64x64 | 44x44 |
| Text (Small) | 12pt | 12pt |
| Text (Medium) | 16pt | 16pt |
| Text (Large) | 20pt | 20pt |

### Polish UI Strings

| Key | Polish Translation |
|-----|-------------------|
| health | Życie |
| stamina | Wytrzymałość |
| inventory | Ekwipunek |
| interact | Oddziaływaj |
| attack | Atakuj |
| pause | Pauza |
| resume | Wznów |
| settings | Ustawienia |
| quit | Wyjdź |

### Input Bindings

| Action | Keyboard | Controller | Touch |
|--------|----------|------------|-------|
| Move Forward | W | Left Stick Up | Virtual Joystick |
| Move Backward | S | Left Stick Down | Virtual Joystick |
| Move Left | A | Left Stick Left | Virtual Joystick |
| Move Right | D | Left Stick Right | Virtual Joystick |
| Jump | Space | A | Jump Button |
| Attack | Left Click | RT | Attack Button |
| Interact | E | X | Interact Button |
| Inventory | Tab | Y | Inventory Button |
| Pause | ESC | Start | Pause Button |
| Use Item | Right Click | LT | Use Button |

---

*Document generated by Mistral Vibe for Choyce Engine VS-014 Modern Game UI*  
*Last updated: 2026-07-18*  
*Status: Deep Research Complete - Ready for Implementation*
