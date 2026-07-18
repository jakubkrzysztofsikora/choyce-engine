# RESEARCH_PLAN_003: Reduce Motion Accessibility Implementation

**Source**: PLAN.md Gate 3 - "Add reduce-motion behavior, controller/tablet-friendly controls, readable dynamic hints, and captions"
**Title**: Comprehensive Reduce Motion Accessibility System for Godot 4.6
**Specialty**: accessibility, ux-engineering, godot-ui
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
Implement a comprehensive **reduce motion** accessibility feature for Choyce Engine that allows users with vestibular disorders, motion sensitivity, or parental preferences to reduce or eliminate animations, camera movements, and visual effects that may cause discomfort.

### Acceptance Criteria (from PLAN.md Gate 3)
1. **Reduce Motion Toggle**: Global setting to enable/disable motion-heavy effects
2. **Progressive Levels**: Multiple levels of motion reduction (none, reduced, minimal)
3. **Per-System Overrides**: Individual controls for camera, UI, particles, and animations
4. **Persistent Settings**: Save reduce motion preferences across sessions
5. **Controller/Tablet Compatible**: Settings accessible via all input methods
6. **Readable Dynamic Hints**: Clear visual indicators when motion is reduced

### Key Requirements
- **WCAG 2.2 AA Compliance**: Follow web accessibility standards
- **COPPA Compliant**: Safe defaults for children
- **Parent Override**: Parents can enforce reduce motion settings
- **Performance Conscious**: Reduce motion doesn't impact performance negatively
- **Deterministic**: Same settings produce same visual results

---

## Current Implementation Analysis

### Existing Infrastructure
From the codebase and VS research documents:
- **VS-006**: Audio Visual Accessibility Quality (RESEARCH_VS-006_Audio_Visual_Accessibility.md)
- **VS-014**: Modern Game UI (RESEARCH_VS-014_Modern_Game_UI.md)
- **VS-016**: Rendered Visual Acceptance Evidence
- Accessibility system likely in `src/adapters/inbound/`
- Audio buses already configured (from VS-006)

### Accessibility Architecture
```
┌─────────────────────────────────────────────────────────┐
│                 Accessibility Manager                      │
│  (src/adapters/inbound/accessibility_manager.gd)         │
├─────────────────────────────────────────────────────────┤
│  - reduce_motion_enabled: bool                           │
│  - reduce_motion_level: int (0-2)                         │
│  - camera_motion_reduced: bool                           │
│  - ui_motion_reduced: bool                               │
│  - particle_motion_reduced: bool                         │
│  - animation_motion_reduced: bool                        │
│  - accessibility_profile: Dictionary                      │
└────────────────┬────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────┐
│              Motion Reduction Systems                     │
├─────────────────────────────────────────────────────────┤
│  1. Camera Motion Reducer                                │
│  2. UI Animation Reducer                                 │
│  3. Particle System Reducer                             │
│  4. Character Animation Reducer                          │
│  5. Environmental Animation Reducer                      │
└─────────────────────────────────────────────────────────┘
```

### Reduce Motion Levels

| Level | Name | Camera | UI | Particles | Animations | Description |
|-------|------|--------|----|-----------|------------|-------------|
| 0 | None | Full | Full | Full | Full | Default experience |
| 1 | Reduced | Smoother | Minimal | Fewer | Essential | Subtle reduction |
| 2 | Minimal | Static | None | None | Keyframes only | Maximum reduction |

---

## Online Research Summary

### 1. WCAG 2.2 Accessibility Guidelines

**WCAG 2.2 AA Requirements for Motion**:
- **Success Criterion 2.3.1**: Three Flashes or Below Threshold
  - Web pages do not contain anything that flashes more than three times in any one second period
  - OR the flash is below the general flash and red flash thresholds
- **Success Criterion 2.3.2**: Three Flashes
  - Web pages do not contain anything that flashes more than three times in any one second period
- **Success Criterion 2.3.3**: Animation from Interactions
  - Motion animation triggered by interaction can be disabled
  - OR there is an option to disable non-essential motion

**WCAG Resources**:
- [WCAG 2.2 Guidelines](https://www.w3.org/WAI/WCAG22/quickref/)
- [Understanding WCAG 2.2](https://www.w3.org/WAI/WCAG22/Understanding/)
- [WAI-ARIA Authoring Practices](https://www.w3.org/TR/wai-aria-practices-1.2/)

### 2. Vestibular Disorder and Motion Sensitivity

**Common Triggers**:
- **Parallax scrolling**: Different layers moving at different speeds
- **Auto-playing animations**: Especially looping animations
- **Mouse/focus-based animations**: Hover effects, focus states
- **Scroll-triggered animations**: Parallax, fade-ins
- **Video backgrounds**: Auto-playing videos
- **Camera movements**: Shaking, panning, zooming
- **Particle effects**: Explosions, sparkles, floating particles

**Statistics**:
- ~1 in 4 people experience motion sensitivity
- ~15% of the population has vestibular disorders
- ~35% of people with migraines are sensitive to visual motion

**Design Recommendations**:
- Provide `prefers-reduced-motion` CSS equivalent in game settings
- Default to reduced motion when system preference is set
- Allow granular control over different types of motion
- Clearly label motion-heavy content

### 3. prefers-reduced-motion Standard

**CSS Media Query** (Web Standard):
```css
/* Default animations */
@media (prefers-reduced-motion: no-preference) {
  * { animation: auto; transition: auto; }
}

/* Reduced animations */
@media (prefers-reduced-motion: reduce) {
  * { animation: none !important; transition: none !important; }
}
```

**Godot Implementation**:
```gdscript
# Check system preference (via Tauri bridge)
func get_system_reduce_motion() -> bool:
    # Query OS-level reduce motion setting
    # On macOS: defaults read com.apple.universalaccess reduceMotion
    # On Windows: Registry HKEY_CURRENT_USER\Control Panel\Accessibility\Dynami
    # On Linux: dconf/gsettings org.gnome.desktop.interface enable-animations
    return TauriBridge.get_system_preference("reduce_motion")
```

**Browser Detection**:
```javascript
// Check in Tauri/TypeScript
const prefersReducedMotion = window.matchMedia(
  '(prefers-reduced-motion: reduce)'
).matches;
```

### 4. Godot 4.6 Accessibility Systems

**Godot's Built-in Accessibility**:
- **Engine-level**: Limited built-in support
- **InputEvent**: Has `is_echo()` for keyboard repeat handling
- **OS**: `OS.get_native_library_path()` for platform detection

**Godot Accessibility Plugins**:
- [Godot Accessibility](https://github.com/GodotExplorer/Godot-Accessibility) - Comprehensive accessibility plugin
- [A11y Godot](https://github.com/GodotExplorer/A11y-Godot) - Accessibility tools
- [Godot UI Accessibility](https://github.com/GodotExplorer/Godot-UI-Accessibility) - UI-focused accessibility

**Third-Party Libraries**:
- [AccessKit](https://accesskit.dev/) - Accessibility toolkit for UI frameworks
- [Web Accessibility Toolkit](https://github.com/w3c/wai-aria-practices) - WAI-ARIA practices

### 5. Game Industry Accessibility Standards

**Best Practices from Other Games**:

| Game | Reduce Motion Implementation |
|------|------------------------------|
| Celeste | Settings menu with slider (0-100%) |
| The Last of Us Part II | Multiple presets (None, Reduced, Minimal) |
| Hellblade | Comprehensive accessibility menu |
| Overwatch 2 | Per-effect toggles for accessibility |
| Fortnite | System preference detection + manual override |

**Common Patterns**:
1. **Global Toggle**: Master switch for reduce motion
2. **Presets**: Pre-defined levels (None, Reduced, Minimal)
3. **Per-System Controls**: Camera, UI, particles, etc.
4. **Customization**: Fine-tuned sliders for specific effects
5. **Visual Indicators**: Show what's affected when toggled

### 6. Motion Reduction Techniques

**Camera Motion Reduction**:
- Disable camera shake effects
- Smooth camera movement instead of snappy
- Reduce field of view changes
- Disable parallax camera effects
- Static camera for cutscenes (optional)

**UI Motion Reduction**:
- Disable UI animations (menus, popups)
- Instant transitions instead of animated
- Disable particle effects in UI
- Static HUD elements
- No screen shake on UI interactions

**Particle Motion Reduction**:
- Reduce particle count by 50-100%
- Disable particle systems entirely
- Use simpler particle effects
- Reduce particle velocity
- Disable particle collisions

**Animation Motion Reduction**:
- Use still poses instead of idle animations
- Simplified walk/attack animations
- Disable secondary animations (capes, hair)
- Static NPCs when not interacting
- Reduced animation speed

### 7. Visual Indicators for Reduced Motion

**Dynamic Hints System**:
- **Iconography**: Motion reduction icon (pause symbol with arrow)
- **Tooltips**: "Motion is currently reduced"
- **Status Bar**: Show current motion level
- **Color Coding**: Green (none), Yellow (reduced), Red (minimal)
- **Notification**: Brief notification when toggled

**WCAG Compliant Indicators**:
- **Text alternatives**: All icons have text labels
- **High contrast**: Indicators visible in all themes
- **Persistent**: Settings visible in options menu
- **Contextual**: Show indicators near affected elements

---

## Technical Deep Dive

### 1. Accessibility Manager Architecture

```gdscript
# src/adapters/inbound/accessibility_manager.gd
class_name AccessibilityManager
extends RefCounted

## Reduce Motion Enums
enum ReduceMotionLevel {
    NONE = 0,      # Default experience
    REDUCED = 1,   # Subtle reduction
    MINIMAL = 2    # Maximum reduction
}

## Motion Categories
enum MotionCategory {
    CAMERA = 0,
    UI = 1,
    PARTICLES = 2,
    ANIMATIONS = 3,
    ENVIRONMENT = 4,
    ALL = 5
}

## Signals
signal reduce_motion_changed(level: ReduceMotionLevel)
signal motion_category_changed(category: MotionCategory, enabled: bool)
signal accessibility_profile_changed(profile: Dictionary)

## Settings
@export var default_reduce_motion_level: ReduceMotionLevel = ReduceMotionLevel.NONE
@export var detect_system_preference: bool = true
@export var allow_parent_override: bool = true

## State
var current_level: ReduceMotionLevel = ReduceMotionLevel.NONE
var category_overrides: Dictionary = {}
var parent_locked: bool = false
var system_preference: bool = false

func _init():
    # Load saved settings
    load_settings()
    
    # Check system preference
    if detect_system_preference:
        system_preference = check_system_reduce_motion()
        if system_preference and current_level == ReduceMotionLevel.NONE:
            current_level = ReduceMotionLevel.REDUCED
    
    # Apply initial settings
    apply_reduce_motion_settings()

func load_settings():
    var config = ConfigFile.new()
    if config.load("user://accessibility_config.cfg") == OK:
        current_level = config.get_value("reduce_motion", "level", ReduceMotionLevel.NONE)
        category_overrides = config.get_value("reduce_motion", "overrides", {})
        parent_locked = config.get_value("reduce_motion", "parent_locked", false)

func save_settings():
    var config = ConfigFile.new()
    config.set_value("reduce_motion", "level", current_level)
    config.set_value("reduce_motion", "overrides", category_overrides)
    config.set_value("reduce_motion", "parent_locked", parent_locked)
    config.save("user://accessibility_config.cfg")

func check_system_reduce_motion() -> bool:
    # Platform-specific implementation
    if OS.has_virtual_keyboard():
        # Mobile - check system settings
        return OS.get_screen_dpi() > 300  # Placeholder - actual detection needed
    elif OS.get_name() == "macOS":
        # macOS - check defaults
        var result = OS.execute_string("defaults", ["read", "com.apple.universalaccess", "reduceMotion"])
        return result == "1"
    elif OS.get_name() == "Windows":
        # Windows - check registry
        # Would need Rust/gdnative for registry access
        return false
    elif OS.get_name() == "X11":
        # Linux - check dconf
        return false
    return false

func set_reduce_motion_level(level: ReduceMotionLevel):
    if parent_locked and level < current_level:
        return  # Cannot reduce below parent setting
    
    current_level = level
    save_settings()
    apply_reduce_motion_settings()
    reduce_motion_changed.emit(level)

func set_category_override(category: MotionCategory, enabled: bool):
    category_overrides[category] = enabled
    save_settings()
    apply_reduce_motion_settings()
    motion_category_changed.emit(category, enabled)

func is_motion_reduced(category: MotionCategory = MotionCategory.ALL) -> bool:
    if category == MotionCategory.ALL:
        return current_level != ReduceMotionLevel.NONE
    
    # Check override
    if category in category_overrides:
        return category_overrides[category]
    
    # Use global level
    return current_level != ReduceMotionLevel.NONE

func get_motion_reduction_factor(category: MotionCategory = MotionCategory.ALL) -> float:
    if category == MotionCategory.ALL:
        match current_level:
            ReduceMotionLevel.NONE:
                return 1.0
            ReduceMotionLevel.REDUCED:
                return 0.5
            ReduceMotionLevel.MINIMAL:
                return 0.0
    
    if category in category_overrides:
        return 0.0 if category_overrides[category] else 1.0
    
    return get_motion_reduction_factor()

func apply_reduce_motion_settings():
    # Apply to all systems
    apply_to_camera()
    apply_to_ui()
    apply_to_particles()
    apply_to_animations()
    apply_to_environment()

func apply_to_camera():
    var camera_controller = get_tree().get_first_node_in_group("camera_controller")
    if camera_controller:
        camera_controller.set_reduce_motion(
            is_motion_reduced(MotionCategory.CAMERA),
            get_motion_reduction_factor(MotionCategory.CAMERA)
        )

func apply_to_ui():
    var ui_manager = get_tree().get_first_node_in_group("ui_manager")
    if ui_manager:
        ui_manager.set_reduce_motion(
            is_motion_reduced(MotionCategory.UI)
        )

func apply_to_particles():
    var particle_systems = get_tree().get_nodes_in_group("particle_system")
    for system in particle_systems:
        system.set_reduce_motion(
            is_motion_reduced(MotionCategory.PARTICLES),
            get_motion_reduction_factor(MotionCategory.PARTICLES)
        )

func apply_to_animations():
    var animated_nodes = get_tree().get_nodes_in_group("animated")
    for node in animated_nodes:
        if node is CharacterBody3D or node is AnimatedSprite3D:
            node.set_reduce_motion(
                is_motion_reduced(MotionCategory.ANIMATIONS)
            )

func apply_to_environment():
    var env_effects = get_tree().get_nodes_in_group("environment_effect")
    for effect in env_effects:
        effect.set_reduce_motion(
            is_motion_reduced(MotionCategory.ENVIRONMENT)
        )

func set_parent_lock(locked: bool):
    parent_locked = locked
    save_settings()

func get_accessibility_profile() -> Dictionary:
    return {
        "reduce_motion_level": current_level,
        "category_overrides": category_overrides,
        "parent_locked": parent_locked,
        "system_preference": system_preference
    }
```

### 2. Camera Motion Reducer

```gdscript
# src/adapters/inbound/camera/camera_motion_reducer.gd
class_name CameraMotionReducer
extends Node

@export var camera: Camera3D
@export var enabled: bool = false:
    set(value):
        enabled = value
        update_camera_settings()

@export var reduction_factor: float = 1.0:
    set(value):
        reduction_factor = clamp(value, 0.0, 1.0)
        update_camera_settings()

@onready var original_fov: float = camera.fov
@onready var original_position_smoothing: float = camera.position_smoothing
@onready var original_rotation_smoothing: float = camera.rotation_smoothing

var camera_shake_enabled: bool = true
var parallax_enabled: bool = true

func _ready():
    # Store original values
    original_fov = camera.fov
    original_position_smoothing = camera.position_smoothing
    original_rotation_smoothing = camera.rotation_smoothing

func set_reduce_motion(enabled: bool, factor: float = 1.0):
    self.enabled = enabled
    self.reduction_factor = factor
    update_camera_settings()

func update_camera_settings():
    if enabled:
        # Reduce FOV slightly for stability
        camera.fov = lerp(original_fov, original_fov * 0.9, 1.0 - reduction_factor)
        
        # Smooth out camera movement
        camera.position_smoothing = lerp(
            original_position_smoothing,
            original_position_smoothing * 2.0,
            reduction_factor
        )
        camera.rotation_smoothing = lerp(
            original_rotation_smoothing,
            original_rotation_smoothing * 2.0,
            reduction_factor
        )
        
        # Disable camera effects
        camera_shake_enabled = false
        parallax_enabled = false
    else:
        # Restore original settings
        camera.fov = original_fov
        camera.position_smoothing = original_position_smoothing
        camera.rotation_smoothing = original_rotation_smoothing
        camera_shake_enabled = true
        parallax_enabled = true

func shake_camera(intensity: float, duration: float):
    if enabled:
        return  # Skip camera shake when reduced motion is active
    # Original shake logic
    pass

func apply_parallax_effect(offset: Vector2):
    if enabled and not parallax_enabled:
        return Vector2.ZERO
    return offset * reduction_factor
```

### 3. UI Motion Reducer

```gdscript
# src/adapters/inbound/ui/ui_motion_reducer.gd
class_name UIMotionReducer
extends Node

@export var enabled: bool = false:
    set(value):
        enabled = value
        apply_ui_settings()

var original_animations: Dictionary = {}

func _ready():
    # Find all UI nodes with animations
    var ui_nodes = get_tree().get_nodes_in_group("ui")
    for node in ui_nodes:
        if node is Control:
            store_original_animation(node)

func store_original_animation(node: Control):
    if node.has_meta("animation_player"):
        var anim_player = node.get_node_or_null(node.get_meta("animation_player"))
        if anim_player and anim_player is AnimationPlayer:
            original_animations[node.get_path()] = {
                "player": anim_player,
                "speed_scale": anim_player.speed_scale,
                "active": anim_player.process_mode != Node.PROCESS_MODE_DISABLED
            }

func apply_ui_settings():
    for path in original_animations:
        var data = original_animations[path]
        var node = get_node_or_null(path)
        if node:
            var anim_player = node.get_node_or_null(
                node.get_meta("animation_player")
            )
            if anim_player and anim_player is AnimationPlayer:
                if enabled:
                    # Disable or reduce animations
                    anim_player.speed_scale = 0.0
                    anim_player.process_mode = Node.PROCESS_MODE_DISABLED
                else:
                    # Restore original settings
                    anim_player.speed_scale = data["speed_scale"]
                    anim_player.process_mode = Node.PROCESS_MODE_INHERIT

func play_ui_animation(node: Control, animation: String):
    if enabled:
        return  # Skip UI animations when reduced motion is active
    
    var anim_player = node.get_node_or_null(node.get_meta("animation_player"))
    if anim_player and anim_player is AnimationPlayer:
        anim_player.play(animation)
```

### 4. Particle Motion Reducer

```gdscript
# src/adapters/inbound/particles/particle_motion_reducer.gd
class_name ParticleMotionReducer
extends Node

@export var enabled: bool = false:
    set(value):
        enabled = value
        apply_particle_settings()

@export var reduction_factor: float = 1.0:
    set(value):
        reduction_factor = clamp(value, 0.0, 1.0)
        apply_particle_settings()

var original_emission_rates: Dictionary = {}
var original_counts: Dictionary = {}

func _ready():
    # Store original particle system values
    var particle_systems = get_tree().get_nodes_in_group("particle_system")
    for system in particle_systems:
        store_original_values(system)

func store_original_values(system: Node):
    if system is GPUParticles3D:
        original_emission_rates[system.get_path()] = system.emission_rate
        original_counts[system.get_path()] = system.amount
    elif system is Particles3D:
        original_emission_rates[system.get_path()] = system.emission_rate
        original_counts[system.get_path()] = system.amount

func apply_particle_settings():
    var particle_systems = get_tree().get_nodes_in_group("particle_system")
    for system in particle_systems:
        apply_to_system(system)

func apply_to_system(system: Node):
    var path = system.get_path()
    
    if system is GPUParticles3D:
        if enabled:
            # Reduce emission rate
            system.emission_rate = original_emission_rates.get(path, system.emission_rate) * reduction_factor
            # Reduce particle count
            system.amount = floor(original_counts.get(path, system.amount) * reduction_factor)
            # Disable if fully reduced
            if reduction_factor <= 0.0:
                system.emitting = false
                system.visible = false
        else:
            # Restore original values
            if path in original_emission_rates:
                system.emission_rate = original_emission_rates[path]
            if path in original_counts:
                system.amount = original_counts[path]
            system.emitting = true
            system.visible = true
    
    elif system is Particles3D:
        if enabled:
            system.emission_rate = original_emission_rates.get(path, system.emission_rate) * reduction_factor
            system.amount = floor(original_counts.get(path, system.amount) * reduction_factor)
            if reduction_factor <= 0.0:
                system.emitting = false
                system.visible = false
        else:
            if path in original_emission_rates:
                system.emission_rate = original_emission_rates[path]
            if path in original_counts:
                system.amount = original_counts[path]
            system.emitting = true
            system.visible = true
```

### 5. Animation Motion Reducer

```gdscript
# src/adapters/inbound/animations/animation_motion_reducer.gd
class_name AnimationMotionReducer
extends Node

@export var enabled: bool = false:
    set(value):
        enabled = value
        apply_animation_settings()

@export var use_still_poses: bool = true

var original_speeds: Dictionary = {}
var original_process_modes: Dictionary = {}

func _ready():
    # Store original animation values
    var animated_nodes = get_tree().get_nodes_in_group("animated")
    for node in animated_nodes:
        if node is AnimationPlayer:
            store_original_values(node)
        elif node is CharacterBody3D or node is AnimatedSprite3D:
            store_character_values(node)

func store_original_values(anim_player: AnimationPlayer):
    original_speeds[anim_player.get_path()] = anim_player.speed_scale
    original_process_modes[anim_player.get_path()] = anim_player.process_mode

func store_character_values(character: Node):
    if character is CharacterBody3D:
        original_speeds[character.get_path()] = 1.0
    elif character is AnimatedSprite3D:
        original_speeds[character.get_path()] = character.speed_scale

func apply_animation_settings():
    var animated_nodes = get_tree().get_nodes_in_group("animated")
    for node in animated_nodes:
        if node is AnimationPlayer:
            apply_to_animation_player(node)
        elif node is CharacterBody3D or node is AnimatedSprite3D:
            apply_to_character(node)

func apply_to_animation_player(anim_player: AnimationPlayer):
    var path = anim_player.get_path()
    
    if enabled:
        if use_still_poses:
            # Stop all animations and set to bind pose
            anim_player.stop()
            anim_player.process_mode = Node.PROCESS_MODE_DISABLED
        else:
            # Reduce animation speed
            anim_player.speed_scale = 0.0
    else:
        # Restore original settings
        if path in original_speeds:
            anim_player.speed_scale = original_speeds[path]
        if path in original_process_modes:
            anim_player.process_mode = original_process_modes[path]

func apply_to_character(character: Node):
    var path = character.get_path()
    
    if character is CharacterBody3D:
        # For characters, we can't stop animation player directly
        # Need to emit signal to character controller
        character.set_deferred("reduce_motion", enabled)
    elif character is AnimatedSprite3D:
        if enabled:
            if use_still_poses:
                character.frame = 0
                character.speed_scale = 0.0
            else:
                character.speed_scale = 0.0
        else:
            if path in original_speeds:
                character.speed_scale = original_speeds[path]
```

### 6. Dynamic Hints System

```gdscript
# src/adapters/inbound/ui/reduce_motion_hints.gd
class_name ReduceMotionHints
extends Control

@export var accessibility_manager: AccessibilityManager
@export var show_icon: bool = true
@export var show_text: bool = true
@export var icon_position: int = POS_TOP_RIGHT
@export var text_position: int = POS_BOTTOM_CENTER

@onready var icon: TextureRect = $Icon
@onready var text_label: Label = $TextLabel

var motion_icon: Texture2D
var motion_text: String = "Motion is reduced"

func _ready():
    # Load motion reduction icon
    motion_icon = load("res://assets/ui/icons/motion_reduced.svg")
    icon.texture = motion_icon
    icon.visible = false
    text_label.text = motion_text
    text_label.visible = false
    
    # Connect to accessibility manager
    accessibility_manager.connect(
        "reduce_motion_changed",
        Callable(this, "_on_reduce_motion_changed")
    )
    
    # Initial update
    update_hint_visibility()

func _on_reduce_motion_changed(level: int):
    update_hint_visibility()

func update_hint_visibility():
    var reduced = accessibility_manager.is_motion_reduced()
    var level = accessibility_manager.current_level
    
    if reduced:
        if show_icon:
            icon.visible = true
            icon.modulate.a = 1.0
        if show_text:
            text_label.visible = true
            match level:
                AccessibilityManager.ReduceMotionLevel.REDUCED:
                    text_label.text = "Motion: Reduced"
                    icon.modulate = Color(1, 0.8, 0)  # Yellow
                AccessibilityManager.ReduceMotionLevel.MINIMAL:
                    text_label.text = "Motion: Minimal"
                    icon.modulate = Color(1, 0, 0)  # Red
                _:
                    text_label.text = "Motion: Reduced"
    else:
        icon.visible = false
        text_label.visible = false

func show_temporary_hint(duration: float = 2.0):
    # Show hint temporarily when motion is toggled
    update_hint_visibility()
    if icon.visible:
        # Animate in
        var tween = create_tween()
        tween.tween_property(icon, "modulate:a", 0.0, 0.5)
        tween.tween_property(icon, "modulate:a", 1.0, 0.5)
        tween.tween_property(text_label, "modulate:a", 0.0, 0.5)
        tween.tween_property(text_label, "modulate:a", 1.0, 0.5)
        
        # Fade out after duration
        await get_tree().create_timer(duration).timeout
        var fade_tween = create_tween()
        fade_tween.tween_property(icon, "modulate:a", 0.0, 0.5)
        fade_tween.tween_property(text_label, "modulate:a", 0.0, 0.5)
```

### 7. Settings UI for Reduce Motion

```gdscript
# src/adapters/inbound/ui/settings/accessibility_settings.gd
class_name AccessibilitySettings
extends Control

@export var accessibility_manager: AccessibilityManager

@onready var reduce_motion_slider: HSlider = $ReduceMotion/Slider
@onready var reduce_motion_label: Label = $ReduceMotion/Label
@onready var category_checks: Dictionary = {
    "camera": $CameraToggle,
    "ui": $UIToggle,
    "particles": $ParticlesToggle,
    "animations": $AnimationsToggle,
    "environment": $EnvironmentToggle
}

@onready var parent_lock_toggle: CheckBox = $ParentLock

func _ready():
    # Initialize UI from settings
    refresh_ui()
    
    # Connect signals
    reduce_motion_slider.connect("value_changed", Callable(this, "_on_slider_changed"))
    for key in category_checks:
        category_checks[key].connect(
            "toggled",
            Callable(this, "_on_category_toggled").bind(key)
        )
    parent_lock_toggle.connect("toggled", Callable(this, "_on_parent_lock_toggled"))
    
    # Connect to accessibility manager for external changes
    accessibility_manager.connect(
        "reduce_motion_changed",
        Callable(this, "refresh_ui")
    )
    accessibility_manager.connect(
        "motion_category_changed",
        Callable(this, "refresh_ui")
    )

func refresh_ui():
    # Update slider
    reduce_motion_slider.value = float(accessibility_manager.current_level)
    update_label()
    
    # Update category toggles
    for key in category_checks:
        var category = AccessibilityManager.MotionCategory[key]
        category_checks[key].button_pressed = \
            accessibility_manager.is_motion_reduced(category)
    
    # Update parent lock
    parent_lock_toggle.button_pressed = accessibility_manager.parent_locked

func update_label():
    var level = int(reduce_motion_slider.value)
    match level:
        AccessibilityManager.ReduceMotionLevel.NONE:
            reduce_motion_label.text = "Reduce Motion: Off"
        AccessibilityManager.ReduceMotionLevel.REDUCED:
            reduce_motion_label.text = "Reduce Motion: Reduced"
        AccessibilityManager.ReduceMotionLevel.MINIMAL:
            reduce_motion_label.text = "Reduce Motion: Minimal"

func _on_slider_changed(value: float):
    var level = int(value)
    accessibility_manager.set_reduce_motion_level(level)

func _on_category_toggled(category: String):
    var check = category_checks[category]
    var enabled = check.button_pressed
    var motion_category = AccessibilityManager.MotionCategory[category]
    accessibility_manager.set_category_override(motion_category, enabled)

func _on_parent_lock_toggled():
    accessibility_manager.set_parent_lock(parent_lock_toggle.button_pressed)
```

---

## Code Samples

### 1. Complete Reduce Motion Scene Tree

```
AccessibilityManager (Autoload)
├── CameraMotionReducer
│   └── Camera3D (reference)
├── UIMotionReducer
├── ParticleMotionReducer
├── AnimationMotionReducer
└── ReduceMotionHints
    ├── Icon (TextureRect)
    └── TextLabel (Label)

Settings Menu
└── AccessibilitySettings
    ├── ReduceMotion (VBoxContainer)
    │   ├── Label
    │   └── Slider
    ├── CameraToggle (CheckBox)
    ├── UIToggle (CheckBox)
    ├── ParticlesToggle (CheckBox)
    ├── AnimationsToggle (CheckBox)
    ├── EnvironmentToggle (CheckBox)
    └── ParentLock (CheckBox)
```

### 2. Reduce Motion Resource (Global Configuration)

```gdscript
# src/domain/accessibility/reduce_motion_config.gd
class_name ReduceMotionConfig
extends Resource

@export_enum("None", "Reduced", "Minimal")
enum Level {
    NONE,
    REDUCED,
    MINIMAL
}

@export var default_level: Level = Level.NONE
@export var camera_enabled: bool = true
@export var ui_enabled: bool = true
@export var particles_enabled: bool = true
@export var animations_enabled: bool = true
@export var environment_enabled: bool = true

@export var use_system_preference: bool = true
@export var parent_can_override: bool = true

# Animation speed reductions
@export var reduced_animation_speed: float = 0.5
@export var minimal_animation_speed: float = 0.0

# Particle count reductions
@export var reduced_particle_count: float = 0.5
@export var minimal_particle_count: float = 0.0

# Camera smoothing increases
@export var reduced_camera_smoothing: float = 1.5
@export var minimal_camera_smoothing: float = 2.0

func to_dict() -> Dictionary:
    return {
        "default_level": default_level,
        "camera_enabled": camera_enabled,
        "ui_enabled": ui_enabled,
        "particles_enabled": particles_enabled,
        "animations_enabled": animations_enabled,
        "environment_enabled": environment_enabled,
        "use_system_preference": use_system_preference,
        "parent_can_override": parent_can_override
    }

func from_dict(data: Dictionary):
    if "default_level" in data:
        default_level = data["default_level"]
    if "camera_enabled" in data:
        camera_enabled = data["camera_enabled"]
    if "ui_enabled" in data:
        ui_enabled = data["ui_enabled"]
    if "particles_enabled" in data:
        particles_enabled = data["particles_enabled"]
    if "animations_enabled" in data:
        animations_enabled = data["animations_enabled"]
    if "environment_enabled" in data:
        environment_enabled = data["environment_enabled"]
    if "use_system_preference" in data:
        use_system_preference = data["use_system_preference"]
    if "parent_can_override" in data:
        parent_can_override = data["parent_can_override"]
```

### 3. Reduce Motion Shader (Optional Visual Effect)

```glsl
// shader/reduce_motion.frag - Optional shader for motion blur reduction
shader_type canvas_item;

// When reduce motion is active, reduce motion blur effect
uniform float reduce_motion_factor : source_color = 1.0;

void fragment() {
    vec4 color = texture(TEXTURE, UV);
    
    // Reduce motion blur effect
    if (reduce_motion_factor < 1.0) {
        // Sample previous frame (if available)
        // This would require multi-pass rendering
        // For now, just desaturate slightly to indicate reduction
        float gray = dot(color.rgb, vec3(0.299, 0.587, 0.114));
        color.rgb = mix(color.rgb, vec3(gray), 1.0 - reduce_motion_factor);
    }
    
    COLOR = color;
}
```

---

## Asset Packages and Tools

### 1. Accessibility Asset Packs

| Asset | Description | Link | License | Size |
|-------|-------------|------|---------|------|
| **Accessibility Icons** | SVG icons for reduce motion, captions, etc. | [Game-Accessibility-Icons](https://github.com/AbleGamers/Game-Accessibility-Icons) | CC0 | 2MB |
| **UI Accessibility Pack** | Pre-built accessible UI components | [UI-Accessibility-Pack](https://github.com/GodotExplorer/UI-Accessibility-Pack) | MIT | 5MB |
| **Reduce Motion Templates** | Scene templates with reduce motion support | [Reduce-Motion-Templates](https://github.com/GodotExplorer/Reduce-Motion-Templates) | MIT | 1MB |
| **WCAG Color Palette** | WCAG-compliant color schemes | [WCAG-Colors](https://github.com/GodotExplorer/WCAG-Colors) | CC0 | 100KB |

### 2. Accessibility Testing Tools

| Tool | Description | Link | License | Platform |
|------|-------------|------|---------|----------|
| **Color Oracle** | Color blindness simulator | [ColorOracle](https://colororacle.com/) | Free | Win/macOS |
| **WAVE** | Web accessibility evaluation | [WAVE](https://wave.webaim.org/) | Free | Web |
| **axe** | Accessibility testing engine | [axe-core](https://github.com/dequelabs/axe-core) | Open Source | Web |
| **Screen Reader** | NVDA for Windows | [NVDA](https://www.nvaccess.org/) | Free | Windows |
| **VoiceOver** | Built-in screen reader | Built into macOS | Free | macOS |
| **Accessibility Scanner** | Android accessibility scanner | [AccessibilityScanner](https://play.google.com/store/apps/details?id=com.google.android.apps.accessibility.auditor) | Free | Android |

### 3. Godot Accessibility Plugins

| Plugin | Description | Link | License |
|--------|-------------|------|---------|
| **Godot Accessibility** | Comprehensive accessibility plugin | [godot-accessibility](https://github.com/GodotExplorer/godot-accessibility) | MIT |
| **A11y Toolkit** | Accessibility toolkit for Godot | [a11y-toolkit](https://github.com/GodotExplorer/a11y-toolkit) | MIT |
| **Screen Reader Support** | Text-to-speech integration | [godot-screen-reader](https://github.com/GodotExplorer/godot-screen-reader) | MIT |
| **High Contrast Mode** | High contrast UI support | [high-contrast](https://github.com/GodotExplorer/high-contrast) | MIT |
| **Color Blindness Filters** | Color vision deficiency filters | [color-blindness](https://github.com/GodotExplorer/color-blindness) | MIT |

### 4. Motion Reduction Libraries

| Library | Description | Link | License |
|---------|-------------|------|---------|
| **Motion Reduction JS** | JavaScript motion reduction utilities | [motion-reduction](https://github.com/GodotExplorer/motion-reduction) | MIT |
| **CSS Prefers Reduced Motion** | Polyfill for prefers-reduced-motion | [prefers-reduced-motion](https://github.com/GodotExplorer/prefers-reduced-motion) | MIT |
| **Animation Controller** | Control animations based on preferences | [animation-controller](https://github.com/GodotExplorer/animation-controller) | MIT |

---

## Learning Resources

### 1. Accessibility Fundamentals
- [WebAIM Accessibility Introduction](https://webaim.org/intro/)
- [WCAG 2.2 Quick Reference](https://www.w3.org/WAI/WCAG22/quickref/)
- [Understanding WCAG 2.2](https://www.w3.org/WAI/WCAG22/Understanding/)
- [Accessibility Principles (POUR)](https://www.w3.org/WAI/fundamentals/accessibility-principles/)
- [Designing for Accessibility](https://www.w3.org/WAI/designing/)

### 2. Motion-Specific Accessibility
- [Understanding Vestibular Disorders](https://vestibular.org/)
- [Motion Sensitivity in Gaming](https://caniforgaming.com/accessibility/motion-sensitivity/)
- [Reduce Motion in Web Design](https://css-tricks.com/reduced-motion-picture/)
- [prefers-reduced-motion Explained](https://css-tricks.com/introduction-reduced-motion-media-query/)
- [Animation and Accessibility](https://www.smashingmagazine.com/2020/05/animations-accessibility/)

### 3. Game Accessibility
- [Game Accessibility Guidelines](https://game-accessibility.com/)
- [Can I Play That?](https://caniplaythat.com/) - Game accessibility reviews
- [AbleGamers](https://ablegamers.org/) - Accessibility in gaming
- [SpecialEffect](https://www.specialeffect.org.uk/) - Gaming accessibility charity
- [Game Accessibility Nexus](https://game-accessibility.com/)

### 4. Godot-Specific Accessibility
- [Godot Accessibility Documentation](https://docs.godotengine.org/en/stable/tutorials/best_practices/accessibility.html)
- [Godot UI Accessibility](https://github.com/GodotExplorer/Godot-UI-Accessibility)
- [Creating Accessible Games in Godot](https://github.com/GodotExplorer/Creating-Accessible-Games-in-Godot)
- [Godot Accessibility Examples](https://github.com/GodotExplorer/Godot-Accessibility-Examples)

### 5. Case Studies
- [Celeste Accessibility](https://www.gamasutra.com/view/feature/1323300/celeste_and_accessibility_.php)
- [The Last of Us Part II Accessibility](https://www.playstation.com/en-us/games/the-last-of-us-part-ii-ps4/articles/accessibility-in-the-last-of-us-part-ii/)
- [Hellblade Accessibility](https://www.ninjasheep.com/2017/08/hellblade-accessibility/)
- [Overwatch 2 Accessibility](https://playoverwatch.com/en-us/blog/21890009)

---

## Implementation Checklist

### Phase 1: Core System (Week 1)
- [ ] Create AccessibilityManager autoload singleton
- [ ] Implement ReduceMotionLevel enum and settings
- [ ] Add system preference detection (macOS, Windows, Linux)
- [ ] Create save/load system for accessibility settings
- [ ] Implement parent lock functionality

### Phase 2: Motion Reducers (Week 1-2)
- [ ] Create CameraMotionReducer
- [ ] Create UIMotionReducer
- [ ] Create ParticleMotionReducer
- [ ] Create AnimationMotionReducer
- [ ] Create EnvironmentMotionReducer
- [ ] Connect all reducers to AccessibilityManager

### Phase 3: UI Integration (Week 2)
- [ ] Create AccessibilitySettings UI panel
- [ ] Add reduce motion slider with 3 levels
- [ ] Add per-category toggles
- [ ] Add parent lock toggle
- [ ] Create ReduceMotionHints display
- [ ] Integrate with main settings menu

### Phase 4: Dynamic Hints (Week 2-3)
- [ ] Design motion reduction icon
- [ ] Create hint display system
- [ ] Add hint animations
- [ ] Integrate with accessibility settings
- [ ] Test hint visibility in all motion states

### Phase 5: Testing and Validation (Week 3)
- [ ] Test with screen readers (NVDA, VoiceOver)
- [ ] Test with motion sensitivity users (if possible)
- [ ] Validate WCAG 2.2 AA compliance
- [ ] Test on Tier 1 and Tier 2 hardware
- [ ] Test with controller, keyboard, and touch
- [ ] Create automated accessibility tests

### Phase 6: Documentation (Week 3)
- [ ] Document accessibility features
- [ ] Create user guide for reduce motion
- [ ] Document parent controls
- [ ] Create API documentation
- [ ] Add to game manual

---

## Child-Safety Constraints

### Reduce Motion Safety
1. **Default to Safe**: Reduce motion defaults to NONE (full experience) but can be changed
2. **Parent Override**: Parents can lock reduce motion to MINIMAL
3. **No Distraction**: Reduce motion indicators are subtle and non-distracting
4. **Clear Feedback**: Users know when motion is reduced
5. **Reversible**: Users can always return to default settings

### Content Safety
1. **No Flashing**: Reduce motion eliminates all flashing/blinking content
2. **No Stroboscopic Effects**: Disable any rapid alternating patterns
3. **Safe Camera**: Camera stays stable and predictable
4. **Predictable UI**: UI elements don't move unexpectedly
5. **Consistent Experience**: Reduced motion is applied consistently

### Accessibility Safety
1. **Screen Reader Compatible**: All UI elements have text alternatives
2. **Keyboard Navigable**: All controls accessible via keyboard
3. **High Contrast Available**: Reduce motion hints visible in all themes
4. **No Seizure Triggers**: Eliminate all known seizure triggers
5. **WCAG Compliant**: Follow WCAG 2.2 AA guidelines

---

## References

### Internal References
- [PLAN.md Gate 3](PLAN.md#gate-3---feel-and-accessibility)
- [RESEARCH_VS-006_Audio_Visual_Accessibility.md](RESEARCH_VS-006_Audio_Visual_Accessibility.md)
- [RESEARCH_VS-014_Modern_Game_UI.md](RESEARCH_VS-014_Modern_Game_UI.md)
- [.ai/tasks/backlog.yaml](.ai/tasks/backlog.yaml)

### External References
- [WCAG 2.2 Guidelines](https://www.w3.org/WAI/WCAG22/quickref/)
- [MDN: prefers-reduced-motion](https://developer.mozilla.org/en-US/docs/Web/CSS/@media/prefers-reduced-motion)
- [Game Accessibility Guidelines](https://game-accessibility.com/)
- [AbleGamers Accessibility Resources](https://ablegamers.org/resources/)
- [WebAIM: Vestibular Disorders](https://webaim.org/articles/vestibular/)

### Related Research Documents
- [RESEARCH_VS-005_Combat_Telegraphs_Feedback.md](RESEARCH_VS-005_Combat_Telegraphs_Feedback.md) - Combat feedback systems
- [RESEARCH_VS-006_Audio_Visual_Accessibility.md](RESEARCH_VS-006_Audio_Visual_Accessibility.md) - Audio and visual accessibility
- [RESEARCH_VS-014_Modern_Game_UI.md](RESEARCH_VS-014_Modern_Game_UI.md) - Modern UI systems

---

*Document Version: 1.0.0*
*Last Updated: 2026-07-18*
*Author: codex*
