class_name InMemoryScriptRepositoryAdapterContractTest
extends PortContractTest


func run() -> Dictionary:
	_reset()
	var repo := InMemoryScriptRepository.new()

	_assert_has_method(repo, "load_script")
	_assert_has_method(repo, "save_script")
	_assert_has_method(repo, "exists")

	_assert_true(
		repo.save_script("project-1", "scripts/main.gd", "print('hello')"),
		"save_script should persist script source"
	)
	_assert_true(
		repo.exists("project-1", "scripts/main.gd"),
		"exists should return true for persisted script"
	)
	_assert_true(
		repo.load_script("project-1", "scripts/main.gd") == "print('hello')",
		"load_script should return persisted source"
	)
	_assert_false(
		repo.save_script("", "scripts/main.gd", "x"),
		"save_script should reject empty project id"
	)
	_assert_false(
		repo.exists("project-1", ""),
		"exists should reject empty script path"
	)

	return _build_result("InMemoryScriptRepositoryAdapter")
