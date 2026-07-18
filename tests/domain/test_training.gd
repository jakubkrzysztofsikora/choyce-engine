## Unit tests for Training domain class.
## Run: godot --headless --script tests/domain/test_training.gd
##
class_name TestTraining
extends SceneTree

const _TRAINING := preload("res://src/domain/gameplay/training.gd")


func _init() -> void:
	var failures: Array = []

	_test_perform(failures)
	_test_cooldown(failures)
	_test_reverse(failures)
	_test_persistence(failures)
	_test_invalid_type(failures)
	_test_level_percent(failures)
	_test_is_at_max(failures)

	if failures.is_empty():
		print("[test_training] OK")
		quit(0)
	else:
		printerr("[test_training] FAIL ", failures.size())
		for f in failures:
			printerr("  - ", f)
		quit(1)


func _test_perform(failures: Array) -> void:
	var training := _TRAINING.new()
	var initial_level: int = training.get_body_level()
	if initial_level != 0:
		failures.append("Should start at level 0")
	
	# Perform training
	var result: bool = training.perform_training("jump")
	if result != true:
		failures.append("Should be able to perform training")
	if training.total_sessions() != 1:
		failures.append("Should have 1 session")
	
	# Body level should still be 0 (needs 5 sessions to level up)
	if training.get_body_level() != 0:
		failures.append("Body level should still be 0")
	
	# Perform 4 more training sessions
	for i in range(4):
		training.perform_training("run")
	
	# Should now have 5 sessions and level 1
	if training.total_sessions() != 5:
		failures.append("Should have 5 sessions")
	if training.get_body_level() != 1:
		failures.append("Body level should be 1 after 5 sessions")


func _test_cooldown(failures: Array) -> void:
	# Cooldown removed from domain layer - both trainings should succeed
	var training := _TRAINING.new()
	
	# First training should succeed
	var result: bool = training.perform_training("jump")
	if result != true:
		failures.append("First training should succeed")
	
	# Second training should also succeed (no cooldown in domain)
	result = training.perform_training("run")
	if result != true:
		failures.append("Second training should succeed (no cooldown)")


func _test_reverse(failures: Array) -> void:
	var training := _TRAINING.new()
	
	# Level up to level 2 (10 sessions)
	for i in range(10):
		training.perform_training("jump")
	
	if training.get_body_level() != 2:
		failures.append("Should be at level 2")
	
	# Reverse training
	var previous_level: int = training.reverse_training()
	if previous_level != 2:
		failures.append("Should return previous level 2")
	if training.get_body_level() != 1:
		failures.append("Should be back at level 1")
	
	# Reverse again
	previous_level = training.reverse_training()
	if previous_level != 1:
		failures.append("Should return previous level 1")
	if training.get_body_level() != 0:
		failures.append("Should be back at level 0")


func _test_persistence(failures: Array) -> void:
	var training := _TRAINING.new()
	# Perform some training
	for i in range(7):
		training.perform_training("jump")
	
	# Serialize to dict
	var data := training.to_dict()
	if not data.has("body_level"):
		failures.append("Should have body_level")
	if not data.has("training_sessions"):
		failures.append("Should have training_sessions")
	
	# Deserialize from dict
	var training2 := _TRAINING.from_dict(data)
	if training2.get_body_level() != training.get_body_level():
		failures.append("Body level should match")
	if training2.total_sessions() != training.total_sessions():
		failures.append("Total sessions should match")


func _test_invalid_type(failures: Array) -> void:
	var training := _TRAINING.new()
	
	# Invalid training type should fail
	var result: bool = training.perform_training("invalid_type")
	if result != false:
		failures.append("Invalid training type should fail")


func _test_level_percent(failures: Array) -> void:
	var training := _TRAINING.new()
	if training.get_body_level_percent() != 0.0:
		failures.append("Percent should be 0 at level 0")
	
	# Level up
	for i in range(5):
		training.perform_training("jump")
	
	if training.get_body_level() != 1:
		failures.append("Should be at level 1")
	if training.get_body_level_percent() != 20.0:
		failures.append("Percent should be 20 at level 1")


func _test_is_at_max(failures: Array) -> void:
	var training := _TRAINING.new()
	if training.is_at_max() != false:
		failures.append("Should not be at max initially")
	
	# Level up to max
	for i in range(30):  # 30 sessions = level 6 (but max is 5)
		training.perform_training("jump")
	
	if training.get_body_level() != 5:
		failures.append("Should be at max level 5")
	if training.is_at_max() != true:
		failures.append("Should be at max")
