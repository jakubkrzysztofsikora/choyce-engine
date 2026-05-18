extends SceneTree

const TestScn = preload("res://tests/application/test_e2e_mvp_flows.gd")

func _init() -> void:
	print("Running E2E MVP flow suite...")
	var test = TestScn.new()
	var result = test.run()
	
	print("Checks run: %d" % result.get("checks_run", 0))
	if result.get("passed", false):
		print("PASS E2E test")
		quit(0)
	else:
		print("FAIL E2E test")
		for f in result.get("failures", []):
			print("  - %s" % f)
		quit(1)
