class_name GymSpawner3D
extends Node3D

signal training_performed(training_type_name: String, new_progress: float, new_level: int)

const TRAINING_STATS := preload("res://src/domain/gameplay/training_stats.gd")

var _gym_root: Node3D = null
var _gym_position := Vector3(-24.0, 0.0, 12.0)
var _active_stats: TrainingStats = null


func _ready() -> void:
	if _active_stats == null:
		_active_stats = TRAINING_STATS.new()


func setup(stats: TrainingStats = null) -> GymSpawner3D:
	if stats != null:
		_active_stats = stats
	return self


## Spawn the 3D Gym Compound near the player basecamp.
func spawn_gym(center_position: Vector3 = Vector3(-24.0, 0.0, 12.0)) -> Node3D:
	_gym_position = center_position

	if _gym_root != null and is_instance_valid(_gym_root):
		_gym_root.queue_free()

	_gym_root = Node3D.new()
	_gym_root.name = "ChoyceGymCompound"
	_gym_root.position = _gym_position
	add_child(_gym_root)

	# 1. Foundation Rubber Floor & Collision
	_build_foundation(_gym_root)

	# 2. Wooden Frame Pergola & Overhead Lights
	_build_building_structure(_gym_root)

	# 3. Equipment Stations (Strength, Posture, Stamina, Agility, Flexibility)
	_build_equipment_stations(_gym_root)

	print("[GymSpawner3D] Gym compound spawned near player camp at ", _gym_position)
	return _gym_root


func _build_foundation(parent: Node3D) -> void:
	var floor_mesh := MeshInstance3D.new()
	floor_mesh.name = "GymRubberFloor"
	var box_mesh := BoxMesh.new()
	box_mesh.size = Vector3(14.0, 0.2, 10.0)
	floor_mesh.mesh = box_mesh
	floor_mesh.position = Vector3(0, 0.1, 0)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.15, 0.20, 0.26) # Dark sports rubber
	mat.roughness = 0.8
	floor_mesh.material_override = mat
	parent.add_child(floor_mesh)

	# Physical Collision Floor
	var body := StaticBody3D.new()
	body.name = "GymFloorBody"
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(14.0, 0.2, 10.0)
	col.shape = shape
	col.position = Vector3(0, 0.1, 0)
	body.add_child(col)
	parent.add_child(body)


func _build_building_structure(parent: Node3D) -> void:
	# Wooden corner posts
	var post_offsets := [
		Vector3(-6.5, 1.5, -4.5),
		Vector3(6.5, 1.5, -4.5),
		Vector3(-6.5, 1.5, 4.5),
		Vector3(6.5, 1.5, 4.5)
	]
	var wood_mat := StandardMaterial3D.new()
	wood_mat.albedo_color = Color(0.42, 0.26, 0.16)

	for offset in post_offsets:
		var post := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.3, 3.0, 0.3)
		post.mesh = mesh
		post.position = offset
		post.material_override = wood_mat
		parent.add_child(post)

	# Overhead Roof Beams
	var beam := MeshInstance3D.new()
	var beam_mesh := BoxMesh.new()
	beam_mesh.size = Vector3(13.4, 0.2, 0.3)
	beam.mesh = beam_mesh
	beam.position = Vector3(0, 3.0, -4.5)
	beam.material_override = wood_mat
	parent.add_child(beam)

	# Neon Sign Board
	var sign_mesh := MeshInstance3D.new()
	var sign_box := BoxMesh.new()
	sign_box.size = Vector3(5.0, 0.8, 0.15)
	sign_mesh.mesh = sign_box
	sign_mesh.position = Vector3(0, 3.3, -4.5)

	var sign_mat := StandardMaterial3D.new()
	sign_mat.albedo_color = Color(0.10, 0.65, 0.95)
	sign_mat.emission_enabled = true
	sign_mat.emission = Color(0.20, 0.75, 1.0)
	sign_mat.emission_energy_multiplier = 2.0
	sign_mesh.material_override = sign_mat
	parent.add_child(sign_mesh)

	# Overhead Lighting
	var light := OmniLight3D.new()
	light.position = Vector3(0, 2.8, 0)
	light.light_color = Color(0.95, 0.92, 0.85)
	light.light_energy = 2.5
	light.omni_range = 12.0
	parent.add_child(light)


func _build_equipment_stations(parent: Node3D) -> void:
	# 1. STRENGTH: Bench Press & Punching Bag
	_create_equipment_station(parent, Vector3(-4.5, 0.2, -2.5), "STRENGTH", "Worek Bokserski & Sztanga (Siła)", Color(0.85, 0.25, 0.25), "train_push", "E  Wyciskaj sztangę / Uderzaj w worek")

	# 2. POSTURE: Pull-Up Bar Rig
	_create_equipment_station(parent, Vector3(-1.5, 0.2, -2.5), "POSTURE", "Drążek do Podciągania (Postawa)", Color(0.25, 0.75, 0.45), "train_pull", "E  Podciągaj się na drążku")

	# 3. STAMINA: Treadmill Platform
	_create_equipment_station(parent, Vector3(1.5, 0.2, -2.5), "STAMINA", "Bieżnia Treningowa (Kondycja)", Color(0.95, 0.65, 0.15), "train_run", "E  Biegnij na bieżni")

	# 4. AGILITY: Plyometric Jump Box
	_create_equipment_station(parent, Vector3(4.5, 0.2, -2.5), "AGILITY", "Skrzynia Plyometryczna (Zwrotność)", Color(0.65, 0.35, 0.95), "train_jump", "E  Skacz na skrzynię")

	# 5. FLEXIBILITY: Stretching Mat Area
	_create_equipment_station(parent, Vector3(0.0, 0.2, 2.5), "FLEXIBILITY", "Mata do Rozciągania (Rozciągliwość)", Color(0.25, 0.85, 0.85), "train_balance", "E  Rozciągaj się na macie")


func _create_equipment_station(parent: Node3D, pos: Vector3, type_name: String, display_name: String, color: Color, action_id: String, prompt_text: String) -> void:
	var station_root := Node3D.new()
	station_root.name = "Station_" + type_name
	station_root.position = pos
	parent.add_child(station_root)

	# Equipment Visual Mesh
	var mesh_inst := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.6, 1.2, 1.6)
	mesh_inst.mesh = box
	mesh_inst.position = Vector3(0, 0.6, 0)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.4
	mesh_inst.material_override = mat
	station_root.add_child(mesh_inst)

	# Equipment Label Indicator
	var label_3d := Label3D.new()
	label_3d.text = display_name
	label_3d.position = Vector3(0, 1.6, 0)
	label_3d.font_size = 20
	label_3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label_3d.modulate = Color(1.0, 1.0, 1.0)
	station_root.add_child(label_3d)

	# Interactive Area3D Trigger Zone
	var area := Area3D.new()
	area.name = "TrainArea_" + type_name
	area.add_to_group("world_interactable")
	area.set_meta("training_type_name", type_name)
	area.set_meta("action_id", action_id)
	area.set_meta("resource_action", action_id)
	area.set_meta("prompt_text", prompt_text)

	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 2.2
	col.shape = shape
	area.add_child(col)
	station_root.add_child(area)


## Trigger workout execution on the active TrainingStats entity.
func perform_workout(type_name: String) -> Dictionary:
	if _active_stats == null:
		return {"success": false, "reason": "No stats entity"}

	var type_enum := _parse_training_type(type_name)
	var leveled_up: bool = _active_stats.add_progress(type_enum, 0.25)

	var current_progress: float = _get_progress_for_type(type_enum)
	var current_level: int = _get_level_for_type(type_enum)

	training_performed.emit(type_name, current_progress, current_level)

	return {
		"success": true,
		"training_type": type_name,
		"progress": current_progress,
		"level": current_level,
		"leveled_up": leveled_up
	}


func _parse_training_type(type_name: String) -> TRAINING_STATS.TrainingType:
	match type_name.to_upper():
		"STRENGTH": return TRAINING_STATS.TrainingType.STRENGTH
		"POSTURE": return TRAINING_STATS.TrainingType.POSTURE
		"STAMINA": return TRAINING_STATS.TrainingType.STAMINA
		"AGILITY": return TRAINING_STATS.TrainingType.AGILITY
		"FLEXIBILITY": return TRAINING_STATS.TrainingType.FLEXIBILITY
		_: return TRAINING_STATS.TrainingType.STRENGTH


func _get_progress_for_type(t: TRAINING_STATS.TrainingType) -> float:
	match t:
		TRAINING_STATS.TrainingType.STRENGTH: return _active_stats.strength_progress
		TRAINING_STATS.TrainingType.POSTURE: return _active_stats.posture_progress
		TRAINING_STATS.TrainingType.STAMINA: return _active_stats.stamina_progress
		TRAINING_STATS.TrainingType.AGILITY: return _active_stats.agility_progress
		TRAINING_STATS.TrainingType.FLEXIBILITY: return _active_stats.flexibility_progress
		_: return 0.0


func _get_level_for_type(t: TRAINING_STATS.TrainingType) -> int:
	match t:
		TRAINING_STATS.TrainingType.STRENGTH: return _active_stats.strength_level
		TRAINING_STATS.TrainingType.POSTURE: return _active_stats.posture_level
		TRAINING_STATS.TrainingType.STAMINA: return _active_stats.stamina_level
		TRAINING_STATS.TrainingType.AGILITY: return _active_stats.agility_level
		TRAINING_STATS.TrainingType.FLEXIBILITY: return _active_stats.flexibility_level
		_: return 0
