## Application service: approves or rejects a pending AI action.
## Enforces that only parent profiles can approve high-impact actions.
## Updates the action status and logs the decision.
class_name ApproveAIPatchService
extends ApproveAIPatchPort

var _clock: ClockPort
var _action_log: EventSourcedActionLog
var _event_bus: DomainEventBus


func setup(
	clock: ClockPort,
	action_log: EventSourcedActionLog = null,
	event_bus: DomainEventBus = null
) -> ApproveAIPatchService:
	_clock = clock
	_action_log = action_log
	_event_bus = event_bus
	return self


func execute(action_id: String, approved: bool, approver: PlayerProfile) -> AIAssistantAction:
	# In a full implementation, this would load the action from a repository.
	# For now, we validate the approval rules and return a status-updated action.

	if not approved:
		var rejected := AIAssistantAction.new(action_id, "")
		rejected.mark_rejected("Rejected by %s" % approver.profile_id)
		return rejected

	# Only parents can approve high-impact actions
	var action := AIAssistantAction.new(action_id, "")

	if action.needs_approval() and approver.is_kid():
		var denied := AIAssistantAction.new(action_id, "")
		denied.mark_rejected("Kid cannot approve high-impact actions")
		return denied

	action.status = AIAssistantAction.ActionStatus.APPROVED
	action.mark_applied()

	var now := _clock.now_iso()
	var previous_state := {"status": "APPROVED"}
	var new_state := {"status": "APPLIED"}
	if not action.reversible_patch.is_empty():
		new_state = action.reversible_patch.duplicate(true)

	if _action_log != null:
		_action_log.record_ai_patch(action.action_id, new_state, previous_state, approver.profile_id, now)
		_action_log.create_checkpoint(action.action_id, "safe_after_ai_apply")

	if _event_bus != null:
		var event := AIAssistanceAppliedEvent.new(action.action_id, approver.profile_id, now)
		event.tool_invocations_count = action.tool_invocations.size()
		event.impact_level = _impact_level_name(action.impact_level)
		event.was_parent_approved = approver.is_parent()
		var patch_keys: Array[String] = []
		for key in action.reversible_patch.keys():
			patch_keys.append(str(key))
		event.reversible_patch_keys = patch_keys
		_event_bus.emit(event)

	return action


func _impact_level_name(level: AIAssistantAction.ImpactLevel) -> String:
	match level:
		AIAssistantAction.ImpactLevel.LOW: return "LOW"
		AIAssistantAction.ImpactLevel.MEDIUM: return "MEDIUM"
		AIAssistantAction.ImpactLevel.HIGH: return "HIGH"
	return "LOW"
