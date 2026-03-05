class_name AIMemoryStorePortContractTest
extends PortContractTest


func run() -> Dictionary:
	_reset()
	var port := AIMemoryStorePort.new()

	_assert_has_method(port, "append_session_entry")
	_assert_has_method(port, "list_session_entries")
	_assert_has_method(port, "save_project_summary")
	_assert_has_method(port, "load_project_summary")

	var appended := port.append_session_entry("session-1", {"text": "hej"})
	_assert_false(appended, "AIMemoryStorePort.append_session_entry(session_id, entry)")

	var listed := port.list_session_entries("session-1", 10)
	_assert_array(listed, "AIMemoryStorePort.list_session_entries(session_id, limit)")

	var saved := port.save_project_summary("project-1", {"summary_text": "x"})
	_assert_false(saved, "AIMemoryStorePort.save_project_summary(project_id, summary)")

	var summary := port.load_project_summary("project-1")
	_assert_dictionary(summary, "AIMemoryStorePort.load_project_summary(project_id)")

	return _build_result("AIMemoryStorePort")
