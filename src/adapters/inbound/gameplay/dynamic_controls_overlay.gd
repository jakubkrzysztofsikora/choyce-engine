class_name DynamicControlsOverlay
extends Control

signal closed

const ACTION_DESCRIPTIONS := {
	"move_forward": "Ruch do przodu",
	"move_back": "Ruch do tyłu",
	"move_left": "Ruch w lewo",
	"move_right": "Ruch w prawo",
	"jump": "Skok",
	"sprint": "Sprint / Bieg",
	"interact": "Interakcja / Wejdź do auta",
	"attack": "Atak mieczem / Strzał",
	"place_block": "Postaw klocki (Budowanie)",
	"break_block": "Zniszcz / Wykop klocek",
	"inventory": "Otwórz plecak / Rzemiosło",
	"silly_fart": "Zabawny dźwięk (Fart)",
	"undo": "Cofnij Ostatnią Zmianę",
	"accelerate": "Gaz (Pojazd)",
	"reverse": "Cofanie (Pojazd)",
	"steer_left": "Skręt w lewo (Pojazd)",
	"steer_right": "Skręt w prawo (Pojazd)",
	"brake": "Hamulec (Pojazd)",
	"exit_vehicle": "Wysiądź z pojazdu",
	# P2 Co-Op Actions
	"p2_move_forward": "P2 Ruch do przodu",
	"p2_move_back": "P2 Ruch do tyłu",
	"p2_move_left": "P2 Ruch w lewo",
	"p2_move_right": "P2 Ruch w prawo",
	"p2_jump": "P2 Skok",
	"p2_sprint": "P2 Bieg",
	"p2_attack": "P2 Atak / Strzał",
	"p2_place_block": "P2 Postaw klocek",
	"p2_break_block": "P2 Wykop klocek",
	"p2_inventory": "P2 Otwórz plecak",
	"p2_look_left": "P2 Obrót kamery w lewo",
	"p2_look_right": "P2 Obrót kamery w prawo"
}

var _panel: PanelContainer = null
var _tab_container: TabContainer = null
var _p1_grid: GridContainer = null
var _p2_grid: GridContainer = null


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()


func open() -> void:
	visible = true
	refresh_bindings()


func close() -> void:
	visible = false
	closed.emit()


func _build_ui() -> void:
	# Semi-transparent dark background
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.08, 0.12, 0.88)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.custom_minimum_size = Vector2(760, 520)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 20)
	_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	margin.add_child(vbox)

	# Header Title & Close Button
	var header := HBoxContainer.new()
	vbox.add_child(header)

	var title := Label.new()
	title.text = "🎮 STEROWANIE — KLAWIATURA + MYSZ & PAD PS4 / DUALSHOCK"
	title.add_theme_font_size_override("font_size", 18)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var close_btn := Button.new()
	close_btn.text = "✖ Zamknij [Esc]"
	close_btn.custom_minimum_size = Vector2(120, 34)
	close_btn.pressed.connect(close)
	header.add_child(close_btn)

	# Tabs for Player 1 (Ziemek) and Player 2 (Gniewko)
	_tab_container = TabContainer.new()
	_tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_tab_container)

	# P1 Tab
	var p1_scroll := ScrollContainer.new()
	p1_scroll.name = "Gracz 1 (Ziemek)"
	_tab_container.add_child(p1_scroll)

	_p1_grid = GridContainer.new()
	_p1_grid.columns = 3
	_p1_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_p1_grid.add_theme_constant_override("h_separation", 24)
	_p1_grid.add_theme_constant_override("v_separation", 8)
	p1_scroll.add_child(_p1_grid)

	# P2 Tab
	var p2_scroll := ScrollContainer.new()
	p2_scroll.name = "Gracz 2 (Gniewko / Co-Op)"
	_tab_container.add_child(p2_scroll)

	_p2_grid = GridContainer.new()
	_p2_grid.columns = 3
	_p2_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_p2_grid.add_theme_constant_override("h_separation", 24)
	_p2_grid.add_theme_constant_override("v_separation", 8)
	p2_scroll.add_child(_p2_grid)

	refresh_bindings()


func refresh_bindings() -> void:
	if _p1_grid == null or _p2_grid == null:
		return
	_populate_grid(_p1_grid, false)
	_populate_grid(_p2_grid, true)


func _populate_grid(grid: GridContainer, is_p2: bool) -> void:
	for child in grid.get_children():
		child.queue_free()

	# Header row
	_add_header_cell(grid, "Akcja w Grze")
	_add_header_cell(grid, "⌨ Klawiatura + Mysz")
	_add_header_cell(grid, "🎮 Pad PS4 / DualShock")

	var actions_to_show := []
	for act in ACTION_DESCRIPTIONS.keys():
		if is_p2 and String(act).begins_with("p2_"):
			actions_to_show.append(act)
		elif not is_p2 and not String(act).begins_with("p2_"):
			actions_to_show.append(act)

	for action_name in actions_to_show:
		var desc: String = ACTION_DESCRIPTIONS[action_name]
		var kbm_label := _format_kbm_events(action_name)
		var ps4_label := _format_ps4_events(action_name)

		_add_body_cell(grid, desc, Color(0.9, 0.9, 0.95))
		_add_body_cell(grid, kbm_label, Color(0.4, 0.85, 0.95))
		_add_body_cell(grid, ps4_label, Color(0.95, 0.75, 0.35))


func _add_header_cell(grid: GridContainer, text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 14)
	l.modulate = Color(0.7, 0.85, 1.0)
	grid.add_child(l)


func _add_body_cell(grid: GridContainer, text: String, color: Color) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 13)
	l.modulate = color
	grid.add_child(l)


func _format_kbm_events(action_name: String) -> String:
	if not InputMap.has_action(action_name):
		return "—"
	var keys: Array[String] = []
	for ev in InputMap.action_get_events(action_name):
		if ev is InputEventKey:
			keys.append(OS.get_keycode_string(ev.keycode))
		elif ev is InputEventMouseButton:
			match ev.button_index:
				MOUSE_BUTTON_LEFT: keys.append("Lewy Przycisk Myszy (LMB)")
				MOUSE_BUTTON_RIGHT: keys.append("Prawy Przycisk Myszy (RMB)")
				MOUSE_BUTTON_MIDDLE: keys.append("Środkowy Przycisk (MMB)")

	if keys.is_empty():
		return "—"
	return ", ".join(keys)


func _format_ps4_events(action_name: String) -> String:
	if not InputMap.has_action(action_name):
		return "—"
	var pads: Array[String] = []
	for ev in InputMap.action_get_events(action_name):
		if ev is InputEventJoypadButton:
			pads.append(_ps4_button_name(ev.button_index))
		elif ev is InputEventJoypadMotion:
			pads.append(_ps4_axis_name(ev.axis, ev.axis_value))

	if pads.is_empty():
		return "—"
	return ", ".join(pads)


func _ps4_button_name(btn: JoyButton) -> String:
	match btn:
		JOY_BUTTON_A: return "✕ Cross"
		JOY_BUTTON_B: return "◯ Circle"
		JOY_BUTTON_X: return "☐ Square"
		JOY_BUTTON_Y: return "△ Triangle"
		JOY_BUTTON_LEFT_SHOULDER: return "L1 Przycisk"
		JOY_BUTTON_RIGHT_SHOULDER: return "R1 Przycisk"
		JOY_BUTTON_LEFT_STICK: return "L3 (Wciśnij Lewy Gałkę)"
		JOY_BUTTON_RIGHT_STICK: return "R3 (Wciśnij Prawą Gałkę)"
		JOY_BUTTON_START: return "Options / Opcje"
		JOY_BUTTON_BACK: return "Share / Touchpad"
		JOY_BUTTON_DPAD_UP: return "D-Pad Góra"
		JOY_BUTTON_DPAD_DOWN: return "D-Pad Dół"
		JOY_BUTTON_DPAD_LEFT: return "D-Pad Lewo"
		JOY_BUTTON_DPAD_RIGHT: return "D-Pad Prawo"
		_: return "Przycisk Pad %d" % int(btn)


func _ps4_axis_name(axis: JoyAxis, value: float) -> String:
	match axis:
		JOY_AXIS_LEFT_X: return "Lewy Drążek (Lewo/Prawo)"
		JOY_AXIS_LEFT_Y: return "Lewy Drążek (Góra/Dół)"
		JOY_AXIS_RIGHT_X: return "Prawy Drążek (Kamera X)"
		JOY_AXIS_RIGHT_Y: return "Prawy Drążek (Kamera Y)"
		JOY_AXIS_TRIGGER_LEFT: return "L2 Spust"
		JOY_AXIS_TRIGGER_RIGHT: return "R2 Spust"
		_: return "Oś Pad %d" % int(axis)


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
