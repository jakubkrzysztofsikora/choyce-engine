# Adv Y — Fight Feel Audit (Post-Kenney-Skeletal Switch)

**Date:** 2026-05-19
**Reviewer:** Adversary Y — kid UX / game-feel specialist
**Audience target:** 7-year-old Roblox/Minecraft fluent player
**Scope:** punch/melee combat feel after two recent fixes (mesh-only squash + Kenney
skeletal `attack-melee-*` / `attack-kick-*` clips)
**Files audited:**
- `src/adapters/inbound/gameplay/player_controller.gd` (`_perform_attack` L372,
  `_trigger_punch_animation` L426, `_on_anim_finished` L230)
- `src/adapters/inbound/gameplay/gameplay_runtime.gd` (`_apply_hit_stop` L329,
  `_spawn_damage_number` L340, `_on_enemy_damaged` L445, `_on_enemy_defeated` L458,
  crosshair build L925-948)
- `src/adapters/inbound/gameplay/enemy_controller.gd` (`apply_damage` L128)

## Verdict in one line

You moved the squash off the camera and you swapped a 2-bone wrapper-rotation hack
for real skeletal clips. Camera no longer wobbles. The fighter now has arms.
**Congratulations — you fixed two things and ignored the other eight that actually
sell a hit.** The user told you "barely visible, wouldn't call it fighting." You
heard "fix the animation" and skipped "fix the **impact**." This is still not
fighting. This is a doll waving its arm while a tinted pink square wiggles.

---

## CRITICAL — these are why it still doesn't read as a punch

### C1. Hit-stop fires on **kill**, not on **hit-connect**. (`gameplay_runtime.gd` L445-455 vs L469)

`_on_enemy_damaged` (every successful swing landing on an alive enemy) runs:

```
_screen_feedback.shake(3.0, 0.06)
_audio_bus.emit_sfx("collect", position)
```

That's it. **No `_apply_hit_stop`.** Hit-stop only runs in `_on_enemy_defeated`
(L469), so the kid feels impact **once per dead slime** — i.e. every 4-8 swings
in normal play. The other 80% of swings have zero time-scale dip. This is the
single biggest reason punches feel like mosquito slaps. Mick Hofman / Jan Willem
Nijman: hit-stop is **the** signature of a punch landing. A 30-50 ms freeze on
connect would do more for fight feel than every other item on this list combined.

**Fix:** add `_apply_hit_stop(0.035)` inside `_on_enemy_damaged` at L454, before
the SFX call. Boss/kill keeps its 0.08s on top.

### C2. Hit SFX is `"collect"`. Literally the pickup sound. (`gameplay_runtime.gd` L454, L455, L467)

Line 454 — **landing a punch plays the loot-pickup chime.** Line 467 — defeat plays
the same chime. There is no whoosh on swing-start, no thud on connect, no enemy
grunt, no impact crunch. Single sample, identical pitch every swing. With 4
animation phases playing identical "ding!" the brain reads it as "I picked up an
item" not "I HIT something."

**Fix:** add SFX keys `"swing_whoosh"`, `"punch_impact"`, `"enemy_grunt"`. Layer:
- `_perform_attack` (L372): `_audio_bus.emit_sfx("swing_whoosh", global_position)`
  unconditionally (every swing — hit or miss).
- `_on_enemy_damaged` (L454): `emit_sfx("punch_impact", position)` **+**
  `emit_sfx("enemy_grunt", position)` with `pitch_scale = randf_range(0.92, 1.10)`
  per call. `sfx_player.gd` will need a `pitch_variance` param if it doesn't
  already accept one.

### C3. Enemy hit-flash is **pink**, not white/red, and it tweens away over 180ms instead of snapping. (`enemy_controller.gd` L141-147)

```
mat.albedo_color = Color(1.0, 0.85, 0.85)
var tween := create_tween()
tween.tween_property(mat, "albedo_color", original_color, 0.18)
```

`(1.0, 0.85, 0.85)` on a green slime = "slightly less green." Invisible at speed.
And tweening it away over 180ms means the peak brightness lasts **one frame** —
the rest is fade. The kid eye registers "snap to white, hold, snap back" as a
hit. Smooth tweens register as nothing.

**Fix:** snap to pure white `Color(1.5, 1.5, 1.5)` (over-1.0 if material allows
HDR; otherwise pure `Color.WHITE`) for **80 ms held**, then snap back in **one
frame**. No tween. Replace L142-147 with:

```gdscript
if _mesh != null and _mesh.material_override is StandardMaterial3D:
    var mat: StandardMaterial3D = _mesh.material_override
    var original_color := mat.albedo_color
    mat.albedo_color = Color.WHITE
    mat.emission_enabled = true
    mat.emission = Color.WHITE
    mat.emission_energy_multiplier = 1.5
    var tw := create_tween()
    tw.tween_interval(0.08)
    tw.tween_callback(func() -> void:
        mat.albedo_color = original_color
        mat.emission_energy_multiplier = 0.0
    )
```

(Emission spike is what your eye actually reads as "WHACK.")

### C4. Camera shake on hit is omnidirectional, 3.0 amplitude, 60 ms — invisible. (`gameplay_runtime.gd` L453)

```
_screen_feedback.shake(3.0, 0.06)
```

60 ms at amplitude 3.0 is **two camera frames** of shimmy. Defeat shake (L466)
is 5.0 / 120 ms — 4x stronger per-hit than per-kill is wrong. **Per-hit needs to
be the loud one** because it fires every swing; kill is the rarer payoff and can
stay punchy.

Also: shake is symmetric. A punch in Doom/Halo nudges the camera **toward the
hit direction** — directional kick. Without it, all hits feel the same regardless
of which side you swung.

**Fix:** bump per-hit to `shake(5.0, 0.10)`. If `screen_feedback.gd` supports a
direction vector, pass `(_player_controller.global_position - position).normalized()`
so the kick is directional. If it doesn't — add it, this is a one-day feature.

---

## HIGH

### H1. Damage number is static — pops up, drifts, fades. No scale-bounce. (`gameplay_runtime.gd` L340-357)

```
tw.tween_property(lbl, "global_position", lbl.global_position + Vector3(0, 1.2, 0), 0.9)
tw.tween_property(lbl, "modulate:a", 0.0, 0.9).set_delay(0.2)
```

Two property tweens. Drift up + fade. Where's the **POP**? Every juicy ARPG /
mobile game scales the label `0 → 1.4 → 1.0` over 80-120 ms with `TRANS_BACK` /
`EASE_OUT` so the number **slams into existence** then settles. Right now it just
appears.

**Fix:** in `_spawn_damage_number` after `add_child(lbl)`, before the existing
tween:

```gdscript
lbl.scale = Vector3(0.2, 0.2, 0.2)
var pop := create_tween()
pop.tween_property(lbl, "scale", Vector3(1.4, 1.4, 1.4), 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
pop.tween_property(lbl, "scale", Vector3.ONE, 0.10)
```

Boss numbers should pop bigger — already have `is_boss` plumbing, use it for
scale target too (`1.8` for boss).

### H2. No swing-start whoosh, so misses are silent and invisible. (`player_controller.gd` L372)

Swings on empty air do **nothing** audibly or visibly. A 7yo can't tell if their
LMB even registered when no enemy is in the cone. The mesh squash (L378-383) is
cosmetic but tiny — `(1.08, 0.94, 1.08)` for 60ms — and the Kenney clip plays
but without a whoosh trail the **air swing feels broken, not weak**. Kid will
think the button is broken.

**Fix:**
- Add `_audio_bus.emit_sfx("swing_whoosh", global_position)` at top of
  `_perform_attack` (L373, after cooldown set, before tween).
- Spawn a brief curved arc particle / Line3D in the swing direction via
  `_effect_spawner` so a missed swing **shows the arc** in front of the kid.

### H3. Hit-stop happens *after* the swing has resolved damage. Off by 1-2 frames. (`player_controller.gd` L388-411 → `gameplay_runtime.gd` L329)

Right now `_trigger_punch_animation` plays the clip *and* damage is applied
*in the same frame as input*. Hit-stop should fire **on the impact frame of the
animation** — i.e. ~50-80 ms into the Kenney clip when the fist is fully
extended. Firing it on input frame means the freeze happens **before the fist
has moved**, so the freeze looks like "game lagged" rather than "fist
connected."

**Fix (medium difficulty):** Either:
- Read the Kenney clip's likely impact-frame timing (eyeball it via Blender or
  the Godot animation panel — probably ~0.10s into a ~0.30s clip) and defer
  the damage application + hit-stop via `get_tree().create_timer(0.10).timeout`
  in `_perform_attack`. Or
- Add an animation track call-method `_on_punch_impact_frame` to each Kenney
  clip via `_anim_player.get_animation(clip).add_track(...)` once at setup,
  pointing at the impact frame.

The second is the right answer long-term. The first is the 1-hour pragmatic
patch and gets you 80% of the feel.

### H4. Crosshair is a static white plus-sign. No swing pulse, no enemy-hover color shift. (`gameplay_runtime.gd` L925-948)

`crosshair_h` and `crosshair_v` are `ColorRect.new()` with fixed
`Color(1, 1, 1, 0.8)` and a `custom_minimum_size`. Nothing scales on swing,
nothing tints when the kid is looking at an enemy in range. In a kid shooter
the crosshair is the **biggest hit-confirmation signal** because it's at
screen-center where the kid's eye lives.

**Fix:**
- On `attack` action just-pressed, scale the crosshair `1.0 → 1.6 → 1.0` over
  150 ms — wire from `_perform_attack` or via `player.attacked` signal that
  `gameplay_runtime` already listens for.
- Add a per-physics-frame raycast from camera through screen-center; if it hits
  an EnemyController inside `ATTACK_RANGE`, tint crosshair `Color(1.0, 0.4, 0.4)`
  (red); else white. This is the "lock-on" feedback that lets a 5yo know "if I
  click now I will hit something."

### H5. Phase variety doesn't read because all 4 clips trigger identical SFX, shake, and damage. (`player_controller.gd` L252-257 + `gameplay_runtime.gd` L445-455)

You cycle jab/cross/kick-r/kick-l in `ATTACK_ANIMS`. But the kick should
**feel different**: louder thud, bigger shake, bigger knockback. Right now the
runtime has no idea which phase fired — `attacked.emit(damage, hit_point)` (L393)
doesn't pass phase info. So all 4 clips read as "the kid swung" and the visual
variety is lost.

**Fix:** Extend the `attacked` signal payload (or add a sibling signal
`attacked_with_phase`) to include `_punch_phase`. In `_on_enemy_damaged`:
- phase 0/1 (punches): current 5.0 shake, 0.035 hit-stop, "punch_impact" SFX.
- phase 2/3 (kicks): 7.0 shake, 0.06 hit-stop, "kick_impact" SFX, **2x knockback**
  passed through to `enemy.apply_damage` (or via a second arg to it).

Without this, the user is right — "it all blurs into swing."

---

## MEDIUM

### M1. Enemy knockback is barely-perceptible. (`enemy_controller.gd` L138-140)

```
velocity = away * 6.0
velocity.y = 3.0
```

6.0 m/s horizontal for a `_hurt_remaining = 0.2`s state = **1.2 m of total
travel** before the hurt state clears and behavior resumes. A green slime is
~0.6m tall. Kid sees it scoot one body-length sideways — easy to miss in motion.

**Fix:** Bump to `away * 10.0`, `velocity.y = 4.5` for non-boss; extend
`_hurt_remaining` to `0.28`s so the slide is more visible. For kicks (see H5),
double these.

### M2. No squash on the enemy when it's hit. (`enemy_controller.gd` L128-150)

Player gets a `_character_mesh` squash on swing-start (L378-383 in
`player_controller.gd`). Enemy gets a tint flash. **Why doesn't the enemy
squash when hit?** A vertical squash + horizontal stretch on impact reads as
"OOF" to a 5yo at a glance, no text needed.

**Fix:** In `apply_damage` (L141-147) just after the white-flash snap,
parallel-tween `_mesh.scale` `(1.0, 1.0, 1.0) → (1.3, 0.65, 1.3) → (1.0, 1.0, 1.0)`
over 60ms+120ms. `TRANS_BACK / EASE_OUT` on the return.

### M3. `ATTACK_COOLDOWN = 0.4s` is fine for first-swing (correctly 0 on game-start, L176) but the gating for **combos** kills the Muay-Thai-combo readability. (`player_controller.gd` L28, L373)

The 4-phase cycle (`ATTACK_ANIMS`) implies a combo. But 0.4s between swings
means the cycle completes in 1.6s total — a kid clicking rapid LMB sees the
input rejected on swings 2/3/4. **The cycle needs to be combo-able: each next
swing within 0.3s after the previous gets a shortened cooldown so jab → cross
→ kick lands as a flurry.**

**Fix:** Add a combo window. Track `_last_swing_time`; if `now - _last_swing_time <
0.5` then the cooldown after the swing is `0.18` instead of `0.4` — but only for
the next 2 swings. After phase 3 (kick-left), enforce a hard 0.6s "recovery"
so the kid can't infinitely cheese. Combo: fast → fast → fast → slow recovery.
This is *Smash Bros / God of War 101* and it works on 7yos.

### M4. Squash tween on punch is **so small** it's invisible at speed. (`player_controller.gd` L378-383)

`Vector3(1.08, 0.94, 1.08)` — 8% squash, 60ms, then `TRANS_BACK / EASE_OUT`
back over 160ms. At 60fps that's 4 visible frames at peak. 8% on a small
3rd-person mesh is **nothing**.

**Fix:** Bump to `(1.18, 0.86, 1.18)` over 80ms. The squash sells the wind-up
and matches the Kenney skeletal swing arc.

---

## LOW

### L1. Damage number color doesn't differentiate phase. (`gameplay_runtime.gd` L349)

`Color(1.0, 0.9, 0.5)` for non-boss is a sandy yellow. Fine for a punch. A kick
landing for higher damage should be a different color — e.g. orange `(1.0, 0.5, 0.2)`.
Tied to H5 (passing phase through). Reads as "different attack mattered."

### L2. Crosshair has no swing-arc trail visualization. (`gameplay_runtime.gd` L925-948)

Could add a faint semi-circle ColorRect/Line2D that pulses outward on swing,
matching the `ATTACK_ARC_RADIANS` cone. Tells the kid "this is the area you
just hit." Nice-to-have, not a blocker.

### L3. `_apply_hit_stop` uses `Engine.time_scale = 0.15` — affects ALL nodes including UI tween animations and audio playback. (`gameplay_runtime.gd` L330)

Damage-number tweens (`_spawn_damage_number`) and the punch SFX itself are
affected by `time_scale`. The "thud" gets pitched down for the duration of the
freeze, then snaps back — actually this *helps* feel (it's a free pitch-drop on
impact) but be aware. If any audio is `bus = "UI"` and should be unaffected, set
`audio_bus_layout` channels appropriately. Document this — or someone else will
"fix" it later and remove the bug-as-feature.

### L4. Mesh squash uses `_character_mesh` but `_character_mesh.position = Vector3.ZERO` is reset in `_trigger_punch_animation` (L435). Reset happens before squash tween fires (`_perform_attack` calls squash THEN `_trigger_punch_animation`). Actually verified ordering L378-388 — squash starts at L379, animation reset at L435. So squash tween starts on a mesh whose position is about to be reset by the next call. Tween targets `scale` not `position`, so no actual conflict — but it's fragile. (`player_controller.gd` L372-388, L426-435)

Document the ordering or refactor — future-you will introduce a tween on
mesh.position and silently lose it.

---

## What the 7yo will say in playtest

> "Did I hit it? It didn't really do anything."

That's verbatim what kids say when:
1. There's no hit-stop on connect (C1).
2. The hit sound is the same as picking up coins (C2).
3. The enemy doesn't visibly react beyond a tint (C3).
4. The crosshair doesn't confirm the hit (H4).

Fix C1, C2, C3, H4 first — those are the four pillars of "yes I hit it."
Everything else is polish on top.

## Recommended fix order (1 sprint of work, ranked by impact-per-hour)

1. C1 — add `_apply_hit_stop(0.035)` in `_on_enemy_damaged` — **5 minutes, biggest single win.**
2. C2 — proper SFX keys + pitch variance — **2 hours including audio asset hunt.**
3. C3 — emission-spike white flash with hold + snap-back — **30 minutes.**
4. H1 — damage-number scale-pop — **15 minutes.**
5. H4 — crosshair pulse + enemy-hover red tint — **2 hours.**
6. C4 — directional shake on hit — **1 hour if screen_feedback supports vector arg.**
7. H5 — phase-aware feedback (kicks > punches) — **3 hours, needs signal extension.**
8. M3 — combo-window cooldown — **2 hours, design + test.**
9. Rest — **half a day total.**

Two full days of work. Ten times the perceived combat quality. The skeletal clip
swap got you the **animation**; this work gets you the **fight**.

---

Report by Adv Y, ready for synthesis.
