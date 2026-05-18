## Contract test for ParentAuditReadModel implementations.
class_name ParentAuditReadModelContractTest
extends PortContractTest


func run() -> Dictionary:
	var adapter_script: Variant = load("res://src/adapters/parent_audit_read_model_adapter.gd")
	if not (adapter_script is Script):
		_assert_true(false, "Parent audit adapter script should load")
		return _build_result("ParentAuditReadModel")
	var impl = (adapter_script as Script).new()

	_assert_eq(impl.get_timeline("parent-1").size(), 0, "Initial timeline is empty")
	_assert_eq(impl.get_interventions("parent-1").size(), 0, "Initial interventions list is empty")

	# Simulate content moderation block
	var block_event = MockSafetyInterventionTriggeredEvent.new("BLOCK", "MODERATION_BLOCK", "Violence detected", "2026-03-02T10:00:00Z")
	impl.update_from_event(block_event)

	var timeline = impl.get_timeline("parent-1")
	_assert_eq(timeline.size(), 1, "Should log blocked event to timeline")
	_assert_true(timeline[0].get("description").find("blocked") >= 0, "Should have descriptive message")

	var interventions = impl.get_interventions("parent-1")
	_assert_eq(interventions.size(), 1, "Should track moderation as intervention")
	_assert_eq(interventions[0].get("type"), "CONTENT_BLOCK", "Should tag as content block")
	_assert_true(interventions[0].get("reason") != "", "Should include reason")

	# Simulate policy override
	var override_event = MockPolicyOverriddenEvent.new("parent-1", "screen_time_limit", "Extended evening session", "2026-03-02T11:00:00Z")
	impl.update_from_event(override_event)

	timeline = impl.get_timeline("parent-1")
	_assert_eq(timeline.size(), 2, "Should add policy override to timeline")

	interventions = impl.get_interventions("parent-1")
	_assert_eq(interventions.size(), 2, "Should track override as intervention")
	_assert_eq(interventions[0].get("type"), "POLICY_OVERRIDE", "Should tag as policy override")

	# Simulate publish approval
	var publish_event = MockPublishApprovedEvent.new("project-1", "parent-1", "2026-03-02T12:00:00Z")
	impl.update_from_event(publish_event)

	timeline = impl.get_timeline("parent-1")
	_assert_eq(timeline.size(), 3, "Should log publish approval")

	interventions = impl.get_interventions("parent-1")
	_assert_eq(interventions.size(), 3, "Should track publish as intervention")

	# Test timeline with limits
	var limited = impl.get_timeline("parent-1", "", "", 1)
	_assert_eq(limited.size(), 1, "Should respect limit parameter")

	return _build_result("ParentAuditReadModel")


# Mock domain events for testing
class MockSafetyInterventionTriggeredEvent extends DomainEvent:
	var decision_type: String
	var policy_rule: String
	var trigger_context: String

	func _init(p_decision_type: String = "", p_policy_rule: String = "", p_trigger_context: String = "", p_timestamp: String = "") -> void:
		super._init("SafetyInterventionTriggered", "", p_timestamp)
		decision_type = p_decision_type
		policy_rule = p_policy_rule
		trigger_context = p_trigger_context


class MockPolicyOverriddenEvent extends DomainEvent:
	var parent_id: String
	var policy_name: String
	var reason: String

	func _init(p_parent_id: String, p_policy: String, p_reason: String, p_timestamp: String) -> void:
		super._init("PolicyOverriddenEvent", "", p_timestamp)
		parent_id = p_parent_id
		policy_name = p_policy
		reason = p_reason


class MockPublishApprovedEvent extends DomainEvent:
	var project_id: String
	var parent_id: String

	func _init(p_project_id: String, p_parent_id: String, p_timestamp: String) -> void:
		super._init("PublishApprovedEvent", "", p_timestamp)
		project_id = p_project_id
		parent_id = p_parent_id


class MockAIAssistanceAppliedEvent extends DomainEvent:
	var action_id: String

	func _init(p_action_id: String, p_timestamp: String) -> void:
		super._init("AIAssistanceApplied", "", p_timestamp)
		action_id = p_action_id
