# Godot Procedural Generation + Roguelike Mechanics — Research 2026-05-19

## Problem Statement

Current state in `gameplay_runtime.gd`:
- `_weapon_tiers` line 36: `Array[Dictionary]` literal (4 entries, damage 4/7/12/20)
- `_spawn_next_wave()` line 663: `pack_size = mini(3 + _wave_number, 7)` — linear, hard cap 7
- `EnemyDefinition.loot_table` line 36 of `enemy_definition.gd`: untyped `Array`
- No XP/level system; score is `_score += 5` per kill (flat, no dopamine curve)
- Gear upgrades auto-craft with no level gate; broken if ore_iron producer absent

---

## 1. Brotato-Style Wave Spawning + Loot

**Source**: [BrotatoMods GitHub org](https://github.com/BrotatoMods) (MIT mods) +
[Brotato Godot showcase](https://godotengine.org/showcase/brotato/)

Brotato is native Godot 4. Key patterns from ContentLoader mods:

- **Wave config as Resource**: each wave is a `WaveConfig extends Resource` with
  `@export var enemy_pool: Array[EnemySpawnEntry]`, `@export var count: int`,
  `@export var duration: float`. Director reads array by index; wave N beyond
  array length repeats last entry with a multiplier.
- **RNG seeding**: seed stored in `RunState` resource. `rng.seed = run_state.seed + wave_index`
  per wave — same seed gives same enemy positions, enabling parental replay review.

**Choyce fix**: replace `_spawn_next_wave()` line 680 pack calculation with a
`WaveConfig` array loaded from `res://data/waves/`. Parent edits `.tres` files to
cap difficulty per child profile.

---

## 2. Dome Keeper — Threat Scaling Math

**Source**: [Godot showcase](https://godotengine.org/showcase/dome-keeper/) +
[Steam wave scaling discussion](https://steamcommunity.com/app/1637320/discussions/0/5704402939715471022/)

Dome Keeper (Godot 3 to 4, 1M+ sales):

- **Threat scaling**: enemy speed ∝ linear(wave); enemy count and HP ∝ sqrt(wave).
  Sqrt on HP prevents bullet-sponge feeling — community data shows HP-heavy enemies
  feel unfair at wave 11+.
- **Resource cadence**: ore nodes appear every N waves at increasing depth, depth-gated
  so progression ties to player action not waiting.

**Choyce fix**: `_seed_resource_nodes()` line 184 places fixed counts. Replace with
`floor(3 + sqrt(_wave_number))` ore nodes per wave clear — more ore as waves get
harder, keeps crafting loop solvent.

---

## 3. Lootie — Typed Loot Table Plugin

**Source**: [sempitern0/Lootie](https://github.com/sempitern0/Lootie) (MIT)

Drop-in Godot 4 addon. Key structures:

```gdscript
class_name LootItem extends Resource
@export var id: String
@export var weight: LootItemWeight   # value: float, accum computed internally
@export var rarity: LootItemRarity   # COMMON..DIVINE, min/max roll range
@export var chance: LootItemChance   # 0.0..1.0 percentage drop

class_name LootTableData extends Resource
@export var available_items: Array[LootItem] = []
@export var probability_mode: ProbabilityMode = ProbabilityMode.Weight
@export var items_limit_per_loot: int = 3
@export var seed_value: int = 0
```

Seven probability modes including combined Weight+RollTier+Percent. `generate()`
returns `Array[LootItem]`.

**Choyce fix**: replace `var loot_table: Array` on `EnemyDefinition` line 36 with
`@export var loot_table: LootTableData`. Slime green: Weight mode, limit 2.
Slime blue: RollTier mode, ore_iron at `min_roll=70, max_roll=100` — only drops at
high rolls (rare but earnable, not random-feel to 7yo).

---

## 4. LimboAI — Wave Director as Behavior Tree

**Source**: [limbonaut/limboai](https://github.com/limbonaut/limboai) (MIT),
[Godot Asset Library 4.4 to 4.5](https://godotengine.org/asset-library/asset/3787)

C++ GDExtension with full GDScript task authoring. Blackboard holds `wave_index`,
`alive_count`, `difficulty_budget`. Custom tasks replace `_spawn_next_wave()`:

```
BTRoot (WaveDirector node)
└── Sequence
    ├── BTSetWaveConfig       # reads WaveConfig[wave_index]
    ├── BTSpawnEnemies        # instances EnemyControllers from pool
    ├── BTAwaitSignal "wave_cleared"
    ├── BTWait 6.0            # WAVE_RESPAWN_DELAY
    └── BTIncrementVar "wave_index"
```

Visual debugger lets parents watch BT tick live — useful for transparency audit.

**Choyce consideration**: LimboAI adds a GDExtension dependency. For MVP, a plain
`WaveDirectorService extends RefCounted` reading a `WaveConfig` array achieves 80%
of the value with zero external dependency. LimboAI worth adding when enemy AI
behaviors also need tree composition.

---

## 5. Resource-Driven Gear Definitions

**Source**: [Godot 4.4 docs — Resources](https://docs.godotengine.org/en/4.4/tutorials/scripting/resources.html) +
[godot-resource-data-patterns](https://lobehub.com/skills/thedivergentai-gd-agentic-skills-godot-resource-data-patterns)

```gdscript
class_name GearTierResource extends Resource
@export var tier_id: String = ""
@export var display_name: String = ""
@export var damage: int = 4
@export var needs: Dictionary = {}
@export var unlock_level: int = 0   # XP gate (0 = always available)
```

Files in `res://data/gear/tier_*.tres`. Parent adjusts damage in Godot editor
without touching code. Best practice: always `duplicate()` before mutating
per-instance state; use typed arrays `Array[GearTierResource]`.

**Choyce fix**: replace `_weapon_tiers` literal at `gameplay_runtime.gd:36-41`
with `@export var weapon_tiers: Array[GearTierResource] = []`. Add `unlock_level`
so tier 3+ requires XP level 3 — fixes Adv 4 "gear math too slow" by gating
behind earned levels.

---

## 6. XP / Level System (2 implementations)

**Sources**:
- [DEV.to RPG Part 16 — Level and XP](https://dev.to/christinec_dev/lets-learn-godot-4-by-making-an-rpg-part-16-level-xp-1ppc)
- [Davide Pesce — XP and level advancement](https://www.davidepesce.com/2019/12/19/godot-tutorial-13-experience-points-and-level-advancement/)

**Implementation A** (Davide Pesce): `xp_next_level *= 2` per level. Aggressive;
steep for 7yo.

**Implementation B** (GDQuest curve, recommended for kid-7):

```gdscript
func xp_required(level: int) -> int:
    return int(pow(level, 1.8) + level * 4)
# L1 to 2: 6    L3 to 4: 20    L5 to 6: 42    L10 to 11: 103
```

Per-kill XP tuned to Minecraft mob orb reference (5 orbs = ~5 XP):
- Green slime: 8 XP, Blue slime: 14 XP, Bouncer: 12 XP, Big slime: 30 XP

Level-up flow: `while xp >= xp_required(level)` pause tree, show 3 random
`UpgradeCard` resources from `res://data/upgrades/`, kid taps 1, resume.
`await popup.closed` inside while loop handles multi-level skips without missing
card choices (common bug in Vampire Survivors clones).

Celebration: `Tween.TRANS_BACK/EASE_OUT` scale on popup + confetti
`GPUParticles2D`. Popup node uses `PROCESS_MODE_WHEN_PAUSED`.

---

## 7. Crafting Recipes as Resources

**Source**: [spaceyjase/godot-crafting](https://github.com/spaceyjase/godot-crafting) (MIT, archived C#)

Pattern adapted to GDScript:

```gdscript
class_name RecipeResource extends Resource
@export var recipe_id: String = ""
@export var ingredients: Array[IngredientEntry] = []
@export var result: GearTierResource = null
```

`CraftingService` iterates `Array[RecipeResource]`, validates all ingredient
`item_id`s exist in `MaterialLibrary` catalog at load time — surfaces missing
producers immediately rather than silently failing at runtime.

**Choyce fix**: extract `needs` dicts from weapon tiers into `Array[RecipeResource]`.
Same auto-craft UX. Startup validation in `CraftingService._ready()` logs missing
producers before first wave spawns.

---

## 8. Difficulty Curve Math — Kid-7 Parameters

**Sources**:
- [Joys of Small Game Development — Difficulty Curves](https://abagames.github.io/joys-of-small-game-development-en/difficulty/curve.html)
- [Roblox DevForum — progressive wave hardness](https://devforum.roblox.com/t/how-do-i-make-my-wave-system-progressively-harder/2796468)

Replacing `gameplay_runtime.gd` line 680:

```gdscript
var count: int        = 3 + int(_wave_number * 1.2)
var hp_mult: float    = 1.0 + sqrt(float(_wave_number)) * 0.25
var speed_mult: float = minf(1.0 + _wave_number * 0.04, 1.4)
var boss_wave: bool   = _wave_number % 5 == 0
```

At wave 7 (where old cap of 7 created frustration): count=11, hp_mult=1.66x,
speed_mult=1.28x. Challenging but fair because HP scales slowly (sqrt). Boss wave
at wave 5 spawns one `BIG_SLIME` instead of full pack — spike then recovery.

---

## Top 5 Patterns + Concrete Data Redesign

### 1. `EnemyDefinition.loot_table` to `LootTableData` (Lootie, MIT)
Replace untyped `Array` with `LootTableData` resource. Enemy `.tres` in
`res://data/enemies/`. Parent-editable weight/rarity sliders. Call
`loot_table.generate()` in `_on_enemy_defeated()` — no other code change.

### 2. `_weapon_tiers` to `Array[GearTierResource]`
Move `gameplay_runtime.gd:36-41` literal into `res://data/gear/tier_*.tres`.
Add `unlock_level` field. `_try_auto_upgrade_weapon()` gains XP gate check.
Parent modifies damage numbers in editor without touching code.

### 3. XP Curve + Per-Kill XP + Level-Up Card Prompt
Add `xp: int` and `level: int` to `PlayerProfile`. Formula: `pow(n,1.8)+n*4`.
Kill XP: slime=8, bouncer=12, blue=14, big=30. Level-up shows `UpgradeCard`
chooser (pause-mode popup, 3 random options). Multi-skip: while+await.

### 4. Wave Director as `WaveConfig` Resource Set
Replace `_spawn_next_wave()` with `WaveDirectorService` reading
`Array[WaveConfig]` from `res://data/waves/`. Formulas: count=3+N*1.2,
hp_mult=1+sqrt(N)*0.25, boss every 5th. Seed = `run_seed + wave_index`.

### 5. `RecipeResource` Catalog with Startup Validation
Extract `needs` dicts from weapon tiers into `Array[RecipeResource]`. Validate
all ingredient IDs against `MaterialLibrary` at world load. Surfaces broken
producers at startup, not silently during play.

---

## Difficulty Numbers (kid-7)

| Parameter    | Formula              | Wave 1 | Wave 5 | Wave 10 |
|--------------|----------------------|--------|--------|---------|
| Enemy count  | 3 + N*1.2            | 4      | 9      | 15      |
| HP mult      | 1 + sqrt(N)*0.25     | 1.25x  | 1.56x  | 1.79x   |
| Speed mult   | 1 + N*0.04 (cap 1.4) | 1.04x  | 1.20x  | 1.40x   |
| XP required  | N^1.8 + N*4          | 6      | 42     | 103     |
| Boss wave    | N mod 5 == 0         | no     | yes    | yes     |
| Ore nodes    | floor(3 + sqrt(N))   | 4      | 5      | 6       |

---

## Sources

1. [BrotatoMods GitHub organization](https://github.com/BrotatoMods)
2. [Brotato Godot Engine showcase](https://godotengine.org/showcase/brotato/)
3. [Dome Keeper Godot showcase](https://godotengine.org/showcase/dome-keeper/)
4. [Dome Keeper wave scaling (Steam)](https://steamcommunity.com/app/1637320/discussions/0/5704402939715471022/)
5. [sempitern0/Lootie MIT](https://github.com/sempitern0/Lootie)
6. [PieKing1215/godot-loot-tables](https://github.com/PieKing1215/godot-loot-tables)
7. [statico/godot-roguelike-example MIT](https://github.com/statico/godot-roguelike-example)
8. [limbonaut/limboai MIT](https://github.com/limbonaut/limboai)
9. [LimboAI documentation](https://limboai.readthedocs.io/)
10. [Godot 4.4 Resources docs](https://docs.godotengine.org/en/4.4/tutorials/scripting/resources.html)
11. [godot-resource-data-patterns](https://lobehub.com/skills/thedivergentai-gd-agentic-skills-godot-resource-data-patterns)
12. [DEV.to RPG Part 16: Level and XP](https://dev.to/christinec_dev/lets-learn-godot-4-by-making-an-rpg-part-16-level-xp-1ppc)
13. [Davide Pesce — Godot XP tutorial](https://www.davidepesce.com/2019/12/19/godot-tutorial-13-experience-points-and-level-advancement/)
14. [spaceyjase/godot-crafting MIT](https://github.com/spaceyjase/godot-crafting)
15. [Joys of Small Game Development — Difficulty Curves](https://abagames.github.io/joys-of-small-game-development-en/difficulty/curve.html)
16. [Roblox DevForum — progressive wave system](https://devforum.roblox.com/t/how-do-i-make-my-wave-system-progressively-harder/2796468)
