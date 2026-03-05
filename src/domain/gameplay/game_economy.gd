## Value object representing game economy configuration.
## Parents can adjust prices, spawn rates, and multipliers in advanced mode.
## Tracks original and adjusted values for auditable diffs.
class_name GameEconomy
extends RefCounted


## Economy parameter with original and current values for diff tracking.
class EconomyParameter extends RefCounted:
	var name: String
	var original_value: float
	var current_value: float
	var min_value: float
	var max_value: float
	var description: String


	func _init(
		p_name: String = "",
		p_original: float = 1.0,
		p_min: float = 0.1,
		p_max: float = 10.0,
		p_desc: String = ""
	) -> void:
		name = p_name
		original_value = p_original
		current_value = p_original
		min_value = p_min
		max_value = p_max
		description = p_desc


	func is_modified() -> bool:
		return not is_equal_approx(current_value, original_value)


	func reset_to_original() -> void:
		current_value = original_value


	func set_value(value: float) -> bool:
		if value < min_value or value > max_value:
			return false
		current_value = clampf(value, min_value, max_value)
		return true


## Collectible pricing (e.g., coin shop prices)
var prices: Dictionary = {}  # name -> EconomyParameter

## Spawn rates and generation rates for items/NPCs
var spawn_rates: Dictionary = {}  # name -> EconomyParameter

## Multipliers for progression (XP, coins, unlock speed)
var progression_multipliers: Dictionary = {}  # name -> EconomyParameter

## World ID this economy is attached to
var world_id: String

## Timestamp when economy was created
var created_at: String

## Timestamp of last modification
var modified_at: String


func _init(p_world_id: String = "", p_created_at: String = "") -> void:
	world_id = p_world_id
	created_at = p_created_at if p_created_at != "" else ""
	modified_at = created_at
	_initialize_default_parameters()


## Initialize economy with sensible defaults for a game world.
func _initialize_default_parameters() -> void:
	# Prices (shop costs for cosmetics/upgrades)
	prices["cosmetic_hat"] = EconomyParameter.new("cosmetic_hat", 100.0, 10.0, 1000.0, "Price for cosmetic hat")
	prices["cosmetic_outfit"] = EconomyParameter.new("cosmetic_outfit", 500.0, 50.0, 5000.0, "Price for cosmetic outfit")
	prices["tool_upgrade"] = EconomyParameter.new("tool_upgrade", 250.0, 25.0, 2500.0, "Price for tool upgrade")

	# Spawn rates (items per minute or similar)
	spawn_rates["coin_spawn_rate"] = EconomyParameter.new("coin_spawn_rate", 1.0, 0.1, 10.0, "Coins spawned per minute")
	spawn_rates["npc_spawn_rate"] = EconomyParameter.new("npc_spawn_rate", 0.5, 0.1, 5.0, "NPCs spawned per minute")
	spawn_rates["item_spawn_rate"] = EconomyParameter.new("item_spawn_rate", 1.0, 0.1, 10.0, "Items spawned per minute")

	# Progression multipliers
	progression_multipliers["coin_multiplier"] = EconomyParameter.new("coin_multiplier", 1.0, 0.5, 5.0, "Coins earned multiplier")
	progression_multipliers["xp_multiplier"] = EconomyParameter.new("xp_multiplier", 1.0, 0.5, 5.0, "Experience earned multiplier")
	progression_multipliers["unlock_speed"] = EconomyParameter.new("unlock_speed", 1.0, 0.5, 5.0, "Speed of progression unlocks")


## Get parameter by category and name.
func get_parameter(category: String, param_name: String) -> EconomyParameter:
	match category:
		"prices":
			return prices.get(param_name)
		"spawn_rates":
			return spawn_rates.get(param_name)
		"progression_multipliers":
			return progression_multipliers.get(param_name)
		_:
			return null


## Update a parameter value with validation.
func set_parameter(category: String, param_name: String, value: float) -> bool:
	var param = get_parameter(category, param_name)
	if param == null:
		return false

	if not param.set_value(value):
		return false

	modified_at = ""
	return true


## Check if any economy parameters have been modified from defaults.
func has_modifications() -> bool:
	for param in prices.values():
		if param.is_modified():
			return true
	for param in spawn_rates.values():
		if param.is_modified():
			return true
	for param in progression_multipliers.values():
		if param.is_modified():
			return true
	return false


## Reset all parameters to original values.
func reset_all() -> void:
	for param in prices.values():
		param.reset_to_original()
	for param in spawn_rates.values():
		param.reset_to_original()
	for param in progression_multipliers.values():
		param.reset_to_original()
	modified_at = created_at


## Get list of all modified parameters with their changes.
func get_modified_parameters() -> Array:
	var modified = []

	for name_key in prices.keys():
		var param = prices[name_key]
		if param.is_modified():
			modified.append({
				"category": "prices",
				"name": name_key,
				"original": param.original_value,
				"current": param.current_value,
				"description": param.description
			})

	for name_key in spawn_rates.keys():
		var param = spawn_rates[name_key]
		if param.is_modified():
			modified.append({
				"category": "spawn_rates",
				"name": name_key,
				"original": param.original_value,
				"current": param.current_value,
				"description": param.description
			})

	for name_key in progression_multipliers.keys():
		var param = progression_multipliers[name_key]
		if param.is_modified():
			modified.append({
				"category": "progression_multipliers",
				"name": name_key,
				"original": param.original_value,
				"current": param.current_value,
				"description": param.description
			})

	return modified
