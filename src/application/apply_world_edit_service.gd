## Application service: applies a scene graph edit to a world.
## Captures previous state for undo, applies the edit, persists,
## and emits a WorldEditedEvent.
class_name ApplyWorldEditService
extends ApplyWorldEditCommandPort

var _project_store: ProjectStorePort
var _clock: ClockPort
var _event_bus: DomainEventBus
var _action_log: EventSourcedActionLog


func setup(
	project_store: ProjectStorePort,
	clock: ClockPort,
	event_bus: DomainEventBus = null,
	action_log: EventSourcedActionLog = null
) -> ApplyWorldEditService:
	_project_store = project_store
	_clock = clock
	_event_bus = event_bus
	_action_log = action_log
	return self


func execute(world_id: String, command: WorldEditCommand, actor: PlayerProfile) -> bool:
	var project := _find_project_for_world(world_id)
	if project == null:
		return false

	var world := project.get_world(world_id)
	if world == null:
		return false

	var success := _apply_command(world, command)
	if not success:
		return false

	project.updated_at = _clock.now_iso()
	_project_store.save_project(project)

	var event := WorldEditedEvent.new(world_id, _action_name(command.action), actor.profile_id)
	event.event_id = "%s_%s" % [world_id, _clock.now_msec()]
	event.timestamp = _clock.now_iso()
	event.target_node_id = command.target_node_id
	event.previous_state = command.previous_state
	event.new_state = command.new_state
	if _action_log != null:
		_action_log.record_world_edit(event)
	if _event_bus != null:
		_event_bus.emit(event)

	return true


func _apply_command(world: World, command: WorldEditCommand) -> bool:
	match command.action:
		WorldEditCommand.Action.ADD_NODE:
			var node := SceneNode.new(
				command.target_node_id,
				command.node_data.get("type", SceneNode.NodeType.OBJECT)
			)
			node.display_name = command.node_data.get("display_name", "")
			node.position = command.node_data.get("position", Vector3.ZERO)
			node.properties = command.node_data.get("properties", {})

			var resolved_provenance := _resolve_command_provenance(command, null)
			if resolved_provenance != null:
				node.provenance = resolved_provenance
			else:
				node.provenance = ProvenanceData.new(ProvenanceData.SourceType.HUMAN)
			
			world.add_node(node)
			command.previous_state = {command.target_node_id: EventSourcedActionLog.DELETE_SENTINEL}
			command.new_state = {command.target_node_id: _snapshot_node(node)}
			return true
		WorldEditCommand.Action.REMOVE_NODE:
			for node in world.scene_nodes:
				if node.node_id == command.target_node_id:
					command.previous_state = {command.target_node_id: _snapshot_node(node)}
					command.new_state = {command.target_node_id: EventSourcedActionLog.DELETE_SENTINEL}
					return world.remove_node(command.target_node_id)
			return false
		WorldEditCommand.Action.MOVE_NODE, \
		WorldEditCommand.Action.CHANGE_PROPERTY, \
		WorldEditCommand.Action.PAINT:
			var requested_patch: Dictionary = command.new_state.duplicate(true)
			for meta_key in [
				"provenance",
				"_provenance",
				"ai_generated",
				"generator_model",
				"audit_id",
				"content_kind",
			]:
				requested_patch.erase(meta_key)
			for node in world.scene_nodes:
				if node.node_id == command.target_node_id:
					var previous_patch := {}
					for key in requested_patch:
						previous_patch[key] = node.properties.get(key, null)
						node.properties[key] = requested_patch[key]
					var updated_provenance := _resolve_command_provenance(command, node.provenance)
					if updated_provenance != null:
						node.provenance = updated_provenance
					command.previous_state = {command.target_node_id: previous_patch}
					command.new_state = {command.target_node_id: requested_patch}
					return true
			return false
		WorldEditCommand.Action.DUPLICATE_NODE:
			for node in world.scene_nodes:
				if node.node_id == command.target_node_id:
					var dup := SceneNode.new(
						command.node_data.get("new_id", command.target_node_id + "_copy"),
						node.node_type
					)
					dup.display_name = node.display_name
					dup.position = node.position + Vector3(1, 0, 0)
					dup.properties = node.properties.duplicate()
					if node.provenance != null:
						# Share reference or duplicate? Provenance is immutable, share is OK.
						# But strictly speaking we might want separate instance.
						# Let's share for now as it's data.
						dup.provenance = node.provenance
					else:
						# If original has no provenance, assume HUMAN for duplicate too? Or legacy?
						# Or create new HUMAN provenance.
						dup.provenance = ProvenanceData.new(ProvenanceData.SourceType.HUMAN)
					var duplicate_provenance := _resolve_command_provenance(command, dup.provenance)
					if duplicate_provenance != null:
						dup.provenance = duplicate_provenance
					
					world.add_node(dup)
					command.previous_state = {dup.node_id: EventSourcedActionLog.DELETE_SENTINEL}
					command.new_state = {dup.node_id: _snapshot_node(dup)}
					return true
			return false
	return false


func _find_project_for_world(world_id: String) -> Project:
	for project in _project_store.list_projects():
		if project.get_world(world_id) != null:
			return project
	return null


func _action_name(action: WorldEditCommand.Action) -> String:
	match action:
		WorldEditCommand.Action.ADD_NODE: return "node_added"
		WorldEditCommand.Action.REMOVE_NODE: return "node_removed"
		WorldEditCommand.Action.MOVE_NODE: return "node_moved"
		WorldEditCommand.Action.DUPLICATE_NODE: return "node_duplicated"
		WorldEditCommand.Action.CHANGE_PROPERTY: return "property_changed"
		WorldEditCommand.Action.PAINT: return "painted"
	return "unknown"


func _snapshot_node(node: SceneNode) -> Dictionary:
	var data: Dictionary = {
		"node_id": node.node_id,
		"node_type": int(node.node_type),
		"display_name": node.display_name,
		"position": node.position,
		"properties": node.properties.duplicate(true),
	}
	
	if node.provenance != null:
		data["provenance"] = {
			"source": int(node.provenance.source),
			"generator_model": node.provenance.generator_model,
			"audit_id": node.provenance.audit_id,
			"timestamp": node.provenance.timestamp
		}
	
	return data


func _resolve_command_provenance(
	command: WorldEditCommand,
	existing: ProvenanceData
) -> ProvenanceData:
	var payload := _extract_provenance_payload(command)
	if payload.is_empty():
		if not _is_ai_command(command):
			return existing
		payload = {
			"source": int(ProvenanceData.SourceType.AI_TEXT),
			"generator_model": str(command.node_data.get("generator_model", command.new_state.get("generator_model", ""))),
			"audit_id": str(command.node_data.get("audit_id", command.new_state.get("audit_id", ""))),
			"content_kind": str(command.node_data.get("content_kind", command.new_state.get("content_kind", ""))),
		}

	var source_value := int(payload.get("source", int(ProvenanceData.SourceType.AI_TEXT)))
	var should_force_hybrid := (
		existing != null
		and existing.source == ProvenanceData.SourceType.HUMAN
		and _is_ai_command(command)
	)
	if should_force_hybrid:
		source_value = int(ProvenanceData.SourceType.HYBRID)
	if payload.has("content_kind") and not should_force_hybrid:
		source_value = _source_from_content_kind(str(payload.get("content_kind", "")), source_value)

	var model := str(payload.get("generator_model", payload.get("model", "")))
	var audit_id := str(payload.get("audit_id", ""))
	var provenance := ProvenanceData.new(source_value, model, audit_id)
	provenance.timestamp = int(payload.get("timestamp", Time.get_unix_time_from_system()))
	return provenance


func _extract_provenance_payload(command: WorldEditCommand) -> Dictionary:
	if command.node_data.has("provenance") and command.node_data["provenance"] is Dictionary:
		return (command.node_data["provenance"] as Dictionary).duplicate(true)
	if command.new_state.has("provenance") and command.new_state["provenance"] is Dictionary:
		return (command.new_state["provenance"] as Dictionary).duplicate(true)
	if command.new_state.has("_provenance") and command.new_state["_provenance"] is Dictionary:
		return (command.new_state["_provenance"] as Dictionary).duplicate(true)
	return {}


func _is_ai_command(command: WorldEditCommand) -> bool:
	if bool(command.node_data.get("ai_generated", false)):
		return true
	if bool(command.new_state.get("ai_generated", false)):
		return true
	if command.node_data.has("provenance") or command.new_state.has("provenance") or command.new_state.has("_provenance"):
		return true
	return false


func _source_from_content_kind(content_kind: String, fallback: int) -> int:
	match content_kind.strip_edges().to_lower():
		"visual", "image", "texture":
			return int(ProvenanceData.SourceType.AI_VISUAL)
		"audio", "music", "sfx", "voice":
			return int(ProvenanceData.SourceType.AI_AUDIO)
		"text", "script", "logic":
			return int(ProvenanceData.SourceType.AI_TEXT)
		_:
			return fallback
