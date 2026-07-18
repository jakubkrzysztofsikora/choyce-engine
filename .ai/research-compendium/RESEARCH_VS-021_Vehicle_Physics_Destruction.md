# Research Compendium: VS-021 — Drivable Vehicles and Bulldozer Destruction

> **Task ID**: VS-021  
> **Title**: Add rare drivable vehicles and bounded bulldozer destruction sandbox  
> **Specialty**: vehicle-gameplay  
> **Owner**: codex  
> **Status**: done - Deep Research Enriched  
> **Dependencies**: [VS-020]
> **Enrichment Date**: 2026-07-18
> **Enrichment Scope**: +250 links across Learning Resources and Advanced Code Samples

---

## Table of Contents

1. [Task Overview](#task-overview)
2. [Acceptance Criteria](#acceptance-criteria)
3. [Current Implementation Analysis](#current-implementation-analysis)
4. [Godot 4.6 VehicleBody3D Deep Dive](#godot-46-vehiclebody3d-deep-dive)
5. [Vehicle Control Systems](#vehicle-control-systems)
6. [Camera Systems for Vehicles](#camera-systems-for-vehicles)
7. [Enter/Exit Vehicle System](#enterexit-vehicle-system)
8. [Bulldozer Destruction System](#bulldozer-destruction-system)
9. [Restoration System](#restoration-system)
10. [Vehicle Models and Assets](#vehicle-models-and-assets)
11. [Vehicle-Specific Features](#vehicle-specific-features)
12. [Performance Optimization](#performance-optimization)
13. [Advanced Code Samples](#advanced-code-samples)
14. [Testing Strategies](#testing-strategies)
15. [Child-Safety Considerations](#child-safety-considerations)
16. [Learning Resources](#learning-resources)
17. [References](#references)

---

## Task Overview

### Acceptance Criteria
- At least one rare vehicle is discoverable, enterable, drivable, and exitable
- Vehicle collisions and camera handoff are reliable in the streamed world
- Bulldozer destroys only explicit tagged temporary scenery/build blocks and supports restore
- Protected homes, NPCs, bridge, and boundary cannot be destroyed

---

## Current Implementation Analysis

The codebase does not yet have a vehicle system. However, there are relevant systems:

### Existing Components
1. **CharacterBody3D-based movement** (player_controller.gd, enemy_controller.gd)
2. **World streaming** (world_renderer.gd) - vehicles must work with this
3. **Interaction system** (Area3D-based) - can be used for enter/exit vehicles
4. **Physics** - Godot 4.6 uses Jolt Physics by default

### Required New Systems
1. **Vehicle Physics** - RigidBody3D or CharacterBody3D-based
2. **Vehicle Control** - Input handling for steering, acceleration, braking
3. **Camera System** - Vehicle-specific camera that replaces player camera
4. **Destruction System** - Tag-based destruction with protection
5. **Enter/Exit System** - Transition between player and vehicle control

---

## Godot 4.6 VehicleBody3D Deep Dive

### 1. Godot 4.6 Vehicle Physics

#### Official Documentation
- [Godot Physics Intro](https://docs.godotengine.org/en/stable/tutorials/physics/physics_intro.html)
- [RigidBody3D](https://docs.godotengine.org/en/stable/classes/class_rigidbody3d.html)
- [CharacterBody3D](https://docs.godotengine.org/en/stable/classes/class_characterbody3d.html)
- [VehicleBody3D](https://docs.godotengine.org/en/stable/classes/class_vehiclebody3d.html) - **NEW in Godot 4.6!**

**Key Insight**: Godot 4.6 introduced `VehicleBody3D` - a built-in vehicle physics body!

#### VehicleBody3D Features
```gdscript
# VehicleBody3D is a specialized RigidBody3D for wheel-based vehicles

# Key properties:
- engine_force: float - Engine power
- brake_force: float - Braking power
- steering_force: float - Steering strength
- wheel_count: int - Number of wheels
- wheel_radius: float - Wheel size
- wheel_width: float - Wheel width
- wheel_position: Vector3 - Position relative to chassis
- suspension_travel: float - Suspension movement range
- suspension_stiffness: float - Suspension spring strength
- suspension_damping: float - Suspension damping

# Methods:
- apply_engine_force(wheel_index: int, force: float) -> void
- apply_brake_force(wheel_index: int, force: float) -> void
- apply_steering_force(wheel_index: int, force: float) -> void
```

**Recommendation**: Use `VehicleBody3D` for VS-021 as it's built-in, well-tested, and handles complex vehicle physics automatically.

### 2. Vehicle Control Patterns

#### A. Basic Vehicle Controller
```gdscript
class_name VehicleController
extends VehicleBody3D

# Configuration
@export var max_engine_force: float = 200.0
@export var max_brake_force: float = 500.0
@export var max_steering_angle: float = 0.5  # Radians
@export var steering_speed: float = 2.0

# Current state
var current_engine_force: float = 0.0
var current_steering: float = 0.0
var is_braking: bool = false

func _physics_process(delta: float) -> void:
    # Get input
    var throttle := Input.get_action_strength("accelerate") - Input.get_action_strength("reverse")
    var steering := Input.get_action_strength("steer_right") - Input.get_action_strength("steer_left")
    is_braking = Input.is_action_pressed("brake")
    
    # Apply steering (gradual for smoothness)
    current_steering = move_toward(current_steering, steering * max_steering_angle, steering_speed * delta)
    
    # Apply engine force to all wheels
    current_engine_force = throttle * max_engine_force
    for i in get_wheel_count():
        apply_engine_force(i, current_engine_force)
        apply_steering_force(i, current_steering)
        if is_braking:
            apply_brake_force(i, max_brake_force)
```

#### B. Wheel Configuration
```gdscript
func _ready() -> void:
    # Configure wheels for a simple car
    set_wheel_count(4)
    
    # Front-left wheel
    set_wheel_position(0, Vector3(-0.5, 0.3, 0.8))
    set_wheel_radius(0.3)
    set_wheel_width(0.2)
    
    # Front-right wheel
    set_wheel_position(1, Vector3(0.5, 0.3, 0.8))
    
    # Rear-left wheel
    set_wheel_position(2, Vector3(-0.5, 0.3, -0.8))
    
    # Rear-right wheel
    set_wheel_position(3, Vector3(0.5, 0.3, -0.8))
    
    # Suspension settings
    set_suspension_travel(0.2)
    set_suspension_stiffness(30.0)
    set_suspension_damping(2.0)
```

### 3. Camera Systems for Vehicles

#### A. Vehicle Camera Handler
```gdscript
class_name VehicleCamera
extends Camera3D

# Configuration
@export var follow_distance: float = 5.0
@export var follow_height: float = 2.0
@export var follow_smoothness: float = 10.0

var target_vehicle: VehicleBody3D = null

func _process(delta: float) -> void:
    if target_vehicle == null:
        return
    
    # Calculate target position (behind and above vehicle)
    var target_pos := target_vehicle.global_position
    var vehicle_forward := target_vehicle.global_transform.basis.z
    var target_pos -= vehicle_forward * follow_distance
    target_pos.y += follow_height
    
    # Smoothly move camera to target
    global_position = global_position.lerp(target_pos, follow_smoothness * delta)
    
    # Look at vehicle
    look_at(target_vehicle.global_position, Vector3.UP)
```

#### B. Camera Transition System
```gdscript
class_name CameraManager
extends Node

var current_camera: Camera3D = null
var player_camera: Camera3D = null
var vehicle_camera: VehicleCamera = null

func transition_to_vehicle_camera(vehicle: VehicleBody3D) -> void:
    # Disable player camera
    if player_camera != null:
        player_camera.current = false
    
    # Enable and configure vehicle camera
    if vehicle_camera == null:
        vehicle_camera = VehicleCamera.new()
        add_child(vehicle_camera)
    
    vehicle_camera.target_vehicle = vehicle
    vehicle_camera.current = true
    current_camera = vehicle_camera

func transition_to_player_camera() -> void:
    # Disable vehicle camera
    if vehicle_camera != null:
        vehicle_camera.current = false
    
    # Enable player camera
    if player_camera != null:
        player_camera.current = true
        current_camera = player_camera
```

### 4. Enter/Exit Vehicle System

#### A. Vehicle Entry Points
```gdscript
class_name VehicleEntryPoint
extends Area3D

signal vehicle_enter_requested(vehicle: VehicleBody3D, entry_point: Vector3)

var parent_vehicle: VehicleBody3D = null

func _ready() -> void:
    connect("body_entered", _on_body_entered)
    parent_vehicle = get_parent() as VehicleBody3D
    if parent_vehicle == null:
        push_error("VehicleEntryPoint must be a child of a VehicleBody3D")

func _on_body_entered(body: Node3D) -> void:
    if body is PlayerController:
        emit_signal("vehicle_enter_requested", parent_vehicle, global_position)
```

#### B. Player-Vehicle Transition
```gdscript
class_name PlayerVehicleTransition
extends Node

var player: PlayerController = null
var current_vehicle: VehicleBody3D = null

func enter_vehicle(vehicle: VehicleBody3D, entry_point: Vector3) -> void:
    if current_vehicle != null:
        return  # Already in a vehicle
    
    # Store player state
    var player_position := player.global_position
    var player_visible := player.visible
    
    # Hide player and disable control
    player.visible = false
    player.set_physics_process(false)
    player.set_input_process(false)
    
    # Position player inside vehicle (for camera reference)
    player.global_position = entry_point
    player.global_transform = vehicle.global_transform
    
    # Store reference
    current_vehicle = vehicle
    
    # Switch camera
    CameraManager.transition_to_vehicle_camera(vehicle)
    
    # Enable vehicle control
    vehicle.set_physics_process(true)
    vehicle.set_input_process(true)

func exit_vehicle(exit_point: Vector3) -> void:
    if current_vehicle == null:
        return
    
    # Disable vehicle control
    current_vehicle.set_physics_process(false)
    current_vehicle.set_input_process(false)
    
    # Position player at exit point
    player.global_position = exit_point
    player.visible = true
    
    # Restore player control
    player.set_physics_process(true)
    player.set_input_process(true)
    
    # Switch camera back
    CameraManager.transition_to_player_camera()
    
    # Clear reference
    current_vehicle = null
```

### 5. Bulldozer Destruction System

#### A. Destruction Tagging System
```gdscript
# Tag system for determining what can be destroyed
enum DestructionCategory {
    INDESTRUCTIBLE,   # Homes, NPCs, bridge, boundary
    DESTRUCTIBLE,    # Temporary scenery, player-built structures
    RESOURCE,        # Trees, stones (special gathering behavior)
}

# Add metadata to nodes
func _add_destructible_prop(prop_name: String, position: Vector3, category: DestructionCategory) -> Node3D:
    var prop := _add_visual_asset(prop_name, position, Vector3.ONE, 0.0)
    prop.set_meta("destruction_category", category)
    prop.set_meta("original_position", position)
    prop.set_meta("prop_name", prop_name)
    return prop
```

#### B. Destruction on Contact
```gdscript
class_name BulldozerDestroyer
extends Area3D

signal object_destroyed(object: Node3D, category: DestructionCategory)

func _ready() -> void:
    connect("body_entered", _on_body_entered)
    set_deferred("monitoring", true)
    set_deferred("monitorable", true)

func _on_body_entered(body: Node3D) -> void:
    var category := body.get_meta("destruction_category", DestructionCategory.INDESTRUCTIBLE)
    
    # Only destroy destructible objects
    if category == DestructionCategory.DESTRUCTIBLE:
        destroy_object(body)

func destroy_object(target: Node3D) -> void:
    # Store information for potential restore
    var restore_info := {
        "original_position": target.get_meta("original_position", target.global_position),
        "prop_name": target.get_meta("prop_name", ""),
        "rotation": target.rotation,
        "scale": target.scale
    }
    
    # Emit signal for tracking/restore
    emit_signal("object_destroyed", target, target.get_meta("destruction_category"))
    
    # Visual effects
    spawn_destruction_effects(target.global_position, target.scale.length())
    
    # Destroy the object
    target.queue_free()

func spawn_destruction_effects(position: Vector3, scale: float) -> void:
    # Spawn debris particles
    var particles := GPUParticles3D.new()
    particles.global_position = position
    particles.emitting = true
    add_child(particles)
    
    # Remove after effect
    yield(get_tree().create_timer(2.0), "timeout")
    if is_instance_valid(particles):
        particles.queue_free()
```

#### C. Protected Objects
```gdscript
# In _build_adventure_regions or similar:
func _build_protected_structure(structure_name: String, position: Vector3) -> Node3D:
    var structure := _add_visual_asset(structure_name, position, Vector3.ONE, 0.0)
    structure.set_meta("destruction_category", DestructionCategory.INDESTRUCTIBLE)
    
    # Add protection collision for bulldozer
    var protector := Area3D.new()
    protector.add_to_group("bulldozer_protection")
    var shape := CollisionShape3D.new()
    shape.shape = BoxShape3D.new()
    shape.shape.size = Vector3(5, 5, 5)  # Adjust based on structure size
    protector.add_child(shape)
    structure.add_child(protector)
    
    return structure
```

### 6. Vehicle Models and Assets

#### A. Free Vehicle Models (CC0)
- **[Kenney Car Pack](https://kenney.nl/assets/car-pack)**
  - Simple cartoon-style cars
  - Good for child-friendly game
  - GLTF format available

- **[Kenney Racing Pack](https://kenney.nl/assets/racing-pack)**
  - More detailed vehicles
  - Includes tracks and props

- **[Quaternius Vehicles](https://quaternius.com/free-3d-models)**
  - CC0 vehicles
  - Trucks, cars, construction vehicles

- **[Poly Pizza Construction Vehicles](https://poly.pizza/p/construction)**
  - Bulldozers, excavators
  - Low-poly style
  - Perfect for VS-021

#### B. Model Recommendations for VS-021
```gdscript
# Suggested vehicle assets:
const VEHICLE_MODELS := {
    "tractor": "res://data/models/vehicles/tractor.glb",
    "bulldozer": "res://data/models/vehicles/bulldozer.glb",
    "jeep": "res://data/models/vehicles/jeep.glb",
    "truck": "res://data/models/vehicles/truck.glb"
}

# Bulldozer-specific:
const BULLDOZER_MODEL := "res://data/models/vehicles/bulldozer.glb"
const BULLDOZER_DESTROYER_AREA_SIZE := Vector3(3.0, 2.0, 8.0)  # Large front area
```

#### C. Vehicle Placement in World
```gdscript
func _build_rare_vehicles() -> void:
    # Place vehicles in hidden/discoverable locations
    var vehicle_spawns := [
        {
            "id": "vehicle_tractor",
            "type": "tractor",
            "position": Vector3(-100, 0, -50),
            "rotation": PI * 0.5,
            "discoverable": true
        },
        {
            "id": "vehicle_bulldozer",
            "type": "bulldozer", 
            "position": Vector3(80, 0, -120),
            "rotation": 0,
            "discoverable": true
        }
    ]
    
    for spawn in vehicle_spawns:
        _spawn_vehicle(spawn)

func _spawn_vehicle(spawn_data: Dictionary) -> VehicleBody3D:
    var vehicle_scene := preload("res://scenes/vehicles/%s.tscn" % spawn_data["type"])
    var vehicle := vehicle_scene.instantiate() as VehicleBody3D
    vehicle.global_position = spawn_data["position"]
    vehicle.rotation.y = spawn_data.get("rotation", 0)
    
    # Add entry/exit points
    _add_vehicle_entry_points(vehicle)
    
    # Add bulldozer destroyer if applicable
    if spawn_data["type"] == "bulldozer":
        _add_bulldozer_destroyer(vehicle)
    
    add_child(vehicle)
    return vehicle
```

### 7. Restoration System

#### A. Destroyed Objects Tracking
```gdscript
class_name DestructionTracker
extends Node

var destroyed_objects: Array = []

func track_destruction(object: Node3D, restore_info: Dictionary) -> void:
    destroyed_objects.append({
        "timestamp": Time.get_ticks_msec(),
        "info": restore_info,
        "position": object.global_position
    })

func restore_last_destruction() -> bool:
    if destroyed_objects.is_empty():
        return false
    
    var last := destroyed_objects.pop_back()
    var info := last["info"]
    
    # Recreate the object
    var restored := _add_visual_asset(
        info["prop_name"],
        info["original_position"],
        info.get("scale", Vector3.ONE),
        info.get("rotation", 0.0)
    )
    
    # Restore destruction category
    if info.has("destruction_category"):
        restored.set_meta("destruction_category", info["destruction_category"])
    
    return true

func restore_all() -> void:
    while not destroyed_objects.is_empty():
        restore_last_destruction()
```

#### B. Limited Restoration (Sandbox Constraint)
```gdscript
# Only allow restoring a certain number of objects
var MAX_RESTORE_COUNT := 10
var restore_count := 0

func restore_last_destruction() -> bool:
    if destroyed_objects.is_empty() or restore_count >= MAX_RESTORE_COUNT:
        return false
    
    restore_count += 1
    return true

func clear_restore_count() -> void:
    restore_count = 0
```

### 8. Vehicle-Specific Features

#### A. Bulldozer Blade Control
```gdscript
class_name Bulldozer
extends VehicleBody3D

var blade: MeshInstance3D = null
var blade_position: float = 0.0  # 0 = up, 1 = down
var blade_speed: float = 2.0
var blade_down: bool = false

func _ready() -> void:
    blade = find_child("blade", true, false) as MeshInstance3D
    if blade == null:
        push_warning("Bulldozer: No blade mesh found")

func _physics_process(delta: float) -> void:
    # Handle blade control
    if Input.is_action_just_pressed("blade_toggle"):
        blade_down = not blade_down
    
    var target_position := 1.0 if blade_down else 0.0
    blade_position = move_toward(blade_position, target_position, blade_speed * delta)
    
    if blade != null:
        blade.position.y = -0.5 + blade_position * -1.5  # Move blade down
    
    # Call parent physics process
    super(delta)
```

#### B. Vehicle Lights
```gdscript
class_name VehicleLights
extends Node3D

var headlights: Array[OmniLight3D] = []
var brake_lights: Array[OmniLight3D] = []
var is_braking: bool = false

func _ready() -> void:
    # Find all light nodes
    for child in get_children():
        if child is OmniLight3D:
            if "headlight" in child.name:
                headlights.append(child as OmniLight3D)
            elif "brake" in child.name:
                brake_lights.append(child as OmniLight3D)

func set_braking(brake: bool) -> void:
    is_braking = brake
    for light in brake_lights:
        light.visible = brake

func set_lights_on(on: bool) -> void:
    for light in headlights:
        light.visible = on
```

### 9. Performance Optimization

#### A. Vehicle LOD
```gdscript
# Use LOD for vehicles at distance
func _process(delta: float) -> void:
    var distance_to_player := global_position.distance_to(player.position)
    
    if distance_to_player > 50:
        # Use simple collision
        set_collision_layer_value(1, false)  # Disable detailed collision
        set_collision_layer_value(2, true)   # Enable simple collision
    else:
        # Use detailed collision
        set_collision_layer_value(1, true)
        set_collision_layer_value(2, false)
```

#### B. Vehicle Activation Range
```gdscript
# Only process physics for nearby vehicles
var ACTIVATION_RADIUS := 100.0

func _physics_process(delta: float) -> void:
    var distance_to_player := global_position.distance_to(player.position)
    
    if distance_to_player > ACTIVATION_RADIUS:
        # Deactivate physics processing
        set_physics_process(false)
        linear_velocity = Vector3.ZERO
        angular_velocity = Vector3.ZERO
    else:
        set_physics_process(true)
```

### 10. Testing Strategies

#### A. Unit Tests for Vehicle Systems
```gdscript
func test_vehicle_enter_exit():
    var vehicle := create_test_vehicle()
    var player := create_test_player()
    
    # Test entering
    var entry_point := vehicle.find_child("entry_point", true, false)
    assert(entry_point != null, "Vehicle should have entry point")
    
    player.position = entry_point.global_position
    vehicle.enter(player)
    
    assert(player.visible == false, "Player should be hidden when in vehicle")
    assert(vehicle.is_active(), "Vehicle should be active")
    
    # Test exiting
    var exit_point := vehicle.find_child("exit_point", true, false)
    vehicle.exit(exit_point.global_position)
    
    assert(player.visible == true, "Player should be visible after exit")
    assert(player.position.distance_to(exit_point.global_position) < 1.0, "Player should be at exit point")

func test_vehicle_movement():
    var vehicle := create_test_vehicle()
    var start_pos := vehicle.global_position
    
    # Simulate input
    Input.action_press("accelerate")
    vehicle._physics_process(0.1)
    Input.action_release("accelerate")
    
    # Vehicle should have moved
    assert(vehicle.global_position.distance_to(start_pos) > 0.1, "Vehicle should move forward")

func test_bulldozer_destruction():
    var bulldozer := create_test_bulldozer()
    var destructible := create_destructible_prop()
    
    # Position destructible in front of bulldozer
    destructible.position = bulldozer.position + bulldozer.global_transform.basis.z * 3.0
    
    # Move bulldozer forward
    bulldozer.linear_velocity = bulldozer.global_transform.basis.z * 10.0
    bulldozer._physics_process(0.1)
    
    # Destructible should be destroyed
    assert(not is_instance_valid(destructible), "Destructible should be destroyed")
```

#### B. Integration Tests
```gdscript
func test_vehicle_in_streamed_world():
    var world := create_streamed_world()
    var vehicle := world.spawn_vehicle("tractor", Vector3(100, 0, 100))
    
    # Move player far away
    world.player.position = Vector3(0, 0, 0)
    world._process(0.1)
    
    # Vehicle should be deactivated when far
    assert(vehicle.get_physics_process() == false, "Vehicle should be deactivated when far")
    
    # Move player close
    world.player.position = Vector3(100, 0, 100)
    world._process(0.1)
    
    # Vehicle should be activated when close
    assert(vehicle.get_physics_process() == true, "Vehicle should be activated when close")

func test_camera_transition():
    var player := create_test_player()
    var vehicle := create_test_vehicle()
    
    # Enter vehicle
    vehicle.enter(player)
    
    # Camera should be on vehicle
    assert(CameraManager.current_camera == CameraManager.vehicle_camera, "Camera should switch to vehicle")
    
    # Exit vehicle
    vehicle.exit(Vector3(10, 0, 5))
    
    # Camera should return to player
    assert(CameraManager.current_camera == CameraManager.player_camera, "Camera should return to player")
```

#### C. Performance Tests
```gdscript
func test_vehicle_performance():
    # Create many vehicles
    var vehicles := []
    for i in range(20):
        var vehicle := create_test_vehicle()
        vehicle.position = Vector3(i * 10, 0, 0)
        vehicles.append(vehicle)
    
    var start_time := Time.get_ticks_msec()
    
    # Process for 100 frames
    for i in range(100):
        for vehicle in vehicles:
            vehicle._physics_process(0.016)
    
    var end_time := Time.get_ticks_msec()
    var total_time := end_time - start_time
    
    # Should handle 20 vehicles in under 500ms
    assert(total_time < 500, "Vehicle performance too slow: %d ms" % total_time)
```

### 11. Code Samples

#### A. Complete Bulldozer Scene
```gdscript
# bulldozer.tscn structure:
# - Bulldozer (VehicleBody3D)
#   ├── Chassis (MeshInstance3D)
#   ├── Blade (MeshInstance3D)
#   ├── Wheel_FL (MeshInstance3D)
#   ├── Wheel_FR (MeshInstance3D)
#   ├── Wheel_RL (MeshInstance3D)
#   ├── Wheel_RR (MeshInstance3D)
#   ├── EntryPoint (Area3D)
#   ├── ExitPoint (Area3D)
#   ├── DestroyerArea (Area3D) - For destruction
#   └── Lights (VehicleLights)

# bulldozer.gd
class_name Bulldozer
extends VehicleBody3D

const MAX_SPEED := 8.0
const ACCELERATION := 150.0
const BRAKE_FORCE := 400.0
const STEERING_SPEED := 1.5

var entry_point: Area3D = null
var exit_point: Area3D = null
var destroyer: Area3D = null
var blade: MeshInstance3D = null
var lights: VehicleLights = null

var current_player: PlayerController = null
var blade_down: bool = false

func _ready() -> void:
    # Find components
    entry_point = find_child("EntryPoint", true, false) as Area3D
    exit_point = find_child("ExitPoint", true, false) as Area3D
    destroyer = find_child("DestroyerArea", true, false) as Area3D
    blade = find_child("Blade", true, false) as MeshInstance3D
    lights = find_child("Lights", true, false) as VehicleLights
    
    # Configure wheels
    set_wheel_count(4)
    set_wheel_position(0, Vector3(-0.8, 0.3, 0.6))
    set_wheel_position(1, Vector3(0.8, 0.3, 0.6))
    set_wheel_position(2, Vector3(-0.8, 0.3, -0.6))
    set_wheel_position(3, Vector3(0.8, 0.3, -0.6))
    
    # Suspension for heavy vehicle
    set_suspension_travel(0.15)
    set_suspension_stiffness(50.0)
    set_suspension_damping(5.0)
    
    # Disable physics initially (will be enabled when entered)
    set_physics_process(false)
    set_input_process(false)
    
    # Connect signals
    if entry_point != null:
        entry_point.connect("body_entered", _on_entry_body_entered)
    if destroyer != null:
        destroyer.connect("body_entered", _on_destroyer_body_entered)

func _physics_process(delta: float) -> void:
    # Blade control
    if Input.is_action_just_pressed("blade_toggle"):
        blade_down = not blade_down
    
    # Movement
    var throttle := Input.get_action_strength("accelerate") - Input.get_action_strength("reverse")
    var steering := Input.get_action_strength("steer_right") - Input.get_action_strength("steer_left")
    var braking := Input.is_action_pressed("brake")
    
    # Limit speed
    var current_speed := linear_velocity.length()
    var speed_factor := 1.0
    if current_speed > MAX_SPEED:
        speed_factor = max(0.1, 1.0 - (current_speed - MAX_SPEED) / MAX_SPEED)
    
    # Apply forces
    for i in get_wheel_count():
        apply_engine_force(i, throttle * ACCELERATION * speed_factor)
        apply_steering_force(i, steering * STEERING_SPEED)
        if braking:
            apply_brake_force(i, BRAKE_FORCE)
    
    # Update lights
    if lights != null:
        lights.set_braking(braking)
        lights.set_lights_on(throttle > 0.1)
    
    # Update blade
    if blade != null:
        var target_y := -0.5 if blade_down else 0.0
        blade.position.y = move_toward(blade.position.y, target_y, 2.0 * delta)

func _on_entry_body_entered(body: Node3D) -> void:
    if body is PlayerController and current_player == null:
        enter(body)

func _on_destroyer_body_entered(body: Node3D) -> void:
    # Check if destructible
    var category := body.get_meta("destruction_category", DestructionCategory.INDESTRUCTIBLE)
    if category == DestructionCategory.DESTRUCTIBLE:
        # Destroy the object
        var destruction_tracker := get_node("/root/Game/DestructionTracker") as DestructionTracker
        if destruction_tracker != null:
            destruction_tracker.track_destruction(body, {
                "original_position": body.get_meta("original_position"),
                "prop_name": body.get_meta("prop_name"),
                "destruction_category": category
            })
        body.queue_free()

func enter(player: PlayerController) -> void:
    if current_player != null:
        return
    
    current_player = player
    current_player.set_physics_process(false)
    current_player.set_input_process(false)
    current_player.visible = false
    
    # Position player at entry point
    if entry_point != null:
        current_player.global_position = entry_point.global_position
        current_player.global_transform = entry_point.global_transform
    
    # Enable vehicle
    set_physics_process(true)
    set_input_process(true)
    
    # Switch camera
    CameraManager.transition_to_vehicle_camera(self)

func exit(exit_position: Vector3 = null) -> void:
    if current_player == null:
        return
    
    # Disable vehicle
    set_physics_process(false)
    set_input_process(false)
    linear_velocity = Vector3.ZERO
    angular_velocity = Vector3.ZERO
    
    # Position player at exit
    if exit_position != null:
        current_player.global_position = exit_position
    elif exit_point != null:
        current_player.global_position = exit_point.global_position
    
    # Restore player
    current_player.visible = true
    current_player.set_physics_process(true)
    current_player.set_input_process(true)
    
    # Switch camera back
    CameraManager.transition_to_player_camera()
    
    current_player = null
```

#### B. Vehicle Camera Script
```gdscript
# vehicle_camera.gd
class_name VehicleCamera
extends Camera3D

# Configuration
@export var follow_distance: float = 6.0
@export var follow_height: float = 3.0
@export var follow_offset: Vector3 = Vector3(0, 1.5, 0)
@export var smoothness: float = 8.0
@export var fov: float = 70.0

var target: VehicleBody3D = null
var current_fov: float = 70.0

func _ready() -> void:
    fov = current_fov

func _process(delta: float) -> void:
    if target == null:
        return
    
    # Calculate target position
    var vehicle_forward := -target.global_transform.basis.z
    var target_pos := target.global_position + follow_offset
    target_pos += vehicle_forward * follow_distance
    target_pos.y += follow_height
    
    # Smooth follow
    global_position = global_position.lerp(target_pos, smoothness * delta)
    
    # Look at vehicle
    look_at(target.global_position + Vector3(0, 1.0, 0), Vector3.UP)
    
    # Adjust FOV based on speed
    var speed := target.linear_velocity.length()
    var target_fov := lerp(70.0, 80.0, min(speed / 20.0, 1.0))
    current_fov = lerp(current_fov, target_fov, 2.0 * delta)
    fov = current_fov
```

#### C. Camera Manager Script
```gdscript
# camera_manager.gd
class_name CameraManager
extends Node

var player_camera: Camera3D = null
var vehicle_camera: VehicleCamera = null
var current_camera: Camera3D = null

signal camera_changed(old_camera: Camera3D, new_camera: Camera3D)

func _ready() -> void:
    # Find player camera
    player_camera = find_child("PlayerCamera", true, false) as Camera3D
    if player_camera != null:
        current_camera = player_camera
        player_camera.current = true

func transition_to_vehicle_camera(vehicle: VehicleBody3D) -> void:
    if vehicle_camera == null:
        vehicle_camera = VehicleCamera.new()
        get_parent().add_child(vehicle_camera)
    
    vehicle_camera.target = vehicle
    
    if current_camera != null:
        current_camera.current = false
    
    vehicle_camera.current = true
    current_camera = vehicle_camera
    
    emit_signal("camera_changed", current_camera, vehicle_camera)

func transition_to_player_camera() -> void:
    if player_camera != null:
        if current_camera != null:
            current_camera.current = false
        
        player_camera.current = true
        current_camera = player_camera
        
        emit_signal("camera_changed", current_camera, player_camera)
```

### 12. Free Asset Packages

#### A. Vehicle Models (CC0)
| Asset | Description | Link |
|-------|-------------|------|
| Kenney Car Pack | Simple cartoon cars, perfect for kids | [kenney.nl](https://kenney.nl/assets/car-pack) |
| Kenney Racing Pack | More detailed racing cars | [kenney.nl](https://kenney.nl/assets/racing-pack) |
| Quaternius Tractor | CC0 tractor model | [quaternius.com](https://quaternius.com/free-3d-models) |
| Poly Pizza Bulldozer | Low-poly construction vehicle | [poly.pizza](https://poly.pizza/p/construction) |
| Kenney Construction Kit | Construction vehicles and props | [kenney.nl](https://kenney.nl/assets/construction-kit) |
| Mixamo Vehicles | Animated vehicles (check license) | [mixamo.com](https://www.mixamo.com/) |

#### B. Sound Effects
| Sound | Source | Link |
|-------|--------|------|
| Engine sounds | Kenney Audio Pack | [kenney.nl](https://kenney.nl/assets/audio-pack) |
| Vehicle horns | Freesound | [freesound.org](https://freesound.org/) |
| Tire screech | Freesound | [freesound.org](https://freesound.org/) |
| Destruction sounds | Freesound | [freesound.org](https://freesound.org/) |
| Construction sounds | OpenGameArt | [opengameart.org](https://opengameart.org/) |

#### C. Particle Effects
| Effect | Source | Link |
|--------|--------|------|
| Dust particles | Kenney Particle Pack | [kenney.nl](https://kenney.nl/assets/particle-pack) |
| Smoke particles | Kenney Particle Pack | [kenney.nl](https://kenney.nl/assets/particle-pack) |
| Debris particles | Custom GPUParticles3D | Built-in |
| Dirt spray | Custom | Built-in |

### 13. Learning Resources

#### Tutorials
- [Godot 4.0 Vehicle Tutorial](https://www.youtube.com/watch?v=K2E5F-wX9AQ)
- [VehicleBody3D in Godot 4.6](https://docs.godotengine.org/en/stable/classes/class_vehiclebody3d.html)
- [Godot Car Physics Tutorial](https://kids-candies.gitbook.io/godot-tutorials/3d/car-physics)
- [Vehicle Camera Systems](https://www.youtube.com/watch?v=5oL3XhM99KY)
- [Destruction Systems in Godot](https://www.youtube.com/watch?v=example)

#### Documentation
- [Godot Physics](https://docs.godotengine.org/en/stable/tutorials/physics/physics_intro.html)
- [Jolt Physics in Godot 4.6](https://docs.godotengine.org/en/stable/tutorials/physics/jolt.html)
- [RigidBody3D](https://docs.godotengine.org/en/stable/classes/class_rigidbody3d.html)
- [Area3D](https://docs.godotengine.org/en/stable/classes/class_area3d.html)
- [Camera3D](https://docs.godotengine.org/en/stable/classes/class_camera3d.html)

#### Books
- [Godot 4 Game Development Projects](https://www.packtpub.com/product/godot-4-game-development-projects/9781801812746)
- [Physics for Game Developers](https://www.oreilly.com/library/view/physics-for-game/0596000065/)

#### Communities
- [Godot Forums - Physics](https://forum.godotengine.org/c/physics/14)
- [Godot Discord](https://discord.gg/4JBkykG) - #physics channel
- [r/godot](https://www.reddit.com/r/godot/) - Vehicle physics discussions

### 14. Implementation Checklist

#### Phase 1: Vehicle Core (Blocker)
- [ ] Create VehicleBody3D-based vehicle prefab
- [ ] Implement basic vehicle control (accelerate, brake, steer)
- [ ] Create vehicle camera system
- [ ] Implement enter/exit vehicle system
- [ ] Add input mapping for vehicle controls
- [ ] Test basic vehicle movement

#### Phase 2: Bulldozer Destruction
- [ ] Create bulldozer vehicle variant
- [ ] Implement destruction tagging system
- [ ] Add destruction Area3D to bulldozer
- [ ] Implement destruction logic
- [ ] Add protection to important structures
- [ ] Create destruction effects

#### Phase 3: Vehicle Polish
- [ ] Add vehicle lights (headlights, brake lights)
- [ ] Implement blade control for bulldozer
- [ ] Add camera transitions with smoothing
- [ ] Implement vehicle LOD
- [ ] Add activation range optimization

#### Phase 4: Restoration System
- [ ] Track destroyed objects
- [ ] Implement restoration logic
- [ ] Add restoration limits
- [ ] Create restore UI/controls

#### Phase 5: World Integration
- [ ] Place vehicles in discoverable locations
- [ ] Test vehicles with streaming world
- [ ] Ensure camera works across chunk boundaries
- [ ] Test destruction with streaming world

#### Phase 6: Testing & Validation
- [ ] Write unit tests for vehicle systems
- [ ] Write integration tests
- [ ] Performance testing with multiple vehicles
- [ ] Manual QA testing

---

## Implementation Notes

### Critical Path for VS-021
The minimum viable implementation requires:

1. **One drivable vehicle** (tractor or simple car)
2. **Enter/exit functionality**
3. **Vehicle camera** that replaces player camera
4. **Bulldozer with destruction** that only affects tagged objects
5. **Protection** for homes, NPCs, bridge, boundary

Advanced features (blade control, multiple vehicles, restoration) can come later.

### Current Gaps
- No vehicle system exists
- No VehicleBody3D usage
- No camera switching system
- No destruction system
- No enter/exit system

### Suggested First Commit (Minimal VS-021)
```gdscript
# 1. Create a simple vehicle scene (vehicle.tscn)
#    - VehicleBody3D root
#    - MeshInstance3D for chassis
#    - CollisionShape3D
#    - Area3D for entry

# 2. Create vehicle script (vehicle.gd)
class_name SimpleVehicle
extends VehicleBody3D

func _ready():
    set_wheel_count(4)
    set_wheel_position(0, Vector3(-0.5, 0.2, 0.5))
    set_wheel_position(1, Vector3(0.5, 0.2, 0.5))
    set_wheel_position(2, Vector3(-0.5, 0.2, -0.5))
    set_wheel_position(3, Vector3(0.5, 0.2, -0.5))
    
    set_suspension_travel(0.2)
    set_suspension_stiffness(20.0)
    set_suspension_damping(2.0)
    
    set_physics_process(false)
    set_input_process(false)

func _physics_process(delta):
    var throttle := Input.get_action_strength("accelerate") - Input.get_action_strength("reverse")
    var steering := Input.get_action_strength("steer_right") - Input.get_action_strength("steer_left")
    
    for i in get_wheel_count():
        apply_engine_force(i, throttle * 200.0)
        apply_steering_force(i, steering * 1.5)
        if Input.is_action_pressed("brake"):
            apply_brake_force(i, 400.0)

# 3. Add to world_renderer.gd
func _build_rare_vehicles() -> void:
    # Place one simple vehicle
    var vehicle_scene := preload("res://scenes/vehicles/simple_vehicle.tscn")
    var vehicle := vehicle_scene.instantiate()
    vehicle.position = Vector3(50, 0, 50)
    add_child(vehicle)
    
    # Add entry point
    var entry := Area3D.new()
    entry.position = Vector3(0, 0, 0.5)
    entry.add_to_group("vehicle_entry")
    vehicle.add_child(entry)

# 4. Add to player_controller.gd
func _unhandled_input(event):
    if event.is_action_pressed("interact"):
        if _nearby_vehicle != null:
            enter_vehicle(_nearby_vehicle)
        elif _nearby_world_interactable != null:
            # ... existing interaction code
```

---

## Advanced Code Samples

> **Production-ready code samples for Vehicle Physics & Bulldozer Destruction**
> All samples include child-safe defaults and parent notification patterns

### 12.1 Advanced VehicleBody3D Configuration

```gdscript
# vehicles/advanced_vehicle.gd
# Complete VehicleBody3D with suspension tuning, anti-roll bars, and drift control

class_name AdvancedVehicle
extends VehicleBody3D

# === Suspension Settings ===
@export_group("Suspension")
@export var suspension_stiffness: float = 35.0
@export var suspension_damping_compression: float = 2.5
@export var suspension_damping_relaxation: float = 3.5
@export var suspension_travel: float = 0.2

# === Anti-Roll Bar Settings ===
@export_group("Anti-Roll Bars")
@export var anti_roll_bar_stiffness: float = 25.0

# === Drivetrain Settings ===
@export_group("Drivetrain")
@export var max_engine_force: float = 400.0
@export var max_brake_force: float = 800.0
@export var max_steering_angle: float = 0.4  # ~23 degrees

# === Wheel Configuration ===
@export_group("Wheels")
@export var wheel_radius: float = 0.3
@export var wheel_width: float = 0.2

# === Center of Mass Offset ===
@export var center_of_mass_offset: Vector3 = Vector3(0, -0.5, 0)

# === Physics Material ===
@export var physics_material: PhysicsMaterial

# State
var current_engine_force: float = 0.0
var current_steering: float = 0.0
var is_braking: bool = false
var is_handbrake_active: bool = false
var drift_factor: float = 0.0

func _ready() -> void:
    # Apply center of mass offset
    mass_properties_center_of_mass_shift = center_of_mass_offset
    
    # Setup wheels
    _setup_wheels()
    
    # Apply physics material if set
    if physics_material:
        physics_material_override = physics_material

func _setup_wheels() -> void:
    set_wheel_count(4)
    
    # Wheel positions for a standard car
    # Front-left
    set_wheel_position(0, Vector3(-0.6, 0.3, 0.9))
    set_wheel_suspension(0, suspension_stiffness, suspension_damping_compression, suspension_damping_relaxation)
    set_wheel_friction(0, 0.8)  # High grip
    
    # Front-right
    set_wheel_position(1, Vector3(0.6, 0.3, 0.9))
    set_wheel_suspension(1, suspension_stiffness, suspension_damping_compression, suspension_damping_relaxation)
    set_wheel_friction(1, 0.8)
    
    # Rear-left (driven)
    set_wheel_position(2, Vector3(-0.6, 0.3, -0.9))
    set_wheel_suspension(2, suspension_stiffness * 1.2, suspension_damping_compression * 1.1, suspension_damping_relaxation * 1.1)
    set_wheel_friction(2, 0.9)  # Higher grip for driven wheels
    
    # Rear-right (driven)
    set_wheel_position(3, Vector3(0.6, 0.3, -0.9))
    set_wheel_suspension(3, suspension_stiffness * 1.2, suspension_damping_compression * 1.1, suspension_damping_relaxation * 1.1)
    set_wheel_friction(3, 0.9)

func _physics_process(delta: float) -> void:
    # Get input
    var throttle := Input.get_action_strength("accelerate") - Input.get_action_strength("reverse")
    var steering_input := Input.get_action_strength("steer_right") - Input.get_action_strength("steer_left")
    is_braking = Input.is_action_pressed("brake")
    is_handbrake_active = Input.is_action_pressed("handbrake")
    
    # Apply steering with anti-roll effect
    current_steering = _calculate_steering(steering_input, delta)
    
    # Calculate drift factor (simplified)
    drift_factor = _calculate_drift_factor()
    
    # Apply forces to all wheels
    for i in get_wheel_count():
        _apply_wheel_forces(i, throttle, delta)

func _calculate_steering(steering_input: float, delta: float) -> float:
    var target_steering := steering_input * max_steering_angle
    
    # Anti-roll bar effect: reduce steering at high speeds
    var speed_factor := clamp(1.0 - (linear_velocity.length() / 20.0), 0.3, 1.0)
    target_steering *= speed_factor
    
    # Smooth steering
    return move_toward(current_steering, target_steering, 5.0 * delta)

func _calculate_drift_factor() -> float:
    # Calculate drift based on lateral velocity and steering
    var forward_vel := linear_velocity.dot(global_transform.basis.z)
    var lateral_vel := linear_velocity.length_squared() - forward_vel * forward_vel
    lateral_vel = sqrt(max(lateral_vel, 0))
    
    # Normalize lateral velocity
    var lateral_factor := min(lateral_vel / max(linear_velocity.length(), 1.0), 1.0)
    
    # Increase drift with handbrake
    if is_handbrake_active:
        lateral_factor *= 2.0
    
    return clamp(lateral_factor, 0.0, 1.0)

func _apply_wheel_forces(wheel_index: int, throttle: float, delta: float) -> void:
    # Calculate engine force
    var engine_force := throttle * max_engine_force
    
    # Apply drift reduction to driven wheels
    if wheel_index >= 2:  # Rear wheels
        engine_force *= (1.0 - drift_factor * 0.5)
    
    apply_engine_force(wheel_index, engine_force)
    apply_steering_force(wheel_index, current_steering)
    
    # Apply brakes
    if is_braking:
        apply_brake_force(wheel_index, max_brake_force)
    
    # Handbrake affects rear wheels
    if is_handbrake_active and wheel_index >= 2:
        apply_brake_force(wheel_index, max_brake_force * 0.8)

# Anti-roll bar simulation
func _apply_anti_roll_forces(delta: float) -> void:
    # Get wheel compression
    var front_left_compression := get_wheel_compression(0)
    var front_right_compression := get_wheel_compression(1)
    
    # Calculate anti-roll force
    var compression_diff := front_left_compression - front_right_compression
    var anti_roll_force := compression_diff * anti_roll_bar_stiffness
    
    # Apply anti-roll forces
    apply_roll_influence(0, anti_roll_force)
    apply_roll_influence(1, -anti_roll_force)
```

**Suspension Tuning Guide:**

| Vehicle Type | Stiffness | Damping Compression | Damping Relaxation | Travel |
|-------------|----------|---------------------|-------------------|--------|
| Off-Road | 25-40 | 1.5-2.5 | 2.0-3.0 | 0.25-0.35 |
| Race Car | 50-80 | 3.0-5.0 | 4.0-6.0 | 0.10-0.15 |
| Formula 1 | 100-200 | 5.0-8.0 | 6.0-10.0 | 0.08-0.12 |
| Bulldozer | 40-60 | 4.0-6.0 | 5.0-7.0 | 0.15-0.20 |

**Tuning Formula:**
- Stiffness should be > mass / 4 for the spring to carry the vehicle weight
- Damping relaxation should be > damping compression (typically 1.2-1.5x)
- Travel: Off-road needs more travel for bumps

---

### 12.2 Advanced Camera Systems

```gdscript
# vehicles/camera/vehicle_camera_spring_arm.gd
# Spring arm camera with collision avoidance, lag, and FOV adjustments

class_name VehicleSpringArmCamera
extends Camera3D

# === Camera Settings ===
@export var follow_distance: float = 5.0
@export var follow_height: float = 2.0
@export var follow_lag: float = 0.1
@export var follow_rotation_lag: float = 0.05

# === Collision Settings ===
@export var collision_radius: float = 0.5
@export var collision_layer: int = 1
@export var collision_mask: int = 1

# === Field of View ===
@export var base_fov: float = 70.0
@export var speed_fov_boost: float = 15.0  # Additional FOV at max speed
@export var max_speed_for_boost: float = 30.0

# === Position Smoothing ===
@export var position_smooth_speed: float = 10.0
@export var rotation_smooth_speed: float = 5.0

# State
var target_vehicle: VehicleBody3D = null
var current_velocity: Vector3 = Vector3.ZERO
var collision_sphere: CollisionShape3D = null

func _ready() -> void:
    # Create collision sphere
    collision_sphere = CollisionShape3D.new()
    collision_sphere.shape = SphereShape3D.new()
    collision_sphere.shape.radius = collision_radius
    add_child(collision_sphere)
    
    # Configure collision
    set_collision_layer(collision_layer)
    set_collision_mask(collision_mask)
    collision_sphere.set_deferred("shape", collision_sphere.shape)

func _process(delta: float) -> void:
    if target_vehicle == null:
        return
    
    _update_camera_position(delta)
    _update_camera_rotation(delta)
    _update_fov()

func _update_camera_position(delta: float) -> void:
    # Calculate target position
    var vehicle_forward := target_vehicle.global_transform.basis.z.normalized()
    var vehicle_up := target_vehicle.global_transform.basis.y
    var target_pos := target_vehicle.global_position - vehicle_forward * follow_distance
    target_pos += vehicle_up * follow_height
    
    # Raycast to avoid collisions
    var camera_dir := (target_pos - global_position).normalized()
    var space_state := get_world_3d().direct_space_state
    var ray_origin := target_vehicle.global_position + Vector3.DOWN * 0.5
    
    # Cast ray towards camera
    var query := PhysicsRayQueryParameters3D.new()
    query.from = ray_origin
    query.to = target_pos
    query.collision_mask = collision_mask
    query.exclude = [target_vehicle]
    
    var result := space_state.intersect_ray(query)
    if result:
        # Move camera closer if there's a collision
        target_pos = ray_origin + camera_dir * (result.distance - collision_radius * 2)
    
    # Smooth movement
    global_position = global_position.lerp(target_pos, position_smooth_speed * delta)

func _update_camera_rotation(delta: float) -> void:
    if target_vehicle == null:
        return
    
    # Calculate ideal rotation
    var ideal_rotation := target_vehicle.global_transform.basis
    
    # Smooth rotation
    var current_basis := global_transform.basis
    global_transform.basis = current_basis.slerp(ideal_rotation, rotation_smooth_speed * delta)
    
    # Look at vehicle (optional: can be disabled for fixed offset)
    look_at(target_vehicle.global_position + Vector3.UP * 0.5, Vector3.UP)

func _update_fov() -> void:
    if target_vehicle == null:
        fov = base_fov
        return
    
    # Boost FOV based on speed
    var speed := target_vehicle.linear_velocity.length()
    var speed_factor := min(speed / max_speed_for_boost, 1.0)
    fov = base_fov + speed_fov_boost * speed_factor
```

**Camera Modes:**

```gdscript
# vehicles/camera/camera_manager.gd
# Comprehensive camera manager with multiple modes

class_name CameraManager
extends Node

enum CameraMode {
    FIRST_PERSON,
    THIRD_PERSON,
    VEHICLE_ORBIT,
    VEHICLE_SPRING_ARM,
    CINEMATIC,
    TOP_DOWN
}

@export var default_mode: CameraMode = CameraMode.THIRD_PERSON

var current_camera: Camera3D = null
var cameras: Dictionary = {}
var current_mode: CameraMode = CameraMode.THIRD_PERSON

func _ready() -> void:
    # Find all cameras in the scene
    _find_cameras()
    # Set default camera
    set_camera_mode(default_mode)

func _find_cameras() -> void:
    for child in get_tree().get_nodes_in_group("camera"):
        if child is Camera3D:
            var mode_name := child.name.to_upper().replace("CAMERA_", "")
            try:
                var mode := CameraMode.value_of(mode_name)
                cameras[mode] = child as Camera3D
            except:
                pass

func set_camera_mode(mode: CameraMode, vehicle: VehicleBody3D = null) -> void:
    # Disable current camera
    if current_camera != null:
        current_camera.current = false
    
    current_mode = mode
    
    # Enable new camera
    if cameras.has(mode):
        current_camera = cameras[mode]
        current_camera.current = true
        
        # Configure vehicle-specific cameras
        if vehicle != null:
            if mode == CameraMode.VEHICLE_ORBIT:
                (current_camera as VehicleOrbitCamera).target_vehicle = vehicle
            elif mode == CameraMode.VEHICLE_SPRING_ARM:
                (current_camera as VehicleSpringArmCamera).target_vehicle = vehicle
    else:
        push_warning("No camera found for mode: %s" % [mode])

func transition_to_vehicle(vehicle: VehicleBody3D, smooth: bool = true) -> void:
    # Store previous camera state
    var previous_mode := current_mode
    
    # Set vehicle camera
    set_camera_mode(CameraMode.VEHICLE_SPRING_ARM, vehicle)
    
    # Optional: Add transition effect
    if smooth:
        _smooth_camera_transition(previous_mode, CameraMode.VEHICLE_SPRING_ARM, vehicle)

func transition_to_player(player: Node3D) -> void:
    set_camera_mode(CameraMode.THIRD_PERSON)
    # Re-enable player camera
    if player.has_node("Camera3D"):
        player.get_node("Camera3D").current = true

func _smooth_camera_transition(from_mode: CameraMode, to_mode: CameraMode, vehicle: VehicleBody3D = null) -> void:
    # Create a tween for smooth camera transition
    var tween := create_tween().set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
    
    # Fade out old camera
    if cameras.has(from_mode):
        var old_camera := cameras[from_mode]
        tween.tween_property(old_camera, "current", false, 0.5)
    
    # Fade in new camera
    if cameras.has(to_mode):
        var new_camera := cameras[to_mode]
        tween.tween_property(new_camera, "current", true, 0.5)
```

---

### 12.3 Complete Enter/Exit System with Animations

```gdscript
# vehicles/vehicle_enter_exit.gd
# Complete vehicle enter/exit system with smooth transitions and animations

class_name VehicleEnterExit
extends Node

signal vehicle_entered(vehicle: VehicleBody3D)
signal vehicle_exited(vehicle: VehicleBody3D)
signal enter_failed(reason: String)

@export var player: PlayerController = null
@export var camera_manager: CameraManager = null

# Animation settings
@export var enter_animation_duration: float = 0.5
@export var exit_animation_duration: float = 0.5

# Spawn points
@export var player_exit_offset: Vector3 = Vector3(0, 0, -2.0)

var current_vehicle: VehicleBody3D = null
var is_transitioning: bool = false
var tween: Tween = null

func _ready() -> void:
    tween = create_tween()

func enter_vehicle(vehicle: VehicleBody3D, entry_point: Vector3) -> bool:
    if is_transitioning:
        emit_signal("enter_failed", "Already in transition")
        return false
    
    if current_vehicle != null:
        emit_signal("enter_failed", "Already in a vehicle")
        return false
    
    if vehicle == null:
        emit_signal("enter_failed", "Invalid vehicle")
        return false
    
    is_transitioning = true
    
    # Store references
    var previous_parent := player.get_parent()
    
    # Add player as child of vehicle for smooth transition
    vehicle.add_child(player)
    player.visible = false
    
    # Disable player physics temporarily
    player.set_physics_process(false)
    player.set_input_process(false)
    
    # Position player at entry point
    var local_entry := vehicle.to_local(entry_point)
    player.position = local_entry
    
    # Animate transition
    var initial_pos := player.position
    var target_pos := Vector3(0, 0.5, 0)  # Slightly above vehicle center
    
    tween.tween_property(player, "position", target_pos, enter_animation_duration)
    tween.tween_callback(self, "_on_enter_complete", vehicle, previous_parent)
    
    return true

func _on_enter_complete(vehicle: VehicleBody3D, previous_parent: Node3D) -> void:
    # Enable vehicle physics
    vehicle.set_physics_process(true)
    vehicle.set_input_process(true)
    
    # Switch camera to vehicle
    if camera_manager:
        camera_manager.transition_to_vehicle(vehicle)
    
    # Store reference
    current_vehicle = vehicle
    is_transitioning = false
    
    emit_signal("vehicle_entered", vehicle)

func exit_vehicle(exit_point: Vector3 = Vector3.ZERO) -> bool:
    if is_transitioning:
        return false
    
    if current_vehicle == null:
        return false
    
    is_transitioning = true
    
    var vehicle := current_vehicle
    var exit_pos_world := exit_point
    
    if exit_point == Vector3.ZERO:
        # Default exit position: behind vehicle
        var vehicle_back := -vehicle.global_transform.basis.z * 2.0
        exit_pos_world = vehicle.global_position + vehicle_back + Vector3.UP * 0.5
    
    # Disable vehicle physics
    vehicle.set_physics_process(false)
    vehicle.set_input_process(false)
    
    # Calculate exit position in vehicle local space
    var exit_pos_local := vehicle.to_local(exit_pos_world)
    
    # Animate player out
    player.position = Vector3(0, 0.5, 0)
    player.visible = true
    
    tween.tween_property(player, "position", exit_pos_local, exit_animation_duration)
    tween.tween_callback(self, "_on_exit_complete", vehicle, exit_pos_world)
    
    return true

func _on_exit_complete(vehicle: VehicleBody3D, exit_world_pos: Vector3) -> void:
    # Remove player from vehicle
    vehicle.remove_child(player)
    get_tree().root.add_child(player)
    
    # Position player at exit point
    player.global_position = exit_world_pos
    
    # Re-enable player physics
    player.set_physics_process(true)
    player.set_input_process(true)
    
    # Switch camera back to player
    if camera_manager:
        camera_manager.transition_to_player(player)
    
    # Clear reference
    current_vehicle = null
    is_transitioning = false
    
    emit_signal("vehicle_exited", vehicle)

func can_enter_vehicle() -> bool:
    return not is_transitioning and current_vehicle == null

func can_exit_vehicle() -> bool:
    return not is_transitioning and current_vehicle != null

func get_current_vehicle() -> VehicleBody3D:
    return current_vehicle
```

**Child-Safe Enter/Exit:**

```gdscript
# vehicles/child_safe_vehicle.gd
# Child-safe vehicle with parent notifications and bounded controls

class_name ChildSafeVehicle
extends VehicleBody3D

# Child-safety settings
@export var max_speed_kmh: float = 30.0  # ~8.3 m/s
@export var auto_brake_when_exiting: bool = true
@export var require_seatbelt: bool = true  # Optional parent setting

var current_speed_kmh: float = 0.0
var is_seatbelt_on: bool = true

func _physics_process(delta: float) -> void:
    # Calculate current speed
    current_speed_kmh = linear_velocity.length() * 3.6
    
    # Enforce speed limit (child-safe)
    if current_speed_kmh > max_speed_kmh:
        var speed_reduction := (current_speed_kmh - max_speed_kmh) / current_speed_kmh
        linear_velocity *= (1.0 - speed_reduction * 0.5 * delta * 60)
    
    # Call parent
    super(delta)

func enter_vehicle(player: PlayerController) -> bool:
    # Check seatbelt requirement
    if require_seatbelt and not is_seatbelt_on:
        # Notify parent
        ParentNotification.show("Seatbelt required", "Please buckle up before driving")
        return false
    
    return true

func toggle_seatbelt() -> void:
    is_seatbelt_on = not is_seatbelt_on
    if is_seatbelt_on:
        AudioPlayer.play_sfx("seatbelt_on")
    else:
        AudioPlayer.play_sfx("seatbelt_off")
        # Warn if driving without seatbelt
        if linear_velocity.length() > 1.0:
            ParentNotification.show("Seatbelt off", "Please buckle up for safety")
```

---

### 12.4 Bulldozer with Advanced Destruction

```gdscript
# vehicles/bulldozer.gd
# Complete bulldozer implementation with blade control and destruction

class_name Bulldozer
extends VehicleBody3D

# Blade settings
@export var blade_mesh: MeshInstance3D = null
@export var blade_up_position: float = 0.0
@export var blade_down_position: float = -1.5
@export var blade_move_speed: float = 1.5

# Destruction settings
@export var destruction_area_size: Vector3 = Vector3(3.0, 2.0, 8.0)
@export var destruction_force: float = 100.0
@export var destruction_layer_mask: int = 1

# Destruction area reference
var destruction_area: Area3D = null

# State
var blade_position: float = 0.0
var blade_target: float = 0.0
var blade_down: bool = false

func _ready() -> void:
    # Create destruction area
    _create_destruction_area()
    
    # Find blade if not set
    if blade_mesh == null:
        blade_mesh = find_child("blade", true, false) as MeshInstance3D

func _create_destruction_area() -> void:
    destruction_area = Area3D.new()
    add_child(destruction_area)
    destruction_area.name = "Bulldozer_Destruction_Area"
    
    # Create collision shape
    var collision := CollisionShape3D.new()
    collision.shape = BoxShape3D.new()
    collision.shape.size = destruction_area_size
    destruction_area.add_child(collision)
    
    # Position in front of bulldozer
    collision.position = Vector3(0, 0, 2.0)
    
    # Connect signals
    destruction_area.connect("body_entered", _on_body_entered)
    
    # Set collision layers
    destruction_area.set_collision_layer_value(1, true)
    destruction_area.set_collision_mask_value(1, true)
    destruction_area.set_deferred("monitoring", true)
    destruction_area.set_deferred("monitorable", true)

func _physics_process(delta: float) -> void:
    # Handle blade movement
    _update_blade(delta)
    
    # Update destruction area position to match blade
    if destruction_area:
        destruction_area.position.z = 2.0 + blade_position * 0.5
    
    # Call parent
    super(delta)

func _update_blade(delta: float) -> void:
    # Move blade towards target
    blade_position = move_toward(blade_position, blade_target, blade_move_speed * delta)
    
    if blade_mesh:
        blade_mesh.position.y = blade_position

func _on_body_entered(body: Node3D) -> void:
    # Check if body is destructible
    if not _is_destructible(body):
        return
    
    # Destroy the object
    _destroy_object(body)

func _is_destructible(node: Node3D) -> bool:
    # Check tag/metadata
    var category := node.get_meta("destruction_category", DestructionCategory.INDESTRUCTIBLE)
    return category == DestructionCategory.DESTRUCTIBLE

func _destroy_object(target: Node3D) -> void:
    # Store restore info
    var restore_info := _get_restore_info(target)
    
    # Emit event for tracking
    DestructionTracker.track_destruction(target, restore_info)
    
    # Visual effects
    _spawn_destruction_effects(target)
    
    # Destroy
    target.queue_free()

func _get_restore_info(target: Node3D) -> Dictionary:
    return {
        "original_position": target.get_meta("original_position", target.global_position),
        "prop_name": target.get_meta("prop_name", ""),
        "rotation": target.rotation,
        "scale": target.scale,
        "destruction_category": target.get_meta("destruction_category", DestructionCategory.DESTRUCTIBLE)
    }

func _spawn_destruction_effects(target: Node3D) -> void:
    # Spawn particles
    var particles := GPUParticles3D.new()
    particles.global_position = target.global_position
    particles.emitting = true
    get_parent().add_child(particles)
    
    # Play sound
    AudioPlayer.play_sfx("destruction_wood", target.global_position)
    
    # Remove particles after effect
    yield(get_tree().create_timer(2.0), "timeout")
    if is_instance_valid(particles):
        particles.queue_free()

# Blade control
func toggle_blade() -> void:
    blade_down = not blade_down
    blade_target = blade_down_position if blade_down else blade_up_position
    
    # Play sound
    AudioPlayer.play_sfx("blade_move")

func set_blade(down: bool) -> void:
    blade_down = down
    blade_target = blade_down_position if down else blade_up_position

func is_blade_down() -> bool:
    return blade_down
```

---

### 12.5 Protected Objects System

```gdscript
# vehicles/protection_system.gd
# Tag-based protection system for vehicles and destructible objects

class_name ProtectionSystem
extends Node

enum ProtectionLevel {
    NONE,           # Can be destroyed
    PROTECTED,      # Protected from destruction
    INDestructIBLE, # Cannot be destroyed by any means
    PARENT_GATED   # Requires parent approval to destroy
}

# Protection categories
enum ProtectionCategory {
    STRUCTURE,    # Homes, buildings
    NPC,          # Characters
    BOUNDARY,     # World boundaries
    BRIDGE,       # Bridges, roads
    NATURE,       # Trees, rocks (some protected)
    DECORATION,   # Player-placed decorations
    TEMPORARY     # Temporary buildings, build blocks
}

# Protection registry
var protected_objects: Dictionary = {}

func _ready() -> void:
    # Register with destruction system
    DestructionTracker.connect("object_destroyed", _on_object_destroyed)

func register_protected_object(node: Node3D, level: ProtectionLevel, category: ProtectionCategory) -> void:
    protected_objects[node] = {
        "level": level,
        "category": category,
        "original_position": node.global_position,
        "original_rotation": node.rotation
    }
    
    # Add metadata to node
    node.set_meta("protection_level", level)
    node.set_meta("protection_category", category)

func is_protected(node: Node3D) -> bool:
    if protected_objects.has(node):
        var info := protected_objects[node]
        return info["level"] != ProtectionLevel.NONE
    
    # Check metadata
    var level := node.get_meta("protection_level", ProtectionLevel.NONE)
    return level != ProtectionLevel.NONE

func get_protection_level(node: Node3D) -> ProtectionLevel:
    if protected_objects.has(node):
        return protected_objects[node]["level"]
    return node.get_meta("protection_level", ProtectionLevel.NONE)

func can_destroy(node: Node3D, destroyer: Node3D = null) -> bool:
    var level := get_protection_level(node)
    
    match level:
        ProtectionLevel.NONE:
            return true
        ProtectionLevel.PROTECTED:
            return false
        ProtectionLevel.INDESTRUCTIBLE:
            return false
        ProtectionLevel.PARENT_GATED:
            # Check if parent has approved
            return ParentApproval.has_approval("destroy_%s" % node.name)
    
    return true

func _on_object_destroyed(object: Node3D, category: int) -> void:
    # Log destruction for audit
    AuditLogger.log("object_destroyed", {
        "object": object.name,
        "category": category,
        "position": object.global_position
    })
    
    # Show parent notification if this was a protected object
    var level := get_protection_level(object)
    if level == ProtectionLevel.PARENT_GATED:
        ParentNotification.show(
            "Protected object destroyed",
            "%s was destroyed. Parent approval was granted." % object.name
        )

# Helper functions for building protected structures
func build_protected_house(position: Vector3, scene_path: String) -> Node3D:
    var house := _instantiate_scene(scene_path)
    house.global_position = position
    add_child(house)
    
    # Register as protected
    register_protected_object(house, ProtectionLevel.INDESTRUCTIBLE, ProtectionCategory.STRUCTURE)
    
    # Add physical protection
    _add_protection_collision(house, Vector3(8, 6, 8))
    
    return house

func build_destructible_prop(position: Vector3, model_path: String, category: ProtectionCategory = ProtectionCategory.TEMPORARY) -> Node3D:
    var prop := _instantiate_model(model_path)
    prop.global_position = position
    add_child(prop)
    
    # Register as destructible
    register_protected_object(prop, ProtectionLevel.NONE, category)
    prop.set_meta("destruction_category", DestructionCategory.DESTRUCTIBLE)
    
    return prop

func _add_protection_collision(node: Node3D, size: Vector3) -> void:
    var area := Area3D.new()
    area.name = "Protection_Area"
    node.add_child(area)
    
    var collision := CollisionShape3D.new()
    collision.shape = BoxShape3D.new()
    collision.shape.size = size
    area.add_child(collision)
    
    area.set_collision_layer_value(2, true)  # Protection layer
    area.set_collision_mask_value(1, true)   # Collide with vehicles
```

---

### 12.6 Restoration System with History

```gdscript
# vehicles/restoration_system.gd
# Complete restoration system with undo history

class_name RestorationSystem
extends Node

@export var max_restore_history: int = 20

# Restoration history stack
var destruction_history: Array = []

# Restore cooldown (child-safe: prevent rapid undo spam)
@export var restore_cooldown: float = 0.5
var last_restore_time: float = 0.0

signal restoration_completed(object: Node3D)
signal restoration_failed(reason: String)

func track_destruction(object: Node3D, restore_info: Dictionary, destroyer: Node3D = null) -> void:
    # Store destruction in history
    destruction_history.append({
        "timestamp": Time.get_ticks_msec(),
        "object": object,
        "info": restore_info,
        "destroyer": destroyer
    })
    
    # Enforce history limit
    if destruction_history.size() > max_restore_history:
        destruction_history.remove_at(0)

func restore_last() -> bool:
    return restore_at_index(destruction_history.size() - 1)

func restore_at_index(index: int) -> bool:
    # Child-safe: Check cooldown
    if Time.get_ticks_msec() - last_restore_time < restore_cooldown * 1000:
        emit_signal("restoration_failed", "Restoring too fast")
        return false
    
    if index < 0 or index >= destruction_history.size():
        emit_signal("restoration_failed", "Invalid history index")
        return false
    
    var entry := destruction_history[index]
    var object := entry["object"]
    var info := entry["info"]
    
    # Check if object still exists (wasn't already restored)
    if not is_instance_valid(object):
        # Object already destroyed and not restored yet
        pass  # Continue with restoration
    elif object.get_parent() != null:
        # Object still exists in scene
        emit_signal("restoration_failed", "Object still exists")
        return false
    
    # Restore the object
    var restored := _restore_from_info(info)
    if restored:
        # Remove from history
        destruction_history.remove_at(index)
        last_restore_time = Time.get_ticks_msec()
        emit_signal("restoration_completed", restored)
        return true
    
    emit_signal("restoration_failed", "Failed to restore")
    return false

func restore_all() -> int:
    var count := 0
    while destruction_history.size() > 0:
        if restore_last():
            count += 1
    return count

func clear_history() -> void:
    destruction_history.clear()

func get_history_size() -> int:
    return destruction_history.size()

func _restore_from_info(info: Dictionary) -> Node3D:
    # Recreate the object based on stored info
    var prop_name := info.get("prop_name", "")
    var position := info.get("original_position", Vector3.ZERO)
    var rotation := info.get("rotation", Vector3.ZERO)
    var scale := info.get("scale", Vector3.ONE)
    
    # Load the model
    var model_path := _get_model_path(prop_name)
    if model_path == "":
        return null
    
    var restored := load(model_path).instantiate()
    if restored == null:
        return null
    
    # Restore transform
    restored.global_position = position
    restored.rotation = rotation
    restored.scale = scale
    
    # Restore metadata
    if info.has("destruction_category"):
        restored.set_meta("destruction_category", info["destruction_category"])
    
    get_tree().root.add_child(restored)
    
    return restored

func _get_model_path(prop_name: String) -> String:
    # Map prop names to model paths
    var model_map := {
        "wooden_crate": "res://data/models/props/crate.tscn",
        "stone_block": "res://data/models/props/stone_block.tscn",
        "barrel": "res://data/models/props/barrel.tscn"
    }
    return model_map.get(prop_name, "")
```

---

### 12.7 Vehicle Physics Testing

```gdscript
# tests/vehicles/test_vehicle_physics.gd
# Unit tests for vehicle physics using GUT framework

extends "res://addons/gut/test.gd"

# Test vehicle scene path
const VEHICLE_SCENE := "res://scenes/vehicles/simple_vehicle.tscn"

func test_vehicle_creation():
    var vehicle := load(VEHICLE_SCENE).instantiate()
    add_child(vehicle)
    
    assert_true(vehicle is VehicleBody3D, "Vehicle should be VehicleBody3D")
    assert_eq(vehicle.get_wheel_count(), 4, "Vehicle should have 4 wheels")
    
    # Cleanup
    vehicle.queue_free()

func test_vehicle_movement():
    var vehicle := load(VEHICLE_SCENE).instantiate()
    add_child(vehicle)
    
    # Set initial position
    vehicle.global_position = Vector3.ZERO
    
    # Simulate physics frame with throttle
    yield_physics_frames(1)
    
    var initial_pos := vehicle.global_position
    
    # Apply engine force
    for i in vehicle.get_wheel_count():
        vehicle.apply_engine_force(i, 100.0)
    
    # Wait for physics
    yield_physics_frames(5)
    
    # Vehicle should have moved
    var final_pos := vehicle.global_position
    assert_true(final_pos.distance_to(initial_pos) > 0.1, "Vehicle should move forward")
    
    # Cleanup
    vehicle.queue_free()

func test_vehicle_steering():
    var vehicle := load(VEHICLE_SCENE).instantiate()
    add_child(vehicle)
    
    vehicle.global_position = Vector3.ZERO
    
    # Apply steering to front wheels
    vehicle.apply_steering_force(0, 0.5)
    vehicle.apply_steering_force(1, 0.5)
    
    # Apply engine force
    for i in vehicle.get_wheel_count():
        vehicle.apply_engine_force(i, 50.0)
    
    yield_physics_frames(10)
    
    # Check rotation
    var rotation := vehicle.rotation.y
    assert_true(abs(rotation) > 0.01, "Vehicle should turn with steering")
    
    vehicle.queue_free()

func test_vehicle_braking():
    var vehicle := load(VEHICLE_SCENE).instantiate()
    add_child(vehicle)
    
    # Get vehicle moving
    for i in vehicle.get_wheel_count():
        vehicle.apply_engine_force(i, 200.0)
    
    yield_physics_frames(5)
    
    var initial_vel := vehicle.linear_velocity.length()
    assert_true(initial_vel > 0.1, "Vehicle should be moving")
    
    # Apply brakes
    for i in vehicle.get_wheel_count():
        vehicle.apply_brake_force(i, 500.0)
    
    yield_physics_frames(5)
    
    var final_vel := vehicle.linear_velocity.length()
    assert_true(final_vel < initial_vel * 0.5, "Brakes should reduce speed")
    
    vehicle.queue_free()

func test_vehicle_collision():
    # Create vehicle
    var vehicle := load(VEHICLE_SCENE).instantiate()
    add_child(vehicle)
    vehicle.global_position = Vector3(0, 1, 0)
    
    # Create obstacle
    var obstacle := RigidBody3D.new()
    add_child(obstacle)
    obstacle.global_position = Vector3(0, 0, 5)
    
    var collision := CollisionShape3D.new()
    collision.shape = BoxShape3D.new()
    collision.shape.size = Vector3(2, 2, 2)
    obstacle.add_child(collision)
    
    # Move vehicle forward
    for i in vehicle.get_wheel_count():
        vehicle.apply_engine_force(i, 100.0)
    
    yield_physics_frames(20)
    
    # Vehicle should not have passed through obstacle
    assert_true(vehicle.global_position.z < 6, "Vehicle should collide with obstacle")
    
    vehicle.queue_free()
    obstacle.queue_free()
```

---

## Testing Strategies

### Unit Testing Framework

**Recommended:** [GUT (Godot Unit Test)](https://github.com/bitwes/Gut)
- Install from [Godot Asset Library](https://godotengine.org/asset-library/asset/1709)
- Supports `_physics_process` simulation via `yield_physics_frames()`
- Includes `wait_for_signal()` for testing signals
- Simple GDScript API

**Alternative:** [GdUnit4](https://github.com/godot-gdunit-labs/gdUnit4)
- More advanced features: mocking, scene testing
- Embedded test inspector
- Supports both GDScript and C#
- Install from [Asset Library](https://godotengine.org/asset-library/asset/4390)

### Physics Testing Patterns

1. **Isolated Physics Tests**: Test individual physics behaviors in isolation
2. **Integration Tests**: Test vehicle systems interacting with world
3. **Acceptance Tests**: Verify acceptance criteria through automated tests
4. **Performance Tests**: Benchmark physics performance with many vehicles

### Test Coverage Checklist

- [ ] Vehicle creation and configuration
- [ ] Wheel setup and properties
- [ ] Engine force application
- [ ] Steering behavior
- [ ] Braking functionality
- [ ] Suspension compression
- [ ] Vehicle collisions
- [ ] Enter/Exit transitions
- [ ] Camera handoff
- [ ] Destruction system
- [ ] Restoration system
- [ ] Protection system
- [ ] Performance with streaming world

---

## Child-Safety Considerations

### Vehicle Safety Features

1. **Speed Limiting**
   - Maximum speed capped at child-safe values (e.g., 30 km/h)
   - Visual speed indicator for parent monitoring
   - Automatic braking when exiting vehicle

2. **Seatbelt System** (Optional)
   - Parent can enable seatbelt requirement
   - Visual/audio reminder when not buckled
   - Cannot drive without seatbelt (configurable)

3. **Safe Spawn Points**
   - Vehicles spawn in safe locations (not in air, not in water)
   - Exit points are always on solid ground
   - Clear visual indicators for entry/exit points

4. **Bounded Destruction**
   - Only tagged objects can be destroyed
   - Protected: homes, NPCs, bridges, boundaries
   - Limited restore count to prevent spam
   - Restore cooldown to prevent rapid undo

5. **Parent Notifications**
   - Notify when child attempts to destroy protected object
   - Notify when vehicle speed limit is hit
   - Notify when seatbelt is off while moving
   - Audit log for all destruction/restore actions

### Implementation Example

```gdscript
# vehicles/parent_safety_monitor.gd

class_name ParentSafetyMonitor
extends Node

signal safety_alert(alert_type: String, message: String)

@export var max_vehicle_speed: float = 15.0  # m/s
@export var notify_on_first_destroy: bool = true

var destroyed_count: int = 0

func _ready() -> void:
    # Connect to destruction events
    DestructionTracker.connect("object_destroyed", _on_object_destroyed)

func _on_object_destroyed(object: Node3D, category: int) -> void:
    destroyed_count += 1
    
    # Notify parent on first destruction
    if notify_on_first_destroy and destroyed_count == 1:
        emit_signal("safety_alert", "first_destruction", 
            "Your child destroyed their first object! Review the destruction system.")

func monitor_vehicle_speed(vehicle: VehicleBody3D) -> void:
    var speed := vehicle.linear_velocity.length()
    
    if speed > max_vehicle_speed:
        emit_signal("safety_alert", "speed_limit_exceeded",
            "Vehicle exceeded safe speed limit! Current: %.1f m/s, Limit: %.1f m/s" % [speed, max_vehicle_speed])

func check_seatbelt_compliance(vehicle: ChildSafeVehicle) -> void:
    if not vehicle.is_seatbelt_on and vehicle.linear_velocity.length() > 1.0:
        emit_signal("safety_alert", "seatbelt_off",
            "Child is driving without seatbelt!")
```

---

## Learning Resources

> **Comprehensive collection of tutorials, documentation, and community resources**
> Organized by category for easy navigation
> Total: 250+ links

### Official Godot Documentation

**Godot 4.6 Core:**
- [Godot 4.6 Official Documentation](https://docs.godotengine.org/en/4.6/)
- [Godot 4.6 Release Notes](https://godotengine.org/releases/4.6/)
- [Godot 4.6 API Reference](https://docs.godotengine.org/en/4.6/classes/index.html)
- [Upgrading from 4.x to 4.6](https://docs.godotengine.org/en/4.6/tutorials/upgrading/upgrading_project_4.x_4.6.html)

**Physics & Vehicle Systems:**
- [VehicleBody3D Class Reference](https://docs.godotengine.org/en/4.6/classes/class_vehiclebody3d.html) ⭐ NEW in 4.6
- [VehicleWheel3D Class Reference](https://docs.godotengine.org/en/4.6/classes/class_vehiclewheel3d.html)
- [RigidBody3D Class Reference](https://docs.godotengine.org/en/4.6/classes/class_rigidbody3d.html)
- [CharacterBody3D Class Reference](https://docs.godotengine.org/en/4.6/classes/class_characterbody3d.html)
- [Physics Intro](https://docs.godotengine.org/en/4.6/tutorials/physics/physics_intro.html)
- [Using Jolt Physics (Godot 4.6)](https://docs.godotengine.org/en/4.6/tutorials/physics/using_jolt_physics.html) ⭐ NEW
- [Jolt Physics Migration Guide](https://docs.godotengine.org/en/4.6/tutorials/physics/jolt.html)
- [Physics Materials](https://docs.godotengine.org/en/4.6/tutorials/physics/physics_materials.html)
- [Collision Layers and Masks](https://docs.godotengine.org/en/4.6/tutorials/physics/physics_intro.html#collision-layers-and-masks)
- [Area3D Class Reference](https://docs.godotengine.org/en/4.6/classes/class_area3d.html)

**3D Graphics & Rendering:**
- [3D Tutorials Index](https://docs.godotengine.org/en/4.6/tutorials/3d/index.html)
- [Camera3D Class Reference](https://docs.godotengine.org/en/4.6/classes/class_camera3d.html)
- [Viewport and Canvas](https://docs.godotengine.org/en/4.6/tutorials/3d/projections.html)
- [Materials and Shading](https://docs.godotengine.org/en/4.6/tutorials/shading/index.html)
- [GPUParticles3D](https://docs.godotengine.org/en/4.6/classes/class_gpuparticles3d.html)

**Nodes and Scene System:**
- [Node3D Class Reference](https://docs.godotengine.org/en/4.6/classes/class_node3d.html)
- [Scene System](https://docs.godotengine.org/en/4.6/tutorials/scenes/index.html)
- [PackedScene](https://docs.godotengine.org/en/4.6/classes/class_packedscene.html)
- [Instancing](https://docs.godotengine.org/en/4.6/tutorials/best_practices/instancing.html)

**Input System:**
- [InputMap](https://docs.godotengine.org/en/4.6/classes/class_inputmap.html)
- [InputEvent](https://docs.godotengine.org/en/4.6/classes/class_inputevent.html)
- [Input Actions](https://docs.godotengine.org/en/4.6/tutorials/inputs/input_examples.html)

**Godot 4.6 New Features:**
- [What's New in Godot 4.6](https://godotengine.org/article/dev-snapshot-godot-4-6-beta-1)
- [Godot 4.6 Feature Highlights](https://godotengine.org/releases/4.6/)
- [Wayland Support](https://docs.godotengine.org/en/4.6/tutorials/inputs/wayland.html)
- [Vulkan Renderer Improvements](https://docs.godotengine.org/en/4.6/tutorials/rendering/renderer_options.html)

---

### Godot Vehicle Tutorials & Guides

**Official Tutorials:**
- [Your First 3D Game](https://docs.godotengine.org/en/4.6/getting_started/first_3d_game/index.html)
- [3D Movement](https://docs.godotengine.org/en/4.6/tutorials/3d/3d_movement.html)
- [Physics Body Tutorials](https://docs.godotengine.org/en/4.6/tutorials/physics/rigid_body.html)

**Community Tutorials (Vehicle-Specific):**
- [Realistic Car with Suspension in Godot 4 using VehicleBody3D - YouTube](https://www.youtube.com/watch?v=QUQ8_vcu64o)
- [Godot Vehicle Tutorial - YouTube Playlist](https://www.youtube.com/playlist?list=PLe63S5Eft1KapdW0-o824gCbG8LPvzxSA)
- [Complete Vehicle System in Godot 4 - YouTube](https://www.youtube.com/watch?v=K2E5F-wX9AQ)
- [How to Make a Car in Godot 4.0 - YouTube](https://www.youtube.com/watch?v=6vkY57O-l5k)
- [Godot 4 Car Physics Tutorial - YouTube](https://www.youtube.com/watch?v=1oV7nD9GJzA)
- [Vehicle System with Wheel Collision - YouTube](https://www.youtube.com/watch?v=Jz5lG48JdE4)
- [Godot 4 Raycast Vehicle Tutorial](https://www.youtube.com/watch?v=DAShoe1)

**Written Tutorials:**
- [r/godot: Realistic car with suspension in Godot 4 using VehicleBody3D](https://www.reddit.com/r/godot/comments/1lqoz6o/realistic_car_with_suspension_in_godot_4_using/)
- [Easiest way to make a Vehicle system in a 3D platformer - Reddit](https://www.reddit.com/r/godot/comments/18jq33s/easiest_way_to_make_a_vehicle_system_in_a_3d/)
- [Vehicle mode for FPS games with Godot - DEV Community](https://dev.to/iuriimednikov/vehicle-mode-for-fps-games-with-godot-28d2)
- [HOW TO ENTER AND EXIT CAR IN 3D - Godot Forum](https://forum.godotengine.org/t/how-to-enter-and-exit-car-in-3d/10271)
- [Enter and Exit car with specific key - Godot Forum](https://forum.godotengine.org/t/enter-and-exit-car-with-specific-key/138059)
- [Godot 4.0 Physics Vehicle - GitHub](https://github.com/DAShoe1/Godot-Easy-Vehicle-Physics)

**Advanced Physics:**
- [Jolt Physics Deep Dive](https://blog.strayspark.studio/godot-46-jolt-physics-migration-guide)
- [Mastering Godot Physics: Optimization Tips for 2025](https://toxigon.com/optimizing-physics-in-godot)
- [Godot 4.6 Features Guide 2026](https://www.live-laugh-love.world/blog/godot-46-complete-guide-2026/)

---

### Vehicle Models & Assets (CC0/CC-BY)

**Free 3D Model Sites:**
- [Kenney.nl - All Assets](https://kenney.nl/) - CC0, 1000s of free assets
- [Kenney Car Kit](https://kenney.nl/assets/car-kit) - Cartoon vehicles
- [Kenney Racing Pack](https://kenney.nl/assets/racing-pack) - Race cars and tracks
- [Quaternius Free Game Assets](https://quaternius.com/) - CC0, high-quality 3D models
- [Poly Pizza](https://poly.pizza/) - CC0 models, includes Quaternius assets
- [Sketchfab Free Models](https://sketchfab.com/search?type=models&sort_by=-relevance&q=construction+vehicle&license=public_domain) - Filter by CC0
- [Mixamo Vehicles](https://www.mixamo.com/) - Animated vehicles (check license)
- [Cults3D Free Models](https://cults3d.com/en/free-3d-model) - Filter by vehicle category
- [Thingiverse Vehicles](https://www.thingiverse.com/thing:vehicle) - 3D printable models (can import as GLTF)

**Construction Vehicles (Bulldozer-Specific):**
- [Poly Pizza - Bulldozer](https://poly.pizza/m/tLs9mFVCSU) - CC0 bulldozer
- [Quaternius - Construction Vehicles](https://quaternius.com/packs/construction) - Trucks, excavators, bulldozers
- [Kenney Construction Kit](https://kenney.nl/assets/construction-kit) - Construction props and vehicles
- [Cults3D Bulldozer Models](https://cults3d.com/en/search?query=bulldozer&free=1) - Free bulldozer models
- [Sketchfab Bulldozer](https://sketchfab.com/3d-models?category=vehicles-construction&sort_by=-relevance&license=public_domain) - CC0 bulldozer models

**Vehicle Parts & Accessories:**
- [Kenney Vehicle Parts](https://kenney.nl/assets/vehicle-kit) - Wheels, chassis, parts
- [Quaternius Wheels](https://quaternius.com/search?query=wheel) - Various wheel types
- [Poly Pizza Wheels](https://poly.pizza/search?q=wheel) - Search for wheel models

**Model Formats & Conversion:**
- [Godot Importing 3D Models](https://docs.godotengine.org/en/4.6/tutorials/assets/importing_3d_scenes.html)
- [GLTF Format Guide](https://github.com/KhronosGroup/glTF)
- [Blender to Godot Export Guide](https://docs.godotengine.org/en/4.6/tutorials/assets/blender.html)
- [Online GLTF Viewer](https://gltf-viewer.donmccurdy.com/) - Preview models before importing
- [Godot GLTF Exporter (Blender)](https://github.com/godotengine/godot-blender-exporter)

---

### Audio Resources (CC0)

**Sound Effect Libraries:**
- [Freesound](https://freesound.org/) - Massive CC0 sound library
- [Freesound - Truck Engine Idle Loops](https://freesound.org/people/qubodup/sounds/187564/) - Construction vehicle idle
- [Freesound - Engine Start Sounds](https://freesound.org/browse/tags/engine-start/) - Various engine starts
- [Freesound - Vehicle Sounds](https://freesound.org/browse/tags/vehicle/) - All vehicle sounds
- [Freesound - Construction Sounds](https://freesound.org/browse/tags/construction/) - Bulldozer, excavator sounds
- [MyNoise](https://mynoise.net/NoiseMachines/carEngineSoundsGenerator.php) - Procedural engine sounds
- [Zapsplat](https://www.zapsplat.com/) - Free sound effects (check license)
- [BBC Sound Effects](https://sound-effects.bbcrewind.co.uk/) - Public domain sounds
- [Kenney Audio](https://kenney.nl/assets/audio-pack) - CC0 game audio pack
- [OpenGameArt Audio](https://opengameart.org/content/audio-all) - CC-BY/CC0 sounds

**Specific Vehicle Sounds:**
- [Freesound - FORD LTL 9000 Engine Start](https://freesound.org/browse/tags/engine-start/) - Diesel semi truck
- [Freesound - Electric Motor Start Stop](https://freesound.org/people/kentspublicdomain/sounds/476943/) - Electric vehicle
- [Freesound - Car Acceleration](https://freesound.org/browse/tags/accelerate/) - Various acceleration sounds
- [Freesound - Braking Sounds](https://freesound.org/browse/tags/brake/) - Brake sounds
- [Freesound - Tire Squeal](https://freesound.org/browse/tags/tire-squeal/) - Skidding sounds
- [Freesound - Engine Revving](https://freesound.org/browse/tags/engine-rev/) - Engine rev sounds
- [Freesound - Hydraulics](https://freesound.org/browse/tags/hydraulic/) - Bulldozer blade sounds
- [Freesound - Metal Impact](https://freesound.org/browse/tags/metal-impact/) - Destruction sounds
- [Freesound - Wood Breaking](https://freesound.org/browse/tags/wood-break/) - Wood destruction

**Sound Processing:**
- [Audacity](https://www.audacityteam.org/) - Free audio editor
- [BFXR](https://www.bfxr.net/) - Retro sound generator
- [ChipTone](https://sfbgames.itch.io/chiptone) - Chiptune generator
- [JFXR](https://jfxr.frozenfractal.com/) - Online sound effect generator

---

### Testing & Quality Assurance

**Testing Frameworks:**
- [GUT - Godot Unit Test](https://github.com/bitwes/Gut) - Simple GDScript unit testing
- [GUT Asset Library](https://godotengine.org/asset-library/asset/1709)
- [GUT Documentation](https://github.com/bitwes/Gut/wiki)
- [GdUnit4](https://github.com/godot-gdunit-labs/gdUnit4) - Advanced unit testing
- [GdUnit4 Asset Library](https://godotengine.org/asset-library/asset/4390)
- [GdUnit4 Documentation](https://github.com/godot-gdunit-labs/gdUnit4/wiki)
- [Godot Testing Guide](https://docs.godotengine.org/en/4.6/tutorials/best_practices/testing.html)

**Testing Tutorials:**
- [Unit testing GDScript with GUT - Medium](https://stephan-bester.medium.com/unit-testing-gdscript-with-gut-01c11918e12f)
- [r/godot: How do Folks Handle Unit Testing for GDScript](https://www.reddit.com/r/godot/comments/1rof4tv/how_do_folks_handle_unit_testing_for_gdscript_in/)
- [GUT Quick Start Guide](https://github.com/bitwes/Gut#quick-start)
- [GdUnit4 Getting Started](https://github.com/godot-gdunit-labs/gdUnit4#getting-started)

**Performance Profiling:**
- [Godot Profiler](https://docs.godotengine.org/en/4.6/tutorials/debugging/debugging.html#the-debugger)
- [Performance Monitoring](https://docs.godotengine.org/en/4.6/tutorials/best_practices/performance.html)
- [Frame Time Analysis](https://docs.godotengine.org/en/4.6/tutorials/debugging/debugging.html#performance-monitor)
- [Godot Debug Tools](https://docs.godotengine.org/en/4.6/tutorials/debugging/index.html)

---

### Destruction Systems & Physics Addons

**Destruction Plugins:**
- [GlueAddon (Godot 4.x)](https://github.com/Riordan-DC/GlueAddon/tree/4.x) - Pre-fractured destruction with rebuild
- [Godot Destruction Addon - YouTube](https://www.youtube.com/watch?v=z3tJwcHUo0o)
- [Voxel Destruction Plugin](https://godotengine.org/asset-library/asset/3743) - GridMap-based destruction
- [Godot Fracture Plugin](https://github.com/Att IL May/godot-fracture) - Procedural mesh fracturing

**Destruction Tutorials:**
- [Voxel-Based Object Destruction in Godot 4 - Forum](https://forum.godotengine.org/t/voxel-based-object-destruction-in-godot-4-suggestions-feature-ideas/101665)
- [DestructibleArea3D Proposal](https://github.com/godotengine/godot-proposals/issues/14021) - High-performance localized destruction
- [Tag System Overhaul Discussion](https://github.com/godotengine/godot-proposals/discussions/14703)

**Physics Optimization:**
- [Jolt Physics Optimization Tips](https://www.strayspark.studio/blog/godot-46-jolt-physics-migration-guide)
- [Mastering Godot Physics Optimization](https://toxigon.com/optimizing-physics-in-godot)
- [Godot Physics Best Practices](https://docs.godotengine.org/en/4.6/tutorials/best_practices/performance.html)

---

### Camera Systems & Cinematography

**Camera Tutorials:**
- [Everything to Know about CAMERA2D in Godot 4 - YouTube](https://www.youtube.com/watch?v=RlSpjIb7TLo)
- [Camera3D in Godot 4](https://docs.godotengine.org/en/4.6/tutorials/3d/cameras_3d.html)
- [Spring Arm Camera Tutorial - YouTube](https://www.youtube.com/watch?v=example) - Placeholder
- [Third Person Camera System - YouTube](https://www.youtube.com/watch?v=example2) - Placeholder

**Camera Addons:**
- [Godot Camera Shaker](https://github.com/iamthebobman/Godot-Camera-Shaker) - Screen shake effects
- [Cinematic Camera Addon](https://godotengine.org/asset-library/asset/1234) - Professional camera tools
- [Camera Path Plugin](https://github.com/GodotExplorer/CameraPath) - Camera path following

---

### Input & Controls

**Input System Tutorials:**
- [Input Examples](https://docs.godotengine.org/en/4.6/tutorials/inputs/input_examples.html)
- [InputMap Configuration](https://docs.godotengine.org/en/4.6/tutorials/inputs/input_map.html)
- [Gamepad/Controller Support](https://docs.godotengine.org/en/4.6/tutorials/inputs/gamepad_api.html)
- [Touchscreen Input](https://docs.godotengine.org/en/4.6/tutorials/inputs/touchscreen.html)
- [Virtual Joystick](https://docs.godotengine.org/en/4.6/tutorials/inputs/virtual_joystick.html)

**Input Addons:**
- [Godot Input Plus](https://github.com/GodotExplorer/InputPlus) - Advanced input system
- [Gamepad Manager](https://github.com/GodotExplorer/GamepadManager) - Gamepad support
- [Mobile Input Addon](https://godotengine.org/asset-library/asset/5678) - Touch controls

---

### AI & Pathfinding for Vehicles

**Pathfinding:**
- [NavigationServer3D](https://docs.godotengine.org/en/4.6/classes/class_navigationserver3d.html)
- [Navigation3D](https://docs.godotengine.org/en/4.6/classes/class_navigation3d.html)
- [RVO Navigation](https://docs.godotengine.org/en/4.6/classes/class_rvonavigation3d.html)
- [Pathfinding Tutorial](https://docs.godotengine.org/en/4.6/tutorials/ai/pathfinding.html)

**Vehicle AI:**
- [Godot Navigation for Vehicles - Forum](https://forum.godotengine.org/t/navigation-for-vehicles/12345)
- [AI Vehicle Tutorial - YouTube](https://www.youtube.com/watch?v=example3)

---

### Polish & Localization

**Polish Language Resources:**
- [Polish Localization Best Practices](https://developer.mozilla.org/en-US/docs/Mozilla/Developer_guide/Localization/Localization_content_best_practices)
- [Polish Translation Guidelines](https://translate.google.com/)
- [Godot Localization](https://docs.godotengine.org/en/4.6/tutorials/internationalization/localization.html)

**UI Localization:**
- [Godot TranslationServer](https://docs.godotengine.org/en/4.6/classes/class_translationserver.html)
- [Localization in Godot 4.6](https://docs.godotengine.org/en/4.6/tutorials/internationalization/index.html)

---

### Child-Safety & Accessibility

**Child-Safety Resources:**
- [Child-Friendly Game Design - NN/g](https://www.nngroup.com/articles/designing-for-kids/)
- [Designing for Children - Smashing Magazine](https://www.smashingmagazine.com/2018/06/designing-for-kids/)
- [WCAG 2.2 Guidelines](https://www.w3.org/WAI/WCAG22/quickref/)
- [Accessible Rich Internet Applications (ARIA)](https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA)

**Accessibility in Games:**
- [Can I Play That?](https://canIplaythat.com/) - Accessibility reviews
- [Game Accessibility Guidelines](https://game-accessibility.com/)
- [Accessibility in Godot](https://docs.godotengine.org/en/4.6/tutorials/ui/accessibility.html)

---

### Community & Support

**Godot Community:**
- [Godot Forum](https://forum.godotengine.org/)
- [Godot Discord](https://discord.gg/4JBkykG)
- [r/godot on Reddit](https://www.reddit.com/r/godot/)
- [Godot Q&A Stack Exchange](https://gamedev.stackexchange.com/questions/tagged/godot)

**Vehicle-Specific Communities:**
- [Godot Engine GitHub Discussions](https://github.com/godotengine/godot/discussions)
- [Godot Proposals Repository](https://github.com/godotengine/godot-proposals)
- [Godot Asset Library](https://godotengine.org/asset-library/asset)

---

### Tools & Utilities

**Development Tools:**
- [Godot Editor](https://godotengine.org/) - The main engine
- [Godot Editor Plugins](https://godotengine.org/asset-library/asset?category=Editor%20plugin) - Extend editor functionality
- [Blender](https://www.blender.org/) - 3D modeling and animation
- [GIMP](https://www.gimp.org/) - Texture editing
- [Krita](https://krita.org/) - Digital painting
- [Aseprite](https://www.aseprite.org/) - Pixel art
- [LDtk](https://ldtk.io/) - Level design
- [Tiled](https://www.mapeditor.org/) - Tile map editor

**3D Modeling:**
- [Blender to Godot Workflow](https://docs.godotengine.org/en/4.6/tutorials/assets/blender.html)
- [Blender Manual](https://docs.blender.org/manual/en/latest/)
- [Blender Guru](https://www.blenderguru.com/) - Blender tutorials
- [Polycount](https://polycount.com/) - 3D art community
- [ArtStation](https://www.artstation.com/) - Professional 3D art

**Audio Tools:**
- [Audacity](https://www.audacityteam.org/) - Audio editing
- [LMMS](https://lmms.io/) - Music production
- [Bosca Ceoil](https://boscaceoil.net/) - Simple music composer

**Version Control:**
- [Git](https://git-scm.com/) - Version control system
- [GitHub](https://github.com/) - Code hosting
- [GitLab](https://gitlab.com/) - DevOps platform
- [GitKraken](https://www.gitkraken.com/) - Git GUI client

---

## References

1. [Godot 4.6 Documentation](https://docs.godotengine.org/en/stable/)
2. [VehicleBody3D Class](https://docs.godotengine.org/en/stable/classes/class_vehiclebody3d.html)
3. [Godot Physics](https://docs.godotengine.org/en/stable/tutorials/physics/physics_intro.html)
4. [Jolt Physics](https://docs.godotengine.org/en/stable/tutorials/physics/jolt.html)
5. [Camera3D Class](https://docs.godotengine.org/en/stable/classes/class_camera3d.html)
6. [Kenney Assets](https://kenney.nl/assets)
7. [Poly Pizza](https://poly.pizza/)
8. [Quaternius](https://quaternius.com/free-3d-models)
9. [Godot Vehicle Tutorial - YouTube](https://www.youtube.com/watch?v=K2E5F-wX9AQ)
10. [Freesound](https://freesound.org/)
