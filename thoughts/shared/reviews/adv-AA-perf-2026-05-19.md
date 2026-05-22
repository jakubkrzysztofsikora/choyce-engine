# Adv AA Perf Review — player_controller.gd + gameplay_runtime.gd

Target: 60 fps M2 Max + tablet. Hot paths fire 60Hz. Hostile audit.

## Critical

### C1. `_physics_process` allocates `PhysicsRayQueryParameters3D` + raycast every tick (build mode), and BlockKind catalog walked every tick
`_update_ghost_preview` runs every physics tick. In BUILD mode it:
- Calls `_build_raycast()` → `PhysicsRayQueryParameters3D.create()` allocates a RefCounted **every frame** (line 641).
- Issues `space.intersect_ray()` — physics query per frame.
- Walks `BlockKind.default_catalog()` **every frame** (line 572-577) to recolor ghost material. Catalog is static — color should be cached on `_active_slot` change, not rebuilt 60×/sec.

**Fix:**
```gdscript
# In setup_build_grid + hotbar slot change:
_active_block_color = _lookup_color(_hotbar[_active_slot])
# In _update_ghost_preview: just assign _ghost_material.albedo_color = _active_block_color
```
And cache one shared `PhysicsRayQueryParameters3D` instance, mutate `.from`/`.to` each frame instead of `create()`.

### C2. `ProjectSettings.get_setting("physics/3d/default_gravity")` called every physics tick (line 140)
`get_setting` is a string-keyed Variant lookup with type cast. Hit 60×/sec for the player and again 60×/sec for any enemy that does the same. Cache in `_ready`:
```gdscript
@onready var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity") as float
```

## High

### H1. `Vector2(velocity.x, velocity.z).length()` computed twice per tick
Line 217 (anim drive) + duplicated in `_on_anim_finished` (line 235). And the `sqrt` is unnecessary — compare against `WALK_VELOCITY_THRESHOLD * WALK_VELOCITY_THRESHOLD` with `length_squared()`. Saves ~60 sqrt/sec just for the player.

### H2. `_update_muay_thai_idle` writes `_character_mesh.rotation.x/.z` every tick even in non-COMBAT mode
Lines 481-482: when not in combat, the function still lerps both axes toward 0 every frame. Once `rotation.x` is `< 0.0001` away from 0, writing it dirties the transform and triggers parent-child traversal. **Gate on `abs(rotation.x) + abs(rotation.z) > epsilon`** before writing; snap to 0 and early-return otherwise.

Also: `_ensure_game_mode_service()` + `current_mode(active_kind)` is invoked **twice per tick** (here + in `_update_ghost_preview` lines 554/586). Resolve mode **once** in `_physics_process` and pass into both.

### H3. `String(_hotbar[_active_slot])` cast every tick (twice)
Lines 474 and 553. Cache `_active_kind: String` field, update only on `_active_slot` change.

### H4. `_anim_player.get_animation(name)` + `anim.loop_mode = LOOP_LINEAR` written every `_play_anim` call
Line 281-286 loops through `LOOPING_ANIMS` and re-assigns `loop_mode` every time `_play_anim` switches to idle/walk/sprint. `_play_anim` is called every tick (line 223). Although guarded by `_current_anim == name`, when transitioning idle↔walk↔sprint the `get_animation` + `loop_mode =` runs each transition. **Set `loop_mode = LOOP_LINEAR` once in `_ready` for the 4 looping clips** instead.

### H5. `Animation.LOOP_NONE` set on every swing (line 458)
`_trigger_punch_animation` re-writes `anim.loop_mode = LOOP_NONE` on every LMB. Kenney attack clips already import as LOOP_NONE. Set once in `_ready`, drop from the hot path.

### H6. Tween allocated **twice per swing** in `_perform_attack`
Line 379 spawns mesh-squash tween, line 388 calls `_trigger_punch_animation` which kills/recreates `_punch_tween` even though the new skeletal-clip path no longer needs a tween (the proc rotation code was removed; the kill is residual). **Drop `_punch_tween` field + its kill block (lines 431-435)** — dead code path. The mesh-squash tween is unavoidable per-swing but only fires on cooldown (≥ 0.4s apart) so it's tolerable; consider pooling later.

## Medium

### M1. `animation_finished` fires on looped clips in Godot 4
Verified: Godot 4 emits `animation_finished` once per loop completion for `LOOP_LINEAR` clips. With idle/walk looped at ~1s, callback runs ~1×/sec doing string casts (`String(finished_name)`, `in ATTACK_ANIMS`) — small but pure waste. **Guard early with `if not _is_punching: return`** so the loop completions of idle/walk are no-ops.

### M2. `_check_enemy_wave_respawn` iterates `_enemy_root.get_children()` every physics tick (gameplay_runtime.gd:1008)
Linear scan of all enemy nodes every 16.6ms just to check "is anyone alive". Track a counter via signal: `enemy_defeated` decrements `_live_enemy_count`; check `if _live_enemy_count > 0` is O(1).

### M3. `_spawn_damage_number` allocates `Label3D` + new tween per hit (gameplay_runtime.gd:340)
Boss fight = many hits/sec → garbage churn. Pool 8 Label3Ds; rotate. Each `queue_free()` defers cleanup to end-of-frame and adds main-thread work.

### M4. Hit-stop `Engine.time_scale = 0.15` (gameplay_runtime.gd:329)
Affects all physics + tweens globally. The damage-number tween and player squash tweens slow down during hit-stop, then snap. Acceptable for 40-80ms but document — and **make sure the timer's `ignore_time_scale=true`** (it is, line 331).

## Low

### L1. `is_processing()` guard inside `_physics_process` (line 124)
The engine already skips `_physics_process` when processing is off via `set_physics_process(false)`. The check is for `set_process(false)` (process vs physics_process are separate); harmless but misleading.

### L2. `_audio_bus.emit_sfx` per damage number / collect — no batching
Multiple simultaneous hits queue multiple SFX events. Not a hot path per se, but watch in waves.

---

## Minimal patch — top 3 wins

```gdscript
# C1 + H3: cache active block + reuse ray params
var _active_kind: String = ""
var _active_block_color: Color = Color(1,1,1,0.4)
var _ray_params: PhysicsRayQueryParameters3D = null

func _set_active_slot(i: int) -> void:
    _active_slot = i
    _active_kind = String(_hotbar[i]) if i < _hotbar.size() else ""
    for k in BlockKind.default_catalog():
        if (k as BlockKind).block_id == _active_kind:
            _active_block_color = (k as BlockKind).color
            _active_block_color.a = 0.45
            break
    hotbar_changed.emit(i, _hotbar[i])

# C2: cache gravity
@onready var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity") as float
# in _physics_process replace ProjectSettings.get_setting(...) with _gravity

# H1: kill the sqrt
var horiz_sq := velocity.x * velocity.x + velocity.z * velocity.z
var want := "idle"
if not is_on_floor():
    want = "fall"
elif horiz_sq > WALK_VELOCITY_THRESHOLD * WALK_VELOCITY_THRESHOLD:
    want = "sprint" if is_sprinting else "walk"

# H4 + H5: set loop_mode once in _ready
for clip in LOOPING_ANIMS:
    var a := _anim_player.get_animation(clip)
    if a: a.loop_mode = Animation.LOOP_LINEAR
for clip in ATTACK_ANIMS:
    var a := _anim_player.get_animation(clip)
    if a: a.loop_mode = Animation.LOOP_NONE
```

Estimated steady-state savings: ~3-5% main thread per player on M2 Max, more on the tablet where the GC + transform-dirty cost dominates.

Report by Adv AA, ready for synthesis.
