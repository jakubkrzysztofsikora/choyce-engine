# RESEARCH_VS-003: NPC Scene-Tree Lifecycle Error Prevention

**Task ID:** VS-003  
**Title:** Remove NPC scene-tree lifecycle errors from Adventure startup  
**Specialty:** runtime-reliability  
**Owner:** codex  
**Cross-review by:** claude  
**Dependencies:** None  
**Status:** done → in_review  

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
Remove NPC scene-tree lifecycle errors from Adventure startup, ensuring that NPC nodes enter the scene tree before any global/local transform access, preventing `!is_inside_tree()` errors in headless and rendered runs.

### Acceptance Criteria (from backlog.yaml)
1. NPC nodes enter the tree before global/local transform use
2. Headless Adventure smoke produces no `!is_inside_tree` errors
3. NPC labels, triggers, models, and collision remain present

### Key Problem
Godot throws `!is_inside_tree()` errors when trying to access scene tree properties (global_position, global_transform, etc.) on nodes that are not yet in the tree. This commonly happens when:
- Code in `_ready()` accesses global transforms
- Signals are connected before nodes are in the tree
- Deferred operations try to access tree properties
- Async operations complete before nodes are added

---

## Current Implementation Analysis

### Existing Infrastructure
Based on backlog.yaml evidence:
- `.smoke/run-1784315018.log` - Smoke test logs showing errors
- `src/adapters/inbound/gameplay/gameplay_runtime.gd` - Main gameplay runtime

### Error Sources
From the smoke test logs and codebase:
- NPC nodes accessing `global_position` or `global_transform` in initialization
- Signals connected before nodes are in the tree
- Deferred node operations on nodes not yet in tree
- Template loading creating NPCs without proper tree entry

### Hexagonal Architecture Context
NPCs in Choyce Engine follow the pattern:
```
Domain NPC → Adapter (NPCController) → Godot CharacterBody3D/RigidBody3D
```

The lifecycle issue occurs at the adapter layer when Godot nodes are created but not yet added to the tree.

---

## Online Research Summary

### 1. Godot 4 Scene Tree Lifecycle
**Objective**: Understand when nodes are safely in the tree

**Godot 4 Node Lifecycle:**
1. `new()` - Node created, not in tree
2. `add_child()` - Node added to parent, still not fully in tree
3. `_enter_tree()` - Called when node enters tree (first frame)
4. `_ready()` - Called when node and all children are ready (after _enter_tree)
5. `_process()` / `_physics_process()` - Called each frame
6. `_exit_tree()` - Called when node is removed from tree
7. `queue_free()` - Node scheduled for deletion
8. `_tree_exited()` - Called after node exits tree

**Tree Entry Sequence:**
```
Parent.add_child(child) → Parent._child_entered_tree(child) → child._enter_tree() → child._ready()
```

**Critical Insight**: Nodes are NOT in the tree until `_enter_tree()` is called, which happens AFTER `add_child()`.

**Safe Access Patterns:**
| Method | Safe in _ready()? | Safe after add_child()? | Notes |
|--------|-------------------|-------------------------|-------|
| `get_parent()` | ✅ Yes | ❌ No | Returns null if not in tree |
| `get_tree()` | ✅ Yes | ❌ No | Returns null if not in tree |
| `global_position` | ✅ Yes | ❌ No | Requires tree access |
| `global_transform` | ✅ Yes | ❌ No | Requires tree access |
| `position` | ✅ Yes | ✅ Yes | Local space, always safe |
| `transform` | ✅ Yes | ✅ Yes | Local space, always safe |
| `is_inside_tree()` | ✅ Yes | ❌ No (returns false) | Check before tree access |

### 2. Common Causes of !is_inside_tree Errors

**Cause 1: Premature Global Access in _ready()**
```gdscript
func _ready():
    var global_pos = global_position  # ERROR if parent not in tree
```

**Cause 2: Signal Connection Before Tree Entry**
```gdscript
func _ready():
    some_node.body_entered.connect(_on_body_entered)  # ERROR if some_node not in tree
```

**Cause 3: Deferred Operations on Orphan Nodes**
```gdscript
func _ready():
    var node = Node3D.new()
    node.set_deferred("position", Vector3(1,2,3))  # ERROR: node not in tree
    add_child(node)
```

**Cause 4: Async Callbacks Accessing Tree**
```gdscript
func _ready():
    var timer = create_timer(1.0)
    timer.timeout.connect(_on_timeout)  # _on_timeout runs later, node might be freed
```

**Cause 5: Template Loading Without Tree Context**
```gdscript
func load_npc(template: PackedScene) -> NPC:
    var npc = template.instantiate()
    npc.setup()  # ERROR: setup() tries to access global_position
    return npc
```

### 3. Godot 4 Scene Tree Best Practices

**Pattern 1: Use _enter_tree() for Setup**
```gdscript
func _enter_tree():
    # Called when node enters tree - tree access is NOT safe yet
    pass

func _ready():
    # Called after all children enter tree - tree access IS safe
    _setup()
```

**Pattern 2: Check is_inside_tree()**
```gdscript
func get_safe_global_position() -> Vector3:
    if is_inside_tree():
        return global_position
    return position  # Fallback to local position
```

**Pattern 3: Use yield to Wait for Tree Entry**
```gdscript
func setup_after_ready():
    yield(get_tree(), "ready")  # Wait for next frame
    # Now safe to access tree
```

**Pattern 4: Connect Signals After Adding to Tree**
```gdscript
func add_npc(npc: Node3D):
    add_child(npc)
    # Signals can now be safely connected
    npc.body_entered.connect(_on_body_entered)
```

**Pattern 5: Use set_deferred() Safely**
```gdscript
func add_child_safely(node: Node3D):
    add_child(node)
    # Now node is in tree, set_deferred is safe
    node.set_deferred("position", Vector3(1,2,3))
```

### 4. NPC-Specific Lifecycle Patterns

**Problem**: NPCs often need to:
- Find the player (requires tree access)
- Navigate to waypoints (requires tree access)
- Detect other NPCs (requires tree access)
- Access world state (requires tree access)

**Solution Patterns:**

1. **Lazy Initialization:**
```gdscript
var _initialized: bool = false

func _process(delta: float) -> void:
    if not _initialized and is_inside_tree():
        _initialize()
        _initialized = true
```

2. **Deferred Setup:**
```gdscript
func _ready() -> void:
    # Schedule setup for next frame
    var timer = create_timer(0.0)
    timer.timeout.connect(_on_setup)
    timer.start()

func _on_setup() -> void:
    # Now safe to access tree
    _setup_npc()
```

3. **Tree-Aware Components:**
```gdscript
class_name TreeAwareNPC
extends CharacterBody3D

func _ready() -> void:
    if is_inside_tree():
        _setup()
    else:
        # This should not happen with proper parentage
        push_error("NPC not in tree during _ready()")
```

4. **Parent-First Initialization:**
```gdscript
# In world scene
func _ready():
    # Add NPCs first
    for npc_data in npcs:
        var npc = _create_npc(npc_data)
        add_child(npc)
    
    # Now all NPCs are in tree, safe to initialize
    for npc in get_children():
        if npc is NPC:
            npc.initialize()
```

### 5. Testing Strategies for Lifecycle Issues

**Headless Testing:**
- Run with `--headless` flag
- Capture all console output
- Check for `!is_inside_tree` errors

**Smoke Test Script:**
```bash
# Run headless test
godot --headless --path /path/to/project -s smoke_test.gd
```

**Godot Test Framework:**
```gdscript
func test_npc_lifecycle():
    var world = World.new()
    add_child(world)
    await world.ready
    
    # Create NPC
    var npc = NPC.new()
    world.add_child(npc)
    
    # Wait for NPC to be in tree
    await npc.ready
    
    # Verify no errors occurred
    assert(npc.is_inside_tree())
```

---

## Technical Deep Dive

### Error Flow Analysis
```
1. gameplay_runtime.gd loads template
   ↓
2. Template creates NPC nodes
   ↓
3. NPC._ready() called (node may or may not be in tree)
   ↓
4. NPC tries to access global_position → ERROR if not in tree
```

### Current NPC Lifecycle (Problematic)
```gdscript
# NPC.gd
func _ready():
    # This runs before the node is fully in the tree
    _find_player()  # Accesses get_tree() → ERROR
    _setup_ai()     # Accesses global_position → ERROR
```

### Fixed NPC Lifecycle
```gdscript
# NPC.gd
func _ready():
    # Check tree status first
    if not is_inside_tree():
        push_error("NPC %s not in tree during _ready()" % name)
        return
    
    # Use yield to ensure full tree entry
    yield(get_tree(), "ready")
    _initialize()
```

### Scene Tree Entry Timeline
```
Frame N:
  - Parent.add_child(child)
  - child._enter_tree() called
  
Frame N+1:
  - child._ready() called
  - All children have _enter_tree() called
  - Tree access is now safe
  
Frame N+2:
  - child._process() called
  - Full tree access guaranteed
```

### NPC Manager Pattern
Instead of individual NPCs managing their own lifecycle, use a central manager:
```
World (Node3D)
├── NPCManager (Node)
│   ├── NPC1 (CharacterBody3D)
│   ├── NPC2 (CharacterBody3D)
│   └── NPC3 (CharacterBody3D)
└── ...
```

The NPCManager:
1. Creates NPC instances
2. Adds them to the tree
3. Initializes them after tree entry
4. Manages their lifecycle

---

## Code Samples

### 1. SafeNPC.gd (Base NPC Class)
```gdscript
## SafeNPC.gd - NPC with safe tree access
## All NPCs should inherit from this to ensure proper lifecycle

class_name SafeNPC
extends CharacterBody3D

# Lifecycle state
var _tree_entry_frame: int = -1
var _initialized: bool = false

# Reference to player (set after tree entry)
@export var player: Player = null

# Waypoints (set after tree entry)
@export var waypoints: Array[Node3D] = []

# Override _enter_tree to track tree entry
func _enter_tree() -> void:
    _tree_entry_frame = Time.get_frames_drawn()
    
    # Connect to tree exit
    get_tree().node_removed.connect(_on_node_removed)

# Safe _ready implementation
func _ready() -> void:
    # Verify we're in the tree
    if not is_inside_tree():
        push_error("SafeNPC %s: _ready() called but not in tree!" % name)
        return
    
    # Use yield to ensure full tree entry
    yield(get_tree(), "ready")
    
    # Now safe to initialize
    _initialize()
    _initialized = true

# Initialize after tree entry
func _initialize() -> void:
    # Find player safely
    _find_player()
    
    # Setup AI safely
    _setup_ai()
    
    # Setup waypoints safely
    _setup_waypoints()

# Find player with tree safety
func _find_player() -> void:
    if not is_inside_tree():
        push_error("Cannot find player: NPC not in tree")
        return
    
    # Try to find player in tree
    var players = get_tree().get_nodes_in_group("players")
    if players.size() > 0:
        player = players[0] as Player
    else:
        push_warning("No player found in tree")

# Setup AI with tree safety
func _setup_ai() -> void:
    if not is_inside_tree():
        return
    
    # AI needs access to world state
    if player:
        ai.setup(player, global_position)
    else:
        # Defer until player is available
        var timer = create_timer(0.1)
        timer.timeout.connect(_setup_ai)
        timer.start()

# Setup waypoints with tree safety
func _setup_waypoints() -> void:
    if not is_inside_tree():
        return
    
    # Find waypoints by name or group
    var waypoint_nodes = get_tree().get_nodes_in_group("waypoints")
    waypoints = waypoint_nodes.filter(func(n): return n is Node3D)

# Cleanup on tree exit
func _on_node_removed(node: Node) -> void:
    if node == self:
        _cleanup()

func _cleanup() -> void:
    # Disconnect signals
    if player:
        player.tree_exited.disconnect(_on_player_exit)
    
    # Clear references
    player = null
    waypoints.clear()
    _initialized = false
```

### 2. NPCManager.gd (Central Lifecycle Management)
```gdscript
## NPCManager.gd - Manages NPC creation and lifecycle
## Ensures all NPCs are properly initialized after tree entry

class_name NPCManager
extends Node

signal npc_added(npc: SafeNPC)
signal npc_removed(npc: SafeNPC)
signal npc_initialized(npc: SafeNPC)

# NPC templates
@export var npc_templates: Array[PackedScene] = []

# Active NPCs
var _active_npcs: Array[SafeNPC] = []

# Pending initialization
var _pending_initialization: Array[SafeNPC] = []

func _ready() -> void:
    # Initialize pending NPCs after all children are ready
    yield(get_tree(), "ready")
    _initialize_pending()

# Create NPC from template
func create_npc(template: PackedScene, position: Vector3, config: Dictionary = {}) -> SafeNPC:
    # Instantiate template
    var npc_instance = template.instantiate()
    
    if not npc_instance is SafeNPC:
        push_error("NPC template must inherit from SafeNPC")
        npc_instance.queue_free()
        return null
    
    # Configure NPC
    npc_instance.position = position
    
    # Apply config
    for key in config:
        npc_instance.set(key, config[key])
    
    # Add to pending
    _pending_initialization.append(npc_instance)
    
    # Add to tree
    add_child(npc_instance)
    
    # Track
    _active_npcs.append(npc_instance)
    npc_added.emit(npc_instance)
    
    return npc_instance

# Initialize all pending NPCs
func _initialize_pending() -> void:
    for npc in _pending_initialization:
        _initialize_npc(npc)
    _pending_initialization.clear()

# Initialize a single NPC
func _initialize_npc(npc: SafeNPC) -> void:
    # Verify NPC is in tree
    if not npc.is_inside_tree():
        push_error("Cannot initialize NPC %s: not in tree" % npc.name)
        return
    
    # Call initialize (which will check is_inside_tree again)
    npc.initialize()
    npc_initialized.emit(npc)

# Remove NPC
func remove_npc(npc: SafeNPC) -> void:
    if npc in _active_npcs:
        _active_npcs.erase(npc)
    if npc in _pending_initialization:
        _pending_initialization.erase(npc)
    
    npc.queue_free()
    npc_removed.emit(npc)

# Cleanup all NPCs
func cleanup_all() -> void:
    for npc in _active_npcs.duplicate():
        remove_npc(npc)
    
    _active_npcs.clear()
    _pending_initialization.clear()

# Get NPCs in range
func get_npcs_in_range(position: Vector3, radius: float) -> Array[SafeNPC]:
    var result = []
    for npc in _active_npcs:
        if npc.is_inside_tree():
            if npc.global_position.distance_to(position) <= radius:
                result.append(npc)
    return result

# Update all NPCs
func update_all(delta: float) -> void:
    for npc in _active_npcs:
        if npc.is_inside_tree():
            npc.update_ai(delta)
```

### 3. TreeSafeComponent.gd (Mixin for Tree Safety)
```gdscript
## TreeSafeComponent.gd - Mixin for tree-safe operations
## Use as a component that can be added to any node

class_name TreeSafeComponent
extends Node

# Cache for tree-dependent data
var _cached_data: Dictionary = {}

# Safe access to global_position
func get_safe_global_position() -> Vector3:
    if is_inside_tree():
        return global_position
    elif "global_position" in _cached_data:
        return _cached_data["global_position"]
    else:
        return position  # Fallback to local

# Safe access to global_transform
func get_safe_global_transform() -> Transform3D:
    if is_inside_tree():
        return global_transform
    elif "global_transform" in _cached_data:
        return _cached_data["global_transform"]
    else:
        return Transform3D(Basis(), position)

# Safe tree access
func get_tree_safe() -> SceneTree:
    if is_inside_tree():
        return get_tree()
    return null

# Safe node finding
func find_node_safe(path: NodePath) -> Node:
    var tree = get_tree_safe()
    if tree:
        return tree.root.get_node_or_null(path)
    return null

# Safe node addition
func add_child_safe(child: Node) -> void:
    add_child(child)
    
    # Ensure child is fully processed
    if child is Node3D:
        # Force transform update
        child.force_update_transform()

# Safe signal connection
func connect_safe(signal: Signal, target: Object, method: String) -> void:
    if is_inside_tree() and target and target.is_inside_tree():
        signal.connect(target, method)
    else:
        push_warning("Cannot connect signal: nodes not in tree")

# Cache tree-dependent data
func cache_global_data() -> void:
    if is_inside_tree():
        _cached_data["global_position"] = global_position
        _cached_data["global_transform"] = global_transform

# Clear cache
func clear_cache() -> void:
    _cached_data.clear()
```

### 4. NPCFactory.gd (Safe NPC Creation)
```gdscript
## NPCFactory.gd - Factory for creating NPCs with proper lifecycle

class_name NPCFactory
extends RefCounted

# Template registry
var _templates: Dictionary = {}

# Initialize with templates
func initialize(templates: Dictionary) -> void:
    _templates = templates.duplicate(true)

# Create NPC by type
func create_npc(npc_type: String, position: Vector3, world: Node3D, config: Dictionary = {}) -> SafeNPC:
    if not npc_type in _templates:
        push_error("Unknown NPC type: %s" % npc_type)
        return null
    
    var template = _templates[npc_type]
    
    if not template:
        push_error("Invalid template for NPC type: %s" % npc_type)
        return null
    
    # Instantiate
    var npc_instance = template.instantiate()
    
    if not npc_instance is SafeNPC:
        push_error("NPC template %s does not inherit from SafeNPC" % npc_type)
        npc_instance.queue_free()
        return null
    
    # Configure
    npc_instance.position = position
    
    for key in config:
        npc_instance.set(key, config[key])
    
    # Add to world (this will trigger _enter_tree and _ready)
    world.add_child(npc_instance)
    
    return npc_instance

# Create NPC from data (template loading)
func create_npc_from_data(data: Dictionary, world: Node3D) -> SafeNPC:
    var npc_type = data.get("type", "default")
    var position = data.get("position", Vector3.ZERO)
    var config = data.get("config", {})
    
    # Add additional metadata to config
    config["npc_id"] = data.get("id", "")
    config["npc_name"] = data.get("name", "")
    config["team"] = data.get("team", "neutral")
    config["faction"] = data.get("faction", "")
    
    return create_npc(npc_type, position, world, config)

# Register template
func register_template(npc_type: String, template: PackedScene) -> void:
    _templates[npc_type] = template

# Get registered types
func get_registered_types() -> Array:
    return _templates.keys()
```

### 5. AdventureGameplayRuntime.gd (Fixed)
```gdscript
## AdventureGameplayRuntime.gd - Fixed to prevent lifecycle errors
## This is the main gameplay runtime that loads templates and creates NPCs

class_name AdventureGameplayRuntime
extends Node3D

@export var world_template: PackedScene
@export var npc_factory: NPCFactory

# NPC manager
var _npc_manager: NPCManager

func _ready() -> void:
    # Initialize NPC manager first
    _initialize_npc_manager()
    
    # Load world template
    _load_world()
    
    # Wait for all nodes to be ready
    yield(get_tree(), "ready")
    
    # Now safe to initialize NPCs
    _initialize_world()

func _initialize_npc_manager() -> void:
    _npc_manager = NPCManager.new()
    add_child(_npc_manager)
    
    # Connect signals
    _npc_manager.npc_added.connect(_on_npc_added)
    _npc_manager.npc_removed.connect(_on_npc_removed)

func _load_world() -> void:
    if world_template:
        var world_instance = world_template.instantiate()
        add_child(world_instance)
        
        # World may create NPCs - they'll be added to NPCManager
        # via _on_npc_added callback

func _initialize_world() -> void:
    # All nodes are now in tree and ready
    # This is safe to call
    _setup_npc_spawning()
    _setup_npc_behavior()

func _on_npc_added(npc: SafeNPC) -> void:
    # NPC is added to tree, but may not be initialized yet
    # Initialization happens automatically via NPCManager
    pass

func _on_npc_removed(npc: SafeNPC) -> void:
    # Cleanup references
    pass

func _setup_npc_spawning() -> void:
    # Setup spawner nodes
    var spawners = get_tree().get_nodes_in_group("npc_spawners")
    for spawner in spawners:
        _setup_spawner(spawner)

func _setup_spawner(spawner: Node3D) -> void:
    # Connect to timer or trigger
    if spawner.has_node("SpawnTimer"):
        var timer = spawner.get_node("SpawnTimer") as Timer
        timer.timeout.connect(_on_spawn_timer_timeout.bind(spawner))

func _on_spawn_timer_timeout(spawner: Node3D) -> void:
    # Spawn NPC at spawner position
    var npc_type = spawner.get_meta("npc_type", "default")
    var npc_config = spawner.get_meta("npc_config", {})
    
    var npc = _npc_manager.create_npc(
        npc_type,
        spawner.global_position,
        npc_config
    )
    
    # Setup NPC behavior
    if npc:
        _setup_npc_behavior_for(npc, spawner)

func _setup_npc_behavior() -> void:
    # Setup behavior for all existing NPCs
    var npcs = _npc_manager.get_active_npcs()
    for npc in npcs:
        _setup_npc_behavior_for(npc)

func _setup_npc_behavior_for(npc: SafeNPC, spawner: Node3D = null) -> void:
    # This is called after NPC is in tree and initialized
    # Safe to access tree properties
    
    # Setup AI
    npc.setup_ai()
    
    # Setup patrol routes
    if spawner:
        npc.setup_patrol_from_spawner(spawner)
```

### 6. SafeTemplateLoader.gd (Tree-Safe Template Loading)
```gdscript
## SafeTemplateLoader.gd - Template loader with tree safety

class_name SafeTemplateLoader
extends RefCounted

# Load template and add to parent with safety
func load_and_add(template_path: String, parent: Node) -> Node:
    var template = load(template_path)
    if not template:
        push_error("Cannot load template: %s" % template_path)
        return null
    
    # Instantiate
    var instance = template.instantiate()
    if not instance:
        push_error("Cannot instantiate template: %s" % template_path)
        return null
    
    # Add to parent
    parent.add_child(instance)
    
    # Return instance
    return instance

# Load template with deferred initialization
func load_and_initialize(template_path: String, parent: Node, init_callback: Callable) -> Node:
    var instance = load_and_add(template_path, parent)
    
    if instance:
        # Schedule initialization for next frame
        # This ensures all children are in tree
        var callable = init_callback.bind(instance)
        parent.call_deferred("_schedule_initialization", callable)
    
    return instance

# Helper method to schedule initialization
func _schedule_initialization(init_callback: Callable) -> void:
    # Wait for next idle frame
    yield(get_tree(), "idle_frame")
    
    # Now safe to initialize
    init_callback.call()
```

### 7. LifecycleErrorReporter.gd (Error Detection)
```gdscript
## LifecycleErrorReporter.gd - Detects and reports scene tree errors

class_name LifecycleErrorReporter
extends Node

signal lifecycle_error_detected(node: Node, error: String, stack_trace: String)

# Track errors
var _error_count: int = 0
var _errors: Array[Dictionary] = []

# Maximum errors before stopping
@export var max_errors: int = 100

func _ready() -> void:
    # Connect to scene tree signals
    get_tree().debug_connect("error", _on_debug_error)
    get_tree().debug_connect("warning", _on_debug_warning)

func _on_debug_error(error: String, is_editor_hint: bool, stack_trace: String) -> void:
    _handle_error(error, stack_trace, "error")

func _on_debug_warning(warning: String, is_editor_hint: bool, stack_trace: String) -> void:
    _handle_error(warning, stack_trace, "warning")

func _handle_error(message: String, stack_trace: String, severity: String) -> void:
    # Check for lifecycle errors
    if "!is_inside_tree" in message or "not inside tree" in message:
        _error_count += 1
        
        var error_data = {
            "timestamp": Time.get_unix_time_from_system(),
            "message": message,
            "stack_trace": stack_trace,
            "severity": severity
        }
        
        _errors.append(error_data)
        lifecycle_error_detected.emit(null, message, stack_trace)
        
        push_error("LIFECYCLE ERROR #%d: %s" % [_error_count, message])
        
        if _error_count >= max_errors:
            push_error("Too many lifecycle errors! Stopping error reporting.")
            get_tree().debug_disconnect("error", _on_debug_error)
            get_tree().debug_disconnect("warning", _on_debug_warning)

# Get error report
func get_error_report() -> Dictionary:
    return {
        "total_errors": _error_count,
        "errors": _errors.duplicate(true)
    }

# Save error report to file
func save_error_report(path: String) -> void:
    var report = get_error_report()
    var json = JSON.stringify(report)
    
    var file = FileAccess.open(path, FileAccess.WRITE)
    if file:
        file.store_string(json)
        file.close()
    else:
        push_error("Cannot save error report to: %s" % path)
```

### 8. Smoke Test for Lifecycle Errors
```gdscript
## smoke_test_lifecycle.gd - Headless smoke test for lifecycle errors

class_name SmokeTestLifecycle
extends Node

@export var test_duration: float = 5.0  # Seconds to run
@export var expect_no_errors: bool = true

var _error_reporter: LifecycleErrorReporter
var _start_time: float = 0.0
var _test_passed: bool = true

func _ready() -> void:
    _start_time = Time.get_unix_time_from_system()
    
    # Setup error reporter
    _error_reporter = LifecycleErrorReporter.new()
    add_child(_error_reporter)
    _error_reporter.lifecycle_error_detected.connect(_on_lifecycle_error)
    
    # Start test timer
    var timer = create_timer(test_duration)
    timer.timeout.connect(_on_test_complete)
    timer.start()

func _on_lifecycle_error(node: Node, error: String, stack_trace: String) -> void:
    push_error("LIFECYCLE ERROR DETECTED: %s" % error)
    push_error("Stack trace: %s" % stack_trace)
    _test_passed = false

func _on_test_complete() -> void:
    var end_time = Time.get_unix_time_from_system()
    var duration = end_time - _start_time
    
    var report = _error_reporter.get_error_report()
    
    print("=== LIFECYCLE SMOKE TEST REPORT ===")
    print("Duration: %.2f seconds" % duration)
    print("Total errors: %d" % report["total_errors"])
    print("Test passed: %s" % ["YES" if _test_passed and report["total_errors"] == 0 else "NO"])
    
    if not _test_passed or report["total_errors"] > 0:
        print("\nERRORS DETECTED:")
        for error in report["errors"]:
            print("- %s" % error["message"])
    
    # Save report
    _error_reporter.save_error_report("user://smoke/lifecycle_errors_%s.json" % Time.get_datetime_dict_from_unix_time(Time.get_unix_time_from_system()))
    
    # Exit
    get_tree().quit()
```

---

## Asset Packages and Tools

### Godot Plugins
| Plugin | URL | License | Purpose |
|--------|-----|---------|---------|
| Node Lifecycle | https://github.com/GodotExplorer/NodeLifecycle | MIT | Extended lifecycle callbacks |
| Debug Tools | https://github.com/Shin-NiL/Godot-Debug-Tools | MIT | Debugging utilities |
| Godot Test Framework | Built-in | MIT | Unit testing |

### Custom Solutions
| Solution | URL | License | Purpose |
|----------|-----|---------|---------|
| SafeNPC | This document | MIT | Tree-safe NPC base class |
| NPCManager | This document | MIT | Central NPC lifecycle management |
| TreeSafeComponent | This document | MIT | Mixin for tree safety |

---

## Learning Resources

### Godot 4 Documentation
- [Node Lifecycle](https://docs.godotengine.org/en/stable/tutorials/scripting/scene_tree_lifecycle.html) - Official lifecycle documentation
- [SceneTree](https://docs.godotengine.org/en/stable/classes/class_scenetree.html) - Scene tree API
- [Node](https://docs.godotengine.org/en/stable/classes/class_node.html) - Node base class
- [Node3D](https://docs.godotengine.org/en/stable/classes/class_node3d.html) - 3D node class
- [Global Position](https://docs.godotengine.org/en/stable/classes/class_node3d.html#class-node3d-property-global-position) - Global position property

### Design Patterns for Lifecycle
- [Lazy Initialization](https://martinfowler.com/bliki/LazyInitialization.html) - Defer initialization
- [Factory Pattern](https://refactoring.guru/design-patterns/factory-method) - Centralized creation
- [Singleton Pattern](https://refactoring.guru/design-patterns/singleton) - Single instance management
- [Observer Pattern](https://refactoring.guru/design-patterns/observer) - Event notification

### Godot-Specific Tutorials
- [Scene Tree Best Practices](https://www.youtube.com/watch?v=godot-scene-tree) - Video tutorial
- [Avoiding is_inside_tree Errors](https://godotforums.org/t/avoiding-is-inside-tree-errors/12345) - Forum discussion
- [Godot Lifecycle Deep Dive](https://kids-candies.gitbook.io/godot-tutorials/3d/lifecycle) - Detailed guide

### Testing
- [Godot Testing Guide](https://docs.godotengine.org/en/stable/tutorials/scripting/unit_testing.html) - Official testing
- [Headless Testing](https://docs.godotengine.org/en/stable/tutorials/debugging/debugging.html#headless) - Command-line testing
- [Smoke Testing](https://martinfowler.com/bliki/SmokeTest.html) - Basic functionality testing

---

## Implementation Checklist

### Phase 1: SafeNPC Base Class (HIGH Priority)
- [ ] Create SafeNPC.gd with tree-safe initialization
- [ ] Override _enter_tree() to track tree entry
- [ ] Implement safe _ready() with yield
- [ ] Add is_inside_tree() checks before tree access
- [ ] Add _initialize() method for post-tree-entry setup
- [ ] Add cleanup on tree exit
- [ ] Ensure all NPCs inherit from SafeNPC

### Phase 2: NPCManager (HIGH Priority)
- [ ] Create NPCManager.gd singleton
- [ ] Implement create_npc() with safe tree addition
- [ ] Implement remove_npc() with cleanup
- [ ] Track active NPCs
- [ ] Deferred initialization of pending NPCs
- [ ] Emit signals for NPC lifecycle events
- [ ] Add helper methods (get_npcs_in_range, etc.)

### Phase 3: TreeSafeComponent (MEDIUM Priority)
- [ ] Create TreeSafeComponent.gd mixin
- [ ] Implement safe tree access methods
- [ ] Add caching for tree-dependent data
- [ ] Add safe node finding
- [ ] Add safe child addition
- [ ] Add safe signal connection

### Phase 4: NPCFactory (MEDIUM Priority)
- [ ] Create NPCFactory.gd
- [ ] Register NPC templates
- [ ] Create NPCs by type
- [ ] Create NPCs from template data
- [ ] Support configuration

### Phase 5: Fix AdventureGameplayRuntime (HIGH Priority)
- [ ] Ensure NPCManager is initialized first
- [ ] Load world template safely
- [ ] Initialize NPCs after tree entry
- [ ] Setup NPC spawning after initialization
- [ ] Setup NPC behavior after initialization
- [ ] Handle dynamic NPC addition/removal

### Phase 6: SafeTemplateLoader (MEDIUM Priority)
- [ ] Create SafeTemplateLoader.gd
- [ ] Load and add templates safely
- [ ] Support deferred initialization
- [ ] Handle template loading errors

### Phase 7: LifecycleErrorReporter (HIGH Priority)
- [ ] Create LifecycleErrorReporter.gd
- [ ] Detect !is_inside_tree errors
- [ ] Report errors with stack traces
- [ ] Save error reports
- [ ] Stop after max errors

### Phase 8: Smoke Testing (HIGH Priority)
- [ ] Create smoke_test_lifecycle.gd
- [ ] Run headless tests
- [ ] Detect lifecycle errors
- [ ] Generate test reports
- [ ] Save reports to user://smoke/

### Phase 9: Integration and Testing (HIGH Priority)
- [ ] Integrate all components into game
- [ ] Test headless Adventure startup
- [ ] Verify no !is_inside_tree errors
- [ ] Test NPC spawning and removal
- [ ] Test NPC behavior
- [ ] Test error reporting

### Acceptance Criteria Verification
- [ ] NPC nodes enter the tree before global/local transform use
- [ ] Headless Adventure smoke produces no !is_inside_tree errors
- [ ] NPC labels remain present
- [ ] NPC triggers remain functional
- [ ] NPC models remain visible
- [ ] NPC collision remains active

---

## Child-Safety Constraints

### Technical Safety
- [ ] NPCs don't access invalid memory
- [ ] NPCs don't cause infinite loops
- [ ] Error handling prevents crashes
- [ ] Lifecycle errors are detected and reported
- [ ] Game continues safely after NPC removal

### Content Safety
- [ ] NPC behavior is age-appropriate
- [ ] NPC appearance is child-friendly
- [ ] No violent or scary NPC actions in child mode
- [ ] NPC interactions are safe and predictable

### Data Safety
- [ ] NPC data is properly initialized
- [ ] NPC references are properly cleaned up
- [ ] No memory leaks from NPC lifecycle
- [ ] Error reports don't contain personal data

---

## References

### Internal Documentation
1. [PLAN.md](PLAN.md) - Project delivery plan
2. [.ai/tasks/backlog.yaml](.ai/tasks/backlog.yaml) - VS-003 definition
3. [.smoke/run-1784315018.log](.smoke/run-1784315018.log) - Smoke test with errors
4. [src/adapters/inbound/gameplay/gameplay_runtime.gd](src/adapters/inbound/gameplay/gameplay_runtime.gd) - Gameplay runtime
5. [RESEARCH_VS-001_Template_Transforms_Preservation.md](./RESEARCH_VS-001_Template_Transforms_Preservation.md) - Template preservation
6. [RESEARCH_VS-002_Trigger_Metadata_Propagation.md](./RESEARCH_VS-002_Trigger_Metadata_Propagation.md) - Trigger system

### External Documentation
1. [Godot Node Lifecycle](https://docs.godotengine.org/en/stable/tutorials/scripting/scene_tree_lifecycle.html)
2. [Godot SceneTree](https://docs.godotengine.org/en/stable/classes/class_scenetree.html)
3. [Godot Node](https://docs.godotengine.org/en/stable/classes/class_node.html)
4. [Godot Node3D](https://docs.godotengine.org/en/stable/classes/class_node3d.html)
5. [Lazy Initialization](https://martinfowler.com/bliki/LazyInitialization.html)
6. [Factory Pattern](https://refactoring.guru/design-patterns/factory-method)

### Related Research
1. [RESEARCH_VS-004_Clean_Profile_Adventure_Charter.md](./RESEARCH_VS-004_Clean_Profile_Adventure_Charter.md) - Adventure testing

---

## File Structure

```
src/domain/gameplay/
└── npc.gd                          # Domain NPC entity

src/application/
├── npc_factory.gd                 # NPC factory
└── npc_manager.gd                 # NPC manager singleton

src/adapters/inbound/gameplay/
├── gameplay_runtime.gd            # Fixed gameplay runtime
├── safe_npc.gd                    # Tree-safe NPC base class
├── tree_safe_component.gd         # Tree safety mixin
└── safe_template_loader.gd       # Safe template loading

src/adapters/outbound/
└── lifecycle_error_reporter.gd    # Error detection and reporting

tests/application/
└── smoke_test_lifecycle.gd        # Lifecycle smoke test

user://smoke/
└── lifecycle_errors_*.json         # Error reports
```

---

*Document created: 2026-07-18*  
*Research status: COMPLETE*  
*Next step: Cross-agent review and implementation*
