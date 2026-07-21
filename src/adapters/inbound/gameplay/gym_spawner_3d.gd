class_name GymSpawner3D
extends Node3D

signal training_performed(training_type_name: String, new_progress: float, new_level: int)

const TRAINING_STATS := preload("res://src/domain/gameplay/training_stats.gd")
const GYM_GLB_PATH := "res://data/models/gym/gym_environment.glb"

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


## Spawn the 3D Gym Compound using the real game-ready gym environment GLB.
## The GLB contains 57 meshes (boxing rings, dumbbells, kettlebells, bikes,
## bars, punching bags, etc.) — we instantiate the whole pack, then attach
## invisible Area3D interaction triggers to the equipment that maps to each
## training type.
func spawn_gym(center_position: Vector3 = Vector3(-24.0, 0.0, 12.0)) -> Node3D:
	_gym_position = center_position

	if _gym_root != null and is_instance_valid(_gym_root):
		_gym_root.queue_free()

	_gym_root = Node3D.new()
	_gym_root.name = "ChoyceGymCompound"
	_gym_root.position = _gym_position
	add_child(_gym_root)

	# Instantiate the full gym environment GLB. It ships as a single PackedScene
	# with all equipment pre-positioned. Scale to fit the world.
	if not ResourceLoader.exists(GYM_GLB_PATH):
		push_error("[GymSpawner3D] gym_environment.glb not found at %s" % GYM_GLB_PATH)
		return _gym_root
	var gym_packed := load(GYM_GLB_PATH) as PackedScene
	if gym_packed == null:
		push_error("[GymSpawner3D] Failed to load gym_environment.glb as PackedScene")
		return _gym_root
	var gym_scene := gym_packed.instantiate() as Node3D
	if gym_scene == null:
		push_error("[GymSpawner3D] Failed to instantiate gym_environment.glb")
		return _gym_root
	gym_scene.name = "GymEnvironmentPack"
	# The GLB's bbox is ~31m × 15m × 4m. Scale down to fit a ~14m × 8m footprint.
	gym_scene.scale = Vector3(0.45, 0.45, 0.45)
	gym_scene.position = Vector3.ZERO
	_gym_root.add_child(gym_scene)

	# Add a rubber floor + collision under the gym so the player can walk on it.
	_build_foundation(_gym_root)

	# Trimesh collision on every equipment piece. The gym GLB is a visual
	# collection with 57 meshes — none of them have collision by default.
	# Walking through a boxing ring is the kind of detail that breaks the
	# world. create_trimesh_collision() walks the mesh geometry and emits a
	# StaticBody3D + ConcavePolygonShape3D child per mesh.
	_add_trimesh_collision_to_all(gym_scene)

	# Overhead light so the gym reads well at dusk/night.
	var light := OmniLight3D.new()
	light.position = Vector3(0, 4.0, 0)
	light.light_color = Color(0.95, 0.92, 0.85)
	light.light_energy = 2.5
	light.omni_range = 14.0
	_gym_root.add_child(light)

	# Attach interaction triggers to specific equipment meshes by name.
	# Each trigger is an invisible Area3D + Label3D that lets the player
	# walk up and press E to train.
	_attach_station_trigger(gym_scene, "punching_bag", "STRENGTH",
		"Worek Bokserski (Siła)", "train_push", "E  Uderzaj w worek")
	_attach_station_trigger(gym_scene, "pull_up_rack", "POSTURE",
		"Drążek do Podciągania (Postawa)", "train_pull", "E  Podciągaj się")
	_attach_station_trigger(gym_scene, "treadmill", "STAMINA",
		"Bieżnia (Kondycja)", "train_run", "E  Biegnij na bieżni")
	_attach_station_trigger(gym_scene, "step_platform", "AGILITY",
		"Skocznia (Zwrotność)", "train_jump", "E  Skacz na platformę")
	_attach_station_trigger(gym_scene, "yoga_mat", "FLEXIBILITY",
		"Mata do Jogi (Rozciągliwość)", "train_balance", "E  Rozciągaj się")

	print("[GymSpawner3D] Gym compound spawned at ", _gym_position)
	return _gym_root


## Rubber floor + collision slab under the gym.
func _build_foundation(parent: Node3D) -> void:
	var floor_mesh := MeshInstance3D.new()
	floor_mesh.name = "GymRubberFloor"
	var box := BoxMesh.new()
	box.size = Vector3(16.0, 0.2, 10.0)
	floor_mesh.mesh = box
	floor_mesh.position = Vector3(0, 0.1, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.15, 0.20, 0.26)
	mat.roughness = 0.85
	floor_mesh.material_override = mat
	parent.add_child(floor_mesh)

	var body := StaticBody3D.new()
	body.name = "GymFloorBody"
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(16.0, 0.2, 10.0)
	col.shape = shape
	col.position = Vector3(0, 0.1, 0)
	body.add_child(col)
	parent.add_child(body)


## Generate trimesh collision on every MeshInstance3D inside `root`. The gym
## GLB ships 57 visual meshes with no physics shapes; this gives them all
## proper concave collision so the player can't walk through equipment.
## Bounds, metadata and existing children are preserved.
func _add_trimesh_collision_to_all(root: Node) -> void:
	var mesh_count := 0
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = mi.mesh
		if mesh == null:
			continue
		mi.create_trimesh_collision()
		mesh_count += 1
	print("[GymSpawner3D] Generated trimesh collision for %d equipment meshes" % mesh_count)


## Find the first mesh whose name contains `equipment_name_fragment` inside
## the gym scene, then attach an invisible interaction trigger + label to it.
func _attach_station_trigger(gym_scene: Node3D, equipment_name: String,
		type_name: String, display_name: String, action_id: String,
		prompt_text: String) -> void:
	# Search for a mesh whose name contains the equipment fragment.
	var target: Node3D = null
	for child in gym_scene.find_children("*", "MeshInstance3D", true, false):
		var mesh_name := String(child.name).to_lower()
		if mesh_name.contains(equipment_name.to_lower()):
			target = child as Node3D
			break
	if target == null:
		push_warning("[GymSpawner3D] Equipment '%s' not found in gym GLB" % equipment_name)
		return

	# Label above the equipment.
	var label := Label3D.new()
	label.text = display_name
	label.position = Vector3(0, 1.8, 0)
	label.font_size = 20
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color(1.0, 1.0, 1.0)
	label.outline_modulate = Color(0, 0, 0, 0.85)
	label.outline_size = 4
	target.add_child(label)

	# Invisible interaction zone around the equipment.
	var area := Area3D.new()
	area.name = "TrainArea_" + type_name
	area.add_to_group("world_interactable")
	area.set_meta("training_type_name", type_name)
	area.set_meta("action_id", action_id)
	area.set_meta("resource_action", action_id)
	area.set_meta("prompt_text", prompt_text)
	# GameplayRuntime._activate_world_interaction dispatches on these two keys —
	# without them pressing E at a station silently did nothing.
	area.set_meta("interaction_action", action_id)
	area.set_meta("interaction_prompt", prompt_text)
	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 2.0
	col.shape = shape
	area.add_child(col)
	target.add_child(area)


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
