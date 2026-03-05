class_name KidStatusReadModelPortContractTest
extends PortContractTest


func run() -> Dictionary:
	_reset()
	var read_model := KidStatusReadModel.new()

	_assert_has_method(read_model, "get_project_status")
	_assert_has_method(read_model, "list_recent_projects")
	_assert_has_method(read_model, "update_from_event")

	var status := read_model.get_project_status("project-1", "kid-1")
	_assert_dictionary(status, "KidStatusReadModel.get_project_status()")

	var recent := read_model.list_recent_projects("kid-1", 5)
	_assert_array(recent, "KidStatusReadModel.list_recent_projects()")

	read_model.update_from_event(WorldEditedEvent.new("w1", "node_added", "kid-1", "2026-03-02T12:00:00Z"))
	_note_check()

	return _build_result("KidStatusReadModel")
