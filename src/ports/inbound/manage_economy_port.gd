## Inbound port for parent economy management use cases.
## Parents can adjust game economy (prices, rates, multipliers) in advanced mode.
class_name ManageEconomyPort
extends RefCounted


## Load economy configuration for a world (with defaults if none saved).
func load_world_economy(world_id: String) -> GameEconomy:
	push_error("ManageEconomyPort.load_world_economy() not implemented")
	return null


## Update a single economy parameter with validation.
## Returns true if successful, false if out of bounds.
func adjust_parameter(world_id: String, category: String, param_name: String, new_value: float) -> bool:
	push_error("ManageEconomyPort.adjust_parameter() not implemented")
	return false


## Get auditable diff showing what changed in economy since last save.
## Useful for parent review before applying.
func get_economy_diff(world_id: String) -> Array:
	push_error("ManageEconomyPort.get_economy_diff() not implemented")
	return []


## Save economy configuration and emit audit event.
func save_economy(world_id: String, economy: GameEconomy) -> bool:
	push_error("ManageEconomyPort.save_economy() not implemented")
	return false


## Reset economy to defaults (all parameters back to 1.0).
func reset_economy_to_defaults(world_id: String) -> bool:
	push_error("ManageEconomyPort.reset_economy_to_defaults() not implemented")
	return false
