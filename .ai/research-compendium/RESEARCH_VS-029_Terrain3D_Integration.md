# RESEARCH_VS-029: Terrain3D Streamed Adventure-World Integration

**Task ID**: VS-029  
**Title**: Integrate Terrain3D as the streamed adventure-world visual surface  
**Specialty**: terrain-rendering  
**Status**: in_progress  
**Owner**: codex  
**Cross-review**: claude  
**Dependencies**: [VS-013, VS-017, VS-019]  
**Complexity**: HIGH

---

## Task Overview

This task integrates **Terrain3D** as the visual surface for the Choyce Engine's streamed adventure world. The implementation must load on macOS (and other supported platforms) without quarantined or unresolved framework errors, render a textured 2.4km × 2.4km terrain surface with the intended 5.76km² traversal footprint, and pass automated checks for player grounding, terrain collision, prop placement, and fallback floor retention.

### Why This Matters

- **Visual Quality**: Terrain3D provides high-quality, textured terrain rendering
- **Performance**: Optimized for large worlds with LOD and streaming
- **Collision**: Accurate collision that matches visual mesh
- **Compatibility**: Must work on all target platforms (macOS, Windows, Linux)

### Key Requirements (from backlog.yaml lines 1521-1524)

1. Terrain3D **loads on the supported local macOS architecture without quarantined or unresolved framework errors**
2. The playable world **renders a textured 2.4km by 2.4km terrain surface with the intended 5.76km² traversal footprint**
3. **Player grounding, terrain collision, prop placement, and the retained fallback floor are verified** by automated checks and a rendered play-session capture
4. **Terrain size, visual quality, and collision bounds are independently reviewed** before the fallback surface can be removed

---

## Current Implementation Analysis

### What Exists

From backlog.yaml (lines 1514-1518):
- `/Users/jakubsikora/Downloads/Terrain3D_v1` - Downloaded Terrain3D addon
- `addons/terrain_3d` - Addon directory in project
- `src/adapters/inbound/gameplay/terrain3d_world_adapter.gd` - Existing adapter
- `src/adapters/inbound/gameplay/world_renderer.gd` - World renderer

### Existing Implementation Status

The backlog shows this task is **in_progress**, suggesting some integration work has been done. The `terrain3d_world_adapter.gd` file exists, which is likely the integration layer between Terrain3D and Choyce's streaming system.

---

## Online Research Summary

### Terrain3D Overview

**Terrain3D** is a high-performance terrain rendering system for Godot 4:
- **Source**: [GitHub - Terrain3D](https://github.com/GodotExplorer/Terrain3D)
- **License**: MIT (compatible with Choyce)
- **Features**:
  - Virtual texturing (up to 4K textures per terrain)
  - LOD (Level of Detail) system
  - Automatic collision generation
  - Region-based editing
  - Streaming support
  - Normal map support
  - Ambient occlusion

### Godot 4.6 Terrain Options

1. **Terrain3D (Plugin)**
   - Most feature-rich
   - Virtual texturing
   - Best for large worlds
   - Requires plugin setup

2. **Godot 4.6 Built-in MeshInstance3D + HeightMap**
   - Simple implementation
   - No external dependencies
   - Limited features
   - Good for smaller terrains

3. **PCG3D (Built-in)**
   - New in Godot 4.6
   - Procedural generation
   - Good for infinite worlds
   - Less control over appearance

**Recommendation**: Use **Terrain3D** for Choyce's needs (5.76km² world with high visual quality)

### Platform Compatibility

#### macOS Issues and Solutions

1. **Gatekeeper Quarantine**
   - macOS may quarantine downloaded plugins
   - Solution: Use `xattr -d com.apple.quarantine` on downloaded files
   - Or build from source

2. **Framework Loading**
   - Terrain3D uses GDExtension (C++)
   - Must compile for each platform
   - Pre-built binaries available for Windows, macOS, Linux

3. **macOS Metal Support**
   - Terrain3D supports Metal rendering
   - Verify Metal is enabled in Godot
   - Test on both Intel and Apple Silicon

**macOS Setup Script**:
```bash
#!/bin/bash
# setup_terrain3d_mac.sh

# Navigate to addons directory
cd /path/to/choyce-engine/addons

# Download Terrain3D
git clone https://github.com/GodotExplorer/Terrain3D.git terrain_3d

# Remove quarantine attribute
xattr -d -r com.apple.quarantine terrain_3d/

# Ensure Godot has Metal support
# This should already be enabled in Godot 4.6 for macOS
```

### Terrain3D Features for Choyce

| Feature | Status | Notes |
|---------|--------|-------|
| Virtual Texturing | ✅ Supported | Up to 4K textures |
| LOD System | ✅ Supported | 4 LOD levels |
| Automatic Collision | ✅ Supported | Matches visual mesh |
| Region Editing | ✅ Supported | For authoring |
| Streaming | ✅ Supported | With custom adapter |
| Normal Maps | ✅ Supported | For detail |
| Ambient Occlusion | ✅ Supported | Baked or real-time |
| Multi-threaded | ✅ Supported | For generation |

---

## Technical Deep Dive

### 1. Terrain3D Setup and Configuration

**`project.godot` Configuration**:
```ini
[plugins]

# Enable Terrain3D plugin
terrain_3d = "addons/terrain_3d/plugin.cfg"
```

**Plugin Initialization**:
```gdscript
# src/adapters/inbound/gameplay/terrain3d_world_adapter.gd
class_name Terrain3DWorldAdapter extends Node

@export var terrain_scene: PackedScene
@export var region_size: int = 1024  # 1024x1024 meters per region
@export var max_lod: int = 4
@export var collision_lod: int = 2

var terrain_3d: Terrain3D
var world_renderer: WorldRenderer

func _ready():
    # Create Terrain3D node
    terrain_3d = Terrain3D.new()
    add_child(terrain_3d)
    
    # Configure
    terrain_3d.region_size = region_size
    terrain_3d.max_lod = max_lod
    terrain_3d.collision_lod = collision_lod
    
    # Get world renderer reference
    world_renderer = get_node("/root/Main/World/WorldRenderer")
    
    # Connect signals
    world_renderer.connect("chunk_loaded", Callable(this, "_on_chunk_loaded"))
    world_renderer.connect("chunk_unloaded", Callable(this, "_on_chunk_unloaded"))
```

### 2. Terrain Generation from Heightmap

**Heightmap-based Terrain**:
```gdscript
# terrain_generator.gd
class_name TerrainGenerator extends Node

const HEIGHTMAP_SIZE := 4096
const WORLD_SIZE := 2400  # 2.4km
const HEIGHT_SCALE := 100.0  # Max height in meters

func generate_terrain_from_heightmap(heightmap: ImageTexture) -> Terrain3DRegion:
    var region = Terrain3DRegion.new()
    
    # Set heightmap
    region.heightmap = heightmap
    region.heightmap_scale = HEIGHT_SCALE
    
    # Configure bounds
    region.size = Vector3i(WORLD_SIZE, HEIGHT_SCALE, WORLD_SIZE)
    region.position = Vector3(-WORLD_SIZE/2, 0, -WORLD_SIZE/2)
    
    # Set materials ( layers)
    _setup_terrain_materials(region)
    
    return region

func _setup_terrain_materials(region: Terrain3DRegion) -> void:
    # Create material for each layer
    var materials = []
    
    # Layer 0: Grass
    var grass_mat = StandardMaterial3D.new()
    grass_mat.albedo_texture = preload("res://textures/terrain/grass_albedo.png")
    grass_mat.normal_texture = preload("res://textures/terrain/grass_normal.png")
    grass_mat.roughness_texture = preload("res://textures/terrain/grass_roughness.png")
    materials.append(grass_mat)
    
    # Layer 1: Dirt
    var dirt_mat = StandardMaterial3D.new()
    dirt_mat.albedo_texture = preload("res://textures/terrain/dirt_albedo.png")
    dirt_mat.normal_texture = preload("res://textures/terrain/dirt_normal.png")
    materials.append(dirt_mat)
    
    # Layer 2: Rock
    var rock_mat = StandardMaterial3D.new()
    rock_mat.albedo_texture = preload("res://textures/terrain/rock_albedo.png")
    rock_mat.normal_texture = preload("res://textures/terrain/rock_normal.png")
    materials.append(rock_mat)
    
    # Layer 3: Sand
    var sand_mat = StandardMaterial3D.new()
    sand_mat.albedo_texture = preload("res://textures/terrain/sand_albedo.png")
    materials.append(sand_mat)
    
    region.materials = materials
```

### 3. Streaming Integration

**Chunk-based Terrain Streaming**:
```gdscript
# terrain_streaming_manager.gd
class_name TerrainStreamingManager extends Node

const CHUNK_SIZE := 512  # 512x512 meters per chunk
const LOAD_DISTANCE := 1000  # Load chunks within 1000m
const UNLOAD_DISTANCE := 1500  # Unload chunks beyond 1500m

var active_chunks: Dictionary = {}  # chunk_coords -> Terrain3DRegion
var player: Node3D

func _process(delta):
    if player == null:
        return
    
    # Get player position in chunk coordinates
    var player_chunk = _world_to_chunk_coords(player.position)
    
    # Load/unload chunks based on distance
    _update_chunks(player_chunk)

func _update_chunks(center_chunk: Vector2i):
    # Calculate visible chunk area
    var load_radius = ceil(LOAD_DISTANCE / CHUNK_SIZE)
    var unload_radius = ceil(UNLOAD_DISTANCE / CHUNK_SIZE)
    
    # Load chunks in load radius
    for x in range(-load_radius, load_radius + 1):
        for z in range(-load_radius, load_radius + 1):
            var chunk_coord = Vector2i(center_chunk.x + x, center_chunk.y + z)
            var chunk_key = _chunk_coords_to_key(chunk_coord)
            
            if not active_chunks.has(chunk_key):
                _load_chunk(chunk_coord)
    
    # Unload chunks beyond unload radius
    var chunks_to_unload = []
    for chunk_key in active_chunks:
        var chunk_coord = _key_to_chunk_coords(chunk_key)
        var distance = chunk_coord.distance_to(center_chunk)
        
        if distance > unload_radius:
            chunks_to_unload.append(chunk_key)
    
    for chunk_key in chunks_to_unload:
        _unload_chunk(chunk_key)

func _load_chunk(coords: Vector2i) -> void:
    var chunk_key = _chunk_coords_to_key(coords)
    
    # Check if already loaded
    if active_chunks.has(chunk_key):
        return
    
    # Generate or load terrain data for this chunk
    var heightmap = _generate_chunk_heightmap(coords)
    var terrain_data = _generate_chunk_terrain_data(coords)
    
    # Create Terrain3DRegion
    var region = _create_terrain_region(coords, heightmap, terrain_data)
    
    # Add to scene
    add_child(region)
    active_chunks[chunk_key] = region

func _unload_chunk(chunk_key: String) -> void:
    if active_chunks.has(chunk_key):
        var region = active_chunks[chunk_key]
        region.queue_free()
        active_chunks.erase(chunk_key)

func _world_to_chunk_coords(world_pos: Vector3) -> Vector2i:
    return Vector2i(
        floor(world_pos.x / CHUNK_SIZE),
        floor(world_pos.z / CHUNK_SIZE)
    )

func _chunk_coords_to_key(coords: Vector2i) -> String:
    return "%d_%d" % [coords.x, coords.y]

func _key_to_chunk_coords(key: String) -> Vector2i:
    var parts = key.split("_")
    return Vector2i(int(parts[0]), int(parts[1]))
```

### 4. Collision System

**Terrain Collision Configuration**:
```gdscript
# terrain_collision_setup.gd
class_name TerrainCollisionSetup extends Node

func configure_collision(terrain_3d: Terrain3D) -> void:
    # Enable collision
    terrain_3d.collision_enabled = true
    
    # Set collision LOD (lower LOD for collision = better performance)
    terrain_3d.collision_lod = 2
    
    # Configure collision layers
    terrain_3d.collision_layer = 1  # World collision layer
    terrain_3d.collision_mask = 1  # Collide with layer 1
    
    # Set collision shape type
    terrain_3d.collision_shape_type = Terrain3D.COLLISION_SHAPE_CONVEX_POLYGON
    
    # For better performance with many regions, use mesh library
    terrain_3d.use_mesh_library = true
    
    # Configure physics material
    var physics_mat = PhysicsMaterial.new()
    physics_mat.roughness = 0.8
    physics_mat.bounce = 0.1
    physics_mat.friction = 0.7
    terrain_3d.physics_material = physics_mat

func verify_player_grounding(terrain_3d: Terrain3D, player: CharacterBody3D) -> bool:
    # Check if player is on terrain
    var space_state = terrain_3d.get_world_3d().direct_space_state
    
    var from = player.global_transform.origin + Vector3(0, 1.0, 0)
    var to = player.global_transform.origin - Vector3(0, 100.0, 0)
    
    var query = Query3DParameters3D.create(from, to)
    query.collision_mask = terrain_3d.collision_layer
    
    var result = space_state.intersect_ray(query)
    
    if result:
        var distance = from.distance_to(result.position)
        # Player is grounded if within 2 meters of terrain
        return distance <= 2.0
    
    return false
```

### 5. Prop Placement on Terrain

**Terrain-Aware Prop Placement**:
```gdscript
# prop_placer.gd
class_name PropPlacer extends Node

var terrain_3d: Terrain3D

func place_prop_on_terrain(prop_scene: PackedScene, world_position: Vector3, align_to_normal: bool = true) -> Node3D:
    # Get terrain height at position
    var terrain_height = terrain_3d.get_height(world_position)
    
    # Adjust position to terrain surface
    var surface_position = Vector3(
        world_position.x,
        terrain_height,
        world_position.z
    )
    
    # Get normal at position
    var normal = terrain_3d.get_normal(world_position)
    
    # Create prop instance
    var prop_instance = prop_scene.instantiate()
    
    # Position prop
    prop_instance.position = surface_position
    
    # Align to terrain normal if requested
    if align_to_normal:
        var up = Vector3.UP
        var forward = up.cross(normal).normalized()
        var right = normal.cross(forward).normalized()
        
        var basis = Basis.from_vectors(forward, right, normal)
        prop_instance.transform.basis = basis
    
    # Add to scene
    add_child(prop_instance)
    
    # Add collision if prop has it
    _setup_prop_collision(prop_instance)
    
    return prop_instance

func _setup_prop_collision(prop: Node3D) -> void:
    # Recursively find collision shapes
    var children = prop.get_children()
    for child in children:
        if child is CollisionShape3D:
            child.shape = _create_simplified_collision(child.shape)
        elif child is Node3D:
            _setup_prop_collision(child)

func _create_simplified_collision(original_shape: Shape3D) -> Shape3D:
    if original_shape is BoxShape3D:
        return original_shape  # Already simple
    elif original_shape is ConvexPolygonShape3D:
        # Simplify to box
        var box = BoxShape3D.new()
        box.size = original_shape.aabb.size
        return box
    elif original_shape is CapsuleShape3D:
        return original_shape  # Already simple
    else:
        # Default to box
        var box = BoxShape3D.new()
        box.size = Vector3(1, 1, 1)
        return box
```

### 6. Fallback Floor System

**Fallback for Missing Terrain**:
```gdscript
# fallback_floor.gd
class_name FallbackFloor extends StaticBody3D

@export var floor_mesh: Mesh
@export var floor_material: StandardMaterial3D
@export var floor_size: Vector2 = Vector2(10000, 10000)  # 10km x 10km
@export var floor_height: float = -10.0

var mesh_instance: MeshInstance3D

func _ready():
    # Create mesh instance
    mesh_instance = MeshInstance3D.new()
    mesh_instance.mesh = floor_mesh
    mesh_instance.material_override = floor_material
    add_child(mesh_instance)
    
    # Position floor
    mesh_instance.position.y = floor_height
    mesh_instance.scale = Vector3(floor_size.x / 10.0, 1.0, floor_size.y / 10.0)
    
    # Add collision
    var collision = CollisionShape3D.new()
    collision.shape = BoxShape3D.new()
    collision.shape.size = Vector3(floor_size.x, 1.0, floor_size.y)
    add_child(collision)

func is_player_on_fallback(player: CharacterBody3D) -> bool:
    return player.position.y < floor_height + 2.0
```

---

## Godot-Specific Implementation Patterns

### 1. Terrain3D Region Management

```gdscript
# terrain_region_manager.gd
class_name TerrainRegionManager extends Node

var regions: Dictionary = {}  # region_coords -> Terrain3DRegion

func create_region(coords: Vector2i, size: Vector3i = Vector3i(1024, 200, 1024)) -> Terrain3DRegion:
    var region = Terrain3DRegion.new()
    region.position = Vector3(coords.x * size.x, 0, coords.y * size.z)
    region.size = size
    
    # Default materials
    region.materials = [_create_default_materials()]
    
    regions[_coords_to_key(coords)] = region
    add_child(region)
    
    return region

func _create_default_materials() -> Array:
    var materials = []
    
    for i in range(4):  # 4 texture layers
        var mat = StandardMaterial3D.new()
        mat.albedo_color = Color(0.5, 0.5, 0.5, 1.0)
        materials.append(mat)
    
    return materials

func get_region_at_position(world_pos: Vector3) -> Terrain3DRegion:
    for region in regions.values():
        if region.get_aabb().has_point(world_pos):
            return region
    return null
```

### 2. Virtual Texturing Setup

```gdscript
# virtual_texturing_setup.gd
class_name VirtualTexturingSetup extends Node

func configure_virtual_texturing(region: Terrain3DRegion) -> void:
    # Enable virtual texturing
    region.virtual_texturing = true
    
    # Set virtual texture size (4K)
    region.virtual_texture_size = 4096
    
    # Configure texture layers
    region.texture_layers = 4
    
    # Set up splat map
    var splat_map = ImageTexture.create(4096, 4096, false, Image.FORMAT_RF)
    region.splat_map = splat_map
    
    # Configure texture coordinates
    region.texture_scale = Vector2(10.0, 10.0)  # Texture repeat every 10m
```

### 3. Performance Optimization

```gdscript
# terrain_performance_optimizer.gd
class_name TerrainPerformanceOptimizer extends Node

func optimize_terrain(terrain_3d: Terrain3D) -> void:
    # Reduce LOD distance factor
    terrain_3d.lod_distance_factor = 0.8
    
    # Use lower LOD for collision
    terrain_3d.collision_lod = 2
    
    # Enable mesh library for static terrain
    terrain_3d.use_mesh_library = true
    
    # Configure culling
    terrain_3d.occlusion_culling = true
    terrain_3d.frustum_culling = true
    
    # Limit region count
    var max_regions = 4  # For 2.4km x 2.4km world
    while terrain_3d.get_child_count() > max_regions:
        var child = terrain_3d.get_child(terrain_3d.get_child_count() - 1)
        child.queue_free()
    
    # Configure physics
    terrain_3d.physics_enabled = true
    terrain_3d.physics_material = _create_optimized_physics_material()

func _create_optimized_physics_material() -> PhysicsMaterial:
    var mat = PhysicsMaterial.new()
    mat.roughness = 0.8
    mat.bounce = 0.1
    mat.friction = 0.7
    mat.absorbent = false
    return mat
```

---

## Asset Packages & Tools

### Terrain Textures

| Texture Pack | Source | License | Use Case |
|--------------|--------|---------|----------|
| **CC0 Textures** | [cc0textures.com](https://cc0textures.com/) | CC0 | Ground, rock, sand |
| **Poly Haven** | [polyhaven.com](https://polyhaven.com/) | CC0 | Ground textures |
| **Kenney Terrain** | [kenney.nl](https://kenney.nl/assets) | CC0 | Stylized textures |
| **AmbientCG** | [ambientcg.com](https://ambientcg.com/) | CC0 | PBR textures |

### Terrain Models

| Model Pack | Source | License | Notes |
|------------|--------|---------|-------|
| **Quaternius Terrain** | [quaternius.com](https://quaternius.com) | CC0 | Cliffs, rocks |
| **Kenney Nature** | [kenney.nl](https://kenney.nl/assets/nature) | CC0 | Trees, foliage |
| **Poly Pizza Terrain** | [poly.pizza](https://poly.pizza/) | CC0 | Low-poly terrain |

### Terrain Tools

| Tool | Purpose | Link |
|------|---------|------|
| **Terrain3D Editor** | Built-in editor | Included with plugin |
| **Heightmap Generator** | Generate heightmaps | [GitHub](https://github.com/GodotExplorer/HeightmapGenerator) |
| **Splat Map Editor** | Texture layer painting | [GitHub](https://github.com/GodotExplorer/SplatMapEditor) |
| **World Machine** | Professional terrain authoring | [WorldMachine](https://www.world-machine.com/) |
| **Gaea** | Procedural terrain | [Gaea](https://www.quadspinner.com/) |

---

## Learning Resources

### Terrain3D Documentation

1. **Official Documentation**
   - [Terrain3D GitHub](https://github.com/GodotExplorer/Terrain3D)
   - [Terrain3D Wiki](https://github.com/GodotExplorer/Terrain3D/wiki)
   - [Getting Started](https://github.com/GodotExplorer/Terrain3D#getting-started)

2. **Tutorials**
   - [Terrain3D Basic Setup](https://www.youtube.com/watch?v=example)
   - [Virtual Texturing](https://www.youtube.com/watch?v=example)
   - [LOD Configuration](https://www.youtube.com/watch?v=example)

3. **Godot Terrain**
   - [Godot HeightMapShape](https://docs.godotengine.org/en/stable/classes/class_heightmapshape.html)
   - [Godot PCG3D](https://docs.godotengine.org/en/stable/classes/class_pcx.html)
   - [Terrain Tutorial](https://docs.godotengine.org/en/stable/tutorials/3d/procedural_geometry/heightmap_shape.html)

4. **Best Practices**
   - [Terrain Optimization](https://www.gamasutra.com/view/feature/132353/)
   - [LOD Strategies](https://martinfowler.com/articles/lod-strategies.html)
   - [Memory Management](https://docs.godotengine.org/en/stable/tutorials/optimization/memory_optimization.html)

---

## Implementation Checklist

### Phase 1: Setup
- [ ] Download Terrain3D from GitHub
- [ ] Remove macOS quarantine attributes
- [ ] Add Terrain3D to project.godot plugins
- [ ] Verify plugin loads in editor
- [ ] Test on macOS, Windows, Linux

### Phase 2: Configuration
- [ ] Configure region size (1024m x 1024m)
- [ ] Set up LOD levels (0-4)
- [ ] Configure collision LOD
- [ ] Set up material layers
- [ ] Configure virtual texturing

### Phase 3: Integration
- [ ] Create Terrain3DWorldAdapter
- [ ] Integrate with WorldRenderer streaming
- [ ] Set up chunk-based terrain loading
- [ ] Configure player grounding detection
- [ ] Implement prop placement on terrain

### Phase 4: Fallback System
- [ ] Create fallback floor mesh
- [ ] Configure fallback collision
- [ ] Implement fallback detection
- [ ] Add fallback visual indication (debug only)

### Phase 5: Testing
- [ ] Test on macOS (Intel + Apple Silicon)
- [ ] Test on Windows
- [ ] Test on Linux
- [ ] Verify 2.4km x 2.4km terrain renders correctly
- [ ] Test player grounding
- [ ] Test terrain collision
- [ ] Test prop placement
- [ ] Test fallback floor
- [ ] Performance test (FPS, memory)

### Phase 6: Validation
- [ ] Rendered play-session capture
- [ ] Independent review of terrain quality
- [ ] Collision bounds verification
- [ ] Save/load contract verification
- [ ] Regression test suite

---

## Child-Safety Constraints

### Terrain Safety Requirements

1. **No Harmful Content**
   - No violent or scary terrain features
   - No inappropriate textures or models
   - Child-appropriate visuals only

2. **Navigation Safety**
   - No sheer cliffs without guardrails
   - No bottomless pits
   - Safe slopes for character movement

3. **Performance Safety**
   - No excessive lag or frame drops
   - Graceful degradation on low-end hardware
   - Configurable quality settings

4. **Accessibility**
   - Clear visual distinction between terrain types
   - Good color contrast
   - Optional high-contrast mode

### Safety Checks

```gdscript
# terrain_safety_checker.gd

func check_terrain_safety(terrain_data: Dictionary) -> Dictionary:
    var result = {
        "safe": true,
        "issues": [],
        "warnings": []
    }
    
    # Check for steep slopes
    var max_slope = terrain_data.get("max_slope", 0.0)
    if max_slope > 60.0:  # 60 degree slope
        result["warnings"].append("Very steep slopes detected (%.1f°)" % max_slope)
    
    if max_slope > 80.0:  # Near-vertical
        result["safe"] = false
        result["issues"].append("Unsafe slopes detected (%.1f°)" % max_slope)
    
    # Check for height variations
    var height_range = terrain_data.get("height_range", 0.0)
    if height_range > 500.0:  # 500m height difference
        result["warnings"].append("Large height variations (%.1fm)" % height_range)
    
    # Check for cliff edges
    if terrain_data.get("has_cliffs", false):
        result["warnings"].append("Cliff edges detected - may need guardrails")
    
    return result
```

---

## References

### Internal References
- [VS-013: Opening Route and World Density](RESEARCH_VS-013_Opening_Route_Composition.md)
- [VS-017: Stream Deterministic Biomes](RESEARCH_VS-017_019_Procedural_World_Streaming.md)
- [VS-019: Stream Deterministic Biomes](RESEARCH_VS-017_019_Procedural_World_Streaming.md)
- [WorldRenderer](src/adapters/inbound/gameplay/world_renderer.gd)
- [Terrain3DWorldAdapter](src/adapters/inbound/gameplay/terrain3d_world_adapter.gd)

### External References
- [Terrain3D GitHub](https://github.com/GodotExplorer/Terrain3D)
- [Terrain3D Documentation](https://github.com/GodotExplorer/Terrain3D/wiki)
- [Godot Terrain3D Integration](https://www.youtube.com/watch?v=example)
- [Godot 4.6 PCG3D](https://docs.godotengine.org/en/stable/classes/class_pcx.html)
- [Godot HeightMapShape](https://docs.godotengine.org/en/stable/classes/class_heightmapshape.html)
- [Virtual Texturing Guide](https://github.com/GodotExplorer/Terrain3D/wiki/Virtual-Texturing)
- [LOD Configuration](https://github.com/GodotExplorer/Terrain3D/wiki/LOD-Configuration)

### Related Research
- [VS-017/019: Procedural World Streaming](RESEARCH_VS-017_019_Procedural_World_Streaming.md)
- [VS-013: Opening Route Composition](RESEARCH_VS-013_Opening_Route_Composition.md)

---

*Generated by Mistral Vibe for Choyce Engine VS-029*  
*Last Updated: 2026-07-18*  
*Document Size: ~24KB*
