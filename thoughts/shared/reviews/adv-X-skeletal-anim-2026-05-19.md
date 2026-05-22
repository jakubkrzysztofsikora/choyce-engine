# Adversary X — Skeletal Punch Animation Review
File: `src/adapters/inbound/gameplay/player_controller.gd`
Date: 2026-05-19

## Critical

### C1 — Shared `Animation` resource mutation poisons all PlayerController instances and any other AnimationPlayer sharing the GLB
**Where:** `player_controller.gd:281-286` (LOOP_LINEAR force) and `:456-458` (LOOP_NONE force).
**Bug:** `_anim_player.get_animation(name).loop_mode = …` mutates the underlying `Animation` resource shared across every instance loaded from the same Kenney GLB. The first idle write flips loop_mode → LOOP_LINEAR. The first attack write flips it → LOOP_NONE. After one punch any other instance reading `idle` gets whatever the last writer set. With one player today this is silent; the moment we add an enemy that reuses the Kenney rig, or hot-reload the scene, idle stops looping or attacks loop forever. Worse, `_on_anim_finished` only fires on non-looping clips — if an idle clip got promoted to LOOP_LINEAR globally, then later `_trigger_punch_animation` writes LOOP_NONE onto the *attack* animation, but the moment _play_anim writes LOOP_LINEAR on "idle" right after (which has the same begins_with match) we never get animation_finished and `_is_punching` sticks forever.
**Fix:**
```gdscript
# at _ready, after _anim_player resolution:
for a in _anim_player.get_animation_list():
    var anim := _anim_player.get_animation(a)
    if anim != null:
        anim.resource_local_to_scene = true
        var lname := String(a).to_lower()
        for loop_name in LOOPING_ANIMS:
            if lname.begins_with(loop_name):
                anim.loop_mode = Animation.LOOP_LINEAR
        if a in ATTACK_ANIMS:
            anim.loop_mode = Animation.LOOP_NONE
# then drop the per-play mutations at :281-286 and :456-458.
```

### C2 — `_is_punching` flag leaks forever when attack is interrupted (no defeated-state, scene-change, or interrupting-non-attack guard)
**Where:** flag set `:437`, cleared only in `_on_anim_finished` (`:233`) when `finished_name in ATTACK_ANIMS`.
**Paths that strand the flag:**
1. `apply_damage_from_enemy` → `_health.apply_damage` → `player_defeated.emit()` (`:510`). Nothing stops the AnimationPlayer or resets `_is_punching`. Player can die mid-punch; on respawn (`spawn_at` `:354`) the flag is still true → `_play_anim` early-return at `:267` blocks `idle/walk/sprint/fall` forever.
2. `gameplay_runtime` sets `set_process(false)` on the controller (`:95`). `_physics_process` stops, but `_anim_player` keeps running on the SceneTree. If the runtime tears down the player between attack play and finished signal, no clip emits anything Godot can route, and on next spawn the flag persists.
3. Rapid LMB on the next attack starts a new clip via `_anim_player.stop()` + `play(new)` (`:459-460`). Per Godot 4.6 docs `stop()` does **not** emit `animation_finished` — but `play()` of a different clip can; the emission is **for the previously-playing clip name** = the prior ATTACK_ANIMS entry → flag is cleared *while the new clip is just starting*. See C3.
**Fix:** clear in `spawn_at`, on `player_defeated`, and add a safety watchdog:
```gdscript
func spawn_at(pos: Vector3) -> void:
    _is_punching = false
    _current_anim = ""
    if _punch_tween != null and _punch_tween.is_valid():
        _punch_tween.kill()
    ...

func _physics_process(delta: float) -> void:
    ...
    if _is_punching and _anim_player != null and not _anim_player.is_playing():
        _is_punching = false  # watchdog
```
And bail out of `_trigger_punch_animation` if `_health == null or not _health.is_alive`.

### C3 — `_anim_player.stop()` then `play(new_clip)` clears `_is_punching` for the just-started attack
**Where:** `:459-460` inside `_trigger_punch_animation`.
**Bug:** In Godot 4.6, calling `play(other_clip)` while a clip is mid-flight emits `animation_finished` **for the previous clip** before the new clip starts ticking. The previous clip is *also* in `ATTACK_ANIMS` (rapid LMB cycles through phases) → `_on_anim_finished` fires with the *prior* phase name, sees it in `ATTACK_ANIMS`, sets `_is_punching = false`, calls `_play_anim("walk")` which now passes the gate at `:267` and clobbers `_current_anim` with `walk`. Net result: every rapid second-punch is overwritten by walk mid-animation; the kid sees the swing *visually cancel*.
**Fix:** suppress the finished handler for self-induced overrides:
```gdscript
var _suppress_anim_finished_for: String = ""
...
func _trigger_punch_animation() -> void:
    ...
    if _anim_player.is_playing():
        _suppress_anim_finished_for = String(_anim_player.current_animation)
    _anim_player.stop()
    _anim_player.play(clip)
    _current_anim = clip

func _on_anim_finished(finished_name: StringName) -> void:
    var name_str := String(finished_name)
    if name_str == _suppress_anim_finished_for:
        _suppress_anim_finished_for = ""
        return
    if name_str in ATTACK_ANIMS:
        _is_punching = false
        ...
```

## High

### H1 — `_update_muay_thai_idle` fights every non-combat attack-finish handler write to `_character_mesh.rotation`
**Where:** `_trigger_punch_animation` writes `_character_mesh.rotation = Vector3(0, PI, 0)` (`:434`). `_update_muay_thai_idle` (`:481-490`) writes `rotation.x` and `rotation.z` every physics tick on Node3D level. The skeletal attack clip animates **bones**, not the Node3D wrapper — so the wrapper-level pitch/roll set by `_update_muay_thai_idle` (when in COMBAT) is *added on top of* the bone animation. During an attack swing `_is_punching == true` correctly guards the idle handler (`:469`), but the *moment* `_on_anim_finished` clears the flag, the next physics tick lerps `_character_mesh.rotation.x` from 0 → 0.10 (forward lean). The lerp factor `MUAY_THAI_POSE_LERP * delta` = 6.0 × 0.016 ≈ 0.096 per frame; visible pop.
**Also:** when in BUILD mode (`combat == false`), the `_character_mesh.rotation.y` is left at PI but `.x/.z` are lerped to 0 — fine. But the *attack* path forces `rotation = Vector3(0, PI, 0)`, zeroing pitch/roll mid-game; on the very next tick the muay-thai idle lerps right back. The kid sees the stance pop on/off per punch.
**Fix:** don't write `.rotation = Vector3(0, PI, 0)` at `:434`. Just zero the position. Let the bone clip do its job and the muay-thai idle reapply pitch/roll smoothly.

### H2 — `_perform_attack` mesh-squash Tween leaks if `_character_mesh` is freed mid-tween
**Where:** `:378-383`. The tween targets `_character_mesh.scale`. The Tween is local (no `_punch_tween` reference held). If `gameplay_runtime` queue_frees the player or the mesh between the first tween_property and the second, the tween's next step calls `set("scale", …)` on a freed object → "Invalid call. Nonexistent function 'set' in base 'previously freed'". Tweens auto-bound to the freed node should be killed; without holding the reference there's no way.
**Fix:**
```gdscript
var _attack_squash_tween: Tween = null
...
if _attack_squash_tween != null and _attack_squash_tween.is_valid():
    _attack_squash_tween.kill()
_attack_squash_tween = create_tween()
_attack_squash_tween.bind_node(_character_mesh)  # auto-kills on free
_attack_squash_tween.tween_property(_character_mesh, "scale", ...)
```

### H3 — `_play_anim` fuzzy-fallback overwrites the parameter `name` and the LOOPING_ANIMS check uses the *resolved* name, not the requested one
**Where:** `:269-276` then `:281-286`.
**Bug:** if you ask for `"walk"` but the GLB has `"walking-cycle"`, the fuzzy fallback at `:272` sets `name = "walking-cycle"`. The LOOPING_ANIMS loop then checks `"walking-cycle".to_lower().begins_with("idle"|"walk"|"sprint"|"static")` → matches `walk` → ok. But the *opposite* case: if the kid is sprinting and the GLB has `"sprint-fast"`, fine. But the `_on_anim_finished` callback compares `finished_name in ATTACK_ANIMS` (`:232`) using the *raw* clip names. If a Kenney variant ships `"attack-melee-right-v2"`, the fuzzy fallback at `_play_anim` won't even fire because `_trigger_punch_animation` calls `_anim_player.play(clip)` directly (`:460`) without `_play_anim`. The finished signal then emits `"attack-melee-right-v2"`, which is NOT in `ATTACK_ANIMS`, so `_is_punching` never clears. → permanently stuck.
**Fix:** route attacks through the same fuzzy resolver, and store the actually-resolved name:
```gdscript
func _resolve_anim(name: String) -> String:
    if _anim_player.has_animation(name):
        return name
    for a in _anim_player.get_animation_list():
        if String(a).to_lower().begins_with(name.to_lower()):
            return String(a)
    return ""

var _active_attack_clip: String = ""
...
func _trigger_punch_animation() -> void:
    ...
    var clip := _resolve_anim(ATTACK_ANIMS[phase])
    if clip == "":
        # try every entry...
    _active_attack_clip = clip
    _anim_player.play(clip)

func _on_anim_finished(finished_name: StringName) -> void:
    if String(finished_name) == _active_attack_clip:
        _active_attack_clip = ""
        _is_punching = false
        ...
```

## Medium

### M1 — `animation_finished` connection in `_ready` is technically guarded but `_ready` runs on every scene re-enter
**Where:** `:120-121`. The `is_connected` guard *does* prevent double-connect on `_ready` re-fire. Good. BUT: if anyone manually `disconnect()`s and reconnects with `CONNECT_ONE_SHOT` later, the guard checks the wrong overload. Not a current bug, just a footgun. Lower-priority.

### M2 — `_punch_phase` increments forever (`:439`) — `int` will wrap at 2^63 (practically never), but `% ATTACK_ANIMS.size()` at `:438` uses pre-increment. Fine logically. Note: `_punch_phase` is never reset on respawn → after death the kid resumes the rotation mid-cycle. Cosmetic.

### M3 — `_current_anim` set to `clip` at `:461` after `_anim_player.play(clip)`, but if `_play_anim("walk")` runs in the same physics tick (e.g. `_physics_process` `:223`), the `_current_anim == name` guard at `:263` will not match `walk`, so it'll re-issue `play("walk")` — except the `_is_punching` gate at `:267` blocks it. Correct under happy path. Under C3 path however, `_current_anim` is left as the attack clip after `_on_anim_finished` resets `_current_anim = ""` at `:234`. Combined with the suppression fix in C3, ensure ordering: clear `_current_anim` only when actually restoring movement, not on suppressed finishes.

### M4 — `LOOPING_ANIMS` substring match: `"sprint"` matches `"sprint-fast"`, fine. But `"static"` matches `"static_pose_t_001"` (Kenney often ships T-pose). If the GLB has a static frame named `"static-tpose"` and someone calls `_play_anim("static")` (no current caller does, but it's in the const) → silently flipped to LOOP_LINEAR → T-pose locked permanent. Defensive: drop `"static"` from `LOOPING_ANIMS` since no caller uses it.

## Low

### L1 — `_health.tick` and `hp_changed.emit` at `:170-171` emit *every* physics tick (60 Hz). Not animation-related but adjacent. Drop into the H signal-burden if it shows up in profiler.

### L2 — `_trigger_punch_animation` `:434` writes `_character_mesh.rotation = Vector3(0, PI, 0)` — but Kenney character mesh already had rotation.y = PI set at `_ready` `:113`. Redundant unless muay-thai stance tilted it; H1 fix removes the need.

### L3 — No `_exit_tree` / `_notification(NOTIFICATION_PREDELETE)` disconnects `animation_finished`. Godot 4.6 auto-disconnects on node free, so usually safe; but `_anim_player` is a *child of `_character_mesh`*, not of `self`. If `_character_mesh` is freed but PlayerController persists (it shouldn't, but `gameplay_runtime` shuffles scenes), the connection survives onto a freed AnimationPlayer → next signal raises. Add explicit disconnect in `_exit_tree`.

## Suggested patch ordering
1. C1 (resource_local_to_scene) — eliminates the silent global state corruption.
2. C3 (suppression flag) — prevents the rapid-LMB attack cancel.
3. C2 (spawn_at + watchdog) — closes the stuck-punching paths.
4. H3 (resolved-name tracking) — fixes variant-GLB stranding.
5. H1 (drop rotation override) — fixes the stance-pop visual.
6. H2 (bind_node on squash tween) — closes the free-during-tween crash.

Report by Adv X, ready for synthesis.
