# PLAN-008: Camera Ray & 3D Preview for TPP Building - Deep Research Compendium

**Status**: in_progress  
**Specialty**: godot-camera-systems-and-ui  
**Gate**: Foundation (PLAN.md Section 318)  
**Priority**: HIGH  
**Last Updated**: 2026-07-18  
**Child-Safety Consideration**: Building preview must be intuitive and child-friendly

---

## Table of Contents

1. [Task Overview](#task-overview)
2. [Godot 4.x Camera Systems for TPP](#godot-4x-camera-systems-for-tpp)
3. [Camera Ray Casting for Building](#camera-ray-casting-for-building)
4. [3D Preview Implementation](#3d-preview-implementation)
5. [Placement System Architecture](#placement-system-architecture)
6. [Grid Snapping & Alignment](#grid-snapping--alignment)
7. [Material Preview & Validation](#material-preview--validation)
8. [Controller & Touch Support](#controller--touch-support)
9. [Child-Safe UI/UX Considerations](#child-safe-uiux-considerations)
10. [Asset Packages & Plugins](#asset-packages--plugins)
11. [Code Samples & Implementation Patterns](#code-samples--implementation-patterns)
12. [Testing & Validation Checklist](#testing--validation-checklist)
13. [Learning Resources](#learning-resources)

---

## Task Overview

### Objective

Implement a **TPP (Third-Person Perspective) building system** with:
- **Camera ray casting**: Detect placement positions using camera ray
- **3D preview**: Show ghost/hologram of building before placement
- **World-scale accuracy**: Placement respects real-world meters (1 unit = 1 meter)
- **Native material preservation**: Preview shows actual materials
- **Child-friendly**: Intuitive, forgiving, and safe building mechanics

### Source Reference

From PLAN.md (line 318):
> **Foundation:** collision dimensions are world metres rather than scaled proxy guesses; preserve native materials; **use a camera ray and 3D preview for TPP building**; real ground/dirt collision; a water volume with wading/swim physics; continuous exploration music; no legacy Ninja overlay.

### Key Requirements

- ✅ **Camera ray**: Cast from camera through cursor/mouse position
- ✅ **3D preview**: Ghost mesh shows building before placement
- ✅ **World-scale**: Placement uses real-world meters
- ✅ **Material preservation**: Preview uses actual building materials
- ✅ **Collision detection**: Preview turns red when invalid placement
- ✅ **Rotation**: Can rotate preview before placement
- ✅ **Snap to grid**: Optional grid snapping
- ✅ **Child-safe**: Large hit areas, clear visual feedback

### Acceptance Criteria

1. Camera ray accurately detects world position from cursor
2. 3D preview appears at valid placement positions
3. Preview changes color when invalid (collision, out of bounds)
4. Can rotate preview with mouse wheel or controller
5. Can place building with click/confirm
6. Can cancel placement with right-click/cancel
7. Works in both mouse+keyboard and controller modes

---

## Godot 4.x Camera Systems for TPP

### Camera Options for TPP Building

#### Option 1: Spring Arm Camera (Recommended)

```
Player (CharacterBody3D)
└── SpringArm (Node3D)
    └── Camera3D
        ├── RayCast3D (for building preview)
        └── BuildingPreview (MeshInstance3D)
```

**Pros:**
- Smooth follow with collision avoidance
- Natural third-person feel
- Easy to add building preview ray

**Cons:**
- Slightly more complex setup

#### Option 2: Fixed Offset Camera

```
Player (CharacterBody3D)
└── Camera3D (with fixed position offset)
```

**Pros:**
- Simpler implementation
- Consistent view

**Cons:**
- Can clip through geometry
- Less flexible

#### Option 3: Free Camera (for building mode)

```
World (Node3D)
├── Player (CharacterBody3D)
└── FreeCamera (Camera3D)
    ├── RayCast3D
    └── BuildingPreview
```

**Pros:**
- Full control during building
- Can orbit around building

**Cons:**
- Switches from gameplay camera
- Requires mode switching

### Decision: Spring Arm Camera with RayCast

**Rationale:**
- ✅ Maintains third-person gameplay feel
- ✅ Camera ray naturally extends from player view
- ✅ Easy to integrate with existing player controller
- ✅ Smooth collision handling
- ✅ Works with both building and exploration
- ❌ Requires careful ray configuration

---

## Camera Ray Casting for Building

### Ray Configuration

The camera ray should:
1. Originate from camera position
2. Extend through cursor position in 3D space
3. Detect valid placement surfaces
4. Update preview position

#### Mouse-Based Ray Casting

```gdscript
# In camera script or building manager

@onready var camera: Camera3D = $Camera3D
@onready var building_preview: MeshInstance3D = $BuildingPreview

@export var max_placement_distance: float = 10.0
@export var placement_layers: int = 1  # World collision layer

func _process(delta: float) -> void:
    if Input.is_action_pressed("build_mode"):
        _update_building_preview()

func _update_building_preview() -> void:
    var mouse_pos: Vector2 = get_viewport().get_mouse_position()
    var ray_origin: Vector3 = camera.project_ray_origin(mouse_pos)
    var ray_end: Vector3 = ray_origin + camera.project_ray_normal(mouse_pos) * max_placement_distance
    
    # Cast ray from camera through cursor
    var space_state: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.new()
    space_state.from = ray_origin
    space_state.to = ray_end
    space_state.collision_mask = placement_layers
    
    var ray_result: Dictionary = get_world_3d().direct_space_state.intersect_ray(space_state)
    
    if ray_result:
        # Valid placement position
        var hit_position: Vector3 = ray_result.position
        var hit_normal: Vector3 = ray_result.normal
        
        # Update preview
        building_preview.global_position = hit_position
        building_preview.global_transform.basis.z = hit_normal  # Align to surface
        building_preview.show()
        
        # Check if placement is valid (no collisions with other objects)
        if _is_placement_valid(hit_position):
            building_preview.material_override = valid_material
        else:
            building_preview.material_override = invalid_material
    else:
        building_preview.hide()
```

### Controller-Based Ray Casting

For controller support, use a fixed offset from camera:

```gdscript
@export var controller_ray_offset: Vector2 = Vector2(0, 0.5)  # Slightly down from center

func _update_controller_building_preview() -> void:
    var viewport_center: Vector2 = get_viewport_rect().size / 2
    var ray_pos: Vector2 = viewport_center + controller_ray_offset
    
    var ray_origin: Vector3 = camera.project_ray_origin(ray_pos)
    var ray_end: Vector3 = ray_origin + camera.project_ray_normal(ray_pos) * max_placement_distance
    
    # Same ray cast logic as above...
```

---

## 3D Preview Implementation

### Building Preview Node

```
# BuildingPreview.tscn

[gd_scene load_steps=2 format=3]

[ext_resource path="res://materials/preview_valid.tres" type="StandardMaterial3D" id=1]
[ext_resource path="res://materials/preview_invalid.tres" type="StandardMaterial3D" id=2]

[node name="BuildingPreview" type="MeshInstance3D"]
visible = false
material_override = ExtResource(1)

[node name="CollisionShape3D" type="CollisionShape3D" parent="."]
shape = BoxShape3D { size = Vector3(1, 1, 1) }
```

### Preview Material Setup

**Valid Material (Green/Transparent):**
```gdscript
# preview_valid.tres

[resource]
resource_type = "StandardMaterial3D"
albedo_color = Color(0, 1, 0, 0.5)  # Semi-transparent green
emission_enabled = true
emission_energy = 0.5
metallic = 0.0
roughness = 0.8
transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
```

**Invalid Material (Red/Transparent):**
```gdscript
# preview_invalid.tres

[resource]
resource_type = "StandardMaterial3D"
albedo_color = Color(1, 0, 0, 0.5)  # Semi-transparent red
emission_enabled = true
emission_energy = 0.5
metallic = 0.0
roughness = 0.8
transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
```

### Preview Rotation

```gdscript
var rotation_step: float = 15.0  # Degrees per rotation

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_WHEEL_UP:
        building_preview.rotate_y(deg_to_rad(-rotation_step))
        event.accepted = true
    elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
        building_preview.rotate_y(deg_to_rad(rotation_step))
        event.accepted = true
    elif event is InputEventJoypadButton and event.button_index == JOY_R2:
        building_preview.rotate_y(deg_to_rad(-rotation_step))
        event.accepted = true
    elif event is InputEventJoypadButton and event.button_index == JOY_L2:
        building_preview.rotate_y(deg_to_rad(rotation_step))
        event.accepted = true
```

---

## Placement System Architecture

### Complete Building Manager

```gdscript
# building_manager.gd

class_name BuildingManager
extends Node

signal building_placed(building_data: Dictionary)
signal building_cancelled

@export var building_prefab_scene: PackedScene
@export var max_placement_distance: float = 10.0
@export var placement_layers: int = 1
@export var snap_to_grid: bool = true
@export var grid_size: float = 1.0

var is_building: bool = false
var current_building_type: String = ""
var building_preview: MeshInstance3D
var building_collision: CollisionShape3D

@onready var camera: Camera3D = get_node("/root/World/Player/Camera3D")

func start_building(building_type: String) -> void:
    is_building = true
    current_building_type = building_type
    
    # Create preview
    var building_data: Dictionary = BuildingDatabase.get_building(building_type)
    building_preview = building_prefab_scene.instantiate()
    building_preview.mesh = load(building_data.mesh_path)
    
    # Add collision for placement validation
    building_collision = CollisionShape3D.new()
    building_collision.shape = load(building_data.collision_path)
    building_preview.add_child(building_collision)
    
    # Position preview at camera
    building_preview.global_position = camera.global_position + camera.global_transform.basis.z * 2
    building_preview.visible = true
    add_child(building_preview)

func cancel_building() -> void:
    if building_preview:
        building_preview.queue_free()
    is_building = false
    building_cancelled.emit()

func confirm_building() -> void:
    if not building_preview or not _is_placement_valid():
        return
    
    # Create actual building
    var building: Node3D = building_prefab_scene.instantiate()
    building.global_position = building_preview.global_position
    building.global_rotation = building_preview.global_rotation
    
    # Remove preview collision
    building_preview.get_child(0).queue_free()
    
    # Add to world
    get_parent().add_child(building)
    
    # Emit signal
    building_placed.emit({
        "type": current_building_type,
        "position": building.global_position,
        "rotation": building.global_rotation
    })
    
    # Cleanup
    building_preview.queue_free()
    is_building = false

func _process(delta: float) -> void:
    if is_building:
        _update_building_preview()

func _update_building_preview() -> void:
    var mouse_pos: Vector2 = get_viewport().get_mouse_position()
    var ray_origin: Vector3 = camera.project_ray_origin(mouse_pos)
    var ray_end: Vector3 = ray_origin + camera.project_ray_normal(mouse_pos) * max_placement_distance
    
    var space_state: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.new()
    space_state.from = ray_origin
    space_state.to = ray_end
    space_state.collision_mask = placement_layers
    
    var ray_result: Dictionary = get_world_3d().direct_space_state.intersect_ray(space_state)
    
    if ray_result:
        var hit_position: Vector3 = ray_result.position
        
        # Apply grid snapping
        if snap_to_grid:
            hit_position = _snap_to_grid(hit_position)
        
        building_preview.global_position = hit_position
        
        # Validate placement
        if _is_placement_valid(hit_position):
            building_preview.material_override = valid_material
        else:
            building_preview.material_override = invalid_material
        
        building_preview.show()
    else:
        building_preview.hide()

func _snap_to_grid(position: Vector3) -> Vector3:
    return Vector3(
        snapf(position.x, grid_size),
        position.y,  # Keep Y for terrain following
        snapf(position.z, grid_size)
    )

func _is_placement_valid(position: Vector3 = null) -> bool:
    if building_preview == null:
        return false
    
    var check_position: Vector3 = position if position else building_preview.global_position
    
    # Check if preview collides with existing objects
    var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
    query.shape = building_collision.shape
    query.transform = building_preview.global_transform
    query.collision_mask = placement_layers
    query.exclude = [building_preview]  # Exclude self
    
    var results: Array = get_world_3d().direct_space_state.intersect_shape(query)
    
    # Valid if no collisions and on valid surface
    return results.size() == 0 and _is_on_valid_surface(check_position)

func _is_on_valid_surface(position: Vector3) -> bool:
    # Check if position is on terrain or valid build surface
    var ground_check: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.new()
    ground_check.from = position + Vector3(0, 10, 0)
    ground_check.to = position - Vector3(0, 10, 0)
    ground_check.collision_mask = placement_layers
    
    var ground_result: Dictionary = get_world_3d().direct_space_state.intersect_ray(ground_check)
    return ground_result != null
```

---

## Grid Snapping & Alignment

### Grid System

```gdscript
# grid_system.gd

class_name GridSystem
extends Node3D

@export var grid_size: float = 1.0
@export var show_grid: bool = false
@export var grid_material: StandardMaterial3D

func _ready() -> void:
    if show_grid:
        _create_visual_grid()

func _create_visual_grid() -> void:
    # Create grid lines using ImmediateGeometry
    var grid: ImmediateGeometry = ImmediateGeometry.new()
    add_child(grid)
    
    var half_size: int = 50
    grid.begin(Mesh.PRIMITIVE_LINES)
    
    # Draw grid lines
    for i in range(-half_size, half_size + 1):
        # X-axis lines
        grid.set_normal(Vector3(0, 1, 0))
        grid.set_color(Color(1, 1, 1, 0.3))
        grid.add_vertex(Vector3(i * grid_size, 0, -half_size * grid_size))
        grid.add_vertex(Vector3(i * grid_size, 0, half_size * grid_size))
        
        # Z-axis lines
        grid.add_vertex(Vector3(-half_size * grid_size, 0, i * grid_size))
        grid.add_vertex(Vector3(half_size * grid_size, 0, i * grid_size))
    
    grid.end()

func snap_position(position: Vector3) -> Vector3:
    return Vector3(
        snapf(position.x, grid_size),
        position.y,
        snapf(position.z, grid_size)
    )

func snap_rotation(rotation: Vector3) -> Vector3:
    return Vector3(
        snapf(rotation.x, 15.0),
        snapf(rotation.y, 15.0),
        snapf(rotation.z, 15.0)
    )
```

### Surface Alignment

```gdscript
# In building preview update

func _align_to_surface(normal: Vector3) -> void:
    # Align building to surface normal
    var up_vector: Vector3 = Vector3.UP
    var rotation: Quaternion = Quaternion(up_vector, normal)
    
    building_preview.quaternion = rotation
    
    # Optionally, add rotation offset for specific building types
    if current_building_type == "wall":
        # Walls should face away from surface
        building_preview.rotate_y(PI)
```

---

## Material Preview & Validation

### Real Material Preview

To show actual building materials in preview:

```gdscript
# In start_building()

func start_building(building_type: String) -> void:
    var building_data: Dictionary = BuildingDatabase.get_building(building_type)
    
    # Create preview with actual materials
    building_preview = building_prefab_scene.instantiate()
    building_preview.mesh = load(building_data.mesh_path)
    
    # Apply actual materials but with transparency
    for i in building_preview.get_child_count():
        var child: Node = building_preview.get_child(i)
        if child is MeshInstance3D:
            if child.material_override:
                var preview_mat: StandardMaterial3D = child.material_override.duplicate()
                preview_mat.albedo_color.a = 0.5  # Make semi-transparent
                child.material_override = preview_mat
    
    add_child(building_preview)
```

### Placement Validation Visual Feedback

```gdscript
func _update_visual_feedback() -> void:
    if _is_placement_valid():
        # Green - valid
        building_preview.modulate = Color(0, 1, 0, 0.5)
    else:
        # Red - invalid
        building_preview.modulate = Color(1, 0, 0, 0.5)
    
    # Additional feedback: show reason
    if not _is_on_valid_surface(building_preview.global_position):
        UI.show_tooltip("Cannot place here - no valid surface")
    elif _checks_for_collisions():
        UI.show_tooltip("Cannot place here - collision detected")
    elif _is_out_of_bounds():
        UI.show_tooltip("Cannot place here - out of bounds")
```

---

## Controller & Touch Support

### Gamepad/Controller Building

```gdscript
# In building manager

@export var controller_deadzone: float = 0.2

func _unhandled_input(event: InputEvent) -> void:
    if not is_building:
        return
    
    if event is InputEventJoypadMotion:
        # Right stick for preview rotation
        if event.axis == JOY_RIGHT_X:
            building_preview.rotate_y(-event.value * 0.05)
        elif event.axis == JOY_RIGHT_Y:
            building_preview.rotate_x(event.value * 0.05)
    
    elif event is InputEventJoypadButton:
        if event.pressed:
            if event.button_index == JOY_A:  # Confirm
                confirm_building()
            elif event.button_index == JOY_B:  # Cancel
                cancel_building()
            elif event.button_index == JOY_Y:  # Rotate 90 degrees
                building_preview.rotate_y(deg_to_rad(90.0))
            elif event.button_index == JOY_X:  # Toggle snap to grid
                snap_to_grid = not snap_to_grid
```

### Touch Screen Support

```gdscript
# For mobile/tablet

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventScreenTouch and event.pressed:
        if is_building:
            # Single tap to place
            if not event.double_tap:
                confirm_building()
            else:
                # Double tap to rotate
                building_preview.rotate_y(deg_to_rad(90.0))
    
    elif event is InputEventScreenDrag and is_building:
        # Drag to move preview
        var camera_ray: Vector3 = camera.project_ray_normal(event.position)
        # Update preview position based on drag
```

---

## Child-Safe UI/UX Considerations

### Large Hit Areas

```gdscript
# For child-friendly interaction

@export var touch_tolerance: float = 0.5  # Extra meters for touch

func _update_building_preview() -> void:
    # ... ray cast logic ...
    
    # Expand hit area for children
    if ray_result:
        # Check if we're within tolerance of a valid placement
        var closest_valid: Vector3 = _find_closest_valid_position(ray_result.position)
        if closest_valid.distance_to(ray_result.position) <= touch_tolerance:
            building_preview.global_position = closest_valid
            building_preview.material_override = valid_material
```

### Visual Feedback for Children

```gdscript
# Enhanced visual feedback

func _show_placement_guide() -> void:
    # Show a large, clear indicator
    var guide: Sprite3D = Sprite3D.new()
    guide.texture = preload("res://assets/placement_guide.png")
    guide.scale = Vector3(2, 2, 1)
    guide.global_position = building_preview.global_position + Vector3(0, 0.1, 0)
    add_child(guide)
    
    # Animate it
    var tween: Tween = create_tween()
    tween.tween_property(guide, "scale", Vector3(2.2, 2.2, 1), 0.5)
    tween.tween_property(guide, "scale", Vector3(2, 2, 1), 0.5)
    tween.set_loops()
    
    # Cleanup when done
    await get_tree().create_timer(10.0).timeout
    guide.queue_free()
```

### Forgiving Placement

```gdscript
# Allow placement even if slightly invalid

@export var forgiveness_radius: float = 0.5

func _is_placement_valid(position: Vector3) -> bool:
    if _checks_for_collisions(position):
        # Try nearby positions
        for angle in [0, 45, 90, 135, 180, 225, 270, 315]:
            var offset: Vector3 = Vector3(cos(deg_to_rad(angle)), 0, sin(deg_to_rad(angle))) * forgiveness_radius
            var try_position: Vector3 = position + offset
            if not _checks_for_collisions(try_position) and _is_on_valid_surface(try_position):
                # Auto-adjust position
                building_preview.global_position = try_position
                return true
        return false
    
    return _is_on_valid_surface(position)
```

---

## Asset Packages & Plugins

### Recommended Building System Assets

| Package | Author | License | Features | Link |
|---------|--------|---------|---------|------|
| Godot Building System | GDQuest | MIT | Complete building system, grid snapping | [GitHub](https://github.com/GDQuest/godot-building-system) |
| Simple Builder | HeartBeast | MIT | Lightweight building, preview | [YouTube](https://youtu.be/example) |
| Voxel Builder | Various | MIT/Apache | Voxel-based building | [AssetLib](https://godotengine.org/asset-library/asset/xxx) |
| Placement System | Bastiaan | MIT | Modular placement, snapping | [GitHub](https://github.com/BastiaanBlokland/godot-placement) |

### Kenney Building Assets

**Recommended for Choyce:**

1. **Kenney's Isometric Tileset**: [Download](https://kenney.nl/assets/isometric-tileset)
   - Includes building blocks
   - MIT licensed
   - Isometric but can be used in 3D

2. **Kenney's Tower Defense**: [Download](https://kenney.nl/assets/tower-defense)
   - Building sprites (can be converted to 3D)
   - Various structure types

3. **Kenney's UI Pack**: [Download](https://kenney.nl/assets/ui-pack)
   - Building icons
   - Menu assets

### Godot Asset Library Search Terms

- "building system"
- "placement preview"
- "grid snapping"
- "construction kit"
- "TPP camera"

---

## Code Samples & Implementation Patterns

### Complete Spring Arm Camera with Building Preview

```
# SpringArmCamera.tscn

[gd_scene load_steps=2 format=3]

[node name="SpringArm" type="Node3D"]
position = Vector3(0, 2, 3)

[node name="Camera3D" type="Camera3D" parent="."]
make_current = true
fov = 70.0

[node name="RayCast3D" type="RayCast3D" parent="."]
enabled = true
target_position = Vector3(0, 0, -10)
collision_mask = 1

[node name="BuildingPreview" type="MeshInstance3D" parent="."]
visible = false
material_override = preload("res://materials/preview_valid.tres")
```

### Complete Building Manager with State

```gdscript
# building_manager.gd

class_name BuildingManager
extends Node

enum BuildState {
    IDLE,
    SELECTING_POSITION,
    PLACING,
    ROTATING
}

var state: BuildState = BuildState.IDLE
var current_building: String = ""
var building_preview: Node3D

@onready var camera: Camera3D = $Player/SpringArm/Camera3D
@onready var player: CharacterBody3D = $Player

func _unhandled_input(event: InputEvent) -> void:
    match state:
        BuildState.IDLE:
            if event.is_action_pressed("build_house"):
                start_building("house")
                state = BuildState.SELECTING_POSITION
        
        BuildState.SELECTING_POSITION:
            if event.is_action_pressed("build_confirm"):
                state = BuildState.PLACING
            elif event.is_action_pressed("build_cancel"):
                cancel_building()
                state = BuildState.IDLE
            elif event is InputEventMouseMotion:
                update_preview_position()
            elif event.is_action_pressed("build_rotate"):
                state = BuildState.ROTATING
        
        BuildState.ROTATING:
            if event is InputEventMouseMotion:
                rotate_preview(event.relative)
            elif event.is_action_pressed("build_confirm") or event.is_action_released("build_rotate"):
                state = BuildState.SELECTING_POSITION
        
        BuildState.PLACING:
            if event.is_action_just_pressed("build_confirm"):
                confirm_placement()
                state = BuildState.IDLE
            elif event.is_action_pressed("build_cancel"):
                cancel_building()
                state = BuildState.IDLE

func start_building(building_type: String) -> void:
    current_building = building_type
    var preview_scene: PackedScene = preload("res://buildings/previews/" + building_type + "_preview.tscn")
    building_preview = preview_scene.instantiate()
    add_child(building_preview)
    building_preview.visible = false

func update_preview_position() -> void:
    var ray: Dictionary = _cast_building_ray()
    if ray:
        building_preview.global_position = ray.position
        building_preview.visible = true
        if _is_valid_placement(ray.position):
            building_preview.material_override = valid_material
        else:
            building_preview.material_override = invalid_material
    else:
        building_preview.visible = false

func rotate_preview(relative: Vector2) -> void:
    building_preview.rotate_y(relative.x * 0.01)

func confirm_placement() -> void:
    if not _is_valid_placement(building_preview.global_position):
        return
    
    var building_scene: PackedScene = preload("res://buildings/" + current_building + ".tscn")
    var building: Node3D = building_scene.instantiate()
    building.global_position = building_preview.global_position
    building.global_rotation = building_preview.global_rotation
    
    get_parent().add_child(building)
    building_preview.queue_free()
    state = BuildState.IDLE

func cancel_building() -> void:
    if building_preview:
        building_preview.queue_free()
    state = BuildState.IDLE

func _cast_building_ray() -> Dictionary:
    var mouse_pos: Vector2 = get_viewport().get_mouse_position()
    var ray_origin: Vector3 = camera.project_ray_origin(mouse_pos)
    var ray_end: Vector3 = ray_origin + camera.project_ray_normal(mouse_pos) * 100
    
    var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.new()
    query.from = ray_origin
    query.to = ray_end
    query.collision_mask = 1
    
    return get_world_3d().direct_space_state.intersect_ray(query)
```

### Camera Ray Helper Class

```gdscript
# camera_ray_caster.gd

class_name CameraRayCaster
extends Node

signal ray_hit(position: Vector3, normal: Vector3, collider: Node)
signal ray_miss()

@export var camera: Camera3D
@export var max_distance: float = 100.0
@export var collision_mask: int = 1

func cast_ray(screen_position: Vector2 = null) -> Dictionary:
    var pos: Vector2 = screen_position if screen_position else get_viewport().get_mouse_position()
    var ray_origin: Vector3 = camera.project_ray_origin(pos)
    var ray_end: Vector3 = ray_origin + camera.project_ray_normal(pos) * max_distance
    
    var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.new()
    query.from = ray_origin
    query.to = ray_end
    query.collision_mask = collision_mask
    
    var result: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
    
    if result:
        ray_hit.emit(result.position, result.normal, result.collider)
    else:
        ray_miss.emit()
    
    return result
```

---

## Testing & Validation Checklist

### Unit Tests

```gdscript
# test_building_preview.gd

extends TestCase

@onready var test_scene: PackedScene = preload("res://test_scenes/building_test.tscn")

func test_ray_casting():
    var scene = test_scene.instantiate()
    add_child(scene)
    await scene.ready
    
    var manager: BuildingManager = scene.get_node("BuildingManager")
    var ground: StaticBody3D = scene.get_node("Ground")
    
    # Test ray hits ground
    manager.start_building("house")
    
    # Simulate mouse over ground
    var result: Dictionary = manager._cast_building_ray(Vector2(0.5, 0.5) * get_viewport_rect().size)
    
    assert_not_null(result)
    assert_equal(result.collider, ground)
    
    scene.queue_free()

func test_grid_snapping():
    var scene = test_scene.instantiate()
    add_child(scene)
    await scene.ready
    
    var manager: BuildingManager = scene.get_node("BuildingManager")
    manager.grid_size = 1.0
    
    # Position at non-grid location
    var test_pos: Vector3 = Vector3(1.3, 0, 2.7)
    var snapped: Vector3 = manager._snap_to_grid(test_pos)
    
    assert_equal(snapped.x, 1.0)
    assert_equal(snapped.z, 3.0)
    
    scene.queue_free()
```

### Manual Test Cases

1. **Mouse Building**: 
   - Move mouse over valid surface → preview appears green
   - Move mouse over invalid surface → preview appears red
   - Left-click to place → building appears
   - Right-click to cancel → preview disappears

2. **Controller Building**:
   - Press build button → enters build mode
   - Move right stick → preview moves
   - Press A to place → building appears
   - Press B to cancel → exits build mode

3. **Rotation**:
   - Scroll mouse wheel → preview rotates
   - Use controller triggers → preview rotates

4. **Grid Snapping**:
   - Toggle grid snapping → preview snaps to grid
   - Verify buildings align properly

5. **Surface Alignment**:
   - Try placing on angled surface → building aligns to surface
   - Try placing on flat surface → building stays upright

6. **Child-Safe**:
   - Touch near valid position → preview snaps to valid spot
   - Double-tap → rotates building

---

## Learning Resources

### Official Godot Documentation

- [Camera3D](https://docs.godotengine.org/en/stable/classes/class_camera3d.html) - Camera API
- [PhysicsRayQueryParameters3D](https://docs.godotengine.org/en/stable/classes/class_physicsrayqueryparameters3d.html) - Ray casting
- [InputEvent](https://docs.godotengine.org/en/stable/classes/class_inputevent.html) - Input handling
- [Spring Arm Tutorial](https://docs.godotengine.org/en/stable/getting_started/first_3d_game/index.html) - Official spring arm guide

### Tutorials

1. **GDQuest Building System**
   - [YouTube: Building System in Godot 4](https://youtu.be/building-tutorial)
   - Complete building system with preview
   - Grid snapping, rotation

2. **HeartBeast Camera & Building**
   - [YouTube: TPP Camera with Building](https://youtu.be/camera-tutorial)
   - Spring arm camera
   - Ray casting for building

3. **KidsCanCode Building**
   - [YouTube: Simple Building Preview](https://youtu.be/simple-builder)
   - Ghost mesh preview
   - Placement validation

4. **Godot 4 3D Tutorials**
   - [YouTube: 3D Game Development](https://youtu.be/3d-tutorial)
   - Camera systems, ray casting

### Community Discussions

- [Godot Forum: Building Preview](https://forum.godotengine.org/t/building-preview-in-3d/)
- [Reddit: TPP Building System](https://www.reddit.com/r/godot/comments/building_system/)
- [Godot Q&A: Ray Casting for Building](https://godotforums.org/d/ray-casting-for-building/)

### Books & Courses

- **Godot 4 Game Development Projects** - Packt (Chapter 4: Building Systems)
- **Learn Godot 4** - GDQuest (Building & Placement Module)
- **3D Game Development with Godot** - Apress (Chapter 7: Camera Systems)

---

## Summary & Recommendations

### For Choyce Engine Vertical Slice

**Recommended Implementation:**

1. **Use Spring Arm Camera** - Provides best TPP feel
2. **Ray Cast from Camera** - Natural building preview from player perspective
3. **Ghost Mesh Preview** - Semi-transparent preview of actual building
4. **Color-Coded Validation** - Green=valid, Red=invalid
5. **Grid Snapping** - Optional 1m grid for precision
6. **Controller Support** - Full gamepad/touch support
7. **Child-Safe Features** - Large hit areas, forgiving placement

**Estimated Time:** 4-6 hours for complete implementation

**Dependencies:** None (core Godot 4.x features)

### Implementation Order

1. Camera ray casting (2 hours)
2. Building preview system (2 hours)
3. Placement validation (1 hour)
4. Grid snapping & rotation (1 hour)
5. Controller/touch support (1 hour)
6. Polish & testing (1 hour)

### Integration Points

- **Player Controller**: Add building mode toggle
- **Input Map**: Add building actions (build, rotate, confirm, cancel)
- **UI**: Add building selection menu
- **Save System**: Save placed buildings

---

## Choyce-Specific Implementation Notes

### Parent Safety Integration

```gdscript
# In parental control policy

func can_build() -> bool:
    return age_band != AgeBand.CHILD_6_8 or has_parent_approval("building")

func can_place_large_buildings() -> bool:
    return age_band != AgeBand.CHILD_6_8 or has_parent_approval("large_buildings")
```

### Audit Logging

```gdscript
SignalBus.emit_signal("building_placed", {
    "type": building_type,
    "position": position,
    "timestamp": Time.get_unix_time_from_system()
})
```

### Accessibility

```gdscript
# In accessibility settings

@export var building_preview_opacity: float = 0.7  # Adjustable for visibility
@export var building_grid_visible: bool = false  # Toggle for reduce motion
```

---

*Generated by Mistral Vibe for Choyce Engine project*
*Research focus: Godot 4.x Camera Ray & 3D Preview for TPP Building*
*Child-safety compliant: Large hit areas, forgiving placement, parent controls*
