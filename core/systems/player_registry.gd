class_name PlayerRegistrySystem
extends Node
## Autoload: PlayerRegistry  (reach it as PlayerRegistrySystem.instance)
##
## Owns the mapping device -> logical player. Nothing else is allowed to
## allocate a player_id. Supports drop-in / drop-out mid-session, which is the
## whole point of the couch co-op architecture.

static var instance: PlayerRegistrySystem

const MAX_PLAYERS := 4

signal player_joined(profile: SandboxPlayerProfile)
signal player_left(profile: SandboxPlayerProfile)
signal roster_changed()

var _by_id: Dictionary = {}        # int player_id -> SandboxPlayerProfile
var _device_to_id: Dictionary = {} # int device_id -> int player_id

## When true, an unclaimed device pressing "join" allocates a player.
var accepting_joins: bool = true


func _ready() -> void:
	instance = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	var mp := MultiplayerInputSystem.instance
	if mp:
		mp.device_disconnected.connect(_on_device_disconnected)


func _process(_delta: float) -> void:
	if not accepting_joins:
		return
	var mp := MultiplayerInputSystem.instance
	if mp == null:
		return
	var device: int = mp.first_device_pressing(&"join")
	if device != -99 and not _device_to_id.has(device):
		join(device)


func join(device: int) -> SandboxPlayerProfile:
	if _device_to_id.has(device):
		return _by_id[_device_to_id[device]]
	var mp := MultiplayerInputSystem.instance
	if mp:
		mp.ensure_device(device)
	var pid := _next_free_id()
	if pid == -1:
		push_warning("PlayerRegistry: roster full, ignoring device %d" % device)
		return null
	var profile := SandboxPlayerProfile.make(pid, device)
	_by_id[pid] = profile
	_device_to_id[device] = pid
	player_joined.emit(profile)
	roster_changed.emit()
	return profile


func leave(player_id: int) -> void:
	if not _by_id.has(player_id):
		return
	var profile: SandboxPlayerProfile = _by_id[player_id]
	_by_id.erase(player_id)
	_device_to_id.erase(profile.device_id)
	player_left.emit(profile)
	roster_changed.emit()


func _on_device_disconnected(device: int) -> void:
	## Deliberately does NOT free the slot. Holding the seat is correct:
	## a yanked USB cable should not delete a player's character.
	if _device_to_id.has(device):
		push_warning("PlayerRegistry: device %d disconnected, holding slot for reconnect" % device)


func _next_free_id() -> int:
	for i in MAX_PLAYERS:
		if not _by_id.has(i):
			return i
	return -1


func count() -> int:
	return _by_id.size()


func profiles() -> Array[SandboxPlayerProfile]:
	var out: Array[SandboxPlayerProfile] = []
	var keys := _by_id.keys()
	keys.sort()
	for k in keys:
		out.append(_by_id[k])
	return out


func get_profile(player_id: int) -> SandboxPlayerProfile:
	return _by_id.get(player_id, null)
