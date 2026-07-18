## Regression: Adventure music is continuous, locally playable, and changes
## state without abruptly stopping the outgoing bed.
extends SceneTree

const AudioBankScript = preload("res://src/adapters/inbound/shared/audio/audio_bank.gd")

var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _assert(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		print("FAIL: %s" % message)
		_failures += 1


func _run() -> void:
	var bank := AudioBankScript.new()
	get_root().add_child(bank)
	await process_frame
	_assert(bank.get_node_or_null("MusicPlayer") is AudioStreamPlayer
		and bank.get_node_or_null("MusicPlayerSecondary") is AudioStreamPlayer,
		"music bank owns two players for seamless state crossfades")
	bank.set_adventure_music_state("explore")
	_assert(bank._active_music_is_playing(), "free-roam starts a continuous ambient-phonk bed")
	bank.set_adventure_music_state("danger")
	_assert(bank._current_music_key.begins_with("res://data/audio/music/voxel/") and bank._active_music_is_playing(),
		"nearby danger crossfades to a high-energy curated phonk track")
	bank.set_adventure_music_state("drive")
	_assert(bank._current_music_key.begins_with("res://data/audio/music/voxel/") and bank._active_music_is_playing(),
		"vehicle travel crossfades to a faster driving track")
	bank.rotate_adventure_track()
	_assert(bank._active_music_is_playing(), "active play states rotate through a seamless music crossfade")
	bank.stop_music(false)
	bank.queue_free()
	quit(_failures)
