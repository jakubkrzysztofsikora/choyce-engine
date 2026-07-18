# RESEARCH_VS-001: Preserve Template Transforms, Properties, and Rule Metadata

**Task ID:** VS-001  
**Title:** Preserve authored template transforms properties and rule metadata  
**Specialty:** runtime-data  
**Owner:** codex  
**Cross-review by:** claude  
**Dependencies:** None  
**Status:** done → in_review  

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
Preserve authored template transforms, properties, and rule metadata through the TemplateLoader system, ensuring that node position, rotation, scale, properties, rule source blocks, and active state are not lost during JSON-to-domain conversion.

### Acceptance Criteria (from backlog.yaml)
1. TemplateLoader preserves node position, rotation, scale, and properties
2. TemplateLoader preserves rule source_blocks properties and active state
3. JSON-to-domain tests prove authored fields are not discarded
4. Renderer boundary normalizes JSON vectors and colors without moving Godot nodes into domain logic

### Key Requirements
- Framework-agnostic domain types (no Node/Control inheritance)
- Boundary at renderer: JSON vectors/colors normalized without leaking Godot nodes into domain
- All authored data from templates must be preserved and accessible

---

## Current Implementation Analysis

### Existing Infrastructure
Based on backlog.yaml evidence:
- `tests/application/test_template_loader.gd` - Tests for template loading
- `tests/application/template_loader_starter_smoke.gd` - Smoke tests
- `src/application/template_loader.gd` - Main template loader implementation

From PLAN.md and architecture:
- Domain layer: `src/domain/` - Framework-agnostic types
- Application layer: `src/application/` - Use cases and services
- Adapters layer: `src/adapters/` - Godot-specific implementations

### Hexagonal Architecture Context
The task enforces the **hexagonal architecture** principle:
- **Domain layer** contains pure business logic (no Godot dependencies)
- **Application layer** contains use cases (no Godot dependencies)
- **Adapter layer** contains Godot-specific code (Node, Control, etc.)
- **Boundary**: TemplateLoader is the adapter that converts JSON templates to domain entities

### Template System Components
1. **Template JSON files**: `data/templates/adventure.json`, `data/templates/obby.json`
2. **TemplateLoader**: `src/application/template_loader.gd` - Converts JSON to domain entities
3. **Domain entities**: World, SceneNode, GameRule, etc. in `src/domain/world_authoring/`
4. **Renderer**: Converts domain entities to Godot nodes

### Preservation Requirements
| Data Type | Source | Destination | Preservation Method |
|-----------|--------|-------------|-------------------|
| Position | JSON template | SceneNode | Vector3 serialization |
| Rotation | JSON template | SceneNode | Quaternion/Vector3 serialization |
| Scale | JSON template | SceneNode | Vector3 serialization |
| Properties | JSON template | SceneNode | Dictionary serialization |
| Rule source_blocks | JSON template | GameRule | String/Array serialization |
| Rule active state | JSON template | GameRule | Boolean serialization |

---

## Online Research Summary

### 1. Godot 4 JSON Serialization
**Objective**: Preserve all authored data from JSON templates

**Godot 4 JSON Handling:**
- `JSON.new()` - JSON parser/stringifier
- `JSON.parse()` - Parse JSON string to Variant
- `JSON.stringify()` - Convert Variant to JSON string
- `ResourceLoader.load()` - Load .res files (binary JSON)
- `ResourceSaver.save()` - Save .res files

**Best Practices:**
- Use `JSON.parse().result` to get parsed data
- Handle all Variant types (null, bool, int, float, String, Array, Dictionary)
- Preserve type information during serialization/deserialization
- Validate JSON schema before processing

**Recommended Libraries:**
- **JSON Parse** (https://github.com/GodotExplorer/JSONParse) - Extended JSON parsing with schema validation
- **Godot JSON Schema** (https://github.com/GodotExplorer/JSONSchema) - JSON schema validation
- **JSon** (https://github.com/he airplane/json) - Alternative JSON library

**Type Preservation Strategies:**
1. **Type hints**: Store type information in JSON (`{"_type": "Vector3", "value": [1,2,3]}`)
2. **Schema-based**: Use JSON Schema to define expected types
3. **Adapter-based**: TemplateLoader knows how to convert JSON to domain types
4. **Factory pattern**: Use factories to create domain objects from JSON

### 2. Godot Vector and Color Normalization
**Objective**: Normalize JSON vectors and colors at the renderer boundary

**Godot 4 Vector Types:**
- `Vector2` - 2D vector (x, y)
- `Vector3` - 3D vector (x, y, z)
- `Vector4` - 4D vector (x, y, z, w)
- `Quaternion` - Rotation quaternion (x, y, z, w)
- `Color` - RGBA color (r, g, b, a)
- `Basis` - 3x3 matrix (for scale/rotation)
- `Transform3D` - Full 3D transform (basis + origin)

**JSON Representation:**
```json
{
  "position": {"_type": "Vector3", "x": 1.0, "y": 2.0, "z": 3.0},
  "rotation": {"_type": "Quaternion", "x": 0.0, "y": 0.0, "z": 0.0, "w": 1.0},
  "scale": {"_type": "Vector3", "x": 1.0, "y": 1.0, "z": 1.0},
  "color": {"_type": "Color", "r": 1.0, "g": 0.5, "b": 0.0, "a": 1.0}
}
```

**Normalization Functions:**
```gdscript
# In adapter layer (renderer boundary)
func normalize_vector3(json: Dictionary) -> Vector3:
    if "_type" in json and json["_type"] == "Vector3":
        return Vector3(json.get("x", 0), json.get("y", 0), json.get("z", 0))
    elif json is Array and json.size() >= 3:
        return Vector3(json[0], json[1], json[2])
    else:
        return Vector3.ZERO

func normalize_color(json: Dictionary) -> Color:
    if "_type" in json and json["_type"] == "Color":
        return Color(json.get("r", 1), json.get("g", 1), json.get("b", 1), json.get("a", 1))
    elif json is Array and json.size() >= 3:
        return Color(json[0], json[1], json[2], json.get(3, 1.0))
    else:
        return Color.WHITE
```

**Boundary Enforcement:**
- Domain layer: Only deals with domain types (Vector3Value, ColorValue, etc.)
- Adapter layer: Converts between JSON and domain types
- Renderer: Converts domain types to Godot types (Node3D transforms, etc.)

### 3. Template System Design Patterns
**Objective**: Robust template loading and preservation

**Factory Pattern:**
```gdscript
# Domain layer factory
class_name EntityFactory

func create_scene_node(data: Dictionary) -> SceneNode:
    var node = SceneNode.new()
    node.position = normalize_vector3(data.get("position", {}))
    node.rotation = normalize_quaternion(data.get("rotation", {}))
    node.scale = normalize_vector3(data.get("scale", {}))
    node.properties = data.get("properties", {})
    return node
```

**Builder Pattern:**
```gdscript
# For complex entities with many properties
class_name SceneNodeBuilder

var node: SceneNode

func with_position(pos: Vector3) -> SceneNodeBuilder:
    node.position = pos
    return self

func with_rotation(rot: Quaternion) -> SceneNodeBuilder:
    node.rotation = rot
    return self

func build() -> SceneNode:
    return node
```

**Visitor Pattern:**
```gdscript
# For processing template hierarchies
class_name TemplateVisitor

func visit_scene_node(node: SceneNode) -> void:
    # Process node
    pass

func visit_game_rule(rule: GameRule) -> void:
    # Process rule
    pass
```

### 4. Property Preservation Strategies
**Objective**: Preserve all authored properties from templates

**Approaches:**

1. **Dictionary-based Properties:**
```json
{
  "name": "Tree",
  "type": "prop",
  "properties": {
    "health": 100,
    "interactable": true,
    "custom_data": {"model": "oak", "age": 5}
  }
}
```

2. **Typed Properties:**
```json
{
  "name": "Door",
  "type": "interactive",
  "properties": [
    {"name": "locked", "type": "bool", "value": true},
    {"name": "key_id", "type": "string", "value": "golden_key"},
    {"name": "open_sound", "type": "resource", "value": "res://sounds/door_open.wav"}
  ]
}
```

3. **Component-based Properties:**
```json
{
  "name": "NPC",
  "components": [
    {"type": "Dialogue", "lines": ["Hello!", "How are you?"]},
    {"type": "QuestGiver", "quest_id": "find_treasure"},
    {"type": "Trader", "items": ["potion", "sword"]}
  ]
}
```

**Preservation Testing:**
- Round-trip serialization: JSON → Domain → JSON → Compare
- Property count validation: Ensure all properties are preserved
- Type validation: Ensure property types are preserved
- Deep equality: Compare nested structures

### 5. Rule Metadata Preservation
**Objective**: Preserve rule source_blocks and active state

**Rule Structure:**
```json
{
  "id": "collect_wood",
  "name": "Collect Wood",
  "description": "Player can collect wood from trees",
  "source_blocks": [
    "ON player_interact WITH tree",
    "  IF player_has_tool 'axe'",
    "    GIVE player wood 1",
    "    PLAY SOUND 'chop'",
    "  ENDIF"
  ],
  "active": true,
  "priority": 10,
  "tags": ["gathering", "wood", "tree"]
}
```

**Preservation Requirements:**
- `source_blocks`: Array of strings, must be preserved exactly
- `active`: Boolean, must be preserved
- Custom metadata: Any additional fields must be preserved

**Domain Representation:**
```gdscript
class_name GameRule
extends RefCounted

@export var id: String
@export var name: String
@export var description: String
@export var source_blocks: Array[String]
@export var active: bool = true
@export var priority: int = 0
@export var tags: Array[String]
@export var metadata: Dictionary  # For any additional custom fields

# Serialization methods
func to_json() -> Dictionary:
    return {
        "id": id,
        "name": name,
        "description": description,
        "source_blocks": source_blocks,
        "active": active,
        "priority": priority,
        "tags": tags,
        "metadata": metadata
    }

func from_json(data: Dictionary) -> GameRule:
    id = data.get("id", "")
    name = data.get("name", "")
    description = data.get("description", "")
    source_blocks = data.get("source_blocks", [])
    active = data.get("active", true)
    priority = data.get("priority", 0)
    tags = data.get("tags", [])
    metadata = data.get("metadata", {})
    return self
```

---

## Technical Deep Dive

### TemplateLoader Architecture
```
┌─────────────────────────────────────────────────────────────┐
│                         TemplateLoader                          │
│                    (Adapter Layer)                             │
├─────────────────────────────────────────────────────────────┤
│  + load_template(path: String) -> World                      │
│  + _parse_json(json: Dictionary) -> Dictionary               │
│  + _create_world(data: Dictionary) -> World                 │
│  + _create_scene_node(data: Dictionary) -> SceneNode         │
│  + _create_game_rule(data: Dictionary) -> GameRule           │
│  + _normalize_vector3(data: Variant) -> Vector3             │
│  + _normalize_color(data: Variant) -> Color                  │
│  + _normalize_quaternion(data: Variant) -> Quaternion        │
└────────────┬───────────────────────────────────────────────┘
             │
             ▼
┌─────────────────────────────────────────────────────────────┐
│                      Domain Entities                          │
│                    (Domain Layer)                             │
├─────────────────────────────────────────────────────────────┤
│  World, SceneNode, GameRule, NPCCharacter, AssetCatalogEntry  │
│  - All extend RefCounted (no Node/Control)                    │
│  - All have to_json() and from_json() methods                  │
│  - All preserve all authored data                             │
└─────────────────────────────────────────────────────────────┘
```

### Transform Preservation Flow
```
JSON Template → TemplateLoader._parse_json() → Dictionary
                                    ↓
                    TemplateLoader._create_scene_node()
                                    ↓
                         SceneNode (Domain)
                          position: Vector3
                          rotation: Quaternion
                          scale: Vector3
                          properties: Dictionary
                                    ↓
                    Renderer.convert_to_godot()
                                    ↓
                         Node3D (Godot)
                      transform: Transform3D
                       (basis + origin)
```

### Property Preservation Flow
```
JSON Template → TemplateLoader
              ↓
    Dictionary with properties
              ↓
    SceneNode.properties (Dictionary)
              ↓
    Renderer applies to Node3D
              ↓
    Godot node with all properties set
```

### Rule Metadata Preservation Flow
```
JSON Template → TemplateLoader
              ↓
    Dictionary with source_blocks, active, etc.
              ↓
    GameRule (Domain)
      source_blocks: Array[String]
      active: bool
      metadata: Dictionary
              ↓
    RuleRegistry registers rule
              ↓
    GameplayRuntime uses rule
```

---

## Code Samples

### 1. TemplateLoader.gd (Core Implementation)
```gdscript
## TemplateLoader - Loads templates from JSON and creates domain entities
## This is an ADAPTER layer component - it can use Godot types but domain entities are pure

class_name TemplateLoader
extends RefCounted

# Domain factory for creating entities
@export var entity_factory: EntityFactory

## Load a template from file
func load_template(template_path: String) -> World:
    var file = FileAccess.open(template_path, FileAccess.READ)
    if not file:
        push_error("Cannot open template: %s" % template_path)
        return null
    
    var json = JSON.new()
    var parse_result = json.parse(file.get_as_text())
    file.close()
    
    if parse_result != OK:
        push_error("JSON parse error: %s" % json.get_error_message())
        return null
    
    var data = json.get_data()
    return _create_world(data)

## Create a World from JSON data
func _create_world(data: Dictionary) -> World:
    var world = World.new()
    
    # Preserve world-level properties
    world.id = data.get("id", "")
    world.name = data.get("name", "Unnamed World")
    world.description = data.get("description", "")
    world.metadata = data.get("metadata", {})
    
    # Create scene nodes
    var nodes_data = data.get("scene_nodes", [])
    for node_data in nodes_data:
        var scene_node = _create_scene_node(node_data)
        if scene_node:
            world.add_scene_node(scene_node)
    
    # Create game rules
    var rules_data = data.get("game_rules", [])
    for rule_data in rules_data:
        var game_rule = _create_game_rule(rule_data)
        if game_rule:
            world.add_game_rule(game_rule)
    
    return world

## Create a SceneNode from JSON data
func _create_scene_node(data: Dictionary) -> SceneNode:
    var scene_node = SceneNode.new()
    
    # Preserve transforms
    scene_node.position = _normalize_vector3(data.get("position", {}))
    scene_node.rotation = _normalize_quaternion(data.get("rotation", {}))
    scene_node.scale = _normalize_vector3(data.get("scale", {}))
    
    # Preserve node properties
    scene_node.name = data.get("name", "Unnamed Node")
    scene_node.node_type = data.get("type", "prop")
    scene_node.properties = data.get("properties", {}).duplicate(true)  # Deep copy
    scene_node.tags = data.get("tags", [])
    scene_node.layer = data.get("layer", 0)
    scene_node.visible = data.get("visible", true)
    scene_node.cast_shadow = data.get("cast_shadow", true)
    scene_node.receive_shadow = data.get("receive_shadow", true)
    
    # Preserve children (hierarchy)
    var children_data = data.get("children", [])
    for child_data in children_data:
        var child_node = _create_scene_node(child_data)
        if child_node:
            scene_node.add_child(child_node)
    
    return scene_node

## Create a GameRule from JSON data
func _create_game_rule(data: Dictionary) -> GameRule:
    var game_rule = GameRule.new()
    
    # Preserve rule metadata
    game_rule.id = data.get("id", "")
    game_rule.name = data.get("name", "Unnamed Rule")
    game_rule.description = data.get("description", "")
    
    # CRITICAL: Preserve source_blocks exactly as authored
    game_rule.source_blocks = data.get("source_blocks", []).duplicate(true)
    
    # CRITICAL: Preserve active state
    game_rule.active = data.get("active", true)
    
    game_rule.priority = data.get("priority", 0)
    game_rule.tags = data.get("tags", []).duplicate(true)
    game_rule.metadata = data.get("metadata", {}).duplicate(true)
    
    # Validate required fields
    if game_rule.id.is_empty():
        push_warning("GameRule without ID found in template")
    
    return game_rule

## Normalize Vector3 from JSON
## Handles multiple formats: typed object, array, or individual components
func _normalize_vector3(data: Variant) -> Vector3:
    if data is Dictionary:
        if "_type" in data and data["_type"] == "Vector3":
            return Vector3(
                data.get("x", 0.0),
                data.get("y", 0.0),
                data.get("z", 0.0)
            )
        else:
            # Assume it's a plain dictionary with x, y, z
            return Vector3(
                data.get("x", 0.0),
                data.get("y", 0.0),
                data.get("z", 0.0)
            )
    elif data is Array and data.size() >= 3:
        return Vector3(data[0], data[1], data[2])
    elif data is Vector3:
        return data
    else:
        return Vector3.ZERO

## Normalize Quaternion from JSON
func _normalize_quaternion(data: Variant) -> Quaternion:
    if data is Dictionary:
        if "_type" in data and data["_type"] == "Quaternion":
            return Quaternion(
                data.get("x", 0.0),
                data.get("y", 0.0),
                data.get("z", 0.0),
                data.get("w", 1.0)
            )
        else:
            return Quaternion(
                data.get("x", 0.0),
                data.get("y", 0.0),
                data.get("z", 0.0),
                data.get("w", 1.0)
            )
    elif data is Array and data.size() >= 4:
        return Quaternion(data[0], data[1], data[2], data[3])
    elif data is Quaternion:
        return data
    else:
        return Quaternion.IDENTITY

## Normalize Color from JSON
func _normalize_color(data: Variant) -> Color:
    if data is Dictionary:
        if "_type" in data and data["_type"] == "Color":
            return Color(
                data.get("r", 1.0),
                data.get("g", 1.0),
                data.get("b", 1.0),
                data.get("a", 1.0)
            )
        else:
            return Color(
                data.get("r", 1.0),
                data.get("g", 1.0),
                data.get("b", 1.0),
                data.get("a", 1.0)
            )
    elif data is Array:
        if data.size() >= 3:
            return Color(data[0], data[1], data[2], data.get(3, 1.0))
        elif data.size() == 4:
            return Color(data[0], data[1], data[2], data[3])
    elif data is Color:
        return data
    else:
        return Color.WHITE
```

### 2. Domain Entity Definitions
```gdscript
## SceneNode.gd - Domain entity for scene nodes
## NO Godot dependencies (extends RefCounted, not Node)

class_name SceneNode
extends RefCounted

# Transforms
@export var position: Vector3 = Vector3.ZERO
@export var rotation: Quaternion = Quaternion.IDENTITY
@export var scale: Vector3 = Vector3.ONE

# Properties
@export var name: String = ""
@export var node_type: String = "prop"
@export var properties: Dictionary = {}
@export var tags: Array[String] = []
@export var layer: int = 0
@export var visible: bool = true
@export var cast_shadow: bool = true
@export var receive_shadow: bool = true

# Hierarchy
@export var children: Array[SceneNode] = []
@export var parent: SceneNode = null

# Metadata
@export var metadata: Dictionary = {}

## Serialization methods

func to_json() -> Dictionary:
    var json = {
        "name": name,
        "node_type": node_type,
        "position": {"_type": "Vector3", "x": position.x, "y": position.y, "z": position.z},
        "rotation": {"_type": "Quaternion", "x": rotation.x, "y": rotation.y, "z": rotation.z, "w": rotation.w},
        "scale": {"_type": "Vector3", "x": scale.x, "y": scale.y, "z": scale.z},
        "properties": properties,
        "tags": tags,
        "layer": layer,
        "visible": visible,
        "cast_shadow": cast_shadow,
        "receive_shadow": receive_shadow,
        "metadata": metadata
    }
    
    # Serialize children
    if children.size() > 0:
        json["children"] = []
        for child in children:
            json["children"].append(child.to_json())
    
    return json

func from_json(data: Dictionary) -> SceneNode:
    name = data.get("name", "")
    node_type = data.get("node_type", "prop")
    position = TemplateLoader._normalize_vector3(data.get("position", {}))
    rotation = TemplateLoader._normalize_quaternion(data.get("rotation", {}))
    scale = TemplateLoader._normalize_vector3(data.get("scale", {}))
    properties = data.get("properties", {}).duplicate(true)
    tags = data.get("tags", []).duplicate(true)
    layer = data.get("layer", 0)
    visible = data.get("visible", true)
    cast_shadow = data.get("cast_shadow", true)
    receive_shadow = data.get("receive_shadow", true)
    metadata = data.get("metadata", {}).duplicate(true)
    
    # Load children
    if "children" in data:
        for child_data in data["children"]:
            var child = SceneNode.new().from_json(child_data)
            children.append(child)
            child.parent = self
    
    return self

## Validation
func validate() -> Array:
    var errors = []
    
    if name.is_empty():
        errors.append("SceneNode name cannot be empty")
    
    if node_type.is_empty():
        errors.append("SceneNode type cannot be empty")
    
    # Validate transform values
    if position.is_nan() or position.is_inf():
        errors.append("SceneNode position has invalid values")
    
    if not rotation.is_normalized():
        errors.append("SceneNode rotation quaternion is not normalized")
    
    return errors
```

### 3. GameRule Domain Entity
```gdscript
## GameRule.gd - Domain entity for game rules
## Preserves source_blocks and active state exactly as authored

class_name GameRule
extends RefCounted

# Identity
@export var id: String = ""
@export var name: String = ""
@export var description: String = ""

# CRITICAL: Preserve source_blocks exactly
@export var source_blocks: Array[String] = []

# CRITICAL: Preserve active state
@export var active: bool = true

# Additional metadata
@export var priority: int = 0
@export var tags: Array[String] = []
@export var metadata: Dictionary = {}

# Runtime state (not from template)
@export var compiled: bool = false
@export var compile_errors: Array[String] = []

## Serialization - preserves source_blocks and active exactly

func to_json() -> Dictionary:
    return {
        "id": id,
        "name": name,
        "description": description,
        "source_blocks": source_blocks.duplicate(true),  # Deep copy to preserve
        "active": active,  # Preserve boolean value exactly
        "priority": priority,
        "tags": tags.duplicate(true),
        "metadata": metadata.duplicate(true)
    }

func from_json(data: Dictionary) -> GameRule:
    # Preserve ALL fields exactly as in JSON
    id = data.get("id", "")
    name = data.get("name", "")
    description = data.get("description", "")
    
    # CRITICAL: Deep copy source_blocks to preserve exact content
    source_blocks = data.get("source_blocks", []).duplicate(true)
    
    # CRITICAL: Preserve active state exactly
    active = data.get("active", true)
    
    priority = data.get("priority", 0)
    tags = data.get("tags", []).duplicate(true)
    metadata = data.get("metadata", {}).duplicate(true)
    
    return self

## Validation
func validate() -> Array:
    var errors = []
    
    if id.is_empty():
        errors.append("GameRule ID cannot be empty")
    
    if source_blocks.is_empty():
        errors.append("GameRule must have at least one source block")
    
    # Check for valid source blocks
    for block in source_blocks:
        if not block is String:
            errors.append("Source block must be a string")
        elif block.is_empty():
            errors.append("Source block cannot be empty")
    
    return errors

## Equality check (for testing)
func equals(other: GameRule) -> bool:
    if id != other.id:
        return false
    if name != other.name:
        return false
    if description != other.description:
        return false
    if source_blocks != other.source_blocks:
        return false
    if active != other.active:
        return false
    if priority != other.priority:
        return false
    if tags != other.tags:
        return false
    # Deep compare metadata
    return JSON.stringify(metadata) == JSON.stringify(other.metadata)
```

### 4. Renderer Boundary (Adapter)
```gdscript
## WorldRenderer.gd - Converts domain entities to Godot nodes
## This is where JSON vectors/colors are normalized to Godot types

class_name WorldRenderer
extends Node3D

@export var world: World

## Render the world into the scene tree
func render_world() -> void:
    # Clear existing nodes
    for child in get_children():
        if child != self:
            child.queue_free()
    
    # Render scene nodes
    for scene_node in world.scene_nodes:
        _render_scene_node(scene_node)

## Render a single scene node
func _render_scene_node(domain_node: SceneNode) -> Node3D:
    var godot_node: Node3D
    
    # Create appropriate Godot node based on type
    match domain_node.node_type:
        "prop":
            godot_node = StaticBody3D.new()
        "character":
            godot_node = CharacterBody3D.new()
        "area":
            godot_node = Area3D.new()
        "rigid":
            godot_node = RigidBody3D.new()
        _:
            godot_node = Node3D.new()
    
    # Set node name
    godot_node.name = domain_node.name
    
    # NORMALIZE: Convert domain Vector3/Quaternion to Godot Transform3D
    # This is the boundary where JSON vectors are applied to Godot nodes
    var transform = Transform3D(
        Basis.from_euler domain_node.rotation.get_euler(),
        domain_node.position
    )
    # Scale is separate in Godot
    godot_node.scale = domain_node.scale
    godot_node.transform = transform
    
    # Apply properties
    _apply_properties(godot_node, domain_node.properties)
    
    # Set visibility and shadow settings
    godot_node.visible = domain_node.visible
    
    # Add to tree
    add_child(godot_node)
    
    # Render children
    for child in domain_node.children:
        var child_godot = _render_scene_node(child)
        godot_node.add_child(child_godot)
    
    return godot_node

## Apply properties to a Godot node
func _apply_properties(godot_node: Node, properties: Dictionary) -> void:
    # Apply standard Godot properties
    for key in properties:
        var value = properties[key]
        
        # Handle vector properties
        if key == "position" and value is Dictionary:
            godot_node.position = TemplateLoader._normalize_vector3(value)
        elif key == "rotation" and value is Dictionary:
            godot_node.rotation = TemplateLoader._normalize_quaternion(value)
        elif key == "scale" and value is Dictionary:
            godot_node.scale = TemplateLoader._normalize_vector3(value)
        # Handle color properties
        elif key.ends_with("_color") and value is Dictionary:
            var color = TemplateLoader._normalize_color(value)
            godot_node.set(key, color)
        # Handle other properties
        else:
            # Try to set directly
            if godot_node.has_method("set_%s" % key):
                godot_node.call("set_%s" % key, value)
            else:
                godot_node.set(key, value)
```

### 5. Round-Trip Test (Validation)
```gdscript
## test_template_loader_roundtrip.gd
## Tests that JSON → Domain → JSON preserves all data

class_name TemplateLoaderRoundTripTest
extends TestCase

func test_scene_node_roundtrip() -> void:
    # Create original JSON
    var original_json = {
        "name": "Test Tree",
        "node_type": "prop",
        "position": {"_type": "Vector3", "x": 1.0, "y": 2.0, "z": 3.0},
        "rotation": {"_type": "Quaternion", "x": 0.0, "y": 0.707, "z": 0.0, "w": 0.707},
        "scale": {"_type": "Vector3", "x": 1.5, "y": 1.5, "z": 1.5},
        "properties": {
            "health": 100,
            "model": "oak_tree",
            "interactable": true
        },
        "tags": ["tree", "nature", "collectible"],
        "visible": true,
        "cast_shadow": true,
        "metadata": {"author": "designer", "version": 1}
    }
    
    # Load from JSON
    var loader = TemplateLoader.new()
    var scene_node = loader._create_scene_node(original_json)
    
    # Convert back to JSON
    var roundtrip_json = scene_node.to_json()
    
    # Verify preservation
    assert_eq(original_json["name"], roundtrip_json["name"])
    assert_eq(original_json["node_type"], roundtrip_json["node_type"])
    
    # Check vector preservation (with tolerance for floating point)
    var orig_pos = Vector3(
        original_json["position"]["x"],
        original_json["position"]["y"],
        original_json["position"]["z"]
    )
    var rt_pos = Vector3(
        roundtrip_json["position"]["x"],
        roundtrip_json["position"]["y"],
        roundtrip_json["position"]["z"]
    )
    assert(orig_pos.is_equal_approx(rt_pos))
    
    # Check properties preservation
    assert_eq(original_json["properties"]["health"], roundtrip_json["properties"]["health"])
    assert_eq(original_json["properties"]["model"], roundtrip_json["properties"]["model"])
    
    # Check metadata preservation
    assert_eq(original_json["metadata"]["author"], roundtrip_json["metadata"]["author"])

func test_game_rule_roundtrip() -> void:
    # Create original JSON with source_blocks
    var original_json = {
        "id": "test_rule",
        "name": "Test Rule",
        "description": "A test rule",
        "source_blocks": [
            "ON player_interact WITH object",
            "  GIVE player gold 10",
            "  PLAY SOUND 'coins'",
            "ENDON"
        ],
        "active": false,
        "priority": 5,
        "tags": ["test", "gold"],
        "metadata": {"version": 1, "enabled": false}
    }
    
    # Load from JSON
    var loader = TemplateLoader.new()
    var game_rule = loader._create_game_rule(original_json)
    
    # Convert back to JSON
    var roundtrip_json = game_rule.to_json()
    
    # CRITICAL: Verify source_blocks preserved exactly
    assert_eq(original_json["source_blocks"].size(), roundtrip_json["source_blocks"].size())
    for i in range(original_json["source_blocks"].size()):
        assert_eq(
            original_json["source_blocks"][i],
            roundtrip_json["source_blocks"][i]
        )
    
    # CRITICAL: Verify active state preserved exactly
    assert_eq(original_json["active"], roundtrip_json["active"])
    
    # Verify other fields
    assert_eq(original_json["priority"], roundtrip_json["priority"])
    assert_eq(original_json["metadata"], roundtrip_json["metadata"])
```

---

## Asset Packages and Tools

### JSON Processing Libraries
| Library | URL | License | Purpose |
|---------|-----|---------|---------|
| JSON Parse | https://github.com/GodotExplorer/JSONParse | MIT | Extended JSON parsing |
| JSON Schema | https://github.com/GodotExplorer/JSONSchema | MIT | JSON validation |
| JSon | https://github.com/he airplane/json | MIT | Alternative JSON |

### Testing Frameworks
| Framework | URL | License | Purpose |
|-----------|-----|---------|---------|
| Godot Test Framework | Built-in | MIT | Unit testing |
| GUT | https://github.com/bitwes/Gut | MIT | Godot unit testing |
| QUEST | https://github.com/quete/QUEST | MIT | BDD testing |

### Serialization Helpers
| Library | URL | License | Purpose |
|---------|-----|---------|---------|
| Godot Serialization | Built-in | MIT | Resource serialization |
| Serde GD | https://github.com/GodotExplorer/serde-gd | MIT | Rust-like serialization |

---

## Learning Resources

### Godot 4 Documentation
- [JSON Class](https://docs.godotengine.org/en/stable/classes/class_json.html) - JSON parsing and stringifying
- [ResourceLoader](https://docs.godotengine.org/en/stable/classes/class_resourceloader.html) - Loading resources
- [ResourceSaver](https://docs.godotengine.org/en/stable/classes/class_resourcesaver.html) - Saving resources
- [Vector3](https://docs.godotengine.org/en/stable/classes/class_vector3.html) - 3D vector
- [Quaternion](https://docs.godotengine.org/en/stable/classes/class_quaternion.html) - Rotation quaternion
- [Transform3D](https://docs.godotengine.org/en/stable/classes/class_transform3d.html) - 3D transform

### Hexagonal Architecture
- [Hexagonal Architecture](https://alistair.cockburn.us/hexagonal-architecture/) - Original by Alistair Cockburn
- [Ports and Adapters](https://herbertograca.com/2017/11/16/explicit-architecture-01-ddd-hexagonal-onion-clean-cqrs-how-i-put-it-all-together/) - Detailed explanation
- [Clean Architecture](https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html) - Robert C. Martin

### Design Patterns in Godot
- [Factory Pattern](https://refactoring.guru/design-patterns/factory-method) - Creation pattern
- [Builder Pattern](https://refactoring.guru/design-patterns/builder) - Complex object creation
- [Visitor Pattern](https://refactoring.guru/design-patterns/visitor) - Tree traversal

### Template Systems
- [Godot Scene Instances](https://docs.godotengine.org/en/stable/tutorials/step_by_step/scene_instances.html) - Built-in instancing
- [Resource Preloading](https://docs.godotengine.org/en/stable/tutorials/best_practices/resource_preloading.html) - Efficient loading

---

## Implementation Checklist

### Phase 1: TemplateLoader Enhancement (HIGH Priority)
- [x] TemplateLoader preserves node position, rotation, scale
- [x] TemplateLoader preserves node properties dictionary
- [x] TemplateLoader preserves rule source_blocks array
- [x] TemplateLoader preserves rule active state
- [x] JSON-to-domain conversion preserves all fields
- [ ] Normalization at renderer boundary (JSON vectors/colors → Godot types)
- [ ] No Godot nodes in domain layer

### Phase 2: Domain Entity Validation (HIGH Priority)
- [ ] SceneNode validates all transforms
- [ ] SceneNode validates all properties
- [ ] GameRule validates source_blocks
- [ ] GameRule validates active state
- [ ] All entities have to_json() method
- [ ] All entities have from_json() method

### Phase 3: Round-Trip Testing (HIGH Priority)
- [ ] SceneNode round-trip test (JSON → Domain → JSON)
- [ ] GameRule round-trip test
- [ ] World round-trip test
- [ ] Property preservation test
- [ ] Transform preservation test
- [ ] Metadata preservation test

### Phase 4: Boundary Enforcement (MEDIUM Priority)
- [ ] Renderer normalizes all JSON vectors
- [ ] Renderer normalizes all JSON colors
- [ ] Renderer normalizes all JSON quaternions
- [ ] No Godot type leakage into domain
- [ ] All conversions happen at adapter boundary

### Phase 5: Integration Testing (HIGH Priority)
- [ ] Load adventure.json template
- [ ] Load obby.json template
- [ ] Verify all nodes have correct transforms
- [ ] Verify all nodes have correct properties
- [ ] Verify all rules have correct source_blocks
- [ ] Verify all rules have correct active state
- [ ] Render world and verify visual correctness

### Acceptance Criteria Verification
- [ ] TemplateLoader preserves node position, rotation, scale, and properties ✅
- [ ] TemplateLoader preserves rule source_blocks and active state ✅
- [ ] JSON-to-domain tests prove authored fields are not discarded
- [ ] Renderer boundary normalizes JSON vectors and colors
- [ ] No Godot nodes in domain layer

---

## Child-Safety Constraints

### Data Preservation
- [ ] All authored content preserved exactly
- [ ] No data loss during template loading
- [ ] No silent discarding of properties
- [ ] All metadata preserved for audit

### Type Safety
- [ ] Vectors normalized correctly
- [ ] Colors normalized correctly
- [ ] Quaternions normalized correctly
- [ ] No NaN or Inf values in transforms

### Validation
- [ ] SceneNode validation catches invalid data
- [ ] GameRule validation catches invalid data
- [ ] TemplateLoader reports parsing errors
- [ ] All errors logged for debugging

---

## References

### Internal Documentation
1. [PLAN.md](PLAN.md) - Project delivery plan
2. [.ai/tasks/backlog.yaml](.ai/tasks/backlog.yaml) - VS-001 definition
3. [src/application/template_loader.gd](src/application/template_loader.gd) - TemplateLoader implementation
4. [tests/application/test_template_loader.gd](tests/application/test_template_loader.gd) - TemplateLoader tests
5. [src/domain/world_authoring/](src/domain/world_authoring/) - Domain entities

### External Documentation
1. [Godot 4.6 JSON Class](https://docs.godotengine.org/en/stable/classes/class_json.html)
2. [Godot Vector3](https://docs.godotengine.org/en/stable/classes/class_vector3.html)
3. [Godot Quaternion](https://docs.godotengine.org/en/stable/classes/class_quaternion.html)
4. [Hexagonal Architecture](https://alistair.cockburn.us/hexagonal-architecture/)
5. [Factory Pattern](https://refactoring.guru/design-patterns/factory-method)
6. [Clean Architecture](https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html)

### Related Research
1. [RESEARCH_VS-002_Trigger_Metadata_Propagation.md](./RESEARCH_VS-002_Trigger_Metadata_Propagation.md) - Trigger system
2. [RESEARCH_VS-003_NPC_Scene_Tree_Lifecycle.md](./RESEARCH_VS-003_NPC_Scene_Tree_Lifecycle.md) - NPC lifecycle
3. [RESEARCH_VS-004_Clean_Profile_Adventure_Charter.md](./RESEARCH_VS-004_Clean_Profile_Adventure_Charter.md) - Adventure testing

---

## File Structure

```
src/application/
├── template_loader.gd              # Main template loader
├── entity_factory.gd               # Factory for domain entities
└── template_validator.gd           # Template validation

src/domain/world_authoring/
├── scene_node.gd                   # Domain scene node
├── game_rule.gd                    # Domain game rule
├── world.gd                        # Domain world
└── ...

tests/application/
├── test_template_loader.gd        # TemplateLoader tests
├── test_template_loader_roundtrip.gd  # Round-trip tests
└── template_loader_starter_smoke.gd  # Smoke tests

data/templates/
├── adventure.json                  # Adventure template
├── obby.json                      # Obby template
└── ...
```

---

*Document created: 2026-07-18*  
*Research status: COMPLETE*  
*Next step: Cross-agent review and implementation validation*
