## BodyProgression.gd - Domain model for visual body progression
##
## Part of VS-025: Add child-safe nutrition, training, and visible body-progression sandbox loop
##
## Handles visual representation of body changes based on training progress.
## All changes are bounded, optional, reversible, and child-safe.
## NO body-shaming, NO size scoring, only positive visual feedback.
##

class_name BodyProgression
extends RefCounted


# Body progression levels (0-5, where 0 = base, 5 = strongest)
# Each level represents a visual posture/appearance change
const MAX_BODY_LEVEL := 5
const MIN_BODY_LEVEL := 0

# Visual progression names (Polish) - positive, child-friendly
const BODY_LEVEL_NAMES := {
	0: "Podstawowy",      # Base/Normal
	1: "Aktywny",       # Active
	2: "Zdrowy",        # Healthy
	3: "Silny",         # Strong
	4: "Wytrawny",      # Skilled/Well-trained
	5: "Mistrzowski"    # Master/Champion
}

# Visual scale multipliers for each body level
# These affect the character's visual appearance (posture, muscle definition)
# NOT weight or size - only positive athletic progression
const BODY_SCALE_MULTIPLIERS := {
	0: Vector3(1.0, 1.0, 1.0),     # Base
	1: Vector3(1.0, 1.01, 1.0),    # Slightly more upright
	2: Vector3(1.01, 1.02, 1.0),  # Better posture, slightly broader
	3: Vector3(1.02, 1.03, 1.01), # Confident stance
	4: Vector3(1.03, 1.04, 1.02), # Athletic build
	5: Vector3(1.04, 1.05, 1.03)  # Peak athletic form
}

# Emission/intensity multipliers for visual "glow" effect at higher levels
const BODY_GLOW_INTENSITY := {
	0: 0.0,
	1: 0.0,
	2: 0.0,
	3: 0.1,
	4: 0.15,
	5: 0.2
}

# Current body level (0-5)
var current_level: int = 0

# Timestamp of last visual update (for animation effects)
var last_update_time: float = 0.0


## Initialize with a body level
func _init(body_level: int = 0) -> void:
	set_body_level(body_level)


## Set body level (clamped to valid range)
func set_body_level(level: int) -> void:
	current_level = clampi(level, MIN_BODY_LEVEL, MAX_BODY_LEVEL)
	last_update_time = Time.get_ticks_msec() / 1000.0


## Get current body level
func get_body_level() -> int:
	return current_level


## Get body level name (Polish)
func get_body_level_name() -> String:
	return BODY_LEVEL_NAMES.get(current_level, "Podstawowy")


## Get scale multiplier for current body level
func get_scale_multiplier() -> Vector3:
	return BODY_SCALE_MULTIPLIERS.get(current_level, Vector3(1.0, 1.0, 1.0))


## Get glow intensity for current body level
func get_glow_intensity() -> float:
	return BODY_GLOW_INTENSITY.get(current_level, 0.0)


## Get body level as percentage (0-100%)
func get_level_percent() -> float:
	return float(current_level) / float(MAX_BODY_LEVEL) * 100.0


## Progress to next body level (if not at max)
## Returns true if level increased, false if already at max
func progress_level() -> bool:
	if current_level < MAX_BODY_LEVEL:
		current_level += 1
		last_update_time = Time.get_ticks_msec() / 1000.0
		return true
	return false


## Regress to previous body level (if not at min)
## Returns true if level decreased, false if already at min
func regress_level() -> bool:
	if current_level > MIN_BODY_LEVEL:
		current_level -= 1
		last_update_time = Time.get_ticks_msec() / 1000.0
		return true
	return false


## Reset to base level
func reset_to_base() -> void:
	current_level = MIN_BODY_LEVEL
	last_update_time = Time.get_ticks_msec() / 1000.0


## Check if at maximum body level
func is_at_max() -> bool:
	return current_level >= MAX_BODY_LEVEL


## Check if at minimum body level
func is_at_min() -> bool:
	return current_level <= MIN_BODY_LEVEL


## Get visual feedback description for level up (Polish)
func get_level_up_message(new_level: int) -> String:
	match new_level:
		1:
			return "Wyglądasz bardziej aktywnie!"
		2:
			return "Twoja postawa jest coraz lepsza!"
		3:
			return "Stajesz się silniejszy!"
		4:
			return "Twoje ciało pokazuje trening!"
		5:
			return "Jesteś w doskonałej formie!"
		_:
			return ""


## Get visual feedback description for level down (Polish)
func get_level_down_message(new_level: int) -> String:
	match new_level:
		4:
			return "Wciąż jesteś silny!"
		3:
			return "Twoja forma jest dobra!"
		2:
			return "Czujesz się zdrowo!"
		1:
			return "Jesteś aktywny!"
		0:
			return "Gotowy na nowy początek!"
		_:
			return ""


## Serialize to dictionary
func to_dict() -> Dictionary:
	return {
		"current_level": current_level
	}


## Deserialize from dictionary
static func from_dict(data: Dictionary) -> BodyProgression:
	var progression := BodyProgression.new()
	if data.has("current_level"):
		progression.current_level = int(data["current_level"])
	return progression


## Get all body level names
func get_all_level_names() -> Array:
	var names := []
	for i in range(MAX_BODY_LEVEL + 1):
		names.append(BODY_LEVEL_NAMES.get(i, "Poziom %d" % i))
	return names


## Get level up threshold (training sessions needed for next level)
## From Training.gd: progresses every 5 sessions
func get_sessions_for_next_level() -> int:
	return 5
