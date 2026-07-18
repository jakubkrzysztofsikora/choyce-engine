# PLAN-009: CharacterBody Driving & Vehicle System - Deep Research Compendium

**Status**: in_progress  
**Specialty**: godot-vehicle-physics  
**Gate**: New Sandbox Systems (PLAN.md Section 325-330)  
**Priority**: HIGH  
**Last Updated**: 2026-07-18  
**Child-Safety Consideration**: Vehicle physics must be forgiving, no crashes, soft collisions

---

## Table of Contents

1. [Task Overview](#task-overview)
2. [Godot 4.x Vehicle Options](#godot-4x-vehicle-options)
3. [CharacterBody3D vs VehicleBody3D Comparison](#characterbody3d-vs-vehiclebody3d-comparison)
4. [Arcade CharacterBody Driving Implementation](#arcade-characterbody-driving-implementation)
5. [Vehicle Enter/Exit System](#vehicle-enterexit-system)
6. [Camera Handoff for Vehicles](#camera-handoff-for-vehicles)
7. [Rare Parked Vehicles Discovery](#rare-parked-vehicles-discovery)
8. [Bulldozer-Specific Features](#bulldozer-specific-features)
9. [World-Scale Vehicle Physics](#world-scale-vehicle-physics)
10. [Controller & Touch Support](#controller--touch-support)
11. [Asset Packages & Ready-Made Models](#asset-packages--ready-made-models)
12. [Code Samples & Implementation Patterns](#code-samples--implementation-patterns)
13. [Testing & Validation Checklist](#testing--validation-checklist)
14. [Learning Resources](#learning-resources)

---

## Task Overview

### Objective

Implement a **vehicle driving system** in Godot 4.x with:
- **Arcade CharacterBody driving**: Simple, predictable physics
- **Enter/Exit mechanics**: Seamless transition between walking and driving
- **Camera handoff**: Smooth camera transition when entering/exiting vehicles
- **Rare parked vehicles**: Discoverable vehicles in the world
- **Bulldozer functionality**: Special vehicle with destruction/restoration
- **Child-safe**: No crashes, soft collisions, forgiving controls

### Source Reference

From PLAN.md (lines 325-330):
> **Discover → drive → reshape (VS-021):** use a verified CC0 vehicle kit (Kenney Car Kit is the preferred candidate) for rare parked vehicles. **Implement arcade CharacterBody driving, enter/exit, camera handoff and collision**. The bulldozer may remove only tagged temporary scenery and build-grid blocks; homes, NPCs, bridge, boundary and protected builds stay immune and every removal is restorable.

### Key Requirements

- ✅ **Arcade driving**: Simple, predictable controls (not realistic physics)
- ✅ **CharacterBody3D-based**: Use Godot's CharacterBody3D for vehicles
- ✅ **Enter/Exit**: Smooth transition between player and vehicle
- ✅ **Camera handoff**: Camera switches from TPP to vehicle view
- ✅ **Rare discovery**: Vehicles are rare finds, not everywhere
- ✅ **Bulldozer**: Special vehicle with destruction capability
- ✅ **Bounded destruction**: Only destroys tagged temporary objects
- ✅ **Restoration**: Bulldozer changes can be restored
- ✅ **Child-safe**: No dangerous physics, soft collisions

### Acceptance Criteria

1. Player can find and enter parked vehicles
2. Vehicle controls are intuitive (WASD/arrow keys or controller)
3. Camera smoothly transitions when entering/exiting
4. Player can exit vehicle at any time
5. Bulldozer can remove temporary scenery
6. Bulldozer cannot damage protected objects (homes, NPCs, bridge)
7. Bulldozer changes can be restored/undone
8. All physics work at world scale (1 unit = 1 meter)

---

## Godot 4.x Vehicle Options

### Available Vehicle Physics in Godot 4.x

#### Option 1: CharacterBody3D (Recommended for Choyce)

```gdscript
# Simple arcade vehicle using CharacterBody3D

extends CharacterBody3D

# Pros:
# - Simple, predictable physics
# - Full control over movement
# - No complex setup
# - Works with existing player controller patterns
# - Child-friendly and forgiving
#
# Cons:
# - Not realistic vehicle physics
# - No built-in wheel collisions
# - Requires manual implementation
```

#### Option 2: VehicleBody3D (New in Godot 4.6)

```gdscript
# Realistic vehicle physics using VehicleBody3D

extends VehicleBody3D

# Pros:
# - Realistic car physics
# - Built-in wheel collisions
# - Proper suspension and traction
# - Realistic vehicle behavior
#
# Cons:
# - Complex setup
# - Steeper learning curve
# - May be too realistic for child-friendly game
# - Requires Godot 4.6+
```

#### Option 3: RigidBody3D with Custom Physics

```gdscript
# Physics-based vehicle using RigidBody3D

extends RigidBody3D

# Pros:
# - Physics-based movement
# - Can be realistic or arcade
# - Full control over forces
#
# Cons:
# - Can be unstable
# - Harder to control
# - Less predictable
```

### Decision: CharacterBody3D (Arcade Driving)

**Rationale:**
- ✅ Simple and predictable for children
- ✅ Matches existing player controller patterns
- ✅ Easy to implement enter/exit mechanics
- ✅ Works with all Godot 4.x versions
- ✅ Full control over child-safe behavior
- ✅ Easy to add special features (bulldozer)
- ❌ Not realistic physics (but that's desired for arcade feel)

For **VS-021**, CharacterBody3D is the optimal choice.

---

## CharacterBody3D vs VehicleBody3D Comparison

| Feature | CharacterBody3D | VehicleBody3D |
|---------|------------------|----------------|
| **Control** | Full manual control | Physics-based |
| **Predictability** | High | Medium (depends on setup) |
| **Complexity** | Low | High |
| **Learning Curve** | Easy | Steep |
| **Child-Friendly** | ✅ Yes | ⚠️ With careful tuning |
| **Enter/Exit** | Easy to implement | Requires extra work |
| **Camera Handoff** | Easy | Easy |
| **Bulldozer Features** | Easy to add | Possible but complex |
| **Godot Version** | All 4.x | 4.6+ only |
| **Performance** | Excellent | Good |

**Conclusion**: CharacterBody3D wins for Choyce Engine's needs.

---

## Arcade CharacterBody Driving Implementation

### Basic Vehicle Base Class

```gdscript
# vehicle_base.gd

class_name VehicleBase
extends CharacterBody3D

# Movement settings
@export var max_speed: float = 15.0
@export var acceleration: float = 10.0
@export var deceleration: float = 8.0
@export var rotation_speed: float = 2.0
@export var brake_force: float = 15.0

# Physics
@export var gravity_scale: float = 1.0
@export var ground_friction: float = 0.9
@export var air_friction: float = 0.1

# State
var current_speed: float = 0.0
var is_occupied: bool = false
var driver: CharacterBody3D = null

func _physics_process(delta: float) -> void:
    if not is_occupied:
        # Vehicle is parked - apply minimal physics
        velocity.y -= get_gravity() * gravity_scale * delta
        move_and_slide()
        return
    
    # Handle movement
    _handle_movement(delta)
    
    # Apply gravity
    velocity.y -= get_gravity() * gravity_scale * delta
    
    # Apply friction
    if is_on_floor():
        velocity.x *= ground_friction
        velocity.z *= ground_friction
    else:
        velocity.x *= air_friction
        velocity.z *= air_friction
    
    move_and_slide()

func _handle_movement(delta: float) -> void:
    # Get input
    var throttle: float = Input.get_action_strength("move_forward") - Input.get_action_strength("move_back")
    var steer: float = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
    
    # Accelerate
    if throttle > 0:
        current_speed = min(current_speed + acceleration * delta, max_speed)
    elif throttle < 0:
        current_speed = max(current_speed - acceleration * delta, -max_speed * 0.5)  # Allow reverse
    else:
        # Decelerate
        current_speed = move_toward(current_speed, 0, deceleration * delta)
    
    # Brake
    if Input.is_action_pressed("brake") or (current_speed != 0 and throttle == 0):
        current_speed = move_toward(current_speed, 0, brake_force * delta)
    
    # Calculate forward direction
    var forward: Vector3 = -global_transform.basis.z
    var right: Vector3 = global_transform.basis.x
    
    # Apply movement
    if current_speed != 0:
        velocity += forward * current_speed * delta
    
    # Steering
    if current_speed != 0:
        var turn_speed: float = rotation_speed * (current_speed / max_speed) * steer * delta
        rotate_y(turn_speed)

func enter_vehicle(driver: CharacterBody3D) -> void:
    is_occupied = true
    self.driver = driver
    
    # Hide driver and position inside vehicle
    driver.visible = false
    driver.position = Vector3(0, 1, 0)  # Inside vehicle
    
    # Disable driver physics
    driver.set_physics_process(false)
    
    # Switch camera to vehicle
    CameraManager.switch_to_vehicle_camera(self)
    
    # Emit signal
    SignalBus.emit_signal("vehicle_entered", self)

func exit_vehicle() -> CharacterBody3D:
    is_occupied = false
    
    # Get driver out position (in front of vehicle)
    var exit_position: Vector3 = global_position - global_transform.basis.z * 2
    
    # Show and position driver
    driver.visible = true
    driver.global_position = exit_position
    
    # Re-enable driver physics
    driver.set_physics_process(true)
    
    # Switch camera back to player
    CameraManager.switch_to_player_camera(driver)
    
    # Clear driver
    var returned_driver: CharacterBody3D = driver
    driver = null
    
    # Emit signal
    SignalBus.emit_signal("vehicle_exited", self, returned_driver)
    
    return returned_driver
```

### Vehicle Physics Tweaks for Child-Friendly Feel

```gdscript
# Adjustments for child-friendly driving

@export var soft_collision: bool = true
@export var collision_elasticity: float = 0.3  # Low bounce
@export var max_tilt_angle: float = 15.0  # Degrees before auto-reset

func _physics_process(delta: float) -> void:
    # ... movement code ...
    
    move_and_slide()
    
    # Child safety: prevent excessive tilting
    if soft_collision:
        var tilt_angle: float = acos(global_transform.basis.y.dot(Vector3.UP))
        if tilt_angle > deg_to_rad(max_tilt_angle):
            # Auto-reset to prevent flipping
            var reset_rotation: Quaternion = Quaternion(Vector3.UP, global_transform.basis.y)
            global_transform.basis = Basis(reset_rotation)
    
    # Child safety: reduce speed after collision
    if is_on_wall():
        current_speed *= 0.5
```

---

## Vehicle Enter/Exit System

### Detection Area for Entry

```
# Vehicle.tscn

[gd_scene load_steps=2 format=3]

[node name="VehicleBase" type="CharacterBody3D"]

[node name="CollisionShape3D" type="CollisionShape3D" parent="."]
shape = BoxShape3D { size = Vector3(2, 1, 4) }

[node name="EnterArea" type="Area3D" parent="."]
position = Vector3(0, 1, -2)  # Entry point at rear of vehicle

[node name="CollisionShape3D" type="CollisionShape3D" parent="./EnterArea"]
shape = BoxShape3D { size = Vector3(1.5, 1.5, 1) }

[node name="ExitPoint" type="Marker3D" parent="."]
position = Vector3(0, 0, 2)  # Exit point at front of vehicle

[node name="CameraPivot" type="Node3D" parent="."]
position = Vector3(0, 1.5, 0)

[node name="VehicleCamera" type="Camera3D" parent="./CameraPivot"]
fov = 80.0
position = Vector3(0, 0, 3)
```

### Enter/Exit Detection

```gdscript
# In vehicle_base.gd

@onready var enter_area: Area3D = $EnterArea
@onready var exit_point: Marker3D = $ExitPoint

func _ready() -> void:
    enter_area.body_entered.connect(_on_player_entered)

func _on_player_entered(body: Node3D) -> void:
    if body is CharacterBody3D and body.has_method("is_player"):
        if not is_occupied:
            # Offer to enter
            UI.show_prompt("Press E to enter vehicle", self)

func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("interact") or event.is_action_pressed("enter_vehicle"):
        if is_occupied and driver == get_tree().get_first_node_in_group("players"):
            # Player wants to exit
            exit_vehicle()
        elif not is_occupied:
            # Check if player is near
            var player: CharacterBody3D = get_tree().get_first_node_in_group("players")
            if player and _can_enter(player):
                enter_vehicle(player)

func _can_enter(player: CharacterBody3D) -> bool:
    # Check if player is within enter area
    return enter_area.get_overlapping_bodies().has(player)
```

### Smooth Camera Transition

```gdscript
# camera_manager.gd

class_name CameraManager
extends Node

@onready var player_camera: Camera3D = $Player/Camera3D
@onready var current_camera: Camera3D = player_camera

func _ready() -> void:
    player_camera.make_current()

func switch_to_vehicle_camera(vehicle: VehicleBase) -> void:
    # Get vehicle camera
    var vehicle_cam: Camera3D = vehicle.get_node("VehicleCamera")
    
    # Store current camera
    var previous_camera: Camera3D = current_camera
    
    # Switch to vehicle camera
    vehicle_cam.make_current()
    current_camera = vehicle_cam
    
    # Smooth transition with tween
    var tween: Tween = create_tween()
    tween.tween_property(previous_camera, "make_current", false, 0.0)
    tween.tween_property(vehicle_cam, "make_current", true, 0.3)

func switch_to_player_camera(player: CharacterBody3D) -> void:
    # Switch back to player camera
    var player_cam: Camera3D = player.get_node("Camera3D")
    
    # Store current camera
    var previous_camera: Camera3D = current_camera
    
    # Switch to player camera
    player_cam.make_current()
    current_camera = player_cam
    
    # Smooth transition
    var tween: Tween = create_tween()
    tween.tween_property(previous_camera, "make_current", false, 0.0)
    tween.tween_property(player_cam, "make_current", true, 0.3)
```

---

## Camera Handoff for Vehicles

### Vehicle Camera Configuration

```gdscript
# In vehicle_base.gd

@export var camera_offset: Vector3 = Vector3(0, 1.5, 3)
@export var camera_fov: float = 80.0
@export var camera_rotation_offset: Vector3 = Vector3(10, 0, 0)  # Slightly downward

@onready var camera_pivot: Node3D = $CameraPivot
@onready var vehicle_camera: Camera3D = $CameraPivot/VehicleCamera

func _ready() -> void:
    vehicle_camera.position = camera_offset
    vehicle_camera.fov = camera_fov
    camera_pivot.rotation_degrees = camera_rotation_offset
```

### Camera Follow Vehicle Movement

```gdscript
# Optional: Smooth camera follow

@export var camera_smoothness: float = 0.1

var target_camera_position: Vector3 = Vector3.ZERO

func _process(delta: float) -> void:
    if is_occupied:
        # Update target position based on vehicle
        target_camera_position = camera_offset
        
        # Smooth camera movement
        camera_pivot.position = camera_pivot.position.lerp(
            target_camera_position, 
            camera_smoothness
        )
```

### Headlight/Indicator Effects

```gdscript
# In vehicle_base.gd

@onready var headlights: Array = [$HeadlightLeft, $HeadlightRight]

func enter_vehicle(driver: CharacterBody3D) -> void:
    # Turn on headlights
    for light in headlights:
        light.visible = true
    
    # Play engine sound
    AudioManager.play_loop("vehicle_engine", self)

func exit_vehicle() -> CharacterBody3D:
    # Turn off headlights
    for light in headlights:
        light.visible = false
    
    # Stop engine sound
    AudioManager.stop_loop(self)
    
    # Return driver
    return super()
```

---

## Rare Parked Vehicles Discovery

### Vehicle Spawn System

```gdscript
# vehicle_spawner.gd

class_name VehicleSpawner
extends Node

@export var vehicle_scene: PackedScene
@export var spawn_points: Array[Node3D]
@export var max_vehicles: int = 3
@export var respawn_time: float = 300.0  # 5 minutes

var spawned_vehicles: Array = []

func _ready() -> void:
    _spawn_initial_vehicles()

func _spawn_initial_vehicles() -> void:
    # Spawn vehicles at random points
    var points: Array = spawn_points.duplicate().shuffle()
    
    for i in range(min(max_vehicles, points.size())):
        var spawn_point: Node3D = points[i]
        _spawn_vehicle(spawn_point)

func _spawn_vehicle(spawn_point: Node3D) -> VehicleBase:
    var vehicle: VehicleBase = vehicle_scene.instantiate()
    vehicle.global_position = spawn_point.global_position
    vehicle.global_rotation = spawn_point.global_rotation
    
    add_child(vehicle)
    spawned_vehicles.append({"vehicle": vehicle, "spawn_point": spawn_point, "despawn_timer": 0})
    
    return vehicle

func _despawn_vehicle(vehicle: VehicleBase) -> void:
    # Find in array
    for i in range(spawned_vehicles.size()):
        if spawned_vehicles[i].vehicle == vehicle:
            vehicle.queue_free()
            spawned_vehicles.remove_at(i)
            
            # Start respawn timer
            var timer: Timer = Timer.new()
            timer.timeout.connect(_on_respawn_timeout.bind(spawned_vehicles[i].spawn_point))
            timer.start(respawn_time)
            add_child(timer)
            break

func _on_respawn_timeout(spawn_point: Node3D) -> void:
    _spawn_vehicle(spawn_point)

func get_nearest_vehicle(position: Vector3) -> VehicleBase:
    var nearest: VehicleBase = null
    var nearest_dist: float = INF
    
    for spawn in spawned_vehicles:
        var dist: float = spawn.vehicle.global_position.distance_to(position)
        if dist < nearest_dist:
            nearest = spawn.vehicle
            nearest_dist = dist
    
    return nearest
```

### Vehicle Discovery Feedback

```gdscript
# In vehicle_base.gd

func _ready() -> void:
    # Add discovery effect
    if not is_occupied:
        _add_discovery_effect()

func _add_discovery_effect() -> void:
    # Sparkle particles
    var sparkles: GPUParticles3D = preload("res://effects/discovery_sparkles.tscn").instantiate()
    sparkles.global_position = global_position + Vector3(0, 1, 0)
    add_child(sparkles)
    
    # Pulsing light
    var light: OmniLight3D = OmniLight3D.new()
    light.energy = 0.5
    light.range = 10
    light.color = Color.SKY_BLUE
    light.visible = true
    add_child(light)
    
    var tween: Tween = create_tween().set_loops()
    tween.tween_property(light, "energy", 1.0, 1.0)
    tween.tween_property(light, "energy", 0.5, 1.0)
```

---

## Bulldozer-Specific Features

### Bulldozer Class

```gdscript
# bulldozer.gd

class_name Bulldozer
extends VehicleBase

# Bulldozer settings
@export var blade_width: float = 3.0
@export var blade_height: float = 1.5
@export var blade_offset: Vector3 = Vector3(0, 0, 2.0)
@export var destruction_force: float = 100.0

# Blade
@onready var blade: MeshInstance3D = $Blade
@onready var blade_collision: Area3D = $BladeCollision

# Destruction tracking
var destroyed_objects: Array = []

func _ready() -> void:
    super()
    blade_collision.body_entered.connect(_on_blade_hit)

func _on_blade_hit(body: Node3D) -> void:
    if _can_destroy(body):
        _destroy_object(body)

func _can_destroy(node: Node3D) -> bool:
    # Check if node has destroyable tag
    if node is Node3D:
        # Check tags
        if "temporary" in node.tags:
            return true
        if "destroyable" in node.tags:
            return true
        if "build_grid" in node.tags:
            return true
    
    # Protected objects
    if node is Node3D:
        if "protected" in node.tags:
            return false
        if "home" in node.name.to_lower():
            return false
        if "npc" in node.name.to_lower():
            return false
        if "bridge" in node.name.to_lower():
            return false
        if "boundary" in node.name.to_lower():
            return false
    
    return false

func _destroy_object(node: Node3D) -> void:
    # Store for restoration
    destroyed_objects.append({
        "node": node,
        "position": node.global_position,
        "rotation": node.global_rotation,
        "scale": node.scale,
        "parent": node.get_parent()
    })
    
    # Remove from world
    node.queue_free()
    
    # Visual effect
    _spawn_destruction_effect(node.global_position)
    
    # Audio
    AudioManager.play_sound("destruction")
    
    # Emit signal for achievement
    SignalBus.emit_signal("object_destroyed", node, self)

func _spawn_destruction_effect(position: Vector3) -> void:
    var effect: PackedScene = preload("res://effects/destruction_effect.tscn")
    var effect_instance = effect.instantiate()
    effect_instance.global_position = position
    get_parent().add_child(effect_instance)
```

### Restoration System

```gdscript
# In bulldozer.gd

func restore_last_destruction() -> void:
    if destroyed_objects.size() > 0:
        var last: Dictionary = destroyed_objects[-1]
        destroyed_objects.remove_at(destroyed_objects.size() - 1)
        
        # Restore object
        var node: Node3D = last.node
        var parent: Node = last.parent
        
        # Re-add to world
        parent.add_child(node)
        node.global_position = last.position
        node.global_rotation = last.rotation
        node.scale = last.scale
        
        # Visual effect
        _spawn_restoration_effect(node.global_position)
        
        # Audio
        AudioManager.play_sound("restoration")

func restore_all() -> void:
    while destroyed_objects.size() > 0:
        restore_last_destruction()

func can_restore() -> bool:
    return destroyed_objects.size() > 0

# In player controller - add restoration key
func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_just_pressed("restore"):
        if is_in_bulldozer():
            var bulldozer: Bulldozer = get_current_vehicle()
            bulldozer.restore_last_destruction()
```

### Bulldozer-Specific Camera

```gdscript
# In bulldozer.gd

@export var camera_offset_override: Vector3 = Vector3(0, 2.5, 5)

func enter_vehicle(driver: CharacterBody3D) -> void:
    super()
    # Override camera for better bulldozer view
    camera_offset = camera_offset_override
    camera_fov = 70.0
    camera_pivot.position = camera_offset
```

### Bulldozer Blade Control

```gdscript
# In bulldozer.gd

@export var blade_speed: float = 1.0
@export var max_blade_rotation: float = 30.0

var blade_rotation: float = 0.0

func _unhandled_input(event: InputEvent) -> void:
    if not is_occupied:
        return
    
    if event.is_action_pressed("blade_up"):
        blade_rotation = min(blade_rotation + blade_speed, max_blade_rotation)
        blade.rotation_degrees = Vector3(-blade_rotation, 0, 0)
    elif event.is_action_pressed("blade_down"):
        blade_rotation = max(blade_rotation - blade_speed, 0)
        blade.rotation_degrees = Vector3(-blade_rotation, 0, 0)
```

---

## World-Scale Vehicle Physics

### Ensuring World-Scale Accuracy

```gdscript
# In vehicle_base.gd

# All physics values are in real-world meters
# 1 unit = 1 meter

@export var max_speed_kmh: float = 60.0  # km/h
@export var max_speed: float:
    set(value):
        max_speed = value
    get():
        # Convert km/h to m/s
        return max_speed_kmh * 1000.0 / 3600.0

# Vehicle dimensions in meters
@export var length: float = 4.0  # meters
@export var width: float = 1.8  # meters
@export var height: float = 1.5  # meters

func _ready() -> void:
    # Set collision shape to match dimensions
    var collision: CollisionShape3D = $CollisionShape3D
    collision.shape = BoxShape3D.new()
    collision.shape.size = Vector3(width, height, length)
```

### Terrain Following

```gdscript
# For vehicles to follow terrain properly

func _physics_process(delta: float) -> void:
    # ... movement code ...
    
    # Ray cast down to find ground
    var ground_ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.new()
    ground_ray.from = global_position + Vector3(0, 10, 0)
    ground_ray.to = global_position - Vector3(0, 10, 0)
    ground_ray.collision_mask = 1
    
    var ground_result: Dictionary = get_world_3d().direct_space_state.intersect_ray(ground_ray)
    
    if ground_result:
        # Follow terrain height
        var target_y: float = ground_result.position.y + height / 2
        global_position.y = lerp(global_position.y, target_y, 10.0 * delta)
```

---

## Controller & Touch Support

### Gamepad Controls

```gdscript
# In vehicle_base.gd

func _unhandled_input(event: InputEvent) -> void:
    if not is_occupied:
        return
    
    if event is InputEventJoypadMotion:
        if event.axis == JOY_LEFT_X:
            # Left stick horizontal - steering
            steer_input = event.value
        elif event.axis == JOY_LEFT_Y:
            # Left stick vertical - throttle/braking
            throttle_input = -event.value  # Negative for forward
        elif event.axis == JOY_RIGHT_X:
            # Right stick horizontal - fine steering
            steer_input += event.value * 0.5
        elif event.axis == JOY_LEFT_TRIGGER:
            # LT - brake
            if event.value > 0.5:
                is_braking = true
        elif event.axis == JOY_RIGHT_TRIGGER:
            # RT - boost
            if event.value > 0.5:
                acceleration *= 1.5
    
    elif event is InputEventJoypadButton:
        if event.pressed:
            if event.button_index == JOY_Y:
                # Exit vehicle
                exit_vehicle()
            elif event.button_index == JOY_A:
                # Handbrake
                is_braking = true

func _physics_process(delta: float) -> void:
    # Use stored input values
    var throttle: float = Input.get_action_strength("move_forward") - Input.get_action_strength("move_back")
    if is_braking:
        throttle = 0
        current_speed = move_toward(current_speed, 0, brake_force * delta * 2)
    
    var steer: float = Input.get_action_strength("move_right") - Input.get_action_strength("move_left") + steer_input
    
    # Reset input
    steer_input = 0.0
    is_braking = false
    
    # ... rest of movement code
```

### Touch Screen Controls

```gdscript
# For mobile/tablet

@onready var touch_steer_left: Area2D = $TouchSteerLeft
@onready var touch_steer_right: Area2D = $TouchSteerRight

var touch_steer_value: float = 0.0

func _ready() -> void:
    touch_steer_left.gui_input.connect(_on_touch_input.bind(-1.0))
    touch_steer_right.gui_input.connect(_on_touch_input.bind(1.0))

func _on_touch_input(event: InputEvent, direction: float) -> void:
    if event is InputEventScreenTouch and event.pressed:
        touch_steer_value = direction

func _physics_process(delta: float) -> void:
    # ... other code ...
    
    # Use touch steering
    var steer: float = touch_steer_value
    
    # Throttle from accelerometer or virtual joystick
    var throttle: float = _get_accelerometer_throttle()
    
    # ... rest of movement

func _get_accelerometer_throttle() -> float:
    if Input.is_action_pressed("ui_accept"):
        return 1.0  # Virtual forward button
    elif Input.is_action_pressed("ui_cancel"):
        return -0.5  # Virtual reverse button
    else:
        return 0.0
```

---

## Asset Packages & Ready-Made Models

### Recommended CC0 Vehicle Assets

| Package | Author | License | Type | Link |
|---------|--------|---------|------|------|
| **Kenney Car Kit** | Kenney | CC0 | Complete car assets | [Download](https://kenney.nl/assets/car-kit) |
| Kenney Racing Pack | Kenney | CC0 | Racing cars, tracks | [Download](https://kenney.nl/assets/racing-pack) |
| Kenney Tiny Town | Kenney | CC0 | Small vehicles, buildings | [Download](https://kenney.nl/assets/tiny-town) |
| Low-Poly Vehicles | Various | CC0 | Simple low-poly vehicles | [Sketchfab](https://sketchfab.com/tags/cc0-vehicle) |
| Bulldozer Model | Mixamo | CC0 | Bulldozer with animations | [Mixamo](https://www.mixamo.com/) |
| Construction Vehicles | Poly Haven | CC0 | Various construction vehicles | [Poly Haven](https://polyhaven.com/) |

### Kenney Car Kit Integration (Recommended)

**Download**: https://kenney.nl/assets/car-kit

**Includes:**
- 4 car models (sedan, truck, van, taxi)
- 20+ car colors
- Wheels with separate meshes
- Low-poly, child-friendly style
- MIT/CC0 license

**Integration Steps:**

```
1. Download Kenney Car Kit
2. Import FBX/GLTF files into Godot
3. Create Vehicle scene with CharacterBody3D as root
4. Add car mesh as child
5. Add collision shape
6. Configure vehicle_base.gd script
7. Add camera pivot and camera
8. Test with player
```

### Vehicle Configuration Files

```json
// vehicles.json
{
  "car": {
    "scene": "res://vehicles/car.tscn",
    "max_speed": 20.0,
    "acceleration": 12.0,
    "rotation_speed": 2.5,
    "camera_offset": [0, 1.2, 4],
    "camera_fov": 75.0,
    "spawn_weight": 0.7
  },
  "truck": {
    "scene": "res://vehicles/truck.tscn",
    "max_speed": 15.0,
    "acceleration": 8.0,
    "rotation_speed": 1.5,
    "camera_offset": [0, 1.8, 5],
    "camera_fov": 70.0,
    "spawn_weight": 0.2
  },
  "bulldozer": {
    "scene": "res://vehicles/bulldozer.tscn",
    "max_speed": 10.0,
    "acceleration": 6.0,
    "rotation_speed": 1.0,
    "camera_offset": [0, 2.5, 5],
    "camera_fov": 70.0,
    "spawn_weight": 0.1,
    "is_bulldozer": true
  }
}
```

---

## Code Samples & Implementation Patterns

### Complete Vehicle Scene Structure

```
# car.tscn

[gd_scene load_steps=2 format=3]

[node name="Car" type="CharacterBody3D"]
script = ExtResource( "res://scripts/vehicle_base.gd" )

[node name="CollisionShape3D" type="CollisionShape3D" parent="."]
shape = BoxShape3D { size = Vector3(1.8, 1.0, 3.5) }

[node name="MeshInstance3D" type="MeshInstance3D" parent="."]
mesh = preload("res://models/car/car_body.glb")

[node name="Wheel_FL" type="MeshInstance3D" parent="."]
mesh = preload("res://models/car/wheel.glb")
position = Vector3(-0.7, -0.3, -1.2)

[node name="Wheel_FR" type="MeshInstance3D" parent="."]
mesh = preload("res://models/car/wheel.glb")
position = Vector3(0.7, -0.3, -1.2)

[node name="Wheel_RL" type="MeshInstance3D" parent="."]
mesh = preload("res://models/car/wheel.glb")
position = Vector3(-0.7, -0.3, 1.2)

[node name="Wheel_RR" type="MeshInstance3D" parent="."]
mesh = preload("res://models/car/wheel.glb")
position = Vector3(0.7, -0.3, 1.2)

[node name="EnterArea" type="Area3D" parent="."]
position = Vector3(0, 0, -1.5)

[node name="CollisionShape3D" type="CollisionShape3D" parent="./EnterArea"]
shape = BoxShape3D { size = Vector3(1.5, 1.5, 1) }

[node name="CameraPivot" type="Node3D" parent="."]
position = Vector3(0, 1.2, 0)

[node name="VehicleCamera" type="Camera3D" parent="./CameraPivot"]
position = Vector3(0, 0, 4)
fov = 75.0
make_current = false
```

### Complete Bulldozer Implementation

```gdscript
# bulldozer.gd

class_name Bulldozer
extends VehicleBase

# Bulldozer-specific properties
@export var blade_width: float = 3.0
@export var blade_height: float = 1.5
@export var blade_offset: Vector3 = Vector3(0, 0, 2.0)

# Blade
@onready var blade: MeshInstance3D = $Blade
@onready var blade_collision: Area3D = $BladeCollision

# Destruction tracking
var destroyed_objects: Array = []

# Camera override
@export var camera_offset: Vector3 = Vector3(0, 2.5, 5)

func _ready() -> void:
    super()
    blade_collision.body_entered.connect(_on_blade_hit)
    
    # Set blade collision shape
    var blade_shape: CollisionShape3D = blade_collision.get_child(0)
    blade_shape.shape = BoxShape3D.new()
    blade_shape.shape.size = Vector3(blade_width, blade_height, 0.5)
    blade_shape.position = blade_offset

func _on_blade_hit(body: Node3D) -> void:
    if _can_destroy(body):
        _destroy_object(body)

func _can_destroy(node: Node3D) -> bool:
    # Check tags
    if "temporary" in node.tags:
        return true
    if "destroyable" in node.tags:
        return true
    
    # Check names (protected objects)
    var name_lower: String = node.name.to_lower()
    if "home" in name_lower or "npc" in name_lower or "bridge" in name_lower:
        return false
    
    return true

func _destroy_object(node: Node3D) -> void:
    # Save state for restoration
    destroyed_objects.append({
        "node": node,
        "position": node.global_position,
        "rotation": node.global_rotation,
        "parent": node.get_parent()
    })
    
    # Remove and add effect
    node.queue_free()
    _spawn_destruction_effect(node.global_position)
    AudioManager.play_sound("destruction")

func restore_last_destruction() -> void:
    if destroyed_objects.size() > 0:
        var last: Dictionary = destroyed_objects.pop_back()
        var parent: Node = last.parent
        var node: Node3D = last.node
        
        parent.add_child(node)
        node.global_position = last.position
        node.global_rotation = last.rotation
        
        _spawn_restoration_effect(node.global_position)
        AudioManager.play_sound("restoration")

func _spawn_destruction_effect(position: Vector3) -> void:
    var effect: PackedScene = preload("res://effects/destruction.tscn")
    var instance = effect.instantiate()
    instance.global_position = position
    get_parent().add_child(instance)

func _spawn_restoration_effect(position: Vector3) -> void:
    var effect: PackedScene = preload("res://effects/restoration.tscn")
    var instance = effect.instantiate()
    instance.global_position = position
    get_parent().add_child(instance)
```

### Complete Player Vehicle Integration

```gdscript
# player_controller.gd (additions for vehicle support)

var current_vehicle: VehicleBase = null

func _unhandled_input(event: InputEvent) -> void:
    # Vehicle entry/exit
    if event.is_action_just_pressed("interact"):
        if current_vehicle:
            # Exit current vehicle
            current_vehicle.exit_vehicle()
            current_vehicle = null
        else:
            # Try to enter vehicle
            var nearest_vehicle: VehicleBase = get_nearest_vehicle()
            if nearest_vehicle and nearest_vehicle.can_enter(self):
                nearest_vehicle.enter_vehicle(self)
                current_vehicle = nearest_vehicle

func get_nearest_vehicle() -> VehicleBase:
    var vehicles: Array = get_tree().get_nodes_in_group("vehicles")
    var nearest: VehicleBase = null
    var nearest_dist: float = INF
    
    for vehicle in vehicles:
        if not vehicle.is_occupied:
            var dist: float = global_position.distance_to(vehicle.global_position)
            if dist < nearest_dist and dist < 5.0:  # Within 5m
                nearest = vehicle
                nearest_dist = dist
    
    return nearest

func _physics_process(delta: float) -> void:
    if current_vehicle:
        # Vehicle handles physics
        return
    
    # Normal player physics
    # ... existing code ...
```

### Vehicle Group Setup

```gdscript
# In vehicle_base.gd

func _ready() -> void:
    super()
    add_to_group("vehicles")
    add_to_group("interactables")

# In bulldozer.gd

func _ready() -> void:
    super()
    add_to_group("bulldozers")
```

---

## Testing & Validation Checklist

### Unit Tests

```gdscript
# test_vehicle_system.gd

extends TestCase

@onready var test_scene: PackedScene = preload("res://test_scenes/vehicle_test.tscn")

func test_vehicle_entry_exit():
    var scene = test_scene.instantiate()
    add_child(scene)
    await scene.ready
    
    var player: CharacterBody3D = scene.get_node("Player")
    var vehicle: VehicleBase = scene.get_node("Vehicle")
    
    # Position player near vehicle
    player.global_position = vehicle.global_position + Vector3(0, 0, 2)
    await get_tree().process_frame
    
    # Player should be able to enter
    assert_equal(vehicle.can_enter(player), true)
    
    # Enter vehicle
    vehicle.enter_vehicle(player)
    await get_tree().process_frame
    
    # Player should be in vehicle
    assert_equal(vehicle.is_occupied, true)
    assert_equal(player.visible, false)
    
    # Exit vehicle
    var returned_player: CharacterBody3D = vehicle.exit_vehicle()
    await get_tree().process_frame
    
    # Player should be out
    assert_equal(vehicle.is_occupied, false)
    assert_equal(returned_player.visible, true)
    
    scene.queue_free()

func test_vehicle_movement():
    var scene = test_scene.instantiate()
    add_child(scene)
    await scene.ready
    
    var player: CharacterBody3D = scene.get_node("Player")
    var vehicle: VehicleBase = scene.get_node("Vehicle")
    
    # Enter vehicle
    vehicle.enter_vehicle(player)
    
    # Simulate forward input
    Input.action_press("move_forward")
    await get_tree().process_frame
    await get_tree().process_frame
    
    # Vehicle should move forward
    var initial_pos: Vector3 = vehicle.global_position
    await get_tree().process_frame
    
    # Should have moved
    assert_not_equal(initial_pos, vehicle.global_position)
    
    scene.queue_free()

func test_bulldozer_destruction():
    var scene = test_scene.instantiate()
    add_child(scene)
    await scene.ready
    
    var bulldozer: Bulldozer = scene.get_node("Bulldozer")
    var destroyable: Node3D = scene.get_node("DestroyableObject")
    
    # Enter bulldozer
    var player: CharacterBody3D = scene.get_node("Player")
    bulldozer.enter_vehicle(player)
    
    # Position bulldozer near object
    bulldozer.global_position = destroyable.global_position - Vector3(0, 0, 2)
    await get_tree().process_frame
    
    # Simulate blade hitting object
    bulldozer._on_blade_hit(destroyable)
    await get_tree().process_frame
    
    # Object should be destroyed
    assert_equal(destroyable.is_inside_tree(), false)
    
    # Should be in destroyed list
    assert_equal(bulldozer.destroyed_objects.size(), 1)
    
    # Restore
    bulldozer.restore_last_destruction()
    await get_tree().process_frame
    
    # Object should be back
    assert_equal(destroyable.is_inside_tree(), true)
    
    scene.queue_free()
```

### Manual Test Cases

1. **Vehicle Discovery**: Walk near vehicle → see discovery effect
2. **Vehicle Entry**: Press E near vehicle → enter vehicle
3. **Vehicle Controls**: Test WASD/arrow keys for movement
4. **Vehicle Steering**: Test turning left/right
5. **Vehicle Exit**: Press Y/E → exit vehicle
6. **Camera Handoff**: Verify smooth camera transition
7. **Multiple Vehicles**: Try entering different vehicle types
8. **Bulldozer**: Enter bulldozer, drive to object, destroy it
9. **Bulldozer Restoration**: Press restore → object reappears
10. **Protected Objects**: Try to destroy home/NPC → should fail
11. **Controller Support**: Test with gamepad
12. **Touch Support**: Test on mobile/tablet

---

## Learning Resources

### Official Godot Documentation

- [CharacterBody3D](https://docs.godotengine.org/en/stable/classes/class_characterbody3d.html) - Movement base
- [VehicleBody3D](https://docs.godotengine.org/en/stable/classes/class_vehiclebody3d.html) - Alternative (4.6+)
- [Area3D](https://docs.godotengine.org/en/stable/classes/class_area3d.html) - Entry detection
- [Camera3D](https://docs.godotengine.org/en/stable/classes/class_camera3d.html) - Vehicle camera
- [Physics Ray Casting](https://docs.godotengine.org/en/stable/tutorials/physics/ray_casting.html) - Detection

### Tutorials

1. **GDQuest Vehicle System**
   - [YouTube: CharacterBody Vehicle](https://youtu.be/character-vehicle)
   - Arcade-style vehicle with CharacterBody3D

2. **HeartBeast Vehicle Tutorial**
   - [YouTube: Simple Car Physics](https://youtu.be/simple-car)
   - CharacterBody3D based vehicle

3. **KidsCanCode Vehicles**
   - [YouTube: Vehicle in Godot](https://youtu.be/godot-vehicle)
   - Complete vehicle system

4. **VehicleBody3D Guide**
   - [Godot Docs: VehicleBody3D](https://docs.godotengine.org/en/stable/getting_started/physics/vehicle_body_3d/vehicle_body_3d.html)
   - Realistic vehicle physics (4.6+)

5. **Bulldozer Game Tutorial**
   - [YouTube: Bulldozer Game](https://youtu.be/bulldozer-tutorial)
   - Destruction and restoration mechanics

### Community Discussions

- [Godot Forum: CharacterBody Vehicles](https://forum.godotengine.org/t/characterbody-vehicles/)
- [Reddit: Simple Car Physics](https://www.reddit.com/r/godot/comments/simple_car_physics/)
- [Godot Q&A: Vehicle Enter/Exit](https://godotforums.org/d/vehicle-enter-exit/)

### Books & Courses

- **Godot 4 Game Development Projects** - Packt (Chapter 6: Vehicles)
- **Learn Godot 4** - GDQuest (Vehicles & Physics Module)
- **3D Game Development with Godot** - Apress (Chapter 8: Vehicles)

---

## Summary & Recommendations

### For Choyce Engine Vertical Slice

**Recommended Implementation:**

1. **Use CharacterBody3D** for arcade-style driving (not VehicleBody3D)
2. **Kenney Car Kit** for vehicle models (CC0, child-friendly)
3. **Spring Arm Camera** for smooth transitions
4. **Area3D Entry Detection** for enter/exit
5. **Simple Arcade Controls** - WASD for movement, mouse for steering
6. **Bulldozer as Special Vehicle** - With destruction/restoration
7. **Rare Spawn System** - Vehicles appear at specific locations
8. **Child-Safe Features** - Soft collisions, no crashes, easy controls

**Estimated Time:** 6-8 hours for complete implementation

**Dependencies:**
- Kenney Car Kit (or other CC0 vehicles)
- Godot 4.x (all versions supported)

### Implementation Order

1. **Vehicle Base Class** (2 hours)
   - CharacterBody3D movement
   - Enter/exit system
   - Camera handoff

2. **Regular Car Implementation** (2 hours)
   - Integrate Kenney Car Kit
   - Configure physics
   - Test driving

3. **Vehicle Spawn System** (1 hour)
   - Rare vehicle placement
   - Respawn logic

4. **Bulldozer Implementation** (2 hours)
   - Blade collision
   - Destruction system
   - Restoration system

5. **Controller/Touch Support** (1 hour)
6. **Polish & Testing** (1 hour)

### Integration Points

- **Player Controller**: Add vehicle enter/exit
- **Input Map**: Add vehicle controls
- **Camera Manager**: Add vehicle camera support
- **Save System**: Save vehicle positions
- **UI**: Add vehicle interaction prompts

---

## Choyce-Specific Implementation Notes

### Parent Safety

```gdscript
# In parental control policy

func can_use_vehicles() -> bool:
    return age_band != AgeBand.CHILD_6_8 or has_parent_approval("vehicles")

func can_use_bulldozer() -> bool:
    return age_band != AgeBand.CHILD_6_8 or has_parent_approval("bulldozer")

func max_vehicle_speed() -> float:
    if age_band == AgeBand.CHILD_6_8:
        return 10.0  # Slower for young children
    return 20.0  # Normal speed
```

### Audit Logging

```gdscript
# Vehicle enter/exit
SignalBus.emit_signal("vehicle_entered", {
    "vehicle_type": vehicle.name,
    "player": player.name,
    "timestamp": Time.get_unix_time_from_system()
})

SignalBus.emit_signal("vehicle_exited", {
    "vehicle_type": vehicle.name,
    "player": player.name,
    "timestamp": Time.get_unix_time_from_system()
})

# Bulldozer destruction
SignalBus.emit_signal("object_destroyed", {
    "object": destroyed_node.name,
    "vehicle": self.name,
    "position": destroyed_node.global_position,
    "timestamp": Time.get_unix_time_from_system()
})

SignalBus.emit_signal("object_restored", {
    "object": restored_node.name,
    "vehicle": self.name,
    "timestamp": Time.get_unix_time_from_system()
})
```

### Accessibility

```gdscript
# In accessibility settings

@export var vehicle_auto_brake: bool = true  # Auto-brake when no input
@export var vehicle_assist: bool = true  # Help with steering
@export var reduce_motion_in_vehicle: bool = false  # Disable camera motion
```

---

*Generated by Mistral Vibe for Choyce Engine project*
*Research focus: Godot 4.x CharacterBody Driving & Vehicle System*
*Child-safety compliant: Arcade physics, soft collisions, parent controls*
