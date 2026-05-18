## Kid mascot — friendly bunny character drawn entirely via _draw() callbacks.
## Anchored bottom-left of viewport. Reacts to DomainEventBus events.
## Wave V3 note: replace _draw() with AnimatedSprite2D/glTF when Blender assets land.
##
## Hexagonal: inbound adapter (UI). Node/signal use is intentional.
## mouse_filter = MOUSE_FILTER_IGNORE — never blocks UI interaction.
class_name Mascot
extends Control

enum State { IDLE, EXCITED, THINKING, SAD, WAVING }

const HEAD_COLOR := Color(1.0, 0.90, 0.80, 1)   # peach
const EAR_INNER := Color(1.0, 0.62, 0.77, 1)    # pink
const EYE_COLOR := Color(0.18, 0.18, 0.18, 1)
const NOSE_COLOR := Color(1.0, 0.42, 0.42, 1)
const BELLY_COLOR := Color(1, 1, 1, 1)

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
	# Body
	draw_circle(Vector2(80, 140), 56, HEAD_COLOR)
	# Belly oval (approximated with a smaller circle)
	draw_circle(Vector2(80, 150), 36, BELLY_COLOR)
	# Head
	draw_circle(Vector2(80, 72), 48, HEAD_COLOR)
	# Ears
	_draw_ear(Vector2(60, 32))
	_draw_ear(Vector2(100, 32))
	# Eyes
	draw_circle(Vector2(68, 70), 6, EYE_COLOR)
	draw_circle(Vector2(92, 70), 6, EYE_COLOR)
	# Nose triangle
	var pts := PackedVector2Array([Vector2(76, 84), Vector2(84, 84), Vector2(80, 90)])
	draw_polygon(pts, PackedColorArray([NOSE_COLOR, NOSE_COLOR, NOSE_COLOR]))
	# Paw dots
	draw_circle(Vector2(52, 188), 8, HEAD_COLOR)
	draw_circle(Vector2(68, 194), 8, HEAD_COLOR)
	draw_circle(Vector2(92, 194), 8, HEAD_COLOR)
	draw_circle(Vector2(108, 188), 8, HEAD_COLOR)


func _draw_ear(center: Vector2) -> void:
	draw_circle(center, 14, HEAD_COLOR)
	draw_circle(center, 8, EAR_INNER)


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
			say("Spróbuj inaczej!")
		"OnboardingStepChanged":
			set_state(State.WAVING)
		_:
			pass


func _phrase_for(event_type: String) -> String:
	match event_type:
		"WorldRemixed": return "Świetnie!"
		"QuestCompleted": return "Brawo!"
		"OnboardingFinished": return "Hura! Idziemy bawić się!"
		_: return "Hej!"
