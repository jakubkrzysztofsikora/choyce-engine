## LandingScreen — boot shell shown when the app starts.
## Kid sees big Play / Create buttons with an animated sky background.
## Hexagonal: inbound UI adapter only — no domain logic here.
## Scene tree is built programmatically so that LandingScreen.new() in tests
## produces a fully functional node without loading a TSCN.
class_name LandingScreen
extends Control

signal play_pressed
signal create_pressed
signal parent_pressed
signal world_card_pressed(project_id: String, world_id: String)

var _project_store: ProjectStorePort  ## injected via setup()
var _profile: PlayerProfile           ## injected via setup()
var _localization: LocalizationPolicyPort

## Cloud Tween refs kept alive so the loops don't get garbage-collected.
var _cloud_tweens: Array[Tween] = []

# Internal node refs (built in _ready).
var _btn_play: Button
var _btn_create: Button
var _btn_parent: Button
var _picker_layer: CanvasLayer
var _card_row: HBoxContainer


func _ready() -> void:
	_build_scene_tree()
	_apply_theme()
	_start_cloud_drift()
	_wire_buttons()
	_wire_picker_close()
	_start_landing_audio.call_deferred()


## DI entry point — call after adding to tree.
func setup(profile, project_store, localization) -> LandingScreen:
	_profile = profile
	_project_store = project_store
	_localization = localization
	return self


# ---------- scene construction ----------

func _build_scene_tree() -> void:
	# BgLayer
	var bg_layer := Control.new()
	bg_layer.name = "BgLayer"
	bg_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg_layer)

	var sky_tex: Texture2D = load("res://data/textures/landing/sky_main.png") if ResourceLoader.exists("res://data/textures/landing/sky_main.png") else null
	if sky_tex != null:
		var sky := TextureRect.new()
		sky.name = "SkyGradient"
		sky.texture = sky_tex
		sky.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sky.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		sky.set_anchors_preset(Control.PRESET_FULL_RECT)
		sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bg_layer.add_child(sky)
	else:
		var sky := ColorRect.new()
		sky.name = "SkyGradient"
		sky.set_anchors_preset(Control.PRESET_FULL_RECT)
		sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sky.color = Color(0.44, 0.73, 0.98)
		bg_layer.add_child(sky)

	# Sun element (above sky, below clouds)
	# W1.10: anchor top-right so the sun stays in the corner across viewport
	# widths (1280-2560+). Previously hardcoded Vector2(1540, 60) clipped off
	# the right edge on the 1600px project default.
	var sun_tex: Texture2D = load("res://data/textures/landing/sun.png") if ResourceLoader.exists("res://data/textures/landing/sun.png") else null
	if sun_tex != null:
		var sun := TextureRect.new()
		sun.name = "Sun"
		sun.texture = sun_tex
		sun.custom_minimum_size = Vector2(192, 192)
		sun.size = Vector2(192, 192)
		sun.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		sun.offset_left = -252
		sun.offset_top = 60
		sun.offset_right = -60
		sun.offset_bottom = 252
		sun.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bg_layer.add_child(sun)

	# Clouds
	var cloud_files := ["res://data/textures/landing/cloud_01.png", "res://data/textures/landing/cloud_02.png", "res://data/textures/landing/cloud_03.png"]
	for i in range(1, 4):
		var cloud_path: String = cloud_files[i - 1]
		var cloud_tex: Texture2D = load(cloud_path) if ResourceLoader.exists(cloud_path) else null
		if cloud_tex != null:
			var cloud := TextureRect.new()
			cloud.name = "Cloud%d" % i
			cloud.texture = cloud_tex
			cloud.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			cloud.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			cloud.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cloud.size = Vector2(420 - i * 60, 140)
			cloud.position = Vector2(-200, 40 + i * 100)
			bg_layer.add_child(cloud)
		else:
			var cloud := ColorRect.new()
			cloud.name = "Cloud%d" % i
			cloud.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cloud.color = Color(1, 1, 1, 0.82 - i * 0.04)
			cloud.size = Vector2(360 - i * 60, 48)
			cloud.position = Vector2(-200, 70 + i * 120)
			bg_layer.add_child(cloud)

	# Sparkles
	# W1.10: CPUParticles2D extends Node2D (no set_anchors_preset). Centre
	# the emitter via viewport rect at build time. Resize callback below
	# also re-centres on viewport size change.
	var sparkles := CPUParticles2D.new()
	sparkles.name = "Sparkles"
	var vp_size := get_viewport_rect().size
	sparkles.position = Vector2(vp_size.x / 2.0, vp_size.y / 2.0)
	get_viewport().size_changed.connect(func() -> void:
		var size := get_viewport_rect().size
		sparkles.position = Vector2(size.x / 2.0, size.y / 2.0)
	)
	sparkles.amount = 40
	sparkles.lifetime = 4.0
	sparkles.direction = Vector2(0.3, -1)
	sparkles.spread = 30.0
	sparkles.gravity = Vector2(0, -20)
	sparkles.initial_velocity_min = 20.0
	sparkles.initial_velocity_max = 60.0
	sparkles.scale_amount_min = 2.0
	sparkles.scale_amount_max = 5.0
	sparkles.color = Color(1, 0.95, 0.4, 1)
	bg_layer.add_child(sparkles)

	# Grass foreground strip (bottom of screen, above clouds/sparkles but below UI)
	var grass_tex: Texture2D = load("res://data/textures/landing/grass_foreground.png") if ResourceLoader.exists("res://data/textures/landing/grass_foreground.png") else null
	if grass_tex != null:
		var grass := TextureRect.new()
		grass.name = "GrassForeground"
		grass.texture = grass_tex
		grass.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		grass.stretch_mode = TextureRect.STRETCH_TILE
		# W1.10: anchor bottom-full-width so grass stays at the bottom across
		# viewport widths/heights instead of clipping out the bottom of the
		# 1600x960 default.
		grass.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		grass.offset_left = 0
		grass.offset_top = -180
		grass.offset_right = 0
		grass.offset_bottom = 0
		grass.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bg_layer.add_child(grass)

	# Title label (W1.9: route via _t() so brand stays in single source of truth)
	var title := Label.new()
	title.name = "TitleLabel"
	title.text = _t("landing.title")
	title.position = Vector2(60, 32)
	title.size = Vector2(440, 110)
	add_child(title)

	# ButtonStack
	var stack := VBoxContainer.new()
	stack.name = "ButtonStack"
	stack.position = Vector2(80, 300)
	stack.size = Vector2(380, 320)
	stack.add_theme_constant_override("separation", 24)
	add_child(stack)

	# W1.9: route landing CTAs through _t() so F-056-01 stays closed on the
	# literal first screen kid sees. Previously hardcoded Polish — regressed
	# the Wave-A/C l10n discipline.
	_btn_play = Button.new()
	_btn_play.name = "BtnPlay"
	_btn_play.text = _t("landing.play")
	_btn_play.custom_minimum_size = Vector2(360, 110)
	stack.add_child(_btn_play)

	_btn_create = Button.new()
	_btn_create.name = "BtnCreate"
	_btn_create.text = _t("landing.create")
	_btn_create.custom_minimum_size = Vector2(360, 110)
	stack.add_child(_btn_create)

	var parent_row := HBoxContainer.new()
	parent_row.name = "ParentRow"
	parent_row.add_theme_constant_override("separation", 16)
	stack.add_child(parent_row)

	_btn_parent = Button.new()
	_btn_parent.name = "BtnParent"
	_btn_parent.text = _t("landing.parent")
	_btn_parent.custom_minimum_size = Vector2(240, 68)
	_btn_parent.modulate.a = 0.72
	parent_row.add_child(_btn_parent)

	# PickerLayer (CanvasLayer, layer=2, hidden)
	_picker_layer = CanvasLayer.new()
	_picker_layer.name = "PickerLayer"
	_picker_layer.layer = 2
	_picker_layer.visible = false
	add_child(_picker_layer)

	var backdrop := ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0, 0, 0, 0.7)
	# CRITICAL: ColorRect defaults to MOUSE_FILTER_STOP and would swallow every
	# click before the world cards (above it) see them. Without this the kid's
	# click on a world card hits the backdrop instead and the picker appears
	# unresponsive. Pass clicks through so cards receive button_pressed.
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_picker_layer.add_child(backdrop)

	# W1.10: picker scroll anchored full-rect with margins so the card row
	# survives 1280-2560px viewports without horizontal clipping.
	var scroll := ScrollContainer.new()
	scroll.name = "PickerScroll"
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 60
	scroll.offset_top = 120
	scroll.offset_right = -60
	scroll.offset_bottom = -180
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_picker_layer.add_child(scroll)

	_card_row = HBoxContainer.new()
	_card_row.name = "CardRow"
	_card_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_card_row.add_theme_constant_override("separation", 20)
	scroll.add_child(_card_row)

	# W1.10: anchor top-right so close button is always reachable.
	var close_btn := Button.new()
	close_btn.name = "CloseBtn"
	close_btn.text = "✕"
	close_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	close_btn.offset_left = -80
	close_btn.offset_top = 20
	close_btn.offset_right = -20
	close_btn.offset_bottom = 80
	_picker_layer.add_child(close_btn)


func _wire_buttons() -> void:
	if _btn_play != null:
		_btn_play.pressed.connect(_on_play_pressed)
	if _btn_create != null:
		_btn_create.pressed.connect(_on_create_pressed)
	if _btn_parent != null:
		_btn_parent.pressed.connect(_on_parent_pressed)


func _wire_picker_close() -> void:
	if _picker_layer == null:
		return
	var close_btn := _picker_layer.get_node_or_null("CloseBtn")
	if close_btn != null:
		close_btn.pressed.connect(func(): _picker_layer.visible = false)


# ---------- audio ----------

func _start_landing_audio() -> void:
	if not has_node("/root/AudioBank"):
		return
	var bank: Node = get_node("/root/AudioBank")
	bank.play_music("landing_ambient", true)
	await get_tree().create_timer(0.8).timeout
	bank.play_voice("greet_landing")


func _audio_bank() -> Node:
	return get_node_or_null("/root/AudioBank")


# ---------- button handlers ----------

func _on_play_pressed() -> void:
	play_pressed.emit()
	var bank := _audio_bank()
	if bank != null:
		bank.play_voice("world_picker")
	_show_world_picker()


func _on_create_pressed() -> void:
	create_pressed.emit()
	var bank := _audio_bank()
	if bank != null:
		bank.play_voice("encourage_create")


func _on_parent_pressed() -> void:
	parent_pressed.emit()
	var bank := _audio_bank()
	if bank != null:
		bank.play_voice("parent_zone")


# ---------- world picker ----------

func _show_world_picker() -> void:
	if _picker_layer == null or _card_row == null:
		return
	# Clear stale cards from a previous open.
	for child in _card_row.get_children():
		child.queue_free()
	# Populate from project_store for the current profile. Filter to seeded
	# starter projects only (project_id contains "_starter_") so stale projects
	# from earlier development versions (e.g. "starter_canvas") don't appear.
	if _project_store != null and _profile != null:
		for project in _project_store.list_projects():
			if project.owner_profile_id != _profile.profile_id:
				continue
			if not String(project.project_id).contains("_starter_"):
				continue
			var card := _build_world_card(project)
			_card_row.add_child(card)
	_picker_layer.visible = true


func _build_world_card(project) -> Control:
	var card := Button.new()
	card.custom_minimum_size = Vector2(380, 240)
	card.text = ""

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.anchor_right = 1.0
	vbox.anchor_bottom = 1.0

	var icon := Label.new()
	icon.text = _icon_for_template(project.template_id)
	icon.add_theme_font_size_override("font_size", 96)
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(icon)

	var name_label := Label.new()
	name_label.text = project.title
	name_label.add_theme_font_size_override("font_size", 26)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(name_label)

	card.add_child(vbox)

	var world_id := ""
	if "worlds" in project and not project.worlds.is_empty():
		world_id = project.worlds[0].world_id

	card.pressed.connect(func():
		var bank := _audio_bank()
		if bank != null:
			bank.play_sfx("ui_confirm")
			bank.stop_music(true)
		# Hide picker CanvasLayer explicitly. Control.visible=false on
		# LandingShell does NOT hide CanvasLayer children (they render
		# independently), so without this the picker stayed on top of
		# PlayShell after navigating away.
		if _picker_layer != null:
			_picker_layer.visible = false
		world_card_pressed.emit(project.project_id, world_id)
	)
	return card


func _icon_for_template(tid: String) -> String:
	match tid:
		"adventure": return "🏝"
		"farm": return "🚜"
		"city": return "🏙"
		"forest": return "🍄"
		_: return "🌎"


# ---------- cloud animation ----------

func _start_cloud_drift() -> void:
	for i in range(1, 4):  # Cloud1, Cloud2, Cloud3
		var cloud_path := "BgLayer/Cloud%d" % i
		if not has_node(cloud_path):
			continue
		var cloud: Control = get_node(cloud_path)
		var start_x := -200.0
		# W1.10: drift to viewport width so clouds reach the right edge on any
		# resolution (was hardcoded 1800 — vanished early on ultrawide, ran
		# past edge on narrow). +200 padding so cloud fully exits before reset.
		var end_x := float(get_viewport_rect().size.x) + 200.0
		# Slow / medium / fast: 48 / 36 / 24 seconds
		var duration := 60.0 - float(i) * 12.0
		var tw := create_tween().set_loops()
		tw.tween_property(cloud, "position:x", end_x, duration).from(start_x)
		_cloud_tweens.append(tw)


# ---------- styling ----------

func _apply_theme() -> void:
	if _btn_play != null:
		_style_main_button(_btn_play, Color(1.0, 0.42, 0.21))
	if _btn_create != null:
		_style_main_button(_btn_create, Color(0.18, 0.72, 0.54))

	# Title label styling.
	var title_node := get_node_or_null("TitleLabel")
	if title_node is Label:
		title_node.add_theme_color_override("font_color", Color(1.0, 0.42, 0.21))
		title_node.add_theme_font_size_override("font_size", 96)


## W1.9: localization helper. Falls back to the key when no port is injected
## so the screen still boots in test harnesses without a LocalizationPolicyPort.
func _t(key: String) -> String:
	if _localization != null and _localization.has_method("translate"):
		return _localization.translate(key)
	return key


func _style_main_button(btn: Button, color: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 24
	style.corner_radius_top_right = 24
	style.corner_radius_bottom_left = 24
	style.corner_radius_bottom_right = 24
	btn.add_theme_stylebox_override("normal", style)
	var hover_style := style.duplicate() as StyleBoxFlat
	hover_style.bg_color = color.lightened(0.15)
	btn.add_theme_stylebox_override("hover", hover_style)
	var pressed_style := style.duplicate() as StyleBoxFlat
	pressed_style.bg_color = color.darkened(0.15)
	btn.add_theme_stylebox_override("pressed", pressed_style)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_font_size_override("font_size", 44)
