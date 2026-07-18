## Training.gd - Domain model for training and body progression
##
## Part of VS-025: Add child-safe nutrition, training, and visible body-progression sandbox loop
##
## Tracks training progress and body progression state.
## All progression is gradual, optional, reversible, and child-safe.
## NO calorie restriction, shame, or body-size scoring.
##

class_name Training
extends RefCounted


# Training types - child-friendly activities
const TRAINING_TYPES := ["jump", "run", "climb", "push", "pull", "balance"]

# Training equipment names (Polish)
const EQUIPMENT_NAMES := {
	"jump": "Skok",
	"run": "Bieg",
	"climb": "Wspinaczka",
	"push": "Pchanie",
	"pull": "Ciągnięcie",
	"balance": "Równowaga"
}

# Body progression levels (0-5, where 0 = base, 5 = strongest)
# Each level represents a visual change, NOT a numerical score
const MAX_BODY_LEVEL := 5
const MIN_BODY_LEVEL := 0

# Current training state
var training_sessions: Dictionary = {}  # training_type -> count
var body_level: int = 0


## Perform training of a specific type
## Returns true if training was successful, false if invalid type
func perform_training(training_type: String) -> bool:
	if not TRAINING_TYPES.has(training_type):
		return false
	
	# Increment training session count
	training_sessions[training_type] = int(training_sessions.get(training_type, 0)) + 1
	
	# Check if we can progress body level
	var total_sessions := 0
	for count in training_sessions.values():
		total_sessions += int(count)
	
	# Progress body level every 5 training sessions (gradual)
	var new_body_level: int = min(int(total_sessions / 5), MAX_BODY_LEVEL)
	
	if new_body_level > body_level:
		body_level = new_body_level
		return true  # Level up!
	
	return true  # Training counted but no level up yet


## Reverse training (optional - allows kid to reset)
## Returns the previous body level
func reverse_training() -> int:
	if body_level > MIN_BODY_LEVEL:
		body_level -= 1
		# Reduce training sessions by 5 to maintain ratio
		var total_to_remove := 5
		for training_type in TRAINING_TYPES:
			if total_to_remove <= 0:
				break
			var current := int(training_sessions.get(training_type, 0))
			if current > 0:
				var remove_count: int = min(current, total_to_remove)
				training_sessions[training_type] = current - remove_count
				total_to_remove -= remove_count
				if training_sessions[training_type] <= 0:
					training_sessions.erase(training_type)
		return body_level + 1
	return body_level


## Get body level (0-5)
func get_body_level() -> int:
	return body_level


## Get body level as percentage (0-100%)
func get_body_level_percent() -> float:
	return float(body_level) / float(MAX_BODY_LEVEL) * 100.0


## Check if at max body level
func is_at_max() -> bool:
	return body_level >= MAX_BODY_LEVEL


## Get training summary
func to_dict() -> Dictionary:
	return {
		"body_level": body_level,
		"training_sessions": training_sessions.duplicate(true)
	}


## Create from dictionary
static func from_dict(data: Dictionary) -> Training:
	var training := Training.new()
	if data.has("body_level"):
		training.body_level = int(data["body_level"])
	if data.has("training_sessions"):
		training.training_sessions = data["training_sessions"].duplicate(true)
	return training


## Get total training sessions
func total_sessions() -> int:
	var total := 0
	for count in training_sessions.values():
		total += int(count)
	return total


## Get training type display name
func get_training_name(training_type: String) -> String:
	return EQUIPMENT_NAMES.get(training_type, training_type)
