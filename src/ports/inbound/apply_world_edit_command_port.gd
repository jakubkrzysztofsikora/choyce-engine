## Inbound port: apply a scene graph edit to a world.
## Covers place, paint, move, duplicate, and property changes.
## Each edit captures previous state for undo support.
class_name ApplyWorldEditCommandPort
extends RefCounted


func execute(world_id: String, command: WorldEditCommand, actor: PlayerProfile) -> bool:
	push_error("ApplyWorldEditCommandPort.execute() not implemented")
	return false
