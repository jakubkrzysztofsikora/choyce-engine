## Onboarding overlay — inbound UI adapter.
## Phase 4a-4: Polish strings extracted to _t(key) via LocalizationPolicyPort.
## Phase 4c: MOUSE_FILTER_PASS, 30s auto-dismiss, "Pomiń" skip button, 5s TTS prompt.
class_name OnboardingOverlay
extends Control

const IconFont = preload("res://src/adapters/inbound/shared/ui/icon_font.gd")

signal advance_requested

const CONFETTI_DURATION := 1.5
const AUTO_DISMISS_SECONDS := 30.0
const TTS_PROMPT_SECONDS := 5.0

var _label: Label
var _pointer: Node2D
var _target_control: Control
var _step_id: String
var _tween: Tween
var _skip_button: Button
var _auto_dismiss_timer: Timer
var _tts_prompt_timer: Timer
var _localization: LocalizationPolicyPort
var _tts: TextToSpeechPort
var _tts_warning_shown: bool = false


func _ready() -> void:
	# Phase 4c: PASS so taps anywhere can advance the overlay.
	mouse_filter = Control.MOUSE_FILTER_PASS

	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 24)
	_label.add_theme_color_override("font_color", Color.WHITE)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 5)
	add_child(_label)
	_label.hide()

	# Phase 4c: Skip button with ear icon.
	_skip_button = Button.new()
	_skip_button.text = "%s %s" % [IconFont.get_icon("ear"), _t("onboarding.skip")]
	_skip_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_skip_button.offset_left = -160
	_skip_button.offset_top = -56
	_skip_button.offset_right = -16
	_skip_button.offset_bottom = -16
	_skip_button.pressed.connect(_on_skip_pressed)
	add_child(_skip_button)

	# Phase 4c: 30s auto-dismiss timer.
	_auto_dismiss_timer = Timer.new()
	_auto_dismiss_timer.wait_time = AUTO_DISMISS_SECONDS
	_auto_dismiss_timer.one_shot = true
	_auto_dismiss_timer.timeout.connect(_on_auto_dismiss)
	add_child(_auto_dismiss_timer)

	# Phase 4c: 5s TTS prompt timer.
	_tts_prompt_timer = Timer.new()
	_tts_prompt_timer.wait_time = TTS_PROMPT_SECONDS
	_tts_prompt_timer.one_shot = true
	_tts_prompt_timer.timeout.connect(_on_tts_prompt)
	add_child(_tts_prompt_timer)

	modulate.a = 0.0


## Inject TTS port. Call before show_step() for voice prompts to work.
func setup_tts(port: TextToSpeechPort) -> void:
	_tts = port


## Inject localization port. Call before show_step/celebrate_completion if translation needed.
func setup_localization(loc: LocalizationPolicyPort) -> void:
	_localization = loc
	# Refresh skip button text with translated key.
	if _skip_button != null:
		_skip_button.text = "%s %s" % [IconFont.get_icon("ear"), _t("onboarding.skip")]


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
		_label.global_position = target_pos + Vector2(0, -60)
		queue_redraw()
	else:
		_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)

	_animate_appear()
	_auto_dismiss_timer.start()
	_tts_prompt_timer.start()


func celebrate_completion() -> void:
	var feedback = Label.new()
	# Phase 4a-4: use localized key instead of hardcoded Polish string.
	feedback.text = "%s %s" % [IconFont.get_icon("star"), _t("onboarding.celebrate")]
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
	_auto_dismiss_timer.stop()
	_tts_prompt_timer.stop()
	_animate_disappear()


## --- Accessors for tests ---

func get_skip_button() -> Button:
	return _skip_button


func get_auto_dismiss_timer() -> Timer:
	return _auto_dismiss_timer


func get_tts_prompt_timer() -> Timer:
	return _tts_prompt_timer


## --- Internal ---

func _on_skip_pressed() -> void:
	advance_requested.emit()


func _on_auto_dismiss() -> void:
	advance_requested.emit()


func _on_tts_prompt() -> void:
	if _tts != null and _tts.is_available():
		_tts.speak(_t("onboarding.tts_prompt"))
	elif not _tts_warning_shown:
		_tts_warning_shown = true
		push_warning("OnboardingOverlay: TTS port not wired or unavailable — voice prompt skipped.")


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


## Internal localization helper. Falls back to key when no port injected.
func _t(key: String) -> String:
	if _localization != null:
		return _localization.translate(key)
	return key
