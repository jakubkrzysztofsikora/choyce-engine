---
date: 2026-05-19
researcher: claude (architecture)
project: choyce-engine
engine: Godot 4.6
target_audience: kids 5-8, Polish locale, tablet + desktop (M2 Max, iPad-class)
related:
  - thoughts/shared/reviews/game-design-2026-05-18.md
  - thoughts/shared/research/2026-05-18-codebase-state-contrarian-review.md
  - src/adapters/inbound/gameplay/player_controller.gd
  - src/adapters/inbound/gameplay/gameplay_runtime.gd
  - src/domain/world_authoring/game_rule.gd
status: draft for backlog grooming
---

# Godot Mechanics — From Tech Demo to AAA-Feel Kid Engine

## Executive summary

The current `PlayerController` + `GameplayRuntime` is a *toy*: a CharacterBody3D walks on a flat plane, an AnimationPlayer cycles three Kenney clips, and trigger areas only know "win" or "collectible". To cross from "tech demo" to "AAA kid game" we don't need new tech — we need *layered juice*: a SpringArm3D third-person rig with collision damping, an AnimationTree state machine with a 1-D locomotion BlendSpace, a tiny Resource-driven rules engine that finally executes the `compiled_logic` strings dead in `GameRule`, and an icon-only quest HUD with audio cues. NPCs come for free once we add NavigationRegion3D + bake-at-load. The four "AAA feel" multipliers — camera collision, animation blending, sub-emitter particles, and reactive music layers — are all native Godot 4.6 nodes; no plugins required for the first 80% of the work, and LimboAI is a clean Asset Library drop-in via GDExtension if behavior trees prove useful for richer NPCs in a second pass. The unlock pattern across all 9 axes is the same: **define an outbound port for the *behavior*, write a thin GDScript adapter, keep the rules engine in `application/` so we don't leak Godot types into domain.**

---

## 1. Third-person camera systems

### Current state
`PlayerController._camera = $Camera3D` is a direct child of the CharacterBody3D. Sits at `(0, 1.6, 0)` (`_camera_base_y`). No collision damping. Rotates with the player when player yaws (because `rotate_y(self)` rotates the camera too). Head-bob lerps `position.y`. Q/E + mouse-drag + right-stick rotate the *body*, not a separate camera rig — which means the kid can't look around without turning the character. This is the single biggest reason it feels "first-person-ish" despite being framed as third-person.

### Target pattern: SpringArm3D + Top-Level rig

```
Player (CharacterBody3D)            ← only translates, never yaws
├── CollisionShape3D
├── CharacterMesh (Node3D)          ← rotates to face movement direction
│   └── AnimationPlayer
├── CameraPivot (Node3D)            ← yaw + pitch live here
│   └── SpringArm3D                 ← collision-aware arm
│       └── Camera3D                ← at the tip of the spring
└── AudioListener3D                 ← make_current() so audio centers on kid
```

Key settings (per Godot 4.6 docs + Dre Dyson's 2026 case study):

- `SpringArm3D.spring_length = 4.0` (shoulder-cam distance; 3.5 for tablet portrait crops)
- `SpringArm3D.shape = SphereShape3D(radius=0.3)` — never use the default raycast fallback, it pops
- `SpringArm3D.margin = 0.05`
- `SpringArm3D.collision_mask` = layer "world" only; **exclude "player"** (current code has no layer setup → arm would compress to 0 against the character mesh)
- `Camera3D.position.z = 0` (sits at arm tip)
- Camera pivot pitch clamped to `-0.6 .. 0.4` rad (kid never looks straight up or down — disorientation)
- Damping: lerp the pivot's global_position toward player at `8.0 * delta`, not snap. Lerp the spring length to a longer value during sprint (cinematic pull-back).

### Tilt-during-jump (Astro Bot trick)
Add `CameraPivot.rotation.z = lerp(0, 0.08, clamp(velocity.y / 6, 0, 1))` while airborne. A 4-5° camera roll on jump sells "lift" without making the kid nauseous. Falling adds the opposite tilt. Reset to 0 on land.

### Tablet UX
- Touch right-side virtual joystick → drives `CameraPivot.rotation.y/x` directly (already partially supported via `Input.get_joy_axis`).
- Disable Q/E camera rotation when touch is active (avoid double-input).
- Mouse-drag remains for desktop QA.

### Dev cost
**M** — 1 day. Refactor `PlayerController` so `rotate_y` targets `_camera_pivot` not `self`, add SpringArm3D + CameraPivot to `player_controller.tscn`, add layer setup, port mouse-drag/stick to pivot.

---

## 2. Character controller upgrades — pick 3, ship them

Current moveset: walk, sprint, jump, coyote-time, jump-buffer, gravity tweak. That's a *good* foundation but feels generic.

| Move | Kid-safe? | Learnable in 30s? | AAA-feel ROI | Dev cost |
|---|---|---|---|---|
| **Hover/glide** (hold Space after peak of jump) | ✅ | ✅ icon = balloon | ⭐⭐⭐ (Astro Bot's secret) | S |
| **Double-jump** (tap Space again mid-air) | ✅ | ✅ | ⭐⭐⭐ | S |
| **Dash** (Shift on ground) | ✅ kid-flavor: "speed run" with sparkles | ✅ | ⭐⭐ | S |
| **Swim** (Y < water_zone.y) | ✅ | ⚠️ contextual | ⭐⭐ | M |
| **Ladder climb** | ✅ | ⚠️ contextual | ⭐ | M |
| **Mantle** (auto-grab ledge) | ✅ | ⚠️ feels magic | ⭐⭐ | M |
| **Slide** (Ctrl down a slope) | ✅ | ❌ adult mechanic | ⭐ | M |

**Recommendation: Hover + Double-Jump first (1 day), Dash second (½ day).** These three give the biggest "feels like Astro" gain because they all extend air time → kid no longer falls off platforms, less frustration, more "I can fly!" moments.

### Hover code sketch (add to `_physics_process` jump section)
```gdscript
const HOVER_GRAVITY_MULT := 0.25   # 4× lighter than normal fall
const HOVER_MAX_DURATION := 1.2
var _hover_timer := 0.0

if not is_on_floor() and velocity.y <= 0.0 \
        and Input.is_action_pressed("jump") \
        and _hover_timer < HOVER_MAX_DURATION:
    # Apply gentle gravity instead of full fall gravity
    velocity.y -= gravity * HOVER_GRAVITY_MULT * delta
    _hover_timer += delta
    # Visual: spawn a small "balloon" particle above head
    _effect_spawner.emit_signal("hover_active")
else:
    if is_on_floor():
        _hover_timer = 0.0
```

### Double-jump
```gdscript
const MAX_AIR_JUMPS := 1
var _air_jumps_used := 0

# in jump block:
if _jump_buffer > 0.0 and (_coyote_time > 0.0 or _air_jumps_used < MAX_AIR_JUMPS):
    if _coyote_time <= 0.0:
        _air_jumps_used += 1
        # different SFX + bigger sparkle for kid feedback
        jumped.emit()
        _effect_spawner.spawn_doublejump_burst(global_position)
    velocity.y = JUMP_VELOCITY * (1.0 if _coyote_time > 0.0 else 0.85)
    _jump_buffer = 0.0
    _coyote_time = 0.0

# reset on landing:
if is_on_floor() and not _was_on_floor:
    _air_jumps_used = 0
```

### Failure recovery (NOT death)
Per game-design review G-005: **plane-below-y=-10 detection → respawn at last checkpoint**, no death animation, just a gentle fade-to-white + spawn position reset. No HP, no game-over screen. Re-uses existing `victory_sequence` infra for the fade — invert color to "soft reset" feel.

```gdscript
const FALL_DEATH_Y := -10.0
var _last_checkpoint: Vector3

func _physics_process(delta):
    ...
    if global_position.y < FALL_DEATH_Y:
        _gentle_respawn()

func _gentle_respawn() -> void:
    _screen_feedback.flash(Color.WHITE, 0.4)
    spawn_at(_last_checkpoint)
    _audio_bus.emit_sfx("respawn_soft", _last_checkpoint)
```

### Dev cost
Hover + double-jump + soft-respawn: **S, ~½ day combined**.

---

## 3. Animation state machine — move to AnimationTree

### Current pain point
`_play_anim(name: String)` with string compare + manual `loop_mode = LOOP_LINEAR` override is fragile. The `WALK_VELOCITY_THRESHOLD = 0.5` makes a binary idle↔walk switch — no blending, no walk↔run blend, no jump→land transition smoothing. Hard landing (`velocity.y < -5`) only shakes the screen, no impact animation.

### Target: AnimationTree with StateMachine root

```
AnimationTree
└── parameters/playback (StateMachine)
    ├── Locomotion (BlendSpace1D, axis = speed 0..1)
    │   ├── 0.0 → idle
    │   ├── 0.3 → walk
    │   └── 1.0 → sprint
    ├── JumpStart   (one-shot, Xfade 0.05, Auto advance At End → JumpLoop)
    ├── JumpLoop    (looping fall pose)
    ├── JumpLand    (one-shot, Xfade 0.1, Auto advance → Locomotion)
    └── Hover       (additive layer? or its own state with balloon pose)
```

Transitions:
- `Locomotion → JumpStart` on `is_jumping` condition (set by `jumped` signal)
- `JumpLoop → JumpLand` on `is_on_floor` condition
- `Locomotion → JumpLoop` on `not is_on_floor and velocity.y < 0` (fell off ledge without jumping)

### Wiring in `player_controller.gd`

```gdscript
@onready var _anim_tree: AnimationTree = $CharacterMesh/AnimationTree
@onready var _state_machine: AnimationNodeStateMachinePlayback = \
    _anim_tree.get("parameters/playback")

func _ready():
    _anim_tree.active = true

func _physics_process(delta):
    ...
    # 1-D BlendSpace param drives smooth idle↔walk↔sprint
    var horiz_speed := Vector2(velocity.x, velocity.z).length()
    var max_speed := SPRINT_SPEED
    _anim_tree.set("parameters/Locomotion/blend_position",
                   clamp(horiz_speed / max_speed, 0.0, 1.0))

    # State machine conditions
    _anim_tree.set("parameters/conditions/is_on_floor", is_on_floor())
    _anim_tree.set("parameters/conditions/is_jumping",
                   not is_on_floor() and velocity.y > 0)
    _anim_tree.set("parameters/conditions/is_falling",
                   not is_on_floor() and velocity.y <= 0)
```

### Hard-landing animation
On `velocity.y < -5` at touchdown, `_state_machine.travel("JumpLand_Hard")` — re-uses JumpLand clip but plays at 0.7× speed with squash baked in. Re-uses existing `_landing_squash()` tween *or* moves it into the animation.

### Kenney character has only 3-4 clips — what about Hover/Land?
The Kenney pack ships idle, walk, sprint, jump, fall, die. We:
- Use `idle` as Hover base + apply additive `BoneAttachment3D` IK to raise an arm holding a procedural balloon (or just attach a balloon mesh as `Hover` overlay sprite).
- Use `fall` last frame as JumpLand for now; the squash tween hides the missing land clip.
- Long term (TASK in next sprint): bake custom Land + Hover clips in Blender, drop into the existing Kenney GLB skeleton.

### Dev cost
**M** — 1 day. Create `player_anim_tree.tres` AnimationTree resource, wire conditions, delete `_play_anim` and `LOOPING_ANIMS` helpers. The state machine is more code-up-front but kills the loop-mode-override hack and makes future moves (swim/climb) drop-in.

---

## 4. Rules engine — execute the `compiled_logic` strings

### Problem
`GameRule.compiled_logic` stores strings like `"every_30s:advance_crop_stage()"`, `"on_happiness_50:unlock_area('school_zone')"`, `"collect_5_carrots:complete_quest('harvest')"`. None of these are parsed. The block logic editor compiles to these strings, the JSON templates carry them, and nothing reads them.

### Recommendation: Resource-driven dispatch, NOT LimboAI for v1

LimboAI is great for *NPC* behavior (BTs), but for **game-world rules** (timers, scorers, win conditions) a behavior tree is overkill. We want a flat list of *active rules*, each with a condition + action. Use **Godot Resource** subclasses so designers can author rules in the inspector when block logic isn't enough.

### Architecture (hex-clean)

```
src/application/
├── rules_engine_service.gd         ← evaluates active rules per frame
└── rule_compiler_service.gd        ← already exists (compile_block_logic_service.gd)

src/domain/world_authoring/
├── game_rule.gd                    ← exists, untouched (string holder)
└── compiled_rule.gd                ← NEW: typed RefCounted with .evaluate(ctx)

src/ports/outbound/
└── rules_runtime_port.gd           ← register_rule, tick(delta, ctx), unregister

src/adapters/inbound/gameplay/
└── godot_rules_runtime_adapter.gd  ← Timer + signal wiring, owns the rule list
```

### CompiledRule (domain, no Godot types)
```gdscript
class_name CompiledRule
extends RefCounted

enum Trigger {
    EVERY_N_SECONDS,
    ON_AREA_ENTER,
    ON_PROGRESS_REACHED,
    ON_COLLECT_COUNT,
}
enum Action {
    INCREMENT_QUEST,
    SPAWN_ITEM,
    UNLOCK_AREA,
    ADVANCE_STAGE,
    COMPLETE_QUEST,
    PLAY_NPC_LINE,
}

var trigger: Trigger
var trigger_params: Dictionary    # e.g. {"interval": 30.0} or {"zone_id": "park"}
var action: Action
var action_params: Dictionary     # e.g. {"quest_id": "harvest", "delta": 1}
var enabled: bool = true
```

### Rule compiler — string → CompiledRule
Single regex pass over `compiled_logic`. Cover the 6 patterns observed in `data/templates/*.json`:

```gdscript
# rule_compiler_service.gd
const PATTERNS := [
    ["^every_(\\d+)s:(\\w+)\\((.*)\\)$",          Trigger.EVERY_N_SECONDS],
    ["^on_collect_(\\d+)_(\\w+):(\\w+)\\((.*)\\)$",Trigger.ON_COLLECT_COUNT],
    ["^on_(\\w+)_(\\d+):(\\w+)\\((.*)\\)$",        Trigger.ON_PROGRESS_REACHED],
    ["^on_area_(\\w+):(\\w+)\\((.*)\\)$",          Trigger.ON_AREA_ENTER],
    # …
]
```

Action strings map by name to Action enum. Args parse via `JSON.parse_string`.

### Runtime adapter (Godot side)
```gdscript
class_name GodotRulesRuntimeAdapter
extends Node

var _rules: Array[CompiledRule] = []
var _timers: Dictionary = {}      # rule_id → accumulated time
var _context: Dictionary = {}     # mutable game state (collected_items, quest_progress, …)

func register_rules(rules: Array[CompiledRule]) -> void:
    _rules = rules.duplicate()
    for r in _rules:
        if r.trigger == CompiledRule.Trigger.EVERY_N_SECONDS:
            _timers[r] = 0.0

func tick(delta: float) -> void:
    for r in _rules:
        if not r.enabled:
            continue
        match r.trigger:
            CompiledRule.Trigger.EVERY_N_SECONDS:
                _timers[r] += delta
                if _timers[r] >= r.trigger_params["interval"]:
                    _timers[r] = 0.0
                    _fire_action(r)
            CompiledRule.Trigger.ON_COLLECT_COUNT:
                var item := r.trigger_params["item"]
                var count := int(_context.get("collected", {}).get(item, 0))
                if count >= r.trigger_params["count"]:
                    r.enabled = false
                    _fire_action(r)

func on_event(event_name: String, payload: Dictionary) -> void:
    # called by GameplayRuntime on body_entered, on_collect, etc.
    for r in _rules:
        if r.trigger == CompiledRule.Trigger.ON_AREA_ENTER \
                and r.trigger_params["zone_id"] == payload.get("zone_id"):
            _fire_action(r)
```

### Why not LimboAI here?
- LimboAI BTs are stateful per-agent — game rules are stateless globals
- C++ module/extension dependency is overkill for what is essentially "13 lines of `match` statements"
- We *would* use LimboAI for NPC AI (section 6) where stateful trees + behaviour selectors shine

### Dev cost
**M** — 1.5 days. Rule compiler (regex + Action enum), CompiledRule type, port + adapter, wire into GameplayRuntime + 5 template JSON files. This is what unblocks G-001 and G-007 from the game-design review.

---

## 5. Quest / objectives system — icons only, audio-first

### Per game-design review G-003 + UX research
Templates already define quests:
```json
{
  "quest_id": "harvest",
  "objective_type": "collect",
  "target_count": 5,
  "target_item": "carrot",
  "reward_score": 40,
  "reward_unlocks": ["sell_zone"]
}
```
A kid-readable HUD shows: icon of the item + filled-pips counter + flag icon for the destination.

### HUD layout (CanvasLayer)
```
┌──────────────────────────────┐
│ [🥕] ●●●○○        [🏁]       │  ← top-left objective stripe
│                              │
│        (3D viewport)         │
│                              │
└──────────────────────────────┘
```

### Implementation
- `quest_hud.gd` Control scene with HBoxContainer; pip widget = 5 TextureRects toggled `modulate.a` 1.0 vs 0.3
- Listen to `RulesEngine.event` signal: when `INCREMENT_QUEST` action fires for current quest, advance pips
- On quest complete: pip explodes into sparkles (sub-emitter pattern, see §8), audio fanfare, flag icon pulses
- **No text whatsoever** — kid can't read. Icons map 1:1 to `target_item` (carrot.png, gem.png, coin.png) and `reward_unlocks` zone (flag-park.png, flag-shop.png).

### Persistence
Already have `SessionProgressStorePort` + `SessionProgressUpdatedEvent`. On every quest_progress change, fire the event with `{quest_id, current, target}`. Existing FilesystemConsentStore-style debounced 250ms flush pattern reused → persists across app restart.

### Audio cues
- Pip fill: short bell (rising pitch with each pip: C5, D5, E5, F5, G5)
- Quest complete: fanfare from existing AudioBank
- Wrong zone entered with quest incomplete: gentle "uh-uh" wobble (don't punish; just hint)

### Dev cost
**S** — ½ day. HUD scene is shallow, the data flow rides on the rules engine from §4.

---

## 6. NPC behavior — friendly companions, no enemies

### Cast (kid-safe)
- **Animal companion**: bunny mascot that follows the kid (carries hints in body language: looks toward next quest target, ears perk when player gets warm/cold)
- **Friendly villager**: stands at quest-giver position, plays NPC line on `body_entered`, waves on quest_complete
- **Treasure-hint helper**: butterfly that floats from player toward next collectible when player idle > 5s
- **No combat NPCs.** Per `CLAUDE.md` constraint. Even "boss" worlds use puzzle-pressing or rhythm-tapping, not damage.

### Two-tier architecture

#### Tier 1: simple FSM in GDScript (for the bunny, butterfly)
Inline state in the NPC script. ~50 lines. States: IDLE, FOLLOW_PLAYER, POINT_AT_TARGET, CELEBRATE.

```gdscript
class_name BunnyCompanion
extends CharacterBody3D

@onready var agent: NavigationAgent3D = $NavigationAgent3D
@onready var anim_tree: AnimationTree = $Mesh/AnimationTree
const FOLLOW_DISTANCE := 2.5
const STOP_DISTANCE := 1.5
const SPEED := 4.5
var _state: int = State.IDLE
enum State { IDLE, FOLLOW, POINT, CELEBRATE }

func _physics_process(delta):
    var to_player := player.global_position - global_position
    var dist := to_player.length()
    match _state:
        State.FOLLOW:
            if dist < STOP_DISTANCE:
                _state = State.IDLE
            else:
                agent.target_position = player.global_position
                var next := agent.get_next_path_position()
                velocity = (next - global_position).normalized() * SPEED
                move_and_slide()
        State.IDLE:
            if dist > FOLLOW_DISTANCE:
                _state = State.FOLLOW
```

#### Tier 2: LimboAI behavior tree (for the villager + helper)
Worth the plugin once we have >3 NPCs with branching idle behaviors. Install via Asset Library (GDExtension build), enable in Project Settings. Then define BT resources per NPC type. Tasks (custom GDScript classes extending `BTAction`): `WalkToTarget`, `PlayNPCLine`, `WaitForPlayer`, `AdvanceQuest`, `WaveAnimation`. Selectors compose them into village-life patterns.

### Navigation (Godot 4.6 native)
- World root gets a `NavigationRegion3D` with `NavigationMesh` baked in editor (per-template `.tres` so each world has correct walkable area)
- Bake **at world-load time** for procedural worlds: `nav_region.bake_navigation_mesh()` after `world_renderer.render_world(world)` completes
- Each NPC has `NavigationAgent3D` with `avoidance_enabled = true`, `radius = 0.4`, `target_desired_distance = STOP_DISTANCE`
- Player itself doesn't need an agent — they're driven by Input, not by pathfinding

### Caveat
The Godot docs warn `NavigationAgent3D` is marked experimental. Wrap usage in our outbound port (`NavigationPort`) so a future swap to a different implementation doesn't ripple.

### Dev cost
**M** — 2 days. Bunny + butterfly: ½ day. Villager + LimboAI install: 1 day. Navmesh bake-at-load wiring + Polish for each starter world: ½ day.

---

## 7. Environmental interactions — buttons, doors, breakables, water

### Current state
`gameplay_runtime._on_trigger_area_entered` handles only `"win"` (victory) and falls everything to `"collectible"` (auto-pickup). Templates define 8+ trigger types (`treasure_zone`, `harvest_zone`, `puzzle_zone`, `sell_zone`, `checkpoint`, `bonus_zone`, `park_zone`, `school_zone`) — all dead.

### Pattern: one `Interactable3D` base scene, subclass by behavior

```
Interactable3D (Area3D)
├── CollisionShape3D
├── Mesh / Sprite (optional)
└── Script: interactable.gd
    ├── signal player_in_range(area)
    ├── signal player_out_of_range(area)
    └── signal activated(payload)
```

Behaviors (each is a subclass + scene):

| Trigger type (template) | Behavior class | Activation | Visual feedback |
|---|---|---|---|
| `collectible` | Pickup3D | auto on enter, queue_free | sparkle burst + bell |
| `checkpoint` | Checkpoint3D | auto on enter, save respawn pos, glow once | gentle pulse + chime |
| `treasure_zone` | TreasureChest3D | press "interact" while in range | chest opens, item pops out |
| `harvest_zone` | HarvestPlot3D | "interact" → triggers harvest action | crop sprouts (anim) |
| `sell_zone` | SellZone3D | enter → opens HUD with inventory swap | gentle "ka-ching" |
| `puzzle_zone` | PuzzleTrigger3D | enter → starts puzzle minigame | dim world, focus on puzzle |
| `bonus_zone` | TimedBonus3D | enter starts X-second multiplier | clock icon + ticking SFX |
| `door` | Door3D | open on signal from Button3D | hinge anim + creak |
| `button` | Button3D | press "interact" → emits `activated` | depress anim + click |
| `breakable` | Breakable3D | hit by player (jump-on-top, dash-through) | spawn pieces, particle |
| `water_zone` | WaterZone3D | enter swaps controller mode → swim | splash + bubble particles |

### Code sketch — pickup
```gdscript
class_name Pickup3D
extends Area3D

@export var item_id: String = "coin"
@export var score_value: int = 10

func _ready():
    body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
    if not (body is PlayerController):
        return
    set_deferred("monitoring", false)  # debounce
    GameplayRuntime.instance.on_pickup(item_id, score_value, global_position)
    visible = false
    # Spawn collect FX via existing EffectSpawner
    queue_free.call_deferred()
```

### Code sketch — door (driven by button activation)
```gdscript
class_name Door3D
extends StaticBody3D

@export var locked_until_buttons: Array[NodePath] = []
var _remaining: int

func _ready():
    _remaining = locked_until_buttons.size()
    for path in locked_until_buttons:
        get_node(path).activated.connect(_on_button_activated)

func _on_button_activated(_payload):
    _remaining -= 1
    if _remaining <= 0:
        _open()

func _open():
    var t := create_tween()
    t.tween_property(self, "rotation:y", PI/2, 0.8).set_trans(Tween.TRANS_BACK)
    AudioEventBus.emit_sfx("door_open", global_position)
    # Remove collision after open
    $CollisionShape3D.set_deferred("disabled", true)
```

### Water swim mode (lightweight)
Don't simulate buoyancy. When player enters `WaterZone3D`, swap to "swim" controller state: reduce gravity to 1/3, cap fall speed, change animation to a `swim` clip (or re-use walk on its side), play continuous bubble particle near head, change footstep SFX to splash. On exit, restore. The swim "feel" is 90% audio+particle, 10% physics.

### Dev cost
**M-L** — 2 days. Pickup3D + Checkpoint3D + Door3D + Button3D + Breakable3D + WaterZone3D each as a `.tscn` with the base `Interactable3D` script. Wiring `_on_trigger_area_entered` to dispatch on `area.get_meta("trigger_type")` covers existing trigger types. Each subclass is 30-60 lines. Templates need *no* JSON changes; just add `behavior_class` meta key.

---

## 8. Particle juiciness — sub-emitters are the secret

### Current state
`effect_spawner.gd` (91 lines) handles `spawn_sparkle_burst`, `spawn_dust_puff`, `spawn_collect_effect`. Already uses GPUParticles3D. Good foundation. Missing: sub-emitter chains, trail meshes, water splash, falling leaves ambient.

### High-impact additions

#### Landing dust (already partial)
- Increase `amount` from current default to 14 for normal landing, 28 for hard landing
- `local_coords = false` so dust gets left behind as kid keeps walking
- Add a sub-emitter (`AT_END`) with 4 tiny "kicked-up pebbles" particles

#### Pickup sparkle — the AAA upgrade
Two GPUParticles3D systems in one scene:
1. **Main burst**: 12 bright stars exploding outward, no gravity, 0.6s lifetime, angular_velocity_random ±2 rad/s
2. **Sub-emitter (per particle)**: 3 tiny trail dots so each star leaves a glitter wake. `sub_emitter_mode = PER_PARTICLE`

```gdscript
# pickup_sparkle.tscn root: GPUParticles3D
# - process_material: ParticleProcessMaterial
#   - direction = Vector3(0,1,0)
#   - spread = 90.0 deg
#   - initial_velocity = 3..5
#   - gravity = Vector3.ZERO
#   - angular_velocity = 0..2
#   - sub_emitter = NodePath("Trail")
#   - sub_emitter_mode = PER_PARTICLE
#   - sub_emitter_amount_at_end = 1
# - one_shot = true
# - local_coords = false
# - Trail (GPUParticles3D child): 0.3s lifetime, tiny scale, additive material
```

#### Water splash
- Main burst on `WaterZone3D.body_entered`: 40 droplet particles upward, gravity restored to make them rain back
- Sub-emitter (`AT_END`): tiny mist puff when each droplet "lands" 1.2s later — looks like real splash residue

#### Falling leaves ambient (forest world)
- One persistent GPUParticles3D parented to world root, `BoxEmissionShape` 50×30×50m above terrain
- `amount = 60`, `lifetime = 8s`, `gravity = (0, -0.4, 0)` (slow fall)
- `angular_velocity` random ±1 rad/s so leaves tumble
- `local_coords = false` (critical — leaves stay in world space)
- 3 different leaf textures, randomized per-particle via `color_initial_ramp`

#### Speed sparkles (dash trail)
- Spawned on dash activation, parented to player's mesh
- `trail_enabled = true`, `RibbonTrailMesh` with 0.15s lifetime
- Emits while `is_dashing == true`

### Implementation pattern in `effect_spawner.gd`
```gdscript
func _spawn_oneshot(scene: PackedScene, pos: Vector3) -> void:
    var fx: GPUParticles3D = scene.instantiate()
    get_tree().current_scene.add_child(fx)
    fx.global_position = pos
    fx.local_coords = false
    fx.one_shot = true
    fx.restart()  # NOT emitting=true — restart bypasses GPU-side delay
    fx.finished.connect(fx.queue_free)
```

### Dev cost
**S-M** — 1 day. The first 4 effects (landing dust + pickup sparkle + water splash + leaves) is ~½ day. Speed sparkles + double-jump burst + respawn fade-in another ½. Each is a `.tscn` resource authored once.

---

## 9. Sound design layer

### Current state
- `AudioBank` autoload: ElevenLabs Polish voice clips + Kenney SFX (collect, jump, footsteps, music)
- `AudioEventBus` (8 lines, thin wrapper) emits SFX by name at a 3D position
- `SFXPlayer`: pool of AudioStreamPlayer3D for spatial SFX
- Music: `_ambient_player` (AudioStreamPlayer, non-positional) driven by AudioBank.play_music on world entry
- No positional listener — defaults to Camera3D, but we switch to AudioListener3D on player (see §1)

### Upgrades

#### Positional vs HUD audio
- **3D world SFX** → `AudioStreamPlayer3D` (already correct in SFXPlayer)
- **HUD/UI SFX** (pip-fill chime, quest-complete fanfare, button click) → `AudioStreamPlayer` (2D, no attenuation). Don't try to use 3D for HUD — kid hears it differently per camera angle. Add a `UISfxPlayer` autoload sibling to SFXPlayer.

#### Reactive music — zone layers
Use `AudioStreamSynchronized` to play 2-3 layers in sync; modulate per-layer `volume_db` based on zone state. E.g. farm world:
- Layer A: ambient cricket loop (always at 0 dB)
- Layer B: cheerful banjo melody (0 dB when player walks, -40 dB when player idle)
- Layer C: triumphant brass (silenced until first quest complete, then 0 dB)

```gdscript
# music_director.gd (autoload)
@onready var _stream := preload("res://audio/farm_synchronized.tres") as AudioStreamSynchronized
@onready var _player := $AudioStreamPlayer

func enter_zone(zone_id: String):
    var tween := create_tween().set_parallel(true)
    match zone_id:
        "farm_quiet":
            tween.tween_method(_set_layer_volume.bind(1), 0.0, -40.0, 1.5)
        "farm_active":
            tween.tween_method(_set_layer_volume.bind(1), -40.0, 0.0, 1.5)

func _set_layer_volume(layer_idx: int, db: float):
    _player.stream_paused = false
    _player.set_stream_sync_volume(layer_idx, db)
```

#### AudioStreamInteractive for state-driven music
Per AAA pattern (Wwise-style): one `AudioStreamInteractive` resource per world theme with clips for intro, exploration, quest-active, victory. Transitions defined in inspector via `add_transition()`:
- `intro → exploration`: `TRANSITION_FROM_TIME_END`, cross-fade 2s
- `exploration → quest_active`: `TRANSITION_FROM_TIME_NEXT_BEAT`, fade 1 beat
- `quest_active → victory`: `TRANSITION_FROM_TIME_IMMEDIATE`, fade 0.3s
- `victory → exploration`: `TRANSITION_FROM_TIME_END`, fade 1 bar

OGG only (WAV doesn't carry BPM metadata).

#### Kid-friendly voiced exclamations
Already have ElevenLabs Polish voice in AudioBank. Add a `VoiceExclamation` system: short reactions tied to events.
- On jump: ¼ chance per jump to play `"Hop!"`, `"Wuu!"`, `"Lecimy!"`
- On pickup: `"Ooo!"`, `"Tak!"`, `"Super!"`
- On respawn: `"Spróbuj jeszcze raz!"`, `"Damy radę!"` (encouraging, never blaming)
- On quest complete: `"Brawo!"`, `"Świetnie!"`, `"Tak trzymaj!"`

Implementation: extend `AudioBank` with `play_exclamation(event_kind: String)` that picks weighted-random clip with cooldown (don't repeat within 8s).

#### Distance-based muffle
For music sources played from `AudioStreamPlayer3D` in zones, attach a `AudioEffectLowPassFilter` to the music bus and modulate cutoff via player→zone-center distance. Per UhiyamaLab pattern. Cutoff ≥ 18 kHz when inside zone, ≤ 2 kHz when far away → makes music feel "outside" until kid enters.

### Dev cost
**M** — 1.5 days. UISfxPlayer autoload (½ day), MusicDirector + AudioStreamSynchronized for farm/forest/adventure (½ day), VoiceExclamation in AudioBank (¼ day), distance-muffle low-pass (¼ day).

---

## Architecture / hex-arch implications

| Concern | Domain | Port (outbound) | Adapter (Godot) |
|---|---|---|---|
| Rules execution | `CompiledRule`, `RulesEngine` | `RulesRuntimePort` | `GodotRulesRuntimeAdapter` |
| Quest tracking | `Quest`, `QuestProgress` | `QuestStorePort` (extend existing SessionProgress) | filesystem (debounced) |
| Navigation | `NavTarget` value type | `NavigationPort` | `GodotNavigationAdapter` wrapping NavigationAgent3D |
| NPC AI | `NpcMood`, `NpcRole` | `NpcAgentPort` | `BunnyAgentAdapter`, `LimboAIVillagerAdapter` |
| Music layering | `MusicState` enum | `MusicDirectorPort` | `GodotAudioStreamInteractiveAdapter` |

**Key rule**: GDScript adapters never appear in `src/application/` or `src/domain/`. The rules engine in `application/` calls into `RulesRuntimePort.register_rule(rule)` — it doesn't know Godot exists. This matches the Wave B pattern from the existing memory (e.g. `EnvironmentPort` + `OSEnvironmentAdapter`).

### Composition root impact
`main.gd._build_default_ports_phase_2` adds:
- `KEY_RULES_RUNTIME` → `GodotRulesRuntimeAdapter` instance (Node, autoload or scene-tree child)
- `KEY_NAVIGATION` → `GodotNavigationAdapter`
- `KEY_NPC_AGENT` → factory (returns adapter per NPC type)
- `KEY_MUSIC_DIRECTOR` → `GodotAudioStreamInteractiveAdapter`

Composition-root CI gate (already present per Wave B) will catch missing wires.

### Test strategy
- Domain (`CompiledRule`, `RulesEngine`) — pure GDScript unit tests in `tests/domain/`
- Application (`rule_compiler_service`) — contract test against fixture template JSONs
- Adapter (`GodotRulesRuntimeAdapter`) — integration test in SceneTree mode, verifies `tick(delta)` fires actions on schedule
- AI vision (TASK-064 KF-001 onwards) — visual regression on starter worlds: kid sees quest HUD pip fill, sees flag pulse on quest complete

---

## Next 3 features to build (punchlist)

In strict order — each unlocks the next, each is ½-1 day:

### 1. SpringArm3D + camera tilt-on-jump (½ day, dev cost S)
**Why first**: The biggest visible perceptual jump from "tech demo" to "real game". Affects every other feature's feel.
- Refactor `player_controller.tscn`: add CameraPivot + SpringArm3D + Camera3D nodes
- Move yaw rotation from CharacterBody3D to CameraPivot
- Add tilt-on-velocity-y
- Set up "world" + "player" physics layers; exclude player from spring arm mask
- Smoke test: jump, run, mouse-drag, controller right-stick all feel third-person
- **Exit criterion**: kid camera no longer rotates the character mesh; player can orbit a stationary kid

### 2. AnimationTree with locomotion BlendSpace + jump states (1 day, dev cost M)
**Why second**: Unblocks Hover/Double-jump animation slots, kills `_play_anim` loop hack, lays the rails for swim/climb later.
- Author `player_anim_tree.tres` resource (StateMachine root, Locomotion BlendSpace1D, JumpStart/Loop/Land)
- Update `player_controller.gd` to set `blend_position` + conditions instead of calling `_play_anim`
- Delete `LOOPING_ANIMS` const and the loop-mode override
- Add hard-landing variant (slower-played JumpLand)
- **Exit criterion**: idle→walk→sprint visibly cross-fades; jump→fall→land plays without a glitch frame; AnimationTree handles all clips

### 3. Resource-driven rules engine + quest HUD (1.5 days, dev cost M)
**Why third**: This is the one that turns the engine from "movement demo" to "you played a game". Executes existing `compiled_logic` strings, makes 4 quests in each starter template actually work, makes pip-counter HUD non-decorative.
- `compiled_rule.gd` (domain) + `rule_compiler_service.gd` (application, regex → CompiledRule)
- `rules_runtime_port.gd` + `godot_rules_runtime_adapter.gd`
- Wire `GameplayRuntime` to forward `body_entered` and per-frame tick into the adapter
- `quest_hud.tscn` Control: HBox with icon + 5 pips + flag, listens to RulesEngine events
- Smoke test on `farm` starter: harvest 5 carrots → pips fill → fanfare → sell zone unlocks → unlock_area glow
- **Exit criterion**: all 3 starter worlds have at least 1 working quest end-to-end; pip HUD updates from gameplay events; quest persistence survives app restart

**After these 3, build in any order**: hover/double-jump (S), navigation + bunny companion (M), sub-emitter particles upgrade (S), AudioStreamInteractive music director (M), water/swim zones (M), LimboAI villager (M).

---

## References

### Godot 4.6 docs
- [Third-person camera with spring arm — Godot 4.6](https://docs.godotengine.org/en/4.6/tutorials/3d/spring_arm.html)
- [Third-person camera with spring arm — latest](https://docs.godotengine.org/en/latest/tutorials/3d/spring_arm.html)
- [GPUParticles3D — latest](https://docs.godotengine.org/en/latest/classes/class_gpuparticles3d.html)
- [Particle systems (3D) — stable](https://docs.godotengine.org/en/stable/tutorials/3d/particles/index.html)
- [Using NavigationAgents — latest](https://docs.godotengine.org/en/latest/tutorials/navigation/navigation_using_navigationagents.html)
- [3D navigation overview — latest](https://docs.godotengine.org/en/latest/tutorials/navigation/navigation_introduction_3d.html)
- [NavigationAgent3D — stable](https://docs.godotengine.org/en/stable/classes/class_navigationagent3d.html)
- [AudioStreamPlayer3D — stable](https://docs.godotengine.org/en/stable/classes/class_audiostreamplayer3d.html)
- [AudioStreamInteractive — latest](https://docs.godotengine.org/en/latest/classes/class_audiostreaminteractive.html)
- [Area3D — Godot Engine](https://docs.godotengine.org/en/4.4/classes/class_area3d.html)

### Tutorials & community
- [Mastering the SpringArm3D in Godot — supermatrix.studio](https://supermatrix.studio/blog/camera-controller-and-spring-arm-3d-in-godot)
- [How I Fixed Third-Person Player Rotation in Godot 3D — Dre Dyson](https://dredyson.com/how-i-fixed-third-person-player-rotation-in-godot-3d-without-breaking-the-camera-a-complete-step-by-step-case-study-after-6-months-of-trial-error-and-real-results/)
- [AnimationTree State Machines in Godot 4 — Complete Guide](https://godot-mcp.abyo.net/guides/godot4-animationtree)
- [Godot 4 AnimationTree Basics – BlendSpace1D — YouTube](https://www.youtube.com/watch?v=KFr63B9RLhA)
- [Character Animation — Godot 4 Recipes (KidsCanCode)](https://kidscancode.org/godot_recipes/4.x/3d/assets/character_animation/index.html)
- [3D Skeletal Animation in Godot — UhiyamaLab](https://uhiyama-lab.com/en/notes/godot/3d-skeletal-animation/)
- [Building Adaptive Music in Godot with AudioStreamInteractive — UhiyamaLab](https://uhiyama-lab.com/en/notes/godot/adaptive-music-system/)
- [3D Audio and Spatial Sound in Godot — UhiyamaLab](https://uhiyama-lab.com/en/notes/godot/3d-audio-spatial-sound/)
- [3D Navigation in Godot — DanielTPerry](https://www.danieltperry.me/post/godot-navigation/)
- [Using Areas — Godot 4 Recipes (KidsCanCode)](https://kidscancode.org/godot_recipes/4.x/g101/3d/101_3d_04/index.html)
- [The new music features in Godot 4.3 explained — Blips Blog](https://blog.blips.fm/articles/the-new-music-features-in-godot-43-explained)

### Plugins & assets
- [LimboAI: Behavior Trees & State Machines (Godot 4.6+) — Asset Library](https://godotassetlibrary.com/asset/KYd7wV/limboai:-behavior-trees-&-state-machines-(godot-4.6+))
- [LimboAI GitHub](https://github.com/limbonaut/limboai)
- [Game-icons.net — 4180 free SVG/PNG icons](https://game-icons.net/)
- [Flag objective icon — Game-icons.net](https://game-icons.net/1x1/delapouite/flag-objective.html)

### Game design references
- [Astro Bot — Wikipedia](https://en.wikipedia.org/wiki/Astro_Bot)
- [Astro Bot review — Ego Clown](https://www.egoclown.com/articles/astro-bot-review-ego)
- [Astro Bot is a supremely silly and incredibly smooth platformer — Engadget](https://www.engadget.com/astro-bot-is-a-supremely-silly-and-incredibly-smooth-platformer-200012651.html)
- [Astro's Playroom vs. Sackboy — VideoChums](https://videochums.com/article/astros-playroom-vs-sackboy-a-big-adventure)
- [UI/UX Design Tips for Child-Friendly Interfaces — Aufait UX](https://www.aufaitux.com/blog/ui-ux-designing-for-children/)

### Internal cross-references
- `thoughts/shared/reviews/game-design-2026-05-18.md` — G-001..G-020 findings this research addresses
- `src/adapters/inbound/gameplay/player_controller.gd` — current controller, target of §1/§2/§3 refactors
- `src/adapters/inbound/gameplay/gameplay_runtime.gd` — host for rules engine wiring (§4) and trigger dispatch (§7)
- `src/domain/world_authoring/game_rule.gd` — string-holder to be paired with new `CompiledRule` type
- `src/adapters/inbound/gameplay/effect_spawner.gd` — extend with sub-emitter scenes (§8)
- `src/adapters/inbound/shared/audio/audio_bank.gd` — extend with `play_exclamation()` and MusicDirector hook (§9)
