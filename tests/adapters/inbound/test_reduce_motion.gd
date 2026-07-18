extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var root := Control.new()
	get_root().add_child(root)
	
	# Test 1: GodotAccessibilityAdapter implementation
	var adapter := GodotAccessibilityAdapter.new().setup(root)
	
	# Initially disabled
	if adapter.is_reduce_motion_enabled():
		print("FAIL: GodotAccessibilityAdapter reduce motion should be disabled by default")
		_cleanup_and_exit(root, 1)
		return
	
	# Enable and verify
	adapter.set_reduce_motion(true)
	if not adapter.is_reduce_motion_enabled():
		print("FAIL: GodotAccessibilityAdapter reduce motion should be enabled")
		_cleanup_and_exit(root, 1)
		return
	
	# Test 2: Global instance access pattern
	# The adapter sets itself as the global instance via AccessibilityPolicyPort._global_instance
	# Verify that a new port instance can delegate to the global instance
	var new_port := AccessibilityPolicyPort.new()
	if not new_port.is_reduce_motion_enabled():
		print("FAIL: New port instance should delegate to global instance (adapter has reduce_motion=true)")
		_cleanup_and_exit(root, 1)
		return
	
	# Test 3: Verify disable works
	adapter.set_reduce_motion(false)
	if adapter.is_reduce_motion_enabled():
		print("FAIL: Reduce motion should be disabled after set_reduce_motion(false)")
		_cleanup_and_exit(root, 1)
		return
	
	# Test 4: Verify delegation works for disabled state too
	var another_port := AccessibilityPolicyPort.new()
	if another_port.is_reduce_motion_enabled():
		print("FAIL: Port instance should delegate to global instance (adapter has reduce_motion=false)")
		_cleanup_and_exit(root, 1)
		return
	
	# Test 5: Toggle back to enabled and verify through delegation
	adapter.set_reduce_motion(true)
	var final_port := AccessibilityPolicyPort.new()
	if not final_port.is_reduce_motion_enabled():
		print("FAIL: Final port instance should see enabled state through global instance")
		_cleanup_and_exit(root, 1)
		return
	
	print("REDUCE_MOTION_TEST: PASS")
	_cleanup_and_exit(root, 0)


func _cleanup_and_exit(root: Control, code: int) -> void:
	if root != null:
		root.queue_free()
	quit(code)
