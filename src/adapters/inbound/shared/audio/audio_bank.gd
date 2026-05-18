extends Node

# Autoload-only singleton — do NOT declare class_name to avoid collision with the
# autoload identifier `AudioBank` declared in project.godot.

## Global voice/SFX/music helper.
##
## Lazy-loads audio streams from disk on first request and keeps them cached.
## Music fades in/out via a Tween. SFX uses a small pool of AudioStreamPlayers
## so rapid-fire triggers do not cut each other off.
##
## Usage:
##   AudioBank.play_sfx("ui_click")
##   AudioBank.play_voice("greet_landing")
##   AudioBank.play_music("landing_ambient")
##   AudioBank.stop_music()

const VOICE_DIR := "res://data/audio/voice/"
const SFX_DIR   := "res://data/audio/sfx/eleven/"
const MUSIC_DIR := "res://data/audio/music/"

const SFX_POOL_SIZE := 6
const HOVER_THROTTLE_MSEC := 100

var _voice_cache: Dictionary = {}
var _sfx_cache:   Dictionary = {}
var _music_cache: Dictionary = {}

var _sfx_pool: Array[AudioStreamPlayer] = []
var _music_player: AudioStreamPlayer
var _voice_player: AudioStreamPlayer

var _last_hover_msec: int = 0


func _ready() -> void:
	_music_player = AudioStreamPlayer.new()
	_music_player.name = "MusicPlayer"
	_music_player.bus = "Master"
	_music_player.volume_db = -12.0
	add_child(_music_player)

	_voice_player = AudioStreamPlayer.new()
	_voice_player.name = "VoicePlayer"
	_voice_player.bus = "Master"
	_voice_player.volume_db = 0.0
	add_child(_voice_player)

	for i in range(SFX_POOL_SIZE):
		var sfx := AudioStreamPlayer.new()
		sfx.name = "Sfx%d" % i
		sfx.bus = "Master"
		sfx.volume_db = -6.0
		add_child(sfx)
		_sfx_pool.append(sfx)


# ---------- public API ----------

func play_sfx(sfx_name: String) -> void:
	var stream := _load_sfx(sfx_name)
	if stream == null:
		return
	for p in _sfx_pool:
		if not p.playing:
			p.stream = stream
			p.play()
			return
	# All busy — overwrite the first slot
	_sfx_pool[0].stream = stream
	_sfx_pool[0].play()


func play_hover_sfx() -> void:
	var now := Time.get_ticks_msec()
	if now - _last_hover_msec < HOVER_THROTTLE_MSEC:
		return
	_last_hover_msec = now
	play_sfx("ui_hover")


func play_voice(voice_name: String) -> void:
	var stream := _load_voice(voice_name)
	if stream == null:
		return
	_voice_player.stream = stream
	_voice_player.play()


func play_music(music_name: String, fade_in: bool = true) -> void:
	var stream := _load_music(music_name)
	if stream == null:
		return
	if stream is AudioStreamMP3:
		stream.loop = true
	_music_player.stream = stream
	if fade_in:
		_music_player.volume_db = -40.0
		_music_player.play()
		var tw := create_tween()
		tw.tween_property(_music_player, "volume_db", -12.0, 0.8)
	else:
		_music_player.volume_db = -12.0
		_music_player.play()


func stop_music(fade_out: bool = true) -> void:
	if not _music_player.playing:
		return
	if fade_out:
		var tw := create_tween()
		tw.tween_property(_music_player, "volume_db", -40.0, 0.4)
		tw.tween_callback(_music_player.stop)
	else:
		_music_player.stop()


# ---------- private loaders ----------

func _load_voice(voice_name: String) -> AudioStream:
	if _voice_cache.has(voice_name):
		return _voice_cache[voice_name]
	var path := VOICE_DIR + voice_name + ".mp3"
	var s: AudioStream = load(path) if ResourceLoader.exists(path) else null
	if s == null:
		push_warning("AudioBank: voice not found — %s" % path)
	_voice_cache[voice_name] = s
	return s


func _load_sfx(sfx_name: String) -> AudioStream:
	if _sfx_cache.has(sfx_name):
		return _sfx_cache[sfx_name]
	var path := SFX_DIR + sfx_name + ".mp3"
	var s: AudioStream = load(path) if ResourceLoader.exists(path) else null
	if s == null:
		push_warning("AudioBank: sfx not found — %s" % path)
	_sfx_cache[sfx_name] = s
	return s


func _load_music(music_name: String) -> AudioStream:
	if _music_cache.has(music_name):
		return _music_cache[music_name]
	var path := MUSIC_DIR + music_name + ".mp3"
	var s: AudioStream = load(path) if ResourceLoader.exists(path) else null
	if s == null:
		push_warning("AudioBank: music not found — %s" % path)
	_music_cache[music_name] = s
	return s
