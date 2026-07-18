## Compact, child-readable customization overlay. One row per dimension
## (face/skin/hair/top/pants/shoes) with a small swatch strip. Built fully
## in code so it inherits the same translucent panel system as the HUD and
## adapts to the viewport via anchored controls.
class_name CharacterCustomizationPanel
extends Control

signal customization_changed(c: CharacterCustomization)
signal panel_closed

const REF := Vector2(1600.0, 960.0)
const _PANEL_BG := Color(0.025, 0.045, 0.075, 0.92)
const _ROW_BG := Color(0.04, 0.07, 0.12, 0.78)
const _DIM_LABELS := ["Twarz", "Skóra", "Włosy", "Bluza", "Spodnie", "Buty"]
const _SWATCH_SIZE := 56.0
const _SWATCH_GAP := 10.0

var _customization: CharacterCustomization = CharacterCustomization.new()
var _face_buttons: Array[Button] = []
var _swatch_buttons: Array = []  ## Array[Array[Button]] per dimension


func setup(initial: CharacterCustomization) -> CharacterCustomizationPanel:
	_customization = initial if initial != null else CharacterCustomization.new()
	return self


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()


func _build() -> void:
	var root := PanelContainer.new()
	root.name = "PanelRoot"
	root.set_anchors_preset(Control.PRESET_CENTER)
	root.custom_minimum_size = Vector2(REF.x * 0.55, REF.y * 0.62)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_theme_stylebox_override("panel", _flat_style(_PANEL_BG, Color(0.55, 0.62, 0.78, 0.45), 14))
	add_child(root)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	root.add_child(col)

	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 12)
	col.add_child(title_row)

	var title := Label.new()
	title.text = "Twój bohater"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.96, 0.97, 1.0))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)

	var close_btn := Button.new()
	close_btn.text = "Gotowe"
	close_btn.custom_minimum_size = Vector2(140, 48)
	close_btn.add_theme_font_size_override("font_size", 22)
	close_btn.add_theme_stylebox_override("normal", _flat_style(Color(0.20, 0.55, 0.85, 0.92), Color(1, 1, 1, 0.6), 12))
	close_btn.add_theme_stylebox_override("hover", _flat_style(Color(0.25, 0.65, 0.95, 0.95), Color(1, 1, 1, 0.9), 12))
	close_btn.add_theme_color_override("font_color", Color.WHITE)
	close_btn.pressed.connect(_on_close)
	title_row.add_child(close_btn)

	var subtitle := Label.new()
	subtitle.text = "Zmiany zapisują się automatycznie i działają też przy kolejnym uruchomieniu."
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.add_theme_font_size_override("font_size", 14)
	subtitle.add_theme_color_override("font_color", Color(0.74, 0.78, 0.86))
	col.add_child(subtitle)

	_face_buttons.clear()
	_swatch_buttons.clear()
	_build_face_row(col)
	_build_color_row(col, "skin", _DIM_LABELS[1], CharacterCustomization.SKIN_PALETTE)
	_build_color_row(col, "hair", _DIM_LABELS[2], CharacterCustomization.HAIR_PALETTE)
	_build_color_row(col, "top", _DIM_LABELS[3], CharacterCustomization.TOP_PALETTE)
	_build_color_row(col, "pants", _DIM_LABELS[4], CharacterCustomization.PANTS_PALETTE)
	_build_color_row(col, "shoes", _DIM_LABELS[5], CharacterCustomization.SHOES_PALETTE)

	var footer := Label.new()
	footer.text = "Bez wpływu na statystyki — wygląd to wygląd."
	footer.add_theme_font_size_override("font_size", 12)
	footer.add_theme_color_override("font_color", Color(0.55, 0.60, 0.68))
	col.add_child(footer)


func _build_face_row(parent: Control) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	parent.add_child(row)
	for variant in CharacterCustomization.FACE_VARIANTS:
		var btn := Button.new()
		btn.text = variant.to_upper()
		btn.custom_minimum_size = Vector2(64, 64)
		btn.add_theme_font_size_override("font_size", 22)
		btn.add_theme_color_override("font_color", Color.WHITE)
		btn.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
		btn.add_theme_constant_override("shadow_offset_x", 2)
		btn.add_theme_constant_override("shadow_offset_y", 2)
		var is_selected: bool = variant == _customization.face
		var accent := Color(0.92, 0.78, 0.30) if is_selected else Color(0.55, 0.62, 0.78, 0.4)
		btn.add_theme_stylebox_override("normal", _flat_style(Color(0.06, 0.10, 0.16, 0.86), accent, 12))
		btn.pressed.connect(_on_face_pressed.bind(variant))
		_face_buttons.append(btn)
		row.add_child(btn)
	_refresh_face_selection()


func _build_color_row(parent: Control, dimension: String, label: String, palette: Array) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	parent.add_child(row)

	var dim_label := Label.new()
	dim_label.text = label
	dim_label.custom_minimum_size = Vector2(110, 0)
	dim_label.add_theme_font_size_override("font_size", 18)
	dim_label.add_theme_color_override("font_color", Color(0.85, 0.90, 0.98))
	row.add_child(dim_label)

	var swatches: Array[Button] = []
	for color in palette:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(_SWATCH_SIZE, _SWATCH_SIZE)
		btn.add_theme_stylebox_override("normal", _swatch_style(color, _is_dim_selected(dimension, swatches.size())))
		btn.add_theme_stylebox_override("hover", _swatch_style(color, true))
		btn.pressed.connect(_on_swatch_pressed.bind(dimension, swatches.size()))
		swatches.append(btn)
		row.add_child(btn)
	_swatch_buttons.append({"dimension": dimension, "buttons": swatches})


func _is_dim_selected(dimension: String, idx: int) -> bool:
	match dimension:
		"skin": return idx == _customization.skin
		"hair": return idx == _customization.hair
		"top": return idx == _customization.top
		"pants": return idx == _customization.pants
		"shoes": return idx == _customization.shoes
	return false


func _refresh_face_selection() -> void:
	for i in range(_face_buttons.size()):
		var variant: String = CharacterCustomization.FACE_VARIANTS[i]
		var is_selected: bool = variant == _customization.face
		var accent := Color(0.92, 0.78, 0.30, 0.95) if is_selected else Color(0.55, 0.62, 0.78, 0.45)
		_face_buttons[i].add_theme_stylebox_override("normal", _flat_style(Color(0.06, 0.10, 0.16, 0.86), accent, 12))


func _refresh_swatch_selection() -> void:
	for entry in _swatch_buttons:
		var dimension: String = entry["dimension"]
		var buttons: Array = entry["buttons"]
		for i in range(buttons.size()):
			var is_selected := _is_dim_selected(dimension, i)
			var color: Color = buttons[i].get_theme_stylebox("normal").bg_color
			buttons[i].add_theme_stylebox_override("normal", _swatch_style(color, is_selected))


func _on_face_pressed(variant: String) -> void:
	if variant == _customization.face:
		return
	_customization.face = variant
	_refresh_face_selection()
	_emit_change()


func _on_swatch_pressed(dimension: String, idx: int) -> void:
	match dimension:
		"skin":
			if idx == _customization.skin: return
			_customization.skin = idx
		"hair":
			if idx == _customization.hair: return
			_customization.hair = idx
		"top":
			if idx == _customization.top: return
			_customization.top = idx
		"pants":
			if idx == _customization.pants: return
			_customization.pants = idx
		"shoes":
			if idx == _customization.shoes: return
			_customization.shoes = idx
	_refresh_swatch_selection()
	_emit_change()


func _emit_change() -> void:
	customization_changed.emit(_customization)


func _on_close() -> void:
	panel_closed.emit()


func _flat_style(bg: Color, border: Color, radius: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 8
	return sb


func _swatch_style(color: Color, selected: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	var border := Color(0.96, 0.90, 0.55, 0.95) if selected else Color(1, 1, 1, 0.45)
	sb.border_color = border
	sb.set_border_width_all(3 if selected else 1)
	sb.set_corner_radius_all(10)
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 4
	return sb
