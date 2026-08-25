class_name SplitScreenManager
extends Control
## Builds and rebuilds 1-4 split-screen panes around ONE shared World3D.
##
## THE RULE: every player SubViewport points at the same World3D and has
## own_world_3d = false. If own_world_3d is true you get N independent physics
## simulations of the same level, silently desynced. That is the single most
## expensive mistake available in this architecture.
##
## The level lives inside a persistent, non-rendering WorldHost viewport so its
## lifetime is decoupled from pane lifetime (last player leaving must not free
## the world).

@export var level_scene: PackedScene
@export var player_scene: PackedScene
@export var spawn_radius: float = 6.0
## Quality tiers by player count. Spike A showed shadow cascades, not
## resolution, are the lever that matters here.
@export var graphics_profile: GraphicsProfile

var last_graphics: Dictionary = {}

var shared_world: World3D
var world_host: SubViewport
var grid: GridContainer
var level: Node3D

var _panes: Dictionary = {}  # player_id -> SubViewportContainer


func _ready() -> void:
	# Offsets too, not just anchors: PRESET_FULL_RECT with stale offsets leaves
	# this Control at 0x0 and every pane collapses to its minimum size.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	shared_world = World3D.new()

	world_host = SubViewport.new()
	world_host.name = "WorldHost"
	world_host.own_world_3d = false
	world_host.world_3d = shared_world
	# disable_3d is load-bearing: without it this viewport allocates a full 3D
	# render pipeline it will never use, and a tiny size makes the renderer spam
	# mipmap/uniform-set errors every frame. Physics and the scenario live in
	# World3D, not in this viewport, so nothing is lost by disabling its render.
	world_host.disable_3d = true
	world_host.render_target_update_mode = SubViewport.UPDATE_DISABLED
	world_host.size = Vector2i(32, 32)
	add_child(world_host)

	grid = GridContainer.new()
	grid.name = "PaneGrid"
	grid.add_theme_constant_override("h_separation", 2)
	grid.add_theme_constant_override("v_separation", 2)
	add_child(grid)
	# Anchors AND offsets, applied after parenting. set_anchors_preset alone
	# leaves stale offsets and the grid ends up 0x0, which starves every
	# SubViewport to 0x0 and makes the renderer spam mipmap/uniform errors.
	grid.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	if level_scene:
		level = level_scene.instantiate()
		world_host.add_child(level)

	var reg := PlayerRegistrySystem.instance
	reg.player_joined.connect(_on_player_joined)
	reg.player_left.connect(_on_player_left)


func _on_player_joined(profile: SandboxPlayerProfile) -> void:
	_spawn_body(profile)
	_rebuild_panes()


func _on_player_left(profile: SandboxPlayerProfile) -> void:
	if is_instance_valid(profile.body):
		profile.body.queue_free()
	_rebuild_panes()


func _spawn_body(profile: SandboxPlayerProfile) -> void:
	if player_scene == null:
		push_error("SplitScreenManager: player_scene not set")
		return
	var body := player_scene.instantiate()
	var angle := TAU * float(profile.player_id) / float(PlayerRegistrySystem.MAX_PLAYERS)
	body.position = Vector3(cos(angle) * spawn_radius, 2.0, sin(angle) * spawn_radius)
	# setup() BEFORE add_child(). add_child runs _ready synchronously, and the
	# player's _ready reads profile/device to colour its mesh and to bind its
	# input device. Setting up afterwards leaves every player white and on
	# device -1, i.e. all four sharing the keyboard.
	if body.has_method("setup"):
		body.setup(profile)
	world_host.add_child(body)
	profile.body = body


## Full teardown + rebuild. Cheap (max 4 panes) and avoids layout drift bugs
## that creep in when you try to mutate the grid in place.
func _rebuild_panes() -> void:
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()
	_panes.clear()

	var profiles := PlayerRegistrySystem.instance.profiles()
	var n := profiles.size()
	if n == 0:
		return

	# 1P full, 2P side-by-side (keeps vertical FOV, better for 3D than
	# a horizontal split), 3-4P quadrants.
	grid.columns = 1 if n == 1 else 2

	for profile in profiles:
		var container := SubViewportContainer.new()
		container.name = "Pane%d" % profile.player_id
		container.stretch = true
		container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		container.size_flags_vertical = Control.SIZE_EXPAND_FILL
		# Floor the size so a transient 0x0 layout frame can never reach the
		# renderer as a 0x0 render target.
		container.custom_minimum_size = Vector2(160, 90)

		var vp := SubViewport.new()
		vp.own_world_3d = false          # <-- the rule
		vp.world_3d = shared_world       # <-- the rule
		vp.handle_input_locally = false
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		container.add_child(vp)

		var cam := Camera3D.new()
		cam.name = "Camera3D"
		cam.fov = 70.0
		vp.add_child(cam)
		cam.make_current()

		# Each pane needs its own listener node even though Godot can only have
		# ONE active 3D listener at a time. Kept here so the audio router has a
		# per-player transform to read when we replace positional audio with
		# scripted per-player panning.
		var listener := AudioListener3D.new()
		listener.name = "Listener"
		cam.add_child(listener)

		# Per-pane UI goes INSIDE the SubViewport, not into the
		# SubViewportContainer. SubViewportContainer manages the geometry of all
		# its children; a sibling Control fights it and the layout collapses.
		var hud := _make_hud(profile)
		vp.add_child(hud)
		hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

		grid.add_child(container)
		_panes[profile.player_id] = container

		profile.viewport = vp
		profile.camera = cam
		if is_instance_valid(profile.body) and profile.body.has_method("attach_camera"):
			profile.body.attach_camera(cam)

	_apply_graphics(profiles.size())


func _apply_graphics(player_count: int) -> void:
	if graphics_profile == null or level == null:
		return
	var vps: Array = []
	for pid in _panes:
		vps.append(_panes[pid].get_child(0))
	last_graphics = GraphicsTier.apply(graphics_profile, level, vps, player_count)


func _make_hud(profile: SandboxPlayerProfile) -> Control:
	var layer := Control.new()
	layer.name = "HUD"
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var label := Label.new()
	label.name = "NameLabel"
	label.text = "%s  (device %d)" % [profile.display_name, profile.device_id]
	label.add_theme_color_override("font_color", profile.colour)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("outline_size", 6)
	label.position = Vector2(12, 10)
	layer.add_child(label)

	# Player-colour border so four people on one TV can find their own pane.
	var border := Panel.new()
	border.name = "Border"
	border.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.border_color = profile.colour
	sb.set_border_width_all(3)
	border.add_theme_stylebox_override("panel", sb)
	layer.add_child(border)

	# Crosshair. Every gameplay ray originates at the aim pivot and points along
	# the camera's forward axis, which projects to the centre of the pane — so
	# without a reticle the player has no idea what they are targeting.
	var cross := Label.new()
	cross.name = "Crosshair"
	cross.text = "+"
	cross.set_anchors_preset(Control.PRESET_CENTER)
	cross.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	cross.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	cross.add_theme_constant_override("outline_size", 5)
	cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(cross)

	# Interaction prompt + build readout.
	var prompt := Label.new()
	prompt.name = "Prompt"
	prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	prompt.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	prompt.add_theme_constant_override("outline_size", 5)
	prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(prompt)

	var hud_script := load("res://gameplay/ui/player_hud.gd")
	if hud_script:
		layer.set_script(hud_script)
		layer.set(&"player_id", profile.player_id)
	return layer


## Diagnostic: proves every pane shares one physics space.
func spaces_are_shared() -> bool:
	var space := world_host.world_3d.space
	for pid in _panes:
		var vp: SubViewport = _panes[pid].get_child(0)
		if vp.world_3d.space != space:
			return false
	return true
