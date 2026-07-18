# PLAN-016: Identity/Ownership - Character Customization System - Deep Research Compendium

**Status**: in_progress  
**Specialty**: godot-character-customization  
**Gate**: VS-022 (PLAN.md Line 331-333)  
**Priority**: HIGH  
**Last Updated**: 2026-07-18  
**Child-Safety Consideration**: All customization options must be child-appropriate, with no disturbing or mature content; all changes are local-only and never affect gameplay stats

---

## Table of Contents

1. [Task Overview](#task-overview)
2. [Character Customization Architecture](#character-customization-architecture)
3. [Modular Character System Design](#modular-character-system-design)
4. [Skeleton3D & Bone Attachment](#skeleton3d--bone-attachment)
5. [Color Customization System](#color-customization-system)
6. [Part Swapping Implementation](#part-swapping-implementation)
7. [Swatch-Based Color Selection](#swatch-based-color-selection)
8. [Persistence System](#persistence-system)
9. [Child-Safe Customization Guidelines](#child-safe-customization-guidelines)
10. [CC0 Character & Part Assets](#cc0-character--part-assets)
11. [Code Samples & Implementation Patterns](#code-samples--implementation-patterns)
12. [Testing & Validation Checklist](#testing--validation-checklist)
13. [Learning Resources](#learning-resources)

---

## Task Overview

### Objective

Implement a **character customization system** (Identity/Ownership - VS-022) for Choyce Engine that:
- Provides **compact bounded swatches/face variants** for skin, hair, face, top, pants, and shoes
- Applies customization to the **actual third-person rig**
- **Persists locally** between sessions
- **Never affects gameplay stats** (cosmetic-only)
- Is **child-safe** with appropriate options
- Uses existing **Quaternius ninja.glb** as base character

### Source Reference

From PLAN.md (line 331-333):
> **Identity/ownership (VS-022):** compact bounded swatches/face variants for skin, hair, face, top, pants and shoes **apply to the actual third-person rig, persist locally and never affect gameplay stats.**

From PLAN.md (line 339-342):
> Acceptance requires a rendered child flow: find an axe → cut a tree → receive wood → find/make a pickaxe → mine stone; find, enter, drive and exit a rare vehicle; **safely restore bulldozer changes; see a chosen character look after a full replay**; and encounter an optional, readable, non-gory liminal creature.

### Key Requirements

- ✅ **6 customizable categories**: Skin, Hair, Face, Top, Pants, Shoes
- ✅ **Swatch-based selection**: Visual color picker for each category
- ✅ **Part swapping**: Different mesh variants (hair styles, clothing)
- ✅ **Applies to 3D rig**: Changes affect the actual third-person character
- ✅ **Local persistence**: Saves between game sessions
- ✅ **Cosmetic only**: No gameplay impact
- ✅ **Child-safe**: All options appropriate for children 5-8
- ✅ **Reversible**: Can always reset to defaults

### Acceptance Criteria

1. Player can customize skin color from predefined swatches
2. Player can customize hair style and color
3. Player can customize face variants
4. Player can customize top (shirt) variants
5. Player can customize pants variants
6. Player can customize shoes variants
7. Customization applies to the 3D character in-game
8. Customization persists across game sessions
9. Customization doesn't affect gameplay (speed, health, etc.)
10. All customization options are child-appropriate
11. Player can see their chosen character after replay

---

## Character Customization Architecture

### High-Level Architecture

```
CharacterCustomizationManager (Singleton)
├── CharacterRig (Skeleton3D + MeshInstances)
│   ├── Body (MeshInstance3D)
│   ├── Head (MeshInstance3D)
│   ├── Hair (MeshInstance3D)
│   ├── Top (MeshInstance3D)
│   ├── Pants (MeshInstance3D)
│   └── Shoes (MeshInstance3D)
├── CustomizationData (Resource)
│   ├── skin_color: Color
│   ├── hair_style: String
│   ├── hair_color: Color
│   ├── face_variant: String
│   ├── top_variant: String
│   └── pants_variant: String
│   └── shoes_variant: String
├── CustomizationUI (CanvasLayer)
│   ├── SkinSwatches (HFlowContainer)
│   ├── HairStyleSelector (HFlowContainer)
│   ├── HairColorSwatches (HFlowContainer)
│   ├── FaceVariantSelector (HFlowContainer)
│   ├── TopVariantSelector (HFlowContainer)
│   ├── PantsVariantSelector (HFlowContainer)
│   └── ShoesVariantSelector (HFlowContainer)
└── Persistence (ConfigFile/JSON)
```

### Node Tree Structure

```
Character (Node3D)
├── Skeleton3D (Bones: head, torso, arms, legs, etc.)
│   ├── BoneAttachment3D (for head attachments)
│   │   └── Hair (MeshInstance3D)
│   ├── BoneAttachment3D (for torso attachments)
│   │   └── Top (MeshInstance3D)
│   ├── BoneAttachment3D (for leg attachments)
│   │   └── Pants (MeshInstance3D)
│   └── BoneAttachment3D (for foot attachments)
│       └── Shoes (MeshInstance3D)
├── Body (MeshInstance3D, uses skin material)
└── Head (MeshInstance3D, uses face material)
```

### Data Flow

```
User Interaction (UI Click)
    → CustomizationUI receives input
    → CustomizationManager updates data
    → CharacterRig updates visuals
    → Persistence saves to disk

Game Load
    → Persistence loads from disk
    → CustomizationManager applies data
    → CharacterRig updates visuals
```

---

## Modular Character System Design

### Design Principles

1. **Shared Skeleton**: All character parts use the same Skeleton3D
2. **Bone Attachment**: Parts attached to specific bones via BoneAttachment3D
3. **Visibility Control**: Show/hide parts to swap variants
4. **Material Override**: Change colors via material_override
5. **Modular Assets**: Each part is a separate mesh that can be swapped

### Part Categories

| Category | Customization Type | Implementation |
|----------|---------------------|----------------|
| **Skin** | Color swatches | Material albedo_color |
| **Hair** | Style + Color | Mesh swap + material color |
| **Face** | Variant textures | Material albedo_texture |
| **Top** | Clothing variant | Mesh swap |
| **Pants** | Clothing variant | Mesh swap |
| **Shoes** | Footwear variant | Mesh swap |

### Modular Approach vs. Combined Mesh

| Approach | Pros | Cons | Recommendation |
|----------|------|------|----------------|
| **Combined Mesh** | Single draw call, better performance | Harder to customize, less flexible | ❌ Not recommended |
| **Modular Parts** | Full customization, flexible | More draw calls, more complex | ✅ **Recommended** |
| **Hybrid** | Best of both (base + overlays) | More complex setup | ⚠️ Consider for optimization |

---

## Skeleton3D & Bone Attachment

### Setting Up the Skeleton

**Step 1: Import or Create Base Skeleton**
```gdscript
# Using existing ninja.glb from Quaternius
var skeleton_scene := preload("res://data/models/quaternius/ninja.glb")
var skeleton := skeleton_scene.instantiate()
add_child(skeleton)

# Get the Skeleton3D node
var skeleton_3d := skeleton.find_child("Skeleton3D") as Skeleton3D
```

**Step 2: Verify Bone Structure**
```gdscript
# Print all bone names
func print_bone_structure(skeleton: Skeleton3D) -> void:
    var bone_count := skeleton.get_bone_count()
    for i in range(bone_count):
        var bone_name := skeleton.get_bone_name(i)
        var parent_bone := skeleton.get_bone_parent(i)
        var parent_name := skeleton.get_bone_name(parent_bone) if parent_bone >= 0 else "Root"
        print("%d: %s (parent: %s)" % [i, bone_name, parent_name])
```

### Bone Attachment for Character Parts

**Key Bones for Attachment:**

| Part | Attachment Bone | Purpose |
|------|-----------------|---------|
| Hair | `head` or `Head` | Attaches hair to head |
| Hat | `head` or `Head` | Attaches hats/helmets |
| Top (Shirt) | `torso`, `spine`, or `Torso` | Attaches upper clothing |
| Jacket | `torso` or `Torso` | Attaches outerwear |
| Pants | `pelvis` or `Hips` | Attaches lower clothing |
| Shoes | `foot.L`, `foot.R` | Attaches to feet |
| Gloves | `hand.L`, `hand.R` | Attaches to hands |

**Code Example: Attaching a Part**
```gdscript
func attach_part(part_mesh: MeshInstance3D, skeleton: Skeleton3D, bone_name: String) -> BoneAttachment3D:
    var bone_idx := skeleton.find_bone(bone_name)
    if bone_idx == -1:
        push_error("Bone '%s' not found in skeleton" % bone_name)
        return null
    
    var attachment := BoneAttachment3D.new()
    attachment.bone_name = bone_name
    skeleton.add_child(attachment)
    attachment.add_child(part_mesh)
    
    return attachment
```

### Complete Character Assembly

```gdscript
# character_assembler.gd

class_name CharacterAssembler

@export var skeleton_scene: PackedScene
@export var default_materials: Dictionary

var skeleton: Skeleton3D
var parts: Dictionary = {}

func _ready() -> void:
    _setup_skeleton()
    _setup_default_parts()

func _setup_skeleton() -> void:
    var instance := skeleton_scene.instantiate()
    skeleton = instance.find_child("Skeleton3D") as Skeleton3D
    if not skeleton:
        skeleton = instance.find_child("*") as Skeleton3D
    add_child(instance)

func _setup_default_parts() -> void:
    # Setup body (direct child of skeleton)
    var body := _find_mesh(instance, "Body")
    if not body:
        body = _find_mesh(instance, "MeshInstance3D")
    parts["body"] = body
    
    # Setup other parts with bone attachments
    # These would be added dynamically

func _find_mesh(node: Node, name_pattern: String) -> MeshInstance3D:
    if node is MeshInstance3D and node.name.match(name_pattern):
        return node
    for child in node.get_children():
        var found := _find_mesh(child, name_pattern)
        if found:
            return found
    return null

func attach_hair(hair_scene: PackedScene) -> void:
    var hair_instance := hair_scene.instantiate()
    var attachment := attach_part(hair_instance, skeleton, "head")
    parts["hair"] = hair_instance

func attach_top(top_scene: PackedScene) -> void:
    var top_instance := top_scene.instantiate()
    var attachment := attach_part(top_instance, skeleton, "torso")
    parts["top"] = top_instance

func set_skin_color(color: Color) -> void:
    if parts.has("body"):
        var material := parts["body"].material_override
        if not material:
            material = parts["body"].material_0.duplicate()
            parts["body"].material_override = material
        if material is StandardMaterial3D:
            material.albedo_color = color
```

---

## Color Customization System

### Color Categories

**Swatch-Based Colors for Choyce:**

| Category | Swatch Count | Color Options |
|----------|--------------|---------------|
| **Skin** | 8 | Light, medium, dark tones |
| **Hair** | 12 | Blonde, brown, black, red, etc. |
| **Face** | N/A (uses texture variants) | Different face textures |
| **Top** | N/A (uses mesh variants) | Different shirt models |
| **Pants** | N/A (uses mesh variants) | Different pants models |
| **Shoes** | N/A (uses mesh variants) | Different shoe models |

### Child-Safe Color Palette

```gdscript
const SKIN_COLORS := [
    Color(0.95, 0.85, 0.75),   # Light skin
    Color(0.85, 0.75, 0.65),   # Medium-light skin
    Color(0.75, 0.65, 0.55),   # Medium skin
    Color(0.65, 0.55, 0.45),   # Medium-dark skin
    Color(0.55, 0.45, 0.35),   # Dark skin
    Color(0.90, 0.75, 0.60),   # Light warm
    Color(0.70, 0.55, 0.40),   # Warm medium
    Color(0.50, 0.40, 0.30)    # Warm dark
]

const HAIR_COLORS := [
    Color(0.95, 0.85, 0.60),   # Blonde
    Color(0.85, 0.65, 0.40),   # Light brown
    Color(0.65, 0.45, 0.25),   # Brown
    Color(0.45, 0.25, 0.10),   # Dark brown
    Color(0.25, 0.10, 0.05),   # Black
    Color(0.90, 0.40, 0.30),   # Red
    Color(0.70, 0.30, 0.20),   # Auburn
    Color(0.90, 0.70, 0.40),   # Light red
    Color(0.60, 0.50, 0.40),   # Gray
    Color(0.30, 0.30, 0.30),   # Dark gray
    Color(0.95, 0.90, 0.80),   # Platinum
    Color(0.50, 0.40, 0.30)    # Chestnut
]
```

### Material Color Application

```gdscript
func apply_skin_color(color: Color) -> void:
    var body := parts.get("body")
    if body:
        var material := _get_or_create_material(body)
        if material is StandardMaterial3D:
            material.albedo_color = color

func apply_hair_color(color: Color) -> void:
    var hair := parts.get("hair")
    if hair:
        var material := _get_or_create_material(hair)
        if material is StandardMaterial3D:
            material.albedo_color = color

func _get_or_create_material(mesh: MeshInstance3D) -> BaseMaterial3D:
    if mesh.material_override:
        return mesh.material_override
    
    # Use first surface material or create new
    if mesh.get_surface_material_count() > 0:
        var surface_mat := mesh.get_surface_material(0)
        if surface_mat:
            mesh.material_override = surface_mat.duplicate()
            return mesh.material_override
    
    # Create new material
    var new_mat := StandardMaterial3D.new()
    mesh.material_override = new_mat
    return new_mat
```

---

## Part Swapping Implementation

### Part Variant System

**Part Definitions:**

```gdscript
# character_parts.gd

const HAIR_STYLES := [
    {"id": "short", "scene": "res://assets/characters/hair/short.tscn", "icon": "res://assets/ui/icons/hair_short.png"},
    {"id": "long", "scene": "res://assets/characters/hair/long.tscn", "icon": "res://assets/ui/icons/hair_long.png"},
    {"id": "ponytail", "scene": "res://assets/characters/hair/ponytail.tscn", "icon": "res://assets/ui/icons/hair_ponytail.png"},
    {"id": "braids", "scene": "res://assets/characters/hair/braids.tscn", "icon": "res://assets/ui/icons/hair_braids.png"}
]

const FACE_VARIANTS := [
    {"id": "default", "texture": "res://assets/characters/faces/default_albedo.png"},
    {"id": "smile", "texture": "res://assets/characters/faces/smile_albedo.png"},
    {"id": "serious", "texture": "res://assets/characters/faces/serious_albedo.png"}
]

const TOP_VARIANTS := [
    {"id": "tshirt", "scene": "res://assets/characters/tops/tshirt.tscn", "icon": "res://assets/ui/icons/top_tshirt.png"},
    {"id": "shirt", "scene": "res://assets/characters/tops/shirt.tscn", "icon": "res://assets/ui/icons/top_shirt.png"},
    {"id": "hoodie", "scene": "res://assets/characters/tops/hoodie.tscn", "icon": "res://assets/ui/icons/top_hoodie.png"},
    {"id": "jacket", "scene": "res://assets/characters/tops/jacket.tscn", "icon": "res://assets/ui/icons/top_jacket.png"}
]

const PANTS_VARIANTS := [
    {"id": "shorts", "scene": "res://assets/characters/pants/shorts.tscn", "icon": "res://assets/ui/icons/pants_shorts.png"},
    {"id": "jeans", "scene": "res://assets/characters/pants/jeans.tscn", "icon": "res://assets/ui/icons/pants_jeans.png"},
    {"id": "skirt", "scene": "res://assets/characters/pants/skirt.tscn", "icon": "res://assets/ui/icons/pants_skirt.png"}
]

const SHOES_VARIANTS := [
    {"id": "sneakers", "scene": "res://assets/characters/shoes/sneakers.tscn", "icon": "res://assets/ui/icons/shoes_sneakers.png"},
    {"id": "boots", "scene": "res://assets/characters/shoes/boots.tscn", "icon": "res://assets/ui/icons/shoes_boots.png"},
    {"id": "sandals", "scene": "res://assets/characters/shoes/sandals.tscn", "icon": "res://assets/ui/icons/shoes_sandals.png"}
]
```

### Part Swapping Code

```gdscript
# character_part_swapper.gd

func swap_hair(style_id: String) -> bool:
    var style_data := _find_style(HAIR_STYLES, style_id)
    if not style_data:
        return false
    
    # Remove current hair if exists
    if parts.has("hair") and parts["hair"]:
        parts["hair"].get_parent().remove_child(parts["hair"])
    
    # Load and attach new hair
    var hair_scene := load(style_data["scene"])
    if hair_scene:
        var hair_instance := hair_scene.instantiate()
        var attachment := attach_part(hair_instance, skeleton, "head")
        parts["hair"] = hair_instance
        
        # Apply current hair color
        if CustomizationData.hair_color != null:
            apply_hair_color(CustomizationData.hair_color)
        
        return true
    return false

func swap_face(variant_id: String) -> bool:
    var variant_data := _find_style(FACE_VARIANTS, variant_id)
    if not variant_data:
        return false
    
    # Update face texture on head material
    var head := parts.get("head")
    if head:
        var material := _get_or_create_material(head)
        if material is StandardMaterial3D and variant_data.has("texture"):
            material.albedo_texture = load(variant_data["texture"])
            return true
    return false

func swap_top(variant_id: String) -> bool:
    return _swap_part("top", TOP_VARIANTS, variant_id, "torso")

func swap_pants(variant_id: String) -> bool:
    return _swap_part("pants", PANTS_VARIANTS, variant_id, "pelvis")

func swap_shoes(variant_id: String) -> bool:
    return _swap_part("shoes", SHOES_VARIANTS, variant_id, "foot")

func _swap_part(part_type: String, variants: Array, variant_id: String, bone_name: String) -> bool:
    var variant_data := _find_style(variants, variant_id)
    if not variant_data:
        return false
    
    # Remove current part if exists
    if parts.has(part_type) and parts[part_type]:
        parts[part_type].get_parent().remove_child(parts[part_type])
    
    # Load and attach new part
    var part_scene := load(variant_data["scene"])
    if part_scene:
        var part_instance := part_scene.instantiate()
        
        # For shoes, we need to attach to both feet
        if part_type == "shoes":
            _attach_to_both_feet(part_instance, skeleton)
        else:
            var attachment := attach_part(part_instance, skeleton, bone_name)
        
        parts[part_type] = part_instance
        return true
    return false

func _attach_to_both_feet(shoes: Node3D, skeleton: Skeleton3D) -> void:
    # Shoes typically come as a pair
    # If they're separate left/right, handle accordingly
    # For now, assume shoes are a single mesh for both feet
    var attachment := attach_part(shoes, skeleton, "pelvis")  # or "foot.L" parent
    
    # If shoes need to be split, create separate attachments
    # This depends on how the shoe models are structured

func _find_style(variants: Array, id: String) -> Dictionary:
    for variant in variants:
        if variant.get("id") == id:
            return variant
    return null
```

---

## Swatch-Based Color Selection

### Swatch UI Component

**Scene Structure:**
```
SwatchSelector (HFlowContainer)
├── Swatch01 (ColorRect)
├── Swatch02 (ColorRect)
├── Swatch03 (ColorRect)
└── ...
```

**Implementation:**

```gdscript
# swatch_selector.gd

extends HFlowContainer

signal color_selected(color: Color, category: String)

@export var category: String = "skin"
@export var swatch_size: Vector2 = Vector2(40, 40)
@export var swatch_margin: int = 5

func _ready() -> void:
    _setup_swatches()

func _setup_swatches() -> void:
    var colors := _get_colors_for_category(category)
    
    for color in colors:
        var swatch := ColorRect.new()
        swatch.color = color
        swatch.custom_minimum_size = swatch_size
        swatch.mouse_filter = MOUSE_FILTER_PASS  # Allow clicks to pass through
        
        # Create a button for interaction
        var button := Button.new()
        button.custom_minimum_size = swatch_size
        button.mouse_filter = MOUSE_FILTER_STOP
        button.modulate = color
        button.pressed.connect(_on_swatch_pressed.bind(color))
        
        add_child(button)

func _on_swatch_pressed(color: Color) -> void:
    emit_signal("color_selected", color, category)

func _get_colors_for_category(category: String) -> Array[Color]:
    match category:
        "skin":
            return SKIN_COLORS
        "hair":
            return HAIR_COLORS
        _:
            return SKIN_COLORS
```

### Complete Customization UI

```gdscript
# character_customization_ui.gd

extends CanvasLayer

@onready var skin_swatches: SwatchSelector
@onready var hair_swatches: SwatchSelector
@onready var hair_style_selector: PartVariantSelector
@onready var face_variant_selector: PartVariantSelector
@onready var top_variant_selector: PartVariantSelector
@onready var pants_variant_selector: PartVariantSelector
@onready var shoes_variant_selector: PartVariantSelector

func _ready() -> void:
    # Connect signals
    skin_swatches.color_selected.connect(_on_color_selected)
    hair_swatches.color_selected.connect(_on_color_selected)
    hair_style_selector.part_selected.connect(_on_part_selected)
    face_variant_selector.part_selected.connect(_on_part_selected)
    top_variant_selector.part_selected.connect(_on_part_selected)
    pants_variant_selector.part_selected.connect(_on_part_selected)
    shoes_variant_selector.part_selected.connect(_on_part_selected)
    
    # Load current customization
    _load_current_customization()

func _on_color_selected(color: Color, category: String) -> void:
    match category:
        "skin":
            CharacterAssembler.apply_skin_color(color)
            CustomizationData.skin_color = color
        "hair":
            CharacterAssembler.apply_hair_color(color)
            CustomizationData.hair_color = color
    
    # Save changes
    PersistenceManager.save_customization(CustomizationData)

func _on_part_selected(variant_id: String, category: String) -> void:
    var success := false
    match category:
        "hair_style":
            success = CharacterAssembler.swap_hair(variant_id)
            if success:
                CustomizationData.hair_style = variant_id
        "face":
            success = CharacterAssembler.swap_face(variant_id)
            if success:
                CustomizationData.face_variant = variant_id
        "top":
            success = CharacterAssembler.swap_top(variant_id)
            if success:
                CustomizationData.top_variant = variant_id
        "pants":
            success = CharacterAssembler.swap_pants(variant_id)
            if success:
                CustomizationData.pants_variant = variant_id
        "shoes":
            success = CharacterAssembler.swap_shoes(variant_id)
            if success:
                CustomizationData.shoes_variant = variant_id
    
    if success:
        PersistenceManager.save_customization(CustomizationData)

func _load_current_customization() -> void:
    var data := PersistenceManager.load_customization()
    if data:
        # Apply colors
        if data.skin_color:
            skin_swatches.select_color(data.skin_color)
            CharacterAssembler.apply_skin_color(data.skin_color)
        if data.hair_color:
            hair_swatches.select_color(data.hair_color)
            CharacterAssembler.apply_hair_color(data.hair_color)
        
        # Apply parts
        if data.hair_style:
            hair_style_selector.select_variant(data.hair_style)
            CharacterAssembler.swap_hair(data.hair_style)
        if data.face_variant:
            face_variant_selector.select_variant(data.face_variant)
            CharacterAssembler.swap_face(data.face_variant)
        if data.top_variant:
            top_variant_selector.select_variant(data.top_variant)
            CharacterAssembler.swap_top(data.top_variant)
        if data.pants_variant:
            pants_variant_selector.select_variant(data.pants_variant)
            CharacterAssembler.swap_pants(data.pants_variant)
        if data.shoes_variant:
            shoes_variant_selector.select_variant(data.shoes_variant)
            CharacterAssembler.swap_shoes(data.shoes_variant)
```

---

## Persistence System

### Customization Data Resource

```gdscript
# customization_data.gd

extends Resource

class_name CustomizationData

# Colors
@export var skin_color: Color = Color(0.85, 0.75, 0.65)  # Default: medium-light skin
@export var hair_color: Color = Color(0.65, 0.45, 0.25)  # Default: brown

# Part variants
@export var hair_style: String = "short"
@export var face_variant: String = "default"
@export var top_variant: String = "tshirt"
@export var pants_variant: String = "jeans"
@export var shoes_variant: String = "sneakers"

func to_dict() -> Dictionary:
    return {
        "skin_color": skin_color.to_rgba32(),
        "hair_color": hair_color.to_rgba32(),
        "hair_style": hair_style,
        "face_variant": face_variant,
        "top_variant": top_variant,
        "pants_variant": pants_variant,
        "shoes_variant": shoes_variant
    }

func from_dict(data: Dictionary) -> void:
    if data.has("skin_color"):
        skin_color = Color.from_rgba32(data["skin_color"])
    if data.has("hair_color"):
        hair_color = Color.from_rgba32(data["hair_color"])
    if data.has("hair_style"):
        hair_style = data["hair_style"]
    if data.has("face_variant"):
        face_variant = data["face_variant"]
    if data.has("top_variant"):
        top_variant = data["top_variant"]
    if data.has("pants_variant"):
        pants_variant = data["pants_variant"]
    if data.has("shoes_variant"):
        shoes_variant = data["shoes_variant"]
```

### Persistence Manager

```gdscript
# persistence_manager.gd

extends Node

const SAVE_FILE := "user://customization.json"

static var instance: PersistenceManager

func _ready() -> void:
    instance = self

static func save_customization(data: CustomizationData) -> void:
    var file := FileAccess.open(SAVE_FILE, FileAccess.WRITE)
    if file:
        file.store_string(JSON.stringify(data.to_dict()))
        file.close()
        return
    push_error("Could not save customization data")

static func load_customization() -> CustomizationData:
    var data := CustomizationData.new()
    
    if FileAccess.file_exists(SAVE_FILE):
        var file := FileAccess.open(SAVE_FILE, FileAccess.READ)
        if file:
            var json := JSON.new()
            var parse_result := json.parse(file.get_as_text())
            if parse_result == OK:
                data.from_dict(json.get_data())
            file.close()
    
    return data

static func reset_customization() -> void:
    var default_data := CustomizationData.new()
    save_customization(default_data)
```

### Alternative: ConfigFile Persistence

```gdscript
# config_persistence.gd

extends Node

const SAVE_FILE := "user://customization.cfg"

static func save_with_config(data: CustomizationData) -> void:
    var config := ConfigFile.new()
    
    # Save colors (ConfigFile handles Color natively)
    config.set_value("Colors", "skin", data.skin_color)
    config.set_value("Colors", "hair", data.hair_color)
    
    # Save variant strings
    config.set_value("Parts", "hair_style", data.hair_style)
    config.set_value("Parts", "face_variant", data.face_variant)
    config.set_value("Parts", "top_variant", data.top_variant)
    config.set_value("Parts", "pants_variant", data.pants_variant)
    config.set_value("Parts", "shoes_variant", data.shoes_variant)
    
    config.save(SAVE_FILE)

static func load_with_config() -> CustomizationData:
    var data := CustomizationData.new()
    
    if FileAccess.file_exists(SAVE_FILE):
        var config := ConfigFile.new()
        config.load(SAVE_FILE)
        
        # Load colors
        if config.has_section_key("Colors", "skin"):
            data.skin_color = config.get_value("Colors", "skin")
        if config.has_section_key("Colors", "hair"):
            data.hair_color = config.get_value("Colors", "hair")
        
        # Load variants
        if config.has_section_key("Parts", "hair_style"):
            data.hair_style = config.get_value("Parts", "hair_style")
        if config.has_section_key("Parts", "face_variant"):
            data.face_variant = config.get_value("Parts", "face_variant")
        if config.has_section_key("Parts", "top_variant"):
            data.top_variant = config.get_value("Parts", "top_variant")
        if config.has_section_key("Parts", "pants_variant"):
            data.pants_variant = config.get_value("Parts", "pants_variant")
        if config.has_section_key("Parts", "shoes_variant"):
            data.shoes_variant = config.get_value("Parts", "shoes_variant")
    
    return data
```

---

## Child-Safe Customization Guidelines

### Content Restrictions

**Allowed:**
- ✅ Various skin tones (light to dark)
- ✅ Natural hair colors (blonde, brown, black, red, etc.)
- ✅ Fantasy hair colors (pastel pink, blue, green - but not neon)
- ✅ Simple face variants (smile, neutral, serious)
- ✅ Casual clothing (t-shirts, jeans, shorts, skirts)
- ✅ Age-appropriate footwear (sneakers, boots, sandals)
- ✅ Simple accessories (baseball caps, beanies)

**Not Allowed:**
- ❌ Realistic injuries or scars
- ❌ Tattoos or body modifications
- ❌ Suggestive or revealing clothing
- ❌ Military or violent-themed items
- ❌ Scary or monster-themed items
- ❌ Brand logos or copyrighted designs
- ❌ Weapons or weapon accessories
- ❌ Neon or eye-straining colors

### Design Guidelines

**DO:**
- ✅ Use bright, friendly colors
- ✅ Keep designs simple and cartoony
- ✅ Use rounded, soft shapes
- ✅ Limit the number of options (8-12 per category max)
- ✅ Make swatches large enough for touch/click
- ✅ Provide clear visual feedback on selection
- ✅ Allow easy reset to defaults
- ✅ Test on various screen sizes

**DON'T:**
- ❌ Use realistic human proportions
- ❌ Include mature themes
- ❌ Use complex or confusing UI
- ❌ Require precise clicking
- ❌ Hide the reset option
- ❌ Make customization permanent

### Age-Appropriate Customization

**For 5-8 year olds:**
- Focus on **colors** rather than complex shapes
- Use **large, clear swatches**
- Provide **visual previews** of changes
- Keep the **number of options limited**
- Make the **UI intuitive and forgiving**

---

## CC0 Character & Part Assets

### Existing Assets in Choyce

```
data/models/quaternius/
├── ninja.glb          # Base character (457KB) - Primary candidate
└── ...
```

**Current Ninja Model:**
- Already imported into Godot
- Has a skeleton with bones
- Can be used as the base character
- Needs customization parts created

### Recommended CC0 Sources for Parts

#### 1. Kenney Character Packs

| Pack | Description | Download | Use Case |
|------|-------------|----------|----------|
| **Toon Characters 1** | 16 animated characters | [kenney.nl/assets/toon-characters-1](https://kenney.nl/assets/toon-characters-1) | Base body parts |
| **Toon Characters 2** | Additional characters | [kenney.nl/assets/toon-characters-2](https://kenney.nl/assets/toon-characters-2) | More variants |
| **Racing Pack** | Car + driver characters | [kenney.nl/assets/racing-pack](https://kenney.nl/assets/racing-pack) | Clothing ideas |

**Extracting Parts from Kenney Packs:**
```bash
# Download Kenney Toon Characters
wget https://kenney.nl/assets/download/toon-characters-1.zip
unzip toon-characters-1.zip

# Extract individual parts in Blender:
# 1. Import all meshes
# 2. Separate by loose parts (P → Separate → By Loose Parts)
# 3. Rig each part to your base skeleton
# 4. Export each part separately
```

#### 2. Mixamo Characters (CC0 via Adobe)

**Website**: [mixamo.com](https://www.mixamo.com/)

**Note**: Mixamo characters are free to use, but check licensing for your use case. Many are CC0 or free for game development.

**Workflow:**
1. Download base character from Mixamo
2. Import into Blender
3. Separate into parts (head, torso, arms, legs)
4. Create clothing/hair variations
5. Rig all to the same skeleton
6. Export as separate GLB files

#### 3. Quaternius Additional Models

**Website**: [quaternius.com](https://quaternius.com/)

**Search for:**
- Hair styles
- Hats and accessories
- Clothing items
- Shoes and footwear

**Recommended Models:**
- Hair: various styles (short, long, ponytail, braids)
- Hats: baseball cap, beanie, top hat
- Clothing: t-shirts, jackets, pants, skirts
- Shoes: sneakers, boots, sandals

#### 4. Blend Swap (CC0 Characters)

**Website**: [blendswap.com](https://www.blendswap.com/)

**Filter by:**
- License: CC0
- Category: Characters
- Rigged: Yes

#### 5. Create Your Own (Simple Approach)

For Choyce's needs, you may want to create **simple, stylized parts** rather than realistic ones:

**Tools:**
- **Blender** (free) - Full 3D modeling
- **MagicaVoxel** (free) - Voxel-based models
- **Tinkercad** (free, browser) - Simple 3D shapes
- **BlocksCAD** (free, browser) - Code-based modeling

**Simple Hair Creation:**
```
1. Create a simple capsule for the head
2. Add a larger capsule for hair volume
3. Shape with proportional editing
4. Subdivide for smoothness
5. Assign to "head" bone
6. Export as separate mesh
```

**Simple Clothing Creation:**
```
1. Create a cylinder for torso
2. Extrude sleeves
3. Shape to match character
4. Assign to "torso" bone
5. Export as separate mesh
```

### Creating Parts from Existing Ninja Model

Since we already have `ninja.glb`, we can extract parts from it:

**Blender Workflow:**
```
1. Import ninja.glb into Blender
2. Enter Edit Mode
3. Select hair vertices (by material or manual selection)
4. Press P → Separate → By Loose Parts or By Material
5. Move separated part to a new layer/collection
6. Create a new armature matching the original skeleton
7. Parent the hair part to the new armature
8. Export as separate GLB (hair.glb)
9. Repeat for other parts (hat, top, pants, shoes)
```

---

## Code Samples & Implementation Patterns

### Complete Character Customizer

```gdscript
# character_customizer.gd - Singleton
extends Node

@onready var skeleton: Skeleton3D
@onready var character_assembler: CharacterAssembler
@onready var customization_data: CustomizationData

# Part references
var parts: Dictionary = {}

func _ready() -> void:
    _setup_skeleton()
    _load_customization()

func _setup_skeleton() -> void:
    # Load base skeleton from ninja.glb
    var ninja_scene := preload("res://data/models/quaternius/ninja.glb")
    var ninja_instance := ninja_scene.instantiate()
    add_child(ninja_instance)
    
    # Find skeleton
    skeleton = ninja_instance.find_child("*Skeleton*") as Skeleton3D
    if not skeleton:
        skeleton = ninja_instance.find_child("Skeleton3D") as Skeleton3D
    
    if not skeleton:
        push_error("No Skeleton3D found in ninja.glb")
        return
    
    # Extract and hide original parts
    _extract_original_parts(ninja_instance)
    
    # Load default customization parts
    _load_default_parts()

func _extract_original_parts(ninja_instance: Node) -> void:
    # Find all MeshInstance3D nodes
    var meshes := ninja_instance.find_children("*").filter(func(n): return n is MeshInstance3D)
    
    for mesh in meshes:
        var mesh_name := mesh.name.to_lower()
        
        # Categorize based on name
        if "hair" in mesh_name or "head" in mesh_name:
            parts["original_hair"] = mesh
            mesh.visible = false
        elif "body" in mesh_name or "torso" in mesh_name:
            parts["body"] = mesh
        elif "pants" in mesh_name or "leg" in mesh_name:
            parts["original_pants"] = mesh
            mesh.visible = false
        elif "shoe" in mesh_name or "foot" in mesh_name:
            parts["original_shoes"] = mesh
            mesh.visible = false

func _load_default_parts() -> void:
    # Load default parts
    _load_part("hair", "res://assets/characters/hair/short.tscn", "head")
    _load_part("top", "res://assets/characters/tops/tshirt.tscn", "torso")
    _load_part("pants", "res://assets/characters/pants/jeans.tscn", "pelvis")
    _load_part("shoes", "res://assets/characters/shoes/sneakers.tscn", "pelvis")
    
    # Apply default colors
    apply_skin_color(customization_data.skin_color)
    apply_hair_color(customization_data.hair_color)

func _load_part(part_type: String, scene_path: String, bone_name: String) -> void:
    if not ResourceLoader.exists(scene_path):
        return
    
    var scene := load(scene_path)
    var instance := scene.instantiate()
    
    if bone_name != "":
        var attachment := CharacterAssembler.attach_part(instance, skeleton, bone_name)
    else:
        skeleton.add_child(instance)
    
    parts[part_type] = instance

func _load_customization() -> void:
    customization_data = PersistenceManager.load_customization()
    
    # Apply saved customization
    if customization_data:
        # Load parts
        if customization_data.hair_style:
            _load_part("hair", _get_part_scene("hair", customization_data.hair_style), "head")
        if customization_data.top_variant:
            _load_part("top", _get_part_scene("top", customization_data.top_variant), "torso")
        if customization_data.pants_variant:
            _load_part("pants", _get_part_scene("pants", customization_data.pants_variant), "pelvis")
        if customization_data.shoes_variant:
            _load_part("shoes", _get_part_scene("shoes", customization_data.shoes_variant), "pelvis")
        
        # Apply colors
        apply_skin_color(customization_data.skin_color)
        apply_hair_color(customization_data.hair_color)

func _get_part_scene(part_type: String, variant_id: String) -> String:
    var variants := _get_variants_for_type(part_type)
    for variant in variants:
        if variant.get("id") == variant_id:
            return variant.get("scene", "")
    return ""

func _get_variants_for_type(part_type: String) -> Array:
    match part_type:
        "hair":
            return HAIR_STYLES
        "top":
            return TOP_VARIANTS
        "pants":
            return PANTS_VARIANTS
        "shoes":
            return SHOES_VARIANTS
        _:
            return []

# Public API
func set_skin_color(color: Color) -> void:
    customization_data.skin_color = color
    apply_skin_color(color)
    PersistenceManager.save_customization(customization_data)

func set_hair_color(color: Color) -> void:
    customization_data.hair_color = color
    apply_hair_color(color)
    PersistenceManager.save_customization(customization_data)

func set_hair_style(style_id: String) -> bool:
    if customization_data.hair_style == style_id:
        return true
    
    if _swap_part("hair", style_id, "head"):
        customization_data.hair_style = style_id
        PersistenceManager.save_customization(customization_data)
        return true
    return false

func set_top_variant(variant_id: String) -> bool:
    if customization_data.top_variant == variant_id:
        return true
    
    if _swap_part("top", variant_id, "torso"):
        customization_data.top_variant = variant_id
        PersistenceManager.save_customization(customization_data)
        return true
    return false

func set_pants_variant(variant_id: String) -> bool:
    if customization_data.pants_variant == variant_id:
        return true
    
    if _swap_part("pants", variant_id, "pelvis"):
        customization_data.pants_variant = variant_id
        PersistenceManager.save_customization(customization_data)
        return true
    return false

func set_shoes_variant(variant_id: String) -> bool:
    if customization_data.shoes_variant == variant_id:
        return true
    
    if _swap_part("shoes", variant_id, "pelvis"):
        customization_data.shoes_variant = variant_id
        PersistenceManager.save_customization(customization_data)
        return true
    return false

func reset_to_defaults() -> void:
    customization_data = CustomizationData.new()
    _load_default_parts()
    apply_skin_color(customization_data.skin_color)
    apply_hair_color(customization_data.hair_color)
    PersistenceManager.save_customization(customization_data)

# Helper functions
func apply_skin_color(color: Color) -> void:
    var body := parts.get("body")
    if body:
        var material := _get_or_create_material(body)
        if material is StandardMaterial3D:
            material.albedo_color = color

func apply_hair_color(color: Color) -> void:
    var hair := parts.get("hair")
    if hair:
        var material := _get_or_create_material(hair)
        if material is StandardMaterial3D:
            material.albedo_color = color

func _swap_part(part_type: String, variant_id: String, bone_name: String) -> bool:
    # Remove current part
    if parts.has(part_type) and parts[part_type]:
        parts[part_type].get_parent().remove_child(parts[part_type])
    
    # Load and attach new part
    var scene_path := _get_part_scene(part_type, variant_id)
    if scene_path == "":
        return false
    
    var scene := load(scene_path)
    if not scene:
        return false
    
    var instance := scene.instantiate()
    
    if bone_name != "":
        var attachment := CharacterAssembler.attach_part(instance, skeleton, bone_name)
    else:
        skeleton.add_child(instance)
    
    parts[part_type] = instance
    return true

func _get_or_create_material(mesh: MeshInstance3D) -> BaseMaterial3D:
    if mesh.material_override:
        return mesh.material_override
    
    if mesh.get_surface_material_count() > 0:
        var surface_mat := mesh.get_surface_material(0)
        if surface_mat:
            mesh.material_override = surface_mat.duplicate()
            return mesh.material_override
    
    var new_mat := StandardMaterial3D.new()
    mesh.material_override = new_mat
    return new_mat
```

### Part Variant Selector UI

```gdscript
# part_variant_selector.gd

extends HFlowContainer

signal part_selected(variant_id: String, category: String)

@export var category: String = "hair_style"
@export var icon_size: Vector2 = Vector2(64, 64)
@export var icon_margin: int = 10

func _ready() -> void:
    _setup_variants()

func _setup_variants() -> void:
    var variants := _get_variants()
    
    for variant in variants:
        var icon := TextureButton.new()
        icon.custom_minimum_size = icon_size
        icon.texture_normal = load(variant.get("icon", ""))
        icon.tooltip_text = variant.get("id", "Unknown").to_pascal_case()
        icon.pressed.connect(_on_variant_selected.bind(variant.get("id")))
        
        add_child(icon)

func _on_variant_selected(variant_id: String) -> void:
    emit_signal("part_selected", variant_id, category)

func _get_variants() -> Array:
    match category:
        "hair_style":
            return HAIR_STYLES
        "face":
            return FACE_VARIANTS
        "top":
            return TOP_VARIANTS
        "pants":
            return PANTS_VARIANTS
        "shoes":
            return SHOES_VARIANTS
        _:
            return []

func select_variant(variant_id: String) -> void:
    for child in get_children():
        if child is TextureButton:
            var current_id := child.get_meta("variant_id", "")
            if current_id == variant_id:
                # Highlight selected
                child.modulate = Color(1, 1, 1)
            else:
                child.modulate = Color(0.7, 0.7, 0.7)
```

---

## Testing & Validation Checklist

### Functional Tests

- [ ] All 6 customization categories are available
- [ ] Skin color swatches change body color
- [ ] Hair style swatches change hair mesh
- [ ] Hair color swatches change hair color
- [ ] Face variant swatches change face texture
- [ ] Top variant swatches change shirt
- [ ] Pants variant swatches change pants
- [ ] Shoes variant swatches change shoes
- [ ] Changes apply to 3D character in real-time
- [ ] Changes persist across game sessions
- [ ] Reset to defaults works
- [ ] All customization is cosmetic-only (no gameplay changes)

### Visual Tests

- [ ] Colors look consistent across all lighting
- [ ] Parts align correctly with body
- [ ] Parts move correctly with animations
- [ ] No clipping between parts
- [ ] No floating parts (all properly attached)
- [ ] Colors are child-appropriate
- [ ] UI is clear and intuitive

### Technical Tests

- [ ] No runtime errors during customization
- [ ] No memory leaks from part swapping
- [ ] Performance is acceptable with all parts visible
- [ ] Skeleton animations work with all part combinations
- [ ] Save/load works correctly
- [ ] File paths are correct for all assets

### Child-Safety Tests

- [ ] No scary or disturbing options
- [ ] All colors are appropriate for children
- [ ] All part shapes are appropriate for children
- [ ] No mature themes in customization
- [ ] Customization is optional (can be skipped)
- [ ] Parent can reset customization

### Integration Tests

- [ ] Customization works in create mode
- [ ] Customization works in play mode
- [ ] Customization persists in adventure mode
- [ ] Character looks correct in all camera views
- [ ] Customization doesn't interfere with gameplay

---

## Learning Resources

### Official Godot Documentation

- [Skeleton3D](https://docs.godotengine.org/en/stable/classes/class_skeleton3d.html) - Skeleton reference
- [BoneAttachment3D](https://docs.godotengine.org/en/stable/classes/class_boneattachment3d.html) - Bone attachment
- [MeshInstance3D](https://docs.godotengine.org/en/stable/classes/class_meshinstance3d.html) - Mesh instance
- [StandardMaterial3D](https://docs.godotengine.org/en/stable/classes/class_standardmaterial3d.html) - Material reference
- [FileAccess](https://docs.godotengine.org/en/stable/classes/class_fileaccess.html) - File I/O
- [ConfigFile](https://docs.godotengine.org/en/stable/classes/class_configfile.html) - Configuration files
- [JSON](https://docs.godotengine.org/en/stable/classes/class_json.html) - JSON parsing

### Tutorials and Guides

- [3D Character Customization System in Godot 4](https://www.youtube.com/watch?v=RXEx7hSkK4c) - YouTube tutorial
- [How to swap skinned meshes for a customizable character](https://gamedev.stackexchange.com/questions/205470/how-to-swap-skinned-meshes-for-a-customizable-character-in-godot) - Stack Exchange
- [Modular Player Character in Godot](https://www.reddit.com/r/godot/comments/1ha6l11/how_to_make_a_modular_player_character/) - Reddit discussion
- [Character Customization in Godot 3D](https://forum.godotengine.org/t/character-customization-in-godot-3d/59840) - Forum discussion
- [Save/Load Systems in Godot 4](https://uhiyama-lab.com/en/notes/godot/save-load-system/) - Comprehensive save system guide

### Community Resources

- [r/godot - Character Customization](https://www.reddit.com/r/godot/search/?q=character+customization) - Community discussions
- [Godot Forum - Character Customization](https://forum.godotengine.org/c/questions/11?search=character+customization) - Official forum
- [Godot Asset Library - Character](https://godotengine.org/asset-library/?search=character) - Character assets

### CC0 Asset Sources

- [Kenney Toon Characters](https://kenney.nl/assets/toon-characters-1) - Base character parts
- [Kenney 3D Kit](https://kenney.nl/assets/3d-kit) - Various props and clothing
- [Quaternius](https://quaternius.com/) - CC0 3D models (hair, hats, clothing)
- [Mixamo](https://www.mixamo.com/) - Free rigged characters
- [Blend Swap](https://www.blendswap.com/) - CC0 Blender models

### Tools

- [Blender](https://www.blender.org/) - 3D modeling and part extraction
- [MagicaVoxel](https://ephtracy.github.io/) - Voxel-based modeling
- [Tinkercad](https://www.tinkercad.com/) - Simple 3D modeling (browser)
- [Godot Palette Tools](https://godotengine.org/asset-library/asset/1635) - Color palette management

---

## Summary

This research compendium provides a comprehensive guide to implementing the **Identity/Ownership Character Customization System** (VS-022) in Godot 4.x for the Choyce Engine.

**Key Takeaways:**

1. **Modular Design**: Use separate mesh parts rigged to a shared Skeleton3D
2. **Bone Attachment**: Attach parts to specific bones using BoneAttachment3D
3. **Swatch Selection**: Use ColorRect or TextureButton for visual color selection
4. **Part Swapping**: Show/hide or load/unload different mesh variants
5. **Persistence**: Save customization data to user:// using JSON or ConfigFile
6. **Child-Safety**: All options must be appropriate for children 5-8
7. **Cosmetic Only**: Customization never affects gameplay stats

**Implementation Strategy:**
1. Extract parts from existing ninja.glb or create new modular parts
2. Set up shared skeleton with BoneAttachment3D for each part type
3. Create swatch-based UI for color selection
4. Create variant-based UI for part selection
5. Implement persistence system
6. Test thoroughly for child-safety and technical correctness

**Integration:** Works with existing Choyce character system and ensures players can see their chosen character throughout the game, as required by PLAN.md acceptance criteria.

---

*Generated for Choyce Engine - PLAN-016 Identity/Ownership Character Customization*
*Last updated: 2026-07-18*
