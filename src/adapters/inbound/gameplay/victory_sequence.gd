class_name VictorySequence extends Node

signal completed

var _effect_spawner: EffectSpawner
var _audio_bus: AudioEventBus
var _screen_feedback: ScreenFeedback
var _player_controller: PlayerController

func setup(effect_spawner: EffectSpawner, audio_bus: AudioEventBus, screen_feedback: ScreenFeedback, player_controller: PlayerController) -> void:
	_effect_spawner = effect_spawner
	_audio_bus = audio_bus
	_screen_feedback = screen_feedback
	_player_controller = player_controller

func play() -> void:
	if _player_controller != null:
		_player_controller.set_process_input(false)
		_player_controller.set_process(false)

	if _audio_bus != null:
		_audio_bus.emit_sfx("win")

	if _effect_spawner != null:
		for i in range(3):
			var offset := Vector3(randf() * 4 - 2, randf() * 2, randf() * 4 - 2)
			_effect_spawner.spawn_confetti(_player_controller.global_position + offset)
			await get_tree().create_timer(0.3).timeout

	if _screen_feedback != null:
		_screen_feedback.flash(Color(0.2, 0.9, 0.4), 0.3)

	await get_tree().create_timer(1.0).timeout
	completed.emit()
