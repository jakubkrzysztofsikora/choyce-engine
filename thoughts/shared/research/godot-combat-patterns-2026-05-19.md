# Godot Combat Patterns Research
_2026-05-19 - Architecture & Review Specialist_

Target: 7yo Roblox/Minecraft player. Existing stack: CharacterBody3D + slime/bouncer FSM + 1.8m sword arc + HP/iframes.

---

## Sources Evaluated

| # | Project | License | Godot 4? | Usable? |
|---|---------|---------|----------|---------|
| 1 | gdquest-demos/godot-4-hitbox-hurtbox | MIT | Yes | Yes |
| 2 | gdquest-demos/godot-4-juicy-attack | MIT | Yes | Yes |
| 3 | Snaiel/Godot4ThirdPersonCombatPrototype | MIT | Yes | Yes (patterns only) |
| 4 | haowg/GODOT-VFX-LIBRARY | MIT | 4.5+ | Yes |
| 5 | kidscancode AnimationTree recipe | CC-BY/public | Yes | Yes |
| 6 | godot-docs mob spawner | MIT | Yes | Yes |
| 7 | Brotato source | Proprietary | Godot 3.5 | NO |
| 8 | Cruelty Squad | Proprietary | No code | NO |

---

## Pattern 1 — HitArea3D / HurtArea3D Typed Split

**Source**: https://github.com/gdquest-demos/godot-4-hitbox-hurtbox (MIT)  
**Files retrieved**: `nodes/hit_area_2d.gd`, `nodes/hurt_area_2d.gd`

Full source (both files retrieved):

```gdscript
# hit_area_2d.gd — port to HitArea3D extends Area3D
class_name HitArea2D extends Area2D
@export var damage := 10

# hurt_area_2d.gd — port to HurtArea3D extends Area3D
class_name HurtArea2D extends Area2D
func _ready() -> void:
    area_entered.connect(_on_area_entered)
func _on_area_entered(hit_area: HitArea2D) -> void:
    if hit_area != null and owner.has_method("take_damage"):
        owner.take_damage(hit_area.damage)
```

**Choyce adaptation**: Replace `has_method` duck-type with typed `DamageReceiverPort` interface (hex arch). `HitArea3D` child of sword bone attachment; `HurtArea3D` wraps slime/bouncer capsule. Damage flows through `ModerationSafety` if AI-generated (existing port).

**Risk**: 2D only — trivial port. No knockback built-in; pair with Pattern 3.

---

## Pattern 2 — AnimationTree Method Call Track Hitbox (frame-perfect arc)

**Source**: https://kidscancode.org/godot_recipes/4.x/animation/using_animation_sm/index.html  
**Source 2**: https://github.com/gdquest-demos/godot-4-juicy-attack (MIT)

Replace current per-frame group-scan with animation-driven hitbox enable/disable:

```gdscript
# In player.gd — state machine travel
@onready var anim_sm: AnimationNodeStateMachinePlayback = \
    $AnimationTree["parameters/playback"]

func attack() -> void:
    if is_attacking: return
    is_attacking = true
    anim_sm.travel("sword_attack")     # "At End" switch mode auto-returns idle

# Called FROM AnimationPlayer Method Call Track at contact frame (~0.18s into 0.5s swing)
func enable_hitbox() -> void:
    $SwordHitbox/CollisionShape3D.set_deferred("disabled", false)

# Called FROM AnimationPlayer Method Call Track at swing end (~0.35s)
func disable_hitbox() -> void:
    $SwordHitbox/CollisionShape3D.set_deferred("disabled", true)

func _on_animation_finished(anim: StringName) -> void:
    if anim.begins_with("sword_attack"):
        disable_hitbox()   # safety net if state interrupted
        is_attacking = false
```

**Choyce adaptation**: Current 1.8m sword arc is spatial — Method Call Track timing controls when the Area3D sweep is live. Set attack→idle transition **Switch Mode = "At End"** so 7yo cannot spam-click through animation. Add `animation_finished` signal safety-net disable.

**Risk**: Requires AnimationTree node (not raw AnimationPlayer). If AnimationTree not yet set up, that's a 0.5-day prerequisite.

---

## Pattern 3 — Boolean Iframe Guard + Knockback Velocity Decay

**Source**: https://forum.godotengine.org/t/best-way-to-disable-hurtboxes-or-hitboxes-after-first-hit-set_deferred-is-too-slow/136234  
**Source 2**: https://dredyson.com/fix-duplicate-hit-detection-in-godot-4-6-2-area3d-hurt-hit-boxes  
**Source 3**: https://github.com/j3du/gd4knockback

Do NOT toggle `monitoring`/`monitorable` — deferred-disable races cause multi-hits (Godot 4.6.2 confirmed). Use boolean guard:

```gdscript
var is_invincible := false
var knockback_vel := Vector3.ZERO

func take_damage(amount: int, source_pos: Vector3) -> void:
    if is_invincible: return
    hp -= amount
    is_invincible = true
    # Knockback: push away from attacker
    var dir = (global_position - source_pos).normalized()
    knockback_vel = dir * 8.0
    await get_tree().create_timer(0.6).timeout
    is_invincible = false

func _physics_process(delta: float) -> void:
    knockback_vel = knockback_vel.move_toward(Vector3.ZERO, 18.0 * delta)
    velocity += knockback_vel
    move_and_slide()
```

**Choyce adaptation**: Existing slime/bouncer FSM likely already has iframes — verify it uses boolean guard not `set_deferred("monitoring", false)`. The `knockback_vel` decay pattern gives the rubbery bouncer-like feel matching Roblox obstacle courses.

**Risk**: None. Pure pattern, zero deps.

---

## Pattern 4 — Path3D Wave Spawner with wave_sizes Array

**Source**: https://github.com/godotengine/godot-docs/blob/master/getting_started/first_3d_game/05.spawning_mobs.rst (MIT)

```gdscript
@export var mob_scene: PackedScene
@export var wave_sizes: Array[int] = [3, 5, 8, 12, 20]
var current_wave := 0

func _on_wave_timer_timeout() -> void:
    for i in wave_sizes[current_wave]:
        var mob := mob_scene.instantiate()
        $SpawnPath/SpawnLocation.progress_ratio = randf()
        mob.initialize($SpawnPath/SpawnLocation.position, $Player.position)
        add_child(mob)
    current_wave = min(current_wave + 1, wave_sizes.size() - 1)
    emit_signal("wave_started", current_wave)
```

**Choyce adaptation**: Wire `wave_started` signal to `ManageProgressionService` (`SessionProgressUpdatedEvent`). Swap mob_scene per wave index for slime→bouncer→boss progression. SpawnPath rings play area perimeter; PathFollow3D `progress_ratio = randf()` for random entry point. Kid-friendly: cap max concurrent mobs at 8 for 7yo cognitive load.

**Risk**: SpawnPath must be set up in scene. 3D path drawing is manual but trivial.

---

## Pattern 5 — Hitstop + Screen Shake + Flash White

**Source**: https://github.com/haowg/GODOT-VFX-LIBRARY (MIT, Godot 4.5+)  
**Source 2**: https://kidscancode.org/godot_recipes/4.x/2d/screen_shake/index.html

```gdscript
# In HurtArea3D._on_area_entered or take_damage():

# Screen shake (trauma-based)
VFX.screen_shake(8.0, 0.15)

# Flash white on enemy hit (no blood — kid-safe)
VFX.flash_white(enemy_mesh_instance, 0.08)

# Hitstop — freeze frame ~80ms, ignore_time_scale = true so timer fires
Engine.time_scale = 0.05
await get_tree().create_timer(0.08, true, false, true).timeout
Engine.time_scale = 1.0
```

**Choyce adaptation**: Gate entire block behind `FeatureFlagService.is_enabled("combat_juice")`. Replace any `spawn_blood_splash` with `spawn_energy_burst` or custom star-burst GPUParticles3D. Hitstop at 0.05 (not 0.0) so audio doesn't fully stutter.

**Risk**: Requires Godot 4.5+. The `ignore_time_scale` timer arg (4th param) is Godot 4.2+ — verify engine version pin in project.godot.

---

## Pattern 6 — Snaiel HealthComponent + DizzyComponent Architecture

**Source**: https://github.com/Snaiel/Godot4ThirdPersonCombatPrototype (MIT)  
**Files inspected**: `scripts/components/wellbeing/health_component.gd`, `scripts/components/combat/dizzy_component.gd`

HealthComponent key design (full structure retrieved):
- `signals: took_damage, health_increased, zero_health`
- `@export var enabled: bool = true` — disabling blocks ALL damage (parry/dodge godmode)
- `incoming_damage(source: DamageSource)` accepts typed resource
- Blood particles: `GPUParticles3D` instantiated, oriented toward source, `.restart()` called

DizzyComponent stun pattern (full structure retrieved):
- One-shot Timer created in `_ready()`, not in scene tree — portable to any entity
- `deal_max_damage: bool` flag for finisher one-shot kill
- Knockback: `SecondaryMovement.create(weight, 5, 10, -direction)` — extract this formula

```gdscript
# Portable timer-based stun (from DizzyComponent pattern):
func apply_stun(duration: float) -> void:
    var t := Timer.new()
    t.wait_time = duration
    t.one_shot = true
    t.autostart = true
    t.timeout.connect(func(): remove_child(t); t.queue_free(); _exit_stun())
    add_child(t)
    _enter_stun()
```

**Choyce adaptation**: Wrap slime/bouncer stun in this pattern. `enabled = false` on HealthComponent maps to existing `is_invincible` flag — consolidate to one place.

**Risk**: Beehave enemy AI (Apache 2.0 in that repo) — do NOT bundle. Use existing slime FSM.

---

## Brotato — NOT Usable

Godot 3.5, proprietary, GDRETools decompile legally grey. No Godot 4 version exists. **Skip entirely.**

## Cruelty Squad — NOT Usable

No public source. Violent art style wholly inappropriate for 7yo. **Skip.**

## Realm of the Mad God Likes — NOT Found

No clean MIT Godot 4 clone. Bullet-hell patterns are covered by existing bouncer FSM + Pattern 4 wave spawner. **Deferred.**

---

## Ranked Top 5 — Implement Next

| Rank | Pattern | File to create/modify | Effort | Child-safety note |
|------|---------|----------------------|--------|-------------------|
| 1 | AnimationTree Method Call Track hitbox | player FSM + AnimationTree setup | 1 day | Prevents spam-click; "At End" mode enforces animation completion |
| 2 | HitArea3D / HurtArea3D typed split | `src/adapters/inbound/combat/hit_area_3d.gd` + `hurt_area_3d.gd` | 0.5 day | Typed — no `has_method` duck-typing; hex-arch safe |
| 3 | Boolean iframe guard + knockback_vel decay | slime.gd + bouncer.gd | 0.5 day | Prevents multi-hit frustration for 7yo |
| 4 | Path3D wave spawner + wave_sizes array | `src/adapters/inbound/gameplay/wave_spawner.gd` | 1 day | Wire to ManageProgressionService for COPPA-safe session tracking |
| 5 | Hitstop + VFX.screen_shake + flash_white | post-damage hook | 1 day | Gate with feature flag; no blood, use energy burst |
