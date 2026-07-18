# Research Compendium: VS-017 & VS-019 — Procedural World Streaming (5.76km²)

## Task Overview

**Task IDs**: VS-017, VS-019  
**Title**: Stream deterministic 5.76km² sandbox biomes around the player / Scale the procedural island and make authored set pieces physically traversable  
**Specialty**: procedural-world-streaming, world-scale-collision  
**Owner**: codex  
**Status**: in_progress  

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

## Online Research: Godot Procedural World Generation

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

## References

1. [Godot 4.6 Documentation](https://docs.godotengine.org/en/stable/)
2. [Godot PCG Documentation](https://docs.godotengine.org/en/stable/tutorials/procedural_generation/pcg_3d.html)
3. [FastNoiseLite Godot Class](https://docs.godotengine.org/en/stable/classes/class_fastnoiselite.html)
4. [Godot Performance Optimization](https://docs.godotengine.org/en/stable/tutorials/performance/optimizing_performance.html)
5. [Godot Physics Optimization](https://docs.godotengine.org/en/stable/tutorials/physics/optimizing_3d_physics.html)
6. [Kenney Assets](https://kenney.nl/assets) - CC0 asset packs
7. [Poly Pizza](https://poly.pizza/) - Free CC0 models
8. [Zylann Voxel Engine](https://github.com/Zylann/godot_voxel)
9. [Godot Procedural Generation Tutorial](https://kids-candies.gitbook.io/godot-tutorials/3d/large-world-streaming)
10. [Procedural Generation Book](https://www.proceduralgenerationbook.com/)
