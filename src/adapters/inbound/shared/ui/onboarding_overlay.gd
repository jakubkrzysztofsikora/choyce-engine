class_name OnboardingOverlay
extends Control

const IconFont = preload("res://src/adapters/inbound/shared/ui/icon_font.gd")

signal advance_requested

const CONFETTI_DURATION := 1.5

var _label: Label
var _pointer: Node2D
var _target_control: Control
var _step_id: String
var _tween: Tween

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 24)
	_label.add_theme_color_override("font_color", Color.WHITE)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 5)
	add_child(_label)
	_label.hide()
	
	modulate.a = 0.0

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		advance_requested.emit()

func show_step(step_id: String, text: String, target: Control = null) -> void:
	_step_id = step_id
	_label.text = text
	_label.show()
	_target_control = target
	
	if _target_control:
		var target_pos = _target_control.get_global_rect().position
		var target_size = _target_control.get_global_rect().size
		_label.global_position = target_pos + Vector2(0, -60)
		queue_redraw()
	else:
		_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	
	_animate_appear()

func celebrate_completion() -> void:
	var feedback = Label.new()
	feedback.text = "%s Świetna robota!" % IconFont.get_icon("star")
	feedback.add_theme_font_size_override("font_size", 36)
	feedback.add_theme_color_override("font_color", Color.YELLOW)
	feedback.add_theme_color_override("font_outline_color", Color.ORANGE)
	feedback.add_theme_constant_override("outline_size", 6)
	feedback.position = get_viewport_rect().size / 2
	add_child(feedback)
	
	var t = create_tween()
	t.tween_property(feedback, "scale", Vector2(1.5, 1.5), 0.5).set_trans(Tween.TRANS_BOUNCE)
	t.parallel().tween_property(feedback, "modulate:a", 0.0, 1.0)
	t.tween_callback(feedback.queue_free)

func dismiss() -> void:
	_animate_disappear()

func _draw() -> void:
	if _target_control and _label.visible:
		var start = _label.global_position + Vector2(_label.size.x / 2, _label.size.y)
		var end = _target_control.global_position + Vector2(_target_control.size.x / 2, 0)
		draw_line(start, end, Color.YELLOW, 4.0)

func _animate_appear() -> void:
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 1.0, 0.25)

func _animate_disappear() -> void:
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	tween.finished.connect(func():
		_label.hide()
		_target_control = null
		queue_redraw()
	)
