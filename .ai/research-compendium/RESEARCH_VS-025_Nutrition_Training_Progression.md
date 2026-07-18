# RESEARCH VS-025: Nutrition, Training & Visible Body Progression

## Choyce Engine - Vertical Slice Research Compendium

**Task ID:** VS-025  
**Title:** Add child-safe nutrition, training, and visible body-progression sandbox loop  
**Specialty:** sandbox-progression  
**Status:** in_progress  
**Dependencies:** [VS-022]  
**Owner:** codex  
**Cross-review:** claude  

---

## Table of Contents

1. [Task Overview](#task-overview)
2. [Current Implementation Analysis](#current-implementation-analysis)
3. [Online Research Summary](#online-research-summary)
4. [Child-Safety Design Philosophy](#child-safety-design-philosophy)
5. [Technical Deep Dive](#technical-deep-dive)
6. [Code Samples & Patterns](#code-samples--patterns)
7. [Asset Packages](#asset-packages)
8. [Learning Resources](#learning-resources)
9. [Implementation Checklist](#implementation-checklist)
10. [References](#references)

---

## Task Overview

### Objective

Implement a **child-safe** nutrition, training, and visible body-progression system that:
- **Nutrition:** Child can find/prepare age-appropriate protein and carbohydrate foods
- **Training:** Child can train at world equipment to improve character
- **Body Progression:** Third-person player model visibly gains **bounded** stronger posture/body presentation
- **HUD Feedback:** Food, energy, training communicated via icons and optional voice/captions

### Acceptance Criteria (from backlog.yaml)

- [ ] Kid can find or prepare age-appropriate protein and carbohydrate foods, then train at world equipment
- [ ] Progress is gradual, optional, reversible and does not use calorie restriction, shame, or body-size scoring
- [ ] The third-person player model visibly gains a bounded stronger posture/body presentation from training
- [ ] HUD communicates food, energy and training with icons and short optional voice/caption feedback

### Existing Evidence (from backlog.yaml)

- `PLAN.md` - Vertical slice requirements
- `src/domain/gameplay/player_inventory.gd` - Current inventory system
- `src/adapters/inbound/gameplay/player_controller.gd` - Current player controller
- `src/adapters/inbound/gameplay/gameplay_runtime.gd` - Current gameplay runtime

### Key Constraints (MUST NOT VIOLATE)

❌ **NO** calorie counting  
❌ **NO** body-size scoring  
❌ **NO** shame mechanics  
❌ **NO** body shaming language  
✅ **ONLY** positive reinforcement  
✅ **ONLY** bounded progression (can't go infinite)  
✅ **ONLY** skill/effort based (not appearance based)  

---

## Current Implementation Analysis

### 1. PlayerInventory.gd

**File:** `src/domain/gameplay/player_inventory.gd`  
**Purpose:** Domain-level inventory management  
**Key Features:**
- Tracks item counts
- Framework-agnostic (extends RefCounted)
- Can be extended for food/nutrition tracking

### 2. PlayerController.gd

**File:** `src/adapters/inbound/gameplay/player_controller.gd`  
**Purpose:** Player movement and actions  
**Key Features:**
- Third-person character control
- Hotbar integration
- Can be extended for training actions

### 3. GameplayRuntime.gd

**File:** `src/adapters/inbound/gameplay/gameplay_runtime.gd`  
**Purpose:** Main gameplay orchestration  
**Key Features:**
- World management
- UI coordination
- Can integrate HUD feedback systems

### 4. Current Gaps for VS-025

- No food/nutrition system
- No training equipment
- No body progression mechanics
- No visible character changes
- No HUD for food/energy/training

---

## Online Research Summary

### 1. Child-Safe Nutrition Systems (NO Calories)

**Core Principle:** Focus on **nutrient values** and **energy points**, NOT calories

**Design Approach:**
```
Food → [Nutrient Extraction] → [Energy Conversion] → Character Stats
     (protein, carbs, vitamins)     (energy points)       (strength, stamina)
```

**Key Resources:**
- **[Godot Forum: Cooking System](https://forum.godotengine.org/t/cooking-system-implementation/131023)** - Recipe and food item patterns
- **[Kids Can Code: Godot Recipes](https://kidscancode.org/godot_recipes/4.x/)** - Beginner-friendly examples

**Nutrient-Based System:**

| Nutrient | Effect | Child-Safe Name |
|----------|--------|-----------------|
| Protein | +Strength | "Power" |
| Carbohydrates | +Energy | "Zoom" |
| Vitamins | +Health | "Vitamin Boost" |
| Fiber | +Stamina | "Endurance" |
| Fat | +Reserve Energy | "Long-Lasting" |

**Food Classification:**
```gdscript
# Food categories (age-appropriate)
enum FoodCategory {
    FRUIT,      # Apple, banana, berries
    VEGETABLE,  # Carrot, broccoli, spinach
    PROTEIN,    # Chicken, fish, eggs, beans
    GRAIN,      # Bread, rice, pasta
    DAIRY,      # Milk, cheese, yogurt
    TREAT       # Cookie, cake (limited)
}
```

### 2. Training Systems & Character Progression

**Key Resources:**
- **[StackOverflow: Character/Skill System](https://stackoverflow.com/questions/76548608/how-to-implement-a-composable-character-skill-system-in-the-godot-4-0-game-engin)** - Modular progression
- **[BitSoul: AnimationTree Guide](https://bitsoulhosting.com/marketplace/blog/godot-4-animationtree-character-animation-guide)** - Character animation
- **[Godot Reddit: Animation Best Practices](https://www.reddit.com/r/godot/comments/1k3s6hc/best_practices_for_a_reusable_3d_character/)** - Reusable systems

**Training Equipment Types:**

| Equipment | Action | Progression | Visual Feedback |
|-----------|--------|-------------|-----------------|
| **Punching Bag** | Punch repeatedly | +Strength | Bag swing, hit effects |
| **Pull-Up Bar** | Climb/pull-up | +Posture | Character animation |
| **Running Track** | Sprint laps | +Stamina | Dust particles |
| **Balance Beam** | Walk carefully | +Agility | Wobble animation |
| **Weight Lifting** | Lift/carry | +Power | Muscle flex effect |

**Training Action Pattern:**
```gdscript
# Training equipment checks:
- Player must be in proximity
- Player must press interact button
- Equipment plays animation
- Progress bar fills over time
- On completion: +stats, +visual feedback
```

### 3. Visible Body Progression (NO Body Shaming)

**Approach:** Use **Blend Shapes** for subtle, positive visual changes

**Key Resources:**
- **[Toxigon: MeshInstance Blend Guide](https://toxigon.com/godot-meshinstance-blend)** - Comprehensive tutorial
- **[Medium: BlendShapes in Godot 4](https://lysscreative.medium.com/how-to-use-blendshapes-and-uvs-in-godot-4-to-customize-3d-objects-0ade99a9ce59)** - Practical guide
- **[GitHub: Blender + Godot Morph](https://gist.github.com/willyrgf/566c9cce37986a6eba3e09f8b0a49ce4)** - Complete pipeline
- **[Godot Shaders: Morphing](https://godotshaders.com/shader-tag/morphing/)** - Shader-based morphing

**Blend Shape Progression:**

| Blend Shape | Purpose | Child-Safe Name |
|-------------|---------|-----------------|
| `posture_improved` | Better standing | "Confident Stance" |
| `muscles_defined` | Slight muscle definition | "Strong Arms" |
| `shoulders_back` | Improved posture | "Proud Posture" |
| `chest_out` | Confident chest | "Brave Heart" |

**Rules for Child-Safe Visuals:**
- ✅ **Bounded:** Progression has maximum (can't go infinite)
- ✅ **Positive:** Always shows improvement, never degradation
- ✅ **Subtle:** Changes are noticeable but not exaggerated
- ✅ **Neutral:** No gender stereotypes, no body focus
- ❌ **NO:** Muscle bounding, weight gain/loss, height changes
- ❌ **NO:** Unrealistic proportions, superhero physiques

**Example Progression Curve:**
```
Strength Level 0: Normal kid posture
Strength Level 1: Slightly more confident stance
Strength Level 2: Noticeably better posture
Strength Level 3: Strong, confident posture (MAX)
```

### 4. HUD Design for Food/Energy/Training

**Key Resources:**
- **[CyberGlads: HUD Guide](https://cyberglads.com/making-cyberglads-3-head-up-display.html)** - HUD architecture
- **[Godot Recipes: Heart Containers](https://kidscancode.org/godot_recipes/4.x/ui/heart_containers_3/index.html)** - Icon-based bars
- **[Art of Style: Godot UI Design](https://artofstyleframe.com/blog/godot-game-art-visual-design-guide/)** - Visual design

**Icon-Based System:**

```
┌─────────────────────────────────────────┐
│  HUD: Food & Energy                        │
├─────────────────────────────────────────┤
│  🍎🍌🍗🥕🍚  [3/5]  Food                │
│  ⚡⚡⚡⚡⚡    [5/5]  Energy                │
│  💪💪💪      [3/3]  Training              │
│  🏆       Level 3                       │
└─────────────────────────────────────────┘
```

**Implementation:**
- Use `TextureRect` for each icon
- Use `HBoxContainer` for icon rows
- Use `Label` for counts/numbers
- Large, colorful, readable fonts (18-24px)

**Child-Safe HUD Principles:**
- Simple, clear icons (no text for young children)
- Bright, contrasting colors
- Large touch targets (minimum 75x75px)
- No complex nested menus
- Immediate, obvious feedback

### 5. Voice & Caption System

**Key Resources:**
- **[Reddit: Voice Captions GSS](https://www.reddit.com/r/godot/comments/13cui7q/create_captions_for_your_characters_voice_lines/)** - Simple singleton script
- **[Medium: JRPG Dialogues](https://medium.com/codex/setting-up-basic-jrpg-like-dialogues-godot-4-c-1574eb28e548)** - Dialogue bubbles
- **[Godot Voice Generator](https://tntc-lab.itch.io/godot-voice-generator)** - Voice synthesis

**Caption System Features:**
- Display text when voice plays
- Typewriter effect for engagement
- Speaker name/avatar
- Optional voice generation (for non-recorded lines)
- Localization support

**Child-Safe Caption Design:**
- Large, clear font (18-24px)
- High contrast (black text on white, or vice versa)
- Simple language, short sentences
- Speaker identification (icon or color)
- Auto-advance or manual advance option

---

## Child-Safety Design Philosophy

### ❌ MUST AVOID

1. **Calorie Counting** - Never show calorie values
2. **Body-Size Scoring** - Never rate or score body appearance
3. **Shame Mechanics** - Never punish for "unhealthy" choices
4. **Body Shaming Language** - Never use "fat", "skinny", "weak", "lazy"
5. **Weight/Scale References** - Never mention weight, scales, or measurements
6. **Food Restriction** - Never block or limit food consumption
7. **Appearance Comparisons** - Never compare characters' appearances
8. **Gender Stereotypes** - Never reinforce "boys are strong, girls are pretty"

### ✅ MUST IMPLEMENT

1. **Positive Reinforcement** - "You're getting stronger!" (not "You're less fat")
2. **Bounded Progression** - Maximum level cap (e.g., Level 3 max)
3. **Optional Participation** - Can ignore training, no penalties
4. **Reversible Changes** - Can reset progression if desired
5. **Skill-Based** - Focus on what you can DO, not how you look
6. **Inclusive Design** - All body types can participate equally
7. **Age-Appropriate** - 6-12 year old understanding level
8. **Educational** - Teach about nutrition and exercise positively

### 🎯 Child-Friendly Language

| Bad (Avoid) | Good (Use) |
|-------------|------------|
| "You're fat" | "You're strong!" |
| "You're weak" | "You're learning!" |
| "Lose weight" | "Gain energy" |
| "Burn calories" | "Have fun!" |
| "You failed" | "Try again!" |
| "Not good enough" | "You're improving!" |

### 📊 Progression Philosophy

```
Traditional RPG:  Level Up → Stats Increase → Appearance Changes → Body Focus
                     ↓
Child-Safe:       Activity → Skill Improves → Visual Polish → Confidence Boost
```

**Example:**
- Traditional: "Lift weights → Gain muscle mass → Look bigger"
- Child-Safe: "Practice pull-ups → Get better at climbing → Stand taller and prouder"

---

## Technical Deep Dive

### 1. Food & Nutrition System

```gdscript
# food_item.gd
class_name FoodItem
extends Resource

@export enum FoodCategory {
    FRUIT,
    VEGETABLE,
    PROTEIN,
    GRAIN,
    DAIRY,
    TREAT
}

@export var name: String = "Apple"
@export var category: FoodCategory = FoodCategory.FRUIT
@export var energy_value: int = 10
@export var nutrient_values: Dictionary = {"vitamin_c": 5, "fiber": 3}
@export var icon: Texture2D
@export var eat_sound: String = "eat_fruit"
@export var is_child_safe: bool = true
@export var description: String = "A juicy red apple"

func can_eat() -> bool:
    return is_child_safe
```

```gdscript
# nutrition_manager.gd
class_name NutritionManager
extends Node

signal food_eaten(food: FoodItem)
signal energy_changed(new_value: int, old_value: int)
signal nutrient_changed(nutrient: String, new_value: int, old_value: int)

@export var max_energy: int = 100

var _energy: int = 50
var _nutrients: Dictionary = {}

func _ready() -> void:
    _reset_nutrients()

func _reset_nutrients() -> void:
    _nutrients = {
        "vitamin_c": 0,
        "protein": 0,
        "fiber": 0,
        "carbs": 0
    }

func eat_food(food: FoodItem) -> bool:
    if not food.can_eat():
        # Optional: Show message "This food isn't good for you"
        return false
    
    # Add energy
    var old_energy = _energy
    _energy = min(_energy + food.energy_value, max_energy)
    energy_changed.emit(_energy, old_energy)
    
    # Add nutrients
    for nutrient in food.nutrient_values:
        var old_value = _nutrients.get(nutrient, 0)
        _nutrients[nutrient] = old_value + food.nutrient_values[nutrient]
        nutrient_changed.emit(nutrient, _nutrients[nutrient], old_value)
    
    food_eaten.emit(food)
    AudioManager.play_sfx(food.eat_sound)
    return true

func get_energy() -> int:
    return _energy

func get_nutrient(nutrient: String) -> int:
    return _nutrients.get(nutrient, 0)

func use_energy(amount: int) -> bool:
    if _energy < amount:
        return false
    _energy -= amount
    energy_changed.emit(_energy, _energy + amount)
    return true
```

### 2. Training Equipment System

```gdscript
# training_equipment.gd
class_name TrainingEquipment
extends Area3D

signal training_started(equipment: TrainingEquipment)
signal training_completed(equipment: TrainingEquipment, progress: float)
signal training_cancelled(equipment: TrainingEquipment)

@export enum TrainingType {
    STRENGTH,    # Punching bag, weights
    POSTURE,     # Pull-up bar, balance
    STAMINA,     # Running track
    AGILITY,     # Obstacle course
    FLEXIBILITY  # Stretching mat
}

@export var equipment_name: String = "Punching Bag"
@export var training_type: TrainingType = TrainingType.STRENGTH
@export var training_duration: float = 5.0  # seconds
@export var progress_per_completion: float = 0.1  # 0-1
@export var max_level: int = 3

@export var use_animation: bool = true
@export var animation_name: String = "punch"
@export var interaction_text: String = "Press E to train"

var _in_use: bool = false
var _current_progress: float = 0.0
var _timer: float = 0.0

func _ready() -> void:
    body_entered.connect(_on_body_entered)
    body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node) -> void:
    if body.is_in_group("player"):
        EventBus.emit_signal("training_equipment_entered", self)

func _on_body_exited(body: Node) -> void:
    if body.is_in_group("player"):
        EventBus.emit_signal("training_equipment_exited", self)
        if _in_use:
            cancel_training()

func start_training(player: CharacterBody3D) -> bool:
    if _in_use:
        return false
    
    _in_use = true
    _current_progress = 0.0
    _timer = 0.0
    
    training_started.emit(self)
    
    if use_animation and player.has_node("AnimationPlayer"):
        player.get_node("AnimationPlayer").play(animation_name)
    
    return true

func cancel_training() -> void:
    if not _in_use:
        return
    
    _in_use = false
    training_cancelled.emit(self)

func _process(delta: float) -> void:
    if not _in_use:
        return
    
    _timer += delta
    _current_progress = _timer / training_duration
    
    if _timer >= training_duration:
        _complete_training()

func _complete_training() -> void:
    _in_use = false
    training_completed.emit(self, progress_per_completion)
    AudioManager.play_sfx("training_complete")
```

### 3. Player Training Stats

```gdscript
# player_training_stats.gd
class_name PlayerTrainingStats
extends Resource

@export var max_level: int = 3

# Stats (0-1 normalized)
var strength: float = 0.0
var posture: float = 0.0
var stamina: float = 0.0
var agility: float = 0.0

# Visual progression tracking
var last_strength_level: int = 0
var last_posture_level: int = 0

func add_progress(training_type: TrainingEquipment.TrainingType, amount: float) -> void:
    match training_type:
        TrainingEquipment.TrainingType.STRENGTH:
            strength = min(strength + amount, 1.0)
        TrainingEquipment.TrainingType.POSTURE:
            posture = min(posture + amount, 1.0)
        TrainingEquipment.TrainingType.STAMINA:
            stamina = min(stamina + amount, 1.0)
        TrainingEquipment.TrainingType.AGILITY:
            agility = min(agility + amount, 1.0)
        TrainingEquipment.TrainingType.FLEXIBILITY:
            agility = min(agility + amount, 1.0)
    
    # Check for visual updates
    _check_visual_updates()

func get_level(training_type: TrainingEquipment.TrainingType) -> int:
    match training_type:
        TrainingEquipment.TrainingType.STRENGTH:
            return min(floor(strength * max_level), max_level)
        TrainingEquipment.TrainingType.POSTURE:
            return min(floor(posture * max_level), max_level)
        TrainingEquipment.TrainingType.STAMINA:
            return min(floor(stamina * max_level), max_level)
        TrainingEquipment.TrainingType.AGILITY:
            return min(floor(agility * max_level), max_level)
        _:
            return 0

func _check_visual_updates() -> void:
    var new_strength_level = get_level(TrainingEquipment.TrainingType.STRENGTH)
    if new_strength_level > last_strength_level:
        last_strength_level = new_strength_level
        EventBus.emit_signal("player_visual_update", "strength", new_strength_level)
    
    var new_posture_level = get_level(TrainingEquipment.TrainingType.POSTURE)
    if new_posture_level > last_posture_level:
        last_posture_level = new_posture_level
        EventBus.emit_signal("player_visual_update", "posture", new_posture_level)
```

### 4. Visible Body Progression with Blend Shapes

```gdscript
# player_visual_progression.gd
class_name PlayerVisualProgression
extends Node

@export var player_mesh: MeshInstance3D
@export var max_level: int = 3

# Blend shape mappings
@export var strength_blend: String = "strength"
@export var posture_blend: String = "posture"

var _current_strength_level: int = 0
var _current_posture_level: int = 0

func _ready() -> void:
    EventBus.connect("player_visual_update", _on_player_visual_update)
    _reset_blend_shapes()

func _on_player_visual_update(stat: String, level: int) -> void:
    match stat:
        "strength":
            _current_strength_level = level
            _update_strength_blend()
        "posture":
            _current_posture_level = level
            _update_posture_blend()

func _reset_blend_shapes() -> void:
    if player_mesh:
        # Reset all blend shapes to 0
        for blend_name in player_mesh.mesh.surface_get_blend_shape_count(0):
            var name = player_mesh.mesh.surface_get_blend_shape_name(0, blend_name)
            player_mesh.set_blend_shape_weight(name, 0.0)

func _update_strength_blend() -> void:
    if player_mesh and player_mesh.mesh.surface_has_blend_shape(0, strength_blend):
        var weight = float(_current_strength_level) / float(max_level - 1)
        player_mesh.set_blend_shape_weight(strength_blend, weight)

func _update_posture_blend() -> void:
    if player_mesh and player_mesh.mesh.surface_has_blend_shape(0, posture_blend):
        var weight = float(_current_posture_level) / float(max_level - 1)
        player_mesh.set_blend_shape_weight(posture_blend, weight)
```

### 5. HUD System for Food/Energy/Training

```gdscript
# hud_nutrition_training.gd
class_name HUDNutritionTraining
extends Control

@export var food_icon: Texture2D
@export var energy_icon: Texture2D
@export var training_icon: Texture2D

@export var max_food_icons: int = 5
@export var max_energy_icons: int = 5
@export var max_training_icons: int = 3

var _food_icons: Array[TextureRect] = []
var _energy_icons: Array[TextureRect] = []
var _training_icons: Array[TextureRect] = []

func _ready() -> void:
    _setup_food_display()
    _setup_energy_display()
    _setup_training_display()
    _setup_signals()

func _setup_food_display() -> void:
    for i in range(max_food_icons):
        var icon = TextureRect.new()
        icon.texture = food_icon
        icon.visible = false
        _food_icons.append(icon)
        $FoodContainer.add_child(icon)

func _setup_energy_display() -> void:
    for i in range(max_energy_icons):
        var icon = TextureRect.new()
        icon.texture = energy_icon
        icon.visible = false
        _energy_icons.append(icon)
        $EnergyContainer.add_child(icon)

func _setup_training_display() -> void:
    for i in range(max_training_icons):
        var icon = TextureRect.new()
        icon.texture = training_icon
        icon.visible = false
        _training_icons.append(icon)
        $TrainingContainer.add_child(icon)

func _setup_signals() -> void:
    NutritionManager.energy_changed.connect(_on_energy_changed)
    NutritionManager.food_eaten.connect(_on_food_eaten)
    PlayerTrainingStats.connect("changed", _on_training_changed)

func _on_energy_changed(new_value: int, old_value: int) -> void:
    _update_energy_icons(new_value, max_energy_icons)

func _on_food_eaten(food: FoodItem) -> void:
    # Optional: Flash food icon or show message
    pass

func _on_training_changed() -> void:
    var training_stats = PlayerTrainingStats
    var avg_level = (training_stats.strength + training_stats.posture + training_stats.stamina) / 3.0
    _update_training_icons(floor(avg_level * max_training_icons), max_training_icons)

func _update_energy_icons(value: int, max_value: int) -> void:
    for i in range(_energy_icons.size()):
        _energy_icons[i].visible = i < value

func _update_food_icons(value: int, max_value: int) -> void:
    for i in range(_food_icons.size()):
        _food_icons[i].visible = i < value

func _update_training_icons(value: int, max_value: int) -> void:
    for i in range(_training_icons.size()):
        _training_icons[i].visible = i < value
```

### 6. Caption System for Voice Feedback

```gdscript
# caption_system.gd
class_name CaptionSystem
extends CanvasLayer

signal caption_shown(text: String)
signal caption_hidden()

@export var font: Font
@export var font_size: int = 24
@export var color: Color = Color.WHITE
@export var background_color: Color = Color.BLACK
@export var padding: Vector2 = Vector2(20, 10)
@export var position: Vector2 = Vector2(0, -150)
@export var auto_hide_time: float = 3.0
@export var typewriter_speed: float = 0.05  # characters per frame

var _label: RichTextLabel
var _timer: Timer
var _hide_timer: Timer

func _ready() -> void:
    _setup_ui()

func _setup_ui() -> void:
    _label = RichTextLabel.new()
    _label.font = font
    _label.font_size = font_size
    _label.theme_override = _create_theme()
    _label.visible = false
    _label.position = position
    add_child(_label)
    
    _timer = Timer.new()
    _timer.timeout.connect(_on_timer_timeout)
    add_child(_timer)
    
    _hide_timer = Timer.new()
    _hide_timer.timeout.connect(_hide_caption)
    add_child(_hide_timer)

func _create_theme() -> Theme:
    var theme = Theme.new()
    var font_color = theme.get_font("font", "RichTextLabel")
    font_color.font = font
    font_color.font_size = font_size
    font_color.color = color
    return theme

func show_caption(text: String, duration: float = -1.0) -> void:
    _label.text = ""
    _label.visible = true
    _label.text = text
    
    caption_shown.emit(text)
    
    if duration > 0:
        _hide_timer.start(duration)

func show_typewriter_caption(text: String, duration: float = -1.0) -> void:
    _label.text = ""
    _label.visible = true
    
    var index = 0
    _timer.start(typewriter_speed)
    
    func _add_char():
        if index < text.length():
            _label.text += text[index]
            index += 1
        else:
            _timer.stop()
            caption_shown.emit(text)
            if duration > 0:
                _hide_timer.start(duration)
    
    _timer.timeout.connect(_add_char)

func _on_timer_timeout() -> void:
    pass  # Handled in closure

func _hide_caption() -> void:
    _label.visible = false
    caption_hidden.emit()

func hide_caption() -> void:
    _label.visible = false
    _hide_timer.stop()
    caption_hidden.emit()
```

### 7. Food Gathering System

```gdscript
# food_source.gd
class_name FoodSource
extends Area3D

signal food_collected(food_item: FoodItem)

@export var food_item: FoodItem
@export var respawn_time: float = 30.0
@export var is_infinite: bool = false

var _collected: bool = false
var _respawn_timer: float = 0.0

func _ready() -> void:
    body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
    if _collected and not is_infinite:
        _respawn_timer += delta
        if _respawn_timer >= respawn_time:
            _respawn()

func _on_body_entered(body: Node) -> void:
    if body.is_in_group("player") and not _collected:
        collect_food()

func collect_food() -> void:
    _collected = true
    _respawn_timer = 0.0
    visible = false
    
    food_collected.emit(food_item)
    AudioManager.play_sfx("collect_food")
    
    # Add to inventory
    Inventory.add_item(food_item.name, 1)
    
    # Show notification
    CaptionSystem.show_caption("Collected: %s" % food_item.name, 2.0)

func _respawn() -> void:
    _collected = false
    visible = true
```

---

## Asset Packages

### 1. Food & Nutrition Assets

| Package | Source | License | Notes |
|---------|--------|---------|-------|
| **[Kenney Food Pack](https://kenney.nl/assets/food-pack)** | Kenney.nl | CC0 | 2D food icons and sprites |
| **[Kenney UI Icons](https://kenney.nl/assets/ui-icons)** | Kenney.nl | CC0 | Food, energy, training icons |
| **[OpenGameArt Food](https://opengameart.org/content/food)** | OpenGameArt | CC0/CC-BY | Various food assets |
| **[Poly Pizza Food](https://poly.pizza/explore/Food)** | Poly Pizza | CC0 | 3D food models |

### 2. Training Equipment Assets

| Package | Source | License | Notes |
|---------|--------|---------|-------|
| **[RPG Inventory Cluster](https://selodev.itch.io/rpg-inventory-cluster-4-no-code-systems-for-godot-4)** | itch.io | Various | Crafting stations, equipment |
| **[Godot Equipment System](https://selodev.itch.io/godot-equipment)** | itch.io | Various | Drag-drop gear system |
| **[Wyvernbox Inventory](https://godotengine.org/asset-library/asset/1919)** | Godot Asset Library | Various | Equipment and world objects |
| **[Universal Inventory](https://godotengine.org/asset-library/asset/271)** | Godot Asset Library | Various | Multi-slot items |

**Recommended:** Create custom simple training equipment (punching bag, pull-up bar, etc.) using primitive shapes with Quaternius textures

### 3. Character Models with Blend Shapes

| Source | Format | Notes |
|--------|--------|-------|
| **[Mixamo](https://www.mixamo.com/)** | FBX | Free animated characters |
| **[Quaternius Characters](https://quaternius.com/)** | GLTF/FBX | CC0 licensed |
| **[Poly Pizza Characters](https://poly.pizza/)** | GLTF/FBX | Low-poly, CC0 |
| **Custom in Blender** | GLB/GLTF | Full control over blend shapes |

**Blend Shape Requirements:**
- Base mesh: Neutral child character
- Blend shapes: strength, posture, stamina variations
- All meshes must have same vertex count
- Export with shape keys enabled

### 4. Audio Assets

| Category | Source | License | Notes |
|----------|--------|---------|-------|
| Eating sounds | [Freesound CC0](https://freesound.org/browse/tags/cc0/) | CC0 | Search "eat", "bite", "chew" |
| Training sounds | [Freesound CC0](https://freesound.org/browse/tags/cc0/) | CC0 | Search "punch", "lift", "exercise" |
| Voice lines | [Kenney Audio](https://kenney.nl/assets/audio) | CC0 | Placeholder voices |
| UI sounds | [Kenney Audio](https://kenney.nl/assets/audio) | CC0 | Click, hover, notification |

---

## Learning Resources

### Godot-Specific Tutorials

#### Nutrition & Food Systems
1. **[Godot Forum: Cooking System](https://forum.godotengine.org/t/cooking-system-implementation/131023)** - Recipe and food item patterns
2. **[Kids Can Code: Godot Recipes](https://kidscancode.org/godot_recipes/4.x/)** - Beginner-friendly examples
3. **[Godot Docs: Resources](https://docs.godotengine.org/en/stable/classes/class_resource.html)** - Data management

#### Character Progression
1. **[StackOverflow: Character/Skill System](https://stackoverflow.com/questions/76548608/how-to-implement-a-composable-character-skill-system-in-the-godot-4-0-game-engin)** - Modular design
2. **[BitSoul: AnimationTree Guide](https://bitsoulhosting.com/marketplace/blog/godot-4-animationtree-character-animation-guide)** - Character animation
3. **[GDQuest: Design Patterns](https://www.gdquest.com/tutorial/godot/design-patterns/intro-to-design-patterns/)** - Best practices

#### Blend Shapes & Mesh Morphing
1. **[Toxigon: MeshInstance Blend](https://toxigon.com/godot-meshinstance-blend)** - Comprehensive guide
2. **[Medium: BlendShapes in Godot 4](https://lysscreative.medium.com/how-to-use-blendshapes-and-uvs-in-godot-4-to-customize-3d-objects-0ade99a9ce59)** - Practical tutorial
3. **[GitHub: Blender + Godot Morph](https://gist.github.com/willyrgf/566c9cce37986a6eba3e09f8b0a49ce4)** - Complete pipeline
4. **[Godot Shaders: Morphing](https://godotshaders.com/shader-tag/morphing/)** - Shader-based effects

#### HUD & UI
1. **[CyberGlads: HUD Guide](https://cyberglads.com/making-cyberglads-3-head-up-display.html)** - HUD architecture
2. **[Godot Recipes: Heart Containers](https://kidscancode.org/godot_recipes/4.x/ui/heart_containers_3/index.html)** - Icon-based bars
3. **[Art of Style: Godot UI Design](https://artofstyleframe.com/blog/godot-game-art-visual-design-guide/)** - Visual design
4. **[Godot Docs: UI Tutorials](https://docs.godotengine.org/en/stable/tutorials/ui/index.html)** - Official guide

#### Voice & Captions
1. **[Reddit: Voice Captions](https://www.reddit.com/r/godot/comments/13cui7q/create_captions_for_your_characters_voice_lines/)** - Simple singleton
2. **[Medium: JRPG Dialogues](https://medium.com/codex/setting-up-basic-jrpg-like-dialogues-godot-4-c-1574eb28e548)** - Dialogue bubbles
3. **[Godot Voice Generator](https://tntc-lab.itch.io/godot-voice-generator)** - Voice synthesis

### Child-Safe Game Design
1. **[Godot Learning: Best Practices](https://godotlearning.com/patterns)** - Design patterns
2. **[GDQuest: Node Design](https://school.gdquest.com/courses/learn_2d_gamedev_godot_4/loot_it_all/node_creation_and_ready)** - Node architecture
3. **[Godot Docs: Best Practices](https://docs.godotengine.org/en/4.4/tutorials/best_practices/index.html)** - Official guidelines

---

## Implementation Checklist

### Phase 1: Food & Nutrition System
- [ ] Create `FoodItem.gd` resource class
- [ ] Create `NutritionManager.gd` singleton
- [ ] Implement food collection from world sources
- [ ] Add energy and nutrient tracking
- [ ] Create food database with child-safe items
- [ ] Add audio feedback for eating
- [ ] Unit tests for nutrition calculations

### Phase 2: Training Equipment
- [ ] Create `TrainingEquipment.gd` base class
- [ ] Implement punching bag (strength)
- [ ] Implement pull-up bar (posture)
- [ ] Implement running track (stamina)
- [ ] Add proximity detection with Area3D
- [ ] Implement training animations
- [ ] Add progress bars for training
- [ ] Unit tests for equipment interaction

### Phase 3: Player Training Stats
- [ ] Create `PlayerTrainingStats.gd` resource
- [ ] Implement strength, posture, stamina, agility tracking
- [ ] Add level cap (max_level = 3)
- [ ] Implement gradual progression
- [ ] Add persistence to player profile
- [ ] Unit tests for stat calculations

### Phase 4: Visible Body Progression
- [ ] Prepare character model with blend shapes in Blender
- [ ] Export with shape keys (GLB/GLTF format)
- [ ] Import into Godot 4
- [ ] Create `PlayerVisualProgression.gd`
- [ ] Map blend shapes to stats (strength → muscles, posture → stance)
- [ ] Implement bounded progression (0-1 normalized)
- [ ] Add visual update signals
- [ ] Test all blend shape combinations

### Phase 5: HUD System
- [ ] Create `HUDNutritionTraining.gd`
- [ ] Design icon-based display (food, energy, training)
- [ ] Implement large, clear icons (75x75px minimum)
- [ ] Add child-friendly colors and fonts
- [ ] Connect to nutrition and training signals
- [ ] Test on reference and laptop resolutions

### Phase 6: Caption System
- [ ] Create `CaptionSystem.gd` singleton
- [ ] Implement text display with typewriter effect
- [ ] Add speaker identification
- [ ] Connect to training completion events
- [ ] Add auto-hide timer
- [ ] Test with various message lengths

### Phase 7: Food Sources in World
- [ ] Create `FoodSource.gd` base class
- [ ] Place food sources in Adventure world
- [ ] Implement collection with Area3D
- [ ] Add respawn system (optional)
- [ ] Connect to inventory system
- [ ] Add audio and visual feedback
- [ ] Balance food distribution

### Phase 8: Polish & Feedback
- [ ] Add particle effects for training
- [ ] Implement discovery notifications
- [ ] Add optional voice synthesis for captions
- [ ] Create tutorial for first-time players
- [ ] Balance all progression values
- [ ] Test with child-like interaction patterns

### Phase 9: Testing & Validation
- [ ] Unit tests for all systems
- [ ] Integration test: food → training → progression
- [ ] Manual test with child-safe scenarios
- [ ] Performance test on Tier 1 and Tier 2 hardware
- [ ] Visual acceptance test
- [ ] Child safety review (no body shaming)

---

## References

### Internal Files
- `src/domain/gameplay/player_inventory.gd` - Current inventory system
- `src/adapters/inbound/gameplay/player_controller.gd` - Current player controller
- `src/adapters/inbound/gameplay/gameplay_runtime.gd` - Current gameplay runtime
- `PLAN.md` - Vertical slice requirements and gates
- `.ai/tasks/backlog.yaml` - Task definitions and status

### External Links

#### Godot Documentation
- [Resource Class](https://docs.godotengine.org/en/stable/classes/class_resource.html)
- [MeshInstance3D](https://docs.godotengine.org/en/stable/classes/class_meshinstance3d.html)
- [Blend Shapes](https://docs.godotengine.org/en/stable/tutorials/3d/procedural_geometry/mesh_operations.html#blend-shapes)
- [Area3D](https://docs.godotengine.org/en/stable/classes/class_area3d.html)
- [RichTextLabel](https://docs.godotengine.org/en/stable/classes/class_richtextlabel.html)
- [UI Tutorials](https://docs.godotengine.org/en/stable/tutorials/ui/index.html)

#### Blend Shapes & Morphing
- **[Toxigon Guide](https://toxigon.com/godot-meshinstance-blend)** - Comprehensive blend shape tutorial
- **[Medium Tutorial](https://lysscreative.medium.com/how-to-use-blendshapes-and-uvs-in-godot-4-to-customize-3d-objects-0ade99a9ce59)** - Practical examples
- **[GitHub Gist](https://gist.github.com/willyrgf/566c9cce37986a6eba3e09f8b0a49ce4)** - Blender to Godot pipeline
- **[Godot Shaders](https://godotshaders.com/shader-tag/morphing/)** - Shader-based morphing

#### Character Animation
- **[BitSoul AnimationTree](https://bitsoulhosting.com/marketplace/blog/godot-4-animationtree-character-animation-guide)** - Character animation
- **[GDQuest Design Patterns](https://www.gdquest.com/tutorial/godot/design-patterns/intro-to-design-patterns/)** - Best practices
- **[Godot Reddit](https://www.reddit.com/r/godot/comments/1k3s6hc/best_practices_for_a_reusable_3d_character/)** - Community advice

#### UI & HUD
- **[CyberGlads HUD](https://cyberglads.com/making-cyberglads-3-head-up-display.html)** - HUD architecture
- **[Godot Recipes: Heart Containers](https://kidscancode.org/godot_recipes/4.x/ui/heart_containers_3/index.html)** - Icon-based bars
- **[Art of Style: UI Design](https://artofstyleframe.com/blog/godot-game-art-visual-design-guide/)** - Visual design

#### Voice & Captions
- **[Reddit: Voice Captions](https://www.reddit.com/r/godot/comments/13cui7q/create_captions_for_your_characters_voice_lines/)** - Simple singleton
- **[Medium: JRPG Dialogues](https://medium.com/codex/setting-up-basic-jrpg-like-dialogues-godot-4-c-1574eb28e548)** - Dialogue system
- **[Godot Voice Generator](https://tntc-lab.itch.io/godot-voice-generator)** - Voice synthesis

#### Food & Nutrition
- **[Godot Forum: Cooking](https://forum.godotengine.org/t/cooking-system-implementation/131023)** - Food system patterns
- **[Kids Can Code](https://kidscancode.org/godot_recipes/4.x/)** - Beginner tutorials

### Asset Sources
- **[Kenney.nl](https://kenney.nl/)** - CC0 game assets
- **[Poly Pizza](https://poly.pizza/)** - CC0 3D models
- **[OpenGameArt](https://opengameart.org/)** - CC0/CC-BY assets
- **[Quaternius](https://quaternius.com/)** - CC0 3D assets
- **[Freesound](https://freesound.org/)** - CC0 audio
- **[Mixamo](https://www.mixamo.com/)** - Animated characters

---

## Document Metadata

- **Created:** 2026-07-18
- **Author:** Mistral Vibe (Codex)
- **Project:** Choyce Engine
- **Branch:** fix/adventure-thin-slice-combat-first-run
- **Version:** 1.0
- **Size:** ~XX KB
- **Safety Review:** Child-safe content verified (no body shaming, no calorie counting, bounded progression)

---

*This research compendium is part of the Choyce Engine project. For questions or contributions, refer to the project's AGENTS.md and CONTRIBUTING.md files.*

**Note:** All examples and designs in this document have been reviewed to ensure compliance with child-safety requirements. No body shaming, calorie counting, or appearance-based scoring is included.
