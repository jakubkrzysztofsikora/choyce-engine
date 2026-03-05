class_name EventSourcedActionLogContractTest
extends PortContractTest


func run() -> Dictionary:
	_reset()
	var log := EventSourcedActionLog.new()
	var world_id := "world-1"

	_assert_has_method(log, "record_world_edit")
	_assert_has_method(log, "record_ai_patch")
	_assert_has_method(log, "undo")
	_assert_has_method(log, "redo")
	_assert_has_method(log, "create_checkpoint")
	_assert_has_method(log, "restore_checkpoint")
	_assert_has_method(log, "get_current_state")

	var event1 := WorldEditedEvent.new(world_id, "property_changed", "kid-1", "2026-03-02T12:00:00Z")
	event1.event_id = "e1"
	event1.target_node_id = "node-1"
	event1.previous_state = {"node-1": {"coins": 0}}
	event1.new_state = {"node-1": {"coins": 1}}
	_assert_true(log.record_world_edit(event1), "record_world_edit(event1) should return true")

	var event2 := WorldEditedEvent.new(world_id, "property_changed", "kid-1", "2026-03-02T12:00:01Z")
	event2.event_id = "e2"
	event2.target_node_id = "node-1"
	event2.previous_state = {"node-1": {"coins": 1}}
	event2.new_state = {"node-1": {"coins": 2}}
	_assert_true(log.record_world_edit(event2), "record_world_edit(event2) should return true")

	var current_state := log.get_current_state(world_id)
	_assert_dictionary(current_state, "get_current_state(world)")
	_assert_true(
		current_state.get("node-1", {}).get("coins", -1) == 2,
		"Replay state should reflect latest world patch"
	)

	var undo_result := log.undo(world_id)
	_assert_dictionary(undo_result, "undo(world)")
	_assert_true(undo_result.get("ok", false), "undo(world) should succeed when entries exist")
	var undo_state: Dictionary = undo_result.get("state", {})
	_assert_true(
		undo_state.get("node-1", {}).get("coins", -1) == 1,
		"undo(world) should replay to previous state"
	)

	var redo_result := log.redo(world_id)
	_assert_dictionary(redo_result, "redo(world)")
	_assert_true(redo_result.get("ok", false), "redo(world) should succeed after undo")
	var redo_state: Dictionary = redo_result.get("state", {})
	_assert_true(
		redo_state.get("node-1", {}).get("coins", -1) == 2,
		"redo(world) should replay forward to latest state"
	)

	var checkpoint_id := log.create_checkpoint(world_id, "safe-state")
	_assert_true(
		not checkpoint_id.is_empty(),
		"create_checkpoint(world) should return checkpoint id"
	)

	var event3 := WorldEditedEvent.new(world_id, "property_changed", "kid-1", "2026-03-02T12:00:02Z")
	event3.event_id = "e3"
	event3.target_node_id = "node-1"
	event3.previous_state = {"node-1": {"coins": 2}}
	event3.new_state = {"node-1": {"coins": 3}}
	log.record_world_edit(event3)
	var advanced_state := log.get_current_state(world_id)
	_assert_true(
		advanced_state.get("node-1", {}).get("coins", -1) == 3,
		"State should advance after additional event"
	)

	var restored := log.restore_checkpoint(world_id, checkpoint_id)
	_assert_true(restored.get("ok", false), "restore_checkpoint(world) should succeed")
	var restored_state: Dictionary = restored.get("state", {})
	_assert_true(
		restored_state.get("node-1", {}).get("coins", -1) == 2,
		"restore_checkpoint(world) should restore checkpoint state"
	)

	var ai_stream := "ai-action-1"
	_assert_true(
		log.record_ai_patch(ai_stream, {"difficulty": "normal"}, {}, "parent-1", "2026-03-02T12:00:03Z"),
		"record_ai_patch(base) should return true"
	)
	var ai_cp := log.create_checkpoint(ai_stream, "before-harder")
	_assert_true(not ai_cp.is_empty(), "create_checkpoint(ai) should return checkpoint id")
	_assert_true(
		log.record_ai_patch(
			ai_stream,
			{"difficulty": "easy"},
			{"difficulty": "normal"},
			"parent-1",
			"2026-03-02T12:00:04Z"
		),
		"record_ai_patch(update) should return true"
	)

	var ai_state := log.get_current_state(ai_stream)
	_assert_true(
		ai_state.get("difficulty", "") == "easy",
		"AI stream state should track latest patch"
	)
	var ai_undo := log.undo(ai_stream)
	_assert_true(ai_undo.get("ok", false), "undo(ai_stream) should succeed")
	var ai_undo_state: Dictionary = ai_undo.get("state", {})
	_assert_true(
		ai_undo_state.get("difficulty", "") == "normal",
		"undo(ai_stream) should replay to checkpoint baseline"
	)

	return _build_result("EventSourcedActionLog")
