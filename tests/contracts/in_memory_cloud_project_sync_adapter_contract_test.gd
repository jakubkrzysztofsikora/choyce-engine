class_name InMemoryCloudProjectSyncAdapterContractTest
extends PortContractTest


func run() -> Dictionary:
	_reset()
	var script_variant: Variant = load("res://src/adapters/outbound/in_memory_cloud_project_sync.gd")
	_assert_true(script_variant is Script, "InMemoryCloudProjectSync script should load")
	if not (script_variant is Script):
		return _build_result("InMemoryCloudProjectSyncAdapter")
	var adapter: RefCounted = (script_variant as Script).new().setup()

	_assert_true(bool(adapter.call("is_available")), "In-memory cloud adapter should be available by default")
	_assert_true(int(adapter.call("get_sync_count")) == 0, "Fresh adapter should have zero syncs")

	var project := Project.new("project-sync-1", "Sync Test")
	_assert_true(bool(adapter.call("sync_project", project)), "sync_project should succeed for valid project")
	_assert_true(int(adapter.call("get_sync_count")) == 1, "Sync count should increment")
	_assert_true(bool(adapter.call("has_synced", "project-sync-1")), "Adapter should track synced project IDs")

	var ids: Variant = adapter.call("get_synced_project_ids")
	_assert_true(ids.size() == 1 and ids[0] == "project-sync-1", "Sync order should contain project id")

	_assert_false(bool(adapter.call("sync_project", null)), "sync_project(null) should be rejected")
	_assert_false(bool(adapter.call("sync_project", Project.new("", "No ID"))), "sync_project should reject empty project id")

	var disabled: RefCounted = (script_variant as Script).new().setup(false)
	_assert_false(bool(disabled.call("is_available")), "Disabled adapter should report unavailable")
	_assert_false(bool(disabled.call("sync_project", project)), "Disabled adapter should reject sync attempts")

	return _build_result("InMemoryCloudProjectSyncAdapter")
