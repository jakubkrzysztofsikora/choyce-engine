## Application service implementing ManageEconomyPort.
## Manages parent economy adjustments with auditable diffs.
class_name ManageEconomyService
extends ManageEconomyPort


var _economy_store: GameEconomyStorePort
var _event_bus: DomainEventBus = null


func setup(
	economy_store: GameEconomyStorePort,
	event_bus: DomainEventBus = null
) -> ManageEconomyService:
	_economy_store = economy_store
	_event_bus = event_bus
	return self


## Load economy configuration for a world.
func load_world_economy(world_id: String) -> GameEconomy:
	if _economy_store == null:
		return GameEconomy.new(world_id)

	var economy = _economy_store.load_economy(world_id)
	if economy == null:
		economy = GameEconomy.new(world_id)

	return economy


## Adjust a single economy parameter with validation.
func adjust_parameter(world_id: String, category: String, param_name: String, new_value: float) -> bool:
	if _economy_store == null:
		return false

	var economy = load_world_economy(world_id)
	if economy == null:
		return false

	return economy.set_parameter(category, param_name, new_value)


## Get auditable diff of all modifications since last save.
func get_economy_diff(world_id: String) -> Array:
	var economy = load_world_economy(world_id)
	if economy == null:
		return []

	return economy.get_modified_parameters()


## Save economy changes and emit audit event.
func save_economy(world_id: String, economy: GameEconomy) -> bool:
	if _economy_store == null or economy == null:
		return false

	var saved = _economy_store.save_economy(world_id, economy)

	if saved and _event_bus != null:
		var adjustments = economy.get_modified_parameters()
		if adjustments.size() > 0:
			var event = EconomyAdjustedEvent.new(world_id, adjustments, "", "")
			_event_bus.emit(event)

	return saved


## Reset economy to default values.
func reset_economy_to_defaults(world_id: String) -> bool:
	if _economy_store == null:
		return false

	var economy = GameEconomy.new(world_id)
	economy.reset_all()

	return _economy_store.save_economy(world_id, economy)
