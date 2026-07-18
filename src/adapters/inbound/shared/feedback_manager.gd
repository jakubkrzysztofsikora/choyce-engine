## Adapter: Centralized feedback system for captions and voice.
## Part of the Nutrition sandbox loop for VS-025.
##
## Design notes:
## - Manages caption display timing
## - Routes voice requests to the audio system
## - Child-safe: all text is appropriate for ages 6-12
## - Optional: voice can be disabled
class_name FeedbackManager
extends Node


## Signals
signal caption_shown(text: String, duration: float)
signal voice_played(voice_id: String, text: String)


# Reference to the caption label (set via editor or code)
@export var caption_label: Label = null

# Reference to the AudioManager (optional)
@export var audio_manager: Node = null

# Default voice ID for child voice
@export var default_voice_id: String = "child_voice_english"

# Whether voice is enabled
@export var voice_enabled: bool = true

# Whether captions are enabled
@export var captions_enabled: bool = true

# Current caption queue (for sequential display)
var _caption_queue: Array[Dictionary] = []

# Whether a caption is currently displayed
var _caption_visible: bool = false

# Timer for current caption
var _caption_timer: float = 0.0
var _current_caption_duration: float = 0.0


## Called when the node enters the scene tree for the first time
func _ready() -> void:
	if caption_label == null:
		## Try to find a caption label in the scene
		caption_label = get_node_or_null("/root/Main/UI/Captions/CaptionLabel")
		if caption_label == null:
			caption_label = get_node_or_null("$CaptionLabel")
	
	if caption_label != null:
		caption_label.visible = false


## Process caption timer
func _process(delta: float) -> void:
	if not _caption_visible:
		return
	
	_caption_timer += delta
	if _caption_timer >= _current_caption_duration:
		_hide_current_caption()
		_show_next_caption()


## Show a caption
func show_caption(text: String, duration: float = 3.0) -> void:
	if not captions_enabled or caption_label == null:
		return
	
	## Add to queue or show immediately
	if _caption_visible:
		_caption_queue.append({"text": text, "duration": duration})
	else:
		_show_caption_immediately(text, duration)


## Show caption immediately (bypassing queue)
func _show_caption_immediately(text: String, duration: float) -> void:
	if caption_label == null:
		return
	
	caption_label.text = text
	caption_label.visible = true
	_caption_visible = true
	_caption_timer = 0.0
	_current_caption_duration = duration
	
	caption_shown.emit(text, duration)


## Hide current caption
func _hide_current_caption() -> void:
	if caption_label == null:
		return
	
	caption_label.visible = false
	_caption_visible = false


## Show next caption from queue
func _show_next_caption() -> void:
	if _caption_queue.size() > 0:
		var next_caption: Dictionary = _caption_queue.pop_front()
		_show_caption_immediately(next_caption["text"], next_caption.get("duration", 3.0))


## Play a voice line
func play_voice(voice_id: String, text: String) -> void:
	if not voice_enabled:
		return
	
	## Try to use AudioManager if available
	if audio_manager != null and audio_manager.has_method("play_voice"):
		audio_manager.call("play_voice", voice_id, text)
	elif audio_manager != null and audio_manager.has_method("play_sfx"):
		## Fallback to SFX
		audio_manager.call("play_sfx", "voice_" + voice_id)
	else:
		## Try to find AudioBank in the scene
		var audio_bank := get_node_or_null("/root/Main/AudioBank")
		if audio_bank != null and audio_bank.has_method("play_voice"):
			audio_bank.call("play_voice", voice_id)
		elif audio_bank != null and audio_bank.has_method("play_voice_variant"):
			audio_bank.call("play_voice_variant", voice_id)
	
	voice_played.emit(voice_id, text)


## Show caption and play voice simultaneously
func show_caption_and_voice(text: String, voice_id: String = "", duration: float = 3.0) -> void:
	show_caption(text, duration)
	if voice_id == "" or voice_id == null:
		voice_id = default_voice_id
	play_voice(voice_id, text)


## Clear all pending captions
func clear_queue() -> void:
	_caption_queue.clear()
	_hide_current_caption()


## Set caption label reference
func set_caption_label(label: Label) -> void:
	caption_label = label
	if caption_label != null:
		caption_label.visible = false


## Set audio manager reference
func set_audio_manager(manager: Node) -> void:
	audio_manager = manager


## Enable or disable voice
func set_voice_enabled(enabled: bool) -> void:
	voice_enabled = enabled


## Enable or disable captions
func set_captions_enabled(enabled: bool) -> void:
	captions_enabled = enabled
	if not enabled and _caption_visible:
		_hide_current_caption()
		clear_queue()


## Set default voice ID
func set_default_voice_id(voice_id: String) -> void:
	default_voice_id = voice_id
