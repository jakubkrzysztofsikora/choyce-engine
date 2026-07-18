## Domain entity: tracks the player's training progression.
## Part of the Nutrition sandbox loop for VS-025.
##
## Design notes:
## - Framework-agnostic (extends RefCounted, not Node)
## - Bounded progression (max level 3 as per research)
## - Gradual, optional, reversible
## - Focus on skills/abilities, NOT body appearance
class_name TrainingStats
extends RefCounted


## Maximum level for each stat (bounded progression)
## Per research: Level 0-3 (Normal -> Confident -> Strong -> Champion)
const MAX_LEVEL: int = 3


## Training types that can be improved
enum TrainingType {
	STRENGTH,    ## Punching bag, weights - makes you stronger
	POSTURE,     ## Pull-up bar, balance - improves posture
	STAMINA,     ## Running track - increases endurance
	AGILITY,     ## Obstacle course - improves reflexes
	FLEXIBILITY  ## Stretching - improves flexibility
}


# Current level for each training type (0-MAX_LEVEL)
var strength_level: int = 0
var posture_level: int = 0
var stamina_level: int = 0
var agility_level: int = 0
var flexibility_level: int = 0

# Progress towards next level (0.0-1.0) for each type
var strength_progress: float = 0.0
var posture_progress: float = 0.0
var stamina_progress: float = 0.0
var agility_progress: float = 0.0
var flexibility_progress: float = 0.0

# Total training points (can be used for overall progression)
var total_training_points: int = 0

# Last training equipment used (for HUD/caption display)
var last_training_type: TrainingType
var last_training_name: String = ""


## Constructor
func _init() -> void:
	strength_level = 0
	posture_level = 0
	stamina_level = 0
	agility_level = 0
	flexibility_level = 0
	strength_progress = 0.0
	posture_progress = 0.0
	stamina_progress = 0.0
	agility_progress = 0.0
	flexibility_progress = 0.0
	total_training_points = 0


## Add progress for a training type
## Returns true if level increased
func add_progress(training_type: TrainingType, amount: float) -> bool:
	var level_increased: bool = false
	
	match training_type:
		TrainingType.STRENGTH:
			strength_progress += amount
			if strength_progress >= 1.0 and strength_level < MAX_LEVEL:
				strength_level += 1
				strength_progress = 0.0
				level_increased = true
			elif strength_progress >= 1.0:
				strength_progress = 1.0  ## Cap at max level
		TrainingType.POSTURE:
			posture_progress += amount
			if posture_progress >= 1.0 and posture_level < MAX_LEVEL:
				posture_level += 1
				posture_progress = 0.0
				level_increased = true
			elif posture_progress >= 1.0:
				posture_progress = 1.0
		TrainingType.STAMINA:
			stamina_progress += amount
			if stamina_progress >= 1.0 and stamina_level < MAX_LEVEL:
				stamina_level += 1
				stamina_progress = 0.0
				level_increased = true
			elif stamina_progress >= 1.0:
				stamina_progress = 1.0
		TrainingType.AGILITY:
			agility_progress += amount
			if agility_progress >= 1.0 and agility_level < MAX_LEVEL:
				agility_level += 1
				agility_progress = 0.0
				level_increased = true
			elif agility_progress >= 1.0:
				agility_progress = 1.0
		TrainingType.FLEXIBILITY:
			flexibility_progress += amount
			if flexibility_progress >= 1.0 and flexibility_level < MAX_LEVEL:
				flexibility_level += 1
				flexibility_progress = 0.0
				level_increased = true
			elif flexibility_progress >= 1.0:
				flexibility_progress = 1.0

	## Track total points for overall progression
	if level_increased:
		total_training_points += 1

	return level_increased


## Get level for a training type
func get_level(training_type: TrainingType) -> int:
	match training_type:
		TrainingType.STRENGTH:
			return strength_level
		TrainingType.POSTURE:
			return posture_level
		TrainingType.STAMINA:
			return stamina_level
		TrainingType.AGILITY:
			return agility_level
		TrainingType.FLEXIBILITY:
			return flexibility_level
		_:
			return 0


## Get progress for a training type (0.0-1.0)
func get_progress(training_type: TrainingType) -> float:
	match training_type:
		TrainingType.STRENGTH:
			return strength_progress
		TrainingType.POSTURE:
			return posture_progress
		TrainingType.STAMINA:
			return stamina_progress
		TrainingType.AGILITY:
			return agility_progress
		TrainingType.FLEXIBILITY:
			return flexibility_progress
		_:
			return 0.0


## Get the overall training level (average of all levels)
func get_overall_level() -> float:
	var total: int = strength_level + posture_level + stamina_level + agility_level + flexibility_level
	return float(total) / float(MAX_LEVEL * 5) * MAX_LEVEL


## Get total progression percentage (0-100)
func get_total_progress_percent() -> float:
	var total_levels: float = float(strength_level + posture_level + stamina_level + agility_level + flexibility_level)
	var max_possible: float = float(MAX_LEVEL * 5)
	return (total_levels / max_possible) * 100.0


## Get a visual state name for a level
## Returns child-friendly names like "Confident Stance", "Strong Arms", etc.
func get_visual_state_name(training_type: TrainingType, level: int) -> String:
	var states: Array[String] = [
		"Normal",           ## Level 0
		"Improving",        ## Level 1
		"Skilled",          ## Level 2
		"Champion"          ## Level 3
	]
	if level >= 0 and level < states.size():
		return states[level]
	return "Normal"


## Get all levels as a dictionary
func get_all_levels() -> Dictionary:
	return {
		"strength": strength_level,
		"posture": posture_level,
		"stamina": stamina_level,
		"agility": agility_level,
		"flexibility": flexibility_level
	}


## Get all progresses as a dictionary
func get_all_progresses() -> Dictionary:
	return {
		"strength": strength_progress,
		"posture": posture_progress,
		"stamina": stamina_progress,
		"agility": agility_progress,
		"flexibility": flexibility_progress
	}


## Reset all training stats
func reset() -> void:
	strength_level = 0
	posture_level = 0
	stamina_level = 0
	agility_level = 0
	flexibility_level = 0
	strength_progress = 0.0
	posture_progress = 0.0
	stamina_progress = 0.0
	agility_progress = 0.0
	flexibility_progress = 0.0
	total_training_points = 0


## Create a snapshot for save/load
func to_dict() -> Dictionary:
	return {
		"strength_level": strength_level,
		"posture_level": posture_level,
		"stamina_level": stamina_level,
		"agility_level": agility_level,
		"flexibility_level": flexibility_level,
		"strength_progress": strength_progress,
		"posture_progress": posture_progress,
		"stamina_progress": stamina_progress,
		"agility_progress": agility_progress,
		"flexibility_progress": flexibility_progress,
		"total_training_points": total_training_points
	}


## Load from a snapshot
func from_dict(data: Dictionary) -> void:
	if data.has("strength_level"):
		strength_level = int(data["strength_level"])
	if data.has("posture_level"):
		posture_level = int(data["posture_level"])
	if data.has("stamina_level"):
		stamina_level = int(data["stamina_level"])
	if data.has("agility_level"):
		agility_level = int(data["agility_level"])
	if data.has("flexibility_level"):
		flexibility_level = int(data["flexibility_level"])
	if data.has("strength_progress"):
		strength_progress = float(data["strength_progress"])
	if data.has("posture_progress"):
		posture_progress = float(data["posture_progress"])
	if data.has("stamina_progress"):
		stamina_progress = float(data["stamina_progress"])
	if data.has("agility_progress"):
		agility_progress = float(data["agility_progress"])
	if data.has("flexibility_progress"):
		flexibility_progress = float(data["flexibility_progress"])
	if data.has("total_training_points"):
		total_training_points = int(data["total_training_points"])
