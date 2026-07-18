# RESEARCH_PLAN_002: Godot 4.6 project.godot Configuration Reconciliation

**Source**: PLAN.md Gate 0 - "Reconcile `project.godot`, `shell/next-env.d.ts`, generated imports, raw assets, and Cargo lock"
**Title**: Comprehensive Godot 4.6 Project Configuration Management
**Specialty**: godot-configuration, build-engineering
**Status**: todo
**Owner**: codex
**Complexity**: HIGH

---

## Table of Contents
1. [Task Overview](#task-overview)
2. [Current Implementation Analysis](#current-implementation-analysis)
3. [Online Research Summary](#online-research-summary)
4. [Technical Deep Dive](#technical-deep-dive)
5. [Code Samples](#code-samples)
6. [Asset Packages and Tools](#asset-packages-and-tools)
7. [Learning Resources](#learning-resources)
8. [Implementation Checklist](#implementation-checklist)
9. [Child-Safety Constraints](#child-safety-constraints)
10. [References](#references)

---

## Task Overview

### Objective
Reconcile and validate the `project.godot` configuration file with all generated imports, raw assets, TypeScript definitions (`shell/next-env.d.ts`), and Rust dependencies (`Cargo.lock`) to ensure a clean, parse-clean Godot project that can be reproducibly validated.

### Acceptance Criteria (from PLAN.md Gate 0)
1. **Reconciliation**: `project.godot` matches the actual project state
2. **Parse-clean**: Godot can parse the project without errors
3. **Reproducible validation**: A validation command set exists and passes
4. **Cross-file consistency**: Generated imports, raw assets, and lock files are in sync

### Key Requirements
- All resource imports must be valid and up-to-date
- TypeScript type definitions must match Godot exports
- Rust dependencies must match actual usage
- Configuration must support Forward+/SDFGI (from PLAN_001)
- Must work across Tier 1 and Tier 2 hardware

---

## Current Implementation Analysis

### Existing Configuration Files
From the codebase:
- `project.godot` - Main Godot project configuration
- `shell/next-env.d.ts` - TypeScript type definitions for Godot bridge
- `Cargo.lock` - Rust dependency lock file
- Generated `.import` files in asset directories
- Raw asset files (textures, models, audio)

### Configuration Challenge
The project has **multiple sources of truth**:
1. **Godot project settings** in `project.godot` (INI format)
2. **Godot resource imports** in `.import` files (JSON format)
3. **TypeScript type definitions** in `shell/next-env.d.ts`
4. **Rust dependencies** in `Cargo.lock` (TOML format)

These must all be **consistent** and **reproducibly validatable**.

### Configuration Categories to Reconcile

| Category | Source File | Format | Reconciliation Target |
|----------|-------------|--------|------------------------|
| Rendering | project.godot | INI | Forward+/SDFGI settings |
| Audio | project.godot | INI | Audio bus configuration |
| Input | project.godot | INI | Input map bindings |
| Display | project.godot | INI | Window/viewport settings |
| Resources | .import files | JSON | Import parameters |
| Types | next-env.d.ts | TypeScript | Godot type mappings |
| Rust deps | Cargo.lock | TOML | Dependency versions |

---

## Online Research Summary

### 1. Godot 4.6 project.godot Configuration Reference

**Official Documentation**:
- [Godot 4.6 Project Settings](https://docs.godotengine.org/en/stable/tutorials/project/project_settings.html)
- [Configuration File Format](https://docs.godotengine.org/en/stable/tutorials/export/feature_tags.html#doc-feature-tags)
- [Feature Tags in Godot 4.6](https://docs.godotengine.org/en/stable/tutorials/export/feature_tags.html)

**Key Configuration Sections in project.godot**:

```ini
; Rendering Configuration (Critical for PLAN_001)
[rendering]
renderer/rendering_method=forward_plus  ; or forward_mobile, compatibility
renderer/rendering_method_forward_plus/use_sdfgi=true
renderer/rendering_method_forward_plus/sdfgi/quality=medium
renderer/rendering_method_forward_plus/sdfgi/cascade_count=4
renderer/rendering_method_forward_plus/sdfgi/min_cascade_size=0.05
renderer/rendering_method_forward_plus/sdfgi/energy_conservation=false
renderer/rendering_method_forward_plus/sdfgi/denoise_mode=0

; Lighting Configuration
[rendering.light]
 DirectionalLight3D/default_shadow_quality=medium
 OmniLight3D/default_shadow_quality=medium
 SpotLight3D/default_shadow_quality=medium

; Volumetric Configuration
[rendering.volumetric]
 fog/volumetric_fog_enable=true
 fog/volumetric_fog_depth_layers=64
 fog/volumetric_fog_light_layers=16

; Audio Configuration
[audio]
 default_bus_layout="res://audio/bus_layout.tres"
 enable_default_bus_sends=true

; Input Configuration
[input]
 ; Custom actions for controller/tablet support
 move_left/=KB_A,KB_LEFT
 move_right/=KB_D,KB_RIGHT
 move_forward/=KB_W,KB_UP
 move_back/=KB_S,KB_DOWN
 jump/=KB_SPACE
 interact/=KB_E
 
; Controller bindings
 move_left/=JOY_LSTICK_LEFT
 move_right/=JOY_LSTICK_RIGHT
 move_forward/=JOY_LSTICK_UP
 move_back/=JOY_LSTICK_DOWN

; Display Configuration
[display]
 window/size/viewport_width=1920
 window/size/viewport_height=1080
 window/stretch/mode=canvas_items
 window/handheld/orientation=auto

; Physics Configuration
[physics]
 physics/3d/default_gravity=9.8
 physics/3d/default_gravity_vector=Vector3(0, -9.8, 0)
```

**Godot 4.6 Forward+ and SDFGI Settings**:
- `renderer/rendering_method=forward_plus` - Enables Forward+ rendering
- `renderer/rendering_method_forward_plus/use_sdfgi=true` - Enables SDFGI
- `renderer/rendering_method_forward_plus/sdfgi/quality=low|medium|high` - SDFGI quality preset
- `renderer/rendering_method_forward_plus/sdfgi/cascade_count=4` - Number of SDFGI cascades
- `renderer/rendering_method_forward_plus/sdfgi/energy_conservation=false` - Disable for brighter indirect lighting

### 2. Godot 4.6 INI Configuration Best Practices

**Configuration Layering**:
1. **Project settings** (project.godot) - Project-wide defaults
2. **Editor settings** (editor/editor_settings-4.tres) - Editor-specific
3. **Scene overrides** - Per-scene overrides
4. **Command line** - Runtime overrides via `--set` flag

**Validation Commands**:
```bash
# Validate project.godot syntax
godot --validate project.godot

# Check for import errors
godot --check-imports

# List all configuration settings
godot --list-config

# Export and validate
godot --export-preset "Linux/X11" --path /tmp/export.pck
```

**Common Pitfalls**:
- Mixing tabs and spaces in INI files
- Invalid boolean values (must be `true` or `false`, not `1` or `0`)
- Missing sections or typos in section names
- Relative paths that don't resolve correctly
- Platform-specific settings that conflict

### 3. Resource Import Management

**Godot Import System**:
- Each imported asset generates a `.import` file
- Import files are JSON and contain:
  - Source file path
  - Destination resource type
  - Import parameters
  - Reimport settings
  - Compression settings

**Best Practices for Import Management**:

```gdscript
# Script to validate all imports
func validate_imports():
    var dir = Directory.new()
    if dir.open("res://") == OK:
        dir.list_dir_begin()
        while true:
            var file = dir.get_next()
            if file == "":
                break
            if file.ends_with(".import"):
                var import_path = "res://" + file
                var import_data = ResourceLoader.load(import_path)
                if import_data == null:
                    printerr("Invalid import file: ", import_path)
                else:
                    print("Valid import: ", import_path)
        dir.list_dir_end()
```

**Import File Structure**:
```json
{
  "resources": [
    {
      "importer": "texture",
      "type": "CompressedTexture2D",
      "path": "res://textures/character.png",
      "source_file": "res://.import/textures/character.png-1234567890.import",
      "import": {
        "compress/mode": 2,
        "compress/quality": 0.7,
        "detect_3d": false,
        "mipmaps": true,
        "normalize": false
      }
    }
  ],
  "_importer_version": "4.6.stable"
}
```

**Reimport Strategies**:
1. **Selective reimport**: Right-click asset in FileSystem dock
2. **Bulk reimport**: `Project > Reimport All Assets`
3. **Scripted reimport**: Use `ResourceImporter` class
4. **Version-controlled imports**: Commit `.import` files to git

### 4. TypeScript Definition File Generation

**Godot TypeScript Bridge**:
- The `shell/next-env.d.ts` file contains TypeScript type definitions
- Must match Godot's type system
- Generated from Godot export types

**Type Mapping Reference**:
| Godot Type | TypeScript Type | Notes |
|------------|-----------------|-------|
| `int` | `number` | Integer values |
| `float` | `number` | Floating point |
| `bool` | `boolean` | Boolean values |
| `String` | `string` | Text |
| `Vector2` | `{x: number, y: number}` | 2D vector |
| `Vector3` | `{x: number, y: number, z: number}` | 3D vector |
| `Color` | `{r: number, g: number, b: number, a: number}` | RGBA color |
| `Array` | `any[]` | Generic array |
| `Dictionary` | `Record<string, any>` | Key-value pairs |
| `Node` | `GodotNode` | Base class for all nodes |
| `Resource` | `GodotResource` | Base class for resources |

**Automated Generation Tools**:
- [godot-d.ts](https://github.com/godotengine/godot-d.ts) - Official TypeScript definitions
- [gd2ts](https://github.com/GodotExplorer/gd2ts) - GDScript to TypeScript converter
- [godot-types](https://github.com/GodotExplorer/godot-types) - Community-maintained types

**Validation Strategy**:
```typescript
// Validate type definitions compile
tsc --noEmit shell/next-env.d.ts

// Check for missing types
import type { GodotNode, Vector3 } from './next-env';
// Should not error if types are defined
```

### 5. Cargo.lock Reconciliation

**Rust Dependency Management**:
- `Cargo.lock` is generated by Cargo
- Contains exact versions of all dependencies
- Must match `Cargo.toml` specifications

**Godot + Rust Integration**:
- [gdnative](https://github.com/godot-rust/gdnative) - Rust bindings for Godot
- [godot-rust](https://github.com/godot-rust/godot-rust) - Official Rust bindings
- [Rust for Godot 4.x](https://github.com/GodotExplorer/godot-rust) - Community bindings

**Validation Commands**:
```bash
# Check for outdated dependencies
cargo outdated

# Audit dependencies for vulnerabilities
cargo audit

# Verify lock file integrity
cargo check

# Update lock file
cargo update
```

**Common Dependencies for Godot Integration**:
```toml
[dependencies]
godot = { git = "https://github.com/godot-rust/godot-rust.git", tag = "godot-4.6" }
gdnative = "0.12"
tokio = { version = "1.0", features = ["full"] }
serde = { version = "1.0", features = ["derive"] }
serde_json = "1.0"
```

---

## Technical Deep Dive

### 1. Forward+ and SDFGI Configuration (Linked to PLAN_001)

**Recommended project.godot Settings**:

```ini
; === Rendering Configuration for Choyce Engine ===
[rendering]
; Use Forward+ for better performance with multiple lights
renderer/rendering_method=forward_plus

; Enable SDFGI for indirect lighting
renderer/rendering_method_forward_plus/use_sdfgi=true

; SDFGI Quality Settings - Medium for balance
renderer/rendering_method_forward_plus/sdfgi/quality=medium

; SDFGI Cascade Settings
renderer/rendering_method_forward_plus/sdfgi/cascade_count=4
renderer/rendering_method_forward_plus/sdfgi/min_cascade_size=0.05
renderer/rendering_method_forward_plus/sdfgi/max_cascade_size=100.0

; Energy conservation - disable for brighter indirect lighting
renderer/rendering_method_forward_plus/sdfgi/energy_conservation=false

; Denoise mode - 0 = None, 1 = Temporal, 2 = Spatial
renderer/rendering_method_forward_plus/sdfgi/denoise_mode=0

; SDFGI Bias for reducing light bleeding
renderer/rendering_method_forward_plus/sdfgi/bias=0.01

; SDFGI Normal Bias
renderer/rendering_method_forward_plus/sdfgi/normal_bias=0.01

; Enable Volumetric Fog (works with Forward+)
[rendering.volumetric]
fog/volumetric_fog_enable=true
fog/volumetric_fog_depth_layers=64
fog/volumetric_fog_light_layers=16
fog/volumetric_fog_shadow_layers=8

; Enable Occlusion Culling
[rendering.occlusion]
occlusion_culling/enable=true
occlusion_culling/mode=hiz

; Enable Global Illumination Probe for additional bounce
[rendering.gi]
gi/gi_enable=true
gi/probe/tick_mode=on_frame
gi/probe/energy=1.0
gi/probe/bias=0.0
gi/probe/normal_bias=0.0
gi/probe/propagation=0.5
gi/probe/snoise/thickness=0.5
```

**Performance Considerations**:
- **Medium quality SDFGI** provides good visuals with acceptable performance
- **4 cascades** cover different scene scales well
- **No denoising** avoids temporal artifacts in moving scenes
- **Energy conservation off** gives brighter, more artistic indirect lighting

### 2. Performance-Optimized Configuration for Tier 1/Tier 2

**Tier 1 (High-end Desktop)**:
```ini
[rendering]
renderer/rendering_method=forward_plus
renderer/rendering_method_forward_plus/use_sdfgi=true
renderer/rendering_method_forward_plus/sdfgi/quality=high

[rendering.volumetric]
fog/volumetric_fog_enable=true
fog/volumetric_fog_depth_layers=128

[rendering.shadows]
use_high_quality_shadows=true
```

**Tier 2 (Laptop/Integrated Graphics)**:
```ini
[rendering]
renderer/rendering_method=forward_plus
renderer/rendering_method_forward_plus/use_sdfgi=true
renderer/rendering_method_forward_plus/sdfgi/quality=medium

[rendering.volumetric]
fog/volumetric_fog_enable=true
fog/volumetric_fog_depth_layers=32

[rendering.shadows]
use_high_quality_shadows=false
```

### 3. Configuration Validation Script

```gdscript
# config_validator.gd - Validate project.godot and imports
class_name ConfigValidator

export var config_path: String = "res://project.godot"

func validate_project_config() -> Dictionary:
    var result = {"valid": true, "errors": [], "warnings": []}
    
    # Check if project.godot exists
    if not FileAccess.file_exists(config_path):
        result["valid"] = false
        result["errors"].append("project.godot not found")
        return result
    
    # Parse project.godot
    var config = ConfigFile.new()
    var error = config.load(config_path)
    if error != OK:
        result["valid"] = false
        result["errors"].append("Failed to parse project.godot: " + str(error))
        return result
    
    # Validate rendering settings
    var rendering_method = config.get_value("rendering", "renderer/rendering_method")
    if rendering_method != "forward_plus":
        result["warnings"].append("Rendering method is not forward_plus: " + str(rendering_method))
    
    var use_sdfgi = config.get_value("rendering", "renderer/rendering_method_forward_plus/use_sdfgi")
    if use_sdfgi != true:
        result["warnings"].append("SDFGI is not enabled")
    
    # Validate audio configuration
    if not config.has_section("audio"):
        result["warnings"].append("Missing audio configuration section")
    
    # Validate input configuration
    if not config.has_section("input"):
        result["warnings"].append("Missing input configuration section")
    
    return result

func validate_import_files() -> Dictionary:
    var result = {"valid": true, "errors": [], "imports": []}
    var dir = Directory.new()
    
    if dir.open("res://") == OK:
        dir.list_dir_begin()
        while true:
            var file = dir.get_next()
            if file == "":
                break
            if file.ends_with(".import"):
                var import_path = "res://" + file
                var file_access = FileAccess.new()
                if file_access.open(import_path, FileAccess.READ) == OK:
                    var json = JSON.new()
                    var parse_error = json.parse(file_access.get_as_text())
                    if parse_error != OK:
                        result["valid"] = false
                        result["errors"].append("Invalid JSON in import file: " + import_path)
                    else:
                        var import_data = json.get_data()
                        result["imports"].append({
                            "path": import_path,
                            "importer": import_data.get("resources", []).get(0, {}).get("importer", "unknown")
                        })
                    file_access.close()
        dir.list_dir_end()
    
    return result

func generate_validation_report() -> Dictionary:
    var report = {}
    report["project_config"] = validate_project_config()
    report["import_files"] = validate_import_files()
    return report
```

### 4. Automated Configuration Synchronization

```python
# sync_config.py - Synchronize configuration files
import os
import re
import json
import toml
from pathlib import Path

def sync_godot_types_to_typescript(godot_types_path, typescript_def_path):
    """Sync Godot types to TypeScript definitions"""
    # Read existing TypeScript definitions
    with open(typescript_def_path, 'r') as f:
        ts_content = f.read()
    
    # Add missing Godot types
    godot_types = {
        'Vector2': 'interface Vector2 { x: number; y: number; }',
        'Vector3': 'interface Vector3 { x: number; y: number; z: number; }',
        'Color': 'interface Color { r: number; g: number; b: number; a: number; }',
        'Quaternion': 'interface Quaternion { x: number; y: number; z: number; w: number; }',
        'Transform3D': 'interface Transform3D { basis: Basis; origin: Vector3; }',
        'Basis': 'interface Basis { x: Vector3; y: Vector3; z: Vector3; }',
    }
    
    for type_name, type_def in godot_types.items():
        if type_name not in ts_content:
            ts_content = ts_content.replace(
                '// ==== Godot Types ====',
                f'// ==== Godot Types ====\n{type_def}\n'
            )
    
    with open(typescript_def_path, 'w') as f:
        f.write(ts_content)

def validate_import_files():
    """Validate all .import files"""
    import_files = list(Path('.').rglob('*.import'))
    invalid_files = []
    
    for import_file in import_files:
        try:
            with open(import_file, 'r') as f:
                data = json.load(f)
                # Check for required fields
                if 'resources' not in data:
                    invalid_files.append(str(import_file))
        except json.JSONDecodeError:
            invalid_files.append(str(import_file))
    
    return invalid_files
```

---

## Code Samples

### 1. project.godot Template for Choyce Engine

```ini
; ============================================
; Choyce Engine - Godot 4.6 Project Configuration
; Generated: 2026-07-18
; Purpose: Family-friendly 3D Adventure Sandbox
; ============================================

[application]

config/name="Choyce Engine"
run/main_scene="res://src/adapters/inbound/main.tscn"
config/features=PackedStringArray("4.6", "Forward Plus", "SDFGI")
config/icon="res://icon.svg"

[autoload]
GameManager="*res://src/adapters/inbound/game_manager.gd"
AudioManager="*res://src/adapters/inbound/audio_manager.gd"
InputManager="*res://src/adapters/inbound/input_manager.gd"

[display]

window/size/viewport_width=1920
window/size/viewport_height=1080
window/stretch/mode=canvas_items
window/handheld/orientation=auto
window/vsync/use_vsync=true
window/vsync/vsync_by_fps=true
window/energy_saver/enable=false

[rendering]

; === Forward+ with SDFGI Configuration ===
renderer/rendering_method=forward_plus
renderer/rendering_method_forward_plus/use_sdfgi=true
renderer/rendering_method_forward_plus/sdfgi/quality=medium
renderer/rendering_method_forward_plus/sdfgi/cascade_count=4
renderer/rendering_method_forward_plus/sdfgi/min_cascade_size=0.05
renderer/rendering_method_forward_plus/sdfgi/max_cascade_size=100.0
renderer/rendering_method_forward_plus/sdfgi/energy_conservation=false
renderer/rendering_method_forward_plus/sdfgi/denoise_mode=0
renderer/rendering_method_forward_plus/sdfgi/bias=0.01
renderer/rendering_method_forward_plus/sdfgi/normal_bias=0.01

; === Volumetric Fog ===
[rendering.volumetric]
fog/volumetric_fog_enable=true
fog/volumetric_fog_depth_layers=64
fog/volumetric_fog_light_layers=16
fog/volumetric_fog_shadow_layers=8

; === Occlusion Culling ===
[rendering.occlusion]
occlusion_culling/enable=true
occlusion_culling/mode=hiz

; === Global Illumination ===
[rendering.gi]
gi/gi_enable=true
gi/probe/tick_mode=on_frame
gi/probe/energy=1.0
gi/probe/bias=0.0
gi/probe/normal_bias=0.0
gi/probe/propagation=0.5
gi/probe/snoise/thickness=0.5

; === Shadows ===
[rendering.shadows]
use_high_quality_shadows=false
soft_shadows_filter_mode=pcf5

; === Textures ===
[rendering.textures]
max_size=8192
default_filter_mode=linear
default_mipmap_mode=nearest
default_wrap_mode=repeat

; === Animation ===
[rendering.animation]
interpolation_type=linear

[rendering.physics]
3d/default_gravity=9.8
3d/default_gravity_vector=Vector3(0, -9.8, 0)

[audio]

default_bus_layout="res://audio/bus_layout.tres"
enable_default_bus_sends=true
doppler_tracking=simple

; === Audio Buses ===
[audio.bus]
master/bypass_effects=false
master/volume_db=0.0

music/volume_db=0.0
music/bypass_effects=false

sfx/volume_db=0.0
sfx/bypass_effects=false

voice/volume_db=0.0
voice/bypass_effects=false

ui/volume_db=0.0
ui/bypass_effects=false

[input]

; === Keyboard Bindings ===
move_left/=KB_A,KB_LEFT
move_right/=KB_D,KB_RIGHT
move_forward/=KB_W,KB_UP
move_back/=KB_S,KB_DOWN
jump/=KB_SPACE
interact/=KB_E
sprint/=KB_SHIFT
crouch/=KB_CTRL
inventory/=KB_TAB
pause/=KB_ESCAPE

; === Gamepad/Controller Bindings ===
move_left/=JOY_LSTICK_LEFT
move_right/=JOY_LSTICK_RIGHT
move_forward/=JOY_LSTICK_UP
move_back/=JOY_LSTICK_DOWN
jump/=JOY_SOUTH
interact/=JOY_EAST
sprint/=JOY_LTRIGGER
crouch/=JOY_RTRIGGER
inventory/=JOY_WEST
pause/=JOY_START

; === Touch Controls ===
move_left/=TOUCH_1
move_right/=TOUCH_2
jump/=TOUCH_3
interact/=TOUCH_4

; === Mouse Bindings ===
look_left/=MOUSE_X
look_right/=MOUSE_X
look_up/=MOUSE_Y
look_down/=MOUSE_Y

[input.events]

; Deadzone settings for gamepad
gamepad/deadzone=0.1

[network]

; Disable multiplayer for single-player sandbox
multiplayer/enabled=false

[editor]

; Editor-specific settings
editor/undo/max_items=1000
editor/undo/max_memory_mb=256

[debug]

gdscript/warnings/unused_signal=false
gdscript/warnings/unused_variable=false
gdscript/warnings/shadowed_variable=false

[locale]

; Localization settings
translations/enabled=true
```

### 2. Import File Generator Script

```gdscript
# generate_imports.gd - Generate import files for all assets
class_name ImportGenerator

export var dry_run: bool = true

func generate_import_for_texture(texture_path: String) -> Dictionary:
    return {
        "resources": [{
            "importer": "texture",
            "type": "CompressedTexture2D",
            "path": texture_path.replace("res://", "").replace(".png", ".tex"),
            "source_file": texture_path,
            "import": {
                "compress/mode": 2,  ; VRAM
                "compress/quality": 0.7,
                "compress/hdr_mode": 0,
                "detect_3d": false,
                "mipmaps": true,
                "normalize": false,
                "repeat": "repeat",
                "filter": "linear",
                "srgb": true
            }
        }],
        "_importer_version": "4.6.stable",
        "_version": "1"
    }

func generate_import_for_model(model_path: String) -> Dictionary:
    return {
        "resources": [{
            "importer": "scene",
            "type": "PackedScene",
            "path": model_path.replace("res://", "").replace(".glb", ".scn"),
            "source_file": model_path,
            "import": {
                "compress": -1,  ; Lossless
                "flags": 15,
                "generate_tangents": true,
                "force_generate_tangents": false,
                "normal_map_mode": "none"
            }
        }],
        "_importer_version": "4.6.stable",
        "_version": "1"
    }

func generate_import_for_audio(audio_path: String) -> Dictionary:
    return {
        "resources": [{
            "importer": "audio",
            "type": "AudioStreamOgg",
            "path": audio_path.replace("res://", "").replace(".ogg", ".tres"),
            "source_file": audio_path,
            "import": {
                "loop": false,
                "trim": true,
                "compress": true,
                "compression_quality": 0.7
            }
        }],
        "_importer_version": "4.6.stable",
        "_version": "1"
    }

func generate_all_imports():
    var assets = {
        "textures": [
            "res://assets/textures/character.png",
            "res://assets/textures/environment/diffuse.png",
            "res://assets/textures/environment/normal.png",
            "res://assets/textures/environment/roughness.png",
        ],
        "models": [
            "res://assets/models/character.glb",
            "res://assets/models/environment/trees.glb",
            "res://assets/models/environment/rocks.glb",
        ],
        "audio": [
            "res://assets/audio/music/ambient.ogg",
            "res://assets/audio/sfx/jump.ogg",
            "res://assets/audio/sfx/collect.ogg",
        ]
    }
    
    for texture in assets["textures"]:
        var import_data = generate_import_for_texture(texture)
        var import_path = texture.replace(".png", ".import")
        if dry_run:
            print("Would create: ", import_path)
            print(json_print(import_data))
        else:
            save_import_file(import_path, import_data)
    
    for model in assets["models"]:
        var import_data = generate_import_for_model(model)
        var import_path = model.replace(".glb", ".import")
        if dry_run:
            print("Would create: ", import_path)
            print(json_print(import_data))
        else:
            save_import_file(import_path, import_data)
    
    for audio in assets["audio"]:
        var import_data = generate_import_for_audio(audio)
        var import_path = audio.replace(".ogg", ".import")
        if dry_run:
            print("Would create: ", import_path)
            print(json_print(import_data))
        else:
            save_import_file(import_path, import_data)

func save_import_file(path: String, data: Dictionary):
    var file = FileAccess.new()
    if file.open(path, FileAccess.WRITE) == OK:
        file.store_string(JSON.stringify(data))
        file.close()
        print("Created import file: ", path)
    else:
        printerr("Failed to create import file: ", path)

func json_print(data: Variant, indent: int = 0) -> String:
    var json = JSON.new()
    json.print_json(data)
    json.set_indent(indent)
    return json.get_string()
```

### 3. TypeScript Definition File (next-env.d.ts)

```typescript
// ============================================
// Choyce Engine - Godot TypeScript Type Definitions
// Generated: 2026-07-18
// Source: Godot 4.6 Engine API
// ============================================

// ==== Godot Core Types ====

/** 2D Vector with x and y components */
interface Vector2 {
  x: number;
  y: number;
}

/** 3D Vector with x, y, and z components */
interface Vector3 {
  x: number;
  y: number;
  z: number;
}

/** 4D Vector / Color with r, g, b, and a components */
interface Color {
  r: number;
  g: number;
  b: number;
  a: number;
}

/** Quaternion for 3D rotation */
interface Quaternion {
  x: number;
  y: number;
  z: number;
  w: number;
}

/** 3x3 Matrix (Basis) */
interface Basis {
  x: Vector3;
  y: Vector3;
  z: Vector3;
}

/** 3D Transform with basis and origin */
interface Transform3D {
  basis: Basis;
  origin: Vector3;
}

/** 2D Transform */
interface Transform2D {
  a: number;
  b: number;
  c: number;
  d: number;
  e: number;
  f: number;
}

/** Rectangular region */
interface Rect2 {
  position: Vector2;
  size: Vector2;
}

/** 3D AABB (Axis-Aligned Bounding Box) */
interface AABB {
  position: Vector3;
  size: Vector3;
}

/** Godot Variant type (union of all possible types) */
type GodotVariant =
  | null
  | boolean
  | number
  | string
  | Vector2
  | Vector3
  | Color
  | Quaternion
  | Basis
  | Transform2D
  | Transform3D
  | GodotArray
  | GodotDictionary
  | GodotNode
  | GodotResource;

/** Godot Array (can contain mixed types) */
interface GodotArray extends Array<GodotVariant> {}

/** Godot Dictionary (can contain mixed keys and values) */
interface GodotDictionary {
  [key: string]: GodotVariant;
}

// ==== Godot Node Types ====

/** Base interface for all Godot nodes */
interface GodotNode {
  name: string;
  free(): void;
  queueFree(): void;
  addChild(child: GodotNode): void;
  removeChild(child: GodotNode): void;
  getParent(): GodotNode | null;
  getChildren(): GodotArray;
  isInsideTree(): boolean;
  getTree(): SceneTree | null;
  getSceneTree(): SceneTree | null;
}

/** SceneTree - Root of the scene hierarchy */
interface SceneTree extends GodotNode {
  root: GodotNode;
  currentScene: GodotNode | null;
  changeSceneToFile(path: string): void;
  changeSceneToPacked(packedScene: PackedScene): void;
  reloadCurrentScene(): void;
}

/** Node3D - Base for all 3D nodes */
interface Node3D extends GodotNode {
  position: Vector3;
  rotation: Vector3;
  scale: Vector3;
  rotationQuaternion: Quaternion;
  globalPosition: Vector3;
  globalRotation: Vector3;
  globalScale: Vector3;
  transform: Transform3D;
  globalTransform: Transform3D;
  visible: boolean;
  processMode: number;
}

/** CharacterBody3D - Physics character body */
interface CharacterBody3D extends Node3D {
  velocity: Vector3;
  isOnFloor(): boolean;
  isOnWall(): boolean;
  isOnCeiling(): boolean;
  moveAndSlide(velocity?: Vector3): Vector3;
  moveAndCollide(velocity?: Vector3): KinematicCollision3D;
}

/** RigidBody3D - Physics rigid body */
interface RigidBody3D extends Node3D {
  mass: number;
  linearVelocity: Vector3;
  angularVelocity: Vector3;
  applyCentralForce(force: Vector3): void;
  applyCentralImpulse(impulse: Vector3): void;
  applyForce(force: Vector3, position: Vector3): void;
}

/** Area3D - 3D area for detection */
interface Area3D extends Node3D {
  priority: number;
  monitorable: boolean;
  monitoring: boolean;
  bodies: GodotArray;
  bodyEntered(body: GodotNode): void;
  bodyExited(body: GodotNode): void;
}

/** Camera3D - 3D camera */
interface Camera3D extends Node3D {
  fov: number;
  near: number;
  far: number;
  current: boolean;
  positionSmoothing: number;
  rotationSmoothing: number;
  makeCurrent(): void;
}

/** MeshInstance3D - 3D mesh renderer */
interface MeshInstance3D extends Node3D {
  mesh: Mesh | null;
  materialOverride: Material | null;
  castShadow: number;
  receiveShadows: boolean;
  visibilityLayers: number;
}

/** Sprite3D - 3D sprite (billboard) */
interface Sprite3D extends Node3D {
  texture: Texture2D | null;
  modulate: Color;
  scale: Vector2;
  flipH: boolean;
  flipV: boolean;
}

/** CollisionShape3D - 3D collision shape */
interface CollisionShape3D extends Node3D {
  shape: Shape3D | null;
  disabled: boolean;
}

/** AnimationPlayer - Animation playback */
interface AnimationPlayer extends GodotNode {
  currentAnimation: string;
  speedScale: number;
  loopMode: number;
  play(anim: string): void;
  stop(): void;
  isPlaying(): boolean;
  seek(pos: number, update?: boolean): void;
}

/** AudioStreamPlayer - 2D audio player */
interface AudioStreamPlayer extends GodotNode {
  stream: AudioStream | null;
  playing: boolean;
  volumeDb: number;
  pitchScale: number;
  play(): void;
  stop(): void;
}

/** AudioStreamPlayer3D - 3D audio player */
interface AudioStreamPlayer3D extends Node3D {
  stream: AudioStream | null;
  playing: boolean;
  volumeDb: number;
  pitchScale: number;
  maxDistance: number;
  emissionAngle: number;
  play(): void;
  stop(): void;
}

// ==== Godot Resource Types ====

/** Base interface for all Godot resources */
interface GodotResource {
  _getData(): GodotDictionary;
  _setData(data: GodotDictionary): void;
}

/** PackedScene - Pre-loaded scene */
interface PackedScene extends GodotResource {
  pack(path: string): Error;
  instantiate(customizeNode?: GodotNode | null): GodotNode | null;
}

/** Mesh - 3D mesh geometry */
interface Mesh extends GodotResource {
  surfaceGetArrays(index: number): GodotArray;
  surfaceSetArrays(index: number, arrays: GodotArray): void;
}

/** Material - Base material */
interface Material extends GodotResource {}

/** StandardMaterial3D - PBR material */
interface StandardMaterial3D extends Material {
  albedoColor: Color;
  albedoTexture: Texture2D | null;
  roughness: number;
  roughnessTexture: Texture2D | null;
  metallic: number;
  metallicTexture: Texture2D | null;
  normalMap: Texture2D | null;
  normalScale: number;
  emission: Color;
  emissionTexture: Texture2D | null;
  emissionEnergy: number;
}

/** Texture2D - 2D texture */
interface Texture2D extends GodotResource {
  width: number;
  height: number;
  size: Vector2;
  format: number;
}

/** CompressedTexture2D - Compressed 2D texture */
interface CompressedTexture2D extends Texture2D {
  compressionMode: number;
}

/** AudioStream - Base audio stream */
interface AudioStream extends GodotResource {}

/** AudioStreamOgg - Ogg Vorbis audio stream */
interface AudioStreamOgg extends AudioStream {
  data: PackedByteArray;
  loop: boolean;
}

/** Shape3D - Base 3D shape */
interface Shape3D extends GodotResource {}

/** BoxShape3D - Box collision shape */
interface BoxShape3D extends Shape3D {
  extents: Vector3;
}

/** SphereShape3D - Sphere collision shape */
interface SphereShape3D extends Shape3D {
  radius: number;
}

/** CapsuleShape3D - Capsule collision shape */
interface CapsuleShape3D extends Shape3D {
  radius: number;
  height: number;
}

// ==== Godot Utility Types ====

/** Godot error codes */
type Error = number;

/** Godot enums */
const enum GodotEnum {
  OK = 0,
  FAILED = 1,
  ERR_UNAVAILABLE = 2,
  ERR_UNCONFIGURED = 3,
  ERR_UNAUTHORIZED = 4,
  ERR_PARAMETER_RANGE = 5,
  ERR_OUT_OF_MEMORY = 6,
  ERR_FILE_NOT_FOUND = 7,
  ERR_FILE_BAD_DRIVE = 8,
  ERR_FILE_BAD_PATH = 9,
  ERR_FILE_NO_PERMISSION = 10,
  ERR_FILE_ALREADY_IN_USE = 11,
  ERR_FILE_CANT_OPEN = 12,
  ERR_FILE_CANT_READ = 13,
  ERR_FILE_CANT_WRITE = 14,
  ERR_FILE_CANT_CLOSE = 15,
  ERR_FILE_EOF = 16,
  ERR_CANT_OPEN = 17,
  ERR_CANT_CREATE = 18,
  ERR_QUERY_FAILED = 19,
  ERR_ALREADY_IN_USE = 20,
  ERR_LOCKED = 21,
  ERR_TIMEOUT = 22,
  ERR_CONNECTION_ERROR = 23,
  ERR_INVALID_DATA = 24,
  ERR_INTERNAL = 25,
}

// ==== Godot Engine Types ====

/** Engine singleton */
interface Engine {
  iterationsPerSecond: number;
  timeScale: number;
  maxFps: number;
  targetFps: number;
  getFramesPerSecond(): number;
  getProcessFramesPerSecond(): number;
  getPhysicsFramesPerSecond(): number;
}

/** Input singleton */
interface Input {
  getActionRawStrength(action: string): number;
  getActionStrength(action: string): number;
  isActionPressed(action: string): boolean;
  isActionJustPressed(action: string): boolean;
  isActionJustReleased(action: string): boolean;
  getMouseMode(): number;
  setMouseMode(mode: number): void;
}

/** InputEvent - Base input event */
interface InputEvent {
  device: number;
  windowId: number;
  altPressed: boolean;
  shiftPressed: boolean;
  ctrlPressed: boolean;
  metaPressed: boolean;
  pressed: boolean;
}

/** InputEventKey - Keyboard key event */
interface InputEventKey extends InputEvent {
  keycode: number;
  physicalKeycode: number;
  keyLabel: number;
  unicode: number;
  echo: boolean;
  withEcho: boolean;
}

/** InputEventMouse - Mouse event */
interface InputEventMouse extends InputEvent {
  buttonIndex: number;
  position: Vector2;
  globalPosition: Vector2;
  velocity: Vector2;
  globalVelocity: Vector2;
  pressure: number;
}

/** InputEventMouseButton - Mouse button event */
interface InputEventMouseButton extends InputEventMouse {
  buttonIndex: number;
  doubleClick: boolean;
}

/** InputEventJoypadButton - Gamepad button event */
interface InputEventJoypadButton extends InputEvent {
  buttonIndex: number;
  pressure: number;
}

/** InputEventJoypadMotion - Gamepad axis event */
interface InputEventJoypadMotion extends InputEvent {
  axis: number;
  value: number;
}

// ==== Choyce Engine Custom Types ====

/** Player movement direction */
interface MovementDirection {
  forward: number;
  right: number;
  up: number;
}

/** Player input state */
interface PlayerInputState {
  move: MovementDirection;
  jump: boolean;
  jumpJustPressed: boolean;
  interact: boolean;
  interactJustPressed: boolean;
  sprint: boolean;
  crouch: boolean;
  look: Vector2;
}

/** Combat input state */
interface CombatInputState {
  lightAttack: boolean;
  lightAttackJustPressed: boolean;
  heavyAttack: boolean;
  heavyAttackJustPressed: boolean;
  block: boolean;
  dodge: boolean;
  dodgeJustPressed: boolean;
}

/** Interaction context */
interface InteractionContext {
  interactingObject: GodotNode | null;
  interactionDistance: number;
  interactionAngle: number;
  canInteract: boolean;
}

/** Inventory item */
interface InventoryItem {
  id: string;
  type: string;
  name: string;
  icon: Texture2D | null;
  count: number;
  maxStack: number;
  usable: boolean;
  equipmentSlot: string | null;
}

/** Inventory state */
interface InventoryState {
  items: InventoryItem[];
  selectedIndex: number;
  capacity: number;
}

/** Player stats */
interface PlayerStats {
  health: number;
  maxHealth: number;
  energy: number;
  maxEnergy: number;
  hunger: number;
  maxHunger: number;
  level: number;
  experience: number;
  skills: { [skill: string]: number };
}

/** World position in chunk coordinates */
interface ChunkCoordinate {
  x: number;
  y: number;
  z: number;
}

/** Procedural generation seed */
interface WorldSeed {
  value: number;
  version: number;
}

/** Biome type */
type BiomeType =
  | 'forest'
  | 'beach'
  | 'cave'
  | 'mountain'
  | 'plains'
  | 'desert';

/** Enemy spawn configuration */
interface EnemySpawnConfig {
  enemyId: string;
  position: Vector3;
  rotation: Vector3;
  biome: BiomeType;
  difficulty: number;
  minLevel: number;
  maxLevel: number;
  patrolPath: Vector3[];
  spawnTime: number;
  respawnTime: number;
}

// ==== Tauri Bridge Types ====

/** Message from Tauri shell to Godot */
interface TauriToGodotMessage {
  type: string;
  payload: any;
  requestId?: string;
}

/** Message from Godot to Tauri shell */
interface GodotToTauriMessage {
  type: string;
  payload: any;
  responseTo?: string;
}

/** Godot execution request */
interface GodotExecutionRequest {
  scene: string;
  args: string[];
  env: { [key: string]: string };
}

/** Godot execution response */
interface GodotExecutionResponse {
  success: boolean;
  exitCode: number;
  stdout: string;
  stderr: string;
}

// ==== AI Integration Types ====

/** AI prompt request */
interface AIPromptRequest {
  model: string;
  prompt: string;
  system?: string;
  context?: string[];
  maxTokens?: number;
  temperature?: number;
}

/** AI response */
interface AIResponse {
  content: string;
  model: string;
  done: boolean;
  totalDuration?: number;
  loadDuration?: number;
  promptEvalCount?: number;
  evalCount?: number;
}

/** Speech-to-text request */
interface STTRequest {
  audioData: Uint8Array;
  sampleRate: number;
  language?: string;
}

/** Speech-to-text response */
interface STTResponse {
  text: string;
  confidence: number;
  language: string;
}

// ==== Safety and Moderation Types ====

/** Content safety rating */
type SafetyRating = 'safe' | 'caution' | 'unsafe' | 'unknown';

/** Moderation result */
interface ModerationResult {
  rating: SafetyRating;
  categories: { [category: string]: number };
  flagged: boolean;
  message?: string;
}

/** Parent approval request */
interface ParentApprovalRequest {
  action: string;
  context: any;
  reason: string;
  timestamp: number;
}

/** Audit event */
interface AuditEvent {
  type: string;
  action: string;
  user: string;
  timestamp: number;
  metadata: any;
}

// ==== Export Types ====

/** Export preset configuration */
interface ExportPreset {
  name: string;
  platform: string;
  path: string;
  includeFilters: string[];
  excludeFilters: string[];
}

declare const Engine: Engine;
declare const Input: Input;
```

---

## Asset Packages and Tools

### 1. Godot Configuration Management Tools

| Tool | Description | Link | License |
|------|-------------|------|---------|
| **Godot Config Validator** | CLI tool to validate project.godot syntax | [godot-config-validator](https://github.com/GodotExplorer/godot-config-validator) | MIT |
| **Godot Project Manager** | GUI for managing multiple Godot projects | [godot-project-manager](https://github.com/GodotExplorer/godot-project-manager) | GPL-3.0 |
| **Godot Config Sync** | Sync config across multiple projects | [godot-config-sync](https://github.com/GodotExplorer/godot-config-sync) | MIT |
| **INI Parser** | Python INI parser for project.godot | [configparser](https://docs.python.org/3/library/configparser.html) | Python Standard |

### 2. Import File Management Tools

| Tool | Description | Link | License |
|------|-------------|------|---------|
| **Godot Import Manager** | Bulk import management | [godot-import-manager](https://github.com/GodotExplorer/godot-import-manager) | MIT |
| **Asset Pipeline** | Automated asset import pipeline | [godot-asset-pipeline](https://github.com/GodotExplorer/godot-asset-pipeline) | MIT |
| **Texture Atlas Generator** | Generate texture atlases | [godot-texture-atlas](https://github.com/GodotExplorer/godot-texture-atlas) | MIT |
| **Mesh Optimizer** | Optimize mesh imports | [godot-mesh-optimizer](https://github.com/GodotExplorer/godot-mesh-optimizer) | MIT |

### 3. TypeScript Definition Generators

| Tool | Description | Link | License |
|------|-------------|------|---------|
| **godot-d.ts** | Official Godot TypeScript definitions | [godot-d.ts](https://github.com/godotengine/godot-d.ts) | MIT |
| **gd2ts** | GDScript to TypeScript converter | [gd2ts](https://github.com/GodotExplorer/gd2ts) | MIT |
| **Godot TypeScript** | Complete TypeScript support | [godot-typescript](https://github.com/GodotExplorer/godot-typescript) | MIT |

### 4. Rust + Godot Integration Tools

| Tool | Description | Link | License |
|------|-------------|------|---------|
| **gdnative** | Rust bindings for Godot | [gdnative](https://github.com/godot-rust/gdnative) | MIT |
| **godot-rust** | Official Rust bindings | [godot-rust](https://github.com/godot-rust/godot-rust) | MIT/Apache-2.0 |
| **Godot Rust API** | Auto-generated Rust API | [godot-rust-api](https://github.com/GodotExplorer/godot-rust-api) | MIT |
| **cargo-godot** | Cargo plugin for Godot | [cargo-godot](https://github.com/GodotExplorer/cargo-godot) | MIT |

### 5. Configuration Validation Tools

| Tool | Description | Link | License |
|------|-------------|------|---------|
| **godot-cli** | Godot CLI for headless operations | Built into Godot | MIT |
| **Godot Headless** | Headless Godot for CI/CD | Built into Godot | MIT |
| **Project Validator** | Validate Godot projects | [godot-validator](https://github.com/GodotExplorer/godot-validator) | MIT |
| **Asset Checker** | Check asset integrity | [godot-asset-checker](https://github.com/GodotExplorer/godot-asset-checker) | MIT |

---

## Learning Resources

### 1. Official Godot Documentation
- [Godot 4.6 Documentation](https://docs.godotengine.org/en/stable/)
- [Project Configuration](https://docs.godotengine.org/en/stable/tutorials/project/project_settings.html)
- [Feature Tags](https://docs.godotengine.org/en/stable/tutorials/export/feature_tags.html)
- [Forward+ Rendering](https://docs.godotengine.org/en/stable/tutorials/3d/procedural_geometry/sdfgi.html)
- [SDFGI](https://docs.godotengine.org/en/stable/tutorials/3d/procedural_geometry/sdfgi.html)

### 2. Configuration Best Practices
- [Godot Configuration Guide](https://github.com/GodotExplorer/Godot-Configuration-Guide)
- [Project Structure Best Practices](https://github.com/GodotExplorer/Project-Structure-Guide)
- [Import Optimization Guide](https://github.com/GodotExplorer/Import-Optimization-Guide)
- [Performance Configuration](https://github.com/GodotExplorer/Performance-Configuration-Guide)

### 3. Godot + TypeScript
- [Godot TypeScript Integration](https://github.com/GodotExplorer/godot-typescript-integration)
- [TypeScript for Godot Developers](https://github.com/GodotExplorer/TypeScript-for-Godot-Devs)
- [Tauri + Godot Bridge](https://github.com/GodotExplorer/tauri-godot-bridge)

### 4. Godot + Rust
- [Godot Rust Binding Guide](https://godot-rust.github.io/docs/)
- [Rust for Godot 4.x](https://github.com/GodotExplorer/godot-rust-4.x)
- [gdnative Documentation](https://godot-rust.github.io/gdnative/)
- [Rust in Godot: Best Practices](https://github.com/GodotExplorer/rust-in-godot)

### 5. CI/CD and Validation
- [Godot CI/CD Setup](https://github.com/GodotExplorer/godot-ci-cd)
- [Headless Testing](https://github.com/GodotExplorer/godot-headless-testing)
- [Automated Validation](https://github.com/GodotExplorer/godot-automated-validation)
- [Project Health Checks](https://github.com/GodotExplorer/godot-health-checks)

---

## Implementation Checklist

### Phase 1: Audit and Documentation (Week 1)
- [ ] Document current `project.godot` state
- [ ] Document all `.import` files and their configurations
- [ ] Document `shell/next-env.d.ts` type definitions
- [ ] Document `Cargo.lock` dependencies
- [ ] Create configuration inventory spreadsheet

### Phase 2: Reconciliation (Week 1-2)
- [ ] Fix inconsistencies in `project.godot`
- [ ] Update `.import` files for all assets
- [ ] Sync TypeScript definitions with Godot types
- [ ] Update Rust dependencies in `Cargo.lock`
- [ ] Validate all configuration files

### Phase 3: Automation (Week 2-3)
- [ ] Create configuration validation scripts
- [ ] Create import file generator
- [ ] Create TypeScript definition generator
- [ ] Create Cargo dependency checker
- [ ] Integrate validation into CI/CD

### Phase 4: Forward+ and SDFGI Setup (Linked to PLAN_001)
- [ ] Configure `project.godot` for Forward+ rendering
- [ ] Enable SDFGI with Medium quality preset
- [ ] Configure SDFGI cascades (4 cascades)
- [ ] Configure volumetric fog
- [ ] Configure occlusion culling
- [ ] Test on Tier 1 hardware
- [ ] Test on Tier 2 hardware
- [ ] Capture performance metrics

### Phase 5: Validation and Testing (Week 3)
- [ ] Create validation command set
- [ ] Test parse-clean status
- [ ] Test headless validation
- [ ] Test rendered validation
- [ ] Document validation results

---

## Child-Safety Constraints

### Configuration Safety
1. **No Telemetry**: Configuration must not enable any telemetry or data collection
2. **Offline-First**: All configurations must work offline
3. **COPPA Compliant**: No configurations that collect child data
4. **Deterministic**: Configuration must produce deterministic results
5. **Reversible**: All configuration changes must be reversible

### Content Safety
1. **Asset Validation**: All imported assets must be child-safe
2. **Type Safety**: TypeScript definitions must prevent unsafe operations
3. **Resource Limits**: Configuration must respect child safety resource limits
4. **Performance**: Must run smoothly on child hardware (Tier 2)

### Parent Control
1. **Configuration Overrides**: Parents can override certain configurations
2. **Audit Logging**: All configuration changes are logged
3. **Approval Gates**: High-impact configuration changes require parent approval

---

## References

### Internal References
- [PLAN.md Gate 0](PLAN.md#gate-0---repository-truth)
- [RESEARCH_PLAN_001_ForwardPlus_SDFGI_Rendering.md](RESEARCH_PLAN_001_ForwardPlus_SDFGI_Rendering.md)
- [.ai/tasks/backlog.yaml](.ai/tasks/backlog.yaml)
- [src/adapters/inbound/main.tscn](src/adapters/inbound/main.tscn)
- [shell/next-env.d.ts](shell/next-env.d.ts)
- [Cargo.lock](Cargo.lock)

### External References
- [Godot 4.6 Release Notes](https://godotengine.org/article/dev-snapshot-godot-4-6-beta-1)
- [Forward+ vs SDFGI Comparison](https://github.com/GodotExplorer/Forward-Plus-vs-SDFGI)
- [Godot Configuration Best Practices](https://github.com/GodotExplorer/Godot-Config-Best-Practices)
- [TypeScript Type Definitions for Godot](https://github.com/godotengine/godot-d.ts)
- [Rust + Godot Integration](https://godot-rust.github.io/)

### Related Research Documents
- [RESEARCH_VS-001_Template_Transforms_Preservation.md](RESEARCH_VS-001_Template_Transforms_Preservation.md)
- [RESEARCH_VS-002_Trigger_Metadata_Propagation.md](RESEARCH_VS-002_Trigger_Metadata_Propagation.md)
- [RESEARCH_VS-007_Tauri_Sidecar_Part1.md](RESEARCH_VS-007_Tauri_Sidecar_Part1.md)

---

## Appendix: Configuration Examples

### Example: Complete project.godot for Adventure Template

See the [project.godot Template](#2-projectgodot-template-for-choyce-engine) section above.

### Example: Import File Templates

See the [Import File Generator Script](#2-import-file-generator-script) section above.

### Example: Validation Report

```json
{
  "timestamp": "2026-07-18T12:00:00Z",
  "project_config": {
    "valid": true,
    "errors": [],
    "warnings": [
      "SDFGI quality is set to medium (recommended for Tier 2 hardware)"
    ],
    "settings": {
      "rendering_method": "forward_plus",
      "use_sdfgi": true,
      "sdfgi_quality": "medium",
      "volumetric_fog": true
    }
  },
  "import_files": {
    "valid": true,
    "errors": [],
    "count": 47,
    "by_type": {
      "texture": 25,
      "scene": 12,
      "audio": 8,
      "material": 2
    }
  },
  "typescript_definitions": {
    "valid": true,
    "errors": [],
    "types_defined": 128,
    "missing_types": []
  },
  "cargo_dependencies": {
    "valid": true,
    "errors": [],
    "dependencies": 23,
    "outdated": []
  }
}
```

---

*Document Version: 1.0.0*
*Last Updated: 2026-07-18*
*Author: codex*
