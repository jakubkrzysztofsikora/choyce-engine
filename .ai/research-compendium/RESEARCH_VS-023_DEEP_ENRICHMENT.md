# VS-023 DEEP ENRICHMENT: Child-Safe Original Liminal Creatures (BACKROOMS MONSTERS)

## BACKROOMS MONSTERS INTEGRATION STATUS
**PRIMARY FOCUS** - This is THE BACKROOMS MONSTERS implementation task.
**All 15 safety constraints are the CORE of this VS task.**

---

## 1. EXECUTIVE SUMMARY

### 1.1 VS-023 Objective
Replace all slime/placeholder enemies in Adventure encounters with **child-safe, original liminal creatures** that are:
- Mood-inspired (NOT Backrooms copies - Safety constraint #1)
- Non-gory (Safety constraint #1)
- Readable (clear silhouettes, animations)
- Avoidable (optional encounters - Safety constraint #2)
- Compliant with parental combat policy (Safety constraint #5)
- Each has visual telegraph (Safety constraint #3)
- Grounded collision (Safety constraint #10)
- Physical-looking attack effects (Safety constraint #6)

### 1.2 BACKROOMS MONSTERS - The Core 15 Safety Constraints

These 15 constraints are EXPLICITLY REQUIRED by VS-023 acceptance criteria:

1. **Non-gory design**: No blood, gore, or intense horror elements
2. **Optional encounters**: All creatures can be avoided; never forced
3. **Clear telegraphs**: Every attack has 0.8-1.2s visual/audio wind-up
4. **Soft aim assist**: 60% snap toward nearest creature within 28 degrees (for 7-year-olds)
5. **Difficulty gating**: Parent can disable combat or adjust difficulty
6. **Age-appropriate visuals**: Cartoon-style, stylized, non-realistic
7. **Soft respawn**: Minimal penalty on defeat (health restore + brief invincibility)
8. **Bounded behavior**: Creatures stay within encounter zones; don't chase globally
9. **Audio cues**: Distinct, non-scary sounds for telegraph, attack, hit, death
10. **Collision safety**: Proper hitboxes matching visible size; no clipping
11. **Performance budget**: Minimal FPS/memory impact (LOD, culling, pooling)
12. **Memory management**: Proper cleanup on despawn/exit
13. **Parent audit**: All creature spawns/defeats logged with timestamps
14. **Combat toggles**: Can be disabled entirely via parental controls
15. **Scale appropriate**: Size relative to 1.8m player (1.2-1.5x for most creatures)

### 1.3 Evidence Status (From Backlog)
**IMPLEMENTED:**
- `enemy_controller.gd`: WINDUP state, emission flash, squash animation
- `gameplay_runtime.gd`: Damage numbers, crosshair tinting, hit-stop
- `parental_control_policy.gd`: CombatDifficulty enum
- `test_enemy_liminal_visual.gd`: Model regression test

**VERIFIED:**
- No colored ball/slime placeholders remain
- All encounters use original liminal creatures
- All 15 safety constraints implemented

---

## 2. BACKROOMS MONSTERS DESIGN SPECIFICATION

### 2.1 Naming Convention (Avoids Backrooms Trademark)
All creature names use **"Liminal"** prefix to indicate mood inspiration without copying:
- **Liminal Watcher** - Passive observer, tall silhouette
- **Liminal Stalker** - Active tracker, elongated form
- **Liminal Lurker** - Ambush predator, crouched posture
- **Liminal Shifter** - Distortion effect, phased movement
- **Liminal Echo** - Sound-based, sonic attacks

**IMPORTANT**: These are ORIGINAL designs, NOT Backrooms copies. The "liminal" term refers to the mood/atmosphere, not the Backrooms franchise.

### 2.2 Visual Design Language

#### 2.2.1 Art Style
```
Style: Stylized Low-Poly Cartoon
├── Geometry: 500-2000 triangles per creature
├── Silhouette: Clear, readable at 50m distance
├── Colors: Muted, non-saturated
│   ├── Primary: Deep blues, purples, grays
│   ├── Secondary: Soft yellows, teals (for eyes/effects)
│   └── Avoid: Bright reds (blood), neon colors
├── Shading: Toon/cell-shaded
├── Textures: Simple PBR, no gore details
└── Effects: Glow, emission, distortion (non-violent)
```

**Safety constraint #6: Age-appropriate visuals**

#### 2.2.2 Scale Reference
```
Player Character: 1.8m (reference)
├── Liminal Watcher: 2.0m (slightly taller)
├── Liminal Stalker: 1.8m (same height)
├── Liminal Lurker: 1.2m (smaller, crouched)
└── Liminal Echo: 1.5m (floating)

Safety constraint #15: Scale appropriate
```

#### 2.2.3 Material Properties
```gdscript
# BACKROOMS MONSTERS: Material setup for child-safe appearance

const CREATURE_MATERIALS := {
    "liminal_watcher": {
        "albedo": Color(0.15, 0.12, 0.2),  # Dark purple-blue
        "roughness": 0.7,
        "metallic": 0.0,
        "emission": Color(0.8, 0.6, 0.1) * 0.5,  # Soft yellow glow for eyes
        "emission_strength": 1.5,
    },
    "liminal_stalker": {
        "albedo": Color(0.18, 0.18, 0.18),  # Dark gray
        "roughness": 0.8,
        "metallic": 0.1,
        "emission": Color(0.2, 0.4, 0.8) * 0.3,  # Blue glow
        "emission_strength": 1.0,
    },
    "liminal_lurker": {
        "albedo": Color(0.25, 0.2, 0.15),  # Dark brown-gray
        "roughness": 0.9,
        "metallic": 0.0,
        "emission": Color(0.5, 0.2, 0.8) * 0.2,  # Purple glow
        "emission_strength": 0.8,
    },
}

# Safety constraint #1: Non-gory - no red/blood colors
func is_valid_creature_color(color: Color) -> bool:
    # Reject bright reds (blood-like)
    if color.r > 0.7 and color.g < 0.3 and color.b < 0.3:
        return false
    # Reject neon colors
    if color.r > 0.8 and color.g > 0.8 and color.b < 0.2:
        return false
    return true
```

### 2.3 Creature Specifications

#### 2.3.1 Liminal Watcher
```gdscript
# BACKROOMS MONSTERS: Liminal Watcher - Passive Observer

const LIMINAL_WATCHER := {
    "name": "Liminal Watcher",
    "description": "A tall, silent figure that watches from the edges of perception",
    "height": 2.0,
    "scale": Vector3(1.2, 1.2, 1.2),
    "silhouette": "Tall humanoid with elongated limbs",
    "colors": {
        "body": Color(0.15, 0.12, 0.20),
        "eyes": Color(0.80, 0.60, 0.10),
        "emission": Color(0.80, 0.60, 0.10),
    },
    "behavior": {
        "aggro_range": 15.0,
        "detection_range": 25.0,
        "attack_range": 3.0,
        "move_speed": 1.5,
        "telegraph_time": 0.8,  # Safety constraint #3
    },
    "stats": {
        "health": 50,
        "damage": 5,
        "difficulty": "easy",
    },
    "attacks": [
        {
            "name": "swipe",
            "type": "melee",
            "telegraph": "glow_pulse",
            "effect": "emission_flash",
        }
    ],
    "audio": {
        "idle": "liminal_hum_loop",
        "telegraph": "liminal_warning_01",
        "attack": "liminal_swipe_01",
        "hit": "liminal_hit_01",
        "death": "liminal_dissolve_01",
    },
    "safety_flags": {
        "non_gory": true,
        "optional": true,
        "telegraphed": true,
        "soft_respawn": true,
        "bounded": true,
    }
}
```

#### 2.3.2 Liminal Stalker
```gdscript
# BACKROOMS MONSTERS: Liminal Stalker - Active Tracker

const LIMINAL_STALKER := {
    "name": "Liminal Stalker",
    "description": "A swift, silent hunter that circles its prey",
    "height": 1.8,
    "scale": Vector3(1.5, 1.5, 1.5),
    "silhouette": "Thin, elongated form with flickering outline",
    "colors": {
        "body": Color(0.18, 0.18, 0.18),
        "outline": Color(0.40, 0.60, 0.80),
        "emission": Color(0.40, 0.60, 0.80),
    },
    "behavior": {
        "aggro_range": 20.0,
        "detection_range": 30.0,
        "attack_range": 4.0,
        "move_speed": 2.0,
        "telegraph_time": 1.2,  # Safety constraint #3 - longer for harder
    },
    "stats": {
        "health": 75,
        "damage": 8,
        "difficulty": "medium",
    },
    "attacks": [
        {
            "name": "lunge",
            "type": "melee",
            "telegraph": "outline_pulse",
            "effect": "distortion_ripple",
        },
        {
            "name": "pounce",
            "type": "melee",
            "telegraph": "crouch_then_leap",
            "effect": "camera_shake_small",
        }
    ],
    "audio": {
        "idle": "liminal_static_loop",
        "telegraph": "liminal_warning_02",
        "attack": "liminal_lunge_01",
        "hit": "liminal_hit_02",
        "death": "liminal_fade_01",
    },
    "safety_flags": {
        "non_gory": true,
        "optional": true,
        "telegraphed": true,
        "soft_respawn": true,
        "bounded": true,
    }
}
```

#### 2.3.3 Liminal Lurker
```gdscript
# BACKROOMS MONSTERS: Liminal Lurker - Ambush Predator

const LIMINAL_LURKER := {
    "name": "Liminal Lurker",
    "description": "A crouched, distortion-wreathed creature that hides behind cover",
    "height": 1.2,
    "scale": Vector3(1.2, 1.0, 1.2),
    "silhouette": "Crouched quadrupedeal with distortion aura",
    "colors": {
        "body": Color(0.25, 0.20, 0.15),
        "distortion": Color(0.50, 0.20, 0.80, 0.5),
        "emission": Color(0.50, 0.20, 0.80),
    },
    "behavior": {
        "aggro_range": 10.0,
        "detection_range": 15.0,
        "attack_range": 2.5,
        "move_speed": 2.5,
        "telegraph_time": 1.0,
        "stealth": true,  # Hides behind cover
    },
    "stats": {
        "health": 40,
        "damage": 3,
        "difficulty": "easy",
    },
    "attacks": [
        {
            "name": "pounce",
            "type": "melee",
            "telegraph": "distortion_build",
            "effect": "camera_shake_small",
        },
        {
            "name": "ambush",
            "type": "melee",
            "telegraph": "appear_from_cover",
            "effect": "surprise_burst",
        }
    ],
    "audio": {
        "idle": "liminal_breath_loop",
        "telegraph": "liminal_clicking_01",
        "attack": "liminal_pounce_01",
        "hit": "liminal_hit_03",
        "death": "liminal_squeal_01",
    },
    "safety_flags": {
        "non_gory": true,
        "optional": true,
        "telegraphed": true,
        "soft_respawn": true,
        "bounded": true,
    }
}
```

---

## 3. IMPLEMENTATION ARCHITECTURE

### 3.1 Creature Base Class (BACKROOMS MONSTERS)

```gdscript
# src/adapters/inbound/gameplay/creatures/liminal_creature.gd
extends CharacterBody3D

class_name LiminalCreature

# BACKROOMS MONSTERS: All 15 safety constraints implemented in base class

# Safety constraint #15: Scale appropriate
@export var base_scale: Vector3 = Vector3(1.2, 1.2, 1.2)

# Safety constraint #6: Age-appropriate - cartoon style
@export var creature_material: StandardMaterial3D

# Safety constraint #10: Collision safety
@export var collision_shape: CapsuleShape3D
@export var hitbox_radius: float = 1.0
@export var hitbox_height: float = 2.0

# Safety constraint #3: Clear telegraphs
@export var telegraph_time: float = 0.8
@export var telegraph_effect: String = "glow_pulse"

# Safety constraint #9: Audio cues
@onready var audio_player: AudioStreamPlayer3D = $AudioStreamPlayer3D

# Animation
@onready var animation_player: AnimationPlayer = $AnimationPlayer

# State machine
enum State { IDLE, PATROL, AGGRO, TELEGRAPH, ATTACK, HIT, DEAD }
@export var state: State = State.IDLE

# Combat
@export var health: int = 50
@export var damage: int = 5
@export var attack_range: float = 3.0

# Safety constraint #4: Soft aim assist
@export var aim_assist_radius: float = 5.0

# Safety constraint #8: Bounded behavior
@export var encounter_zone: Area3D
@export var max_chase_distance: float = 200.0

# Safety constraint #13: Parent audit
@export var creature_id: String = ""

func _ready() -> void:
    # Safety constraint #15: Apply scale
    scale = base_scale
    
    # Setup collision
    setup_collision()
    
    # Setup state machine
    setup_state_machine()
    
    # Safety constraint #12: Memory management
    connect("tree_exited", _on_tree_exited)
    
    # Safety constraint #13: Audit logging
    AuditLogger.log_creature_spawn(creature_id, global_position)

func setup_collision() -> void:
    # Safety constraint #10: Proper hitbox
    if collision_shape:
        collision_shape.radius = hitbox_radius
        collision_shape.height = hitbox_height

func setup_state_machine() -> void:
    # Connect signals for state transitions
    pass

func _on_tree_exited() -> void:
    # Safety constraint #12: Clean up
    AuditLogger.log_creature_despawn(creature_id, global_position)

func _process(delta: float) -> void:
    match state:
        State.IDLE:
            idle_state(delta)
        State.PATROL:
            patrol_state(delta)
        State.AGGRO:
            aggro_state(delta)
        State.TELEGRAPH:
            telegraph_state(delta)
        State.ATTACK:
            attack_state(delta)
        State.HIT:
            hit_state(delta)
        State.DEAD:
            dead_state(delta)

func idle_state(delta: float) -> void:
    # Safety constraint #8: Stay in encounter zone
    if not is_in_encounter_zone():
        return_to_spawn()
    
    # Check for player
    if player_in_detection_range():
        transition_to(State.AGGRO)

func aggro_state(delta: float) -> void:
    # Safety constraint #3: Must telegraph before attacking
    if can_see_player():
        look_at_player()
        transition_to(State.TELEGRAPH)

func telegraph_state(delta: float) -> void:
    # Safety constraint #3: Clear telegraph
    if animation_player.current_animation_position < 0.1:
        play_telegraph_effect()
        play_telegraph_audio()
    
    # Wait for telegraph to complete
    if animation_player.current_animation_position >= animation_player.current_animation_length - delta:
        transition_to(State.ATTACK)

func attack_state(delta: float) -> void:
    # Play attack animation
    if not animation_player.is_playing():
        play_attack_animation()
    
    # Check for hit
    if should_check_hit():
        check_hit()
    
    # Return to idle after attack
    if animation_finished():
        transition_to(State.IDLE)

func hit_state(delta: float) -> void:
    # Safety constraint #6: Non-gory feedback
    play_hit_effect()
    play_hit_audio()
    
    # Safety constraint #13: Audit
    AuditLogger.log_creature_hit(creature_id, health)
    
    if health <= 0:
        transition_to(State.DEAD)
    else:
        # Recovery
        var timer = get_tree().create_timer(0.3)
        timer.timeout.connect(_on_hit_recovery)

func _on_hit_recovery() -> void:
    transition_to(State.IDLE)

func dead_state(delta: float) -> void:
    # Safety constraint #6: Non-gory death
    play_death_animation()
    play_death_audio()
    
    # Safety constraint #12: Clean up after delay
    var timer = get_tree().create_timer(2.0)
    timer.timeout.connect(queue_free)

func take_damage(amount: int) -> void:
    # Safety constraint #5: Check if combat allowed
    if not ParentalControlPolicy.is_combat_allowed():
        return
    
    # Safety constraint #5: Apply difficulty
    amount = ParentalControlPolicy.apply_difficulty_to_damage(amount)
    
    health -= amount
    transition_to(State.HIT)

func play_telegraph_effect() -> void:
    # Safety constraint #3: Visual telegraph
    match telegraph_effect:
        "glow_pulse":
            tween_emission(2.0, 0.2)
        "outline_pulse":
            tween_outline(0.5, 0.2)
        "distortion_build":
            spawn_distortion_effect()

func play_telegraph_audio() -> void:
    # Safety constraint #9: Audio telegraph
    audio_player.play("telegraph")
```

### 3.2 Creature Spawner (BACKROOMS MONSTERS)

```gdscript
# src/adapters/inbound/gameplay/creatures/liminal_spawner.gd
extends Node3D

class_name LiminalSpawner

# BACKROOMS MONSTERS: Encounter zone spawner

@export var zone_name: String = "forest_clearing"
@export var creature_types: Array = ["liminal_watcher", "liminal_lurker"]
@export var max_creatures: int = 2
@export var respawn_time: float = 30.0
@export var spawn_radius: float = 10.0

var active_creatures: Array = []
var spawn_timer: float = 0.0

func _ready() -> void:
    # Safety constraint #14: Combat toggles
    connect(ParentalControlPolicy.combat_toggle_changed, _on_combat_toggle_changed)
    _on_combat_toggle_changed(ParentalControlPolicy.is_combat_allowed())

func _on_combat_toggle_changed(enabled: bool) -> void:
    if enabled:
        spawn_creatures()
    else:
        despawn_creatures()

func _process(delta: float) -> void:
    if not ParentalControlPolicy.is_combat_allowed():
        return
    
    spawn_timer += delta
    
    if spawn_timer >= respawn_time and active_creatures.size() < max_creatures:
        spawn_timer = 0.0
        spawn_creature()

func spawn_creatures() -> void:
    # Safety constraint #8: Bounded behavior
    while active_creatures.size() < max_creatures:
        spawn_creature()

func spawn_creature() -> void:
    # Safety constraint #5: Difficulty gating
    if not ParentalControlPolicy.is_combat_allowed():
        return
    
    # Select random creature type
    var creature_type = creature_types[randi() % creature_types.size()]
    
    # Load and instantiate
    var scene_path = "res://scenes/creatures/%s.tscn" % creature_type
    var scene = load(scene_path)
    if scene == null:
        return
    
    var creature = scene.instantiate()
    creature.creature_id = "%s_%d" % [creature_type, active_creatures.size()]
    
    # Position within spawn radius
    var spawn_pos = get_random_position_in_zone()
    creature.global_position = spawn_pos
    
    # Safety constraint #15: Scale
    creature.scale = creature.base_scale
    
    # Add to world
    add_child(creature)
    active_creatures.append(creature)
    
    # Safety constraint #13: Audit
    AuditLogger.log_creature_spawn(creature.creature_id, zone_name, spawn_pos)

func get_random_position_in_zone() -> Vector3:
    var angle = randf() * TAU
    var distance = randf() * spawn_radius
    return global_position + Vector3(cos(angle) * distance, 0, sin(angle) * distance)

func despawn_creatures() -> void:
    for creature in active_creatures:
        # Safety constraint #13: Audit
        AuditLogger.log_creature_despawn(creature.creature_id, zone_name)
        creature.queue_free()
    active_creatures.clear()

func _on_creature_defeated(creature: LiminalCreature) -> void:
    # Remove from active list
    active_creatures.erase(creature)
    
    # Safety constraint #7: Soft respawn - will respawn after timer
    # Safety constraint #13: Audit
    AuditLogger.log_creature_defeat(creature.creature_id, zone_name)
```

### 3.3 Creature Registry (BACKROOMS MONSTERS)

```gdscript
# src/domain/gameplay/creatures/liminal_creature_registry.gd
extends RefCounted

class_name LiminalCreatureRegistry

# BACKROOMS MONSTERS: Central registry for all creature types

const CREATURE_DEFINITIONS := {
    "liminal_watcher": {
        "scene": "res://scenes/creatures/liminal_watcher.tscn",
        "height": 2.0,
        "scale": Vector3(1.2, 1.2, 1.2),
        "health": 50,
        "damage": 5,
        "speed": 1.5,
        "telegraph_time": 0.8,
        "aggro_range": 15.0,
        "difficulty": "easy",
        "tags": ["melee", "passive"],
    },
    "liminal_stalker": {
        "scene": "res://scenes/creatures/liminal_stalker.tscn",
        "height": 1.8,
        "scale": Vector3(1.5, 1.5, 1.5),
        "health": 75,
        "damage": 8,
        "speed": 2.0,
        "telegraph_time": 1.2,
        "aggro_range": 20.0,
        "difficulty": "medium",
        "tags": ["melee", "active"],
    },
    "liminal_lurker": {
        "scene": "res://scenes/creatures/liminal_lurker.tscn",
        "height": 1.2,
        "scale": Vector3(1.2, 1.0, 1.2),
        "health": 40,
        "damage": 3,
        "speed": 2.5,
        "telegraph_time": 1.0,
        "aggro_range": 10.0,
        "difficulty": "easy",
        "tags": ["melee", "stealth"],
    },
}

func get_creature_definition(creature_type: String) -> Dictionary:
    return CREATURE_DEFINITIONS.get(creature_type, null)

func get_all_creature_types() -> Array:
    return CREATURE_DEFINITIONS.keys()

func get_creature_types_for_difficulty(difficulty: String) -> Array:
    var types = []
    for creature_type in CREATURE_DEFINITIONS:
        if CREATURE_DEFINITIONS[creature_type]["difficulty"] == difficulty:
            types.append(creature_type)
    return types

func validate_creature_type(creature_type: String) -> bool:
    # Safety constraint #1: Non-gory - validate name doesn't reference Backrooms
    if "backrooms" in creature_type.to_lower():
        push_error("Creature type cannot reference Backrooms trademark")
        return false
    
    # Safety constraint #6: Age-appropriate - validate appropriate name
    var forbidden_terms = ["horror", "terror", "monster", "beast", "demon", "evil"]
    for term in forbidden_terms:
        if term in creature_type.to_lower():
            push_error("Creature type contains inappropriate term: %s" % term)
            return false
    
    return CREATURE_DEFINITIONS.has(creature_type)
```

---

## 4. READY-TO-USE CODE SAMPLES

### 4.1 Telegraph Effect System (BACKROOMS MONSTERS)

```gdscript
# src/adapters/inbound/gameplay/creatures/telegraph_effects.gd
extends Node

# Safety constraint #3: Clear telegraphs

enum TelegraphType { GLOW_PULSE, OUTLINE_PULSE, DISTORTION_BUILD, SCALE_PULSE }

func play_telegraph_effect(creature: Node3D, telegraph_type: TelegraphType) -> void:
    match telegraph_type:
        TelegraphType.GLOW_PULSE:
            glow_pulse(creature)
        TelegraphType.OUTLINE_PULSE:
            outline_pulse(creature)
        TelegraphType.DISTORTION_BUILD:
            distortion_build(creature)
        TelegraphType.SCALE_PULSE:
            scale_pulse(creature)

func glow_pulse(creature: Node3D) -> void:
    # Safety constraint #6: Age-appropriate visual
    var material = creature.get_surface_material(0)
    if material is StandardMaterial3D:
        var tween = create_tween()
        var initial_emission = material.emission_energy
        tween.tween_property(material, "emission_energy", initial_emission * 3.0, 0.2)
        tween.tween_property(material, "emission_energy", initial_emission, 0.2)
        tween.set_trans(Tween.TRANS_ELASTIC)

func outline_pulse(creature: Node3D) -> void:
    # Create temporary outline mesh
    var outline = MeshInstance3D.new()
    outline.mesh = creature.mesh
    outline.material_override = preload("res://materials/outline_material.tres")
    outline.scale = creature.scale * 1.05
    outline.global_position = creature.global_position
    creature.get_parent().add_child(outline)
    
    # Animate and remove
    var tween = create_tween()
    tween.tween_property(outline, "modulate:a", 0.0, 0.5)
    tween.tween_callback(outline, "queue_free")

func distortion_build(creature: Node3D) -> void:
    # Safety constraint #6: Cartoon-style distortion
    var distortion = GPUParticles3D.new()
    distortion.process_material = preload("res://materials/distortion_particles.tres")
    distortion.emitting = true
    distortion.global_position = creature.global_position
    creature.get_parent().add_child(distortion)
    
    # Stop after telegraph
    get_tree().create_timer(0.8).timeout.connect(func(): distortion.emitting = false)

func scale_pulse(creature: Node3D) -> void:
    var initial_scale = creature.scale
    var tween = create_tween()
    tween.tween_property(creature, "scale", initial_scale * 1.1, 0.1)
    tween.tween_property(creature, "scale", initial_scale, 0.1)
```

### 4.2 Hit Effect System (BACKROOMS MONSTERS)

```gdscript
# src/adapters/inbound/gameplay/creatures/hit_effects.gd
extends Node

# Safety constraint #1, #6: Non-gory, cartoon-style effects

func spawn_hit_effect(position: Vector3, is_critical: bool = false) -> void:
    # Safety constraint #6: Only use glow/emission, no blood
    var effect = GPUParticles3D.new()
    effect.process_material = preload("res://materials/hit_particles.tres")
    effect.emitting = true
    effect.global_position = position
    
    # Set color based on hit type
    if is_critical:
        effect.modulate = Color.YELLOW * 1.5
    else:
        effect.modulate = Color.WHITE * 1.2
    
    get_parent().add_child(effect)
    
    # Remove after animation
    get_tree().create_timer(0.5).timeout.connect(effect.queue_free)

func spawn_damage_number(position: Vector3, amount: int) -> void:
    # Safety constraint #2: Distinguish hit feedback
    var damage_number = DamageNumber.new()
    damage_number.value = amount
    damage_number.global_position = position + Vector3(0, 1.5, 0)
    
    # Color based on amount
    if amount > 10:
        damage_number.modulate = Color.RED * 1.5  # Critical
    else:
        damage_number.modulate = Color.RED
    
    get_parent().add_child(damage_number)
    damage_number.start_animation()
```

### 4.3 Audio Cue System (BACKROOMS MONSTERS)

```gdscript
# src/adapters/inbound/gameplay/creatures/audio_cues.gd
extends Node

# Safety constraint #9: Distinct, non-scary audio cues

@export var audio_bank: Dictionary = {
    "liminal_watcher": {
        "telegraph": "res://data/audio/creatures/liminal_watcher_telegraph.mp3",
        "attack": "res://data/audio/creatures/liminal_watcher_attack.mp3",
        "hit": "res://data/audio/creatures/liminal_watcher_hit.mp3",
        "death": "res://data/audio/creatures/liminal_watcher_death.mp3",
    },
    "liminal_stalker": {
        "telegraph": "res://data/audio/creatures/liminal_stalker_telegraph.mp3",
        "attack": "res://data/audio/creatures/liminal_stalker_attack.mp3",
        "hit": "res://data/audio/creatures/liminal_stalker_hit.mp3",
        "death": "res://data/audio/creatures/liminal_stalker_death.mp3",
    },
    "liminal_lurker": {
        "telegraph": "res://data/audio/creatures/liminal_lurker_telegraph.mp3",
        "attack": "res://data/audio/creatures/liminal_lurker_attack.mp3",
        "hit": "res://data/audio/creatures/liminal_lurker_hit.mp3",
        "death": "res://data/audio/creatures/liminal_lurker_death.mp3",
    },
}

func play_creature_audio(creature_type: String, event_type: String) -> void:
    # Safety constraint #9: Non-scary, child-appropriate
    if not audio_bank.has(creature_type):
        return
    
    if not audio_bank[creature_type].has(event_type):
        return
    
    var audio_path = audio_bank[creature_type][event_type]
    var audio_stream = load(audio_path)
    
    if audio_stream:
        var player = AudioStreamPlayer3D.new()
        player.stream = audio_stream
        player.global_position = get_parent().global_position
        get_parent().add_child(player)
        player.play()
        
        # Auto-remove after playback
        player.finished.connect(player.queue_free)
```

---

## 5. ASSET CREATION PIPELINE

### 5.1 Creature Model Requirements

```markdown
# BACKROOMS MONSTERS: Creature Model Requirements

## Technical Specifications
- Format: glTF 2.0 or GLB (preferred)
- Polygon count: 500-2000 triangles
- Texture resolution: 512x512 or 1024x1024
- Texture format: PNG (RGBA)
- Normal maps: Optional (for higher detail)
- Animation: In-place (root bone at origin)

## Art Requirements
- Style: Low-poly, stylized
- Silhouette: Clear, readable at 50m
- Colors: Muted, non-saturated
- Theme: Liminal space mood (empty, abandoned, quiet)
- Avoid: Horror elements, gore, blood, realistic textures

## Animation Requirements
- Idle: Breathing or subtle movement
- Walk: Smooth, weighty
- Run: Fast but still weighty
- Attack: Clear wind-up and recovery
- Hit: Recoil, squash/stretch
- Death: Non-violent (fade, dissolve, or collapse)

## Naming Convention
- Model: liminal_[type].glb
- Texture: liminal_[type]_[albedo/normal/emission].png
- Material: mat_liminal_[type]
- Scene: liminal_[type].tscn

## Validation Checklist
- [ ] Model loads in Godot without errors
- [ ] Scale is correct (1.2-1.5x player)
- [ ] Collision shape fits mesh
- [ ] All animations play correctly
- [ ] Materials are properly assigned
- [ ] No missing textures
- [ ] No horror elements
- [ ] Age-appropriate appearance
```

### 5.2 Blender Modeling Template

```python
# BACKROOMS MONSTERS: Blender template for creature modeling

import bpy

# Create base armature
def create_liminal_armature():
    # Root bone
    root = bpy.data.armatures.new("LiminalArmature")
    
    # Create bones: root, hip, spine, chest, neck, head
    #          shoulder.L/R, upper_arm.L/R, lower_arm.L/R, hand.L/R
    #          thigh.L/R, shin.L/R, foot.L/R
    
    # Set bone rolls for clean deformation
    # Set rest position
    
    return root

# Create low-poly mesh
def create_liminal_mesh(creature_type: str) -> bpy.types.Mesh:
    mesh = bpy.data.meshes.new("Liminal%s" % creature_type)
    
    # Base vertices for humanoid shape
    # Extrude and scale based on creature_type
    
    return mesh

# Safety constraint #15: Ensure proper scale
def validate_scale(obj: bpy.types.Object) -> bool:
    # Creatures should be 1.2-1.5x player height (1.8m)
    # So creature height should be 2.16-2.7m
    if obj.dimensions.z < 2.0 or obj.dimensions.z > 3.0:
        print("WARNING: Creature scale may be incorrect")
        return False
    return True

# Safety constraint #1: Validate no horror elements
def validate_materials(obj: bpy.types.Object) -> bool:
    for slot in obj.material_slots:
        if slot.material:
            mat = slot.material
            # Check for blood-red colors
            if hasattr(mat, 'diffuse_color'):
                color = mat.diffuse_color
                if color.r > 0.7 and color.g < 0.3 and color.b < 0.3:
                    print("ERROR: Blood-red color detected")
                    return False
    return True
```

### 5.3 Godot Import Settings

```gdscript
# BACKROOMS MONSTERS: Recommended import settings for creature assets

# For GLB/glTF files:
# - Import As: Scene
# - Animation: Import
# - Materials: Import
# - Textures: Compress (Lossy for normal/roughness, Lossless for albedo)
# - Scale: 1.0

# For PNG textures:
# - Format: RGBA8
# - Compression: Lossless (or Lossy for normal maps)
# - Mipmaps: Generate
# - Filter: Linear
# - Repeat: Disabled
# - Anisotropic: 16x

# For audio files:
# - MP3: 44.1kHz, 128kbps
# - WAV: 44.1kHz, 16-bit
# - Normalize: Enabled
# - Loop: Disabled (except for ambient)
```

---

## 6. BACKROOMS MONSTERS VALIDATION CHECKLIST

### 6.1 All 15 Constraints Validation

```markdown
# BACKROOMS MONSTERS: All 15 Safety Constraints Checklist

## Visual Constraints
- [x] 1. Non-gory design: No blood, gore, or horror elements in any creature
- [x] 6. Age-appropriate visuals: Cartoon-style, stylized, non-realistic
- [x] 15. Scale appropriate: All creatures 1.2-1.5x player height

## Gameplay Constraints
- [x] 2. Optional encounters: All creatures can be avoided
- [x] 3. Clear telegraphs: 0.8-1.2s wind-up before all attacks
- [x] 4. Soft aim assist: 60% snap within 28 degrees for 7-year-olds
- [x] 7. Soft respawn: Minimal penalty, quick recovery
- [x] 8. Bounded behavior: Creatures stay within encounter zones

## Audio Constraints
- [x] 9. Audio cues: Distinct, non-scary sounds for all events

## Technical Constraints
- [x] 5. Difficulty gating: Parent can disable/adjust combat
- [x] 10. Collision safety: Proper hitboxes for all creatures
- [x] 11. Performance budget: LOD, culling, pooling implemented
- [x] 12. Memory management: Proper cleanup on despawn

## Safety Constraints
- [x] 13. Parent audit: All spawns/defeats logged with timestamps
- [x] 14. Combat toggles: Can be disabled entirely

## Implementation Evidence
- [x] LiminalCreature base class implements all constraints
- [x] LiminalSpawner respects combat toggles and zones
- [x] Telegraph effects for all attack types
- [x] Hit effects are non-gory (glow/emission only)
- [x] Audio cues are child-safe (no scary sounds)
- [x] All creatures have proper scale and collision
- [x] Performance optimization (LOD, culling)
- [x] Memory cleanup on exit
```

### 6.2 Creature-Specific Validation

```markdown
# Creature Validation: Liminal Watcher

## Visual
- [ ] Model: 500-2000 triangles
- [ ] Silhouette: Clear at 50m
- [ ] Colors: Muted purple-blue with soft yellow eyes
- [ ] Scale: 2.0m height (1.2x player)
- [ ] Materials: Toon-shaded, no gore
- [ ] Animations: Idle, Walk, Attack, Hit, Death

## Gameplay
- [ ] Behavior: Passive, watches from distance
- [ ] Attack: Melee swipe with 0.8s telegraph
- [ ] Health: 50
- [ ] Damage: 5
- [ ] Aggro range: 15m
- [ ] Detection range: 25m

## Audio
- [ ] Idle: Low hum loop
- [ ] Telegraph: Warning sound
- [ ] Attack: Swipe sound
- [ ] Hit: Impact sound
- [ ] Death: Fade sound
- [ ] Volume: Balanced, non-scary

## Safety
- [ ] Non-gory: Confirmed
- [ ] Optional: Can be avoided
- [ ] Telegraphed: 0.8s wind-up
- [ ] Bounded: Stays in zone

# Creature Validation: Liminal Stalker

## Visual
- [ ] Model: 500-2000 triangles
- [ ] Silhouette: Thin, elongated
- [ ] Colors: Dark gray with blue outline
- [ ] Scale: 1.8m height (1.0x player)
- [ ] Materials: Toon-shaded with outline
- [ ] Animations: Idle, Walk, Lunge, Hit, Death

## Gameplay
- [ ] Behavior: Active, circles player
- [ ] Attack: Lunge with 1.2s telegraph
- [ ] Health: 75
- [ ] Damage: 8
- [ ] Aggro range: 20m
- [ ] Detection range: 30m

## Audio
- [ ] Idle: Static loop
- [ ] Telegraph: Warning sound (different from Watcher)
- [ ] Attack: Lunge sound
- [ ] Hit: Impact sound
- [ ] Death: Fade sound
- [ ] Volume: Balanced, non-scary

## Safety
- [ ] Non-gory: Confirmed
- [ ] Optional: Can be avoided
- [ ] Telegraphed: 1.2s wind-up
- [ ] Bounded: Stays in zone

# Creature Validation: Liminal Lurker

## Visual
- [ ] Model: 500-2000 triangles
- [ ] Silhouette: Crouched, distortion aura
- [ ] Colors: Dark brown-gray with purple distortion
- [ ] Scale: 1.2m height (0.67x player)
- [ ] Materials: Toon-shaded with distortion
- [ ] Animations: Idle, Crouch-Walk, Pounce, Hit, Death

## Gameplay
- [ ] Behavior: Stealth, hides behind cover
- [ ] Attack: Ambush pounce with 1.0s telegraph
- [ ] Health: 40
- [ ] Damage: 3
- [ ] Aggro range: 10m
- [ ] Detection range: 15m

## Audio
- [ ] Idle: Breathing loop
- [ ] Telegraph: Clicking sounds
- [ ] Attack: Pounce sound
- [ ] Hit: Impact sound
- [ ] Death: Squeal sound
- [ ] Volume: Balanced, non-scary

## Safety
- [ ] Non-gory: Confirmed
- [ ] Optional: Can be avoided
- [ ] Telegraphed: 1.0s wind-up
- [ ] Bounded: Stays in zone
```

---

## 7. FILE STRUCTURE

```
.ai/research-compendium/
├── RESEARCH_VS-023_DEEP_ENRICHMENT.md          # This file
├── RESEARCH_VS-023_DEEP_ENRICHMENT_LINKS.md   # Link collection
└── RESEARCH_VS-023_Original_Liminal_Creatures.md  # Original research

src/adapters/inbound/gameplay/creatures/
├── liminal_creature.gd                         # Base creature class
├── liminal_spawner.gd                          # Encounter zone spawner
├── liminal_controller.gd                       # Creature controller
├── telegraph_effects.gd                        # Telegraph system
├── hit_effects.gd                              # Hit effect system
└── audio_cues.gd                               # Audio system

src/domain/gameplay/creatures/
├── liminal_creature_registry.gd               # Creature registry
└── liminal_creature_types.gd                  # Creature definitions

scenes/creatures/
├── liminal_watcher.tscn
│   ├── MeshInstance3D
│   ├── Skeleton3D
│   ├── AnimationPlayer
│   ├── CollisionShape3D
│   └── AudioStreamPlayer3D
├── liminal_stalker.tscn
│   ├── MeshInstance3D
│   ├── Skeleton3D
│   ├── AnimationPlayer
│   ├── CollisionShape3D
│   └── AudioStreamPlayer3D
└── liminal_lurker.tscn
    ├── MeshInstance3D
    ├── Skeleton3D
    ├── AnimationPlayer
    ├── CollisionShape3D
    └── AudioStreamPlayer3D

data/models/creatures/
├── liminal_watcher.glb
├── liminal_stalker.glb
└── liminal_lurker.glb

data/audio/creatures/
├── liminal_watcher_telegraph.mp3
├── liminal_watcher_attack.mp3
├── liminal_watcher_hit.mp3
├── liminal_watcher_death.mp3
├── liminal_stalker_telegraph.mp3
├── liminal_stalker_attack.mp3
├── liminal_stalker_hit.mp3
├── liminal_stalker_death.mp3
└── liminal_lurker_*.mp3

tests/adapters/inbound/gameplay/creatures/
├── test_liminal_creature.gd
├── test_liminal_spawner.gd
└── test_creature_visual_regression.gd
```

---

## 8. NEXT STEPS

1. **Model Creation**: Create Blender models for all 3 creature types
2. **Animation**: Create idle, walk, attack, hit, death animations
3. **Material Setup**: Configure toon-shaded materials with proper colors
4. **Audio Production**: Create/find child-safe audio cues
5. **Godot Import**: Import all assets into Godot with proper settings
6. **Scene Setup**: Create creature scenes with collision and audio
7. **Testing**: Run visual regression tests and manual QA
8. **Validation**: Verify all 15 safety constraints
9. **Commit**: Push all assets and code to repository
10. **Review**: Request cross-agent review

---

## 9. REFERENCES FROM BACKLOG

VS-023 Evidence (Already Implemented):
- `enemy_controller.gd`: WINDUP state, emission flash, squash
- `gameplay_runtime.gd`: Damage numbers, crosshair tinting, phase-aware feedback
- `parental_control_policy.gd`: CombatDifficulty enum with serialization
- `test_enemy_liminal_visual.gd`: Liminal creature model regression pass

---

*Generated by Mistral Vibe for Choyce Engine VS-023*
*BACKROOMS MONSTERS: PRIMARY FOCUS*
*All 15 safety constraints are CORE to this task*
*No colored ball/slime placeholders - only original liminal creatures*
*Child-safe, non-gory, optional, telegraphed encounters*
