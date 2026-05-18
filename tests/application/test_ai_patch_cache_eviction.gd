## Application test: bounded cache eviction for AI patch services.
## Verifies that _pending_actions (ApproveAIPatchService) and _actions
## (AIPatchWorkflowService) never grow past MAX_PENDING=200, and that the
## oldest entry is evicted on the 201st insert.
class_name TestAIPatchCacheEviction
extends ApplicationTest


class MockClock:
	extends ClockPort

	var _tick: int = 0

	func now_iso() -> String:
		_tick += 1
		return "2026-05-18T00:00:%02dZ" % (_tick % 60)

	func now_msec() -> int:
		_tick += 1
		return 1747526400000 + _tick


func run() -> Dictionary:
	test_approve_service_evicts_oldest_on_201st_insert()
	test_approve_service_retains_newest_on_eviction()
	test_approve_service_size_stays_at_max_pending()
	test_workflow_service_evicts_oldest_on_201st_insert()
	test_workflow_service_retains_newest_on_eviction()
	test_workflow_service_size_stays_at_max_pending()
	test_approve_service_update_existing_does_not_grow()
	test_workflow_service_update_existing_does_not_grow()
	return _build_result("AIPatchCacheEviction")


## --- ApproveAIPatchService tests ---

func test_approve_service_evicts_oldest_on_201st_insert() -> void:
	var service := ApproveAIPatchService.new().setup(MockClock.new())

	# Insert MAX_PENDING (200) actions; first is "action-0"
	for i in range(ApproveAIPatchService.MAX_PENDING):
		var action := AIAssistantAction.new("action-%d" % i, "desc")
		service.register_pending_action(action)

	# Sanity: size should equal MAX_PENDING
	_assert_eq(
		service._pending_actions.size(),
		ApproveAIPatchService.MAX_PENDING,
		"ApproveAIPatchService: cache should be exactly MAX_PENDING after filling"
	)

	# Insert 201st action — should evict "action-0"
	var new_action := AIAssistantAction.new("action-200", "newest")
	service.register_pending_action(new_action)

	_assert_false(
		service._pending_actions.has("action-0"),
		"ApproveAIPatchService: oldest entry 'action-0' must be evicted on 201st insert"
	)


func test_approve_service_retains_newest_on_eviction() -> void:
	var service := ApproveAIPatchService.new().setup(MockClock.new())

	for i in range(ApproveAIPatchService.MAX_PENDING):
		var action := AIAssistantAction.new("action-%d" % i, "desc")
		service.register_pending_action(action)

	var new_action := AIAssistantAction.new("action-newest", "newest")
	service.register_pending_action(new_action)

	_assert_true(
		service._pending_actions.has("action-newest"),
		"ApproveAIPatchService: newest entry must be present after eviction"
	)


func test_approve_service_size_stays_at_max_pending() -> void:
	var service := ApproveAIPatchService.new().setup(MockClock.new())

	for i in range(ApproveAIPatchService.MAX_PENDING + 10):
		var action := AIAssistantAction.new("action-%d" % i, "desc")
		service.register_pending_action(action)

	_assert_eq(
		service._pending_actions.size(),
		ApproveAIPatchService.MAX_PENDING,
		"ApproveAIPatchService: cache size must never exceed MAX_PENDING"
	)


## --- AIPatchWorkflowService tests ---

func test_workflow_service_evicts_oldest_on_201st_insert() -> void:
	var service := AIPatchWorkflowService.new().setup(MockClock.new())

	for i in range(AIPatchWorkflowService.MAX_PENDING):
		var action := AIAssistantAction.new("wf-action-%d" % i, "desc")
		service.track_action(action)

	_assert_eq(
		service._actions.size(),
		AIPatchWorkflowService.MAX_PENDING,
		"AIPatchWorkflowService: cache should be exactly MAX_PENDING after filling"
	)

	var new_action := AIAssistantAction.new("wf-action-200", "newest")
	service.track_action(new_action)

	_assert_false(
		service._actions.has("wf-action-0"),
		"AIPatchWorkflowService: oldest entry 'wf-action-0' must be evicted on 201st insert"
	)


func test_workflow_service_retains_newest_on_eviction() -> void:
	var service := AIPatchWorkflowService.new().setup(MockClock.new())

	for i in range(AIPatchWorkflowService.MAX_PENDING):
		var action := AIAssistantAction.new("wf-action-%d" % i, "desc")
		service.track_action(action)

	var new_action := AIAssistantAction.new("wf-newest", "newest")
	service.track_action(new_action)

	_assert_true(
		service._actions.has("wf-newest"),
		"AIPatchWorkflowService: newest entry must be present after eviction"
	)


func test_workflow_service_size_stays_at_max_pending() -> void:
	var service := AIPatchWorkflowService.new().setup(MockClock.new())

	for i in range(AIPatchWorkflowService.MAX_PENDING + 10):
		var action := AIAssistantAction.new("wf-action-%d" % i, "desc")
		service.track_action(action)

	_assert_eq(
		service._actions.size(),
		AIPatchWorkflowService.MAX_PENDING,
		"AIPatchWorkflowService: cache size must never exceed MAX_PENDING"
	)


## --- Update-existing must not grow order array ---

func test_approve_service_update_existing_does_not_grow() -> void:
	var service := ApproveAIPatchService.new().setup(MockClock.new())

	var action := AIAssistantAction.new("action-repeat", "v1")
	service.register_pending_action(action)
	var order_size_after_first: int = service._pending_order.size()

	var updated := AIAssistantAction.new("action-repeat", "v2")
	service.register_pending_action(updated)

	_assert_eq(
		service._pending_order.size(),
		order_size_after_first,
		"ApproveAIPatchService: re-inserting existing key must not grow order array"
	)


func test_workflow_service_update_existing_does_not_grow() -> void:
	var service := AIPatchWorkflowService.new().setup(MockClock.new())

	var action := AIAssistantAction.new("wf-repeat", "v1")
	service.track_action(action)
	var order_size_after_first: int = service._actions_order.size()

	var updated := AIAssistantAction.new("wf-repeat", "v2")
	service.track_action(updated)

	_assert_eq(
		service._actions_order.size(),
		order_size_after_first,
		"AIPatchWorkflowService: re-inserting existing key must not grow order array"
	)
