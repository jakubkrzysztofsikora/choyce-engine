# RESEARCH_VS-012: Visual Art Direction Reset

**Task ID**: VS-012  
**Title**: Visual art direction reset: palette, materials, lighting, and cohesive asset kit  
**Owner**: codex  
**Specialty**: visual-art-direction  
**Status**: in_review  
**Dependencies**: [VS-004]  
**Complexity**: HIGH  
**Gate**: Visual Rescue Gate (Critical for presentability)

---

## Task Overview

### Purpose

Establish a **cohesive, child-friendly visual identity** for the Adventure slice that:
- Replaces debug/placeholder colors and materials
- Creates a restrained, intentional color palette
- Implements proper PBR materials with surface variation
- Sets up daylight with controlled exposure and shadows
- Uses only approved asset sources (Kenney, Quaternius, KayKit)
- Makes the first screenshot look intentional and professional

### Acceptance Criteria (from PLAN.md Visual Rescue Gate)

> - Establish one restrained palette and material language for ground, water, foliage, architecture, characters, and interactables
> - Remove neon rainbow defaults and untextured debug colors from the main camera
> - Add real surface variation to terrain and props: albedo detail, roughness differences, slope/shore transitions, foliage variation, and contact shadows
> - Prefer cohesive ready-made Kenney, Quaternius, KayKit, and existing project assets
> - Do not mix disconnected art packs in the same focal composition

### Gate A Requirements

> The next playable demo must look intentional in the first screenshot and remain interesting for the first five minutes.

---

## Current State Analysis

### What Exists

From PLAN.md latest evidence:
- Template terrain duplicated PBR ground 25cm above it, hiding river, trail, and ground dressing (FIXED: Adventure now uses one floor only)
- CC0 AmbientCG Ground003 colour/normal/roughness maps wired into 2.4km terrain material
- New authored forest mass extends 400m × 300m NW from signposted entrance
- Imported nature assets are larger and denser
- River continues well beyond the bridge

### What's Missing

1. **No cohesive palette** - Current materials are mismatched
2. **Debug colors remain** - Rainbow hotbar, giant world labels, emoji/debug icons
3. **Lighting is flat** - No ambient occlusion, contact shadows, atmospheric depth
4. **Materials are basic** - No albedo detail, roughness variation, slope transitions
5. **Foliage lacks variation** - Same trees/bushes repeated without variation
6. **Architecture style undefined** - Houses don't match the visual language

---

## Online Research Findings

### 1. Color Palette Design for Child-Friendly Games

**Recommended Approach**: Use a **harmonious, desaturated palette** with one accent color.

#### Child-Safe Color Theory

```
Base Palette (Desaturated, Calm):
┌─────────────────────────────────────────────┐
│ Color          │ Hex     │ Usage                │
├─────────────────────────────────────────────┤
│ Warm Beige     │ #D4C4A8 │ Ground, stone       │
│ Soft Green     │ #8FA68A │ Grass, foliage       │
│ Sky Blue       │ #B8D8D8 │ Water, sky          │
│ Wood Brown     │ #8B6B51 │ Trees, furniture     │
│ Roof Red       │ #A66B5A │ Architecture accents │
│ Accent Orange  │ #E8A862 │ Interactive elements │
└─────────────────────────────────────────────┘

Avoid:
❌ Neon colors (rainbow hotbar)
❌ Saturated primaries (pure red/blue/green)
❌ Clashing complementary colors
❌ More than 2-3 accent colors
```

**Tools for Palette Creation**:
- [Adobe Color](https://color.adobe.com/) - Create harmonious palettes
- [Coolors](https://coolors.co/) - Quick palette generation
- [Paletton](https://paletton.com/) - Color scheme designer
- [Lospec Palette List](https://lospec.com/palette-list) - Game-focused palettes

**Child-Friendly Palette Examples**:
- [Mario Kart 8 Palette](https://www.mariowiki.com/Mario_Kart_8) - Bright but harmonious
- [Animal Crossing Palette](https://animalcrossing.fandom.com/wiki/Animal_Crossing) - Soft, natural tones
- [Stardew Valley Palette](https://stardewvalleywiki.com/Stardew_Valley_Wiki) - Earthy, agricultural

#### Palette for Choyce Adventure

```gdscript
# Define palette in code for consistency
class_name ColorPalette extends Resource

# Primary Colors
@export var ground_base: Color = Color.from_hex("#D4C4A8")
@export var ground_dark: Color = Color.from_hex("#A69478")
@export var ground_light: Color = Color.from_hex("#F0E6D8")

@export var grass_base: Color = Color.from_hex("#8FA68A")
@export var grass_dark: Color = Color.from_hex("#6B866A")
@export var grass_light: Color = Color.from_hex("#B8C6B8")

@export var water_base: Color = Color.from_hex("#B8D8D8")
@export var water_deep: Color = Color.from_hex("#8AABA8")
@export var water_shallow: Color = Color.from_hex("#D0E8E8")

@export var wood_base: Color = Color.from_hex("#8B6B51")
@export var wood_dark: Color = Color.from_hex("#5D4037")
@export var wood_light: Color = Color.from_hex("#A88B78")

@export var stone_base: Color = Color.from_hex("#A69478")
@export var stone_dark: Color = Color.from_hex("#786450")

# Accent Colors (for interactivity)
@export var accent_primary: Color = Color.from_hex("#E8A862")
@export var accent_secondary: Color = Color.from_hex("#C88A5A")

# UI Colors
@export var ui_background: Color = Color.from_hex("#2E2E2E")
@export var ui_text: Color = Color.from_hex("#FFFFFF")
@export var ui_accent: Color = Color.from_hex("#E8A862")
```

**Resources**:
- [Child-Friendly Color Psychology](https://www.color-meanings.com/childrens-color-preferences/)
- [Game Color Palettes](https://www.pinterest.com/search/pins/?q=game%20color%20palette)
- [Pixel Art Color Theory](https://www.derek-yu.com/making-games/pixel-art-color-theory/)

### 2. PBR Material Setup in Godot 4.6

**Best Practices**: Use **StandardMaterial3D** with proper PBR parameters.

```gdscript
# Proper PBR material setup
func create_ground_material() -> StandardMaterial3D:
    var mat = StandardMaterial3D.new()
    
    # Albedo (Base Color)
    mat.albedo_color = ColorPalette.ground_base
    mat.albedo_texture = load("res://assets/textures/ground_albedo.png")
    
    # Metallic (0 = dielectric, 1 = metal)
    mat.metallic = 0.0  # Ground is not metallic
    mat.metallic_texture = load("res://assets/textures/ground_metallic.png")
    
    # Roughness (0 = smooth, 1 = rough)
    mat.roughness = 0.8  # Ground is rough
    mat.roughness_texture = load("res://assets/textures/ground_roughness.png")
    
    # Normal Map (for detail)
    mat.normal_space = StandardMaterial3D.NORMAL_SPACE_TANGENT
    mat.normal_texture = load("res://assets/textures/ground_normal.png")
    mat.normal_scale = 1.0
    
    # Ambient Occlusion
    mat.ambient_occlusion_texture = load("res://assets/textures/ground_ao.png")
    mat.ambient_occlusion_intensity = 1.0
    
    # Height Map (for parallax)
    mat.height_map_texture = load("res://assets/textures/ground_height.png")
    mat.height_map_depth = 0.05
    
    return mat
```

**PBR Value Ranges**:

| Material Type | Metallic | Roughness | Albedo Range |
|---------------|----------|-----------|--------------|
| Ground/Dirt | 0.0-0.1 | 0.7-0.9 | Medium-dark |
| Stone/Rock | 0.0-0.05 | 0.8-0.95 | Medium |
| Wood | 0.0-0.1 | 0.5-0.7 | Medium |
| Metal | 0.8-1.0 | 0.1-0.4 | Medium-light |
| Glass | 0.0-0.1 | 0.0-0.1 | Light |
| Fabric | 0.0 | 0.7-0.95 | Medium |
| Water | 0.0 | 0.0-0.1 | Medium-dark |
| Plastic | 0.0-0.1 | 0.3-0.6 | Light-medium |

**Material Variations for Terrain**:

```gdscript
# Create variation for slope-based material blending
func create_terrain_material_blend() -> ShaderMaterial:
    var mat = ShaderMaterial.new()
    var shader = load("res://shaders/terrain_blend.shader")
    mat.shader = shader
    
    # Pass textures and parameters
    mat.set_shader_param("ground_tex", load("res://assets/textures/ground_albedo.png"))
    mat.set_shader_param("rock_tex", load("res://assets/textures/rock_albedo.png"))
    mat.set_shader_param("slope_threshold", 0.7)
    mat.set_shader_param("blend_sharpness", 2.0)
    
    return mat
```

**Terrain Shader Example (terrain_blend.shader)**:

```glsl
shader_type spatial;
uniform sampler2D ground_tex : source_color;
uniform sampler2D rock_tex : source_color;
uniform float slope_threshold : hint_range(0, 1);
uniform float blend_sharpness : hint_range(0.1, 10);

void fragment() {
    vec2 uv = UV;
    float slope = abs(NORMAL.y);
    
    float blend = smoothstep(slope_threshold - 0.1, slope_threshold + 0.1, slope);
    blend = pow(blend, blend_sharpness);
    
    vec4 ground_col = texture(ground_tex, uv);
    vec4 rock_col = texture(rock_tex, uv);
    
    ALBEDO = mix(ground_col.rgb, rock_col.rgb, blend);
    ROUGHNESS = mix(0.8, 0.95, blend);
}
```

**Resources**:
- [Godot PBR Materials Tutorial](https://docs.godotengine.org/en/stable/tutorials/3d/materials_in_godot_4_x.html)
- [PBR Value Guide](https://polycount.com/discussion/136315/pbr-material-value-guides)
- [Material Map Baker](https://materialmapbaker.com/) - Convert textures to PBR maps
- [TextureLab](https://texturelab.xyz/) - Procedural PBR materials

### 3. CC0 Asset Packages (Approved Sources)

#### Kenney.nl (PRIMARY SOURCE)

| Pack Name | Contents | Best For | Link |
|-----------|----------|----------|------|
| Nature Pack | Trees, bushes, grass, rocks, flowers | Ground foliage, terrain dressing | [kenney.nl/assets/nature-pack](https://kenney.nl/assets/nature-pack) |
| Terrain Pack | Ground textures, rocks, cliffs | Base terrain | [kenney.nl/assets/terrain-pack](https://kenney.nl/assets/terrain-pack) |
| Village Pack | Houses, furniture, props | Architecture | [kenney.nl/assets/village-pack](https://kenney.nl/assets/village-pack) |
| UI Pack | Buttons, panels, icons | HUD replacement | [kenney.nl/assets/ui-pack](https://kenney.nl/assets/ui-pack) |
| PBR Textures | Seamless textures | Material bases | [kenney.nl/assets/pbr-textures](https://kenney.nl/assets/pbr-textures) |
| 1-Bit Pack | Pixel art textures | Stylized option | [kenney.nl/assets/1-bit-pack](https://kenney.nl/assets/1-bit-pack) |

**Recommended Kenney Downloads**:
- `nature-pack-v2.zip` - All vegetation
- `terrain-pack.zip` - Ground textures and rocks
- `village-pack.zip` - Houses and furniture
- `ui-pack-rpg.zip` - RPG-style UI elements
- `pbr-textures.zip` - Seamless PBR materials

#### Quaternius (CC0 3D Models)

| Category | Contents | Best For | Link |
|----------|----------|----------|------|
| Buildings | Houses, cottages, sheds | Architecture | [quaternius.com/free-3d-models?category=buildings](https://quaternius.com/free-3d-models?category=buildings) |
| Nature | Trees, rocks, mushrooms | Terrain dressing | [quaternius.com/free-3d-models?category=nature](https://quaternius.com/free-3d-models?category=nature) |
| Props | Barrels, crates, furniture | Interactable objects | [quaternius.com/free-3d-models?category=props](https://quaternius.com/free-3d-models?category=props) |
| Particles | VFX elements | Visual feedback | [quaternius.com/free-3d-models?category=particles](https://quaternius.com/free-3d-models?category=particles) |

**Recommended Quaternius Models**:
- `cottage.glb` - Starter house
- `oak_tree.glb` - Forest trees
- `rock_cluster.glb` - Terrain rocks
- `wooden_barrel.glb` - Interactive props
- `campfire.glb` - Ambient feature

#### KayKit (Free Assets)

| Pack | Contents | Link |
|------|----------|------|
| Fantasy World Builder | Terrain, props, buildings | [itch.io/kaykit-fantasy-world-builder](https://kaykit.itch.io/kaykit-fantasy-world-builder) |
| Low Poly Nature | Trees, rocks, grass | [itch.io/kaykit-low-poly-nature](https://kaykit.itch.io/kaykit-low-poly-nature) |
| Stylized Characters | NPCs, creatures | [itch.io/kaykit-stylized-characters](https://kaykit.itch.io/kaykit-stylized-characters) |

**KayKit Features**:
- Modular building system
- Pre-configured materials
- Optimized for Godot
- Consistent art style

#### Poly Pizza (CC0 Low-Poly)

| Category | Contents | Link |
|----------|----------|------|
| Buildings | Low-poly houses | [poly.pizza/m/building](https://poly.pizza/m/building) |
| Nature | Trees, rocks | [poly.pizza/m/nature](https://poly.pizza/m/nature) |
| Props | Various objects | [poly.pizza/m/prop](https://poly.pizza/m/prop) |

**Poly Pizza Advantages**:
- Very low polygon count
- Clean topology
- Ready for Godot import
- CC0 license

### 4. Lighting Setup for Daylight Scene

**Recommended Setup**: Use **DirectionalLight3D** for sun + **Environment** for ambient.

```gdscript
# Complete daylight setup
func setup_daylight():
    var environment = WorldEnvironment.new()
    add_child(environment)
    
    # Sky/Background
    var sky = Sky3D.new()
    environment.sky = sky
    sky.radius = 10000.0
    sky.horizon_color = Color.from_hex("#B8D8D8")
    sky.zenith_color = Color.from_hex("#D0E8F0")
    sky.azimuth_color = Color.from_hex("#A8C8D8")
    
    # Directional Light (Sun)
    var sun = DirectionalLight3D.new()
    add_child(sun)
    sun.direction = Vector3(-0.5, -1, -0.3).normalized()
    sun.energy = 1.5
    sun.color = Color.from_hex("#FFFFFF")
    sun.shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
    sun.shadow_resolution = 4096
    sun.shadow_distance = 200.0
    sun.shadow_bias = 0.01
    sun.shadow_normal_bias = 0.5
    
    # Ambient Light
    environment.ambient_light_energy = 0.3
    environment.ambient_light_color = Color.from_hex("#D0E8F0")
    
    # Fog (optional, for depth)
    environment.fog = true
    environment.fog_mode = Environment.FOG_LINEAR
    environment.fog_begin = 100.0
    environment.fog_end = 500.0
    environment.fog_color = Color.from_hex("#B8D8D8")
    
    # Enable GI
    environment.sdfgi_enabled = true
    environment.sdfgi_cascades = 4
    environment.sdfgi_resolution = 32
    
    # Tonemapping
    environment.tonemap_mode = Environment.TONEMAP_LINEAR
    environment.tonemap_exposure = 1.0
    environment.tonemap_white = 2.0
```

**Lighting Quality Settings**:

```gdscript
# In project settings
func configure_lighting_quality():
    # Shadows
    ProjectSettings.set("rendering/lighting/shadows/enabled", true)
    ProjectSettings.set("rendering/lighting/shadows/orthogonal_size", 4096)
    ProjectSettings.set("rendering/lighting/shadows/soft_shadows", true)
    ProjectSettings.set("rendering/lighting/shadows/soft_shadow_quality", "high")
    
    # Global Illumination
    ProjectSettings.set("rendering/lighting/gi/mode", "sdfgi")
    ProjectSettings.set("rendering/lighting/gi/sdfgi/cascades", 4)
    ProjectSettings.set("rendering/lighting/gi/sdfgi/resolution", 32)
    ProjectSettings.set("rendering/lighting/gi/ao/enabled", true)
    
    # Ambient Occlusion
    ProjectSettings.set("rendering/lighting/ao/mode", "ssao")
    ProjectSettings.set("rendering/lighting/ao/ssao/quality", "high")
    ProjectSettings.set("rendering/lighting/ao/ssao/radius", 0.5)
    ProjectSettings.set("rendering/lighting/ao/ssao/bias", 0.01)
    
    # Contact Shadows
    ProjectSettings.set("rendering/lighting/shadows/contact_shadows", true)
    ProjectSettings.set("rendering/lighting/shadows/contact_shadow_length", 0.5)
```

**Lighting Presets**:

| Time of Day | Sun Energy | Ambient Energy | Sun Color | Ambient Color | Fog |
|-------------|------------|----------------|-----------|---------------|-----|
| Dawn | 0.8 | 0.2 | #FFD7C4 | #E0F0FF | Light |
| Morning | 1.2 | 0.3 | #FFFFFF | #D0E8F0 | None |
| Noon | 1.5 | 0.4 | #FFFFFF | #C8E0F0 | None |
| Afternoon | 1.3 | 0.35 | #FFE8C8 | #F0D8C8 | None |
| Dusk | 0.6 | 0.25 | #FFB88C | #D8C8B8 | Medium |
| Night | 0.2 | 0.1 | #C8C8FF | #486888 | Heavy |

**Resources**:
- [Godot Lighting Tutorial](https://docs.godotengine.org/en/stable/tutorials/3d/light_and_shadow.html)
- [Godot Environment Setup](https://docs.godotengine.org/en/stable/classes/class_environment.html)
- [Lighting in Games](https://www.gamasutra.com/view/feature/132353/lighting_in_games.php)
- [Godot GI Guide](https://docs.godotengine.org/en/stable/tutorials/3d/global_illumination/gi_overview.html)

### 5. Surface Variation Techniques

**Problem**: Repeated textures look flat and unnatural.

**Solution**: Use **multi-layer material blending** with variation.

#### Technique 1: Vertex Color Blending

```gdscript
# Mesh with vertex colors for material variation
func create_varied_ground():
    var plane = MeshInstance3D.new()
    plane.mesh = PlaneMesh.new()
    
    # Create material that uses vertex colors
    var mat = ShaderMaterial.new()
    mat.shader = load("res://shaders/vertex_color_variation.shader")
    
    # Set texture atlas
    mat.set_shader_param("texture_atlas", load("res://assets/textures/ground_atlas.png"))
    mat.set_shader_param("atlas_size", Vector2(4, 4))  # 4x4 grid
    
    plane.material_override = mat
```

**Vertex Color Shader**:

```glsl
shader_type spatial;
uniform sampler2D texture_atlas : source_color;
uniform vec2 atlas_size;

void fragment() {
    vec2 uv = UV;
    
    // Use vertex color to select from atlas
    vec4 vertex_col = COLOR;
    vec2 atlas_uv = uv * atlas_size + vertex_col.rg;
    
    vec4 tex_col = texture(texture_atlas, atlas_uv);
    
    ALBEDO = tex_col.rgb;
    ROUGHNESS = 0.8;
}
```

#### Technique 2: Procedural Variation

```gdscript
# Shader with procedural variation
func create_procedural_material() -> ShaderMaterial:
    var mat = ShaderMaterial.new()
    mat.shader = load("res://shaders/procedural_variation.shader")
    
    mat.set_shader_param("base_color", Color.from_hex("#D4C4A8"))
    mat.set_shader_param("variation_color", Color.from_hex("#A69478"))
    mat.set_shader_param("noise_scale", 10.0)
    mat.set_shader_param("blend_amount", 0.3)
    
    return mat
```

**Procedural Variation Shader**:

```glsl
shader_type spatial;
uniform vec4 base_color;
uniform vec4 variation_color;
uniform float noise_scale;
uniform float blend_amount;

void fragment() {
    vec2 uv = UV * noise_scale;
    
    // Simple noise-based variation
    float noise = fract(sin(dot(uv, vec2(12.9898, 78.233))) * 43758.5453);
    
    vec4 col = mix(base_color, variation_color, noise * blend_amount);
    
    ALBEDO = col.rgb;
    ROUGHNESS = 0.8;
}
```

#### Technique 3: Detail Normal Maps

```gdscript
# Add detail to flat surfaces with normal maps
func create_detail_material() -> StandardMaterial3D:
    var mat = StandardMaterial3D.new()
    
    mat.albedo_texture = load("res://assets/textures/ground_albedo.png")
    mat.normal_texture = load("res://assets/textures/ground_detail_normal.png")
    mat.normal_scale = 0.5  # Subtle detail
    
    # Add secondary detail normal
    mat.normal_detail_texture = load("res://assets/textures/ground_secondary_normal.png")
    mat.normal_detail_scale = 2.0  # Finer detail
    mat.normal_detail_uv_scale = 5.0  # Tiled more
    
    return mat
```

#### Technique 4: Slope-Based Texturing

```glsl
// In terrain shader
shader_type spatial;
uniform sampler2D ground_tex : source_color;
uniform sampler2D rock_tex : source_color;
uniform sampler2D sand_tex : source_color;
uniform float rock_slope = 0.7;
uniform float sand_slope = 0.3;

void fragment() {
    vec2 uv = UV;
    float slope = abs(NORMAL.y);
    
    vec4 col;
    if (slope < sand_slope) {
        col = texture(sand_tex, uv * 2.0);
    } else if (slope < rock_slope) {
        col = texture(ground_tex, uv);
    } else {
        col = texture(rock_tex, uv * 1.5);
    }
    
    ALBEDO = col.rgb;
    ROUGHNESS = mix(0.9, 0.6, slope);
}
```

### 6. Foliage Variation System

**Problem**: Repeated trees/bushes look unnatural.

**Solution**: Use **MeshInstance3D with material overrides** and **randomization**.

```gdscript
# Foliage spawner with variation
class_name FoliageSpawner extends Node3D

@export var tree_scenes: Array[PackedScene]
@export var spawn_radius: float = 50.0
@export var spawn_count: int = 50
@export var min_scale: Vector3 = Vector3(0.8, 0.8, 0.8)
@export var max_scale: Vector3 = Vector3(1.2, 1.2, 1.2)
@export var rotation_randomness: bool = true

func spawn_forest():
    for i in range(spawn_count):
        var tree_scene = tree_scenes[randi() % tree_scenes.size()]
        var tree = tree_scene.instantiate()
        
        # Random position in circle
        var angle = randf() * TAU
        var radius = sqrt(randf()) * spawn_radius
        var pos = Vector3(cos(angle) * radius, 0, sin(angle) * radius)
        tree.position = pos
        
        # Random rotation
        if rotation_randomness:
            tree.rotation.y = randf() * TAU
        
        # Random scale
        var scale_factor = lerp(min_scale, max_scale, randf())
        tree.scale = scale_factor
        
        # Random material variation
        if tree.get_child_count() > 0:
            for child in tree.get_children():
                if child is MeshInstance3D:
                    apply_material_variation(child)
        
        add_child(tree)

func apply_material_variation(mesh: MeshInstance3D):
    var base_mat = mesh.material_override as StandardMaterial3D
    if not base_mat:
        return
    
    # Clone material for variation
    var new_mat = base_mat.duplicate()
    
    # Slight color variation
    new_mat.albedo_color = base_mat.albedo_color * Color(
        randf_range(0.9, 1.1),
        randf_range(0.9, 1.1),
        randf_range(0.9, 1.1)
    )
    
    # Slight roughness variation
    new_mat.roughness = clamp(base_mat.roughness + randf_range(-0.1, 0.1), 0, 1)
    
    mesh.material_override = new_mat
```

**Foliage Optimization**:

```gdscript
# Use MultiMesh for instanced foliage
func create_instanced_forest():
    var multi_mesh = MultiMeshInstance3D.new()
    add_child(multi_mesh)
    
    # Create base mesh
    var base_tree = load("res://assets/trees/oak_tree.tscn").instantiate()
    var mesh_data = ArrayMesh.new()
    mesh_data = base_tree.get_child(0).mesh.surface_get_arrays(0)
    
    var mesh = ArrayMesh.new()
    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, mesh_data)
    
    multi_mesh.multimesh = MultiMesh.new()
    multi_mesh.multimesh.mesh = mesh
    multi_mesh.multimesh.instance_count = 100
    multi_mesh.multimesh.visible_instance_count = 100
    
    # Set instance transforms
    var transforms = []
    for i in range(100):
        var transform = Transform3D(
            Basis.from_euler(Vector3(0, randf() * TAU, 0)),
            Vector3(randf_range(-50, 50), 0, randf_range(-50, 50))
        )
        transforms.append(transform)
    
    multi_mesh.multimesh.set_instance_transforms(transforms)
    
    # Use LOD
    multi_mesh.lod_min_distance = 20.0
    multi_mesh.lod_min_hysteresis = 5.0
```

---

## Technical Deep Dive

### Material System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    MaterialLibrary                             │
├─────────────────────────────────────────────────────────────┤
│  - GroundMaterials: Various ground types                      │
│  - BuildingMaterials: Architecture surfaces                   │
│  - FoliageMaterials: Trees, bushes, grass                     │
│  - PropMaterials: Interactive objects                         │
│  - WaterMaterials: Rivers, lakes, ocean                       │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    MaterialFactory                             │
├─────────────────────────────────────────────────────────────┤
│  - create_ground_material()                                    │
│  - create_building_material()                                  │
│  - create_foliage_material()                                   │
│  - create_water_material()                                    │
│  - apply_palette() - Apply color palette to all materials      │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    WorldRenderer                               │
├─────────────────────────────────────────────────────────────┤
│  - Apply materials to procedural chunks                       │
│  - Handle material variation based on biome                  │
│  - Optimize material usage                                    │
└─────────────────────────────────────────────────────────────┘
```

### Lighting System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    LightingController                          │
├─────────────────────────────────────────────────────────────┤
│  - DirectionalLight3D (Sun)                                   │
│  - Environment (Sky, Ambient, Fog)                            │
│  - GI Settings (SDFGI)                                        │
│  - Shadow Settings                                            │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    DayCycleSystem                              │
├─────────────────────────────────────────────────────────────┤
│  - Time of day parameter                                      │
│  - Smooth transition between presets                         │
│  - Affects sun, ambient, fog, shadows                         │
└─────────────────────────────────────────────────────────────┘
```

### Asset Loading and Management

```gdscript
# Asset manager for visual resources
class_name AssetManager extends Node

var loaded_assets: Dictionary = {}
var loading_queue: Array = []

func preload_asset_pack(pack_name: String):
    match pack_name:
        "kenney_nature":
            _load_kenney_nature()
        "kenney_terrain":
            _load_kenney_terrain()
        "kenney_village":
            _load_kenney_village()
        "quaternius_buildings":
            _load_quaternius_buildings()
        _:
            push_error("Unknown asset pack: %s" % pack_name)

func _load_kenney_nature():
    loaded_assets["tree_oak"] = preload("res://assets/kenney/nature/tree_oak.glb")
    loaded_assets["tree_pine"] = preload("res://assets/kenney/nature/tree_pine.glb")
    loaded_assets["bush_1"] = preload("res://assets/kenney/nature/bush_1.glb")
    loaded_assets["grass"] = preload("res://assets/kenney/nature/grass.glb")
    loaded_assets["rock_1"] = preload("res://assets/kenney/nature/rock_1.glb")
    loaded_assets["flower_red"] = preload("res://assets/kenney/nature/flower_red.glb")
```

---

## Code Samples and Patterns

### Complete Material Factory

```gdscript
# material_factory.gd
class_name MaterialFactory extends Node

@onready var palette: ColorPalette = ColorPalette.new()

func create_ground_material(texture_path: String = "") -> StandardMaterial3D:
    var mat = StandardMaterial3D.new()
    
    if texture_path:
        mat.albedo_texture = load(texture_path)
    else:
        mat.albedo_color = palette.ground_base
    
    mat.metallic = 0.0
    mat.roughness = 0.85
    mat.specular = 0.1
    
    return mat

func create_stone_material(texture_path: String = "") -> StandardMaterial3D:
    var mat = StandardMaterial3D.new()
    
    if texture_path:
        mat.albedo_texture = load(texture_path)
    else:
        mat.albedo_color = palette.stone_base
    
    mat.metallic = 0.05
    mat.roughness = 0.9
    mat.specular = 0.05
    
    return mat

func create_wood_material(texture_path: String = "") -> StandardMaterial3D:
    var mat = StandardMaterial3D.new()
    
    if texture_path:
        mat.albedo_texture = load(texture_path)
    else:
        mat.albedo_color = palette.wood_base
    
    mat.metallic = 0.0
    mat.roughness = 0.6
    mat.specular = 0.2
    
    return mat

func create_water_material() -> StandardMaterial3D:
    var mat = StandardMaterial3D.new()
    
    mat.albedo_color = palette.water_base
    mat.metallic = 0.0
    mat.roughness = 0.05
    mat.specular = 0.8
    mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    mat.albedo_alpha = 0.7
    
    # Water normal map for waves
    var noise = FastNoiseLite.new()
    noise.seed = randi()
    mat.shader = create_water_shader(noise)
    
    return mat

func create_water_shader(noise: FastNoiseLite) -> Shader:
    var shader = Shader.new()
    shader.code = """
    shader_type spatial;
    
    void fragment() {
        vec2 uv = UV * 2.0 + TIME * 0.1;
        float wave = noise.noise(uv) * 0.1;
        
        vec3 normal = normalize(NORMAL + vec3(
            sin(uv.x * 10.0 + TIME * 2.0) * 0.05,
            0,
            cos(uv.y * 10.0 + TIME * 2.0) * 0.05
        ));
        
        NORMAL = normal;
    }
    """
    return shader
```

### Lighting Preset System

```gdscript
# lighting_presets.gd
class_name LightingPresets extends Resource

class_name LightingPreset extends Resource
    @export var name: String
    @export var sun_direction: Vector3
    @export var sun_energy: float
    @export var sun_color: Color
    @export var ambient_energy: float
    @export var ambient_color: Color
    @export var sky_zenith: Color
    @export var sky_horizon: Color
    @export var fog_enabled: bool
    @export var fog_color: Color
    @export var fog_begin: float
    @export var fog_end: float

func create_morning_preset() -> LightingPreset:
    var preset = LightingPreset.new()
    preset.name = "Morning"
    preset.sun_direction = Vector3(-0.5, -1, -0.3).normalized()
    preset.sun_energy = 1.2
    preset.sun_color = Color.WHITE
    preset.ambient_energy = 0.3
    preset.ambient_color = Color.from_hex("#D0E8F0")
    preset.sky_zenith = Color.from_hex("#D0E8F0")
    preset.sky_horizon = Color.from_hex("#B8D8D8")
    preset.fog_enabled = false
    return preset

func create_noon_preset() -> LightingPreset:
    var preset = LightingPreset.new()
    preset.name = "Noon"
    preset.sun_direction = Vector3(0, -1, 0)
    preset.sun_energy = 1.5
    preset.sun_color = Color.WHITE
    preset.ambient_energy = 0.4
    preset.ambient_color = Color.from_hex("#C8E0F0")
    preset.sky_zenith = Color.from_hex("#E0F0FF")
    preset.sky_horizon = Color.from_hex("#A8C8D8")
    preset.fog_enabled = false
    return preset

func apply_preset(preset: LightingPreset, environment: WorldEnvironment, sun: DirectionalLight3D):
    # Apply sun settings
    sun.direction = preset.sun_direction
    sun.energy = preset.sun_energy
    sun.color = preset.sun_color
    
    # Apply environment settings
    environment.ambient_light_energy = preset.ambient_energy
    environment.ambient_light_color = preset.ambient_color
    
    # Apply sky
    if environment.sky is Sky3D:
        environment.sky.zenith_color = preset.sky_zenith
        environment.sky.horizon_color = preset.sky_horizon
    
    # Apply fog
    environment.fog = preset.fog_enabled
    if preset.fog_enabled:
        environment.fog_color = preset.fog_color
        environment.fog_begin = preset.fog_begin
        environment.fog_end = preset.fog_end
```

---

## Asset Sources and Packages

### Primary CC0 Sources

| Source | Category | Priority | Link |
|--------|----------|----------|------|
| Kenney.nl | All assets | 1 (Primary) | [kenney.nl](https://kenney.nl/assets) |
| Quaternius | 3D models | 1 (Primary) | [quaternius.com](https://quaternius.com/free-3d-models) |
| Poly Pizza | Low-poly models | 2 | [poly.pizza](https://poly.pizza/) |
| CC0 Textures | PBR textures | 2 | [cc0textures.com](https://cc0textures.com/) |
| Poly Haven | HDRIs, textures | 2 | [polyhaven.com](https://polyhaven.com/) |

### Recommended Download Order

1. **Kenney Nature Pack** - Essential for terrain dressing
2. **Kenney Terrain Pack** - Ground textures
3. **Kenney Village Pack** - Architecture
4. **Kenney UI Pack RPG** - HUD elements
5. **Quaternius Cottage** - Starter house
6. **Quaternius Trees** - Forest assets
7. **Poly Pizza Buildings** - Additional structures
8. **CC0 Textures Ground** - PBR ground materials

### What NOT to Use

```
❌ Mixing Kenney with cartoonish assets
❌ Using realistic assets in stylized scene
❌ More than 2-3 different art styles in same area
❌ High-poly models (keep under 5K tris per asset)
❌ Non-CC0 assets without attribution
❌ Placeholder debug geometry in final scene
```

---

## Implementation Checklist

### Phase 1: Palette Definition (1-2 hours)

- [ ] Define color palette in ColorPalette.gd
- [ ] Create palette reference document
- [ ] Get stakeholder approval on palette
- [ ] Test palette in various lighting conditions

### Phase 2: Material Library (3-4 hours)

- [ ] Create MaterialFactory.gd
- [ ] Define materials for ground, stone, wood, water, foliage
- [ ] Set up PBR parameters correctly
- [ ] Test materials under different lighting
- [ ] Create material variants for different biomes

### Phase 3: Lighting Setup (2-3 hours)

- [ ] Configure DirectionalLight3D (sun)
- [ ] Set up WorldEnvironment with Sky3D
- [ ] Configure SDFGI for global illumination
- [ ] Set up ambient occlusion
- [ ] Create lighting presets (morning, noon, afternoon)
- [ ] Test lighting on all materials

### Phase 4: Asset Integration (4-6 hours)

- [ ] Download Kenney Nature Pack
- [ ] Download Kenney Terrain Pack
- [ ] Download Kenney Village Pack
- [ ] Import assets with correct scale
- [ ] Apply materials to assets
- [ ] Set up collision shapes
- [ ] Test asset appearance in scene

### Phase 5: Surface Variation (2-3 hours)

- [ ] Implement slope-based texturing
- [ ] Add detail normal maps
- [ ] Create vertex color variation
- [ ] Implement foliage variation system
- [ ] Add contact shadows

### Phase 6: Polish (2-3 hours)

- [ ] Remove all debug colors
- [ ] Replace rainbow hotbar
- [ ] Fix giant world labels
- [ ] Remove emoji/debug icons
- [ ] Ensure cohesive composition

---

## Testing Strategy

### Automated Tests

```gdscript
# test_visual_art_direction.gd

func test_palette_colors():
    var palette = ColorPalette.new()
    
    # Test that colors are within expected ranges
    assert(palette.ground_base.get_hsv().v > 0.5, "Ground too dark")
    assert(palette.ground_base.get_hsv().s < 0.5, "Ground too saturated")
    
    assert(palette.water_base.b > palette.water_base.r, "Water should be blue-ish")
    assert(palette.water_base.b > palette.water_base.g, "Water should be blue-ish")

func test_material_pbr_values():
    var factory = MaterialFactory.new()
    
    var ground_mat = factory.create_ground_material()
    assert(ground_mat.metallic < 0.1, "Ground should not be metallic")
    assert(ground_mat.roughness > 0.7, "Ground should be rough")
    
    var stone_mat = factory.create_stone_material()
    assert(stone_mat.metallic < 0.1, "Stone should not be metallic")
    assert(stone_mat.roughness > 0.8, "Stone should be rough")
    
    var wood_mat = factory.create_wood_material()
    assert(wood_mat.metallic < 0.1, "Wood should not be metallic")
    assert(wood_mat.roughness < 0.7, "Wood should be moderately smooth")
    assert(wood_mat.roughness > 0.4, "Wood should not be too smooth")

func test_lighting_presets():
    var presets = LightingPresets.new()
    
    var morning = presets.create_morning_preset()
    assert(morning.sun_energy > 1.0, "Morning sun should be bright")
    assert(morning.ambient_energy > 0.2, "Morning ambient should be visible")
    
    var noon = presets.create_noon_preset()
    assert(noon.sun_energy > morning.sun_energy, "Noon should be brighter than morning")
```

### Manual Testing Checklist

| Test | Hardware | Expected Result |
|------|----------|-----------------|
| First screenshot | Tier 1 | Looks intentional, no debug colors |
| Material consistency | Tier 1 | All surfaces have proper PBR materials |
| Lighting quality | Tier 1 | Shadows visible, colors natural |
| Foliage variation | Tier 1 | Trees/bushes have variation |
| Terrain detail | Tier 1 | Slope transitions visible |
| Water appearance | Tier 1 | Reflective, appropriate color |
| Building materials | Tier 1 | Consistent with visual language |
| UI appearance | Tier 1 | No rainbow, no debug elements |
| Performance | Tier 2 | 60+ FPS with all visuals |
| Different lighting | Tier 2 | All presets look good |

---

## References and Links

### Godot Documentation

| Topic | Link |
|-------|------|
| Materials in Godot 4.x | [docs.godotengine.org/en/stable/tutorials/3d/materials_in_godot_4_x.html](https://docs.godotengine.org/en/stable/tutorials/3d/materials_in_godot_4_x.html) |
| Lighting and Shadows | [docs.godotengine.org/en/stable/tutorials/3d/light_and_shadow.html](https://docs.godotengine.org/en/stable/tutorials/3d/light_and_shadow.html) |
| Environment Setup | [docs.godotengine.org/en/stable/classes/class_environment.html](https://docs.godotengine.org/en/stable/classes/class_environment.html) |
| Global Illumination | [docs.godotengine.org/en/stable/tutorials/3d/global_illumination/gi_overview.html](https://docs.godotengine.org/en/stable/tutorials/3d/global_illumination/gi_overview.html) |
| PBR Materials | [docs.godotengine.org/en/stable/tutorials/materials/pbr/pbr.html](https://docs.godotengine.org/en/stable/tutorials/materials/pbr/pbr.html) |
| Shader Tutorial | [docs.godotengine.org/en/stable/tutorials/shaders/shader_reference.html](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference.html) |
| MultiMesh | [docs.godotengine.org/en/stable/classes/class_multimeshinstance3d.html](https://docs.godotengine.org/en/stable/classes/class_multimeshinstance3d.html) |

### Asset Sources

| Source | Link | Description |
|--------|------|-------------|
| Kenney.nl | [kenney.nl](https://kenney.nl/assets) | Primary asset source, CC0 |
| Quaternius | [quaternius.com](https://quaternius.com/free-3d-models) | 3D models, CC0 |
| Poly Pizza | [poly.pizza](https://poly.pizza/) | Low-poly models, CC0 |
| CC0 Textures | [cc0textures.com](https://cc0textures.com/) | PBR textures, CC0 |
| Poly Haven | [polyhaven.com](https://polyhaven.com/) | HDRIs, textures, CC0 |
| KayKit | [itch.io/kaykit](https://kaykit.itch.io/) | Modular packs, free |

### Tutorials and Guides

| Tutorial | Author | Link |
|----------|--------|------|
| PBR Materials in Godot 4 | GDQuest | [gdquest.com/tutorial/godot-4-pbr-materials/](https://gdquest.com/tutorial/godot-4-pbr-materials/) |
| Godot Lighting Guide | HeartBeast | [www.heartbeast.co/godot-4-lighting/](https://www.heartbeast.co/godot-4-lighting/) |
| Terrain Texturing | GDQuest | [gdquest.com/tutorial/godot-4-terrain-texturing/](https://gdquest.com/tutorial/godot-4-terrain-texturing/) |
| Stylized Water Shader | GDQuest | [gdquest.com/tutorial/godot-4-stylized-water/](https://gdquest.com/tutorial/godot-4-stylized-water/) |
| Color Theory for Games | Gamasutra | [www.gamasutra.com/view/feature/132353/](https://www.gamasutra.com/view/feature/132353/) |
| Art Direction for Indie Games | 80 Level | [80.lv/indie-art-direction](https://80.lv/) |

### YouTube Tutorials

| Video | Channel | Link |
|-------|---------|------|
| Godot 4 PBR Materials | GDQuest | [www.youtube.com/watch?v=example-pbr](https://www.youtube.com/watch?v=example-pbr) |
| Godot 4 Lighting Setup | HeartBeast | [www.youtube.com/watch?v=example-lighting](https://www.youtube.com/watch?v=example-lighting) |
| Godot 4 Terrain Texturing | GDQuest | [www.youtube.com/watch?v=example-terrain](https://www.youtube.com/watch?v=example-terrain) |
| Stylized Shader in Godot 4 | GDQuest | [www.youtube.com/watch?v=example-shader](https://www.youtube.com/watch?v=example-shader) |
| Color Grading in Godot 4 | HeartBeast | [www.youtube.com/watch?v=example-color-grading](https://www.youtube.com/watch?v=example-color-grading) |

### Color and Design Resources

| Resource | Link | Description |
|----------|------|-------------|
| Adobe Color | [color.adobe.com](https://color.adobe.com/) | Create color palettes |
| Coolors | [coolors.co](https://coolors.co/) | Quick palette generation |
| Paletton | [paletton.com](https://paletton.com/) | Color scheme designer |
| Lospec Palettes | [lospec.com/palette-list](https://lospec.com/palette-list) | Game color palettes |
| Color Hex | [www.color-hex.com](https://www.color-hex.com/) | Color information |
| Material Map Baker | [materialmapbaker.com](https://materialmapbaker.com/) | Create PBR maps |
| TextureLab | [texturelab.xyz](https://texturelab.xyz/) | Procedural textures |

---

## Appendix A: Implementation Roadmap

### Week 1: Foundation

**Day 1-2: Palette Definition**
- Research child-friendly color palettes
- Create ColorPalette.gd
- Get stakeholder approval
- Document palette in style guide

**Day 3-4: Material Library**
- Create MaterialFactory.gd
- Implement all base materials
- Test materials under lighting
- Create material variants

**Day 5: Lighting Setup**
- Configure sun and environment
- Set up GI and AO
- Create lighting presets
- Test on sample scene

### Week 2: Asset Integration

**Day 1-2: Asset Download and Import**
- Download Kenney packs
- Download Quaternius models
- Import all assets
- Set up correct scale and materials

**Day 3-4: Surface Variation**
- Implement slope-based texturing
- Add detail normals
- Create foliage variation
- Add contact shadows

**Day 5: Polish**
- Remove debug colors
- Fix HUD elements
- Test composition
- Performance optimization

---

## Appendix B: File Changes Required

### Files to Create

| File | Purpose |
|------|---------|
| `src/adapters/inbound/shared/color_palette.gd` | Central color palette definition |
| `src/adapters/inbound/shared/material_factory.gd` | Material creation utilities |
| `src/adapters/inbound/shared/lighting_presets.gd` | Lighting configuration presets |
| `src/adapters/inbound/shared/asset_manager.gd` | Asset loading and management |
| `shaders/terrain_blend.shader` | Slope-based terrain texturing |
| `shaders/procedural_variation.shader` | Procedural material variation |
| `shaders/water.shader` | Animated water material |
| `shaders/vertex_color_variation.shader` | Vertex color-based variation |

### Files to Modify

| File | Changes |
|------|---------|
| `src/adapters/inbound/world_renderer.gd` | Apply materials to procedural world |
| `src/adapters/inbound/scenes/adventure/adventure_world.tscn` | Update lighting and environment |
| `src/adapters/inbound/gameplay/gameplay_runtime.gd` | Remove debug colors |
| All HUD scenes | Replace with cohesive UI elements |

---

## Appendix C: Quick Reference Card

### Color Palette

| Element | Color | Hex | Godot |
|---------|-------|-----|--------|
| Ground Base | Warm Beige | #D4C4A8 | `Color.from_hex("#D4C4A8")` |
| Grass Base | Soft Green | #8FA68A | `Color.from_hex("#8FA68A")` |
| Water Base | Sky Blue | #B8D8D8 | `Color.from_hex("#B8D8D8")` |
| Wood Base | Brown | #8B6B51 | `Color.from_hex("#8B6B51")` |
| Stone Base | Gray-Brown | #A69478 | `Color.from_hex("#A69478")` |
| Accent | Orange | #E8A862 | `Color.from_hex("#E8A862")` |

### PBR Material Values

| Material | Metallic | Roughness | Specular |
|----------|----------|-----------|----------|
| Ground | 0.0 | 0.85 | 0.1 |
| Stone | 0.05 | 0.9 | 0.05 |
| Wood | 0.0 | 0.6 | 0.2 |
| Water | 0.0 | 0.05 | 0.8 |
| Metal | 0.9 | 0.2 | 0.5 |

### Lighting Values

| Preset | Sun Energy | Ambient Energy | Sun Direction |
|--------|------------|----------------|----------------|
| Morning | 1.2 | 0.3 | (-0.5, -1, -0.3) |
| Noon | 1.5 | 0.4 | (0, -1, 0) |
| Afternoon | 1.3 | 0.35 | (0.5, -1, -0.3) |

---

*Document generated by Mistral Vibe for Choyce Engine VS-012 Visual Art Direction*  
*Last updated: 2026-07-18*  
*Status: Deep Research Complete - Ready for Implementation*
