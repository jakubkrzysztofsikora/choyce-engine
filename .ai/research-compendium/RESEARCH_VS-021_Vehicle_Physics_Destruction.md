# Research Compendium: VS-021 — Drivable Vehicles and Bulldozer Destruction

## Task Overview

**Task ID**: VS-021  
**Title**: Add rare drivable vehicles and bounded bulldozer destruction sandbox  
**Specialty**: vehicle-gameplay  
**Owner**: codex  
**Status**: todo  
**Dependencies**: [VS-020]

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

## Online Research: Godot Vehicle Systems

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

## References

1. [Godot 4.6 Documentation](https://docs.godotengine.org/en/stable/)
2. [VehicleBody3D Class](https://docs.godotengine.org/en/stable/classes/class_vehiclebody3d.html)
3. [Godot Physics](https://docs.godotengine.org/en/stable/tutorials/physics/physics_intro.html)
4. [Jolt Physics](https://docs.godotengine.org/en/stable/tutorials/physics/jolt.html)
5. [Camera3D Class](https://docs.godotengine.org/en/stable/classes/class_camera3d.html)
6. [Kenney Assets](https://kenney.nl/assets)
7. [Poly Pizza](https://poly.pizza/)
8. [Quaternius](https://quaternius.com/free-3d-models)
9. [Godot Vehicle Tutorial](https://www.youtube.com/watch?v=K2E5F-wX9AQ)
10. [Freesound](https://freesound.org/)
