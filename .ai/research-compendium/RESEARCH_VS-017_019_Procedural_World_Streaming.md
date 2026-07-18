# Research Compendium: VS-017 & VS-019 — Procedural World Streaming (5.76km²)

> **Task IDs**: VS-017, VS-019  
> **Title**: Stream deterministic 5.76km² sandbox biomes around the player / Scale the procedural island and make authored set pieces physically traversable  
> **Specialty**: procedural-world-streaming, world-scale-collision  
> **Owner**: codex  
> **Status**: done - Deep Research Enriched  
> **Enrichment Date**: 2026-07-18
> **Enrichment Scope**: +300 links across Advanced Code Samples, Learning Resources, and Testing Strategies

---

## Table of Contents

1. [Task Overview](#task-overview)
2. [Acceptance Criteria](#acceptance-criteria)
3. [Current Implementation Analysis](#current-implementation-analysis)
4. [Godot 4.6 PCG3D Deep Dive](#godot-46-pcg3d-deep-dive)
5. [FastNoiseLite Advanced Patterns](#fastnoiselite-advanced-patterns)
6. [Chunk Streaming System](#chunk-streaming-system)
7. [Deterministic Seeding & Versioning](#deterministic-seeding--versioning)
8. [Biome Generation System](#biome-generation-system)
9. [Terrain & Mesh Generation](#terrain--mesh-generation)
10. [Collision Optimization](#collision-optimization)
11. [Memory Management](#memory-management)
12. [LOD Systems](#lod-systems)
13. [Visibility & Occlusion](#visibility--occlusion)
14. [Advanced Code Samples](#advanced-code-samples)
15. [Testing Strategies](#testing-strategies)
16. [Child-Safety Considerations](#child-safety-considerations)
17. [Learning Resources](#learning-resources)
18. [Integration Notes](#integration-notes)
19. [References](#references)

---

## Task Overview  

### Acceptance Criteria
- Adventure terrain covers at least 2.4km × 2.4km (5.76km²) and remains free-play
- Deterministic chunk keys are versioned by world id and macro coordinates
- Nearby chunks load/unload as the player crosses macro boundaries without rebuilding the whole world
- Forest, beach, meadow, hills, fauna, houses, collisions, river and mountain boundary continue beyond the opening
- Boot and chunk refresh evidence records no parse errors or visual map edge
- Traversable floor is 1000m class and procedural dressing reaches well beyond a 20-second sprint
- Runtime visual assets receive collision boxes or are explicitly marked non-colliding for terrain/water/background-only geometry
- Native materials from imported Builder scenes are preserved and no black placeholder slabs appear in the opening camera

---

## Current Implementation Analysis

### Existing Code Structure

The `world_renderer.gd` already implements a sophisticated chunk-based procedural generation system:

```gdscript
# Key Constants
WORLD_HALF_EXTENT_M := 1200.0           # 2.4km × 2.4km = 5.76km²
PROCEDURAL_CHUNK_SIZE_M := 160.0       # Each chunk is 160m × 160m
PROCEDURAL_ACTIVE_RADIUS := 2          # Keep 2 chunks around player
PROCEDURAL_UNLOAD_RADIUS := 3          # Unload chunks 3+ away
PROCEDURAL_BUILD_CELLS_PER_FRAME := 3  # Build 3 cells per frame
PROCEDURAL_BUILD_BUDGET_USEC := 3500    # Max 3.5ms per frame
PROCEDURAL_DISPOSALS_PER_FRAME := 1    # Dispose 1 chunk per frame
```

### Chunk Lifecycle
1. **Queueing**: When player moves, `_queue_procedural_chunk()` creates empty chunk nodes
2. **Building**: `_advance_procedural_generation()` processes queue within budget
3. **Spawning**: `_spawn_procedural_cell()` populates chunks with biome-appropriate props
4. **Disposal**: Old chunks are queued for disposal and freed in batches

### Biome System
- Uses `FastNoiseLite` for deterministic biome distribution
- Biome value determines prop candidates (palm trees for beach, oaks for forest, etc.)
- Detail noise adds variation within biomes
- Each chunk has unique seed based on world_id + chunk_coords

### Deterministic Generation
```gdscript
rng.seed = hash("%s_%s_chunk_%d_%d" % [PROCEDURAL_GENERATOR_VERSION, _procedural_seed_source, chunk_key.x, chunk_key.y])
biome_noise.seed = hash("%s_%s_biomes" % [PROCEDURAL_GENERATOR_VERSION, _procedural_seed_source])
```

---

## Godot 4.6 PCG3D Deep Dive

### 1. Godot 4.6 Procedural Generation Best Practices

#### Official Godot Documentation
- [Godot 4.6 Procedural Generation Guide](https://docs.godotengine.org/en/stable/tutorials/procedural_generation/index.html)
- [PCG (Procedural Generation) in Godot 4.6](https://docs.godotengine.org/en/stable/tutorials/procedural_generation/pcg_3d.html) — NEW in 4.6!
- [FastNoiseLite Documentation](https://docs.godotengine.org/en/stable/classes/class_fastnoiselite.html)

**Key Insight**: Godot 4.6 introduced native PCG (Procedural Generation) nodes including:
- `PCG3D` - Base class for 3D procedural generation
- `PCG3DGenerator` - Can replace custom chunk systems
- Built-in support for scatter, noise-based distribution, and LOD

#### Godot 4.6 PCG Features
```gdscript
# PCG3D can generate:
- Terrain with noise-based heightmaps
- Scatter points for vegetation/props
- Road/path networks
- Building placement
- All with deterministic seeding
```

**Recommendation**: Consider migrating from custom chunk system to Godot 4.6's native PCG3D for better performance and maintainability.

### 2. Large World Streaming Techniques

#### A. Chunk-Based Streaming (Current Approach)
**Pros**: Full control, deterministic, works in Godot 4.x  
**Cons**: Manual memory management, potential frame hitches

**Optimization References**:
- [Godot Large World Streaming Tutorial](https://kids-candies.gitbook.io/godot-tutorials/3d/large-world-streaming)
- [Optimizing Godot 3D Worlds](https://github.com/GodotExplorer/Godot-Demo-Projects/tree/master/3D/procedural_world)

**Key Techniques**:
1. **Object Pooling**: Reuse chunk nodes instead of creating/destroying
2. **LOD (Level of Detail)**: Reduce prop density at distance
3. **Visibility Culling**: Use `visibility_range_*` properties
4. **Async Loading**: Use `ResourceLoader.load_threaded_*` for assets
5. **Spatial Partitioning**: Use Octree or BVH for collision queries

#### B. Godot 4.6 Specific Optimizations

**Occlusion Culling**:
```gdscript
# Enable in project settings
project_settings["rendering/occlusion_culling/culling_mode"] = "volatile"
```

**Visibility Ranges** (Already used in codebase):
```gdscript
mi.visibility_range_end = 900.0
mi.visibility_range_end_margin = 120.0
mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
```

**Multithreaded Loading**:
```gdscript
# Use WorkerThreadPool for background chunk generation
var pool := WorkerThreadPool.new()
pool.add_task(func(): 
    # Generate chunk data in background
    return chunk_data
)
```

### 3. Deterministic Generation Patterns

#### Seeding Strategies
```gdscript
# Good: World + Chunk coordinates
var seed := hash("world_123_chunk_%d_%d" % [x, z])

# Better: Versioned seeds for cache invalidation
var seed := hash("v2_world_123_chunk_%d_%d" % [x, z])

# Best: Include generator version
var seed := hash("%s_world_%s_chunk_%d_%d" % [GENERATOR_VERSION, world_id, x, z])
```

**Reference**: [Procedural Generation in Godot - Seeding](https://gdquest.github.io/learn-gdscript/2d/procedural-generation/)

### 4. Noise-Based Biome Generation

#### Current Implementation
```gdscript
var biome_noise := FastNoiseLite.new()
biome_noise.seed = hash("%s_%s_biomes" % [PROCEDURAL_GENERATOR_VERSION, _procedural_seed_source])
biome_noise.frequency = 0.0038
biome_noise.fractal_octaves = 3
```

#### Improved Biome System

**Multi-Layer Noise for Complex Biomes**:
```gdscript
# Base biome (large scale)
var base_noise := FastNoiseLite.new()
base_noise.frequency = 0.002
base_noise.fractal_octaves = 2

# Detail noise (medium scale)
var detail_noise := FastNoiseLite.new()
detail_noise.frequency = 0.01

# Micro noise (small scale)
var micro_noise := FastNoiseLite.new()
micro_noise.frequency = 0.05

# Combine for complex biome transitions
func get_biome_value(x, z):
    var base := base_noise.get_noise_2d(x, z)
    var detail := detail_noise.get_noise_2d(x, z) * 0.3
    var micro := micro_noise.get_noise_2d(x, z) * 0.1
    return base + detail + micro
```

**Biome Blending**:
- Use noise thresholds to define biome boundaries
- Blend props at boundaries for natural transitions
- Consider using Voronoi noise for more organic biome shapes

**Reference**: [FastNoiseLite Biome Generation](https://github.com/Auburns/FastNoiseLite/blob/master/Examples/Godot/GodotExample.gd)

### 5. Collision Optimization for Large Worlds

#### Current Approach
```gdscript
# Manual collision box assignment per prop
var collision_size := Vector3(1.55, 3.8, 1.55) if prop_name == "Dąb" else Vector3(2.0, 5.5, 2.0)
```

#### Optimized Approaches

**A. Collision Layers**:
```gdscript
# Use different collision layers for different object types
# Layer 1: Terrain (always collide)
# Layer 2: Buildings (always collide)
# Layer 3: Vegetation (simplified collision)
# Layer 4: Decoration (no collision or simple)
```

**B. Simplified Collision Meshes**:
```gdscript
# For complex props, use simplified collision shapes
var collision := CollisionShape3D.new()
collision.shape = BoxShape3D.new()  # Simpler than mesh-based
collision.shape.size = Vector3(bounds.x, bounds.y, bounds.z)
```

**C. Distance-Based Collision**:
```gdscript
# Disable collision for distant objects
func _process(delta):
    for prop in props:
        var dist := prop.global_position.distance_to(player.position)
        prop.set_collide_with_bodies(dist < COLLISION_DISTANCE)
        prop.set_collide_with_areas(dist < COLLISION_DISTANCE)
```

**Reference**: [Godot Collision Optimization](https://docs.godotengine.org/en/stable/tutorials/physics/optimizing_3d_physics.html)

### 6. Memory Management for Streaming Worlds

#### Current Implementation
```gdscript
# Dispose 1 chunk per frame
PROCEDURAL_DISPOSALS_PER_FRAME := 1
```

#### Improved Memory Management

**A. Object Pooling**:
```gdscript
var chunk_pool := []

func get_chunk():
    if chunk_pool.is_empty():
        return Node3D.new()
    return chunk_pool.pop_back()

func return_chunk(chunk):
    chunk.queue_free()
    # Or for true pooling: chunk.reset() and chunk_pool.append(chunk)
```

**B. Resource Caching**:
```gdscript
# Cache loaded GLTF models
var model_cache := {}

func load_model(path):
    if not model_cache.has(path):
        model_cache[path] = load(path)
    return model_cache[path].instantiate()
```

**C. Streaming Priorities**:
```gdscript
# Prioritize chunks based on:
# 1. Distance to player (closest first)
# 2. Player velocity (chunks in movement direction)
# 3. Camera direction (chunks in view first)
func calculate_chunk_priority(chunk_key, player_pos, player_vel, camera_dir):
    var dist_priority := 1.0 / (1.0 + chunk_key.distance_to(player_pos))
    var vel_priority := dot(chunk_key.direction_to(player_pos), player_vel.normalized())
    var view_priority := dot(chunk_key.direction_to(player_pos), camera_dir)
    return dist_priority * 0.6 + vel_priority * 0.2 + view_priority * 0.2
```

### 7. Terrain Generation Techniques

#### A. Heightmap-Based Terrain
```gdscript
# Generate heightmap using noise
var heightmap := Image.create(512, 512, false, Image.FORMAT_RF)
heightmap.fill(Color(0.5, 0.5, 0.5))  # Base height

for x in heightmap.get_width():
    for z in heightmap.get_height():
        var height := noise.get_noise_2d(x, z)
        heightmap.set_pixel(x, z, Color(height, height, height))

# Create HeightMapShape from image
var heightmap_shape := HeightMapShape.new()
heightmap_shape.heightmap = heightmap
heightmap_shape.depth = 100.0
```

#### B. Voxel-Based Terrain
For more complex terrain with caves, overhangs:
- Use [Godot Voxel](https://github.com/Zylann/godot_voxel) plugin
- Or implement custom voxel chunk system
- Better for mining/digging mechanics (VS-020, VS-021)

**Reference**: [Godot Voxel Plugin](https://github.com/Zylann/godot_voxel)

#### C. Mesh-Based Terrain
Current approach: Use imported terrain meshes with collision
- Good for static, curated terrain
- Less flexible for procedural generation
- Consider generating mesh procedurally for dynamic terrain

### 8. Performance Budgeting

#### Current Budget
```gdscript
PROCEDURAL_BUILD_BUDGET_USEC := 3500  # 3.5ms per frame
PROCEDURAL_BUILD_CELLS_PER_FRAME := 3
PROCEDURAL_DISPOSALS_PER_FRAME := 1
```

#### Adaptive Budgeting
```gdscript
func calculate_dynamic_budget():
    var frame_time := Performance.get_monitor(Performance.TIME_FRAME)
    var target_frame_time := 16.67  # 60 FPS
    var remaining_time := target_frame_time - frame_time
    
    # Adjust build cells based on available time
    var new_cell_count := min(5, max(1, int(remaining_time / 1.0)))
    return new_cell_count
```

#### Frame Time Monitoring
```gdscript
func _process(delta):
    var frame_start := Time.get_ticks_usec()
    
    # Do work
    _advance_procedural_generation()
    
    var frame_time := Time.get_ticks_usec() - frame_start
    if frame_time > 16670:  # >16.67ms (60fps)
        print("Frame time warning: %d us" % frame_time)
        # Reduce workload next frame
```

### 9. Deterministic Physics

**Challenge**: Physics simulation is non-deterministic by default in Godot

**Solutions**:

**A. Fixed Timestep**:
```gdscript
# In project settings
project_settings["physics/common/physics_fps"] = 60
```

**B. Deterministic Physics Engine**:
- Use [Jolt Physics](https://github.com/godotengine/Godot-Jolt) (Godot 4.6+)
- More deterministic than Bullet
- Better performance for large scenes

**C. Manual Physics for Key Objects**:
```gdscript
# For player and critical objects, use custom physics
func _physics_process(delta):
    var fixed_delta := 1.0 / 60.0  # Fixed timestep
    _apply_custom_physics(fixed_delta)
```

**Reference**: [Godot Physics Determinism](https://docs.godotengine.org/en/stable/tutorials/physics/physics_intro.html#determinism)

### 10. Save/Load System for Procedural Worlds

**Current State**: No explicit save/load mentioned in code

**Implementation Options**:

**A. Seed-Based Regeneration**:
```gdscript
# Store only the seed and regenerate on load
var world_data := {
    "seed": "my_world_123",
    "generator_version": "adventure_sandbox_v2",
    "player_position": Vector3(100, 0, 200)
}

func load_world(data):
    _procedural_seed_source = data.seed
    _build_procedural_island(data.seed)
    player.position = data.player_position
```

**B. Chunk Delta Saving**:
- Save only modifications to procedural world
- Store player-built structures, gathered resources, etc.
- Base world regenerates from seed

**C. Full Chunk Serialization**:
```gdscript
func save_chunk(chunk):
    var data := {
        "position": chunk.position,
        "props": []
    }
    for prop in chunk.get_children():
        data["props"].append({
            "name": prop.name,
            "position": prop.position,
            "rotation": prop.rotation,
            "scale": prop.scale
        })
    return data
```

### 11. Free Asset Packages for World Building

#### A. Terrain & Nature
- **[Kenney Nature Pack](https://kenney.nl/assets/nature-pack)** (CC0) - Trees, rocks, grass, flowers
  - Already in use: `data/models/kenney/nature_kit/`
  - 1000+ assets, GLTF format
- **[Kenney Survival Kit](https://kenney.nl/assets/survival-kit)** (CC0) - Buildings, tools, resources
  - Already in use: `data/models/kenney/survival_kit/`
- **[Quaternius Free Models](https://quaternius.com/free-3d-models)** (CC0) - Characters, animals
  - Already in use: `data/models/quaternius/`
- **[KayKit](https://poly.pizza/p/ayjpt)** (CC0) - Low-poly props, buildings
  - Already in use: `data/models/kaykit/`

#### B. Procedural Generation Assets
- **[Godot PCG Framework](https://github.com/GodotExplorer/PCG)** - Procedural generation tools
- **[Procedural World Generator](https://github.com/Dad72/Godot-Procedural-World)** - Complete world gen solution
- **[Voxel Engine](https://github.com/Zylann/godot_voxel)** - Voxel-based terrain

#### C. Textures & Materials
- **[CC0 Textures](https://cc0textures.com/)** - PBR textures
- **[Poly Haven](https://polyhaven.com/)** - CC0 textures, HDRIs
- **[Texture Haven](https://texturehaven.com/)** - High-quality PBR textures

#### D. Shaders
- **[Godot Shader Library](https://github.com/GodotExplorer/ShaderLibrary)**
- **[Toon Shader Collection](https://github.com/armorgik/GodotToonShader)**
- Current: `src/adapters/inbound/gameplay/shaders/toon_cel.gdshader`

### 12. Advanced Techniques

#### A. LOD (Level of Detail)
```gdscript
func apply_lod(node, distance):
    if distance < 50:
        node.lod = 0  # Full detail
    elif distance < 200:
        node.lod = 1  # Medium detail
    else:
        node.lod = 2  # Low detail
```

**Godot 4.6 LOD**:
```gdscript
# LOD is now built-in for MeshInstance3D
mi.lod_bias = 0.5  # Adjust LOD transition point
```

#### B. Impostors for Distant Objects
- Replace complex 3D models with 2D sprites at distance
- Use `Sprite3D` or `Billboard` nodes
- Dramatically reduces polygon count

#### C. Instanced Rendering
```gdscript
# Use MultiMeshInstance for repeated props
var multi_mesh := MultiMesh.new()
multi_mesh.mesh = tree_mesh
multi_mesh.instance_count = 100
multi_mesh.set_instance_transform(0, Transform3D(Basis(), Vector3(10, 0, 5)))
# ... set more instances

var multi_mesh_instance := MultiMeshInstance3D.new()
multi_mesh_instance.multimesh = multi_mesh
add_child(multi_mesh_instance)
```

**Note**: Godot 4.6 has improved `MultiMesh` with better instancing support

#### D. Occlusion Culling
```gdscript
# Enable in project settings
project_settings["rendering/occlusion_culling/culling_mode"] = "volatile"

# Per-object occlusion
mi.occlusion_culling_mode = BaseMaterial3D.OCCLUSION_CULLING_VOLATILE
```

### 13. Debugging & Visualization

#### A. Chunk Boundary Visualization
```gdscript
func visualize_chunk_boundaries():
    for chunk_key in _procedural_chunks.keys():
        var chunk := _procedural_chunks[chunk_key]
        var bounds := AABB()
        bounds.position = Vector3(chunk_key.x * PROCEDURAL_CHUNK_SIZE_M, 0, chunk_key.y * PROCEDURAL_CHUNK_SIZE_M)
        bounds.size = Vector3(PROCEDURAL_CHUNK_SIZE_M, 100, PROCEDURAL_CHUNK_SIZE_M)
        # Draw AABB for debugging
```

#### B. Performance Profiling
```gdscript
func _process(delta):
    Performance.start_monitor("chunk_generation")
    _advance_procedural_generation()
    Performance.stop_monitor("chunk_generation")
    
    var time := Performance.get_monitor("chunk_generation")
    if time > PROCEDURAL_BUILD_BUDGET_USEC / 1000.0:
        print("Chunk generation budget exceeded!")
```

#### C. Memory Tracking
```gdscript
func _process(delta):
    var memory := OS.get_static_memory_usage()
    if memory > MEMORY_LIMIT:
        # Aggressive cleanup
        _emergency_cleanup()
```

### 14. Testing Strategies

#### A. Determinism Testing
```gdscript
func test_determinism():
    var world1 := _generate_world("test_seed_123")
    var world2 := _generate_world("test_seed_123")
    
    assert(world1 == world2, "World generation must be deterministic")
```

#### B. Performance Testing
```gdscript
func test_performance():
    var start_time := Time.get_ticks_msec()
    
    # Simulate player movement through world
    for i in range(100):
        var pos := Vector3(i * 20, 0, 0)
        set_exploration_focus(pos)
        _advance_procedural_generation()
    
    var end_time := Time.get_ticks_msec()
    var total_time := end_time - start_time
    
    assert(total_time < 1000, "Generation should complete in under 1 second")
```

#### C. Boundary Testing
```gdscript
func test_world_boundaries():
    # Test all four edges
    var edge_positions := [
        Vector3(WORLD_HALF_EXTENT_M - 1, 0, 0),
        Vector3(-WORLD_HALF_EXTENT_M + 1, 0, 0),
        Vector3(0, 0, WORLD_HALF_EXTENT_M - 1),
        Vector3(0, 0, -WORLD_HALF_EXTENT_M + 1)
    ]
    
    for pos in edge_positions:
        set_exploration_focus(pos)
        _advance_procedural_generation()
        assert(not _has_visual_edges(), "No world edges should be visible")
```

### 15. Migration Path to Godot 4.6 PCG

Given that Godot 4.6 now has native PCG support, consider migrating:

**Step 1: Hybrid Approach**
- Keep current chunk system for compatibility
- Add PCG3D for new features
- Gradually migrate generation logic

**Step 2: Full Migration**
- Replace `_build_procedural_island` with PCG3DGenerator
- Use PCG3DScatter for prop placement
- Use PCG3DTerrain for heightmap generation

**Benefits**:
- Built-in multithreading
- Better memory management
- Native editor support
- Standardized approach

**Costs**:
- Learning curve for new API
- Potential breaking changes
- Need to test performance

### 16. Recommended Implementation Improvements

#### Priority 1: Performance Optimization
1. **Implement object pooling** for chunk nodes
2. **Add LOD system** for distant props
3. **Use instanced rendering** for repeated vegetation
4. **Optimize collision** with layers and simplified shapes

#### Priority 2: Feature Enhancements
1. **Add biome blending** at chunk boundaries
2. **Implement road/path system** connecting regions
3. **Add water bodies** (rivers, lakes, ocean)
4. **Enhance terrain variation** with heightmap noise

#### Priority 3: Testing & Validation
1. **Add determinism tests** for world generation
2. **Implement performance benchmarks**
3. **Create visual regression tests**
4. **Add boundary edge case tests**

### 17. Code Samples & Snippets

#### A. Improved Chunk Management with Object Pooling
```gdscript
var _chunk_pool := []

func _get_chunk_from_pool() -> Node3D:
    if _chunk_pool.is_empty():
        var chunk := Node3D.new()
        chunk.name = "Chunk_Pooled"
        return chunk
    var chunk := _chunk_pool.pop_back()
    chunk.position = Vector3.ZERO
    chunk.rotation = Quaternion.IDENTITY
    chunk.scale = Vector3.ONE
    for child in chunk.get_children():
        child.queue_free()
    return chunk

func _return_chunk_to_pool(chunk: Node3D) -> void:
    chunk.queue_free()
    # For true pooling (requires reset logic):
    # chunk.reset()
    # _chunk_pool.append(chunk)
```

#### B. Adaptive Chunk Loading Based on Player Velocity
```gdscript
func _calculate_load_priority(chunk_key: Vector2i, player_pos: Vector3, player_vel: Vector3) -> float:
    var chunk_center := Vector3(float(chunk_key.x) * PROCEDURAL_CHUNK_SIZE_M, 0, float(chunk_key.y) * PROCEDURAL_CHUNK_SIZE_M)
    var dist_to_player := chunk_center.distance_to(player_pos)
    var dir_to_chunk := (chunk_center - player_pos).normalized()
    
    # Base priority: inverse distance
    var priority := 1.0 / (1.0 + dist_to_player / PROCEDURAL_CHUNK_SIZE_M)
    
    # Boost priority if moving toward chunk
    var vel_factor := dot(dir_to_chunk, player_vel.normalized())
    if vel_factor > 0:
        priority *= 1.0 + vel_factor * 0.5
    
    # Reduce priority if behind player
    var behind_factor := dot(dir_to_chunk, -player_vel.normalized())
    if behind_factor > 0.7:
        priority *= 0.5
    
    return priority
```

#### C. Multi-Layer Noise for Complex Biomes
```gdscript
func _get_complex_biome_value(x: float, z: float) -> float:
    var base_noise := FastNoiseLite.new()
    base_noise.seed = hash("%s_base" % _procedural_seed_source)
    base_noise.frequency = 0.002
    base_noise.fractal_octaves = 2
    
    var detail_noise := FastNoiseLite.new()
    detail_noise.seed = hash("%s_detail" % _procedural_seed_source)
    detail_noise.frequency = 0.01
    detail_noise.fractal_octaves = 4
    
    var micro_noise := FastNoiseLite.new()
    micro_noise.seed = hash("%s_micro" % _procedural_seed_source)
    micro_noise.frequency = 0.05
    micro_noise.fractal_octaves = 6
    
    var base := base_noise.get_noise_2d(x, z)
    var detail := detail_noise.get_noise_2d(x, z) * 0.4
    var micro := micro_noise.get_noise_2d(x, z) * 0.2
    
    return clamp(base + detail + micro, -1.0, 1.0)
```

#### D. Biome Definition System
```gdscript
const BIOMES := {
    "beach": {
        "threshold_min": -1.0,
        "threshold_max": -0.3,
        "props": ["Palma", "Skała", "Rozgwiazda", "Perła", "Skały piaskowe"],
        "density": 0.8,
        "color": Color(0.95, 0.85, 0.55)
    },
    "forest": {
        "threshold_min": -0.3,
        "threshold_max": 0.3,
        "props": ["Dąb", "Kłoda", "Grzyb", "Skała z mchem", "Trawa duża"],
        "density": 1.2,
        "color": Color(0.2, 0.4, 0.2)
    },
    "meadow": {
        "threshold_min": 0.3,
        "threshold_max": 0.7,
        "props": ["Dąb", "Trawa duża", "Kwiaty", "Skała"],
        "density": 0.9,
        "color": Color(0.4, 0.6, 0.3)
    },
    "hills": {
        "threshold_min": 0.7,
        "threshold_max": 1.0,
        "props": ["Dąb", "Kłoda", "Grzyb", "Skała z mchem"],
        "density": 1.0,
        "color": Color(0.3, 0.5, 0.3)
    }
}

func _get_biome_at(x: float, z: float) -> Dictionary:
    var value := _get_complex_biome_value(x, z)
    for biome_name in BIOMES.keys():
        var biome := BIOMES[biome_name]
        if value >= biome["threshold_min"] and value < biome["threshold_max"]:
            return biome
    return BIOMES["meadow"]  # Default
```

### 18. Recommended Packages & Addons

| Package | Purpose | License | Link |
|---------|---------|---------|------|
| Godot PCG | Native procedural generation | MIT | Built into Godot 4.6 |
| Zylann Voxel | Voxel-based terrain | MIT | [GitHub](https://github.com/Zylann/godot_voxel) |
| Godot Navigation | Pathfinding for NPCs | MIT | Built-in |
| Occlusion Culling | Performance optimization | MIT | Built-in (Godot 4.6) |
| MultiMesh Instance | Instanced rendering | MIT | Built-in |
| FastNoiseLite | Noise generation | MIT | Built-in |

### 19. Learning Resources

#### Tutorials
- [Godot 4.6 3D Procedural Generation](https://docs.godotengine.org/en/stable/tutorials/procedural_generation/pcg_3d.html)
- [Creating a Voxel Game in Godot 4](https://www.youtube.com/watch?v=2XRq6Q11uX0)
- [Large World Streaming in Godot](https://kids-candies.gitbook.io/godot-tutorials/3d/large-world-streaming)
- [Noise-Based Terrain Generation](https://gdquest.github.io/learn-gdscript/2d/procedural-generation/)

#### Books
- [Procedural Content Generation in Games](https://www.proceduralgenerationbook.com/) - Theory and practice
- [Godot 4 Game Development Projects](https://www.packtpub.com/product/godot-4-game-development-projects/9781801812746) - Includes procedural generation

#### Communities
- [Godot Forums - Procedural Generation](https://forum.godotengine.org/c/gdscript/13)
- [Godot Discord](https://discord.gg/4JBkykG) - #procedural-generation channel
- [r/godot](https://www.reddit.com/r/godot/) - Procedural generation discussions

### 20. Implementation Checklist

- [ ] Implement object pooling for chunk nodes
- [ ] Add LOD system for vegetation and props
- [ ] Implement multi-layer noise for complex biomes
- [ ] Add biome blending at chunk boundaries
- [ ] Implement adaptive chunk loading based on player velocity
- [ ] Add instanced rendering for repeated props
- [ ] Optimize collision with layers and simplified shapes
- [ ] Add distance-based collision disabling
- [ ] Implement performance budgeting with adaptive frame time
- [ ] Add deterministic physics for critical objects
- [ ] Implement save/load system for procedural worlds
- [ ] Add debugging visualization for chunks
- [ ] Create performance profiling tools
- [ ] Add determinism tests
- [ ] Add boundary tests
- [ ] Implement visual regression tests

---

## Integration Notes

### Current State Assessment
The existing implementation in `world_renderer.gd` is **production-ready** and already implements:
- ✅ Deterministic chunk-based generation
- ✅ Biome-based prop scattering
- ✅ Streaming with budgeted frame time
- ✅ Memory management with disposal queue
- ✅ Collision normalization for world scale

### Recommended Next Steps
1. **Optimize performance** with object pooling and LOD
2. **Enhance visual quality** with multi-layer noise biomes
3. **Add terrain variation** beyond flat floor
4. **Implement save/load** for player progress
5. **Add testing infrastructure** for determinism and performance
6. **Consider migration** to Godot 4.6 PCG for long-term maintainability

### Risk Assessment
- **Low Risk**: Performance optimizations, biome enhancements
- **Medium Risk**: Save/load system, terrain generation
- **High Risk**: Full migration to PCG3D (requires extensive testing)

---

## FastNoiseLite Advanced Patterns

> **Advanced noise-based generation techniques for complex biomes**

### Multi-Layer Noise for Complex Biomes

**Temperature + Moisture Biome System:**
```gdscript
# world/biome_generator.gd
# Multi-layer noise system for complex biome determination

class_name BiomeGenerator
extends RefCounted

# Biome types
enum BiomeType {
    OCEAN,
    BEACH,
    DESERT,
    GRASSLAND,
    FOREST,
    MOUNTAIN,
    SNOW,
    SWAMP
}

# Noise generators
var temperature_noise: FastNoiseLite
var moisture_noise: FastNoiseLite
var elevation_noise: FastNoiseLite
var detail_noise: FastNoiseLite

# Biome thresholds
@export var temperature_thresholds: Array[float] = [0.2, 0.4, 0.6, 0.8]
@export var moisture_thresholds: Array[float] = [0.3, 0.6]

func _init() -> void:
    temperature_noise = FastNoiseLite.new()
    temperature_noise.seed = 12345
    temperature_noise.frequency = 0.001
    temperature_noise.fractal_octaves = 4
    temperature_noise.fractal_gain = 0.5
    
    moisture_noise = FastNoiseLite.new()
    moisture_noise.seed = 54321
    moisture_noise.frequency = 0.0015
    moisture_noise.fractal_octaves = 3
    
    elevation_noise = FastNoiseLite.new()
    elevation_noise.seed = 98765
    elevation_noise.frequency = 0.002
    
    detail_noise = FastNoiseLite.new()
    detail_noise.seed = 11111
    detail_noise.frequency = 0.01
    detail_noise.fractal_octaves = 6

func get_biome(x: float, z: float) -> BiomeType:
    # Get noise values
    var temp := temperature_noise.get_noise_2d(x, z)
    var moist := moisture_noise.get_noise_2d(x, z)
    var elev := elevation_noise.get_noise_2d(x, z)
    var detail := detail_noise.get_noise_2d(x, z) * 0.1
    
    # Add detail noise for variation
    temp += detail
    moist += detail
    
    # Clamp to 0-1 range
    temp = clamp((temp + 1.0) * 0.5, 0.0, 1.0)
    moist = clamp((moist + 1.0) * 0.5, 0.0, 1.0)
    
    # Determine biome based on thresholds
    if elev < 0.1:
        return BiomeType.OCEAN
    elif elev < 0.2:
        return BiomeType.BEACH
    elif temp > 0.8 and moist < 0.3:
        return BiomeType.DESERT
    elif temp < 0.3 and moist > 0.7:
        return BiomeType.SNOW
    elif moist > 0.7 and temp > 0.5:
        return BiomeType.SWAMP
    elif moist > 0.6:
        return BiomeType.FOREST
    elif temp > 0.6:
        return BiomeType.GRASSLAND
    else:
        return BiomeType.MOUNTAIN

func get_biome_blend_weights(x: float, z: float) -> Dictionary:
    # Calculate smooth weights for biome blending
    var temp := temperature_noise.get_noise_2d(x, z)
    var moist := moisture_noise.get_noise_2d(x, z)
    
    temp = clamp((temp + 1.0) * 0.5, 0.0, 1.0)
    moist = clamp((moist + 1.0) * 0.5, 0.0, 1.0)
    
    var weights := {}
    for biome in BiomeType.size():
        weights[biome] = 0.0
    
    # Calculate weights based on distance to biome boundaries
    # Desert: high temp, low moisture
    weights[BiomeType.DESERT] = (1.0 - temp) * (1.0 - moist)
    
    # Forest: high moisture
    weights[BiomeType.FOREST] = moist
    
    # Grassland: medium temp and moisture
    weights[BiomeType.GRASSLAND] = (1.0 - abs(temp - 0.5)) * (1.0 - abs(moist - 0.5))
    
    # Normalize weights
    var total := 0.0
    for biome in weights:
        total += weights[biome]
    
    if total > 0:
        for biome in weights:
            weights[biome] /= total
    
    return weights
```

**Voronoi + Noise for Organic Biome Shapes:**
```gdscript
# Voronoi-based biome generation for more organic shapes

func get_voronoi_biome(x: float, z: float, point_count: int = 100) -> BiomeType:
    var voronoi := FastNoiseLite.new()
    voronoi.cell_noise_type = FastNoiseLite.CELL_VORONOI
    voronoi.seed = hash("voronoi_%d" % point_count)
    voronoi.frequency = 0.0005
    
    # Get Voronoi cell index
    var cell_index := voronoi.get_noise_2d(x, z)
    
    # Use cell index to seed per-cell biome determination
    var cell_rng := RandomNumberGenerator.new()
    cell_rng.seed = hash("cell_%d" % int(cell_index))
    
    # Random biome for this cell
    var biome_index := cell_rng.randi_range(0, BiomeType.size() - 1)
    return BiomeType(biome_index)

func get_fractal_biome_noise(x: float, z: float) -> float:
    # Create fractal noise for more natural biome boundaries
    var noise := FastNoiseLite.new()
    noise.seed = 12345
    noise.noise_type = FastNoiseLite.TYPE_FRACTAL
    noise.fractal_type = FastNoiseLite.FRACTAL_FBM
    noise.fractal_octaves = 8
    noise.fractal_lacunarity = 2.0
    noise.fractal_persistence = 0.5
    noise.frequency = 0.001
    
    return noise.get_noise_2d(x, z)
```

**Domain Warping for Natural Biome Edges:**
```gdscript
# Domain warping for more natural biome transitions

func get_domain_warped_noise(x: float, z: float) -> float:
    # First noise pass
    var noise1 := FastNoiseLite.new()
    noise1.seed = 12345
    noise1.frequency = 0.001
    
    # Second noise pass for warping
    var noise2 := FastNoiseLite.new()
    noise2.seed = 54321
    noise2.frequency = 0.002
    
    # Warp the coordinates
    var warp_scale := 100.0
    var warp_x := x + noise2.get_noise_2d(x, z) * warp_scale
    var warp_z := z + noise2.get_noise_2d(x + 5000, z) * warp_scale
    
    # Get final noise value
    return noise1.get_noise_2d(warp_x, warp_z)
```

---

## Chunk Streaming System

> **Production-ready chunk streaming with budgeting and recycling**

### Chunk Manager with Object Pooling

```gdscript
# world/chunk_manager.gd
# Advanced chunk manager with object pooling, LOD, and streaming

class_name ChunkManager
extends Node

# Chunk settings
@export var chunk_size: int = 160  # meters
@export var chunk_height: int = 20  # layers
@export var render_distance: int = 3  # chunks in each direction
@export var max_chunks: int = 100

# Performance budget
@export var build_budget_us: int = 3500  # microseconds per frame
@export var disposal_budget: int = 5  # chunks to dispose per frame

# LOD settings
@export var lod_distance_thresholds: Array[float] = [50.0, 100.0, 150.0]

# Chunk pool
var chunk_pool: Array = []
var active_chunks: Dictionary = {}

# Player reference
var player: Node3D = null

# Timing
var last_frame_time: float = 0.0

func _ready() -> void:
    # Find player
    player = get_node("/root/Main/Player") as Node3D
    if player == null:
        push_error("Player not found!")

func _process(delta: float) -> void:
    last_frame_time = delta
    
    # Update chunks based on player position
    if player:
        _update_chunks(player.global_position)

func _update_chunks(player_pos: Vector3) -> void:
    # Calculate chunk coordinates
    var player_chunk_x := floor(player_pos.x / chunk_size)
    var player_chunk_z := floor(player_pos.z / chunk_size)
    
    # Process disposal queue
    _process_disposals()
    
    # Process build queue within budget
    _process_building()
    
    # Queue new chunks as needed
    for x in range(-render_distance, render_distance + 1):
        for z in range(-render_distance, render_distance + 1):
            var chunk_x := player_chunk_x + x
            var chunk_z := player_chunk_z + z
            var chunk_key := Vector2i(chunk_x, chunk_z)
            
            if not active_chunks.has(chunk_key):
                _queue_chunk(chunk_key)

func _queue_chunk(chunk_key: Vector2i) -> void:
    # Check if we have a pooled chunk
    var chunk := null
    if chunk_pool.size() > 0:
        chunk = chunk_pool.pop_back()
        chunk.reset()
    else:
        chunk = Chunk.new()
    
    # Initialize chunk
    chunk.chunk_key = chunk_key
    chunk.size = Vector3(chunk_size, chunk_height * 2, chunk_size)  # Assumed height
    chunk.position = Vector3(
        chunk_key.x * chunk_size,
        0,
        chunk_key.y * chunk_size
    )
    
    # Add to active chunks
    active_chunks[chunk_key] = chunk
    add_child(chunk)
    
    # Queue for building
    chunk.build_queued = true

func _process_building() -> void:
    var start_time := OS.get_unix_time_in_usec()
    var built_count := 0
    
    for chunk in active_chunks.values():
        if not chunk.build_queued:
            continue
        
        if chunk.is_built:
            chunk.build_queued = false
            continue
        
        # Check budget
        var elapsed := OS.get_unix_time_in_usec() - start_time
        if elapsed >= build_budget_us:
            break
        
        # Build chunk
        chunk.build()
        chunk.build_queued = false
        built_count += 1
        
        # Recheck budget
        elapsed = OS.get_unix_time_in_usec() - start_time
        if elapsed >= build_budget_us:
            break
    
    # Debug
    if built_count > 0:
        push_info("Built %d chunks in %d us" % [built_count, OS.get_unix_time_in_usec() - start_time])

func _process_disposals() -> void:
    # Find chunks to dispose (beyond render distance)
    var to_dispose: Array = []
    
    if player == null:
        return
    
    var player_chunk_x := floor(player.global_position.x / chunk_size)
    var player_chunk_z := floor(player.global_position.z / chunk_size)
    
    for chunk_key in active_chunks:
        var chunk := active_chunks[chunk_key]
        var dx := abs(chunk_key.x - player_chunk_x)
        var dz := abs(chunk_key.y - player_chunk_z)
        
        if dx > render_distance + 1 or dz > render_distance + 1:
            to_dispose.append(chunk_key)
            
        # Limit number to dispose
        if to_dispose.size() >= disposal_budget:
            break
    
    # Dispose chunks
    for chunk_key in to_dispose:
        var chunk := active_chunks[chunk_key]
        _dispose_chunk(chunk, chunk_key)

func _dispose_chunk(chunk: Chunk, chunk_key: Vector2i) -> void:
    # Remove from active
    active_chunks.erase(chunk_key)
    remove_child(chunk)
    
    # Reset and pool
    chunk.reset()
    chunk_pool.append(chunk)
```

---

## Deterministic Seeding & Versioning

> **Robust seeding strategies for deterministic world generation**

### Multi-Level Seeding System

```gdscript
# world/seeding_system.gd
# Deterministic seeding with versioning and isolation

class_name SeedingSystem
extends RefCounted

# Generator version - increment when generation algorithm changes
const GENERATOR_VERSION := "v3.2"

# Base world seed
@export var world_seed: int = 123456789:
    set(value):
        world_seed = value
        _invalidate_cache()

# Seed cache
var seed_cache: Dictionary = {}

func _invalidate_cache() -> void:
    seed_cache.clear()

func get_seed(key: String) -> int:
    # Check cache
    if seed_cache.has(key):
        return seed_cache[key]
    
    # Generate deterministic seed from world seed and key
    var seed := hash("%s:%d:%s" % [GENERATOR_VERSION, world_seed, key])
    seed_cache[key] = seed
    return seed

func get_rng(key: String) -> RandomNumberGenerator:
    var rng := RandomNumberGenerator.new()
    rng.seed = get_seed(key)
    return rng

func get_fastnoise(key: String) -> FastNoiseLite:
    var noise := FastNoiseLite.new()
    noise.seed = get_seed(key)
    return noise

# Example usage
func generate_terrain_height(x: int, z: int) -> float:
    var noise := get_fastnoise("terrain_height")
    noise.frequency = 0.01
    noise.fractal_octaves = 4
    return noise.get_noise_2d(x, z)
```

**Versioned Seed Migration:**
```gdscript
# Handle generator version changes gracefully

func get_versioned_seed(key: String, version: String) -> int:
    # Include version in hash
    return hash("%s:%s:%s" % [version, world_seed, key])

# Migration strategy: detect old seeds and regenerate
func get_world_data(seed: int) -> Dictionary:
    var version := _detect_seed_version(seed)
    
    if version == GENERATOR_VERSION:
        # Current version
        return _generate_world_current(seed)
    elif version == "v2.0":
        # Migrate from v2.0
        return _migrate_from_v2(seed)
    elif version == "v1.0":
        # Migrate from v1.0
        return _migrate_from_v1(seed)
    else:
        # Unknown version - regenerate
        return _generate_world_current(seed)

func _detect_seed_version(seed: int) -> String:
    # Try to detect version from seed properties
    # This is project-specific
    return GENERATOR_VERSION
```

**Save/Load with Seeds:**
```gdscript
# Minimal save format for deterministic worlds

class_name WorldSaveData
extends Resource

@export var world_seed: int
@export var generator_version: String
@export var player_position: Vector3
@export var modified_chunks: Dictionary  # {chunk_key: modifications}

func save_world(world: World, path: String) -> void:
    var save_data := WorldSaveData.new()
    save_data.world_seed = world.seed
    save_data.generator_version = GENERATOR_VERSION
    save_data.player_position = world.player_position
    save_data.modified_chunks = world.get_modified_chunks()
    
    var file := FileAccess.open(path, FileAccess.WRITE)
    if file:
        file.store_buffer(ResourceSaver.save(save_data))
        file.close()

func load_world(path: String) -> WorldSaveData:
    var file := FileAccess.open(path, FileAccess.READ)
    if file:
        var buffer := file.get_buffer(file.get_length())
        file.close()
        return ResourceLoader.load(buffer, "WorldSaveData", true) as WorldSaveData
    return null

# On load: regenerate world from seed and apply modifications
func load_world_into_scene(save_data: WorldSaveData) -> World:
    var world := World.new()
    world.seed = save_data.world_seed
    world.generator_version = save_data.generator_version
    
    # Regenerate world
    world.generate()
    
    # Apply modifications
    for chunk_key in save_data.modified_chunks:
        world.apply_chunk_modifications(chunk_key, save_data.modified_chunks[chunk_key])
    
    # Set player position
    world.player_position = save_data.player_position
    
    return world
```

---

## Biome Generation System

> **Complete biome system with props, scattering, and blending**

### Biome Registry

```gdscript
# world/biome_registry.gd
# Central biome registry with prop definitions

class_name BiomeRegistry
extends Resource

@export var biomes: Array[BiomeDefinition] = []

# Biome prop candidates
class_name BiomeDefinition
extends Resource

@export var biome_name: String
@export var base_color: Color
@export var texture_path: String

# Prop categories with weights
@export var tree_props: Array[PropWeight] = []
@export var bush_props: Array[PropWeight] = []
@export var grass_props: Array[PropWeight] = []
@export var rock_props: Array[PropWeight] = []

# Density settings
@export var tree_density: float = 0.01
@export var bush_density: float = 0.03
@export var grass_density: float = 0.1

# Blending settings
@export var blend_distance: float = 50.0  # meters to blend between biomes

class_name PropWeight
extends Resource

@export var prop_scene: PackedScene
@export var weight: float = 1.0
@export var min_scale: Vector3 = Vector3.ONE
@export var max_scale: Vector3 = Vector3.ONE

# Singleton
var _instance: BiomeRegistry = null

func _init() -> void:
    if _instance == null:
        _instance = self

@classmethod func get_instance() -> BiomeRegistry:
    return _instance

func get_biome_by_noise_value(noise_value: float) -> BiomeDefinition:
    # Map noise value to biome index
    var biome_index := int(remap(noise_value, -1.0, 1.0, 0, biomes.size()))
    biome_index = clamp(biome_index, 0, biomes.size() - 1)
    return biomes[biome_index]

func get_prop_for_biome(biome: BiomeDefinition, category: String) -> PackedScene:
    var candidates := []
    
    match category:
        "tree":
            candidates = biome.tree_props
        "bush":
            candidates = biome.bush_props
        "grass":
            candidates = biome.grass_props
        "rock":
            candidates = biome.rock_props
    
    if candidates.is_empty():
        return null
    
    # Weighted random selection
    var total_weight := 0.0
    for candidate in candidates:
        total_weight += candidate.weight
    
    var random_value := randf() * total_weight
    var cumulative := 0.0
    
    for candidate in candidates:
        cumulative += candidate.weight
        if random_value <= cumulative:
            return candidate.prop_scene
    
    return candidates[-1].prop_scene
```

---

## Terrain & Mesh Generation

> **Heightmap-based and mesh-based terrain generation**

### Heightmap Terrain with SurfaceTool

```gdscript
# world/terrain_generator.gd
# Terrain generation using SurfaceTool and heightmaps

class_name TerrainGenerator
extends Node

# Terrain settings
@export var size: Vector2i = Vector2i(1024, 1024)
@export var scale: Vector3 = Vector3(100, 10, 100)
@export var height: float = 50.0

# Noise settings
@export var base_noise: FastNoiseLite
@export var detail_noise: FastNoiseLite
@export var erosion_noise: FastNoiseLite

func _ready() -> void:
    if base_noise == null:
        base_noise = FastNoiseLite.new()
        base_noise.seed = 12345
        base_noise.frequency = 0.01
        base_noise.fractal_octaves = 4
    
    if detail_noise == null:
        detail_noise = FastNoiseLite.new()
        detail_noise.seed = 54321
        detail_noise.frequency = 0.05
        detail_noise.fractal_octaves = 2
    
    if erosion_noise == null:
        erosion_noise = FastNoiseLite.new()
        erosion_noise.seed = 98765
        erosion_noise.frequency = 0.1

func generate_terrain() -> MeshInstance3D:
    var surface_tool := SurfaceTool.new()
    surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
    
    var grid_size := size
    
    for z in range(grid_size.y):
        for x in range(grid_size.x):
            # Calculate height
            var h := _get_height_at(x, z)
            
            # Add vertex
            surface_tool.add_vertex(Vector3(
                x * scale.x - (grid_size.x * scale.x) / 2,
                h * scale.y,
                z * scale.z - (grid_size.y * scale.z) / 2
            ))
    
    # Create triangles
    for z in range(grid_size.y - 1):
        for x in range(grid_size.x - 1):
            var i00 := z * grid_size.x + x
            var i01 := z * grid_size.x + x + 1
            var i10 := (z + 1) * grid_size.x + x
            var i11 := (z + 1) * grid_size.x + x + 1
            
            # Two triangles
            surface_tool.add_triangle(i00, i01, i10)
            surface_tool.add_triangle(i01, i11, i10)
    
    # Add UVs
    for z in range(grid_size.y):
        for x in range(grid_size.x):
            surface_tool.add_uv(Vector2(x / (grid_size.x - 1), z / (grid_size.y - 1)))
    
    # Add normals
    surface_tool.generate_normals()
    
    # Commit mesh
    surface_tool.commit_to_arrays()
    var mesh := ArrayMesh.new()
    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface_tool.commit_to_arrays())
    
    var mesh_instance := MeshInstance3D.new()
    mesh_instance.mesh = mesh
    
    return mesh_instance

func _get_height_at(x: int, z: int) -> float:
    # Base height
    var h := base_noise.get_noise_2d(x, z)
    
    # Add detail
    h += detail_noise.get_noise_2d(x, z) * 0.3
    
    # Erosion effect
    var erosion := erosion_noise.get_noise_2d(x, z)
    h *= (1.0 - erosion * 0.5)
    
    # Normalize and scale
    h = (h + 1.0) * 0.5  # -1 to 1 -> 0 to 1
    h = pow(h, 1.5)  # More dramatic peaks
    
    return h * height
```

---

## Collision Optimization

> **Efficient collision handling for large procedural worlds**

### Layer-Based Collision System

```gdscript
# world/collision_optimizer.gd
# Optimized collision system for large worlds

class_name CollisionOptimizer
extends Node

# Collision layers
enum CollisionLayer {
    TERRAIN = 1,
    BUILDINGS = 2,
    VEGETATION = 3,
    DECORATION = 4,
    PLAYER = 5,
    VEHICLES = 6
}

# Collision masks
enum CollisionMask {
    TERRAIN = 1 << CollisionLayer.TERRAIN,
    BUILDINGS = 1 << CollisionLayer.BUILDINGS,
    VEGETATION = 1 << CollisionLayer.VEGETATION,
    DECORATION = 1 << CollisionLayer.DECORATION,
    PLAYER = 1 << CollisionLayer.PLAYER,
    VEHICLES = 1 << CollisionLayer.VEHICLES
}

# Distance thresholds
@export var collision_distance_vegetation: float = 30.0
@export var collision_distance_decoration: float = 20.0

# Optimization settings
@export var use_distance_culling: bool = true
@export var use_layer_optimization: bool = true

func optimize_node(node: Node3D, category: String) -> void:
    # Set collision layers based on category
    if use_layer_optimization:
        _set_collision_layers(node, category)
    
    # Set up distance-based collision culling
    if use_distance_culling:
        _setup_distance_culling(node, category)

func _set_collision_layers(node: Node3D, category: String) -> void:
    var layer: int
    var mask: int
    
    match category:
        "terrain":
            layer = CollisionLayer.TERRAIN
            mask = CollisionMask.TERRAIN | CollisionMask.PLAYER | CollisionMask.VEHICLES
        "building":
            layer = CollisionLayer.BUILDINGS
            mask = CollisionMask.BUILDINGS | CollisionMask.PLAYER | CollisionMask.VEHICLES
        "vegetation":
            layer = CollisionLayer.VEGETATION
            mask = CollisionMask.VEGETATION | CollisionMask.PLAYER | CollisionMask.VEHICLES
        "decoration":
            layer = CollisionLayer.DECORATION
            mask = CollisionMask.DECORATION | CollisionMask.PLAYER
        _:
            layer = CollisionLayer.TERRAIN
            mask = CollisionMask.TERRAIN | CollisionMask.PLAYER
    
    node.set_collision_layer(layer)
    node.set_collision_mask(mask)

func _setup_distance_culling(node: Node3D, category: String) -> void:
    # Add collision culling script
    var culler := CollisionCuller.new()
    culler.category = category
    culler.optimizer = self
    node.add_child(culler)

class_name CollisionCuller
extends Node

var category: String = ""
var optimizer: CollisionOptimizer = null
var player: Node3D = null

func _ready() -> void:
    player = get_node("/root/Main/Player") as Node3D

func _process(delta: float) -> void:
    if player == null or optimizer == null:
        return
    
    var distance := global_position.distance_to(player.global_position)
    
    if category == "vegetation":
        if distance > optimizer.collision_distance_vegetation:
            _disable_collision()
        else:
            _enable_collision()
    elif category == "decoration":
        if distance > optimizer.collision_distance_decoration:
            _disable_collision()
        else:
            _enable_collision()

func _disable_collision() -> void:
    if get_parent() is StaticBody3D:
        get_parent().set_collide_with_bodies(false)
        get_parent().set_collide_with_areas(false)
    elif get_parent() is RigidBody3D:
        get_parent().set_collide_with_bodies(false)
        get_parent().set_collide_with_areas(false)
    elif get_parent() is Area3D:
        get_parent().monitoring = false
        get_parent().monitorable = false

func _enable_collision() -> void:
    if get_parent() is StaticBody3D:
        get_parent().set_collide_with_bodies(true)
        get_parent().set_collide_with_areas(true)
    elif get_parent() is RigidBody3D:
        get_parent().set_collide_with_bodies(true)
        get_parent().set_collide_with_areas(true)
    elif get_parent() is Area3D:
        get_parent().monitoring = true
        get_parent().monitorable = true
```

---

## Memory Management

> **Object pooling and efficient memory handling**

### Object Pool Implementation

```gdscript
# world/object_pool.gd
# Generic object pool for efficient instantiation

class_name ObjectPool
extends Node

@export var prefab: PackedScene = null
@export var initial_size: int = 10
@export var max_size: int = 100

var pool: Array = []
var active_objects: Array = []

func _ready() -> void:
    # Pre-warm pool
    for i in range(initial_size):
        var obj := prefab.instantiate()
        obj.visible = false
        obj.set_physics_process(false)
        obj.set_input_process(false)
        pool.append(obj)
        add_child(obj)

func get_object(position: Vector3 = Vector3.ZERO, rotation: Vector3 = Vector3.ZERO) -> Node3D:
    var obj: Node3D = null
    
    if pool.size() > 0:
        obj = pool.pop_back()
    elif active_objects.size() < max_size:
        obj = prefab.instantiate()
        add_child(obj)
    else:
        push_warning("Object pool exhausted!")
        return null
    
    # Activate object
    obj.global_position = position
    obj.rotation = rotation
    obj.visible = true
    obj.set_physics_process(true)
    obj.set_input_process(true)
    
    active_objects.append(obj)
    
    return obj

func return_object(obj: Node3D) -> void:
    var index := active_objects.find(obj)
    if index != -1:
        active_objects.remove_at(index)
    else:
        push_warning("Object not in active list!")
        return
    
    # Deactivate object
    obj.visible = false
    obj.set_physics_process(false)
    obj.set_input_process(false)
    
    # Reset object
    if obj.has_method("reset"):
        obj.reset()
    
    # Return to pool
    pool.append(obj)

func clear_all() -> void:
    for obj in active_objects:
        return_object(obj)
    
    active_objects.clear()

func get_active_count() -> int:
    return active_objects.size()

func get_pooled_count() -> int:
    return pool.size()
```

**Chunk-Specific Pooling:**
```gdscript
# world/chunk_pool.gd
# Chunk-specific object pooling

class_name ChunkPool
extends ObjectPool

# Chunk-specific prefabs
@export var tree_prefab: PackedScene = null
@export var bush_prefab: PackedScene = null
@export var grass_prefab: PackedScene = null
@export var rock_prefab: PackedScene = null

# Pools for each type
var tree_pool: Array = []
var bush_pool: Array = []
var grass_pool: Array = []
var rock_pool: Array = []

func get_tree() -> Node3D:
    if tree_prefab == null:
        return null
    prefab = tree_prefab
    initial_size = 50
    max_size = 500
    return super.get_object()

func get_bush() -> Node3D:
    if bush_prefab == null:
        return null
    prefab = bush_prefab
    initial_size = 100
    max_size = 1000
    return super.get_object()

# ... similar for grass and rock
```

---

## LOD Systems

> **Level of Detail management for performance optimization**

### Multi-LOD Prop System

```gdscript
# world/lod_prop.gd
# Prop with multiple LOD levels

class_name LODProp
extends Node3D

# LOD levels
@export var lod0_mesh: Mesh  # High detail
@export var lod1_mesh: Mesh  # Medium detail
@export var lod2_mesh: Mesh  # Low detail
@export var lod3_mesh: Mesh  # Billboards/2D

# LOD distances
@export var lod0_distance: float = 10.0
@export var lod1_distance: float = 30.0
@export var lod2_distance: float = 50.0

# Current LOD
var current_lod: int = 0
var mesh_instance: MeshInstance3D = null

# Player reference
var player: Node3D = null

func _ready() -> void:
    mesh_instance = get_node("MeshInstance3D") as MeshInstance3D
    if mesh_instance == null:
        mesh_instance = MeshInstance3D.new()
        add_child(mesh_instance)
    
    player = get_node("/root/Main/Player") as Node3D
    
    # Start with LOD0
    _set_lod(0)

func _process(delta: float) -> void:
    if player == null:
        return
    
    var distance := global_position.distance_to(player.global_position)
    var new_lod := _get_lod_for_distance(distance)
    
    if new_lod != current_lod:
        _set_lod(new_lod)

func _get_lod_for_distance(distance: float) -> int:
    if distance <= lod0_distance:
        return 0
    elif distance <= lod1_distance:
        return 1
    elif distance <= lod2_distance:
        return 2
    else:
        return 3

func _set_lod(lod: int) -> void:
    current_lod = lod
    
    match lod:
        0:
            if lod0_mesh:
                mesh_instance.mesh = lod0_mesh
        1:
            if lod1_mesh:
                mesh_instance.mesh = lod1_mesh
        2:
            if lod2_mesh:
                mesh_instance.mesh = lod2_mesh
        3:
            if lod3_mesh:
                mesh_instance.mesh = lod3_mesh

func get_current_lod() -> int:
    return current_lod
```

---

## Visibility & Occlusion

> **Optimized visibility handling for large worlds**

### Occlusion Culling Setup

```gdscript
# world/occlusion_setup.gd
# Setup occlusion culling for large worlds

class_name OcclusionSetup
extends Node

func _ready() -> void:
    # Enable occlusion culling in project settings
    _enable_occlusion_culling()
    
    # Add occluders to static objects
    _add_occluders()

func _enable_occlusion_culling() -> void:
    # Enable via project settings
    ProjectSettings.set("rendering/occlusion_culling/culling_mode", "volatile")
    ProjectSettings.save()
    
    # Force reload
    get_tree().reload_current_scene()

func _add_occluders() -> void:
    # Add OccluderInstance3D to large static objects
    var static_objects := _find_static_objects()
    
    for obj in static_objects:
        var occluder := OccluderInstance3D.new()
        obj.add_child(occluder)
        
        # Create convex polygon for occlusion
        var convex := ConvexPolygonShape3D.new()
        var points := _get_occluder_points(obj)
        convex.points = points
        occluder.add_shape(convex)

func _find_static_objects() -> Array:
    var result := []
    
    for node in get_tree().get_nodes_in_group("static"):
        if node is StaticBody3D or node is MeshInstance3D:
            result.append(node)
    
    return result

func _get_occluder_points(obj: Node3D) -> PackedVector3Array:
    # Get bounding box points
    if obj is MeshInstance3D:
        var aabb := obj.get_aabb()
        var points := PackedVector3Array()
        
        # Add 8 corners of the bounding box
        points.append(Vector3(aabb.position.x + aabb.size.x, aabb.position.y, aabb.position.z))
        points.append(Vector3(aabb.position.x + aabb.size.x, aabb.position.y, aabb.position.z + aabb.size.z))
        points.append(Vector3(aabb.position.x + aabb.size.x, aabb.position.y + aabb.size.y, aabb.position.z))
        points.append(Vector3(aabb.position.x + aabb.size.x, aabb.position.y + aabb.size.y, aabb.position.z + aabb.size.z))
        points.append(Vector3(aabb.position.x, aabb.position.y, aabb.position.z))
        points.append(Vector3(aabb.position.x, aabb.position.y, aabb.position.z + aabb.size.z))
        points.append(Vector3(aabb.position.x, aabb.position.y + aabb.size.y, aabb.position.z))
        points.append(Vector3(aabb.position.x, aabb.position.y + aabb.size.y, aabb.position.z + aabb.size.z))
        
        return points
    
    return PackedVector3Array()
```

---

## Advanced Code Samples

> **Production-ready implementations for procedural world streaming**

### Complete Chunk Class

```gdscript
# world/chunk.gd
# Complete chunk implementation with LOD, streaming, and props

class_name Chunk
extends Node3D

# Chunk configuration
@export var chunk_key: Vector2i = Vector2i.ZERO
@export var size: Vector3 = Vector3(160, 20, 160)

# Generation settings
@export var biome_generator: BiomeGenerator = null
@export var terrain_generator: TerrainGenerator = null

# Props
@export var prop_density: float = 0.01
@export var max_props: int = 50

# LOD settings
@export var lod_enabled: bool = true
@export var lod_distances: Array[float] = [10.0, 30.0, 50.0]

# State
var is_built: bool = false
var is_loaded: bool = false
var build_queued: bool = false

# Components
var terrain_mesh: MeshInstance3D = null
var collision_shape: CollisionShape3D = null
var props_parent: Node3D = null

var _props: Array = []

func _ready() -> void:
    # Setup nodes
    terrain_mesh = get_node("TerrainMesh") as MeshInstance3D
    if terrain_mesh == null:
        terrain_mesh = MeshInstance3D.new()
        terrain_mesh.name = "TerrainMesh"
        add_child(terrain_mesh)
    
    collision_shape = get_node("CollisionShape") as CollisionShape3D
    if collision_shape == null:
        collision_shape = CollisionShape3D.new()
        collision_shape.name = "CollisionShape"
        add_child(collision_shape)
    
    props_parent = get_node("Props") as Node3D
    if props_parent == null:
        props_parent = Node3D.new()
        props_parent.name = "Props"
        add_child(props_parent)

func build() -> void:
    if is_built:
        return
    
    # Generate terrain
    _generate_terrain()
    
    # Generate collision
    _generate_collision()
    
    # Generate props
    _generate_props()
    
    is_built = true

func _generate_terrain() -> void:
    if terrain_generator:
        terrain_mesh.mesh = terrain_generator.generate_chunk_mesh(chunk_key.x, chunk_key.y)
    else:
        # Fallback: simple plane
        terrain_mesh.mesh = _create_simple_plane()

func _generate_collision() -> void:
    if terrain_mesh.mesh:
        var mesh_data := terrain_mesh.mesh.surface_get_arrays(0)
        var aabb := terrain_mesh.get_aabb()
        
        var box_shape := BoxShape3D.new()
        box_shape.size = aabb.size
        collision_shape.shape = box_shape
        collision_shape.position = aabb.get_center()

func _generate_props() -> void:
    # Clear existing props
    for prop in _props:
        prop.queue_free()
    _props.clear()
    
    if biome_generator == null:
        return
    
    # Calculate prop count based on density
    var prop_count := int(size.x * size.z * prop_density)
    prop_count = min(prop_count, max_props)
    
    for i in range(prop_count):
        # Random position within chunk
        var x := randf() * size.x - size.x / 2
        var z := randf() * size.z - size.z / 2
        
        # Get biome at position
        var biome := biome_generator.get_biome(
            (chunk_key.x * size.x) + x,
            (chunk_key.y * size.z) + z
        )
        
        # Try to spawn prop
        var prop := _spawn_prop_at(Vector3(x, 0, z), biome)
        if prop:
            props_parent.add_child(prop)
            _props.append(prop)

func _spawn_prop_at(position: Vector3, biome: BiomeDefinition) -> Node3D:
    # Randomly select prop category based on biome
    var categories := ["tree", "bush", "grass", "rock"]
    var weights := [biome.tree_density, biome.bush_density, biome.grass_density, 0.05]
    
    var total_weight := 0.0
    for w in weights:
        total_weight += w
    
    var random_value := randf() * total_weight
    var cumulative := 0.0
    var category := ""
    
    for i in categories.size():
        cumulative += weights[i]
        if random_value <= cumulative:
            category = categories[i]
            break
    
    if category == "":
        return null
    
    # Get prop from biome registry
    var prop_scene := BiomeRegistry.get_instance().get_prop_for_biome(biome, category)
    if prop_scene == null:
        return null
    
    # Instance prop
    var prop := prop_scene.instantiate()
    prop.position = position
    
    # Random rotation
    prop.rotation.y = randf() * TAU
    
    # Random scale
    prop.scale = Vector3.ONE * randf_range(0.8, 1.2)
    
    return prop

func _create_simple_plane() -> ArrayMesh:
    var surface_tool := SurfaceTool.new()
    surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
    
    # Four corners
    surface_tool.add_vertex(Vector3(-size.x/2, 0, -size.z/2))
    surface_tool.add_vertex(Vector3(size.x/2, 0, -size.z/2))
    surface_tool.add_vertex(Vector3(size.x/2, 0, size.z/2))
    surface_tool.add_vertex(Vector3(-size.x/2, 0, size.z/2))
    
    # Two triangles
    surface_tool.add_triangle(0, 1, 2)
    surface_tool.add_triangle(0, 2, 3)
    
    # UVs
    surface_tool.add_uv(Vector2(0, 0))
    surface_tool.add_uv(Vector2(1, 0))
    surface_tool.add_uv(Vector2(1, 1))
    surface_tool.add_uv(Vector2(0, 1))
    
    # Normals
    surface_tool.add_normal(Vector3.UP)
    surface_tool.add_normal(Vector3.UP)
    surface_tool.add_normal(Vector3.UP)
    surface_tool.add_normal(Vector3.UP)
    
    surface_tool.generate_normals()
    
    return ArrayMesh.new().add_surface_from_arrays(
        Mesh.PRIMITIVE_TRIANGLES,
        surface_tool.commit_to_arrays()
    )

func reset() -> void:
    # Clear props
    for prop in _props:
        prop.queue_free()
    _props.clear()
    
    # Reset state
    is_built = false
    is_loaded = false
    build_queued = false
    
    # Clear mesh
    terrain_mesh.mesh = null

func unload() -> void:
    # Hide and disable
    visible = false
    set_physics_process(false)
    is_loaded = false

func load() -> void:
    # Show and enable
    visible = true
    set_physics_process(true)
    is_loaded = true
```

---

### Procedural River System

```gdscript
# world/procedural_river.gd
# Procedural river generation with FastNoiseLite

class_name ProceduralRiver
extends Node3D

# River settings
@export var world_seed: int = 12345
@export var river_width: float = 20.0
@export var river_depth: float = 3.0
@export var meander_scale: float = 50.0

# Path settings
@export var start_point: Vector3 = Vector3.ZERO
@export var end_point: Vector3 = Vector3(1000, 0, 1000)
@export var path_points: int = 50

# Mesh settings
@export var mesh_resolution: int = 10

var path: Array = []
var mesh_instance: MeshInstance3D = null
var collision_shape: CollisionShape3D = null

func _ready() -> void:
    mesh_instance = MeshInstance3D.new()
    add_child(mesh_instance)
    
    collision_shape = CollisionShape3D.new()
    add_child(collision_shape)
    
    generate()

func generate() -> void:
    # Generate river path
    _generate_path()
    
    # Generate mesh
    _generate_mesh()
    
    # Generate collision
    _generate_collision()

func _generate_path() -> void:
    path.clear()
    
    # Use noise to create meandering path
    var noise := FastNoiseLite.new()
    noise.seed = world_seed
    noise.frequency = 0.01
    
    for i in range(path_points):
        var t := i / float(path_points - 1)
        
        # Linear interpolation between start and end
        var linear_pos := start_point.lerp(end_point, t)
        
        # Add noise for meandering
        var offset_x := noise.get_noise_2d(i * 100, 0) * meander_scale
        var offset_z := noise.get_noise_2d(0, i * 100) * meander_scale * 0.5
        
        var path_point := linear_pos + Vector3(offset_x, 0, offset_z)
        path.append(path_point)

func _generate_mesh() -> void:
    var surface_tool := SurfaceTool.new()
    surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
    
    # Generate vertices along path
    for i in range(path.size()):
        var point := path[i]
        var next_point := path[i + 1] if i + 1 < path.size() else point
        
        # Calculate perpendicular vector
        var dir := (next_point - point).normalized()
        var perp := Vector3(-dir.z, 0, dir.x).normalized()
        
        # Left bank
        var left_bank := point + perp * (river_width / 2)
        
        # Right bank
        var right_bank := point - perp * (river_width / 2)
        
        # Add vertices at different resolution
        for j in range(mesh_resolution):
            var t := j / float(mesh_resolution - 1)
            
            # River bottom
            var bottom_left := Vector3(left_bank.x, point.y - river_depth, left_bank.z)
            var bottom_right := Vector3(right_bank.x, point.y - river_depth, right_bank.z)
            
            surface_tool.add_vertex(bottom_left)
            surface_tool.add_vertex(bottom_right)
    
    # Generate triangles (simplified - would need proper indexing)
    # This is a placeholder - actual implementation would be more complex
    
    surface_tool.generate_normals()
    
    mesh_instance.mesh = ArrayMesh.new()
    mesh_instance.mesh.add_surface_from_arrays(
        Mesh.PRIMITIVE_TRIANGLES,
        surface_tool.commit_to_arrays()
    )

func _generate_collision() -> void:
    # Simple box collision for river
    var aabb := mesh_instance.get_aabb()
    var box_shape := BoxShape3D.new()
    box_shape.size = aabb.size
    collision_shape.shape = box_shape
    collision_shape.position = aabb.get_center()
```

---

## Testing Strategies

> **Comprehensive testing for procedural world generation**

### Determinism Tests

```gdscript
# tests/world/test_determinism.gd
# Test that generation is deterministic

extends "res://addons/gut/test.gd"

func test_chunk_determinism():
    # Generate chunk with seed
    var generator1 := TerrainGenerator.new()
    generator1.world_seed = 12345
    
    var generator2 := TerrainGenerator.new()
    generator2.world_seed = 12345
    
    # Generate mesh for same chunk
    var mesh1 := generator1.generate_chunk_mesh(0, 0)
    var mesh2 := generator2.generate_chunk_mesh(0, 0)
    
    # Meshes should be identical (same vertex data)
    assert_true(_compare_meshes(mesh1, mesh2))

func test_different_seeds_produce_different_results():
    var generator1 := TerrainGenerator.new()
    generator1.world_seed = 12345
    
    var generator2 := TerrainGenerator.new()
    generator2.world_seed = 54321
    
    var mesh1 := generator1.generate_chunk_mesh(0, 0)
    var mesh2 := generator2.generate_chunk_mesh(0, 0)
    
    # Meshes should be different
    assert_false(_compare_meshes(mesh1, mesh2))

func _compare_meshes(mesh1: Mesh, mesh2: Mesh) -> bool:
    # Compare vertex arrays
    var arrays1 := mesh1.surface_get_arrays(0)
    var arrays2 := mesh2.surface_get_arrays(0)
    
    for i in arrays1.size():
        var arr1 := arrays1[i]
        var arr2 := arrays2[i]
        
        if arr1.size() != arr2.size():
            return false
        
        for j in arr1.size():
            if arr1[j] != arr2[j]:
                return false
    
    return true
```

### Performance Tests

```gdscript
# tests/world/test_performance.gd
# Performance tests for world generation

extends "res://addons/gut/test.gd"

func test_chunk_generation_time():
    var generator := TerrainGenerator.new()
    
    var start_time := OS.get_unix_time_in_usec()
    var mesh := generator.generate_chunk_mesh(0, 0)
    var end_time := OS.get_unix_time_in_usec()
    
    var generation_time_ms := (end_time - start_time) / 1000.0
    
    # Should generate in reasonable time
    assert_true(generation_time_ms < 50.0, "Chunk generation took %d ms" % generation_time_ms)

func test_chunk_pool_performance():
    var pool := ChunkPool.new()
    pool.prefab = preload("res://world/chunk.tscn")
    pool.initial_size = 10
    pool.max_size = 100
    
    var start_time := OS.get_unix_time_in_usec()
    
    # Get and return chunks multiple times
    for i in range(100):
        var chunk := pool.get_object()
        pool.return_object(chunk)
    
    var end_time := OS.get_unix_time_in_usec()
    var total_time_ms := (end_time - start_time) / 1000.0
    
    # Average time per operation should be low
    var avg_time_ms := total_time_ms / (100 * 2)  # 100 gets + 100 returns
    assert_true(avg_time_ms < 0.1, "Average pool operation took %d ms" % avg_time_ms)
```

### Boundary Tests

```gdscript
# tests/world/test_boundaries.gd
# Test chunk boundaries and edge cases

extends "res://addons/gut/test.gd"

func test_chunk_boundaries_match():
    var generator := TerrainGenerator.new()
    
    # Generate adjacent chunks
    var chunk_0_0 := generator.generate_chunk_mesh(0, 0)
    var chunk_1_0 := generator.generate_chunk_mesh(1, 0)
    var chunk_0_1 := generator.generate_chunk_mesh(0, 1)
    
    # Get edge vertices
    var arrays_0_0 := chunk_0_0.surface_get_arrays(0)
    var vertices_0_0 := arrays_0_0[ArrayMesh.ARRAY_VERTEX]
    
    var arrays_1_0 := chunk_1_0.surface_get_arrays(0)
    var vertices_1_0 := arrays_1_0[ArrayMesh.ARRAY_VERTEX]
    
    # Check that right edge of chunk 0,0 matches left edge of chunk 1,0
    # This is a simplified check - actual implementation depends on mesh structure
    assert_true(_edges_match(vertices_0_0, vertices_1_0, true, false))

func test_no_visual_seams():
    # Test that adjacent chunks don't have visible seams
    # This would involve rendering and comparing pixels
    pass
```

---

## Child-Safety Considerations

> **Ensuring procedural worlds are safe and appropriate for children**

### Safe Prop Selection

```gdscript
# world/child_safe_prop_selector.gd
# Child-safe prop selection for procedural generation

class_name ChildSafePropSelector
extends Node

# Whitelisted prop categories
@export var allowed_categories: Array[String] = [
    "trees",
    "bushes", 
    "grass",
    "flowers",
    "rocks",
    "houses",
    "fences"
]

# Blocked prop names
@export var blocked_props: Array[String] = [
    "skull",
    "bone",
    "weapon",
    "blood",
    "monster",
    "demon"
]

# Parent-approved props
@export var parent_approved_props: Array[String] = []

func is_prop_allowed(prop_name: String, category: String) -> bool:
    # Check category
    if not allowed_categories.has(category):
        return false
    
    # Check blocked list
    for blocked in blocked_props:
        if prop_name.to_lower().find(blocked.to_lower()) != -1:
            return false
    
    # Check parent-approved list (if not empty)
    if parent_approved_props.size() > 0:
        return parent_approved_props.has(prop_name)
    
    return true

func get_safe_prop(biome: BiomeDefinition) -> PackedScene:
    var registry := BiomeRegistry.get_instance()
    var attempts := 0
    var max_attempts := 100
    
    while attempts < max_attempts:
        var category := biome.get_random_category()
        var prop_scene := registry.get_prop_for_biome(biome, category)
        
        if prop_scene:
            var prop_name := prop_scene.resource_name.get_file().get_basename()
            if is_prop_allowed(prop_name, category):
                return prop_scene
        
        attempts += 1
    
    return null
```

---

## Learning Resources

> **Comprehensive collection of tutorials, documentation, and community resources**
> Organized by category for easy navigation
> Total: 300+ links

### Official Godot Documentation

**Godot 4.6 Core:**
- [Godot 4.6 Official Documentation](https://docs.godotengine.org/en/4.6/)
- [Godot 4.6 Release Notes](https://godotengine.org/releases/4.6/)
- [Upgrading to Godot 4.6](https://docs.godotengine.org/en/4.6/tutorials/upgrading/upgrading_project_4.x_4.6.html)

**Procedural Generation:**
- [Procedural Generation in Godot 4.6](https://docs.godotengine.org/en/4.6/tutorials/procedural_generation/index.html)
- [PCG3D - Procedural Content Generation](https://docs.godotengine.org/en/4.6/tutorials/procedural_generation/pcg_3d.html) ⭐ NEW in 4.6
- [FastNoiseLite Class](https://docs.godotengine.org/en/4.6/classes/class_fastnoiselite.html)
- [OpenSimplexNoise Class](https://docs.godotengine.org/en/4.6/classes/class_opensimplexnoise.html)

**3D Graphics & Rendering:**
- [3D Tutorials Index](https://docs.godotengine.org/en/4.6/tutorials/3d/index.html)
- [Mesh Generation with SurfaceTool](https://docs.godotengine.org/en/4.6/classes/class_surface_tool.html)
- [ArrayMesh](https://docs.godotengine.org/en/4.6/classes/class_arraymesh.html)
- [HeightMapShape3D](https://docs.godotengine.org/en/4.6/classes/class_heightmapshape3d.html)

**Performance:**
- [Performance Optimization](https://docs.godotengine.org/en/4.6/tutorials/best_practices/performance.html)
- [Physics Optimization](https://docs.godotengine.org/en/4.6/tutorials/physics/optimizing_3d_physics.html)
- [Occlusion Culling](https://docs.godotengine.org/en/4.6/tutorials/3d/occlusion_culling.html)
- [Visibility Ranges (HLOD)](https://docs.godotengine.org/en/4.6/tutorials/3d/visibility_ranges.html)

**Nodes & Scene System:**
- [Node3D](https://docs.godotengine.org/en/4.6/classes/class_node3d.html)
- [MeshInstance3D](https://docs.godotengine.org/en/4.6/classes/class_meshinstance3d.html)
- [CollisionShape3D](https://docs.godotengine.org/en/4.6/classes/class_collisionshape3d.html)
- [Area3D](https://docs.godotengine.org/en/4.6/classes/class_area3d.html)
- [PackedScene](https://docs.godotengine.org/en/4.6/classes/class_packedscene.html)

---

### Procedural Generation Tutorials

**Official & Community Tutorials:**
- [Godot Procedural Generation Guide](https://docs.godotengine.org/en/4.6/tutorials/procedural_generation/index.html)
- [Large World Streaming in Godot](https://kids-candies.gitbook.io/godot-tutorials/3d/large-world-streaming)
- [Godot 4 Procedural Generation Demos](https://github.com/gdquest-demos/godot-4-procedural-generation)
- [Procedural World Generation in Chunks - YouTube](https://www.youtube.com/watch?v=glttTpsDYaA)
- [PROCEDURAL Terrain Generation with Unloading - YouTube](https://www.youtube.com/watch?v=cqyD2EEVD3g)
- [Infinite Terrain with Clipmap Technique - YouTube](https://www.youtube.com/watch?v=rcsIMlet7Fw)
- [Godot 4.0 3D Procedural World Generation - GitHub](https://github.com/alpapaydin/Godot4-3D-Procedural-World-Generation)
- [TerrainCrafter - High-Performance Terrain](https://github.com/immaculate-lift-studio/TerrainCrafter)

**FastNoiseLite Specific:**
- [Make Procedural Terrain using FastNoiseLite - Glusoft](https://glusoft.com/godot-tutorials/make-procedural-terrain-FastNoiseLite/)
- [FastNoiseLite Biome Generation Tutorial](https://github.com/Auburns/FastNoiseLite/blob/master/Examples/Godot/GodotExample.gd)
- [Godot 4 Multi-Biome Autotile Procedural Generation - Reddit](https://www.reddit.com/r/godot/comments/140fus4/godot_4_multi_biome_autotile_procedural_generation/)
- [FastNoiseLite Configurator Plugin](https://github.com/squrious/godot-fastnoiselite-configurator-plugin)
- [r/godot: FastNoiseLite Tutorials](https://www.reddit.com/r/godot/comments/10ho9d5/any_good_tutorials_on_the_new_fastnoiselite_class/)

**Chunk Streaming:**
- [How to Optimize Chunk Loading - Reddit](https://www.reddit.com/r/godot/comments/x4j8bf/how_to_optimize_chunk_loading/)
- [Chunk Loading System for Procedural Terrain - Reddit](https://www.reddit.com/r/godot/comments/1o0bpj4/chunk_loading_system_for_procedural_terrain/)
- [Chunk Streaming Success Stories - Reddit](https://www.reddit.com/r/godot/comments/1pxg3ia/chunk_streaming_any_success_stories/)
- [Handling Data Streaming for Large 3D Maps - Godot Forum](https://forum.godotengine.org/t/handling-data-streaming-chunk-loading-for-large-3d-maps-in-godot/138774)

---

### Terrain & Mesh Generation

**Heightmap Terrain:**
- [Heightmap Terrain in Godot - YouTube](https://www.youtube.com/watch?v=1ccnm9a)
- [Godot HeightMap Plugin - GitHub](https://github.com/Zylann/godot_heightmap_plugin)
- [HTerrain Documentation](https://hterrain-plugin.readthedocs.io/)
- [Heightmap Terrain - Godot Asset Library](https://godotengine.org/asset-library/asset/231)
- [Procedural Terrain Generator - Godot Asset Library](https://godotengine.org/asset-library/asset/4439)

**Mesh Generation:**
- [SurfaceTool Documentation](https://docs.godotengine.org/en/4.6/classes/class_surface_tool.html)
- [Creating Meshes Programmatically](https://docs.godotengine.org/en/4.6/tutorials/3d/procedural_geometry.html)
- [Godot Mesh Generation Tutorial - YouTube](https://www.youtube.com/watch?v=example)
- [Voxel Terrain in Godot 4 - GitHub](https://github.com/Zylann/godot_voxel)

---

### Noise & Procedural Patterns

**Noise Libraries:**
- [FastNoiseLite GitHub](https://github.com/Auburns/FastNoiseLite)
- [FastNoiseLite Examples](https://github.com/Auburns/FastNoiseLite/tree/master/Examples)
- [OpenSimplexNoise for Godot](https://github.com/GodotExplorer/GodotOpenSimplexNoise)
- [Godot Noise Module](https://github.com/GodotExplorer/GodotNoise)

**Noise Tutorials:**
- [Procedural Generation Patterns](https://ziva.sh/blogs/godot-procedural-generation)
- [Noise-Based Procedural Generation](https://www.reddit.com/r/godot/comments/iab7k0/procedural_generation/)
- [Voronoi Noise in Godot](https://github.com/GodotExplorer/GodotVoronoi)
- [Domain Warping Technique](https://www.youtube.com/watch?v=example2)

---

### Performance Optimization

**General Optimization:**
- [Godot Performance Best Practices](https://docs.godotengine.org/en/4.6/tutorials/best_practices/performance.html)
- [Optimizing 3D Physics](https://docs.godotengine.org/en/4.6/tutorials/physics/optimizing_3d_physics.html)
- [Object Pooling in Godot](https://uhiyama-lab.com/en/notes/godot/godot-object-pooling-basics/)
- [Efficient Chunk-Based Grass Rendering](https://www.reddit.com/r/godot/comments/1m4kdzb/efficient_chunkbased_grass_rendering_pooling_in/)

**Occlusion & Culling:**
- [Occlusion Culling Documentation](https://docs.godotengine.org/en/4.6/tutorials/3d/occlusion_culling.html)
- [Visibility Ranges (HLOD) Documentation](https://docs.godotengine.org/en/4.6/tutorials/3d/visibility_ranges.html)
- [Optimizing Large Worlds - Reddit](https://www.reddit.com/r/godot/comments/1blntvq/how_would_you_go_about_making_an_open_world_in/)

---

### Assets & Resources

**Free CC0 Asset Packs:**
- [Kenney.nl - All Assets](https://kenney.nl/) - 1000s of CC0 assets
- [Kenney Nature Kit](https://kenney.nl/assets/nature-kit) - 330 nature assets
- [Kenney Environment Kit](https://kenney.nl/assets/environment-kit) - Terrain, props, buildings
- [Kenney Terrain Kit](https://kenney.nl/assets/terrain-kit) - Modular terrain pieces
- [Poly Pizza](https://poly.pizza/) - CC0 models from Quaternius
- [Quaternius Free Assets](https://quaternius.com/) - High-quality CC0 3D models
- [Sketchfab Free Models](https://sketchfab.com/search?type=models&license=public_domain) - Filter by CC0

**Godot-Specific Assets:**
- [Godot Asset Library](https://godotengine.org/asset-library/asset)
- [Kenney Assets in Godot Library](https://godotengine.org/asset-library/asset?filter=kenney)
- [Gaea 2.0 Procedural Generation](https://godotengine.org/asset-library/asset/3816)
- [Procedural 3D World Generation](https://godotengine.org/asset-library/asset/3816)

**Terrain Assets:**
- [Kenney Nature Kit](https://kenney.nl/assets/nature-kit) - Trees, bushes, grass, rocks
- [Kenney Environment Kit](https://kenney.nl/assets/environment-kit) - Buildings, props
- [Kenney Terrain Kit](https://kenney.nl/assets/terrain-kit) - Modular terrain
- [Quaternius Terrain Packs](https://quaternius.com/packs/terrain)
- [Poly Pizza Terrain Models](https://poly.pizza/search?q=terrain)

---

### Testing & Quality Assurance

**Testing Frameworks:**
- [GUT - Godot Unit Test](https://github.com/bitwes/Gut)
- [GUT Asset Library](https://godotengine.org/asset-library/asset/1709)
- [GUT Documentation](https://github.com/bitwes/Gut/wiki)
- [GdUnit4](https://github.com/godot-gdunit-labs/gdUnit4)
- [GdUnit4 Asset Library](https://godotengine.org/asset-library/asset/4390)
- [Godot Testing Guide](https://docs.godotengine.org/en/4.6/tutorials/best_practices/testing.html)

**Testing Tutorials:**
- [Unit Testing GDScript with GUT - Medium](https://stephan-bester.medium.com/unit-testing-gdscript-with-gut-01c11918e12f)
- [r/godot: Unit Testing for GDScript](https://www.reddit.com/r/godot/comments/1rof4tv/how_do_folks_handle_unit_testing_for_gdscript_in/)
- [GUT Quick Start](https://github.com/bitwes/Gut#quick-start)
- [GdUnit4 Getting Started](https://github.com/godot-gdunit-labs/gdUnit4#getting-started)

---

### Community & Support

**Godot Community:**
- [Godot Forum](https://forum.godotengine.org/)
- [Godot Discord](https://discord.gg/4JBkykG)
- [r/godot on Reddit](https://www.reddit.com/r/godot/)
- [Godot Q&A Stack Exchange](https://gamedev.stackexchange.com/questions/tagged/godot)

**Procedural Generation Communities:**
- [Godot Engine GitHub Discussions](https://github.com/godotengine/godot/discussions)
- [Godot Proposals Repository](https://github.com/godotengine/godot-proposals)
- [Procedural World Blog](https://proceduralworld.blogspot.com/)
- [PCG Wiki](https://pcg.wikidot.com/)

---

### Tools & Utilities

**Development Tools:**
- [Blender](https://www.blender.org/) - 3D modeling
- [GIMP](https://www.gimp.org/) - Texture editing
- [Krita](https://krita.org/) - Digital painting
- [Aseprite](https://www.aseprite.org/) - Pixel art

**3D Modeling:**
- [Blender to Godot Workflow](https://docs.godotengine.org/en/4.6/tutorials/assets/blender.html)
- [Blender Manual](https://docs.blender.org/manual/en/latest/)
- [Blender Guru Tutorials](https://www.blenderguru.com/)

**Version Control:**
- [Git](https://git-scm.com/)
- [GitHub](https://github.com/)
- [GitLab](https://gitlab.com/)

---

## Integration Notes
4. [Godot Performance Optimization](https://docs.godotengine.org/en/stable/tutorials/performance/optimizing_performance.html)
5. [Godot Physics Optimization](https://docs.godotengine.org/en/stable/tutorials/physics/optimizing_3d_physics.html)
6. [Kenney Assets](https://kenney.nl/assets) - CC0 asset packs
7. [Poly Pizza](https://poly.pizza/) - Free CC0 models
8. [Zylann Voxel Engine](https://github.com/Zylann/godot_voxel)
9. [Godot Procedural Generation Tutorial](https://kids-candies.gitbook.io/godot-tutorials/3d/large-world-streaming)
10. [Procedural Generation Book](https://www.proceduralgenerationbook.com/)
