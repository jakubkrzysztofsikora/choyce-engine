extends SceneTree

const TestScn = preload("res://tests/application/test_manage_family_session_service.gd")

func _init() -> void:
	print("Running ManageFamilySessionService tests...")
	var test = TestScn.new()
	var result = test.run()
	
	print("Checks run: %d" % result.get("checks_run", 0))
	if result.get("passed", false):
		print("PASS ManageFamilySessionService tests")
		quit(0)
	else:
		print("FAIL ManageFamilySessionService tests")
		for f in result.get("failures", []):
			print("  - %s" % f)
		quit(1)
