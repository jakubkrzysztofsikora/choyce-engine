## Adapter: Manages the player's training progression in the gameplay runtime.
## Part of the Nutrition sandbox loop for VS-025.
##
## Design notes:
## - Connects domain TrainingStats with the gameplay runtime
## - Handles training equipment interaction, progression, visual updates
## - Emits signals for UI/feedback systems
class_name TrainingManager
extends Node


## Signals for UI/feedback
signal training_started(training_type: TrainingStats.TrainingType)
signal training_completed(training_type: TrainingStats.TrainingType, level_up: bool, new_level: int)
signal training_level_up(training_type: TrainingStats.TrainingType, new_level: int)
signal body_progression_updated(level: int, state_name: String)
signal caption_requested(text: String)
signal voice_requested(voice_id: String, text: String)


# Reference to the domain TrainingStats
var _training_stats: TrainingStats

# Reference to the player's character mesh for visual progression
@export var player_mesh: MeshInstance3D = null

# Whether to use voice feedback
@export var use_voice: bool = true

# Whether to use captions
@export var use_captions: bool = true

# Default voice ID for training voice feedback
@export var default_voice_id: String = "child_voice_english"

# Child-friendly level names
@export var level_names: Array[String] = ["Beginner", "Improving", "Skilled", "Champion"]


## Called when the node enters the scene tree for the first time
func _ready() -> void:
	if _training_stats == null:
		_training_stats = TrainingStats.new()


## Handle training completed from equipment
func on_training_completed(equipment: TrainingEquipment, progress_gained: float) -> void:
	if _training_stats == null:
		return

	var training_type: TrainingStats.TrainingType = equipment.get_training_type()
	var old_level: int = _training_stats.get_level(training_type)
	
	## Check if level increased
	var level_up: bool = false
	var new_level: int = old_level
	
	## Manually check for level up (since add_progress was already called by equipment)
	var progress: float = _training_stats.get_progress(training_type)
	if old_level < TrainingStats.MAX_LEVEL and progress >= 1.0:
		new_level = old_level + 1
		level_up = true

	training_completed.emit(training_type, level_up, new_level)

	if level_up:
		training_level_up.emit(training_type, new_level)
		_on_level_up(training_type, new_level)

	## Update body progression visualization
	_update_body_progression()


## Handle level up
func _on_level_up(training_type: TrainingStats.TrainingType, new_level: int) -> void:
	var state_name: String = level_names[new_level - 1] if new_level > 0 and new_level <= level_names.size() else "Improved"
	
	if use_captions:
		var message: String
		match training_type:
			TrainingStats.TrainingType.STRENGTH:
				message = "Strength Level %d: %s!" % [new_level, state_name]
			TrainingStats.TrainingType.POSTURE:
				message = "Posture Level %d: %s!" % [new_level, state_name]
			TrainingStats.TrainingType.STAMINA:
				message = "Stamina Level %d: %s!" % [new_level, state_name]
			TrainingStats.TrainingType.AGILITY:
				message = "Agility Level %d: %s!" % [new_level, state_name]
			TrainingStats.TrainingType.FLEXIBILITY:
				message = "Flexibility Level %d: %s!" % [new_level, state_name]
			_:
				message = "Level Up! %s!" % [state_name]
		caption_requested.emit(message)

	if use_voice:
		voice_requested.emit("child_voice", "I leveled up!")


## Update body progression visualization
func _update_body_progression() -> void:
	if _training_stats == null or player_mesh == null:
		return

	## Calculate overall progression level
	var total_level: float = _training_stats.get_overall_level()
	var level_index: int = floor(total_level)
	
	## Update BlendShapes based on training stats
	## Child-safe visual progression with bounded levels (0-3)
	var strength_level: int = _training_stats.get_level(TrainingStats.TrainingType.STRENGTH)
	var posture_level: int = _training_stats.get_level(TrainingStats.TrainingType.POSTURE)
	var stamina_level: int = _training_stats.get_level(TrainingStats.TrainingType.STAMINA)
	var agility_level: int = _training_stats.get_level(TrainingStats.TrainingType.AGILITY)
	var flexibility_level: int = _training_stats.get_level(TrainingStats.TrainingType.FLEXIBILITY)
	
	## Imported Adventure meshes can have no blend shapes at all.  Query the
	## Godot 4 MeshInstance3D API, where blend-shape lookup and values belong to
	## the instance (not ArrayMesh surfaces), and quietly retain the bounded
	## gameplay stat when a ready-made model cannot express the visual change.
	var strength_weight: float = float(strength_level) / float(TrainingStats.MAX_LEVEL)
	var posture_weight: float = float(posture_level) / float(TrainingStats.MAX_LEVEL)
	_set_named_blend_shape("muscles_defined", strength_weight)
	_set_named_blend_shape("posture_improved", posture_weight)
	_set_named_blend_shape("shoulders_back", posture_weight)
	_set_named_blend_shape("chest_out", strength_weight)
	
	## Emit signal with level and state name
	var state_name: String = level_names[level_index] if level_index >= 0 and level_index < level_names.size() else "Normal"
	body_progression_updated.emit(level_index, state_name)


## Godot 4 exposes blend shapes through MeshInstance3D.  An index of -1 is a
## normal outcome for most downloaded stylised models, so this helper must be
## a safe no-op rather than a startup error.
func _set_named_blend_shape(shape_name: StringName, value: float) -> void:
	if player_mesh == null or player_mesh.mesh == null:
		return
	var shape_index := player_mesh.find_blend_shape_by_name(shape_name)
	if shape_index >= 0:
		player_mesh.set_blend_shape_value(shape_index, clampf(value, 0.0, 1.0))


## Add training progress for a type
func add_training_progress(training_type: TrainingStats.TrainingType, amount: float) -> bool:
	if _training_stats == null:
		return false
	
	var level_up: bool = _training_stats.add_progress(training_type, amount)
	
	if level_up:
		var new_level: int = _training_stats.get_level(training_type)
		training_level_up.emit(training_type, new_level)
		_on_level_up(training_type, new_level)
		_update_body_progression()

	return level_up


## Get training level for a type
func get_training_level(training_type: TrainingStats.TrainingType) -> int:
	if _training_stats == null:
		return 0
	return _training_stats.get_level(training_type)


## Get training progress for a type
func get_training_progress(training_type: TrainingStats.TrainingType) -> float:
	if _training_stats == null:
		return 0.0
	return _training_stats.get_progress(training_type)


## Get overall training level
func get_overall_level() -> float:
	if _training_stats == null:
		return 0.0
	return _training_stats.get_overall_level()


## Get total progression percentage
func get_total_progress_percent() -> float:
	if _training_stats == null:
		return 0.0
	return _training_stats.get_total_progress_percent()


## Get all levels as a dictionary
func get_all_levels() -> Dictionary:
	if _training_stats == null:
		return {}
	return _training_stats.get_all_levels()


## Get all progresses as a dictionary
func get_all_progresses() -> Dictionary:
	if _training_stats == null:
		return {}
	return _training_stats.get_all_progresses()


## Get the current visual state name
func get_visual_state_name() -> String:
	var total_level: float = get_overall_level()
	var level_index: int = floor(total_level)
	return level_names[level_index] if level_index >= 0 and level_index < level_names.size() else "Normal"


## Reset all training stats
func reset() -> void:
	if _training_stats != null:
		_training_stats.reset()
		_update_body_progression()


## Save state to dictionary
func save_to_dict() -> Dictionary:
	if _training_stats == null:
		return {}
	return _training_stats.to_dict()


## Load state from dictionary
func load_from_dict(data: Dictionary) -> void:
	if _training_stats == null:
		_training_stats = TrainingStats.new()
	_training_stats.from_dict(data)
	_update_body_progression()


## Update player mesh reference
func set_player_mesh(mesh: MeshInstance3D) -> void:
	player_mesh = mesh
	_update_body_progression()


func get_training_stats_entity() -> TrainingStats:
	return _training_stats


## Start training of a specific type at a specific anchor point
func start_training(training_type: TrainingStats.TrainingType, anchor: Node3D) -> void:
	if _training_stats == null:
		push_error("TrainingManager: TrainingStats not initialized")
		return
	
	## Add progress for this training type
	var progress_gained := 5.0  # Default progress per training session
	var level_up := _training_stats.add_progress(training_type, progress_gained)
	
	## Emit signals
	training_started.emit(training_type)
	
	## Show feedback
	var level := _training_stats.get_level(training_type)
	var level_name := level_names[level] if level < level_names.size() else "Champion"
	
	if use_captions:
		var message := "Trening %s: Poziom %d!" % [level_name, level + 1]
		caption_requested.emit(message)
	
	if use_voice:
		voice_requested.emit(default_voice_id, "Training complete")
	
	## Update body progression
	_update_body_progression()
	
	## Emit completion signal
	training_completed.emit(training_type, level_up, level)
