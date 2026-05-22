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
## CC0 phonk pack imported via scripts/audio/moderate_imported_music.py.
## Every track in this dir has passed STT-based lyric moderation against
## data/moderation/rules_pl.json. play_phonk_random() rotates through them.
const MUSIC_DIR_VOXEL := "res://data/audio/music/voxel/"

const SFX_POOL_SIZE := 6
const HOVER_THROTTLE_MSEC := 100

var _voice_cache: Dictionary = {}
var _sfx_cache:   Dictionary = {}
var _music_cache: Dictionary = {}
## Slugs of phonk tracks discovered at startup (filenames sans .mp3).
var _voxel_phonk_slugs: Array[String] = []
## Index of the last slug played, so we don't repeat back-to-back.
var _last_phonk_index: int = -1

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

	_scan_voxel_phonk()


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


## Kid-safe drift phonk profile. Volume capped at -20 dB so the
## loop doesn't fight UI sounds or overstimulate a 7-yo. Pitch
## stays at 1.0 because the new "drift_phonk" track is authored
## at the right tempo upstream — no chopped-and-screwed hack
## needed.
const MUSIC_PITCH := 1.0
const MUSIC_TARGET_VOLUME_DB := -20.0


func play_music(music_name: String, fade_in: bool = true) -> void:
	var stream := _load_music(music_name)
	if stream == null:
		return
	if stream is AudioStreamMP3:
		stream.loop = true
	_music_player.stream = stream
	_music_player.pitch_scale = MUSIC_PITCH
	if fade_in:
		_music_player.volume_db = -40.0
		_music_player.play()
		var tw := create_tween()
		tw.tween_property(_music_player, "volume_db", MUSIC_TARGET_VOLUME_DB, 1.2)
	else:
		_music_player.volume_db = MUSIC_TARGET_VOLUME_DB
		_music_player.play()


## Plays a random CC0 phonk track from data/audio/music/voxel/.
## Used as the new default for landing + combat-mode shells. Never repeats
## the same track twice in a row. If the voxel dir is empty (e.g. tests
## stub the project structure), falls back silently — caller decides
## whether to play a different track.
func play_phonk_random(fade_in: bool = true) -> bool:
	if _voxel_phonk_slugs.is_empty():
		push_warning("AudioBank: voxel phonk dir empty — play_phonk_random no-op")
		return false
	var idx := randi() % _voxel_phonk_slugs.size()
	if _voxel_phonk_slugs.size() > 1 and idx == _last_phonk_index:
		idx = (idx + 1) % _voxel_phonk_slugs.size()
	_last_phonk_index = idx
	var slug := _voxel_phonk_slugs[idx]
	_play_music_from_dir(MUSIC_DIR_VOXEL, slug, fade_in)
	return true


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


## Internal: load + play a track from an arbitrary res:// music dir.
## Mirrors play_music() but lets callers swap MUSIC_DIR for MUSIC_DIR_VOXEL
## (or any future genre dir) without polluting the slug namespace.
func _play_music_from_dir(dir: String, slug: String, fade_in: bool) -> void:
	var cache_key := dir + slug
	var stream: AudioStream
	if _music_cache.has(cache_key):
		stream = _music_cache[cache_key]
	else:
		var path := dir + slug + ".mp3"
		stream = load(path) if ResourceLoader.exists(path) else null
		if stream == null:
			push_warning("AudioBank: music not found — %s" % path)
		_music_cache[cache_key] = stream
	if stream == null:
		return
	if stream is AudioStreamMP3:
		stream.loop = true
	_music_player.stream = stream
	_music_player.pitch_scale = MUSIC_PITCH
	if fade_in:
		_music_player.volume_db = -40.0
		_music_player.play()
		var tw := create_tween()
		tw.tween_property(_music_player, "volume_db", MUSIC_TARGET_VOLUME_DB, 1.2)
	else:
		_music_player.volume_db = MUSIC_TARGET_VOLUME_DB
		_music_player.play()


## Scans res://data/audio/music/voxel/ at startup and remembers the
## slugs (filenames sans .mp3) so play_phonk_random() can rotate.
## Empty dir is non-fatal — caller fallback handles it.
func _scan_voxel_phonk() -> void:
	_voxel_phonk_slugs.clear()
	var dir := DirAccess.open(MUSIC_DIR_VOXEL)
	if dir == null:
		push_warning("AudioBank: voxel phonk dir missing — %s" % MUSIC_DIR_VOXEL)
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if not dir.current_is_dir() and name.ends_with(".mp3"):
			_voxel_phonk_slugs.append(name.get_basename())
		name = dir.get_next()
	dir.list_dir_end()
	_voxel_phonk_slugs.sort()
