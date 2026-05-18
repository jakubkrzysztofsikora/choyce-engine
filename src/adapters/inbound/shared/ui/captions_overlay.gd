## Captions overlay — inbound UI adapter.
## Phase 4a-5: Polish strings would be routed via _t(key); currently no hardcoded
##             Polish in captions (show_message receives text from callers).
## Phase 4d: font_size option (24/32/40), high-contrast toggle, position (bottom/top),
##            TTS narration toggle (delegates to audio-governance pipeline when available).
class_name CaptionsOverlay
extends Control

const VALID_FONT_SIZES: Array[int] = [24, 32, 40]
## 32px default: more readable for emergent readers (ages 5-8) than 24px.
## 24px remains available via set_font_size() for parent/advanced users.
const DEFAULT_FONT_SIZE: int = 32

var _panel: PanelContainer
var _label: Label
var _timer: Timer
var _style: StyleBoxFlat

# Phase 4d state
var _font_size: int = DEFAULT_FONT_SIZE
var _high_contrast: bool = false
var _caption_position: String = "bottom"
var _tts_narration: bool = false

# Optional TTS port (Phase 4d): inject TextToSpeechPort to enable voice narration
# for captions. Typed port replaces previous duck-typed audio-governance reference.
var _tts: TextToSpeechPort = null


func _init() -> void:
	_panel = PanelContainer.new()
	_panel.anchor_left = 0.5
	_panel.anchor_top = 0.85
	_panel.anchor_right = 0.5
	_panel.anchor_bottom = 0.95
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_panel.custom_minimum_size = Vector2(640, 80)

	_style = StyleBoxFlat.new()
	_style.bg_color = Color(0.08, 0.10, 0.14, 0.82)
	_style.corner_radius_top_left = 16
	_style.corner_radius_top_right = 16
	_style.corner_radius_bottom_right = 16
	_style.corner_radius_bottom_left = 16
	_style.content_margin_left = 24
	_style.content_margin_right = 24
	_style.content_margin_top = 14
	_style.content_margin_bottom = 14
	_style.shadow_color = Color(0, 0, 0, 0.2)
	_style.shadow_size = 6
	_style.shadow_offset = Vector2(0, 3)
	_panel.add_theme_stylebox_override("panel", _style)

	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.add_theme_font_size_override("font_size", _font_size)
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

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(_panel, "modulate:a", 1.0, 0.25)

	_timer.start(max(duration, 0.1))

	# Phase 4d: delegate to TTS narration when enabled.
	if _tts_narration and _tts != null and _tts.is_available():
		_tts.speak(text)


## --- Phase 4d: option setters ---

## Set font size. Accepted values: 24, 32, 40. Other values clamped to nearest.
func set_font_size(size: int) -> void:
	_font_size = _clamp_font_size(size)
	if _label != null:
		_label.add_theme_font_size_override("font_size", _font_size)


## Enable or disable high-contrast mode.
## High contrast: nearly-black background (alpha 1.0), white text.
func set_high_contrast(enabled: bool) -> void:
	_high_contrast = enabled
	if _style != null:
		if enabled:
			_style.bg_color = Color(0.0, 0.0, 0.0, 1.0)
		else:
			_style.bg_color = Color(0.08, 0.10, 0.14, 0.82)
	if _label != null:
		_label.add_theme_color_override("font_color", Color.WHITE)


func is_high_contrast() -> bool:
	return _high_contrast


## Set caption vertical position. Accepted: "bottom" (default), "top".
func set_caption_position(pos: String) -> void:
	_caption_position = pos
	if _panel == null:
		return
	if pos == "top":
		_panel.anchor_top = 0.02
		_panel.anchor_bottom = 0.12
	else:
		_panel.anchor_top = 0.85
		_panel.anchor_bottom = 0.95


## Enable TTS narration for each shown caption.
## When enabled and _audio_governance is set, generates speech via governance pipeline.
func set_tts_narration(enabled: bool) -> void:
	_tts_narration = enabled


func is_tts_narration_enabled() -> bool:
	return _tts_narration


## Inject TTS port for voice narration (optional).
## Replaces legacy setup_audio_governance() — callers must update to this signature.
func setup_tts(port: TextToSpeechPort) -> void:
	_tts = port


## --- Accessors for tests ---

func get_label() -> Label:
	return _label


func get_panel() -> PanelContainer:
	return _panel


## --- Internal ---

func _on_timeout() -> void:
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(_panel, "modulate:a", 0.0, 0.4)
	tween.finished.connect(func(): visible = false)


func _clamp_font_size(size: int) -> int:
	if size <= 24:
		return 24
	if size <= 32:
		return 32
	return 40
