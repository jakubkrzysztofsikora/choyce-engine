## Adapter: Manages the player's nutrition state in the gameplay runtime.
## Part of the Nutrition sandbox loop for VS-025.
##
## Design notes:
## - Connects domain NutritionState with the gameplay runtime
## - Handles food consumption, energy usage, HUD updates
## - Emits signals for UI/feedback systems
class_name NutritionManager
extends Node


## Signals for UI/feedback
signal food_eaten(food_item: FoodItem)
signal nutrition_changed(energy: float, power: float, zoom: float, health: float, endurance: float)
signal energy_changed(current: int, max: int)
signal caption_requested(text: String)
signal voice_requested(voice_id: String, text: String)


# Reference to the domain NutritionState
var _nutrition_state: NutritionState

# Reference to the food database
@export var food_database: FoodDatabase

# Whether to use voice feedback
@export var use_voice: bool = true

# Whether to use captions
@export var use_captions: bool = true

# Energy consumption rate per second when sprinting
@export var sprint_energy_rate: float = 5.0

# Energy consumption rate per jump
@export var jump_energy_cost: int = 3

# Energy consumption rate per attack
@export var attack_energy_cost: int = 2

# Timer for continuous energy drain (e.g., sprinting)
var _sprint_timer: float = 0.0
var _is_sprinting: bool = false


## Called when the node enters the scene tree for the first time
func _ready() -> void:
	if _nutrition_state == null:
		_nutrition_state = NutritionState.new()
	
	## Connect to player signals if available
	var player: CharacterBody3D = get_node_or_null("/root/Main/World/Player")
	if player != null:
		## Try to connect to sprint signal
		if player.has_signal("sprint_started"):
			player.sprint_started.connect(_on_sprint_started)
		if player.has_signal("sprint_ended"):
			player.sprint_ended.connect(_on_sprint_ended)
		if player.has_signal("jumped"):
			player.jumped.connect(_on_player_jumped)
		if player.has_signal("attacked"):
			player.attacked.connect(_on_player_attacked)


## Process continuous energy drain (e.g., sprinting)
func _process(delta: float) -> void:
	if _is_sprinting and _nutrition_state != null:
		_sprint_timer += delta
		if _sprint_timer >= 1.0:
			## Use 1 second worth of energy
			_nutrition_state.use_energy(sprint_energy_rate)
			_sprint_timer = 0.0
			_emit_nutrition_changed()


## Handle sprint started
func _on_sprint_started() -> void:
	_is_sprinting = true
	_sprint_timer = 0.0


## Handle sprint ended
func _on_sprint_ended() -> void:
	_is_sprinting = false


## Handle player jumped
func _on_player_jumped(damage: int, hit_position: Vector3) -> void:
	if _nutrition_state != null:
		_nutrition_state.use_energy(jump_energy_cost)
		_emit_nutrition_changed()


## Handle player attacked
func _on_player_attacked(damage: int, hit_position: Vector3) -> void:
	if _nutrition_state != null:
		_nutrition_state.use_energy(attack_energy_cost)
		_emit_nutrition_changed()


## Eat a food item
## Returns true if successfully eaten
func eat_food(food: FoodItem) -> bool:
	if _nutrition_state == null:
		return false
	
	var success: bool = _nutrition_state.add_food(food)
	if success:
		## Emit signals
		food_eaten.emit(food)
		_emit_nutrition_changed()
		
		## Show feedback
		var caption: String = "Ate %s!" % [food.name]
		var nutrient_feedback: String = _get_nutrient_feedback(food)
		if nutrient_feedback != "":
			caption += " %s" % [nutrient_feedback]
		
		if use_captions:
			caption_requested.emit(caption)
		
		if use_voice:
			## For now, just request a generic eat sound
			## In the future, this would use the food's eat_sound
			voice_requested.emit("child_voice", caption)
		
		return true
	
	return false


## Get feedback text for a food's nutrients
func _get_nutrient_feedback(food: FoodItem) -> String:
	var nutrients: Array[String] = []
	
	if food.nutrient_values.has("power") and food.nutrient_values["power"] > 0:
		nutrients.append("+Power")
	if food.nutrient_values.has("zoom") and food.nutrient_values["zoom"] > 0:
		nutrients.append("+Zoom")
	if food.nutrient_values.has("health") and food.nutrient_values["health"] > 0:
		nutrients.append("+Health")
	if food.nutrient_values.has("endurance") and food.nutrient_values["endurance"] > 0:
		nutrients.append("+Endurance")
	if food.nutrient_values.has("long_lasting") and food.nutrient_values["long_lasting"] > 0:
		nutrients.append("+Long-Lasting")
	
	if nutrients.size() > 0:
		return "Gain: %s" % [", ".join(nutrients)]
	return ""


## Get a random forageable food and eat it
## Used for testing or when player interacts with forageable objects
func eat_random_forageable_food() -> bool:
	if food_database == null:
		return false
	
	var food: FoodItem = food_database.get_random_forageable_food()
	if food != null:
		return eat_food(food)
	return false


## Get current nutrition state
func get_nutrition_state() -> NutritionState:
	return _nutrition_state


## Get energy percentage
func get_energy_percent() -> float:
	if _nutrition_state == null:
		return 50.0
	return _nutrition_state.get_energy_percent()


## Get nutrient percentages
func get_nutrient_percentages() -> Dictionary:
	if _nutrition_state == null:
		return {}
	return _nutrition_state.get_nutrient_percentages()


## Use energy for an action
func use_energy(amount: int) -> bool:
	if _nutrition_state == null:
		return false
	var success: bool = _nutrition_state.use_energy(amount)
	if success:
		_emit_nutrition_changed()
	return success


## Add energy directly (for special events, power-ups, etc.)
func add_energy(amount: int) -> void:
	if _nutrition_state == null:
		return
	_nutrition_state.energy = min(_nutrition_state.energy + amount, NutritionState.MAX_ENERGY)
	_emit_nutrition_changed()


## Emit nutrition changed signal
func _emit_nutrition_changed() -> void:
	if _nutrition_state == null:
		return
	
	var percentages: Dictionary = _nutrition_state.get_nutrient_percentages()
	nutrition_changed.emit(
		_nutrition_state.get_energy_percent(),
		percentages.get("power", 0.0),
		percentages.get("zoom", 0.0),
		percentages.get("health", 0.0),
		percentages.get("endurance", 0.0)
	)
	energy_changed.emit(_nutrition_state.energy, NutritionState.MAX_ENERGY)


## Reset nutrition state
func reset() -> void:
	if _nutrition_state != null:
		_nutrition_state.reset()
		_emit_nutrition_changed()


## Save state to dictionary
func save_to_dict() -> Dictionary:
	if _nutrition_state == null:
		return {}
	return _nutrition_state.to_dict()


## Load state from dictionary
func load_from_dict(data: Dictionary) -> void:
	if _nutrition_state == null:
		_nutrition_state = NutritionState.new()
	_nutrition_state.from_dict(data)
	_emit_nutrition_changed()
