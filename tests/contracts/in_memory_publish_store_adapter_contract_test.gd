class_name InMemoryPublishStoreAdapterContractTest
extends PortContractTest


func run() -> Dictionary:
	_reset()
	var script_variant: Variant = load("res://src/adapters/outbound/in_memory_publish_store.gd")
	_assert_true(script_variant is Script, "InMemoryPublishStore script should load")
	if not (script_variant is Script):
		return _build_result("InMemoryPublishStoreAdapter")
	var store: RefCounted = (script_variant as Script).new().setup()

	var req1 := PublishRequest.new("project-1", "world-a")
	req1.request_id = "req-1"
	req1.state = PublishRequest.PublishState.PENDING_REVIEW
	_assert_true(bool(store.call("save_request", req1)), "save_request should persist valid request")

	var req2 := PublishRequest.new("project-1", "world-b")
	req2.request_id = "req-2"
	req2.state = PublishRequest.PublishState.PUBLISHED
	_assert_true(bool(store.call("save_request", req2)), "save_request should persist second request")

	var loaded: Variant = store.call("load_request", "req-1")
	_assert_true(loaded is PublishRequest, "load_request should return PublishRequest")
	if loaded is PublishRequest:
		_assert_true((loaded as PublishRequest).world_id == "world-a", "load_request should preserve world id")

	var project_rows: Variant = store.call("list_requests_for_project", "project-1")
	_assert_true(project_rows is Array and project_rows.size() == 2, "list_requests_for_project should return both rows")

	var published_rows: Variant = store.call("list_published")
	_assert_true(published_rows is Array and published_rows.size() == 1, "list_published should filter by published state")
	if published_rows is Array and published_rows.size() == 1:
		var only: Variant = published_rows[0]
		if only is PublishRequest:
			_assert_true((only as PublishRequest).request_id == "req-2", "Published row should match req-2")

	_assert_false(bool(store.call("save_request", null)), "save_request(null) should be rejected")
	_assert_null(store.call("load_request", ""), "load_request(empty) should return null")

	return _build_result("InMemoryPublishStoreAdapter")
