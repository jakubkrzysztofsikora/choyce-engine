class_name AIPerformanceReadModelPortContractTest
extends PortContractTest


func run() -> Dictionary:
	_reset()
	var read_model := AIPerformanceReadModel.new()

	_assert_has_method(read_model, "get_metrics")
	_assert_has_method(read_model, "get_tool_statistics")
	_assert_has_method(read_model, "update_from_event")

	var metrics := read_model.get_metrics("7d")
	_assert_dictionary(metrics, "AIPerformanceReadModel.get_metrics()")

	var tool_stats := read_model.get_tool_statistics(25)
	_assert_array(tool_stats, "AIPerformanceReadModel.get_tool_statistics()")

	read_model.update_from_event(
		AIAssistanceRequestedEvent.new("session-1", "kid-1", "2026-03-02T12:00:00Z")
	)
	_note_check()

	return _build_result("AIPerformanceReadModel")
