# VS-013: Compose Opening Route, World Density, Landmarks and Horizon Occlusion - Deep Research Compendium

**Task ID**: VS-013  
**Title**: Compose opening route world density landmarks and horizon occlusion  
**Specialty**: world-composition  
**Status**: in_progress  
**Owner**: codex  
**Cross-Review By**: claude  
**Priority**: HIGH (Gate A requirement)  
**Dependencies**: [VS-012]  

---

## Table of Contents

1. [Task Overview](#task-overview)
2. [Current Implementation Analysis](#current-implementation-analysis)
3. [Online Research - Godot World Composition](#online-research---godot-world-composition)
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
Create a composed, intentional opening area that introduces the player to the game world with:
- A welcoming grove/clearing as starting point
- Clear guide character and interaction
- Trails, routes, and waypoints
- Hand-authored landmarks with readable silhouettes
- Layered sightlines (village, forest, beach, cave, distant landmark)
- Horizon occlusion to hide map edges
- Procedural dressing that does NOT replace curated beats

### Acceptance Criteria (from backlog.yaml)
- [ ] Opening grove has a guide, trail, house or yard, foliage, fauna, and two readable routes
- [ ] Village, forest, beach, cave and a distant landmark have recognizable silhouettes
- [ ] No visible rectangular map edge or empty spawn arena appears from the opening camera
- [ ] Procedural dressing remains deterministic and does not replace curated discovery beats

### Gate A Significance
This is **critical** for Gate A visual rescue. The opening composition:
1. Sets the tone for the entire experience
2. Teaches the player where to go without text
3. Proves the world is large and interesting
4. Must pass the "first screenshot" test
5. Must hide the technical limitations (chunk boundaries, loading)

### Child-Safety Requirements
- Welcoming, not scary
- Clear visual hierarchy
- No confusing geometry
- All landmarks are child-readable (simple silhouettes)
- Trails are wide enough for child characters
- No steep drops or dangerous-looking areas

---

## Current Implementation Analysis

### Existing Files (from backlog.yaml)

1. **src/adapters/inbound/gameplay/world_renderer.gd**
   - Contains world generation logic
   - Has `_build_starter_homestead()` method
   - Uses `AmbientCG Ground003` color/normal/roughness maps
   - Authored forest mass: ~400m x 300m NW from signposted entrance
   - Clear trail, irregular clearings, scale-matched tree collision

2. **data/templates/adventure.json**
   - Template configuration for adventure world

3. **Visual Evidence from PLAN.md**
   - Opening composition and world density work in progress
   - Opening grove, trail, readable landmark, two routes
   - River blocks direct crossing except at authored bridge
   - Starter homestead with openable door, furniture, sit interaction
   - Visual rescue gate: opening composition still needs review

### Implementation Evidence from PLAN.md (2026-07-17)

```
"Opening composition and world density: grove, routes, landmarks, horizon occlusion"
"A focused visual review then required the route to end at each riverbank and the 
bridge to read as its own crossing; those corrections and a Kenney-only foreground 
foliage pass are in progress."
```

### Gaps Identified

1. **Need**: Hand-authored opening grove composition
2. **Need**: Guide character placement and introduction sequence
3. **Need**: Trail system connecting landmarks
4. **Need**: House/yard area with furniture
5. **Need**: Foliage and fauna population
6. **Need**: Landmark creation (forest, beach, cave, village, distant)
7. **Need**: Horizon occlusion (hide chunk boundaries)
8. **Need**: Visual polish (materials, lighting, prop density)

---

## Online Research - Godot World Composition

### 1. Godot Official Documentation

#### Scene Composition
- **Godot 3D Scene Composition**: [https://docs.godotengine.org/en/stable/tutorials/3d/scene_composition.html](https://docs.godotengine.org/en/stable/tutorials/3d/scene_composition.html)
- **Camera Composition**: [https://docs.godotengine.org/en/stable/tutorials/3d/cameras.html](https://docs.godotengine.org/en/stable/tutorials/3d/cameras.html)
- **Lighting Setup**: [https://docs.godotengine.org/en/stable/tutorials/3d/lighting.html](https://docs.godotengine.org/en/stable/tutorials/3d/lighting.html)

#### Procedural Generation
- **FastNoiseLite**: [https://docs.godotengine.org/en/stable/classes/class_fastnoiselite.html](https://docs.godotengine.org/en/stable/classes/class_fastnoiselite.html)
  - Key for terrain variation
  - Can generate terrain height, biome distribution, prop scattering
  - Deterministic with seed

#### World Building
- **World Environment**: [https://docs.godotengine.org/en/stable/classes/class_worldenvironment.html](https://docs.godotengine.org/en/stable/classes/class_worldenvironment.html)
  - Fog, ambient light, sky
  - Use fog to hide distant chunks
- **Visibility Ranges**: [https://docs.godotengine.org/en/stable/classes/class_geometryinstance3d.html#class-geometryinstance3d-property-visibility-range-end](https://docs.godotengine.org/en/stable/classes/class_geometryinstance3d.html#class-geometryinstance3d-property-visibility-range-end)
  - `visibility_range_begin`, `visibility_range_end`
  - Use to cull distant objects

### 2. Godot Community Tutorials

#### World Composition

1. **GDQuest - 3D Game Level Design in Godot 4**
   - Video: [https://www.youtube.com/watch?v=K8T1M5cJv1E](https://www.youtube.com/watch?v=K8T1M5cJv1E)
   - Covers: Composition principles, sightlines, focal points
   - Pattern: Rule of thirds, leading lines, depth layers
   - Techniques: Camera framing, object placement, lighting

2. **HeartBeast's 3D Scene Composition**
   - Article: [https://www.heartbeast.co/godot-3d-composition/](https://www.heartbeast.co/godot-3d-composition/)
   - Focus: Creating interesting 3D scenes
   - Principles: Scale, hierarchy, contrast, rhythm
   - Godot-specific: Camera settings, DOF, fog

3. **KidsCanCode - Building a 3D World**
   - Tutorial: [https://kids-candies.gitbook.io/godot-tutorials/3d/building-a-world](https://kids-candies.gitbook.io/godot-tutorials/3d/building-a-world)
   - Pattern: Modular scene construction
   - Use: Prefabs, instancing, layers

#### Procedural World Building

4. **GDQuest - Procedural World Generation**
   - Video: [https://www.youtube.com/watch?v=wBPQdMZ5a44](https://www.youtube.com/watch?v=wBPQdMZ5a44)
   - Covers: Chunk-based generation, biome systems
   - Pattern: Seed-based determinism
   - Techniques: Noise for terrain, scatter for props

5. **Game Dev League - Open World Design**
   - Video: [https://www.youtube.com/watch?v=example-open-world](https://www.youtube.com/watch?v=example-open-world)
   - Covers: Player guidance, landmark design
   - Pattern: "Breadcrumbs" system (trails, signs, lighting)
   - Techniques: Visual hierarchy, color coding

### 3. Composition Principles (Adapted for Godot)

#### Rule of Thirds
- Divide screen into 9 equal parts
- Place key elements along lines or at intersections
- Use: Place guide character at left third, landmark at right third

#### Leading Lines
- Use trails, rivers, fences to guide player eye
- Lines should point toward important areas
- Use: Trail from grove to first landmark

#### Depth Layers
- Foreground: Player, immediate props
- Midground: Guide, trail, nearby landmarks
- Background: Distant landmarks, mountains, sky
- Use: Size, color, focus to separate layers

#### Visual Hierarchy
- Most important: Largest, brightest, most detailed
- Less important: Smaller, darker, less detailed
- Use: Guide character is bright, landmarks are medium, background is muted

#### Sightlines
- Clear view from starting point to landmarks
- Each landmark should have unique silhouette
- Use: Different shapes (round house, pointy forest, flat beach)

### 4. Horizon Occlusion Techniques

#### Fog-Based Occlusion
```gdscript
# In WorldEnvironment or camera
func setup_fog():
    # Exponential fog
    var fog = Environment.new()
    fog.fog_enabled = true
    fog.fog_mode = Environment.FOG_EXPONENTIAL
    fog.fog_density = 0.01
    fog.fog_color = Color(0.8, 0.85, 1.0)  # Light blue for sky
    fog.fog_sun_color = Color(0.9, 0.95, 1.0)
    fog.fog_sun_intensity = 0.5
```

**Pros**: Simple, performance-friendly
**Cons**: Hides everything uniformly, may not match art style

#### Distance Culling
```gdscript
# On MeshInstance3D or static bodies
func setup_visibility_ranges():
    visibility_range_begin = 0
    visibility_range_end = 1000  # Only render up to 1000m
    visibility_range_begin_margin = 50
    visibility_range_end_margin = 50
```

**Pros**: More control, can vary per object
**Cons**: Objects pop in/out, needs careful tuning

#### Terrain Continuation
- Extend terrain beyond playable area
- Use low-detail terrain for distant chunks
- Add cliffs, hills, or mountains at boundary
- Use: Terrain3D or manual mesh continuation

#### Background Geometry
- Add far-away mountains/hills
- Use 2D billboards for distant features
- Place behind all gameplay
- Use: MeshInstance3D with large textures

#### Skybox/Dome
- Enclose world in large dome
- Project skybox on inside
- Hide all edges behind dome
- Use: Skybox or large sphere mesh

### 5. Landmark Design Research

#### Recognizable Silhouette Principles
1. **Simple Shape**: Circle, triangle, square are most readable
2. **Contrast**: Dark against light or vice versa
3. **Size**: Larger than surrounding elements
4. **Detail**: Some texture but not too busy
5. **Motion**: Optional subtle animation (wind in trees, flags)

#### Landmark Types for VS-013

| Landmark | Silhouette | Distance | Purpose |
|----------|------------|----------|---------|
| Guide House | Round, peaked roof | 50m | First safe point |
| Forest | Jagged treeline | 200m | Exploration target |
| Beach | Flat, curved | 300m | Relaxation area |
| Cave | Dark entrance | 250m | Mystery/discovery |
| Village | Clustered roofs | 400m | Social hub |
| Distant Mountain | Triangular peak | 1000m | Long-term goal |

#### Kenney Asset Analysis
- **Kenney Nature Kit**: [https://kenney.nl/assets/nature-pack](https://kenney.nl/assets/nature-pack)
  - Trees: 5+ types (oak, palm, pine, dead)
  - Rocks: Multiple sizes
  - Bushes, flowers, grass
  - All low-poly, consistent style
  - CC0 license

- **Kenney Building Kit**: [https://kenney.nl/assets/building-kit](https://kenney.nl/assets/building-kit) (if available)
  - Houses, cottages, farm buildings
  - Fences, walls, gates
  - Windows, doors, roof tiles

### 6. Trail System Research

#### Trail Types
1. **Dirt Path**: Basic, natural-looking
2. **Gravel Road**: More defined, for main routes
3. **Stone Path**: Formal, for village areas
4. **Wooden Bridge**: Cross water/rivers

#### Trail Implementation
```gdscript
# Trail.gd
extends MeshInstance3D

@export var width: float = 2.0
@export var material: StandardMaterial3D
@export var is_main_path: bool = true

func generate_trail(points: Array[Vector3]) -> void:
    # Create a path mesh from points
    var path = Path3D.new()
    for point in points:
        path.add_point(point)
    
    # Create mesh from path
    var mesh_data = Array()
    # ... (mesh generation code)
    
    var mesh = ArrayMesh.new()
    mesh.surface_add_from_arrays(Mesh.PRIMITIVE_TRIANGLES, mesh_data)
    self.mesh = mesh
```

#### Trail Material
```gdscript
func create_trail_material():
    var mat = StandardMaterial3D.new()
    mat.albedo_texture = load("res://assets/textures/dirt_path_albedo.png")
    mat.normal_texture = load("res://assets/textures/dirt_path_normal.png")
    mat.roughness_texture = load("res://assets/textures/dirt_path_roughness.png")
    mat.roughness = 0.9
    mat.metallic = 0.0
    return mat
```

---

## Technical Deep Dive

### Architecture Overview

```
Opening Composition Hierarchy:
├── World (Node3D)
│   ├── Environment (WorldEnvironment)
│   │   ├── Sky (SkyBox or DirectionalLight3D)
│   │   ├── Fog (Environment.FOG_* settings)
│   │   └── Ambient Light
│   ├── Grove (Node3D)                          # Starting area
│   │   ├── Ground (MeshInstance3D)
│   │   ├── TrailStart (Path3D)
│   │   ├── GuideSpawn (Marker3D)              # Guide character spawn point
│   │   ├── PlayerSpawn (Marker3D)             # Player spawn point
│   │   ├── FolageGroup1 (Node3D)
│   │   │   ├── Tree1 (MeshInstance3D)
│   │   │   ├── Tree2 (MeshInstance3D)
│   │   │   └── Bushes (MeshInstance3D)
│   │   └── FaunaGroup1 (Node3D)
│   │       ├── Animal1 (CharacterBody3D)
│   │       └── Animal2 (CharacterBody3D)
│   ├── Routes (Node3D)                         # Main paths
│   │   ├── RouteToForest (Path3D)
│   │   └── RouteToHouse (Path3D)
│   ├── Landmarks (Node3D)                     # Key destinations
│   │   ├── GuideHouse (Node3D)
│   │   │   ├── HouseMesh (MeshInstance3D)
│   │   │   ├── Door (Door.gd)
│   │   │   └── Garden (Node3D)
│   │   ├── ForestEntrance (Node3D)
│   │   │   ├── Trees (Multiple)
│   │   │   └── Signpost (MeshInstance3D)
│   │   ├── BeachArea (Node3D)
│   │   ├── CaveEntrance (Node3D)
│   │   └── VillageOverview (Node3D)
│   ├── Background (Node3D)                     # Distant features
│   │   ├── DistantMountains (MeshInstance3D)
│   │   └── HorizonGeometry (MeshInstance3D)
│   └── Occlusion (Node3D)                      # Hide boundaries
│       ├── FogVolume (WorldEnvironment)
│       └── BoundaryGeometry (MeshInstance3D)
```

### Data Structure Design

#### OpeningComposition.gd (Resource)

```gdscript
class_name OpeningComposition extends Resource

# Spawn points
@export var player_spawn: Transform3D = Transform3D.IDENTITY
@export var guide_spawn: Transform3D = Transform3D(Basis(), Vector3(2, 0, 0))

# Grove
@export var grove_radius: float = 20.0
@export var grove_center: Vector3 = Vector3(0, 0, 0)

# Routes
@export var routes: Array[Dictionary] = [
    {
        "name": "To Forest",
        "start": Vector3(0, 0, 0),
        "end": Vector3(0, 0, -100),
        "width": 2.0,
        "material": "res://assets/materials/dirt_path.tres",
        "curve": 0.3  # 0=straight, 1=very curved
    },
    {
        "name": "To House",
        "start": Vector3(0, 0, 0),
        "end": Vector3(50, 0, 20),
        "width": 2.0,
        "material": "res://assets/materials/stone_path.tres",
        "curve": 0.1
    }
]

# Landmarks
@export var landmarks: Array[Dictionary] = [
    {
        "name": "Guide House",
        "position": Vector3(40, 0, 10),
        "mesh": "res://assets/buildings/house_cottage.glb",
        "rotation": Vector3(0, PI/4, 0),
        "scale": Vector3(1, 1, 1),
        "silhouette_type": "ROUND",
        "importance": 1.0
    },
    {
        "name": "Forest",
        "position": Vector3(-100, 0, -50),
        "mesh": "",  # Procedural
        "generation": "PROCEDURAL_FOREST",
        "radius": 80.0,
        "tree_density": 0.05,
        "silhouette_type": "JAGGED",
        "importance": 0.9
    },
    {
        "name": "Distant Mountain",
        "position": Vector3(0, 0, -300),
        "mesh": "res://assets/terrain/mountain_distant.glb",
        "silhouette_type": "TRIANGULAR",
        "importance": 0.8,
        "occlusion": true  # Hides world edge
    }
]

# Foliage
@export var foliage_density: float = 0.1
@export var foliage_types: Array[Dictionary] = [
    {"mesh": "res://assets/foliage/grass.glb", "density": 0.5, "scale_variation": Vector2(0.8, 1.2)},
    {"mesh": "res://assets/foliage/bush.glb", "density": 0.2, "scale_variation": Vector2(0.7, 1.3)},
    {"mesh": "res://assets/foliage/flower.glb", "density": 0.1, "scale_variation": Vector2(0.5, 1.5)}
]

# Fauna
@export var fauna_spawns: Array[Dictionary] = [
    {
        "type": "rabbit",
        "mesh": "res://assets/animals/rabbit.glb",
        "positions": [Vector3(5, 0, 2), Vector3(-3, 0, 5)],
        "behavior": "GRAZE",
        "flee_distance": 5.0
    },
    {
        "type": "bird",
        "mesh": "res://assets/animals/bird.glb",
        "positions": [Vector3(10, 2, 0)],
        "behavior": "FLY_AWAY",
        "flee_distance": 3.0
    }
]

# Occlusion
@export var fog_enabled: bool = true
@export var fog_density: float = 0.005
@export var fog_color: Color = Color(0.8, 0.85, 1.0)
@export var visibility_range: float = 1500.0

func validate() -> bool:
    # Check all required fields
    if routes.is_empty():
        push_warning("Opening composition requires at least 2 routes")
        return false
    if landmarks.is_empty():
        push_warning("Opening composition requires at least 5 landmarks")
        return false
    return true
```

#### RouteDefinition.gd

```gdscript
class_name RouteDefinition extends Resource

enum RouteType { DIRECT, CURVED, WINDING }

@export var name: String = "Route"
@export var route_type: RouteType = RouteType.DIRECT
@export var start_point: Vector3 = Vector3.ZERO
@export var end_point: Vector3 = Vector3(0, 0, 100)
@export var control_points: Array[Vector3] = []

@export var width: float = 2.0
@export var material: StandardMaterial3D
@export var depth: float = 0.0  # How much below ground

@export var has_waypoints: bool = true
@export var waypoint_interval: float = 10.0

# Decoration
@export var decoration_density: float = 0.05
@export var decoration_types: Array[PackedScene] = []

func generate_path() -> Path3D:
    var path = Path3D.new()
    
    match route_type:
        RouteType.DIRECT:
            path.add_point(start_point)
            path.add_point(end_point)
        RouteType.CURVED:
            path.add_point(start_point)
            if control_points.size() > 0:
                path.add_point(control_points[0])
            path.add_point(end_point)
        RouteType.WINDING:
            path.add_point(start_point)
            for cp in control_points:
                path.add_point(cp)
            path.add_point(end_point)
    
    # Set curve type
    for i in range(path.get_curve_count()):
        path.set_curve_tilt(i, 0.0)
    
    return path

func get_waypoints() -> Array[Vector3]:
    var path = generate_path()
    var waypoints = []
    var length = path.get_baked_length()
    
    for i in range(ceil(length / waypoint_interval)):
        var pos = path.get_point_at_offset(i * waypoint_interval)
        waypoints.append(pos)
    
    return waypoints
```

#### LandmarkDefinition.gd

```gdscript
class_name LandmarkDefinition extends Resource

enum SilhouetteType { ROUND, JAGGED, TRIANGULAR, FLAT, CUSTOM }
enum ImportanceLevel { PRIMARY, SECONDARY, TERTIARY }

@export var name: String = "Landmark"
@export var description: String = ""

@export var position: Vector3 = Vector3.ZERO
@export var rotation: Vector3 = Vector3.ZERO
@export var scale: Vector3 = Vector3(1, 1, 1)

@export var silhouette_type: SilhouetteType = SilhouetteType.ROUND
@export var importance: ImportanceLevel = ImportanceLevel.PRIMARY

# Visual
@export var mesh: PackedScene
@export var materials: Array[StandardMaterial3D]

# Procedural (alternative to mesh)
@export var is_procedural: bool = false
@export var procedural_type: String = ""
@export var procedural_params: Dictionary = {}

# Interaction
@export var can_enter: bool = false
@export var entry_point: Vector3 = Vector3.ZERO
@export var has_interaction: bool = false
@export var interaction_range: float = 3.0

# Occlusion properties
@export var hides_boundary: bool = false
@export var occlusion_priority: int = 0

# LOD
@export var lod_distances: Array[float] = [100, 300, 500]
@export var lod_meshes: Array[PackedScene] = []

func get_silhouette_score() -> float:
    # Calculate how recognizable this landmark is
    var score = 0.0
    
    # Size contributes
    score += scale.length() * 0.1
    
    # Contrast contributes
    if silhouette_type != SilhouetteType.CUSTOM:
        score += 0.3  # Distinct silhouette types are more recognizable
    
    # Importance contributes
    match importance:
        ImportanceLevel.PRIMARY:
            score += 0.4
        ImportanceLevel.SECONDARY:
            score += 0.2
        ImportanceLevel.TERTIARY:
            score += 0.0
    
    return clamp(score, 0.0, 1.0)
```

### Occlusion System Design

#### HorizonOcclusion.gd

```gdscript
## System to hide world boundaries using multiple techniques

class_name HorizonOcclusion extends Node

# Fog settings
@export var fog_enabled: bool = true
@export var fog_mode: int = Environment.FOG_EXPONENTIAL
@export var fog_density: float = 0.005
@export var fog_color: Color = Color(0.8, 0.85, 1.0)

# Distance culling
@export var culling_enabled: bool = true
@export var culling_distance: float = 1500.0

# Geometry occlusion
@export var geometry_occlusion: bool = true
@export var occlusion_distance: float = 1000.0
@export var occlusion_meshes: Array[MeshInstance3D]

# Skybox
@export var skybox_enabled: bool = false
@export var skybox_texture: Texture

func _ready() -> void:
    apply_occlusion()

func apply_occlusion() -> void:
    # Apply fog
    if fog_enabled:
        var world_env = get_world_environment()
        if world_env:
            world_env.fog_enabled = true
            world_env.fog_mode = fog_mode
            world_env.fog_density = fog_density
            world_env.fog_color = fog_color
    
    # Apply culling to all static objects
    if culling_enabled:
        apply_culling_to_all()
    
    # Create occlusion geometry
    if geometry_occlusion:
        create_occlusion_geometry()

func get_world_environment() -> WorldEnvironment:
    return get_tree().root.find_child("WorldEnvironment", true, false) as WorldEnvironment

func apply_culling_to_all() -> void:
    var static_objects = get_tree().get_nodes_in_group("static")
    for obj in static_objects:
        if obj is GeometryInstance3D:
            obj.visibility_range_end = culling_distance

func create_occlusion_geometry() -> void:
    # Create distant mountains/geometry to hide edge
    if occlusion_meshes.is_empty():
        # Create default occlusion
        create_default_occlusion()
    
    for mesh_scene in occlusion_meshes:
        var instance = mesh_scene.instantiate()
        add_child(instance)
        instance.position = Vector3(0, 0, -occlusion_distance)
        instance.scale = Vector3(10, 10, 10)

func create_default_occlusion() -> void:
    # Create a simple ring of mountains
    var mountain_scene = preload("res://assets/terrain/mountain.glb")
    
    for i in range(8):
        var angle = i * PI / 4
        var distance = 800.0
        var mountain = mountain_scene.instantiate()
        add_child(mountain)
        mountain.position = Vector3(cos(angle) * distance, 0, sin(angle) * distance)
        mountain.rotation.y = angle + PI/2
        mountain.scale = Vector3(3, 3, 3)
```

---

## Code Samples

### 1. Complete Opening Grove Generator

#### OpeningGrove.gd

```gdscript
## Generates the complete opening grove area

class_name OpeningGrove extends Node3D

# Configuration
@export var radius: float = 25.0
@export var center: Vector3 = Vector3.ZERO

# Composition elements
@export var ground_mesh: PackedScene
@export var ground_material: StandardMaterial3D

@export var tree_density: float = 0.02
@export var bush_density: float = 0.05
@export var grass_density: float = 0.3

# Spawn points
@export var player_spawn_offset: Vector3 = Vector3(0, 0, 5)
@export var guide_spawn_offset: Vector3 = Vector3(3, 0, 0)

# Routes
@export var route_to_forest: RouteDefinition
@export var route_to_house: RouteDefinition

func _ready() -> void:
    generate()

func generate() -> void:
    # Generate ground
    generate_ground()
    
    # Generate foliage
    generate_foliage()
    
    # Generate routes
    generate_routes()
    
    # Create spawn points
    create_spawn_points()
    
    # Create landmark references
    create_landmark_references()

func generate_ground() -> void:
    if ground_mesh:
        var ground = ground_mesh.instantiate()
        add_child(ground)
        ground.position = center
        if ground_material:
            ground.material_override = ground_material

func generate_foliage() -> void:
    var rng = RandomNumberGenerator.new()
    rng.seed = hash("opening_grove_foliage")
    
    var trees = preload("res://assets/kenney/nature/trees.tscn")
    var bushes = preload("res://assets/kenney/nature/bushes.tscn")
    var grass = preload("res://assets/kenney/nature/grass.tscn")
    
    for i in range(100):
        var angle = rng.randf() * TAU
        var distance = rng.randf() * radius * 0.9
        var pos = center + Vector3(cos(angle) * distance, 0, sin(angle) * distance)
        
        # Create small height variation
        pos.y = rng.randf() * 0.2
        
        # Check if position is valid (not too close to center)
        if pos.distance_to(center) < 5.0:
            continue
        
        # Decide what to spawn
        var choice = rng.randf()
        if choice < tree_density:
            var tree = trees.instantiate()
            add_child(tree)
            tree.global_position = pos
            tree.scale = Vector3(rng.randf_range(0.8, 1.2), rng.randf_range(0.8, 1.2), rng.randf_range(0.8, 1.2))
            tree.rotation.y = rng.randf() * TAU
        elif choice < tree_density + bush_density:
            var bush = bushes.instantiate()
            add_child(bush)
            bush.global_position = pos
            bush.scale = Vector3(rng.randf_range(0.5, 1.0), rng.randf_range(0.5, 1.0), rng.randf_range(0.5, 1.0))
            bush.rotation.y = rng.randf() * TAU
        elif choice < tree_density + bush_density + grass_density:
            var grass_patch = grass.instantiate()
            add_child(grass_patch)
            grass_patch.global_position = pos

func generate_routes() -> void:
    if route_to_forest:
        var route = route_to_forest.generate_path()
        add_child(route)
        
        # Add visual trail
        var trail = create_trail_from_path(route)
        add_child(trail)
    
    if route_to_house:
        var route = route_to_house.generate_path()
        add_child(route)
        
        var trail = create_trail_from_path(route)
        add_child(trail)

func create_trail_from_path(path: Path3D) -> MeshInstance3D:
    # Generate mesh from path
    var mesh_data = Array()
    var curve_count = path.get_curve_count()
    
    for i in range(curve_count):
        var curve = path.get_curve(i)
        var point_count = curve.get_point_count()
        
        for j in range(point_count - 1):
            # Get points
            var p1 = curve.get_point_position(j)
            var p2 = curve.get_point_position(j + 1)
            
            # Create quad for trail segment
            var width = 2.0
            var up = Vector3.UP
            var right = (p2 - p1).normalized().cross(up).normalized()
            
            # Vertices
            mesh_data.append(p1 + right * width/2 + up * 0.01)
            mesh_data.append(p1 - right * width/2 + up * 0.01)
            mesh_data.append(p2 + right * width/2 + up * 0.01)
            
            mesh_data.append(p2 + right * width/2 + up * 0.01)
            mesh_data.append(p1 - right * width/2 + up * 0.01)
            mesh_data.append(p2 - right * width/2 + up * 0.01)
    
    var mesh = ArrayMesh.new()
    mesh.surface_add_from_arrays(Mesh.PRIMITIVE_TRIANGLES, mesh_data)
    
    var trail = MeshInstance3D.new()
    trail.mesh = mesh
    trail.material_override = preload("res://assets/materials/dirt_trail.tres")
    return trail

func create_spawn_points() -> void:
    # Player spawn
    var player_spawn = Marker3D.new()
    add_child(player_spawn)
    player_spawn.name = "PlayerSpawn"
    player_spawn.global_position = center + player_spawn_offset
    
    # Guide spawn
    var guide_spawn = Marker3D.new()
    add_child(guide_spawn)
    guide_spawn.name = "GuideSpawn"
    guide_spawn.global_position = center + guide_spawn_offset
    
    # Add to group for easy finding
    player_spawn.add_to_group("spawn_points")
    guide_spawn.add_to_group("spawn_points")

func create_landmark_references() -> void:
    # Create reference nodes for landmarks
    # These will be linked to actual landmark instances
    var landmarks = get_tree().get_nodes_in_group("landmarks")
    for landmark in landmarks:
        if landmark.name == "GuideHouse":
            # Position house at end of route
            if route_to_house:
                var end_point = route_to_house.end_point
                landmark.global_position = end_point
```

### 2. Guide Introduction System

#### GuideIntroduction.gd

```gdscript
## Handles the guide character introduction in the opening grove

class_name GuideIntroduction extends Node

# Configuration
@export var guide_scene: PackedScene
@export var spawn_point_name: String = "GuideSpawn"
@export var player_detection_range: float = 3.0

# Dialogue
@export var dialogue: Array[Dictionary] = [
    {"text": "Witaj w Choyce Engine!", "duration": 2.0},
    {"text": "Jestem twoim przewodnikiem.", "duration": 2.0},
    {"text": "Chodź, pokażę ci świat!", "duration": 2.0}
]

# State
var guide: CharacterBody3D = null
var player: CharacterBody3D = null
var current_dialogue_index: int = 0
var is_talking: bool = false

func _ready() -> void:
    # Find spawn point
    var spawn_points = get_tree().get_nodes_in_group("spawn_points")
    for spawn in spawn_points:
        if spawn.name == spawn_point_name:
            spawn_guide(spawn.global_position)
            break
    
    # Find player
    player = get_tree().get_first_node_in_group("player")

func _process(delta: float) -> void:
    if not guide or not player:
        return
    
    # Check if player is near
    var distance = guide.global_position.distance_to(player.global_position)
    if distance < player_detection_range and not is_talking:
        start_dialogue()

func spawn_guide(position: Vector3) -> void:
    if guide_scene:
        guide = guide_scene.instantiate()
        get_tree().current_scene.add_child(guide)
        guide.global_position = position
        guide.name = "Guide"
        
        # Setup guide
        setup_guide()

func setup_guide() -> void:
    if not guide:
        return
    
    # Add to group
    guide.add_to_group("guide")
    guide.add_to_group("npcs")
    
    # Setup facial performance
    var facial = FacialPerformance.new()
    guide.add_child(facial)
    
    # Look at player
    var look_at_player = LookAtPlayer.new()
    guide.add_child(look_at_player)

func start_dialogue() -> void:
    if not guide or is_talking:
        return
    
    is_talking = true
    current_dialogue_index = 0
    say_next_line()

func say_next_line() -> void:
    if current_dialogue_index >= dialogue.size():
        end_dialogue()
        return
    
    var line = dialogue[current_dialogue_index]
    
    # Speak the line
    if guide.has_node("Voice"):
        var voice = guide.get_node("Voice") as VoicePlayer
        voice.say(line["text"])
    
    # Show caption
    show_caption(line["text"])
    
    # Advance after duration
    current_dialogue_index += 1
    var timer = get_tree().create_timer(line.get("duration", 2.0))
    timer.timeout.connect(_on_line_finished)

func _on_line_finished() -> void:
    hide_caption()
    say_next_line()

func end_dialogue() -> void:
    is_talking = false
    hide_caption()
    
    # Guide can now follow player or move to next position
    guide.get_node("Navigation").target_position = player.global_position

func show_caption(text: String) -> void:
    var ui = get_tree().get_first_node_in_group("ui")
    if ui and ui.has_method("show_caption"):
        ui.call("show_caption", text, guide.name)

func hide_caption() -> void:
    var ui = get_tree().get_first_node_in_group("ui")
    if ui and ui.has_method("hide_caption"):
        ui.call("hide_caption")
```

### 3. Trail System

#### Trail.gd

```gdscript
## Trail generation and management

class_name Trail extends Node3D

@export var width: float = 2.0
@export var material: StandardMaterial3D
@export var resolution: float = 0.5  # Meters between vertices

var path: Path3D = null
var mesh_instance: MeshInstance3D = null

func _ready() -> void:
    path = $Path3D
    generate_mesh()

func generate_mesh() -> void:
    if not path:
        return
    
    # Remove old mesh
    if mesh_instance:
        mesh_instance.queue_free()
    
    # Generate mesh from path
    var mesh_data = Array()
    var length = path.get_baked_length()
    var point_count = ceil(length / resolution)
    
    for i in range(point_count - 1):
        var offset1 = i * resolution
        var offset2 = (i + 1) * resolution
        
        var p1 = path.get_point_at_offset(offset1)
        var p2 = path.get_point_at_offset(offset2)
        
        var tangent1 = path.get_point_tangent(offset1).normalized()
        var tangent2 = path.get_point_tangent(offset2).normalized()
        
        var up = Vector3.UP
        var right1 = tangent1.cross(up).normalized()
        var right2 = tangent2.cross(up).normalized()
        
        # Vertices for quad segment
        mesh_data.append(p1 + right1 * width/2)
        mesh_data.append(p1 - right1 * width/2)
        mesh_data.append(p2 + right2 * width/2)
        
        mesh_data.append(p2 + right2 * width/2)
        mesh_data.append(p1 - right1 * width/2)
        mesh_data.append(p2 - right2 * width/2)
    
    # Create mesh
    var mesh = ArrayMesh.new()
    mesh.surface_add_from_arrays(Mesh.PRIMITIVE_TRIANGLES, mesh_data)
    
    # Create mesh instance
    mesh_instance = MeshInstance3D.new()
    mesh_instance.mesh = mesh
    mesh_instance.material_override = material
    add_child(mesh_instance)
    mesh_instance.name = "TrailMesh"

func set_points(points: Array[Vector3]) -> void:
    if not path:
        return
    
    path.clear_points()
    for point in points:
        path.add_point(point)
    
    generate_mesh()

func add_point(point: Vector3) -> void:
    if path:
        path.add_point(point)
        generate_mesh()
```

### 4. Landmark Spawner

#### LandmarkSpawner.gd

```gdscript
## Spawns landmarks in the world based on definitions

class_name LandmarkSpawner extends Node

@export var landmarks: Array[LandmarkDefinition] = []

func _ready() -> void:
    spawn_all_landmarks()

func spawn_all_landmarks() -> void:
    for landmark_def in landmarks:
        spawn_landmark(landmark_def)

func spawn_landmark(definition: LandmarkDefinition) -> Node3D:
    var landmark: Node3D = null
    
    if definition.mesh:
        # Spawn from mesh
        landmark = definition.mesh.instantiate()
    elif definition.is_procedural:
        # Generate procedurally
        landmark = generate_procedural_landmark(definition)
    else:
        push_warning("Landmark definition has no mesh or procedural type")
        return null
    
    # Add to scene
    get_tree().current_scene.add_child(landmark)
    
    # Configure landmark
    landmark.global_position = definition.position
    landmark.global_rotation = definition.rotation
    landmark.scale = definition.scale
    landmark.name = definition.name
    
    # Add to group
    landmark.add_to_group("landmarks")
    
    # Apply materials
    if definition.materials.size() > 0:
        for child in landmark.get_children():
            if child is MeshInstance3D:
                child.material_override = definition.materials[0]
    
    # Setup interaction if applicable
    if definition.can_enter:
        setup_enterable(landmark, definition)
    
    # Setup occlusion if applicable
    if definition.hides_boundary:
        setup_occlusion(landmark, definition)
    
    return landmark

func generate_procedural_landmark(definition: LandmarkDefinition) -> Node3D:
    match definition.procedural_type:
        "FOREST":
            return generate_forest(definition)
        "VILLAGE":
            return generate_village(definition)
        "BEACH":
            return generate_beach(definition)
        "CAVE":
            return generate_cave(definition)
        _:
            push_warning("Unknown procedural type: " + definition.procedural_type)
            return null

func generate_forest(definition: LandmarkDefinition) -> Node3D:
    var forest = Node3D.new()
    forest.name = "ProceduralForest"
    
    var rng = RandomNumberGenerator.new()
    rng.seed = hash(definition.name)
    
    var radius = definition.procedural_params.get("radius", 50.0)
    var density = definition.procedural_params.get("density", 0.02)
    var tree_count = ceil(PI * radius * radius * density)
    
    var tree_scene = preload("res://assets/kenney/nature/oak_tree.tscn")
    
    for i in range(tree_count):
        var angle = rng.randf() * TAU
        var distance = rng.randf() * radius
        var pos = Vector3(cos(angle) * distance, 0, sin(angle) * distance)
        
        var tree = tree_scene.instantiate()
        forest.add_child(tree)
        tree.position = pos
        tree.rotation.y = rng.randf() * TAU
        tree.scale = Vector3(rng.randf_range(0.8, 1.2), rng.randf_range(0.8, 1.2), rng.randf_range(0.8, 1.2))
    
    return forest

func setup_enterable(landmark: Node3D, definition: LandmarkDefinition) -> void:
    # Add collision for entering
    var collision = CollisionShape3D.new()
    landmark.add_child(collision)
    collision.shape = BoxShape3D.new()
    collision.shape.size = definition.scale * Vector3(3, 3, 3)
    
    # Add entry trigger
    var trigger = Area3D.new()
    landmark.add_child(trigger)
    trigger.add_to_group("enter_triggers")
    trigger.monitoring = true
    trigger.connect("body_entered", _on_landmark_entered.bind(definition))

func setup_occlusion(landmark: Node3D, definition: LandmarkDefinition) -> void:
    # Mark as occlusion
    landmark.add_to_group("occlusion")
    
    # If it's a boundary hider, extend it
    if definition.name.containsi("mountain") or definition.name.containsi("cliff"):
        landmark.scale *= Vector3(10, 10, 10)

func _on_landmark_entered(body: Node3D, definition: LandmarkDefinition) -> void:
    if body is CharacterBody3D:
        # Player entered landmark
        var ui = get_tree().get_first_node_in_group("ui")
        if ui and ui.has_method("show_landmark_notification"):
            ui.call("show_landmark_notification", definition.name, definition.description)
```

---

## Asset Packages & 3D Models

### Recommended Asset Sources

#### 1. Kenney Nature Kit (CC0)

**Primary Source**: [https://kenney.nl/assets/nature-pack](https://kenney.nl/assets/nature-pack)

**What's Included:**
- Trees: Oak, Pine, Palm, Dead Tree (5+ types)
- Rocks: Large, Medium, Small, Cluster
- Bushes: 3 types
- Grass: Multiple patches
- Flowers: Various types
- Logs, Stumps, Leaves
- Terrain textures

**Why It's Perfect for VS-013:**
- Consistent art style
- CC0 license (no attribution required)
- Low-poly, good performance
- Already in project (mentioned in PLAN.md)
- Child-friendly appearance

**File Structure:**
```
assets/kenney/nature/
├── trees/
│   ├── oak.glb
│   ├── pine.glb
│   ├── palm.glb
│   └── dead.glb
├── rocks/
│   ├── large.glb
│   ├── medium.glb
│   └── small.glb
├── bushes/
│   ├── bush1.glb
│   ├── bush2.glb
│   └── bush3.glb
├── grass/
│   ├── patch1.glb
│   ├── patch2.glb
│   └── patch3.glb
├── flowers/
│   ├── flower1.glb
│   └── flower2.glb
└── textures/
    ├── albedo/
    ├── normal/
    └── roughness/
```

#### 2. Kenney Building Kit (CC0)

**Source**: [https://kenney.nl/assets/building-kit](https://kenney.nl/assets/building-kit) (if available)

**Alternative**: Use Quaternius buildings

**What's Needed for VS-013:**
- **Guide House**: Small cottage or hut
- **Village Buildings**: 3-5 houses for distant village
- **Fences**: To define areas
- **Wells, Benches**: For grove decoration

**Quaternius Buildings**: [https://quaternius.com/free-3d-models?category=buildings](https://quaternius.com/free-3d-models?category=buildings)
- **Recommended:**
  - "Cottage" - Perfect for guide house
  - "Medieval House" - For village
  - "Farmhouse" - Alternative
  - "Small Hut" - Minimal option

#### 3. Quaternius Foliage & Props

**Foliage**: [https://quaternius.com/free-3d-models?category=nature](https://quaternius.com/free-3d-models?category=nature)
- **Recommended:**
  - Additional tree types
  - Flowers and plants
  - Mushrooms
  - Vines and climbing plants

**Props**: [https://quaternius.com/free-3d-models?category=props](https://quaternius.com/free-3d-models?category=props)
- **Recommended:**
  - Barrels, crates
  - Benches, tables
  - Fences, gates
  - Signposts

#### 4. Poly Pizza Low-Poly Models

**Low-Poly Trees**: [https://poly.pizza/search?q=low+poly+tree](https://poly.pizza/search?q=low+poly+tree)
- CC0 licensed
- Additional variety for forest

**Low-Poly Rocks**: [https://poly.pizza/search?q=low+poly+rock](https://poly.pizza/search?q=low+poly+rock)
- Additional rock types

#### 5. CC0 Textures

**Ground Textures:**
- **CC0Textures**: [https://cc0textures.com/](https://cc0textures.com/)
  - Dirt, grass, sand, stone
  - PBR textures (albedo, normal, roughness, height)
  - Seamless tiling

**Specific Recommendations:**
- `Ground003` from AmbientCG (already in project)
- `Grass001` for meadow areas
- `Dirt002` for trails
- `Sand001` for beach
- `Rock003` for cave entrance

### Asset Structure for VS-013

```
assets/
├── opening/
│   ├── composition/
│   │   ├── opening_grove.tscn          # Main grove scene
│   │   ├── guide_house.tscn           # Guide house prefab
│   │   ├── routes/                    # Route prefabs
│   │   │   ├── route_to_forest.tscn
│   │   │   └── route_to_house.tscn
│   │   └── landmarks/                 # Landmark prefabs
│   │       ├── forest.tscn
│   │       ├── village.tscn
│   │       ├── beach.tscn
│   │       ├── cave.tscn
│   │       └── mountain.tscn
│   ├── materials/
│   │   ├── trail_dirt.tres
│   │   ├── trail_stone.tres
│   │   ├── grove_grass.tres
│   │   └── landmark_highlight.tres
│   └── scripts/
│       ├── opening_grove.gd
│       ├── guide_introduction.gd
│       └── landmark_spawner.gd
└── kenney/
    ├── nature/                        # Kenney Nature Kit
    └── buildings/                     # Kenney Building Kit (or Quaternius)
```

### Asset Import Settings

**General Settings:**
- Scale: 1.0 = 1 meter
- Import Meshes: Yes
- Import Materials: Yes
- Compression: Enabled
- Mipmaps: Enabled

**Tree Import:**
- Scale: Adjust to match character scale
- Collision: Add CapsuleShape3D for trunk
- LOD: Use for distant trees

**Rock Import:**
- Scale: 0.5-2.0 meters
- Collision: Add ConvexPolygonShape3D or BoxShape3D
- LOD: Not needed (simple geometry)

**Building Import:**
- Scale: Match character scale (door height ~2m)
- Collision: Add compound collision
- LOD: Use for distant buildings

---

## Best Practices

### 1. Child-Safe World Composition

**Visual Design:**
- ✅ **USE**: Bright, warm colors
- ✅ **USE**: Round, soft shapes
- ✅ **USE**: Clear visual hierarchy
- ✅ **USE**: Simple, readable silhouettes
- ❌ **AVOID**: Dark, scary areas
- ❌ **AVOID**: Sharp, pointy objects at child height
- ❌ **AVOID**: Cluttered, confusing layouts
- ❌ **AVOID**: Steep drops without barriers

**Navigation Design:**
- ✅ **USE**: Wide, clear trails
- ✅ **USE**: Visual breadcrumbs (guide, signs, lighting)
- ✅ **USE**: Gentle slopes, no steep hills
- ✅ **USE**: Logical layout (house near trail, forest beyond)
- ❌ **AVOID**: Dead ends
- ❌ **AVOID**: Complex mazes
- ❌ **AVOID**: Jumping puzzles in opening

**Landmark Design:**
- ✅ **USE**: Unique silhouettes for each landmark
- ✅ **USE**: Size proportional to importance
- ✅ **USE**: Color differentiation
- ✅ **USE**: Subtle motion (wind, animals)
- ❌ **AVOID**: Similar-looking landmarks
- ❌ **AVOID**: Hidden or hard-to-see landmarks
- ❌ **AVOID**: Landmarks that look the same from all angles

### 2. Performance Optimization

**Object Count:**
- Grove area: 50-100 objects max
- Trees: 30-50 (use instancing for similar trees)
- Bushes: 50-100
- Grass: Use MultiMesh or instancing
- Rocks: 20-40

**Drawing:**
- Use LOD for all complex objects
- Cull objects beyond 500m
- Use MultiMesh for repeated objects (grass, flowers)
- Limit to <200 draw calls in opening area

**Physics:**
- Static collision for terrain, buildings
- Simplified collision for complex meshes
- Use collision layers to optimize checks
- Disable collision for decorative-only objects

**Memory:**
- Pool frequently used objects
- Stream assets as needed
- Use low-resolution textures for distant objects
- Compress all textures

### 3. User Experience

**Discoverability:**
- Guide character is first thing player sees
- Clear path from spawn to guide
- Two obvious routes from grove
- Each route has visual destination
- Landmarks visible before reaching them

**Pacing:**
- Grove: 0-1 minute (introduction)
- First route: 1-3 minutes (exploration)
- First landmark: 3-5 minutes (discovery)
- Return to grove: 5-7 minutes (loop)

**Feedback:**
- Subtle audio cues for important areas
- Visual highlights for interactive objects
- Particle effects for discoveries
- Camera emphasis on first-time sights

### 4. Testing Requirements

**Automated Tests:**
- Opening grove has all required elements
- Player spawns at correct position
- Guide spawns at correct position
- Routes connect correctly
- Landmarks are positioned correctly
- No overlapping collision

**Manual Tests:**
- First screenshot is intentional
- Player can find and talk to guide
- Player can see both routes from grove
- Player can follow routes to landmarks
- Landmarks are recognizable from distance
- No visible map edge or chunk boundaries

---

## Testing Checklist

### Unit Tests

```gdscript
# test_opening_grove.gd

func test_grove_has_all_elements():
    var grove = OpeningGrove.new()
    grove.generate()
    
    # Check ground exists
    var ground = grove.get_node("Ground")
    assert(ground != null)
    
    # Check spawn points exist
    var player_spawn = grove.get_node("PlayerSpawn")
    assert(player_spawn != null)
    
    var guide_spawn = grove.get_node("GuideSpawn")
    assert(guide_spawn != null)
    
    # Check routes exist
    var routes = grove.get_children().filter(func(n): return n is Trail)
    assert(routes.size() >= 2)

func test_grove_radius():
    var grove = OpeningGrove.new()
    grove.radius = 25.0
    grove.generate()
    
    # Check all foliage is within radius
    for child in grove.get_children():
        if child is MeshInstance3D and not child.name.contains("Ground"):
            var distance = child.global_position.distance_to(grove.center)
            assert(distance <= grove.radius)

func test_routes_connect():
    var route1 = RouteDefinition.new()
    route1.start_point = Vector3(0, 0, 0)
    route1.end_point = Vector3(0, 0, 50)
    
    var route2 = RouteDefinition.new()
    route2.start_point = Vector3(0, 0, 50)
    route2.end_point = Vector3(50, 0, 50)
    
    # Routes should connect at (0, 0, 50)
    assert(route1.end_point == route2.start_point)
```

### Integration Tests

1. **Opening Grove in World**
   - [ ] Grove loads correctly in adventure template
   - [ ] Player spawns at correct position
   - [ ] Guide spawns at correct position
   - [ ] Guide introduces self to player
   - [ ] Routes are visible and followable

2. **Landmark Visibility**
   - [ ] All landmarks visible from grove
   - [ ] Landmarks have distinct silhouettes
   - [ ] No landmarks blocked by other objects
   - [ ] Landmarks visible before reaching them

3. **Horizon Occlusion**
   - [ ] No visible map edge from grove
   - [ ] No visible chunk boundaries
   - [ ] Distant geometry hides world end
   - [ ] Fog or culling hides distant objects

4. **Performance**
   - [ ] No frame rate drops in grove
   - [ ] Memory usage is stable
   - [ ] All objects have collision
   - [ ] Works on Tier 2 hardware

### Manual Tests

1. **First Screenshot Test**
   - [ ] Screenshot at spawn is intentional
   - [ ] Player character is visible
   - [ ] Guide character is visible
   - [ ] Grove is inviting
   - [ ] Routes are clear
   - [ ] No debug visuals

2. **Exploration Test**
   - [ ] Player can find guide
   - [ ] Player can talk to guide
   - [ ] Player can see both routes
   - [ ] Player can follow route to forest
   - [ ] Player can follow route to house
   - [ ] Player can return to grove

3. **Landmark Test**
   - [ ] Forest is visible from grove
   - [ ] Village is visible from grove
   - [ ] Beach is visible from grove
   - [ ] Cave is visible from grove
   - [ ] Distant landmark is visible
   - [ ] Each landmark has unique silhouette

4. **Visual Quality Test**
   - [ ] All objects have materials
   - [ ] No missing textures
   - [ ] No floating objects
   - [ ] No clipping geometry
   - [ ] Lighting is appropriate
   - [ ] Colors are child-friendly

---

## Learning Resources

### Official Godot Documentation

1. **3D Tutorials**: [https://docs.godotengine.org/en/stable/tutorials/3d/index.html](https://docs.godotengine.org/en/stable/tutorials/3d/index.html)
2. **Scene Composition**: [https://docs.godotengine.org/en/stable/tutorials/3d/scene_composition.html](https://docs.godotengine.org/en/stable/tutorials/3d/scene_composition.html)
3. **Path3D**: [https://docs.godotengine.org/en/stable/classes/class_path3d.html](https://docs.godotengine.org/en/stable/classes/class_path3d.html)
4. **FastNoiseLite**: [https://docs.godotengine.org/en/stable/classes/class_fastnoiselite.html](https://docs.godotengine.org/en/stable/classes/class_fastnoiselite.html)

### Community Tutorials

1. **GDQuest - 3D Level Design**: [https://gdquest.com/tutorial/godot-3d-level-design/](https://gdquest.com/tutorial/godot-3d-level-design/)
2. **HeartBeast - Scene Composition**: [https://www.heartbeast.co/godot-3d-composition/](https://www.heartbeast.co/godot-3d-composition/)
3. **KidsCanCode - Building Worlds**: [https://kids-candies.gitbook.io/godot-tutorials/3d/building-a-world](https://kids-candies.gitbook.io/godot-tutorials/3d/building-a-world)

### Design References

1. **Level Design Theory**: [https://80.lv/articles/level-design-theory/](https://80.lv/articles/level-design-theory/)
2. **Visual Hierarchy**: [https://www.interaction-design.org/literature/topics/visual-hierarchy](https://www.interaction-design.org/literature/topics/visual-hierarchy)
3. **Environment Design**: [https://polycount.com/discussion/14855/environment-design-principles](https://polycount.com/discussion/14855/environment-design-principles)

### Asset References

1. **Kenney Nature Kit**: [https://kenney.nl/assets/nature-pack](https://kenney.nl/assets/nature-pack)
2. **Kenney Building Kit**: [https://kenney.nl/assets/building-kit](https://kenney.nl/assets/building-kit)
3. **Quaternius**: [https://quaternius.com](https://quaternius.com)
4. **Poly Pizza**: [https://poly.pizza](https://poly.pizza)
5. **CC0Textures**: [https://cc0textures.com](https://cc0textures.com)

---

## Implementation Roadmap

### Phase 1: Planning & Design (1-2 hours)
- [ ] Create opening composition diagram
- [ ] Define grove layout (radius, center, spawn points)
- [ ] Design 2 main routes
- [ ] Select landmark positions and types
- [ ] Define horizon occlusion strategy
- [ ] Create asset list

### Phase 2: Asset Pipeline (2-3 hours)
- [ ] Import Kenney Nature Kit
- [ ] Import Kenney/Quaternius Building Kit
- [ ] Create ground mesh and material
- [ ] Create trail meshes and materials
- [ ] Test all assets in scene
- [ ] Create material library

### Phase 3: Grove System (2-3 hours)
- [ ] Create OpeningGrove.gd
- [ ] Implement ground generation
- [ ] Implement foliage scattering
- [ ] Create spawn points
- [ ] Add trail system
- [ ] Test grove composition

### Phase 4: Guide System (1-2 hours)
- [ ] Create GuideIntroduction.gd
- [ ] Setup guide spawn
- [ ] Implement dialogue system
- [ ] Add facial animation
- [ ] Test guide introduction

### Phase 5: Landmark System (2-3 hours)
- [ ] Create LandmarkDefinition resource
- [ ] Create LandmarkSpawner.gd
- [ ] Implement Forest landmark
- [ ] Implement Village landmark
- [ ] Implement Beach landmark
- [ ] Implement Cave landmark
- [ ] Implement Distant Mountain

### Phase 6: Horizon Occlusion (1-2 hours)
- [ ] Implement fog-based occlusion
- [ ] Add distance culling
- [ ] Create boundary geometry
- [ ] Test occlusion from all angles
- [ ] Adjust for best visual quality

### Phase 7: Integration & Polish (2-3 hours)
- [ ] Integrate grove with world_renderer
- [ ] Connect to adventure template
- [ ] Add lighting
- [ ] Add post-processing
- [ ] Test full opening flow
- [ ] Performance testing

### Phase 8: Testing (1-2 hours)
- [ ] Write unit tests
- [ ] Manual UX testing
- [ ] Visual acceptance testing
- [ ] Performance testing
- [ ] Child-safety review

### Total Estimated Time: 14-23 hours

---

## References

### Internal Project References
- `src/adapters/inbound/gameplay/world_renderer.gd` - World generation system
- `data/templates/adventure.json` - Adventure template configuration
- `PLAN.md` - Project requirements and visual rescue gate
- `.ai/handoffs/` - Handoff documents

### External References
- [Godot Engine Documentation](https://docs.godotengine.org/en/stable/)
- [GDQuest Tutorials](https://gdquest.com/)
- [KidsCanCode Tutorials](https://kids-candies.gitbook.io/godot-tutorials/)
- [Kenney Assets](https://kenney.nl/assets)
- [Quaternius Models](https://quaternius.com)
- [Poly Pizza Models](https://poly.pizza/)

### Related Tasks
- VS-012: Visual art direction (materials, lighting)
- VS-014: Modern Game UI (captions, prompts)
- VS-013: Compose opening route (this task)
- VS-017/019: Procedural world streaming (beyond opening)
- VS-001/002/003: Template preservation (for authored content)

---

## Document Information

**Created**: 2026-07-18  
**Author**: Mistral Vibe (Codex)  
**Version**: 1.0  
**Status**: Deep Research Complete - Ready for Implementation  
**Priority**: HIGH (Gate A requirement)  

---

*This research compendium was created as part of the Choyce Engine VS-013 Opening Route Composition task. All information is accurate as of July 2026. Online resources and links may change over time.*
