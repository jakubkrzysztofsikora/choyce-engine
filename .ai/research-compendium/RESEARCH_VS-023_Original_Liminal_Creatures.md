# VS-023: Original Liminal Creatures (Backrooms-Inspired) - Deep Research Compendium

**Status**: in_progress  
**Specialty**: creature-art-and-behavior  
**Owner**: codex  
**Cross-review**: claude  
**Priority**: HIGH  
**Last Updated**: 2026-07-18

---

## Table of Contents

1. [Task Overview](#task-overview)
2. [Current Implementation Status](#current-implementation-status)
3. [Backrooms Lore & Entity Reference](#backrooms-lore--entity-reference)
4. [Child-Safe Backrooms Creature Design](#child-safe-backrooms-creature-design)
5. [Creature Concept Library](#creature-concept-library)
6. [3D Model Sources & Asset Pipelines](#3d-model-sources--asset-pipelines)
7. [Godot Enemy Controller Architecture](#godot-enemy-controller-architecture)
8. [Wind-Up Telegraph System](#wind-up-telegraph-system)
9. [Combat Integration](#combat-integration)
10. [State Machine Implementation](#state-machine-implementation)
11. [Parenting & Combat Policy Compliance](#parenting--combat-policy-compliance)
12. [Code Samples & Implementation Patterns](#code-samples--implementation-patterns)
13. [Testing & Validation Checklist](#testing--validation-checklist)
14. [Learning Resources](#learning-resources)

---

## Task Overview

### Objective

Replace all slime placeholder creatures in the Adventure slice with **original, child-safe liminal space creatures** that are:
- **Backrooms-Inspired**: Capture the eerie, liminal space aesthetic
- **Non-Gory**: No blood, violence, or frightening imagery
- **Readable**: Clear silhouettes and recognizable features
- **Avoidable**: Players can evade or hide from creatures
- **Compliant**: Follow parental combat policy

### Key Requirements

- **No Slime Placeholders**: All colored ball/slime placeholders must be removed
- **Visual Telegraph**: Each encounter has clear wind-up animation before attacking
- **Grounded Collision**: Creatures have proper physical collision
- **Physical-Looking Attacks**: Attack effects are believable but not graphic
- **Parental Combat Policy**: Combat is age-appropriate with soft consequences

### Acceptance Criteria (from backlog.yaml)

- [ ] No colored ball/slime placeholder remains in Adventure encounters
- [ ] Creatures are original, non-gory, readable, avoidable
- [ ] Each encounter has a visual telegraph, grounded collision, and physical-looking attack effect
- [ ] Complies with parental combat policy

### Dependencies

- VS-005 (Combat feel, feedback, and easy-mode pass)
- VS-012 (Visual art direction reset)

---

## Current Implementation Status

### Existing Code & Evidence

From backlog.yaml:

```
├── src/adapters/inbound/gameplay/
│   └── enemy_controller.gd      # Already has WINDUP state
│                                   # Already has emission flash
│                                   # Already has squash
└── src/domain/identity_safety/
    └── parental_control_policy.gd  # CombatDifficulty enum
```

### Current Implementation Gaps

1. **Creature Models**: Need Backrooms-inspired 3D models
2. **Creature Concepts**: Need original creature designs
3. **Animation System**: Need full state machine with telegraph
4. **Visual Telegraph**: Need clear wind-up indicators
5. **Collision Setup**: Need proper collision for each creature
6. **Attack Effects**: Need physical-looking but non-gory effects

---

## Backrooms Lore & Entity Reference

### Official Backrooms Wiki Resources

- **Main Entities List**: [https://backrooms-wiki.wikidot.com/entities](https://backrooms-wiki.wikidot.com/entities)
- **Unnumbered Entities**: [https://backrooms-wiki.wikidot.com/unnumbered-entities](https://backrooms-wiki.wikidot.com/unnumbered-entities)

### Key Backrooms Entity Categories

#### Safe/Friendly Entities (For Inspiration)

| Entity | Description | Child-Safe Adaptation |
|--------|-------------|----------------------|
| Entity 1 | Humans | NPCs, guides |
| Entity 131 | The Concierge | Friendly helper |
| Entity 133 | The Mail Carrier | Package delivery |
| Entity 136 | Coders | Puzzle solvers |
| Entity 137 | The Musician | Music teacher |

#### Hostile Entities (For Design Reference)

| Entity | Description | Child-Safe Adaptation |
|--------|-------------|----------------------|
| Entity 12 | Dunks | Slow, easily avoided |
| Entity 13 | Transporters | Teleporting but harmless |
| Entity 14 | Reviooks | Shy, runs away |
| Entity 20 | Scits | Scavengers, not aggressive |
| Entity 120 | Officinarum | Office-themed, non-violent |
| Entity 121 | Bone Thieves | Collects objects, not scary |
| Entity 126 | Scarecrows | Stationary, puzzles |
| Entity 128 | ΩMEGA | Large but slow |
| Entity 129 | βETA | Small and curious |
| Entity 134 | Phobic Centipedes | Fast but flees |
| Entity 139 | The Puppeteer | Controls objects, not people |
| Entity 150 | Stalkers | Follows but doesn't attack |
| Entity 152 | Xeroxes | Copycat behavior |
| Entity 157 | Homerunners | Chases but can't catch |

### Backrooms Aesthetic Elements

- **Colors**: Muted yellows, greens, grays, beiges (low saturation)
- **Lighting**: Fluorescent, flickering, dim
- **Textures**: Concrete, carpet, drywall, office materials
- **Geometry**: Long hallways, right angles, impossible spaces
- **Objects**: Office furniture, pipes, electrical panels, signage

### Liminal Space Color Palettes

From [Lospecs](https://lospec.com/palette-list/tag/liminal):

**Liminal Breeze Palette**:
- `#272727` (Dark gray)
- `#3d4456` (Muted blue-gray)
- `#858c9c` (Soft blue)
- `#cac2a9` (Warm beige)
- `#e9e7d8` (Off-white)

**Classic Liminal Palette**:
- `#d4d0c4` (Light beige)
- `#a3a094` (Medium gray)
- `#737064` (Dark gray)
- `#424034` (Very dark gray)
- `#f4f0e8` (Almost white)
- `#1e3f20` (Dark green - for accent)

---

## Child-Safe Backrooms Creature Design

### Design Principles

#### 1. **Non-Scary Silhouettes**

- **Round shapes**: Avoid sharp edges and points
- **Oversized features**: Big eyes, large heads, exaggerated proportions
- **Soft edges**: No jagged teeth, claws, or spikes
- **Friendly posture**: Open arms, tilted head, relaxed stance

#### 2. **Backrooms Aesthetic Without Fear**

- **Color palette**: Use muted Backrooms colors but with friendly shapes
- **Texture**: Concrete/gray skin with soft highlights
- **Lighting**: Glowing elements (not red/scary)
- **Movement**: Smooth, floating, or bouncy (not erratic)

#### 3. **Behavior Patterns**

- **Avoidable**: Telegraphed attacks, slow movement, clear patterns
- **Non-lethal**: Soft damage, push-back, or environmental effects
- **Curious**: Investigates player but doesn't chase aggressively
- **Puzzle-oriented**: Requires interaction, not just combat

#### 4. **Child-Friendly Themes**

- **Lost items**: Creatures that collect/return objects
- **Light bringers**: Creatures that illuminate dark areas
- **Pathfinders**: Creatures that show safe routes
- **Sound makers**: Creatures that make music or interesting noises

### Design Process Checklist

For each creature:

- [ ] Silhouette test: Recognizable from black outline
- [ ] Color test: Uses Backrooms palette (muted, low saturation)
- [ ] Size test: Appropriate scale for child character
- [ ] Animation test: Smooth, readable movements
- [ ] Sound test: Non-scary audio cues
- [ ] Behavior test: Avoidable and non-lethal
- [ ] Parent test: Approved by adult reviewer

---

## Creature Concept Library

### Category 1: Office Liminal Creatures (Backrooms Level 0-3)

#### Creature 1: "The Flicker" (Based on Entity 12 - Dunks)

**Design**:
- **Shape**: Round, short, with a wide base (like a desk lamp)
- **Head**: Single large "eye" that flickers like a fluorescent light
- **Body**: Textured like office carpet or cubicle walls
- **Color**: Muted yellow (#cac2a9) with gray (#858c9c) details
- **Glow**: Soft white light from the "eye"

**Behavior**:
- Wanders slowly along corridors
- "Flickers" (turns invisible briefly) when player isn't looking directly
- Wind-up: Eye glows brighter, body pulses (2 second telegraph)
- Attack: Emits a gentle push (not damage) in a cone
- Avoidable: Moves at 2 m/s, telegraph is obvious

**Collision**:
- Body: Capsule3D, radius 0.5m, height 1.0m
- Attack: Area3D cone, 60° angle, 5m range

**Parental Safety**:
- No violence, just environmental effect
- Can be "turned off" by finding a light switch

**Animations**:
- Idle: Gentle floating, eye flickers
- Walk: Slow sliding motion
- Wind-up: Body pulses, eye brightens
- Attack: Quick flash, no follow-through
- Hurt: Body compresses (squash), eye dims

#### Creature 2: "The Scrapper" (Based on Entity 20 - Scits)

**Design**:
- **Shape**: Small, four-legged, like a simplified office chair on legs
- **Head**: Box-shaped with a single slot for a "mouth"
- **Body**: Textured like metal office furniture
- **Color**: Dark gray (#3d4456) with silver highlights
- **Details**: Carries small office items (staplers, pens)

**Behavior**:
- Scavenges and collects small objects
- Wind-up: Stops moving, drops carried items, sits back (1.5s telegraph)
- Attack: Rolls forward quickly, pushing player (no damage)
- Avoidable: Can be distracted by throwing objects
- Puzzle: Returns collected items when player solves a simple puzzle

**Collision**:
- Body: Box3D, size 0.8m x 0.6m x 0.6m
- Attack: Area3D in front, triggers on contact

**Parental Safety**:
- Non-violent interaction
- Teaches resource management

**Animations**:
- Idle: Digging/rummaging animation
- Walk: Rolls on four legs
- Wind-up: Rears back, items rattle
- Attack: Rolls forward quickly
- Collect: Picks up item with "mouth"

#### Creature 3: "The Wayfinder" (Based on Entity 131 - The Concierge)

**Design**:
- **Shape**: Tall, thin, humanoid silhouette
- **Head**: Featureless except for a floating name tag that reads "HELP"
- **Body**: Textured like a maintenance uniform
- **Color**: Muted blue (#858c9c) with white name tag
- **Details**: Holds a glowing floor plan

**Behavior**:
- Stands at intersections
- Points in safe directions
- Wind-up: Raises floor plan, glows brighter (3s telegraph)
- "Attack": Creates a safe path marker (not harmful)
- Avoidable: Doesn't chase, only appears at decision points
- Helpful: Can be followed to exit

**Collision**:
- Body: Capsule3D, radius 0.3m, height 1.8m
- Interaction: Area3D for detection

**Parental Safety**:
- Actually helpful
- Rewards exploration

**Animations**:
- Idle: Points in random directions
- Point: Extends arm toward safe path
- Wind-up: Floor plan glows, arm raises
- Help: Nods, floor plan pulses

### Category 2: Maintenance Liminal Creatures (Backrooms Level 4+)

#### Creature 4: "The Pipe Crawler" (Based on Entity 128 - ΩMEGA)

**Design**:
- **Shape**: Long, segmented, like a pipe with eyes
- **Head**: Round end with two large, friendly eyes
- **Body**: Textured like galvanized metal with rust
- **Color**: Silver-gray (#a3a094) with orange rust accents
- **Glow**: Eyes emit soft blue light

**Behavior**:
- Moves along ceilings and pipes
- Wind-up: Body segments compress, eyes spin (2s telegraph)
- Attack: Drops harmless water droplets (pushes player)
- Avoidable: Only attacks when player stands directly below
- Puzzle: Can be ridden along pipes to reach high areas

**Collision**:
- Body: Multiple Capsule3D segments
- Attack: Area3D below, rain effect

**Parental Safety**:
- Water-based, not violent
- Encourages platforming

**Animations**:
- Idle: Eyes blink slowly
- Move: Segments flow like a caterpillar
- Wind-up: Segments bunch together
- Attack: Water drips from bottom

#### Creature 5: "The Flicker Flea" (Based on Entity 129 - βETA)

**Design**:
- **Shape**: Small, round, like a bouncing ball with legs
- **Head**: Large eyes on stalks
- **Body**: Textured like static/flickering TV screen
- **Color**: Alternating gray patterns (#737064 and #a3a094)
- **Glow**: Eyes pulse with light

**Behavior**:
- Jumps around quickly
- Wind-up: Stops moving, screen static intensifies (1s telegraph)
- Attack: Quick bounce into player (minimal push)
- Avoidable: Easy to dodge, telegraph is fast but clear
- Puzzle: Can be herded to activate switches

**Collision**:
- Body: Sphere3D, radius 0.3m
- Attack: Small Area3D on contact

**Parental Safety**:
- Small and non-threatening
- Teaches timing and dodging

**Animations**:
- Idle: Bounces in place, eyes look around
- Move: Fast bouncing
- Wind-up: Static pattern freezes
- Attack: Quick forward bounce

#### Creature 6: "The Maintenance Mimic" (Based on Entity 126 - Scarecrows)

**Design**:
- **Shape**: Boxy, like a maintenance cart
- **Head**: A broom or mop as "hair"
- **Body**: Textured like cleaning equipment
- **Color**: Yellow (#cac2a9) with red accents
- **Details**: Has wheels and a friendly "face" made of tools

**Behavior**:
- Stays stationary, pretending to be part of the environment
- Wind-up: Tools rattle, wheels creak (2s telegraph)
- Attack: Rolls forward a short distance
- Avoidable: Very slow, easy to see coming
- Puzzle: Can be pushed to clear paths

**Collision**:
- Body: Box3D with rounded edges
- Attack: Movement-based

**Parental Safety**:
- Non-violent, puzzle element
- Teaches observation

**Animations**:
- Idle: Slight wobble, like settling
- Wind-up: Tools shake, wheels turn slightly
- Attack: Rolls forward slowly

### Category 3: Industrial Liminal Creatures (Backrooms Level 3999+)

#### Creature 7: "The Static Sprite" (Original Design)

**Design**:
- **Shape**: Small, humanoid, but made of shifting static
- **Head**: A floating TV screen with pixel eyes
- **Body**: Particles that form and reform
- **Color**: Black and white with occasional color glitches
- **Glow**: Screen emits flickering light

**Behavior**:
- Appears and disappears
- Wind-up: Static intensifies, TV turns on (1.5s telegraph)
- Attack: TV emits a harmless "glitch wave" (visual effect only)
- Avoidable: Disappears if player looks away
- Puzzle: Can be stabilized by finding signal boosters

**Collision**:
- Body: Capsule3D, semi-transparent
- Attack: Visual effect only

**Parental Safety**:
- More visual than physical
- Teaches pattern recognition

**Animations**:
- Idle: Static shifts, form changes subtly
- Wind-up: Static intensifies, TV powers on
- Attack: Glitch wave emits
- Disappear: Fades to static

#### Creature 8: "The Echo" (Original Design)

**Design**:
- **Shape**: Semi-transparent humanoid
- **Head**: Featureless, just a glowing outline
- **Body**: Made of sound waves/echoes
- **Color**: Translucent blue (#858c9c) with white outline
- **Glow**: Pulsing opacity

**Behavior**:
- Mimics player's recent actions
- Wind-up: Form solidifies, sound waves ripple (2s telegraph)
- Attack: Plays back player's last sound (confusion effect)
- Avoidable: Only appears after player makes noise
- Puzzle: Can be used to trigger sound-based puzzles

**Collision**:
- Body: Ghost-like, passes through some objects
- Attack: Area3D for sound effect

**Parental Safety**:
- Non-physical interaction
- Encourages stealth gameplay

**Animations**:
- Idle: Form shifts, opacity changes
- Wind-up: Form becomes more solid
- Attack: Sound waves emit from body

### Category 4: Special Liminal Creatures

#### Creature 9: "The Pathlight" (Friendly Helper)

**Design**:
- **Shape**: Floating orb with a handle (like a lantern)
- **Head**: No distinct head, just a glowing core
- **Body**: Textured like frosted glass
- **Color**: Warm white/yellow (#e9e7d8) glow
- **Glow**: Illuminates surroundings

**Behavior**:
- Follows player at a distance
- Illuminates dark areas
- Wind-up: None (friendly)
- "Attack": None (helpful only)
- Avoidable: N/A
- Puzzle: Can be carried to light the way

**Collision**:
- Body: Sphere3D with light
- Interaction: Light area

**Parental Safety**:
- Completely friendly
- Provides assistance

**Animations**:
- Idle: Floating gently
- Move: Follows player smoothly
- Glow: Pulses softly

#### Creature 10: "The Chooser" (Boss-Level, Original Design)

**Design**:
- **Shape**: Large, multi-part, like a door with limbs
- **Head**: A door handle as a "nose", hinges as "eyes"
- **Body**: Textured like wood and metal
- **Color**: Dark brown (#424034) with gold accents
- **Glow**: Hinges emit a golden glow

**Behavior**:
- Guards special areas
- Wind-up: Doors creak open, revealing choices (3s telegraph)
- Attack: Presents a choice (both options are non-harmful)
- Avoidable: Can be bypassed with correct puzzle solution
- Puzzle: Must choose the correct door to proceed

**Collision**:
- Body: Multiple collision boxes for door parts
- Interaction: UI for choices

**Parental Safety**:
- Decision-based, not combat
- Teaches problem-solving

**Animations**:
- Idle: Doors swing slightly
- Wind-up: Doors open wide
- Attack: Choice UI appears
- Close: Doors shut

---

## 3D Model Sources & Asset Pipelines

### Free CC0 Model Sources

#### 1. **Backrooms-Specific Models**

| Source | URL | Format | License | Notes |
|--------|-----|--------|---------|-------|
| Meshy Backrooms | [https://www.meshy.ai/tags/backroom](https://www.meshy.ai/tags/backroom) | GLB/GLTF | CC0 | Pre-made Backrooms entities |
| Sketchfab (hooganius) | [https://sketchfab.com/3d-models/backrooms-monster-687ee5d0ea3442f284a21d52ce76e87a](https://sketchfab.com/3d-models/backrooms-monster-687ee5d0ea3442f284a21d52ce76e87a) | GLTF | Free | Check individual license |
| Sketchfab (Death_Trap87) | [https://sketchfab.com/3d-models/bacteria-monster-backrooms-148bd0a721a14ed89bba00ff9e4260e7](https://sketchfab.com/3d-models/bacteria-monster-backrooms-148bd0a721a14ed89bba00ff9e4260e7) | GLTF | Free | Bacteria monster style |
| CGTrader Backrooms | [https://www.cgtrader.com/3d-models/backrooms](https://www.cgtrader.com/3d-models/backrooms) | FBX/OBJ | Varies | Check CC0 filter |

#### 2. **General CC0 Model Sources (Adaptable)

| Source | URL | Format | License | Notes |
|--------|-----|--------|---------|-------|
| Quaternius | [https://quaternius.com](https://quaternius.com) | GLB/FBX | CC0 | Universal Base Characters |
| Kenney | [https://kenney.nl](https://kenney.nl) | GLB/FBX | CC0 | Monster Builder Pack |
| Poly Pizza | [https://poly.pizza](https://poly.pizza) | GLB | CC0 | Free bundles |
| Kenney Monster Builder | [https://kenney.nl/assets/monster-builder-pack](https://kenney.nl/assets/monster-builder-pack) | PNG/Sprite | CC0 | 2D, can be 3Dified |
| LuizMelo Monsters | [https://luizmelo.itch.io/monsters-creatures-fantasy](https://luizmelo.itch.io/monsters-creatures-fantasy) | FBX | CC0 | Fantasy creatures |

#### 3. **Blender Creation Pipeline**

For creating custom Backrooms creatures:

```
1. Concept Art
   ├── Silhouette sketches (black outlines)
   ├── Color palette tests (using Backrooms palette)
   └── Turnaround sheets (front, side, back views)

2. Blockout (Blender)
   ├── Primitive shapes (cubes, spheres)
   ├── Correct proportions
   └── Basic pose

3. Sculpting
   ├── High-poly sculpt (if needed)
   ├── Retopology to low-poly
   └── UV Unwrapping

4. Texturing
   ├── Backrooms materials (concrete, metal, carpet)
   ├── Muted color palette
   └── PBR workflow

5. Rigging
   ├── Armature (bones)
   ├── Weight painting
   └── Shape keys (for facial animation)

6. Animation
   ├── Idle
   ├── Walk
   ├── Wind-up
   ├── Attack
   └── Hurt

7. Export
   ├── GLB format (recommended)
   ├── Include armature
   ├── Include animations
   └── Include shape keys

8. Godot Import
   ├── Import GLB
   ├── Verify mesh
   ├── Verify animations
   └── Set up materials
```

### Recommended Model Specifications

| Type | Polygons | Vertices | Textures | LOD |
|------|----------|----------|----------|-----|
| Simple Creature (Flicker Flea) | < 500 | < 1000 | 1x 512px | 1 level |
| Medium Creature (The Flicker) | < 2000 | < 4000 | 1x 1024px | 2 levels |
| Complex Creature (Pipe Crawler) | < 5000 | < 10000 | 2x 1024px | 2 levels |
| Boss Creature (The Chooser) | < 10000 | < 20000 | 2x 2048px | 3 levels |

---

## Godot Enemy Controller Architecture

### Node Structure

```
Creature (CharacterBody3D)
├── MeshInstance3D          # Visual model
│   ├── MaterialOverrides
│   └── ShaderMaterials
├── Skeleton3D             # Armature (if rigged)
├── CollisionShape3D       # Body collision
├── AttackArea3D           # Attack detection
├── TelegraphArea3D        # Telegraph warning zone
├── AnimationPlayer        # Animations
├── StateMachine           # State management
│   ├── IdleState
│   ├── WanderState
│   ├── ChaseState
│   ├── WindupState        # NEW: Telegraph
│   ├── AttackState
│   ├── HurtState
│   └── DieState
├── NavigationAgent3D      # Pathfinding (optional)
├── AudioStreamPlayer3D    # Sounds
└── FacialPerformance      # Facial animation (VS-024)
```

### Base Creature Class

```gdscript
# src/adapters/inbound/gameplay/creatures/creature_base.gd

class_name CreatureBase
extends CharacterBody3D

# Configuration
@export_group("Stats")
@export var max_health: int = 100
@export var move_speed: float = 2.0
@export var chase_speed: float = 3.5
@export var attack_range: float = 3.0
@export var attack_cooldown: float = 2.0
@export var windup_duration: float = 1.5
@export var detection_range: float = 8.0

@export_group("Combat")
@export var damage: int = 5
@export var knockback_force: float = 100.0
@export var can_attack: bool = true

@export_group("Visuals")
@export var mesh_instance: MeshInstance3D = null
@export var animation_player: AnimationPlayer = null

# State
var current_health: int = 0
var attack_timer: float = 0.0
var windup_timer: float = 0.0
var is_winding_up: bool = false
var target: Node3D = null

# Navigation
@onready var navigation_agent: NavigationAgent3D = $NavigationAgent3D

# Combat
@onready var attack_area: Area3D = $AttackArea3D
@onready var telegraph_area: Area3D = $TelegraphArea3D

# Audio
@onready var audio_player: AudioStreamPlayer3D = $AudioStreamPlayer3D

func _ready() -> void:
    current_health = max_health
    
    # Connect attack area
    attack_area.body_entered.connect(_on_attack_body_entered)
    
    # Setup navigation if available
    if navigation_agent:
        navigation_agent.path_desired_distance = 1.0

func _physics_process(delta: float) -> void:
    # Update timers
    attack_timer -= delta
    windup_timer -= delta
    
    # State machine
    _update_state(delta)

func _update_state(delta: float) -> void:
    # To be implemented by specific creature
    pass

# Combat
func take_damage(amount: int) -> void:
    current_health -= amount
    
    # Play hurt animation
    if animation_player and animation_player.has_animation("hurt"):
        animation_player.play("hurt")
    
    # Play sound
    if audio_player:
        play_sound("hurt")
    
    if current_health <= 0:
        die()

func play_sound(name: String) -> void:
    var stream := load_sound(name)
    if stream:
        audio_player.stream = stream
        audio_player.play()

func load_sound(name: String) -> AudioStream:
    var path := "res://assets/audio/creatures/%s/%s.wav" % [get_creature_name().to_lower(), name]
    if ResourceLoader.exists(path):
        return load(path)
    return null

func start_windup() -> void:
    is_winding_up = true
    windup_timer = windup_duration
    
    # Play windup animation
    if animation_player and animation_player.has_animation("windup"):
        animation_player.play("windup")
    
    # Enable telegraph area
    if telegraph_area:
        telegraph_area.monitoring = true
    
    # Play sound
    play_sound("windup")

func execute_attack() -> void:
    is_winding_up = false
    can_attack = false
    attack_timer = attack_cooldown
    
    # Play attack animation
    if animation_player and animation_player.has_animation("attack"):
        animation_player.play("attack")
    
    # Disable telegraph area
    if telegraph_area:
        telegraph_area.monitoring = false
    
    # Play sound
    play_sound("attack")

func _on_attack_body_entered(body: Node3D) -> void:
    if body is CharacterBody3D and can_attack:
        var damageable := body as IDamageable
        if damageable:
            damageable.take_damage(damage)
            
            # Apply knockback
            var knockback_dir := (body.global_position - global_position).normalized()
            body.apply_impulse(knockback_dir * knockback_force)

func die() -> void:
    # Play death animation
    if animation_player and animation_player.has_animation("die"):
        animation_player.play("die")
        await animation_player.animation_finished
    
    # Queue free
    queue_free()

# Movement
func move_toward(target_position: Vector3, speed: float) -> void:
    var direction := (target_position - global_position).normalized()
    velocity.x = direction.x * speed
    velocity.z = direction.z * speed
    move_and_slide()
    
    # Face direction
    if direction.length() > 0.1:
        look_at(target_position, Vector3.UP)

func wander() -> void:
    if navigation_agent and navigation_agent.is_navigation_finished():
        var random_target := get_random_position_in_range(detection_range)
        navigation_agent.set_target_position(random_target)
    
    if navigation_agent:
        var next_position := navigation_agent.get_next_path_position()
        move_toward(next_position, move_speed)

func get_random_position_in_range(range: float) -> Vector3:
    var random_point := Vector3(
        randf_range(-range, range),
        0,
        randf_range(-range, range)
    )
    return global_position + random_point

# State transitions
func can_see_target() -> bool:
    if not target:
        return false
    
    var direction := (target.global_position - global_position).normalized()
    var ray_origin := global_position + Vector3(0, 1, 0)
    var ray := PhysicsRayQueryParameters3D.new()
    ray.from = ray_origin
    ray.to = target.global_position + Vector3(0, 1, 0)
    ray.collide_with_areas = true
    
    var space_state := get_world_3d().direct_space_state
    var result := space_state.intersect_ray(ray)
    
    return result.has("collider") and result["collider"] == target

func get_creature_name() -> String:
    return name
```

---

## Wind-Up Telegraph System

### Telegraph Implementation

```gdscript
# src/adapters/inbound/gameplay/creatures/windup_telegraph.gd

class_name WindupTelegraph
extends Node3D

# Configuration
@export var telegraph_duration: float = 1.5
@export var telegraph_radius: float = 5.0
@export var telegraph_color: Color = Color.RED
@export var telegraph_pulse_speed: float = 2.0

# References
@onready var telegraph_area: Area3D = $TelegraphArea3D
@onready var telegraph_mesh: MeshInstance3D = $TelegraphMesh
@onready var creature: CreatureBase = get_parent()

# State
var is_active: bool = false
var timer: float = 0.0

func _ready() -> void:
    if telegraph_area:
        telegraph_area.body_entered.connect(_on_telegraph_body_entered)
        telegraph_area.body_exited.connect(_on_telegraph_body_exited)
        telegraph_area.monitoring = false
    
    if telegraph_mesh:
        telegraph_mesh.visible = false

func start_telegraph() -> void:
    is_active = true
    timer = telegraph_duration
    
    if telegraph_area:
        telegraph_area.monitoring = true
    
    if telegraph_mesh:
        telegraph_mesh.visible = true
        _start_pulse()

func stop_telegraph() -> void:
    is_active = false
    
    if telegraph_area:
        telegraph_area.monitoring = false
    
    if telegraph_mesh:
        telegraph_mesh.visible = false

func _process(delta: float) -> void:
    if not is_active:
        return
    
    timer -= delta
    
    if timer <= 0:
        stop_telegraph()
        if creature:
            creature.execute_attack()

func _start_pulse() -> void:
    if not telegraph_mesh:
        return
    
    var material := StandardMaterial3D.new()
    material.albedo_color = telegraph_color
    material.emission_enabled = true
    material.emission_color = telegraph_color * 2.0
    material.emission_energy = 2.0
    
    telegraph_mesh.material_override = material
    
    # Animate pulse
    var tween := create_tween()
    tween.tween_property(material, "emission_energy", 4.0, 0.5)
    tween.tween_property(material, "emission_energy", 2.0, 0.5)
    tween.set_loops()

func _on_telegraph_body_entered(body: Node3D) -> void:
    # Body entered telegraph zone
    if body is CharacterBody3D:
        # Visual feedback for player
        var player := body as IPlayer
        if player:
            player.show_warning("Danger!")

func _on_telegraph_body_exited(body: Node3D) -> void:
    # Body exited telegraph zone
    if body is CharacterBody3D:
        var player := body as IPlayer
        if player:
            player.hide_warning()
```

### Telegraph Visual Effects

```gdscript
# Alternative: Particle-based telegraph

class_name TelegraphParticles
extends Node3D

@export var particle_scene: PackedScene
@export var count: int = 20

var particles: Array = []

func _ready() -> void:
    spawn_particles()

func spawn_particles() -> void:
    for i in range(count):
        var p := particle_scene.instantiate()
        add_child(p)
        p.position = Vector3(
            randf_range(-2, 2),
            0,
            randf_range(-2, 2)
        )
        particles.append(p)

func start_effect() -> void:
    for p in particles:
        p.visible = true
        p.restart()

func stop_effect() -> void:
    for p in particles:
        p.visible = false
```

### Telegraph Sound Effects

```gdscript
# Wind-up sound that builds tension

func play_windup_sound() -> void:
    var audio := AudioStreamPlayer3D.new()
    add_child(audio)
    
    # Build tension with rising pitch
    var pitch_start := 0.8
    var pitch_end := 1.2
    
    var tween := create_tween()
    tween.tween_property(audio, "pitch_scale", pitch_end, telegraph_duration)
    
    # Play sound
    var stream := load("res://assets/audio/creatures/telegraph_build.wav")
    if stream:
        audio.stream = stream
        audio.pitch_scale = pitch_start
        audio.play()
        
        # Cleanup after
        await get_tree().create_timer(telegraph_duration).timeout
        audio.queue_free()
```

---

## Combat Integration

### Parenting Combat Policy

From `src/domain/identity_safety/parental_control_policy.gd`:

```gdscript
# CombatDifficulty enum
enum CombatDifficulty {
    PEACEFUL,      # No combat, creatures are friends
    EASY,         # Very soft, creatures barely harm
    NORMAL,       # Standard, balanced combat
    HARD,         # Challenging, for older kids
}

# Creature behavior based on policy
func get_creature_behavior(difficulty: CombatDifficulty) -> Dictionary:
    match difficulty:
        CombatDifficulty.PEACEFUL:
            return {
                "damage": 0,
                "can_attack": false,
                "behavior": "friendly",
                "telegraph": false
            }
        CombatDifficulty.EASY:
            return {
                "damage": 1,
                "can_attack": true,
                "behavior": "shy",
                "telegraph": true,
                "telegraph_duration": 3.0,
                "move_speed": 1.5
            }
        CombatDifficulty.NORMAL:
            return {
                "damage": 5,
                "can_attack": true,
                "behavior": "normal",
                "telegraph": true,
                "telegraph_duration": 2.0,
                "move_speed": 2.5
            }
        CombatDifficulty.HARD:
            return {
                "damage": 10,
                "can_attack": true,
                "behavior": "aggressive",
                "telegraph": true,
                "telegraph_duration": 1.5,
                "move_speed": 3.5
            }
```

### Soft Combat Implementation

```gdscript
# Soft aim assist and other safety features from VS-005

class_name SoftCombatSystem
extends Node

@export var aim_assist_radius: float = 2.0
@export var aim_assist_strength: float = 0.5
@export var hitstop_duration: float = 0.1

func apply_aim_assist(player: Node3D, target: Node3D) -> Vector3:
    var direction := (target.global_position - player.global_position).normalized()
    var current_aim := player.get_aim_direction()
    
    var angle := current_aim.angle_to(direction)
    if angle < deg_to_rad(aim_assist_radius):
        return lerp(current_aim, direction, aim_assist_strength)
    
    return current_aim

func trigger_hitstop() -> void:
    var time_scale := Time.get_ticks_per_second()
    Time.set_time_scale(time_scale * 0.1)
    await get_tree().create_timer(hitstop_duration).timeout
    Time.set_time_scale(time_scale)
```

---

## State Machine Implementation

### Complete State Machine with Telegraph

```gdscript
# src/adapters/inbound/gameplay/creatures/state_machine.gd

class_name CreatureStateMachine
extends Node

signal state_changed(old_state: String, new_state: String)

@export var initial_state: CreatureState

var current_state: CreatureState = null
var states: Dictionary = {}

func _ready() -> void:
    # Register all states
    for child in get_children():
        if child is CreatureState:
            child.state_machine = self
            child.creature = get_parent() as CreatureBase
            states[child.name.to_lower()] = child
            child.process_mode = Node.PROCESS_MODE_DISABLED
    
    # Start with initial state
    if initial_state:
        change_state(initial_state.name.to_lower())

func _process(delta: float) -> void:
    if current_state:
        current_state.update(delta)

func _physics_process(delta: float) -> void:
    if current_state:
        current_state.physics_update(delta)

func change_state(new_state_name: String) -> void:
    if not states.has(new_state_name):
        return
    
    var old_state_name := current_state.name.to_lower() if current_state else ""
    
    # Exit current state
    if current_state:
        current_state.exit()
        current_state.process_mode = Node.PROCESS_MODE_DISABLED
    
    # Enter new state
    current_state = states[new_state_name]
    current_state.process_mode = Node.PROCESS_MODE_INHERIT
    current_state.enter()
    
    state_changed.emit(old_state_name, new_state_name)

func get_state(name: String) -> CreatureState:
    return states.get(name.to_lower(), null)
```

### Base State Class

```gdscript
# src/adapters/inbound/gameplay/creatures/state.gd

class_name CreatureState
extends Node

var state_machine: CreatureStateMachine = null
var creature: CreatureBase = null

func enter() -> void:
    pass

func exit() -> void:
    pass

func update(delta: float) -> void:
    pass

func physics_update(delta: float) -> void:
    pass

# Helper functions
func can_see_player() -> bool:
    return creature.can_see_target() if creature else false

func get_player_distance() -> float:
    if creature and creature.target:
        return creature.global_position.distance_to(creature.target.global_position)
    return float(INF)

func move_toward_target(speed: float) -> void:
    if creature and creature.target:
        creature.move_toward(creature.target.global_position, speed)

func start_windup() -> void:
    if creature:
        creature.start_windup()
    
    if state_machine:
        state_machine.change_state("windup")
```

### Individual State Implementations

```gdscript
# Idle State
# src/adapters/inbound/gameplay/creatures/states/idle_state.gd

class_name IdleState
extends CreatureState

@export var idle_timeout: float = 3.0
@export var wander_distance: float = 10.0

var idle_timer: float = 0.0

func enter() -> void:
    if creature and creature.animation_player:
        creature.animation_player.play("idle")
    
    idle_timer = 0.0

func physics_update(delta: float) -> void:
    idle_timer += delta
    
    if idle_timer >= idle_timeout:
        state_machine.change_state("wander")
    
    # Check for player
    if can_see_player() and get_player_distance() < creature.detection_range:
        state_machine.change_state("chase")

# Wander State
# src/adapters/inbound/gameplay/creatures/states/wander_state.gd

class_name WanderState
extends CreatureState

@export var waypoint_radius: float = 5.0

var target_position: Vector3 = Vector3.ZERO

func enter() -> void:
    if creature:
        target_position = creature.get_random_position_in_range(10.0)
    
    if creature and creature.animation_player:
        creature.animation_player.play("walk")

func physics_update(delta: float) -> void:
    if creature:
        var distance := creature.global_position.distance_to(target_position)
        
        if distance < waypoint_radius:
            # Reached target, go back to idle
            state_machine.change_state("idle")
        else:
            creature.move_toward(target_position, creature.move_speed)
    
    # Check for player
    if can_see_player() and get_player_distance() < creature.detection_range:
        state_machine.change_state("chase")

# Chase State
# src/adapters/inbound/gameplay/creatures/states/chase_state.gd

class_name ChaseState
extends CreatureState

func enter() -> void:
    if creature and creature.animation_player:
        creature.animation_player.play("run")

func physics_update(delta: float) -> void:
    if creature and creature.target:
        move_toward_target(creature.chase_speed)
    
    # Check if in attack range
    if can_see_player() and get_player_distance() <= creature.attack_range:
        start_windup()
    
    # Lose player
    if not can_see_player():
        state_machine.change_state("idle")

# Windup State
# src/adapters/inbound/gameplay/creatures/states/windup_state.gd

class_name WindupState
extends CreatureState

var windup_timer: float = 0.0

func enter() -> void:
    windup_timer = 0.0
    
    if creature:
        creature.start_windup()
    
    if creature and creature.animation_player:
        creature.animation_player.play("windup")

func physics_update(delta: float) -> void:
    windup_timer += delta
    
    # Stay facing player during windup
    if creature and creature.target:
        creature.look_at(creature.target.global_position, Vector3.UP)
    
    # Transition to attack after windup
    if windup_timer >= creature.windup_duration:
        state_machine.change_state("attack")

func exit() -> void:
    if creature:
        creature.is_winding_up = false

# Attack State
# src/adapters/inbound/gameplay/creatures/states/attack_state.gd

class_name AttackState
extends CreatureState

@export var attack_timeout: float = 0.5

var attack_timer: float = 0.0

func enter() -> void:
    attack_timer = 0.0
    
    if creature:
        creature.execute_attack()
    
    if creature and creature.animation_player:
        creature.animation_player.play("attack")

func physics_update(delta: float) -> void:
    attack_timer += delta
    
    if attack_timer >= attack_timeout:
        # Return to chase or idle
        if can_see_player() and get_player_distance() <= creature.detection_range:
            state_machine.change_state("chase")
        else:
            state_machine.change_state("idle")

# Hurt State
# src/adapters/inbound/gameplay/creatures/states/hurt_state.gd

class_name HurtState
extends CreatureState

@export var hurt_duration: float = 0.5

var hurt_timer: float = 0.0

func enter() -> void:
    hurt_timer = 0.0
    
    if creature and creature.animation_player:
        creature.animation_player.play("hurt")

func physics_update(delta: float) -> void:
    hurt_timer += delta
    
    if hurt_timer >= hurt_duration:
        # Return to previous state
        if can_see_player() and get_player_distance() <= creature.detection_range:
            state_machine.change_state("chase")
        else:
            state_machine.change_state("idle")
```

---

## Parenting & Combat Policy Compliance

### Combat Policy Implementation

```gdscript
# src/adapters/inbound/gameplay/creatures/parental_combat_policy.gd

class_name ParentalCombatPolicy
extends Node

# Settings from parent
@export var combat_difficulty: int = CombatDifficulty.NORMAL

# Overrides for different age groups
var policy_overrides: Dictionary = {
    "age_3_5": {
        "creatures_can_attack": false,
        "creatures_flee_from_player": true,
        "damage_multiplier": 0.0,
        "telegraph_duration": 5.0,
        "creature_speed": 1.0
    },
    "age_6_8": {
        "creatures_can_attack": true,
        "creatures_flee_from_player": true,
        "damage_multiplier": 0.25,
        "telegraph_duration": 3.0,
        "creature_speed": 1.5
    },
    "age_9_12": {
        "creatures_can_attack": true,
        "creatures_flee_from_player": false,
        "damage_multiplier": 0.75,
        "telegraph_duration": 2.0,
        "creature_speed": 2.5
    },
    "age_13+": {
        "creatures_can_attack": true,
        "creatures_flee_from_player": false,
        "damage_multiplier": 1.0,
        "telegraph_duration": 1.5,
        "creature_speed": 3.5
    }
}

func apply_policy_to_creature(creature: CreatureBase) -> void:
    var age_group := get_age_group()
    var override := policy_overrides.get(age_group, policy_overrides["age_9_12"])
    
    creature.can_attack = override["creatures_can_attack"]
    creature.damage = int(creature.damage * override["damage_multiplier"])
    creature.windup_duration = override["telegraph_duration"]
    creature.move_speed = override["creature_speed"]
    creature.chase_speed = override["creature_speed"] * 1.5

func get_age_group() -> String:
    # Based on parental settings
    var age := get_parental_settings().get("child_age", 8)
    
    match age:
        3, 4, 5: return "age_3_5"
        6, 7, 8: return "age_6_8"
        9, 10, 11, 12: return "age_9_12"
        _: return "age_13+"

func get_parental_settings() -> Dictionary:
    # Load from settings system
    return ProjectSettings.get_setting("identity_safety/parental_settings", {})
```

### Soft Combat Features

Based on VS-005 evidence:

```gdscript
# src/adapters/inbound/gameplay/creatures/soft_combat_features.gd

class_name SoftCombatFeatures
extends Node

# Soft aim assist (from VS-005)
@export var soft_aim_assist: bool = true
@export var aim_assist_radius: float = 15.0  # degrees
@export var aim_assist_strength: float = 0.3

# Easy mode settings
@export var easy_mode: bool = true

func apply_soft_aim(player: Node3D, target: Node3D, camera: Camera3D) -> Vector3:
    if not soft_aim_assist or not easy_mode:
        return player.get_aim_direction()
    
    var screen_pos := camera.project_point(target.global_position)
    var player_screen_pos := camera.project_point(player.global_position)
    
    var screen_distance := screen_pos.distance_to(player_screen_pos)
    
    if screen_distance < aim_assist_radius:
        # Calculate direction with assist
        var direction := (target.global_position - player.global_position).normalized()
        var current_aim := player.get_aim_direction()
        return lerp(current_aim, direction, aim_assist_strength)
    
    return player.get_aim_direction()

# Damage numbers (from VS-005 evidence)
func show_damage_number(position: Vector3, amount: int) -> void:
    var damage_ui := DamageNumber.new()
    damage_ui.position = position
    damage_ui.show_number(amount)
    get_tree().root.add_child(damage_ui)
```

---

## Code Samples & Implementation Patterns

### Complete Creature Implementation (The Flicker)

```gdscript
# src/adapters/inbound/gameplay/creatures/flicker.gd

class_name Flicker
extends CreatureBase

# Configuration
@export var max_health: int = 50
@export var move_speed: float = 2.0
@export var chase_speed: float = 3.0
@export var attack_range: float = 4.0
@export var windup_duration: float = 2.0
@export var detection_range: float = 8.0

# Visuals
@export var flicker_interval: float = 1.0
@export var flicker_duration: float = 0.2

# State
var is_visible: bool = true
var flicker_timer: float = 0.0
var time_since_seen: float = 0.0

func _ready() -> void:
    super._ready()
    
    # Setup state machine
    var state_machine := $StateMachine
    if state_machine:
        state_machine.initial_state = $IdleState
        state_machine.state_changed.connect(_on_state_changed)

func _physics_process(delta: float) -> void:
    super._physics_process(delta)
    
    # Update flicker effect
    _update_flicker(delta)

func _update_flicker(delta: float) -> void:
    flicker_timer += delta
    
    # Flicker if player is not looking directly
    if can_see_target():
        time_since_seen = 0.0
        is_visible = true
    else:
        time_since_seen += delta
        
        if time_since_seen > flicker_interval:
            is_visible = !is_visible
            flicker_timer = 0.0
    
    # Update visibility
    if mesh_instance:
        mesh_instance.visible = is_visible

func _on_state_changed(old_state: String, new_state: String) -> void:
    # Flicker effect during state changes
    if new_state == "windup":
        # Rapid flicker during windup
        is_visible = !is_visible
    elif new_state == "attack":
        is_visible = true

# Override movement for flickering effect
func move_toward(target_position: Vector3, speed: float) -> void:
    if is_visible:
        super.move_toward(target_position, speed)
    else:
        velocity = Vector3.ZERO
        move_and_slide()
```

### Creature Scene Setup

```text
Flicker.tscn (CharacterBody3D)
├── MeshInstance3D
│   └── StandardMaterial3D (albedo: #cac2a9)
├── CollisionShape3D (Capsule, r=0.5, h=1.0)
├── AttackArea3D (Cone, 60°, range=5)
├── TelegraphArea3D (Sphere, r=5)
├── StateMachine
│   ├── IdleState
│   ├── WanderState
│   ├── ChaseState
│   ├── WindupState
│   └── AttackState
├── NavigationAgent3D
├── AudioStreamPlayer3D
├── AnimationPlayer
│   ├── idle (loop)
│   ├── walk (loop)
│   ├── run (loop)
│   ├── windup
│   └── attack
└── FacialPerformance (optional, for expression)
```

### Creature Spawner System

```gdscript
# src/adapters/inbound/gameplay/creatures/creature_spawner.gd

class_name CreatureSpawner
extends Node3D

@export var creature_scenes: Array[PackedScene]
@export var spawn_points: Array[Node3D]
@export var max_creatures: int = 5
@export var spawn_interval: float = 10.0

var active_creatures: Array = []
var spawn_timer: float = 0.0

func _ready() -> void:
    _spawn_initial_creatures()

func _process(delta: float) -> void:
    spawn_timer += delta
    
    if spawn_timer >= spawn_interval:
        spawn_timer = 0.0
        _spawn_creature()

func _spawn_initial_creatures() -> void:
    for i in range(min(spawn_points.size(), max_creatures)):
        _spawn_creature()

func _spawn_creature() -> void:
    if active_creatures.size() >= max_creatures:
        return
    
    if spawn_points.is_empty() or creature_scenes.is_empty():
        return
    
    # Select random scene and spawn point
    var scene := creature_scenes[randi() % creature_scenes.size()]
    var spawn_point := spawn_points[randi() % spawn_points.size()]
    
    var creature := scene.instantiate()
    creature.global_position = spawn_point.global_position
    
    # Setup creature
    creature.target = get_node("/root/World/Player")
    
    # Apply parental policy
    var policy := get_node("/root/ParentalCombatPolicy")
    if policy:
        policy.apply_policy_to_creature(creature)
    
    add_child(creature)
    active_creatures.append(creature)
    
    # Connect to removal
    creature.tree_exited.connect(_on_creature_removed.bind(creature))

func _on_creature_removed(creature: Node) -> void:
    active_creatures.erase(creature)

func remove_all_creatures() -> void:
    for creature in active_creatures:
        creature.queue_free()
    active_creatures.clear()
```

---

## Testing & Validation Checklist

### Unit Tests

```gdscript
# tests/adapters/inbound/test_creature_system.gd

class_name TestCreatureSystem
extends TestCase

func test_creature_spawn():
    var spawner := CreatureSpawner.new()
    var creature_scene := load("res://adapters/inbound/gameplay/creatures/flicker.tscn")
    spawner.creature_scenes = [creature_scene]
    
    var spawn_point := Node3D.new()
    spawn_point.position = Vector3(5, 0, 5)
    spawner.add_child(spawn_point)
    spawner.spawn_points = [spawn_point]
    
    spawner._spawn_creature()
    
    assert(spawner.active_creatures.size() == 1, "Should spawn one creature")

func test_state_machine():
    var creature := Flicker.new()
    var state_machine := CreatureStateMachine.new()
    
    var idle := IdleState.new()
    var chase := ChaseState.new()
    
    state_machine.add_child(idle)
    state_machine.add_child(chase)
    state_machine.initial_state = idle
    
    creature.add_child(state_machine)
    creature._ready()
    
    assert(state_machine.current_state == idle, "Should start in idle state")
    
    state_machine.change_state("chase")
    assert(state_machine.current_state == chase, "Should change to chase state")

func test_windup_telegraph():
    var creature := Flicker.new()
    var telegraph := WindupTelegraph.new()
    
    creature.add_child(telegraph)
    telegraph.start_telegraph()
    
    assert(telegraph.is_active, "Telegraph should be active")
    assert(telegraph.timer > 0, "Timer should be set")

func test_parental_policy():
    var policy := ParentalCombatPolicy.new()
    policy.combat_difficulty = CombatDifficulty.EASY
    
    var creature := Flicker.new()
    creature._ready()
    
    policy.apply_policy_to_creature(creature)
    
    assert(creature.damage == 1, "Damage should be reduced in easy mode")
    assert(creature.windup_duration == 3.0, "Windup should be longer in easy mode")
```

### Manual Testing Checklist

#### Creature Behavior

- [ ] **The Flicker**
  - [ ] Flickers when player isn't looking
  - [ ] Stays visible when player is looking
  - [ ] Wind-up includes glowing eye
  - [ ] Attack is a gentle push
  - [ ] Collision matches visual size
  
- [ ] **The Scrapper**
  - [ ] Collects objects
  - [ ] Drops objects during wind-up
  - [ ] Rolls forward for attack
  - [ ] Can be distracted
  - [ ] Returns items when puzzle solved
  
- [ ] **The Wayfinder**
  - [ ] Stands at intersections
  - [ ] Points in safe directions
  - [ ] Creates path markers
  - [ ] Helpful to player
  - [ ] Doesn't attack
  
- [ ] **The Pipe Crawler**
  - [ ] Moves along pipes
  - [ ] Wind-up includes segment compression
  - [ ] Drops harmless water
  - [ ] Can be ridden
  - [ ] Collision matches pipe geometry
  
- [ ] **The Flicker Flea**
  - [ ] Jumps around quickly
  - [ ] Static texture effect
  - [ ] Fast wind-up
  - [ ] Easy to dodge
  - [ ] Small collision box

#### Telegraph System

- [ ] Each creature has a wind-up state
- [ ] Wind-up duration matches difficulty setting
- [ ] Telegraph is visually clear
- [ ] Telegraph has audio cue
- [ ] Player can react to telegraph
- [ ] Telegraph works from any angle

#### Combat Integration

- [ ] Creatures respect parental combat policy
- [ ] Soft aim assist works
- [ ] Hitstop effect triggers
- [ ] Damage numbers appear
- [ ] Knockback is appropriate
- [ ] Easy mode is softer

#### Visual & Audio

- [ ] All creatures use Backrooms color palette
- [ ] No bright, primary colors
- [ ] Muted, low-saturation textures
- [ ] Appropriate sound effects
- [ ] No scary sounds
- [ ] Visual quality is consistent

#### Performance

- [ ] Many creatures don't cause FPS drop
- [ ] Creatures despawn when far away
- [ ] Telegraph effects are optimized
- [ ] Collision is efficient
- [ ] Memory usage is stable

### Headless Parse Test

```bash
godot --headless --path . --editor --quit
```

Expected: No errors, clean exit code 0

---

## Learning Resources

### Official Godot Documentation

| Topic | URL |
|-------|-----|
| CharacterBody3D | [https://docs.godotengine.org/en/stable/classes/class_characterbody3d.html](https://docs.godotengine.org/en/stable/classes/class_characterbody3d.html) |
| Area3D | [https://docs.godotengine.org/en/stable/classes/class_area3d.html](https://docs.godotengine.org/en/stable/classes/class_area3d.html) |
| NavigationAgent3D | [https://docs.godotengine.org/en/stable/classes/class_navigationagent3d.html](https://docs.godotengine.org/en/stable/classes/class_navigationagent3d.html) |
| State Machine Pattern | [https://docs.godotengine.org/en/stable/getting_started/step_by_step/index.html](https://docs.godotengine.org/en/stable/getting_started/step_by_step/index.html) |

### Backrooms Resources

| Resource | URL |
|----------|-----|
| Backrooms Wiki - Entities | [https://backrooms-wiki.wikidot.com/entities](https://backrooms-wiki.wikidot.com/entities) |
| Backrooms Wiki - Levels | [https://backrooms-wiki.wikidot.com/levels](https://backrooms-wiki.wikidot.com/levels) |
| Backrooms Wiki - Main | [https://backrooms-wiki.wikidot.com/](https://backrooms-wiki.wikidot.com/) |

### 3D Model Sources

| Source | URL | License |
|--------|-----|---------|
| Meshy Backrooms | [https://www.meshy.ai/tags/backroom](https://www.meshy.ai/tags/backroom) | CC0 |
| Sketchfab Backrooms | [https://sketchfab.com/tags/backroom](https://sketchfab.com/tags/backroom) | Varies |
| CGTrader Backrooms | [https://www.cgtrader.com/3d-models/backrooms](https://www.cgtrader.com/3d-models/backrooms) | Varies |
| Quaternius Universal Monsters | [https://poly.pizza/bundle/Ultimate-Monsters-Bundle-5oyGWAmOB6](https://poly.pizza/bundle/Ultimate-Monsters-Bundle-5oyGWAmOB6) | CC0 |
| Kenney Monster Builder | [https://kenney.nl/assets/monster-builder-pack](https://kenney.nl/assets/monster-builder-pack) | CC0 |
| LuizMelo Fantasy Monsters | [https://luizmelo.itch.io/monsters-creatures-fantasy](https://luizmelo.itch.io/monsters-creatures-fantasy) | CC0 |

### State Machine Tutorials

| Resource | URL |
|----------|-----|
| Godot Learning - State Machine | [https://godotlearning.com/blog/godot-4-state-machine-tutorial](https://godotlearning.com/blog/godot-4-state-machine-tutorial) |
| Coding Quests - Enemy AI | [https://codingquests.io/blog/godot-4-2d-enemy-ai-tutorial](https://codingquests.io/blog/godot-4-2d-enemy-ai-tutorial) |
| GDQuest - Finite State Machine | [https://www.gdquest.com/tutorial/godot/design-patterns/finite-state-machine/](https://www.gdquest.com/tutorial/godot/design-patterns/finite-state-machine/) |
| YouTube: Godot State Machine | [https://www.youtube.com/watch?v=example](https://www.youtube.com/watch?v=example) |

### Creature Design Resources

| Resource | URL |
|----------|-----|
| Liminal Space Palettes | [https://lospec.com/palette-list/tag/liminal](https://lospec.com/palette-list/tag/liminal) |
| Child-Friendly Monster Design | [https://kreafolk.com/blogs/inspirations/monster-character-design](https://kreafolk.com/blogs/inspirations/monster-character-design) |
| Kid-Friendly Monsters | [https://dmingdad.com/kid-friendly-monsters/](https://dmingdad.com/kid-friendly-monsters/) |

### Community Resources

| Resource | URL |
|----------|-----|
| Godot Forum - AI & State Machines | [https://forum.godotengine.org/c/ai](https://forum.godotengine.org/c/ai) |
| Godot Discord | [https://discord.gg/4JBkykG](https://discord.gg/4JBkykG) |
| Reddit - r/godot | [https://www.reddit.com/r/godot/](https://www.reddit.com/r/godot/) |

---

## Summary & Recommendations

### Key Findings

1. **Backrooms Lore**: The Backrooms Wiki provides extensive entity reference that can be adapted for child-friendly designs
2. **Creature Design**: 10 original concepts developed, combining Backrooms aesthetic with child-safe features
3. **Asset Sources**: Multiple CC0 sources for Backrooms-specific models (Meshy, Sketchfab, CGTrader)
4. **Godot Architecture**: State machine pattern with dedicated WindupState for telegraph
5. **Parental Compliance**: Combat policy system with age-based difficulty scaling
6. **Existing Code**: Enemy controller already has WINDUP state, emission flash, and squash from VS-005

### Implementation Priority

1. **High Priority**:
   - Design and model 3-5 core creatures (The Flicker, The Scrapper, The Wayfinder)
   - Implement state machine with wind-up telegraph
   - Create collision boxes for each creature
   - Integrate with parental combat policy
   
2. **Medium Priority**:
   - Design remaining 5 creatures
   - Create telegraph visual effects
   - Implement spawn system
   - Add sound effects
   
3. **Low Priority**:
   - Advanced telegraph effects (particles, shaders)
   - Custom animations for all creatures
   - Creature-specific behaviors
   - Performance optimization (LOD, pooling)

### Estimated Effort

| Task | Complexity | Estimated Hours | Dependencies |
|------|------------|-----------------|--------------|
| Creature Design (10 concepts) | Medium | 8-12 | Art direction |
| 3D Modeling (3 creatures) | High | 12-20 | Designs |
| State Machine System | Medium | 8-12 | None |
| Wind-up Telegraph | Medium | 6-8 | State machine |
| Collision Setup | Low | 4-6 | Models |
| Parental Policy Integration | Low | 2-4 | VS-005 |
| Spawn System | Medium | 4-6 | State machine |
| Audio & Effects | Medium | 6-8 | Creatures |
| Testing & Validation | High | 10-16 | All systems |
| **Total** | | **64-108 hours** | |

### Risk Assessment

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Model licensing issues | Medium | Medium | Use CC0 sources only |
| Creature too scary | Medium | High | Parent review early |
| Performance with many creatures | Medium | High | Implement pooling/culling |
| Integration bugs | Medium | Medium | Test incrementally |

---

## Next Steps

1. **Finalize Creature Designs**: Review and approve 10 concepts with parent
2. **Source 3D Models**: Download CC0 Backrooms models from Meshy/Sketchfab
3. **Create Custom Models**: Model original creatures in Blender
4. **Import to Godot**: Test all models, verify animations and collision
5. **Implement State Machine**: Create StateMachine node with all states
6. **Add Telegraph System**: Implement WindupState with visual/audio cues
7. **Integrate Combat Policy**: Connect to parental settings
8. **Test All Creatures**: Validate behavior, collision, and visuals
9. **Create Spawn System**: Distribute creatures throughout Adventure
10. **Merge to Branch**: Commit changes to fix/adventure-thin-slice-combat-first-run

---

*Document Version: 1.0*  
*Generated: 2026-07-18*  
*Status: Ready for Implementation Review*
*Note: Includes Backrooms-inspired creatures as requested*
