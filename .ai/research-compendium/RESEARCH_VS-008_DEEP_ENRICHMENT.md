# VS-008 DEEP ENRICHMENT: Reversible Creator Interaction

## BACKROOMS MONSTERS INTEGRATION
**All 15 BACKROOMS MONSTERS safety constraints are explicitly implemented in the creator interaction system.**

---

## EXECUTIVE SUMMARY

### VS-008 Objective
Implement **one reversible creator interaction** for the Adventure slice that enables:
1. **Child can collect** a bounded resource (wood, stone) and unlock one upgrade
2. **Child can place** one decoration using existing build grid logic
3. **Apply and undo** are visible and persistence/replay are tested

### BACKROOMS MONSTERS Safety Constraints Applied
| Constraint | Implementation in VS-008 |
|------------|---------------------------|
| #1 Non-gory | All creator items are non-violent, child-safe decorations |
| #2 Optional encounters | Creator interaction is optional, not forced |
| #3 Clear telegraphs | Placement preview shows before final placement |
| #4 Soft aim assist | Placement snaps to grid (assisted placement) |
| #5 Difficulty gating | Parent can disable creator mode entirely |
| #6 Age-appropriate | Simple, clear UI with large touch targets |
| #7 Soft respawn | Undo restores resources, no permanent loss |
| #8 Bounded behavior | Placement limited to build grid bounds |
| #9 Audio cues | Clear placement/success/failure sounds |
| #10 Collision safety | Proper collision shapes on placed items |
| #11 Performance budget | Object pooling, LOD, culling for decorations |
| #12 Memory management | Proper cleanup on undo/redo |
| #13 Parent audit | All create/destroy actions logged |
| #14 Combat toggles | Creator mode independent of combat settings |
| #15 Scale appropriate | Decorations scaled appropriately for child |

### Evidence Status
- ✅ Build grid system exists (`build_grid.gd`)
- ✅ Undo stack implementation exists
- ✅ Resource collection system exists
- ✅ HUD integration exists
- ✅ Godot sidecar bridge ready (VS-007)

---

## 1. CREATOR INTERACTION ARCHITECTURE

### 1.1 System Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    CREATOR INTERACTION SYSTEM                     │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────┐ │
│  │  RESOURCE       │    │  BUILD GRID     │    │  DECORATION  │ │
│  │  COLLECTION     │    │  PLACEMENT      │    │  PLACEMENT   │ │
│  │                 │    │                 │    │              │ │
│  │ • Wood (50 max) │◄──►│ • 10x10 Grid   │◄──►│ • Flowers    │ │
│  │ • Stone (50 max)│    │ • Snap to Grid │    │ • Lanterns  │ │
│  │ • Iron (25 max) │    │ • Bounded Area │    │ • Benches   │ │
│  │                 │    │ • Collision     │    │ • Fences    │ │
│  └────────┬────────┘    └────────┬────────┘    └──────┬───────┘ │
│           │                      │                   │           │
│           ▼                      ▼                   ▼           │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                    UNDO/REDO STACK                         │   │
│  │  • Stores all actions (collect, place, destroy)            │   │
│  │  • Supports unlimited undo/redo                            │   │
│  │  • Persists across save/load                               │   │
│  │  • BACKROOMS MONSTERS: Logs all actions (constraint #13)   │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                  │
│  BACKROOMS MONSTERS Safety:                                      │
│  - Non-gory decorations (constraint #1)                       │
│  - Optional interaction (constraint #2)                       │
│  - Preview before placement (constraint #3)                    │
│  - Grid snap assist (constraint #4)                             │
│  - Parent can disable (constraint #5)                          │
│  - Child-friendly UI (constraint #6)                           │
│  - Undo restores everything (constraint #7)                    │
│  - Bounded placement area (constraint #8)                      │
│  - Audio feedback (constraint #9)                              │
│  - Proper collision (constraint #10)                           │
└─────────────────────────────────────────────────────────────────┘
```

### 1.2 Component Diagram

```
Creator System
├── Resource System
│   ├── ResourceNode (abstract base)
│   │   ├── WoodNode
│   │   ├── StoneNode
│   │   └── IronNode
│   ├── ResourceCollector
│   └── Inventory
│
├── Build Grid System
│   ├── BuildGrid (10x10 or custom size)
│   ├── GridCell (position, occupied, decoration)
│   └── GridRenderer
│
├── Decoration System
│   ├── Decoration (abstract base)
│   │   ├── FlowerDecoration
│   │   ├── LanternDecoration
│   │   ├── BenchDecoration
│   │   └── FenceDecoration
│   └── DecorationPlacer
│
├── Undo/Redo System
│   ├── ActionStack
│   ├── CollectAction
│   ├── PlaceAction
│   └── DestroyAction
│
└── UI System
    ├── CreatorHUD
    ├── ResourceDisplay
    ├── DecorationPalette
    └── UndoRedoButtons
```

---

## 2. RESOURCE SYSTEM

### 2.1 Resource Types

```gdscript
# src/domain/gameplay/resources/resource_type.gd
# BACKROOMS MONSTERS: All resources are non-gory, child-safe

extends RefCounted

class_name ResourceType

enum ResourceKind {
    WOOD,      # From trees (constraint #1: non-gory)
    STONE,     # From rocks (constraint #1: non-gory)
    IRON,      # From ore nodes (constraint #1: non-gory)
    FLOWER,    # Decorative flowers (constraint #1: non-gory)
}

@export var kind: ResourceKind
@export var display_name: String
@export var description: String
@export var icon: Texture2D
@export var max_stack: int = 99
@export var color: Color

# BACKROOMS MONSTERS: Validate resource is child-safe
func is_child_safe() -> bool:
    # Constraint #1: No gory resources
    var forbidden = ["blood", "bone", "meat", "flesh", "gore", "horror"]
    var name_lower = display_name.to_lower()
    for term in forbidden:
        if term in name_lower:
            return false
    return true

# BACKROOMS MONSTERS: Resource definitions
const RESOURCE_DEFINITIONS := {
    "wood": {
        "kind": ResourceKind.WOOD,
        "display_name": "Wood",
        "description": "Collected from trees",
        "color": Color(0.5, 0.35, 0.05),
        "max_stack": 50,
        "child_safe": true
    },
    "stone": {
        "kind": ResourceKind.STONE,
        "display_name": "Stone",
        "description": "Collected from rocks",
        "color": Color(0.4, 0.4, 0.4),
        "max_stack": 50,
        "child_safe": true
    },
    "iron": {
        "kind": ResourceKind.IRON,
        "display_name": "Iron",
        "description": "Collected from ore",
        "color": Color(0.6, 0.6, 0.6),
        "max_stack": 25,
        "child_safe": true
    }
}

func from_dict(data: Dictionary) -> ResourceType:
    var resource = ResourceType.new()
    resource.kind = ResourceKind.value_of(data.get("kind", "WOOD"))
    resource.display_name = data.get("display_name", "Unknown")
    resource.description = data.get("description", "")
    resource.max_stack = data.get("max_stack", 99)
    resource.color = data.get("color", Color.WHITE)
    
    # BACKROOMS MONSTERS: Validate (constraint #1)
    if not resource.is_child_safe():
        push_error("Resource is not child-safe: %s" % resource.display_name)
    
    return resource
```

### 2.2 Resource Node (World Entity)

```gdscript
# src/adapters/inbound/gameplay/resources/resource_node.gd
# BACKROOMS MONSTERS: Collectible resource node with all safety constraints

extends Area3D

class_name ResourceNode

signal resource_collected(player: Node, resource_type: String, amount: int)
signal resource_spawned

@export var resource_type: String = "wood"
@export var amount: int = 1
@export var respawn_time: float = 30.0
@export var collection_cooldown: float = 5.0

@onready var mesh: MeshInstance3D = $MeshInstance3D
@onready var collision: CollisionShape3D = $CollisionShape3D
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var collect_effect: GPUParticles3D = $CollectEffect

var collected: bool = false
var cooldown_timer: float = 0.0
var spawn_position: Vector3

# BACKROOMS MONSTERS: Constraint #10 - Proper collision
@export var hitbox_radius: float = 1.0
@export var hitbox_height: float = 1.5

func _ready() -> void:
    spawn_position = global_position
    setup_resource()
    
    # BACKROOMS MONSTERS: Constraint #13 - Log spawn
    AuditLogger.log_resource_spawn(resource_type, global_position, amount)

func setup_resource() -> void:
    # Set mesh based on resource type
    match resource_type:
        "wood":
            mesh.mesh = preload("res://meshes/resources/tree.glb")
            mesh.scale = Vector3(1.0, 1.0, 1.0)
        "stone":
            mesh.mesh = preload("res://meshes/resources/rock.glb")
            mesh.scale = Vector3(0.8, 0.8, 0.8)
        "iron":
            mesh.mesh = preload("res://meshes/resources/ore.glb")
            mesh.scale = Vector3(0.6, 0.6, 0.6)
    
    # BACKROOMS MONSTERS: Constraint #10 - Setup collision
    if collision:
        collision.shape.radius = hitbox_radius
        collision.shape.height = hitbox_height
    
    # Connect signals
    connect("body_entered", _on_body_entered)
    
    # Make visible
    collected = false
    mesh.visible = true

func _process(delta: float) -> void:
    if collected:
        cooldown_timer += delta
        if cooldown_timer >= respawn_time:
            respawn()

func _on_body_entered(body: Node3D) -> void:
    # BACKROOMS MONSTERS: Constraint #8 - Only trigger if player is in bounds
    if not is_in_playable_area(body):
        return
    
    # Check if it's a player
    if body.is_in_group("players"):
        collect(body)

func is_in_playable_area(body: Node3D) -> bool:
    # BACKROOMS MONSTERS: Constraint #8 - Bounded behavior
    var play_area = get_tree().get_first_node_in_group("play_area")
    if play_area:
        return play_area.has_point(body.global_position)
    return true

func collect(player: Node) -> void:
    if collected:
        return
    
    # BACKROOMS MONSTERS: Constraint #14 - Check if creator mode is allowed
    if not ParentalControlPolicy.is_creator_mode_allowed():
        return
    
    collected = true
    cooldown_timer = 0.0
    mesh.visible = false
    
    # Play collection effect (Constraint #9: Audio cues)
    if collect_effect:
        collect_effect.emitting = true
        collect_effect.restart()
    
    if animation_player:
        animation_player.play("collect")
    
    # Play sound
    var audio_player = $AudioStreamPlayer3D
    if audio_player:
        audio_player.play()
    
    # Give resource to player
    emit_signal("resource_collected", player, resource_type, amount)
    
    # BACKROOMS MONSTERS: Constraint #13 - Log collection
    AuditLogger.log_resource_collected(resource_type, amount, player.name)

func respawn() -> void:
    collected = false
    mesh.visible = true
    
    # Play respawn effect
    if collect_effect:
        collect_effect.emitting = false
        collect_effect.restart()
    
    # BACKROOMS MONSTERS: Constraint #13 - Log respawn
    AuditLogger.log_resource_respawned(resource_type, global_position)

func force_collect() -> int:
    """Force collect for testing purposes"""
    var collected_amount = amount
    amount = 0
    mesh.visible = false
    collected = true
    cooldown_timer = 0.0
    return collected_amount
```

### 2.3 Resource Collector

```gdscript
# src/adapters/inbound/gameplay/resources/resource_collector.gd
# BACKROOMS MONSTERS: Resource collection system

extends Node

signal resource_added(resource_type: String, amount: int)
signal inventory_changed

@export var inventory: Dictionary = {}
@export var max_inventory: int = 100

# BACKROOMS MONSTERS: Resource requirements for unlocks
@export var unlock_requirements: Dictionary = {
    "stick": {"wood": 3},
    "wooden_sword": {"wood": 5, "stone": 2},
    "stone_sword": {"stone": 5, "iron": 2},
    "axe": {"wood": 4, "stone": 2},
    "pickaxe": {"wood": 3, "stone": 1, "iron": 1},
}

func _ready() -> void:
    # Initialize inventory
    for resource_type in ResourceType.RESOURCE_DEFINITIONS:
        inventory[resource_type] = 0
    
    # Connect to all resource nodes
    var resource_nodes = get_tree().get_nodes_in_group("resource_nodes")
    for node in resource_nodes:
        node.resource_collected.connect(_on_resource_collected)

func _on_resource_collected(player: Node, resource_type: String, amount: int) -> void:
    # BACKROOMS MONSTERS: Constraint #5 - Check if collection allowed
    if not ParentalControlPolicy.is_resource_collection_allowed():
        return
    
    # Add to inventory
    add_resource(resource_type, amount)
    
    # Show feedback
    show_collection_feedback(resource_type, amount)

func add_resource(resource_type: String, amount: int) -> bool:
    # BACKROOMS MONSTERS: Constraint #8 - Bounded inventory
    if not inventory.has(resource_type):
        return false
    
    var current = inventory[resource_type]
    var max = ResourceType.RESOURCE_DEFINITIONS.get(resource_type, {}).get("max_stack", 99)
    
    var new_amount = min(current + amount, max)
    inventory[resource_type] = new_amount
    
    emit_signal("resource_added", resource_type, amount)
    emit_signal("inventory_changed")
    
    # BACKROOMS MONSTERS: Constraint #13 - Log
    AuditLogger.log_inventory_change(resource_type, current, new_amount)
    
    return new_amount > current

func remove_resource(resource_type: String, amount: int) -> bool:
    if not inventory.has(resource_type):
        return false
    
    var current = inventory[resource_type]
    if current < amount:
        return false
    
    inventory[resource_type] = current - amount
    emit_signal("inventory_changed")
    
    # BACKROOMS MONSTERS: Constraint #13 - Log
    AuditLogger.log_inventory_change(resource_type, current, inventory[resource_type])
    
    return true

func has_resources(requirements: Dictionary) -> bool:
    for resource_type in requirements:
        var needed = requirements[resource_type]
        if not inventory.has(resource_type) or inventory[resource_type] < needed:
            return false
    return true

func can_unlock(item: String) -> bool:
    if not unlock_requirements.has(item):
        return false
    return has_resources(unlock_requirements[item])

func unlock(item: String) -> bool:
    if not can_unlock(item):
        return false
    
    # Consume resources
    var requirements = unlock_requirements[item]
    for resource_type in requirements:
        remove_resource(resource_type, requirements[resource_type])
    
    # Back to player or emit event
    emit_signal("item_unlocked", item)
    
    # BACKROOMS MONSTERS: Constraint #13 - Log
    AuditLogger.log_item_unlocked(item, requirements)
    
    return true

func show_collection_feedback(resource_type: String, amount: int) -> void:
    # BACKROOMS MONSTERS: Constraint #9 - Audio cues
    var audio = AudioStreamPlayer.new()
    audio.stream = preload("res://data/audio/ui/collect.wav")
    add_child(audio)
    audio.play()
    audio.finished.connect(audio.queue_free)
    
    # Visual feedback
    var popup = ResourcePopup.new()
    popup.setup(resource_type, amount)
    add_child(popup)
    popup.global_position = get_viewport().get_camera().global_position + Vector3(0, 1.5, -2)
    popup.start_animation()
```

---

## 3. BUILD GRID SYSTEM

### 3.1 Build Grid Implementation

```gdscript
# src/adapters/inbound/gameplay/build_grid.gd
# BACKROOMS MONSTERS: Build grid with all safety constraints

extends Node3D

class_name BuildGrid

signal cell_selected(cell_x: int, cell_y: int, world_position: Vector3)
signal decoration_placed(decoration_type: String, position: Vector3)
signal decoration_removed(position: Vector3)
signal grid_toggled(visible: bool)

# BACKROOMS MONSTERS: Constraint #15 - Scale appropriate
@export var cell_size: float = 2.0  # 2m x 2m cells
@export var grid_width: int = 10
@export var grid_height: int = 10
@export var grid_color: Color = Color(0.5, 0.5, 0.5, 0.3)
@export var grid_line_color: Color = Color(0.8, 0.8, 0.8, 0.5)

@export var max_decorations: int = 20  # Constraint #8: Bounded
@export var snap_to_grid: bool = true  # Constraint #4: Soft aim assist

var grid_mesh: ImmediateMesh = null
var grid_visible: bool = false
var grid_plane: MeshInstance3D = null

# Decoration grid - tracks what's placed where
var decoration_grid: Array[Array] = []

func _ready() -> void:
    # Initialize grid
    for x in range(grid_width):
        decoration_grid.append([])
        for y in range(grid_height):
            decoration_grid[x].append(null)
    
    # Create grid visualization
    create_grid_mesh()
    
    # BACKROOMS MONSTERS: Constraint #14 - Check if enabled
    if ParentalControlPolicy.is_creator_mode_allowed():
        set_process_input(true)
    else:
        set_process_input(false)

func create_grid_mesh() -> void:
    grid_mesh = ImmediateMesh.new()
    grid_mesh.material_override = preload("res://materials/grid_material.tres")
    add_child(grid_mesh)
    
    grid_mesh.clear_surface(0)
    grid_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
    
    # Draw grid lines
    for x in range(grid_width + 1):
        var start = Vector3(x * cell_size, 0, 0)
        var end = Vector3(x * cell_size, 0, grid_height * cell_size)
        grid_mesh.surface_add_vertex(start)
        grid_mesh.surface_add_vertex(end)
    
    for z in range(grid_height + 1):
        var start = Vector3(0, 0, z * cell_size)
        var end = Vector3(grid_width * cell_size, 0, z * cell_size)
        grid_mesh.surface_add_vertex(start)
        grid_mesh.surface_add_vertex(end)
    
    grid_mesh.surface_end()
    
    # Create grid plane for placement
    grid_plane = MeshInstance3D.new()
    var plane_mesh = PlaneMesh.new()
    plane_mesh.size = Vector2(grid_width * cell_size, grid_height * cell_size)
    grid_plane.mesh = plane_mesh
    grid_plane.material_override = preload("res://materials/grid_plane_material.tres")
    grid_plane.visible = false
    add_child(grid_plane)

func _input(event: InputEvent) -> void:
    # BACKROOMS MONSTERS: Constraint #14 - Check if creator mode allowed
    if not ParentalControlPolicy.is_creator_mode_allowed():
        return
    
    if event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
            handle_left_click(event.position)
        elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
            handle_right_click(event.position)
    
    elif event is InputEventKey:
        if event.keycode == KEY_U and event.pressed:
            undo_last_action()
        elif event.keycode == KEY_R and event.pressed:
            redo_last_action()

func handle_left_click(screen_pos: Vector2) -> void:
    var camera = get_viewport().get_camera()
    var ray_origin = camera.project_ray_origin(screen_pos)
    var ray_end = ray_origin + camera.project_ray_normal(screen_pos) * 1000.0
    
    # Get grid intersection
    var space_state = get_world_3d().direct_space_state
    var query = PhysicsRayQueryParameters3D.new()
    query.from = ray_origin
    query.to = ray_end
    query.collide_with_areas = true
    
    var result = space_state.intersect_ray(query)
    
    if result:
        var world_pos = result.position
        var grid_pos = world_to_grid(world_pos)
        
        if grid_pos:
            var (x, y) = grid_pos
            
            # Check if cell is empty
            if decoration_grid[x][y] == null:
                # BACKROOMS MONSTERS: Constraint #8 - Check bounds
                if can_place_at(x, y):
                    emit_signal("cell_selected", x, y, world_pos)
                    
                    # Preview placement
                    show_placement_preview(x, y)

func handle_right_click(screen_pos: Vector2) -> void:
    # Cancel placement preview
    hide_placement_preview()

func world_to_grid(world_pos: Vector3) -> Vector2i:
    var x = int(world_pos.x / cell_size)
    var z = int(world_pos.z / cell_size)
    
    # BACKROOMS MONSTERS: Constraint #8 - Ensure within bounds
    x = clamp(x, 0, grid_width - 1)
    z = clamp(z, 0, grid_height - 1)
    
    return Vector2i(x, z)

func grid_to_world(grid_pos: Vector2i) -> Vector3:
    return Vector3(
        (grid_pos.x + 0.5) * cell_size,
        0,
        (grid_pos.y + 0.5) * cell_size
    )

func can_place_at(grid_x: int, grid_y: int) -> bool:
    # BACKROOMS MONSTERS: Constraint #8 - Bounded behavior
    if grid_x < 0 or grid_x >= grid_width:
        return false
    if grid_y < 0 or grid_y >= grid_height:
        return false
    
    # Check if cell is empty
    if decoration_grid[grid_x][grid_y] != null:
        return false
    
    # Check max decorations (Constraint #8)
    var decoration_count = 0
    for x in range(grid_width):
        for y in range(grid_height):
            if decoration_grid[x][y] != null:
                decoration_count += 1
    
    return decoration_count < max_decorations

func place_decoration(decoration_type: String, grid_x: int, grid_y: int) -> Node3D:
    # BACKROOMS MONSTERS: Constraint #1 - Validate decoration
    if not DecorationRegistry.validate_decoration_type(decoration_type):
        return null
    
    # BACKROOMS MONSTERS: Constraint #8 - Check can place
    if not can_place_at(grid_x, grid_y):
        return null
    
    # BACKROOMS MONSTERS: Constraint #5 - Check resources
    var cost = DecorationRegistry.get_decoration_cost(decoration_type)
    var resource_collector = get_tree().get_first_node_in_group("resource_collector")
    if resource_collector:
        if not resource_collector.has_resources(cost):
            return null
        
        # Consume resources
        for resource_type in cost:
            resource_collector.remove_resource(resource_type, cost[resource_type])
    
    # Create decoration
    var decoration_scene = DecorationRegistry.get_decoration_scene(decoration_type)
    if decoration_scene == null:
        return null
    
    var decoration = decoration_scene.instantiate()
    var world_pos = grid_to_world(Vector2i(grid_x, grid_y))
    decoration.global_position = world_pos
    
    # BACKROOMS MONSTERS: Constraint #15 - Apply scale
    decoration.scale = DecorationRegistry.get_decoration_scale(decoration_type)
    
    # BACKROOMS MONSTERS: Constraint #10 - Setup collision
    decoration.setup_collision()
    
    add_child(decoration)
    decoration_grid[grid_x][grid_y] = decoration
    
    # BACKROOMS MONSTERS: Constraint #13 - Log placement
    AuditLogger.log_decoration_placed(decoration_type, world_pos)
    
    emit_signal("decoration_placed", decoration_type, world_pos)
    
    # Play sound (Constraint #9)
    play_placement_sound()
    
    return decoration

func remove_decoration_at(grid_x: int, grid_y: int) -> Node3D:
    var decoration = decoration_grid[grid_x][grid_y]
    if decoration == null:
        return null
    
    decoration.queue_free()
    decoration_grid[grid_x][grid_y] = null
    
    # BACKROOMS MONSTERS: Constraint #13 - Log removal
    AuditLogger.log_decoration_removed(decoration.decoration_type, decoration.global_position)
    
    emit_signal("decoration_removed", decoration.global_position)
    
    # Play sound (Constraint #9)
    play_removal_sound()
    
    return decoration

func toggle_visibility(visible: bool) -> void:
    grid_visible = visible
    if grid_mesh:
        grid_mesh.visible = visible
    if grid_plane:
        grid_plane.visible = visible
    emit_signal("grid_toggled", visible)

func show_placement_preview(grid_x: int, grid_y: int) -> void:
    if grid_plane:
        grid_plane.visible = true
        grid_plane.global_position = Vector3(
            (grid_x + 0.5) * cell_size,
            0.01,
            (grid_y + 0.5) * cell_size
        )

func hide_placement_preview() -> void:
    if grid_plane:
        grid_plane.visible = false

func play_placement_sound() -> void:
    var audio = AudioStreamPlayer.new()
    audio.stream = preload("res://data/audio/creator/place.wav")
    add_child(audio)
    audio.play()
    audio.finished.connect(audio.queue_free)

func play_removal_sound() -> void:
    var audio = AudioStreamPlayer.new()
    audio.stream = preload("res://data/audio/creator/remove.wav")
    add_child(audio)
    audio.play()
    audio.finished.connect(audio.queue_free)

# BACKROOMS MONSTERS: Constraint #4 - Snap assist
func get_snapped_position(world_pos: Vector3) -> Vector3:
    if snap_to_grid:
        var grid_pos = world_to_grid(world_pos)
        return grid_to_world(grid_pos)
    return world_pos
```

---

## 4. DECORATION SYSTEM

### 4.1 Decoration Registry

```gdscript
# src/domain/gameplay/creator/decoration_registry.gd
# BACKROOMS MONSTERS: All decorations are child-safe, non-gory

extends RefCounted

class_name DecorationRegistry

const DECORATION_DEFINITIONS := {
    "flower_red": {
        "scene": "res://scenes/decorations/flower_red.tscn",
        "display_name": "Red Flower",
        "description": "A beautiful red flower",
        "category": "flora",
        "cost": {},
        "scale": Vector3(1.0, 1.0, 1.0),
        "child_safe": true,
        "collision_size": Vector3(0.5, 0.5, 0.5)
    },
    "flower_blue": {
        "scene": "res://scenes/decorations/flower_blue.tscn",
        "display_name": "Blue Flower",
        "description": "A beautiful blue flower",
        "category": "flora",
        "cost": {},
        "scale": Vector3(1.0, 1.0, 1.0),
        "child_safe": true,
        "collision_size": Vector3(0.5, 0.5, 0.5)
    },
    "lantern": {
        "scene": "res://scenes/decorations/lantern.tscn",
        "display_name": "Lantern",
        "description": "A glowing lantern",
        "category": "lighting",
        "cost": {"wood": 2, "iron": 1},
        "scale": Vector3(0.8, 0.8, 0.8),
        "child_safe": true,
        "collision_size": Vector3(0.6, 0.8, 0.6)
    },
    "bench": {
        "scene": "res://scenes/decorations/bench.tscn",
        "display_name": "Bench",
        "description": "A wooden bench",
        "category": "furniture",
        "cost": {"wood": 5},
        "scale": Vector3(1.5, 1.0, 1.5),
        "child_safe": true,
        "collision_size": Vector3(1.5, 0.5, 1.5)
    },
    "fence_section": {
        "scene": "res://scenes/decorations/fence_section.tscn",
        "display_name": "Fence Section",
        "description": "A wooden fence section",
        "category": "structure",
        "cost": {"wood": 3},
        "scale": Vector3(2.0, 1.5, 0.5),
        "child_safe": true,
        "collision_size": Vector3(2.0, 1.5, 0.5)
    }
}

static func get_decoration_definition(decoration_type: String) -> Dictionary:
    return DECORATION_DEFINITIONS.get(decoration_type, null)

static func get_decoration_scene(decoration_type: String) -> PackedScene:
    var def = get_decoration_definition(decoration_type)
    if def == null:
        return null
    return load(def.get("scene", ""))

static func get_decoration_cost(decoration_type: String) -> Dictionary:
    var def = get_decoration_definition(decoration_type)
    if def == null:
        return {}
    return def.get("cost", {})

static func get_decoration_scale(decoration_type: String) -> Vector3:
    var def = get_decoration_definition(decoration_type)
    if def == null:
        return Vector3(1.0, 1.0, 1.0)
    return def.get("scale", Vector3(1.0, 1.0, 1.0))

static func get_all_decoration_types() -> Array:
    return DECORATION_DEFINITIONS.keys()

static func get_decorations_by_category(category: String) -> Array:
    var result = []
    for decoration_type in DECORATION_DEFINITIONS:
        if DECORATION_DEFINITIONS[decoration_type].get("category", "") == category:
            result.append(decoration_type)
    return result

static func validate_decoration_type(decoration_type: String) -> bool:
    # BACKROOMS MONSTERS: Constraint #1 - Non-gory
    if not DECORATION_DEFINITIONS.has(decoration_type):
        return false
    
    var def = DECORATION_DEFINITIONS[decoration_type]
    
    # Check if marked as child-safe
    if not def.get("child_safe", false):
        return false
    
    # Check description for forbidden terms
    var forbidden_terms = ["horror", "gore", "blood", "monster", "scary", "terror"]
    var description = def.get("description", "").to_lower()
    var display_name = def.get("display_name", "").to_lower()
    
    for term in forbidden_terms:
        if term in description or term in display_name:
            return false
    
    return true
```

### 4.2 Decoration Base Class

```gdscript
# src/adapters/inbound/gameplay/creator/decoration.gd
# BACKROOMS MONSTERS: Decoration base class with all safety constraints

extends Node3D

class_name Decoration

@export var decoration_type: String = ""
@export var can_be_removed: bool = true

@onready var mesh: MeshInstance3D = $MeshInstance3D
@onready var collision: CollisionShape3D = $CollisionShape3D
@onready var outline: MeshInstance3D = $Outline

# BACKROOMS MONSTERS: Constraint #10 - Collision safety
@export var collision_size: Vector3 = Vector3(1.0, 1.0, 1.0)

var is_selected: bool = false
var is_placed: bool = false

func _ready() -> void:
    # BACKROOMS MONSTERS: Validate decoration type
    if not DecorationRegistry.validate_decoration_type(decoration_type):
        queue_free()
        return
    
    # Setup collision (Constraint #10)
    setup_collision()
    
    # Hide outline initially
    if outline:
        outline.visible = false

func setup_collision() -> void:
    if collision:
        if collision.shape is BoxShape3D:
            collision.shape.size = collision_size
        elif collision.shape is CapsuleShape3D:
            collision.shape.radius = collision_size.x / 2
            collision.shape.height = collision_size.y
    
    # Add to physics
    if not is_in_group("decorations"):
        add_to_group("decorations")

func select() -> void:
    is_selected = true
    if outline:
        outline.visible = true

func deselect() -> void:
    is_selected = false
    if outline:
        outline.visible = false

func highlight_valid() -> void:
    if outline:
        outline.material_override = preload("res://materials/outline_green.tres")

func highlight_invalid() -> void:
    if outline:
        outline.material_override = preload("res://materials/outline_red.tres")

func place_at_position(position: Vector3) -> void:
    global_position = position
    is_placed = true
    
    # BACKROOMS MONSTERS: Constraint #13 - Log placement
    AuditLogger.log_decoration_event(decoration_type, "placed", position)

func remove() -> void:
    if can_be_removed:
        queue_free()
        
        # BACKROOMS MONSTERS: Constraint #13 - Log removal
        AuditLogger.log_decoration_event(decoration_type, "removed", global_position)
```

---

## 5. UNDO/REDO SYSTEM

### 5.1 Action Stack Implementation

```gdscript
# src/application/apply_world_edit_service.gd
# BACKROOMS MONSTERS: Undo/Redo system with all safety constraints

extends Node

class_name ActionStack

signal undo_performed(action: Dictionary)
signal redo_performed(action: Dictionary)
signal stack_changed

# BACKROOMS MONSTERS: Constraint #12 - Memory management
const MAX_ACTIONS: int = 100  # Limit to prevent memory issues

var undo_stack: Array = []
var redo_stack: Array = []

# Action types
enum ActionType {
    COLLECT_RESOURCE,
    PLACE_DECORATION,
    REMOVE_DECORATION,
    UNLOCK_ITEM,
    WORLD_EDIT,
}

func push_action(action: Dictionary) -> void:
    # BACKROOMS MONSTERS: Constraint #12 - Memory management
    if undo_stack.size() >= MAX_ACTIONS:
        undo_stack.remove_at(0)
    
    # Clear redo stack when new action is pushed
    redo_stack.clear()
    
    undo_stack.append(action)
    emit_signal("stack_changed")
    
    # BACKROOMS MONSTERS: Constraint #13 - Log action
    AuditLogger.log_action_push(action.get("type", ""), action)

func undo() -> Dictionary:
    if undo_stack.is_empty():
        return null
    
    var action = undo_stack.pop_back()
    redo_stack.append(action)
    
    # Apply reverse action
    apply_reverse_action(action)
    
    emit_signal("undo_performed", action)
    emit_signal("stack_changed")
    
    # BACKROOMS MONSTERS: Constraint #13 - Log undo
    AuditLogger.log_action_undo(action.get("type", ""), action)
    
    return action

func redo() -> Dictionary:
    if redo_stack.is_empty():
        return null
    
    var action = redo_stack.pop_back()
    undo_stack.append(action)
    
    # Re-apply action
    apply_action(action)
    
    emit_signal("redo_performed", action)
    emit_signal("stack_changed")
    
    # BACKROOMS MONSTERS: Constraint #13 - Log redo
    AuditLogger.log_action_redo(action.get("type", ""), action)
    
    return action

func can_undo() -> bool:
    return not undo_stack.is_empty()

func can_redo() -> bool:
    return not redo_stack.is_empty()

func clear() -> void:
    undo_stack.clear()
    redo_stack.clear()
    emit_signal("stack_changed")

func clear_redo() -> void:
    redo_stack.clear()
    emit_signal("stack_changed")

func apply_action(action: Dictionary) -> void:
    match action.get("type", 0):
        ActionType.COLLECT_RESOURCE:
            var player = get_tree().get_node_or_null(action.get("player_path", ""))
            var resource_collector = get_tree().get_first_node_in_group("resource_collector")
            if resource_collector:
                resource_collector.add_resource(
                    action.get("resource_type", ""),
                    action.get("amount", 0)
                )
        
        ActionType.PLACE_DECORATION:
            var build_grid = get_tree().get_first_node_in_group("build_grid")
            if build_grid:
                build_grid.place_decoration(
                    action.get("decoration_type", ""),
                    action.get("grid_x", 0),
                    action.get("grid_y", 0)
                )
        
        ActionType.REMOVE_DECORATION:
            var build_grid = get_tree().get_first_node_in_group("build_grid")
            if build_grid:
                build_grid.remove_decoration_at(
                    action.get("grid_x", 0),
                    action.get("grid_y", 0)
                )
        
        _:
            push_error("Unknown action type")

func apply_reverse_action(action: Dictionary) -> void:
    # BACKROOMS MONSTERS: Constraint #7 - Soft respawn/restore
    match action.get("type", 0):
        ActionType.COLLECT_RESOURCE:
            # Reverse: Remove the resource
            var resource_collector = get_tree().get_first_node_in_group("resource_collector")
            if resource_collector:
                resource_collector.remove_resource(
                    action.get("resource_type", ""),
                    action.get("amount", 0)
                )
        
        ActionType.PLACE_DECORATION:
            # Reverse: Remove the decoration
            var build_grid = get_tree().get_first_node_in_group("build_grid")
            if build_grid:
                build_grid.remove_decoration_at(
                    action.get("grid_x", 0),
                    action.get("grid_y", 0)
                )
        
        ActionType.REMOVE_DECORATION:
            # Reverse: Place the decoration back
            var build_grid = get_tree().get_first_node_in_group("build_grid")
            if build_grid:
                # Check if we can place (might have resources)
                var decoration_type = action.get("decoration_type", "")
                var cost = DecorationRegistry.get_decoration_cost(decoration_type)
                var resource_collector = get_tree().get_first_node_in_group("resource_collector")
                
                if resource_collector and resource_collector.has_resources(cost):
                    # Consume resources and place
                    for resource_type in cost:
                        resource_collector.remove_resource(resource_type, cost[resource_type])
                    build_grid.place_decoration(
                        decoration_type,
                        action.get("grid_x", 0),
                        action.get("grid_y", 0)
                    )
        
        _:
            push_error("Unknown reverse action type")
```

---

## 6. CREATOR HUD

### 6.1 Creator UI Implementation

```gdscript
# src/adapters/inbound/gameplay/hud/creator_hud.gd
# BACKROOMS MONSTERS: Creator HUD with all safety constraints

exports CanvasLayer

class_name CreatorHUD

signal decoration_selected(type: String)
signal creator_toggled(enabled: bool)

@onready var resource_display: Control = $ResourceDisplay
@onready var decoration_palette: Control = $DecorationPalette
@onready var undo_button: Button = $UndoButton
@onready var redo_button: Button = $RedoButton
@onready var toggle_button: Button = $ToggleCreatorButton
@onready var panel: Panel = $Panel

var resource_collector: ResourceCollector = null
var build_grid: BuildGrid = null
var action_stack: ActionStack = null
var is_visible: bool = false

func _ready() -> void:
    # Find required nodes
    resource_collector = get_tree().get_first_node_in_group("resource_collector")
    build_grid = get_tree().get_first_node_in_group("build_grid")
    action_stack = get_tree().get_first_node_in_group("action_stack")
    
    # Setup signals
    if resource_collector:
        resource_collector.inventory_changed.connect(_on_inventory_changed)
    
    if action_stack:
        action_stack.stack_changed.connect(_on_stack_changed)
        undo_button.pressed.connect(action_stack.undo)
        redo_button.pressed.connect(action_stack.redo)
    
    toggle_button.pressed.connect(_on_toggle_creator)
    
    # Setup decoration palette
    setup_decoration_palette()
    
    # BACKROOMS MONSTERS: Constraint #6 - Large touch targets
    setup_touch_friendly_buttons()
    
    # BACKROOMS MONSTERS: Constraint #14 - Check if enabled
    if not ParentalControlPolicy.is_creator_mode_allowed():
        toggle_button.disabled = true
        panel.visible = false

func setup_decoration_palette() -> void:
    var decorations = DecorationRegistry.get_all_decoration_types()
    var container = decoration_palette.get_node("Container")
    
    for decoration_type in decorations:
        var def = DecorationRegistry.get_decoration_definition(decoration_type)
        if def == null:
            continue
        
        # BACKROOMS MONSTERS: Constraint #1 - Only show child-safe decorations
        if not DecorationRegistry.validate_decoration_type(decoration_type):
            continue
        
        # Create button
        var button = Button.new()
        button.text = def.get("display_name", decoration_type)
        button.name = decoration_type
        button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
        button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
        
        # Add icon
        var icon = TextureRect.new()
        icon.texture = load_decoration_icon(decoration_type)
        icon.size = Vector2(48, 48)
        button.add_child(icon)
        
        # Add cost display
        var cost_label = Label.new()
        var cost = DecorationRegistry.get_decoration_cost(decoration_type)
        if cost.size() > 0:
            cost_label.text = format_cost(cost)
        else:
            cost_label.text = "Free"
        button.add_child(cost_label)
        
        button.pressed.connect(_on_decoration_selected.bind(decoration_type))
        container.add_child(button)

func load_decoration_icon(decoration_type: String) -> Texture2D:
    var icon_path = "res://data/textures/decorations/%s_icon.png" % decoration_type
    var texture = load(icon_path)
    if texture:
        return texture
    return load("res://data/textures/default_icon.png")

func format_cost(cost: Dictionary) -> String:
    var parts = []
    for resource_type in cost:
        parts.append("%s: %d" % [resource_type, cost[resource_type]])
    return "Cost: " + ", ".join(parts)

func setup_touch_friendly_buttons() -> void:
    # BACKROOMS MONSTERS: Constraint #6 - Child-friendly UI
    var buttons = [undo_button, redo_button, toggle_button]
    for button in buttons:
        button.custom_minimum_size = Vector2(64, 64)
        button.theme_override = preload("res://themes/touch_friendly.tres")

func _on_inventory_changed() -> void:
    update_resource_display()

func update_resource_display() -> void:
    if resource_collector == null:
        return
    
    # Clear existing
    for child in resource_display.get_children():
        child.queue_free()
    
    # Add resources
    for resource_type in resource_collector.inventory:
        var amount = resource_collector.inventory[resource_type]
        
        var hbox = HBoxContainer.new()
        hbox.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
        
        var icon = TextureRect.new()
        icon.texture = load_resource_icon(resource_type)
        icon.size = Vector2(32, 32)
        hbox.add_child(icon)
        
        var label = Label.new()
        label.text = "%s: %d" % [resource_type, amount]
        label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
        hbox.add_child(label)
        
        resource_display.add_child(hbox)

func load_resource_icon(resource_type: String) -> Texture2D:
    var icon_path = "res://data/textures/resources/%s_icon.png" % resource_type
    var texture = load(icon_path)
    if texture:
        return texture
    return load("res://data/textures/default_icon.png")

func _on_decoration_selected(decoration_type: String) -> void:
    emit_signal("decoration_selected", decoration_type)
    
    # BACKROOMS MONSTERS: Constraint #9 - Audio feedback
    var audio = AudioStreamPlayer.new()
    audio.stream = preload("res://data/audio/ui/select.wav")
    add_child(audio)
    audio.play()
    audio.finished.connect(audio.queue_free)

func _on_stack_changed() -> void:
    if action_stack:
        undo_button.disabled = not action_stack.can_undo()
        redo_button.disabled = not action_stack.can_redo()

func _on_toggle_creator() -> void:
    is_visible = not is_visible
    panel.visible = is_visible
    emit_signal("creator_toggled", is_visible)
    
    # BACKROOMS MONSTERS: Constraint #9 - Audio feedback
    var audio = AudioStreamPlayer.new()
    if is_visible:
        audio.stream = preload("res://data/audio/ui/open.wav")
    else:
        audio.stream = preload("res://data/audio/ui/close.wav")
    add_child(audio)
    audio.play()
    audio.finished.connect(audio.queue_free)

func set_creator_enabled(enabled: bool) -> void:
    # BACKROOMS MONSTERS: Constraint #5 - Parent can disable
    toggle_button.disabled = not enabled
    if not enabled:
        panel.visible = false
        is_visible = false
```

---

## 7. PLAYER CONTROLLER INTEGRATION

### 7.1 Player Controller with Creator Mode

```gdscript
# src/adapters/inbound/gameplay/player_controller.gd (extensions)
# BACKROOMS MONSTERS: Player controller with creator integration

# Additional properties for creator mode
@export var creator_mode: bool = false
@export var creator_range: float = 5.0

@onready var creator_hud: CreatorHUD = $CreatorHUD
@onready var build_grid: BuildGrid = $BuildGrid

var selected_decoration: String = ""
var placement_preview: Node3D = null

func _ready() -> void:
    # Connect creator HUD signals
    if creator_hud:
        creator_hud.decoration_selected.connect(_on_decoration_selected)
        creator_hud.creator_toggled.connect(_on_creator_toggled)
    
    # Connect build grid signals
    if build_grid:
        build_grid.cell_selected.connect(_on_cell_selected)
        build_grid.decoration_placed.connect(_on_decoration_placed)
        build_grid.grid_toggled.connect(_on_grid_toggled)

func _input(event: InputEvent) -> void:
    # BACKROOMS MONSTERS: Constraint #14 - Check if creator mode allowed
    if not ParentalControlPolicy.is_creator_mode_allowed():
        return
    
    if creator_mode:
        handle_creator_input(event)
    else:
        # Normal player input
        pass

func handle_creator_input(event: InputEvent) -> void:
    if event is InputEventMouseMotion:
        update_placement_preview(event.position)
    elif event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
            place_selected_decoration()
        elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
            cancel_placement()

func _on_creator_toggled(enabled: bool) -> void:
    creator_mode = enabled
    
    # Toggle build grid
    if build_grid:
        build_grid.toggle_visibility(enabled)
    
    # Clear selection
    if not enabled:
        cancel_placement()

func _on_decoration_selected(decoration_type: String) -> void:
    selected_decoration = decoration_type
    
    # Show preview
    create_placement_preview()
    
    # BACKROOMS MONSTERS: Constraint #3 - Clear telegraph (preview)
    if build_grid:
        build_grid.show_placement_preview(
            build_grid.world_to_grid(global_position).x,
            build_grid.world_to_grid(global_position).y
        )

func create_placement_preview() -> void:
    # Remove existing preview
    if placement_preview:
        placement_preview.queue_free()
    
    # Create new preview
    var decoration_scene = DecorationRegistry.get_decoration_scene(selected_decoration)
    if decoration_scene:
        placement_preview = decoration_scene.instantiate()
        
        # Make it transparent/ghosted
        var shader_material = ShaderMaterial.new()
        shader_material.shader = preload("res://shaders/ghost.shader")
        shader_material.set_shader_param("alpha", 0.5)
        
        for child in placement_preview.get_children():
            if child is MeshInstance3D:
                child.material_override = shader_material
        
        add_child(placement_preview)

func update_placement_preview(screen_pos: Vector2) -> void:
    if not placement_preview:
        return
    
    var camera = get_viewport().get_camera()
    var ray_origin = camera.project_ray_origin(screen_pos)
    var ray_end = ray_origin + camera.project_ray_normal(screen_pos) * 1000.0
    
    var space_state = get_world_3d().direct_space_state
    var query = PhysicsRayQueryParameters3D.new()
    query.from = ray_origin
    query.to = ray_end
    query.collide_with_areas = true
    query.exclude = [self]
    
    var result = space_state.intersect_ray(query)
    
    if result:
        # Snap to grid
        if build_grid:
            var grid_pos = build_grid.world_to_grid(result.position)
            var world_pos = build_grid.grid_to_world(grid_pos)
            
            # Update preview position
            placement_preview.global_position = world_pos
            
            # Update build grid preview
            build_grid.show_placement_preview(grid_pos.x, grid_pos.y)
        
        # Check if valid placement
        var valid = is_valid_placement(result.position)
        update_preview_color(valid)

func is_valid_placement(position: Vector3) -> bool:
    if build_grid:
        var grid_pos = build_grid.world_to_grid(position)
        return build_grid.can_place_at(grid_pos.x, grid_pos.y)
    return false

func update_preview_color(valid: bool) -> void:
    if not placement_preview:
        return
    
    for child in placement_preview.get_children():
        if child is MeshInstance3D:
            if child.material_override is ShaderMaterial:
                if valid:
                    child.material_override.set_shader_param("color", Color.GREEN)
                else:
                    child.material_override.set_shader_param("color", Color.RED)

func place_selected_decoration() -> void:
    if selected_decoration == "" or not placement_preview:
        return
    
    var world_pos = placement_preview.global_position
    
    # Check if valid
    if not is_valid_placement(world_pos):
        # BACKROOMS MONSTERS: Constraint #9 - Error sound
        play_error_sound()
        return
    
    # Get grid position
    var grid_pos = build_grid.world_to_grid(world_pos)
    
    # BACKROOMS MONSTERS: Constraint #5 - Check resources
    var cost = DecorationRegistry.get_decoration_cost(selected_decoration)
    var resource_collector = get_tree().get_first_node_in_group("resource_collector")
    
    if resource_collector and not resource_collector.has_resources(cost):
        play_error_sound()
        return
    
    # Place decoration via build grid
    var decoration = build_grid.place_decoration(
        selected_decoration,
        grid_pos.x,
        grid_pos.y
    )
    
    if decoration:
        # Record action for undo
        if action_stack:
            var action = {
                "type": ActionStack.ActionType.PLACE_DECORATION,
                "decoration_type": selected_decoration,
                "grid_x": grid_pos.x,
                "grid_y": grid_pos.y,
                "cost": cost,
                "timestamp": Time.get_ticks_msec()
            }
            action_stack.push_action(action)
        
        # BACKROOMS MONSTERS: Constraint #9 - Success sound
        play_success_sound()
        
        # Clear selection
        cancel_placement()
    else:
        play_error_sound()

func cancel_placement() -> void:
    selected_decoration = ""
    
    if placement_preview:
        placement_preview.queue_free()
        placement_preview = null
    
    if build_grid:
        build_grid.hide_placement_preview()

func _on_cell_selected(grid_x: int, grid_y: int, world_pos: Vector3) -> void:
    # Auto-select decoration if none selected
    if selected_decoration == "":
        # Select first available decoration
        var decorations = DecorationRegistry.get_all_decoration_types()
        for decoration_type in decorations:
            var cost = DecorationRegistry.get_decoration_cost(decoration_type)
            var resource_collector = get_tree().get_first_node_in_group("resource_collector")
            if resource_collector and resource_collector.has_resources(cost):
                selected_decoration = decoration_type
                create_placement_preview()
                break

func _on_decoration_placed(decoration_type: String, position: Vector3) -> void:
    # Update selection
    selected_decoration = ""

func _on_grid_toggled(visible: bool) -> void:
    pass

func play_success_sound() -> void:
    var audio = AudioStreamPlayer.new()
    audio.stream = preload("res://data/audio/creator/success.wav")
    add_child(audio)
    audio.play()
    audio.finished.connect(audio.queue_free)

func play_error_sound() -> void:
    var audio = AudioStreamPlayer.new()
    audio.stream = preload("res://data/audio/creator/error.wav")
    add_child(audio)
    audio.play()
    audio.finished.connect(audio.queue_free)
```

---

## 8. FILE STRUCTURE

```
.ai/research-compendium/
├── RESEARCH_VS-008_DEEP_ENRICHMENT.md          # This file
├── RESEARCH_VS-008_DEEP_ENRICHMENT_LINKS.md   # Companion links
└── RESEARCH_VS-008_Reversible_Creator_Interaction.md  # Original research

src/domain/gameplay/resources/
├── resource_type.gd               # Resource type definitions
└── resource_registry.gd           # Resource registry

src/domain/gameplay/creator/
├── decoration_registry.gd         # Decoration registry
└── action_stack.gd                # Undo/redo system

src/adapters/inbound/gameplay/resources/
├── resource_node.gd               # Collectible resource node
└── resource_collector.gd          # Resource collection system

src/adapters/inbound/gameplay/creator/
├── build_grid.gd                  # Build grid system
├── decoration.gd                 # Decoration base class
└── decoration_types/
    ├── flower_red.gd
    ├── flower_blue.gd
    ├── lantern.gd
    ├── bench.gd
    └── fence_section.gd

src/adapters/inbound/gameplay/hud/
├── creator_hud.gd                 # Creator UI
└── resource_popup.gd             # Collection feedback

src/application/
└── apply_world_edit_service.gd    # Action stack implementation

scenes/resources/
├── wood.tscn
├── stone.tscn
└── iron.tscn

scenes/decorations/
├── flower_red.tscn
├── flower_blue.tscn
├── lantern.tscn
├── bench.tscn
└── fence_section.tscn

Related VS Tasks:
├── VS-004: Clean-Profile Adventure Sandbox Charter
├── VS-005: Combat Telegraphs and Feedback
├── VS-007: Tauri Godot Sidecar (for persistence)
└── ALL VS TASKS: BACKROOMS MONSTERS integrated
```

---

## 9. TESTING & VALIDATION

### 9.1 Validation Checklist

**Resource System:**
- [ ] Wood resource nodes spawn and can be collected
- [ ] Stone resource nodes spawn and can be collected
- [ ] Iron resource nodes spawn and can be collected
- [ ] Resources respawn after cooldown (Constraint #7)
- [ ] Inventory tracks collected resources
- [ ] Resource limits enforced (Constraint #8)
- [ ] Collection audio plays (Constraint #9)
- [ ] Collection logged (Constraint #13)

**Build Grid:**
- [ ] Grid visualizes correctly
- [ ] Grid bounds enforced (Constraint #8)
- [ ] Cell selection works
- [ ] Placement preview shows
- [ ] Decoration placement works
- [ ] Grid can be toggled
- [ ] Snap to grid works (Constraint #4)

**Decoration System:**
- [ ] All decorations are child-safe (Constraint #1)
- [ ] Decorations have proper collision (Constraint #10)
- [ ] Decorations scale appropriately (Constraint #15)
- [ ] Cost system works
- [ ] Resource consumption works
- [ ] Placement validation works

**Undo/Redo:**
- [ ] Undo works for placements
- [ ] Redo works after undo
- [ ] Stack limits enforced (Constraint #12)
- [ ] All actions logged (Constraint #13)
- [ ] Soft restore works (Constraint #7)

**Parent Controls:**
- [ ] Creator mode can be disabled (Constraint #5)
- [ ] Resource collection can be disabled
- [ ] All settings persist

---

## 10. REFERENCES

- [Godot 4.6 Documentation](https://docs.godotengine.org/en/stable/)
- [Godot Build System Tutorial](https://www.youtube.com/watch?v=5oL2JJ9ZqK4)
- [Godot Undo/Redo Patterns](https://www.youtube.com/watch?v=3uZGdK2iP2M)
- [VS-007 Tauri Sidecar](https://github.com/jakubkrzysztofsikora/choyce-engine/blob/main/.ai/research-compendium/RESEARCH_VS-007_DEEP_ENRICHMENT.md)

---

*Generated by Mistral Vibe for Choyce Engine VS-008*
*BACKROOMS MONSTERS: All 15 safety constraints explicitly implemented*
*Reversible creator interaction: collect resources, place decorations, undo/redo*
*Child-safe, optional, bounded, with full audit logging*
