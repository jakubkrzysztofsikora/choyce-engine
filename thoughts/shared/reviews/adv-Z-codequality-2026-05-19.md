# Adv Z — Code Quality Review

Target: `src/adapters/inbound/gameplay/player_controller.gd`
Date: 2026-05-19
Reviewer: Adversary Z (hex-arch + GDScript code-quality)

Ranked findings, highest severity first.

---

## P0-1 — Shared `Animation` resource mutated across spawns (LOOP_NONE / LOOP_LINEAR thrash)

**File:** `player_controller.gd:281-286` (LOOP_LINEAR write in `_play_anim`) and `:456-458` (LOOP_NONE write in `_trigger_punch_animation`).

```gdscript
var anim := _anim_player.get_animation(name)
if anim != null:
    anim.loop_mode = Animation.LOOP_LINEAR        # _play_anim
...
var anim := _anim_player.get_animation(clip)
if anim != null:
    anim.loop_mode = Animation.LOOP_NONE          # _trigger_punch_animation
```

`AnimationPlayer.get_animation()` returns the **shared** `Animation` resource from the GLB's
imported `AnimationLibrary`. Every Kenney character spawned from the same scene/GLB references
that exact resource. Mutating `loop_mode` here is a **global side-effect**.

Failure modes that will fire in production:
1. Multiplayer / multi-player-instance dev test: spawning a second `PlayerController` (or any future NPC sharing the GLB, including the planned skeletal enemy refactor) walks the same shared lib. Attack-clip's `LOOP_NONE` flips to `LOOP_LINEAR` on character B's idle preroll → character A's next punch loops forever, never fires `animation_finished`, `_is_punching` stays true, kid is locked out of input.
2. Editor-only: a second `_ready()` (e.g. scene re-instanced after `queue_free`, common in our `GameplayRuntime` rebuild path) flips loop modes mid-game.

**Suggested patch:** make_unique once on `_ready`, mutate the duplicate:

```gdscript
# inside _ready, after _anim_player resolved:
for clip_name in _anim_player.get_animation_list():
    var src := _anim_player.get_animation(clip_name)
    if src == null:
        continue
    var dup := src.duplicate() as Animation
    var want_loop := false
    for prefix in LOOPING_ANIMS:
        if String(clip_name).to_lower().begins_with(prefix):
            want_loop = true
            break
    dup.loop_mode = Animation.LOOP_LINEAR if want_loop else Animation.LOOP_NONE
    var lib := _anim_player.get_animation_library(_anim_player.find_animation_library(clip_name))
    if lib != null:
        lib.remove_animation(clip_name)
        lib.add_animation(clip_name, dup)
```
Then drop the `anim.loop_mode = …` lines from `_play_anim` and `_trigger_punch_animation` entirely.

Severity: **CRITICAL** — input-lockout is a kid-safety regression (kid sees frozen character, perceives "game broken", no escape unless ESC discovered).

---

## P0-2 — `_play_anim` punch-guard creates infinite-clip lock if `animation_finished` ever drops

**File:** `player_controller.gd:267-268`, `:230-241`.

```gdscript
if _is_punching and not (name in ATTACK_ANIMS):
    return
```

`_is_punching` is **only** cleared in `_on_anim_finished`. If the signal does not fire for any
reason — and there are several:

- P0-1 shared-loop mutation (see above)
- `_anim_player.stop()` followed by `play(clip)` (line 459-460) — `stop()` does NOT emit `animation_finished`, but if the previous clip was mid-flight, the signal for THAT clip will fire LATER carrying the *new* clip name. Race window exists.
- Scene transition tearing down `_anim_player` between `play()` and finish — signal queued on a freed node.
- An enemy `apply_damage_from_enemy` knockback animation that we'll add later overriding the attack clip via `play()` from outside the controller.

…the kid is permanently stuck unable to walk because every `_play_anim("walk")` early-returns.

**Suggested patch:** belt-and-braces watchdog timer in `_trigger_punch_animation`:

```gdscript
_is_punching = true
get_tree().create_timer(0.6).timeout.connect(func():
    if _is_punching and _current_anim in ATTACK_ANIMS:
        _is_punching = false
)
```

(0.6 s = longest Kenney attack clip + headroom. Match to `ATTACK_COOLDOWN * 1.5` if you want.)

Severity: **HIGH** — defence-in-depth against P0-1; without P0-1 fixed, this is also a hard lockout.

---

## P1-3 — Dead code: `PUNCH_LEAN_RAD`, `PUNCH_FORWARD_PUSH`, `PUNCH_DURATION`, `_punch_tween`

**File:** `player_controller.gd:44-46`, `:55`.

`PUNCH_LEAN_RAD` (44), `PUNCH_FORWARD_PUSH` (45), `PUNCH_DURATION` (46) are **declared but referenced nowhere** after the skeletal rewrite. Verified by inspection of the whole file.

`_punch_tween` is read once at `:431` (`if _punch_tween != null and _punch_tween.is_valid()` /
`kill()`) but **never assigned**. The conditional is dead — the field is permanently `null`. The
guard is a no-op left over from the old procedural tween path.

The comment block `:39-43` claims this is procedural Muay-Thai via mesh-wrapper tween. The
implementation no longer matches the comment.

**Suggested patch:**

```gdscript
# DELETE lines 39-43 (stale comment block claiming procedural tween)
# DELETE lines 44-46 (PUNCH_LEAN_RAD, PUNCH_FORWARD_PUSH, PUNCH_DURATION)
# DELETE line 55 (_punch_tween declaration)
# DELETE lines 431-432 in _trigger_punch_animation:
#   if _punch_tween != null and _punch_tween.is_valid():
#       _punch_tween.kill()
```

`_punch_phase` IS still used (`:438-439`). Keep it. `_muay_thai_t` is still used by `_update_muay_thai_idle`. Keep.

Severity: **MEDIUM** — not a bug, but the next dev (us, in 2 weeks) will assume those constants drive behaviour and waste time tracing them.

---

## P1-4 — `ATTACK_ANIMS` magic list duplicates Kenney's source-of-truth, not extracted to Resource

**File:** `player_controller.gd:252-257`.

The four clip names live as a hardcoded `const Array[String]` inside an inbound adapter. This couples the controller to:
1. Kenney's clip naming (`attack-melee-right`, etc.) which differs between Kenney character packs (some use `attack_right_1`, some `slash_a`).
2. The Muay-Thai phase ordering policy (jab → cross → kick → kick) which is a **gameplay design decision**, not an adapter concern.

CLAUDE.md mandates hexagonal isolation: framework strings keyed off external asset names belong in a **Resource** (i.e. a `CharacterAnimationProfile.tres`) that the adapter resolves via constructor / `setup()`.

**Suggested patch:** new file `src/adapters/inbound/gameplay/character_animation_profile.gd`:

```gdscript
class_name CharacterAnimationProfile
extends Resource

@export var idle_anim: String = "idle"
@export var walk_anim: String = "walk"
@export var sprint_anim: String = "sprint"
@export var fall_anim: String = "fall"
@export var attack_clips: PackedStringArray = [
    "attack-melee-right",
    "attack-melee-left",
    "attack-kick-right",
    "attack-kick-left",
]
@export var looping_clips: PackedStringArray = ["idle", "walk", "sprint", "static"]
```

Inject:

```gdscript
var _anim_profile: CharacterAnimationProfile = preload("res://assets/characters/kenney_default.tres")
# Then replace `ATTACK_ANIMS` references with `_anim_profile.attack_clips`,
# `LOOPING_ANIMS` with `_anim_profile.looping_clips`, etc.
```

Same Resource then powers the enemy-skeletal refactor (see P2-8 below).

Severity: **MEDIUM** — hex-arch leak (asset-name strings hardcoded in adapter), blocks asset-pack swap, blocks design tuning without recompile.

---

## P1-5 — Ad-hoc FSM (`_is_punching` + `_current_anim` + `_punch_phase`) should be `AnimationTree` state machine

**File:** `player_controller.gd:52-54`, `:262-288`, `:230-241`.

Three booleans/ints encode:
- "Am I in attack right now?" (`_is_punching`)
- "What clip is loaded?" (`_current_anim`)
- "Which attack comes next?" (`_punch_phase`)

Plus the implicit transitions:
- velocity-driven (idle ↔ walk ↔ sprint ↔ fall) in `_physics_process:216-223`
- one-shot attack from `_trigger_punch_animation`
- return-to-movement in `_on_anim_finished`

Godot 4.x **already ships** an `AnimationTree` + `AnimationNodeStateMachine` for exactly this. The current code reinvents it badly — note the `_is_punching` guard is mirrored in `_play_anim` AND `_on_anim_finished` AND `_trigger_punch_animation` (three places to forget to update).

Not a P0 because it works, but it will compound when we add:
- Hit-reaction clips (planned per backlog)
- Block/parry
- Item-use anims
- Death anim (currently absent — `player_defeated` emits but nothing animates)

**Suggested patch:** medium-term refactor — wire `AnimationTree` over the GLB's `AnimationPlayer`, expose state-machine via `_anim_tree.get("parameters/playback")`, drop the ad-hoc booleans. New backlog task: TASK-NEW "Migrate PlayerController + EnemyController to AnimationTree state machines".

Short-term: **at minimum, extract** the FSM into a tiny `PlayerAnimationState` RefCounted with `request_attack()`, `request_movement(velocity, on_floor, sprinting)`, `on_clip_finished(name)` returning `{clip: String, force_restart: bool}`. Tests can target it directly. This pulls 3 fields and 2 funcs out of the 700-line controller.

Severity: **MEDIUM** — bug-magnet hub; complaint matches finding P2-7.

---

## P2-6 — `is_connected` guard on `animation_finished` betrays an unintended double-`_ready` codepath

**File:** `player_controller.gd:120-121`.

```gdscript
if not _anim_player.animation_finished.is_connected(_on_anim_finished):
    _anim_player.animation_finished.connect(_on_anim_finished)
```

The guard is correct, but it's only necessary if `_ready()` can be called twice on the **same node**, which in Godot only happens if the node leaves and re-enters the tree, OR if `_ready` is called manually. Neither should be happening for `PlayerController` — when `GameplayRuntime` rebuilds, it `queue_free`s and spawns a fresh one.

Two possibilities:
1. The guard was added defensively without verification → it's cargo-cult code → delete it.
2. The node IS re-entering the tree somewhere → there's a hidden bug (memory leak: old controller still in tree under a different parent).

I bet #1. Verify with `print("[player_controller] _ready id=%d" % get_instance_id())` for a session.

**Suggested patch:** either:

```gdscript
# Option A — if confirmed single _ready:
_anim_player.animation_finished.connect(_on_anim_finished)
```

or, more robust against rebuild paths:

```gdscript
# Option B — explicit one-shot via CONNECT_PERSIST or guard by lifetime:
_anim_player.animation_finished.connect(_on_anim_finished,
    CONNECT_REFERENCE_COUNTED)  # actually no — use the is_connected guard,
                                 # but ADD A COMMENT explaining WHY.
```

Severity: **LOW** — works, but undocumented defensive code rots.

---

## P2-7 — `_play_anim` central hub will accrete special-cases

**File:** `player_controller.gd:262-288`.

Already two special cases (`_is_punching` guard + fuzzy-fallback fuzzy-match loop). Predictable accretion:
- "but jump anim should preempt walk even though kid is not punching"
- "but hurt anim is one-shot like attack BUT kid can still walk during hurt"
- "but the celebration-emote anim should loop ONCE"

The fuzzy `begins_with` fallback at `:271-274` is doubly dangerous because:
1. `_play_anim("attack")` would match `"attack-melee-right"` from `LOOPING_ANIMS` check below — though `LOOPING_ANIMS` doesn't include "attack", a future addition would silently loop a strike clip.
2. The loop **mutates the `name` parameter**, which is a function-local rebind in GDScript but still a mental-model footgun.

**Suggested patch:** see P1-5 — extract FSM. Short-term, at minimum rename the param to `requested_name` and split fuzzy-fallback into `_resolve_clip_name(requested) -> String` returning empty on miss. Then the loop-flag pass and the punch-guard pass become independent guard-clauses, not interleaved.

Severity: **LOW (now), MEDIUM (in 3 sprints)**.

---

## P2-8 — Divergence: `enemy_controller.gd` does NOT use skeletal animation; will diverge further

**File:** `src/adapters/inbound/gameplay/enemy_controller.gd:65-97`.

EnemyController builds **procedural** `SphereMesh` / `CapsuleMesh` + `StandardMaterial3D` tints. It does NOT load a GLB, does NOT have `_anim_player`, does NOT have an ATTACK_ANIMS list. Hit-flash is a procedural tween on `mat.albedo_color` (`:142-147`). Defeat is a scale-to-zero tween (`:170-176`).

Two separate visual-feedback systems now coexist:

| Concern         | Player                          | Enemy                          |
|-----------------|---------------------------------|--------------------------------|
| Mesh            | Kenney GLB                      | Procedural primitive           |
| Anim            | `_anim_player.play("walk")`     | Procedural velocity drive      |
| Hit reaction    | none (TODO)                     | Material modulate tween        |
| Death           | none (TODO)                     | Scale-to-zero tween            |
| Attack          | 4 skeletal clips, cycled        | Bounce + contact-damage        |

This is **acceptable for now** — enemy is Tier-1 procedural by design — but two things will go wrong:
1. The Muay-Thai phase logic / `CharacterAnimationProfile` (P1-4) will not be reusable by enemy without the same skeletal rig.
2. When we DO swap enemy to a Kenney slime GLB (planned per backlog under "BIG_SLIME boss"), there will be **two implementations** of "play one-shot attack clip then resume movement" — almost certain to diverge in subtle ways (e.g. whether `_is_punching`-equivalent gates HURT state).

**Suggested patch:** factor the skeletal-driver into a shared helper now while there's only one user:

```
src/adapters/inbound/gameplay/skeletal_animator.gd  (extends RefCounted)
   var _anim_player: AnimationPlayer
   var _profile: CharacterAnimationProfile
   var _state: {idle, walking, sprinting, falling, attacking}
   func request_movement(velocity, on_floor, sprinting) -> void
   func request_attack(phase: int) -> void
   func on_clip_finished(name: StringName) -> void
   signal attack_finished
```

`PlayerController` owns one; future `BIG_SLIME` boss owns one. EnemyController for Tier-1 procedural enemies doesn't need it.

Severity: **MEDIUM** — preventive; pay now or pay 3× later.

---

## P3-9 — Hex-arch check: file is clean of domain/application calls (good)

**File:** `player_controller.gd` overall.

Grepping mentally: the only `src/application/` or `src/domain/` reference is `GameModeService` (line 67, `:599`). `GameModeService` is at `src/application/...` — let me confirm.

Actually inbound adapters are **allowed** to call application services (that's the whole point of an inbound port — adapter → application → domain). So `GameModeService` is a legit dependency.

What's MISSING: a port for animation. The Kenney clip names (`"attack-melee-right"` etc.) ARE framework strings hardcoded in an adapter — but that's an adapter-internal concern (adapter ↔ Godot GLB), not a domain leak. **The fix is P1-4** (extract to a Resource), not "add an AnimationPort".

Severity: **NONE** — no hex-arch leak.

---

## P3-10 — Type safety: `_anim_player.get_animation()` may return null

**File:** `player_controller.gd:283-285`, `:456-458`.

```gdscript
var anim := _anim_player.get_animation(name)
if anim != null:
    anim.loop_mode = Animation.LOOP_LINEAR
```

```gdscript
var anim := _anim_player.get_animation(clip)
if anim != null:
    anim.loop_mode = Animation.LOOP_NONE
```

Both call sites correctly nil-check before mutating. The function is guarded by `has_animation(name)` earlier, so in practice `null` should be impossible — but the guard is harmless. Good.

Severity: **NONE** — already safe.

---

## P3-11 — `WALK_VELOCITY_THRESHOLD` constant declared mid-file (line 89), bad style

**File:** `player_controller.gd:89`.

```gdscript
var _character_mesh: Node3D
var _anim_player: AnimationPlayer
var _current_anim: String = ""
const WALK_VELOCITY_THRESHOLD := 0.5    # ← interleaved with var declarations
```

Convention: constants at top of file, then exports, then vars. Move to the const block near `WALK_SPEED` (line 4).

Also: `WALK_VELOCITY_THRESHOLD` is used in two places (`:221`, `:239`) with identical semantics — good, single source of truth. But once `CharacterAnimationProfile` (P1-4) exists, this constant belongs on it: `@export var walk_velocity_threshold: float = 0.5`.

Severity: **LOW (cosmetic)**.

---

## Patch summary (ordered for application)

1. **P0-1** Duplicate animations in `_ready` (`Animation.duplicate()` per clip into the lib). Drop in-place `loop_mode` mutations.
2. **P0-2** Add watchdog timer in `_trigger_punch_animation` to clear `_is_punching`.
3. **P1-3** Delete `PUNCH_LEAN_RAD`, `PUNCH_FORWARD_PUSH`, `PUNCH_DURATION`, `_punch_tween` + stale comments.
4. **P1-4** Extract `CharacterAnimationProfile` Resource; replace `ATTACK_ANIMS` + `LOOPING_ANIMS` consts + relevant magic numbers.
5. **P2-6** Either delete `is_connected` guard with audit, or add `# WHY` comment.
6. **P1-5 / P2-7** Extract `PlayerAnimationState` RefCounted helper (Phase 1) → migrate to `AnimationTree` (Phase 2).
7. **P2-8** Extract `SkeletalAnimator` helper before enemy needs it.
8. **P3-11** Move `WALK_VELOCITY_THRESHOLD` to const block (folded into P1-4).

---

Report by Adv Z, ready for synthesis.
