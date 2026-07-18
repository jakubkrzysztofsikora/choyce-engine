## VS-032 gate: UAL is a source library, not a drop-in replacement for the
## current simplified child rig. This test makes that constraint explicit until
## a licensed retargetable visual rig and BoneMap are introduced.
extends SceneTree

const UAL := preload("res://data/models/quaternius/animations/UAL1_Standard.glb")
const PLAYER := preload("res://data/models/kenney/toon_characters/Models/GLB format/character-male-a.glb")

var _exit_code := 0


func _init() -> void:
	call_deferred("_run_tests")


func _assert(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		print("FAIL: %s" % message)
		_exit_code = 1


func _run_tests() -> void:
	print("=== VS-032: Universal Animation Library compatibility gate ===")
	var ual_root := UAL.instantiate()
	var player_root := PLAYER.instantiate()
	var ual_skeleton := _first_skeleton(ual_root)
	var player_skeleton := _first_skeleton(player_root)
	_assert(ual_skeleton != null and player_skeleton != null, "both source and target rigs contain Skeleton3D")
	_assert(_has_clip(ual_root, "Walk") and _has_clip(ual_root, "Punch_Jab"),
		"UAL contains locomotion and physical-melee source clips")
	_assert(not _same_bone_layout(ual_skeleton, player_skeleton),
		"current child rig is not directly compatible; an explicit retarget profile is required")
	_assert(_source_does_not_assign_ual_directly("res://src/adapters/inbound/gameplay/player_controller.gd"),
		"player controller does not directly assign incompatible UAL clips")
	_assert(_source_does_not_assign_ual_directly("res://src/adapters/inbound/scenes/launcher/launcher_overlay.gd"),
		"launcher does not directly assign incompatible UAL clips")
	ual_root.queue_free()
	player_root.queue_free()
	quit(_exit_code)


func _first_skeleton(root: Node) -> Skeleton3D:
	var skeletons := root.find_children("*", "Skeleton3D", true, false)
	return skeletons[0] as Skeleton3D if not skeletons.is_empty() else null


func _has_clip(root: Node, clip_name: String) -> bool:
	for node in root.find_children("*", "AnimationPlayer", true, false):
		if (node as AnimationPlayer).has_animation(clip_name):
			return true
	return false


func _same_bone_layout(source: Skeleton3D, target: Skeleton3D) -> bool:
	if source == null or target == null or source.get_bone_count() != target.get_bone_count():
		return false
	for index in source.get_bone_count():
		if source.get_bone_name(index) != target.get_bone_name(index):
			return false
	return true


func _source_does_not_assign_ual_directly(path: String) -> bool:
	var source := FileAccess.get_file_as_string(path)
	return not source.contains("UAL1_Standard")
