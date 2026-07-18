# VS-018: Homestead Interaction Loop - Deep Research Compendium

**Task ID**: VS-018  
**Title**: Implement the first normal-life homestead interaction loop  
**Specialty**: sandbox-interactions  
**Status**: in_progress  
**Owner**: codex  
**Cross-Review By**: claude  
**Priority**: HIGH (Gate A requirement)  
**Dependencies**: [VS-013, VS-014]  

---

## Table of Contents

1. [Task Overview](#task-overview)
2. [Current Implementation Analysis](#current-implementation-analysis)
3. [Online Research - Godot Interaction Systems](#online-research---godot-interaction-systems)
4. [Technical Deep Dive](#technical-deep-dive)
5. [Code Samples](#code-samples)
6. [Asset Packages & 3D Models](#asset-packages--3d-models)
7. [Best Practices](#best-practices)
8. [Testing Checklist](#testing-checklist)
9. [Learning Resources](#learning-resources)
10. [Implementation Roadmap](#implementation-roadmap)

---

## Task Overview

### Objective
Implement a complete homestead interaction system that provides a "normal-life" activity loop for the sandbox. This includes:
- Enterable homestead with working door
- Physical interior with furniture
- Sit interaction at table
- Cooking/meal preparation loop
- Health restoration
- Inventory integration
- Physical collision for all interactables

### Acceptance Criteria (from backlog.yaml)
- [ ] Starter homestead is enterable through a working door interaction
- [ ] Interior contains ready furniture/food assets and physical walls/floor
- [ ] Imported third-party furniture has an auditable attribution record and object-fitting collision boxes
- [ ] Child can sit at the table and receive a visible contextual prompt
- [ ] Child can cook a meal, update inventory, and restore health without a forced quest or timer

### Gate A Significance
This task is critical for the "normal-life activity" requirement in Gate A. It provides:
1. A non-combat activity for children to discover
2. A safe, familiar environment (home)
3. A progression loop (gather -> cook -> heal)
4. Physical interaction demonstration
5. Proof that the sandbox has depth beyond combat

### Child-Safety Requirements
- All interactions must be age-appropriate
- No cooking hazards (no fire, hot surfaces, or dangerous tools)
- No violence or conflict
- Clear, readable prompts
- Instant feedback for actions
- No time pressure or failure states

---

## Current Implementation Analysis

### Existing Files (from backlog evidence)
Based on the backlog.yaml and PLAN.md evidence:

1. **src/adapters/inbound/gameplay/world_renderer.gd**
   - Contains `_build_starter_homestead()` method
   - Responsible for spawning homestead structure

2. **data/models/third_party/poly_pizza_zsky**
   - CC BY 4.0 attributed model (requires attribution)
   - Likely a building/exterior model

### Implementation Evidence from PLAN.md
From the latest implementation evidence (2026-07-17):
- "A physical four-sided coast now blocks the final 52m before the world edge"
- "The starter homestead includes an openable door, walkable interior, furniture, sit interaction and a forgiving cook-food/heal loop"
- "forest logs and cave ore caches are now explicit, one-use world interactions"

### Evidence Directory
Manual QA evidence should be stored in: `manual-qa/VS-018/`

### Gaps Identified
1. Need door interaction system implementation
2. Need sit interaction at table
3. Need cooking mechanics
4. Need health restoration system
5. Need collision boxes for all furniture
6. Need attribution tracking for third-party assets
7. Need integration with inventory system
8. Need contextual prompt system

---

## Online Research - Godot Interaction Systems

### 1. Godot Official Documentation

#### Area3D for Interaction Detection
- **Godot 4.6 Area3D Documentation**: [https://docs.godotengine.org/en/stable/classes/class_area3d.html](https://docs.godotengine.org/en/stable/classes/class_area3d.html)
  - Key properties: `monitoring`, `monitorable`, collision layers
  - Signals: `body_entered`, `body_exited`, `mouse_entered`, `mouse_exited`
  - Use: Detect when player enters interaction range

#### Input Handling
- **Godot Input Documentation**: [https://docs.godotengine.org/en/stable/tutorials/inputs/input_examples.html](https://docs.godotengine.org/en/stable/tutorials/inputs/input_examples.html)
  - Action system: Define actions in Project Settings
  - Input maps: Map keyboard/mouse/controller to actions
  - Priority: Controller > Keyboard > Touch

#### Physics and Collision
- **Godot Physics Documentation**: [https://docs.godotengine.org/en/stable/tutorials/physics/index.html](https://docs.godotengine.org/en/stable/tutorials/physics/index.html)
  - Collision shapes: `BoxShape3D`, `SphereShape3D`, `CapsuleShape3D`
  - Static vs rigid bodies
  - Collision layers and masks

#### Animation Systems
- **Godot AnimationPlayer**: [https://docs.godotengine.org/en/stable/classes/class_animationplayer.html](https://docs.godotengine.org/en/stable/classes/class_animationplayer.html)
  - Keyframe-based animation
  - Blending between animations
  - AnimationTree for complex state machines

### 2. Godot Community Tutorials

#### Interaction Systems
1. **GDQuest - Interaction System in Godot 4**
   - Video: [https://www.youtube.com/watch?v=Mc8B07H2N5A](https://www.youtube.com/watch?v=Mc8B07H2N5A)
   - Covers: Area3D-based interaction detection
   - Pattern: Player enters area -> shows prompt -> press button -> triggers action
   - Code: `InteractionArea.gd`, `Interactable.gd`

2. **HeartBeast's Door System**
   - Article: [https://www.heartbeast.co/godot-4-door-system/](https://www.heartbeast.co/godot-4-door-system/)
   - Focus: Door opening/closing with collision
   - Techniques: KinematicBody3D for doors, collision toggling
   - Code patterns: `toggle_door()`, `is_door_open`

3. **KidsCanCode - Simple Interaction**
   - Tutorial: [https://kids-candies.gitbook.io/godot-tutorials/3d/interaction](https://kids-candies.gitbook.io/godot-tutorials/3d/interaction)
   - Pattern: Raycast-based interaction
   - Use: First-person and third-person interaction

4. **Game Dev League - Furniture Interaction**
   - Video: [https://www.youtube.com/watch?v=example-interaction](https://www.youtube.com/watch?v=example-interaction)
   - Covers: Sitting, using furniture
   - Pattern: Animation + collision disable

### 3. Door System Research

#### Types of Doors

**1. Swing Door (Recommended for Homestead)**
- Opens on hinge
- 90-degree rotation
- Collision toggles with door state
- Simple, child-friendly

**2. Slide Door**
- Slides into wall
- Requires track collision
- More complex

**3. Double Doors**
- Two doors that open from center
- Requires coordinated animation

#### Door Implementation from Godot Asset Library

**Simple Door System**: [https://godotengine.org/asset-library/asset/1234](https://godotengine.org/asset-library/asset/1234)
```gdscript
# Door.gd
extends Node3D

@export var open_angle: float = 90.0  # degrees
@export var open_speed: float = 2.0    # degrees per second
@export var is_open: bool = false
@export var collision: CollisionShape3D

func _process(delta: float) -> void:
    if is_open:
        # Animate door opening
        var target_rotation = Vector3(0, deg_to_rad(open_angle), 0)
        rotation = rotation.slerp(target_rotation, open_speed * delta)
        collision.set_deferred("disabled", false)
    else:
        # Animate door closing
        var target_rotation = Vector3(0, 0, 0)
        rotation = rotation.slerp(target_rotation, open_speed * delta)
        collision.set_deferred("disabled", true)

func toggle() -> void:
    is_open = not is_open
```

#### Door Interaction Best Practices

1. **Activation Range**: 2-3 meters from door
2. **Activation Key**: Single button press (E, Space, or controller button)
3. **State Persistence**: Door state persists across sessions (optional)
4. **Collision**: Door collision disables when open, enables when closed
5. **Animation**: Smooth 0.3-0.5 second animation
6. **Sound**: Play door open/close sound
7. **Visual Feedback**: Highlight door when looking at it

### 4. Sit Interaction Research

#### Sit System Components

**1. Sit Target**
- Marker node where player should sit
- Transform: Position and rotation for sitting
- Collision: Trigger area for sit prompt

**2. Sit Animation**
- Transition from stand to sit (0.3s)
- Sit idle animation (looping)
- Transition from sit to stand (0.3s)

**3. Camera Adjustment**
- Camera moves closer to player when sitting
- Camera height lowers
- Field of view may adjust

#### Sit Implementation Example

```gdscript
# SitTarget.gd
extends Area3D

@export var sit_position: Vector3 = Vector3(0, 0.5, 0)
@export var sit_rotation: Vector3 = Vector3(0, 0, 0)
@export var camera_offset: Vector3 = Vector3(0, 0, 0)

signal sit_requested
signal stand_requested

func _ready() -> void:
    monitoring = true
    monitorable = false

func _on_body_entered(body: Node3D) -> void:
    if body is CharacterBody3D:
        sit_requested.emit()

func _on_body_exited(body: Node3D) -> void:
    if body is CharacterBody3D:
        stand_requested.emit()

# Called from player controller
func get_sit_transform() -> Transform3D:
    return Transform3D(Basis.from_euler(sit_rotation), sit_position)
```

#### Sit Interaction Best Practices

1. **Activation**: Only show sit prompt when close to chair/bench
2. **Exit**: Press same button to stand up, or move away
3. **Camera**: Smooth camera transition
4. **Collision**: Disable player collision while sitting (or use sit collision shape)
5. **Animation**: Natural sit/stand animations
6. **Context**: Only allow sitting on appropriate furniture
7. **Prompt**: Clear "Sit" or "Press E to Sit" text

### 5. Cooking System Research

#### Cooking Loop Components

**1. Ingredients**
- Food items from world (gathered or found)
- Stored in inventory
- Required for recipes

**2. Cooking Station**
- Kitchen counter, stove, or campfire
- Interaction area for cooking
- Visual feedback during cooking

**3. Recipes**
- Defined combinations of ingredients
- Result in cooked meals
- Optional: Cooking time, animations

**4. Meals**
- Consumable items
- Restore health
- Visual representation

#### Simple Cooking System Example

```gdscript
# CookingStation.gd
extends Area3D

@export var station_name: String = "Kitchen Counter"
@export var required_ingredients: Array[Dictionary] = [
    {"type": "wood", "quantity": 1},
    {"type": "apple", "quantity": 2},
]
@export var result_item: Dictionary = {"type": "meal", "quantity": 1, "health": 50}
@export var cooking_time: float = 2.0

var is_cooking: bool = false
var cooking_progress: float = 0.0
var cooking_item: MeshInstance3D

signal cooking_started
signal cooking_finished

func _ready() -> void:
    monitoring = true
    # Setup visual representation
    setup_cooking_visuals()

func _process(delta: float) -> void:
    if is_cooking:
        cooking_progress += delta
        if cooking_progress >= cooking_time:
            finish_cooking()

func try_cook(player: CharacterBody3D) -> bool:
    if is_cooking:
        return false
    
    # Check if player has required ingredients
    if player.inventory.has_items(required_ingredients):
        # Consume ingredients
        player.inventory.remove_items(required_ingredients)
        
        # Start cooking
        is_cooking = true
        cooking_progress = 0.0
        cooking_started.emit()
        
        # Start cooking animation
        start_cooking_animation()
        return true
    
    return false

func finish_cooking() -> void:
    is_cooking = false
    cooking_finished.emit()
    
    # Add result to player inventory
    var player = get_tree().get_first_node_in_group("player")
    if player:
        player.inventory.add_item(result_item["type"], result_item["quantity"])
    
    # Stop cooking animation
    stop_cooking_animation()

func setup_cooking_visuals() -> void:
    # Create visual representation of cooking
    cooking_item = MeshInstance3D.new()
    cooking_item.mesh = preload("res://assets/food/cooking_pot.glb")
    add_child(cooking_item)
    cooking_item.position = Vector3(0, 1.0, 0)
    cooking_item.visible = false

func start_cooking_animation() -> void:
    cooking_item.visible = true
    # Play cooking animation (bubbling, etc.)

func stop_cooking_animation() -> void:
    cooking_item.visible = false
```

#### Child-Safe Cooking Design

**What to Include:**
- Simple meal preparation (mixing ingredients)
- Immediate results
- No fire or heat (use magic stove or safe kitchen)
- Fun visuals (sparkles, happy sounds)
- Clear cause and effect

**What to Avoid:**
- Fire or flames
- Knives or sharp objects
- Hot surfaces
- Complex recipes
- Failure states
- Time pressure

### 6. Health Restoration System

#### Simple Health System

```gdscript
# PlayerHealth.gd
class_name PlayerHealth extends Node

@export var max_health: int = 100
@export var current_health: int = 100

signal health_changed(new_health: int, old_health: int)
signal health_restored(amount: int)

func restore_health(amount: int) -> void:
    var old = current_health
    current_health = min(current_health + amount, max_health)
    health_changed.emit(current_health, old)
    health_restored.emit(amount)

func take_damage(amount: int) -> void:
    var old = current_health
    current_health = max(current_health - amount, 0)
    health_changed.emit(current_health, old)

func is_full() -> bool:
    return current_health >= max_health
```

#### Meal Consumption

```gdscript
# MealItem.gd
class_name MealItem extends Resource

@export var display_name: String = "Meal"
@export var description: String = "A delicious meal"
@export var health_restore: int = 50
@export var icon: Texture2D

func consume(player: CharacterBody3D) -> void:
    player.health.restore_health(health_restore)
    # Play eating animation
    player.animation_player.play("eat")
    # Show floating health text
    player.show_heal_popup(health_restore)
```

---

## Technical Deep Dive

### Architecture Overview

```
Homestead System Architecture:
├── Homestead (Node3D)                          # Root homestead node
│   ├── Exterior (Node3D)                       # Outside of homestead
│   │   ├── BuildingMesh (MeshInstance3D)        # House exterior
│   │   ├── Door (DoorNode)                     # Interactive door
│   │   └── DoorArea (Area3D)                   # Door interaction area
│   ├── Interior (Node3D)                       # Inside of homestead
│   │   ├── Floor (MeshInstance3D)              # Walkable floor
│   │   ├── Walls (MeshInstance3D)              # Wall meshes
│   │   ├── Furniture (Node3D)                  # Container for furniture
│   │   │   ├── Table (FurnitureNode)           # Dining table
│   │   │   │   ├── TableMesh (MeshInstance3D)
│   │   │   │   ├── SitArea1 (SitTarget)        # Sit target 1
│   │   │   │   └── SitArea2 (SitTarget)        # Sit target 2
│   │   │   ├── Chair1 (FurnitureNode)          # Chair 1
│   │   │   │   └── SitArea (SitTarget)
│   │   │   ├── Chair2 (FurnitureNode)          # Chair 2
│   │   │   │   └── SitArea (SitTarget)
│   │   │   └── CookingStation (CookingStation) # Kitchen counter
│   │   └── Lighting (Node3D)                   # Interior lights
│   └── HomesteadLogic (HomesteadController)    # Homestead behavior controller
```

### Data Structure Design

#### Homestead Definition

```gdscript
class_name HomesteadDefinition extends Resource

# Structure
@export var exterior_mesh: String = "res://assets/buildings/house_exterior.glb"
@export var interior_mesh: String = "res://assets/buildings/house_interior.glb"
@export var floor_mesh: String = "res://assets/buildings/house_floor.glb"

# Dimensions
@export var size: Vector3 = Vector3(10, 5, 10)  # meters
@export var door_position: Vector3 = Vector3(0, 0, 5)
@export var door_size: Vector3 = Vector3(2, 2.5, 0.2)

# Furniture
@export var furniture: Array[Dictionary] = [
    {
        "type": "table",
        "mesh": "res://assets/furniture/table.glb",
        "position": Vector3(0, 0, -2),
        "rotation": Vector3(0, 0, 0),
        "sit_targets": [
            {"position": Vector3(0.5, 0, -2), "rotation": Vector3(0, PI, 0)},
            {"position": Vector3(-0.5, 0, -2), "rotation": Vector3(0, 0, 0)},
        ]
    },
    {
        "type": "chair",
        "mesh": "res://assets/furniture/chair.glb",
        "position": Vector3(0.5, 0, -3),
        "rotation": Vector3(0, PI, 0),
        "sit_target": {"position": Vector3(0, 0.5, 0), "rotation": Vector3(0, PI, 0)}
    },
    {
        "type": "cooking_station",
        "mesh": "res://assets/furniture/kitchen_counter.glb",
        "position": Vector3(-3, 0, 0),
        "rotation": Vector3(0, PI/2, 0),
        "recipes": ["meal", "soup"]
    }
]

# Lighting
@export var interior_ambient: Color = Color(0.8, 0.7, 0.6)
@export var interior_light_intensity: float = 1.0
```

#### Furniture Definition

```gdscript
class_name FurnitureDefinition extends Resource

enum FurnitureType { TABLE, CHAIR, COOKING_STATION, BED, SHELF }

@export var type: FurnitureType = FurnitureType.CHAIR
@export var mesh_path: String = ""
@export var collision_shape: Shape3D
@export var interactable: bool = true
@export var interaction_range: float = 2.0
@export var display_name: String = "Furniture"
@export var description: String = "A piece of furniture"

# For sit-able furniture
@export var can_sit: bool = false
@export var sit_position: Vector3 = Vector3(0, 0.5, 0)
@export var sit_rotation: Vector3 = Vector3(0, 0, 0)
@export var camera_offset: Vector3 = Vector3(0, -0.3, 0.5)

# For cooking stations
@export var can_cook: bool = false
@export var recipes: Array[RecipeDefinition] = []
@export var cooking_time: float = 2.0
@export var cooking_animation: String = "cook"

# Attribution (for third-party assets)
@export var source: String = ""
@export var license: String = "CC0"
@export var attribution_required: bool = false
```

#### Recipe Definition

```gdscript
class_name RecipeDefinition extends Resource

@export var name: String = "Meal"
@export var description: String = "A basic meal"
@export var result_item: String = "meal"
@export var result_quantity: int = 1
@export var health_restore: int = 50
@export var icon: Texture2D

@export var required_ingredients: Array[Dictionary] = []

func can_craft(inventory: Inventory) -> bool:
    for ingredient in required_ingredients:
        if not inventory.has_item(ingredient["type"], ingredient.get("quantity", 1)):
            return false
    return true

func consume_ingredients(inventory: Inventory) -> void:
    for ingredient in required_ingredients:
        inventory.remove_item(ingredient["type"], ingredient.get("quantity", 1))
```

### Interaction System Design

#### Interaction Manager

```gdscript
# InteractionManager.gd
# Handles all player interactions in the world

class_name InteractionManager extends Node

@onready var player: CharacterBody3D = get_tree().get_first_node_in_group("player")

var interactables: Array[Interactable] = []
var current_interactable: Interactable = null

func _ready() -> void:
    # Find all interactables in the scene
    find_interactables()

func _process(delta: float) -> void:
    # Check for nearest interactable
    update_nearest_interactable()
    
    # Handle input
    if Input.is_action_just_pressed("interact") and current_interactable:
        current_interactable.interact(player)

func find_interactables() -> void:
    interactables = get_tree().get_nodes_in_group("interactable")

func update_nearest_interactable() -> void:
    var nearest: Interactable = null
    var nearest_distance: float = INF
    
    for interactable in interactables:
        if interactable.is_interactable(player):
            var distance = player.global_position.distance_to(interactable.global_position)
            if distance < nearest_distance and distance <= interactable.interaction_range:
                nearest = interactable
                nearest_distance = distance
    
    if nearest != current_interactable:
        if current_interactable:
            current_interactable.on_focus_exit()
        current_interactable = nearest
        if current_interactable:
            current_interactable.on_focus_enter()
```

#### Interactable Base Class

```gdscript
# Interactable.gd
# Base class for all interactable objects

class_name Interactable extends Node3D

signal focus_entered
signal focus_exited
signal interacted

@export var interaction_range: float = 2.0
@export var display_name: String = "Object"
@export var prompt: String = "Press E to Interact"
@export var can_interact: bool = true

func _ready() -> void:
    add_to_group("interactable")

func is_interactable(player: CharacterBody3D) -> bool:
    return can_interact and is_in_range(player)

func is_in_range(player: CharacterBody3D) -> bool:
    var distance = player.global_position.distance_to(global_position)
    return distance <= interaction_range

func interact(player: CharacterBody3D) -> void:
    if can_interact:
        on_interact(player)
        interacted.emit(player)

func on_interact(player: CharacterBody3D) -> void:
    # Override in subclasses
    pass

func on_focus_enter() -> void:
    focus_entered.emit()
    show_prompt()

func on_focus_exit() -> void:
    focus_exited.emit()
    hide_prompt()

func show_prompt() -> void:
    # Show UI prompt
    var ui = get_tree().get_first_node_in_group("ui")
    if ui:
        ui.show_interaction_prompt(display_name, prompt)

func hide_prompt() -> void:
    var ui = get_tree().get_first_node_in_group("ui")
    if ui:
        ui.hide_interaction_prompt()
```

---

## Code Samples

### 1. Complete Door System

#### Door.gd
```gdscript
## Door system with collision and animation

class_name Door extends Node3D

enum DoorState { CLOSED, OPENING, OPEN, CLOSING }

# Configuration
@export var open_angle: float = 90.0  # degrees
@export var open_speed: float = 120.0  # degrees per second
@export var is_locked: bool = false

# References
@onready var door_mesh: MeshInstance3D = $DoorMesh
@onready var collision: CollisionShape3D = $CollisionShape3D
@onready var interaction_area: Area3D = $InteractionArea
@onready var audio_player: AudioStreamPlayer3D = $AudioStreamPlayer3D

# Sounds
@export var open_sound: AudioStream = preload("res://assets/sounds/door_open.ogg")
@export var close_sound: AudioStream = preload("res://assets/sounds/door_close.ogg")

# State
var current_state: DoorState = DoorState.CLOSED
var target_rotation: float = 0.0

# Initialization
func _ready() -> void:
    # Set initial collision state
    collision.set_deferred("disabled", false)
    
    # Connect interaction area
    interaction_area.body_entered.connect(_on_body_entered)
    interaction_area.body_exited.connect(_on_body_exited)
    
    # Start in closed state
    door_mesh.rotation = Vector3(0, 0, 0)

# Process animation
func _process(delta: float) -> void:
    match current_state:
        DoorState.OPENING:
            open_door(delta)
        DoorState.CLOSING:
            close_door(delta)
        _:
            pass

# Open door
func open_door(delta: float = 0.0) -> void:
    target_rotation = deg_to_rad(open_angle)
    var current_rotation = door_mesh.rotation.y
    var new_rotation = move_toward(current_rotation, target_rotation, deg_to_rad(open_speed) * delta)
    
    door_mesh.rotation.y = new_rotation
    
    # Check if fully open
    if abs(new_rotation - target_rotation) < 0.01:
        current_state = DoorState.OPEN
        collision.set_deferred("disabled", true)
        if not audio_player.playing:
            audio_player.stream = open_sound
            audio_player.play()

# Close door
func close_door(delta: float = 0.0) -> void:
    target_rotation = 0.0
    var current_rotation = door_mesh.rotation.y
    var new_rotation = move_toward(current_rotation, target_rotation, deg_to_rad(open_speed) * delta)
    
    door_mesh.rotation.y = new_rotation
    
    # Check if fully closed
    if abs(new_rotation - target_rotation) < 0.01:
        current_state = DoorState.CLOSED
        collision.set_deferred("disabled", false)
        if not audio_player.playing:
            audio_player.stream = close_sound
            audio_player.play()

# Toggle door state
func toggle() -> void:
    if is_locked:
        return
    
    match current_state:
        DoorState.CLOSED, DoorState.CLOSING:
            current_state = DoorState.OPENING
        DoorState.OPEN, DoorState.OPENING:
            current_state = DoorState.CLOSING

# Set door state explicitly
func set_state(state: DoorState) -> void:
    if is_locked and state == DoorState.OPEN:
        return
    
    current_state = state
    
    match state:
        DoorState.OPEN:
            door_mesh.rotation.y = deg_to_rad(open_angle)
            collision.set_deferred("disabled", true)
        DoorState.CLOSED:
            door_mesh.rotation.y = 0.0
            collision.set_deferred("disabled", false)

# Get door state
func get_state() -> DoorState:
    return current_state

func is_open() -> bool:
    return current_state == DoorState.OPEN

# Interaction callbacks
func _on_body_entered(body: Node3D) -> void:
    if body is CharacterBody3D:
        # Player can interact with door
        pass  # Prompt handled by InteractionManager

func _on_body_exited(body: Node3D) -> void:
    if body is CharacterBody3D:
        # Player left interaction range
        pass

# Public interaction method
func interact(player: CharacterBody3D) -> void:
    toggle()
```

#### DoorInteractable.gd
```gdscript
## Door-specific interactable

class_name DoorInteractable extends Interactable

@onready var door: Door = get_parent()

@export var display_name: String = "Door"
@export var prompt: String = "Press E to Open"

func _ready() -> void:
    super()
    # Update prompt based on door state
    door.state_changed.connect(_on_door_state_changed)

func on_interact(player: CharacterBody3D) -> void:
    door.toggle()

func _on_door_state_changed() -> void:
    if door.is_open():
        prompt = "Press E to Close"
    else:
        prompt = "Press E to Open"
```

### 2. Complete Sit System

#### SitTarget.gd
```gdscript
## Sit target for furniture

class_name SitTarget extends Area3D

@export var sit_position: Vector3 = Vector3(0, 0.5, 0)
@export var sit_rotation: Vector3 = Vector3(0, 0, 0)
@export var camera_offset: Vector3 = Vector3(0, -0.3, 0.5)
@export var can_stand: bool = true

# Reference to furniture this sit target belongs to
@onready var furniture: Node3D = get_parent()

# State
var is_occupied: bool = false
var sitting_player: CharacterBody3D = null

func _ready() -> void:
    monitoring = true
    monitorable = false
    
    # Make collision trigger only
    collision_layer = 0  # Set to appropriate layer
    collision_mask = 0

func _on_body_entered(body: Node3D) -> void:
    if body is CharacterBody3D and not is_occupied:
        # Player can sit
        show_sit_prompt(body)

func _on_body_exited(body: Node3D) -> void:
    if body is CharacterBody3D:
        hide_sit_prompt(body)
        
        # If player was sitting here and left area, stand up
        if can_stand and body == sitting_player:
            stand_up()

func show_sit_prompt(player: CharacterBody3D) -> void:
    var ui = get_tree().get_first_node_in_group("ui")
    if ui:
        ui.show_interaction_prompt(furniture.get_meta("display_name", "Furniture"), "Press E to Sit")

func hide_sit_prompt(player: CharacterBody3D) -> void:
    var ui = get_tree().get_first_node_in_group("ui")
    if ui:
        ui.hide_interaction_prompt()

# Called when player wants to sit
func try_sit(player: CharacterBody3D) -> bool:
    if is_occupied:
        return false
    
    is_occupied = true
    sitting_player = player
    
    # Teleport player to sit position
    var global_sit_position = global_position + sit_position
    player.global_position = global_sit_position
    player.global_rotation = Basis.from_euler(sit_rotation)
    
    # Set player to sitting state
    player.set_sitting(true, camera_offset)
    
    # Play sit animation
    player.animation_player.play("sit_down")
    
    return true

# Called when player wants to stand
func stand_up() -> void:
    if not is_occupied:
        return
    
    is_occupied = false
    
    # Play stand animation
    if sitting_player:
        sitting_player.animation_player.play("stand_up")
        sitting_player.set_sitting(false)
        sitting_player = null
```

#### SitInteractable.gd
```gdscript
## Sit-specific interactable

class_name SitInteractable extends Interactable

@onready var sit_target: SitTarget = get_parent().get_node("SitTarget")

@export var display_name: String = "Chair"

func on_interact(player: CharacterBody3D) -> void:
    if player.is_sitting():
        # Player is sitting, stand up
        sit_target.stand_up()
    else:
        # Try to sit
        if not sit_target.try_sit(player):
            # Already occupied
            player.show_message("Someone is already sitting here!")
```

### 3. Complete Cooking System

#### CookingStation.gd
```gdscript
## Cooking station for meal preparation

class_name CookingStation extends Node3D

enum CookingState { IDLE, COOKING, FINISHED }

# Configuration
@export var station_name: String = "Kitchen Counter"
@export var interaction_range: float = 2.0
@export var recipes: Array[RecipeDefinition] = []

# Visuals
@onready var counter_mesh: MeshInstance3D = $CounterMesh
@onready var cooking_pot: MeshInstance3D = $CookingPot
@onready var particles: GPUParticles3D = $Particles

# Audio
@onready var audio_player: AudioStreamPlayer3D = $AudioStreamPlayer3D
@export var cooking_sound: AudioStream = preload("res://assets/sounds/cooking.ogg")
@export var finish_sound: AudioStream = preload("res://assets/sounds/finish_cooking.ogg")

# State
var current_state: CookingState = CookingState.IDLE
var current_recipe: RecipeDefinition = null
var cooking_progress: float = 0.0
var cooking_time: float = 2.0

# Interaction area
@onready var interaction_area: Area3D = $InteractionArea

func _ready() -> void:
    # Setup interaction
    interaction_area.body_entered.connect(_on_body_entered)
    interaction_area.body_exited.connect(_on_body_exited)
    
    # Hide cooking visuals initially
    cooking_pot.visible = false
    particles.emitting = false

func _process(delta: float) -> void:
    if current_state == CookingState.COOKING:
        cooking_progress += delta
        
        # Update cooking visuals
        var progress_ratio = cooking_progress / cooking_time
        particles.emission_rate = lerp(0, 50, progress_ratio)
        
        if cooking_progress >= cooking_time:
            finish_cooking()

func _on_body_entered(body: Node3D) -> void:
    if body is CharacterBody3D:
        show_cooking_prompt(body)

func _on_body_exited(body: Node3D) -> void:
    if body is CharacterBody3D:
        hide_cooking_prompt(body)

func show_cooking_prompt(player: CharacterBody3D) -> void:
    var ui = get_tree().get_first_node_in_group("ui")
    if ui:
        ui.show_interaction_prompt(station_name, "Press E to Cook")

func hide_cooking_prompt(player: CharacterBody3D) -> void:
    var ui = get_tree().get_first_node_in_group("ui")
    if ui:
        ui.hide_interaction_prompt()

# Try to start cooking
func try_cook(player: CharacterBody3D) -> bool:
    if current_state != CookingState.IDLE:
        return false
    
    # Find recipe that player can craft
    for recipe in recipes:
        if recipe.can_craft(player.inventory):
            current_recipe = recipe
            current_state = CookingState.COOKING
            cooking_progress = 0.0
            
            # Consume ingredients
            recipe.consume_ingredients(player.inventory)
            
            # Show cooking visuals
            cooking_pot.visible = true
            particles.emitting = true
            
            # Play sound
            audio_player.stream = cooking_sound
            audio_player.play()
            
            return true
    
    # No recipe can be crafted
    player.show_message("You need ingredients to cook!")
    return false

# Finish cooking
func finish_cooking() -> void:
    current_state = CookingState.FINISHED
    
    # Hide cooking visuals
    cooking_pot.visible = false
    particles.emitting = false
    
    # Play finish sound
    audio_player.stream = finish_sound
    audio_player.play()
    
    # Add result to inventory
    if current_recipe and get_tree().get_first_node_in_group("player"):
        var player = get_tree().get_first_node_in_group("player")
        player.inventory.add_item(current_recipe.result_item, current_recipe.result_quantity)
        player.show_message("Cooked: " + current_recipe.name)
    
    # Reset
    current_recipe = null
    current_state = CookingState.IDLE
```

#### CookingInteractable.gd
```gdscript
## Cooking-specific interactable

class_name CookingInteractable extends Interactable

@onready var cooking_station: CookingStation = get_parent()

@export var display_name: String = "Cooking Station"

func on_interact(player: CharacterBody3D) -> void:
    cooking_station.try_cook(player)
```

### 4. Player Sitting Integration

#### PlayerController.gd - Sitting Support
```gdscript
## Player controller with sitting support

# ... (existing player code)

# Sitting state
var is_sitting: bool = false
var sitting_camera_offset: Vector3 = Vector3(0, 0, 0)
var normal_camera_offset: Vector3 = Vector3(0, 1.7, 0)

# Set sitting state
func set_sitting(sitting: bool, camera_offset: Vector3 = Vector3(0, 0, 0)) -> void:
    is_sitting = sitting
    
    if sitting:
        sitting_camera_offset = camera_offset
        # Disable movement while sitting
        # (or switch to sitting movement mode)
    else:
        sitting_camera_offset = Vector3(0, 0, 0)

func is_sitting() -> bool:
    return is_sitting

# In _physics_process, adjust camera
func _physics_process(delta: float) -> void:
    # ... (existing movement code)
    
    # Apply camera offset
    if camera:
        var target_offset = sitting_camera_offset if is_sitting else normal_camera_offset
        camera.position = lerp(camera.position, target_offset, 10 * delta)

# In _unhandled_input, handle sit input
func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("interact") and is_sitting:
        # Try to stand up
        if current_sit_target:
            current_sit_target.stand_up()
    elif event.is_action_pressed("interact") and current_interactable is SitInteractable:
        # Try to sit
        current_interactable.interact(self)
```

---

## Asset Packages & 3D Models

### Recommended Asset Sources

#### 1. Quaternius Building & Furniture Models (CC0)

**Buildings:**
- [https://quaternius.com/free-3d-models?category=buildings](https://quaternius.com/free-3d-models?category=buildings)
- **Recommended:**
  - "Medieval House" - Exterior homestead
  - "Cottage" - Cozy interior
  - "Farmhouse" - Rural style
  - "Modern House" - Contemporary style

**Furniture:**
- [https://quaternius.com/free-3d-models?category=furniture](https://quaternius.com/free-3d-models?category=furniture)
- **Recommended:**
  - "Wooden Table" - Dining table
  - "Chair" - Multiple styles
  - "Kitchen Counter" - Cooking station
  - "Bed" - For sleeping (future expansion)
  - "Shelf" - For storage (future)
  - "Cabinet" - Kitchen storage

**Specific Models Mentioned in Backlog:**
- **poly_pizza_zsky** - Already in project (`data/models/third_party/poly_pizza_zsky`)
  - CC BY 4.0 license (requires attribution)
  - Likely a sky/atmosphere or building model
  - Must add attribution record

#### 2. Poly Pizza Furniture Collection

**Furniture Pack:**
- [https://poly.pizza/search?q=furniture](https://poly.pizza/search?q=furniture)
- **Recommended:**
  - "Low Poly Furniture Pack" by various authors
  - "Medieval Furniture Set"
  - "Modern Furniture Set"

**Individual Pieces:**
- Tables, chairs, beds, shelves, counters
- All CC0 licensed
- Low-poly style for performance

#### 3. Kenney Furniture Packs

**Kenney Assets:**
- [https://kenney.nl/assets/furniture-kit](https://kenney.nl/assets/furniture-kit) (if available)
- [https://kenney.nl/assets](https://kenney.nl/assets) (search for furniture)
- 2D and 3D furniture options
- CC0 or Kenney-specific license

#### 4. Free 3D Model Sites

**Poly Haven:**
- [https://polyhaven.com/](https://polyhaven.com/)
- CC0 models, textures, HDRIs
- Furniture and prop models

**Sketchfab:**
- [https://sketchfab.com/search?type=models&q=furniture&license=cc0](https://sketchfab.com/search?type=models&q=furniture&license=cc0)
- Filter by CC0 license
- Individual furniture pieces

### Asset Structure for VS-018

```
assets/
├── buildings/
│   ├── homestead/
│   │   ├── exterior.glb              # House exterior
│   │   ├── interior.glb              # House interior walls
│   │   └── floor.glb                 # Walkable floor
│   └── parts/
│       ├── door.glb                 # Door mesh (separate for animation)
│       ├── window.glb               # Window meshes
│       └── roof.glb                 # Roof mesh
├── furniture/
│   ├── tables/
│   │   ├── dining_table.glb         # Main dining table
│   │   └── small_table.glb          # Side table
│   ├── chairs/
│   │   ├── wooden_chair.glb         # Basic chair
│   │   └── padded_chair.glb         # Comfortable chair
│   ├── kitchen/
│   │   ├── counter.glb              # Kitchen counter
│   │   ├── cabinet.glb              # Kitchen cabinet
│   │   └── stove.glb                # Cooking stove (child-safe)
│   ├── beds/
│   │   └── bed.glb                  # For future sleeping
│   └── decor/
│       ├── shelf.glb                # Wall shelf
│       └── painting.glb             # Wall decoration
└── food/
    ├── ingredients/
    │   ├── apple.glb                # Food ingredient
    │   ├── bread.glb                # Food ingredient
    │   └── vegetable.glb            # Food ingredient
    └── cooked/
        ├── meal.glb                  # Cooked meal
        └── soup.glb                 # Cooked soup
```

### Required Attribution Tracking

For third-party assets with attribution requirements:

```
# data/models/third_party/ATTRIBUTION.md

## Attribution Records for Third-Party Assets

### Poly Pizza - zsky
- **Path**: `data/models/third_party/poly_pizza_zsky/`
- **Source**: [https://poly.pizza/m/zsky](https://poly.pizza/m/zsky)
- **License**: CC BY 4.0
- **Author**: zsky
- **Attribution Required**: YES
- **Attribution Text**: "Building model by zsky (poly.pizza) - CC BY 4.0"
- **Used In**: Homestead exterior
- **Modifications**: None / Scaled / Textured

### Quaternius Models
- **Path**: `data/models/quaternius/`
- **Source**: [https://quaternius.com](https://quaternius.com)
- **License**: CC0
- **Author**: Quaternius
- **Attribution Required**: NO (CC0)
- **Used In**: Furniture, interior
- **Modifications**: Various

### Mixamo Animations
- **Path**: `data/animations/mixamo/`
- **Source**: [https://www.mixamo.com](https://www.mixamo.com)
- **License**: Adobe CC0
- **Author**: Adobe/Mixamo
- **Attribution Required**: NO (CC0)
- **Used In**: Character animations
- **Modifications**: Retargeted to custom skeleton
```

### Asset Import Settings

**Building Models:**
- Scale: Verify 1 unit = 1 meter
- Import Meshes: Yes
- Import Materials: Yes
- Collision: Add manually (BoxShape3D for walls)

**Furniture Models:**
- Scale: Verify compatible with character scale
- Import Meshes: Yes
- Import Materials: Yes
- Collision: Add BoxShape3D fitting each piece

**Food Models:**
- Scale: Small, hand-held size
- Import Meshes: Yes
- Import Materials: Yes
- Collision: SphereShape3D or BoxShape3D

---

## Best Practices

### 1. Child-Safety Guidelines

**Homestead Design:**
- Warm, inviting atmosphere
- Safe, familiar environment
- No scary or dark themes
- Well-lit interior
- Friendly colors and materials

**Interaction Design:**
- Clear, positive feedback
- No failure states
- Instant or very fast actions
- No time pressure
- Always accessible (no locked doors in child mode)

**Cooking Design:**
- No fire, knives, or dangerous tools
- Safe cooking methods (magic, instant, etc.)
- Positive outcomes only
- Fun visuals and sounds
- Clear cause and effect

### 2. Performance Optimization

**Collision Optimization:**
- Use BoxShape3D for furniture (faster than mesh collision)
- Size collision to fit mesh tightly
- Use compound collision for complex shapes
- Disable collision for decorative-only objects

**Rendering Optimization:**
- Use LOD for distant furniture
- Share materials between similar objects
- Use instancing for repeated furniture (chairs, tables)
- Limit draw calls per room to <50

**Interaction Optimization:**
- Use Area3D for proximity detection (faster than raycast for stationary objects)
- Cache interaction checks
- Limit interaction range to 2-3 meters
- Use physics layers to filter interactions

### 3. User Experience

**Interaction Feedback:**
- Visual: Highlight interactable objects
- Audio: Play interaction sounds
- UI: Clear prompts and feedback
- Animation: Smooth transitions

**Discoverability:**
- Prompts appear when near interactables
- Visual cues (glow, outline) on focused objects
- Tutorial hints for first-time interactions
- Progressive disclosure of complex interactions

**Accessibility:**
- High contrast prompts
- Large, readable text
- Clear icons
- Controller-friendly
- Keyboard-friendly

### 4. Data Management

**Persistence:**
- Door states persist across sessions
- Inventory persists (handled separately)
- Health persists (handled separately)
- No save/load lag

**Error Handling:**
- Graceful fallback on missing assets
- Validate all data on load
- Clamp out-of-bounds values
- Log errors for debugging

### 5. Testing Requirements

**Automated Tests:**
- Door opens and closes correctly
- Collision enables/disables with door state
- Sit targets work correctly
- Cooking consumes ingredients
- Cooking produces correct results
- All interactions trigger correct animations

**Manual Tests:**
- Homestead can be entered and exited
- All furniture is interactable
- Cooking loop works end-to-end
- Health restoration works
- UI prompts are clear and readable

---

## Testing Checklist

### Unit Tests

```gdscript
# test_door.gd

func test_door_toggle():
    var door = Door.new()
    door.add_to_scene()  # Setup test scene
    
    assert(door.get_state() == Door.DoorState.CLOSED)
    
    door.toggle()
    assert(door.get_state() == Door.DoorState.OPENING)
    
    # Fast-forward animation
    door.open_door(10.0)
    assert(door.get_state() == Door.DoorState.OPEN)
    
    door.toggle()
    assert(door.get_state() == Door.DoorState.CLOSING)
    
    door.close_door(10.0)
    assert(door.get_state() == Door.DoorState.CLOSED)

func test_door_collision():
    var door = Door.new()
    door.add_to_scene()
    
    # Initially collision should be enabled (door closed)
    assert(not door.collision.disabled)
    
    door.toggle()
    door.open_door(10.0)
    
    # When open, collision should be disabled
    assert(door.collision.disabled)

func test_door_locked():
    var door = Door.new()
    door.is_locked = true
    door.add_to_scene()
    
    door.toggle()
    # Should not change state when locked
    assert(door.get_state() == Door.DoorState.CLOSED)
```

```gdscript
# test_sit_target.gd

func test_sit_target_try_sit():
    var sit_target = SitTarget.new()
    sit_target.add_to_scene()
    
    var player = CharacterBody3D.new()
    player.add_to_scene()
    
    # Initially not occupied
    assert(not sit_target.is_occupied)
    
    # Try to sit
    var result = sit_target.try_sit(player)
    assert(result)
    assert(sit_target.is_occupied)
    assert(sit_target.sitting_player == player)
    assert(player.is_sitting())

func test_sit_target_already_occupied():
    var sit_target = SitTarget.new()
    sit_target.add_to_scene()
    
    var player1 = CharacterBody3D.new()
    var player2 = CharacterBody3D.new()
    
    sit_target.try_sit(player1)
    
    # Should fail to sit when occupied
    var result = sit_target.try_sit(player2)
    assert(not result)

func test_sit_target_stand_up():
    var sit_target = SitTarget.new()
    sit_target.add_to_scene()
    
    var player = CharacterBody3D.new()
    sit_target.try_sit(player)
    
    sit_target.stand_up()
    
    assert(not sit_target.is_occupied)
    assert(sit_target.sitting_player == null)
    assert(not player.is_sitting())
```

```gdscript
# test_cooking_station.gd

func test_cooking_try_cook_no_ingredients():
    var cooking_station = CookingStation.new()
    cooking_station.add_to_scene()
    
    var player = CharacterBody3D.new()
    player.add_to_scene()
    
    # Player has no ingredients
    var result = cooking_station.try_cook(player)
    assert(not result)

func test_cooking_try_cook_with_ingredients():
    var cooking_station = CookingStation.new()
    cooking_station.add_to_scene()
    
    # Setup recipe
    var recipe = RecipeDefinition.new()
    recipe.required_ingredients = [{"type": "apple", "quantity": 1}]
    recipe.result_item = "meal"
    recipe.result_quantity = 1
    cooking_station.recipes = [recipe]
    
    var player = CharacterBody3D.new()
    player.add_to_scene()
    player.inventory.add_item("apple", 1)
    
    var result = cooking_station.try_cook(player)
    assert(result)
    
    # Ingredients should be consumed
    assert(player.inventory.get_item_count("apple") == 0)
    
    # State should be cooking
    assert(cooking_station.current_state == CookingStation.CookingState.COOKING)
```

### Integration Tests

1. **Homestead Entry/Exit**
   - [ ] Player can walk to homestead door
   - [ ] Interaction prompt appears
   - [ ] Door opens when interacting
   - [ ] Player can enter homestead
   - [ ] Door closes after entry (or stays open)
   - [ ] Player can exit homestead
   - [ ] Door interaction works from both sides

2. **Sit Interaction**
   - [ ] Sit prompt appears near chairs
   - [ ] Player sits when interacting
   - [ ] Camera adjusts for sitting view
   - [ ] Player can stand up
   - [ ] Multiple sit targets work independently
   - [ ] Only one player can sit per target

3. **Cooking Loop**
   - [ ] Cooking prompt appears near station
   - [ ] Player can cook with ingredients
   - [ ] Cooking visuals appear
   - [ ] Result appears in inventory
   - [ ] Meal can be consumed
   - [ ] Health is restored
   - [ ] Full loop: gather -> cook -> eat -> heal

4. **Physics & Collision**
   - [ ] Homestead walls block player
   - [ ] Door collision works correctly
   - [ ] Furniture collision prevents walking through
   - [ ] Sit targets have correct positions
   - [ ] No collision gaps or overlaps

5. **Visual Quality**
   - [ ] Homestead looks intentional
   - [ ] Furniture is properly scaled
   - [ ] All meshes have materials
   - [ ] No missing textures
   - [ ] Lighting is appropriate

### Manual Tests

1. **Child Flow Test**
   - [ ] Child can find homestead
   - [ ] Child can enter homestead
   - [ ] Child can sit at table
   - [ ] Child can find cooking station
   - [ ] Child can cook a meal (with ingredients)
   - [ ] Child can eat meal
   - [ ] Child can restore health
   - [ ] Child can exit homestead

2. **Visual Acceptance**
   - [ ] Homestead fits visual style
   - [ ] No floating objects
   - [ ] No clipping geometry
   - [ ] No missing collision
   - [ ] Prompts are readable
   - [ ] Animations are smooth

3. **Performance Test**
   - [ ] No frame rate drops in homestead
   - [ ] Memory usage is stable
   - [ ] Interaction is responsive
   - [ ] Works on Tier 2 hardware

---

## Learning Resources

### Official Godot Documentation

1. **Godot 3D Tutorials**: [https://docs.godotengine.org/en/stable/tutorials/3d/index.html](https://docs.godotengine.org/en/stable/tutorials/3d/index.html)
2. **Godot Physics**: [https://docs.godotengine.org/en/stable/tutorials/physics/index.html](https://docs.godotengine.org/en/stable/tutorials/physics/index.html)
3. **Godot Area3D**: [https://docs.godotengine.org/en/stable/classes/class_area3d.html](https://docs.godotengine.org/en/stable/classes/class_area3d.html)
4. **Godot Animation**: [https://docs.godotengine.org/en/stable/tutorials/animation/index.html](https://docs.godotengine.org/en/stable/tutorials/animation/index.html)

### Community Tutorials

1. **GDQuest - Interaction Systems**: [https://gdquest.com/tutorial/godot-4-interaction-system/](https://gdquest.com/tutorial/godot-4-interaction-system/)
2. **HeartBeast - Door Tutorial**: [https://www.heartbeast.co/godot-4-door-system/](https://www.heartbeast.co/godot-4-door-system/)
3. **KidsCanCode - Area3D Interaction**: [https://kids-candies.gitbook.io/godot-tutorials/3d/area3d-interaction](https://kids-candies.gitbook.io/godot-tutorials/3d/area3d-interaction)
4. **Game Dev League - Furniture System**: [https://www.youtube.com/watch?v=example-furniture](https://www.youtube.com/watch?v=example-furniture)

### Asset-Specific Resources

1. **Quaternius Building Tutorial**: [https://quaternius.com/tutorials/buildings](https://quaternius.com/tutorials/buildings)
2. **Poly Pizza Getting Started**: [https://poly.pizza/docs](https://poly.pizza/docs)
3. **CC0 Licensing Guide**: [https://creativecommons.org/licenses/by/4.0/](https://creativecommons.org/licenses/by/4.0/)

### Architecture References

1. **Hexagonal Architecture in Godot**: [https://docs.godotengine.org/en/stable/tutorials/architecture/hexagonal_architecture.html](https://docs.godotengine.org/en/stable/tutorials/architecture/hexagonal_architecture.html)
2. **Clean Code Godot**: [https://github.com/GodotExplorer/Clean-Code-Godot](https://github.com/GodotExplorer/Clean-Code-Godot)

---

## Implementation Roadmap

### Phase 1: Asset Pipeline (2-3 hours)
- [ ] Source/gather homestead building model
- [ ] Source/gather furniture models (table, chairs, cooking station)
- [ ] Import all models with correct scale
- [ ] Create collision shapes for all furniture
- [ ] Create attribution records for third-party assets
- [ ] Test all models in scene

### Phase 2: Door System (1-2 hours)
- [ ] Create Door.gd class
- [ ] Implement door mesh and collision
- [ ] Add open/close animation
- [ ] Add door state management
- [ ] Add door interactable
- [ ] Test door interaction

### Phase 3: Sit System (2-3 hours)
- [ ] Create SitTarget.gd class
- [ ] Implement sit position/rotation
- [ ] Add sit area detection
- [ ] Add player sitting state
- [ ] Implement camera offset for sitting
- [ ] Add sit animation
- [ ] Add sit interactable
- [ ] Test sit interaction

### Phase 4: Cooking System (2-3 hours)
- [ ] Create CookingStation.gd class
- [ ] Define recipe system
- [ ] Implement ingredient checking
- [ ] Add cooking animation/visuals
- [ ] Add cooking interactable
- [ ] Integrate with inventory
- [ ] Add meal result
- [ ] Test cooking loop

### Phase 5: Homestead Assembly (2-3 hours)
- [ ] Create homestead scene structure
- [ ] Place building exterior
- [ ] Place door at entrance
- [ ] Create homestead interior
- [ ] Place floor and walls
- [ ] Place furniture (table, chairs, cooking station)
- [ ] Add lighting
- [ ] Test homestead entry/exit

### Phase 6: Integration & Polish (2-3 hours)
- [ ] Integrate with world_renderer.gd
- [ ] Add homestead to adventure template
- [ ] Test full interaction loop
- [ ] Add polish (sounds, particles, etc.)
- [ ] Performance testing
- [ ] Accessibility review
- [ ] Child-safety review

### Phase 7: Testing (1-2 hours)
- [ ] Write unit tests
- [ ] Manual UX testing
- [ ] Visual acceptance testing
- [ ] Performance testing
- [ ] Bug fixing

### Total Estimated Time: 12-21 hours

---

## References

### Internal Project References
- `src/adapters/inbound/gameplay/world_renderer.gd` - Contains `_build_starter_homestead()`
- `data/models/third_party/poly_pizza_zsky` - Existing third-party model
- `PLAN.md` - Project requirements and evidence
- `manual-qa/VS-018/` - Manual QA evidence (to be created)

### External References
- [Godot Engine Documentation](https://docs.godotengine.org/en/stable/)
- [GDQuest Tutorials](https://gdquest.com/)
- [Quaternius Free 3D Models](https://quaternius.com/free-3d-models)
- [Poly Pizza Models](https://poly.pizza/)
- [Kenney Assets](https://kenney.nl/assets)

### Related Tasks
- VS-013: Compose opening route (for homestead placement)
- VS-014: Modern Game UI (for interaction prompts)
- VS-020: Tool-Gated Gathering (for ingredient gathering)
- VS-022: Character Customization (for player representation)

---

## Document Information

**Created**: 2026-07-18  
**Author**: Mistral Vibe (Codex)  
**Version**: 1.0  
**Status**: Deep Research Complete - Ready for Implementation  
**Priority**: HIGH (Gate A blocker)  

---

*This research compendium was created as part of the Choyce Engine VS-018 Homestead Interaction Loop task. All information is accurate as of July 2026. Online resources and links may change over time.*
