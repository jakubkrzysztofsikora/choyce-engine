class_name ScriptRepositoryPortContractTest
extends PortContractTest


func run() -> Dictionary:
	_reset()
	var port := ScriptRepositoryPort.new()

	_assert_has_method(port, "load_script")
	_assert_has_method(port, "save_script")
	_assert_has_method(port, "exists")

	var loaded := port.load_script("project-1", "scripts/main.gd")
	_assert_string(loaded, "ScriptRepositoryPort.load_script(project_id, script_path)")

	var saved := port.save_script("project-1", "scripts/main.gd", "pass")
	_assert_false(saved, "ScriptRepositoryPort.save_script(project_id, script_path, code)")

	var exists := port.exists("project-1", "scripts/main.gd")
	_assert_false(exists, "ScriptRepositoryPort.exists(project_id, script_path)")

	return _build_result("ScriptRepositoryPort")
