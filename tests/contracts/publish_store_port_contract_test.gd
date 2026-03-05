class_name PublishStorePortContractTest
extends PortContractTest


func run() -> Dictionary:
	_reset()
	var port := PublishStorePort.new()

	_assert_has_method(port, "save_request")
	_assert_has_method(port, "load_request")
	_assert_has_method(port, "list_requests_for_project")
	_assert_has_method(port, "list_published")

	var req := PublishRequest.new("project-1", "world-1")
	req.request_id = "req-1"
	_assert_false(
		port.save_request(req),
		"Default PublishStorePort.save_request should return false"
	)
	_assert_null(
		port.load_request("req-1"),
		"Default PublishStorePort.load_request should return null"
	)
	_assert_array(
		port.list_requests_for_project("project-1"),
		"Default PublishStorePort.list_requests_for_project should return Array"
	)
	_assert_array(
		port.list_published(),
		"Default PublishStorePort.list_published should return Array"
	)

	return _build_result("PublishStorePort")
