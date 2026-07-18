# RESEARCH VS-011: Sandbox Interaction, Ecology & Discovery

## Choyce Engine - Vertical Slice Research Compendium

**Task ID:** VS-011  
**Title:** Polish sandbox interactions ecology and discovery feedback  
**Specialty:** sandbox-world  
**Status:** in_progress  
**Dependencies:** [VS-004]  
**Owner:** codex  
**Cross-review:** claude  

---

## Table of Contents

1. [Task Overview](#task-overview)
2. [Current Implementation Analysis](#current-implementation-analysis)
3. [Online Research Summary](#online-research-summary)
4. [Technical Deep Dive](#technical-deep-dive)
5. [Code Samples & Patterns](#code-samples--patterns)
6. [Asset Packages & Integration](#asset-packages--integration)
7. [Learning Resources](#learning-resources)
8. [Implementation Checklist](#implementation-checklist)
9. [Child-Safety Constraints](#child-safety-constraints)
10. [References](#references)

---

## Task Overview

### Objective

Polish the Adventure sandbox to create a compelling free-play experience with:
- **Free-Play Philosophy:** No goals, timers, or forced objectives
- **Rich Ecology:** Day/night cycles, weather, fauna, flora
- **Discovery Feedback:** Signposts, landmarks, non-combat interactions
- **Procedural Dressing:** Deterministic world decoration (houses, forest, beach, cave)
- **Performance:** Optimized for Tier 1 and Tier 2 hardware

### Acceptance Criteria (from backlog.yaml)

- [ ] Adventure remains free-play with no default goal, countdown timer, or finite lives
- [ ] Guide signposts, chest, and region landmarks provide at least one non-combat interaction path
- [ ] Procedural dressing is deterministic per world seed and includes houses, forest, beach, cave, flora, and fauna
- [ ] Discovery feedback is readable without requiring quest completion or combat
- [ ] Performance and density are measured on supported hardware tiers

### Existing Evidence (from backlog.yaml)

- `PLAN.md` - Vertical slice requirements
- `data/templates/adventure.json` - Template configuration
- `src/adapters/inbound/gameplay/world_renderer.gd` - Current world renderer
- `data/models/quaternius/medieval_village` - CC0 Quaternius Medieval Village MegaKit assets
- `src/adapters/inbound/gameplay/gameplay_runtime.gd` - Current gameplay runtime

---

## Current Implementation Analysis

### 1. WorldRenderer.gd

**File:** `src/adapters/inbound/gameplay/world_renderer.gd`  
**Purpose:** Renderer for streaming procedural world chunks  
**Key Features (from PLAN.md):**

- 5×5 player-relative chunk envelope
- Deterministic seed/version/coordinate chunk identity
- 2400m × 2400m (5.76km²) floor
- Physical coast barrier at 52m before edge
- Streamed procedural biomes

**From VS-019 Implementation:**
- Chunk-based deterministic generation
- Player-relative streaming
- Budget: 3.5ms per frame for world construction

### 2. Adventure Template

**File:** `data/templates/adventure.json`  
**Purpose:** Template definition for Adventure world  
**Key Features:**

- Sandbox/free-play session contract
- No compulsory targets, scores, timers, or victory screens
- Four readable landmark regions
- Natural traversal routes
- Flora, fauna, ambient motion
- Encounter zones distributed across island

### 3. Quaternius Medieval Village MegaKit

**Assets:** `data/models/quaternius/medieval_village`  
**Source:** [Quaternius Medieval Village MegaKit](https://quaternius.com/packs/medievalvillagemegakit.html)  
**License:** CC0  
**Features:**

- 300+ modular medieval assets
- Custom shaders for customizable wear colors
- Optimized collisions for each model
- Compatible with Godot 4.3+
- Modular pieces (walls, roofs, stairs) snap to grid

### 4. Current Gaps for VS-011

- No interaction system for signposts/chests
- No ecology systems (day/night, weather, animal AI)
- No discovery feedback mechanisms
- No deterministic procedural dressing implementation
- No performance benchmarking on hardware tiers

---

## Online Research Summary

### 1. Sandbox Interaction Systems

**Core Principle:** Free-play with emergent gameplay, no pressure

**Godot Implementation:**
- Use `Area3D` for proximity detection
- Simple, intuitive controls (no complex combos)
- Bright, cheerful visuals and sounds
- Undo/reset capabilities for experimentation

**Key Resources:**
- **[Kids Can Code: Godot 4 Recipes](https://kidscancode.org/godot_recipes/4.x/)** - Beginner-friendly guides
- **[GDQuest Learn Godot](https://www.gdquest.com/)** - Interactive courses
- **[itch.io: Free Sandbox Games](https://itch.io/games/free/made-with-godot/tag-sandbox)** - Inspiration examples

**Child-Safe Design Principles:**
- Open-ended play without scores/timers
- Simple, forgiving controls
- No fail states or punishment
- Creative tools (building, drawing, experimenting)

### 2. Ecology Systems

**Day/Night Cycle:**

| Plugin | Features | Godot Version | License |
|--------|----------|----------------|---------|
| **[Sky3D](https://github.com/TokisanGames/Sky3D)** | Dynamic sun/moon/stars, clouds, atmosphere | 4.x | MIT |
| **[TCA Weather System](https://github.com/kS222138/TCA_Weather_System)** | Volumetric clouds, dynamic sky, water shader, wind, seasons, precipitation | 4.x | MIT |
| **[Dynamic Day Night Cycles](https://godotengine.org/asset-library/asset/1693)** | Seasonal day-length variation, winter/summer | 4.x | CC0 |
| **[Day & Night Cycle](https://godotengine.org/asset-library/asset/4357)** | Simple, customizable | 4.x | MIT |

**Recommended:** Sky3D + TCA Weather System for full ecology

**Weather Effects:**
- Rain: Particle systems + audio
- Snow: GPUParticles3D + collision
- Wind: Shader-based foliage animation
- Fog: WorldEnvironment fog settings

**Seasons:**
- Texture swapping on terrain
- Foliage color changes via shader parameters
- Animal behavior variations

**Fauna AI:**
- State machines for animal behavior (idle, graze, flee)
- Simple pathfinding with NavigationServer3D
- Proximity detection with Area3D

### 3. Procedural World Dressing

**Approaches:**

| Method | Pros | Cons | Best For |
|--------|------|------|----------|
| **FastNoiseLite** | Fast, deterministic | Limited control | Terrain, biome maps |
| **PCG (Godot 4.6+)** | Native, optimized | Godot 4.6 only | Procedural generation |
| **Wave Function Collapse** | Rule-based, coherent | Complex setup | Buildings, dungeons |
| **Cellular Automata** | Natural caves | Slow for large areas | Cave systems |

**Key Resources:**
- **[Godot4-3D-Procedural-World-Generation](https://github.com/alpapaydin/Godot4-3D-Procedural-World-Generation)** - Noise-based, Minecraft-style
- **[Procedural Forest Demo](https://godotengine.org/asset-library/asset/5013)** - Deterministic biome scattering
- **[Godot Spatial Gardener](https://github.com/dreadpon/godot_spatial_gardener)** - Foliage painting plugin

**Deterministic Generation Pattern:**
```gdscript
# Pass world seed to all generators
func generate_chunk(chunk_pos: Vector3i, world_seed: int) -> void:
    var local_seed = hash(chunk_pos) + world_seed
    var noise = FastNoiseLite.new()
    noise.seed = local_seed
    
    # Generate terrain height
    var height = noise.get_noise_1d(x) * amplitude
    
    # Place features deterministically
    if noise.get_noise_2d(x, z) > 0.7:
        place_tree(x, z, local_seed)
```

### 4. Discovery Feedback Systems

**Interaction Detection:**
- `Area3D` for proximity detection
- `body_entered` / `body_exited` signals
- Group-based filtering (e.g., "player", "interactable")

**Feedback Types:**
- UI prompts: "Press E to read"
- Audio cues: Discovery sound effects
- Visual effects: Particle bursts, screen effects
- HUD updates: Quest log, discovery counter

**Key Resources:**
- **[Godot Recipes: Using Areas](https://kidscancode.org/godot_recipes/4.x/g101/3d/101_3d_04/index.html)** - Area3D tutorial
- **[Godot Forum: Interaction System](https://forum.godotengine.org/t/player-interacting-with-every-object/68602)** - Community discussion
- **[StraySpark: Dialogue & Quest Systems](https://www.strayspark.studio/blog/godot-4-dialogue-quest-systems-signals-resources)** - Signal-based patterns

### 5. Performance Optimization

**For Large 3D Worlds:**

| Technique | Use Case | Godot Implementation |
|-----------|----------|----------------------|
| **Occlusion Culling** | Indoor, complex scenes | `OccluderInstance3D` + baking |
| **Frustum Culling** | All scenes | Automatic |
| **LOD (Level of Detail)** | Open worlds | `LOD` node or `MeshInstance3D` |
| **Visibility Ranges** | Distant objects | `visibility_range_begin/end` |
| **Instancing** | Repeated objects | `MultiMeshInstance3D` |
| **Object Pooling** | Frequent spawn/despawn | Custom pool manager |

**Key Resources:**
- **[Godot Occlusion Culling Demo](https://godotengine.org/asset-library/asset/2744)** - Official demo
- **[Optimizing 3D Performance](https://docs.godotengine.org/en/stable/tutorials/performance/optimizing_3d_performance.html)** - Official docs
- **[Sky3D Official Page](https://tokisan.com/sky3d/)** - Atmospheric system

---

## Technical Deep Dive

### 1. Interaction System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                  Interaction System                            │
├─────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────┐     ┌──────────────┐     ┌──────────────┐ │
│  │   Player     │────▶│   Area3D    │────▶│  Interactable│ │
│  │ CharacterBody│     │  (Proximity) │     │   Object     │ │
│  └──────────────┘     └──────────────┘     └──────────────┘ │
│         │                    │                     │          │
│         ▼                    ▼                     ▼          │
│  ┌─────────────────────────────────────────────────────┐   │
│  │               Interaction Manager                   │   │
│  │  - Tracks current interactable                       │   │
│  │  - Handles input (E key, touch)                       │   │
│  │  - Emits interaction signals                         │   │
│  └─────────────────────────────────────────────────────┘   │
│                         │                                     │
│                         ▼                                     │
│  ┌─────────────────────────────────────────────────────┐   │
│  │                 UI Feedback Layer                      │   │
│  │  - "Press E to interact" prompt                        │   │
│  │  - Discovery text/Dialog                               │   │
│  │  - Visual/audio effects                                │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                                  │
└─────────────────────────────────────────────────────────────┘
```

### 2. Interactable Base Class

```gdscript
# interactable.gd
class_name Interactable
extends Node3D

signal interaction_requested(interactable: Interactable)
signal interacted(interactable: Interactable)

@export var interaction_range: float = 3.0
@export var interaction_text: String = "Press E to interact"
@export var can_interact: bool = true
@export var interact_once: bool = false

var _has_interacted: bool = false
var _player_in_range: bool = false

func _ready() -> void:
    _setup_trigger()

func _setup_trigger() -> void:
    var trigger = Area3D.new()
    trigger.position = Vector3.ZERO
    trigger.add_child(CollisionShape3D.new())
    
    var shape = SphereShape3D.new()
    shape.radius = interaction_range
    trigger.get_child(0).shape = shape
    
    trigger.body_entered.connect(_on_body_entered)
    trigger.body_exited.connect(_on_body_exited)
    add_child(trigger)

func _on_body_entered(body: Node) -> void:
    if body.is_in_group("player"):
        _player_in_range = true
        EventBus.emit_signal("interactable_entered", self)

func _on_body_exited(body: Node) -> void:
    if body.is_in_group("player"):
        _player_in_range = false
        EventBus.emit_signal("interactable_exited", self)

func can_be_interacted() -> bool:
    return can_interact and _player_in_range and (not interact_once or not _has_interacted)

func interact() -> void:
    if not can_be_interacted():
        return
    
    _has_interacted = true
    _perform_interaction()
    interacted.emit(self)

func _perform_interaction() -> void:
    # Override in subclasses
    pass

func get_interaction_text() -> String:
    return interaction_text
```

### 3. Signpost Implementation

```gdscript
# signpost.gd
class_name Signpost
extends Interactable

@export var sign_text: String = "Welcome to the Adventure!"
@export var text_display_time: float = 5.0
@export var show_distance: float = 5.0

func _ready() -> void:
    super()
    interaction_text = "Press E to read sign"

func _perform_interaction() -> void:
    # Show sign text in UI
    EventBus.emit_signal("show_sign_text", sign_text, text_display_time)
    
    # Optional: Play sound
    AudioManager.play_sfx("ui_read")
```

### 4. Chest Implementation

```gdscript
# chest.gd
class_name Chest
extends Interactable

@export var is_open: bool = false
@export var loot_table: Array[Dictionary] = []
@export var open_animation: String = "open"
@export var close_animation: String = "close"

var _animation_player: AnimationPlayer

func _ready() -> void:
    super()
    _animation_player = get_node_or_null("AnimationPlayer")
    interaction_text = "Press E to %s" % ["open" if not is_open else "close"]

func _perform_interaction() -> void:
    if is_open:
        close()
    else:
        open()

func open() -> void:
    if is_open or not can_interact:
        return
    
    is_open = true
    interaction_text = "Press E to close"
    
    if _animation_player and _animation_player.sprite_frames.has_animation(open_animation):
        _animation_player.play(open_animation)
    
    # Drop loot
    _drop_loot()
    
    # Play sound
    AudioManager.play_sfx("chest_open")

func close() -> void:
    if not is_open:
        return
    
    is_open = false
    interaction_text = "Press E to open"
    
    if _animation_player and _animation_player.sprite_frames.has_animation(close_animation):
        _animation_player.play(close_animation)
    
    AudioManager.play_sfx("chest_close")

func _drop_loot() -> void:
    if loot_table.is_empty():
        return
    
    for loot_def in loot_table:
        var item_id = loot_def.get("item_id", "")
        var count = loot_def.get("count", 1)
        var drop_chance = loot_def.get("chance", 1.0)
        
        if randf() <= drop_chance:
            for i in range(count):
                Inventory.add_item(item_id)
                # Spawn pickup in world
                var pickup = Pickup.new(item_id)
                pickup.position = global_position + Vector3(randf_range(-0.5, 0.5), 0.5, randf_range(-0.5, 0.5))
                get_parent().add_child(pickup)
```

### 5. Landmark System

```gdscript
# landmark.gd
class_name Landmark
extends Interactable

@export var landmark_name: String = "Unknown Landmark"
@export var description: String = ""
@export var icon: Texture2D
@export var auto_discover: bool = true
@export var discovery_range: float = 10.0

var _discovered: bool = false

func _ready() -> void:
    super()
    interaction_range = discovery_range
    
    if auto_discover:
        var trigger = Area3D.new()
        trigger.position = Vector3.ZERO
        trigger.add_child(CollisionShape3D.new())
        var shape = SphereShape3D.new()
        shape.radius = discovery_range
        trigger.get_child(0).shape = shape
        trigger.body_entered.connect(_on_discovery_trigger_entered)
        add_child(trigger)

func _on_discovery_trigger_entered(body: Node) -> void:
    if body.is_in_group("player") and not _discovered:
        discover()

func _perform_interaction() -> void:
    if not _discovered:
        discover()
    else:
        # Show landmark info
        EventBus.emit_signal("show_landmark_info", landmark_name, description, icon)

func discover() -> void:
    _discovered = true
    _discovered = true
    EventBus.emit_signal("landmark_discovered", landmark_name, global_position, icon)
    
    # Save to player progress
    PlayerProfile.add_discovered_landmark(landmark_name)
    
    # Optional: Show discovery effect
    var effect = preload("res://effects/discovery_particles.tscn").instantiate()
    effect.position = global_position + Vector3(0, 1, 0)
    get_parent().add_child(effect)
    
    AudioManager.play_sfx("discovery")
```

### 6. Ecology Manager

```gdscript
# ecology_manager.gd
class_name EcologyManager
extends Node

signal time_changed(hour: float, minute: float)
signal day_changed(day: int)
signal weather_changed(weather_type: String, intensity: float)
signal season_changed(season: String)

# Time settings
@export var day_length_seconds: float = 120.0  # 2 minutes per day
@export var start_hour: float = 8.0  # 8 AM

# Weather settings
@export var weather_change_interval: float = 30.0  # seconds

# Season settings
@export var season_length_days: int = 30

# Current state
var _current_time: float = 0.0  # 0-24
var _current_day: int = 0
var _current_weather: String = "clear"
var _current_season: String = "spring"

func _ready() -> void:
    _setup_time()
    _setup_weather()
    _setup_seasons()

func _process(delta: float) -> void:
    _update_time(delta)
    _update_weather(delta)

func _setup_time() -> void:
    _current_time = start_hour

func _update_time(delta: float) -> void:
    _current_time += (24.0 / day_length_seconds) * delta
    
    if _current_time >= 24.0:
        _current_time = 0.0
        _current_day += 1
        day_changed.emit(_current_day)
        
        # Check for season change
        var season_index = (_current_day / season_length_days) % 4
        var new_season = ["spring", "summer", "autumn", "winter"][season_index]
        if new_season != _current_season:
            _current_season = new_season
            season_changed.emit(_current_season)
    
    time_changed.emit(_current_time, (_current_time % 1) * 60)

func _setup_weather() -> void:
    pass

func _update_weather(delta: float) -> void:
    # Random weather changes
    pass

func get_time_info() -> Dictionary:
    return {
        "hour": _current_time,
        "day": _current_day,
        "season": _current_season
    }

func get_sun_angle() -> float:
    # Convert time to sun angle (-90 at midnight, 0 at noon, 90 at midnight)
    return (_current_time / 24.0 * TAU) - PI/2

func get_moon_phase() -> float:
    return (_current_day % 28) / 28.0  # 28-day cycle
```

### 7. Sky3D Integration

```gdscript
# sky_manager.gd
class_name SkyManager
extends Node

@export var sky_material: StandardMaterial3D
@export var sun: DirectionalLight3D
@export var moon: DirectionalLight3D
@export var skybox: MeshInstance3D

func _ready() -> void:
    EcologyManager.time_changed.connect(_on_time_changed)
    EcologyManager.season_changed.connect(_on_season_changed)

func _on_time_changed(hour: float, minute: float) -> void:
    # Update sun position
    var sun_angle = EcologyManager.get_sun_angle()
    var moon_angle = sun_angle + PI
    
    if sun:
        sun.rotation_degrees = Vector3(sun_angle * 180.0 / PI, 0, 0)
        sun.intensity = max(0, sin(sun_angle + PI/2)) * 2.0
    
    if moon:
        moon.rotation_degrees = Vector3(moon_angle * 180.0 / PI, 0, 0)
        moon.intensity = max(0, -sin(sun_angle + PI/2)) * 1.5
    
    # Update skybox rotation
    if skybox:
        skybox.rotation_degrees = Vector3(sun_angle * 180.0 / PI, 0, 0)

func _on_season_changed(season: String) -> void:
    # Change sky colors based on season
    match season:
        "spring":
            _apply_spring_colors()
        "summer":
            _apply_summer_colors()
        "autumn":
            _apply_autumn_colors()
        "winter":
            _apply_winter_colors()
```

### 8. Deterministic Procedural Dressing

```gdscript
# procedural_dressing.gd
class_name ProceduralDressing
extends Node

@export var world_seed: int = 12345
@export var chunk_size: int = 16

# Dressing definitions
@export var dressing_definitions: Array[Dictionary] = [
    {
        "name": "tree_oak",
        "biome": "forest",
        "density": 0.05,
        "min_scale": 0.8,
        "max_scale": 1.2,
        "y_offset": 0.0
    },
    {
        "name": "rock_small",
        "biome": ["forest", "beach", "mountain"],
        "density": 0.02,
        "min_scale": 0.5,
        "max_scale": 0.8
    },
    {
        "name": "flower_red",
        "biome": ["forest", "meadow"],
        "density": 0.1,
        "min_scale": 0.3,
        "max_scale": 0.5
    }
]

var _dressing_cache: Dictionary = {}

func generate_chunk_dressing(chunk_pos: Vector3i) -> Array:
    var key = "%d_%d_%d" % [chunk_pos.x, chunk_pos.y, chunk_pos.z]
    if _dressing_cache.has(key):
        return _dressing_cache[key]
    
    var instances: Array = []
    var local_seed = hash(chunk_pos) + world_seed
    
    var noise = FastNoiseLite.new()
    noise.seed = local_seed
    noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
    
    for x in range(chunk_size):
        for z in range(chunk_size):
            var world_x = chunk_pos.x * chunk_size + x
            var world_z = chunk_pos.z * chunk_size + z
            
            # Get biome at this position
            var biome = _get_biome(world_x, world_z, local_seed)
            
            for def in dressing_definitions:
                if _biome_matches(def.get("biome"), biome):
                    # Check density with noise
                    var noise_val = noise.get_noise_2d(world_x, world_z)
                    if noise_val > (1.0 - def.get("density", 0.0)):
                        var instance = {
                            "prefab": def["name"],
                            "position": Vector3(world_x, 0, world_z),
                            "scale": Vector3(1, 1, 1) * randf_range(def.get("min_scale", 1.0), def.get("max_scale", 1.0)),
                            "y_offset": def.get("y_offset", 0.0),
                            "seed": local_seed + hash(Vector3i(world_x, 0, world_z))
                        }
                        instances.append(instance)
    
    _dressing_cache[key] = instances
    return instances

func _get_biome(world_x: int, world_z: int, seed: int) -> String:
    # Simple biome determination based on noise
    var noise = FastNoiseLite.new()
    noise.seed = seed
    noise.frequency = 0.01
    
    var moisture = noise.get_noise_2d(world_x, world_z)
    var temperature = FastNoiseLite.new()
    temperature.seed = seed + 1000
    temperature.frequency = 0.01
    temperature.noise_type = FastNoiseLite.TYPE_SIMPLEX
    temperature.get_noise_2d(world_x, world_z)
    
    # Simple biome map
    if moisture > 0.5 and temperature > 0.5:
        return "forest"
    elif moisture > 0.5:
        return "swamp"
    elif temperature > 0.5:
        return "desert"
    else:
        return "mountain"

func _biome_matches(expected: Variant, actual: String) -> bool:
    if expected is Array:
        return actual in expected
    return expected == actual
```

### 9. Animal AI System

```gdscript
# animal.gd
class_name Animal
extends CharacterBody3D

enum State { IDLE, GRAZE, WANDER, FLEE, SLEEP }

@export var move_speed: float = 2.0
@export var flee_speed: float = 5.0
@export var detection_range: float = 10.0
@export var graze_range: float = 2.0

var _current_state: State = State.IDLE
var _target_position: Vector3
var _wander_timer: float = 0.0
var _state_timer: float = 0.0

func _ready() -> void:
    _setup_detection()
    _change_state(State.IDLE)

func _setup_detection() -> void:
    var detection_area = Area3D.new()
    detection_area.position = Vector3.ZERO
    detection_area.add_child(CollisionShape3D.new())
    var shape = SphereShape3D.new()
    shape.radius = detection_range
    detection_area.get_child(0).shape = shape
    detection_area.body_entered.connect(_on_body_entered)
    add_child(detection_area)

func _physics_process(delta: float) -> void:
    match _current_state:
        State.IDLE:
            _state_idle(delta)
        State.GRAZE:
            _state_graze(delta)
        State.WANDER:
            _state_wander(delta)
        State.FLEE:
            _state_flee(delta)
        State.SLEEP:
            _state_sleep(delta)

func _on_body_entered(body: Node) -> void:
    if body.is_in_group("player"):
        # Flee from player
        _change_state(State.FLEE)
        var direction = (global_position - body.global_position).normalized()
        _target_position = global_position + direction * 5.0

func _change_state(new_state: State) -> void:
    _current_state = new_state
    _state_timer = 0.0

func _state_idle(delta: float) -> void:
    _state_timer += delta
    if _state_timer > randf_range(5.0, 15.0):
        _change_state(State.WANDER)

func _state_wander(delta: float) -> void:
    if _target_position == null or global_position.distance_to(_target_position) < 1.0:
        _find_new_wander_target()
    
    var direction = (global_position - _target_position).normalized()
    velocity = -direction * move_speed
    move_and_slide()

func _state_graze(delta: float) -> void:
    # Stay in place, play eating animation
    pass

func _state_flee(delta: float) -> void:
    var direction = (global_position - _target_position).normalized()
    velocity = -direction * flee_speed
    move_and_slide()
    
    # Return to idle after fleeing for a while
    _state_timer += delta
    if _state_timer > 5.0:
        _change_state(State.IDLE)

func _state_sleep(delta: float) -> void:
    # Stay in place, play sleep animation
    pass

func _find_new_wander_target() -> void:
    var angle = randf() * TAU
    var distance = randf_range(3.0, 8.0)
    _target_position = global_position + Vector3(cos(angle), 0, sin(angle)) * distance
```

---

## Asset Packages & Integration

### 1. Nature Assets

| Package | Source | License | Assets | Integration |
|---------|--------|---------|--------|-------------|
| **[Kenney Nature Pack](https://opengameart.org/content/3d-nature-pack)** | OpenGameArt | CC0 | 200+ trees, rocks, bushes | Import FBX/OBJ, create scenes |
| **[Kenney Nature Kit](https://opengameart.org/content/nature-kit)** | OpenGameArt | CC0 | 2D nature assets | For UI/2D elements |
| **[Quaternius Nature Pack](https://quaternius.com/)** | Quaternius | CC0 | Trees, rocks, foliage | Godot-ready GLTF |

**Integration Steps:**
```bash
1. Download pack (FBX/OBJ/GLTF format)
2. Copy to res://assets/nature/
3. Godot auto-imports on next editor open
4. Create scenes for each model
5. Add CollisionShape3D for interactables
6. Instance into world
```

**Optimization Plugin:**
- **[Godot Spatial Gardener](https://github.com/dreadpon/godot_spatial_gardener)** - Paint foliage on terrain surfaces

### 2. Animal & Fauna Assets

| Package | Source | License | Count | Formats |
|---------|--------|---------|-------|---------|
| **[Quaternius Farm Animals](https://poly.pizza/bundle/Farm-Animal-Pack-1kUvRTPLzT)** | Poly Pizza | CC0 | 7 | FBX, OBJ, GLTF |
| **[Quaternius Animated Animals](https://poly.pizza/bundle/Animated-Animal-Pack-ILAPXeUYiS)** | Poly Pizza | CC0 | 12 | FBX, OBJ, GLTF |
| **[Poly Pizza Animals](https://poly.pizza/explore/Animals)** | Poly Pizza | CC0 | 50+ | FBX, OBJ, GLTF |
| **[Kenney Animals](https://godotengine.org/asset-library/asset?category=&filter=kenney)** | Godot Asset Library | CC0 | Various | Godot-ready |

**Recommended Animals for Child-Safe Sandbox:**
- Farm animals: cow, pig, chicken, sheep
- Forest animals: deer, rabbit, squirrel, fox
- Birds: sparrow, pigeon, duck
- Marine: fish, seagull

### 3. Building & Structure Assets

| Package | Source | License | Notes |
|---------|--------|---------|-------|
| **[Quaternius Medieval Village MegaKit](https://quaternius.com/packs/medievalvillagemegakit.html)** | Quaternius | CC0 | 300+ modular pieces |
| **[Kenney Village Pack](https://kenney.nl/assets/village-pack)** | Kenney.nl | CC0 | Low-poly buildings |
| **[Poly Pizza Buildings](https://poly.pizza/explore/Buildings)** | Poly Pizza | CC0 | Low-poly structures |

**Quaternius Medieval Village Integration:**
```gdscript
# All models in Source version are already in Godot 4.3+ format
# Custom shaders for wear color customization
# Optimized collisions pre-configured

func spawn_house(house_type: String, position: Vector3) -> Node3D:
    var house_scene = preload("res://assets/village/houses/%s.tscn" % house_type)
    var house = house_scene.instantiate()
    house.position = position
    add_child(house)
    return house
```

### 4. Audio Assets

| Category | Source | License | Notes |
|----------|--------|---------|-------|
| Nature SFX | [Freesound CC0](https://freesound.org/browse/tags/cc0/) | CC0 | Search by tag |
| Ambient Music | [Freesound CC0](https://freesound.org/browse/tags/cc0/) | CC0 | Looping tracks |
| Animal Sounds | [Kenney Audio](https://kenney.nl/assets/audio) | CC0 | 500+ SFX |

**Recommended Audio Setup:**
```gdscript
# Audio categories for sandbox
- Ambient: Forest, beach, cave
- Interaction: Collect, open, read
- Animal: Idle, move, alert
- Weather: Rain, wind, thunder
- UI: Click, hover, notification
```

---

## Learning Resources

### Godot-Specific Tutorials

#### Interaction Systems
1. **[Kids Can Code: Using Areas](https://kidscancode.org/godot_recipes/4.x/g101/3d/101_3d_04/index.html)** - Area3D fundamentals
2. **[YouTube: Interact With Objects](https://www.youtube.com/watch?v=ajCraxGAeYU)** - Step-by-step interaction
3. **[GitHub: 3D Inventory & Interaction](https://github.com/MacdonaldRobinson/Godot4-3D-inventory-and-interaction-system)** - Complete system template
4. **[Godot Forum: Interaction System](https://forum.godotengine.org/t/player-interacting-with-every-object/68602)** - Community solutions

#### Ecology & Weather
1. **[Sky3D Documentation](https://tokisan.com/sky3d/)** - Dynamic day/night cycle
2. **[TCA Weather System](https://github.com/kS222138/TCA_Weather_System)** - Full weather implementation
3. **[Dynamic Day Night Cycles](https://godotengine.org/asset-library/asset/1693)** - Seasonal variations
4. **[YouTube: Day/Night Cycle](https://www.youtube.com/watch?v=djt3YPuhi9g)** - Simple implementation

#### Procedural Generation
1. **[Procedural Forest Demo](https://godotengine.org/asset-library/asset/5013)** - Deterministic biome scattering
2. **[Godot4-3D-Procedural-World](https://github.com/alpapaydin/Godot4-3D-Procedural-World-Generation)** - Minecraft-style generation
3. **[YouTube: Procedural Generation](https://www.youtube.com/watch?v=ztPbGyQnKPo)** - Infinite world tutorial
4. **[Ziva: Procedural Patterns](https://ziva.sh/blogs/godot-procedural-generation)** - 5 patterns from real games

#### Performance Optimization
1. **[Godot Docs: Optimizing 3D](https://docs.godotengine.org/en/stable/tutorials/performance/optimizing_3d_performance.html)** - Official guide
2. **[Occlusion Culling Demo](https://godotengine.org/asset-library/asset/2744)** - Official demonstration
3. **[Reddit: 3D Performance Tips](https://www.reddit.com/r/godot/comments/zz6um8/perfecting_performance_how/)** - Community advice

#### Asset Integration
1. **[Quaternius Medieval Village](https://quaternius.com/packs/medievalvillagemegakit.html)** - Official page
2. **[Kenney Nature Pack](https://opengameart.org/content/3d-nature-pack)** - OpenGameArt
3. **[Godot Spatial Gardener](https://github.com/dreadpon/godot_spatial_gardener)** - Foliage painting
4. **[YouTube: Nature in Godot](https://www.youtube.com/watch?v=OoVAtGHEgjA)** - Integration tutorial

### Child-Safe Sandbox Design
1. **[GameDev Academy: Sandbox Tutorial](https://gamedevacademy.org/godot-dialogue-box-tutorial/)** - UI patterns
2. **[itch.io: Free Sandbox Games](https://itch.io/games/free/made-with-godot/tag-sandbox)** - Inspiration
3. **[Godot Learning: Design Patterns](https://godotlearning.com/patterns)** - Best practices

---

## Implementation Checklist

### Phase 1: Core Interaction System
- [ ] Create `Interactable.gd` base class
- [ ] Implement `Area3D` proximity detection
- [ ] Create `InteractionManager.gd` singleton
- [ ] Add input handling (E key, touch)
- [ ] Implement interaction UI prompts
- [ ] Unit tests for interaction detection

### Phase 2: Signpost & Discovery System
- [ ] Create `Signpost.gd` with text display
- [ ] Create `Landmark.gd` with discovery tracking
- [ ] Create `Chest.gd` with loot system
- [ ] Implement discovery UI feedback
- [ ] Add discovery particle effects
- [ ] Persist discovered landmarks in profile

### Phase 3: Ecology Systems
- [ ] Integrate Sky3D for day/night cycle
- [ ] Add TCA Weather System for weather effects
- [ ] Create `EcologyManager.gd` for time/season control
- [ ] Implement sun/moon position calculation
- [ ] Add weather transition system
- [ ] Create seasonal visual changes

### Phase 4: Procedural Dressing
- [ ] Create `ProceduralDressing.gd`
- [ ] Implement biome system (forest, beach, cave, etc.)
- [ ] Add deterministic seed-based generation
- [ ] Create dressing definitions for each biome
- [ ] Optimize with instancing (MultiMesh)
- [ ] Add LOD for distant objects

### Phase 5: Fauna & AI
- [ ] Create `Animal.gd` base class
- [ ] Implement state machine (idle, graze, wander, flee)
- [ ] Add simple pathfinding with NavigationServer3D
- [ ] Create animal spawning system
- [ ] Add day/night behavior variations
- [ ] Optimize with occlusion culling

### Phase 6: Asset Integration
- [ ] Import Quaternius Medieval Village MegaKit
- [ ] Import Kenney Nature Pack
- [ ] Import Quaternius Farm Animals
- [ ] Set up modular building system
- [ ] Create foliage placement tooling
- [ ] Optimize all models with collisions

### Phase 7: Performance Optimization
- [ ] Implement occlusion culling
- [ ] Add LOD system for all models
- [ ] Configure visibility ranges
- [ ] Use MultiMesh for repeated objects
- [ ] Add object pooling for frequent spawns
- [ ] Profile on Tier 1 and Tier 2 hardware

### Phase 8: Polish & Feedback
- [ ] Add audio feedback for all interactions
- [ ] Create discovery notification system
- [ ] Implement minimap/radar for landmarks
- [ ] Add tooltips for first-time discovery
- [ ] Balance discovery density and frequency

### Phase 9: Testing & Validation
- [ ] Unit tests for all systems
- [ ] Integration test: discovery flow
- [ ] Performance test on reference hardware
- [ ] Manual test with child-like interaction
- [ ] Visual acceptance test

---

## Child-Safety Constraints

### Must Implement

1. **No Pressure:** No goals, timers, or fail states
2. **Safe Interactions:** All interactions are constructive and non-destructive
3. **Clear Feedback:** Discovery is always positive and readable
4. **Free Exploration:** Player can go anywhere, do anything (within bounds)
5. **Deterministic:** Same seed = same world (for consistency)

### Must Avoid

1. **No combat requirements** for discovery
2. **No hidden interactions** that require specific knowledge
3. **No time limits** on exploration
4. **No violent content** in ecology (predators OK but no blood/gore)
5. **No small/confusing UI** elements

### Age-Appropriate Content

| Feature | Implementation |
|---------|----------------|
| Animals | Friendly, non-threatening (deer, rabbits, farm animals) |
| Discovery | Always rewarding, never punishing |
| Feedback | Clear, immediate, positive |
| Navigation | Simple, forgiving, no dead ends |
| Controls | Single action, large touch targets |

### Content Guidelines

- **Fauna:** Only friendly animals (no predators that attack)
- **Flora:** Realistic but stylized (cartoonish, not photorealistic)
- **Weather:** Gentle effects (no extreme storms, hurricanes)
- **Night:** Not too dark, with ambient lighting
- **Interactions:** Always safe and reversible

---

## References

### Internal Files
- `data/templates/adventure.json` - Adventure template configuration
- `src/adapters/inbound/gameplay/world_renderer.gd` - Current world renderer
- `src/adapters/inbound/gameplay/gameplay_runtime.gd` - Current gameplay runtime
- `PLAN.md` - Vertical slice requirements and gates
- `.ai/tasks/backlog.yaml` - Task definitions and status

### External Links

#### Godot Documentation
- [Area3D](https://docs.godotengine.org/en/stable/classes/class_area3d.html)
- [FastNoiseLite](https://docs.godotengine.org/en/stable/classes/class_fastnoiselite.html)
- [NavigationServer3D](https://docs.godotengine.org/en/stable/classes/class_navigationserver3d.html)
- [Optimizing 3D Performance](https://docs.godotengine.org/en/stable/tutorials/performance/optimizing_3d_performance.html)
- [MultiMeshInstance3D](https://docs.godotengine.org/en/stable/classes/class_multimeshinstance3d.html)

#### Plugins & Addons
- **[Sky3D](https://github.com/TokisanGames/Sky3D)** - Day/night cycle
- **[TCA Weather System](https://github.com/kS222138/TCA_Weather_System)** - Weather and seasons
- **[Godot Spatial Gardener](https://github.com/dreadpon/godot_spatial_gardener)** - Foliage painting
- **[Godot Rollback Netcode](https://godotengine.org/asset-library/asset/2450)** - Deterministic state

#### Asset Packages
- **[Quaternius Medieval Village MegaKit](https://quaternius.com/packs/medievalvillagemegakit.html)** - 300+ buildings
- **[Quaternius Farm Animals](https://poly.pizza/bundle/Farm-Animal-Pack-1kUvRTPLzT)** - 7 farm animals
- **[Quaternius Animated Animals](https://poly.pizza/bundle/Animated-Animal-Pack-ILAPXeUYiS)** - 12 animated animals
- **[Kenney Nature Pack](https://opengameart.org/content/3d-nature-pack)** - 200+ nature assets
- **[Poly Pizza Animals](https://poly.pizza/explore/Animals)** - 50+ CC0 animals

#### Tutorials
- **[Kids Can Code: Areas](https://kidscancode.org/godot_recipes/4.x/g101/3d/101_3d_04/index.html)**
- **[Sky3D Official](https://tokisan.com/sky3d/)**
- **[Procedural Forest Demo](https://godotengine.org/asset-library/asset/5013)**
- **[Godot4 Procedural World](https://github.com/alpapaydin/Godot4-3D-Procedural-World-Generation)**

#### Community Resources
- **[Godot Forum: Interaction](https://forum.godotengine.org/t/player-interacting-with-every-object/68602)**
- **[Reddit: Procedural Generation](https://www.reddit.com/r/godot/comments/iab7k0/procedural_generation/)**
- **[StraySpark: Quest Systems](https://www.strayspark.studio/blog/godot-4-dialogue-quest-systems-signals-resources)**

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
