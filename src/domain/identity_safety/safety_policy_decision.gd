## Entity recording a safety policy evaluation result.
## Created whenever the system evaluates content against safety rules.
## Decisions are logged for the parent audit timeline and are
## tamper-evident when persisted to the audit ledger.
class_name SafetyPolicyDecision
extends RefCounted

enum DecisionType { ALLOW, BLOCK, ESCALATE_TO_PARENT }

var decision_id: String
var decision_type: DecisionType
var policy_rule: String
var trigger_context: String
var moderation_result: ModerationResult
var explanation: String
var logged_at: String  # ISO 8601


func _init(
	p_type: DecisionType = DecisionType.ALLOW,
	p_rule: String = ""
) -> void:
	decision_id = ""
	decision_type = p_type
	policy_rule = p_rule
	trigger_context = ""
	moderation_result = ModerationResult.new()
	explanation = ""
	logged_at = ""


func is_blocked() -> bool:
	return decision_type == DecisionType.BLOCK


func needs_parent() -> bool:
	return decision_type == DecisionType.ESCALATE_TO_PARENT
