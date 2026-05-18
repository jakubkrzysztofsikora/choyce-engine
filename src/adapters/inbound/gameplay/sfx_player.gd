class_name SFXPlayer extends Node3D

# Placeholder SFX system — uses AudioStreamPlayer with synthesized tones
# since we don't have actual audio files yet.

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
	match event_name:
		"jump": _play_tone(440.0, 0.15, -10.0)
		"land": _play_tone(220.0, 0.2, -12.0)
		"collect": _play_tone(880.0, 0.2, -8.0)
		"win": _play_chime([523.0, 659.0, 784.0, 1047.0])
		"step": _play_tone(150.0, 0.05, -20.0)
		"ui_click": _play_tone(600.0, 0.08, -15.0)
		"ui_back": _play_tone(400.0, 0.1, -15.0)

func _play_tone(freq: float, duration: float, volume_db: float) -> void:
	var player := AudioStreamPlayer.new()
	var gen := AudioStreamGenerator.new()
	gen.buffer_length = duration
	player.stream = gen
	player.volume_db = volume_db
	add_child(player)
	player.play()
	# Synthesize a simple sine wave
	var playback: AudioStreamGeneratorPlayback = player.get_stream_playback()
	var sample_rate := gen.mix_rate
	var frames := int(sample_rate * duration)
	for i in range(frames):
		var t := float(i) / sample_rate
		playback.push_frame(Vector2.ONE * sin(t * freq * TAU) * (1.0 - t / duration))
	await get_tree().create_timer(duration).timeout
	player.queue_free()

func _play_chime(freqs: Array) -> void:
	for freq in freqs:
		_play_tone(freq, 0.25, -10.0)
		await get_tree().create_timer(0.1).timeout
