class_name CloudProjectSyncPortContractTest
extends PortContractTest


func run() -> Dictionary:
	_reset()
	var script_variant: Variant = load("res://src/ports/outbound/cloud_project_sync_port.gd")
	_assert_true(script_variant is Script, "CloudProjectSyncPort script should load")
	if not (script_variant is Script):
		return _build_result("CloudProjectSyncPort")
	var port: RefCounted = (script_variant as Script).new()

	_assert_has_method(port, "sync_project")
	_assert_has_method(port, "is_available")

	var project := Project.new("project-1", "Autosave")
	var sync_result: Variant = port.call("sync_project", project)
	_assert_false(sync_result, "Default sync_project should return false")
	_assert_false(bool(port.call("is_available")), "Default cloud sync port should report unavailable")

	return _build_result("CloudProjectSyncPort")
