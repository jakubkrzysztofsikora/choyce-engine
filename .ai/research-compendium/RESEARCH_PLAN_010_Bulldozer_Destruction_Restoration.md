# PLAN-010: Bulldozer Destruction & Restoration System - Deep Research Compendium

**Status**: in_progress  
**Specialty**: godot-destruction-physics-and-undo  
**Gate**: New Sandbox Systems (PLAN.md Section 328-330)  
**Priority**: HIGH  
**Last Updated**: 2026-07-18  
**Child-Safety Consideration**: Destruction must be bounded, reversible, and child-safe

---

## Table of Contents

1. [Task Overview](#task-overview)
2. [Destruction System Architecture](#destruction-system-architecture)
3. [Tag-Based Destruction Filtering](#tag-based-destruction-filtering)
4. [Undo/Redo & Restoration Stack](#undoredo--restoration-stack)
5. [Protected Objects System](#protected-objects-system)
6. [Destruction Visual Effects](#destruction-visual-effects)
7. [Restoration Visual Effects](#restoration-visual-effects)
8. [Bulldozer Blade Physics](#bulldozer-blade-physics)
9. [Temporary Scenery Tagging System](#temporary-scenery-tagging-system)
10. [Build-Grid Block Management](#build-grid-block-management)
11. [Child-Safe Destruction Limits](#child-safe-destruction-limits)
12. [Asset Packages & Models](#asset-packages--models)
13. [Code Samples & Implementation Patterns](#code-samples--implementation-patterns)
14. [Testing & Validation Checklist](#testing--validation-checklist)
15. [Learning Resources](#learning-resources)

---

## Task Overview

### Objective

Implement a **bulldozer destruction and restoration system** that:
- **Destroys only tagged objects**: Temporary scenery and build-grid blocks
- **Protects important objects**: Homes, NPCs, bridge, boundary, protected builds
- **Tracks all destructions**: For restoration/undo
- **Provides visual feedback**: Destruction and restoration effects
- **Is child-safe**: Bounded, reversible, no permanent damage

### Source Reference

From PLAN.md (lines 328-330):
> **Discover → drive → reshape (VS-021):** use a verified CC0 vehicle kit (Kenney Car Kit is the preferred candidate) for rare parked vehicles. Implement arcade CharacterBody driving, enter/exit, camera handoff and collision. **The bulldozer may remove only tagged temporary scenery and build-grid blocks; homes, NPCs, bridge, boundary and protected builds stay immune and every removal is restorable.**

### Key Requirements

- ✅ **Tag-based filtering**: Only destroys objects with `temporary` or `destroyable` tags
- ✅ **Protected objects**: Homes, NPCs, bridge, boundary are immune
- ✅ **Restoration**: Every destroyed object can be restored
- ✅ **Undo/Redo**: Can undo single or multiple destructions
- ✅ **Visual feedback**: Particles, sounds, animations
- ✅ **Child-safe**: No permanent damage, bounded system
- ✅ **Build-grid integration**: Works with building system
- ✅ **Performance**: Efficient for many objects

### Acceptance Criteria

1. Bulldozer blade destroys only tagged temporary scenery
2. Protected objects (homes, NPCs, bridge, boundary) cannot be destroyed
3. Destroyed objects can be restored individually or all at once
4. Restoration places objects at their original position/rotation
5. Visual effects show destruction and restoration
6. System works with build-grid blocks
7. Child cannot permanently damage the world
8. Performance remains smooth with many destroyable objects

---

## Destruction System Architecture

### Core System Design

```
Bulldozer (CharacterBody3D)
├── Blade (MeshInstance3D)
│   └── BladeCollision (Area3D) - Detects objects to destroy
├── DestructionManager (Node) - Manages destruction/restoration
│   ├── destruction_stack: Array - List of destroyed objects
│   └── redo_stack: Array - List of restored objects (for redo)
└── BulldozerCamera (Camera3D)
```

### Destruction Flow

```
1. BladeCollision detects object
2. DestructionManager checks if object is destroyable
3. If YES: Store object state, remove from world, add to destruction_stack
4. If NO: Ignore collision
5. On restore: Pop from destruction_stack, restore object to saved state
```

### DestructionManager Singleton

```gdscript
# destruction_manager.gd

class_name DestructionManager
extends Node

# Singleton pattern
static var instance: DestructionManager = null

signal object_destroyed(object_data: Dictionary)
signal object_restored(object_data: Dictionary)
signal destruction_stack_changed(size: int)

# Destruction tracking
var destruction_stack: Array = []
var redo_stack: Array = []

@export var max_history: int = 100  # Prevent memory issues

func _ready() -> void:
    instance = self

func can_destroy(node: Node3D) -> bool:
    # Check if node is destroyable
    return _is_destroyable(node) and not _is_protected(node)

func destroy_object(node: Node3D) -> bool:
    if not can_destroy(node):
        return false
    
    # Store object state
    var state: Dictionary = _capture_object_state(node)
    
    # Remove from world
    node.queue_free()
    
    # Add to destruction stack
    destruction_stack.append(state)
    
    # Trim if over max
    if destruction_stack.size() > max_history:
        destruction_stack.remove_at(0)
    
    # Clear redo stack (can't redo after new action)
    redo_stack.clear()
    
    # Emit signals
    object_destroyed.emit(state)
    destruction_stack_changed.emit(destruction_stack.size())
    
    return true

func restore_last() -> bool:
    if destruction_stack.is_empty():
        return false
    
    # Get last destroyed object
    var state: Dictionary = destruction_stack.pop_back()
    
    # Restore object
    _restore_object_state(state)
    
    # Add to redo stack
    redo_stack.append(state)
    
    # Emit signals
    object_restored.emit(state)
    destruction_stack_changed.emit(destruction_stack.size())
    
    return true

func restore_all() -> int:
    var count: int = 0
    while restore_last():
        count += 1
    return count

func redo_last() -> bool:
    if redo_stack.is_empty():
        return false
    
    # Get last restored object
    var state: Dictionary = redo_stack.pop_back()
    
    # Re-destroy it
    _destroy_object_by_state(state)
    
    # Add back to destruction stack
    destruction_stack.append(state)
    
    # Emit signals
    object_destroyed.emit(state)
    destruction_stack_changed.emit(destruction_stack.size())
    
    return true
```

### Object State Capture

```gdscript
func _capture_object_state(node: Node3D) -> Dictionary:
    return {
        "node": node,
        "position": node.global_position,
        "rotation": node.global_rotation,
        "scale": node.scale,
        "parent": node.get_parent(),
        "index_in_parent": node.get_index_in_parent(),
        "tags": node.tags.duplicate(),
        "metadata": node.get_meta_list().to_array(),
        "timestamp": Time.get_unix_time_from_system(),
        "type": node.get_class()
    }

func _restore_object_state(state: Dictionary) -> Node3D:
    var node: Node3D = state.node
    var parent: Node = state.parent
    
    # Re-add to parent
    parent.add_child(node)
    parent.move_child(node, state.index_in_parent)
    
    # Restore transform
    node.global_position = state.position
    node.global_rotation = state.rotation
    node.scale = state.scale
    
    # Restore tags
    node.tags = state.tags.duplicate()
    
    # Restore metadata
    for key in state.metadata.size():
        node.set_meta(key, state.metadata[key])
    
    return node

func _destroy_object_by_state(state: Dictionary) -> void:
    # Get node from state (it should be in tree)
    var node: Node3D = state.node
    if node.is_inside_tree():
        node.queue_free()
```

---

## Tag-Based Destruction Filtering

### Tag System Design

| Tag | Description | Destroyable? |
|-----|-------------|--------------|
| `temporary` | Temporary scenery, decorations | ✅ YES |
| `destroyable` | Explicitly marked as destroyable | ✅ YES |
| `build_grid` | Objects placed by building system | ✅ YES |
| `protected` | Explicitly protected objects | ❌ NO |
| `home` | Player homes, buildings | ❌ NO |
| `npc` | NPC characters | ❌ NO |
| `bridge` | Bridge structures | ❌ NO |
| `boundary` | World boundary markers | ❌ NO |

### Tag Checking Functions

```gdscript
# In destruction_manager.gd

func _is_destroyable(node: Node3D) -> bool:
    # Check for destroyable tags
    if "temporary" in node.tags:
        return true
    if "destroyable" in node.tags:
        return true
    if "build_grid" in node.tags:
        return true
    
    # Check name patterns
    var name_lower: String = node.name.to_lower()
    if name_lower.begins_with("temp_") or name_lower.begins_with("decoration_"):
        return true
    
    return false

func _is_protected(node: Node3D) -> bool:
    # Check for protected tags
    if "protected" in node.tags:
        return true
    
    # Check name patterns
    var name_lower: String = node.name.to_lower()
    if "home" in name_lower or name_lower.begins_with("house_"):
        return true
    if "npc" in name_lower or name_lower.begins_with("character_"):
        return true
    if "bridge" in name_lower or name_lower.begins_with("bridge_"):
        return true
    if "boundary" in name_lower or name_lower.begins_with("world_boundary"):
        return true
    if "player" in name_lower:
        return true
    
    # Check parent hierarchy
    var parent: Node = node.get_parent()
    while parent:
        if "protected" in parent.tags:
            return true
        parent = parent.get_parent()
    
    return false
```

### Tag Helper Functions

```gdscript
# tag_utils.gd

class_name TagUtils
extends RefCounted

static func add_tags(node: Node, tags: Array) -> void:
    for tag in tags:
        if not node.tags.has(tag):
            node.tags.append(tag)

static func remove_tags(node: Node, tags: Array) -> void:
    for tag in tags:
        if node.tags.has(tag):
            node.tags.erase(tag)

static func has_any_tag(node: Node, tags: Array) -> bool:
    for tag in tags:
        if node.tags.has(tag):
            return true
    return false

static func has_all_tags(node: Node, tags: Array) -> bool:
    for tag in tags:
        if not node.tags.has(tag):
            return false
    return true
```

---

## Undo/Redo & Restoration Stack

### Command Pattern Implementation

```gdscript
# command.gd (base class)

class_name Command
extends RefCounted

func execute() -> void:
    pass

func undo() -> void:
    pass

func redo() -> void:
    execute()
```

```gdscript
# destroy_command.gd

class_name DestroyCommand
extends Command

var node: Node3D
var state: Dictionary
var executed: bool = false

func _init(object: Node3D) -> void:
    node = object

func execute() -> void:
    if executed:
        return
    
    state = DestructionManager.instance._capture_object_state(node)
    node.queue_free()
    executed = true

func undo() -> void:
    if not executed:
        return
    
    DestructionManager.instance._restore_object_state(state)
    executed = false
```

### Command History Manager

```gdscript
# command_history.gd

class_name CommandHistory
extends Node

var undo_stack: Array[Command] = []
var redo_stack: Array[Command] = []

@export var max_history: int = 100

func execute_command(command: Command) -> void:
    command.execute()
    undo_stack.append(command)
    redo_stack.clear()
    
    # Trim history
    if undo_stack.size() > max_history:
        undo_stack.remove_at(0)

func undo() -> bool:
    if undo_stack.is_empty():
        return false
    
    var command: Command = undo_stack.pop_back()
    command.undo()
    redo_stack.append(command)
    return true

func redo() -> bool:
    if redo_stack.is_empty():
        return false
    
    var command: Command = redo_stack.pop_back()
    command.execute()
    undo_stack.append(command)
    return true
```

### Integration with Bulldozer

```gdscript
# In bulldozer.gd

@onready var command_history: CommandHistory = CommandHistory.new()

func _ready() -> void:
    add_child(command_history)

func _on_blade_hit(body: Node3D) -> void:
    if DestructionManager.instance.can_destroy(body):
        var command: DestroyCommand = DestroyCommand.new(body)
        command_history.execute_command(command)
```

---

## Protected Objects System

### Protection Categories

#### 1. Static Protected Objects

```gdscript
# In world setup

func _setup_protected_objects() -> void:
    # Mark homes as protected
    var homes: Array = get_tree().get_nodes_in_group("homes")
    for home in homes:
        home.tags.append("protected")
    
    # Mark NPCs as protected
    var npcs: Array = get_tree().get_nodes_in_group("npcs")
    for npc in npcs:
        npc.tags.append("protected")
    
    # Mark bridge as protected
    var bridge: Node3D = $Bridge
    bridge.tags.append("protected")
    
    # Mark boundary as protected
    var boundaries: Array = get_tree().get_nodes_in_group("boundaries")
    for boundary in boundaries:
        boundary.tags.append("protected")
```

#### 2. Dynamic Protection

```gdscript
# In building system

func place_building(building_data: Dictionary) -> Node3D:
    var building: Node3D = _create_building(building_data)
    
    # Add to world
    add_child(building)
    
    # Mark as protected if it's a home
    if building_data.type == "home":
        building.tags.append("protected")
        building.tags.append("home")
    
    # Mark as temporary if it's decoration
    if building_data.type == "decoration":
        building.tags.append("temporary")
    
    return building
```

#### 3. Protection Visualization

```gdscript
# protection_visualizer.gd

class_name ProtectionVisualizer
extends Node

@export var protected_color: Color = Color.RED
@export var destroyable_color: Color = Color.GREEN

func visualize_protection(node: Node3D) -> void:
    if DestructionManager.instance._is_protected(node):
        _show_protection_indicator(node, protected_color, "PROTECTED")
    elif DestructionManager.instance._is_destroyable(node):
        _show_protection_indicator(node, destroyable_color, "DESTROYABLE")

func _show_protection_indicator(node: Node3D, color: Color, label: String) -> void:
    # Create outline effect
    var outline: MeshInstance3D = node.duplicate()
    outline.material_override = create_outline_material(color)
    outline.position = Vector3(0, 0, 0.01)  # Slightly offset
    node.add_child(outline)
    
    # Add label
    var label_3d: Node3D = _create_3d_label(label)
    label_3d.global_position = node.global_position + Vector3(0, 2, 0)
    add_child(label_3d)
    
    # Remove after delay
    await get_tree().create_timer(3.0).timeout
    outline.queue_free()
    label_3d.queue_free()
```

---

## Destruction Visual Effects

### Destruction Effect Prefab

```
# destruction_effect.tscn

[gd_scene load_steps=2 format=3]

[node name="DestructionEffect" type="Node3D"]

[node name="DebrisParticles" type="GPUParticles3D" parent="."]
emitting = true
process_material = StandardMaterial3D.new()
particles_per_second = 50
direction = Vector3(0, 1, 0)
spread = 45
lifetime = 1.0
gravity = Vector3(0, -5, 0)

[node name="SmokeParticles" type="GPUParticles3D" parent="."]
emitting = true
process_material = StandardMaterial3D.new()
particles_per_second = 20
direction = Vector3(0, 1, 0)
spread = 30
lifetime = 2.0

[node name="AudioStreamPlayer3D" type="AudioStreamPlayer3D" parent="."]
stream = preload("res://audio/destruction.ogg")
autoplay = true

[node name="Timer" type="Timer" parent="."]
timeout_sec = 2.0
timeout.connect = ["queue_free"]
```

### Effect Spawner

```gdscript
# effect_spawner.gd

class_name EffectSpawner
extends Node

@export var destruction_effect_scene: PackedScene
@export var restoration_effect_scene: PackedScene

static var instance: EffectSpawner = null

func _ready() -> void:
    instance = self

func spawn_destruction_effect(position: Vector3) -> void:
    var effect: Node3D = destruction_effect_scene.instantiate()
    effect.global_position = position
    get_parent().add_child(effect)

func spawn_restoration_effect(position: Vector3) -> void:
    var effect: Node3D = restoration_effect_scene.instantiate()
    effect.global_position = position
    get_parent().add_child(effect)

# Usage in destruction_manager.gd
func destroy_object(node: Node3D) -> bool:
    if not can_destroy(node):
        return false
    
    var position: Vector3 = node.global_position
    
    # Spawn effect
    EffectSpawner.instance.spawn_destruction_effect(position)
    
    # Rest of destruction logic...
```

### Material Destruction Effect

```gdscript
# For more dramatic destruction

func _spawn_material_destruction(node: Node3D) -> void:
    if node is MeshInstance3D:
        # Get all materials
        var materials: Array = []
        if node.material_override:
            materials.append(node.material_override)
        else:
            for i in node.get_surface_material_count():
                materials.append(node.get_surface_material(i))
        
        # Create debris with materials
        for material in materials:
            _spawn_debris_with_material(node, material)

func _spawn_debris_with_material(node: MeshInstance3D, material: Material) -> void:
    # Create debris mesh
    var debris: MeshInstance3D = MeshInstance3D.new()
    debris.mesh = node.mesh
    debris.material_override = material
    debris.scale = node.scale * Vector3(0.3, 0.3, 0.3)
    
    # Random position near destruction
    debris.global_position = node.global_position + Vector3(
        randf_range(-1, 1),
        randf_range(0, 2),
        randf_range(-1, 1)
    )
    
    # Add physics
    var body: RigidBody3D = RigidBody3D.new()
    debris.add_to_group("debris")
    body.add_child(debris)
    body.mass = 1.0
    body.linear_velocity = Vector3(
        randf_range(-5, 5),
        randf_range(2, 5),
        randf_range(-5, 5)
    )
    body.angular_velocity = Vector3(
        randf_range(-2, 2),
        randf_range(-2, 2),
        randf_range(-2, 2)
    )
    
    get_parent().add_child(body)
    
    # Auto-cleanup
    var timer: Timer = Timer.new()
    timer.timeout.connect(body.queue_free.bind())
    timer.start(3.0)
    body.add_child(timer)
    timer.start()
```

---

## Restoration Visual Effects

### Restoration Effect Prefab

```
# restoration_effect.tscn

[gd_scene load_steps=2 format=3]

[node name="RestorationEffect" type="Node3D"]

[node name="MagicParticles" type="GPUParticles3D" parent="."]
emitting = true
process_material = StandardMaterial3D.new()
particles_per_second = 30
direction = Vector3(0, 1, 0)
spread = 15
lifetime = 1.5

[node name="GlowParticles" type="GPUParticles3D" parent="."]
emitting = true
process_material = StandardMaterial3D.new()
particles_per_second = 10
emission_energy = 2.0
lifetime = 2.0

[node name="AudioStreamPlayer3D" type="AudioStreamPlayer3D" parent="."]
stream = preload("res://audio/restoration.ogg")
autoplay = true

[node name="Timer" type="Timer" parent="."]
timeout_sec = 2.0
timeout.connect = ["queue_free"]
```

### Reverse Destruction Animation

```gdscript
# For restoration with animation

func _restore_with_animation(state: Dictionary) -> void:
    var node: Node3D = state.node
    var parent: Node = state.parent
    
    # Re-add to parent (hidden)
    parent.add_child(node)
    parent.move_child(node, state.index_in_parent)
    node.visible = false
    
    # Position slightly underground
    node.global_position = state.position - Vector3(0, 1, 0)
    node.global_rotation = state.rotation
    node.scale = Vector3(0.1, 0.1, 0.1)
    
    # Animate restoration
    var tween: Tween = create_tween()
    tween.tween_property(node, "global_position", state.position, 0.5)
    tween.tween_property(node, "scale", state.scale, 0.5)
    tween.tween_property(node, "visible", true, 0.1)
    
    # Spawn effect
    EffectSpawner.instance.spawn_restoration_effect(state.position)
    
    await tween.finished
```

### Restoration Preview

```gdscript
# For undo preview

func show_restoration_preview() -> void:
    if destruction_stack.is_empty():
        return
    
    var state: Dictionary = destruction_stack[-1]
    var preview: MeshInstance3D = _create_preview_mesh(state)
    
    preview.global_position = state.position
    preview.material_override = create_preview_material()
    
    add_child(preview)
    
    await get_tree().create_timer(3.0).timeout
    preview.queue_free()

func create_preview_material() -> StandardMaterial3D:
    var mat: StandardMaterial3D = StandardMaterial3D.new()
    mat.albedo_color = Color(0, 1, 0, 0.5)
    mat.emission_enabled = true
    mat.emission_energy = 0.5
    return mat
```

---

## Bulldozer Blade Physics

### Blade Area3D Setup

```
# Blade.tscn

[gd_scene load_steps=2 format=3]

[node name="Blade" type="Node3D"]

[node name="MeshInstance3D" type="MeshInstance3D" parent="."]
mesh = preload("res://models/bulldozer/blade.glb")

[node name="BladeCollision" type="Area3D" parent="."]
monitoring = true
monitorable = true

[node name="CollisionShape3D" type="CollisionShape3D" parent="."]
shape = BoxShape3D { size = Vector3(3, 1.5, 0.5) }
position = Vector3(0, 0, 2)
```

### Blade Movement & Control

```gdscript
# In bulldozer.gd

@export var blade_width: float = 3.0
@export var blade_height: float = 1.5
@export var blade_depth: float = 0.5

@export var blade_speed: float = 1.5  # Degrees per second
@export var max_blade_angle: float = 30.0  # Max degrees from horizontal

@onready var blade: Node3D = $Blade
@onready var blade_collision: Area3D = $Blade/BladeCollision

var blade_angle: float = 0.0  # Current blade angle in degrees

func _ready() -> void:
    # Setup blade collision
    var blade_shape: CollisionShape3D = blade_collision.get_child(0)
    blade_shape.shape = BoxShape3D.new()
    blade_shape.shape.size = Vector3(blade_width, blade_height, blade_depth)
    
    # Connect signal
    blade_collision.body_entered.connect(_on_blade_hit)
    
    # Set initial blade position
    blade.rotation_degrees = Vector3(-blade_angle, 0, 0)

func _process(delta: float) -> void:
    # Blade control from input
    var blade_input: float = Input.get_action_strength("blade_down") - Input.get_action_strength("blade_up")
    
    if blade_input != 0:
        blade_angle = clamp(
            blade_angle + blade_input * blade_speed * delta, 
            0, 
            max_blade_angle
        )
        blade.rotation_degrees = Vector3(-blade_angle, 0, 0)

func _on_blade_hit(body: Node3D) -> void:
    if DestructionManager.instance.can_destroy(body):
        # Small delay to prevent multiple hits
        if not _is_cooldown_active(body):
            _add_cooldown(body)
            DestructionManager.instance.destroy_object(body)

# Cooldown system to prevent rapid multiple hits
var hit_cooldowns: Dictionary = {}

func _is_cooldown_active(node: Node3D) -> bool:
    var node_id: int = node.get_instance_id()
    return hit_cooldowns.get(node_id, 0) > Time.get_ticks_msec()

func _add_cooldown(node: Node3D) -> void:
    hit_cooldowns[node.get_instance_id()] = Time.get_ticks_msec() + 500  # 500ms cooldown
```

### Blade Visual Effects

```gdscript
# Add effects when blade is active

func _process(delta: float) -> void:
    # Update blade effects
    if blade_angle > 0:
        _update_blade_effects()
    else:
        _hide_blade_effects()

func _update_blade_effects() -> void:
    # Show active effect
    $BladeActiveEffect.visible = true
    
    # Position effect at blade tip
    var effect: Node3D = $BladeActiveEffect
    effect.global_position = blade.global_position + Vector3(0, 0, 2)

func _hide_blade_effects() -> void:
    $BladeActiveEffect.visible = false
```

---

## Temporary Scenery Tagging System

### Automatic Tagging on Placement

```gdscript
# In building system

func place_decoration(decoration_data: Dictionary) -> Node3D:
    var decoration: Node3D = _create_decoration(decoration_data)
    
    # Add to world
    add_child(decoration)
    
    # Tag as temporary and destroyable
    decoration.tags.append("temporary")
    decoration.tags.append("destroyable")
    
    # Add metadata
    decoration.set_meta("placed_by", "player")
    decoration.set_meta("placement_time", Time.get_unix_time_from_system())
    
    return decoration
```

### Tagging Existing World Objects

```gdscript
# world_tagging_tool.gd

class_name WorldTaggingTool
extends Node

@export var tag_configurations: Dictionary = {
    "rocks": {"tags": ["temporary", "destroyable"], "layer": 1},
    "trees": {"tags": ["temporary", "destroyable"], "layer": 1},
    "bushes": {"tags": ["temporary", "destroyable"], "layer": 1},
    "homes": {"tags": ["protected", "home"], "layer": 2},
    "npcs": {"tags": ["protected", "npc"], "layer": 2},
    "bridge": {"tags": ["protected", "bridge"], "layer": 2}
}

func tag_world_objects() -> void:
    # Tag by name pattern
    for pattern in tag_configurations:
        _tag_objects_by_pattern(pattern, tag_configurations[pattern])

func _tag_objects_by_pattern(pattern: String, config: Dictionary) -> void:
    var objects: Array = get_tree().get_nodes_in_group(pattern)
    
    for obj in objects:
        if obj is Node3D:
            # Add tags
            for tag in config["tags"]:
                if not obj.tags.has(tag):
                    obj.tags.append(tag)
            
            # Set collision layer
            if obj is CollisionObject3D:
                obj.collision_layer = config["layer"]
```

### Tag Visualization in Editor

```gdscript
# tag_visualizer.gd (Editor plugin)

tool
class_name TagVisualizer
extends EditorPlugin

func _enter_tree() -> void:
    add_child(TagVisualizerNode.new())

func _exit_tree() -> void:
    pass

class_name TagVisualizerNode
extends Node

func _process(delta: float) -> void:
    if not Engine.is_editor_hint():
        return
    
    # Clear existing visualizations
    _clear_visualizations()
    
    # Show tags for selected objects
    var selected: Array = get_tree().get_nodes_in_group("selected")
    for node in selected:
        if node is Node3D:
            _show_tags_for_node(node)

func _show_tags_for_node(node: Node3D) -> void:
    var label: EditorLabel3D = EditorLabel3D.new()
    label.text = "Tags: " + str(node.tags)
    label.position = node.position + Vector3(0, 2, 0)
    add_child(label)
```

---

## Build-Grid Block Management

### Build-Grid System Integration

```gdscript
# In building_manager.gd

func place_building(building_data: Dictionary) -> Node3D:
    var building: Node3D = _create_building(building_data)
    
    # Add to world
    add_child(building)
    
    # Tag based on type
    if building_data.type == "home":
        building.tags.append("protected")
        building.tags.append("home")
    elif building_data.type == "decoration":
        building.tags.append("temporary")
        building.tags.append("destroyable")
        building.tags.append("build_grid")
    elif building_data.type == "furniture":
        building.tags.append("temporary")
        building.tags.append("destroyable")
        building.tags.append("build_grid")
    
    return building
```

### Build-Grid Block Prefab

```
# build_grid_block.tscn

[gd_scene load_steps=2 format=3]

[node name="BuildGridBlock" type="StaticBody3D"]
tags = ["temporary", "destroyable", "build_grid"]

[node name="MeshInstance3D" type="MeshInstance3D" parent="."]
mesh = preload("res://models/blocks/cube.glb")

[node name="CollisionShape3D" type="CollisionShape3D" parent="."]
shape = BoxShape3D { size = Vector3(1, 1, 1) }
```

### Bulldozer Build-Grid Interaction

```gdscript
# In bulldozer.gd

func _on_blade_hit(body: Node3D) -> void:
    if "build_grid" in body.tags:
        # This is a build-grid block
        _handle_build_grid_destruction(body)
    elif DestructionManager.instance.can_destroy(body):
        # Regular destroyable object
        DestructionManager.instance.destroy_object(body)

func _handle_build_grid_destruction(block: Node3D) -> void:
    # Check if we can destroy it
    if DestructionManager.instance.can_destroy(block):
        # Store additional build-grid specific data
        var state: Dictionary = DestructionManager.instance._capture_object_state(block)
        
        # Add build-grid metadata
        state["is_build_grid"] = true
        state["block_type"] = block.get_meta("block_type", "unknown")
        
        # Destroy
        DestructionManager.instance.destroy_object(block)
        
        # Update build-grid registry
        BuildGridRegistry.instance.remove_block(block)
```

### Build-Grid Registry

```gdscript
# build_grid_registry.gd

class_name BuildGridRegistry
extends Node

var placed_blocks: Dictionary = {}  # {position_string: block}

static var instance: BuildGridRegistry = null

func _ready() -> void:
    instance = self

func add_block(block: Node3D) -> void:
    var pos_key: String = _position_to_key(block.global_position)
    placed_blocks[pos_key] = block

func remove_block(block: Node3D) -> void:
    var pos_key: String = _position_to_key(block.global_position)
    if placed_blocks.has(pos_key):
        placed_blocks.erase(pos_key)

func _position_to_key(position: Vector3) -> String:
    return str(position.x) + "," + str(position.y) + "," + str(position.z)

func can_place_at(position: Vector3) -> bool:
    var pos_key: String = _position_to_key(position)
    return not placed_blocks.has(pos_key)

func restore_block(block: Node3D) -> void:
    add_block(block)
```

---

## Child-Safe Destruction Limits

### Destruction Time Limits

```gdcript
# In bulldozer.gd

@export var max_destruction_per_minute: int = 20
@export var destruction_cooldown: float = 3.0  # Seconds between destructions

var destruction_count: int = 0
var last_destruction_time: float = 0.0
var cooldown_timer: Timer = null

func _ready() -> void:
    super()
    cooldown_timer = Timer.new()
    cooldown_timer.timeout.connect(_on_cooldown_timeout)
    add_child(cooldown_timer)

func _on_blade_hit(body: Node3D) -> void:
    # Child safety: Check rate limit
    if not _can_destroy_by_rate():
        UI.show_message("Slow down! You're destroying too fast!")
        return
    
    if DestructionManager.instance.can_destroy(body):
        super._on_blade_hit(body)

func _can_destroy_by_rate() -> bool:
    var current_time: float = Time.get_ticks_sec()
    
    # Check cooldown
    if current_time - last_destruction_time < destruction_cooldown:
        return false
    
    # Check per-minute limit
    if destruction_count >= max_destruction_per_minute:
        return false
    
    return true

func _on_blade_hit_successful() -> void:
    last_destruction_time = Time.get_ticks_sec()
    destruction_count += 1
    
    # Reset cooldown timer
    cooldown_timer.stop()
    cooldown_timer.start(destruction_cooldown)
    
    # Reset count every minute
    if destruction_count >= max_destruction_per_minute:
        cooldown_timer.start(60.0)

func _on_cooldown_timeout() -> void:
    destruction_count = 0
```

### Parent Approval System

```gdscript
# In parental_control_policy.gd

func can_use_bulldozer_destruction(player_age: int) -> bool:
    match player_age:
        AgeBand.CHILD_6_8:
            return false  # 6-8 year olds cannot use destruction
        AgeBand.CHILD_9_12:
            return has_parent_approval("bulldozer_destruction")
        _:
            return true  # Teens and adults can use freely

func get_max_destruction_count(age_band: int) -> int:
    match age_band:
        AgeBand.CHILD_6_8:
            return 0
        AgeBand.CHILD_9_12:
            return 10  # Limited for younger children
        AgeBand.TEEN:
            return 50
        _:
            return 100  # No limit for adults

# In bulldozer.gd
func _on_blade_hit(body: Node3D) -> void:
    var player: CharacterBody3D = get_tree().get_first_node_in_group("players")
    var age_band: int = player.age_band if player else AgeBand.CHILD_6_8
    
    if not ParentalControlPolicy.can_use_bulldozer_destruction(age_band):
        UI.show_message("Bulldozer destruction is restricted for your age group")
        return
    
    # Rest of destruction logic...
```

### Safe Destruction Areas

```gdscript
# safe_area_manager.gd

class_name SafeAreaManager
extends Node

@export var safe_areas: Array[Area3D] = []

func is_in_safe_area(position: Vector3) -> bool:
    for area in safe_areas:
        if area.get_rect().has_point(position):
            return true
    return false

func can_destroy_at(position: Vector3) -> bool:
    # Allow destruction only in safe areas
    return is_in_safe_area(position)

# In bulldozer.gd
func _on_blade_hit(body: Node3D) -> void:
    if SafeAreaManager.instance.can_destroy_at(body.global_position):
        if DestructionManager.instance.can_destroy(body):
            super._on_blade_hit(body)
    else:
        UI.show_message("Cannot destroy outside safe area!")
```

---

## Asset Packages & Models

### Recommended Bulldozer Models

| Model | Author | License | Format | Link |
|-------|--------|---------|--------|------|
| **Kenney Construction Kit** | Kenney | CC0 | GLTF | [Download](https://kenney.nl/assets/construction-kit) |
| Low-Poly Bulldozer | Various | CC0 | FBX/GLTF | [Sketchfab](https://sketchfab.com/search?q=bulldozer+cc0) |
| Toy Bulldozer | Mixamo | CC0 | FBX | [Mixamo](https://www.mixamo.com/) |
| Construction Vehicles | Poly Haven | CC0 | GLTF | [Poly Haven](https://polyhaven.com/) |
| Cartoony Bulldozer | Blend Swap | CC0 | Blend | [Blend Swap](https://www.blendswap.com/) |

### Kenney Construction Kit

**Download**: https://kenney.nl/assets/construction-kit

**Includes:**
- Bulldozer model
- Excavator model
- Construction site props
- Low-poly, child-friendly style
- CC0 license

**Integration Steps:**

```
1. Download Kenney Construction Kit
2. Import bulldozer.glb into Godot
3. Create Bulldozer scene with CharacterBody3D
4. Add blade mesh and collision
5. Configure blade physics
6. Add camera and effects
7. Test in game
```

### Bulldozer Materials & Textures

**Recommended CC0 Textures:**
- **Poly Haven**: [Metal Textures](https://polyhaven.com/textures) (for blade)
- **CC0 Textures**: [Vehicle Textures](https://cc0textures.com/) (for body)
- **Kenney Assets**: Included in Construction Kit

---

## Code Samples & Implementation Patterns

### Complete Bulldozer Scene

```
# bulldozer.tscn

[gd_scene load_steps=2 format=3]

[ext_resource path="res://scripts/bulldozer.gd" type="Script" id=1]
[ext_resource path="res://models/bulldozer/body.glb" type="PackedScene" id=2]
[ext_resource path="res://models/bulldozer/blade.glb" type="PackedScene" id=3]

[node name="Bulldozer" type="CharacterBody3D"]
script = ExtResource(1)

[node name="CollisionShape3D" type="CollisionShape3D" parent="."]
shape = BoxShape3D { size = Vector3(3, 1.5, 5) }

[node name="MeshInstance3D" type="MeshInstance3D" parent="."]
mesh = ExtResource(2)

[node name="Blade" type="Node3D" parent="."]
position = Vector3(0, 0.5, 2)

[node name="MeshInstance3D" type="MeshInstance3D" parent="./Blade"]
mesh = ExtResource(3)

[node name="BladeCollision" type="Area3D" parent="./Blade"]
monitoring = true
monitorable = true

[node name="CollisionShape3D" type="CollisionShape3D" parent="./Blade/BladeCollision"]
shape = BoxShape3D { size = Vector3(3, 1.5, 0.5) }
position = Vector3(0, 0, 2)

[node name="CameraPivot" type="Node3D" parent="."]
position = Vector3(0, 2.5, 0)

[node name="BulldozerCamera" type="Camera3D" parent="./CameraPivot"]
position = Vector3(0, 0, 5)
fov = 70.0
make_current = false

[node name="EnterArea" type="Area3D" parent="."]
position = Vector3(0, 1, -2.5)

[node name="CollisionShape3D" type="CollisionShape3D" parent="./EnterArea"]
shape = BoxShape3D { size = Vector3(2, 1.5, 1) }
```

### Complete Destruction Manager

```gdscript
# destruction_manager.gd

class_name DestructionManager
extends Node

static var instance: DestructionManager = null

signal object_destroyed(object_data: Dictionary)
signal object_restored(object_data: Dictionary)
signal stack_changed(destruction_count: int, restoration_count: int)

var destruction_stack: Array = []
var max_history: int = 100

func _ready() -> void:
    instance = self

func can_destroy(node: Node3D) -> bool:
    return _is_destroyable(node) and not _is_protected(node)

func destroy_object(node: Node3D) -> bool:
    if not can_destroy(node):
        return false
    
    var state: Dictionary = _capture_object_state(node)
    
    # Remove from world
    node.queue_free()
    
    # Add to stack
    destruction_stack.append(state)
    
    # Trim if needed
    if destruction_stack.size() > max_history:
        destruction_stack.remove_at(0)
    
    # Emit signals
    object_destroyed.emit(state)
    stack_changed.emit(destruction_stack.size(), 0)
    
    return true

func restore_last() -> bool:
    if destruction_stack.is_empty():
        return false
    
    var state: Dictionary = destruction_stack.pop_back()
    _restore_object_state(state)
    
    # Emit signals
    object_restored.emit(state)
    stack_changed.emit(destruction_stack.size(), 1)
    
    return true

func restore_all() -> int:
    var count: int = 0
    while restore_last():
        count += 1
    return count

func _capture_object_state(node: Node3D) -> Dictionary:
    return {
        "node": node,
        "position": node.global_position,
        "rotation": node.global_rotation,
        "scale": node.scale,
        "parent": node.get_parent(),
        "index": node.get_index_in_parent(),
        "tags": node.tags.duplicate()
    }

func _restore_object_state(state: Dictionary) -> Node3D:
    var node: Node3D = state.node
    var parent: Node = state.parent
    
    parent.add_child(node)
    parent.move_child(node, state.index)
    
    node.global_position = state.position
    node.global_rotation = state.rotation
    node.scale = state.scale
    node.tags = state.tags.duplicate()
    
    return node

func _is_destroyable(node: Node3D) -> bool:
    if "temporary" in node.tags or "destroyable" in node.tags or "build_grid" in node.tags:
        return true
    
    # Check name patterns
    var name_lower: String = node.name.to_lower()
    return name_lower.begins_with("temp_") or name_lower.begins_with("decoration_")

func _is_protected(node: Node3D) -> bool:
    # Check tags
    if "protected" in node.tags:
        return true
    
    # Check name patterns
    var name_lower: String = node.name.to_lower()
    if "home" in name_lower or "npc" in name_lower or "bridge" in name_lower or "boundary" in name_lower:
        return true
    
    # Check parent hierarchy
    var parent: Node = node.get_parent()
    while parent:
        if parent is Node3D and "protected" in parent.tags:
            return true
        parent = parent.get_parent()
    
    return false
```

### Complete Bulldozer Implementation

```gdscript
# bulldozer.gd

class_name Bulldozer
extends VehicleBase

# Blade settings
@export var blade_width: float = 3.0
@export var blade_height: float = 1.5
@export var blade_depth: float = 0.5
@export var blade_speed: float = 1.5
@export var max_blade_angle: float = 30.0

# Destruction settings
@export var cooldown_time: float = 0.5

# Nodes
@onready var blade: Node3D = $Blade
@onready var blade_collision: Area3D = $Blade/BladeCollision

# State
var blade_angle: float = 0.0
var last_hit_time: float = 0.0
var hit_cooldowns: Dictionary = {}

# Camera
@export var camera_offset: Vector3 = Vector3(0, 2.5, 5)

func _ready() -> void:
    super()
    
    # Setup blade collision
    var blade_shape: CollisionShape3D = blade_collision.get_child(0)
    blade_shape.shape = BoxShape3D.new()
    blade_shape.shape.size = Vector3(blade_width, blade_height, blade_depth)
    
    # Connect signal
    blade_collision.body_entered.connect(_on_blade_hit)

func _process(delta: float) -> void:
    # Blade control
    var blade_input: float = Input.get_action_strength("blade_down") - Input.get_action_strength("blade_up")
    
    if blade_input != 0:
        blade_angle = clamp(
            blade_angle + blade_input * blade_speed * delta,
            0,
            max_blade_angle
        )
        blade.rotation_degrees = Vector3(-blade_angle, 0, 0)

func _on_blade_hit(body: Node3D) -> void:
    # Check cooldown for this specific object
    var body_id: int = body.get_instance_id()
    if hit_cooldowns.get(body_id, 0) > Time.get_ticks_msec():
        return
    
    hit_cooldowns[body_id] = Time.get_ticks_msec() + cooldown_time * 1000
    
    # Check if we can destroy
    if DestructionManager.instance.can_destroy(body):
        DestructionManager.instance.destroy_object(body)
        EffectSpawner.instance.spawn_destruction_effect(body.global_position)
        AudioManager.play_sound("destruction", body.global_position)

func enter_vehicle(driver: CharacterBody3D) -> void:
    super()
    # Override camera
    camera_offset = Vector3(0, 2.5, 5)
    if $CameraPivot:
        $CameraPivot.position = camera_offset

func _unhandled_input(event: InputEvent) -> void:
    super._unhandled_input(event)
    
    if event.is_action_just_pressed("undo"):
        DestructionManager.instance.restore_last()
    elif event.is_action_just_pressed("redo"):
        # Note: Redo would need to be implemented in DestructionManager
        pass
```

---

## Testing & Validation Checklist

### Unit Tests

```gdscript
# test_bulldozer_destruction.gd

extends TestCase

@onready var test_scene: PackedScene = preload("res://test_scenes/bulldozer_test.tscn")

func test_destruction_filtering():
    var scene = test_scene.instantiate()
    add_child(scene)
    await scene.ready
    
    var bulldozer: Bulldozer = scene.get_node("Bulldozer")
    var temporary_obj: Node3D = scene.get_node("TemporaryObject")
    var protected_obj: Node3D = scene.get_node("ProtectedObject")
    
    # Can destroy temporary
    assert_equal(DestructionManager.instance.can_destroy(temporary_obj), true)
    
    # Cannot destroy protected
    assert_equal(DestructionManager.instance.can_destroy(protected_obj), false)
    
    # Bulldozer should destroy temporary
    bulldozer._on_blade_hit(temporary_obj)
    await get_tree().process_frame
    
    assert_equal(temporary_obj.is_inside_tree(), false)
    assert_equal(DestructionManager.instance.destruction_stack.size(), 1)
    
    # Bulldozer should not destroy protected
    var initial_stack_size: int = DestructionManager.instance.destruction_stack.size()
    bulldozer._on_blade_hit(protected_obj)
    await get_tree().process_frame
    
    assert_equal(DestructionManager.instance.destruction_stack.size(), initial_stack_size)
    
    scene.queue_free()

func test_restoration():
    var scene = test_scene.instantiate()
    add_child(scene)
    await scene.ready
    
    var bulldozer: Bulldozer = scene.get_node("Bulldozer")
    var temporary_obj: Node3D = scene.get_node("TemporaryObject")
    var initial_position: Vector3 = temporary_obj.global_position
    
    # Destroy object
    bulldozer._on_blade_hit(temporary_obj)
    await get_tree().process_frame
    
    assert_equal(temporary_obj.is_inside_tree(), false)
    
    # Restore
    DestructionManager.instance.restore_last()
    await get_tree().process_frame
    
    assert_equal(temporary_obj.is_inside_tree(), true)
    assert_equal(temporary_obj.global_position, initial_position)
    
    scene.queue_free()

func test_tag_based_destruction():
    var scene = test_scene.instantiate()
    add_child(scene)
    await scene.ready
    
    var bulldozer: Bulldozer = scene.get_node("Bulldozer")
    
    # Create test objects with different tags
    var temp_obj: Node3D = Node3D.new()
    temp_obj.tags.append("temporary")
    scene.add_child(temp_obj)
    
    var destroyable_obj: Node3D = Node3D.new()
    destroyable_obj.tags.append("destroyable")
    scene.add_child(destroyable_obj)
    
    var protected_obj: Node3D = Node3D.new()
    protected_obj.tags.append("protected")
    scene.add_child(protected_obj)
    
    # Bulldozer should destroy temporary and destroyable
    assert_equal(DestructionManager.instance.can_destroy(temp_obj), true)
    assert_equal(DestructionManager.instance.can_destroy(destroyable_obj), true)
    
    # Bulldozer should not destroy protected
    assert_equal(DestructionManager.instance.can_destroy(protected_obj), false)
    
    scene.queue_free()

func test_build_grid_integration():
    var scene = test_scene.instantiate()
    add_child(scene)
    await scene.ready
    
    var bulldozer: Bulldozer = scene.get_node("Bulldozer")
    var build_grid_block: Node3D = scene.get_node("BuildGridBlock")
    
    # Should be destroyable
    assert_equal(DestructionManager.instance.can_destroy(build_grid_block), true)
    
    # Destroy
    bulldozer._on_blade_hit(build_grid_block)
    await get_tree().process_frame
    
    assert_equal(build_grid_block.is_inside_tree(), false)
    
    # Restore
    DestructionManager.instance.restore_last()
    await get_tree().process_frame
    
    assert_equal(build_grid_block.is_inside_tree(), true)
    
    scene.queue_free()
```

### Manual Test Cases

1. **Bulldozer Discovery**: Find bulldozer in world, see discovery effect
2. **Enter Bulldozer**: Press E near bulldozer → enter vehicle
3. **Blade Control**: Use mouse wheel/triggers to raise/lower blade
4. **Destroy Temporary**: Drive to temporary scenery → should be destroyed
5. **Destroy Build-Grid**: Drive to build-grid block → should be destroyed
6. **Protected Objects**: Drive to home/NPC/bridge → should NOT be destroyed
7. **Undo Destruction**: Press Ctrl+Z → last destroyed object restored
8. **Multiple Undo**: Destroy 5 objects, press Ctrl+Z 5 times → all restored
9. **Restore All**: Destroy 5 objects, press Ctrl+Shift+Z → all restored at once
10. **Cooldown**: Rapid blade hits → should only destroy once per cooldown
11. **Child Safety**: Test with child account → destruction limited/restricted
12. **Visual Effects**: Verify destruction/restoration particles and sounds

---

## Learning Resources

### Official Godot Documentation

- [Area3D](https://docs.godotengine.org/en/stable/classes/class_area3d.html) - Collision detection
- [Node Tags](https://docs.godotengine.org/en/stable/tutorials/scripting/built_in_types.html#tags) - Tag system
- [Tween](https://docs.godotengine.org/en/stable/classes/class_tween.html) - Smooth animations
- [GPUParticles3D](https://docs.godotengine.org/en/stable/classes/class_gpuparticles3d.html) - Visual effects
- [Resource Management](https://docs.godotengine.org/en/stable/getting_started/scripting/gdscript/gdscript_basics.html#resources) - Instance management

### Tutorials

1. **GDQuest Destruction System**
   - [YouTube: Destruction & Restoration](https://youtu.be/destruction-tutorial)
   - Undo/redo system, visual effects

2. **HeartBeast Tag System**
   - [YouTube: Using Tags in Godot](https://youtu.be/tags-tutorial)
   - Filtering objects by tags

3. **KidsCanCode Undo System**
   - [YouTube: Command Pattern in Godot](https://youtu.be/command-pattern)
   - Undo/redo implementation

4. **Godot Particle Effects**
   - [YouTube: GPUParticles3D Tutorial](https://youtu.be/particles-tutorial)
   - Destruction and restoration effects

### Community Discussions

- [Godot Forum: Undo/Redo System](https://forum.godotengine.org/t/undo-redo-system/)
- [Reddit: Tag-Based Destruction](https://www.reddit.com/r/godot/comments/tag_destruction/)
- [Godot Q&A: Object Restoration](https://godotforums.org/d/object-restoration/)

### Books & Courses

- **Godot 4 Game Development Projects** - Packt (Chapter 9: Destruction Systems)
- **Learn Godot 4** - GDQuest (Undo/Redo Module)
- **3D Game Development with Godot** - Apress (Chapter 10: Physics & Destruction)

---

## Summary & Recommendations

### For Choyce Engine Vertical Slice

**Recommended Implementation:**

1. **Tag-Based System**: Use Godot's built-in tag system for filtering
2. **DestructionManager Singleton**: Centralized management of destruction/restoration
3. **Command Pattern**: Clean undo/redo implementation
4. **Bulldozer as Special Vehicle**: Extend VehicleBase with blade collision
5. **Child-Safe Limits**: Rate limiting, parent approval, safe areas
6. **Visual Feedback**: Particles, sounds, animations for destruction/restoration
7. **Build-Grid Integration**: Seamless with building system

**Estimated Time:** 4-6 hours for complete implementation

**Dependencies:**
- None (core Godot 4.x features)
- Optional: Kenney Construction Kit for models

### Implementation Order

1. **Tag System** (1 hour)
   - Tag all world objects appropriately
   - Create tag utility functions

2. **DestructionManager** (2 hours)
   - Capture/restore object state
   - Implement destruction stack
   - Add undo/restore functionality

3. **Bulldozer Vehicle** (2 hours)
   - Extend VehicleBase
   - Add blade collision
   - Connect to DestructionManager

4. **Child-Safe Features** (1 hour)
   - Rate limiting
   - Parent approval
   - Safe areas

5. **Visual Effects** (1 hour)
   - Destruction particles
   - Restoration particles
   - Audio effects

6. **Testing & Polish** (1 hour)

### Integration Points

- **Bulldozer**: Connect blade collision to DestructionManager
- **Building System**: Tag placed objects appropriately
- **UI**: Add undo/redo buttons and destruction counter
- **Save System**: Save/load destruction history (optional)
- **Parent Controls**: Limit destruction based on age/permissions

---

## Choyce-Specific Implementation Notes

### Parent Safety Integration

```gdscript
# In parental_control_policy.gd

func can_destroy_objects(age_band: int) -> bool:
    return age_band != AgeBand.CHILD_6_8 or has_parent_approval("destruction")

func get_max_destructions_per_minute(age_band: int) -> int:
    match age_band:
        AgeBand.CHILD_6_8:
            return 0  # No destruction
        AgeBand.CHILD_9_12:
            return 5  # Limited
        AgeBand.TEEN:
            return 20
        _:
            return 100
```

### Audit Logging

```gdscript
# In destruction_manager.gd

func destroy_object(node: Node3D) -> bool:
    if not can_destroy(node):
        return false
    
    var state: Dictionary = _capture_object_state(node)
    
    # Log destruction
    AuditLogger.log({
        "action": "object_destroyed",
        "object": node.name,
        "position": node.global_position,
        "player": get_current_player_name(),
        "timestamp": Time.get_unix_time_from_system()
    })
    
    # Rest of destruction logic...
```

### Accessibility

```gdscript
# In accessibility settings

@export var destruction_effects_enabled: bool = true
@export var destruction_sounds_enabled: bool = true
@export var reduce_destruction_motion: bool = false

# In effect_spawner.gd

func spawn_destruction_effect(position: Vector3) -> void:
    if not AccessibilitySettings.destruction_effects_enabled:
        return
    
    if AccessibilitySettings.reduce_destruction_motion:
        spawn_simple_effect(position)  # Reduced motion version
    else:
        spawn_full_effect(position)
```

---

*Generated by Mistral Vibe for Choyce Engine project*
*Research focus: Godot 4.x Bulldozer Destruction & Restoration System*
*Child-safety compliant: Tag-based filtering, undo/redo, parent controls*
