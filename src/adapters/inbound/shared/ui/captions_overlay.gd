class_name CaptionsOverlay
extends Control

var _panel: PanelContainer
var _label: Label
var _timer: Timer

func _init() -> void:
	# Build UI hierarchy dynamically to avoid .tscn dep without editor
	_panel = PanelContainer.new()
	_panel.anchor_left = 0.5
	_panel.anchor_top = 0.85
	_panel.anchor_right = 0.5
	_panel.anchor_bottom = 0.95
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	# Centered width approx 600px
	_panel.custom_minimum_size = Vector2(600, 80)
	
	# Style
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.7)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_right = 12
	style.corner_radius_bottom_left = 12
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	_panel.add_theme_stylebox_override("panel", style)

	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.add_theme_font_size_override("font_size", 24)
	_label.add_theme_color_override("font_color", Color.WHITE)
	
	_panel.add_child(_label)
	add_child(_panel)
	
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.timeout.connect(_on_timeout)
	add_child(_timer)
	
	visible = false
	_panel.modulate.a = 0.0


func show_message(text: String, duration: float = 3.0) -> void:
	if not is_inside_tree():
		return
	if text.strip_edges().is_empty():
		return

	_label.text = text
	visible = true
	
	# Reset any active fade out
	var tween := create_tween()
	tween.tween_property(_panel, "modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_CUBIC)
	
	_timer.start(max(duration, 0.1))

func _on_timeout() -> void:
	var tween := create_tween()
	tween.tween_property(_panel, "modulate:a", 0.0, 0.5).set_trans(Tween.TRANS_CUBIC)
	tween.finished.connect(func(): visible = false)
