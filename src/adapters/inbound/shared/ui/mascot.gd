## Kid mascot — NINJA sidekick character drawn entirely via _draw() callbacks.
## Replaces the original bunny (kid was 7, asked for something cooler than
## a baby rabbit). Original IP only — Steve/Mario/brainrot are trademarked
## and would break the CC0-only constraint in CLAUDE.md.
## Anchored bottom-left of viewport. Reacts to DomainEventBus events.
##
## Hexagonal: inbound adapter (UI). Node/signal use is intentional.
## mouse_filter = MOUSE_FILTER_IGNORE — never blocks UI interaction.
class_name Mascot
extends Control

enum State { IDLE, EXCITED, THINKING, SAD, WAVING }

# Ninja palette — dark hood, red highlight band, white slit-eyes.
const HOOD_COLOR := Color(0.10, 0.10, 0.14, 1)   # near-black hood
const BAND_COLOR := Color(0.85, 0.18, 0.22, 1)   # red headband
const EYE_GLOW := Color(0.98, 0.98, 1.0, 1)      # white slit eyes
const EYE_PUPIL := Color(0.08, 0.10, 0.16, 1)    # dark pupil dot
const BELT_COLOR := Color(0.85, 0.18, 0.22, 1)   # red belt
const SKIN_BAND := Color(0.96, 0.85, 0.72, 1)    # exposed eye-strip skin
# Legacy aliases kept for any external draw helpers still in tree.
const HEAD_COLOR := HOOD_COLOR
const EAR_INNER := BAND_COLOR
const EYE_COLOR := EYE_PUPIL
const NOSE_COLOR := BAND_COLOR
const BELLY_COLOR := HOOD_COLOR

var _state: State = State.IDLE
var _event_bus: Variant  # DomainEventBus duck-typed
var _voice_prompt: Variant  # VoicePromptPort duck-typed
var _speech_panel: PanelContainer
var _speech_label: Label
var _wiggle_tween: Tween


func _ready() -> void:
	custom_minimum_size = Vector2(160, 220)
	pivot_offset = Vector2(80, 180)  # rotate around body centre
	mouse_filter = MOUSE_FILTER_IGNORE
	_build_speech_bubble()
	_start_idle_wiggle()


func _draw() -> void:
	# Body — hooded torso (rounded rect via overlapping circles + rect).
	draw_rect(Rect2(Vector2(32, 110), Vector2(96, 90)), HOOD_COLOR, true)
	draw_circle(Vector2(80, 110), 48, HOOD_COLOR)
	# Red belt across the waist.
	draw_rect(Rect2(Vector2(32, 168), Vector2(96, 10)), BELT_COLOR, true)
	# Hood — head silhouette.
	draw_circle(Vector2(80, 64), 48, HOOD_COLOR)
	# Hood point on top (small triangle) — gives the ninja a peak.
	var hood_peak := PackedVector2Array([Vector2(80, 12), Vector2(64, 36), Vector2(96, 36)])
	draw_polygon(hood_peak, PackedColorArray([HOOD_COLOR, HOOD_COLOR, HOOD_COLOR]))
	# Eye-band — exposed skin strip across the eyes.
	draw_rect(Rect2(Vector2(36, 56), Vector2(88, 18)), SKIN_BAND, true)
	# Red headband stripe on top of the eye-band.
	draw_rect(Rect2(Vector2(36, 50), Vector2(88, 8)), BAND_COLOR, true)
	# Two slit eyes — narrow horizontal ellipses approximated as rects.
	draw_rect(Rect2(Vector2(54, 62), Vector2(14, 6)), EYE_GLOW, true)
	draw_rect(Rect2(Vector2(92, 62), Vector2(14, 6)), EYE_GLOW, true)
	# Dark pupil dots inside the slit eyes.
	draw_circle(Vector2(61, 65), 2.5, EYE_PUPIL)
	draw_circle(Vector2(99, 65), 2.5, EYE_PUPIL)
	# Crossed-arms hint — two diagonal bands across the chest.
	draw_line(Vector2(38, 130), Vector2(122, 158), BELT_COLOR, 3)
	draw_line(Vector2(122, 130), Vector2(38, 158), BELT_COLOR, 3)


func _draw_ear(center: Vector2) -> void:
	# Legacy method kept so any older call sites compile. No-op visually
	# now that the ninja has no ears.
	pass


## Wire the mascot to the DomainEventBus and optional VoicePromptPort.
## Returns self for chaining. Safe to call before _ready().
func setup(event_bus: Variant, voice_prompt: Variant = null) -> Mascot:
	_event_bus = event_bus
	_voice_prompt = voice_prompt
	if event_bus != null and event_bus.has_method("subscribe_all"):
		event_bus.subscribe_all(Callable(self, "_on_domain_event"))
	return self


func _build_speech_bubble() -> void:
	_speech_panel = PanelContainer.new()
	_speech_panel.position = Vector2(120, 0)
	_speech_panel.modulate.a = 0.0
	_speech_panel.mouse_filter = MOUSE_FILTER_IGNORE
	var label := Label.new()
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", Color(0.18, 0.18, 0.18, 1))
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(140, 0)
	label.text = ""
	_speech_label = label
	_speech_panel.add_child(label)
	add_child(_speech_panel)


## Display a speech bubble for duration_sec, optionally invoking VoicePromptPort.
func say(text: String, duration_sec: float = 3.0) -> void:
	# Caller (CreateShell._greet_via_mascot) can fire before our own
	# _ready() builds the bubble. Lazy-build so the first line isn't
	# eaten and the runtime doesn't NPE on `_speech_label.text`.
	if _speech_label == null or _speech_panel == null:
		_build_speech_bubble()
	if _speech_label == null:
		return
	_speech_label.text = text
	_speech_panel.modulate.a = 0.0
	_speech_panel.scale = Vector2(0.6, 0.6)
	var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_speech_panel, "scale", Vector2(1.0, 1.0), 0.25)
	tw.parallel().tween_property(_speech_panel, "modulate:a", 1.0, 0.2)
	if _voice_prompt != null and _voice_prompt.has_method("speak"):
		_voice_prompt.speak(text)
	await get_tree().create_timer(duration_sec).timeout
	var fade := create_tween()
	fade.tween_property(_speech_panel, "modulate:a", 0.0, 0.4)


func set_state(new_state: State) -> void:
	_state = new_state
	match new_state:
		State.EXCITED: _play_excited()
		State.SAD: _play_sad()
		State.WAVING: _play_waving()
		_: _start_idle_wiggle()


func _start_idle_wiggle() -> void:
	if _wiggle_tween != null and _wiggle_tween.is_valid():
		_wiggle_tween.kill()
	_wiggle_tween = create_tween().set_loops()
	_wiggle_tween.tween_property(self, "rotation_degrees", 4.0, 0.7).set_ease(Tween.EASE_IN_OUT)
	_wiggle_tween.tween_property(self, "rotation_degrees", -4.0, 0.7).set_ease(Tween.EASE_IN_OUT)


func _play_excited() -> void:
	if _wiggle_tween != null and _wiggle_tween.is_valid():
		_wiggle_tween.kill()
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.15, 1.15), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "scale", Vector2(1.0, 1.0), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.finished.connect(func(): set_state(State.IDLE))


func _play_sad() -> void:
	if _wiggle_tween != null and _wiggle_tween.is_valid():
		_wiggle_tween.kill()
	var tw := create_tween()
	tw.tween_property(self, "rotation_degrees", -8.0, 0.3)
	tw.tween_property(self, "rotation_degrees", 0.0, 0.5)
	tw.finished.connect(func(): set_state(State.IDLE))


func _play_waving() -> void:
	if _wiggle_tween != null and _wiggle_tween.is_valid():
		_wiggle_tween.kill()
	var tw := create_tween()
	tw.tween_property(self, "rotation_degrees", 12.0, 0.25)
	tw.tween_property(self, "rotation_degrees", -12.0, 0.25)
	tw.tween_property(self, "rotation_degrees", 12.0, 0.25)
	tw.tween_property(self, "rotation_degrees", 0.0, 0.25)
	tw.finished.connect(func(): set_state(State.IDLE))


## Subscriber callback for DomainEventBus.subscribe_all.
## Matches on event.event_type (the short string set by each DomainEvent subclass).
func _on_domain_event(event: Variant) -> void:
	if event == null:
		return
	var event_type: String = ""
	if event.has_method("get_event_type"):
		event_type = event.get_event_type()
	elif "event_type" in event:
		event_type = str(event.event_type)
	match event_type:
		# DomainEvent.event_type strings match the first arg of super._init(), NOT the class name.
		"WorldRemixed", "QuestCompleted", "OnboardingFinished":
			set_state(State.EXCITED)
			say(_phrase_for(event_type))
		"ParentalPolicyDecryptionFailed":
			set_state(State.SAD)
			say("Coś nie pasuje. Spróbuj inaczej.")
		"OnboardingStepChanged":
			set_state(State.WAVING)
		_:
			pass


func _phrase_for(event_type: String) -> String:
	# Ninja-mascot dialogue — short, calm, dry. No exclamation overload.
	match event_type:
		"WorldRemixed": return "Niezły remix."
		"QuestCompleted": return "Tak. Następna misja?"
		"OnboardingFinished": return "Gotowy. Czas iść."
		_: return "Cześć."
