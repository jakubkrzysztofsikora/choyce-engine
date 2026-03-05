class_name OnboardingOverlay
extends Control

signal advance_requested

const CONFETTI_DURATION := 1.5

var _label: Label
var _pointer: Node2D # Simple arrow drawn or sprite
var _target_control: Control
var _step_id: String
var _tween: Tween

func _ready() -> void:
	# Full screen overlay to catch clicks if needed, or mouse_filter = ignore
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 24)
	_label.add_theme_color_override("font_color", Color.WHITE)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 4)
	add_child(_label)
	_label.hide()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		advance_requested.emit()

func show_step(step_id: String, text: String, target: Control = null) -> void:
	_step_id = step_id
	_label.text = text
	_label.show()
	_target_control = target
	
	if _target_control:
		# Position label near target
		var target_pos = _target_control.get_global_rect().position
		var target_size = _target_control.get_global_rect().size
		_label.global_position = target_pos + Vector2(0, -50) # Above
		
		# Optional: Add an arrow pointing down
		queue_redraw()
	else:
		# Center screen
		_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)

func celebrate_completion() -> void:
	# Spawn confetti effect (simple visual feedback)
	var feedback = Label.new()
	feedback.text = "Great Job!"
	feedback.add_theme_font_size_override("font_size", 32)
	feedback.add_theme_color_override("font_color", Color.YELLOW)
	feedback.position = get_viewport_rect().size / 2
	add_child(feedback)
	
	var t = create_tween()
	t.tween_property(feedback, "scale", Vector2(1.5, 1.5), 0.5).set_trans(Tween.TRANS_BOUNCE)
	t.parallel().tween_property(feedback, "modulate:a", 0.0, 1.0)
	t.tween_callback(feedback.queue_free)

func dismiss() -> void:
	_label.hide()
	_target_control = null
	queue_redraw()

func _draw() -> void:
	if _target_control and _label.visible:
		# Draw arrow from label to target
		var start = _label.global_position + Vector2(_label.size.x / 2, _label.size.y)
		var end = _target_control.global_position + Vector2(_target_control.size.x / 2, 0)
		draw_line(start, end, Color.YELLOW, 4.0)
