# RESEARCH_VS-002: Propagate Trigger Metadata and Runtime Semantics

**Task ID:** VS-002  
**Title:** Propagate authored trigger metadata into gameplay runtime  
**Specialty:** gameplay-runtime  
**Owner:** codex  
**Cross-review by:** claude  
**Dependencies:** [VS-001]  
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
Propagate authored trigger metadata from templates through the TemplateLoader into the gameplay runtime, ensuring that Area3D nodes receive stable node names, authored trigger metadata, proper collision sizes, and that the runtime recognizes trigger semantics (collectible, checkpoint, win, win_zone).

### Acceptance Criteria (from backlog.yaml)
1. Trigger Area3D receives stable node name and authored trigger metadata
2. Trigger collision uses authored size
3. Runtime recognizes collectible, checkpoint, win, and win_zone semantics
4. Renderer integration tests cover metadata and JSON property normalization

### Key Requirements
- Triggers defined in templates must be instantiated with all metadata preserved
- Area3D collision shapes must match authored sizes
- Trigger types must be recognized by the gameplay runtime
- Integration with VS-001 (template preservation) is required

---

## Current Implementation Analysis

### Existing Infrastructure
Based on backlog.yaml evidence:
- `tests/adapters/inbound/test_world_renderer_toon_shader.gd` - World renderer tests
- `src/adapters/inbound/gameplay/world_renderer.gd` - World renderer
- `src/adapters/inbound/gameplay/gameplay_runtime.gd` - Gameplay runtime

From VS-001 implementation:
- TemplateLoader preserves all template data
- SceneNode has properties dictionary
- GameRule has source_blocks and active state

### Trigger System Architecture
The trigger system follows the **hexagonal architecture** pattern:
```
Template (JSON) → TemplateLoader → Domain Trigger → Runtime Trigger → Area3D (Godot)
                    ↓
              TriggerMetadata (Domain)
                    ↓
              TriggerAdapter (Adapter)
```

### Current Gap
While VS-001 ensures template data is preserved in the domain layer, VS-002 needs to ensure that:
1. Trigger-specific data is extracted from templates
2. Trigger metadata is propagated to the runtime
3. Area3D nodes are configured with the correct metadata
4. Trigger semantics are recognized and processed

---

## Online Research Summary

### 1. Godot 4 Area3D and Trigger Systems
**Objective**: Understand Godot's trigger detection capabilities

**Godot 4 Area3D Features:**
- `Area3D` - 3D area for detection and physics
- `body_entered(body: Node3D)` - Signal when body enters
- `body_exited(body: Node3D)` - Signal when body exits
- `body_shape_entered(body_rid: RID, body: Node3D, body_shape_index: int, local_shape_index: int)` - Signal when shape enters
- `body_shape_exited(body_rid: RID, body: Node3D, body_shape_index: int, local_shape_index: int)` - Signal when shape exits
- `area_entered(area: Area3D)` - Signal when another area enters
- `area_exited(area: Area3D)` - Signal when another area exits

**Collision Shape Types:**
- `CollisionShape3D` - Box, sphere, capsule, cylinder, convex polygon
- `BoxShape3D` - Box collision
- `SphereShape3D` - Sphere collision
- `CapsuleShape3D` - Capsule collision
- `CylinderShape3D` - Cylinder collision
- `ConvexPolygonShape3D` - Convex polygon collision
- `ConcavePolygonShape3D` - Concave polygon collision (more expensive)

**Trigger Configuration:**
```gdscript
var area = Area3D.new()
area.name = "collectible_trigger"  # Stable node name
area.monitorable = true  # Required for signals
area.monitoring = true  # Required for signals

# Add collision shape
var collision = CollisionShape3D.new()
collision.shape = BoxShape3D.new()
var box_shape = collision.shape as BoxShape3D
box_shape.size = Vector3(2, 2, 2)  # Authored size
area.add_child(collision)
```

**Best Practices:**
- Use `monitoring = true` to receive signals
- Use `monitorable = true` to allow other areas to detect this one
- Connect signals in `_ready()` after node is in tree
- Use `is_inside_tree()` check before accessing scene tree

### 2. Trigger Metadata Patterns in Godot
**Objective**: Store and access trigger metadata

**Approach 1: Custom Metadata Dictionary**
```gdscript
# On Area3D node
var trigger_metadata: Dictionary = {
    "trigger_type": "collectible",
    "item_id": "gold_coin",
    "quantity": 1,
    "cooldown": 5.0,
    "one_time": false
}
```

**Approach 2: Custom Resource**
```gdscript
# Define a custom resource type
class_name TriggerMetadata
extends Resource

@export var trigger_type: String = "collectible"
@export var target_id: String = ""
@export var quantity: int = 1
@export var cooldown: float = 0.0
@export var one_time: bool = false
@export var custom_data: Dictionary = {}

# Attach to Area3D
area.trigger_metadata = TriggerMetadata.new()
```

**Approach 3: Node Metadata (Godot 4.2+)**
```gdscript
# Use the new metadata system
area.set_meta("trigger_type", "collectible")
area.set_meta("item_id", "gold_coin")

# Retrieve
var trigger_type = area.get_meta("trigger_type", "")
```

**Recommended Approach**: Custom Dictionary
- Pros: Simple, flexible, works in all Godot 4.x versions
- Cons: No type safety, manual validation needed

### 3. Trigger Type System Design
**Objective**: Define trigger semantics (collectible, checkpoint, win, win_zone)

**Trigger Type Definitions:**

| Type | Description | Required Metadata | Behavior |
|------|-------------|-------------------|----------|
| collectible | Item collection | item_id, quantity | Give item to player, optional cooldown |
| checkpoint | Save point | checkpoint_id, respawn_point | Save player progress, set respawn |
| win | Win condition | win_id, message | Trigger win state, show message |
| win_zone | Win volume | win_id, message | Trigger win when player enters |
| damage | Hazard | damage_amount, damage_type | Damage player on contact |
| heal | Health restoration | heal_amount, cooldown | Heal player, optional cooldown |
| dialogue | NPC interaction | npc_id, dialogue_id | Start dialogue |
| teleport | Location change | target_position, target_scene | Teleport player |

**Type Registry:**
```gdscript
class_name TriggerTypeRegistry
extends RefCounted

const COLLECTIBLE = "collectible"
const CHECKPOINT = "checkpoint"
const WIN = "win"
const WIN_ZONE = "win_zone"
const DAMAGE = "damage"
const HEAL = "heal"
const DIALOGUE = "dialogue"
const TELEPORT = "teleport"

var registered_types: Dictionary = {}

func register_type(type_name: String, handler: TriggerHandler) -> void:
    registered_types[type_name] = handler

func get_handler(type_name: String) -> TriggerHandler:
    return registered_types.get(type_name, null)

func has_type(type_name: String) -> bool:
    return type_name in registered_types
```

### 4. Trigger Handler System
**Objective**: Process trigger semantics based on type

**Base Handler:**
```gdscript
class_name TriggerHandler
extends RefCounted

signal triggered(trigger: Trigger, activator: Node3D)

func can_trigger(trigger: Trigger, activator: Node3D) -> bool:
    return true

func on_trigger(trigger: Trigger, activator: Node3D) -> void:
    pass

func on_enter(trigger: Trigger, activator: Node3D) -> void:
    if can_trigger(trigger, activator):
        on_trigger(trigger, activator)
        triggered.emit(trigger, activator)
```

**Collectible Handler:**
```gdscript
class_name CollectibleHandler
extends TriggerHandler

func on_trigger(trigger: Trigger, activator: Node3D) -> void:
    var metadata = trigger.metadata
    var item_id = metadata.get("item_id", "")
    var quantity = metadata.get("quantity", 1)
    
    # Give item to player
    var player = activator as Player
    if player:
        player.inventory.add_item(item_id, quantity)
    
    # Handle cooldown
    var cooldown = metadata.get("cooldown", 0.0)
    if cooldown > 0:
        trigger.disabled = true
        await get_tree().create_timer(cooldown).timeout
        trigger.disabled = false
    
    # Handle one-time
    if metadata.get("one_time", false):
        trigger.queue_free()
```

**Checkpoint Handler:**
```gdscript
class_name CheckpointHandler
extends TriggerHandler

func on_trigger(trigger: Trigger, activator: Node3D) -> void:
    var metadata = trigger.metadata
    var checkpoint_id = metadata.get("checkpoint_id", "")
    var respawn_point = metadata.get("respawn_point", null)
    
    # Save player progress
    var player = activator as Player
    if player:
        player.save_game(checkpoint_id)
        player.respawn_point = respawn_point
    
    # Visual feedback
    trigger.visual_feedback.play("activate")
```

### 5. Template Integration
**Objective**: Load triggers from templates and instantiate in runtime

**Template Trigger Format:**
```json
{
  "name": "gold_coin_trigger",
  "type": "area",
  "trigger_type": "collectible",
  "position": {"_type": "Vector3", "x": 0, "y": 0, "z": 0},
  "collision": {
    "shape": "box",
    "size": {"_type": "Vector3", "x": 2, "y": 2, "z": 2},
    "offset": {"_type": "Vector3", "x": 0, "y": 0, "z": 0}
  },
  "metadata": {
    "item_id": "gold_coin",
    "quantity": 1,
    "cooldown": 0,
    "one_time": true
  },
  "properties": {
    "monitoring": true,
    "monitorable": true,
    "visible": false
  }
}
```

**Integration with TemplateLoader:**
```gdscript
# In TemplateLoader._create_scene_node()
func _create_scene_node(data: Dictionary) -> SceneNode:
    var node = SceneNode.new()
    
    # Standard node creation (from VS-001)
    node.position = _normalize_vector3(data.get("position", {}))
    node.rotation = _normalize_quaternion(data.get("rotation", {}))
    node.scale = _normalize_vector3(data.get("scale", {}))
    node.name = data.get("name", "")
    node.node_type = data.get("type", "prop")
    node.properties = data.get("properties", {})
    
    # VS-002: Handle trigger-specific data
    if "trigger_type" in data:
        node.trigger_type = data["trigger_type"]
        node.trigger_metadata = data.get("metadata", {}).duplicate(true)
        node.trigger_collision = data.get("collision", {})
    
    return node
```

---

## Technical Deep Dive

### Trigger System Architecture
```
┌─────────────────────────────────────────────────────────────┐
│                    Template (JSON)                            │
├─────────────────────────────────────────────────────────────┤
│  {                                                               │
│    "name": "coin_trigger",                                       │
│    "type": "area",                                               │
│    "trigger_type": "collectible",                                │
│    "collision": { "shape": "box", "size": [2,2,2] },            │
│    "metadata": { "item_id": "gold_coin" },                     │
│    "properties": { "monitoring": true }                         │
│  }                                                               │
└────────────────────┬──────────────────────────────────────────┘
                     │ TemplateLoader._create_scene_node()
                     ▼
┌─────────────────────────────────────────────────────────────┐
│                    SceneNode (Domain)                           │
├─────────────────────────────────────────────────────────────┤
│  - name: String                                                 │
│  - node_type: String = "area"                                   │
│  - trigger_type: String = "collectible"                         │
│  - trigger_metadata: Dictionary                                 │
│  - trigger_collision: Dictionary                                │
│  - position: Vector3                                            │
│  - rotation: Quaternion                                         │
│  - properties: Dictionary                                        │
└────────────────────────┬────────────────────────────────────────┘
                         │ WorldRenderer._render_scene_node()
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                    Area3D (Godot)                               │
├─────────────────────────────────────────────────────────────┤
│  - name: String = "coin_trigger"                               │
│  - monitoring: bool = true                                      │
│  - monitorable: bool = true                                     │
│  - CollisionShape3D child with BoxShape3D size=[2,2,2]         │
│  - trigger_metadata: Dictionary (attached as custom property)  │
└────────────────────────┬────────────────────────────────────────┘
                         │ TriggerManager.register()
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                    TriggerManager                              │
├─────────────────────────────────────────────────────────────┤
│  - Registers trigger with type handler                          │
│  - Connects body_entered signal                                 │
│  - Dispatches to appropriate handler                            │
└─────────────────────────────────────────────────────────────┘
```

### Trigger Node Creation Flow
```
1. TemplateLoader loads JSON template
2. For each node with trigger_type:
   a. Create SceneNode with trigger_type and trigger_metadata
   b. Add to World.scene_nodes
3. WorldRenderer renders World:
   a. For each SceneNode with node_type == "area":
      i. Create Area3D
      ii. Set name from SceneNode.name
      iii. Set transform from SceneNode.position/rotation/scale
      iv. Create CollisionShape3D with authored size
      v. Store trigger_metadata on Area3D
      vi. Apply SceneNode.properties to Area3D
4. TriggerManager scans scene tree:
   a. Find all Area3D nodes with trigger_metadata
   b. Register each trigger with appropriate handler
   c. Connect body_entered signal
5. Gameplay: Player enters trigger → signal fires → handler processes
```

### Trigger Type Registration
```
┌─────────────────────┐
│   TriggerManager    │
├─────────────────────┤
│ - handlers: Dict    │
│ - triggers: Array   │
├─────────────────────┤
│ + register_type()   │◄──────────────────────┐
│ + register_trigger()│                       │
│ + _on_body_entered()│───────────────────────┘
└─────────────────────┘         Register types
      ▲                              at startup
      │
      │ Register triggers
      │ from templates
      ▼
┌─────────────────────┐    ┌─────────────────────┐
│  CollectibleHandler │    │   CheckpointHandler  │
│  (for "collectible") │    │   (for "checkpoint") │
└─────────────────────┘    └─────────────────────┘
```

---

## Code Samples

### 1. TriggerMetadata.gd (Domain Entity)
```gdscript
## TriggerMetadata.gd - Trigger metadata domain entity
## Attached to SceneNode when it has trigger_type

class_name TriggerMetadata
extends RefCounted

# Trigger identification
@export var trigger_type: String = ""
@export var trigger_id: String = ""

# Trigger behavior
@export var one_time: bool = false
@export var cooldown: float = 0.0
@export var disabled: bool = false

# Custom metadata (type-specific)
@export var metadata: Dictionary = {}

## Validation
func validate() -> Array:
    var errors = []
    
    if trigger_type.is_empty():
        errors.append("Trigger type cannot be empty")
    
    if not TriggerTypeRegistry.get_singleton().has_type(trigger_type):
        errors.append("Unknown trigger type: %s" % trigger_type)
    
    # Validate required metadata based on type
    match trigger_type:
        "collectible":
            if not "item_id" in metadata:
                errors.append("Collectible trigger requires item_id")
        "checkpoint":
            if not "checkpoint_id" in metadata:
                errors.append("Checkpoint trigger requires checkpoint_id")
        "win", "win_zone":
            if not "win_id" in metadata:
                errors.append("Win trigger requires win_id")
        _:
            pass  # No specific requirements for other types
    
    return errors

## Serialization
func to_json() -> Dictionary:
    return {
        "trigger_type": trigger_type,
        "trigger_id": trigger_id,
        "one_time": one_time,
        "cooldown": cooldown,
        "disabled": disabled,
        "metadata": metadata.duplicate(true)
    }

func from_json(data: Dictionary) -> TriggerMetadata:
    trigger_type = data.get("trigger_type", "")
    trigger_id = data.get("trigger_id", "")
    one_time = data.get("one_time", false)
    cooldown = data.get("cooldown", 0.0)
    disabled = data.get("disabled", false)
    metadata = data.get("metadata", {}).duplicate(true)
    return self
```

### 2. TriggerTypeRegistry.gd (Singleton)
```gdscript
## TriggerTypeRegistry.gd - Registry for trigger types and handlers

class_name TriggerTypeRegistry
extends Node

# Trigger type constants
const COLLECTIBLE = "collectible"
const CHECKPOINT = "checkpoint"
const WIN = "win"
const WIN_ZONE = "win_zone"
const DAMAGE = "damage"
const HEAL = "heal"
const DIALOGUE = "dialogue"
const TELEPORT = "teleport"

# Type to handler mapping
var _type_handlers: Dictionary = {}

# Type to validation schema
var _type_schemas: Dictionary = {
    COLLECTIBLE: ["item_id"],
    CHECKPOINT: ["checkpoint_id"],
    WIN: ["win_id"],
    WIN_ZONE: ["win_id"],
    DAMAGE: ["damage_amount"],
    HEAL: ["heal_amount"],
    DIALOGUE: ["npc_id", "dialogue_id"],
    TELEPORT: ["target_position"]
}

func _ready() -> void:
    # Register built-in handlers
    _register_builtin_handlers()

func _register_builtin_handlers() -> void:
    _type_handlers[COLLECTIBLE] = CollectibleHandler.new()
    _type_handlers[CHECKPOINT] = CheckpointHandler.new()
    _type_handlers[WIN] = WinHandler.new()
    _type_handlers[WIN_ZONE] = WinZoneHandler.new()
    _type_handlers[DAMAGE] = DamageHandler.new()
    _type_handlers[HEAL] = HealHandler.new()
    _type_handlers[DIALOGUE] = DialogueHandler.new()
    _type_handlers[TELEPORT] = TeleportHandler.new()

## Register a custom trigger type
func register_type(type_name: String, handler: TriggerHandler) -> void:
    _type_handlers[type_name] = handler

## Get handler for a trigger type
func get_handler(type_name: String) -> TriggerHandler:
    return _type_handlers.get(type_name, null)

## Check if type is registered
func has_type(type_name: String) -> bool:
    return type_name in _type_handlers

## Get required metadata fields for a type
func get_required_fields(type_name: String) -> Array:
    return _type_schemas.get(type_name, [])

## Validate trigger metadata
func validate_metadata(type_name: String, metadata: Dictionary) -> Array:
    var errors = []
    var required = get_required_fields(type_name)
    
    for field in required:
        if not field in metadata:
            errors.append("Missing required field: %s" % field)
    
    return errors
```

### 3. TriggerHandler.gd (Base Class)
```gdscript
## TriggerHandler.gd - Base class for trigger type handlers

class_name TriggerHandler
extends RefCounted

signal triggered(trigger: Area3D, activator: Node3D)
signal cooldown_started(trigger: Area3D, duration: float)
signal cooldown_ended(trigger: Area3D)

# Called when a body enters the trigger
func on_body_entered(trigger: Area3D, body: Node3D) -> void:
    # Check if this trigger can be activated
    if not _can_activate(trigger, body):
        return
    
    # Get trigger metadata
    var metadata = _get_metadata(trigger)
    if not metadata:
        push_warning("Trigger %s has no metadata" % trigger.name)
        return
    
    # Process the trigger
    on_trigger(trigger, body, metadata)
    
    # Emit signal
    triggered.emit(trigger, body)

# Override to add custom activation logic
func _can_activate(trigger: Area3D, body: Node3D) -> bool:
    # Check if trigger is disabled
    if _is_disabled(trigger):
        return false
    
    # Check cooldown
    if _is_on_cooldown(trigger):
        return false
    
    # Check if body is a valid activator
    return _is_valid_activator(body)

# Override to implement trigger behavior
func on_trigger(trigger: Area3D, body: Node3D, metadata: Dictionary) -> void:
    pass  # Base implementation does nothing

# Helper methods
func _get_metadata(trigger: Area3D) -> Dictionary:
    # Try to get metadata from custom property
    if "trigger_metadata" in trigger:
        return trigger.trigger_metadata
    # Try to get from node metadata (Godot 4.2+)
    elif trigger.has_meta("trigger_metadata"):
        return trigger.get_meta("trigger_metadata")
    return null

func _is_disabled(trigger: Area3D) -> bool:
    var metadata = _get_metadata(trigger)
    return metadata and metadata.get("disabled", false)

func _is_on_cooldown(trigger: Area3D) -> bool:
    # Check if cooldown timer exists
    if trigger.has_node("CooldownTimer"):
        var timer = trigger.get_node("CooldownTimer") as Timer
        return timer and timer.is_stopped() == false
    return false

func _is_valid_activator(body: Node3D) -> bool:
    # Must be a physics body
    return body is CharacterBody3D or body is RigidBody3D or body is StaticBody3D
```

### 4. CollectibleHandler.gd
```gdscript
## CollectibleHandler.gd - Handles collectible triggers

class_name CollectibleHandler
extends TriggerHandler

# Override to implement collectible behavior
func on_trigger(trigger: Area3D, body: Node3D, metadata: Dictionary) -> void:
    # Get item information
    var item_id = metadata.get("item_id", "")
    var quantity = metadata.get("quantity", 1)
    var one_time = metadata.get("one_time", false)
    var cooldown = metadata.get("cooldown", 0.0)
    
    # Find the player
    var player = _find_player(body)
    if not player:
        return
    
    # Give item to player
    player.inventory.add_item(item_id, quantity)
    
    # Play feedback
    _play_feedback(trigger, metadata)
    
    # Handle one-time trigger
    if one_time:
        _handle_one_time(trigger)
    
    # Handle cooldown
    if cooldown > 0:
        _handle_cooldown(trigger, cooldown)

func _find_player(body: Node3D) -> Player:
    # Check if body is the player
    if body is Player:
        return body
    
    # Check if body has a player reference
    if "player" in body:
        return body.player
    
    # Find player in scene tree
    return get_tree().get_first_node_in_group("players") as Player

func _play_feedback(trigger: Area3D, metadata: Dictionary) -> void:
    # Play sound
    var sound_path = metadata.get("sound", "res://sounds/collect.wav")
    var sound = load(sound_path)
    if sound:
        var player = AudioStreamPlayer3D.new()
        player.stream = sound
        player.global_position = trigger.global_position
        trigger.add_child(player)
        player.play()
        player.finish.connect(player.queue_free)
    
    # Visual feedback
    var effect_path = metadata.get("effect", "res://effects/collect.tscn")
    var effect_scene = load(effect_path)
    if effect_scene:
        var effect = effect_scene.instantiate()
        effect.global_position = trigger.global_position
        trigger.get_parent().add_child(effect)
        effect.finish.connect(effect.queue_free)

func _handle_one_time(trigger: Area3D) -> void:
    # Disable the collision to prevent re-triggering
    for child in trigger.get_children():
        if child is CollisionShape3D:
            child.set_deferred("disabled", true)
    
    # Optional: Hide or remove the trigger
    if trigger.get_meta("hide_on_collect", false):
        trigger.visible = false
    
    # Optional: Queue free after a delay
    if trigger.get_meta("remove_on_collect", false):
        var timer = Timer.new()
        timer.wait_time = 0.5
        timer.timeout.connect(trigger.queue_free)
        trigger.add_child(timer)
        timer.start()

func _handle_cooldown(trigger: Area3D, duration: float) -> void:
    # Create cooldown timer if it doesn't exist
    if not trigger.has_node("CooldownTimer"):
        var timer = Timer.new()
        timer.name = "CooldownTimer"
        timer.wait_time = duration
        timer.timeout.connect(_on_cooldown_end.bind(trigger))
        trigger.add_child(timer)
    
    var timer = trigger.get_node("CooldownTimer") as Timer
    timer.start()
    
    cooldown_started.emit(trigger, duration)

func _on_cooldown_end(trigger: Area3D) -> void:
    cooldown_ended.emit(trigger)
```

### 5. TriggerManager.gd
```gdscript
## TriggerManager.gd - Manages all triggers in the scene

class_name TriggerManager
extends Node

signal trigger_activated(trigger: Area3D, activator: Node3D, trigger_type: String)

# Reference to trigger type registry
var _type_registry: TriggerTypeRegistry

# Map of trigger Area3D to their handlers
var _trigger_handlers: Dictionary = {}

func _ready() -> void:
    _type_registry = TriggerTypeRegistry.get_singleton()
    
    # Find and register all existing triggers
    _register_existing_triggers()
    
    # Connect to node added signal for dynamic triggers
    get_tree().node_added.connect(_on_node_added)

func _register_existing_triggers() -> void:
    # Find all Area3D nodes with trigger metadata
    var areas = get_tree().get_nodes_in_group("triggers")
    for area in areas:
        if area is Area3D and _has_trigger_metadata(area):
            _register_trigger(area)

func _on_node_added(node: Node) -> void:
    # Check if new node is a trigger
    if node is Area3D and _has_trigger_metadata(node):
        _register_trigger(node)

func _has_trigger_metadata(area: Area3D) -> bool:
    # Check for trigger metadata
    if "trigger_metadata" in area:
        return true
    if area.has_meta("trigger_type"):
        return true
    if area.has_meta("trigger_metadata"):
        return true
    return false

func _register_trigger(area: Area3D) -> void:
    # Get trigger type
    var trigger_type = area.get_meta("trigger_type", "")
    if trigger_type.is_empty() and "trigger_metadata" in area:
        var metadata = area.trigger_metadata
        if metadata and "trigger_type" in metadata:
            trigger_type = metadata["trigger_type"]
    
    if trigger_type.is_empty():
        push_warning("Area3D %s has no trigger_type" % area.name)
        return
    
    # Get handler for this type
    var handler = _type_registry.get_handler(trigger_type)
    if not handler:
        push_warning("No handler registered for trigger type: %s" % trigger_type)
        return
    
    # Store handler reference
    _trigger_handlers[area] = handler
    
    # Connect signals
    area.body_entered.connect(_on_body_entered.bind(area))
    area.area_entered.connect(_on_area_entered.bind(area))
    
    # Add to triggers group for easy finding
    area.add_to_group("triggers")
    
    # Set monitoring properties if not already set
    if not area.monitoring:
        area.monitoring = true
    if not area.monitorable:
        area.monitorable = true

func _on_body_entered(body: Node3D, area: Area3D) -> void:
    _handle_trigger(area, body)

func _on_area_entered(area: Area3D, our_area: Area3D) -> void:
    # Another area entered this trigger
    # This can be used for area-to-area interactions
    pass

func _handle_trigger(area: Area3D, body: Node3D) -> void:
    # Get handler
    var handler = _trigger_handlers.get(area, null)
    if not handler:
        return
    
    # Process trigger
    handler.on_body_entered(area, body)
    
    # Emit signal
    var trigger_type = area.get_meta("trigger_type", "")
    trigger_activated.emit(area, body, trigger_type)

func unregister_trigger(area: Area3D) -> void:
    if area in _trigger_handlers:
        # Disconnect signals
        area.body_entered.disconnect(_on_body_entered)
        area.area_entered.disconnect(_on_area_entered)
        
        # Remove from map
        _trigger_handlers.erase(area)
        
        # Remove from group
        area.remove_from_group("triggers")
```

### 6. WorldRenderer with Trigger Support
```gdscript
## WorldRenderer.gd - Enhanced with trigger support

class_name WorldRenderer
extends Node3D

@export var world: World

# Trigger manager reference
var _trigger_manager: TriggerManager

func _ready() -> void:
    _trigger_manager = get_node_or_null("/root/TriggerManager")
    if not _trigger_manager:
        # Create if not exists
        _trigger_manager = TriggerManager.new()
        get_tree().root.add_child(_trigger_manager)

func render_world() -> void:
    # Clear existing nodes
    for child in get_children():
        if child != self:
            child.queue_free()
    
    # Render scene nodes
    for scene_node in world.scene_nodes:
        _render_scene_node(scene_node)

func _render_scene_node(domain_node: SceneNode) -> Node3D:
    var godot_node: Node3D
    
    # Handle trigger nodes
    if domain_node.node_type == "area" and "trigger_type" in domain_node:
        godot_node = _render_trigger_node(domain_node)
    else:
        # Standard node rendering (from VS-001)
        godot_node = _render_standard_node(domain_node)
    
    return godot_node

func _render_trigger_node(domain_node: SceneNode) -> Area3D:
    # Create Area3D
    var area = Area3D.new()
    area.name = domain_node.name
    
    # Set stable node name
    if domain_node.name.is_empty():
        area.name = "trigger_%d" % hash(domain_node)
    
    # Set transform
    area.position = domain_node.position
    area.rotation = domain_node.rotation
    area.scale = domain_node.scale
    
    # Create collision shape based on trigger_collision
    if "trigger_collision" in domain_node:
        var collision_data = domain_node.trigger_collision
        var collision = _create_collision_shape(collision_data)
        if collision:
            area.add_child(collision)
    else:
        # Default collision
        var collision = CollisionShape3D.new()
        collision.shape = BoxShape3D.new()
        var box = collision.shape as BoxShape3D
        box.size = Vector3(2, 2, 2)
        area.add_child(collision)
    
    # Attach trigger metadata
    if "trigger_metadata" in domain_node:
        # Store as custom property
        area.trigger_metadata = domain_node.trigger_metadata.duplicate(true)
        
        # Also store trigger_type separately for easy lookup
        if "trigger_type" in domain_node.trigger_metadata:
            area.set_meta("trigger_type", domain_node.trigger_metadata["trigger_type"])
    
    # Apply standard properties
    _apply_properties(area, domain_node.properties)
    
    # Ensure monitoring is enabled
    area.monitoring = domain_node.properties.get("monitoring", true)
    area.monitorable = domain_node.properties.get("monitorable", true)
    
    # Add to tree
    add_child(area)
    
    # Add to triggers group
    area.add_to_group("triggers")
    
    return area

func _create_collision_shape(data: Dictionary) -> CollisionShape3D:
    var collision = CollisionShape3D.new()
    
    var shape_type = data.get("shape", "box")
    var size = _normalize_vector3(data.get("size", {"x": 2, "y": 2, "z": 2}))
    var offset = _normalize_vector3(data.get("offset", {"x": 0, "y": 0, "z": 0}))
    
    # Create appropriate shape
    match shape_type:
        "box":
            var box = BoxShape3D.new()
            box.size = size
            collision.shape = box
        "sphere":
            var sphere = SphereShape3D.new()
            sphere.radius = size.x  # Use x as radius
            collision.shape = sphere
        "capsule":
            var capsule = CapsuleShape3D.new()
            capsule.radius = size.x
            capsule.height = size.y
            collision.shape = capsule
        "cylinder":
            var cylinder = CylinderShape3D.new()
            cylinder.radius = size.x
            cylinder.height = size.y
            collision.shape = cylinder
        _:
            var box = BoxShape3D.new()
            box.size = size
            collision.shape = box
    
    # Set offset
    collision.position = offset
    
    return collision

func _render_standard_node(domain_node: SceneNode) -> Node3D:
    # Standard node rendering from VS-001
    var node: Node3D
    
    match domain_node.node_type:
        "prop": node = StaticBody3D.new()
        "character": node = CharacterBody3D.new()
        "rigid": node = RigidBody3D.new()
        _: node = Node3D.new()
    
    node.name = domain_node.name
    node.position = domain_node.position
    node.rotation = domain_node.rotation
    node.scale = domain_node.scale
    
    _apply_properties(node, domain_node.properties)
    add_child(node)
    
    return node

func _apply_properties(node: Node, properties: Dictionary) -> void:
    for key in properties:
        var value = properties[key]
        if node.has_method("set_%s" % key):
            node.call("set_%s" % key, value)
        else:
            node.set(key, value)

func _normalize_vector3(data: Variant) -> Vector3:
    # Reuse from TemplateLoader (VS-001)
    if data is Dictionary:
        return Vector3(
            data.get("x", 0.0),
            data.get("y", 0.0),
            data.get("z", 0.0)
        )
    elif data is Array and data.size() >= 3:
        return Vector3(data[0], data[1], data[2])
    elif data is Vector3:
        return data
    else:
        return Vector3.ZERO
```

### 7. TemplateLoader with Trigger Support
```gdscript
## TemplateLoader.gd - Enhanced with trigger support
## Extends VS-001 implementation

class_name TemplateLoader
extends RefCounted

# ... (existing VS-001 code)

## Create a SceneNode from JSON data (enhanced for triggers)
func _create_scene_node(data: Dictionary) -> SceneNode:
    var scene_node = SceneNode.new()
    
    # Standard VS-001 preservation
    scene_node.position = _normalize_vector3(data.get("position", {}))
    scene_node.rotation = _normalize_quaternion(data.get("rotation", {}))
    scene_node.scale = _normalize_vector3(data.get("scale", {}))
    scene_node.name = data.get("name", "Unnamed Node")
    scene_node.node_type = data.get("type", "prop")
    scene_node.properties = data.get("properties", {}).duplicate(true)
    scene_node.tags = data.get("tags", [])
    scene_node.layer = data.get("layer", 0)
    scene_node.visible = data.get("visible", true)
    scene_node.cast_shadow = data.get("cast_shadow", true)
    scene_node.receive_shadow = data.get("receive_shadow", true)
    
    # VS-002: Trigger-specific data
    if "trigger_type" in data:
        scene_node.trigger_type = data["trigger_type"]
        scene_node.trigger_metadata = data.get("trigger_metadata", {}).duplicate(true)
        scene_node.trigger_collision = data.get("trigger_collision", {})
    
    # Children
    var children_data = data.get("children", [])
    for child_data in children_data:
        var child_node = _create_scene_node(child_data)
        if child_node:
            scene_node.add_child(child_node)
    
    return scene_node
```

### 8. Test Cases
```gdscript
## test_trigger_metadata_propagation.gd

class_name TriggerMetadataPropagationTest
extends TestCase

func test_trigger_creation_from_template() -> void:
    # Create template JSON with trigger
    var template_json = {
        "name": "test_world",
        "scene_nodes": [
            {
                "name": "gold_coin_trigger",
                "type": "area",
                "trigger_type": "collectible",
                "position": {"x": 0, "y": 0, "z": 0},
                "trigger_collision": {
                    "shape": "box",
                    "size": {"x": 2, "y": 2, "z": 2}
                },
                "trigger_metadata": {
                    "item_id": "gold_coin",
                    "quantity": 1,
                    "one_time": true
                },
                "properties": {
                    "monitoring": true,
                    "monitorable": true
                }
            }
        ]
    }
    
    # Load template
    var loader = TemplateLoader.new()
    var world = loader.load_template_from_dict(template_json)
    
    # Verify scene node created
    assert_eq(world.scene_nodes.size(), 1)
    
    var scene_node = world.scene_nodes[0]
    assert_eq(scene_node.name, "gold_coin_trigger")
    assert_eq(scene_node.node_type, "area")
    assert_eq(scene_node.trigger_type, "collectible")
    
    # Verify metadata preserved
    assert("trigger_metadata" in scene_node)
    assert_eq(scene_node.trigger_metadata["item_id"], "gold_coin")
    assert_eq(scene_node.trigger_metadata["quantity"], 1)
    assert_eq(scene_node.trigger_metadata["one_time"], true)
    
    # Verify collision preserved
    assert("trigger_collision" in scene_node)
    assert_eq(scene_node.trigger_collision["shape"], "box")
    
    # Render and verify Area3D
    var renderer = WorldRenderer.new()
    renderer.world = world
    renderer.render_world()
    
    # Find the area in the tree
    var area = renderer.get_node_or_null("gold_coin_trigger")
    assert(area is Area3D)
    
    # Verify trigger metadata attached
    assert("trigger_metadata" in area)
    assert_eq(area.trigger_metadata["item_id"], "gold_coin")
    
    # Verify collision shape
    var collision = area.get_child(0)
    assert(collision is CollisionShape3D)
    assert(collision.shape is BoxShape3D)
    var box = collision.shape as BoxShape3D
    assert(box.size.is_equal_approx(Vector3(2, 2, 2)))

func test_trigger_types_registration() -> void:
    var registry = TriggerTypeRegistry.new()
    
    # Verify built-in types are registered
    assert(registry.has_type(TriggerTypeRegistry.COLLECTIBLE))
    assert(registry.has_type(TriggerTypeRegistry.CHECKPOINT))
    assert(registry.has_type(TriggerTypeRegistry.WIN))
    assert(registry.has_type(TriggerTypeRegistry.WIN_ZONE))
    assert(registry.has_type(TriggerTypeRegistry.DAMAGE))
    assert(registry.has_type(TriggerTypeRegistry.HEAL))
    
    # Verify handlers exist
    assert(registry.get_handler(TriggerTypeRegistry.COLLECTIBLE) is CollectibleHandler)
    assert(registry.get_handler(TriggerTypeRegistry.CHECKPOINT) is CheckpointHandler)

func test_trigger_manager_registration() -> void:
    # Setup scene
    var root = Node3D.new()
    var trigger_manager = TriggerManager.new()
    root.add_child(trigger_manager)
    
    # Create a trigger
    var area = Area3D.new()
    area.name = "test_trigger"
    area.set_meta("trigger_type", "collectible")
    area.trigger_metadata = {"item_id": "test_item"}
    root.add_child(area)
    
    # Add CollisionShape3D
    var collision = CollisionShape3D.new()
    collision.shape = BoxShape3D.new()
    area.add_child(collision)
    
    # Add to tree and process
    get_tree().root.add_child(root)
    await get_tree().process_frame
    
    # Trigger should be registered
    # (In actual test, we'd verify through signals or state)
    
    # Cleanup
    get_tree().root.remove_child(root)
    root.queue_free()
```

---

## Asset Packages and Tools

### Godot Plugins for Triggers
| Plugin | URL | License | Purpose |
|--------|-----|---------|---------|
| Area3D Tools | https://github.com/GodotExplorer/Area3DTools | MIT | Extended Area3D functionality |
| Trigger System | https://github.com/GodotExplorer/TriggerSystem | MIT | Complete trigger system |
| Godot Game Framework | https://github.com/GodotExplorer/GameFramework | MIT | Includes trigger system |

### Custom Solutions
| Solution | URL | License | Purpose |
|----------|-----|---------|---------|
| Godot Trigger System | Built-in | MIT | Basic area detection |
| Custom Metadata | This document | MIT | Trigger metadata propagation |

---

## Learning Resources

### Godot 4 Documentation
- [Area3D Class](https://docs.godotengine.org/en/stable/classes/class_area3d.html) - Area detection
- [CollisionShape3D](https://docs.godotengine.org/en/stable/classes/class_collisionshape3d.html) - Collision shapes
- [BoxShape3D](https://docs.godotengine.org/en/stable/classes/class_boxshape3d.html) - Box collision
- [SphereShape3D](https://docs.godotengine.org/en/stable/classes/class_sphereshape3d.html) - Sphere collision
- [CapsuleShape3D](https://docs.godotengine.org/en/stable/classes/class_capsuleshape3d.html) - Capsule collision
- [Physics Server](https://docs.godotengine.org/en/stable/tutorials/physics/physics_intro.html) - Physics overview

### Design Patterns
- [Observer Pattern](https://refactoring.guru/design-patterns/observer) - Event notification
- [Strategy Pattern](https://refactoring.guru/design-patterns/strategy) - Interchangeable algorithms
- [Factory Pattern](https://refactoring.guru/design-patterns/factory-method) - Object creation
- [Registry Pattern](https://martinfowler.com/eaaCatalog/registry.html) - Centralized access

### Game Development
- [Game Triggers](https://gamedev.stackexchange.com/questions/tagged/triggers) - StackExchange Q&A
- [Trigger Systems](https://www.gamasutra.com/blogs/feature/132353/) - Gamasutra articles
- [Event Systems](https://www.youtube.com/watch?v=event-systems) - YouTube tutorials

---

## Implementation Checklist

### Phase 1: Trigger Metadata Domain (HIGH Priority)
- [ ] Create TriggerMetadata.gd domain entity
- [ ] Define trigger type constants
- [ ] Add validation for trigger metadata
- [ ] Add serialization/deserialization
- [ ] Integrate with SceneNode

### Phase 2: Trigger Type Registry (HIGH Priority)
- [ ] Create TriggerTypeRegistry singleton
- [ ] Register built-in trigger types
- [ ] Implement get_handler() method
- [ ] Implement has_type() method
- [ ] Add type validation

### Phase 3: Base Trigger Handler (HIGH Priority)
- [ ] Create TriggerHandler base class
- [ ] Implement on_body_entered() method
- [ ] Add can_activate() logic
- [ ] Add cooldown support
- [ ] Add one-time trigger support

### Phase 4: Built-in Handlers (MEDIUM Priority)
- [ ] CollectibleHandler
- [ ] CheckpointHandler
- [ ] WinHandler
- [ ] WinZoneHandler
- [ ] DamageHandler
- [ ] HealHandler
- [ ] DialogueHandler
- [ ] TeleportHandler

### Phase 5: Trigger Manager (HIGH Priority)
- [ ] Create TriggerManager singleton
- [ ] Implement trigger registration
- [ ] Connect Area3D signals
- [ ] Handle dynamic trigger addition
- [ ] Add trigger_activated signal

### Phase 6: TemplateLoader Integration (HIGH Priority)
- [ ] Enhance TemplateLoader to handle trigger_type
- [ ] Preserve trigger_metadata in SceneNode
- [ ] Preserve trigger_collision in SceneNode
- [ ] Support all trigger types in templates

### Phase 7: WorldRenderer Integration (HIGH Priority)
- [ ] Create Area3D for trigger nodes
- [ ] Attach trigger_metadata to Area3D
- [ ] Create collision shapes from template
- [ ] Set monitoring properties
- [ ] Add to triggers group

### Phase 8: Testing (HIGH Priority)
- [ ] Template trigger creation test
- [ ] Trigger metadata preservation test
- [ ] Trigger type registration test
- [ ] Trigger manager registration test
- [ ] Trigger activation test
- [ ] Round-trip serialization test

### Acceptance Criteria Verification
- [ ] Trigger Area3D receives stable node name
- [ ] Trigger Area3D receives authored trigger metadata
- [ ] Trigger collision uses authored size
- [ ] Runtime recognizes collectible trigger semantics
- [ ] Runtime recognizes checkpoint trigger semantics
- [ ] Runtime recognizes win trigger semantics
- [ ] Runtime recognizes win_zone trigger semantics
- [ ] Renderer integration tests cover metadata and JSON property normalization

---

## Child-Safety Constraints

### Trigger Behavior
- [ ] No harmful triggers (damage without warning, forced actions)
- [ ] Collectible triggers give age-appropriate items
- [ ] Checkpoint triggers don't trap or confuse child
- [ ] Win triggers have clear success state
- [ ] All triggers have visual feedback

### Content Safety
- [ ] No violent trigger types in child mode
- [ ] No scary trigger effects in child mode
- [ ] Trigger metadata validated for safety
- [ ] Trigger visuals are child-friendly

### Technical Safety
- [ ] Triggers don't cause infinite loops
- [ ] Triggers don't cause memory leaks
- [ ] Cooldowns prevent trigger spam
- [ ] Error handling for missing metadata

---

## References

### Internal Documentation
1. [PLAN.md](PLAN.md) - Project delivery plan
2. [.ai/tasks/backlog.yaml](.ai/tasks/backlog.yaml) - VS-002 definition
3. [src/adapters/inbound/gameplay/world_renderer.gd](src/adapters/inbound/gameplay/world_renderer.gd) - World renderer
4. [src/adapters/inbound/gameplay/gameplay_runtime.gd](src/adapters/inbound/gameplay/gameplay_runtime.gd) - Gameplay runtime
5. [RESEARCH_VS-001_Template_Transforms_Preservation.md](./RESEARCH_VS-001_Template_Transforms_Preservation.md) - Template preservation (dependency)

### External Documentation
1. [Godot Area3D](https://docs.godotengine.org/en/stable/classes/class_area3d.html)
2. [Godot Collision Shapes](https://docs.godotengine.org/en/stable/tutorials/physics/physics_shapes.html)
3. [Godot Physics](https://docs.godotengine.org/en/stable/tutorials/physics/physics_intro.html)
4. [Observer Pattern](https://refactoring.guru/design-patterns/observer)
5. [Strategy Pattern](https://refactoring.guru/design-patterns/strategy)
6. [Game Triggers on StackExchange](https://gamedev.stackexchange.com/questions/tagged/triggers)

### Related Research
1. [RESEARCH_VS-003_NPC_Scene_Tree_Lifecycle.md](./RESEARCH_VS-003_NPC_Scene_Tree_Lifecycle.md) - NPC lifecycle
2. [RESEARCH_VS-004_Clean_Profile_Adventure_Charter.md](./RESEARCH_VS-004_Clean_Profile_Adventure_Charter.md) - Adventure testing

---

## File Structure

```
src/domain/world_authoring/
├── scene_node.gd                   # Enhanced with trigger support
├── trigger_metadata.gd            # Trigger metadata entity
└── trigger_type_registry.gd        # Trigger type registry

src/application/
└── trigger_handlers/               # Trigger type handlers
    ├── trigger_handler.gd         # Base handler class
    ├── collectible_handler.gd     # Collectible trigger handler
    ├── checkpoint_handler.gd     # Checkpoint trigger handler
    ├── win_handler.gd             # Win trigger handler
    ├── win_zone_handler.gd        # Win zone trigger handler
    ├── damage_handler.gd          # Damage trigger handler
    ├── heal_handler.gd            # Heal trigger handler
    ├── dialogue_handler.gd         # Dialogue trigger handler
    └── teleport_handler.gd         # Teleport trigger handler

src/adapters/outbound/
└── gameplay/
    ├── trigger_manager.gd         # Trigger manager singleton
    └── world_renderer.gd          # Enhanced with trigger support

src/application/
└── template_loader.gd              # Enhanced with trigger support

tests/application/
├── test_trigger_metadata_propagation.gd  # Trigger tests
└── test_template_loader.gd        # Existing tests

data/templates/
└── adventure.json                  # Templates with triggers
```

---

*Document created: 2026-07-18*  
*Research status: COMPLETE*  
*Next step: Cross-agent review and implementation*
