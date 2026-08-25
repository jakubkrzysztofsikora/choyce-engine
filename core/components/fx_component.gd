class_name FXComponent
extends SandboxComponent
## Maps semantic gameplay events to pooled particles and pooled audio.
## Keeps every "spawn a puff of smoke" call out of gameplay code, which is how
## FX code metastasises through a sandbox.
##
## Keys used by the kit: hit, destroyed, placed, removed, picked_up, dropped.

@export var effects: Dictionary = {}          ## StringName -> PackedScene
@export var sounds: Dictionary = {}           ## StringName -> AudioStream
@export var sound_volume_db: float = 0.0
## Local cues are panned per player by AudioRouter; global cues are not.
@export var sounds_are_global: bool = false


func _component_key() -> StringName:
	return Components.FX


func play(key: StringName, at: Vector3 = Vector3.ZERO, normal: Vector3 = Vector3.UP) -> void:
	var pos := at
	if pos == Vector3.ZERO and entity is Node3D:
		pos = (entity as Node3D).global_position

	if effects.has(key):
		var pool := FXPool.instance
		if pool:
			pool.spawn(effects[key], pos, normal)

	if sounds.has(key):
		var router := AudioRouter.instance
		if router:
			if sounds_are_global:
				router.play_global(sounds[key], sound_volume_db)
			else:
				router.play_at(sounds[key], pos, sound_volume_db)
