## Adapter: Represents a training equipment object in the world.
## Part of the Nutrition sandbox loop for VS-025.
##
## Design notes:
## - Extends Area3D for proximity detection
## - Handles player interaction
## - Connects to TrainingStats for progression
class_name TrainingEquipment
extends Area3D


## Signals
signal training_started(equipment: TrainingEquipment, player: CharacterBody3D)
signal training_completed(equipment: TrainingEquipment, progress_gained: float)
signal training_cancelled(equipment: TrainingEquipment)
signal training_progress_updated(equipment: TrainingEquipment, progress: float)
signal caption_requested(text: String)
signal voice_requested(voice_id: String, text: String)


# Equipment name for display
@export var equipment_name: String = "Training Equipment"

# Type of training this equipment provides
@export var training_type: TrainingStats.TrainingType = TrainingStats.TrainingType.STRENGTH

# How long training takes (in seconds)
@export var training_duration: float = 5.0

# Progress towards completion (0.0-1.0)
@export var progress_per_completion: float = 0.25

# Maximum level for this equipment type (capped by TrainingStats.MAX_LEVEL)
@export var max_level: int = 3

# Whether to play an animation during training
@export var use_animation: bool = true

# Name of the animation to play
@export var animation_name: String = "train"

# Text to show when player is near the equipment
@export var interaction_text: String = "Press E to train"

# Whether to use voice feedback
@export var use_voice: bool = true

# Whether to use captions
@export var use_captions: bool = true


# Internal state
var _in_use: bool = false
var _current_progress: float = 0.0
var _timer: float = 0.0
var _training_player: CharacterBody3D = null

# Reference to the TrainingStats (injected)
var _training_stats: TrainingStats = null

# Original material for visual feedback
var _original_material: Material = null
var _highlight_material: Material = null


## Called when the node enters the scene tree for the first time
func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	## Setup visual feedback
	_on_setup_visual_feedback()


## Setup visual feedback materials
func _on_setup_visual_feedback() -> void:
	if get_child_count() > 0:
		var mesh := get_child(0) as MeshInstance3D
		if mesh != null and mesh.material_override != null:
			_original_material = mesh.material_override.duplicate()
			_highlight_material = mesh.material_override.duplicate()
			## Make it glow when highlighted
			if _highlight_material is ShaderMaterial:
				_highlight_material.set_shader_param("emission_enabled", true)
				_highlight_material.set_shader_param("emission_color", Color.YELLOW)
				_highlight_material.set_shader_param("emission_strength", 0.5)


## Handle body entered the area
func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		_highlight_equipment(true)


## Handle body exited the area
func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		_highlight_equipment(false)
		if _in_use and _training_player == body:
			cancel_training()


## Highlight the equipment visually
func _highlight_equipment(highlight: bool) -> void:
	if get_child_count() > 0 and _original_material != null and _highlight_material != null:
		var mesh := get_child(0) as MeshInstance3D
		if mesh != null:
			mesh.material_override = _highlight_material if highlight else _original_material


## Try to start training with a player
func try_start_training(player: CharacterBody3D) -> bool:
	if _in_use:
		return false
	
	if _training_stats == null:
		var manager := get_node_or_null("/root/Main/World/GameplayRuntime/TrainingManager") as TrainingManager
		if manager != null:
			_training_stats = manager.get_training_stats_entity()
		else:
			push_error("TrainingEquipment: No TrainingManager found in scene!")
			return false

	_training_player = player
	_in_use = true
	_current_progress = 0.0
	_timer = 0.0

	training_started.emit(self, player)

	if use_animation and player.has_node("AnimationPlayer"):
		var anim_player: AnimationPlayer = player.get_node("AnimationPlayer")
		anim_player.play(animation_name)

	## Show starting caption
	if use_captions:
		caption_requested.emit("Training with %s..." % [equipment_name])

	if use_voice:
		voice_requested.emit("child_voice", "Training!")

	return true


## Cancel training
func cancel_training() -> void:
	if not _in_use:
		return

	_in_use = false
	_training_player = null

	if use_animation and _training_player != null and _training_player.has_node("AnimationPlayer"):
		var anim_player: AnimationPlayer = _training_player.get_node("AnimationPlayer")
		anim_player.stop()

	training_cancelled.emit(self)
	
	## Show cancelled caption
	if use_captions:
		caption_requested.emit("Training cancelled.")


## Process training progress
func _process(delta: float) -> void:
	if not _in_use:
		return

	_timer += delta
	_current_progress = _timer / training_duration

	training_progress_updated.emit(self, _current_progress)

	if _timer >= training_duration:
		_complete_training()


## Complete training
func _complete_training() -> void:
	if not _in_use or _training_stats == null:
		return

	_in_use = false

	## Calculate progress based on training type
	var progress_gained: float = progress_per_completion

	## Apply training to stats
	var level_up: bool = _training_stats.add_progress(training_type, progress_gained)

	training_completed.emit(self, progress_gained)

	## Show completion feedback
	var current_level: int = _training_stats.get_level(training_type)
	var level_name: String = _training_stats.get_visual_state_name(training_type, current_level)

	if use_captions:
		var message: String = "Training complete! %s: Level %d" % [equipment_name, current_level + 1]
		if level_up:
			message += " - Level Up! %s" % [level_name]
		caption_requested.emit(message)

	if use_voice:
		voice_requested.emit("child_voice", "I'm getting stronger!")

	## Stop animation
	if _training_player != null and _training_player.has_node("AnimationPlayer"):
		var anim_player: AnimationPlayer = _training_player.get_node("AnimationPlayer")
		anim_player.stop()

	_training_player = null


## Set the TrainingStats reference (dependency injection)
func set_training_stats(stats: TrainingStats) -> void:
	_training_stats = stats


## Get the current progress (0.0-1.0)
func get_current_progress() -> float:
	return _current_progress


## Get whether training is in progress
func is_in_use() -> bool:
	return _in_use


## Get the training type
func get_training_type() -> TrainingStats.TrainingType:
	return training_type


## Get the equipment name
func get_equipment_name() -> String:
	return equipment_name


## Get the interaction text
func get_interaction_text() -> String:
	return interaction_text


## Reset the equipment state
func reset() -> void:
	_in_use = false
	_current_progress = 0.0
	_timer = 0.0
	_training_player = null
	_highlight_equipment(false)
