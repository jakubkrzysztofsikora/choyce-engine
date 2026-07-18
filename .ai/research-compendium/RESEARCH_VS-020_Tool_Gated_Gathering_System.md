# Research Compendium: VS-020 — Tool-Gated Tree Cutting and Stone Mining

## Task Overview

**Task ID**: VS-020  
**Title**: Implement tool-gated tree cutting and stone mining sandbox loop  
**Specialty**: gathering-progression  
**Owner**: codex  
**Status**: in_progress  
**Dependencies**: [VS-018, VS-019]

### Acceptance Criteria
- Axe and pickaxe are discoverable or craftable and visible in the interaction flow
- Trees require an axe and stones require a pickaxe before yielding resources
- Harvest feedback, inventory changes, respawn behavior, and physical proxies are tested
- No timer, grind quota, or forced quest is introduced

---

## Current Implementation Analysis

### Existing Code Structure

The codebase already has a partial gathering system in place:

#### 1. Resource Definitions (world_renderer.gd)
```gdscript
# Gatherable resources defined in _add_gatherable_resource
_add_gatherable_resource("forest_wood_1", "wood_oak", Vector3(-55, 0, 46), "Kłoda", "Zbierz drewno", "gather_wood")
_add_gatherable_resource("cave_iron_1", "ore_iron", Vector3(36, 0, -48), "Skała z mchem", "Wydobądź kamień", "gather_stone")
```

#### 2. Interaction Anchors (world_renderer.gd)
```gdscript
func _add_interaction_anchor(id: String, anchor_position: Vector3, prompt: String, action: String) -> Area3D:
    var anchor := Area3D.new()
    anchor.name = id
    anchor.position = anchor_position
    anchor.add_to_group("world_interactable")
    anchor.set_meta("interaction_id", id)
    anchor.set_meta("interaction_prompt", prompt)
    anchor.set_meta("interaction_action", action)
    var shape := CollisionShape3D.new()
    var sphere := SphereShape3D.new()
    sphere.radius = 1.8
    shape.shape = sphere
    anchor.add_child(shape)
    add_child(anchor)
    return anchor
```

#### 3. Resource Gathering (gameplay_runtime.gd)
```gdscript
func _gather_world_resource(anchor: Node3D) -> void:
    var item_id := String(anchor.get_meta("resource_item_id", ""))
    if item_id.is_empty():
        return
    var inventory: Dictionary = {}
    if _rules_runtime != null:
        var raw: Variant = _rules_runtime.get_context_value("inventory")
        if raw is Dictionary:
            inventory = raw
    inventory[item_id] = int(inventory.get(item_id, 0)) + 1
    if _rules_runtime != null:
        _rules_runtime.set_context_value("inventory", inventory)
        _rules_runtime.on_event("inventory_changed", {"item": item_id})
        _rules_runtime.on_event("collect_%s" % item_id, {})
    # ... visual feedback, effects, cleanup
```

#### 4. Tool System (player_controller.gd)
```gdscript
# Tool definitions
const _AXE := "res://data/models/kenney/survival_kit/Models/GLB format/tool-axe.glb"
const _PICKAXE := "res://data/models/kenney/survival_kit/Models/GLB format/tool-pickaxe.glb"

const TOOL_DEFS: Dictionary = {
    "tool_axe": model_path = _AXE
    "tool_pickaxe": model_path = _PICKAXE
}

# Equipment
var _equipped_tool_id := ""
var _hotbar: Array = []

func equip_tool(tool_id: String) -> void:
    if tool_id not in ["tool_axe", "tool_pickaxe"]:
        return
    _equipped_tool_id = tool_id
    set_weapon_visual(tool_id)
    if not _hotbar.has(tool_id):
        _hotbar.append(tool_id)
    _active_slot = _hotbar.find(tool_id)
    hotbar_changed.emit(_active_slot, tool_id)

func has_equipped_tool(tool_id: String) -> bool:
    return _equipped_tool_id == tool_id
```

### Current Flow
1. Player approaches gatherable resource (tree, stone)
2. Interaction anchor (Area3D) detects player
3. `_nearby_world_interactable` is set
4. Player presses "E" to interact
5. `_gather_world_resource` is called
6. Resource is added to inventory
7. Visual is destroyed
8. **Missing**: Tool requirement check!

---

## What's Missing for VS-020

The current system allows gathering **without** tool requirements. VS-020 requires:
- Trees **require** an axe
- Stones **require** a pickaxe
- Proper feedback when tool is missing
- Tool discovery/crafting flow

---

## Online Research: Godot Tool-Gated Interaction Systems

### 1. Godot Input and Interaction Systems

#### Official Documentation
- [Godot Input System](https://docs.godotengine.org/en/stable/tutorials/inputs/input_examples.html)
- [Area3D for Proximity Detection](https://docs.godotengine.org/en/stable/classes/class_area3d.html)
- [Collision Layers and Masks](https://docs.godotengine.org/en/stable/tutorials/physics/physics_intro.html#collision-layers-and-masks)

#### Best Practices for Interaction Systems

**A. Proximity-Based Interaction**:
```gdscript
# Current implementation uses Area3D for proximity detection
# This is the correct approach for Godot 4.x

# Improved: Use signals for cleaner architecture
signal resource_entered(resource: Node3D)
signal resource_exited(resource: Node3D)

func _ready():
    var area := Area3D.new()
    area.connect("body_entered", _on_body_entered)
    area.connect("body_exited", _on_body_exited)
    add_child(area)
```

**B. Input Buffering**:
```gdscript
# Buffer "E" key press for when entering interaction range
var _buffered_interaction := false

func _unhandled_input(event):
    if event.is_action_pressed("interact"):
        if _nearby_world_interactable:
            _perform_interaction()
        else:
            _buffered_interaction = true

func _on_interactable_entered(interactable):
    _nearby_world_interactable = interactable
    if _buffered_interaction:
        _buffered_interaction = false
        _perform_interaction()
```

### 2. Tool System Architectures

#### A. Component-Based Tools
```gdscript
# Base Tool class
class_name Tool
extends RefCounted

var tool_id: String
var display_name: String
var icon: Texture2D
var action: String  # "chop", "mine", "dig"
var required_tags: Array = []  # ["tree", "log"]

func can_use(target: Node3D) -> bool:
    for tag in required_tags:
        if not target.has_meta("tags") or not target.get_meta("tags").has(tag):
            return false
    return true

func use(target: Node3D) -> Dictionary:
    # Returns result: {success: bool, message: String, loot: Array}
    return {"success": true, "message": "Gathered!", "loot": ["wood_oak"]}
```

#### B. Tool Registry Pattern
```gdscript
# Central tool registry
var TOOL_REGISTRY: Dictionary = {
    "tool_axe": {
        "name": "Axe",
        "action": "chop",
        "required_tags": ["tree", "log"],
        "effective_tags": ["wood"],
        "model": "res://models/tool_axe.glb",
        "icon": "res://textures/icon_axe.png",
        "sound": "res://audio/chop.ogg"
    },
    "tool_pickaxe": {
        "name": "Pickaxe", 
        "action": "mine",
        "required_tags": ["stone", "ore"],
        "effective_tags": ["stone", "ore"],
        "model": "res://models/tool_pickaxe.glb",
        "icon": "res://textures/icon_pickaxe.png",
        "sound": "res://audio/mine.ogg"
    }
}

func get_tool_definition(tool_id: String) -> Dictionary:
    return TOOL_REGISTRY.get(tool_id, null)

func can_tool_act_on(tool_id: String, target: Node3D) -> bool:
    var def := get_tool_definition(tool_id)
    if def == null:
        return false
    var target_tags := target.get_meta("tags", [])
    for required_tag in def.get("required_tags", []):
        if not target_tags.has(required_tag):
            return false
    return true
```

### 3. Gathering System Design Patterns

#### A. Resource Definition System
```gdscript
class_name ResourceDefinition
extends RefCounted

var resource_id: String  # "wood_oak", "ore_iron"
var display_name: String  # "Drewno dębowe", "Ruda żelaza"
var description: String
var icon: Texture2D
var gather_action: String  # "gather_wood", "gather_stone"
var required_tool: String  # "tool_axe", "tool_pickaxe"
var gather_time: float = 1.5  # Seconds to gather
var respawn_time: float = 30.0  # Seconds to respawn
var loot_table: Array = [{"item": "wood_oak", "count": 1, "probability": 1.0}]
var visual_prefab: String  # Path to 3D model
var sound_effect: String  # Path to gathering sound

# Tags for tool matching
var tags: Array = ["tree", "wood", "renewable"]
```

#### B. Gathering State Machine
```gdscript
enum GatheringState { IDLE, STARTING, GATHERING, COMPLETING, ON_COOLDOWN }

class_name GatherableResource
extends Area3D

signal gathering_started(player: Node3D, tool: String)
signal gathering_completed(player: Node3D, items: Array)
signal gathering_failed(player: Node3D, reason: String)

var definition: ResourceDefinition
var current_state: GatheringState = GatheringState.IDLE
var gathering_player: Node3D = null
var gathering_tool: String = ""
var progress: float = 0.0
var cooldown_remaining: float = 0.0

func _process(delta):
    match current_state:
        GatheringState.GATHERING:
            progress += delta / definition.gather_time
            if progress >= 1.0:
                current_state = GatheringState.COMPLETING
                _complete_gathering()
        GatheringState.ON_COOLDOWN:
            cooldown_remaining -= delta
            if cooldown_remaining <= 0:
                current_state = GatheringState.IDLE
                _respawn()

func try_gather(player: Node3D, tool_id: String) -> bool:
    if current_state != GatheringState.IDLE:
        return false
    
    var tool_def := get_tool_definition(tool_id)
    if not can_tool_act_on(tool_id, self):
        emit_signal("gathering_failed", player, "wrong_tool")
        return false
    
    gathering_player = player
    gathering_tool = tool_id
    current_state = GatheringState.GATHERING
    progress = 0.0
    emit_signal("gathering_started", player, tool_id)
    
    # Play gathering animation/sound
    if tool_def != null and tool_def.has("sound"):
        AudioStreamPlayer.new().play(tool_def["sound"])
    
    return true
```

### 4. Progress Bars and Visual Feedback

#### A. Gathering Progress Bar
```gdscript
# Create a progress bar that follows the resource
var _gathering_progress_bar: ProgressBar

func show_gathering_progress(target: Node3D, duration: float):
    if _gathering_progress_bar == null:
        _gathering_progress_bar = ProgressBar.new()
        _gathering_progress_bar.add_to_group("hud_progress")
        # Style the progress bar
        _gathering_progress_bar.self_modulate = Color(1, 1, 1, 0.9)
        _gathering_progress_bar.tint_progress = Color.GREEN
        _gathering_progress_bar.tint_fill = Color.DARK_GREEN
        add_child(_gathering_progress_bar)
    
    _gathering_progress_bar.value = 0
    _gathering_progress_bar.max_value = duration
    _gathering_progress_bar.visible = true
    # Position above the resource in world space
    _gathering_progress_bar.global_position = target.global_position + Vector3(0, 2, 0)
    
    # Animate
    var tween := create_tween()
    tween.tween_property(_gathering_progress_bar, "value", duration, duration)
    tween.connect("finished", _on_gathering_progress_complete)

func hide_gathering_progress():
    if _gathering_progress_bar != null:
        _gathering_progress_bar.visible = false
```

#### B. Particle Effects for Gathering
```gdscript
# Use GPUParticles3D for gathering effects
const WOOD_CHIPS := preload("res://particles/wood_chips.gp3d")
const STONE_DUST := preload("res://particles/stone_dust.gp3d")

func play_gathering_effect(resource_type: String, position: Vector3):
    var particles := GPUParticles3D.new()
    particles.particle_process_mode = Node.PROCESS_MODE_LOCAL
    
    if resource_type == "wood":
        particles.process_material = WOOD_CHIPS
    elif resource_type == "stone":
        particles.process_material = STONE_DUST
    
    particles.global_position = position
    particles.emitting = true
    add_child(particles)
    
    # Remove after effect completes
    yield(get_tree().create_timer(2.0), "timeout")
    if is_instance_valid(particles):
        particles.queue_free()
```

### 5. Respawn System

#### A. Deterministic Respawn
```gdscript
# Each resource has a unique seed based on its position
var _resource_seeds: Dictionary = {}

func generate_resource_seed(world_id: String, position: Vector3) -> int:
    var key := "%s_%s" % [world_id, position.to_string()]
    if not _resource_seeds.has(key):
        _resource_seeds[key] = randi()
    return _resource_seeds[key]

func calculate_respawn_time(base_time: float, seed: int) -> float:
    # Add small random variation to prevent synchronized respawning
    var rng := RandomNumberGenerator.new()
    rng.seed = seed
    return base_time * rng.randf_range(0.9, 1.1)
```

#### B. Respawn with Growth Stages
```gdscript
enum GrowthStage { SAPLING, YOUNG, MATURE, READY }

class_name RenewableResource
extends Area3D

var growth_stage: GrowthStage = GrowthStage.SAPLING
var growth_timers: Dictionary = {}

func _ready():
    _start_growth()

func _start_growth():
    var growth_time := _get_stage_growth_time(growth_stage)
    growth_timers["growth"] = get_tree().create_timer(growth_time)
    growth_timers["growth"].connect("timeout", _advance_growth)

func _advance_growth():
    growth_stage += 1
    if growth_stage == GrowthStage.READY:
        # Resource is now gatherable
        _make_gatherable()
    else:
        _start_growth()

func _make_gatherable():
    # Enable interaction
    set_deferred("monitoring", true)
    set_deferred("monitorable", true)
    # Visual change to indicate readiness
```

### 6. Tool Durability System

#### A. Durability Component
```gdscript
class_name ToolDurability
extends Node

var max_durability: int = 100
var current_durability: int = 100
var durability_per_use: int = 1

signal durability_changed(new_durability: int, max_durability: int)
signal tool_broke()

func use() -> bool:
    current_durability -= durability_per_use
    durability_changed.emit(current_durability, max_durability)
    
    if current_durability <= 0:
        tool_broke.emit()
        return false
    return true

func repair(amount: int) -> void:
    current_durability = min(current_durability + amount, max_durability)
    durability_changed.emit(current_durability, max_durability)
```

#### B. Tool Quality Tiers
```gdscript
const TOOL_TIERS := {
    "wooden": {"durability": 50, "efficiency": 1.0, "required_level": 1},
    "stone": {"durability": 100, "efficiency": 1.2, "required_level": 5},
    "iron": {"durability": 200, "efficiency": 1.5, "required_level": 10},
    "diamond": {"durability": 500, "efficiency": 2.0, "required_level": 20}
}

func get_tool_efficiency(tool_id: String) -> float:
    var tier := tool_id.get_slice("_", 1)
    var tier_data := TOOL_TIERS.get(tier, TOOL_TIERS["wooden"])
    return tier_data["efficiency"]
```

### 7. Inventory System Integration

#### A. Tool Equipment Slots
```gdscript
class_name EquipmentSystem
extends Node

const TOOL_SLOT := "tool"
const WEAPON_SLOT := "weapon"
const ARMOR_SLOT := "armor"

var equipped: Dictionary = {}

signal tool_equipped(slot: String, tool_id: String)
signal tool_unequipped(slot: String)

func equip(slot: String, item_id: String) -> bool:
    # Check if item is a valid tool for this slot
    if slot == TOOL_SLOT and not item_id.begins_with("tool_"):
        return false
    
    # Unequip current
    if equipped.has(slot):
        unequip(slot)
    
    # Equip new
    equipped[slot] = item_id
    tool_equipped.emit(slot, item_id)
    return true

func unequip(slot: String) -> String:
    var item_id := equipped.get(slot, "")
    if item_id != "":
        equipped.erase(slot)
        tool_unequipped.emit(slot)
    return item_id

func get_equipped_tool() -> String:
    return equipped.get(TOOL_SLOT, "")
```

#### B. Hotbar System
```gdscript
class_name Hotbar
extends HBoxContainer

var slots: Array = []
var active_slot: int = 0

signal slot_selected(index: int, item_id: String)
signal slot_activated(index: int, item_id: String)

func _ready():
    for i in range(8):  # 8 hotbar slots
        var slot := create_slot(i)
        slots.append(slot)
        add_child(slot)

func create_slot(index: int) -> Control:
    var slot := Control.new()
    slot.name = "Slot_%d" % index
    # Add icon, border, etc.
    return slot

func set_slot_item(slot_index: int, item_id: String, icon: Texture2D = null, count: int = 1):
    if slot_index < 0 or slot_index >= slots.size():
        return
    # Update slot UI
    slots[slot_index].set_item(item_id, icon, count)

func select_slot(index: int):
    if index < 0 or index >= slots.size():
        return
    # Deselect current
    if active_slot >= 0 and active_slot < slots.size():
        slots[active_slot].set_selected(false)
    # Select new
    active_slot = index
    slots[active_slot].set_selected(true)
    slot_selected.emit(active_slot, slots[active_slot].item_id)

func activate_slot(index: int):
    if index < 0 or index >= slots.size():
        index = active_slot
    slot_activated.emit(index, slots[index].item_id)
```

### 8. Crafting System Integration

#### A. Tool Crafting Recipes
```gdscript
const TOOL_RECIPES := [
    {
        "id": "tool_axe_wooden",
        "name": "Wooden Axe",
        "result": "tool_axe",
        "ingredients": {"wood_oak": 5, "rope": 2},
        "workstation": "workbench",
        "crafting_time": 2.0,
        "required_level": 1
    },
    {
        "id": "tool_pickaxe_stone",
        "name": "Stone Pickaxe", 
        "result": "tool_pickaxe",
        "ingredients": {"wood_oak": 3, "ore_iron": 2, "rope": 1},
        "workstation": "workbench",
        "crafting_time": 3.0,
        "required_level": 5
    },
    {
        "id": "tool_axe_iron",
        "name": "Iron Axe",
        "result": "tool_axe_iron",
        "ingredients": {"wood_oak": 2, "ore_iron": 3},
        "workstation": "anvil",
        "crafting_time": 4.0,
        "required_level": 10
    }
]

func can_craft(recipe_id: String, inventory: Dictionary) -> bool:
    var recipe := get_recipe(recipe_id)
    if recipe == null:
        return false
    
    for ingredient in recipe["ingredients"]:
        if not inventory.has(ingredient.key) or inventory[ingredient.key] < ingredient.value:
            return false
    return true

func craft(recipe_id: String, inventory: Dictionary) -> Dictionary:
    var recipe := get_recipe(recipe_id)
    var new_inventory := inventory.duplicate()
    
    # Consume ingredients
    for ingredient in recipe["ingredients"]:
        new_inventory[ingredient.key] -= ingredient.value
    
    # Add result
    new_inventory[recipe["result"]] = new_inventory.get(recipe["result"], 0) + 1
    
    return new_inventory
```

### 9. Visual and Audio Feedback

#### A. Gathering Animations
```gdscript
# Tree chopping animation
const TREE_CHOP_ANIM := preload("res://animations/tree_chop.tres")

func play_chop_animation(tree: Node3D, hit_position: Vector3):
    var anim_player := AnimationPlayer.new()
    tree.add_child(anim_player)
    anim_player.add_animation_library("chop")
    anim_player.load("res://animations/tree_chop.tres")
    anim_player.play("chop")
    anim_player.connect("animation_finished", func(anim_name):
        anim_player.queue_free()
    )
```

#### B. Camera Shake on Gathering
```gdscript
func shake_camera(intensity: float = 0.1, duration: float = 0.2):
    if _player_controller != null and _player_controller.get_camera() != null:
        var camera := _player_controller.get_camera()
        var original_pos := camera.global_position
        var tween := create_tween()
        tween.tween_property(camera, "global_position", 
            original_pos + Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * intensity,
            duration / 2.0)
        tween.tween_property(camera, "global_position", original_pos, duration / 2.0)
```

#### C. Sound Effects
```gdscript
const SOUND_CHOP := preload("res://audio/sfx/chop.ogg")
const SOUND_MINE := preload("res://audio/sfx/mine.ogg")
const SOUND_WHOOSH := preload("res://audio/sfx/whoosh.ogg")

func play_gathering_sound(resource_type: String, position: Vector3):
    var audio := AudioStreamPlayer3D.new()
    audio.global_position = position
    
    if resource_type == "wood":
        audio.stream = SOUND_CHOP
    elif resource_type == "stone":
        audio.stream = SOUND_MINE
    else:
        audio.stream = SOUND_WHOOSH
    
    add_child(audio)
    audio.play()
    audio.connect("finished", func(): audio.queue_free())
```

### 10. Free Asset Packages for Tools and Resources

#### A. Tool Models (CC0/Kenney)
- **[Kenney Survival Kit](https://kenney.nl/assets/survival-kit)**
  - `tool-axe.glb` - Axe model
  - `tool-pickaxe.glb` - Pickaxe model
  - `tool-shovel.glb` - Shovel model
  - Already included in project at `data/models/kenney/survival_kit/`

- **[Kenney UI Pack](https://kenney.nl/assets/ui-pack)**
  - Icons for tools and resources
  - Hotbar slot graphics
  - Progress bar styles

- **[Kenney RPG Pack](https://kenney.nl/assets/rpg-interface)**
  - Inventory UI elements
  - Tool icons
  - Resource icons

#### B. Resource Models
- **[Kenney Nature Kit](https://kenney.nl/assets/nature-pack)**
  - Trees, logs, stumps
  - Rocks, stones, ores
  - Already included

- **[Kenney Farming Pack](https://kenney.nl/assets/farming-pack)**
  - Wood piles, stone blocks
  - Crafting materials

#### C. Particle Effects
- **[Kenney Particle Pack](https://kenney.nl/assets/particle-pack)**
  - Wood chips
  - Stone dust
  - Spark effects

- **Custom GPUParticles3D**:
  - Can create custom effects in Godot
  - More performant than CPU particles

#### D. Sound Effects
- **[Kenney Audio Pack](https://kenney.nl/assets/audio-pack)**
  - Chopping sounds
  - Mining sounds
  - Gathering sounds

- **[Freesound](https://freesound.org/)**
  - Search for "wood chop", "stone mine", "gather"
  - Filter by CC0 license

- **[OpenGameArt](https://opengameart.org/)**
  - Game-ready sound effects
  - CC0 and CC-BY licensed

### 11. Testing Strategies

#### A. Unit Tests for Tool System
```gdscript
func test_tool_requirements():
    var axe_def := get_tool_definition("tool_axe")
    var pickaxe_def := get_tool_definition("tool_pickaxe")
    
    # Test tree requires axe
    var tree := create_mock_resource("tree", ["tree", "wood"])
    assert(can_tool_act_on("tool_axe", tree), "Axe should work on tree")
    assert(not can_tool_act_on("tool_pickaxe", tree), "Pickaxe should NOT work on tree")
    
    # Test stone requires pickaxe
    var stone := create_mock_resource("stone", ["stone", "ore"])
    assert(can_tool_act_on("tool_pickaxe", stone), "Pickaxe should work on stone")
    assert(not can_tool_act_on("tool_axe", stone), "Axe should NOT work on stone")

func test_gathering_flow():
    var tree := create_gatherable_resource("tree_1", "wood_oak", Vector3(10, 0, 5), "tree")
    var player := create_mock_player()
    player.equip_tool("tool_axe")
    
    # Start gathering
    assert(tree.try_gather(player, "tool_axe"), "Gathering should start")
    assert(tree.current_state == GatheringState.GATHERING, "State should be GATHERING")
    
    # Fast-forward gathering
    tree.progress = 1.0
    tree._complete_gathering()
    
    assert(player.inventory.get("wood_oak", 0) == 1, "Player should have wood")
```

#### B. Integration Tests
```gdscript
func test_full_gathering_loop():
    # Create world with tree
    var world := create_test_world()
    var tree_pos := Vector3(10, 0, 5)
    world.add_tree(tree_pos)
    
    # Create player with axe
    var player := create_test_player()
    player.equip_tool("tool_axe")
    player.position = tree_pos + Vector3(2, 0, 0)
    
    # Simulate player movement to tree
    player.position = tree_pos + Vector3(0.5, 0, 0)
    world._process(0.1)
    
    # Check interaction detected
    assert(player.nearby_interactable != null, "Should detect tree")
    
    # Gather
    player.interact()
    
    # Check results
    assert(player.inventory.get("wood_oak", 0) >= 1, "Should have wood")
    assert(world.tree_exists(tree_pos) == false, "Tree should be gone or in cooldown")
```

#### C. Performance Tests
```gdscript
func test_gathering_performance():
    # Create world with 100 gatherable resources
    var world := create_test_world()
    for i in range(100):
        world.add_tree(Vector3(randf_range(-100, 100), 0, randf_range(-100, 100)))
    
    var start_time := Time.get_ticks_msec()
    
    # Process world for 100 frames
    for i in range(100):
        world._process(0.016)
    
    var end_time := Time.get_ticks_msec()
    var total_time := end_time - start_time
    
    # Should process 100 frames in under 500ms (5ms per frame avg)
    assert(total_time < 500, "World processing too slow: %d ms" % total_time)
```

### 12. Implementation Roadmap

#### Phase 1: Tool Requirement System (Blocker)
1. [ ] Add tool requirement check to `_gather_world_resource`
2. [ ] Create tool definition system (TOOL_REGISTRY)
3. [ ] Add tool tagging to gatherable resources
4. [ ] Implement "wrong tool" feedback
5. [ ] Add visual indicator for tool requirements

#### Phase 2: Gathering Feedback & Polish
1. [ ] Add gathering progress bar
2. [ ] Implement gathering animations
3. [ ] Add particle effects for gathering
4. [ ] Add sound effects
5. [ ] Add camera shake

#### Phase 3: Tool Progression System
1. [ ] Implement tool durability
2. [ ] Add tool quality tiers
3. [ ] Create tool crafting recipes
4. [ ] Add tool upgrade system
5. [ ] Implement tool repair system

#### Phase 4: Resource Respawn System
1. [ ] Add respawn timers
2. [ ] Implement growth stages (for trees)
3. [ ] Add visual feedback for respawning
4. [ ] Test respawn determinism

#### Phase 5: Integration & Testing
1. [ ] Integrate with existing inventory system
2. [ ] Add to hotbar system
3. [ ] Write unit tests
4. [ ] Write integration tests
5. [ ] Performance testing

### 13. Code Samples

#### A. Tool Requirement Check
```gdscript
# Add to gameplay_runtime.gd
func _gather_world_resource(anchor: Node3D) -> void:
    if anchor == null or not is_instance_valid(anchor):
        return
    
    var item_id := String(anchor.get_meta("resource_item_id", ""))
    if item_id.is_empty():
        return
    
    # NEW: Check tool requirement
    var required_tool := String(anchor.get_meta("required_tool", ""))
    if not required_tool.is_empty():
        if not _player_controller.has_equipped_tool(required_tool):
            _interaction_feedback("Potrzebujesz %s!" % _get_tool_display_name(required_tool))
            return
    
    # Continue with gathering...
    # ... rest of function
```

#### B. Tag-Based Tool Matching
```gdscript
# Add metadata to resources
func _add_gatherable_resource(id: String, item_id: String, position: Vector3, 
        prop_name: String, prompt: String, action: String, required_tool: String = "") -> void:
    # ... existing code
    anchor.set_meta("resource_item_id", item_id)
    anchor.set_meta("resource_visual", visual)
    anchor.set_meta("interaction_action", action)
    anchor.set_meta("interaction_prompt", prompt)
    
    # NEW: Add required tool
    if not required_tool.is_empty():
        anchor.set_meta("required_tool", required_tool)
    
    # NEW: Add tags for tool matching
    var tags := []
    match action:
        "gather_wood":
            tags = ["tree", "wood", "renewable"]
        "gather_stone":
            tags = ["stone", "ore", "mineable"]
    anchor.set_meta("tags", tags)
```

#### C. Tool Display Names
```gdscript
const TOOL_DISPLAY_NAMES := {
    "tool_axe": "Topór",
    "tool_pickaxe": "Kilof",
    "tool_shovel": "Łopata",
    "tool_hammer": "Młotek"
}

func _get_tool_display_name(tool_id: String) -> String:
    return TOOL_DISPLAY_NAMES.get(tool_id, tool_id)
```

#### D. Gathering with Progress
```gdscript
func _try_gather_with_tool(anchor: Node3D) -> void:
    var required_tool := String(anchor.get_meta("required_tool", ""))
    
    if not required_tool.is_empty():
        if not _player_controller.has_equipped_tool(required_tool):
            _interaction_feedback("Potrzebujesz %s!" % _get_tool_display_name(required_tool))
            return
    
    # Start gathering with progress
    var action := String(anchor.get_meta("interaction_action", ""))
    var gather_time := 1.5  # Default gathering time
    
    if action == "gather_wood":
        gather_time = 1.8
    elif action == "gather_stone":
        gather_time = 2.2
    
    # Show progress bar
    _show_gathering_progress(anchor, gather_time)
    
    # Disable player movement during gathering
    if _player_controller != null:
        _player_controller.set_movement_locked(true)
    
    # Wait for gathering to complete
    yield(get_tree().create_timer(gather_time), "timeout")
    
    # Complete gathering
    if is_instance_valid(anchor):
        _gather_world_resource(anchor)
    
    # Re-enable player
    if _player_controller != null:
        _player_controller.set_movement_locked(false)
    
    _hide_gathering_progress()
```

#### E. Tool Discovery System
```gdscript
# Add to world_renderer.gd
func _build_starter_tools() -> void:
    # Place tools in the world for discovery
    var tool_positions := [
        {"tool": "tool_axe", "position": Vector3(15, 0, 10), "on_ground": true},
        {"tool": "tool_pickaxe", "position": Vector3(-12, 0, 8), "on_ground": true}
    ]
    
    for tool_info in tool_positions:
        var tool_node := _add_visual_asset(
            "world_tool_%s" % tool_info["tool"],
            tool_info["position"],
            Vector3.ONE,
            0.0,
            _prop_path_for_name(tool_info["tool"]),
            true
        )
        
        if tool_node != null and tool_info.get("on_ground", false):
            # Make tool pickable
            var anchor := _add_interaction_anchor(
                "tool_%s" % tool_info["tool"],
                tool_info["position"],
                "E  Podnieś %s" % _get_tool_display_name(tool_info["tool"]),
                "pickup_tool"
            )
            anchor.set_meta("tool_id", tool_info["tool"])
            anchor.set_meta("tool_visual", tool_node)
```

#### F. Pickup Tool Handler
```gdscript
# Add to gameplay_runtime.gd
func _pickup_tool(anchor: Node3D) -> void:
    var tool_id := String(anchor.get_meta("tool_id", ""))
    if tool_id.is_empty():
        return
    
    # Add to inventory
    var inventory: Dictionary = {}
    if _rules_runtime != null:
        var raw: Variant = _rules_runtime.get_context_value("inventory")
        if raw is Dictionary:
            inventory = raw
    
    inventory[tool_id] = inventory.get(tool_id, 0) + 1
    
    if _rules_runtime != null:
        _rules_runtime.set_context_value("inventory", inventory)
        _rules_runtime.on_event("inventory_changed", {"item": tool_id})
    
    _refresh_inventory_panel(inventory)
    
    # Visual feedback
    var visual := anchor.get_meta("tool_visual", null)
    if visual != null and is_instance_valid(visual):
        visual.queue_free()
    
    anchor.remove_from_group("world_interactable")
    if _nearby_world_interactable == anchor:
        _nearby_world_interactable = null
    anchor.queue_free()
    
    _interaction_feedback("Znaleziono %s!" % _get_tool_display_name(tool_id))
    
    # Auto-equip if hotbar has space
    if _player_controller != null:
        _player_controller.equip_tool(tool_id)
```

### 14. Recommended Packages & Addons

| Package | Purpose | License | Link |
|---------|---------|---------|------|
| Kenney Survival Kit | Tool models (axe, pickaxe) | CC0 | [kenney.nl](https://kenney.nl/assets/survival-kit) |
| Kenney Nature Kit | Trees, stones, resources | CC0 | [kenney.nl](https://kenney.nl/assets/nature-pack) |
| Kenney UI Pack | Hotbar, inventory icons | CC0 | [kenney.nl](https://kenney.nl/assets/ui-pack) |
| Kenney RPG Pack | More tool/resource icons | CC0 | [kenney.nl](https://kenney.nl/assets/rpg-interface) |
| Godot Navigation | AI pathfinding for NPCs | MIT | Built-in |
| GPUParticles3D | High-performance effects | MIT | Built-in |

### 15. Learning Resources

#### Tutorials
- [Godot 4.0 Inventory System](https://www.youtube.com/watch?v=Mc1xxL3k82o)
- [Godot Tool System Tutorial](https://www.youtube.com/watch?v=K2E5F-wX9AQ)
- [Godot Crafting System](https://www.youtube.com/watch?v=5oL3XhM99KY)
- [Godot RPG Inventory](https://kids-candies.gitbook.io/godot-tutorials/rpg/inventory)

#### Documentation
- [Godot Area3D](https://docs.godotengine.org/en/stable/classes/class_area3d.html)
- [Godot Input System](https://docs.godotengine.org/en/stable/tutorials/inputs/input_examples.html)
- [Godot Animation System](https://docs.godotengine.org/en/stable/tutorials/animation/index.html)
- [Godot Particle Systems](https://docs.godotengine.org/en/stable/tutorials/particles/particles_3d.html)

#### Books
- [Godot 4 Game Development Projects](https://www.packtpub.com/product/godot-4-game-development-projects/9781801812746)
- [Making Games with Godot 4.0](https://gumroad.com/l/godot4-book)

#### Communities
- [Godot Forums - Gameplay Systems](https://forum.godotengine.org/c/gameplay/12)
- [Godot Discord](https://discord.gg/4JBkykG) - #gameplay channel
- [r/godot](https://www.reddit.com/r/godot/) - Gameplay discussions

### 16. Integration Checklist

- [ ] Add tool requirement check to `_gather_world_resource`
- [ ] Create tool definition registry
- [ ] Add tool tags to gatherable resources
- [ ] Implement wrong tool feedback
- [ ] Add tool pickup system
- [ ] Create tool display names (Polish)
- [ ] Add gathering progress visualization
- [ ] Implement gathering animations
- [ ] Add particle effects
- [ ] Add sound effects
- [ ] Add camera shake
- [ ] Integrate with hotbar system
- [ ] Add tool durability (optional for VS-020)
- [ ] Create tool crafting recipes (optional for VS-020)
- [ ] Implement resource respawn system
- [ ] Write unit tests
- [ ] Write integration tests
- [ ] Performance testing
- [ ] Manual QA testing

---

## Implementation Notes

### Critical Path for VS-020
The minimum viable implementation for VS-020 requires:

1. **Tool requirement check** - Block gathering without correct tool
2. **Tool discovery** - Place tools in world for player to find
3. **Tool equipment** - Allow player to equip/unequip tools
4. **Visual feedback** - Show when tool is missing or gathering is in progress
5. **Basic respawn** - Resources reappear after gathering

Advanced features (durability, crafting, tiers) can come later.

### Current Gaps
- No tool requirement check exists
- Tools are not placed in the world
- No visual feedback for tool requirements
- Resources don't respawn
- No gathering progress indication

### Suggested First Commit
```gdscript
# Minimal changes to achieve VS-020 acceptance criteria:

# 1. Add required_tool metadata to resources
# In world_renderer.gd, line 557-570:
func _add_gatherable_resource(id: String, item_id: String, position: Vector3, 
        prop_name: String, prompt: String, action: String) -> void:
    # ... existing code
    
    # NEW: Determine required tool based on action
    var required_tool := ""
    if action == "gather_wood":
        required_tool = "tool_axe"
    elif action == "gather_stone":
        required_tool = "tool_pickaxe"
    
    if not required_tool.is_empty():
        anchor.set_meta("required_tool", required_tool)

# 2. Add tool check to gathering
# In gameplay_runtime.gd, line 1844-1874:
func _gather_world_resource(anchor: Node3D) -> void:
    # NEW: Check tool requirement
    var required_tool := String(anchor.get_meta("required_tool", ""))
    if not required_tool.is_empty():
        if not _player_controller or not _player_controller.has_equipped_tool(required_tool):
            _interaction_feedback("Potrzebujesz topora!" if required_tool == "tool_axe" else "Potrzebujesz kilofa!")
            return
    # ... rest of existing code

# 3. Place tools in world
# In world_renderer.gd, _build_starter_homestead (around line 930):
func _build_starter_homestead() -> void:
    # ... existing code
    
    # NEW: Add tools for discovery
    _add_visual_asset("starter_axe", center + Vector3(3.0, 0.0, 0.5), 
        Vector3.ONE, 0.0, _prop_path_for_name("topór"), true)
    var axe_anchor := _add_interaction_anchor("tool_axe", center + Vector3(3.0, 0.0, 0.5),
        "E  Podnieś topór", "pickup_tool")
    axe_anchor.set_meta("tool_id", "tool_axe")
    
    _add_visual_asset("starter_pickaxe", center + Vector3(2.5, 0.0, -0.5), 
        Vector3.ONE, 0.0, _prop_path_for_name("kilof"), true)
    var pickaxe_anchor := _add_interaction_anchor("tool_pickaxe", center + Vector3(2.5, 0.0, -0.5),
        "E  Podnieś kilof", "pickup_tool")
    pickaxe_anchor.set_meta("tool_id", "tool_pickaxe")
```

---

## References

1. [Godot 4.6 Documentation](https://docs.godotengine.org/en/stable/)
2. [Godot Input System](https://docs.godotengine.org/en/stable/tutorials/inputs/input_examples.html)
3. [Godot Area3D](https://docs.godotengine.org/en/stable/classes/class_area3d.html)
4. [Godot Animation](https://docs.godotengine.org/en/stable/tutorials/animation/index.html)
5. [Kenney Assets](https://kenney.nl/assets) - CC0 asset packs
6. [Kenney Survival Kit](https://kenney.nl/assets/survival-kit)
7. [Kenney Nature Kit](https://kenney.nl/assets/nature-pack)
8. [Godot Particle Systems](https://docs.godotengine.org/en/stable/tutorials/particles/particles_3d.html)
9. [Godot Inventory Tutorial](https://www.youtube.com/watch?v=Mc1xxL3k82o)
10. [Godot Crafting Tutorial](https://www.youtube.com/watch?v=5oL3XhM99KY)
