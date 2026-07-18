# RESEARCH VS-008: Reversible Creator Interaction

## Choyce Engine - Vertical Slice Research Compendium

**Task ID:** VS-008  
**Title:** Add one reversible creator interaction to the Adventure slice  
**Specialty:** creator-loop  
**Status:** in_progress  
**Dependencies:** [VS-004]  
**Owner:** claude  
**Cross-review:** codex  

---

## Table of Contents

1. [Task Overview](#task-overview)
2. [Current Implementation Analysis](#current-implementation-analysis)
3. [Online Research Summary](#online-research-summary)
4. [Technical Deep Dive](#technical-deep-dive)
5. [Code Samples & Patterns](#code-samples--patterns)
6. [Free Asset Packages](#free-asset-packages)
7. [Learning Resources](#learning-resources)
8. [Implementation Checklist](#implementation-checklist)
9. [Child-Safety Constraints](#child-safety-constraints)
10. [References](#references)

---

## Task Overview

### Objective

Implement a complete reversible creator interaction loop for the Adventure slice:
- **Collect** → Child gathers a bounded resource (wood, stone, etc.)
- **Upgrade** → Resource unlocks a new decoration/block type
- **Place** → Child places decoration using existing build grid logic
- **Undo/Replay** → All actions are reversible with visible undo history

### Acceptance Criteria (from PLAN.md)

- [ ] Child can collect a bounded resource
- [ ] Resource unlocks one upgrade
- [ ] Child can place one decoration using existing build grid logic
- [ ] Apply and undo are visible
- [ ] Persistence/replay are tested

### Existing Evidence (from backlog.yaml)

- `src/adapters/inbound/gameplay/build_grid.gd` (undo stack support)
- `src/adapters/inbound/gameplay/gameplay_runtime.gd` (HUD UndoBtn connection)
- `src/adapters/inbound/gameplay/player_controller.gd` (hotbar items, keyboard shortcut)
- `src/adapters/inbound/shared/input_map_initializer.gd` (U key mapping)
- `tests/adapters/inbound/test_build_grid_undo.gd` (automated tests)

---

## Current Implementation Analysis

### 1. BuildGrid.gd - Voxel Grid Manager

**File:** `src/adapters/inbound/gameplay/build_grid.gd`  
**Purpose:** Minecraft-lite block-grid manager, places/removes voxel cubes on 1m integer grid  
**Key Features:**

- **Per-cell map:** `Dictionary[Vector3i, MeshInstance3D]` - each block is StaticBody3D + BoxMesh + BoxShape3D
- **Performance cap:** 500 blocks per world (kid-friendly limit)
- **History stack:** `Array[Dictionary]` tracks `{"action": "place"|"break", "cell": Vector3i, "block_id": String}`
- **Undo support:** `undo_last_action()` pops last action and reverses it

**Code Pattern:**
```gdscript
# From build_grid.gd
const MAX_BLOCKS_PER_WORLD := 500
var _history_stack: Array = []

func place_block(cell: Vector3i, block_id: String, record_history: bool = true) -> bool:
    # ... validation ...
    if record_history:
        _history_stack.append({"action": "place", "cell": cell, "block_id": block_id})
    return true

func undo_last_action() -> bool:
    if _history_stack.is_empty():
        return false
    var last_act: Dictionary = _history_stack.pop_back()
    match last_act["action"]:
        "place":
            break_block(last_act["cell"], false)
            return true
        "break":
            place_block(last_act["cell"], last_act["block_id"], false)
            return true
    return false
```

**Strengths:**
- Simple, clear undo mechanism
- History stack captures all necessary state
- Kid-friendly block cap prevents performance issues

**Gaps for VS-008:**
- No resource collection system
- No upgrade/unlock mechanism
- No decoration-specific block types
- No persistence of undo history across sessions

### 2. BlockKind.gd - Block Descriptors

**File:** `src/domain/build/block_kind.gd`  
**Purpose:** Pure data class for voxel block definitions  
**Catalog:** 10 kid-friendly block kinds (grass, dirt, wood_oak, stone, sand, brick_red, glow, spring, tree_oak, ore_node)

**Design Pattern:** RefCounted (framework-agnostic), allowlist of 8 starter kinds for readable hotbar

**Relevance to VS-008:**
- Existing `drop_id` mechanism can support resource gathering (tree_oak drops wood_oak)
- Need to extend with decoration blocks unlocked via upgrades

### 3. ApplyWorldEditService.gd - Application Layer

**File:** `src/application/apply_world_edit_service.gd`  
**Purpose:** Application service applying scene graph edits with undo support  
**Key Features:**

- Event-sourced action logging
- Captures previous state for undo
- Emits WorldEditedEvent
- Provenance tracking (human vs AI)

**Pattern:** Command pattern - each edit is encapsulated with full state capture

---

## Online Research Summary

### 1. Command Pattern for Undo/Redo

**Primary Approach:** Encapsulate each action in a Command object with `do()` and `undo()` methods

**Key Resources:**
- [Moonjump Forum: Command Pattern in GDScript](https://moonjump.com/forum/coding/wrote-an-undo-redo-system-for-my-godot-level-editor-command-pattern-in-gdscript-deccd2) - Practical implementation discussion
- [YouTube: Creating an Undo/Redo System in Godot 4](https://www.youtube.com/watch?v=FDd1isr5xdM) - Step-by-step visual tutorial
- [Game Programming Patterns: Command Pattern](https://davidserrano.io/game-programming-patterns-in-godot-the-command-pattern) - Theoretical + practical guide
- [Godot UndoRedo Class Documentation](https://docs.godotengine.org/en/stable/classes/class_undoredo.html) - Built-in editor support

**Community Consensus:**
- Use fixed-size ring buffer for undo stack to prevent memory issues
- Handle scene node references carefully to prevent garbage collection
- Store minimal state in commands (positions, IDs, types - not node references)

### 2. Voxel Building Performance

**Critical Performance Insights:**

**Do NOT:**
- Create MeshInstance3D for every block (extremely inefficient)
- Generate huge MultiMesh instances at runtime (slow)

**DO:**
- One mesh per chunk (16x16x16 blocks recommended)
- Use ArrayMesh + SurfaceTool for chunk mesh generation
- Use MultiMeshInstance3D for instancing repeated blocks
- Implement chunk loading/unloading based on player position
- Budget: 3.5ms per frame for world streaming (from PLAN.md)

**Recommended Plugins:**
- **[Zylann/godot_voxel](https://github.com/Zylann/godot_voxel)** - C++ module, realtime editing, chunked meshes, physics
- **[Voxel-Core](https://github.com/ClarkThyLord/Voxel-Core)** - VoxelMultiMesh, multithreading (being reworked)

**Tutorials:**
- [RandomMomentania Voxel Terrain Tutorial](https://randommomentania.com/2019/01/godot-voxel-terrain-tutorial-part-1/)
- [YouTube: Voxel Chunking with Threads](https://www.youtube.com/watch?v=ItAvgeKB0Kk)

### 3. Child-Safe UI/UX for Building

**Age 7 Best Practices:**

| Aspect | Requirement | Godot Implementation |
|--------|-------------|----------------------|
| Button Size | Minimum 75x75px | TextureButton with custom size |
| Text Size | 18-19px minimum | Label with large font |
| Navigation | Simple, no hidden functions | Clear menu hierarchy |
| Feedback | Immediate, visual/audio | Signals + animations + sound |
| Touch Targets | Large, forgiving | Big buttons, spacing |
| Icons | Literal, familiar | Kenney icon packs |

**Sources:**
- [Smashing Magazine: Designing for Children](https://www.smashingmagazine.com/2024/02/practical-guide-design-children/)
- [Aufait UX: Child-Friendly Interfaces](https://www.aufaitux.com/blog/ui-ux-designing-for-children/)
- [GDQuest UI Containers](https://school.gdquest.com/courses/learn_2d_gamedev_godot_4/start_a_dialogue/all_the_containers)

### 4. Inventory & Hotbar Systems

**Pattern:** Grid-based inventory with hotbar as first row

**Key Resources:**
- [Medium: Grid Inventory with Godot](https://medium.com/@thrivevolt/making-a-grid-inventory-system-with-godot-727efedb71f7)
- [YouTube: Dynamic Slot-Based Inventory](https://www.youtube.com/watch?v=sVQMjXm6fSw)
- [GitHub: Modular Inventory System](https://github.com/mujtaba-io/inventory-system) - Complete Godot 4 project
- [Godot Forums: Inventory & Hotbar](https://godotforums.org/d/39924-how-to-make-an-inventory-and-a-hotbar-in-godot-4)

**Implementation Pattern:**
```gdscript
# Hotbar is row 0 of inventory 2D array
# Number keys 0-9 map to columns in row 0
# Selected hotbar index updates on mouse click
```

### 5. Godot InputMap Best Practices

**For Child-Friendly Controls:**

- Single keys per action (no modifiers)
- Support both keyboard and gamepad
- Allow rebinding (parent customization)
- Visual feedback on input
- Input buffering for forgiveness

**Code:**
```gdscript
# Add action dynamically
var event = InputEventKey.new()
event.keycode = KEY_SPACE
InputMap.add_action("jump")
InputMap.action_add_event("jump", event)
```

**References:**
- [Godot Input Documentation](https://docs.godotengine.org/en/stable/tutorials/inputs/index.html)
- [Kids Can Code: Input Recipes](https://kidscancode.org/godot_recipes/4.x/input/custom_actions/index.html)

---

## Technical Deep Dive

### 1. Command Pattern Implementation

**Structure:**
```
┌─────────────────────┐
│   Command            │
│  (Abstract Base)     │
└──────────┬──────────┘
           │
     ┌─────┴─────┐
     │           │
┌────▼────┐ ┌────▼────┐
│PlaceBlock│ │BreakBlock│
│ Command  │ │ Command  │
└──────────┘ └──────────┘
```

**Base Command Class:**
```gdscript
# command.gd
class_name Command
extends RefCounted

signal command_done
signal command_undone

# Execute the command
func do() -> void:
    pass

# Reverse the command
func undo() -> void:
    pass

# Re-execute after undo
func redo() -> void:
    do()
```

### 2. Command Types for VS-008

```gdscript
# place_decoration_command.gd
class_name PlaceDecorationCommand extends Command

export var cell: Vector3i
export var decoration_id: String
export var build_grid: BuildGrid

func do() -> void:
    if build_grid.place_block(cell, decoration_id):
        command_done.emit()

func undo() -> void:
    build_grid.break_block(cell, false)
    command_undone.emit()


# collect_resource_command.gd
class_name CollectResourceCommand extends Command

export var resource_node: Node3D
export var inventory: Inventory
export var resource_id: String

func do() -> void:
    inventory.add_item(resource_id, 1)
    resource_node.queue_free()
    command_done.emit()

func undo() -> void:
    inventory.remove_item(resource_id, 1)
    # Respawn resource at original position
    var new_node = preload("res://path/to/resource.tscn").instantiate()
    new_node.position = _original_position
    get_tree().current_scene.add_child(new_node)
    command_undone.emit()
```

### 3. Command Manager

```gdscript
# command_manager.gd
class_name CommandManager
extends Node

signal undo_stack_changed(size: int)
signal redo_stack_changed(size: int)

const MAX_UNDO_HISTORY := 100  # Child-safe limit

var _undo_stack: Array[Command] = []
var _redo_stack: Array[Command] = []

func execute(command: Command) -> void:
    command.do()
    _undo_stack.append(command)
    _redo_stack.clear()
    
    # Enforce history limit
    if _undo_stack.size() > MAX_UNDO_HISTORY:
        _undo_stack[0].queue_free()
        _undo_stack.remove_at(0)
    
    undo_stack_changed.emit(_undo_stack.size())

func undo() -> bool:
    if _undo_stack.is_empty():
        return false
    
    var command = _undo_stack.pop_back()
    command.undo()
    _redo_stack.append(command)
    
    undo_stack_changed.emit(_undo_stack.size())
    redo_stack_changed.emit(_redo_stack.size())
    return true

func redo() -> bool:
    if _redo_stack.is_empty():
        return false
    
    var command = _redo_stack.pop_back()
    command.redo()
    _undo_stack.append(command)
    
    undo_stack_changed.emit(_undo_stack.size())
    redo_stack_changed.emit(_redo_stack.size())
    return true

func clear() -> void:
    for cmd in _undo_stack:
        cmd.queue_free()
    for cmd in _redo_stack:
        cmd.queue_free()
    _undo_stack.clear()
    _redo_stack.clear()
    undo_stack_changed.emit(0)
    redo_stack_changed.emit(0)
```

### 4. Resource Collection System

**Design:**
- Resources are Node3D with Area3D for detection
- On player overlap, emit collection event
- Resource respawns after cooldown (or is finite)

```gdscript
# resource_node.gd
class_name ResourceNode
extends Area3D

signal collected(resource_id: String, position: Vector3)

@export var resource_id: String = "wood_oak"
@export var respawn_time: float = 30.0  # seconds
@export var max_uses: int = 1  # 0 = infinite

var _uses_remaining: int
var _respawn_timer: float = 0.0
var _active: bool = true

func _ready() -> void:
    _uses_remaining = max_uses if max_uses > 0 else -1
    connect("body_entered", _on_body_entered)

func _process(delta: float) -> void:
    if not _active and respawn_time > 0:
        _respawn_timer += delta
        if _respawn_timer >= respawn_time:
            _active = true
            visible = true
            _respawn_timer = 0.0

func _on_body_entered(body: Node) -> void:
    if not _active:
        return
    if body is PlayerCharacter:
        _active = false
        visible = false
        collected.emit(resource_id, global_position)
        
        if max_uses > 0:
            _uses_remaining -= 1
            if _uses_remaining <= 0:
                queue_free()
```

### 5. Upgrade System

**Design:**
- Inventory tracks resource counts
- UnlockManager maps resources to unlocked decorations
- Persists unlocks in player profile

```gdscript
# unlock_manager.gd
class_name UnlockManager
extends Node

signal decoration_unlocked(decoration_id: String)

@export var unlock_definitions: Array[Dictionary] = [
    {"resource_id": "wood_oak", "required_count": 5, "unlocks": "decoration_wooden_fence"},
    {"resource_id": "stone", "required_count": 10, "unlocks": "decoration_stone_pillar"},
    {"resource_id": "ore_iron", "required_count": 3, "unlocks": "decoration_iron_lantern"},
]

var _unlocked_decorations: Set = Set()

func check_unlocks(inventory: Inventory) -> void:
    for def in unlock_definitions:
        var resource_id = def["resource_id"]
        var required = def["required_count"]
        var decoration_id = def["unlocks"]
        
        if inventory.get_count(resource_id) >= required and not decoration_id in _unlocked_decorations:
            _unlocked_decorations.add(decoration_id)
            decoration_unlocked.emit(decoration_id)

func is_unlocked(decoration_id: String) -> bool:
    return decoration_id in _unlocked_decorations

func save_to_profile(profile: PlayerProfile) -> void:
    profile.unlocked_decorations = _unlocked_decorations.to_array()

func load_from_profile(profile: PlayerProfile) -> void:
    _unlocked_decorations = Set(profile.unlocked_decorations)
```

### 6. Child-Safe Hotbar

**Design:**
- 5 slots (fits 7yo attention span)
- Large touch targets (100x100px minimum)
- Visual feedback on selection
- Number key shortcuts (1-5)
- Only shows unlocked decorations

```gdscript
# hotbar.gd
class_name Hotbar
extends Control

signal decoration_selected(decoration_id: String)
signal hotbar_changed()

@export var slot_count: int = 5
@export var slot_size: Vector2 = Vector2(100, 100)
@export var slot_spacing: int = 10

var _slots: Array[TextureRect] = []
var _decorations: Array[String] = []
var _selected_index: int = 0

func _ready() -> void:
    _setup_slots()

func _setup_slots() -> void:
    for i in range(slot_count):
        var slot = TextureRect.new()
        slot.size = slot_size
        slot.position = Vector2(i * (slot_size.x + slot_spacing), 0)
        add_child(slot)
        _slots.append(slot)
        
        # Add touch/mouse detection
        var area = Area2D.new()
        area.position = slot.size / 2
        area.connect("input_event", _on_slot_input.bind(i))
        slot.add_child(area)

func set_decorations(decorations: Array[String]) -> void:
    _decorations = decorations.duplicate()
    _update_slot_icons()
    _select_slot(_selected_index)

func _on_slot_input(viewport: Node, event: InputEvent, slot_index: int) -> void:
    if event is InputEventMouseButton and event.pressed:
        _selected_index = slot_index
        _select_slot(_selected_index)

func _select_slot(index: int) -> void:
    _selected_index = clamp(index, 0, _slots.size() - 1)
    for i in range(_slots.size()):
        _slots[i].self_modulate = Color(1, 1, 1) if i == _selected_index else Color(0.7, 0.7, 0.7)
    
    if _selected_index < _decorations.size():
        decoration_selected.emit(_decorations[_selected_index])

func get_selected_decoration() -> String:
    if _selected_index < _decorations.size():
        return _decorations[_selected_index]
    return ""

func _on_key_pressed(event: InputEventKey) -> void:
    if event.keycode >= KEY_1 and event.keycode <= KEY_5:
        var index = event.keycode - KEY_1
        _selected_index = index
        _select_slot(_selected_index)
```

---

## Code Samples & Patterns

### 1. Complete Undo/Redo Ring Buffer

```gdscript
# ring_buffer.gd - Generic ring buffer for history
class_name RingBuffer
extends RefCounted

var _buffer: Array = []
var _capacity: int
var _head: int = 0
var _tail: int = 0
var _size: int = 0

func _init(capacity: int) -> void:
    _capacity = capacity
    _buffer.resize(capacity)

func push(item: Variant) -> void:
    _buffer[_head] = item
    _head = (_head + 1) % _capacity
    if _size < _capacity:
        _size += 1
    else:
        _tail = (_tail + 1) % _capacity

func pop() -> Variant:
    if _size == 0:
        return null
    var item = _buffer[_tail]
    _tail = (_tail + 1) % _capacity
    _size -= 1
    return item

func peek() -> Variant:
    if _size == 0:
        return null
    return _buffer[_tail]

func size() -> int:
    return _size

func clear() -> void:
    _head = 0
    _tail = 0
    _size = 0
```

### 2. EventBus Pattern for Decoupling

```gdscript
# event_bus.gd - Autoload singleton
class_name EventBus
extends Node

# Voxel events
signal voxel_placed(cell: Vector3i, voxel_type: String)
signal voxel_removed(cell: Vector3i, voxel_type: String)

# Resource events
signal resource_collected(resource_id: String, position: Vector3)
signal resource_spawned(resource_id: String, position: Vector3)

# Unlock events
signal decoration_unlocked(decoration_id: String)

# Command events
signal undo_performed(remaining_undo_count: int)
signal redo_performed(remaining_redo_count: int)

func _ready() -> void:
    # Make this a singleton
    if not get_tree().root.get_node_or_null("EventBus"):
        get_tree().root.add_child(self)
        name = "EventBus"
```

### 3. Building Placement with Raycast

```gdscript
# player_building.gd
class_name PlayerBuilding
extends Node

signal place_request(cell: Vector3i, decoration_id: String)
signal break_request(cell: Vector3i)

@export var build_grid: BuildGrid
@export var camera: Camera3D
@export var max_distance: float = 10.0
@export var hotbar: Hotbar

var _selected_decoration: String = ""

func _ready() -> void:
    hotbar.connect("decoration_selected", _on_decoration_selected)

func _on_decoration_selected(decoration_id: String) -> void:
    _selected_decoration = decoration_id

func _physics_process(delta: float) -> void:
    if _selected_decoration == "":
        return
    
    var from = camera.project_ray_origin(Input.get_mouse_position())
    var to = from + camera.project_ray_normal(Input.get_mouse_position()) * max_distance
    
    var space_state = get_world_3d().direct_space_state
    var query = PhysicsRayQueryParameters3D.new()
    query.from = from
    query.to = to
    query.collision_mask = 1  # World collision layer
    
    var result = space_state.intersect_ray(query)
    
    if result:
        var cell = build_grid.world_to_cell(result.position + result.normal * 0.6)
        
        if Input.is_action_just_pressed("place_block"):
            place_request.emit(cell, _selected_decoration)
        elif Input.is_action_just_pressed("break_block"):
            break_request.emit(cell)
```

### 4. Persistence with ResourceSaver

```gdscript
# persistence_manager.gd
class_name PersistenceManager
extends Node

func save_build_grid(build_grid: BuildGrid, file_path: String) -> bool:
    var save_data = []
    for cell in build_grid._cells.keys():
        save_data.append({
            "cell": cell,
            "block_id": build_grid._kind_for_cell.get(cell, "")
        })
    
    var file = FileAccess.open(file_path, FileAccess.WRITE)
    if file:
        file.store_string(JSON.stringify(save_data))
        file.close()
        return true
    return false

func load_build_grid(build_grid: BuildGrid, file_path: String) -> bool:
    if not FileAccess.file_exists(file_path):
        return false
    
    var file = FileAccess.open(file_path, FileAccess.READ)
    if file:
        var json = JSON.new()
        var parse_result = json.parse(file.get_as_text())
        file.close()
        
        if parse_result == OK:
            var data = json.data
            for item in data:
                build_grid.place_block(item["cell"], item["block_id"], false)
            return true
    return false
```

---

## Free Asset Packages

### Voxel & Block Assets

| Package | Source | License | Blocks | Notes |
|---------|--------|---------|--------|-------|
| [Kenney Voxel Pack](https://www.kenney.nl/assets/voxel-pack) | Kenney.nl | CC0 | 190+ | Pure voxel style, perfect for building |
| [Kenney Nature Pack](https://www.kenney.nl/assets/nature-pack) | Kenney.nl | CC0 | 200+ | Trees, rocks, foliage for gathering |
| [Poly Pizza Low Poly](https://poly.pizza/bundles) | Poly Pizza | CC0 | Various | GLTF format, Godot-ready |
| [Quaternius Buildings](https://quaternius.com/free-3d-models) | Quaternius | CC0 | 500+ | Furniture, decorations |
| [CC0 Textures](https://cc0textures.com/) | CC0Textures | CC0 | 100+ | PBR materials for blocks |

### UI Assets

| Package | Source | License | Notes |
|---------|--------|---------|-------|
| [Kenney UI Pack](https://kenney.nl/assets/ui-pack) | Kenney.nl | CC0 | 300+ UI elements |
| [Kenney Icons](https://kenney.nl/assets/ui-icons) | Kenney.nl | CC0 | 200+ icons |
| [Godot Asset Library UI](https://godotengine.org/asset-library/asset?category=ui&sort=updated) | Godot | CC0 | Pre-packaged for Godot |

### Sound Effects

| Package | Source | License | Notes |
|---------|--------|---------|-------|
| [Kenney Audio](https://kenney.nl/assets/audio) | Kenney.nl | CC0 | 500+ SFX |
| [Freesound CC0](https://freesound.org/browse/tags/cc0/) | Freesound | CC0 | Search by tag |

---

## Learning Resources

### Godot-Specific Tutorials

#### Command Pattern & Undo/Redo
1. **[YouTube: Creating an Undo/Redo System in Godot 4](https://www.youtube.com/watch?v=FDd1isr5xdM)** - Step-by-step GDScript implementation
2. **[Moonjump Forum: Command Pattern Discussion](https://moonjump.com/forum/coding/wrote-an-undo-redo-system-for-my-godot-level-editor-command-pattern-in-gdscript-deccd2)** - Practical tips and edge cases
3. **[Game Programming Patterns in Godot](https://davidserrano.io/game-programming-patterns-in-godot-the-command-pattern)** - Theoretical + code examples
4. **[Godot UndoRedo Class Docs](https://docs.godotengine.org/en/stable/classes/class_undoredo.html)** - Built-in editor support

#### Voxel Building
1. **[RandomMomentania: Godot Voxel Terrain Tutorial](https://randommomentania.com/2019/01/godot-voxel-terrain-tutorial-part-1/)** - SurfaceTool mesh generation
2. **[YouTube: Voxel Chunking with Threads](https://www.youtube.com/watch?v=ItAvgeKB0Kk)** - Performance optimization
3. **[Godot Docs: MultiMesh Optimization](https://docs.godotengine.org/en/stable/tutorials/performance/using_multimesh.html)** - Instancing guide
4. **[GitHub: Zylann/godot_voxel](https://github.com/Zylann/godot_voxel)** - Production-ready plugin

#### UI & Inventory
1. **[Medium: Grid Inventory System](https://medium.com/@thrivevolt/making-a-grid-inventory-system-with-godot-727efedb71f7)** - Complete hotbar integration
2. **[YouTube: Dynamic Slot-Based Inventory](https://www.youtube.com/watch?v=sVQMjXm6fSw)** - Drag & drop implementation
3. **[GitHub: Modular Inventory](https://github.com/mujtaba-io/inventory-system)** - Complete Godot 4 project
4. **[GDQuest: UI Containers](https://school.gdquest.com/courses/learn_2d_gamedev_godot_4/start_a_dialogue/all_the_containers)** - Responsive design

#### Input Handling
1. **[Godot Input Documentation](https://docs.godotengine.org/en/stable/tutorials/inputs/index.html)** - Official guide
2. **[Kids Can Code: Input Recipes](https://kidscancode.org/godot_recipes/4.x/input/custom_actions/index.html)** - Practical examples
3. **[Sharp Coder: UI in Godot](https://www.sharpcoderblog.com/blog/building-user-interfaces-for-your-games-in-godot-engine)** - Best practices

### Child-Safe Game Design

1. **[Smashing Magazine: Designing for Children](https://www.smashingmagazine.com/2024/02/practical-guide-design-children/)** - Age-appropriate UX
2. **[Aufait UX: Child-Friendly Interfaces](https://www.aufaitux.com/blog/ui-ux-designing-for-children/)** - UI/UX guidelines
3. **[Glance: Safe Apps for Kids](https://thisisglance.com/learning-centre/how-do-i-design-apps-that-kids-can-use-safely)** - Safety considerations
4. **[Gapsy: UX for Kids Guide](https://gapsystudio.com/blog/ux-design-for-kids/)** - Comprehensive guide

---

## Implementation Checklist

### Phase 1: Core Command System
- [ ] Create `Command.gd` base class
- [ ] Create `PlaceDecorationCommand.gd`
- [ ] Create `CollectResourceCommand.gd`
- [ ] Create `CommandManager.gd` with undo/redo stacks
- [ ] Add ring buffer limit (MAX_UNDO_HISTORY = 100)
- [ ] Unit tests for command execution and undo

### Phase 2: Resource Collection
- [ ] Create `ResourceNode.gd` with Area3D detection
- [ ] Implement resource spawning in world
- [ ] Add respawn cooldown system
- [ ] Integrate with inventory
- [ ] Visual/audio feedback on collection

### Phase 3: Inventory & Hotbar
- [ ] Create `Inventory.gd` with resource tracking
- [ ] Create `Hotbar.gd` with 5 slots
- [ ] Implement number key selection (1-5)
- [ ] Add mouse/touch selection
- [ ] Visual selection feedback
- [ ] Only show unlocked decorations

### Phase 4: Upgrade System
- [ ] Create `UnlockManager.gd`
- [ ] Define unlock mappings (wood → fence, stone → pillar, etc.)
- [ ] Persist unlocks in player profile
- [ ] Emit unlock events
- [ ] Update hotbar when new decorations unlock

### Phase 5: Integration
- [ ] Connect building placement to command system
- [ ] Connect resource collection to command system
- [ ] Add undo/redo keyboard shortcuts (Ctrl+Z, Ctrl+Y)
- [ ] Add undo/redo button in UI
- [ ] Show undo count in HUD

### Phase 6: Persistence
- [ ] Save/load build grid state
- [ ] Save/load unlock progress
- [ ] Save/load inventory
- [ ] Test full save/load cycle

### Phase 7: Testing
- [ ] Unit tests for all command types
- [ ] Integration test: collect → unlock → place → undo
- [ ] Manual test with child-like controls
- [ ] Performance test (500 blocks, undo history)
- [ ] Visual acceptance test

### Phase 8: Polish
- [ ] Child-friendly visuals for decorations
- [ ] Clear audio feedback for all actions
- [ ] Tooltips/hints for first-time users
- [ ] Parent override for block limits
- [ ] Accessibility: controller support, larger UI option

---

## Child-Safety Constraints

### Must Implement

1. **Block Cap:** Maximum 500 blocks per world (already in build_grid.gd)
2. **Undo Limit:** Maximum 100 history entries (prevents memory issues)
3. **Resource Limits:** Bounded resource counts (prevents overflow)
4. **Safe Defaults:** All new blocks default to safe, non-destructive types
5. **Parental Override:** Parent can disable building or set higher limits

### Must Avoid

1. **No infinite loops** in undo/redo
2. **No memory leaks** from command history
3. **No complex gestures** (pinch, swipe, etc.)
4. **No small touch targets** (<75px)
5. **No hidden mechanics** (must be discoverable)

### Age-Appropriate Design (7yo)

| Feature | Implementation |
|---------|----------------|
| Button Size | 75x75px minimum |
| Text Size | 18-19px minimum |
| Color Contrast | High contrast, bright colors |
| Feedback | Immediate, obvious |
| Navigation | Linear, no nesting |
| Controls | Single actions, no combos |
| Time Limits | No timers or pressure |

### Compliance

- **COPPA:** No personal data collection
- **GDPR:** Parental consent for any data
- **WCAG 2.2 AA:** Accessibility standards
- **Content Safety:** All models/textures child-friendly

---

## References

### Internal Files
- `src/adapters/inbound/gameplay/build_grid.gd` - Current voxel grid implementation
- `src/domain/build/block_kind.gd` - Block definitions and catalog
- `src/application/apply_world_edit_service.gd` - Event-sourced world edits
- `src/adapters/inbound/gameplay/voxel_texture_registry.gd` - Material registry
- `PLAN.md` - Vertical slice requirements and gates
- `.ai/tasks/backlog.yaml` - Task definitions and status

### External Links

#### Godot Documentation
- [UndoRedo Class](https://docs.godotengine.org/en/stable/classes/class_undoredo.html)
- [Input Handling](https://docs.godotengine.org/en/stable/tutorials/inputs/index.html)
- [MultiMesh Optimization](https://docs.godotengine.org/en/stable/tutorials/performance/using_multimesh.html)
- [User Interface Tutorials](https://docs.godotengine.org/en/stable/tutorials/ui/index.html)

#### Plugins
- [Zylann/godot_voxel](https://github.com/Zylann/godot_voxel) - Voxel module for Godot 4
- [Voxel-Core](https://github.com/ClarkThyLord/Voxel-Core) - VoxelMultiMesh implementation

#### Tutorials
- [Moonjump Forum: Command Pattern](https://moonjump.com/forum/coding/wrote-an-undo-redo-system-for-my-godot-level-editor-command-pattern-in-gdscript-deccd2)
- [YouTube: Undo/Redo System](https://www.youtube.com/watch?v=FDd1isr5xdM)
- [RandomMomentania: Voxel Tutorial](https://randommomentania.com/2019/01/godot-voxel-terrain-tutorial-part-1/)
- [Medium: Grid Inventory](https://medium.com/@thrivevolt/making-a-grid-inventory-system-with-godot-727efedb71f7)
- [GitHub: Modular Inventory](https://github.com/mujtaba-io/inventory-system)

#### Assets
- [Kenney.nl](https://kenney.nl/assets) - All CC0 packs
- [Poly Pizza](https://poly.pizza/) - Low-poly GLTF models
- [Quaternius](https://quaternius.com/) - Free 3D models
- [CC0 Textures](https://cc0textures.com/) - PBR materials
- [Freesound CC0](https://freesound.org/browse/tags/cc0/) - Sound effects

#### Child-Safe Design
- [Smashing Magazine: Designing for Children](https://www.smashingmagazine.com/2024/02/practical-guide-design-children/)
- [Aufait UX](https://www.aufaitux.com/blog/ui-ux-designing-for-children/)
- [Glance: Safe Apps](https://thisisglance.com/learning-centre/how-do-i-design-apps-that-kids-can-use-safely)

---

## Document Metadata

- **Created:** 2026-07-18
- **Author:** Mistral Vibe (Codex)
- **Project:** Choyce Engine
- **Branch:** fix/adventure-thin-slice-combat-first-run
- **Version:** 1.0
- **Size:** ~XX KB

---

*This research compendium is part of the Choyce Engine project. For questions or contributions, refer to the project's AGENTS.md and CONTRIBUTING.md files.*
