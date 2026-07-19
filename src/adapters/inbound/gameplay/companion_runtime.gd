## Companion runtime for Bella (the ragdoll cat follower NPC).
##
## Spawned alongside the hero at session start. Bella follows the nearest hero
## at a soft leash distance, idles with subtle head/ear/tail motion, and runs
## a short gallop when the hero moves fast. This is intentionally a
## non-combatant, non-blocking decoration — no attack, no UI, no dialogue.
##
## Bella is the second visible member of the home cast (after Pestka). She
## appears in the world as a low-poly cat that walks between the player's
## legs, sits when idle, and adds warmth without gameplay pressure.
##
## Faithfully CC0: Bella.glb is derived from Styloo's CC0 cat rig
## (data/models/companions/bella.glb); see NOTICES.md.
class_name CompanionRuntime
extends Node3D

const BELLA_GLB := preload("res://data/models/companions/bella.glb")

## Distance at which Bella starts moving toward the hero.
const FOLLOW_ACTIVATION_DISTANCE := 4.0
## Distance at which Bella stops moving (her comfort zone behind the hero).
const FOLLOW_STOP_DISTANCE := 1.4
## Linear speed (m/s) of Bella's walking. Cats are not sprinters.
const WALK_SPEED := 2.2
## Linear speed when the hero is sprinting.
const RUN_SPEED := 4.6
## Rotation speed when turning toward the hero.
const TURN_SPEED := 6.0
## Vertical offset above terrain to avoid sinking into uneven ground.
const GROUND_OFFSET := 0.18
## Cat idle scale breathing amplitude (mild).
const BREATHE_AMP := 0.02
## Cat idle breathing rate (Hz).
const BREATHE_HZ := 0.8
## Tail sway amplitude when idle (radians around local Z).
const TAIL_SWAY_AMP := 0.18
## Tail sway rate (Hz).
const TAIL_SWAY_HZ := 0.5

var _bella: Node3D = null
var _root: Node3D = null
var _hero: Node3D = null
var _breath_t: float = 0.0
var _tail_t: float = 0.0
var _is_running: bool = false


func _ready() -> void:
	_root = Node3D.new()
	_root.name = "BellaRoot"
	add_child(_root)
	_spawn_bella()
	_find_hero()
	set_physics_process(true)


## Tear down Bella cleanly so a session restart doesn't leak her GLB's
## materials, the cached hero reference, or her Skeleton3D pose work.
## Children (_root, _bella) are freed automatically when this node is freed;
## we just null the references so _physics_process can't touch freed objects
## between the queue_free() and the actual deletion at end of frame.
func _exit_tree() -> void:
	set_physics_process(false)
	_hero = null
	_bella = null
	_root = null


## Spawn Bella's GLB and ground it. The GLB is pre-baked from the Styloo CC0
## cat (NOTICES.md) at 0.35× scale so she's a child-sized cat.
func _spawn_bella() -> void:
	if not ResourceLoader.exists(BELLA_GLB.resource_path):
		push_warning("[companion_runtime] Bella GLB missing at %s" % BELLA_GLB.resource_path)
		return
	var scene := BELLA_GLB.instantiate()
	if scene == null:
		push_warning("[companion_runtime] Bella GLB failed to instantiate")
		return
	scene.name = "Bella"
	_root.add_child(scene)
	_bella = scene
	_bella.visible = true


## Locate the active PlayerController in the scene tree. Bella follows the
## first one found (P1 in single player, P1 in split-screen). Falls back to
## scanning the tree by class because PlayerController does not currently
## register itself in a "players" group.
func _find_hero() -> void:
	var tree := get_tree()
	if tree == null:
		return
	# Prefer the gameplay runtime's authoritative P1 if present.
	var p1 := tree.get_first_node_in_group("players")
	if p1 is Node3D:
		_hero = p1
		return
	# Fall back to a class-name scan.
	for node in tree.get_nodes_in_group("_class_PlayerController"):
		if node is Node3D:
			_hero = node
			return
	var root_node := tree.current_scene if tree.current_scene != null else tree.root
	if root_node != null:
		var found := _find_by_class(root_node, "PlayerController")
		if found != null:
			_hero = found


func _find_by_class(node: Node, class_name_str: String) -> Node3D:
	if node == null:
		return null
	if node.is_class(class_name_str) or (node.get_script() != null and String(node.get_script().get_global_name()) == class_name_str):
		if node is Node3D:
			return node
	for child in node.get_children():
		var found := _find_by_class(child, class_name_str)
		if found != null:
			return found
	return null


func _physics_process(delta: float) -> void:
	if _bella == null:
		return
	if _hero == null or not is_instance_valid(_hero):
		_find_hero()
		if _hero == null:
			_idle_only(delta)
			return
	var hero_pos := _hero.global_position
	var bella_pos := _bella.global_position
	var to_hero := hero_pos - bella_pos
	to_hero.y = 0.0
	var dist := to_hero.length()

	# If Bella is well behind the hero, idle in place (don't micro-jitter).
	if dist < FOLLOW_STOP_DISTANCE:
		_idle_only(delta)
		return

	var dir := Vector3.ZERO
	if dist > 0.001:
		dir = to_hero / dist
	_is_running = dist > FOLLOW_ACTIVATION_DISTANCE * 1.8
	var speed := RUN_SPEED if _is_running else WALK_SPEED
	# Move Bella toward hero at the chosen speed, but never overshoot the stop
	# distance in one frame (would teleport past the hero).
	var step := minf(speed * delta, maxf(0.0, dist - FOLLOW_STOP_DISTANCE))
	var new_pos := bella_pos + dir * step
	# Vertical follow: cats can't fly. Track the hero's altitude so Bella stays
	# grounded alongside the player on slopes and stairs.
	new_pos.y = hero_pos.y
	_bella.global_position = new_pos

	# Smoothly turn Bella to face the hero's forward direction so the cat's
	# "front" (head + ears) orients naturally toward the player.
	if dist > 0.5:
		var target_yaw := atan2(dir.x, dir.z)
		var current_yaw := _bella.rotation.y
		_bella.rotation.y = lerp_angle(current_yaw, target_yaw, clampf(TURN_SPEED * delta, 0.0, 1.0))

	# Subtle running bob (vertical bounce) when moving fast.
	if _is_running:
		var bob := sin(Time.get_ticks_msec() * 0.012) * 0.04
		_bella.position.y = bob
	else:
		_bella.position.y = lerpf(_bella.position.y, 0.0, 4.0 * delta)

	_animate_idle(delta)


## Idle in place: subtle breathing scale + tail sway. Used when within stop
## distance, when the hero is gone, or while the GLB is still loading.
func _idle_only(delta: float) -> void:
	if _bella == null:
		return
	_bella.position.y = lerpf(_bella.position.y, 0.0, 4.0 * delta)
	_animate_idle(delta)


## Apply breathing + tail sway. Cheap (no skeleton work) — keeps the cat
## from looking frozen while the hero stands still. Tints the tail via the
## scene's existing bones if present, otherwise no-ops gracefully.
func _animate_idle(delta: float) -> void:
	_breath_t += delta * BREATHE_HZ * TAU
	_tail_t += delta * TAIL_SWAY_HZ * TAU
	var breathe := 1.0 + sin(_breath_t) * BREATHE_AMP
	_bella.scale = Vector3.ONE * breathe
	# Find a tail bone (Styloo rig: bone named "tail" or "ORG-tail" or similar).
	# If absent, the gentle body sway alone keeps the cat alive-looking.
	var skeleton := _find_skeleton(_bella)
	if skeleton != null:
		for bone_name in ["tail", "ORG-tail", "DEF-tail", "tail.001"]:
			var bone_idx := skeleton.find_bone(bone_name)
			if bone_idx < 0:
				continue
			var sway := sin(_tail_t) * TAIL_SWAY_AMP
			var rest_quat: Quaternion = skeleton.get_bone_rest(bone_idx).basis.get_rotation_quaternion()
			var sway_quat := Quaternion(Vector3.UP, sway)
			skeleton.set_bone_pose_rotation(bone_idx, rest_quat * sway_quat)
			break


func _find_skeleton(root: Node) -> Skeleton3D:
	if root is Skeleton3D:
		return root
	for child in root.get_children():
		var found := _find_skeleton(child)
		if found != null:
			return found
	return null


## Snap Bella to the floor at a given XZ, keeping her above the terrain.
## Called by GameplayRuntime once after spawn so she doesn't float or sink.
func place_on_terrain(terrain_y: float) -> void:
	if _bella == null:
		return
	var pos := _bella.global_position
	pos.y = terrain_y + GROUND_OFFSET
	_bella.global_position = pos


func get_bella_node() -> Node3D:
	return _bella
