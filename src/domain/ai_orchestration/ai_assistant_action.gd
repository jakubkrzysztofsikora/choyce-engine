## Entity representing a single AI-proposed action within the orchestration loop.
## Tracks lifecycle: proposed -> previewing -> approved -> applied (or reverted/rejected).
## Every action carries an explanation and a reversible patch for undo support.
## High-impact actions require explicit parent approval before application.
class_name AIAssistantAction
extends RefCounted

enum ActionStatus {
	PROPOSED,
	PREVIEWING,
	APPROVED,
	APPLIED,
	REVERTED,
	REJECTED,
}

enum ImpactLevel { LOW, MEDIUM, HIGH }

var action_id: String
var intent: String
var status: ActionStatus
var impact_level: ImpactLevel
var tool_invocations: Array  # of ToolInvocation
var explanation: String
var requires_parent_approval: bool
var reversible_patch: Dictionary
var created_at: String  # ISO 8601
var provenance: ProvenanceData


func _init(p_id: String = "", p_intent: String = "") -> void:
	action_id = p_id
	intent = p_intent
	status = ActionStatus.PROPOSED
	impact_level = ImpactLevel.LOW
	tool_invocations = []
	explanation = ""
	requires_parent_approval = false
	reversible_patch = {}
	created_at = ""
	provenance = null


func needs_approval() -> bool:
	return requires_parent_approval or impact_level == ImpactLevel.HIGH


func can_revert() -> bool:
	return status == ActionStatus.APPLIED and not reversible_patch.is_empty()


func mark_applied() -> void:
	status = ActionStatus.APPLIED


func mark_reverted() -> void:
	status = ActionStatus.REVERTED


func mark_rejected(reason: String) -> void:
	status = ActionStatus.REJECTED
	explanation = reason
