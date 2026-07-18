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
## Curated from the imported, moderation-cleared pack. These sets deliberately
## favour bright synth hooks, punchy drums, and short-form game energy over the
## slower ambient/R&B material in the source pack.  They are the closest fit to
## a playful, Roblox-like gen-Z phonk bed without introducing lyrics.
const GEN_Z_PHONK_EXPLORATION := ["circuit_synthwave", "tokyo_trap", "drift_synthwave_02"]
const GEN_Z_PHONK_DANGER := ["drift_drums_xd250", "tokyo_trap", "circuit_synthwave"]
const GEN_Z_PHONK_DRIVE := ["drift_drums_xd250", "tokyo_trap", "circuit_synthwave"]
const GEN_Z_PHONK_NIGHT := ["drift_synthwave_01", "circuit_synthwave"]

const SFX_POOL_SIZE := 6
const HOVER_THROTTLE_MSEC := 100

# Bus setup helper - ensures buses exist before use
var _bus_setup: Node = null

var _voice_cache: Dictionary = {}
var _sfx_cache:   Dictionary = {}
var _music_cache: Dictionary = {}
## Slugs of phonk tracks discovered at startup (filenames sans .mp3).
var _voxel_phonk_slugs: Array[String] = []
## Index of the last slug played, so we don't repeat back-to-back.
var _last_phonk_index: int = -1

var _sfx_pool: Array[AudioStreamPlayer] = []
var _melee_pool: Array[AudioStreamPlayer] = []
var _music_player: AudioStreamPlayer
var _music_player_secondary: AudioStreamPlayer
var _voice_player: AudioStreamPlayer
var _voice_queue: Array[Dictionary] = []
var _active_music_player := 0
var _music_transition: Tween = null
var _current_music_key := ""
var _adventure_music_state := ""

var _last_hover_msec: int = 0


func _ready() -> void:
	# Set up buses synchronously. The previous one-frame await left this autoload
	# half-initialized while LauncherOverlay was already asking it for music.
	var bus_setup_scene := load("res://src/adapters/inbound/shared/audio/bus_setup.tscn") as PackedScene
	if bus_setup_scene != null:
		_bus_setup = bus_setup_scene.instantiate()
		if _bus_setup.has_method("setup_now"):
			_bus_setup.call("setup_now")
		_bus_setup = null
	
	_music_player = AudioStreamPlayer.new()
	_music_player.name = "MusicPlayer"
	_music_player.bus = "Music"
	_music_player.volume_db = -40.0
	add_child(_music_player)
	_music_player_secondary = AudioStreamPlayer.new()
	_music_player_secondary.name = "MusicPlayerSecondary"
	_music_player_secondary.bus = "Music"
	_music_player_secondary.volume_db = -40.0
	add_child(_music_player_secondary)

	_voice_player = AudioStreamPlayer.new()
	_voice_player.name = "VoicePlayer"
	_voice_player.bus = "Voice"
	_voice_player.volume_db = 0.0
	_voice_player.finished.connect(_play_next_voice)
	add_child(_voice_player)

	for i in range(SFX_POOL_SIZE):
		var sfx := AudioStreamPlayer.new()
		sfx.name = "Sfx%d" % i
		sfx.bus = "SFX"
		sfx.volume_db = 0.0
		add_child(sfx)
		_sfx_pool.append(sfx)
	for i in range(4):
		var melee := AudioStreamPlayer.new()
		melee.name = "Melee%d" % i
		melee.bus = "SFX"
		melee.volume_db = 0.0
		add_child(melee)
		_melee_pool.append(melee)

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
	# All busy — overwrite the first slot.
	if not _sfx_pool.is_empty():
		_sfx_pool[0].stream = stream
		_sfx_pool[0].play()


## Short physical contact. Prefer the locally bundled ElevenLabs punch/kick
## clips; their use keeps audible impact grounded in a real recorded-style SFX
## rather than a tone generator. The dry synthesis below is only a resilient
## fallback if a local clip is missing or fails to import.
func play_melee_impact(style: String = "punch") -> void:
	var asset_key := "kick_impact" if style == "kick" else "punch_thud"
	if _load_sfx(asset_key) != null:
		play_sfx(asset_key)
		return
	var player: AudioStreamPlayer = null
	for candidate in _melee_pool:
		if not candidate.playing:
			player = candidate
			break
	if player == null and not _melee_pool.is_empty():
		player = _melee_pool[0]
	if player == null:
		return
	var generator := AudioStreamGenerator.new()
	generator.mix_rate = 44100.0
	generator.buffer_length = 0.22 if style == "kick" else 0.16
	player.stream = generator
	player.play()
	var playback := player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback == null:
		return
	var frames := int(generator.mix_rate * generator.buffer_length)
	var base_hz := 62.0 if style == "kick" else 104.0
	var body_gain := 0.78 if style == "kick" else 0.62
	var crack_gain := 0.22 if style == "kick" else 0.34
	for i in frames:
		var t := float(i) / generator.mix_rate
		var body_env := exp(-t * (25.0 if style == "kick" else 34.0))
		var crack_env := exp(-t * 110.0)
		var body := sin(TAU * base_hz * t) * body_env * body_gain
		body += sin(TAU * (base_hz * 1.9) * t) * body_env * 0.18
		var crack := randf_range(-1.0, 1.0) * crack_env * crack_gain
		var sample := clampf(body + crack, -1.0, 1.0)
		playback.push_frame(Vector2(sample, sample))


## Dry contact cues for an action before/without a hit. These intentionally
## avoid the old tonal imported whoosh: an arm moving through air should read
## as cloth/air, while axe and pickaxe work should read as wood and stone.
func play_physical_action(action: String) -> void:
	var player: AudioStreamPlayer = null
	for candidate in _melee_pool:
		if not candidate.playing:
			player = candidate
			break
	if player == null and not _melee_pool.is_empty():
		player = _melee_pool[0]
	if player == null:
		return
	var is_pickaxe := action.contains("pickaxe")
	var is_axe := action.contains("axe")
	var duration := 0.12 if is_pickaxe or is_axe else 0.075
	var generator := AudioStreamGenerator.new()
	generator.mix_rate = 44100.0
	generator.buffer_length = duration
	player.stream = generator
	player.play()
	var playback := player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback == null:
		return
	var frames := int(generator.mix_rate * duration)
	for i in frames:
		var t := float(i) / generator.mix_rate
		var impact_env := exp(-t * (42.0 if is_axe else (58.0 if is_pickaxe else 70.0)))
		var noise_gain := 0.30 if is_axe else (0.18 if is_pickaxe else 0.10)
		var tone_hz := 118.0 if is_axe else (235.0 if is_pickaxe else 85.0)
		var tone_gain := 0.34 if is_axe else (0.24 if is_pickaxe else 0.045)
		var sample := randf_range(-1.0, 1.0) * impact_env * noise_gain
		sample += sin(TAU * tone_hz * t) * impact_env * tone_gain
		playback.push_frame(Vector2(clampf(sample, -1.0, 1.0), clampf(sample, -1.0, 1.0)))


func play_hover_sfx() -> void:
	var now := Time.get_ticks_msec()
	if now - _last_hover_msec < HOVER_THROTTLE_MSEC:
		return
	_last_hover_msec = now
	play_sfx("ui_hover")


func play_voice(voice_name: String) -> void:
	play_voice_variant(voice_name, 1.0)


## Plays a short voice line with a bounded pitch variation. The cinematic uses
## this for two distinct, kid-like character voices while keeping all audio
## local and deterministic; normal narration remains at pitch 1.0.
func play_voice_variant(voice_name: String, pitch_scale: float = 1.0) -> void:
	var stream := _load_voice(voice_name)
	if stream == null:
		return
	_voice_queue.append({
		"stream": stream,
		"pitch_scale": clampf(pitch_scale, 0.85, 1.35),
	})
	if _voice_player != null and not _voice_player.playing:
		_play_next_voice()


func _play_next_voice() -> void:
	if _voice_player == null or _voice_queue.is_empty():
		return
	var next_line: Dictionary = _voice_queue.pop_front()
	_voice_player.stream = next_line.get("stream") as AudioStream
	_voice_player.pitch_scale = float(next_line.get("pitch_scale", 1.0))
	_voice_player.play()


func stop_voice() -> void:
	_voice_queue.clear()
	if _voice_player != null:
		_voice_player.stop()
		_voice_player.pitch_scale = 1.0


## Kid-safe drift phonk profile. Volume capped at -20 dB so the
## loop doesn't fight UI sounds or overstimulate a 7-yo. Pitch
## stays at 1.0 because the new "drift_phonk" track is authored
## at the right tempo upstream — no chopped-and-screwed hack
## needed.
const MUSIC_PITCH := 1.0
const MUSIC_TARGET_VOLUME_DB := -12.0


func play_music(music_name: String, fade_in: bool = true) -> void:
	var stream := _load_music(music_name)
	_play_music_stream(stream, music_name, fade_in)


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


func _play_curated_voxel_track(candidates: Array, fade_in: bool = true) -> bool:
	var available: Array[String] = []
	for candidate_variant in candidates:
		var candidate := String(candidate_variant)
		if candidate in _voxel_phonk_slugs:
			available.append(candidate)
	if available.is_empty():
		return false
	var idx := randi() % available.size()
	if available.size() > 1 and available[idx] == _current_music_key.get_file().get_basename():
		idx = (idx + 1) % available.size()
	_play_music_from_dir(MUSIC_DIR_VOXEL, available[idx], fade_in)
	return true


## Runtime-facing music director for the playable adventure. These are all
## local, moderated, non-lyrical tracks. Keeping selection here makes menu,
## direct-launch, driving, and combat transitions use one crossfade path.
func set_adventure_music_state(state: String) -> void:
	var normalized := state.strip_edges().to_lower()
	if normalized.is_empty():
		normalized = "explore"
	if normalized == _adventure_music_state and _active_music_is_playing():
		return
	_adventure_music_state = normalized
	match normalized:
		"danger":
			if not _play_curated_voxel_track(GEN_Z_PHONK_DANGER, true):
				play_music("combat_phonk", true)
		"drive":
			if not _play_curated_voxel_track(GEN_Z_PHONK_DRIVE, true):
				play_music("drift_phonk", true)
		"night":
			if not _play_curated_voxel_track(GEN_Z_PHONK_NIGHT, true):
				play_music("mushroom_forest", true)
		"explore":
			if not _play_curated_voxel_track(GEN_Z_PHONK_EXPLORATION, true):
				play_music("adventure_island", true)
		_:
			play_music("adventure_island", true)


## Rotate a state-specific bed through the same crossfade path. This keeps a
## long sandbox session lively while never cutting music, SFX, or dialogue off.
func rotate_adventure_track() -> void:
	match _adventure_music_state:
		"danger":
			_play_curated_voxel_track(GEN_Z_PHONK_DANGER, true)
		"drive":
			_play_curated_voxel_track(GEN_Z_PHONK_DRIVE, true)
		"night":
			_play_curated_voxel_track(GEN_Z_PHONK_NIGHT, true)
		"explore":
			_play_curated_voxel_track(GEN_Z_PHONK_EXPLORATION, true)


## Compatibility entry point for existing callers. New runtime code should use
## rotate_adventure_track() so every play state can stay fresh.
func rotate_adventure_exploration_track() -> void:
	if _adventure_music_state == "explore":
		rotate_adventure_track()


func stop_music(fade_out: bool = true) -> void:
	if _music_player == null:
		return
	if _music_transition != null and is_instance_valid(_music_transition):
		_music_transition.kill()
	var playing_players: Array[AudioStreamPlayer] = []
	for player in [_music_player, _music_player_secondary]:
		if player != null and player.playing:
			playing_players.append(player)
	if playing_players.is_empty():
		return
	if fade_out:
		_music_transition = create_tween()
		for player in playing_players:
			_music_transition.parallel().tween_property(player, "volume_db", -40.0, 0.4)
			_music_transition.parallel().tween_callback(player.stop)
	else:
		for player in playing_players:
			player.stop()
	_current_music_key = ""
	_adventure_music_state = ""


# ---------- private loaders ----------

func _load_voice(voice_name: String) -> AudioStream:
	if _voice_cache.has(voice_name):
		return _voice_cache[voice_name]
	var path := VOICE_DIR + voice_name + ".mp3"
	if not ResourceLoader.exists(path):
		path = VOICE_DIR + voice_name + ".wav"
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
	# H1: Set loop_offset to skip silent tails for seamless looping
	if s is AudioStreamMP3:
		s.loop = true
		# Known music files and their loop points (end of silence tail)
		match music_name:
			"adventure_island":
				s.loop_offset = 28.0
			"celebration":
				s.loop_offset = 28.7
			"combat_phonk":
				s.loop_offset = 29.0
			"landing_ambient":
				s.loop_offset = 29.2
			"little_farm":
				s.loop_offset = 28.3
			"mushroom_forest":
				s.loop_offset = 28.1
			_:  # default: try to detect from file duration
				pass
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
		if stream is AudioStreamMP3:
			stream.loop = true
			# Voxel phonk tracks: default loop offset to avoid silence
			stream.loop_offset = 29.0
	_play_music_stream(stream, dir + slug, fade_in)


func _active_music_is_playing() -> bool:
	var active := _music_player if _active_music_player == 0 else _music_player_secondary
	return active != null and active.playing


func _play_music_stream(stream: AudioStream, music_key: String, fade_in: bool) -> void:
	if stream == null or _music_player == null or _music_player_secondary == null:
		return
	if music_key == _current_music_key and _active_music_is_playing():
		return
	if stream is AudioStreamMP3:
		stream.loop = true
	var from := _music_player if _active_music_player == 0 else _music_player_secondary
	var to := _music_player_secondary if _active_music_player == 0 else _music_player
	if _music_transition != null and is_instance_valid(_music_transition):
		_music_transition.kill()
	to.stream = stream
	to.pitch_scale = MUSIC_PITCH
	to.volume_db = -40.0 if fade_in else MUSIC_TARGET_VOLUME_DB
	to.play()
	_current_music_key = music_key
	if not fade_in or not from.playing:
		from.stop()
		_active_music_player = 1 - _active_music_player
		return
	_music_transition = create_tween()
	_music_transition.tween_property(from, "volume_db", -40.0, 0.85)
	_music_transition.parallel().tween_property(to, "volume_db", MUSIC_TARGET_VOLUME_DB, 0.85)
	_music_transition.tween_callback(from.stop)
	_active_music_player = 1 - _active_music_player


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
