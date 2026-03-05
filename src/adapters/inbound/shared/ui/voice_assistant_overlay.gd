class_name VoiceAssistantOverlay
extends Control

signal action_confirmed(action: AIAssistantAction)

var _card: VoiceAssistantCard
var _record_button: Button
var _stt: SpeechToTextPort
var _ai_help: RequestAICreationHelpPort
var _profile: PlayerProfile
var _session_id: String = "session_default"

func setup(stt: SpeechToTextPort, ai_help: RequestAICreationHelpPort, profile: PlayerProfile, session_id: String) -> void:
	_stt = stt
	_ai_help = ai_help
	_profile = profile
	_session_id = session_id


func _init() -> void:
	# Overlay covers full screen but lets events pass when not modal
	# Actually, usually overlays block input when active.
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS

	_record_button = Button.new()
	_record_button.text = "🎤"
	_record_button.custom_minimum_size = Vector2(48, 48)
	# Bottom right
	_record_button.position = Vector2(100, 100) # Placeholder, will layout in _ready or anchors
	_record_button.pressed.connect(_on_record_pressed)
	add_child(_record_button)

	_card = VoiceAssistantCard.new()
	_card.visible = false
	_card.confirmed.connect(_on_card_confirmed)
	_card.cancelled.connect(_on_card_cancelled)
	_card.adjusted.connect(_on_card_adjusted)
	add_child(_card)

func _ready() -> void:
	# Layout
	_record_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_record_button.position -= Vector2(64, 64) # Margin

	_card.set_anchors_preset(Control.PRESET_CENTER)
	# Center signal
	
func _on_record_pressed() -> void:
	print("Nagrywanie polecenia...")
	# Simulate processing delay
	if is_inside_tree():
		await get_tree().create_timer(1.0).timeout
	
	if _ai_help != null and _profile != null:
		var prompt := _capture_prompt_from_stt()
		if prompt.is_empty():
			prompt = "Dodaj spokojny plac zabaw"
		var action := _ai_help.execute(_session_id, prompt, _profile, true)
		if action:
			if action.status == AIAssistantAction.ActionStatus.PROPOSED:
				_card.set_action(action)
				_card.visible = true
				_record_button.visible = false
			else:
				# Auto-executed or rejected?
				print("Action status: ", action.status)
		return

	# Mock result (fallback)
	var dummy_action = AIAssistantAction.new("act_1", "Zbuduj zamek")
	dummy_action.explanation = "Utworze zamek z wiezami w centrum planszy."
	dummy_action.impact_level = AIAssistantAction.ImpactLevel.MEDIUM
	
	_card.set_action(dummy_action)
	_card.visible = true
	_record_button.visible = false

func _on_card_confirmed(action: AIAssistantAction) -> void:
	print("Action confirmed: ", action.intent)
	action_confirmed.emit(action)
	_hide_card()

func _on_card_cancelled() -> void:
	print("Action cancelled")
	_hide_card()


func _on_card_adjusted(action: AIAssistantAction, adjustment_key: String) -> void:
	if action == null:
		return
	print("Action adjusted: %s -> %s" % [action.action_id, adjustment_key])

func _hide_card() -> void:
	_card.visible = false
	_record_button.visible = true


func _capture_prompt_from_stt() -> String:
	if _stt == null:
		return ""

	# Temporary capture bridge until microphone recording adapter is wired.
	var probe_audio := PackedByteArray([16, 32, 64, 128])
	return _stt.transcribe(probe_audio, "pl-PL").strip_edges()
