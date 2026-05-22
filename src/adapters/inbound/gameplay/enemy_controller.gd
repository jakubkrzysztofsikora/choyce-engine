## Tier-1 FSM enemy controller — IDLE / WANDER / CHASE / HURT / DEFEAT.
## CharacterBody3D-based. Procedural mesh fallback (Sphere for SLIME,
## Capsule for BOUNCER) when EnemyDefinition.mesh_asset_id is empty.
##
## Defeat is **kid-safe** (CLAUDE.md): no death rag-doll, no blood;
## body scales to 0 over 0.3s while spawning a sparkle burst.
class_name EnemyController
extends CharacterBody3D


signal damaged(remaining_hp: int)
## Adv N #11 fix — floating damage numbers. Carries the amount that
## actually landed (after iframes + cap) + impact position so the
## runtime can spawn a "-N" Label3D billboard.
signal damaged_with_amount(amount: int, position: Vector3)
signal defeated(enemy_id: String, position: Vector3, loot: Array)


const GRAVITY := 18.0           ## m/s^2 — slightly heavier than player for snappy bounce
const BOUNCE_INTERVAL := 1.2    ## SLIME hops every N seconds
const BOUNCE_VELOCITY := 5.0
const BOUNCER_VELOCITY := 7.5
const BOUNCER_INTERVAL := 0.9


enum State { IDLE, WANDER, CHASE, HURT, DEFEAT }


var definition: EnemyDefinition
var health: HealthState
var _state: State = State.IDLE
var _bounce_cooldown: float = 0.0
var _hurt_remaining: float = 0.0
var _player_ref: Node3D
var _wander_target: Vector3 = Vector3.ZERO
var _wander_remaining: float = 0.0
var _spawn_origin: Vector3 = Vector3.ZERO
var _mesh: MeshInstance3D
var _collision: CollisionShape3D
## Boolean guard — `_collision.set_deferred("disabled", true)` alone
## is racy on Godot 4.6.2: a second damage source in the same tick
## can re-enter _on_defeat before the deferred call lands and
## double-emit the defeated signal (which would double-drop loot).
var _already_defeated: bool = false


func setup(p_def: EnemyDefinition, p_player: Node3D) -> EnemyController:
	definition = p_def
	_player_ref = p_player
	health = HealthState.new(p_def.max_hp)
	if is_inside_tree():
		_build_visuals()
		_spawn_origin = global_position
	return self


func _ready() -> void:
	# Visuals may have been built already if setup() was called before
	# add_child. Skip if so.
	if _mesh == null and definition != null:
		_build_visuals()
		_spawn_origin = global_position


func _build_visuals() -> void:
	# Big-slime boss reads as a boss — 2.2× the regular sphere radius
	# + matching collision. Without this, BIG_SLIME falls into the
	# same SphereMesh radius 0.4 as regular slime and kid can't tell
	# them apart by silhouette (Adv M P0).
	var is_boss := definition.archetype == EnemyDefinition.Archetype.BIG_SLIME
	var radius := 0.88 if is_boss else 0.4
	# Collision shape
	_collision = CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = radius
	_collision.shape = shape
	add_child(_collision)

	# Mesh — procedural sphere or capsule, tinted by definition.tint.
	_mesh = MeshInstance3D.new()
	var mesh_res: Mesh
	if definition.archetype == EnemyDefinition.Archetype.BOUNCER:
		var cap := CapsuleMesh.new()
		cap.radius = 0.35
		cap.height = 1.0
		mesh_res = cap
	else:
		var sph := SphereMesh.new()
		sph.radius = radius
		sph.height = radius * 2.0
		mesh_res = sph
	_mesh.mesh = mesh_res
	var mat := StandardMaterial3D.new()
	mat.albedo_color = definition.tint
	mat.roughness = 0.7
	_mesh.material_override = mat
	add_child(_mesh)


func _physics_process(delta: float) -> void:
	if not health.is_alive:
		return
	health.tick(delta)
	_hurt_remaining = maxf(_hurt_remaining - delta, 0.0)

	# Gravity
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0.0

	match _state:
		State.IDLE:
			_state_idle(delta)
		State.WANDER:
			_state_wander(delta)
		State.CHASE:
			_state_chase(delta)
		State.HURT:
			_state_hurt(delta)
		State.DEFEAT:
			pass

	move_and_slide()
	_check_aggro()


func apply_damage(amount: int, knockback_from: Vector3 = Vector3.ZERO) -> bool:
	if not health.apply_damage(amount):
		return false
	emit_signal("damaged", health.current_hp)
	emit_signal("damaged_with_amount", amount, global_position + Vector3(0, 0.4, 0))
	_state = State.HURT
	_hurt_remaining = 0.2
	# Knockback away from attacker
	if knockback_from != Vector3.ZERO:
		var away := (global_position - knockback_from).normalized()
		away.y = 0.0
		velocity = away * 6.0
		velocity.y = 3.0
	# Adv Y C3 fix — emission-spike white flash (visible on green AND
	# purple BIG_SLIME). Previous pale-pink (1.0, 0.85, 0.85) tint
	# was invisible on green slime tint. Snap to pure white + emission
	# spike for 50ms, then linear-fade back over 120ms. Holds the
	# bright frame long enough for the kid's eye to register "WHACK"
	# before the colour returns to the original tint.
	if _mesh != null and _mesh.material_override is StandardMaterial3D:
		var mat: StandardMaterial3D = _mesh.material_override
		var original_color := mat.albedo_color
		var original_emission := mat.emission
		var original_emission_enabled := mat.emission_enabled
		var original_emission_energy := mat.emission_energy_multiplier
		mat.albedo_color = Color.WHITE
		mat.emission_enabled = true
		mat.emission = Color.WHITE
		mat.emission_energy_multiplier = 1.5
		var tween := create_tween()
		# Hold the bright frame.
		tween.tween_interval(0.05)
		# Linear-fade albedo + emission energy back to original.
		tween.parallel().tween_property(mat, "albedo_color", original_color, 0.12)
		tween.parallel().tween_property(mat, "emission_energy_multiplier",
			original_emission_energy, 0.12)
		tween.tween_callback(func() -> void:
			if mat == null:
				return
			mat.emission = original_emission
			mat.emission_enabled = original_emission_enabled
		)
	if not health.is_alive:
		_on_defeat()
	return true


func _on_defeat() -> void:
	if _already_defeated:
		return
	_already_defeated = true
	_state = State.DEFEAT
	var loot := _roll_loot()
	emit_signal("defeated", definition.enemy_id, global_position, loot)
	# Disable collision so player can walk over the poof spot. Guard
	# against _build_visuals having been skipped (Adv 6 #3).
	if _collision != null and is_instance_valid(_collision):
		_collision.set_deferred("disabled", true)
	# Shrink-out anim (kid-safe — no rag doll). If end_session frees
	# the node mid-tween, the post-await check prevents calling
	# queue_free on an already-freed instance (Adv 6 #1).
	if _mesh == null or not is_instance_valid(_mesh):
		queue_free()
		return
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_mesh, "scale", Vector3.ZERO, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "global_position",
		global_position + Vector3(0, 0.5, 0), 0.3)
	await tween.finished
	if is_inside_tree():
		queue_free()


# ---- state behaviours ----

func _state_idle(_delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	_wander_remaining -= _delta
	if _wander_remaining <= 0.0:
		_state = State.WANDER
		_pick_wander_target()


func _state_wander(delta: float) -> void:
	var to_target := _wander_target - global_position
	to_target.y = 0.0
	if to_target.length() < 0.3:
		_state = State.IDLE
		_wander_remaining = randf_range(1.0, 2.5)
		return
	if definition.archetype == EnemyDefinition.Archetype.SLIME:
		_bounce_toward(to_target, BOUNCE_VELOCITY, BOUNCE_INTERVAL, delta)
	else:
		var step := to_target.normalized() * definition.move_speed
		velocity.x = step.x
		velocity.z = step.z


func _state_chase(delta: float) -> void:
	if _player_ref == null:
		_state = State.WANDER
		return
	var to_player := _player_ref.global_position - global_position
	to_player.y = 0.0
	if to_player.length() < 0.6:
		# In contact range — try contact-damage on player via callback metadata.
		_try_contact_damage()
		return
	match definition.archetype:
		EnemyDefinition.Archetype.BOUNCER:
			_bounce_toward(to_player, BOUNCER_VELOCITY, BOUNCER_INTERVAL, delta)
		EnemyDefinition.Archetype.SLIME, _:
			_bounce_toward(to_player, BOUNCE_VELOCITY, BOUNCE_INTERVAL, delta)


func _state_hurt(_delta: float) -> void:
	if _hurt_remaining <= 0.0:
		_state = State.CHASE if _player_in_range() else State.WANDER


func _bounce_toward(direction: Vector3, magnitude: float, interval: float, delta: float) -> void:
	_bounce_cooldown -= delta
	if is_on_floor() and _bounce_cooldown <= 0.0:
		var dir := direction.normalized()
		velocity.x = dir.x * definition.move_speed
		velocity.z = dir.z * definition.move_speed
		velocity.y = magnitude
		_bounce_cooldown = interval


func _try_contact_damage() -> void:
	if _player_ref == null or not _player_ref.has_method("apply_damage_from_enemy"):
		return
	_player_ref.call_deferred("apply_damage_from_enemy",
		definition.contact_damage, global_position)


func _pick_wander_target() -> void:
	var angle := randf() * TAU
	var radius := randf_range(2.0, 4.5)
	_wander_target = _spawn_origin + Vector3(cos(angle) * radius, 0, sin(angle) * radius)


func _check_aggro() -> void:
	if _player_ref == null:
		return
	if _state == State.HURT or _state == State.DEFEAT:
		return
	if definition.disposition == EnemyDefinition.Disposition.PASSIVE:
		return
	var dist := global_position.distance_to(_player_ref.global_position)
	if dist <= definition.aggro_radius:
		if _state != State.CHASE:
			_state = State.CHASE
	elif _state == State.CHASE and dist > definition.aggro_radius * 1.5:
		_state = State.WANDER
		_pick_wander_target()


func _player_in_range() -> bool:
	if _player_ref == null:
		return false
	return global_position.distance_to(_player_ref.global_position) <= definition.aggro_radius


func _roll_loot() -> Array:
	var out: Array = []
	for entry in definition.loot_table:
		if not (entry is Dictionary):
			continue
		var chance := float(entry.get("chance", 1.0))
		if randf() > chance:
			continue
		var lo := int(entry.get("min", 1))
		var hi := int(entry.get("max", lo))
		var qty := randi_range(lo, hi)
		if qty <= 0:
			continue
		out.append({"item_id": String(entry.get("item_id", "")), "quantity": qty})
	return out
