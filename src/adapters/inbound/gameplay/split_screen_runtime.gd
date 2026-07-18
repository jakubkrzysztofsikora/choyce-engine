## Local two-player split-screen. Hosts the existing GameplayRuntime as the
## authoritative world (P1, left half, full HUD + build + combat) and adds a
## second SubViewport on the right that renders the SAME World3D from a second
## player's camera. P2 is a movement+combat character on the right-hand key set.
##
## Kept isolated from the single-player path: solo still launches GameplayRuntime
## directly. This wraps it only when the co-op button is used, so there is zero
## regression risk to solo play.
##
## Godot 4 split-screen pattern (per docs): two SubViewports sharing one World3D
## via set_world_3d(); each SubViewport's Camera3D becomes current for its own
## viewport. The right viewport has its own World2D (default) so no 2D bleeds.
class_name SplitScreenRuntime
extends Control

const PlayerScript := preload("res://src/adapters/inbound/gameplay/player_controller.gd")
const CHARACTER_MESH_P2 := "res://data/models/kenney/toon_characters/Models/GLB format/character-male-b.glb"

signal session_ended

var _runtime: Node = null            ## the wrapped GameplayRuntime (P1 world owner)
var _p2: PlayerController = null
var _p2_viewport: SubViewport = null
var _p1_events_stripped := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


## host_runtime: an already-instantiated GameplayRuntime added to the tree.
## We reparent nothing — P1 keeps rendering to the main viewport (left half via
## a SubViewportContainer is overkill; instead P1 uses the full screen and P2
## overlays the right half). Simpler + avoids reparenting the 1700-line runtime.
func setup(host_runtime: Node) -> SplitScreenRuntime:
	_runtime = host_runtime
	return self


## Build the P2 half once the world exists (call after runtime.start_session).
func attach_second_player() -> void:
	if _runtime == null:
		return
	var world_node := _runtime.get_node_or_null("WorldRenderer")
	if world_node == null:
		return
	var shared_world: World3D = _runtime.get_viewport().world_3d

	# Right-half SubViewportContainer.
	var container := SubViewportContainer.new()
	container.name = "P2Container"
	container.stretch = true
	container.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	container.anchor_left = 0.5
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(container)

	_p2_viewport = SubViewport.new()
	_p2_viewport.name = "P2Viewport"
	_p2_viewport.world_3d = shared_world      # same world = same props + enemies
	_p2_viewport.handle_input_locally = false
	_p2_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(_p2_viewport)

	# Second player, built in code (the P1 player is inline in the runtime
	# scene, not its own .tscn). Same pieces: CharacterBody3D + capsule +
	# Kenney mesh + a 3rd-person Camera3D that becomes current for THIS
	# SubViewport. Routed to the p2_ action set.
	_p2 = _build_player()
	_p2.set_action_prefix("p2_")
	_p2_viewport.add_child(_p2)
	# P1 begins as the turquoise, backpacked Ziemek. P2 is not a duplicate
	# avatar: switch the same grounded/facial rig to Gniewko's clean polo and
	# navy-trouser identity immediately after it enters the scene tree.
	_p2.set_hero_identity(PlayerController.HERO_IDENTITY_GNIEWKO)
	# Both children operate one shared BuildGrid and one shared inventory owned
	# by GameplayRuntime. P2 gets the same creative hotbar mechanics; its tool
	# signal is explicitly routed with P2 as the actor for correct target picks.
	var build_grid := _runtime.get("_build_grid") as BuildGrid
	if build_grid != null:
		_p2.setup_build_grid(build_grid)
	if _runtime.has_method("_on_player_tool_used_for"):
		_p2.tool_used.connect(func(tool_id: String, effect_origin: Vector3, forward: Vector3) -> void:
			_runtime.call("_on_player_tool_used_for", _p2, tool_id, effect_origin, forward)
		)
	if _runtime.has_method("_on_player_farted"):
		_p2.farted.connect(func(effect_origin: Vector3) -> void:
			_runtime.call("_on_player_farted", effect_origin)
		)
	var p1 := _runtime.get_node_or_null("PlayerController")
	var spawn := Vector3(2, 1, 0)
	if p1 != null:
		spawn = p1.global_position + Vector3(2, 0, 0)
	_p2.spawn_at(spawn)
	_p2.visible = true
	# P2 attacks the shared enemies too (enemy group is world-wide).
	if _runtime.has_method("_on_enemy_defeated") and _p2.has_signal("attacked"):
		pass  # P2 damages via its own arc scan in player_controller

	# Resolve the arrow-key conflict: P1's move_* also bind arrows. Strip the
	# arrow events from P1's actions for the co-op session so P2 owns them.
	_strip_p1_arrow_bindings()

	# A thin divider line between the two views.
	var divider := ColorRect.new()
	divider.color = Color(0, 0, 0, 0.9)
	divider.set_anchors_preset(Control.PRESET_CENTER)
	divider.anchor_left = 0.5
	divider.anchor_right = 0.5
	divider.offset_left = -2
	divider.offset_right = 2
	divider.offset_top = 0
	divider.grow_vertical = Control.GROW_DIRECTION_BOTH
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(divider)


## Build a P2 CharacterBody3D matching the inline P1 in gameplay_runtime.tscn:
## capsule collider, Kenney character mesh, and a 3rd-person camera. The camera
## make_current() (in player_controller._ready) binds to the nearest ancestor
## viewport — our SubViewport — so it renders the P2 view, not the root.
func _build_player() -> PlayerController:
	var body := CharacterBody3D.new()
	body.set_script(PlayerScript)
	body.name = "Player2"

	var col := CollisionShape3D.new()
	col.name = "CollisionShape3D"
	col.transform = Transform3D(Basis(), Vector3(0, 0.8, 0))
	var shape := CapsuleShape3D.new()
	shape.radius = 0.35
	# Match P1's physical envelope exactly. The former 1.6m capsule had a
	# different floor contact plane, so P2 could appear to hover alongside him.
	shape.height = 1.8
	col.shape = shape
	body.add_child(col)

	if ResourceLoader.exists(CHARACTER_MESH_P2):
		var mesh_scene: PackedScene = load(CHARACTER_MESH_P2)
		if mesh_scene != null:
			var mesh := mesh_scene.instantiate()
			mesh.name = "CharacterMesh"
			body.add_child(mesh)

	var cam := Camera3D.new()
	cam.name = "Camera3D"
	# Same third-person offset/tilt as P1's camera in the runtime scene. Keeping
	# one camera language prevents the right pane feeling like a high spectator
	# view rather than Gniewko's own adventure view.
	cam.transform = Transform3D(
		Basis(Vector3(1, 0, 0), deg_to_rad(15.0)),
		Vector3(0, 1.7, 4.2))
	body.add_child(cam)
	return body


## P1 keeps WASD; arrows go to P2. Removes arrow InputEventKeys from P1's
## move_* actions and restores them on teardown so solo is unaffected next time.
func _strip_p1_arrow_bindings() -> void:
	var arrow_map := {
		"move_forward": KEY_UP, "move_back": KEY_DOWN,
		"move_left": KEY_LEFT, "move_right": KEY_RIGHT,
	}
	for action in arrow_map:
		if not InputMap.has_action(action):
			continue
		for ev in InputMap.action_get_events(action):
			if ev is InputEventKey and ev.keycode == arrow_map[action]:
				InputMap.action_erase_event(action, ev)
	_p1_events_stripped = true


func _restore_p1_arrow_bindings() -> void:
	if not _p1_events_stripped:
		return
	var arrow_map := {
		"move_forward": KEY_UP, "move_back": KEY_DOWN,
		"move_left": KEY_LEFT, "move_right": KEY_RIGHT,
	}
	for action in arrow_map:
		if not InputMap.has_action(action):
			continue
		var already := false
		for ev in InputMap.action_get_events(action):
			if ev is InputEventKey and ev.keycode == arrow_map[action]:
				already = true
		if not already:
			var e := InputEventKey.new()
			e.keycode = arrow_map[action]
			InputMap.action_add_event(action, e)
	_p1_events_stripped = false


func teardown() -> void:
	_restore_p1_arrow_bindings()
	if _p2 != null and is_instance_valid(_p2):
		_p2.queue_free()
	queue_free()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_restore_p1_arrow_bindings()
