## Application service for AI patch action-card workflow.
## Exposes Preview -> Apply -> Undo behavior with parent approval gates
## for high-impact and script/asset mutations.
class_name AIPatchWorkflowService
extends RefCounted

var _clock: ClockPort
var _tool_gateway: ToolExecutionGateway
var _action_log: EventSourcedActionLog
var _event_bus: DomainEventBus
var _actions: Dictionary = {}


func setup(
	clock: ClockPort,
	tool_gateway: ToolExecutionGateway = null,
	action_log: EventSourcedActionLog = null,
	event_bus: DomainEventBus = null
) -> AIPatchWorkflowService:
	_clock = clock
	_tool_gateway = tool_gateway
	_action_log = action_log
	_event_bus = event_bus
	return self


func track_action(action: AIAssistantAction) -> bool:
	if action == null or action.action_id.is_empty():
		return false
	_actions[action.action_id] = action
	return true


func get_action(action_id: String) -> AIAssistantAction:
	return _get_action(action_id)


func preview(action_id: String, actor: PlayerProfile) -> Dictionary:
	var action := _get_action(action_id)
	if action == null or actor == null:
		return {"ok": false, "error": "Action or actor not found"}

	if action.status == AIAssistantAction.ActionStatus.PROPOSED:
		action.status = AIAssistantAction.ActionStatus.PREVIEWING

	var requires_parent_gate := _requires_parent_gate(action)
	return {
		"ok": true,
		"card": {
			"action_id": action.action_id,
			"status": _status_name(action.status),
			"impact_level": _impact_level_name(action.impact_level),
			"requires_parent_approval": requires_parent_gate,
			"available_actions": ["Preview", "Apply", "Undo"],
			"tool_count": action.tool_invocations.size(),
			"summary": action.explanation,
			"can_apply": (not requires_parent_gate) or actor.is_parent(),
			"can_undo": action.can_revert(),
		}
	}


func apply(action_id: String, actor: PlayerProfile) -> AIAssistantAction:
	var action := _get_action(action_id)
	if action == null or actor == null:
		return null

	if action.status == AIAssistantAction.ActionStatus.APPLIED:
		return action

	if _requires_parent_gate(action) and not actor.is_parent():
		action.mark_rejected("Parent approval required for script or asset changes")
		return action

	var tx := _execute_transactionally(action, actor)
	if not tx.get("ok", false):
		action.mark_rejected(str(tx.get("reason", "Tool execution failed")))
		return action

	var previous_status := _status_name(action.status)
	action.mark_applied()
	action.reversible_patch = {"undo_tokens": tx.get("undo_tokens", [])}

	_record_state_change(
		action,
		actor,
		{"status": previous_status},
		{"status": "APPLIED", "undo_tokens": tx.get("undo_tokens", [])}
	)
	_emit_applied_event(action, actor)
	return action


func undo(action_id: String, actor: PlayerProfile) -> AIAssistantAction:
	var action := _get_action(action_id)
	if action == null or actor == null:
		return null
	if not action.can_revert():
		return action

	var undo_tokens: Array = action.reversible_patch.get("undo_tokens", [])
	for i in range(undo_tokens.size() - 1, -1, -1):
		var token: Variant = undo_tokens[i]
		if _tool_gateway != null and token is Dictionary:
			var ok := _tool_gateway.rollback(token, {"actor_id": actor.profile_id, "action_id": action.action_id})
			if not ok:
				action.mark_rejected("Undo rollback failed")
				return action

	action.mark_reverted()
	_record_state_change(
		action,
		actor,
		{"status": "APPLIED"},
		{"status": "REVERTED"}
	)
	_emit_reverted_event(action, actor, undo_tokens.size())
	return action


func _execute_transactionally(action: AIAssistantAction, actor: PlayerProfile) -> Dictionary:
	if _tool_gateway == null:
		return {"ok": true, "undo_tokens": action.reversible_patch.get("undo_tokens", [])}

	var undo_tokens: Array = []
	for invocation in action.tool_invocations:
		var result := _tool_gateway.execute(
			invocation,
			{"actor_id": actor.profile_id, "action_id": action.action_id}
		)
		if not result.get("ok", false):
			for i in range(undo_tokens.size() - 1, -1, -1):
				_tool_gateway.rollback(undo_tokens[i], {"actor_id": actor.profile_id, "action_id": action.action_id})
			return {"ok": false, "reason": str(result.get("error", "Execution failed"))}

		var undo_token: Variant = result.get("undo_token", null)
		if undo_token is Dictionary:
			undo_tokens.append((undo_token as Dictionary).duplicate(true))

	return {"ok": true, "undo_tokens": undo_tokens}


func _requires_parent_gate(action: AIAssistantAction) -> bool:
	if action.needs_approval() or action.requires_parent_approval:
		return true

	for invocation in action.tool_invocations:
		if not (invocation is ToolInvocation):
			continue
		var tool: ToolInvocation = invocation
		if tool.requires_approval:
			return true
		if tool.tool_name in ["script_edit", "asset_import"]:
			return true
	return false


func _record_state_change(
	action: AIAssistantAction,
	actor: PlayerProfile,
	previous_state: Dictionary,
	new_state: Dictionary
) -> void:
	if _action_log == null:
		return
	_action_log.record_ai_patch(
		action.action_id,
		new_state,
		previous_state,
		actor.profile_id,
		_now_iso()
	)


func _emit_applied_event(action: AIAssistantAction, actor: PlayerProfile) -> void:
	if _event_bus == null:
		return

	var event := AIAssistanceAppliedEvent.new(
		action.action_id,
		actor.profile_id,
		_now_iso()
	)
	event.tool_invocations_count = action.tool_invocations.size()
	event.impact_level = _impact_level_name(action.impact_level)
	event.was_parent_approved = actor.is_parent()
	var patch_keys: Array[String] = []
	for key in action.reversible_patch.keys():
		patch_keys.append(str(key))
	event.reversible_patch_keys = patch_keys
	_event_bus.emit(event)


func _emit_reverted_event(action: AIAssistantAction, actor: PlayerProfile, tokens_count: int) -> void:
	if _event_bus == null:
		return

	var event := AIAssistanceRevertedEvent.new(
		action.action_id,
		actor.profile_id,
		_now_iso()
	)
	event.reverted_tokens_count = tokens_count
	event.impact_level = _impact_level_name(action.impact_level)
	_event_bus.emit(event)


func _get_action(action_id: String) -> AIAssistantAction:
	if action_id.is_empty():
		return null
	var action: Variant = _actions.get(action_id, null)
	if action is AIAssistantAction:
		return action
	return null


func _now_iso() -> String:
	if _clock == null:
		return ""
	return _clock.now_iso()


func _impact_level_name(level: AIAssistantAction.ImpactLevel) -> String:
	match level:
		AIAssistantAction.ImpactLevel.LOW: return "LOW"
		AIAssistantAction.ImpactLevel.MEDIUM: return "MEDIUM"
		AIAssistantAction.ImpactLevel.HIGH: return "HIGH"
	return "LOW"


func _status_name(status: AIAssistantAction.ActionStatus) -> String:
	match status:
		AIAssistantAction.ActionStatus.PROPOSED: return "PROPOSED"
		AIAssistantAction.ActionStatus.PREVIEWING: return "PREVIEWING"
		AIAssistantAction.ActionStatus.APPROVED: return "APPROVED"
		AIAssistantAction.ActionStatus.APPLIED: return "APPLIED"
		AIAssistantAction.ActionStatus.REVERTED: return "REVERTED"
		AIAssistantAction.ActionStatus.REJECTED: return "REJECTED"
	return "PROPOSED"
