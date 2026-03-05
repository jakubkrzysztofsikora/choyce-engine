class_name ProjectStorePortContractTest
extends PortContractTest

class NullLoadProjectStorePort:
	extends ProjectStorePort

	func load_project(project_id: String) -> Project:
		return null


func run() -> Dictionary:
	_reset()
	var port := ProjectStorePort.new()

	_assert_has_method(port, "save_project")
	_assert_has_method(port, "load_project")
	_assert_has_method(port, "list_projects")

	var project := Project.new("proj-1", "Projekt testowy")
	var save_result := port.save_project(project)
	_assert_bool(save_result, "ProjectStorePort.save_project(project)")

	var save_null_result := port.save_project(null)
	_assert_bool(save_null_result, "ProjectStorePort.save_project(null)")

	var loaded := port.load_project("proj-1")
	_assert_project(loaded, "ProjectStorePort.load_project(project_id)")

	var loaded_empty := port.load_project("")
	_assert_project(loaded_empty, "ProjectStorePort.load_project(empty_id)")

	var null_return_port := NullLoadProjectStorePort.new()
	var loaded_null := null_return_port.load_project("missing")
	_assert_null(
		loaded_null,
		"ProjectStorePort.load_project(missing) null-adapter scenario"
	)

	var projects := port.list_projects()
	_assert_array(projects, "ProjectStorePort.list_projects()")

	return _build_result("ProjectStorePort")
