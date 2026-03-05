## Inbound port: launch a playtest session from the current world state.
## Creates a Session entity with the appropriate mode and players.
class_name RunPlaytestPort
extends RefCounted


## players: Array[PlayerProfile]
func execute(world_id: String, players: Array) -> Session:
	push_error("RunPlaytestPort.execute() not implemented")
	return null
