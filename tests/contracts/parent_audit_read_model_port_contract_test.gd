class_name ParentAuditReadModelPortContractTest
extends PortContractTest


func run() -> Dictionary:
	_reset()
	var read_model := ParentAuditReadModel.new()

	_assert_has_method(read_model, "get_timeline")
	_assert_has_method(read_model, "get_interventions")
	_assert_has_method(read_model, "update_from_event")

	var timeline := read_model.get_timeline("parent-1", "", "", 20)
	_assert_array(timeline, "ParentAuditReadModel.get_timeline()")

	var interventions := read_model.get_interventions("parent-1", 10)
	_assert_array(interventions, "ParentAuditReadModel.get_interventions()")

	read_model.update_from_event(
		SafetyInterventionTriggeredEvent.new("decision-1", "kid-1", "2026-03-02T12:00:00Z")
	)
	_note_check()

	return _build_result("ParentAuditReadModel")
