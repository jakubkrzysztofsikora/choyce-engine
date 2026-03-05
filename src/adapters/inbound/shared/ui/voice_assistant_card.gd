class_name VoiceAssistantCard
extends PanelContainer

signal confirmed(action: AIAssistantAction)
signal cancelled
signal adjusted(action: AIAssistantAction, adjustment_key: String)

const ADJUSTMENT_PRESETS := [
	{"key": "gentle", "label": "Mniej zmian"},
	{"key": "balanced", "label": "Bez zmian"},
	{"key": "creative", "label": "Wiecej zmian"},
	{"key": "surprise", "label": "Niespodzianka"},
]

var _action: AIAssistantAction
var _intent_label: Label
var _explanation_label: Label
var _adjust_label: Label
var _adjust_option: OptionButton
var _adjust_button: Button
var _confirm_button: Button
var _cancel_button: Button

func _init() -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.2, 0.95)
	style.set_corner_radius_all(8)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	add_child(vbox)

	var title = Label.new()
	title.text = "Slysze, ze mowisz:"
	title.add_theme_font_size_override("font_size", 14)
	title.modulate = Color(1, 1, 1, 0.7)
	vbox.add_child(title)

	_intent_label = Label.new()
	_intent_label.add_theme_font_size_override("font_size", 18)
	_intent_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_intent_label)

	var sub_title = Label.new()
	sub_title.text = "Wykonam:"
	sub_title.add_theme_font_size_override("font_size", 14)
	sub_title.modulate = Color(1, 1, 1, 0.7)
	vbox.add_child(sub_title)

	_explanation_label = Label.new()
	_explanation_label.add_theme_color_override("font_color", Color("81C784")) # Light Green
	_explanation_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_explanation_label)

	_adjust_label = Label.new()
	_adjust_label.text = "Dopasuj propozycje (4 opcje):"
	_adjust_label.add_theme_font_size_override("font_size", 14)
	_adjust_label.modulate = Color(1, 1, 1, 0.7)
	vbox.add_child(_adjust_label)

	var adjust_row = HBoxContainer.new()
	adjust_row.add_theme_constant_override("separation", 8)
	vbox.add_child(adjust_row)

	_adjust_option = OptionButton.new()
	_adjust_option.custom_minimum_size = Vector2(200, 40)
	for i in range(ADJUSTMENT_PRESETS.size()):
		var preset: Dictionary = ADJUSTMENT_PRESETS[i]
		_adjust_option.add_item(str(preset.get("label", "")), i)
	adjust_row.add_child(_adjust_option)

	_adjust_button = Button.new()
	_adjust_button.text = "Dostosuj"
	_adjust_button.custom_minimum_size = Vector2(120, 40)
	_adjust_button.pressed.connect(_on_adjust)
	adjust_row.add_child(_adjust_button)

	var hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 24)
	vbox.add_child(hbox)

	_cancel_button = Button.new()
	_cancel_button.text = "Anuluj"
	_cancel_button.custom_minimum_size = Vector2(100, 40)
	_cancel_button.pressed.connect(_on_cancel)
	hbox.add_child(_cancel_button)

	_confirm_button = Button.new()
	_confirm_button.text = "Wykonaj"
	_confirm_button.custom_minimum_size = Vector2(100, 40)
	_confirm_button.pressed.connect(_on_confirm)
	hbox.add_child(_confirm_button)

func set_action(action: AIAssistantAction) -> void:
	_action = action
	_intent_label.text = '"' + action.intent + '"'
	_explanation_label.text = action.explanation
	_adjust_option.select(1)


func get_adjustment_keys() -> Array[String]:
	var keys: Array[String] = []
	for preset in ADJUSTMENT_PRESETS:
		keys.append(str(preset.get("key", "")))
	return keys


func apply_adjustment_choice(index: int) -> void:
	if _action == null:
		return
	var clamped := clampi(index, 0, ADJUSTMENT_PRESETS.size() - 1)
	_adjust_option.select(clamped)
	var preset: Dictionary = ADJUSTMENT_PRESETS[clamped]
	var adjustment_key := str(preset.get("key", "balanced"))

	var patch := _action.reversible_patch.duplicate(true)
	patch["kid_adjustment"] = adjustment_key
	_action.reversible_patch = patch

	var base_explanation := _action.explanation.strip_edges()
	_action.explanation = "%s\nWybor dziecka: %s" % [
		base_explanation,
		str(preset.get("label", "")),
	]
	_explanation_label.text = _action.explanation


func _selected_adjustment_index() -> int:
	var idx := _adjust_option.get_selected_id()
	if idx < 0:
		return 1
	return idx

func _on_confirm() -> void:
	if _action:
		confirmed.emit(_action)

func _on_cancel() -> void:
	cancelled.emit()


func _on_adjust() -> void:
	if _action == null:
		return
	var idx := _selected_adjustment_index()
	apply_adjustment_choice(idx)
	var preset: Dictionary = ADJUSTMENT_PRESETS[idx]
	adjusted.emit(_action, str(preset.get("key", "balanced")))
