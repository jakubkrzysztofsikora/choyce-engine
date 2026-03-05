class_name AIPatchWorkflowServiceContractTest
extends PortContractTest


class MockClock:
	extends ClockPort

	var _tick: int = 0

	func now_iso() -> String:
		_tick += 1
		return "2026-03-02T15:10:%02dZ" % _tick

	func now_msec() -> int:
		_tick += 1
		return 1767424200000 + _tick


class MockToolGateway:
	extends ToolExecutionGateway

	var execute_calls: int = 0
	var rollback_calls: int = 0

	func execute(invocation: ToolInvocation, _context: Dictionary = {}) -> Dictionary:
		execute_calls += 1
		return {
			"ok": true,
			"undo_token": {
				"tool_name": invocation.tool_name,
				"token_id": "undo_%d" % execute_calls,
			}
		}

	func rollback(_undo_token: Dictionary, _context: Dictionary = {}) -> bool:
		rollback_calls += 1
		return true


func run() -> Dictionary:
	_reset()

	var gateway := MockToolGateway.new()
	var bus := DomainEventBus.new(50)
	var log := EventSourcedActionLog.new()
	var service := AIPatchWorkflowService.new().setup(MockClock.new(), gateway, log, bus)

	var kid := PlayerProfile.new("kid-1", PlayerProfile.Role.KID)
	var parent := PlayerProfile.new("parent-1", PlayerProfile.Role.PARENT)

	var script_action := AIAssistantAction.new("action-script", "Zmien skrypt")
	script_action.impact_level = AIAssistantAction.ImpactLevel.HIGH
	script_action.requires_parent_approval = true
	script_action.tool_invocations = [ToolInvocation.new("script_edit", {"code": "print(1)"}, "script-1")]
	service.track_action(script_action)

	var preview_kid := service.preview("action-script", kid)
	_assert_true(preview_kid.get("ok", false), "Preview should return card data")
	var card_kid: Dictionary = preview_kid.get("card", {})
	_assert_true(
		card_kid.get("requires_parent_approval", false),
		"Preview should flag parent approval for high-impact script edits"
	)
	_assert_true(
		not card_kid.get("can_apply", true),
		"Kid should not be allowed to apply parent-gated action"
	)

	var rejected_for_kid := service.apply("action-script", kid)
	_assert_true(
		rejected_for_kid.status == AIAssistantAction.ActionStatus.REJECTED,
		"Kid apply should be rejected for parent-gated script action"
	)

	var asset_action := AIAssistantAction.new("action-asset", "Importuj model")
	asset_action.tool_invocations = [ToolInvocation.new("asset_import", {"asset_ref": "res://tree.glb"}, "asset-1")]
	service.track_action(asset_action)
	var parent_applied := service.apply("action-asset", parent)
	_assert_true(
		parent_applied.status == AIAssistantAction.ActionStatus.APPLIED,
		"Parent should be able to apply asset import action"
	)
	_assert_true(
		gateway.execute_calls >= 1,
		"Applying tracked action should execute tool invocations"
	)
	_assert_true(
		parent_applied.reversible_patch.get("undo_tokens", []).size() == 1,
		"Applied action should carry reversible undo tokens"
	)
	_assert_true(
		bus.get_history("AIAssistanceApplied").size() == 1,
		"Applying action should emit AIAssistanceApplied event"
	)

	var reverted := service.undo("action-asset", parent)
	_assert_true(
		reverted.status == AIAssistantAction.ActionStatus.REVERTED,
		"Undo should mark action as REVERTED"
	)
	_assert_true(
		gateway.rollback_calls == 1,
		"Undo should rollback through tool gateway"
	)
	_assert_true(
		bus.get_history("AIAssistanceReverted").size() == 1,
		"Undo should emit AIAssistanceReverted event"
	)
	_assert_true(
		log.get_entry_count("action-asset") == 2,
		"Apply and undo should both be recorded in action log stream"
	)

	var low_action := AIAssistantAction.new("action-low", "Pomaluj domek")
	low_action.tool_invocations = [ToolInvocation.new("paint", {"color": "niebieski"}, "paint-1")]
	service.track_action(low_action)
	var low_applied := service.apply("action-low", kid)
	_assert_true(
		low_applied.status == AIAssistantAction.ActionStatus.APPLIED,
		"Low-impact paint action should apply for kid"
	)

	var missing_preview := service.preview("missing-action", parent)
	_assert_true(
		not missing_preview.get("ok", false),
		"Preview should fail for unknown action id"
	)

	return _build_result("AIPatchWorkflowService")
