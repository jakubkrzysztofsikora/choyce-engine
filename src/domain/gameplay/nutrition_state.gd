## Domain entity: tracks the player's nutrition status.
## Part of the Nutrition sandbox loop for VS-025.
##
## Design notes:
## - Framework-agnostic (extends RefCounted, not Node)
## - Uses child-safe terminology: Power, Zoom, Health, Endurance
## - NO calorie counting, all values are normalized (0-100 scale)
## - Gradual, optional, reversible progression
class_name NutritionState
extends RefCounted


## Maximum values (child-friendly scale, NOT calories)
const MAX_ENERGY: int = 100
const MAX_POWER: int = 100
const MAX_ZOOM: int = 100
const MAX_HEALTH: int = 100
const MAX_ENDURANCE: int = 100


# Current energy level (0-MAX_ENERGY)
var energy: int = 50

# Current nutrient levels (0-MAX_* for each)
var power: int = 0       ## From protein foods - makes you stronger
var zoom: int = 0        ## From carb foods - gives you energy
var health: int = 0      ## From vitamin-rich foods - keeps you healthy
var endurance: int = 0   ## From fiber-rich foods - helps you keep going

# Last food eaten (for HUD/caption display)
var last_food_id: String = ""
var last_food_name: String = ""

# Timestamp of last food consumption (for cooldown if needed)
var last_ate_time: float = 0.0


## Constructor
func _init() -> void:
	energy = 50  ## Start with half energy
	power = 0
	zoom = 0
	health = 0
	endurance = 0


## Add nutrition from a food item
## Returns true if the food was consumed successfully
func add_food(food: FoodItem) -> bool:
	if not food.can_eat():
		return false

	## Store last food info for HUD/captions
	last_food_id = food.id
	last_food_name = food.name
	last_ate_time = Time.get_ticks_msec()

	## Add energy (clamped to max)
	energy = min(energy + food.energy_value, MAX_ENERGY)

	## Add nutrient values
	for nutrient_key in food.nutrient_values:
		_add_nutrient(nutrient_key, food.nutrient_values[nutrient_key])

	return true


## Add a specific nutrient amount
func _add_nutrient(nutrient_key: String, amount: int) -> void:
	var normalized_key = nutrient_key.to_lower()
	match normalized_key:
		"power":
			power = min(power + amount, MAX_POWER)
		"zoom":
			zoom = min(zoom + amount, MAX_ZOOM)
		"health":
			health = min(health + amount, MAX_HEALTH)
		"endurance":
			endurance = min(endurance + amount, MAX_ENDURANCE)
		"long_lasting":
			## Add to both zoom and power for lasting energy
			zoom = min(zoom + amount, MAX_ZOOM)
			power = min(power + amount / 2, MAX_POWER)


## Use energy for an action (e.g., sprinting, jumping)
## Returns true if enough energy was available
func use_energy(amount: int) -> bool:
	if energy < amount:
		return false
	energy = max(energy - amount, 0)
	return true


## Get total nutrition score (0-100)
## This is a simple average for display purposes
func get_nutrition_score() -> float:
	var total: float = float(power + zoom + health + endurance)
	var max_total: float = float(MAX_POWER + MAX_ZOOM + MAX_HEALTH + MAX_ENDURANCE)
	return total / max_total * 100.0


## Get energy percentage (0-100)
func get_energy_percent() -> float:
	return float(energy) / float(MAX_ENERGY) * 100.0


## Get all nutrient percentages as a dictionary
func get_nutrient_percentages() -> Dictionary:
	return {
		"power": float(power) / float(MAX_POWER) * 100.0,
		"zoom": float(zoom) / float(MAX_ZOOM) * 100.0,
		"health": float(health) / float(MAX_HEALTH) * 100.0,
		"endurance": float(endurance) / float(MAX_ENDURANCE) * 100.0
	}


## Reset to default state
func reset() -> void:
	energy = 50
	power = 0
	zoom = 0
	health = 0
	endurance = 0
	last_food_id = ""
	last_food_name = ""


## Create a snapshot for save/load
func to_dict() -> Dictionary:
	return {
		"energy": energy,
		"power": power,
		"zoom": zoom,
		"health": health,
		"endurance": endurance,
		"last_food_id": last_food_id,
		"last_food_name": last_food_name
	}


## Load from a snapshot
func from_dict(data: Dictionary) -> void:
	if data.has("energy"):
		energy = int(data["energy"])
	if data.has("power"):
		power = int(data["power"])
	if data.has("zoom"):
		zoom = int(data["zoom"])
	if data.has("health"):
		health = int(data["health"])
	if data.has("endurance"):
		endurance = int(data["endurance"])
	if data.has("last_food_id"):
		last_food_id = data["last_food_id"]
	if data.has("last_food_name"):
		last_food_name = data["last_food_name"]
