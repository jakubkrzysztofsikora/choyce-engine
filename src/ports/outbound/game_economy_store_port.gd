## Outbound port contract for game economy persistence.
## Allows parents to save and load economy configurations for worlds.
class_name GameEconomyStorePort
extends RefCounted


## Save economy configuration for a world.
## Returns true if successful, false otherwise.
func save_economy(world_id: String, economy: GameEconomy) -> bool:
	push_error("GameEconomyStorePort.save_economy() not implemented")
	return false


## Load economy configuration for a world.
## Returns empty GameEconomy if none exists.
func load_economy(world_id: String) -> GameEconomy:
	push_error("GameEconomyStorePort.load_economy() not implemented")
	return GameEconomy.new(world_id)


## List all economies accessible (for dashboard/review).
func list_economies() -> Array:
	push_error("GameEconomyStorePort.list_economies() not implemented")
	return []


## Delete economy configuration for a world (revert to defaults).
func delete_economy(world_id: String) -> bool:
	push_error("GameEconomyStorePort.delete_economy() not implemented")
	return false
