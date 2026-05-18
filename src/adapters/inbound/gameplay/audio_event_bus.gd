class_name AudioEventBus extends Node

signal play_sfx(event_name: String, position: Vector3)
signal play_music(track_name: String)
signal stop_music()

func emit_sfx(event_name: String, position: Vector3 = Vector3.ZERO) -> void:
	play_sfx.emit(event_name, position)
