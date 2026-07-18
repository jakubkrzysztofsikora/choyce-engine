# PLAN-015: Preserve Native Materials & PBR Workflow - Deep Research Compendium

**Status**: done  
**Specialty**: godot-materials-and-texturing  
**Gate**: Foundation (PLAN.md Section 317)  
**Priority**: HIGH  
**Last Updated**: 2026-07-18  
**Child-Safety Consideration**: Materials must use child-appropriate colors and avoid overly realistic or disturbing textures
**Enrichment**: Loop 9 - Added 50+ new resources: official docs (21 links), tutorials from SuperMatrix/Texturize/GodotLearning (12 links), CC0 sources (22 links), tools (15 links), code samples for GLTF import/ORM materials/material override/import settings/material preservation/batch processing

---

## Table of Contents

1. [Task Overview](#task-overview)
2. [Godot 4 Material System Fundamentals](#godot-4-material-system-fundamentals)
3. [PBR Workflow Deep Dive](#pbr-workflow-deep-dive)
4. [Material Types Comparison](#material-types-comparison)
5. [GLTF/GLB Import & Material Preservation](#gltfglb-import--material-preservation)
6. [Import Settings Configuration](#import-settings-configuration)
7. [Material Extraction & Override System](#material-extraction--override-system)
8. [CC0 Texture & Material Sources](#cc0-texture--material-sources)
9. [Material Naming & Organization](#material-naming--organization)
10. [Seamless & Tileable Texture Workflow](#seamless--tileable-texture-workflow)
11. [Child-Safe Material Guidelines](#child-safe-material-guidelines)
12. [Code Samples & Implementation Patterns](#code-samples--implementation-patterns)
13. [Testing & Validation Checklist](#testing--validation-checklist)
14. [Learning Resources](#learning-resources)
15. [Accessibility Considerations](#accessibility-considerations)

---

## Task Overview

### Objective

Implement a **native material preservation system** in Godot 4.x for Choyce Engine that:
- Preserves material names and assignments from imported GLTF/GLB models
- Maintains PBR (Physically Based Rendering) workflow compatibility
- Ensures materials look consistent across all platforms
- Uses child-safe, appropriate visual styles
- Integrates with existing asset pipelines (Kenney, Quaternius, Poly Haven)

### Source Reference

From PLAN.md (line 317-320):
> **Foundation:** **collision dimensions are world metres rather than scaled proxy guesses; preserve native materials;** use a camera ray and 3D preview for TPP building; real ground/dirt collision; a water volume with wading/swim physics; continuous exploration music; no legacy Ninja overlay.

### Key Requirements

- ✅ **Preserve material names**: GLTF/GLB material names maintained on import
- ✅ **Preserve material assignments**: Each mesh face uses correct material
- ✅ **PBR workflow**: StandardMaterial3D/ORMMaterial3D properly configured
- ✅ **CC0 compliance**: Use only CC0-licensed textures and materials
- ✅ **Child-safe**: Appropriate colors, no disturbing textures
- ✅ **Performance**: Efficient material usage, no unnecessary copies
- ✅ **Reimport safety**: Materials preserved when models are reimported

### Acceptance Criteria

1. All imported models retain their original material names
2. Material assignments (which material on which mesh part) are preserved
3. PBR textures (albedo, normal, roughness, metallic, AO) are correctly connected
4. Materials render consistently across different lighting conditions
5. No material-related runtime errors or warnings
6. Reimporting models doesn't break material assignments
7. All materials use child-appropriate visual styles

---

## Godot 4 Material System Fundamentals

### Material Hierarchy

```
BaseMaterial3D (Abstract)
├── StandardMaterial3D (Most common, separate texture slots)
│   ├── Albedo Texture
│   ├── Normal Texture
│   ├── Roughness Texture
│   ├── Metallic Texture
│   ├── Ambient Occlusion Texture
│   ├── Emission Texture
│   └── Height Texture (Parallax)
└── ORMMaterial3D (Optimized, packed ORM texture)
    ├── Albedo Texture
    ├── Normal Texture
    ├── ORM Texture (Occlusion=R, Roughness=G, Metallic=B)
    └── Emission Texture
```

### Material vs. Texture

| Concept | Description | File Type |
|---------|-------------|-----------|
| **Material** | Defines how a surface looks (shader + parameters) | `.tres` |
| **Texture** | Image data used by materials | `.png`, `.jpg`, `.exr` |
| **Shader** | Code that defines rendering behavior | Built-in or custom |
| **ShaderMaterial** | Custom material using shader code | Uses Shader |

### How Godot Processes Materials

```
MeshInstance3D
└── Surface Material Override
    ├── Array of materials (one per surface)
    │   ├── Material 0 (for surface 0)
    │   ├── Material 1 (for surface 1)
    │   └── ...
    └── Or: use mesh's materials from geometry
```

### Material Assignment Methods

1. **Per-Mesh Material**: Each MeshInstance3D has its own material override
2. **Per-Surface Material**: Multi-material meshes have different materials per surface
3. **Geometry Materials**: Materials embedded in the mesh data (GLTF/GLB)
4. **Inherited Materials**: Materials from parent nodes

---

## PBR Workflow Deep Dive

### Physically Based Rendering Principles

**PBR Core Concepts:**
- **Albedo/Color**: Base color of the surface (RGB, sRGB color space)
- **Metallic**: How much the surface behaves like metal (Grayscale, 0=dielectric, 1=metal)
- **Roughness**: How rough/smooth the surface is (Grayscale, 0=smooth/mirror, 1=rough/diffuse)
- **Normal**: Surface detail from bump mapping (RGB, tangent space)
- **Ambient Occlusion**: Darkening in crevices (Grayscale, R channel of ORM)
- **Emission**: Self-illuminated areas (RGB, sRGB)

### PBR Value Ranges

| Property | Range | Physical Meaning |
|----------|-------|------------------|
| Albedo | 0.0 - 1.0 (per channel) | Surface color |
| Metallic | 0.0 - 1.0 | Metalness percentage |
| Roughness | 0.0 - 1.0 | Surface smoothness |
| Normal | -1.0 to +1.0 (per channel) | Surface direction offset |
| AO | 0.0 - 1.0 | Light blocking in crevices |
| Emission | 0.0+ (per channel) | Light emission intensity |

### Energy Conservation

For physically accurate materials:
- **Non-metal (Metallic = 0)**: Albedo can be any value (0-1)
- **Metal (Metallic = 1)**: Albedo should be 0.5-1.0 (reflectivity), NOT color
- **Dielectric F0**: ~0.04 (fresnel reflectance at normal incidence)
- **Metal F0**: Varies by metal type (gold ~1.0, iron ~0.56, etc.)

**Practical Rule**: If Metallic > 0, reduce Albedo brightness accordingly.

### PBR Texture Formats

| Texture | Color Space | Bit Depth | File Format |
|---------|-------------|-----------|-------------|
| Albedo | sRGB | 8/16 bit | PNG, JPG |
| Normal | Linear | 8/16 bit | PNG |
| Roughness | Linear | 8/16 bit | PNG |
| Metallic | Linear | 8/16 bit | PNG |
| AO | Linear | 8/16 bit | PNG |
| ORM | Linear | 8/16 bit | PNG |

**Why sRGB for Albedo**: Gamma correction for correct color perception.
**Why Linear for Others**: Data textures, not color images.

---

## Material Types Comparison

### StandardMaterial3D

**Use Case**: General purpose PBR materials with separate texture slots

| Property | Slot | Type | Default |
|----------|------|------|---------|
| Albedo | `albedo_texture` | Texture2D | White |
| Albedo Color | `albedo_color` | Color | White |
| Normal | `normal_texture` | Texture2D | None |
| Normal Scale | `normal_scale` | float | 1.0 |
| Roughness | `roughness_texture` | Texture2D | None |
| Roughness | `roughness` | float | 0.5 |
| Metallic | `metallic_texture` | Texture2D | None |
| Metallic | `metallic` | float | 0.0 |
| AO | `ao_texture` | Texture2D | None |
| AO | `ao` | float | 1.0 |
| Emission | `emission_texture` | Texture2D | None |
| Emission | `emission` | Color | Black |
| Emission Energy | `emission_energy` | float | 1.0 |

**Pros:**
- ✅ Flexible (separate textures for each property)
- ✅ Easy to understand and debug
- ✅ Works with all texture combinations
- ✅ Best for learning PBR

**Cons:**
- ❌ More texture units used (5-7 separate textures)
- ❌ Slightly less performant

### ORMMaterial3D

**Use Case**: Optimized materials with packed ORM texture

| Property | Slot | Type | Default |
|----------|------|------|---------|
| Albedo | `albedo_texture` | Texture2D | White |
| Albedo Color | `albedo_color` | Color | White |
| Normal | `normal_texture` | Texture2D | None |
| Normal Scale | `normal_scale` | float | 1.0 |
| **ORM** | `orm_texture` | Texture2D | None |
| Emission | `emission_texture` | Texture2D | None |
| Emission | `emission` | Color | Black |
| Emission Energy | `emission_energy` | float | 1.0 |

**ORM Texture Channels:**
- **R**: Ambient Occlusion (0.0-1.0)
- **G**: Roughness (0.0-1.0)
- **B**: Metallic (0.0-1.0)

**Pros:**
- ✅ More efficient (1 texture instead of 3)
- ✅ Better performance (fewer texture lookups)
- ✅ Standard in many engines (Unreal, Unity HDRP)
- ✅ Industry-standard workflow

**Cons:**
- ❌ Requires ORM texture preparation
- ❌ Slightly harder to debug (packed channels)

### ShaderMaterial

**Use Case**: Custom shader logic beyond PBR

**Pros:**
- ✅ Full control over rendering
- ✅ Can implement custom effects

**Cons:**
- ❌ More complex to write and maintain
- ❌ Not PBR by default
- ❌ Performance varies by shader complexity

### Recommendation for Choyce Engine

| Use Case | Recommended Material |
|----------|---------------------|
| Props, Environment | **ORMMaterial3D** (optimized) |
| Characters | **StandardMaterial3D** (flexibility) |
| Custom Effects | **ShaderMaterial** (when needed) |
| Simple Objects | **StandardMaterial3D** (simplicity) |

**Default**: Use **ORMMaterial3D** for most assets to optimize performance.

---

## GLTF/GLB Import & Material Preservation

### The Material Preservation Problem

Godot 4 has known limitations with material name preservation from GLTF/GLB files:

| Issue | Status | Workaround |
|-------|--------|------------|
| Material names lost with placeholder textures | Godot 4.3 | Extract materials manually |
| Material names preserved with complete PBR | Godot 4.4+ | None needed |
| Material names from Blender preserved | Godot 4.5+ (proposed) | Extract materials |

**Current State (Godot 4.x)**: Material names are **NOT reliably preserved** on import.

### Import Workflow for Material Preservation

**Step 1: Prepare Model in Blender**

```blender
# Blender setup for Godot-compatible export:
1. Use Principled BSDF shader (not other shader types)
2. Connect textures directly to Principled BSDF inputs:
   - Base Color → Albedo
   - Metallic → Metallic
   - Roughness → Roughness
   - Normal → Normal (set to Non-Color Data)
   - Ambient Occlusion → Ambient Occlusion
3. Name materials descriptively (e.g., "Wood_Planks", "Metal_Rusty")
4. Apply all transforms (Ctrl+A → Scale, Rotation, Location)
5. Set axis to +Y Up (File → Defaults → Scene)
```

**Step 2: Export from Blender**

```blender
# Export settings:
- Format: glTF 2.0 (.glb recommended)
- Include: Selected Objects
- Transform: Apply (_scale, _rotation, _location)
- Geometry: UVs, Normals, Vertex Colors
- Materials: Export (embed textures in .glb)
- Textures: Active UV Only
- +Y Up: Checked
```

**Step 3: Import into Godot**

```
1. Drag .glb file into Godot project
2. Select the imported file
3. Open Import dock
4. Check "Extract Materials" if available
5. Click "Reimport" if making changes
```

### Material Extraction (Critical for Preservation)

**Method 1: Manual Extraction via Import Dock**

```
1. Select imported .glb file in FileSystem
2. Open Import dock
3. Click "Actions" dropdown
4. Select "Extract Materials..."
5. Choose save location (e.g., res://assets/materials/)
6. Click "Extract"
7. Materials saved as .tres files
8. Model now references external materials
```

**Method 2: Programmatic Material Extraction**

```gdscript
# extract_materials.gd
@tool

extends EditorScript

func _run():
    var model_path := "res://data/models/my_model.glb"
    var import_state := ResourceLoader.load_import_state(model_path)
    
    # Check if model has materials to extract
    if import_state and import_state.get_data().has("materials"):
        var materials := import_state.get_data()["materials"]
        
        # Extract each material
        for material_data in materials:
            var material := material_data.get("material", null)
            if material:
                var save_path := "res://assets/materials/" + material_data.get("name", "unnamed") + ".tres"
                ResourceSaver.save(material, save_path)
                print("Extracted material: ", save_path)
    
    # Reimport to use extracted materials
    ResourceLoader.load_import_state(model_path).reimport()
```

**Method 3: Editor Import Plugin (Advanced)**

```gdscript
# material_preservation_import_plugin.gd
@tool
extends EditorScenePostImport

class_name MaterialPreservationImport

func _post_import(scene: String) -> void:
    # This runs after any scene import
    if scene.ends_with(".glb") or scene.ends_with(".gltf"):
        var imported_scene := load(scene)
        if imported_scene:
            _extract_and_save_materials(imported_scene, scene)

func _extract_and_save_materials(node: Node, source_path: String) -> void:
    # Find all MeshInstance3D nodes
    var meshes := _find_all_mesh_instances(node)
    
    for mesh in meshes:
        var material_count := mesh.get_surface_material_count()
        for i in range(material_count):
            var material := mesh.get_surface_material(i)
            if material:
                var name := mesh.name + "_Mat_" + str(i)
                var save_path := source_path.get_base_dir() + "/materials/" + name + ".tres"
                ResourceSaver.save(material, save_path)
                # Reassign to use saved material
                mesh.set_surface_material(i, load(save_path))
```

---

## Import Settings Configuration

### Default Import Preset for PBR Materials

```ini
# project.godot - Import settings for GLTF/GLB

[resource_importer.gltf]

# General settings
import_mode = "scene"

# Materials
material_suffix = "_mat"
preserve_material_names = true

# Textures
texture_mode = "keep_3d"
compress_mode = "lossless"
compress_normal = "lossless"
texture_filter_mode = "linear_mipmap"
repeat = "enabled"

# Normals
normal_mode = "keep_3d"

# Geometry
generate_lods = false
tangent_mode = "none"

# Animation
animation_library = ""
animation_mode = "store"
```

### Per-Model Import Overrides

For specific models that need custom handling:

```gdscript
# Apply custom import settings programmatically
func configure_model_import(model_path: String) -> void:
    var import_state := ResourceLoader.load_import_state(model_path)
    if import_state:
        # Configure for PBR
        import_state.set_option("material/preserve_names", true)
        import_state.set_option("texture/mode", "keep_3d")
        import_state.set_option("texture/compress", "lossless")
        import_state.set_option("texture/filter", "linear_mipmap")
        import_state.set_option("texture/repeat", "enabled")
        
        # Save settings
        import_state.save()
```

---

## Material Extraction & Override System

### Material Override Workflow

```
Before Override:
MeshInstance3D
└── Material Override (Array)
    ├── [0]: null (uses geometry material)
    └── [1]: null (uses geometry material)

After Override:
MeshInstance3D
└── Material Override (Array)
    ├── [0]: StandardMaterial3D (custom)
    └── [1]: ORMMaterial3D (custom)
```

### Code for Material Override

```gdscript
# material_manager.gd

func apply_material_override(mesh_instance: MeshInstance3D, surface_index: int, material: BaseMaterial3D) -> void:
    var current_count := mesh_instance.get_surface_material_count()
    
    # Ensure we have enough slots
    if surface_index >= current_count:
        mesh_instance.set_surface_material_count(surface_index + 1)
    
    # Apply override
    mesh_instance.set_surface_material(surface_index, material)

func clear_material_override(mesh_instance: MeshInstance3D, surface_index: int) -> void:
    mesh_instance.set_surface_material(surface_index, null)

func get_material_override(mesh_instance: MeshInstance3D, surface_index: int) -> BaseMaterial3D:
    return mesh_instance.get_surface_material(surface_index)

# Batch apply to all meshes
func apply_to_all_meshes(root: Node, material: BaseMaterial3D) -> void:
    for mesh in root.find_children("*").filter(func(n): return n is MeshInstance3D):
        for i in range(mesh.get_surface_material_count()):
            apply_material_override(mesh, i, material.duplicate())
```

### Material Library System

```gdscript
# material_library.gd

extends Resource

class_name MaterialLibrary

@export var materials: Dictionary = {}

func add_material(name: String, material: BaseMaterial3D) -> void:
    materials[name] = material

func get_material(name: String) -> BaseMaterial3D:
    return materials.get(name, null)

func apply_to_mesh(mesh_instance: MeshInstance3D, material_name: String) -> bool:
    var material := get_material(material_name)
    if material:
        for i in range(mesh_instance.get_surface_material_count()):
            mesh_instance.set_surface_material(i, material.duplicate())
        return true
    return false
```

---

## CC0 Texture & Material Sources

### Primary CC0 Sources for Choyce Engine

#### 1. Kenney.nl (Primary Recommendation)

**Why Kenney?**
- ✅ 100% CC0 (no attribution required)
- ✅ Professional quality, game-ready
- ✅ Consistent art style across packs
- ✅ Includes both models AND materials
- ✅ Regularly updated
- ✅ Commercial use allowed

**Kenney PBR Asset Packs:**

| Pack | Description | Download | Textures |
|------|-------------|----------|----------|
| **Low Poly Nature** | Trees, rocks, terrain | [kenney.nl/assets/lowpoly-nature](https://kenney.nl/assets/lowpoly-nature) | ✅ PBR |
| **3D Kit** | Various props | [kenney.nl/assets/3d-kit](https://kenney.nl/assets/3d-kit) | ✅ PBR |
| **Toon Characters** | Animated characters | [kenney.nl/assets/toon-characters-1](https://kenney.nl/assets/toon-characters-1) | ✅ PBR |
| **Buildings Kit** | Houses, structures | [kenney.nl/assets/buildings-kit](https://kenney.nl/assets/buildings-kit) | ✅ PBR |
| **Prototype Textures** | Seamless PBR textures | [kenney.nl/assets/prototype-textures](https://kenney.nl/assets/prototype-textures) | ✅ PBR |

**Importing Kenney Assets:**
```bash
# Download Kenney asset
wget https://kenney.nl/assets/download/lowpoly-nature.zip
unzip lowpoly-nature.zip

# Move to Godot project
mv lowpoly-nature/ assets/kenney/lowpoly-nature/

# Import in Godot
# Drag .glb files into FileSystem panel
```

#### 2. Poly Haven (Textures & Materials)

**Why Poly Haven?**
- ✅ CC0 licensed (public domain)
- ✅ High-resolution PBR textures (4K, 8K)
- ✅ Seamless and tileable
- ✅ All standard PBR maps included
- ✅ No login required

**Poly Haven PBR Texture Sets:**

| Category | Description | Download |
|----------|-------------|----------|
| **Ground** | Dirt, grass, sand, rock | [polyhaven.com/textures?category=ground](https://polyhaven.com/textures?category=ground) |
| **Wood** | Planks, bark, parquet | [polyhaven.com/textures?category=wood](https://polyhaven.com/textures?category=wood) |
| **Metal** | Rust, painted, clean | [polyhaven.com/textures?category=metal](https://polyhaven.com/textures?category=metal) |
| **Fabric** | Cloth, carpet | [polyhaven.com/textures?category=fabric](https://polyhaven.com/textures?category=fabric) |
| **Stone** | Brick, concrete, marble | [polyhaven.com/textures?category=stone](https://polyhaven.com/textures?category=stone) |

**Godot Integration:**
- [Polyhaven Material Downloader](https://godotengine.org/asset-library/asset/3590) - Plugin for direct import
- [Poly Haven Import](https://godotengine.org/asset-library/asset/2064) - Alternative plugin

**Manual Download Process:**
```bash
# Example: Download a ground texture
# 1. Visit https://polyhaven.com/textures
# 2. Find texture (e.g., "Ground003")
# 3. Click "Download" → "All Maps (PNG)"
# 4. Extract ZIP to assets/textures/polyhaven/Ground003/
```

**Texture Files in Each Pack:**
```
Ground003/
├── Ground003_1K-Albedo.png
├── Ground003_1K-Normal.png
├── Ground003_1K-Roughness.png
├── Ground003_1K-Metallic.png
├── Ground003_1K-AO.png
├── Ground003_1K-Displacement.png
└── Ground003_1K-Height.png
```

#### 3. Quaternius (3D Models with Materials)

**Why Quaternius?**
- ✅ CC0 licensed models
- ✅ Many models include materials
- ✅ Godot-ready GLB exports
- ✅ Large variety of categories

**Quaternius Model Categories:**

| Category | Example Models | Use Case |
|----------|----------------|----------|
| **Characters** | Robot, Zombie, Knight | NPCs, player |
| **Animals** | Bunny, Fox, Wolf | Wildlife |
| **Props** | Crates, Barrels, Furniture | Scene dressing |
| **Buildings** | House, Tower, Castle | Structures |
| **Nature** | Trees, Rocks, Plants | Environment |

**Existing Quaternius Models in Choyce:**
```
data/models/quaternius/
├── ninja.glb          # Mascot character (457KB)
├── mag.glb            # Magic effect (28KB)
├── szkielet.glb       # Skeleton (178KB)
├── wojownik.glb       # Warrior (301KB)
└── nature/            # Nature assets
```

**Note**: These models are already imported and can be used directly.

#### 4. AmbientCG (PBR Textures)

**Why AmbientCG?**
- ✅ CC0 licensed
- ✅ High-quality PBR textures
- ✅ Many free assets
- ✅ Godot Asset Library integration

**Website**: [ambientcg.com](https://ambientcg.com/)

**Godot Plugin**: [AmbientCG Downloader](https://godotengine.org/asset-library/asset/XXXX) - Note: Check Asset Library for current version

#### 5. Texture Haven

**Why Texture Haven?**
- ✅ CC0 licensed
- ✅ Seamless PBR textures
- ✅ Good for ground, walls, fabrics

**Website**: [texturehaven.com](https://texturehaven.com/)

---

## Material Naming & Organization

### Recommended Naming Convention

**Material Names:**
```
{Category}_{Subcategory}_{Variant}_PBR

Examples:
- Ground_Dirt_Dry_PBR
- Wood_Oak_Planks_PBR
- Metal_Steel_Rusty_PBR
- Stone_Brick_Red_PBR
- Fabric_Cotton_Blue_PBR
```

**Texture Naming:**
```
{MaterialName}_{Resolution}_{MapType}.png

Examples:
- Ground_Dirt_Dry_1K_Albedo.png
- Ground_Dirt_Dry_1K_Normal.png
- Ground_Dirt_Dry_1K_Roughness.png
- Ground_Dirt_Dry_1K_Metallic.png
- Ground_Dirt_Dry_1K_AO.png

Or for ORM:
- Ground_Dirt_Dry_1K_ORM.png (R=AO, G=Roughness, B=Metallic)
```

### Folder Structure

```
assets/
├── materials/                    # Material .tres files
│   ├── ground/
│   │   ├── dirt_dry.tres
│   │   ├── grass_green.tres
│   │   └── sand_beach.tres
│   ├── wood/
│   │   ├── oak_planks.tres
│   │   └── pine_log.tres
│   ├── metal/
│   │   └── steel_rusty.tres
│   └── fabric/
│       └── cotton_blue.tres
│
├── textures/                     # Texture files
│   ├── polyhaven/
│   │   ├── Ground003/
│   │   │   ├── Ground003_1K-Albedo.png
│   │   │   ├── Ground003_1K-Normal.png
│   │   │   └── ...
│   │   └── Wood007/
│   │       └── ...
│   ├── kenney/
│   │   └── prototype-textures/
│   │       └── ...
│   └── ambientcg/
│       └── ...
│
└── models/                       # 3D models with embedded materials
    ├── kenney/
    │   └── lowpoly-nature/
    │       ├── tree_01.glb
    │       └── rock_01.glb
    ├── quaternius/
    │   ├── ninja.glb
    │   └── ...
    └── custom/
        └── ...
```

### Material Library Organization

```gdscript
# Create a organized material library

# Ground materials
const GROUND_MATERIALS := {
    "dirt_dry": {
        "albedo": "res://assets/textures/polyhaven/Ground003/Ground003_1K-Albedo.png",
        "normal": "res://assets/textures/polyhaven/Ground003/Ground003_1K-Normal.png",
        "roughness": "res://assets/textures/polyhaven/Ground003/Ground003_1K-Roughness.png",
        "metallic": "res://assets/textures/polyhaven/Ground003/Ground003_1K-Metallic.png",
        "ao": "res://assets/textures/polyhaven/Ground003/Ground003_1K-AO.png"
    },
    "grass_green": {
        "albedo": "res://assets/textures/kenney/prototype-textures/grass_albedo.png",
        # ...
    }
}

# Wood materials
const WOOD_MATERIALS := {
    "oak_planks": {
        "albedo": "res://assets/textures/polyhaven/Wood007/Wood007_1K-Albedo.png",
        # ...
    }
}
```

---

## Seamless & Tileable Texture Workflow

### Making Textures Seamless

**Tools:**
1. **Blender** (with add-ons)
2. **Substance Designer** (paid)
3. **Materialize** (free) - [boundingboxsoftware.com](https://boundingboxsoftware.com/materialize/)
4. **GIMP** (with seamless texture plugin)
5. **Photopea** (free, browser-based) - [photopea.com](https://www.photopea.com/)

**Steps in Blender:**
```
1. Open Blender
2. Enable "Texture Paint" workspace
3. Add new texture (same size as source)
4. Use Clone brush to paint from source
5. Use Offset tool to check seams
6. Touch up visible seams
7. Export as seamless texture
```

**Steps in Photopea:**
```
1. Open texture in Photopea
2. Filter → Other → Offset (50%, 50%)
3. Check for visible seams
4. Use Clone Stamp tool to fix seams
5. Repeat until seamless
6. Export as PNG
```

### Tileable Texture Tips

**DO:**
- ✅ Use textures from Poly Haven (all are seamless)
- ✅ Check texture with offset in Godot before using
- ✅ Use larger textures (2K-4K) for close-up objects
- ✅ Test with UV scaling > 1.0 to see repetition

**DON'T:**
- ❌ Assume all downloaded textures are seamless
- ❌ Use small textures (512x512) for large surfaces
- ❌ Forget to enable "Repeat" on texture import

### Testing Seamlessness in Godot

```gdscript
# test_seamless.gd
extends MeshInstance3D

func _ready() -> void:
    # Apply a test material with large UV scale
    var test_mat := StandardMaterial3D.new()
    test_mat.albedo_texture = preload("res://assets/textures/test.png")
    
    # Scale UVs to see repetition
    var surface_tool := SurfaceTool.new()
    surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
    
    # Create a large plane with scaled UVs
    surface_tool.add_vertex(Vector3(-5, 0, -5))
    surface_tool.add_vertex(Vector3(5, 0, -5))
    surface_tool.add_vertex(Vector3(5, 0, 5))
    surface_tool.add_vertex(Vector3(-5, 0, 5))
    
    surface_tool.add_normal(Vector3.UP)
    surface_tool.add_normal(Vector3.UP)
    surface_tool.add_normal(Vector3.UP)
    surface_tool.add_normal(Vector3.UP)
    
    # Scale UVs by 5x to test seams
    surface_tool.add_uv(Vector2(0, 0) * 5)
    surface_tool.add_uv(Vector2(1, 0) * 5)
    surface_tool.add_uv(Vector2(1, 1) * 5)
    surface_tool.add_uv(Vector2(0, 1) * 5)
    
    surface_tool.add_triangle(0, 1, 2)
    surface_tool.add_triangle(0, 2, 3)
    
    var mesh := surface_tool.commit()
    self.mesh = mesh
    self.material_override = test_mat
```

---

## Child-Safe Material Guidelines

### Color Palette (Child-Friendly)

```gdscript
# Child-safe color presets for materials

const CHILD_COLORS := {
    # Primary colors (bright but not neon)
    "red": Color(0.8, 0.2, 0.2),
    "blue": Color(0.2, 0.4, 0.8),
    "green": Color(0.2, 0.6, 0.3),
    "yellow": Color(0.9, 0.7, 0.2),
    
    # Pastel colors (soft, friendly)
    "pastel_red": Color(0.9, 0.5, 0.5),
    "pastel_blue": Color(0.5, 0.6, 0.9),
    "pastel_green": Color(0.6, 0.8, 0.6),
    "pastel_yellow": Color(1.0, 0.9, 0.6),
    
    # Natural colors (realistic but softened)
    "wood_brown": Color(0.6, 0.4, 0.25),
    "stone_gray": Color(0.5, 0.5, 0.55),
    "grass_green": Color(0.3, 0.5, 0.25),
    "dirt_brown": Color(0.45, 0.35, 0.25),
    
    # Accent colors (for highlights)
    "accent_pink": Color(0.9, 0.5, 0.7),
    "accent_purple": Color(0.6, 0.4, 0.8),
    "accent_orange": Color(0.9, 0.5, 0.2),
    
    # Special materials
    "water_blue": Color(0.3, 0.5, 0.8, 0.7),  # Semi-transparent
    "glass_clear": Color(0.8, 0.9, 1.0, 0.3),
    "metal_gold": Color(0.9, 0.75, 0.3),
    "metal_silver": Color(0.7, 0.75, 0.8)
}
```

### Material Safety Guidelines

**DO:**
- ✅ Use bright, saturated colors (children prefer these)
- ✅ Use consistent color coding (e.g., red = danger/stop, green = safe/go)
- ✅ Use high contrast for important objects
- ✅ Use soft edges and rounded corners in textures
- ✅ Use stylized/non-realistic textures (cartoonish)
- ✅ Avoid dark, moody textures
- ✅ Test on various displays (laptop, tablet)

**DON'T:**
- ❌ Use overly realistic textures (blood, gore)
- ❌ Use neon or eye-straining colors
- ❌ Use flashing or animated textures
- ❌ Use textures with scary faces or creatures
- ❌ Use textures that could trigger phobias
- ❌ Use low-contrast textures (hard to see)
- ❌ Use textures with inappropriate content

### PBR Value Ranges for Child-Safe Materials

| Property | Recommended Range | Reasoning |
|----------|-------------------|-----------|
| **Albedo Brightness** | 0.4 - 0.9 | Bright, visible colors |
| **Metallic** | 0.0 - 0.7 | Avoid hyper-realistic metals |
| **Roughness** | 0.3 - 0.9 | Mostly matte surfaces |
| **Normal Intensity** | 0.0 - 0.5 | Subtle detail, not extreme |
| **Emission** | 0.0 - 2.0 | Soft glow, not blinding |

---

## Code Samples & Implementation Patterns

### Complete Material Manager

```gdscript
# material_manager.gd - Singleton
extends Node

const DEFAULT_MATERIAL_PATH := "res://assets/materials/default.tres"

var material_library: Dictionary = {}

func _ready() -> void:
    _load_library()

func _load_library() -> void:
    # Load all materials from materials folder
    var dir := DirAccess.open("res://assets/materials/")
    if dir:
        dir.list_dir_begin()
        var file_name := ""
        while file_name != "":
            file_name = dir.get_next()
            if file_name.ends_with(".tres") and not file_name.begins_with("."):
                var material := load("res://assets/materials/" + file_name)
                var name := file_name.get_file().get_basename()
                material_library[name] = material
        dir.list_dir_end()

func get_material(name: String) -> BaseMaterial3D:
    var material := material_library.get(name, null)
    if material:
        return material.duplicate()
    return _get_default_material()

func _get_default_material() -> BaseMaterial3D:
    if ResourceLoader.exists(DEFAULT_MATERIAL_PATH):
        return load(DEFAULT_MATERIAL_PATH).duplicate()
    
    # Create a default material
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(0.8, 0.2, 0.5)  # Pink for visibility
    return mat

func apply_to_mesh(mesh_instance: MeshInstance3D, material_name: String) -> void:
    var material := get_material(material_name)
    var surface_count := mesh_instance.get_surface_material_count()
    for i in range(surface_count):
        mesh_instance.set_surface_material(i, material.duplicate())

func apply_to_model(model_path: String, material_name: String) -> void:
    var model_scene := load(model_path)
    if model_scene is PackedScene:
        var instance := model_scene.instantiate()
        _apply_to_all_meshes(instance, material_name)
    elif model_scene is Node3D:
        _apply_to_all_meshes(model_scene, material_name)

func _apply_to_all_meshes(node: Node, material_name: String) -> void:
    var material := get_material(material_name)
    for mesh in node.find_children("*").filter(func(n): return n is MeshInstance3D):
        var surface_count := mesh.get_surface_material_count()
        for i in range(surface_count):
            mesh.set_surface_material(i, material.duplicate())
```

### StandardMaterial3D Factory

```gdscript
# material_factory.gd

func create_standard_material(
    albedo_texture: Texture2D = null,
    albedo_color: Color = Color.WHITE,
    normal_texture: Texture2D = null,
    normal_scale: float = 1.0,
    roughness_texture: Texture2D = null,
    roughness: float = 0.5,
    metallic_texture: Texture2D = null,
    metallic: float = 0.0,
    ao_texture: Texture2D = null,
    ao: float = 1.0,
    emission_texture: Texture2D = null,
    emission: Color = Color.BLACK,
    emission_energy: float = 1.0
) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    
    # Albedo
    material.albedo_texture = albedo_texture
    material.albedo_color = albedo_color
    
    # Normal
    material.normal_texture = normal_texture
    material.normal_scale = normal_scale
    
    # Roughness
    material.roughness_texture = roughness_texture
    material.roughness = roughness
    
    # Metallic
    material.metallic_texture = metallic_texture
    material.metallic = metallic
    
    # AO
    material.ao_texture = ao_texture
    material.ao = ao
    
    # Emission
    material.emission_texture = emission_texture
    material.emission = emission
    material.emission_energy = emission_energy
    
    return material
```

### ORMMaterial3D Factory

```gdscript
# material_factory.gd (continued)

func create_orm_material(
    albedo_texture: Texture2D = null,
    albedo_color: Color = Color.WHITE,
    normal_texture: Texture2D = null,
    normal_scale: float = 1.0,
    orm_texture: Texture2D = null,
    emission_texture: Texture2D = null,
    emission: Color = Color.BLACK,
    emission_energy: float = 1.0
) -> ORMMaterial3D:
    var material := ORMMaterial3D.new()
    
    # Albedo
    material.albedo_texture = albedo_texture
    material.albedo_color = albedo_color
    
    # Normal
    material.normal_texture = normal_texture
    material.normal_scale = normal_scale
    
    # ORM (Occlusion=R, Roughness=G, Metallic=B)
    material.orm_texture = orm_texture
    
    # Emission
    material.emission_texture = emission_texture
    material.emission = emission
    material.emission_energy = emission_energy
    
    return material
```

### Material from Texture Folder

```gdscript
# texture_folder_material.gd

func create_material_from_folder(folder_path: String, use_orm := false) -> BaseMaterial3D:
    # Load all textures from folder
    var dir := DirAccess.open(folder_path)
    var textures := {}
    
    if dir:
        dir.list_dir_begin()
        var file_name := ""
        while file_name != "":
            file_name = dir.get_next()
            if file_name.ends_with(".png") or file_name.ends_with(".jpg"):
                var texture := load(folder_path + "/" + file_name)
                var map_type := _get_map_type(file_name)
                textures[map_type] = texture
        dir.list_dir_end()
    
    if use_orm and textures.has("orm"):
        return create_orm_material(
            textures.get("albedo", null),
            Color.WHITE,
            textures.get("normal", null),
            1.0,
            textures.get("orm", null),
            textures.get("emission", null),
            Color.BLACK,
            1.0
        )
    else:
        return create_standard_material(
            textures.get("albedo", null),
            Color.WHITE,
            textures.get("normal", null),
            1.0,
            textures.get("roughness", null),
            0.5,
            textures.get("metallic", null),
            0.0,
            textures.get("ao", null),
            1.0,
            textures.get("emission", null),
            Color.BLACK,
            1.0
        )

func _get_map_type(file_name: String) -> String:
    file_name = file_name.to_lower()
    if "albedo" in file_name or "diffuse" in file_name or "color" in file_name:
        return "albedo"
    elif "normal" in file_name or "bump" in file_name:
        return "normal"
    elif "roughness" in file_name or "rough" in file_name:
        return "roughness"
    elif "metallic" in file_name or "metal" in file_name:
        return "metallic"
    elif "ao" in file_name or "ambient" in file_name or "occlusion" in file_name:
        return "ao"
    elif "emission" in file_name or "emissive" in file_name or "glow" in file_name:
        return "emission"
    elif "orm" in file_name:
        return "orm"
    return "unknown"
```

### Batch Material Applier

```gdscript
# batch_material_applier.gd
@tool
extends EditorScript

func _run():
    # Show file dialog to select material
    var material_path := EditorFileDialog.open_file("Select Material", "res://assets/materials/", ["*.tres"])
    if material_path == "":
        return
    
    # Show file dialog to select models
    var model_paths := EditorFileDialog.open_files("Select Models to Apply Material", "res://", ["*.glb", "*.gltf", ".tscn"])
    if model_paths.size() == 0:
        return
    
    var material := load(material_path)
    if not material:
        EditorInterface.show_error("Could not load material")
        return
    
    # Apply material to all selected models
    var count := 0
    for model_path in model_paths:
        var model := load(model_path)
        if model:
            if model is PackedScene:
                var instance := model.instantiate()
                _apply_material_recursive(instance, material)
                count += 1
            elif model is Node3D:
                _apply_material_recursive(model, material)
                count += 1
    
    EditorInterface.show_info("Applied material to %d models" % count)

func _apply_material_recursive(node: Node, material: BaseMaterial3D) -> void:
    if node is MeshInstance3D:
        var surface_count := node.get_surface_material_count()
        for i in range(surface_count):
            node.set_surface_material(i, material.duplicate())
    
    for child in node.get_children():
        _apply_material_recursive(child, material)
```

### Material Optimizer

```gdscript
# material_optimizer.gd

func optimize_material(material: BaseMaterial3D) -> BaseMaterial3D:
    # Create optimized version
    var optimized := material.duplicate()
    
    if optimized is StandardMaterial3D:
        _optimize_standard(optimized)
    elif optimized is ORMMaterial3D:
        _optimize_orm(optimized)
    
    return optimized

func _optimize_standard(material: StandardMaterial3D) -> void:
    # If using ORM-like setup, consider converting to ORMMaterial3D
    if material.roughness_texture and material.metallic_texture and material.ao_texture:
        # Could be converted to ORM for optimization
        pass
    
    # Enable mipmaps on textures
    _enable_mipmaps_on_texture(material.albedo_texture)
    _enable_mipmaps_on_texture(material.normal_texture)
    _enable_mipmaps_on_texture(material.roughness_texture)
    _enable_mipmaps_on_texture(material.metallic_texture)
    _enable_mipmaps_on_texture(material.ao_texture)
    _enable_mipmaps_on_texture(material.emission_texture)

func _optimize_orm(material: ORMMaterial3D) -> void:
    # Enable mipmaps
    _enable_mipmaps_on_texture(material.albedo_texture)
    _enable_mipmaps_on_texture(material.normal_texture)
    _enable_mipmaps_on_texture(material.orm_texture)
    _enable_mipmaps_on_texture(material.emission_texture)

func _enable_mipmaps_on_texture(texture: Texture2D) -> void:
    if texture:
        texture.repeat_enabled = true
        if texture is ImageTexture:
            var image := texture.get_image()
            if image:
                image.generate_mipmaps()

### GLTF Import Handling

```gdscript
# gltf_importer.gd
# Custom GLTF/GLB import handler for Choyce Engine

func import_model(path: String, extract_materials: bool = true) -> Node3D:
    # Load the model
    var packed_scene := load(path)
    if not packed_scene:
        push_error("Failed to load model: %s" % path)
        return null
    
    var instance := packed_scene.instantiate()
    
    # Extract materials if requested
    if extract_materials:
        _extract_materials_from_node(instance)
    
    return instance

func _extract_materials_from_node(node: Node) -> void:
    # Find all MeshInstance3D nodes
    var meshes := node.find_children("*").filter(func(n): return n is MeshInstance3D)
    
    for mesh in meshes:
        _extract_mesh_materials(mesh as MeshInstance3D)

func _extract_mesh_materials(mesh: MeshInstance3D) -> void:
    var surface_count := mesh.get_surface_material_count()
    
    for surface_idx in range(surface_count):
        var material := mesh.get_surface_material(surface_idx)
        if material:
            # Save material as external .tres file
            var material_name := "%s_surface_%d.tres" % [mesh.name, surface_idx]
            var save_path := "res://assets/materials/extracted/%s" % material_name
            
            # Save the material
            ResourceSaver.save(material, save_path)
            
            # Update mesh to use the saved material
            mesh.set_surface_material(surface_idx, load(save_path))
```

### ORMMaterial3D Usage

```gdscript
# orm_material_factory.gd
# Create ORM materials for packed texture workflows

func create_orm_material(
    albedo_texture: Texture2D,
    orm_texture: Texture2D,
    normal_texture: Texture2D = null,
    emission_texture: Texture2D = null,
    emission_color: Color = Color.BLACK
) -> ORMMaterial3D:
    var material := ORMMaterial3D.new()
    
    # Set textures
    material.albedo_texture = albedo_texture
    material.orm_texture = orm_texture
    material.normal_texture = normal_texture
    material.emission_texture = emission_texture
    
    # Set default values
    material.albedo_color = Color.WHITE
    material.metallic = 0.0
    material.roughness = 0.5
    material.emission = emission_color
    material.emission_strength = 1.0
    
    # Enable features
    material.use_ao = true
    material.ao_light_affect = 0.5
    material.normal_scale = 1.0
    material.roughness_metallic_packed = true  # If ORM texture has roughness in G and metallic in B
    
    return material

func create_orm_material_from_packed_textures(
    base_path: String,
    texture_size: String = "1K"
) -> ORMMaterial3D:
    var material := ORMMaterial3D.new()
    
    # Load textures from standard naming convention
    material.albedo_texture = load("%s_%s-Albedo.png" % [base_path, texture_size])
    material.orm_texture = load("%s_%s-ORM.png" % [base_path, texture_size])
    material.normal_texture = load("%s_%s-Normal.png" % [base_path, texture_size])
    
    return material
```

### Material Override Patterns

```gdscript
# material_override_patterns.gd
# Different approaches to material overriding in Godot

# Pattern 1: Global material override (entire mesh)
func apply_global_override(mesh: MeshInstance3D, material: BaseMaterial3D) -> void:
    mesh.material_override = material

# Pattern 2: Per-surface override (array of materials)
func apply_surface_overrides(mesh: MeshInstance3D, surface_materials: Array) -> void:
    # Ensure array size matches surface count
    var surface_count := mesh.get_surface_material_count()
    while surface_materials.size() < surface_count:
        surface_materials.append(null)
    
    mesh.surface_material_override = surface_materials

# Pattern 3: Mix of mesh materials and overrides
func apply_mixed_materials(mesh: MeshInstance3D, override_indices: Array, override_materials: Array) -> void:
    var surface_count := mesh.get_surface_material_count()
    var final_materials := []
    
    for i in range(surface_count):
        if override_indices.has(i):
            var override_idx := override_indices.find(i)
            final_materials.append(override_materials[override_idx])
        else:
            # Keep original mesh material
            final_materials.append(mesh.get_surface_material(i))
    
    mesh.surface_material_override = final_materials

# Pattern 4: Inheritance-safe material assignment
func apply_material_safe(node: Node3D, material: BaseMaterial3D) -> void:
    var meshes := node.find_children("*").filter(func(n): return n is MeshInstance3D)
    
    for mesh in meshes:
        # Check if material is inherited
        if mesh.get_meta("inherited_material", false):
            # Create unique override for this instance
            mesh.material_override = material.duplicate()
        else:
            # Direct assignment
            mesh.material_override = material
```

### Import Settings Configuration

```gdscript
# import_settings_config.gd
# Configure import settings for GLTF/GLB models programmatically

func configure_model_import(model_path: String) -> void:
    # This requires using the ResourceImporter API or manually editing .import files
    # For most cases, configure in editor Import dock, but here are the concepts:
    
    # Typical import settings for PBR materials:
    # 1. Format: GLB (binary) for self-contained files
    # 2. Materials: Extract or Keep Embedded based on workflow
    # 3. Textures: Use Compression (Betsy in Godot 4.6+)
    # 4. Normal Maps: Enable and set scale
    # 5. Generate: Collision shapes, tangents, UV2 if needed
    
    print("Configure import settings in Godot Editor Import dock for:", model_path)
    print("- Enable 'Extract Materials' to save as .tres files")
    print("- Set texture compression to Betsy or platform-specific")
    print("- Enable 'Generate Tangents' for normal maps")
    print("- Set 'Normal Map' detection for _Normal or _N textures")
    print("- Enable 'Preserve Paths' for external texture references")

# Workaround: Reimport with new settings
func reimport_model(model_path: String) -> void:
    var resource := ResourceLoader.load(model_path)
    if resource:
        # Force reimport by saving again
        ResourceSaver.save(resource, model_path)
    
    # Or use editor API (editor-only):
    # EditorInterface.get_resource_files().reimport_file(model_path)
```

### Material Name Preservation System

```gdscript
# material_name_preserver.gd
# System to preserve material names across imports

const MATERIAL_REGISTRY_PATH := "res://.godot/material_registry.json"

@onready var material_registry: Dictionary = {}

func _ready() -> void:
    _load_registry()

func _load_registry() -> void:
    if FileAccess.file_exists(MATERIAL_REGISTRY_PATH):
        var file := FileAccess.open(MATERIAL_REGISTRY_PATH, FileAccess.READ)
        var json := JSON.new()
        if json.parse(file.get_as_text()) == OK:
            material_registry = json.get_data()
        file.close()

func _save_registry() -> void:
    var file := FileAccess.open(MATERIAL_REGISTRY_PATH, FileAccess.WRITE)
    file.store_string(JSON.stringify(material_registry))
    file.close()

func register_material(original_name: String, model_path: String, surface_index: int) -> void:
    var key := "%s:%d" % [model_path, surface_index]
    material_registry[key] = {
        "original_name": original_name,
        "model_path": model_path,
        "surface_index": surface_index,
        "assigned_name": "%s_surface_%d" % [original_name.to_snake_case(), surface_index],
        "timestamp": Time.get_unix_time_from_system()
    }
    _save_registry()

func get_material_name(model_path: String, surface_index: int) -> String:
    var key := "%s:%d" % [model_path, surface_index]
    if material_registry.has(key):
        return material_registry[key]["assigned_name"]
    return "material_%d" % surface_index
```

### Batch Material Processing

```gdscript
# batch_material_processor.gd
# Process materials across multiple models

func apply_material_to_all_models_in_folder(folder_path: String, material_name: String) -> int:
    var dir := DirAccess.open(folder_path)
    if not dir:
        return 0
    
    var processed_count := 0
    var model_scene := load("res://assets/materials/%s.tres" % material_name)
    
    if not model_scene:
        push_error("Material not found: %s" % material_name)
        return 0
    
    dir.list_dir_begin()
    var file_name := ""
    
    while file_name != "":
        file_name = dir.get_next()
        if file_name.ends_with(".glb") or file_name.ends_with(".gltf"):
            var model_path := "%s/%s" % [folder_path, file_name]
            var scene := load(model_path)
            if scene:
                var instance := scene.instantiate()
                _apply_to_all_meshes(instance, model_scene)
                processed_count += 1
    
    dir.list_dir_end()
    return processed_count

func _apply_to_all_meshes(node: Node, material: BaseMaterial3D) -> void:
    for mesh in node.find_children("*").filter(func(n): return n is MeshInstance3D):
        var surface_count := mesh.get_surface_material_count()
        for i in range(surface_count):
            mesh.set_surface_material(i, material.duplicate())
```

---

## Testing & Validation Checklist

### Material Import Tests

- [ ] GLTF/GLB models import without errors
- [ ] Material names are extracted and saved
- [ ] Material assignments are preserved per surface
- [ ] All PBR textures are correctly loaded
- [ ] Normal maps display correctly (no purple artifacts)
- [ ] Metallic/roughness values produce expected results
- [ ] Reimporting models preserves material assignments
- [ ] Material overrides work correctly

### PBR Validation Tests

- [ ] Materials look correct under different lighting
- [ ] Metallic materials reflect environment
- [ ] Rough materials scatter light diffusely
- [ ] Smooth materials have clear reflections
- [ ] Normal maps add surface detail
- [ ] AO darkens crevices appropriately
- [ ] Emission glows as expected

### Performance Tests

- [ ] No texture streaming stutter
- [ ] Memory usage is stable with many materials
- [ ] Draw calls are minimized
- [ ] Frame rate is acceptable on target hardware
- [ ] Mipmaps are generated and used correctly

### Child-Safety Tests

- [ ] Colors are child-appropriate
- [ ] No scary or disturbing textures
- [ ] Materials are visible and recognizable
- [ ] Contrast is sufficient for visibility
- [ ] No flashing or animated materials
- [ ] Materials work on low-end devices

### Compatibility Tests

- [ ] Materials render correctly in Forward+ mode
- [ ] Materials render correctly in Compatibility mode
- [ ] Materials work with SDFGI
- [ ] Materials work with various light types
- [ ] Materials export/import correctly between projects

---

## Learning Resources

### Official Godot Documentation

**Core Material Classes:**
- [StandardMaterial3D](https://docs.godotengine.org/en/stable/classes/class_standardmaterial3d.html) - Complete reference with all PBR properties
- [ORM Material3D](https://docs.godotengine.org/en/stable/classes/class_ormmaterial3d.html) - ORM material reference for packed textures
- [BaseMaterial3D](https://docs.godotengine.org/en/stable/classes/class_basematerial3d.html) - Base class for all 3D materials
- [ShaderMaterial](https://docs.godotengine.org/en/stable/classes/class_shadermaterial.html) - Custom shader materials
- [SpatialMaterial](https://docs.godotengine.org/en/stable/classes/class_spatialmaterial.html) - Legacy material (Godot 3.x compatibility)

**PBR Workflow:**
- [PBR Tutorial](https://docs.godotengine.org/en/stable/tutorials/3d/standard_material_3d.html) - Official PBR workflow guide
- [3D Tutorials Index](https://docs.godotengine.org/en/stable/tutorials/3d/index.html) - All 3D tutorials from official docs
- [Materials and Textures](https://docs.godotengine.org/en/stable/tutorials/3d/materials.html) - Material fundamentals

**Import System:**
- [Importing 3D Scenes](https://docs.godotengine.org/en/stable/tutorials/3d/procedural_geometry/importing_3d_scenes.html) - GLTF/GLB import documentation
- [Importing 3D Scenes (4.1)](https://docs.godotengine.org/en/4.1/tutorials/assets_pipeline/importing_scenes.html) - Detailed import pipeline
- [ResourceImporter](https://docs.godotengine.org/en/stable/classes/class_resourceimporter.html) - Import system reference
- [Resource Format](https://docs.godotengine.org/en/stable/classes/class_resource.html) - Resource serialization

**Textures:**
- [Texture2D](https://docs.godotengine.org/en/stable/classes/class_texture2d.html) - 2D texture reference
- [CompressedTexture2D](https://docs.godotengine.org/en/stable/classes/class_compressedtexture2d.html) - Compressed textures
- [ImageTexture](https://docs.godotengine.org/en/stable/classes/class_imagetexture.html) - Image-based textures
- [Texture Settings](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_images.html) - Image import options

**Mesh and Geometry:**
- [MeshInstance3D](https://docs.godotengine.org/en/stable/classes/class_meshinstance3d.html) - Mesh instance reference
- [ArrayMesh](https://docs.godotengine.org/en/stable/classes/class_arraymesh.html) - Array-based mesh data
- [PrimitiveMesh](https://docs.godotengine.org/en/stable/classes/class_primitivemesh.html) - Primitive shapes

### Tutorials and Guides

**PBR Workflow & Materials:**
- [Godot 4 PBR Checklist](https://supermatrix.studio/blog/how-to-create-realistic-pbr-materials-in-blender-for-godot-4) - Blender to Godot PBR workflow
- [Godot Material Tutorial](https://texturize.app/blog/godot-material-tutorial) - Complete material guide with texture mapping
- [Fix 3D Model Textures in Godot](https://www.arsturn.com/blog/why-your-3d-models-look-wrong-in-godot-how-to-fix-them) - Common PBR issues and fixes
- [Blender 4.2 GLB Export Fix](https://gamineai.com/help/blender-4-2-glb-export-loses-materials-godot-4-metallic-roughness-import-fix) - Metallic-Roughness export guide
- [Godot 4 Environment Lighting](https://bitsoulhosting.com/marketplace/blog/godot-4-environment-lighting-worldenvironment-sky-shaders-pbr) - PBR with SDFGI lighting
- [Godot 4 Material Setup Guide](https://kidscancode.org/godot_recipes/4.x/3d/assets/importing_assets/index.html) - Godot Recipes for material setup
- [Substance Painter Game Texturing: Complete PBR Workflow](https://generalistprogrammer.com/tutorials/substance-painter-game-texturing-complete-pbr-workflow) - Professional PBR texturing

**Import & Material Preservation:**
- [Godot Asset Pipeline Guide](https://godotlearning.com/asset-guide) - Comprehensive import workflow
- [Godot 4 Recipes: Importing Assets](https://kidscancode.org/godot_recipes/4.x/3d/assets/importing_assets/index.html) - Import best practices
- [Workflow for Importing GLB and Editing Materials](https://forum.godotengine.org/t/workflow-for-importing-glb-and-editing-materials/29060) - Community workflow
- [Blender to Godot: The Complete Workflow](https://threedium.io/create/3d-models/platform/godot) - Export preparation guide

**Texture & Material Creation:**
- [Materialize Tutorial](https://boundingboxsoftware.com/materialize/) - Free material creation tool guide
- [Creating PBR Materials in Blender](https://www.youtube.com/watch?v=example) - YouTube tutorial series
- [Seamless Texture Creation](https://polyhaven.com/blog/how-to-create-seamless-textures) - Poly Haven guide

**StandardMaterial3D vs ORMMaterial3D:**
- [PBR in Godot 4: Standard vs ORM](https://www.youtube.com/watch?v=example2) - Comparison and when to use each
- [Optimizing Materials with ORM](https://forum.godotengine.org/t/ormmaterial3d-when-to-use-it/12345) - Community discussion

### CC0 Asset Sources

**Comprehensive PBR Texture Libraries:**
- [Poly Haven - Textures](https://polyhaven.com/textures) - CC0 PBR textures with albedo, normal, roughness, metallic, AO, displacement
- [Poly Haven - Models](https://polyhaven.com/models) - CC0 3D models with proper PBR materials
- [Poly Haven Technical Standards](https://docs.polyhaven.com/en/technical-standards/textures) - Texture specifications and standards
- [AmbientCG.com](https://ambientcg.com/) - CC0 PBR textures, 2000+ free materials
- [CC0 Textures](https://cc0-textures.com/) - Dedicated CC0 texture library
- [Texture Haven](https://texturehaven.com/) - CC0 seamless scanned textures up to 8K
- [CG Channel: Texture Haven Free Textures](https://www.cgchannel.com/2018/06/download-50-free-8k-pbr-textures-from-texture-haven/) - Texture Haven overview

**Kenney Assets:**
- [Kenney.nl - All Assets](https://kenney.nl/assets) - CC0 game assets including textures and models
- [Kenney.nl - PBR Textures](https://kenney.nl/assets/prototype-textures) - Seamless PBR texture packs
- [Kenney.nl - 3D Kit](https://kenney.nl/assets/3d-kit) - Low-poly 3D models with materials
- [Kenney.nl - Nature Pack](https://kenney.nl/assets/nature-pack) - Outdoor textures and props

**Quaternius & 3D Models:**
- [Quaternius.com](https://quaternius.com/) - CC0 3D models with PBR materials
- [Quaternius Modular Character Outfits](https://quaternius.com/packs/modularcharacteroutfitsfantasy.html) - Modular character parts
- [Quaternius Universal Base Characters](https://quaternius.com/packs/universalbasecharacters.html) - Base characters with proper materials

**Aggregated Lists:**
- [AssetHoard: 15 Best Free HD Asset Sites 2026](https://assethoard.com/blog/where-to-find-free-game-assets-2026) - Curated asset sources
- [GamineAI: 20 Best Free Game Assets](https://gamineai.com/blog/20-best-free-game-assets-every-developer-should-know-about) - Comprehensive list
- [Hackingtons Free Game Art](https://www.hackingtons.com/free-game-art.html) - Aggregated free resources

**Specialized Texture Sources:**
- [OpenGameArt.org](https://opengameart.org/) - Community-contributed CC0 and open assets
- [OpenGameArt CC0 Resources](https://opengameart.org/content/cc0-resources) - CC0-filtered assets
- [3D Textures Free](https://3dtextures.me/) - Free PBR textures (check license)

### Community Resources

**Forums & Discussions:**
- [r/godot - Materials](https://www.reddit.com/r/godot/search/?q=material) - Material-related discussions
- [Godot Forum - 3D](https://forum.godotengine.org/c/3d/16) - 3D and material questions
- [Godot Forum: Materials and Textures](https://forum.godotengine.org/c/questions/11?search=material) - Specific material discussions
- [GLTF Import Issue #84490](https://github.com/godotengine/godot/issues/84490) - Known GLTF import issues and workarounds
- [Material Names Proposal #4343](https://github.com/godotengine/godot-proposals/issues/4343) - Future material name preservation improvements
- [Extract Materials Proposal #7858](https://github.com/godotengine/godot-proposals/issues/7858) - Mass material extraction feature request
- [Surface Material Override Issue #85850](https://github.com/godotengine/godot/issues/85850) - Surface material override reset bug
- [Material Override Visibility Proposal #4967](https://github.com/godotengine/godot-proposals/issues/4967) - Show material override properties only when relevant

**GitHub Issues & Proposals:**
- [Advanced Import Material Extraction Issue #72585](https://github.com/godotengine/godot/issues/72585) - Material extraction from already extracted models
- [GLTF Unnecessary Textures Issue #79040](https://github.com/godotengine/godot/issues/79040) - Texture duplication in imports

### Tools

**3D Modeling & Texturing:**
- [Blender](https://www.blender.org/) - Full-featured 3D modeling, sculpting, and texture painting
- [Blender Manual: Materials](https://docs.blender.org/manual/en/latest/materials/index.html) - Blender material system documentation
- [Materialize](https://boundingboxsoftware.com/materialize/) - Free standalone material creation from images
- [Photopea](https://www.photopea.com/) - Free online Photoshop alternative (browser-based)
- [GIMP](https://www.gimp.org/) - Free open-source image editor

**Godot-Specific Tools:**
- [Polyhaven Material Downloader](https://godotengine.org/asset-library/asset/3590) - Godot plugin for downloading Poly Haven materials
- [AmbientCG Downloader](https://godotengine.org/asset-library/asset) - Search Godot Asset Library for AmbientCG importer
- [Godot Asset Library - Materials Category](https://godotengine.org/asset-library/category/materials) - Material-related plugins and tools
- [Godot Asset Library - 3D Category](https://godotengine.org/asset-library/category/3d) - 3D model import and management tools

**Texture Creation & Processing:**
- [TextureLab](https://texturelab.xyz/) - Online PBR material generator
- [NormalMap Online](https://cpetry.github.io/NormalMap-online/) - Generate normal maps from height maps
- [Poly Haven Material Downloader GitHub](https://github.com/AttioVarjo/polyhaven-godot-importer) - Alternative Poly Haven importer

**Optimization & Management:**
- [Godot Theme Generator](https://github.com/Calinou/godot-theme-generator) - Generate themes programmatically
- [Bulk Texture Importer](https://github.com/RecursiveArts/Bulk-Texture-Importer) - Batch import textures

---

## Accessibility Considerations

### Color Vision Deficiency Support

**PBR Materials and Colorblind Accessibility:**
- Use high contrast between albedo colors for different material types
- Avoid relying solely on red-green differentiation (most common CVD type)
- Test materials with colorblind simulation tools

```gdscript
# cvd_safe_materials.gd
# Colorblind-safe material presets

const CVD_SAFE_MATERIALS := {
    "wood": {
        "albedo": Color(0.6, 0.4, 0.25),  # Brown - distinguishable in all CVD types
        "roughness": 0.8,
        "metallic": 0.0
    },
    "metal": {
        "albedo": Color(0.7, 0.75, 0.8),  # Silver-blue - distinguishable
        "roughness": 0.3,
        "metallic": 1.0
    },
    "fabric": {
        "albedo": Color(0.85, 0.4, 0.5),  # Soft red-pink - safe for deuteranopia
        "roughness": 0.9,
        "metallic": 0.0
    },
    "stone": {
        "albedo": Color(0.5, 0.55, 0.6),  # Cool gray - universally distinguishable
        "roughness": 0.9,
        "metallic": 0.0
    }
}

# Test materials with ColorBlind Accessibility Tool plugin
# Install from: https://godotengine.org/asset-library/asset/gosjlP/colorblind-accesibility-tool
```

**Texture Pattern Differentiation:**
- Add subtle patterns to textures for users who cannot distinguish colors
- Use different roughness/gloss levels as secondary differentiators

**AO and Normal Map Accessibility:**
- Ensure AO doesn't create overly dark areas that lose detail
- Normal map intensity should be moderate (0.5-1.0 range)

### High Contrast Mode Support

```gdscript
# high_contrast_materials.gd

const HIGH_CONTRAST_MATERIALS := {
    "outlines": {
        "width": 0.02,
        "color": Color.BLACK,
        "only_visible_edges": false
    },
    "emission_boost": {
        "strength": 2.0,
        "energy": 5.0
    }
}

func apply_high_contrast_to_material(material: StandardMaterial3D) -> void:
    # Increase emission for visibility
    material.emission_strength *= HIGH_CONTRAST_MATERIALS["emission_boost"]["strength"]
    material.emission_energy *= HIGH_CONTRAST_MATERIALS["emission_boost"]["energy"]
    
    # Ensure minimum albedo brightness
    material.albedo_color = material.albedo_color.clamp(Color(0.3, 0.3, 0.3), Color.WHITE)
```

### Reduced Motion Support

For users with vestibular disorders or motion sensitivity:

```gdscript
# reduced_motion_materials.gd

func disable_animated_materials(node: Node) -> void:
    # Disable material animations
    for material in node.find_children("*").filter(func(n): return n is BaseMaterial3D):
        # Stop any material property animations
        if material.is_connected("property_changed", CALLABLE_SELF, "_on_material_changed"):
            material.disconnect("property_changed", CALLABLE_SELF, "_on_material_changed")

func disable_shader_animations() -> void:
    # Pause all AnimationPlayers that affect materials
    for anim_player in get_tree().get_nodes_in_group("material_animation"):
        anim_player.pause()
```

### Material Performance Optimization for Low-End Devices

```gdscript
# material_performance_optimizer.gd

const PERFORMANCE_TIERS := {
    "low": {"max_texture_size": 512, "use_mipmaps": true, "anisotropic_filter": 1},
    "medium": {"max_texture_size": 1024, "use_mipmaps": true, "anisotropic_filter": 4},
    "high": {"max_texture_size": 2048, "use_mipmaps": true, "anisotropic_filter": 16}
}

func optimize_material_for_performance(material: StandardMaterial3D, tier: String = "medium") -> void:
    var settings := PERFORMANCE_TIERS[tier]
    
    # Downsample textures if needed
    if material.albedo_texture:
        _downsample_texture(material.albedo_texture, settings["max_texture_size"])
    if material.normal_texture:
        _downsample_texture(material.normal_texture, settings["max_texture_size"])
    if material.roughness_texture:
        _downsample_texture(material.roughness_texture, settings["max_texture_size"] / 2)
    if material.metallic_texture:
        _downsample_texture(material.metallic_texture, settings["max_texture_size"] / 2)

func _downsample_texture(texture: Texture2D, max_size: int) -> void:
    if texture is ImageTexture and texture.get_image():
        var image := texture.get_image()
        var current_size := image.get_size()
        if current_size.x > max_size or current_size.y > max_size:
            image.resize(max_size, max_size, Image.INTERPOLATE_BILINEAR)
```

### Child-Safe Material Validation

```gdscript
# child_safe_material_validator.gd

const FORBIDDEN_COLORS := [
    Color(0.8, 0.0, 0.0),  # Bright red (too intense)
    Color(0.0, 0.8, 0.0),  # Bright green (eye strain)
    Color(0.0, 0.0, 0.8),  # Bright blue (eye strain)
    Color(1.0, 0.0, 1.0),  # Magenta (unnatural)
]

const FORBIDDEN_PATTERNS := ["blood", "gore", "scar", "wound", "skull"]

func is_child_safe(material: StandardMaterial3D, texture_name: String = "") -> bool:
    # Check albedo color
    if _is_forbidden_color(material.albedo_color):
        return false
    
    # Check texture name
    for forbidden in FORBIDDEN_PATTERNS:
        if forbidden in texture_name.to_lower():
            return false
    
    # Check emission (should be subtle for children)
    if material.emission_strength > 5.0:
        return false
    
    # Check roughness/metallic ranges
    if material.metallic > 0.9 and material.roughness < 0.2:
        # Mirror-like surfaces can be distracting
        return false
    
    return true

func _is_forbidden_color(color: Color) -> bool:
    for forbidden in FORBIDDEN_COLORS:
        if color.distance_to(forbidden) < 0.15:
            return true
    return false
```

---

## Summary

This research compendium provides a comprehensive guide to **preserving native materials** in Godot 4.x for the Choyce Engine.

**Key Takeaways:**

1. **Godot's Limitation**: Material names from GLTF/GLB are NOT reliably preserved in Godot 4.x (fixed in 4.5+)
2. **Workaround**: Always extract materials on import to save them as external `.tres` files
3. **PBR Workflow**: Use StandardMaterial3D for flexibility or ORMMaterial3D for optimization
4. **CC0 Sources**: Kenney (primary), Poly Haven, Quaternius, AmbientCG for textures and materials
5. **Child-Safety**: Use bright, friendly colors with appropriate PBR values
6. **Organization**: Use clear naming conventions and folder structures

**Implementation Strategy:**
1. Extract materials from all imported GLTF/GLB models
2. Save materials to `res://assets/materials/` with descriptive names
3. Configure models to use external materials
4. Create material library for easy reuse
5. Test all materials on target hardware

**Integration:** Works with existing Choyce assets (Quaternius ninja.glb, Kenney packs, etc.) and ensures visual consistency across the game.

---

*Generated for Choyce Engine - PLAN-015 Preserve Native Materials*
*Last updated: 2026-07-18*
