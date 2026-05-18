## Application test: bounded cache eviction for AI patch services.
## Verifies that _pending_actions (ApproveAIPatchService) and _actions
## (AIPatchWorkflowService) never grow past MAX_PENDING=200, and that the
## oldest entry is evicted on the 201st insert.
##
## FIFO-by-last-update semantics (LRU-ish):
##   Re-inserting an existing action_id refreshes its position to the back of
##   the eviction queue. The re-inserted action is therefore the LAST to be
##   evicted — not the first — regardless of its original insertion position.
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
	# FIFO-by-last-update (re-insert position refresh) tests
	test_approve_reinserting_position_0_action_makes_it_last_evicted()
	test_approve_reinserting_position_100_action_survives_max_plus_1_inserts()
	test_workflow_reinserting_position_0_action_makes_it_last_evicted()
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


## --- FIFO-by-last-update (LRU-ish position refresh) tests ---

## Re-insert the very first action (position 0) then fill to MAX_PENDING.
## The re-inserted action must be the LAST evicted, not the first.
## Criterion: re-insert at position 0 then fill to MAX_PENDING; assert the
## re-inserted action is present after MAX_PENDING inserts and only evicted
## on the (MAX_PENDING+1)th insert.
func test_approve_reinserting_position_0_action_makes_it_last_evicted() -> void:
	var service := ApproveAIPatchService.new().setup(MockClock.new())
	const MAX := ApproveAIPatchService.MAX_PENDING

	# Insert first action — it would normally be evicted first
	var first := AIAssistantAction.new("action-first", "v1")
	service.register_pending_action(first)

	# Fill the rest to MAX_PENDING - 1 more (total = MAX)
	for i in range(1, MAX):
		service.register_pending_action(AIAssistantAction.new("action-%d" % i, "desc"))

	# Re-insert "action-first" — this must move it to the back of the queue
	var refreshed := AIAssistantAction.new("action-first", "v2")
	service.register_pending_action(refreshed)

	# Now insert one truly-new action to trigger eviction of the oldest (action-1)
	service.register_pending_action(AIAssistantAction.new("action-trigger-evict", "desc"))

	_assert_false(
		service._pending_actions.has("action-1"),
		"ApproveAIPatchService: action-1 (now oldest) must be evicted, not re-inserted action-first"
	)
	_assert_true(
		service._pending_actions.has("action-first"),
		"ApproveAIPatchService: re-inserted action-first must still be present after eviction of action-1"
	)


## Re-insert action at position 100 (mid-queue) then fill remaining slots.
## The re-inserted action must survive past MAX_PENDING+1 total inserts.
## Criterion: re-insert at position 100 then fill to MAX_PENDING; assert the
## re-inserted action is still present after MAX+1th insert.
func test_approve_reinserting_position_100_action_survives_max_plus_1_inserts() -> void:
	var service := ApproveAIPatchService.new().setup(MockClock.new())
	const MAX := ApproveAIPatchService.MAX_PENDING

	# Fill 101 entries (indices 0..100)
	for i in range(101):
		service.register_pending_action(AIAssistantAction.new("ap100-%d" % i, "desc"))

	# Re-insert index 100 to move it to back of queue
	service.register_pending_action(AIAssistantAction.new("ap100-100", "refreshed"))

	# Fill remaining slots up to MAX  (we have 101 entries, need MAX - 101 more new ones)
	for i in range(101, MAX):
		service.register_pending_action(AIAssistantAction.new("ap100-new-%d" % i, "desc"))

	# One more new insert triggers eviction of oldest (ap100-0, not ap100-100)
	service.register_pending_action(AIAssistantAction.new("ap100-overflow", "desc"))

	_assert_true(
		service._pending_actions.has("ap100-100"),
		"ApproveAIPatchService: re-inserted ap100-100 must still be present after MAX+1 inserts"
	)
	_assert_false(
		service._pending_actions.has("ap100-0"),
		"ApproveAIPatchService: ap100-0 (oldest untouched) must be evicted instead"
	)


## Workflow service equivalent of the position-0 re-insert test.
func test_workflow_reinserting_position_0_action_makes_it_last_evicted() -> void:
	var service := AIPatchWorkflowService.new().setup(MockClock.new())
	const MAX := AIPatchWorkflowService.MAX_PENDING

	var first := AIAssistantAction.new("wf-first", "v1")
	service.track_action(first)

	for i in range(1, MAX):
		service.track_action(AIAssistantAction.new("wf-%d" % i, "desc"))

	# Re-insert wf-first to refresh its position
	service.track_action(AIAssistantAction.new("wf-first", "v2"))

	# Trigger eviction — oldest is now wf-1
	service.track_action(AIAssistantAction.new("wf-trigger-evict", "desc"))

	_assert_false(
		service._actions.has("wf-1"),
		"AIPatchWorkflowService: wf-1 (now oldest) must be evicted, not re-inserted wf-first"
	)
	_assert_true(
		service._actions.has("wf-first"),
		"AIPatchWorkflowService: re-inserted wf-first must still be present after eviction of wf-1"
	)
