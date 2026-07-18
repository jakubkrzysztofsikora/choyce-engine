## DestructionTracker.gd - Tracks destroyed objects for restoration
##
## Part of VS-021: Add rare drivable vehicles and bounded bulldozer destruction sandbox
##
## Handles:
## - Tracking all destroyed objects with metadata
## - Restoration logic with limits
## - Restore UI integration
##
class_name DestructionTracker
extends Node


signal object_destroyed(object: Node3D, info: Dictionary)
signal object_restored(object: Node3D, info: Dictionary)
signal restore_count_changed(count: int, max: int)


# Maximum number of restorations
const MAX_RESTORE_COUNT := 10

# Tracked destructions (stack - most recent last)
var destroyed_objects: Array[Dictionary] = []

# Current restore count
var restore_count: int = 0

# Reference to world renderer for recreating objects
var world_renderer: Node = null
var runtime_root: Node = null


func _ready() -> void:
	if runtime_root == null:
		runtime_root = get_parent()
	if world_renderer == null and runtime_root != null:
		world_renderer = runtime_root.get_node_or_null("WorldRenderer")


func configure(runtime: Node, renderer: Node) -> void:
	runtime_root = runtime
	world_renderer = renderer


func track_destruction(object: Node3D, restore_info: Dictionary) -> void:
	# Store destruction info
	var entry := {
		"timestamp": Time.get_ticks_msec(),
		"info": restore_info,
		"original_position": object.global_position,
		"object_name": object.name,
		"object_type": object.get_class()
	}

	destroyed_objects.append(entry)

	# Clamp to reasonable limit
	if destroyed_objects.size() > MAX_RESTORE_COUNT * 2:
		destroyed_objects.remove_at(0)

	emit_signal("object_destroyed", object, restore_info)


func restore_last() -> bool:
	if destroyed_objects.is_empty():
		return false

	if restore_count >= MAX_RESTORE_COUNT:
		return false

	var last: Dictionary = destroyed_objects.pop_back()
	var info: Dictionary = last.get("info", {})

	# Recreate the object
	var original_position: Vector3 = _vector3_value(last.get("original_position", Vector3.ZERO), Vector3.ZERO)
	var restored: Node3D = _restore_object(info, original_position)

	if restored != null:
		restore_count += 1
		emit_signal("object_restored", restored, info)
		emit_signal("restore_count_changed", restore_count, MAX_RESTORE_COUNT)
		return true

	return false


func restore_all() -> int:
	var count := 0

	while not destroyed_objects.is_empty() and restore_count < MAX_RESTORE_COUNT:
		if restore_last():
			count += 1
		else:
			break

	return count


func clear_all() -> void:
	destroyed_objects.clear()
	restore_count = 0
	emit_signal("restore_count_changed", restore_count, MAX_RESTORE_COUNT)


func _restore_object(info: Dictionary, position: Vector3) -> Node3D:
	# Try to recreate the object based on stored info

	var prop_name: String = String(info.get("prop_name", ""))
	var original_position: Vector3 = _vector3_value(info.get("original_position", position), position)
	var rotation: Vector3 = _vector3_value(info.get("rotation", Vector3.ZERO), Vector3.ZERO)
	var scale: Vector3 = _vector3_value(info.get("scale", Vector3.ONE), Vector3.ONE)

	# Try to find a recreate method in world_renderer
	if world_renderer != null and world_renderer.has_method("_add_visual_asset"):
		var restored_variant: Variant = world_renderer.call(
			"_add_visual_asset", prop_name, original_position, scale, rotation.y)
		if restored_variant is Node3D:
			var restored: Node3D = restored_variant
			restored.rotation = rotation
			# Restore metadata
			if info.has("destruction_category"):
				restored.set_meta("destruction_category", info["destruction_category"])
			if info.has("original_position"):
				restored.set_meta("original_position", info["original_position"])
			if info.has("prop_name"):
				restored.set_meta("prop_name", info["prop_name"])

			return restored

	# Fallback: create a simple placeholder
	push_warning("DestructionTracker: Could not restore object with prop_name: %s" % prop_name)

	var placeholder := MeshInstance3D.new()
	placeholder.name = "restored_%s" % prop_name
	placeholder.global_position = original_position
	placeholder.rotation = rotation
	placeholder.scale = scale

	if get_parent() != null:
		get_parent().add_child(placeholder)
	else:
		get_tree().current_scene.add_child(placeholder)

	return placeholder


func _vector3_value(value: Variant, fallback: Vector3) -> Vector3:
	if value is Vector3:
		return value
	if value is Array and (value as Array).size() >= 3:
		var values: Array = value
		return Vector3(float(values[0]), float(values[1]), float(values[2]))
	return fallback


func get_destroyed_count() -> int:
	return destroyed_objects.size()


func get_restore_count() -> int:
	return restore_count


func can_restore() -> bool:
	return not destroyed_objects.is_empty() and restore_count < MAX_RESTORE_COUNT
