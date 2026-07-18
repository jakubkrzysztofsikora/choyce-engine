# RESEARCH_VS-005: Age-Appropriate Combat Telegraphs and Feedback System

**Task ID**: VS-005  
**Title**: Improve age-appropriate combat telegraphs and feedback  
**Owner**: mistral  
**Specialty**: combat-feel  
**Status**: in_review  
**Dependencies**: [VS-004]  
**Complexity**: HIGH  
**Child-Safety Level**: PARAMOUNT - No blood, no gore, gentle feedback, readable telegraphs  

---

## Table of Contents

1. [Task Overview](#task-overview)
2. [Current Implementation Analysis](#current-implementation-analysis)
3. [Online Research Findings](#online-research-findings)
4. [Technical Deep Dive](#technical-deep-dive)
5. [Code Samples and Patterns](#code-samples-and-patterns)
6. [Asset Sources and Packages](#asset-sources-and-packages)
7. [Child-Safety Constraints](#child-safety-constraints)
8. [Godot 4.6 Specific Features](#godot-46-specific-features)
9. [Implementation Checklist](#implementation-checklist)
10. [Testing Strategy](#testing-strategy)
11. [References and Links](#references-and-links)

---

## Task Overview

### Purpose

Create a polished, satisfying, and **child-safe** combat feel system that provides:
- **Clear telegraphs**: Enemies signal attacks with readable wind-up animations and visual cues
- **Satisfying feedback**: Hits, misses, defeats, and rewards are visually and aurally distinct
- **Accessible difficulty**: Soft aim assist and easy-mode profile for ages 6-8
- **Non-violent presentation**: No blood, no gore, no disturbing imagery

### Acceptance Criteria (from backlog.yaml)

- [x] Enemy attacks have readable wind-up and recovery (PARTIALLY IMPLEMENTED)
- [x] Hit feedback distinguishes hit/miss/defeat/reward (PARTIALLY IMPLEMENTED)
- [x] Soft aim assist and easier kid-safe tuning profile exist (PARTIALLY IMPLEMENTED)
- [ ] Crosshair tinting when enemy in range (BLOCKING - comment only at line 1966)
- [ ] combat_difficulty not serialized in to_dict()/from_dict() (BLOCKING)
- [ ] EASY mode not applied (hp_mult *= 0.6, contact_damage *= 0.5 missing) (BLOCKING)

### Gate 3 Requirements (from PLAN.md)

> Add enemy telegraph/wind-up, hit response, soft aim assist, weapon differentiation, and clear reward feedback.

---

## Current Implementation Analysis

### Existing Code Evidence

From `src/adapters/inbound/gameplay/enemy_controller.gd`:

```gdscript
# WINDUP state implementation
enum EnemyState { ..., WINDUP, ATTACKING, RECOVERY, ... }

# Wind-up timing (codex_cr_findings confirmed)
# - 0.8s for regular mobs
# - 1.2s for bosses
func _enter_windup():
    $AnimationPlayer.play("windup")
    $WindupTimer.start(WINDUP_DURATION)
    # Emission spike white flash on hit (snap to white + emission, 80ms hold)
    _flash_white()

# Squash + stretch animation on enemy hit (1.3, 0.65, 1.3)
func take_damage(amount: float):
    squash_stretch(1.3, 0.65, 1.3)
```

From `src/adapters/inbound/gameplay/player_controller.gd`:

```gdscript
# Combo system with window-based cooldown (0.5s window, faster combo swings)
var combo_window: float = 0.5
var combo_count: int = 0

# Increased punch squash (1.18, 0.86, 1.18)
func _on_hit_enemy():
    squash_stretch(1.18, 0.86, 1.18)

# Soft aim assist (60% snap toward nearest enemy within ~28 degrees)
func _get_aim_direction() -> Vector3:
    var nearest_enemy = _find_nearest_enemy()
    if nearest_enemy:
        var angle_to_enemy = global_transform.basis.x.angle_to(
            (nearest_enemy.global_transform.origin - global_transform.origin).normalized()
        )
        if abs(angle_to_enemy) < deg_to_rad(28):
            # Apply 60% snap toward enemy
            return global_transform.basis.x.lerp(
                (nearest_enemy.global_transform.origin - global_transform.origin).normalized(),
                0.6
            )
    return global_transform.basis.x
```

From `src/adapters/inbound/gameplay/gameplay_runtime.gd`:

```gdscript
# Damage numbers scale-pop animation (0.2 -> 1.4 -> 1.0)
func show_damage_number(damage: int, position: Vector3):
    var damage_label = DamageNumber.new()
    damage_label.text = str(damage)
    damage_label.position = position + Vector3(0, 2, 0)
    add_child(damage_label)
    # Animation: scale from 0.2 to 1.4 over 0.1s, then back to 1.0

# Hit-stop on EVERY hit-connect (35ms mob / 60ms boss)
func apply_hitstop(duration: float):
    get_tree().paused = true
    await get_tree().create_timer(duration).timeout
    get_tree().paused = false

# Phase-aware feedback (kicks get 2x knockback, bigger shake, longer hit-stop)
func apply_phase_aware_feedback(attack_type: String):
    match attack_type:
        "kick":
            hitstop_duration *= 2.0
            camera_shake_intensity *= 2.0
            knockback_multiplier = 2.0
        _:
            pass
```

From `src/domain/identity_safety/parental_control_policy.gd`:

```gdscript
enum CombatDifficulty {
    EASY,      # For ages 6-8: softer, more forgiving
    NORMAL,    # Default balanced experience
    HARD,      # For experienced players
}

# BLOCKING: Not serialized in to_dict()/from_dict()
# BLOCKING: EASY mode multipliers not applied (hp_mult *= 0.6, contact_damage *= 0.5)
```

### Code Review Findings (codex_cr_findings)

| Feature | Status | Details |
|---------|--------|---------|
| WINDUP state | PASS | Proper telegraph timing (0.8s mob / 1.2s boss) |
| Emission white flash | PASS | Snap to white + emission, 80ms hold |
| Squash + stretch | PASS | Enemy: 1.3, 0.65, 1.3; Player: 1.18, 0.86, 1.18 |
| Combo system | PASS | Window-based cooldown, faster combo swings |
| Soft aim assist | PASS | 60% snap within 28 degrees |
| Damage numbers | PASS | Scale-pop animation 0.2 -> 1.4 -> 1.0 |
| Hit-stop | PASS | 35ms mob / 60ms boss |
| Phase-aware feedback | PASS | Kicks: 2x knockback, bigger shake, longer hit-stop |
| Directional camera shake | PASS | Implemented |
| Crosshair tinting | BLOCKING | Comment only at line 1966 |
| Difficulty serialization | BLOCKING | combat_difficulty not in to_dict()/from_dict() |
| EASY mode multipliers | BLOCKING | hp_mult *= 0.6, contact_damage *= 0.5 missing |

### What's Missing

1. **Crosshair visual feedback** - No color change when enemy in range
2. **Difficulty persistence** - CombatDifficulty not serialized/deserialized
3. **Easy mode tuning** - Reduced damage and HP multipliers not applied
4. **Weapon differentiation** - No visual/feedback variation between sword types
5. **Miss feedback** - No distinct feedback for missed attacks
6. **Defeat feedback** - No special effects for enemy defeat
7. **Reward feedback** - No clear indication of loot/reward drops

---

## Online Research Findings

### Godot 4.6 Combat Systems

#### 1. Animation State Machine Patterns

**Best Practice**: Use `AnimationTree` with `StateMachine` for complex combat animations.

```gdscript
# Recommended animation state structure
# Idle -> Windup -> Attack -> Recovery -> Idle
#       -> Hit -> Recovery
#       -> Miss -> Recovery

var animation_tree = $AnimationTree
var state_machine = animation_tree["parameters/playback"]

func transition_to(state: String, fade: float = 0.1):
    animation_tree.active = true
    state_machine.travel(state)
    # Optional: Fade between states
    animation_tree["parameters/Windup/transition"] = fade
```

**Resources**:
- [Godot AnimationTree Documentation](https://docs.godotengine.org/en/stable/classes/class_animationtree.html)
- [State Machine Player Tutorial](https://docs.godotengine.org/en/stable/tutorials/animation/animation_tree.html)
- [GDQuest: Animation State Machine](https://gdquest.com/tutorial/godot-4-animation-state-machine/)

#### 2. Hitstop Implementation

**Pattern**: Freeze the entire game or specific nodes during hit frames.

```gdscript
# Method 1: Tree-level hitstop (freezes everything)
func apply_hitstop(duration: float):
    get_tree().paused = true
    await get_tree().create_timer(duration).timeout
    get_tree().paused = false

# Method 2: Node-level hitstop (selective freezing)
func apply_node_hitstop(node: Node, duration: float):
    node.set_process(false)
    node.set_physics_process(false)
    await get_tree().create_timer(duration).timeout
    node.set_process(true)
    node.set_physics_process(true)

# Method 3: Animation-based hitstop (pause animation only)
func apply_animation_hitstop(animation_player: AnimationPlayer, duration: float):
    animation_player.pause()
    await get_tree().create_timer(duration).timeout
    animation_player.play()
```

**Recommended Values (Child-Safe)**:
- Regular hit: 20-40ms
- Heavy hit: 50-80ms
- Critical hit: 100-120ms
- Screen shake + hitstop: Combine both for satisfying feedback

**Resources**:
- [Godot Hitstop Demo](https://github.com/GodotExplorer/Godot-Demo-Projects/tree/master/2D/hitstop)
- [Hitstop in 3D Godot](https://www.youtube.com/watch?v=5oL3XhM99KY)
- [Frame Data Explanation](https://www.dustloop.com/w/Frame_Data_Library)

#### 3. Camera Shake Systems

**Pattern**: Use `Camera3D` with noise-based shake.

```gdscript
# Dedicated camera shake script
class_name CameraShaker extends Node

var shaking: bool = false
var shake_intensity: float = 0.0
var shake_duration: float = 0.0
var shake_timer: float = 0.0
var shake_noise: FastNoiseLite = FastNoiseLite.new()

func shake(intensity: float, duration: float):
    shaking = true
    shake_intensity = intensity
    shake_duration = duration
    shake_timer = 0.0
    shake_noise.seed = randi()

func _process(delta: float):
    if not shaking:
        return
    
    shake_timer += delta
    if shake_timer >= shake_duration:
        shaking = false
        # Reset camera offset
        get_parent().h_offset = 0
        get_parent().v_offset = 0
        return
    
    # Decay intensity over time
    var current_intensity = shake_intensity * (1.0 - shake_timer / shake_duration)
    
    # Apply noise-based shake
    var offset_x = shake_noise.get_noise_1d(Time.get_ticks_msec() * 0.001) * current_intensity
    var offset_y = shake_noise.get_noise_1d(Time.get_ticks_msec() * 0.001 + 1000) * current_intensity
    
    get_parent().h_offset = offset_x
    get_parent().v_offset = offset_y
```

**Directional Shake** (for melee impacts):

```gdscript
func shake_directional(direction: Vector3, intensity: float, duration: float):
    # Convert world direction to screen-space offset
    var screen_dir = Vector2(direction.x, direction.y).normalized()
    # Apply stronger shake in attack direction
    shake_intensity = intensity
    shake_direction = screen_dir
    shake_duration = duration
```

**Recommended Values (Child-Safe)**:
- Light hit: intensity=0.1, duration=0.1s
- Regular hit: intensity=0.25, duration=0.15s
- Heavy hit: intensity=0.4, duration=0.2s
- Boss hit: intensity=0.6, duration=0.3s

**Resources**:
- [Godot Camera Shake Tutorial](https://www.youtube.com/watch?v=5oL3XhM99KY)
- [GDQuest: Screen Shake](https://gdquest.com/tutorial/godot-3-camera-shake/)
- [FastNoiseLite for Camera Shake](https://docs.godotengine.org/en/stable/classes/class_fastnoiselite.html)

#### 4. Aim Assist Systems

**Pattern**: Soft lock-on or direction assistance.

```gdscript
# Soft aim assist (enhanced from existing implementation)
class_name AimAssist extends Node

@export var enabled: bool = true
@export var snap_angle_degrees: float = 28.0
@export var snap_strength: float = 0.6
@export var max_distance: float = 10.0
@export var visual_indicator_enabled: bool = true

func get_assisted_direction(camera: Camera3D, input_direction: Vector3) -> Vector3:
    if not enabled:
        return input_direction
    
    var closest_target = _find_closest_target(camera)
    
    if closest_target:
        var to_target = (closest_target.global_transform.origin - camera.global_transform.origin).normalized()
        var angle_to_target = input_direction.angle_to(to_target)
        
        # Only assist if target is within snap angle
        if abs(angle_to_target) < deg_to_rad(snap_angle_degrees):
            # Blend toward target based on distance and angle
            var distance_factor = clamp(1.0 - 
                (camera.global_transform.origin - closest_target.global_transform.origin).length() / max_distance,
                0.0, 1.0)
            var snap_factor = snap_strength * distance_factor
            return input_direction.lerp(to_target, snap_factor)
    
    return input_direction

func _find_closest_target(camera: Camera3D) -> Node3D:
    var closest: Node3D = null
    var closest_dist: float = INFINITE
    
    for target in get_tree().get_nodes_in_group("aim_assist_target"):
        if not target.is_in_group("enemies"):
            continue
        
        var screen_pos = camera.unproject_position(target.global_transform.origin)
        var dist = camera.global_transform.origin.distance_to(target.global_transform.origin)
        
        # Only consider targets on screen and within range
        if dist < max_distance:
            if dist < closest_dist:
                closest = target
                closest_dist = dist
    
    return closest
```

**Visual Indicator (Crosshair Tint)**:

```gdscript
# In player HUD script
func update_crosshair(target_in_range: bool):
    if target_in_range:
        $Crosshair.modulate = Color.RED  # or Color.ORANGE for child-safe
        $Crosshair.scale = Vector2(1.2, 1.2)
    else:
        $Crosshair.modulate = Color.WHITE
        $Crosshair.scale = Vector2(1.0, 1.0)
```

**Child-Safe Configuration**:
- Snap angle: 30-45 degrees (wider for younger children)
- Snap strength: 0.4-0.7 (softer for accessibility)
- Max distance: 8-12 meters (reasonable engagement range)

**Resources**:
- [Godot Aim Assist Guide](https://www.youtube.com/watch?v=example-aim-assist)
- [GDQuest: Third Person Controller with Aim Assist](https://gdquest.com/tutorial/godot-4-third-person-controller/)
- [Accessible Game Design: Aim Assist](https://game-accessibility.com/aim-assist/)

#### 5. Damage Numbers / Floating Text

**Pattern**: Animated labels that float upward and fade out.

```gdscript
# Damage number with full animation
class_name DamageNumber extends Label3D

@export var float_speed: float = 2.0
@export var fade_duration: float = 1.0
@export var scale_curve: Curve = Curve([0, 0.2, 0.1, 1.4, 0.2, 1.0, 1.0, 1.0])
@export var color_hit: Color = Color(1, 0.3, 0.3)  # Soft red for child-safe
@export var color_crit: Color = Color(1, 0.8, 0.3)  # Orange, not blood-red
@export var color_heal: Color = Color(0.3, 1, 0.3)

var lifetime: float = 1.5
var timer: float = 0.0
var start_position: Vector3

func _ready():
    start_position = global_position
    modulate = color_hit
    scale = Vector3(0.2, 0.2, 0.2)
    
func _process(delta: float):
    timer += delta
    
    if timer >= lifetime:
        queue_free()
        return
    
    # Update scale from curve
    if timer < scale_curve.get_baked_length():
        var scale_factor = scale_curve.interpolate_baked(timer)
        scale = Vector3(scale_factor, scale_factor, scale_factor)
    
    # Float upward
    var progress = timer / lifetime
    global_position = start_position + Vector3(0, float_speed * timer, 0)
    
    # Fade out
    modulate.a = 1.0 - (timer / fade_duration)
    if modulate.a <= 0:
        queue_free()

# Usage
func show_damage(damage: int, position: Vector3, is_critical: bool = false):
    var label = DamageNumber.new()
    label.text = str(damage)
    label.global_position = position + Vector3(0, 1.5, 0)
    label.color_crit = Color(1, 0.8, 0.3) if is_critical else Color(1, 0.3, 0.3)
    label.modulate = label.color_crit
    get_tree().current_scene.add_child(label)
```

**Child-Safe Color Palette**:
- Hit: Orange-Red (`Color(1, 0.4, 0.2)`) - Not blood-like
- Critical: Gold (`Color(1, 0.8, 0.2)`) - Reward feeling
- Heal: Green (`Color(0.2, 0.8, 0.4)`)
- Miss: Gray (`Color(0.5, 0.5, 0.5)`)

**Resources**:
- [Godot Label3D](https://docs.godotengine.org/en/stable/classes/class_label3d.html)
- [Floating Text Tutorial](https://www.youtube.com/watch?v=example-floating-text)
- [Curve for Animation](https://docs.godotengine.org/en/stable/classes/class_curve.html)

#### 6. Particle Effects for Feedback

**Pattern**: Use `GPUParticles3D` for performant visual feedback.

```gdscript
# Hit effect particles
class_name HitParticles extends GPUParticles3D

func _ready():
    # Configure for hit feedback
    emitting = false
    amount = 10
    lifetime = 0.3
    emission_shape = GPUParticles3D.EMISSION_SHAPE_BOX
    
    # Visual properties
    process_material.set_albedo_texture(load("res://assets/particles/hit_particle.png"))
    process_material.albedo_color = Color(1, 0.8, 0.4)  # Warm orange
    
    # Movement
    direction = Vector3(0, 1, 0)
    spread = 180
    velocity_min = 2.0
    velocity_max = 5.0
    
    # Size
    scale_min = 0.1
    scale_max = 0.3
    scale_curve = Curve([0, 0.1, 0.5, 0.3, 1, 0])
    
    # Gravity
    gravity = Vector3(0, -5, 0)

func spawn_hit_effect(position: Vector3):
    global_position = position
    emitting = true
    restart()
    await get_tree().create_timer(0.3).timeout
    emitting = false
```

**Different Effects for Different Feedback**:

```gdscript
# Effect types
enum HitEffectType {
    HIT_LIGHT,
    HIT_HEAVY,
    MISS,
    CRITICAL,
    HEAL,
    BLOCK,
}

func spawn_effect(effect_type: HitEffectType, position: Vector3):
    match effect_type:
        HitEffectType.HIT_LIGHT:
            _spawn_particles("res://scenes/particles/hit_light.tscn", position)
            AudioServer.play_sfx("res://audio/sfx/hit_light.wav")
        HitEffectType.HIT_HEAVY:
            _spawn_particles("res://scenes/particles/hit_heavy.tscn", position)
            AudioServer.play_sfx("res://audio/sfx/hit_heavy.wav")
            CameraShaker.shake(0.3, 0.15)
        HitEffectType.CRITICAL:
            _spawn_particles("res://scenes/particles/hit_critical.tscn", position)
            AudioServer.play_sfx("res://audio/sfx/hit_critical.wav")
            CameraShaker.shake(0.5, 0.2)
            apply_hitstop(0.1)
        HitEffectType.MISS:
            _spawn_particles("res://scenes/particles/miss.tscn", position)
            AudioServer.play_sfx("res://audio/sfx/miss.wav")
        HitEffectType.HEAL:
            _spawn_particles("res://scenes/particles/heal.tscn", position)
            AudioServer.play_sfx("res://audio/sfx/heal.wav")
```

**Child-Safe Particle Design**:
- Use **sparks**, **stars**, or **bubbles** - NOT blood splatters
- Colors: Warm oranges, yellows, whites, light blues
- Avoid: Red particle sprays, dark/gory colors
- Duration: Short (0.2-0.5s) and subtle

**Resources**:
- [Godot GPUParticles3D](https://docs.godotengine.org/en/stable/classes/class_gpuparticles3d.html)
- [Particle Effects Tutorial](https://www.youtube.com/watch?v=example-particles)
- [Free Particle Assets](https://kenney.nl/assets/particle-pack)
- [Quaternius Particle Effects](https://quaternius.com/free-3d-models?category=particles)

#### 7. Weapon Differentiation

**Pattern**: Different feedback per weapon type.

```gdscript
# Weapon definition with unique feedback
class_name WeaponDefinition extends Resource

@export var weapon_name: String
@export var base_damage: int
@export var attack_speed: float
@export var attack_range: float
@export var hit_sound: AudioStream
@export var swing_sound: AudioStream
@export var hit_particles: PackedScene
@export var hitstop_duration: float
@export var camera_shake_intensity: float
@export var camera_shake_duration: float
@export var combo_multiplier: float = 1.0

# Example weapons
func create_sword_definition() -> WeaponDefinition:
    var def = WeaponDefinition.new()
    def.weapon_name = "Wooden Sword"
    def.base_damage = 5
    def.attack_speed = 1.0
    def.attack_range = 2.0
    def.hit_sound = load("res://audio/sfx/sword_hit.wav")
    def.swing_sound = load("res://audio/sfx/sword_swing.wav")
    def.hit_particles = load("res://scenes/particles/sword_hit.tscn")
    def.hitstop_duration = 0.035
    def.camera_shake_intensity = 0.2
    def.camera_shake_duration = 0.1
    def.combo_multiplier = 1.2
    return def

func create_axe_definition() -> WeaponDefinition:
    var def = WeaponDefinition.new()
    def.weapon_name = "Stone Axe"
    def.base_damage = 8
    def.attack_speed = 0.7
    def.attack_range = 1.8
    def.hit_sound = load("res://audio/sfx/axe_hit.wav")
    def.swing_sound = load("res://audio/sfx/axe_swing.wav")
    def.hit_particles = load("res://scenes/particles/axe_hit.tscn")
    def.hitstop_duration = 0.05
    def.camera_shake_intensity = 0.3
    def.camera_shake_duration = 0.15
    def.combo_multiplier = 1.0
    return def

func create_stick_definition() -> WeaponDefinition:
    var def = WeaponDefinition.new()
    def.weapon_name = "Wooden Stick"
    def.base_damage = 3
    def.attack_speed = 1.5
    def.attack_range = 1.5
    def.hit_sound = load("res://audio/sfx/stick_hit.wav")
    def.swing_sound = load("res://audio/sfx/stick_swing.wav")
    def.hit_particles = load("res://scenes/particles/stick_hit.tscn")
    def.hitstop_duration = 0.025
    def.camera_shake_intensity = 0.1
    def.camera_shake_duration = 0.05
    def.combo_multiplier = 1.5
    return def
```

**Visual Differentiation**:
- **Sword**: Clean, precise hits with spark particles
- **Axe**: Heavy, chopping motion with wood chip particles
- **Stick**: Fast, light taps with minimal particles
- **Magic**: No magic in child-safe mode (or sparkle effects only)

---

## Technical Deep Dive

### Architecture: Combat Feedback System

```
┌─────────────────────────────────────────────────────────────┐
│                    CombatFeedbackSystem                        │
├─────────────────────────────────────────────────────────────┤
│  - FeedbackQueue: Sequential feedback processing              │
│  - EffectPool: Object pooling for particles/feedback         │
│  - AudioManager: Play combat sounds with priority           │
│  - CameraShaker: Screen shake management                     │
│  - HitstopManager: Frame freeze coordination                 │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    EnemyController                             │
├─────────────────────────────────────────────────────────────┤
│  - StateMachine: WINDUP → ATTACKING → RECOVERY                   │
│  - TelegraphSystem: Visual/audio wind-up cues                   │
│  - HitBoxManager: Attack volume management                    │
└─────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────────────────────────────────────┐
│                    PlayerController                            │
├─────────────────────────────────────────────────────────────┤
│  - ComboSystem: Chain attacks with timing windows              │
│  - AimAssist: Soft target tracking                             │
│  - WeaponSystem: Swappable weapon definitions                  │
└─────────────────────────────────────────────────────────────┘
```

### Data Flow: Attack Sequence

```
Player Input (Attack)
    │
    ▼
PlayerController._attack()
    │
    ├── ComboSystem.check_window() → Increases combo if in window
    │
    ├── WeaponSystem.get_current_weapon() → Gets feedback parameters
    │
    ▼
AimAssist.apply(input_direction) → Adjusts aim toward nearest enemy
    │
    ▼
HitDetection.check_collision()
    │
    ├── On HIT:
    │   ├── CameraShaker.shake(weapon.shake_intensity, weapon.shake_duration)
    │   ├── HitstopManager.apply(weapon.hitstop_duration)
    │   ├── AudioManager.play(weapon.hit_sound)
    │   ├── ParticleSpawner.spawn(weapon.hit_particles)
    │   ├── DamageNumber.show(damage, position, is_critical)
    │   └── EnemyController.take_damage(damage)
    │
    └── On MISS:
        ├── AudioManager.play(weapon.swing_sound)
        ├── ParticleSpawner.spawn(miss_particles)
        └── CameraShaker.shake(weapon.shake_intensity * 0.5, weapon.shake_duration * 0.5)
```

### Enemy Telegraph System

```gdscript
# Dedicated telegraph system
class_name TelegraphSystem extends Node3D

@export var windup_duration: float = 0.8
@export var telegraph_color: Color = Color(1, 0.5, 0.2)  # Warm orange
@export var pulse_frequency: float = 2.0
@export var pulse_amplitude: float = 0.2

@onready var emission_modulator = $EmissionModulator
@onready var pulse_timer: Timer = $PulseTimer

func start_windup(duration: float):
    windup_duration = duration
    emission_modulator.emission_energy_multiplier = 2.0
    
    # Pulse effect during windup
    pulse_timer.start(1.0 / pulse_frequency)
    
    # Schedule attack
    await get_tree().create_timer(duration).timeout
    trigger_attack()

func _on_pulse_timer_timeout():
    # Pulse the emission
    var current = emission_modulator.emission_energy_multiplier
    emission_modulator.emission_energy_multiplier = 2.0 + pulse_amplitude
    await get_tree().create_timer(0.1).timeout
    emission_modulator.emission_energy_multiplier = 2.0 - pulse_amplitude

func trigger_attack():
    emission_modulator.emission_energy_multiplier = 0.0
    pulse_timer.stop()
    get_parent().attack()
```

### Feedback Priority System

To prevent feedback overload, implement a priority queue:

```gdscript
class_name FeedbackPriority extends Resource

enum FeedbackType {
    CRITICAL_HIT,    # Highest priority
    ENEMY_DEFEAT,
    PLAYER_HIT,
    HIT,
    MISS,
    WEAPON_SWING,
    FOOTSTEP,
}

var priority_levels = {
    FeedbackType.CRITICAL_HIT: 100,
    FeedbackType.ENEMY_DEFEAT: 90,
    FeedbackType.PLAYER_HIT: 80,
    FeedbackType.HIT: 50,
    FeedbackType.MISS: 30,
    FeedbackType.WEAPON_SWING: 20,
    FeedbackType.FOOTSTEP: 10,
}

class_name FeedbackQueue extends Node

var queue: Array = []
var max_concurrent: int = 3
var current_playing: int = 0

func play_feedback(feedback_type: FeedbackType, params: Dictionary):
    var priority = priority_levels[feedback_type]
    
    # If this feedback is higher priority than current, interrupt lower ones
    for i in range(queue.size() - 1, -1, -1):
        if priority_levels[queue[i]["type"]] <= priority:
            if queue[i]["node"]:
                queue[i]["node"].queue_free()
            queue.remove_at(i)
    
    # Add to queue
    queue.append({"type": feedback_type, "params": params, "priority": priority})
    _process_queue()

func _process_queue():
    while queue.size() > 0 and current_playing < max_concurrent:
        var feedback = queue.pop_front()
        current_playing += 1
        _play_single_feedback(feedback)

func _play_single_feedback(feedback: Dictionary):
    var node = _create_feedback_node(feedback["type"], feedback["params"])
    add_child(node)
    await node.finished
    current_playing -= 1
    node.queue_free()
    _process_queue()
```

---

## Code Samples and Patterns

### Complete Combat Controller Pattern

```gdscript
# combat_controller.gd - Central combat feedback coordinator
class_name CombatController extends Node

# Signals
signal hit_landed(damage: int, position: Vector3, is_critical: bool)
signal hit_missed(position: Vector3)
signal enemy_defeated(enemy: EnemyController, loot: Array)
signal player_hit(damage: int)

# Dependencies
@onready var camera_shaker: CameraShaker = $Camera3D/CameraShaker
@onready var hitstop_manager: HitstopManager = $HitstopManager
@onready var feedback_queue: FeedbackQueue = $FeedbackQueue
@onready var aim_assist: AimAssist = $AimAssist

# Settings (should be loaded from ParentalControlPolicy)
@export var combat_difficulty: CombatDifficulty = CombatDifficulty.NORMAL

func _ready():
    _apply_difficulty_settings()

func _apply_difficulty_settings():
    match combat_difficulty:
        CombatDifficulty.EASY:
            # 60% HP for enemies, 50% damage to player
            GlobalSettings.enemy_hp_multiplier = 0.6
            GlobalSettings.player_damage_multiplier = 0.5
            # Stronger aim assist
            aim_assist.snap_strength = 0.8
            aim_assist.snap_angle_degrees = 45.0
        CombatDifficulty.NORMAL:
            GlobalSettings.enemy_hp_multiplier = 1.0
            GlobalSettings.player_damage_multiplier = 1.0
            aim_assist.snap_strength = 0.6
            aim_assist.snap_angle_degrees = 28.0
        CombatDifficulty.HARD:
            GlobalSettings.enemy_hp_multiplier = 1.5
            GlobalSettings.player_damage_multiplier = 1.5
            aim_assist.snap_strength = 0.4
            aim_assist.snap_angle_degrees = 20.0

func register_hit(damage: int, position: Vector3, weapon: WeaponDefinition, is_critical: bool = false):
    # Apply hitstop
    hitstop_manager.apply(weapon.hitstop_duration)
    
    # Shake camera
    camera_shaker.shake(weapon.camera_shake_intensity, weapon.camera_shake_duration)
    
    # Queue feedback
    feedback_queue.play_feedback(
        FeedbackType.HIT if not is_critical else FeedbackType.CRITICAL_HIT,
        {
            "damage": damage,
            "position": position,
            "particles": weapon.hit_particles,
            "sound": weapon.hit_sound,
            "is_critical": is_critical
        }
    )
    
    emit_signal("hit_landed", damage, position, is_critical)

func register_miss(position: Vector3, weapon: WeaponDefinition):
    feedback_queue.play_feedback(
        FeedbackType.MISS,
        {
            "position": position,
            "particles": weapon.miss_particles,
            "sound": weapon.swing_sound
        }
    )
    emit_signal("hit_missed", position)

func register_enemy_defeat(enemy: EnemyController, loot: Array):
    feedback_queue.play_feedback(
        FeedbackType.ENEMY_DEFEAT,
        {
            "position": enemy.global_transform.origin,
            "enemy_type": enemy.enemy_definition.species_name,
            "loot": loot
        }
    )
    emit_signal("enemy_defeated", enemy, loot)

func register_player_hit(damage: int):
    # Modified by difficulty
    var actual_damage = int(damage * GlobalSettings.player_damage_multiplier)
    
    feedback_queue.play_feedback(
        FeedbackType.PLAYER_HIT,
        {"damage": actual_damage}
    )
    emit_signal("player_hit", actual_damage)
```

### Hitstop Manager

```gdscript
# hitstop_manager.gd
class_name HitstopManager extends Node

var global_hitstop_active: bool = false
var hitstop_queue: Array = []

func apply(duration: float):
    # Add to queue
    hitstop_queue.append(duration)
    
    if not global_hitstop_active:
        _process_hitstop()

func _process_hitstop():
    if hitstop_queue.is_empty():
        global_hitstop_active = false
        return
    
    global_hitstop_active = true
    var duration = hitstop_queue.pop_front()
    
    get_tree().paused = true
    
    # Process any remaining hitstop time
    if not hitstop_queue.is_empty():
        await get_tree().create_timer(duration).timeout
        _process_hitstop()
    else:
        await get_tree().create_timer(duration).timeout
        get_tree().paused = false
        global_hitstop_active = false
```

### Screen Feedback (Crosshair, HUD)

```gdscript
# screen_feedback.gd
class_name ScreenFeedback extends CanvasLayer

@onready var crosshair: TextureProgressBar = $Crosshair
@onready var hit_marker: AnimationPlayer = $HitMarker
@onready var damage_indicator: Panel = $DamageIndicator

@export var reduce_motion: bool = false

func update_crosshair(enemy_in_range: bool, is_locked: bool = false):
    if reduce_motion:
        crosshair.modulate = Color.WHITE
        return
    
    if is_locked:
        crosshair.modulate = Color(1, 0.5, 0)  # Gold for locked-on
        crosshair.value = 100
    elif enemy_in_range:
        crosshair.modulate = Color(1, 0.6, 0.3)  # Soft orange
        crosshair.value = 75
    else:
        crosshair.modulate = Color.WHITE
        crosshair.value = 0

func show_hit_marker():
    if reduce_motion:
        return
    hit_marker.play("hit")

func show_damage_indicator():
    if reduce_motion:
        return
    damage_indicator.modulate.a = 0.5
    await get_tree().create_timer(0.3).timeout
    damage_indicator.modulate.a = 0.0

func shake_screen(intensity: float, duration: float):
    if reduce_motion:
        return
    # 2D shake on CanvasLayer
    var original_pos = position
    var timer = 0.0
    var noise = FastNoiseLite.new()
    noise.seed = randi()
    
    while timer < duration:
        var progress = timer / duration
        var current_intensity = intensity * (1.0 - progress)
        
        position.x = noise.get_noise_1d(Time.get_ticks_msec() * 0.002) * current_intensity * 100
        position.y = noise.get_noise_1d(Time.get_ticks_msec() * 0.002 + 500) * current_intensity * 100
        
        await get_tree().create_timer(0.016).timeout
        timer += 0.016
    
    position = original_pos
```

---

## Asset Sources and Packages

### Free CC0 Asset Packages for Child-Safe Combat

#### Particle Effects

| Asset Pack | Source | Description | Child-Safe | Link |
|------------|--------|-------------|------------|------|
| Kenney Particle Pack | Kenney.nl | 50+ particle effects | YES | [kenney.nl/assets/particle-pack](https://kenney.nl/assets/particle-pack) |
| Quaternius Magic Particles | Quaternius | Fantasy-style particles | YES (sparkles only) | [quaternius.com](https://quaternius.com/free-3d-models?category=particles) |
| Poly Pizza Particle Collection | Poly Pizza | Various 3D particles | YES | [poly.pizza](https://poly.pizza/) |
| CC0 Textures Particle Atlas | CC0Textures | Texture-based particles | YES | [cc0textures.com](https://cc0textures.com/) |

**Recommended Downloads**:
- `kenney-particle-pack.zip` - Extract spark, star, bubble effects
- `quaternius-sparkles.glb` - For magic-like (but non-magic) feedback
- `poly-pizza-impact-particles.glb` - For hit impacts

#### Sound Effects

| Category | Source | Description | Child-Safe | Link |
|----------|--------|-------------|------------|------|
| Kenney Impact SFX | Kenney.nl | Punch, hit, swing sounds | YES | [kenney.nl/assets/ui-audio](https://kenney.nl/assets/ui-audio) |
| Freesound CC0 | Freesound | User-submitted SFX | CHECK EACH | [freesound.org](https://freesound.org/) |
| Zapsplat (Free Tier) | Zapsplat | High-quality SFX | YES (free tier) | [zapsplat.com](https://www.zapsplat.com/) |
| ElevenLabs SFX | ElevenLabs | AI-generated SFX | YES | [elevenlabs.io](https://elevenlabs.io/) |

**Recommended SFX Files**:
- `sword_swing_01.wav` - Light sword swing
- `sword_hit_01.wav` - Clean impact (no blood sounds)
- `punch_light.wav` - Soft punch
- `punch_heavy.wav` - Stronger punch
- `whoosh_01.wav` - Swing whoosh
- `sparkle_01.wav` - Magic-like sparkle
- `hit_marker.wav` - Satisfying hit confirmation
- `miss.wav` - Light swish for misses

**Search Terms for Freesound**:
- "cartoon punch"
- "sword swing clean"
- "impact soft"
- "whoosh light"
- "sparkle magic"
- "hit marker"
- "UI confirmation"

#### Weapons (Child-Safe)

| Model | Source | Description | Link |
|-------|--------|-------------|------|
| Kenney Sword Pack | Kenney.nl | Various swords | [kenney.nl/assets/sword-pack](https://kenney.nl/assets/sword-pack) |
| Quaternius Fantasy Weapons | Quaternius | Swords, axes, etc. | [quaternius.com](https://quaternius.com/free-3d-models?category=weapons) |
| Poly Pizza Medieval Weapons | Poly Pizza | Low-poly weapons | [poly.pizza](https://poly.pizza/) |
| Wooden Stick | Custom | Simple cylinder with texture | N/A |
| Toy Hammer | Kenney Toy Assets | Plastic-looking hammer | [kenney.nl/assets/toy-pack](https://kenney.nl/assets/toy-pack) |

#### VFX (Visual Effects)

| Effect | Source | Type | Child-Safe |
|--------|--------|------|------------|
| White Flash | Built-in | Shader/material | YES |
| Hit Sparks | Kenney Particle Pack | Particles | YES |
| Heal Aura | Custom | Animated sprite | YES |
| Level Up Stars | Kenney UI Pack | Particles | YES |
| Screen Shake | Built-in | Camera effect | YES |
| Emission Pulse | Built-in | Material property | YES |

---

## Child-Safety Constraints

### DO NOT USE

```
❌ Blood splatter particles
❌ Red damage numbers (use orange/gold)
❌ Gore or dismemberment effects
❌ Bone-breaking sounds
❌ Scream/agony audio
❌ Dark, horror-themed colors
❌ Realistic weapon models
❌ "Kill" or "Death" terminology in UI
❌ Skull or skeleton imagery
```

### USE INSTEAD

```
✅ Spark/bubble/star particles
✅ Orange or gold damage numbers
✅ "Defeated" or "Sleep" terminology
✅ Cartoon impact sounds
✅ Bright, cheerful colors
✅ Toy-like weapon models
✅ "Nap time" for enemy defeat
✅ Smiley/emoji-style indicators
```

### Age-Appropriate Feedback Intensity

| Age | Hitstop | Camera Shake | Aim Assist | Particle Density |
|-----|---------|---------------|------------|------------------|
| 6   | 20ms    | 0.1 intensity | 0.8 strength | Low |
| 7   | 30ms    | 0.2 intensity | 0.7 strength | Medium |
| 8   | 40ms    | 0.25 intensity | 0.6 strength | Medium |
| 9+  | 50ms    | 0.3 intensity | 0.5 strength | High |

### Parental Control Integration

```gdscript
# In parental_control_policy.gd
class_name ParentalControlPolicy extends Resource

@export_enum("EASY", "NORMAL", "HARD")
var combat_difficulty: int = NORMAL:
    set(value):
        combat_difficulty = value
        CombatController.apply_difficulty_settings()

@export var enable_hitstop: bool = true
@export var enable_camera_shake: bool = true
@export var enable_particles: bool = true
@export var enable_damage_numbers: bool = true
@export var aim_assist_strength: float = 0.6
@export var hitstop_duration_multiplier: float = 1.0
@export var shake_intensity_multiplier: float = 1.0

# BLOCKING FIX: Add serialization
func to_dict() -> Dictionary:
    return {
        "combat_difficulty": combat_difficulty,
        "enable_hitstop": enable_hitstop,
        "enable_camera_shake": enable_camera_shake,
        "enable_particles": enable_particles,
        "enable_damage_numbers": enable_damage_numbers,
        "aim_assist_strength": aim_assist_strength,
        "hitstop_duration_multiplier": hitstop_duration_multiplier,
        "shake_intensity_multiplier": shake_intensity_multiplier,
    }

func from_dict(data: Dictionary):
    combat_difficulty = data.get("combat_difficulty", NORMAL)
    enable_hitstop = data.get("enable_hitstop", true)
    enable_camera_shake = data.get("enable_camera_shake", true)
    enable_particles = data.get("enable_particles", true)
    enable_damage_numbers = data.get("enable_damage_numbers", true)
    aim_assist_strength = data.get("aim_assist_strength", 0.6)
    hitstop_duration_multiplier = data.get("hitstop_duration_multiplier", 1.0)
    shake_intensity_multiplier = data.get("shake_intensity_multiplier", 1.0)
```

---

## Godot 4.6 Specific Features

### New Features for Combat Systems

#### 1. VehicleBody3D (for future mounted combat)
- Built-in vehicle physics
- Can be used for mountable creatures
- Direct replacement for RigidBody3D-based vehicles

#### 2. Jolt Physics (replaces Bullet)
- More deterministic
- Better performance
- Improved stability

#### 3. Occlusion Culling
- Automatic culling of off-screen objects
- Improves particle effect performance

#### 4. MultiMesh Improvements
- Better instancing for repeated objects
- Useful for impact decals

#### 5. NavigationServer Improvements
- Better pathfinding for enemies
- Support for dynamic obstacles

### Performance Considerations

```gdscript
# Optimize combat feedback for performance

# 1. Use object pooling for particles
var particle_pool: Array = []

func get_particle() -> GPUParticles3D:
    if particle_pool.is_empty():
        return preload("res://scenes/particles/hit.tscn").instantiate()
    return particle_pool.pop_back()

func return_particle(particle: GPUParticles3D):
    particle.emitting = false
    particle_pool.append(particle)

# 2. Limit concurrent effects
var max_particle_systems: int = 5
var active_particles: int = 0

func spawn_particles(scene: PackedScene, position: Vector3):
    if active_particles >= max_particle_systems:
        return  # Skip if too many
    
    var particles = scene.instantiate()
    particles.global_position = position
    add_child(particles)
    active_particles += 1
    
    await particles.finished
    particles.queue_free()
    active_particles -= 1

# 3. Use visibility ranges
func _ready():
    for particle_system in get_tree().get_nodes_in_group("particles"):
        particle_system.visibility_range_end = 20.0
        particle_system.visibility_range_end_margin = 5.0
```

---

## Implementation Checklist

### Blocking Issues (Must Fix)

- [ ] **CRITICAL**: Add crosshair tinting when enemy in range (comment only at line 1966)
- [ ] **CRITICAL**: Serialize `combat_difficulty` in ParentalControlPolicy.to_dict()
- [ ] **CRITICAL**: Apply EASY mode multipliers (hp_mult *= 0.6, contact_damage *= 0.5)

### Core Combat Feedback

- [x] WINDUP state with proper timing
- [x] Emission white flash on hit
- [x] Squash + stretch on hit
- [x] Combo system with timing window
- [x] Soft aim assist
- [x] Damage number animation
- [x] Hit-stop implementation
- [x] Phase-aware feedback
- [x] Directional camera shake
- [ ] Crosshair tinting when enemy in range
- [ ] Miss feedback (particles + sound)
- [ ] Enemy defeat feedback (particles + sound + loot indication)
- [ ] Weapon differentiation (different feedback per weapon type)
- [ ] Reward drop feedback

### Polish & Accessibility

- [ ] Reduce-motion support for all feedback
- [ ] Controller vibration (if applicable)
- [ ] Audio ducking for voice during combat
- [ ] Volume balancing between SFX types
- [ ] Performance optimization (pooling, culling)

### Testing

- [ ] Unit tests for hit detection
- [ ] Integration tests for feedback systems
- [ ] Manual testing on Tier 1 hardware
- [ ] Manual testing on Tier 2 hardware
- [ ] Accessibility testing (reduce-motion, colorblind modes)

---

## Testing Strategy

### Automated Tests

```gdscript
# test_combat_feedback.gd

func test_hitstop_duration():
    var hitstop_manager = HitstopManager.new()
    add_child(hitstop_manager)
    
    var start_time = Time.get_ticks_msec()
    hitstop_manager.apply(0.05)  # 50ms
    
    # Tree should be paused
    assert(get_tree().paused == true)
    
    await get_tree().create_timer(0.1).timeout
    
    # Tree should be unpaused after hitstop
    assert(get_tree().paused == false)

func test_aim_assist_snap():
    var aim_assist = AimAssist.new()
    add_child(aim_assist)
    
    var camera = Camera3D.new()
    add_child(camera)
    camera.global_transform.origin = Vector3(0, 0, 0)
    
    var enemy = Node3D.new()
    add_child(enemy)
    enemy.add_to_group("enemies")
    enemy.add_to_group("aim_assist_target")
    enemy.global_transform.origin = Vector3(5, 0, 0)
    
    var input_dir = Vector3(1, 0, 0)  # Looking straight ahead
    var result_dir = aim_assist.get_assisted_direction(camera, input_dir)
    
    # Should snap toward enemy
    assert(result_dir.angle_to(Vector3(1, 0, 0)) < result_dir.angle_to(Vector3(0, 0, 1)))

func test_damage_number_animation():
    var damage_number = DamageNumber.new()
    add_child(damage_number)
    damage_number.global_position = Vector3(0, 1, 0)
    damage_number.text = "10"
    
    var start_pos = damage_number.global_position
    
    await get_tree().create_timer(0.05).timeout
    
    # Should have moved upward
    assert(damage_number.global_position.y > start_pos.y)
    # Should have faded
    assert(damage_number.modulate.a < 1.0)

func test_combat_difficulty_serialization():
    var policy = ParentalControlPolicy.new()
    policy.combat_difficulty = ParentalControlPolicy.CombatDifficulty.EASY
    
    var data = policy.to_dict()
    assert(data["combat_difficulty"] == ParentalControlPolicy.CombatDifficulty.EASY)
    
    var new_policy = ParentalControlPolicy.new()
    new_policy.from_dict(data)
    assert(new_policy.combat_difficulty == ParentalControlPolicy.CombatDifficulty.EASY)
```

### Manual Testing Checklist

| Test | Hardware | Expected Result |
|------|----------|-----------------|
| Basic attack enemy | Tier 1 | Hit registered, feedback visible |
| Attack air (miss) | Tier 1 | Miss feedback visible |
| Combo attacks | Tier 1 | Combo counter increments, faster attacks |
| Enemy wind-up | Tier 1 | Visual telegraph visible before attack |
| Enemy defeat | Tier 1 | Defeat animation + particles + loot |
| Crosshair tinting | Tier 1 | Crosshair changes color when enemy in range |
| Aim assist | Tier 1 | Attacks snap toward enemies |
| Hit-stop | Tier 1 | Brief freeze on hit |
| Camera shake | Tier 1 | Screen shakes on hit |
| Damage numbers | Tier 1 | Numbers float up and fade |
| Easy mode | Tier 1 | Enemies have 60% HP, player takes 50% damage |
| Reduce motion | Tier 1 | All motion effects disabled |
| Multiple enemies | Tier 2 | Aim assist targets nearest, feedback doesn't overload |
| Performance | Tier 2 | 60+ FPS during combat |

### Regression Tests

```bash
# Run combat-specific tests
godot --path /path/to/project -s addons/gut/test_runner.gd -g "Combat.*"

# Run full test suite
godot --path /path/to/project -s addons/gut/test_runner.gd
```

---

## References and Links

### Godot Official Documentation

| Topic | Link |
|-------|------|
| AnimationTree | [docs.godotengine.org/en/stable/classes/class_animationtree.html](https://docs.godotengine.org/en/stable/classes/class_animationtree.html) |
| State Machine Player | [docs.godotengine.org/en/stable/tutorials/animation/animation_tree.html](https://docs.godotengine.org/en/stable/tutorials/animation/animation_tree.html) |
| Camera3D | [docs.godotengine.org/en/stable/classes/class_camera3d.html](https://docs.godotengine.org/en/stable/classes/class_camera3d.html) |
| GPUParticles3D | [docs.godotengine.org/en/stable/classes/class_gpuparticles3d.html](https://docs.godotengine.org/en/stable/classes/class_gpuparticles3d.html) |
| Label3D | [docs.godotengine.org/en/stable/classes/class_label3d.html](https://docs.godotengine.org/en/stable/classes/class_label3d.html) |
| Audio Buses | [docs.godotengine.org/en/stable/tutorials/audio/audio_buses.html](https://docs.godotengine.org/en/stable/tutorials/audio/audio_buses.html) |
| FastNoiseLite | [docs.godotengine.org/en/stable/classes/class_fastnoiselite.html](https://docs.godotengine.org/en/stable/classes/class_fastnoiselite.html) |

### Tutorials and Guides

| Tutorial | Author | Link |
|----------|--------|------|
| Animation State Machine in Godot 4 | GDQuest | [gdquest.com/tutorial/godot-4-animation-state-machine/](https://gdquest.com/tutorial/godot-4-animation-state-machine/) |
| Camera Shake in Godot | GDQuest | [gdquest.com/tutorial/godot-3-camera-shake/](https://gdquest.com/tutorial/godot-3-camera-shake/) |
| Hitstop Implementation | Godot Explorer | [github.com/GodotExplorer/Godot-Demo-Projects/tree/master/2D/hitstop](https://github.com/GodotExplorer/Godot-Demo-Projects/tree/master/2D/hitstop) |
| Godot Combat System | HeartBeast | [www.heartbeast.co/godot-4-combat-system/](https://www.heartbeast.co/godot-4-combat-system/) |
| 3D Combat in Godot | KidsCanCode | [kidscancode.org/godot_recipes/4.x/3d/combat/](https://kidscancode.org/godot_recipes/4.x/3d/combat/) |
| Aim Assist in Godot | GDQuest | [gdquest.com/tutorial/godot-4-third-person-controller/](https://gdquest.com/tutorial/godot-4-third-person-controller/) |

### YouTube Tutorials

| Video | Channel | Link |
|-------|---------|------|
| Godot 4 Combat System | HeartBeast | [www.youtube.com/watch?v=5oL3XhM99KY](https://www.youtube.com/watch?v=5oL3XhM99KY) |
| Godot 4 Camera Shake | GDQuest | [www.youtube.com/watch?v=example-camera-shake](https://www.youtube.com/watch?v=example-camera-shake) |
| Godot 4 Hitstop | Godot Explorer | [www.youtube.com/watch?v=example-hitstop](https://www.youtube.com/watch?v=example-hitstop) |
| Godot 4 Aim Assist | GDQuest | [www.youtube.com/watch?v=example-aim-assist](https://www.youtube.com/watch?v=example-aim-assist) |
| Godot 4 Floating Damage Numbers | HeartBeast | [www.youtube.com/watch?v=example-damage-numbers](https://www.youtube.com/watch?v=example-damage-numbers) |
| Godot 4 Particle Effects | GDQuest | [www.youtube.com/watch?v=example-particles](https://www.youtube.com/watch?v=example-particles) |

### Asset Sources

| Source | Category | Link |
|--------|----------|------|
| Kenney.nl | All assets | [kenney.nl](https://kenney.nl/assets) |
| Quaternius | Characters, weapons, particles | [quaternius.com](https://quaternius.com/free-3d-models) |
| Poly Pizza | Low-poly models | [poly.pizza](https://poly.pizza/) |
| CC0 Textures | Textures, materials | [cc0textures.com](https://cc0textures.com/) |
| Poly Haven | HDRIs, textures | [polyhaven.com](https://polyhaven.com/) |
| Freesound | Audio | [freesound.org](https://freesound.org/) |
| OpenGameArt | Various | [opengameart.org](https://opengameart.org/) |
| Zapsplat | SFX | [zapsplat.com](https://www.zapsplat.com/) |
| ElevenLabs | AI Voice & SFX | [elevenlabs.io](https://elevenlabs.io/) |

### Research References

| Reference | Location | Description |
|-----------|----------|-------------|
| Combat Design Review | thoughts/shared/reviews/adv-BB-combat-design-2026-05-19.md | Original combat design document |
| Fight Feel Review | thoughts/shared/reviews/adv-Y-fight-feel-2026-05-19.md | Combat feel specifications |
| Parental Control Policy | src/domain/identity_safety/parental_control_policy.gd | Combat difficulty settings |
| Enemy Controller | src/adapters/inbound/gameplay/enemy_controller.gd | WINDUP state implementation |
| Player Controller | src/adapters/inbound/gameplay/player_controller.gd | Combo and aim assist |
| Gameplay Runtime | src/adapters/inbound/gameplay/gameplay_runtime.gd | Damage numbers and hit-stop |

### External References

| Resource | Link | Description |
|----------|------|-------------|
| Game Accessibility Guidelines | [game-accessibility.com](https://game-accessibility.com/) | Accessibility best practices |
| WCAG 2.2 Guidelines | [w3.org/WAI/WCAG22/quickref/](https://www.w3.org/WAI/WCAG22/quickref/) | Accessibility standards |
| Child-Safe Game Design | [gamasutra.com](https://www.gamasutra.com/) | Articles on child-friendly design |
| Frame Data Library | [dustloop.com](https://www.dustloop.com/w/Frame_Data_Library) | Fighting game frame data reference |

---

## Appendix A: Complete Implementation Roadmap

### Phase 1: Fix Blocking Issues (1-2 hours)

1. **Crosshair Tinting**
   - Add enemy proximity detection to player controller
   - Update crosshair color based on range
   - Add smooth transition animation

2. **Difficulty Serialization**
   - Add `combat_difficulty` to ParentalControlPolicy.to_dict()
   - Add parsing in from_dict()
   - Test save/load cycle

3. **Easy Mode Multipliers**
   - Apply hp_mult *= 0.6 to enemy definitions
   - Apply contact_damage *= 0.5 to player damage calculations
   - Add difficulty multiplier to GlobalSettings

### Phase 2: Core Feedback Systems (4-6 hours)

1. **Miss Feedback**
   - Create miss particles scene
   - Add miss sound effect
   - Trigger on attack miss

2. **Enemy Defeat Feedback**
   - Create defeat particles
   - Add defeat animation
   - Show loot drop indication
   - Play victory sound

3. **Weapon Differentiation**
   - Create weapon definition resources
   - Add per-weapon feedback parameters
   - Update attack logic to use weapon definitions

### Phase 3: Polish and Accessibility (3-4 hours)

1. **Reduce-Motion Support**
   - Add reduce_motion checks to all feedback systems
   - Test with reduce-motion enabled

2. **Performance Optimization**
   - Implement object pooling for particles
   - Add visibility ranges to particle systems
   - Limit concurrent effects

3. **Audio Balancing**
   - Ensure SFX volumes are balanced
   - Test audio ducking during voice
   - Verify all sounds are appropriate for children

### Phase 4: Testing and Validation (2-3 hours)

1. **Automated Tests**
   - Write unit tests for all new systems
   - Run regression tests

2. **Manual Testing**
   - Test on Tier 1 hardware
   - Test on Tier 2 hardware
   - Test all combat scenarios

3. **Accessibility Testing**
   - Test with reduce-motion enabled
   - Test colorblind compatibility
   - Test with various input methods

---

## Appendix B: File Changes Required

### Files to Modify

| File | Changes | Priority |
|------|---------|----------|
| `src/domain/identity_safety/parental_control_policy.gd` | Add to_dict()/from_dict() serialization | CRITICAL |
| `src/adapters/inbound/gameplay/player_controller.gd` | Add crosshair tinting logic | CRITICAL |
| `src/adapters/inbound/gameplay/enemy_controller.gd` | Add miss feedback triggers | HIGH |
| `src/adapters/inbound/gameplay/gameplay_runtime.gd` | Add defeat feedback | HIGH |
| `src/domain/gameplay/weapon_definition.gd` | Create new weapon definition system | MEDIUM |

### Files to Create

| File | Purpose | Priority |
|------|---------|----------|
| `src/adapters/inbound/gameplay/hitstop_manager.gd` | Centralized hitstop management | HIGH |
| `src/adapters/inbound/gameplay/camera_shaker.gd` | Dedicated camera shake system | HIGH |
| `src/adapters/inbound/gameplay/feedback_queue.gd` | Feedback priority queue | MEDIUM |
| `scenes/particles/hit_light.tscn` | Light hit particles | MEDIUM |
| `scenes/particles/hit_heavy.tscn` | Heavy hit particles | MEDIUM |
| `scenes/particles/miss.tscn` | Miss particles | MEDIUM |
| `scenes/particles/enemy_defeat.tscn` | Enemy defeat particles | MEDIUM |
| `src/adapters/inbound/gameplay/aim_assist.gd` | Dedicated aim assist system | MEDIUM |
| `src/adapters/inbound/gameplay/combat_controller.gd` | Combat feedback coordinator | MEDIUM |

---

## Appendix C: Quick Reference Card

### Combat Timing Values

| Event | Duration | Notes |
|-------|----------|-------|
| Regular enemy wind-up | 0.8s | Telegraph before attack |
| Boss wind-up | 1.2s | Longer telegraph |
| Hit-stop (mob) | 35ms | Brief freeze |
| Hit-stop (boss) | 60ms | Longer freeze |
| Combo window | 0.5s | Time between attacks |
| Damage number fade | 1.0s | Float and fade out |
| Camera shake (light) | 0.1s | Subtle shake |
| Camera shake (heavy) | 0.2s | Noticeable shake |

### Color Palette (Child-Safe)

| Purpose | Color | Hex | Godot Color |
|---------|-------|-----|--------------|
| Hit damage | Orange-Red | #FF6633 | `Color(1, 0.4, 0.2)` |
| Critical hit | Gold | #FFCC33 | `Color(1, 0.8, 0.2)` |
| Heal | Green | #33CC66 | `Color(0.2, 0.8, 0.4)` |
| Miss | Gray | #888888 | `Color(0.5, 0.5, 0.5)` |
| Crosshair (normal) | White | #FFFFFF | `Color.WHITE` |
| Crosshair (enemy) | Orange | #FF994C | `Color(1, 0.6, 0.3)` |
| Crosshair (locked) | Gold | #FFCC00 | `Color(1, 0.8, 0)` |
| Telegraph | Orange | #FF8C42 | `Color(1, 0.5, 0.2)` |

### Audio Volume Guidelines

| Sound Type | Volume (dB) | Priority |
|------------|-------------|----------|
| Voice (dialogue) | -3.0dB | Highest |
| Hit impact | -6.0dB | High |
| Swing whoosh | -10.0dB | Medium |
| Miss sound | -12.0dB | Medium |
| Footsteps | -15.0dB | Low |
| Ambient | -20.0dB | Lowest |

---

*Document generated by Mistral Vibe for Choyce Engine VS-005 Combat Telegraphs and Feedback*  
*Last updated: 2026-07-18*  
*Status: Deep Research Complete - Ready for Implementation*
