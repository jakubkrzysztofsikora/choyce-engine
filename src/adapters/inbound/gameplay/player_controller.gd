class_name PlayerController
extends CharacterBody3D

const WALK_SPEED := 5.0
const SPRINT_SPEED := 10.0
const JUMP_VELOCITY := 4.5
const MOUSE_SENSITIVITY := 0.003
const VERTICAL_LOOK_LIMIT := 1.2
const COYOTE_TIME := 0.1
const JUMP_BUFFER_TIME := 0.1
const FOOTSTEP_INTERVAL := 0.4
const BASE_FOV := 64.0
const SPRINT_FOV := 70.0
const GRAVITY_RISE_MULTIPLIER := 1.0
const GRAVITY_FALL_MULTIPLIER := 1.35
const BUILD_RAY_RANGE := 8.0
const WATER_MOVE_MULTIPLIER := 0.48
const WATER_SINK_SPEED := 1.3
const WATER_SWIM_UP_VELOCITY := 3.4

signal footstep
signal landed
signal hard_landed
signal jumped
signal attacked(damage: int, hit_position: Vector3)
## Adv Y C2 fix — emitted when a swing's in-arc enemy scan finds
## nothing. Lets the gameplay runtime fire a whoosh SFX from the
## attack origin so the kid hears their fist cutting air (otherwise
## misses are silent and a 7yo thinks the button is broken).
signal swing_missed(attack_origin: Vector3)
signal hp_changed(current: int, max_hp: int)
signal player_defeated

## Combat state. Player HP regenerates 2/sec when not recently hit.
## Equipped weapon damage drives _on_attack hit value; defaults to a
## starter "fist" 4-damage weapon until inventory injects something.
const ATTACK_COOLDOWN := 0.4
const ATTACK_RANGE := 1.8
const ATTACK_ARC_RADIANS := 1.4   ## ~80° front cone
const STARTER_WEAPON_DAMAGE := 4
const PLAYER_MAX_HP := 100
const PLAYER_REGEN_PER_SEC := 2.0
## Adv Y M3 fix: combo-window cooldown system
const COMBO_WINDOW_SEC := 0.5
const COMBO_COOLDOWN := 0.18
const COMBO_RECOVERY_SEC := 0.6
const MAX_COMBO_SWINGS := 2

var _health: HealthState
var _attack_cooldown: float = 0.0
var _equipped_weapon_damage: int = STARTER_WEAPON_DAMAGE
var _last_swing_time: float = 0.0
var _combo_count: int = 0
## Input action prefix for local co-op. "" = player 1 (default, solo path
## unchanged). "p2_" routes movement/jump/sprint/attack to the P2 action set
## the split-screen runtime registers (arrow keys / RCtrl / RShift).
var _act_prefix: String = ""


## Route this controller's input to a distinct action set (local co-op P2).
## Call before the first physics tick. Empty prefix keeps the P1 bindings.
func set_action_prefix(prefix: String) -> void:
	_act_prefix = prefix


func _act(name: String) -> String:
	return _act_prefix + name

# Procedural Muay Thai fight animation state. No skeletal-bone work
# required — animates the existing _character_mesh wrapper via tween
# and lerp. Cheap, keeps the Kenney character's own idle/walk anims
# running underneath. Kid sees: forward-leaned stance when idle in
# combat mode, alternating jab/cross thrust on each LMB swing.
const PUNCH_LEAN_RAD := 0.32        ## ~18° side-lean per punch
const PUNCH_FORWARD_PUSH := 0.22     ## meters forward at peak
const PUNCH_DURATION := 0.22         ## one full strike cycle in s
const MUAY_THAI_FORWARD_LEAN := 0.10 ## ~6° permanent forward stance
const MUAY_THAI_BOUNCE_AMP := 0.04
const MUAY_THAI_BOUNCE_FREQ := 1.6   ## Hz
const MUAY_THAI_POSE_LERP := 6.0
## Adv Y M4 fix: increased squash for visible punch feedback
## Was (1.08, 0.94, 1.08) — too small to read at speed
const PUNCH_SQUASH_SCALE := Vector3(1.18, 0.86, 1.18)

var _punch_phase: int = 0           ## 0=jab(R), 1=cross(L), 2=elbow(R)…
var _last_attack_style: String = "punch"
var _is_punching: bool = false
var _muay_thai_t: float = 0.0
var _punch_tween: Tween = null

## Voxel build hookup. GameplayRuntime injects via setup_build_grid().
## Hotbar tracks which BlockKind id maps to slots 1..5; default first
## 5 from BlockKind.default_catalog().
var _build_grid: BuildGrid = null
var _hotbar: Array = []        ## Array[String] block_ids
var _active_slot: int = 0      ## 0-based index into _hotbar
var _equipped_tool_id := ""

## Game-mode resolver — equipped-slot kind drives whether LMB
## breaks blocks (build mode) or attacks (combat mode). Lazy-init
## so older callers without setup_game_mode keep working.
var _game_mode_service: GameModeService = null

## Ghost preview Node3D attached to the player. Shown in build mode
## at the cell adjacent to the current raycast hit. Updated every
## physics tick.
var _ghost_preview: MeshInstance3D = null
var _ghost_material: StandardMaterial3D = null

signal hotbar_changed(active_slot: int, block_id: String)

var _camera: Camera3D
var _vertical_look: float = 0.0
var _coyote_time: float = 0.0
var _jump_buffer: float = 0.0
var _was_on_floor: bool = false
var _footstep_timer: float = 0.0
var _head_bob_time: float = 0.0
var _base_scale: Vector3 = Vector3.ONE
var _camera_base_y: float = 1.6
var _character_mesh: Node3D
var _anim_player: AnimationPlayer
var _current_anim: String = ""
var _world_interaction_lock: float = 0.0
var _in_water: bool = false
const WALK_VELOCITY_THRESHOLD := 0.5

func _ready() -> void:
	_health = HealthState.new(PLAYER_MAX_HP)
	hp_changed.emit(_health.current_hp, _health.max_hp)
	_build_ghost_preview()
	_camera = $Camera3D
	if _camera == null:
		push_error("PlayerController: Camera3D child not found")
	_base_scale = scale
	if _camera != null:
		_camera_base_y = _camera.position.y
		_camera.fov = BASE_FOV
		# Without make_current(), the root viewport has no active camera and
		# only the Environment sky_blue clears the frame. Kid saw a blue
		# screen instead of the 3D world. set_process(false) at construction
		# does not stop the camera from rendering — only its update loop.
		_camera.make_current()
		print("[player_controller] _ready: camera current=%s pos=%s viewport=%s" %
			[_camera.current, _camera.global_position, _camera.get_viewport()])
	# Kenney character authored facing +Z (toward camera). Rotate 180° so it
	# faces forward (-Z, away from camera) matching movement direction.
	_character_mesh = get_node_or_null("CharacterMesh")
	if _character_mesh != null:
		_character_mesh.rotation.y = PI
		# Kenney GLB embeds an AnimationPlayer with idle/walk/sprint/jump/fall.
		_anim_player = _character_mesh.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if _anim_player != null:
			# Adv X C1: GLB clips are shared Animation resources. Mutating
			# `loop_mode` per play() poisoned other character instances and
			# could flip an attack clip to LOOP_LINEAR → animation_finished
			# never fires → _is_punching strands forever. Duplicate each
			# clip once + set loop_mode here; play() never mutates after.
			for anim_name in _anim_player.get_animation_list():
				var src := _anim_player.get_animation(anim_name)
				if src == null:
					continue
				var dup := src.duplicate() as Animation
				var lname := String(anim_name).to_lower()
				var is_attack := String(anim_name) in ATTACK_ANIMS
				var is_loop := false
				if not is_attack:
					for ln in LOOPING_ANIMS:
						if lname.begins_with(ln):
							is_loop = true
							break
				dup.loop_mode = Animation.LOOP_LINEAR if is_loop else Animation.LOOP_NONE
				var lib := _anim_player.get_animation_library("")
				if lib != null:
					lib.remove_animation(anim_name)
					lib.add_animation(anim_name, dup)
			_play_anim("idle")
			# Kenney attack clips (attack-melee-*/attack-kick-*) are one-shot.
			# Return to velocity-driven movement anim when the clip finishes.
			if not _anim_player.animation_finished.is_connected(_on_anim_finished):
				_anim_player.animation_finished.connect(_on_anim_finished)

func _physics_process(delta: float) -> void:
	if not is_processing():
		return
	if _world_interaction_lock > 0.0:
		_world_interaction_lock -= delta
		velocity = Vector3.ZERO
		return

	# Coyote time
	if is_on_floor():
		_coyote_time = COYOTE_TIME
	else:
		_coyote_time -= delta

	# Jump buffer
	if Input.is_action_just_pressed(_act("jump")):
		_jump_buffer = JUMP_BUFFER_TIME
	else:
		_jump_buffer -= delta

	# Better gravity curve. Water is an Area3D volume, not an invisible wall:
	# gravity turns into a gentle sink and jump becomes a small swim stroke.
	var gravity := ProjectSettings.get_setting("physics/3d/default_gravity") as float
	if _in_water:
		velocity.y = move_toward(velocity.y, -WATER_SINK_SPEED, gravity * 0.42 * delta)
	elif not is_on_floor():
		var gravity_mult := GRAVITY_RISE_MULTIPLIER if velocity.y > 0 else GRAVITY_FALL_MULTIPLIER
		velocity.y -= gravity * gravity_mult * delta

	# Jump with coyote time and buffering
	if _in_water and _jump_buffer > 0.0:
		velocity.y = WATER_SWIM_UP_VELOCITY
		_jump_buffer = 0.0
		jumped.emit()
	elif _jump_buffer > 0.0 and _coyote_time > 0.0:
		velocity.y = JUMP_VELOCITY
		_jump_buffer = 0.0
		_coyote_time = 0.0
		jumped.emit()

	# Movement
	var input_dir := Input.get_vector(_act("move_left"), _act("move_right"), _act("move_forward"), _act("move_back"))
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	var is_sprinting := Input.is_action_pressed(_act("sprint"))
	var speed := SPRINT_SPEED if is_sprinting else WALK_SPEED
	if _in_water:
		speed *= WATER_MOVE_MULTIPLIER

	if direction.length() > 0:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)

	move_and_slide()

	# Combat tick — regen + cooldowns + attack input.
	if _health != null:
		_health.tick(delta, PLAYER_REGEN_PER_SEC)
		hp_changed.emit(_health.current_hp, _health.max_hp)
	_attack_cooldown = maxf(_attack_cooldown - delta, 0.0)
	# Route LMB / "attack" action through GameModeService — block in
	# active slot → break; weapon in slot → attack. Matches
	# Minecraft Bedrock; dissolves Adv 5 #1 mouse-rebind concern.
	if Input.is_action_just_pressed(_act("attack")) and _attack_cooldown <= 0.0:
		_dispatch_lmb()
	# Place still bound to dedicated action (K) AND right mouse in
	# build mode. _process_build_input handles K + 1-5.
	_process_build_input()
	_update_ghost_preview()
	_update_muay_thai_idle(delta)

	# Landing detection and squash
	if is_on_floor() and not _was_on_floor:
		landed.emit()
		_landing_squash()
		if velocity.y < -5.0:
			_hard_landing_feedback()
		_check_spring_block_launch()
	_was_on_floor = is_on_floor()

	# Footstep rhythm
	if is_on_floor() and direction.length() > 0:
		_footstep_timer -= delta
		if _footstep_timer <= 0.0:
			_footstep_timer = FOOTSTEP_INTERVAL
			footstep.emit()
	else:
		_footstep_timer = FOOTSTEP_INTERVAL * 0.5

	# Sprint FOV tween
	var target_fov := SPRINT_FOV if is_sprinting and direction.length() > 0 else BASE_FOV
	if _camera != null and not is_equal_approx(_camera.fov, target_fov):
		_camera.fov = lerp(_camera.fov, target_fov, 8.0 * delta)

	# Head bob (was at the tail of _physics_process — kept here)
	if is_on_floor() and direction.length() > 0 and _camera != null:
		_head_bob_time += delta * speed * 0.8
		var bob_offset := sin(_head_bob_time * TAU) * 0.04
		_camera.position.y = _camera_base_y + bob_offset
	elif _camera != null:
		_camera.position.y = lerp(_camera.position.y, _camera_base_y, 10.0 * delta)

	# Drive character animation from horizontal velocity.
	if _anim_player != null:
		var horiz := Vector2(velocity.x, velocity.z).length()
		var want := "idle"
		if not is_on_floor():
			want = "fall"
		elif horiz > WALK_VELOCITY_THRESHOLD:
			want = "sprint" if is_sprinting else "walk"
		_play_anim(want)


## Called by the renderer's authored water volumes. This stays on the player
## adapter so physics response is owned by movement rather than a scenery prop.
func set_in_water(active: bool) -> void:
	_in_water = active


## Fires when the AnimationPlayer finishes a one-shot clip (mainly
## the Kenney attack-melee-*/attack-kick-* swings). Clears the punch
## flag and lets the next physics-process tick re-select a movement
## anim from velocity.
func _on_anim_finished(finished_name: StringName) -> void:
	var name_str := String(finished_name)
	if name_str in ATTACK_ANIMS:
		_is_punching = false
		_current_anim = ""  # force _play_anim to re-pick a movement clip
		var horiz := Vector2(velocity.x, velocity.z).length()
		var want := "idle"
		if not is_on_floor():
			want = "fall"
		elif horiz > WALK_VELOCITY_THRESHOLD:
			want = "walk"
		_play_anim(want)


## Animation names that should loop continuously. Kenney glTFs default to
## loop_mode = NONE on import; without overriding, walk/idle play once
## (~1 s) and stop while the kid is still moving. (Bug reported via
## /dev:debug 'walking animation works for a moment then stops'.)
const LOOPING_ANIMS := ["idle", "walk", "sprint", "static"]

## Kenney character GLB skeletal one-shot strike clips. Cycled per
## _punch_phase to give the Muay-Thai feel: jab → cross → kick → kick.
const ATTACK_ANIMS := [
	"attack-melee-right",  # phase 0 — right jab
	"attack-melee-left",   # phase 1 — left cross
	"attack-kick-right",   # phase 2 — right kick (elbow stand-in)
	"attack-kick-left",    # phase 3 — left kick (knee stand-in)
]


## Switch to the named animation if not already playing. Falls back to whatever
## is in the GLB if the name isn't found (some Kenney packs name them differently).
func _play_anim(name: String) -> void:
	if _anim_player == null or _current_anim == name:
		return
	# Skeletal attack clip is mid-flight — do not let velocity-driven
	# walk/idle/sprint preempt it. _on_anim_finished restores movement.
	if _is_punching and not (name in ATTACK_ANIMS):
		return
	if not _anim_player.has_animation(name):
		# Try a fuzzy fallback to anything starting with the name.
		for a in _anim_player.get_animation_list():
			if String(a).to_lower().begins_with(name.to_lower()):
				name = a
				break
		if not _anim_player.has_animation(name):
			return
	# loop_mode pre-set in _ready on duplicated clips — no mutation here.
	_anim_player.play(name)
	_current_anim = name

const KEY_ROTATE_SPEED := 2.5  # rad/s for Q/E fallback rotation
const STICK_ROTATE_SPEED := 3.0  # rad/s at full joypad deflection
const STICK_DEADZONE := 0.2
const MOUSE_DRAG_SENSITIVITY := 0.005  # rad per pixel while dragging

var _mouse_dragging: bool = false

func _input(event: InputEvent) -> void:
	if not is_processing_input():
		return

	# FPS-style mouselook: mouse motion alone rotates the camera (no
	# hold-to-look needed). The cursor is captured for the 3D session
	# so motion deltas are raw. ESC releases capture so the kid can
	# click HUD (back button, hotbar). LMB swings only when captured;
	# LMB while cursor is visible falls through to HUD click handlers
	# (Adv C B2 fix — was capturing cursor on every LMB regardless of
	# mode, breaking back-button + hotbar clicks).
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			# Only treat LMB as a sword/break swing when the cursor
			# is captured (kid is "in" the 3D view). When the cursor
			# is visible, LMB belongs to whatever HUD control it
			# lands on.
			if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
				return
			if event.pressed:
				Input.action_press("attack")
			else:
				Input.action_release("attack")
			return

	if event is InputEventMouseMotion:
		var captured := Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED
		if not captured:
			return  # cursor visible → kid is on HUD; don't move camera
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		_vertical_look -= event.relative.y * MOUSE_SENSITIVITY
		_vertical_look = clamp(_vertical_look, -VERTICAL_LOOK_LIMIT, VERTICAL_LOOK_LIMIT)
		if _camera != null:
			_camera.rotation.x = _vertical_look

func _process(delta: float) -> void:
	if not is_processing():
		return
	# Camera rotation: Q/E keys (fallback) + controller right-stick.
	# Right-mouse drag is handled in _input.
	var rot := 0.0
	if Input.is_key_pressed(KEY_Q):
		rot += 1.0
	if Input.is_key_pressed(KEY_E):
		rot -= 1.0
	if rot != 0.0:
		rotate_y(rot * KEY_ROTATE_SPEED * delta)
	# Controller right-stick: axis 2 = X (yaw), axis 3 = Y (pitch).
	var stick_x := Input.get_joy_axis(0, JOY_AXIS_RIGHT_X)
	var stick_y := Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
	if absf(stick_x) > STICK_DEADZONE:
		rotate_y(-stick_x * STICK_ROTATE_SPEED * delta)
	if absf(stick_y) > STICK_DEADZONE and _camera != null:
		_vertical_look -= stick_y * STICK_ROTATE_SPEED * delta
		_vertical_look = clamp(_vertical_look, -VERTICAL_LOOK_LIMIT, VERTICAL_LOOK_LIMIT)
		_camera.rotation.x = _vertical_look

func spawn_at(pos: Vector3) -> void:
	global_position = pos
	velocity = Vector3.ZERO
	_was_on_floor = false
	_coyote_time = 0.0
	_jump_buffer = 0.0
	_head_bob_time = 0.0
	if _camera != null:
		_camera.position.y = _camera_base_y
		# Re-assert current — if a previous GameplayRuntime was queue_freed,
		# its Camera3D may still be holding the viewport until cleanup runs.
		_camera.make_current()
		print("[player_controller] spawn_at: player=%s camera=%s current=%s" %
			[global_position, _camera.global_position, _camera.current])


func play_sit_at(pos: Vector3) -> void:
	# Small authored interaction pose for the home loop. Input is locked for a
	# moment so the kid sees the action complete instead of cancelling it with
	# the next movement tick.
	global_position = Vector3(pos.x, global_position.y, pos.z)
	velocity = Vector3.ZERO
	_world_interaction_lock = 1.7
	if _character_mesh == null:
		return
	var tween := create_tween()
	tween.tween_property(_character_mesh, "position:y", -0.28, 0.18)
	tween.parallel().tween_property(_character_mesh, "rotation:x", -0.35, 0.18)
	tween.tween_interval(1.15)
	tween.tween_property(_character_mesh, "position:y", 0.0, 0.22)
	tween.parallel().tween_property(_character_mesh, "rotation:x", 0.0, 0.22)

## Sweep the front cone for enemies. Hit each EnemyController within
## ATTACK_RANGE + ATTACK_ARC. Emit `attacked` signal so gameplay
## runtime can spawn swing VFX / SFX.
func _perform_attack() -> void:
	# Adv Y M3 fix: combo-window cooldown system
	var now := Time.get_ticks_msec() / 1000.0
	var in_combo_window := now - _last_swing_time < COMBO_WINDOW_SEC
	_last_swing_time = now
	
	# Reset combo if outside window or at max swings
	if not in_combo_window:
		_combo_count = 0
	
	# After phase 3 (kick-left), enforce hard recovery
	# Check if this was the last swing in the combo
	var is_last_combo_swing := _punch_phase % 4 == 3  # phase 3 is the last in 0-3 cycle
	
	if is_last_combo_swing:
		# Hard recovery after kick
		_attack_cooldown = COMBO_RECOVERY_SEC
		_combo_count = 0
	elif _combo_count < MAX_COMBO_SWINGS and in_combo_window:
		# Fast combo swing
		_attack_cooldown = COMBO_COOLDOWN
		_combo_count += 1
	else:
		# Normal cooldown
		_attack_cooldown = ATTACK_COOLDOWN
		_combo_count = 1
	
	# Squash on the MESH, not on `self` (CharacterBody3D parent of
	# Camera3D). Was scaling self → camera scaled with it →
	# whole-screen "wobble". Cosmetic-only on mesh keeps camera
	# steady. (User reported "screen jumps weirdly when punching".)
	if _character_mesh != null:
		var attack_tween := create_tween()
		# Adv Y M4 fix: bigger squash for visible punch feedback
		# Was (1.08, 0.94, 1.08) — too small to read at speed
		attack_tween.tween_property(_character_mesh, "scale",
			PUNCH_SQUASH_SCALE, 0.08)
		attack_tween.tween_property(_character_mesh, "scale",
			Vector3.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# Procedural Muay Thai strike. Alternates jab/cross/elbow/knee
	# pattern so kid sees variety. Kept short (0.22s) to match
	# combat cooldown — strike resolves before next swing.
	_trigger_punch_animation()

	# Camera direction = aim ray. Keeps 3rd-person view but lets the
	# centered crosshair point exactly where the swing lands — kid was
	# unable to aim because body forward and camera forward disagreed.
	var hit_origin := global_position + Vector3(0, 0.8, 0)
	var forward: Vector3 = -transform.basis.z.normalized()
	if _camera != null:
		var cam_fwd: Vector3 = -_camera.global_transform.basis.z
		cam_fwd.y = 0.0
		if cam_fwd.length_squared() > 0.0001:
			forward = cam_fwd.normalized()
	var hit_point := hit_origin + forward * (ATTACK_RANGE * 0.5)
	# Adv BB P0-3 fix: soft aim assist for 7yo
	# Find nearest enemy in expanded cone and rotate toward it
	var tree := get_tree()
	if tree != null:
		var best_enemy: EnemyController = null
		var best_angle := ATTACK_ARC_RADIANS * 0.5
		var best_distance := ATTACK_RANGE * 1.4
		for body in tree.get_nodes_in_group("enemies"):
			if not (body is EnemyController):
				continue
			var to_enemy: Vector3 = body.global_position - global_position
			to_enemy.y = 0.0
			var distance := to_enemy.length()
			if distance > ATTACK_RANGE * 1.4:
				continue
			var angle := forward.angle_to(to_enemy.normalized())
			if angle > ATTACK_ARC_RADIANS * 1.5:
				continue
			if best_enemy == null or angle < best_angle or (angle == best_angle and distance < best_distance):
				best_enemy = body as EnemyController
				best_angle = angle
				best_distance = distance
		if best_enemy != null and absf(best_angle) < 0.5:  # ~28°
			var to_e := (best_enemy.global_position - global_position)
			to_e.y = 0.0
			var assist_yaw := forward.signed_angle_to(to_e.normalized(), Vector3.UP)
			if absf(assist_yaw) < 0.5:
				rotate_y(assist_yaw * 0.6)  # 60% of the way — visible but not robotic
				forward = -transform.basis.z.normalized()  # Update forward after rotation
				hit_point = hit_origin + forward * (ATTACK_RANGE * 0.5)
	
	attacked.emit(_equipped_weapon_damage, hit_point)

	# Hit-detect: scan scene tree for EnemyControllers in arc.
	# (Cheap O(N) — kid maps will rarely hold > 20 enemies.)
	if tree == null:
		return
	var hit_count := 0
	for body in tree.get_nodes_in_group("enemies"):
		if not (body is EnemyController):
			continue
		var to_enemy: Vector3 = body.global_position - global_position
		to_enemy.y = 0.0
		var distance := to_enemy.length()
		if distance > ATTACK_RANGE:
			continue
		var angle := forward.angle_to(to_enemy.normalized())
		if angle > ATTACK_ARC_RADIANS * 0.5:
			continue
		# Adv Y H5 fix: pass attack style for 2x kick knockback
		(body as EnemyController).apply_damage(_equipped_weapon_damage, global_position, _last_attack_style)
		hit_count += 1
	# Adv Y C2 fix — whoosh on miss (no enemy in cone). Routed via
	# signal so audio plumbing stays in gameplay_runtime; this layer
	# doesn't know about AudioEventBus.
	if hit_count == 0:
		swing_missed.emit(hit_origin)


## Procedural Muay Thai strike animation. Alternates four moves so
## a run of swings reads as fight choreography, not a single repeat:
##   phase 0  jab — right-arm-out forward thrust, +lean
##   phase 1  cross — left-arm-out forward thrust, opposite lean
##   phase 2  elbow — short range, sharp Z-rotation
##   phase 3  knee — slight crouch (Y dip) + forward push
## Plays a Kenney skeletal attack clip on the rigged character mesh.
## Cycles attack-melee-right → attack-melee-left → attack-kick-right →
## attack-kick-left to read as a Muay-Thai jab/cross/kick/kick combo.
## The previous procedural wrapper-rotation tween rotated the whole
## rigged body as one chunk and barely read on screen; real bone
## animation isolates the arms/legs so the strike is visible.
func _trigger_punch_animation() -> void:
	if _anim_player == null:
		return
	# Snap mesh back to neutral in case an earlier wrapper-rotation pose
	# left it tilted, then drop any stale punch tween.
	if _punch_tween != null and _punch_tween.is_valid():
		_punch_tween.kill()
	if _character_mesh != null:
		_character_mesh.rotation = Vector3(0, PI, 0)
		_character_mesh.position = Vector3.ZERO

	_is_punching = true
	var phase := _punch_phase % ATTACK_ANIMS.size()
	_punch_phase += 1
	_last_attack_style = "kick" if phase >= 2 else "punch"
	var clip: String = ATTACK_ANIMS[phase]

	# Restart even when the previous clip name matches (rapid LMB on
	# the same phase needs a fresh play call, not a no-op).
	if not _anim_player.has_animation(clip):
		# Some Kenney variants might miss a clip — fall back to whichever
		# attack clip exists, else punt to idle to clear the flag.
		var fallback := ""
		for c in ATTACK_ANIMS:
			if _anim_player.has_animation(c):
				fallback = c
				break
		if fallback == "":
			_is_punching = false
			return
		clip = fallback
	var anim := _anim_player.get_animation(clip)
	if anim != null:
		anim.loop_mode = Animation.LOOP_NONE
	_anim_player.play(clip)
	_current_anim = clip
	# Adv X C2 / Adv Z P0-2 watchdog: if animation_finished signal drops
	# (clip override, scene teardown, respawn mid-strike), force-clear
	# the flag so the kid isn't locked out of walk/idle forever.
	var anim_len := 0.4
	if anim != null:
		anim_len = anim.length + 0.1
	get_tree().create_timer(anim_len, true, false, true).timeout.connect(_on_punch_watchdog)


func get_last_attack_style() -> String:
	return _last_attack_style


func _on_punch_watchdog() -> void:
	if _is_punching:
		_is_punching = false
		_current_anim = ""


## Subtle Muay Thai stance: forward lean + side-to-side bounce when
## the kid is in COMBAT mode (weapon/fist held). Reads as "ready to
## fight" idle vs the default straight-arms-down Kenney idle. Only
## runs when not actively punching so the strike tween isn't fought.
func _update_muay_thai_idle(delta: float) -> void:
	if _character_mesh == null or _is_punching:
		return
	# Only apply the stance when fist/weapon is the active hotbar
	# slot. Holding a block (BUILD mode) keeps neutral posture so
	# kid doesn't look like they're fighting their toolbox.
	var active_kind: String = String(_hotbar[_active_slot]) if (_active_slot >= 0 and _active_slot < _hotbar.size()) else ""
	var svc := _ensure_game_mode_service()
	var combat := svc.current_mode(active_kind) == GameModeService.Mode.COMBAT
	if not combat:
		# Drift toward neutral so leaving combat mode releases the
		# stance smoothly. _character_mesh.rotation.y stays at PI
		# (the +180° base orientation for Kenney character).
		_character_mesh.rotation.x = lerp(_character_mesh.rotation.x, 0.0, MUAY_THAI_POSE_LERP * delta)
		_character_mesh.rotation.z = lerp(_character_mesh.rotation.z, 0.0, MUAY_THAI_POSE_LERP * delta)
		return
	_muay_thai_t += delta * MUAY_THAI_BOUNCE_FREQ * TAU
	var sway := sin(_muay_thai_t) * MUAY_THAI_BOUNCE_AMP
	# Forward lean (pitch) + alternating side bounce (roll).
	var target_pitch := MUAY_THAI_FORWARD_LEAN
	var target_roll := sway * 0.6
	_character_mesh.rotation.x = lerp(_character_mesh.rotation.x, target_pitch, MUAY_THAI_POSE_LERP * delta)
	_character_mesh.rotation.z = lerp(_character_mesh.rotation.z, target_roll, MUAY_THAI_POSE_LERP * delta)


## Called by EnemyController on touch contact. Routes through
## HealthState which enforces invuln + per-hit damage cap.
func apply_damage_from_enemy(amount: int, source_position: Vector3) -> void:
	if _health == null:
		return
	if not _health.apply_damage(amount):
		return
	hp_changed.emit(_health.current_hp, _health.max_hp)
	# Knockback away from source. Add to existing horizontal velocity
	# (not overwrite) and only boost Y if the kid isn't already
	# rising faster — prevents mid-jump stall (Adv 6 #5).
	var away := (global_position - source_position).normalized()
	away.y = 0.0
	velocity.x += away.x * 5.0
	velocity.z += away.z * 5.0
	velocity.y = maxf(velocity.y, 4.0)
	if not _health.is_alive:
		player_defeated.emit()


func get_health() -> HealthState:
	return _health


func equip_weapon_damage(damage: int) -> void:
	_equipped_weapon_damage = maxi(damage, 1)


const _SWORD_1H := "res://data/models/kaykit/adventurers/assets/sword_1handed.gltf"
const _SWORD_2H := "res://data/models/kaykit/adventurers/assets/sword_2handed.gltf"
const _AXE := "res://data/models/kenney/survival_kit/Models/GLB format/tool-axe.glb"
const _PICKAXE := "res://data/models/kenney/survival_kit/Models/GLB format/tool-pickaxe.glb"
var _held_weapon: Node3D = null

## Show a real weapon model in the kid's hand for sword tiers. Bare hand
## (fist/stick) keeps the Muay Thai animation with nothing held. The 2-handed
## "epic" sword reads as the FF-style big blade. Silent no-op if the model or
## the character mesh is missing (procedural fallback stays bare-hand).
func set_weapon_visual(tier_id: String) -> void:
	if _held_weapon != null and is_instance_valid(_held_weapon):
		_held_weapon.queue_free()
		_held_weapon = null
	if _character_mesh == null:
		return
	var model_path := ""
	match tier_id:
		"sword_iron": model_path = _SWORD_1H
		"sword_epic": model_path = _SWORD_2H
		"tool_axe": model_path = _AXE
		"tool_pickaxe": model_path = _PICKAXE
		_: return  # fist / stick — bare-handed Muay Thai
	if not ResourceLoader.exists(model_path):
		return
	var packed: PackedScene = load(model_path)
	if packed == null:
		return
	_held_weapon = packed.instantiate()
	_character_mesh.add_child(_held_weapon)
	# Right-hand offset + upright grip. Tuned to the Kenney rig's scale so the
	# blade sits in the fist and points up-forward.
	_held_weapon.position = Vector3(0.28, 0.55, 0.15)
	_held_weapon.rotation_degrees = Vector3(0, 0, -20)
	_held_weapon.scale = Vector3.ONE * (1.4 if tier_id == "sword_epic" else 1.1)


func equip_tool(tool_id: String) -> void:
	if tool_id not in ["tool_axe", "tool_pickaxe"]:
		return
	_equipped_tool_id = tool_id
	set_weapon_visual(tool_id)
	if _hotbar.is_empty():
		_hotbar.append(tool_id)
	else:
		_hotbar[0] = tool_id
	_active_slot = 0
	hotbar_changed.emit(_active_slot, tool_id)


func has_equipped_tool(tool_id: String) -> bool:
	return _equipped_tool_id == tool_id


func select_creative_build_item(item_id: String) -> void:
	if item_id in ["tool_axe", "tool_pickaxe"]:
		equip_tool(item_id)
		return
	var catalog_ids: Array[String] = []
	for kind in BlockKind.default_catalog():
		catalog_ids.append((kind as BlockKind).block_id)
	if item_id not in catalog_ids:
		return
	if _hotbar.size() < 2:
		_hotbar.append(item_id)
	else:
		_hotbar[1] = item_id
	_active_slot = 1
	hotbar_changed.emit(_active_slot, item_id)


## Build a translucent BoxMesh that shows where the next block will
## land. Top-level Node3D (not parented to player rotation) so the
## preview stays axis-aligned in world space regardless of where the
## kid is looking.
func _build_ghost_preview() -> void:
	_ghost_preview = MeshInstance3D.new()
	_ghost_preview.name = "GhostPreview"
	_ghost_preview.top_level = true   ## ignore parent transform — world-space placement
	var box := BoxMesh.new()
	box.size = Vector3(1.0, 1.0, 1.0)
	_ghost_preview.mesh = box
	_ghost_material = StandardMaterial3D.new()
	_ghost_material.albedo_color = Color(1, 1, 1, 0.4)
	_ghost_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ghost_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ghost_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_ghost_material.no_depth_test = false
	_ghost_preview.material_override = _ghost_material
	_ghost_preview.visible = false
	add_child(_ghost_preview)


## Show the ghost-preview cube at the cell the next K / RMB press
## will place a block into. Called every physics tick. Only visible
## when build mode is active.
## Adv I #1 perf fix: bail BEFORE the raycast + catalog walk when
## we're not in BUILD mode. Was running a full ray query through
## PhysicsDirectSpaceState3D every tick even during combat.
func _update_ghost_preview() -> void:
	if _ghost_preview == null or _build_grid == null:
		return
	# Cheap early-out — skip the raycast entirely outside BUILD mode.
	var active_kind: String = String(_hotbar[_active_slot]) if (_active_slot >= 0 and _active_slot < _hotbar.size()) else ""
	var svc := _ensure_game_mode_service()
	if svc.current_mode(active_kind) != GameModeService.Mode.BUILD:
		if _ghost_preview.visible:
			_ghost_preview.visible = false
		return
	var hit := _build_raycast()
	if hit.is_empty():
		_ghost_preview.visible = false
		return
	var hit_pos: Vector3 = hit.get("position", global_position)
	var normal: Vector3 = hit.get("normal", Vector3.UP)
	var cell := _build_grid.world_to_cell(hit_pos + normal * 0.5)
	if _build_grid.has_block_at(cell):
		_ghost_preview.visible = false
		return
	_ghost_preview.global_position = _build_grid.cell_to_world(cell)
	# Tint the ghost with the active block's color so kid sees what's
	# coming, not a generic white outline.
	var catalog := BlockKind.default_catalog()
	for k in catalog:
		if (k as BlockKind).block_id == active_kind:
			_ghost_material.albedo_color = (k as BlockKind).color
			_ghost_material.albedo_color.a = 0.45
			break
	_ghost_preview.visible = true


## Dispatch the LMB / "attack" action based on the active hotbar
## slot. Block held → break adjacent block; weapon (or empty) →
## swing sword. The cooldown is shared: kid can't spam-place
## buildings while attacking either.
func _dispatch_lmb() -> void:
	var svc := _ensure_game_mode_service()
	var active_kind: String = String(_hotbar[_active_slot]) if (_active_slot >= 0 and _active_slot < _hotbar.size()) else ""
	var mode := svc.current_mode(active_kind)
	match mode:
		GameModeService.Mode.BUILD:
			_try_break_block()
			_attack_cooldown = ATTACK_COOLDOWN * 0.5  ## faster mining than swinging
		_:
			_perform_attack()


func _ensure_game_mode_service() -> GameModeService:
	if _game_mode_service == null:
		_game_mode_service = GameModeService.new()
	return _game_mode_service


## Injection point for Minecraft-lite block placement. Called by
## GameplayRuntime once per session, after the BuildGrid node is
## added to the scene tree. Hotbar layout: slot 1 = current weapon
## (kid is in COMBAT mode by default — LMB attacks). Slots 2-5 = first
## 4 blocks from the catalog. Number keys 1..5 cycle.
func setup_build_grid(grid: BuildGrid) -> void:
	_build_grid = grid
	var default := BlockKind.default_catalog()
	_hotbar.clear()
	_hotbar.append("fist")   ## slot 0 = weapon → COMBAT mode default
	for i in mini(default.size(), 4):
		_hotbar.append((default[i] as BlockKind).block_id)
	_active_slot = 0
	hotbar_changed.emit(_active_slot, _hotbar[_active_slot])


func _process_build_input() -> void:
	if _build_grid == null or _hotbar.is_empty():
		return
	# Hotbar slot selection.
	for i in range(_hotbar.size()):
		if Input.is_action_just_pressed(_act("hotbar_%d" % (i + 1))):
			_active_slot = i
			hotbar_changed.emit(_active_slot, _hotbar[i])
	# Place or break — raycast 6m ahead.
	if Input.is_action_just_pressed(_act("place_block")):
		_try_place_block()
	if Input.is_action_just_pressed(_act("break_block")):
		_try_break_block()


func _build_raycast() -> Dictionary:
	if _build_grid == null:
		return {}
	# TPP placement must follow the camera's composition, never the character's
	# hips. The old body-forward ray put the block beside the thing the child was
	# visibly pointing at, which made building feel arbitrary.
	var origin := global_position + Vector3(0, 1.0, 0)
	var forward := -transform.basis.z.normalized()
	if _camera != null:
		var viewport := _camera.get_viewport()
		if viewport != null:
			var screen_center := viewport.get_visible_rect().size * 0.5
			origin = _camera.project_ray_origin(screen_center)
			forward = _camera.project_ray_normal(screen_center).normalized()
	var end := origin + forward * BUILD_RAY_RANGE
	var space := get_world_3d().direct_space_state
	var params := PhysicsRayQueryParameters3D.create(origin, end, 1, [self])
	var hit := space.intersect_ray(params)
	if not hit.is_empty():
		return hit
	# When the camera looks over empty ground, retain an intuitive TPP target
	# rather than falling back to a body-relative guess. The visual ghost makes
	# the exact snapped cell explicit before the child clicks.
	if absf(forward.y) > 0.0001:
		var distance_to_ground := -origin.y / forward.y
		if distance_to_ground > 0.0 and distance_to_ground <= BUILD_RAY_RANGE:
			return {"position": origin + forward * distance_to_ground, "normal": Vector3.UP}
	return {}


func _try_place_block() -> void:
	var hit := _build_raycast()
	var cell: Vector3i
	if hit.is_empty():
		return
	else:
		# Place adjacent to hit face — use normal to offset.
		var hit_pos: Vector3 = hit.get("position", global_position)
		var normal: Vector3 = hit.get("normal", Vector3.UP)
		cell = _build_grid.world_to_cell(hit_pos + normal * 0.5)
	_build_grid.place_block(cell, _hotbar[_active_slot])


## On landing, check whether the cell directly below the player is a
## spring block. If so, launch upward with a big arc (obby-style
## trampoline). Cheap — single dictionary lookup.
func _check_spring_block_launch() -> void:
	if _build_grid == null:
		return
	var below_pos := global_position + Vector3(0, -0.6, 0)
	var cell := _build_grid.world_to_cell(below_pos)
	if _build_grid.kind_at(cell) == "spring":
		velocity.y = 14.0
		jumped.emit()


func _try_break_block() -> void:
	var hit := _build_raycast()
	if hit.is_empty():
		return
	var hit_pos: Vector3 = hit.get("position", global_position)
	var normal: Vector3 = hit.get("normal", Vector3.UP)
	# Step into the block by half a cell in the negative-normal direction.
	var cell := _build_grid.world_to_cell(hit_pos - normal * 0.5)
	_build_grid.break_block(cell)


func _landing_squash() -> void:
	# Jolt Physics rejects non-uniform scale on CharacterBody3D collision
	# shapes — squash the mesh, not the body. (Was spamming the console
	# with "scale not supported" + "invalid transform" per frame.)
	if _character_mesh == null:
		return
	var tween := create_tween()
	tween.tween_property(_character_mesh, "scale", Vector3(1.12, 0.72, 1.12), 0.05)
	tween.tween_property(_character_mesh, "scale", Vector3.ONE, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _hard_landing_feedback() -> void:
	hard_landed.emit()
