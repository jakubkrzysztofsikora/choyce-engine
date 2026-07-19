## Thin launcher: the very first thing the kid sees. One screen, one clear
## action — a big pulsing PLAY that drops straight into the Adventure world.
## Fully code-built (no fragile .tscn) and responsive: anchored controls +
## the project's canvas_items/expand stretch scale it to any viewport. Music
## via the AudioBank autoload; the intro is a realtime 3D cinematic built in a
## SubViewport so it feels like a trailer while staying instant/offline.
##
## Emits `play_pressed(coop: bool)` — main.gd wires it to the proven direct-launch path
## (_on_world_card_pressed) so we reuse the whole play→win loop, no new
## composition root.
class_name LauncherOverlay
extends CanvasLayer

signal play_pressed(coop: bool)

const REF := Vector2(1600.0, 960.0)  ## design reference; stretch scales from here
const ADVENTURE_TITLE := "Ziemek i Gniewko: Demo"
const _MUSIC := "adventure_island"
## A deliberate 7-second first impression: wide reveal, two hero attacks,
## monster recoil, camera push-in, then a clean hand-off to the launcher.
const CINEMATIC_LENGTH_SEC := 7.2
const HERO_A_MODEL := "res://data/models/kenney/toon_characters/Models/GLB format/character-male-a.glb"
const HERO_B_MODEL := "res://data/models/kenney/toon_characters/Models/GLB format/character-male-b.glb"
const MONSTER_MODEL := "res://data/models/quaternius/szkielet.glb"
## The supplied skeleton is authored about four times taller than the Kenney
## children. Keep this source-model compensation in one place so every trailer
## shot preserves a readable kid-versus-monster scale relationship.
const CINEMATIC_HERO_SCALE := 2.15
const CINEMATIC_MONSTER_SCALE := 0.72
const HERO_A_NAME := "ZIEMEK"
const HERO_B_NAME := "GNIEWKO"
const FACIAL_PERFORMANCE_SCRIPT := preload("res://src/adapters/inbound/gameplay/facial_performance.gd")
## VS-015: Voice durations in seconds for caption synchronization
const VOICE_DURATIONS := {
	"cinematic_ziemek_attack": 1.67,
	"cinematic_ziemek_monster": 1.44,
	"cinematic_gniewko_ready": 0.88,
	"cinematic_gniewko_help": 1.07,
}
## VS-015: Extra time after voice finishes before caption fades (seconds)
const CAPTION_FADEOUT_DELAY := 0.25

var _root: Control
var _title: Label
var _play_btn: Button
var _coop_btn: Button
var _subtitle: Label
var _shapes: Array[Dictionary] = []      ## {node, speed, phase, base}
var _t: float = 0.0
var _localization = null
## Realtime 3D cinematic nodes. The Control is only the presentation shell;
## all actors, camera, light, particles, and staging are actual Node3D nodes.
var _cutscene: Control = null
var _cinematic_container: SubViewportContainer = null
var _cinematic_viewport: SubViewport = null
var _cinematic_world: Node3D = null
var _cinematic_camera: Camera3D = null
var _hero_a: Node3D = null
var _hero_b: Node3D = null
var _monster: Node3D = null
var _hero_a_anim: AnimationPlayer = null
var _hero_b_anim: AnimationPlayer = null
var _monster_anim: AnimationPlayer = null
var _hero_a_face = null
var _hero_b_face = null
var _monster_face = null
var _cinematic_tween: Tween = null
var _cinematic_time: float = 0.0
var _flash: ColorRect = null
var _cinematic_caption: Label = null
var _menu_revealed: bool = false
var _menu_vignette: ColorRect = null


func setup(localization = null) -> LauncherOverlay:
	_localization = localization
	return self


func _ready() -> void:
	layer = 100  ## above every shell
	_build()
	_start_music()
	set_process(true)


## Kill every tween we created so they don't keep ticking after this CanvasLayer
## is freed (which would print "ObjectDB instances leaked at exit" warnings).
func _exit_tree() -> void:
	set_process(false)
	if _cinematic_tween != null and _cinematic_tween.is_valid():
		_cinematic_tween.kill()
		_cinematic_tween = null
	# SceneTree has no Tween — they are bound to this node, so freeing the node
	# tree below already invalidates them. The kill() above is just for the
	# long-lived cinematic tween we keep a handle to.


## Tear down launcher: stop music, kill cinematic, fade out + free.
func _shutdown() -> void:
	set_process(false)
	if _play_btn != null:
		_play_btn.disabled = true
	if _coop_btn != null:
		_coop_btn.disabled = true
	var bank := get_node_or_null("/root/AudioBank")
	if bank != null and bank.has_method("stop_voice"):
		bank.stop_voice()


func _build() -> void:
	_root = Control.new()
	_root.name = "LauncherRoot"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP  ## eat clicks behind us
	add_child(_root)

	# Animated gradient sky.
	var sky := ColorRect.new()
	sky.name = "Sky"
	sky.set_anchors_preset(Control.PRESET_FULL_RECT)
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sky.color = Color(0.15, 0.62, 0.86)
	sky.material = _make_gradient_material()
	_root.add_child(sky)

	# Floating shapes layer (drifting rounded rects — cheap "clouds/bubbles").
	var shapes_layer := Control.new()
	shapes_layer.name = "Shapes"
	shapes_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	shapes_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(shapes_layer)
	_spawn_shapes(shapes_layer)

	# Centre column — anchored to viewport centre so it stays put on resize.
	var col := VBoxContainer.new()
	col.name = "CenterColumn"
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 28)
	col.set_anchors_preset(Control.PRESET_CENTER)
	# Grow from the anchored centre; container sizes to content.
	col.grow_horizontal = Control.GROW_DIRECTION_BOTH
	col.grow_vertical = Control.GROW_DIRECTION_BOTH
	_root.add_child(col)

	_title = Label.new()
	_title.name = "Title"
	_title.text = _tr("launcher.title", "Ziemek i Gniewko: Demo")
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 96)
	_title.add_theme_color_override("font_color", Color(1, 1, 1))
	_title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.45))
	_title.add_theme_constant_override("shadow_offset_x", 4)
	_title.add_theme_constant_override("shadow_offset_y", 4)
	_title.pivot_offset = Vector2(0, 0)
	col.add_child(_title)

	_subtitle = Label.new()
	_subtitle.name = "Subtitle"
	_subtitle.text = _tr("launcher.subtitle", "Odkrywaj wyspę, spotykaj bohaterów i baw się po swojemu.")
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.add_theme_font_size_override("font_size", 34)
	_subtitle.add_theme_color_override("font_color", Color(1, 1, 0.85))
	_subtitle.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.4))
	_subtitle.add_theme_constant_override("shadow_offset_x", 2)
	_subtitle.add_theme_constant_override("shadow_offset_y", 2)
	col.add_child(_subtitle)

	# Spacer so the button sits below the titles.
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 24)
	col.add_child(spacer)

	_play_btn = Button.new()
	_play_btn.name = "PlayButton"
	_play_btn.text = _tr("launcher.play", "GRAJ")
	_play_btn.custom_minimum_size = Vector2(420, 140)
	_play_btn.add_theme_font_size_override("font_size", 64)
	_play_btn.focus_mode = Control.FOCUS_CLICK
	_style_play_button(_play_btn)

	# Co-op toggle button (local split-screen)
	_coop_btn = Button.new()
	_coop_btn.name = "CoopButton"
	_coop_btn.text = _tr("launcher.coop", "KOOPERACJA")
	_coop_btn.custom_minimum_size = Vector2(420, 140)
	_coop_btn.add_theme_font_size_override("font_size", 64)
	_coop_btn.focus_mode = Control.FOCUS_CLICK
	_style_play_button(_coop_btn)

	# Center both buttons within the column.
	var btn_wrap := HBoxContainer.new()
	btn_wrap.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_wrap.set("size_flags_horizontal", Control.SIZE_SHRINK_CENTER)
	btn_wrap.add_child(_play_btn)
	btn_wrap.add_child(_coop_btn)
	col.add_child(btn_wrap)

	_play_btn.pressed.connect(_on_play)
	_coop_btn.pressed.connect(_on_play_coop)

	# Menu starts hidden; the fight cutscene plays, then the beat drop reveals
	# it. col holds title/subtitle/button — hide the interactive parts until
	# the drop so the kid watches the intro first.
	_subtitle.modulate.a = 0.0
	btn_wrap.modulate.a = 0.0
	_title.modulate.a = 0.0
	# Invisible AND non-interactive during the cutscene, so an early Enter/tap
	# can't launch a session mid-intro. Re-enabled on the beat-drop reveal.
	_play_btn.disabled = true

	_build_cutscene()
	# Reveal the menu on the beat drop.
	var timer := get_tree().create_timer(CINEMATIC_LENGTH_SEC)
	timer.timeout.connect(_reveal_menu)


## Cinematic intro: a realtime 3D trailer shot rendered in an isolated
## SubViewport. Two actual toon characters attack an actual 3D monster while
## the camera dollies, lights flare, particles drift, and impact bursts sell
## the action. It is deliberately scripted rather than video-backed so it is
## deterministic, offline, responsive, and cheap to restart.
func _build_cutscene() -> void:
	_cutscene = Control.new()
	_cutscene.name = "Cutscene"
	_cutscene.set_anchors_preset(Control.PRESET_FULL_RECT)
	_cutscene.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_cutscene)

	_cinematic_container = SubViewportContainer.new()
	_cinematic_container.name = "Cinematic3D"
	_cinematic_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_cinematic_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cinematic_container.stretch = true
	_cinematic_container.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_cutscene.add_child(_cinematic_container)

	_cinematic_viewport = SubViewport.new()
	_cinematic_viewport.name = "CinematicViewport"
	_cinematic_viewport.size = Vector2i(int(REF.x), int(REF.y))
	_cinematic_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_cinematic_viewport.msaa_3d = Viewport.MSAA_2X
	_cinematic_container.add_child(_cinematic_viewport)

	_cinematic_world = Node3D.new()
	_cinematic_world.name = "TrailerWorld"
	_cinematic_viewport.add_child(_cinematic_world)
	_build_cinematic_stage()

	_hero_a = _spawn_cinematic_actor(HERO_A_MODEL, Vector3(-4.2, 0.0, 1.2), Vector3.ONE * CINEMATIC_HERO_SCALE)
	_hero_b = _spawn_cinematic_actor(HERO_B_MODEL, Vector3(4.2, 0.0, 1.0), Vector3.ONE * CINEMATIC_HERO_SCALE)
	# Keep the tall source skeleton inside the frame and at a child-readable
	# threat scale rather than letting its raw mesh proportions dominate the shot.
	_monster = _spawn_cinematic_actor(MONSTER_MODEL, Vector3(0.0, 0.0, -1.2), Vector3.ONE * CINEMATIC_MONSTER_SCALE)
	_hero_a_face = _attach_cinematic_face(_hero_a, false)
	_hero_b_face = _attach_cinematic_face(_hero_b, false)
	_monster_face = _attach_cinematic_face(_monster, true)
	_hero_a_anim = _find_animation_player(_hero_a)
	_hero_b_anim = _find_animation_player(_hero_b)
	_monster_anim = _find_animation_player(_monster)
	_face_actor(_hero_a, Vector3(0.0, 1.0, -1.0))
	_face_actor(_hero_b, Vector3(0.0, 1.0, -1.0))
	_face_actor(_monster, Vector3(0.0, 1.0, 3.0))
	_play_cinematic_clip(_hero_a_anim, ["idle", "static"])
	_play_cinematic_clip(_hero_b_anim, ["idle", "static"])
	_play_cinematic_clip(_monster_anim, ["idle", "static"])

	_cinematic_camera = Camera3D.new()
	_cinematic_camera.name = "TrailerCamera"
	_cinematic_camera.fov = 40.0
	_cinematic_camera.near = 0.05
	_cinematic_camera.far = 120.0
	_cinematic_world.add_child(_cinematic_camera)
	_cinematic_camera.position = Vector3(0.0, 3.65, 15.4)
	_cinematic_camera.look_at(Vector3(0.0, 1.25, -0.7), Vector3.UP)
	_cinematic_camera.current = true

	# Letterbox bars make the shot read as a trailer, while remaining kid-safe
	# and disappearing entirely before the launcher controls become interactive.
	var top_bar := ColorRect.new()
	top_bar.color = Color(0.015, 0.02, 0.04, 0.92)
	top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_bar.offset_bottom = 72.0
	top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cutscene.add_child(top_bar)
	var bottom_bar := ColorRect.new()
	bottom_bar.color = top_bar.color
	bottom_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom_bar.offset_top = -72.0
	bottom_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cutscene.add_child(bottom_bar)

	# A restrained trailer title sits over the 3D frame and gives the first
	# seconds a readable focal point without turning the fight into a UI panel.
	var hype := Label.new()
	hype.text = _tr("launcher.cutscene", "PRZYGODA CZEKA…")
	hype.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hype.add_theme_font_size_override("font_size", 44)
	hype.add_theme_color_override("font_color", Color(1, 1, 1, 0.92))
	hype.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	hype.add_theme_constant_override("shadow_offset_x", 3)
	hype.add_theme_constant_override("shadow_offset_y", 3)
	hype.set_anchors_preset(Control.PRESET_TOP_WIDE)
	hype.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hype.offset_top = 95.0
	hype.offset_bottom = 155.0
	hype.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cutscene.add_child(hype)
	hype.modulate.a = 0.0
	var hype_tw := create_tween().set_loops(4)
	hype_tw.tween_property(hype, "modulate:a", 0.88, 0.65)
	hype_tw.tween_property(hype, "modulate:a", 0.45, 0.65)

	# Captions keep the names and calls understandable even when the player is
	# playing quietly. The actual lines are ElevenLabs-generated Polish audio.
	_cinematic_caption = Label.new()
	_cinematic_caption.name = "CinematicCaption"
	_cinematic_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cinematic_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_cinematic_caption.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_cinematic_caption.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_cinematic_caption.offset_left = 180.0
	_cinematic_caption.offset_right = -180.0
	_cinematic_caption.offset_top = -190.0
	_cinematic_caption.offset_bottom = -116.0
	_cinematic_caption.add_theme_font_size_override("font_size", 30)
	_cinematic_caption.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.96))
	_cinematic_caption.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.8))
	_cinematic_caption.add_theme_constant_override("shadow_offset_x", 3)
	_cinematic_caption.add_theme_constant_override("shadow_offset_y", 3)
	_cinematic_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cinematic_caption.modulate.a = 0.0
	_cutscene.add_child(_cinematic_caption)

	_play_cinematic_sequence()

	# White flash overlay, invisible until the drop.
	_flash = ColorRect.new()
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.color = Color(1, 1, 1, 0)
	_root.add_child(_flash)


func _build_cinematic_stage() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.012, 0.025, 0.08)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.20, 0.28, 0.52)
	env.ambient_light_energy = 0.8
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.15
	env.glow_enabled = true
	env.glow_intensity = 1.05
	env.glow_bloom = 0.12
	env.fog_enabled = true
	env.fog_light_color = Color(0.08, 0.12, 0.28)
	env.fog_light_energy = 0.6
	env.fog_density = 0.012
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	_cinematic_world.add_child(world_env)

	var key := DirectionalLight3D.new()
	key.name = "KeyLight"
	key.rotation_degrees = Vector3(-42.0, -28.0, 0.0)
	key.light_color = Color(1.0, 0.78, 0.48)
	key.light_energy = 2.2
	key.shadow_enabled = true
	key.directional_shadow_max_distance = 45.0
	_cinematic_world.add_child(key)
	var rim := OmniLight3D.new()
	rim.name = "RimLight"
	rim.position = Vector3(0.0, 4.5, -5.0)
	rim.light_color = Color(0.28, 0.58, 1.0)
	rim.light_energy = 9.0
	rim.omni_range = 18.0
	_cinematic_world.add_child(rim)
	var warm := OmniLight3D.new()
	warm.name = "ImpactLight"
	warm.position = Vector3(0.0, 2.0, 1.0)
	warm.light_color = Color(1.0, 0.20, 0.08)
	warm.light_energy = 3.0
	warm.omni_range = 10.0
	_cinematic_world.add_child(warm)

	var floor_mesh := BoxMesh.new()
	floor_mesh.size = Vector3(34.0, 0.35, 24.0)
	var floor := MeshInstance3D.new()
	floor.name = "TrailerStage"
	floor.mesh = floor_mesh
	floor.position = Vector3(0.0, -0.28, 0.0)
	floor.material_override = _cinematic_material(Color(0.035, 0.07, 0.15), Color(0.02, 0.10, 0.28), 0.35)
	_cinematic_world.add_child(floor)

	var arena_mesh := CylinderMesh.new()
	arena_mesh.top_radius = 8.0
	arena_mesh.bottom_radius = 8.5
	arena_mesh.height = 0.18
	var arena := MeshInstance3D.new()
	arena.name = "ArenaRing"
	arena.mesh = arena_mesh
	arena.position = Vector3(0.0, -0.05, 0.0)
	arena.material_override = _cinematic_material(Color(0.08, 0.16, 0.28), Color(0.05, 0.30, 0.80), 0.9)
	_cinematic_world.add_child(arena)

	# Deep silhouettes in the background give the camera a real horizon and
	# scale instead of a flat color card.
	for i in range(7):
		var tower_mesh := CylinderMesh.new()
		tower_mesh.top_radius = 0.6 + float(i % 2) * 0.4
		tower_mesh.bottom_radius = 1.3 + float(i % 3) * 0.35
		tower_mesh.height = 4.5 + float(i % 3) * 1.8
		var tower := MeshInstance3D.new()
		tower.name = "BackdropSpire%d" % i
		tower.mesh = tower_mesh
		tower.position = Vector3(-12.0 + i * 4.0, tower_mesh.height * 0.5 - 0.3, -7.0 - (i % 2) * 2.0)
		tower.material_override = _cinematic_material(Color(0.025, 0.05, 0.13), Color(0.04, 0.12, 0.32), 0.2)
		_cinematic_world.add_child(tower)

	var dust := GPUParticles3D.new()
	dust.name = "CinematicDust"
	dust.amount = 180
	dust.lifetime = 7.0
	var dust_process := ParticleProcessMaterial.new()
	dust_process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	dust_process.emission_box_extents = Vector3(13.0, 3.0, 8.0)
	dust_process.gravity = Vector3(0.0, 0.08, 0.0)
	dust_process.initial_velocity_min = 0.2
	dust_process.initial_velocity_max = 0.8
	dust_process.scale_min = 0.5
	dust_process.scale_max = 1.4
	dust_process.color = Color(0.55, 0.72, 1.0, 0.38)
	dust.process_material = dust_process
	var dust_mesh := SphereMesh.new()
	dust_mesh.radius = 0.035
	dust_mesh.height = 0.07
	dust_mesh.material = _cinematic_material(Color(0.50, 0.72, 1.0, 0.6), Color(0.25, 0.55, 1.0), 1.2)
	dust.draw_pass_1 = dust_mesh
	dust.position = Vector3(0.0, 3.0, -1.0)
	_cinematic_world.add_child(dust)


func _cinematic_material(base: Color, emission: Color, energy: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = base
	mat.roughness = 0.72
	mat.metallic = 0.08
	mat.emission_enabled = true
	mat.emission = emission
	mat.emission_energy_multiplier = energy
	return mat


func _spawn_cinematic_actor(path: String, pos: Vector3, actor_scale: Vector3) -> Node3D:
	var actor: Node3D = null
	var packed := load(path) as PackedScene
	if packed != null:
		actor = packed.instantiate() as Node3D
	if actor == null:
		actor = _make_cinematic_fallback(path)
	actor.position = pos
	actor.scale = actor_scale
	_cinematic_world.add_child(actor)
	return actor


func _attach_cinematic_face(actor: Node3D, is_monster: bool):
	if actor == null:
		return null
	if is_monster:
		var face = FACIAL_PERFORMANCE_SCRIPT.new()
		face.name = "FacialPerformance"
		actor.add_child(face)
		# The skeleton is more compact than the heroes; its face remains visible
		# in the close shot without adding a giant overlay to the viewport.
		face.setup_face(Vector3(0.0, 1.34, 0.0), 0.31, 0.86)
		return face
	else:
		return FACIAL_PERFORMANCE_SCRIPT.attach_kenney_humanoid(actor)


func _make_cinematic_fallback(path: String) -> Node3D:
	var root := Node3D.new()
	root.name = "FallbackActor_%s" % path.get_file().get_basename()
	var body := MeshInstance3D.new()
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.42
	body_mesh.height = 1.6
	body.mesh = body_mesh
	body.material_override = _cinematic_material(
		Color(0.78, 0.22, 0.14) if "szkielet" in path else Color(0.18, 0.55, 0.95),
		Color(1.0, 0.12, 0.04) if "szkielet" in path else Color(0.08, 0.30, 1.0),
		1.0
	)
	body.position.y = 0.9
	root.add_child(body)
	var head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.48
	head_mesh.height = 0.96
	head.mesh = head_mesh
	head.position.y = 1.9
	head.material_override = body.material_override
	root.add_child(head)
	return root


func _find_animation_player(actor: Node3D) -> AnimationPlayer:
	if actor == null:
		return null
	return actor.find_child("AnimationPlayer", true, false) as AnimationPlayer


func _face_actor(actor: Node3D, target: Vector3) -> void:
	if actor != null:
		# The imported Kenney and Quaternius rigs are authored with their visual
		# front along local +Z. Godot's look_at aims a node's conventional front
		# (-Z), so compensate or the heroes appear to face away from the threat.
		actor.look_at(target, Vector3.UP)
		actor.rotate_y(PI)


func _play_cinematic_clip(player: AnimationPlayer, candidates: Array[String]) -> void:
	if player == null:
		return
	for candidate in candidates:
		if player.has_animation(candidate):
			player.play(candidate, 0.16)
			return
	for raw_name in player.get_animation_list():
		var name := String(raw_name).to_lower()
		for candidate in candidates:
			if name.begins_with(candidate.to_lower()):
				player.play(raw_name, 0.16)
				return


func _camera_rotation(position: Vector3, target: Vector3) -> Vector3:
	return Basis.looking_at(target - position, Vector3.UP).get_euler()


func _cinematic_voice(voice_name: String, pitch_scale: float) -> void:
	var bank := get_node_or_null("/root/AudioBank")
	if bank != null and bank.has_method("play_voice_variant"):
		bank.call("play_voice_variant", voice_name, pitch_scale)


func _cinematic_sfx(sfx_name: String) -> void:
	var bank := get_node_or_null("/root/AudioBank")
	if bank != null and bank.has_method("play_sfx"):
		bank.call("play_sfx", sfx_name)


func _cinematic_melee(style: String) -> void:
	var bank := get_node_or_null("/root/AudioBank")
	if bank != null and bank.has_method("play_melee_impact"):
		bank.call("play_melee_impact", style)


func _show_cinematic_line(speaker: String, line: String, voice_name: String, pitch_scale: float) -> void:
	# Face timing and caption timing must share one value. Keep it outside the
	# optional caption branch so cinematic facial animation also works if the
	# caption node is temporarily unavailable.
	var voice_duration: float = float(VOICE_DURATIONS.get(voice_name, 1.5))
	if _cinematic_caption != null:
		_cinematic_caption.text = "%s  •  %s" % [speaker, line]
		var caption_tween := create_tween()
		caption_tween.tween_property(_cinematic_caption, "modulate:a", 1.0, 0.08)
		## VS-015: Use actual voice duration + delay for caption timing
		var fade_start: float = voice_duration + CAPTION_FADEOUT_DELAY
		caption_tween.tween_interval(fade_start)
		caption_tween.tween_property(_cinematic_caption, "modulate:a", 0.0, 0.24).set_trans(Tween.TRANS_SINE)
	_cinematic_voice(voice_name, pitch_scale)
	var face = _hero_a_face if speaker == HERO_A_NAME else _hero_b_face
	if face != null:
		## VS-015: Use actual voice duration for facial animation
		face.speak_for(voice_duration, FacialPerformance.Emotion.HAPPY)


func _play_cinematic_sequence() -> void:
	_cinematic_tween = create_tween()
	_cinematic_tween.tween_interval(0.25)
	_cinematic_tween.tween_callback(func() -> void:
		_play_cinematic_clip(_hero_a_anim, ["run", "walk", "idle"])
		_play_cinematic_clip(_hero_b_anim, ["run", "walk", "idle"])
		_cinematic_sfx("footstep_grass")
	)
	# Establishing shot: the heroes enter a shared, grounded lane and remain
	# visibly turned toward the monster. Their imported run/walk clips carry the
	# body motion; root transforms only provide restrained screen movement.
	_cinematic_tween.tween_property(_hero_a, "position", Vector3(-2.55, 0.0, 0.65), 1.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_cinematic_tween.parallel().tween_property(_cinematic_camera, "position", Vector3(-0.8, 3.75, 14.6), 1.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_cinematic_tween.parallel().tween_property(_cinematic_camera, "rotation", _camera_rotation(Vector3(-0.8, 3.75, 14.6), Vector3(0.0, 1.15, -0.65)), 1.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_cinematic_tween.tween_callback(func() -> void:
		_face_actor(_hero_a, _monster.global_position + Vector3(0.0, 1.0, 0.0))
		_face_actor(_hero_b, _monster.global_position + Vector3(0.0, 1.0, 0.0))
	)

	# First hit: a readable anticipation, short lunge, visible contact, and
	# smooth recovery. No bounce or roll is applied to the actor root.
	_cinematic_tween.tween_callback(func() -> void:
		_play_cinematic_clip(_hero_a_anim, ["attack-melee-right", "attack", "kick"])
		_show_cinematic_line(HERO_A_NAME, "Gniewko!", "cinematic_ziemek_attack", 0.98)
		_cinematic_sfx("swing_whoosh")
	)
	_cinematic_tween.tween_interval(0.22)
	_cinematic_tween.tween_property(_hero_a, "position", Vector3(-2.08, 0.0, 0.25), 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_cinematic_tween.tween_callback(func() -> void:
		_cinematic_impact(Vector3(-0.62, 1.25, -0.75), Color(0.30, 0.70, 1.0))
		_cinematic_sfx("punch_thud")
	)
	_cinematic_tween.tween_property(_monster, "position", Vector3(0.34, 0.0, -1.0), 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_cinematic_tween.parallel().tween_property(_monster, "scale", Vector3.ONE * CINEMATIC_MONSTER_SCALE * 1.10, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_cinematic_tween.tween_property(_hero_a, "position", Vector3(-2.55, 0.0, 0.65), 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_cinematic_tween.parallel().tween_property(_monster, "scale", Vector3.ONE * CINEMATIC_MONSTER_SCALE, 0.28).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_cinematic_tween.tween_callback(func() -> void:
		_play_cinematic_clip(_hero_a_anim, ["idle", "static"])
	)

	# Lateral camera sweep into a second shot, then the second hero enters from
	# frame right. Camera rotation is tweened with position so the framing stays
	# intentional instead of sliding past a frozen aim direction.
	_cinematic_tween.tween_property(_cinematic_camera, "position", Vector3(1.3, 3.15, 12.0), 0.72).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_cinematic_tween.parallel().tween_property(_cinematic_camera, "rotation", _camera_rotation(Vector3(1.3, 3.15, 12.0), Vector3(0.0, 1.1, -0.55)), 0.72).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_cinematic_tween.parallel().tween_property(_hero_b, "position", Vector3(2.5, 0.0, 0.55), 0.95).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_cinematic_tween.tween_callback(func() -> void:
		_face_actor(_hero_b, _monster.global_position + Vector3(0.0, 1.0, 0.0))
		_play_cinematic_clip(_hero_b_anim, ["attack-melee-left", "attack", "kick"])
		_show_cinematic_line(HERO_B_NAME, "Ziemek!", "cinematic_gniewko_ready", 0.94)
		_cinematic_sfx("swing_whoosh")
	)
	_cinematic_tween.tween_interval(0.20)
	_cinematic_tween.tween_property(_hero_b, "position", Vector3(2.05, 0.0, 0.18), 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_cinematic_tween.tween_callback(func() -> void:
		_cinematic_impact(Vector3(0.72, 1.35, -0.52), Color(1.0, 0.46, 0.16))
		_cinematic_sfx("kick_impact")
	)
	_cinematic_tween.tween_property(_monster, "position", Vector3(-0.22, 0.0, -0.95), 0.17).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_cinematic_tween.parallel().tween_property(_monster, "scale", Vector3.ONE * CINEMATIC_MONSTER_SCALE * 1.10, 0.17).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_cinematic_tween.tween_property(_hero_b, "position", Vector3(2.5, 0.0, 0.55), 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_cinematic_tween.parallel().tween_property(_monster, "position", Vector3(0.0, 0.0, -1.2), 0.30).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_cinematic_tween.parallel().tween_property(_monster, "scale", Vector3.ONE * CINEMATIC_MONSTER_SCALE, 0.30).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_cinematic_tween.tween_callback(func() -> void:
		_play_cinematic_clip(_hero_b_anim, ["idle", "static"])
	)

	# The monster answers while the camera pushes into a closer, lower
	# composition. The authored monster attack provides the action; there is no
	# artificial root spin.
	_cinematic_tween.tween_callback(func() -> void:
		_play_cinematic_clip(_monster_anim, ["attack", "hit", "idle"])
		_show_cinematic_line(HERO_A_NAME, "Potwór!", "cinematic_ziemek_monster", 0.98)
		_cinematic_sfx("swing_whoosh")
	)
	_cinematic_tween.tween_property(_cinematic_camera, "position", Vector3(0.0, 2.65, 9.7), 0.86).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_cinematic_tween.parallel().tween_property(_cinematic_camera, "rotation", _camera_rotation(Vector3(0.0, 2.65, 9.7), Vector3(0.0, 1.15, -0.75)), 0.86).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_cinematic_tween.tween_interval(0.50)

	# Final synchronized hit: two small forward steps, bright contact, then a
	# controlled settle before the launcher fades in.
	_cinematic_tween.tween_callback(func() -> void:
		_face_actor(_hero_a, _monster.global_position + Vector3(0.0, 1.0, 0.0))
		_face_actor(_hero_b, _monster.global_position + Vector3(0.0, 1.0, 0.0))
		_play_cinematic_clip(_hero_a_anim, ["attack-kick-right", "attack", "idle"])
		_play_cinematic_clip(_hero_b_anim, ["attack-kick-left", "attack", "idle"])
		_show_cinematic_line(HERO_B_NAME, "Uwaga!", "cinematic_gniewko_help", 0.94)
		_cinematic_sfx("swing_whoosh")
	)
	_cinematic_tween.tween_property(_hero_a, "position", Vector3(-2.05, 0.0, 0.25), 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_cinematic_tween.parallel().tween_property(_hero_b, "position", Vector3(2.0, 0.0, 0.20), 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_cinematic_tween.tween_callback(func() -> void:
		_cinematic_impact(Vector3(0.0, 1.55, -0.5), Color(1.0, 0.84, 0.28))
		_cinematic_sfx("kick_impact")
	)
	_cinematic_tween.tween_property(_hero_a, "position", Vector3(-2.4, 0.0, 0.55), 0.28).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_cinematic_tween.parallel().tween_property(_hero_b, "position", Vector3(2.35, 0.0, 0.52), 0.28).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_cinematic_tween.tween_callback(func() -> void:
		_cinematic_impact(Vector3(0.0, 1.6, -0.3), Color(0.56, 0.82, 1.0))
		_flash_cinematic(Color(0.78, 0.90, 1.0), 0.7)
	)
	_cinematic_tween.tween_callback(func() -> void:
		_play_cinematic_clip(_hero_a_anim, ["idle", "static"])
		_play_cinematic_clip(_hero_b_anim, ["idle", "static"])
	)
	_cinematic_tween.tween_interval(0.75)


func _cinematic_impact(at: Vector3, tint: Color) -> void:
	if _cinematic_world == null:
		return
	if _monster_face != null:
		_monster_face.set_emotion(FacialPerformance.Emotion.HURT, 0.56)
	var burst := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.22
	mesh.height = 0.44
	burst.mesh = mesh
	burst.material_override = _cinematic_material(Color(tint.r, tint.g, tint.b, 0.75), tint, 3.5)
	burst.position = at
	_cinematic_world.add_child(burst)
	var light := OmniLight3D.new()
	light.light_color = tint
	light.light_energy = 14.0
	light.omni_range = 5.5
	light.position = at
	_cinematic_world.add_child(light)
	var burst_tween := create_tween().set_parallel(true)
	burst_tween.tween_property(burst, "scale", Vector3.ONE * 4.5, 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	burst_tween.tween_property(light, "light_energy", 0.0, 0.48)
	burst_tween.chain().tween_callback(func() -> void:
		burst.queue_free()
		light.queue_free()
	)
	_flash_cinematic(tint, 0.28)


func _flash_cinematic(tint: Color, strength: float) -> void:
	if _flash == null:
		return
	var flash_tween := create_tween()
	flash_tween.tween_property(_flash, "color", Color(tint.r, tint.g, tint.b, strength), 0.045)
	flash_tween.tween_property(_flash, "color:a", 0.0, 0.34).set_trans(Tween.TRANS_SINE)


	## Beat drop: flash, snap the menu in, fade the 3D trailer, and reveal the
	## launcher controls.
func _reveal_menu() -> void:
	if _menu_revealed:
		return
	_menu_revealed = true

	# Flash punch.
	if _flash != null:
		var ftw := create_tween()
		ftw.tween_property(_flash, "color:a", 0.85, 0.06)
		ftw.tween_property(_flash, "color:a", 0.0, 0.45)

	# Keep the final rendered 3D action frame as the launcher backdrop. The
	# previous full fade exposed the debug-like gradient and erased the promise
	# made by the trailer at precisely the moment the child chooses to play.
	if _cinematic_container != null and is_instance_valid(_cinematic_container):
		_cinematic_container.modulate.a = 1.0
	if _cinematic_viewport != null:
		# One final frame is enough for a living key art background. Freezing it
		# avoids paying to animate a hidden attract-mode scene while the launcher
		# waits for the child.
		_cinematic_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	if _cutscene != null:
		# Trailer-specific bars, hype text and captions should not compete with
		# the menu, but the rendered 3D image remains deliberately present.
		for child in _cutscene.get_children():
			if child != _cinematic_container:
				child.visible = false

	if _menu_vignette == null:
		_menu_vignette = ColorRect.new()
		_menu_vignette.name = "CinematicMenuVignette"
		_menu_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
		_menu_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_menu_vignette.color = Color(0.008, 0.018, 0.05, 0.0)
		_root.add_child(_menu_vignette)
		var vignette_fade := create_tween()
		vignette_fade.tween_property(_menu_vignette, "color:a", 0.52, 0.42)

	# The cutscene was constructed after the menu, so promote the launcher
	# controls above the held frame rather than depending on a transparent fade.
	var menu_column := _root.get_node_or_null("CenterColumn") as Control
	if menu_column != null:
		_root.move_child(menu_column, _root.get_child_count() - 1)

	# Menu pops in (title, subtitle, GRAJ).
	_title.pivot_offset = Vector2(_title.size.x * 0.5, _title.size.y * 0.5)
	_title.scale = Vector2(0.6, 0.6)
	var mtw := create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	mtw.tween_property(_title, "scale", Vector2.ONE, 0.5)
	mtw.tween_property(_title, "modulate:a", 1.0, 0.4)
	mtw.tween_property(_subtitle, "modulate:a", 1.0, 0.5).set_delay(0.15)
	var btn_wrap := _play_btn.get_parent()
	if btn_wrap != null:
		mtw.tween_property(btn_wrap, "modulate:a", 1.0, 0.5).set_delay(0.25)
	_play_btn.disabled = false
	_coop_btn.disabled = false

	# Keep the frozen cutscene as the static menu key art until the child presses
	# Play. It is owned by this overlay and is released normally with it.


## Animated sky: vertical gradient + a soft radial sun glow that breathes +
## slow drifting light bands. Pure canvas_item shader, no texture assets.
func _make_gradient_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;

uniform vec4 top_color : source_color = vec4(0.16, 0.62, 0.95, 1.0);
uniform vec4 bottom_color : source_color = vec4(0.58, 0.88, 0.72, 1.0);
uniform vec4 sun_color : source_color = vec4(1.0, 0.96, 0.72, 1.0);
uniform vec2 sun_pos = vec2(0.80, 0.24);   // top-right, in UV space
uniform float band_speed : hint_range(0.0, 0.5) = 0.06;

void fragment() {
	// Base vertical gradient.
	vec3 col = mix(top_color.rgb, bottom_color.rgb, UV.y);

	// Breathing radial sun glow (aspect-corrected so it stays round-ish).
	vec2 d = UV - sun_pos;
	d.x *= 1.7;
	float dist = length(d);
	float breath = 0.5 + 0.5 * sin(TIME * 0.8);
	float glow = smoothstep(0.55, 0.0, dist) * (0.55 + 0.25 * breath);
	col = mix(col, sun_color.rgb, glow);

	// Slow drifting diagonal light bands for gentle motion.
	float band = sin((UV.x + UV.y) * 6.0 - TIME * band_speed * 10.0);
	col += band * 0.015;

	COLOR = vec4(col, 1.0);
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	return mat


func _spawn_shapes(parent: Control) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260719
	for i in range(7):
		var c := ColorRect.new()
		c.name = "Shape%d" % i
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var s := rng.randf_range(90.0, 220.0)
		c.size = Vector2(s, s * 0.62)
		c.color = Color(1, 1, 1, rng.randf_range(0.10, 0.22))
		var base := Vector2(
			rng.randf_range(0.0, REF.x),
			rng.randf_range(0.0, REF.y)
		)
		c.position = base
		parent.add_child(c)
		_shapes.append({
			"node": c,
			"speed": rng.randf_range(12.0, 34.0),
			"phase": rng.randf_range(0.0, TAU),
			"base": base,
		})


func _style_play_button(btn: Button) -> void:
	var mk := func(bg: Color, border: Color) -> StyleBoxFlat:
		var sb := StyleBoxFlat.new()
		sb.bg_color = bg
		sb.set_corner_radius_all(70)
		sb.set_border_width_all(6)
		sb.border_color = border
		sb.set_content_margin_all(24)
		sb.shadow_color = Color(0, 0, 0, 0.35)
		sb.shadow_size = 12
		sb.shadow_offset = Vector2(0, 8)
		return sb
	btn.add_theme_stylebox_override("normal", mk.call(Color(0.16, 0.78, 0.42), Color(1, 1, 1, 0.9)))
	btn.add_theme_stylebox_override("hover", mk.call(Color(0.20, 0.88, 0.50), Color(1, 1, 1)))
	btn.add_theme_stylebox_override("pressed", mk.call(Color(0.12, 0.64, 0.34), Color(1, 1, 1, 0.8)))
	btn.add_theme_stylebox_override("focus", mk.call(Color(0.20, 0.88, 0.50), Color(1, 1, 0.6)))
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_pressed_color", Color(0.92, 1, 0.92))


func _process(delta: float) -> void:
	_t += delta
	# Gentle idle pulse on the PLAY button — only after the beat-drop reveal,
	# so it doesn't fight the reveal pop-in tween.
	if _menu_revealed and _play_btn != null and is_instance_valid(_play_btn):
		var pulse := 1.0 + sin(_t * 2.4) * 0.04
		_play_btn.scale = Vector2(pulse, pulse)
	# Drift floating shapes; wrap across the reference width.
	for s in _shapes:
		var node: ColorRect = s["node"]
		if not is_instance_valid(node):
			continue
		var base: Vector2 = s["base"]
		var x := base.x + fmod(_t * float(s["speed"]), REF.x + 240.0) - 120.0
		var y := base.y + sin(_t * 0.6 + float(s["phase"])) * 18.0
		node.position = Vector2(x, y)


func _on_play() -> void:
	set_process(false)
	if _play_btn != null:
		_play_btn.disabled = true
	if _coop_btn != null:
		_coop_btn.disabled = true
	var bank := get_node_or_null("/root/AudioBank")
	if bank != null and bank.has_method("stop_voice"):
		bank.stop_voice()
	# Quick press feedback, then hand off.
	var tw := create_tween()
	tw.tween_property(_root, "modulate:a", 0.0, 0.35).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func() -> void:
		_stop_music()
		play_pressed.emit(false)
		queue_free()
	)


func _on_play_coop() -> void:
	set_process(false)
	if _play_btn != null:
		_play_btn.disabled = true
	if _coop_btn != null:
		_coop_btn.disabled = true
	var bank := get_node_or_null("/root/AudioBank")
	if bank != null and bank.has_method("stop_voice"):
		bank.stop_voice()
	# Quick press feedback, then hand off with co-op flag.
	var tw := create_tween()
	tw.tween_property(_root, "modulate:a", 0.0, 0.35).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func() -> void:
		_stop_music()
		play_pressed.emit(true)
		queue_free()
	)


func _start_music() -> void:
	var bank := get_node_or_null("/root/AudioBank")
	if bank != null and bank.has_method("play_music"):
		bank.play_music(_MUSIC, true)


func _stop_music() -> void:
	var bank := get_node_or_null("/root/AudioBank")
	if bank != null and bank.has_method("stop_music"):
		bank.stop_music(true)


func _tr(key: String, fallback: String) -> String:
	if _localization != null and _localization.has_method("translate"):
		var v: String = _localization.translate(key)
		if v != "" and v != key:
			return v
	return fallback
