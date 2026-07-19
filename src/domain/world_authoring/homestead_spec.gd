## Domain value object representing a generated homestead compound specification:
## house model path, vehicle model path, animal set, owner NPC ID, and 3D transform.
class_name HomesteadSpec
extends RefCounted

var homestead_id: String
var owner_npc_id: String
var house_model_path: String
var vehicle_model_path: String
var animal_types: Array[String] = []
var position: Vector3
var rotation_y: float
var footprint_radius: float = 6.0


func _init(
	p_homestead_id: String = "",
	p_owner_npc_id: String = "",
	p_house_path: String = "",
	p_vehicle_path: String = "",
	p_animal_types: Array[String] = [],
	p_position: Vector3 = Vector3.ZERO,
	p_rotation_y: float = 0.0,
	p_footprint_radius: float = 6.0
) -> void:
	homestead_id = p_homestead_id
	owner_npc_id = p_owner_npc_id
	house_model_path = p_house_path
	vehicle_model_path = p_vehicle_path
	animal_types = p_animal_types
	position = p_position
	rotation_y = p_rotation_y
	footprint_radius = p_footprint_radius


func to_dict() -> Dictionary:
	return {
		"homestead_id": homestead_id,
		"owner_npc_id": owner_npc_id,
		"house_model_path": house_model_path,
		"vehicle_model_path": vehicle_model_path,
		"animal_types": animal_types,
		"position": [position.x, position.y, position.z],
		"rotation_y": rotation_y,
		"footprint_radius": footprint_radius
	}


static func from_dict(d: Dictionary) -> HomesteadSpec:
	if not d.has("homestead_id"):
		return null

	var pos_arr: Array = d.get("position", [0.0, 0.0, 0.0])
	var pos := Vector3.ZERO
	if pos_arr.size() >= 3:
		pos = Vector3(float(pos_arr[0]), float(pos_arr[1]), float(pos_arr[2]))

	var anim_arr: Array[String] = []
	for a in d.get("animal_types", []):
		anim_arr.append(str(a))

	var script := load("res://src/domain/world_authoring/homestead_spec.gd") as GDScript
	return script.new(
		str(d.get("homestead_id", "")),
		str(d.get("owner_npc_id", "")),
		str(d.get("house_model_path", "")),
		str(d.get("vehicle_model_path", "")),
		anim_arr,
		pos,
		float(d.get("rotation_y", 0.0)),
		float(d.get("footprint_radius", 6.0))
	) as HomesteadSpec
