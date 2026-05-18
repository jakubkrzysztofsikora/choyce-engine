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
	var sun_tex: Texture2D = load("res://data/textures/landing/sun.png") if ResourceLoader.exists("res://data/textures/landing/sun.png") else null
	if sun_tex != null:
		var sun := TextureRect.new()
		sun.name = "Sun"
		sun.texture = sun_tex
		sun.custom_minimum_size = Vector2(192, 192)
		sun.size = Vector2(192, 192)
		sun.position = Vector2(1540, 60)
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
	var sparkles := CPUParticles2D.new()
	sparkles.name = "Sparkles"
	sparkles.position = Vector2(960, 540)
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
		grass.size = Vector2(1920, 180)
		grass.position = Vector2(0, 900)
		grass.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bg_layer.add_child(grass)

	# Title label
	var title := Label.new()
	title.name = "TitleLabel"
	title.text = "Choyce"
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

	_btn_play = Button.new()
	_btn_play.name = "BtnPlay"
	_btn_play.text = "ZAGRAJ"
	_btn_play.custom_minimum_size = Vector2(360, 110)
	stack.add_child(_btn_play)

	_btn_create = Button.new()
	_btn_create.name = "BtnCreate"
	_btn_create.text = "ZRÓB"
	_btn_create.custom_minimum_size = Vector2(360, 110)
	stack.add_child(_btn_create)

	var parent_row := HBoxContainer.new()
	parent_row.name = "ParentRow"
	parent_row.add_theme_constant_override("separation", 16)
	stack.add_child(parent_row)

	_btn_parent = Button.new()
	_btn_parent.name = "BtnParent"
	_btn_parent.text = "RODZIC"
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
	_picker_layer.add_child(backdrop)

	var scroll := ScrollContainer.new()
	scroll.name = "PickerScroll"
	scroll.position = Vector2(60, 120)
	scroll.size = Vector2(1800, 580)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_picker_layer.add_child(scroll)

	_card_row = HBoxContainer.new()
	_card_row.name = "CardRow"
	_card_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_card_row.add_theme_constant_override("separation", 20)
	scroll.add_child(_card_row)

	var close_btn := Button.new()
	close_btn.name = "CloseBtn"
	close_btn.text = "✕"
	close_btn.position = Vector2(1840, 20)
	close_btn.size = Vector2(60, 60)
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


# ---------- button handlers ----------

func _on_play_pressed() -> void:
	play_pressed.emit()
	_show_world_picker()


func _on_create_pressed() -> void:
	create_pressed.emit()


func _on_parent_pressed() -> void:
	parent_pressed.emit()


# ---------- world picker ----------

func _show_world_picker() -> void:
	if _picker_layer == null or _card_row == null:
		return
	# Clear stale cards from a previous open.
	for child in _card_row.get_children():
		child.queue_free()
	# Populate from project_store for the current profile.
	if _project_store != null and _profile != null:
		for project in _project_store.list_projects():
			if project.owner_profile_id == _profile.profile_id:
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

	card.pressed.connect(func(): world_card_pressed.emit(project.project_id, world_id))
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
		var end_x := 1800.0
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
