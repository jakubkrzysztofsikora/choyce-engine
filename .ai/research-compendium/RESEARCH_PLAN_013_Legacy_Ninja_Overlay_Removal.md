# PLAN-013: Legacy Ninja Overlay Removal & Modern UI Replacement - Deep Research Compendium

**Status**: in_progress  
**Specialty**: godot-ui-and-ux  
**Gate**: Foundation (PLAN.md Section 317)  
**Priority**: HIGH  
**Last Updated**: 2026-07-18  
**Child-Safety Consideration**: New UI must be intuitive for children, with clear visuals and no confusing elements

---

## Table of Contents

1. [Task Overview](#task-overview)
2. [Current State Analysis](#current-state-analysis)
3. [Legacy Ninja Overlay Architecture](#legacy-ninja-overlay-architecture)
4. [Removal Strategy](#removal-strategy)
5. [Modern UI Replacement Architecture](#modern-ui-replacement-architecture)
6. [Modern Mascot System (3D or Sprite-Based)](#modern-mascot-system-3d-or-sprite-based)
7. [Clean HUD Design Principles](#clean-hud-design-principles)
8. [Modern UI Component Library](#modern-ui-component-library)
9. [Godot Control Nodes Best Practices](#godot-control-nodes-best-practices)
10. [Theme System & Styling](#theme-system--styling)
11. [Accessibility Considerations](#accessibility-considerations)
12. [Code Samples & Implementation Patterns](#code-samples--implementation-patterns)
13. [Testing & Validation Checklist](#testing--validation-checklist)
14. [Learning Resources](#learning-resources)

---

## Task Overview

### Objective

**Remove the legacy Ninja overlay** (currently implemented as 2D `_draw()` primitives in `mascot.gd`) and replace it with a **modern, clean UI system** that:
- Uses proper Godot Control nodes or 3D models instead of `_draw()` primitives
- Provides a child-friendly, intuitive HUD
- Maintains the mascot character's personality and functionality
- Integrates seamlessly with the new visual direction (PLAN-012, PLAN-014)
- Removes all references to the old "Cześć, jestem twoim ninja" greeting (PLAN.md line 159)

### Source Reference

From PLAN.md (line 317-320):
> **Foundation:** collision dimensions are world metres rather than scaled proxy guesses; preserve native materials; use a camera ray and 3D preview for TPP building; real ground/dirt collision; a water volume with wading/swim physics; continuous exploration music; **no legacy Ninja overlay.**

From PLAN.md (line 159):
> The think-demo launcher starts without the old **"Cześć, jestem twoim ninja"** greeting.

From PLAN.md Visual Rescue Gate (line 154-155):
> Replace the oversized control legend, emoji/debug icon treatment, rainbow hotbar, giant world labels, **and mascot overlay** with a compact modern HUD.

### Key Requirements

- ✅ **Remove 2D primitives**: Replace `_draw()` calls in `mascot.gd` with proper nodes
- ✅ **Use existing 3D model**: Leverage the imported `ninja.glb` from Quaternius
- ✅ **Modern UI architecture**: Use CanvasLayer, Control nodes, proper containers
- ✅ **Clean separation**: Separate mascot presentation from game logic
- ✅ **Child-friendly**: Intuitive, clear, non-distracting UI
- ✅ **Remove legacy greeting**: Eliminate "Cześć, jestem twoim ninja" message
- ✅ **Maintain functionality**: Preserve mascot animations, speech bubbles, reactions

### Acceptance Criteria

1. No `_draw()` calls in mascot implementation
2. Mascot uses either 3D model (SubViewport) or proper Sprite3D/Sprite2D
3. All UI elements use Control nodes with proper theming
4. Mascot overlay is replaced with clean, compact HUD elements
5. Legacy Polish greeting is removed
6. No runtime errors after removal
7. Mascot functionality (speech, animations, reactions) preserved
8. Child can understand and interact with the new UI

---

## Current State Analysis

### Files Involved

```
src/adapters/inbound/shared/ui/
├── mascot.gd          # Current 2D draw-based implementation
├── mascot.tscn        # Mascot scene
├── voice_assistant_overlay.gd
├── onboarding_overlay.gd
└── ...

data/models/quaternius/
└── ninja.glb          # Available 3D ninja model (457KB)

.importer/imported/
└── ninja.glb-*        # Imported Godot resources
```

### Current Mascot Implementation (`mascot.gd`)

**Key Issues:**
1. **2D Primitives**: Uses `_draw()` with `draw_circle()`, `draw_rect()`, `draw_line()`
2. **Hardcoded Strings**: Polish greetings bypass localization (`_t()`)
3. **Legacy Methods**: `_draw_ear()` is a no-op (ninja has no ears)
4. **Mixed Concerns**: Combines presentation and behavior logic
5. **Visual Quality**: Flat 2D circles don't match the visual rescue gate requirements

**Current Code Structure:**
```gdscript
# From mascot.gd
extends Control
func _draw() -> void:
    # Draw ninja using primitives
    draw_rect(Rect2(Vector2(32, 110), Vector2(96, 90)), HOOD_COLOR, true)
    draw_circle(Vector2(80, 110), 48, HOOD_COLOR)
    draw_circle(Vector2(80, 64), 48, HOOD_COLOR)
    # ... more primitive drawing
```

### Available 3D Asset

**`ninja.glb` (Quaternius)**:
- Size: 457KB (GLB format)
- Location: `data/models/quaternius/ninja.glb`
- Status: Already imported into Godot
- Potential: Full 3D model that can replace 2D primitives
- Note: May need scale adjustment for UI context

---

## Legacy Ninja Overlay Architecture

### Current Node Tree

```
Mascot (Control)
├── _speech_panel (PanelContainer)
│   └── _speech_label (Label)
└── [Visual: _draw() primitives]
```

### Problems with Current Approach

| Issue | Impact | Severity |
|-------|--------|----------|
| `_draw()` primitives | Non-scalable, flat visuals | HIGH |
| Hardcoded Polish strings | Breaks localization | HIGH |
| No proper theming | Inconsistent with UI system | HIGH |
| Mixed concerns | Hard to maintain | MEDIUM |
| Legacy greeting | Violates PLAN.md | HIGH |
| 2D only | Doesn't leverage 3D assets | MEDIUM |

### Dependencies

**Files that reference Mascot:**
- `create_shell.gd`: Creates and manages mascot instance
- `test_mascot.gd`: Tests mascot functionality
- Various shell scenes that include mascot

---

## Removal Strategy

### Step 1: Backup Current Implementation

```bash
# Create backup of current mascot
cp src/adapters/inbound/shared/ui/mascot.gd src/adapters/inbound/shared/ui/mascot.gd.backup
cp src/adapters/inbound/shared/ui/mascot.tscn src/adapters/inbound/shared/ui/mascot.tscn.backup
```

### Step 2: Identify All Mascot References

```bash
# Find all references to mascot
rg -l "mascot|Mascot" src/ tests/ --type gd

# Find references to the legacy greeting
rg "Cześć, jestem twoim ninja" .
```

### Step 3: Gradual Replacement Approach

**Option A: Incremental Replacement (Recommended)**
1. Create new `mascot_modern.gd` with proper node-based implementation
2. Test new implementation in isolation
3. Replace references one by one
4. Remove old `mascot.gd` when all references are updated

**Option B: Direct Replacement**
1. Modify `mascot.gd` in place
2. Replace `_draw()` with proper nodes
3. Fix all issues at once

**Recommendation**: Use **Option A** for safer migration with rollback capability.

### Step 4: Cleanup Legacy Code

After replacement:
1. Remove `mascot.gd.backup` and `mascot.tscn.backup`
2. Remove any dead code in related files
3. Remove unused imports
4. Remove old configuration options

---

## Modern UI Replacement Architecture

### Recommended Architecture

```
Root (Node3D/Control)
└── CanvasLayer (Layer: 100 - HUD Layer)
    ├── HUD (Control)
    │   ├── HealthBar (TextureProgressBar)
    │   ├── ScoreDisplay (Label)
    │   ├── Inventory (HBoxContainer)
    │   │   └── ItemSlots (multiple)
    │   └── InteractionPrompt (Label)
    └── MascotContainer (Control)
        ├── Mascot3D (SubViewport + Camera3D + Ninja model)
        │   └── Ninja (MeshInstance3D)
        └── SpeechBubble (PanelContainer)
            ├── Background (StyleBoxFlat)
            └── Text (Label)
```

### Why This Architecture?

1. **Separation of Concerns**: Mascot is separate from game HUD
2. **Scalability**: Easy to add/remove HUD elements
3. **Maintainability**: Each component is self-contained
4. **Performance**: CanvasLayer ensures proper rendering order
5. **Child-Friendly**: Clear visual hierarchy

### Layer System

| Layer | Purpose | Z-Index |
|-------|---------|---------|
| 0 | Game World | - |
| 1 | World UI (3D interactions) | - |
| 100 | HUD | Topmost |
| 101 | Mascot | Above HUD |
| 102 | Overlays (pause, menus) | Highest |

---

## Modern Mascot System (3D or Sprite-Based)

### Option 1: 3D Mascot with SubViewport (Recommended)

**Architecture:**
```
MascotContainer (Control)
└── MascotViewport (SubViewport)
    ├── Camera3D (orthographic)
    └── NinjaScene (Node3D)
        └── Ninja (MeshInstance3D)
            └── ninja.glb (imported)
```

**Pros:**
- ✅ Uses existing 3D asset
- ✅ Consistent with game's 3D aesthetic
- ✅ Can animate properly (idle, wave, etc.)
- ✅ Professional appearance

**Cons:**
- ⚠️ Slightly more complex setup
- ⚠️ Performance overhead (minimal for single model)

### Option 2: Sprite-Based Mascot

**Architecture:**
```
MascotContainer (Control)
└── MascotSprite (Sprite2D/AnimatedSprite2D)
    └── ninja_sprite.png (rendered from 3D)
```

**Pros:**
- ✅ Very performant
- ✅ Simple implementation
- ✅ Works well for UI

**Cons:**
- ⚠️ Requires baking 3D model to sprites
- ⚠️ Limited animation flexibility

### Option 3: Hybrid Approach (Recommended for Choyce)

Use **3D SubViewport** for the mascot, but with optimizations:
- Small viewport size (160x220 to match current)
- Orthographic camera for consistent scaling
- Simplified lighting (no shadows needed)
- Baked animations

---

## Clean HUD Design Principles

### For Children (Target Audience: 5-8 years)

**DO:**
- ✅ Use large, clear icons and text
- ✅ Consistent placement (bottom-left for mascot is good)
- ✅ Bright, friendly colors
- ✅ Minimal text (use icons where possible)
- ✅ Clear visual hierarchy
- ✅ Forgiving hit areas for touch/click

**DON'T:**
- ❌ Cluttered layouts
- ❌ Small text
- ❌ Complex animations
- ❌ Unclear affordances
- ❌ Overlapping elements

### HUD Component Guidelines

| Component | Size | Position | Visibility |
|-----------|------|----------|------------|
| Mascot | 160x220px | Bottom-left | Always |
| Health | 200x20px | Top-left | On damage |
| Score | Auto | Top-center | Always |
| Inventory | Auto | Bottom-center | On hover |
| Interaction | Auto | Center | On target |

### Color Palette (Child-Friendly)

```gdscript
# Recommended colors for new HUD
const HUD_BG := Color(0.95, 0.95, 0.98, 0.9)  # Light blue-white
const HUD_TEXT := Color(0.15, 0.15, 0.20, 1.0)  # Dark slate
const HUD_ACCENT := Color(0.20, 0.50, 0.80, 1.0)  # Friendly blue
const HUD_WARNING := Color(0.90, 0.40, 0.30, 1.0)  # Soft orange
const HUD_SUCCESS := Color(0.20, 0.70, 0.40, 1.0)  # Soft green
```

---

## Modern UI Component Library

### Essential Control Nodes

| Node | Purpose | Best Practice |
|------|---------|---------------|
| `CanvasLayer` | UI layer | One per UI layer |
| `Control` | Base UI element | Use for containers |
| `PanelContainer` | Background panel | Use StyleBoxFlat |
| `Label` | Text display | Use themes for consistency |
| `TextureProgressBar` | Health/energy | Smooth transitions |
| `HBoxContainer` | Horizontal layout | Use margins and spacing |
| `VBoxContainer` | Vertical layout | Use margins and spacing |
| `MarginContainer` | Padding | Wrap content |
| `TextureRect` | Image display | Use texture filtering |
| `AnimatedSprite2D` | 2D animations | Preload frames |
| `SubViewport` | 3D in UI | Orthographic camera |

### Recommended Container Hierarchy

```gdscript
# HUD scene structure
hud_scene.tscn:
- CanvasLayer (layer: 100)
  - HBoxContainer (Full Rect)
    - MarginContainer (left, for mascot)
      - Mascot (your implementation)
    - CenterContainer (center, for main HUD)
      - VBoxContainer
        - ScoreLabel
        - HealthBar
    - MarginContainer (right, for menu buttons)
      - PauseButton
      - SettingsButton
```

---

## Godot Control Nodes Best Practices

### General Principles

1. **Use Containers**: Always use containers (HBox, VBox, Margin) for layout
2. **Anchors and Margins**: Use anchors for responsive design
3. **Theming**: Use themes instead of hardcoded colors
4. **Signals**: Use signals for communication, not direct references
5. **Mouse Filter**: Set `mouse_filter = MOUSE_FILTER_IGNORE` on non-interactive elements

### Specific Best Practices

**For PanelContainer:**
```gdscript
# Apply theme overrides
panel_container.add_theme_color_override("font_color", Color(0.18, 0.18, 0.18))
panel_container.add_theme_font_size_override("font_size", 22)
panel_container.add_theme_stylebox_override("panel", stylebox_flat)
```

**For Label:**
```gdscript
label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
label.clip_text = true
label.align = HORIZONTAL_ALIGNMENT_CENTER
label.valign = VERTICAL_ALIGNMENT_CENTER
```

**For TextureProgressBar:**
```gdscript
progress_bar.min_value = 0
progress_bar.max_value = 100
progress_bar.value = 75
progress_bar.tint_progress = Color.GREEN
progress_bar.tint_over = Color.DARK_GREEN
progress_bar.tint_under = Color.LIGHT_GREEN
```

### Anchor Presets

| Position | Anchor Preset | Use Case |
|----------|---------------|----------|
| Top-left | `ANCHOR_BEGIN_BEGIN` | Health bar |
| Top-center | `ANCHOR_BEGIN_END` | Score |
| Top-right | `ANCHOR_END_BEGIN` | Mini-map |
| Center | `ANCHOR_CENTER` | Interaction prompt |
| Bottom-left | `ANCHOR_END_BEGIN` | Mascot |
| Bottom-center | `ANCHOR_END_MIDDLE` | Inventory |
| Bottom-right | `ANCHOR_END_END` | Chat/Log |

---

## Theme System & Styling

### Creating a Theme

**Step 1: Create Theme Resource**
```gdscript
# theme_generator.gd
func create_hud_theme() -> Theme:
    var theme := Theme.new()
    
    # Label defaults
    theme.set_font("font", "res://assets/fonts/main.ttf")
    theme.set_font_size("font_size", 20)
    theme.set_color("font_color", Color(0.15, 0.15, 0.20))
    theme.set_color("font_outline_color", Color.WHITE)
    theme.set_int("font_outline_size", 2)
    
    # Panel defaults
    var stylebox := StyleBoxFlat.new()
    stylebox.bg_color = Color(0.95, 0.95, 0.98, 0.9)
    stylebox.border_color = Color(0.7, 0.7, 0.8)
    stylebox.border_width_left = 2
    stylebox.border_width_top = 2
    stylebox.border_width_right = 2
    stylebox.border_width_bottom = 2
    stylebox.corner_radius_top_left = 8
    stylebox.corner_radius_top_right = 8
    stylebox.corner_radius_bottom_left = 8
    stylebox.corner_radius_bottom_right = 8
    theme.set_stylebox("panel", stylebox)
    
    # Button defaults
    var button_normal := StyleBoxFlat.new()
    button_normal.bg_color = Color(0.20, 0.50, 0.80)
    var button_hover := StyleBoxFlat.new()
    button_hover.bg_color = Color(0.30, 0.60, 0.90)
    var button_pressed := StyleBoxFlat.new()
    button_pressed.bg_color = Color(0.10, 0.40, 0.70)
    theme.set_stylebox("normal", button_normal)
    theme.set_stylebox("hover", button_hover)
    theme.set_stylebox("pressed", button_pressed)
    
    return theme
```

**Step 2: Apply Theme**
```gdscript
# In your HUD scene _ready()
func _ready() -> void:
    var theme := load("res://themes/hud_theme.tres")
    add_theme(theme)
    
    # Or apply to specific control
    $PanelContainer.add_theme(theme)
```

### Theme Inheritance

```gdscript
# Create child theme that extends parent
func create_child_theme(parent_theme: Theme) -> Theme:
    var child_theme := Theme.new()
    child_theme.set_parent(parent_theme)
    
    # Override specific properties
    child_theme.set_color("font_color", Color.RED)
    
    return child_theme
```

---

## Accessibility Considerations

### Reduce Motion Support

```gdscript
# In project.godot
[input]
; Add reduce_motion action

# In code
func _ready() -> void:
    if ProjectSettings.get("input/reduce_motion"):
        disable_animations()

func disable_animations() -> void:
    # Disable all Tweens
    for child in get_children():
        if child is Tween:
            child.pause()
    
    # Use static positions instead of animated
    $Mascot.position = Vector2(80, 180)  # Static position
```

### Color Blindness Support

```gdscript
# Color blind friendly palette
const COLORBLIND_SAFE := {
    "red": Color(0.8, 0.2, 0.2),
    "green": Color(0.2, 0.8, 0.2),
    "blue": Color(0.2, 0.2, 0.8),
    "yellow": Color(0.8, 0.8, 0.2),
    "purple": Color(0.6, 0.2, 0.8)
}

# High contrast mode
const HIGH_CONTRAST := {
    "bg": Color.BLACK,
    "text": Color.WHITE,
    "border": Color.WHITE,
    "accent": Color.YELLOW
}
```

### Scalable UI

```gdscript
# Scale UI based on screen size
func _ready() -> void:
    var screen_size := get_viewport_rect().size
    var scale_factor := min(screen_size.x / 1920, screen_size.y / 1080)
    
    if scale_factor < 0.8:
        # Small screen - increase UI scale
        scale = Vector2(1.2, 1.2)
    elif scale_factor > 1.2:
        # Large screen - decrease UI scale
        scale = Vector2(0.8, 0.8)
```

---

## Code Samples & Implementation Patterns

### Option 1: 3D Mascot with SubViewport

```gdscript
# mascot_modern_3d.gd
extends Control

class_name MascotModern

@export var event_bus: Variant
@export var voice_prompt: Variant

@onready var speech_panel: PanelContainer
@onready var speech_label: Label
@onready var viewport_container: SubViewportContainer
@onready var ninja_scene: Node3D

const IDLE_SCALE := Vector3(0.15, 0.15, 0.15)  # Scale down for UI
const WIGGLE_AMOUNT := 0.05

func _ready() -> void:
    custom_minimum_size = Vector2(160, 220)
    pivot_offset = Vector2(80, 180)
    mouse_filter = MOUSE_FILTER_IGNORE
    
    _setup_viewport()
    _build_speech_bubble()
    _start_idle_wiggle()
    
    if event_bus and event_bus.has_method("subscribe_all"):
        event_bus.subscribe_all(Callable(self, "_on_domain_event"))

func _setup_viewport() -> void:
    # Configure SubViewport
    viewport_container.size = Vector2(160, 220)
    
    # Setup camera (orthographic for consistent scaling)
    var camera := viewport_container.get_child(0).get_child(0) as Camera3D
    if camera:
        camera.projection = Camera3D.PROJECTION_ORTHOGRAPHIC
        camera.fov = 0.0  # Not used in orthographic
        camera.size = 2.0  # Viewport size in world units
        camera.position = Vector3(0, 0, 5)  # Distance from ninja
        camera.look_at(Vector3(0, 0, 0))
    
    # Load and position ninja
    var ninja_mesh := preload("res://.godot/imported/ninja.glb-d2c5e26523e1cd1199d21ebae0cd70eb.scn")
    if ninja_mesh:
        ninja_scene.add_child(ninja_mesh.instantiate())
        ninja_scene.scale = IDLE_SCALE
        ninja_scene.position.y = -1.0  # Adjust vertical position

func _build_speech_bubble() -> void:
    speech_panel = PanelContainer.new()
    speech_panel.position = Vector2(120, 0)
    speech_panel.modulate.a = 0.0
    speech_panel.mouse_filter = MOUSE_FILTER_IGNORE
    
    # Apply theme
    var stylebox := StyleBoxFlat.new()
    stylebox.bg_color = Color(0.95, 0.95, 0.98, 0.95)
    stylebox.border_color = Color(0.7, 0.7, 0.8)
    stylebox.corner_radius_all = 12
    speech_panel.add_theme_stylebox_override("panel", stylebox)
    
    var label := Label.new()
    label.add_theme_font_size_override("font_size", 22)
    label.add_theme_color_override("font_color", Color(0.15, 0.15, 0.20))
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    label.custom_minimum_size = Vector2(140, 0)
    label.text = ""
    speech_label = label
    speech_panel.add_child(label)
    add_child(speech_panel)

func _start_idle_wiggle() -> void:
    var tween := create_tween()
    tween.set_loops()
    tween.tween_property(ninja_scene, "scale:x", IDLE_SCALE.x * (1.0 + WIGGLE_AMOUNT), 2.0)
    tween.tween_property(ninja_scene, "scale:x", IDLE_SCALE.x * (1.0 - WIGGLE_AMOUNT), 2.0)
    tween.set_trans(Tween.TRANS_SINE)

func say(text: String, duration := 3.0) -> void:
    speech_label.text = text
    speech_panel.modulate.a = 1.0
    
    # Auto-hide after duration
    if duration > 0:
        var timer := get_tree().create_timer(duration)
        timer.timeout.connect(_hide_speech_bubble.bind(speech_panel))

func _hide_speech_bubble(panel: PanelContainer) -> void:
    panel.modulate.a = 0.0

func _on_domain_event(event: Variant) -> void:
    # Handle domain events (combat, exploration, etc.)
    match event.type:
        DomainEventType.COMBAT_STARTED:
            _show_excited_state()
        DomainEventType.EXPLORATION_STARTED:
            _show_idle_state()
        DomainEventType.QUEST_COMPLETED:
            say(_t("mascot.cheer.quest_completed"))
        _:
            pass
```

**Corresponding Scene (`mascot_modern_3d.tscn`):**
```
Node (MascotModern)
├── SubViewportContainer
│   └── SubViewport
│       └── Camera3D
└── Node3D (ninja_scene)
```

### Option 2: Sprite-Based Mascot (Simpler)

```gdscript
# mascot_modern_sprite.gd
extends Control

class_name MascotModern

@export var event_bus: Variant
@export var voice_prompt: Variant

@onready var speech_panel: PanelContainer
@onready var speech_label: Label
@onready var mascot_sprite: AnimatedSprite2D

func _ready() -> void:
    custom_minimum_size = Vector2(160, 220)
    pivot_offset = Vector2(80, 180)
    mouse_filter = MOUSE_FILTER_IGNORE
    
    _build_speech_bubble()
    _setup_sprite()
    _start_idle_animation()
    
    if event_bus and event_bus.has_method("subscribe_all"):
        event_bus.subscribe_all(Callable(self, "_on_domain_event"))

func _setup_sprite() -> void:
    mascot_sprite = AnimatedSprite2D.new()
    mascot_sprite.position = Vector2(80, 110)
    
    # Load sprite sheets (pre-rendered from 3D model)
    var sprite_sheet := preload("res://assets/ui/mascot/ninja_spritesheet.tres")
    mascot_sprite.sprite_frames = sprite_sheet
    
    # Add animations
    mascot_sprite.play("idle")
    
    add_child(mascot_sprite)

func _start_idle_animation() -> void:
    # Sprite already plays idle animation
    pass

# ... rest of implementation same as 3D version
```

### HUD Manager Implementation

```gdscript
# hud_manager.gd
extends CanvasLayer

# HUD Components
@onready var health_bar: TextureProgressBar
@onready var score_label: Label
@onready var interaction_label: Label
@onready var mascot_container: Control

# Configuration
@export var show_health_on_full: bool = false
@export var auto_hide_interaction: float = 2.0  # Seconds before hiding

var _interaction_timer: SceneTreeTimer

func _ready() -> void:
    # Initialize HUD
    health_bar.max_value = 100
    health_bar.value = 100
    update_score(0)
    hide_interaction()
    
    # Setup mascot
    _setup_mascot()

func _setup_mascot() -> void:
    var mascot_scene := preload("res://src/adapters/inbound/shared/ui/mascot_modern_3d.tscn")
    var mascot := mascot_scene.instantiate()
    mascot_container.add_child(mascot)
    
    # Position mascot
    mascot.anchor_right = 0.0
    mascot.anchor_bottom = 1.0
    mascot.position = Vector2(20, -20)

func update_health(value: float) -> void:
    health_bar.value = value
    
    # Show health bar when not full (optional)
    if show_health_on_full:
        health_bar.visible = value < health_bar.max_value
    else:
        health_bar.visible = true

func update_score(value: int) -> void:
    score_label.text = str(value)

func show_interaction(text: String) -> void:
    interaction_label.text = text
    interaction_label.visible = true
    
    # Auto-hide
    if _interaction_timer:
        _interaction_timer.timeout.disconnect(_hide_interaction)
    
    _interaction_timer = get_tree().create_timer(auto_hide_interaction)
    _interaction_timer.timeout.connect(_hide_interaction)

func _hide_interaction() -> void:
    interaction_label.visible = false

func set_mascot_state(state: String) -> void:
    mascot_container.get_child(0).set_state(state)

func make_mascot_speak(text: String) -> void:
    mascot_container.get_child(0).say(text)
```

### Migration Script (From Old to New)

```gdscript
# migrate_mascot.gd - Run once to migrate

func migrate() -> void:
    print("Starting mascot migration...")
    
    # Step 1: Create new mascot scene
    _create_new_mascot_scene()
    
    # Step 2: Update references in create_shell.gd
    _update_create_shell()
    
    # Step 3: Update test files
    _update_test_files()
    
    # Step 4: Remove legacy greeting
    _remove_legacy_greeting()
    
    print("Mascot migration complete!")

func _create_new_mascot_scene() -> void:
    # Create new mascot scene file
    var new_mascot_code := """
    # [Content of mascot_modern_3d.gd]
    """
    
    # Write to file
    var file := FileAccess.open("res://src/adapters/inbound/shared/ui/mascot_modern_3d.gd", FileAccess.WRITE)
    file.store_string(new_mascot_code)
    file.close()

func _update_create_shell() -> void:
    # Read create_shell.gd
    var file := FileAccess.open("res://src/adapters/inbound/scenes/create/create_shell.gd", FileAccess.READ)
    var content := file.get_as_text()
    file.close()
    
    # Replace old mascot references
    content = content.replace(
        'preload("res://src/adapters/inbound/shared/ui/mascot.tscn")',
        'preload("res://src/adapters/inbound/shared/ui/mascot_modern_3d.tscn")'
    )
    content = content.replace(
        'Mascot.new()',
        'MascotModern.new()'
    )
    
    # Write back
    file = FileAccess.open("res://src/adapters/inbound/scenes/create/create_shell.gd", FileAccess.WRITE)
    file.store_string(content)
    file.close()

func _remove_legacy_greeting() -> void:
    # Find and remove the greeting from all files
    var files := [
        "res://src/adapters/inbound/scenes/create/create_shell.gd",
        "res://src/adapters/inbound/main.gd"
    ]
    
    for file_path in files:
        if FileAccess.file_exists(file_path):
            var file := FileAccess.open(file_path, FileAccess.READ)
            var content := file.get_as_text()
            file.close()
            
            # Remove the greeting
            content = content.replace("Cześć, jestem twoim ninja", "")
            content = content.replace('"Cześć, jestem twoim ninja"', '""')
            
            file = FileAccess.open(file_path, FileAccess.WRITE)
            file.store_string(content)
            file.close()
```

---

## Testing & Validation Checklist

### Functional Tests

- [ ] New mascot scene loads without errors
- [ ] Mascot renders correctly (no missing textures)
- [ ] Mascot animations play (idle, excited, etc.)
- [ ] Speech bubble appears when mascot speaks
- [ ] Speech bubble auto-hides after timeout
- [ ] Mascot reacts to domain events
- [ ] HUD elements render correctly
- [ ] Health bar updates properly
- [ ] Score display updates
- [ ] Interaction prompts appear and disappear

### Visual Tests

- [ ] Mascot looks good at all screen sizes
- [ ] Mascot scales properly
- [ ] No visual glitches or artifacts
- [ ] Colors match the new art direction
- [ ] HUD is readable on all backgrounds
- [ ] No overlapping UI elements
- [ ] Speech bubble is properly styled

### Migration Tests

- [ ] All old mascot references are updated
- [ ] No `_draw()` calls remain in mascot code
- [ ] Legacy greeting is removed from all files
- [ ] Tests pass with new implementation
- [ ] No runtime errors
- [ ] Performance is acceptable

### Child-Safety Tests

- [ ] Mascot is visible and recognizable
- [ ] Mascot doesn't block important UI
- [ ] Speech is clear and readable
- [ ] Animations are smooth, not distracting
- [ ] UI is intuitive for children
- [ ] Touch/click targets are large enough

### Accessibility Tests

- [ ] Mascot works with reduce-motion setting
- [ ] UI scales with screen size
- [ ] Colors are accessible
- [ ] Text is readable
- [ ] No reliance on color alone for information

### Performance Tests

- [ ] No frame drops with mascot visible
- [ ] Memory usage is stable
- [ ] Loading times are acceptable
- [ ] Multiple mascot instances don't cause issues

---

## Learning Resources

### Official Godot Documentation

- [Control Nodes](https://docs.godotengine.org/en/stable/classes/class_control.html) - Base UI class
- [CanvasLayer](https://docs.godotengine.org/en/stable/classes/class_canvaslayer.html) - UI layer system
- [SubViewport](https://docs.godotengine.org/en/stable/classes/class_subviewport.html) - 3D in UI
- [Container Controls](https://docs.godotengine.org/en/stable/tutorials/ui/index.html) - UI layout
- [Theme System](https://docs.godotengine.org/en/stable/tutorials/ui/theming/index.html) - Styling UI

### Tutorials and Guides

- [GDQuest: UI System in Godot 4](https://www.gdquest.com/tutorial/godot/ui/) - Comprehensive UI tutorial
- [GDQuest: Heads Up Display](https://www.gdquest.com/tutorial/godot/2d/hud/) - HUD implementation
- [Godot Docs: First 2D Game - HUD](https://docs.godotengine.org/en/stable/getting_started/first_2d_game/06.heads_up_display.html) - Basic HUD
- [SubViewport Tutorial](https://www.gdquest.com/tutorial/godot/3d/subviewport/) - 3D in UI

### Community Resources

- [r/godot - UI Questions](https://www.reddit.com/r/godot/search/?q=ui) - UI discussions
- [Godot Forum - UI Section](https://forum.godotengine.org/c/ui/15) - Official UI forum
- [UI Best Practices](https://forum.godotengine.org/t/ui-nodes-good-practice/77720) - Community advice

### Asset Sources

- [Kenney UI Packs](https://kenney.nl/assets?category=UI) - Free UI assets
- [Quaternius 3D Models](https://quaternius.com/) - 3D models (including ninja)
- [OpenGameArt UI](https://opengameart.org/) - Free UI assets

### Tools

- [Godot Theme Generator](https://github.com/Calinou/godot-theme-generator) - Generate themes
- [GDQuest UI Framework](https://github.com/GDQuest/godot-ui-framework) - UI utilities

---

## Summary

This research compendium provides a comprehensive guide to **removing the legacy Ninja overlay** and implementing a **modern UI system** in Godot 4.x for the Choyce Engine.

**Key Actions:**

1. **Replace 2D primitives** in `mascot.gd` with proper 3D SubViewport or Sprite2D implementation
2. **Use existing `ninja.glb`** model from Quaternius
3. **Implement clean HUD** with proper Control nodes and theming
4. **Remove legacy greeting** "Cześć, jestem twoim ninja" from all files
5. **Ensure child-safety** with intuitive, clear UI
6. **Test thoroughly** across all devices and screen sizes

**Recommended Implementation:**
- Use **3D SubViewport** for the mascot to leverage existing 3D asset
- Create **modular HUD** with separate components
- Apply **consistent theming** across all UI elements
- Follow **accessibility best practices**

This work integrates with:
- PLAN-012 (Continuous Exploration Music) - for audio in new UI
- PLAN-014 (Audio Bus Architecture) - for proper audio routing
- VS-014 (Modern Game UI) - for overall UI modernization

---

*Generated for Choyce Engine - PLAN-013 Legacy Ninja Overlay Removal*
*Last updated: 2026-07-18*
