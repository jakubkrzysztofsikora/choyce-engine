## Godot-specific implementation of AccessibilityPolicyPort.
## Manages global theme overrides and the captions overlay.
class_name GodotAccessibilityAdapter
extends AccessibilityPolicyPort

var _root_node: Node
var _overlay: CaptionsOverlay
var _dyslexia_font_resource: Font

var _is_dyslexia_enabled: bool = false
var _is_motor_enabled: bool = false
var _captions_enabled: bool = false
var _motor_scale_factor: float = 1.0

# Default configuration values
const DYSLEXIA_FONT_NAME := "OpenDyslexic"
const MOTOR_SCALE_FACTOR := 1.25
const MIN_TOUCH_TARGET := Vector2(56.0, 56.0)
const META_ORIGINAL_MIN_SIZE := "_a11y_original_min_size"

func setup(root_node: Node) -> GodotAccessibilityAdapter:
	_root_node = root_node
	
	# Initialize overlay
	_overlay = CaptionsOverlay.new()
	# Ensure it covers full screen and ignores mouse
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	# Add to scene tree, preferably on a CanvasLayer if available, else direct child
	# For simplicity in adapter pattern, direct child with high Z index
	if _root_node is Control:
		_overlay.z_index = 4096 # High enough to be on top
		_root_node.add_child(_overlay)
	elif _root_node is Node:
		# If root is just Node, try to find a canvas layer or just add
		_root_node.add_child(_overlay)

	_load_resources()
	apply_baseline_contrast()
	return self


func _load_resources() -> void:
	# Try loading system font or fallback
	# In a real project, we'd load("res://assets/fonts/OpenDyslexic-Regular.otf")
	# Here we simulate with system font lookup or basic override
	var font = SystemFont.new()
	font.font_names = PackedStringArray(["OpenDyslexic", "Comic Sans MS", "Arial"])
	_dyslexia_font_resource = font


## Applies the base WCAG AA contrast theme
func apply_baseline_contrast() -> void:
	if not (_root_node is Control):
		return

	var root: Control = _root_node
	var theme: Theme = root.theme
	if theme == null:
		theme = Theme.new()
		root.theme = theme

	var button_normal := StyleBoxFlat.new()
	button_normal.bg_color = Color(0.08, 0.08, 0.08, 1.0)
	button_normal.border_color = Color(1.0, 1.0, 1.0, 1.0)
	button_normal.border_width_left = 2
	button_normal.border_width_top = 2
	button_normal.border_width_right = 2
	button_normal.border_width_bottom = 2
	button_normal.corner_radius_top_left = 6
	button_normal.corner_radius_top_right = 6
	button_normal.corner_radius_bottom_left = 6
	button_normal.corner_radius_bottom_right = 6
	theme.set_stylebox("normal", "Button", button_normal)

	var button_focus := StyleBoxFlat.new()
	button_focus.bg_color = Color(0.18, 0.18, 0.18, 1.0)
	button_focus.border_color = Color(1.0, 0.9, 0.2, 1.0)
	button_focus.border_width_left = 3
	button_focus.border_width_top = 3
	button_focus.border_width_right = 3
	button_focus.border_width_bottom = 3
	button_focus.corner_radius_top_left = 6
	button_focus.corner_radius_top_right = 6
	button_focus.corner_radius_bottom_left = 6
	button_focus.corner_radius_bottom_right = 6
	theme.set_stylebox("focus", "Button", button_focus)

	theme.set_color("font_color", "Label", Color(1.0, 1.0, 1.0, 1.0))
	theme.set_color("font_color", "Button", Color(1.0, 1.0, 1.0, 1.0))
	theme.set_color("font_focus_color", "Button", Color(1.0, 0.95, 0.4, 1.0))
	theme.set_color("font_color", "CheckBox", Color(1.0, 1.0, 1.0, 1.0))
	theme.set_color("font_color", "OptionButton", Color(1.0, 1.0, 1.0, 1.0))


## Toggles the Dyslexia-friendly font override
func set_dyslexia_font(enabled: bool) -> void:
	_is_dyslexia_enabled = enabled
	_apply_theme_overrides()


## Adjusts UI scale and touch target padding
func set_motor_scale(scale_factor: float) -> void:
	# We interpret scale_factor > 1.0 as enabling motor mode
	_motor_scale_factor = max(scale_factor, 1.0)
	_is_motor_enabled = (_motor_scale_factor > 1.0)
	_apply_theme_overrides()


## Toggles the visibility of the captions overlay system
func set_captions_enabled(enabled: bool) -> void:
	_captions_enabled = enabled
	if not _captions_enabled:
		_overlay.visible = false


## Requests a caption to be displayed
func show_caption(text: String, duration: float = 3.0) -> void:
	if not _captions_enabled or _overlay == null:
		return
	var safe_text := text.strip_edges()
	if safe_text.is_empty():
		return

	if _overlay.is_inside_tree():
		_overlay.show_message(safe_text, duration)
	else:
		_overlay.call_deferred("show_message", safe_text, duration)


func _apply_theme_overrides() -> void:
	if not (_root_node is Control):
		return

	var root: Control = _root_node
	var theme: Theme = root.theme
	if theme == null:
		theme = Theme.new()
		root.theme = theme

	# Handle Font
	if _is_dyslexia_enabled:
		theme.default_font = _dyslexia_font_resource
	else:
		theme.default_font = null

	_apply_motor_overrides(root, _is_motor_enabled)


func _apply_motor_overrides(node: Node, enabled: bool) -> void:
	if node is Control:
		var control: Control = node
		if enabled:
			if not control.has_meta(META_ORIGINAL_MIN_SIZE):
				control.set_meta(META_ORIGINAL_MIN_SIZE, control.custom_minimum_size)
			var baseline: Vector2 = control.custom_minimum_size
			var scaled_target := MIN_TOUCH_TARGET * _motor_scale_factor
			var adjusted := Vector2(
				max(baseline.x, scaled_target.x),
				max(baseline.y, scaled_target.y)
			)
			if control is Button or control is CheckBox or control is OptionButton:
				control.custom_minimum_size = adjusted
		else:
			if control.has_meta(META_ORIGINAL_MIN_SIZE):
				var original: Variant = control.get_meta(META_ORIGINAL_MIN_SIZE, Vector2.ZERO)
				if original is Vector2:
					control.custom_minimum_size = original
				control.remove_meta(META_ORIGINAL_MIN_SIZE)

	for child in node.get_children():
		if child is Node:
			_apply_motor_overrides(child, enabled)
