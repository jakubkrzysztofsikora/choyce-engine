class_name AudioRouter
extends Node
## Autoload "Audio". Reach via AudioRouter.instance.
##
## SPIKE B. Godot can only have ONE active 3D audio listener per world, so
## AudioStreamPlayer3D is unusable for split-screen: three of your four players
## would hear the world from someone else's ears.
##
## Strategy (hybrid, architecture doc §3.3 option C):
##   - GLOBAL cues (music, UI, world events everyone should hear) play once,
##     non-spatial, on the Master bus.
##   - LOCALISED cues play once PER PLAYER on that player's own bus, with volume
##     and pan computed in script from that player's camera transform.
##
## This is more code than "just use AudioStreamPlayer3D", and it is the only
## approach that gives four people on one screen correct-feeling audio.

static var instance: AudioRouter

## Beyond this, a localised cue is simply not played for that player.
@export var max_distance: float = 40.0
@export var falloff_exponent: float = 1.6
## Cap on simultaneous one-shot players before the oldest is recycled.
@export var voice_limit: int = 48

var _voices: Array[AudioStreamPlayer] = []
var _next_voice: int = 0
var _player_bus: Dictionary = {}   # player_id -> bus name


func _ready() -> void:
	instance = self
	process_mode = Node.PROCESS_MODE_PAUSABLE
	for i in voice_limit:
		var p := AudioStreamPlayer.new()
		p.bus = &"Master"
		add_child(p)
		_voices.append(p)


## Heard identically by everyone: music, UI, global announcements.
func play_global(stream: AudioStream, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if stream == null:
		return
	var v := _take_voice()
	v.stream = stream
	# Reset the bus. Voices are shared round-robin with play_at(), which
	# reassigns v.bus to a per-player bus. Without this, a "global" UI or music
	# cue plays on whichever player bus that voice was last used for and
	# inherits that player's current pan.
	v.bus = &"Master"
	v.volume_db = volume_db
	v.pitch_scale = pitch
	v.play()


## Heard per player, panned and attenuated from each player's own viewpoint.
## Returns how many players actually heard it (useful in tests).
func play_at(stream: AudioStream, world_pos: Vector3, volume_db: float = 0.0,
		pitch: float = 1.0) -> int:
	if stream == null:
		return 0
	var reg := PlayerRegistrySystem.instance
	if reg == null:
		return 0
	var heard := 0
	for profile in reg.profiles():
		if not _has_listener(profile):
			continue
		var listener := _listener_xform(profile)
		var to_sound: Vector3 = world_pos - listener.origin
		var dist := to_sound.length()
		if dist > max_distance:
			continue

		var atten := 1.0 - pow(clampf(dist / max_distance, 0.0, 1.0), falloff_exponent)
		if atten <= 0.001:
			continue

		# Pan from the listener's local right axis: -1 hard left, +1 hard right.
		var local_right: float = 0.0
		if dist > 0.001:
			local_right = listener.basis.x.dot(to_sound / dist)

		var v := _take_voice()
		v.stream = stream
		v.bus = _bus_for(profile.player_id)
		v.volume_db = volume_db + linear_to_db(atten)
		v.pitch_scale = pitch
		# AudioStreamPlayer exposes panning through its bus; for a stereo bus a
		# Panner effect on that bus is driven here.
		_set_bus_pan(profile.player_id, local_right)
		v.play()
		heard += 1
	return heard


func _take_voice() -> AudioStreamPlayer:
	# Round-robin. Deliberately steals the oldest voice rather than allocating:
	# a sandbox WILL produce audio storms (a collapsing structure is 40 impacts
	# in 200ms) and unbounded allocation is how you get a frame spike.
	var v := _voices[_next_voice]
	_next_voice = (_next_voice + 1) % _voices.size()
	return v


func _has_listener(profile: SandboxPlayerProfile) -> bool:
	return is_instance_valid(profile.camera) or is_instance_valid(profile.body)


## Camera first (that is where the player's eyes are), body as fallback.
func _listener_xform(profile: SandboxPlayerProfile) -> Transform3D:
	if is_instance_valid(profile.camera):
		return profile.camera.global_transform
	if is_instance_valid(profile.body):
		return (profile.body as Node3D).global_transform
	return Transform3D.IDENTITY


func _bus_for(player_id: int) -> StringName:
	if _player_bus.has(player_id):
		return _player_bus[player_id]
	var bus_name := "P%d" % player_id
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		idx = AudioServer.bus_count
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, bus_name)
		AudioServer.set_bus_send(idx, &"Master")
		var panner := AudioEffectPanner.new()
		AudioServer.add_bus_effect(idx, panner)
	_player_bus[player_id] = StringName(bus_name)
	return _player_bus[player_id]


func _set_bus_pan(player_id: int, pan: float) -> void:
	var idx := AudioServer.get_bus_index("P%d" % player_id)
	if idx == -1:
		return
	var fx := AudioServer.get_bus_effect(idx, 0)
	if fx is AudioEffectPanner:
		(fx as AudioEffectPanner).pan = clampf(pan, -1.0, 1.0)


## Diagnostic for the harness.
func bus_count_for_players() -> int:
	return _player_bus.size()
