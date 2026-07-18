## Facial features must follow an animated humanoid head bone, never remain
## parented to the model root like a detached mask.
extends SceneTree

const CHARACTER := preload("res://data/models/kenney/toon_characters/Models/GLB format/character-male-a.glb")
const FacialPerformanceScript = preload("res://src/adapters/inbound/gameplay/facial_performance.gd")

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
	var character := CHARACTER.instantiate() as Node3D
	get_root().add_child(character)
	var face := FacialPerformanceScript.attach_kenney_humanoid(character)
	var skeleton := character.find_child("Skeleton3D", true, false) as Skeleton3D
	var anchor := face.get_parent() as BoneAttachment3D
	_assert(skeleton != null and skeleton.find_bone("head") >= 0, "Kenney character exposes an animated head bone")
	_assert(anchor != null and anchor.get_parent() == skeleton, "face is parented through BoneAttachment3D, not the model root")
	_assert(anchor != null and anchor.bone_name == "head", "face anchor follows the head bone")
	_assert(face.position.y > 0.1 and face.position.y < 0.25, "face uses the head-local offset rather than a world-body offset")
	await process_frame
	var before := face.global_position
	var head_index := skeleton.find_bone("head") if skeleton != null else -1
	var animation_player := character.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if animation_player != null:
		animation_player.active = false
	if skeleton != null and head_index >= 0:
		var moved_head := skeleton.get_bone_global_pose(head_index).translated(Vector3(0.0, 0.24, 0.0))
		skeleton.set_bone_global_pose_override(head_index, moved_head, 1.0, true)
		skeleton.force_update_all_bone_transforms()
	await process_frame
	_assert(face.global_position.y > before.y + 0.15,
		"face moves with an animated head-bone pose rather than remaining in world space")
	character.queue_free()
	quit(_exit_code)
