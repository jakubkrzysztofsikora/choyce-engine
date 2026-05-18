class_name SFXPlayer extends Node3D

# SFX dispatcher — routes gameplay audio events to AudioBank-loaded streams.
# Previously used synthesized tones (AudioStreamGenerator); now uses real assets.

var _audio_bus: AudioEventBus


func _ready() -> void:
	# Connect to AudioEventBus if available (search parent then siblings)
	var parent_node := get_parent()
	if parent_node is AudioEventBus:
		_audio_bus = parent_node
	else:
		for child in parent_node.get_children():
			if child is AudioEventBus:
				_audio_bus = child
				break
	if _audio_bus != null:
		_audio_bus.play_sfx.connect(play)


func play(event_name: String, _position: Vector3 = Vector3.ZERO) -> void:
	var bank: Node = get_node_or_null("/root/AudioBank")
	if bank == null:
		return
	match event_name:
		"jump":     bank.play_sfx("jump_up")
		"land":     bank.play_sfx("land_soft")
		"collect":  bank.play_sfx("collect_coin")
		"win":      bank.play_sfx("victory_fanfare")
		"step":     bank.play_sfx("footstep_grass")
		"ui_click": bank.play_sfx("ui_click")
		"ui_back":  bank.play_sfx("ui_back")
		_:
			# Attempt a direct name match so future events resolve automatically
			bank.play_sfx(event_name)
