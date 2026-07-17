extends Node
## Audio bus setup helper.
## Creates the Master -> Music/Voice/SFX hierarchy with proper routing.
## Called once from AudioBank._ready() to ensure buses exist before use.

func _ready() -> void:
	setup_now()
	# Self-destruct after setup
	queue_free()


## AudioBank calls this synchronously before constructing players.  Calling it
## from `_ready` as well keeps the scene safe when it is used standalone.
func setup_now() -> void:
	_setup_audio_buses()


func _setup_audio_buses() -> void:
	# Check if buses already exist
	var audio_server := AudioServer
	
	# Clear existing buses (except Master which always exists)
	var bus_count := audio_server.get_bus_count()
	if bus_count > 1:
		# Remove all non-Master buses
		for i in range(bus_count - 1, 0, -1):
			audio_server.remove_bus(i)
	
	# Create Music bus as child of Master (index 0)
	audio_server.add_bus()
	var music_idx := audio_server.get_bus_count() - 1
	audio_server.set_bus_name(music_idx, "Music")
	audio_server.set_bus_volume_db(music_idx, -12.0)
	
	# Add compressor to Music bus (effects can be configured in editor later)
	# var music_compressor := AudioEffectCompressor.new()
	# music_compressor.active = true
	# audio_server.add_bus_effect(music_idx, music_compressor)
	
	# Create Voice bus
	audio_server.add_bus()
	var voice_idx := audio_server.get_bus_count() - 1
	audio_server.set_bus_name(voice_idx, "Voice")
	audio_server.set_bus_volume_db(voice_idx, 0.0)
	
	# Create SFX bus
	audio_server.add_bus()
	var sfx_idx := audio_server.get_bus_count() - 1
	audio_server.set_bus_name(sfx_idx, "SFX")
	audio_server.set_bus_volume_db(sfx_idx, -6.0)
	
	# Add limiter to SFX bus to catch clipping
	var sfx_limiter := AudioEffectLimiter.new()
	audio_server.add_bus_effect(sfx_idx, sfx_limiter)
	
	print("Audio buses setup: Master -> Music/Voice/SFX")
