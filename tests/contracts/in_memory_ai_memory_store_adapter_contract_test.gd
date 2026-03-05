class_name InMemoryAIMemoryStoreAdapterContractTest
extends PortContractTest


func run() -> Dictionary:
	_reset()
	var store := InMemoryAIMemoryStore.new()

	_assert_has_method(store, "append_session_entry")
	_assert_has_method(store, "list_session_entries")
	_assert_has_method(store, "save_project_summary")
	_assert_has_method(store, "load_project_summary")

	_assert_true(
		store.append_session_entry("session-1", {"seq": 1, "content": "A"}),
		"append_session_entry should store valid entry"
	)
	_assert_true(
		store.append_session_entry("session-1", {"seq": 2, "content": "B"}),
		"append_session_entry should allow subsequent entries"
	)

	var entries := store.list_session_entries("session-1", 10)
	_assert_true(entries.size() == 2, "list_session_entries should return appended entries")
	_assert_true(
		str(entries[1].get("content", "")) == "B",
		"list_session_entries should preserve append order"
	)

	var limited := store.list_session_entries("session-1", 1)
	_assert_true(limited.size() == 1, "list_session_entries should enforce limit")
	_assert_true(
		str(limited[0].get("content", "")) == "B",
		"list_session_entries should return most recent entries for limited queries"
	)

	_assert_true(
		store.save_project_summary("project-1", {"summary_text": "Krotkie podsumowanie"}),
		"save_project_summary should persist summary"
	)
	var summary := store.load_project_summary("project-1")
	_assert_true(
		str(summary.get("summary_text", "")) == "Krotkie podsumowanie",
		"load_project_summary should return persisted summary"
	)

	_assert_false(
		store.append_session_entry("", {"seq": 3}),
		"append_session_entry should reject empty session id"
	)
	_assert_false(
		store.save_project_summary("", {"summary_text": "x"}),
		"save_project_summary should reject empty project id"
	)

	return _build_result("InMemoryAIMemoryStoreAdapter")
