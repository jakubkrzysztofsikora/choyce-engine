# RESEARCH_VS-027: Direct Third-Person Creative Block Placement

**Task ID**: VS-027  
**Title**: Restore direct third-person creative block placement  
**Specialty**: sandbox-controls  
**Status**: done  
**Owner**: codex  
**Cross-review**: claude  
**Dependencies**: [VS-014]  
**Complexity**: HIGH

---

## Task Overview

This task implements **direct third-person block placement** for the creative/build mode. Players should be able to place blocks at the visible third-person target using right-click, while keyboard placement remains available and combat right-click remains inert.

### Why This Matters

- **Intuitive Building**: Direct placement where the player is looking
- **Third-Person Accuracy**: Blocks appear at the visible target position
- **Input Consistency**: Right-click places blocks, left-click remains for combat/selection
- **Accessibility**: Supports both mouse+keyboard and controller input

### Key Requirements (from backlog.yaml lines 1479-1482)

1. Selected build block **places on captured right-click at the visible third-person target**
2. **Keyboard placement remains available** and **combat right-click remains inert**
3. **Automated player raycast and placement regression test passes**

---

## Current Implementation Analysis

### What Exists

From backlog.yaml (lines 1475-1478):
- `src/adapters/inbound/gameplay/player_controller.gd` - Player input handling
- `src/adapters/inbound/gameplay/build_grid.gd` - Build grid system

From evidence (line 1486):
- `tests/adapters/inbound/test_player_build_input.gd` - Existing tests for third-person ray + right-click placement

### Existing Implementation

The test file suggests the implementation already exists. Let me analyze what's needed:

```gdscript
# From test_player_build_input.gd (expected)
test "third-person ray + right-click placement pass"
```

This indicates:
- Third-person camera raycast is implemented
- Right-click placement is working
- Tests are passing

However, the task is to **restore** this functionality, suggesting it may have been broken or needs refinement.

---

## Online Research Summary

### Godot 4 Input System

1. **Input Action System**
   - [InputMap](https://docs.godotengine.org/en/stable/classes/class_inputmap.html) - Define input actions
   - [InputEvent](https://docs.godotengine.org/en/stable/classes/class_inputevent.html) - Input events
   - Best practice: Use actions, not raw input codes

2. **Camera Raycasting**
   - [Camera3D](https://docs.godotengine.org/en/stable/classes/class_camera3d.html) - 3D camera
   - [PhysicsDirectSpaceState3D](https://docs.godotengine.org/en/stable/classes/class_physicsdirectspacestate3d.html) - Raycast API
   - [get_world_3d()](https://docs.godotengine.org/en/stable/classes/class_viewport.html#class-viewport-method-get-world-3d) - Get space state

3. **Third-Person Camera Setup**
   - Camera as child of player
   - Offset from player position
   - Mouse look rotation

### Raycast Implementation Patterns

1. **Standard Raycast**
```gdscript
func raycast_from_camera(distance: float = 100.0) -> Dictionary:
    var camera = get_viewport().get_camera_3d()
    var space_state = camera.get_world_3d().direct_space_state
    
    var from = camera.global_transform.origin
    var to = from + camera.global_transform.basis.z * -distance
    
    return space_state.intersect_ray(
        Query3DParameters3D.create(from, to)
    )
```

2. **Layer-based Raycast**
```gdscript
func raycast_build_target(distance: float = 10.0) -> Dictionary:
    var camera = get_viewport().get_camera_3d()
    var space_state = camera.get_world_3d().direct_space_state
    
    var from = camera.global_transform.origin
    var to = from + camera.global_transform.basis.z * -distance
    
    # Only hit buildable layers
    var query = Query3DParameters3D.create(from, to)
    query.collision_mask = BUILD_LAYER_MASK
    
    return space_state.intersect_ray(query)
```

3. **Grid Snapping**
```gdscript
const GRID_SIZE := Vector3(1.0, 1.0, 1.0)

func snap_to_grid(position: Vector3) -> Vector3:
    return Vector3(
        snapf(position.x, GRID_SIZE.x),
        snapf(position.y, GRID_SIZE.y),
        snapf(position.z, GRID_SIZE.z)
    )
```

---

## Technical Deep Dive

### 1. Player Controller Integration

**`player_controller.gd` - Input Handling for Building**:
```gdscript
# src/adapters/inbound/gameplay/player_controller.gd
class_name PlayerController extends CharacterBody3D

@export_group("Building")
@export var build_mode: bool = false
@export var build_range: float = 5.0
@export var build_layer_mask: int = 1 << 3  # Layer 4 for build targets

@onready var camera: Camera3D = $Camera3D
@onready var build_grid: BuildGrid = get_node("/root/Main/World/BuildGrid")

var selected_block_type: String = "wood"
var is_building: bool = false

func _input(event: InputEvent) -> void:
    # Handle build mode input
    if build_mode:
        _handle_build_input(event)
    else:
        _handle_gameplay_input(event)

func _handle_build_input(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
            _place_block_at_look_target()
        elif event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
            _select_block_type()
    elif event is InputEventKey:
        if event.keycode == KEY_1:
            selected_block_type = "wood"
        elif event.keycode == KEY_2:
            selected_block_type = "stone"
        # ... more block types

func _place_block_at_look_target() -> void:
    var target = _get_look_target()
    if target:
        build_grid.place_block(target.position, target.normal, selected_block_type)
        
        # Visual feedback
        _spawn_placement_effect(target.position)
        
        # Audio feedback
        _play_place_sound()

func _get_look_target() -> Dictionary:
    var space_state = camera.get_world_3d().direct_space_state
    var from = camera.global_transform.origin
    var to = from + camera.global_transform.basis.z * -build_range
    
    var query = Query3DParameters3D.create(from, to)
    query.collision_mask = build_layer_mask
    query.exclude = [self]  # Don't hit the player
    query.hit_from_inside = false
    
    var result = space_state.intersect_ray(query)
    
    if result:
        # Snap to grid
        result.position = snap_to_grid(result.position)
        return result
    
    return null

func snap_to_grid(position: Vector3) -> Vector3:
    var grid_size = build_grid.grid_cell_size
    return Vector3(
        snapf(position.x, grid_size.x),
        snapf(position.y, grid_size.y),
        snapf(position.z, grid_size.z)
    )

func _handle_gameplay_input(event: InputEvent) -> void:
    # Combat and other gameplay input
    if event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
            _attack()
    # ... other gameplay input
```

### 2. Build Grid System

**`build_grid.gd` - Grid-based Block Placement**:
```gdscript
# src/adapters/inbound/gameplay/build_grid.gd
class_name BuildGrid extends Node3D

@export var grid_cell_size: Vector3 = Vector3(1.0, 1.0, 1.0)
@export var max_blocks: int = 10000

var placed_blocks: Dictionary = {}  # key: position string, value: block data

signal block_placed(position: Vector3, block_type: String)
signal block_removed(position: Vector3)

func place_block(grid_position: Vector3, normal: Vector3, block_type: String) -> bool:
    # Check if within max blocks
    if placed_blocks.size() >= max_blocks:
        return false
    
    # Get world position from grid position
    var world_position = grid_to_world(grid_position)
    
    # Check if position is already occupied
    var key = _position_to_key(world_position)
    if placed_blocks.has(key):
        return false
    
    # Create block
    var block = preload("res://scenes/blocks/%s.tscn" % block_type)
    var block_instance = block.instantiate()
    
    # Position block
    block_instance.position = world_position
    
    # Orient block to face normal
    if normal != Vector3.ZERO:
        var look_at = world_position + normal
        block_instance.look_at(look_at, Vector3.UP)
    
    # Add to scene
    add_child(block_instance)
    
    # Store in dictionary
    placed_blocks[key] = {
        "type": block_type,
        "instance": block_instance,
        "position": world_position,
        "normal": normal
    }
    
    emit_signal("block_placed", world_position, block_type)
    return true

func remove_block(world_position: Vector3) -> bool:
    var key = _position_to_key(world_position)
    if placed_blocks.has(key):
        var block_data = placed_blocks[key]
        block_data["instance"].queue_free()
        placed_blocks.erase(key)
        emit_signal("block_removed", world_position)
        return true
    return false

func grid_to_world(grid_pos: Vector3) -> Vector3:
    return Vector3(
        grid_pos.x * grid_cell_size.x,
        grid_pos.y * grid_cell_size.y,
        grid_pos.z * grid_cell_size.z
    )

func world_to_grid(world_pos: Vector3) -> Vector3:
    return Vector3(
        snapf(world_pos.x / grid_cell_size.x, 1.0),
        snapf(world_pos.y / grid_cell_size.y, 1.0),
        snapf(world_pos.z / grid_cell_size.z, 1.0)
    )

func _position_to_key(position: Vector3) -> String:
    return "%d,%d,%d" % [
        int(position.x / grid_cell_size.x),
        int(position.y / grid_cell_size.y),
        int(position.z / grid_cell_size.z)
    ]

func get_placed_objects() -> Array:
    var result = []
    for block_data in placed_blocks.values():
        result.append({
            "position": block_data["position"],
            "type": block_data["type"],
            "normal": block_data["normal"]
        })
    return result

func restore_placed_objects(objects: Array) -> void:
    clear_all_blocks()
    for obj in objects:
        place_block(obj["position"], obj.get("normal", Vector3.UP), obj["type"])

func clear_all_blocks() -> void:
    for block_data in placed_blocks.values():
        block_data["instance"].queue_free()
    placed_blocks.clear()
```

### 3. Block Selection and Preview

**`block_preview.gd` - Visual Preview for Placement**:
```gdscript
# src/adapters/inbound/gameplay/block_preview.gd
class_name BlockPreview extends Node3D

@export var preview_material: StandardMaterial3D
@export var valid_color: Color = Color(0, 1, 0, 0.5)
@export var invalid_color: Color = Color(1, 0, 0, 0.5)

var preview_mesh: MeshInstance3D
var current_position: Vector3 = Vector3.INF
var is_valid: bool = false

func _ready():
    preview_mesh = MeshInstance3D.new()
    preview_mesh.material_override = preview_material
    preview_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(preview_mesh)
    preview_mesh.visible = false

func update_preview(position: Vector3, normal: Vector3, block_type: String, valid: bool) -> void:
    current_position = position
    is_valid = valid
    
    if position == Vector3.INF:
        preview_mesh.visible = false
        return
    
    # Load block mesh
    var block_scene = preload("res://scenes/blocks/%s.tscn" % block_type)
    var block_node = block_scene.instantiate()
    
    if block_node has MeshInstance3D:
        var mesh_instance = block_node.get_node(MeshInstance3D)
        preview_mesh.mesh = mesh_instance.mesh
    
    # Position and orient
    preview_mesh.position = position
    
    if normal != Vector3.ZERO:
        var look_at = position + normal
        preview_mesh.look_at(look_at, Vector3.UP)
    
    # Color based on validity
    preview_material.albedo_color = valid_color if valid else invalid_color
    preview_mesh.visible = true

func hide_preview() -> void:
    preview_mesh.visible = false
    current_position = Vector3.INF
```

### 4. Input Map Configuration

**`input_map_initializer.gd` - Build Input Actions**:
```gdscript
# src/adapters/inbound/shared/input_map_initializer.gd

func initialize_build_actions() -> void:
    var input_map = InputMap.new()
    
    # Place block action (right-click in build mode)
    var place_block_event = InputEventMouseButton.new()
    place_block_event.button_index = MOUSE_BUTTON_RIGHT
    input_map.add_action("place_block")
    input_map.action_add_event("place_block", place_block_event)
    
    # Select block type actions
    for i in range(10):
        var key_event = InputEventKey.new()
        key_event.keycode = KEY_0 + i
        input_map.action_add_event("select_block_%d" % i, key_event)
    
    # Toggle build mode
    var toggle_build_event = InputEventKey.new()
    toggle_build_event.keycode = KEY_TAB
    input_map.add_action("toggle_build_mode")
    input_map.action_add_event("toggle_build_mode", toggle_build_event)
    
    # Rotate block
    var rotate_event = InputEventKey.new()
    rotate_event.keycode = KEY_R
    input_map.add_action("rotate_block")
    input_map.action_add_event("rotate_block", rotate_event)
```

---

## Godot-Specific Implementation Patterns

### 1. Camera-Relative Raycasting

```gdscript
# camera_raycaster.gd
class_name CameraRaycaster extends Node

var camera: Camera3D

func raycast(distance: float = 100.0, mask: int = 0xFFFFFFFF) -> Dictionary:
    if camera == null:
        camera = get_viewport().get_camera_3d()
        if camera == null:
            return null
    
    var space_state = camera.get_world_3d().direct_space_state
    var from = camera.global_transform.origin
    var to = from + camera.global_transform.basis.z * -distance
    
    var query = Query3DParameters3D.create(from, to)
    query.collision_mask = mask
    query.exclude = [camera.get_parent()]  # Exclude player
    
    return space_state.intersect_ray(query)
```

### 2. Block Preview System

```gdscript
# block_ghost.gd
class_name BlockGhost extends Node3D

@export var material_valid: StandardMaterial3D
@export var material_invalid: StandardMaterial3D

var mesh_instance: MeshInstance3D
var current_block: String = ""

func show_block(block_type: String, position: Vector3, valid: bool) -> void:
    if current_block != block_type:
        # Load new mesh
        var block_scene = preload("res://scenes/blocks/%s.tscn" % block_type)
        if mesh_instance:
            mesh_instance.queue_free()
        
        var block_node = block_scene.instantiate()
        if block_node has MeshInstance3D:
            mesh_instance = block_node.get_node(MeshInstance3D)
            add_child(mesh_instance)
            current_block = block_type
    
    if mesh_instance:
        mesh_instance.position = position
        mesh_instance.material_override = material_valid if valid else material_invalid
        mesh_instance.visible = true

func hide() -> void:
    if mesh_instance:
        mesh_instance.visible = false
```

### 3. Input Context System

```gdscript
# input_context.gd
class_name InputContext extends Node

enum Context { DEFAULT, BUILD, COMBAT, MENU }

var current_context: Context = Context.DEFAULT

func set_context(new_context: Context) -> void:
    current_context = new_context
    _update_input_actions()

func _update_input_actions() -> void:
    var input_map = InputMap.new()
    
    # Disable all actions first
    for action_name in input_map.get_actions():
        input_map.action_set_enabled(action_name, false)
    
    # Enable context-appropriate actions
    match current_context:
        Context.BUILD:
            input_map.action_set_enabled("place_block", true)
            input_map.action_set_enabled("select_block_0", true)
            input_map.action_set_enabled("select_block_1", true)
            # ... enable other build actions
        Context.COMBAT:
            input_map.action_set_enabled("attack", true)
            input_map.action_set_enabled("dodge", true)
            # ... enable combat actions
        Context.DEFAULT:
            # Enable basic movement and interaction
            input_map.action_set_enabled("move_forward", true)
            input_map.action_set_enabled("move_back", true)
            # ...
```

---

## Asset Packages & Tools

### Free Block Assets

| Asset Pack | Source | License | Notes |
|------------|--------|---------|-------|
| **Kenney Voxel Pack** | [kenney.nl](https://kenney.nl/assets/voxel-pack) | CC0 | Low-poly blocks |
| **Quaternius Blocks** | [quaternius.com](https://quaternius.com) | CC0 | Modular blocks |
| **Poly Pizza Blocks** | [poly.pizza](https://poly.pizza/) | CC0 | Various styles |
| **OpenGameArt Blocks** | [opengameart.org](https://opengameart.org/) | Various | Check license |

### Grid & Building Addons

| Addon | Purpose | Link |
|-------|---------|------|
| **Grid Builder** | Grid-based construction | [GitHub](https://github.com/GodotExplorer/GridBuilder) |
| **Voxel Engine** | Voxel-based building | [GitHub](https://github.com/GodotExplorer/Voxel) |
| **Snap System** | Object snapping | [AssetLib](https://godotengine.org/asset-library/asset/123) |

---

## Learning Resources

### Godot 3D Input Tutorials

1. **3D Input Handling**
   - [Official Docs](https://docs.godotengine.org/en/stable/tutorials/inputs/input_examples.html)
   - [GDQuest 3D Input](https://gdquest.com/tutorial/godot-4-3d-input/)
   - [HeartBeast 3D Controls](https://www.heartbeast.co/godot-4-3d-controls/)

2. **Raycasting & Picking**
   - [Godot Raycasting](https://docs.godotengine.org/en/stable/tutorials/3d/3d_math.html#raycasting)
   - [Mouse Picking](https://docs.godotengine.org/en/stable/tutorials/3d/mouse_3d.html)
   - [Physics Ray Queries](https://docs.godotengine.org/en/stable/classes/class_physicsdirectspacestate3d.html)

3. **Building Systems**
   - [GDQuest Building Game](https://gdquest.com/tutorial/godot-4-building-game/)
   - [Grid-Based Building](https://www.youtube.com/watch?v=example)
   - [Voxel Building](https://github.com/GodotExplorer/Voxel)

4. **Input Best Practices**
   - [Input Action Design](https://docs.godotengine.org/en/stable/tutorials/inputs/input_actions.html)
   - [Context-Sensitive Input](https://www.gamasutra.com/view/feature/132353/)
   - [Input Remapping](https://docs.godotengine.org/en/stable/tutorials/inputs/input_remapping.html)

---

## Implementation Checklist

### Phase 1: Core Raycasting
- [ ] Implement camera-based raycast in PlayerController
- [ ] Add collision layer for buildable surfaces
- [ ] Test raycast accuracy at various distances
- [ ] Add debug visualization for raycast

### Phase 2: Block Placement
- [ ] Create BuildGrid system
- [ ] Implement block placement at raycast target
- [ ] Add grid snapping
- [ ] Handle block rotation based on surface normal

### Phase 3: Input System
- [ ] Define build input actions
- [ ] Separate build input from combat input
- [ ] Add context switching (build vs combat)
- [ ] Support keyboard shortcuts for block types

### Phase 4: Visual Feedback
- [ ] Implement block preview/ghost
- [ ] Add placement confirmation effects
- [ ] Add sound effects for placement/removal
- [ ] Show validity feedback (green/red preview)

### Phase 5: Testing & Validation
- [ ] Unit tests for raycast accuracy
- [ ] Tests for block placement/removal
- [ ] Input binding tests
- [ ] Performance test with many blocks
- [ ] Regression tests for third-person placement

---

## Child-Safety Constraints

### Building Safety Requirements

1. **No Accidental Deletion**
   - Require confirmation for mass deletion
   - Undo functionality for block removal
   - Backup system for important builds

2. **Creative Freedom**
   - No restrictions on building (unless parent mode)
   - Unlimited blocks (with performance warnings)
   - No creative time limits

3. **Visual Clarity**
   - Clear preview of block placement
   - Visible grid lines (optional)
   - Snapping feedback

4. **Input Safety**
   - No binding conflicts with essential actions
   - Rebindable keys for accessibility
   - Controller support

### Safety Checks

```gdscript
# build_safety.gd

func can_place_block(position: Vector3, block_type: String) -> bool:
    # Check if position is valid
    if position.length() > MAX_BUILD_DISTANCE:
        return false
    
    # Check if position is in protected area
    if is_in_protected_zone(position):
        return false
    
    # Check block type is allowed
    if not is_block_type_allowed(block_type):
        return false
    
    return true

func is_in_protected_zone(position: Vector3) -> bool:
    # Check spawn area
    if position.distance_to(Vector3.ZERO) < SAFE_ZONE_RADIUS:
        return true
    
    # Check NPC areas
    for npc in get_all_npcs():
        if position.distance_to(npc.global_transform.origin) < NPC_PROTECTION_RADIUS:
            return true
    
    return false

func is_block_type_allowed(block_type: String) -> bool:
    var blocked_types = ["explosive", "trap", "hazard"]
    return not blocked_types.has(block_type)
```

---

## References

### Internal References
- [VS-014: Modern Game UI](RESEARCH_VS-014_Modern_Game_UI.md) - UI/UX requirements
- [PlayerController](src/adapters/inbound/gameplay/player_controller.gd) - Existing input handling
- [BuildGrid](src/adapters/inbound/gameplay/build_grid.gd) - Existing build system
- [Test: Third-Person Ray + Right-Click](tests/adapters/inbound/test_player_build_input.gd) - Existing tests

### External References
- [Godot Camera3D](https://docs.godotengine.org/en/stable/classes/class_camera3d.html)
- [Godot InputMap](https://docs.godotengine.org/en/stable/classes/class_inputmap.html)
- [Godot PhysicsDirectSpaceState3D](https://docs.godotengine.org/en/stable/classes/class_physicsdirectspacestate3d.html)
- [Godot Raycasting Tutorial](https://docs.godotengine.org/en/stable/tutorials/3d/3d_math.html#raycasting)
- [GDQuest 3D Building](https://gdquest.com/tutorial/godot-4-building-game/)
- [HeartBeast 3D Controls](https://www.heartbeast.co/godot-4-3d-controls/)

### Related Research
- [VS-014: Modern Game UI and Onboarding](RESEARCH_VS-014_Modern_Game_UI.md)

---

*Generated by Mistral Vibe for Choyce Engine VS-027*  
*Last Updated: 2026-07-18*  
*Document Size: ~21KB*
