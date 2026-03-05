class_name DeterministicToolExecutionGatewayContractTest
extends PortContractTest


class MockHandlers:
	extends RefCounted

	var scene_calls: int = 0
	var asset_calls: int = 0
	var rollback_calls: int = 0

	func execute_scene(_invocation: ToolInvocation, _context: Dictionary = {}) -> Dictionary:
		scene_calls += 1
		return {
			"ok": true,
			"undo_token": {
				"tool_name": "scene_edit",
				"token_id": "scene_undo_%d" % scene_calls,
			},
		}

	func execute_asset(_invocation: ToolInvocation, _context: Dictionary = {}) -> Dictionary:
		asset_calls += 1
		return {
			"ok": true,
			"undo_token": {
				"tool_name": "asset_import",
				"token_id": "asset_undo_%d" % asset_calls,
			},
		}

	func rollback_scene(_undo_token: Dictionary, _context: Dictionary = {}) -> bool:
		rollback_calls += 1
		return true


func run() -> Dictionary:
	_reset()

	var registry := AIToolRegistry.new()
	var gateway := DeterministicToolExecutionGateway.new().setup(registry)
	var handlers := MockHandlers.new()

	_assert_true(
		gateway.register_handler(
			"scene_edit",
			Callable(handlers, "execute_scene"),
			Callable(handlers, "rollback_scene")
		),
		"Gateway should register scene_edit handler"
	)
	_assert_true(
		gateway.register_handler("asset_import", Callable(handlers, "execute_asset")),
		"Gateway should register asset_import handler"
	)
	_assert_true(
		not gateway.register_handler("nonexistent_tool", Callable(handlers, "execute_scene")),
		"Gateway should reject handler registration for unknown tools"
	)

	var first_scene := gateway.execute(
		ToolInvocation.new("scene_edit", {"op": "move", "dx": 1}, "scene-idem-1"),
		{"actor_id": "kid-1"}
	)
	_assert_true(first_scene.get("ok", false), "First idempotent scene_edit execution should succeed")
	_assert_true(handlers.scene_calls == 1, "First idempotent execution should call handler once")

	var replay_scene := gateway.execute(
		ToolInvocation.new("scene_edit", {"op": "move", "dx": 1}, "scene-idem-1"),
		{"actor_id": "kid-1"}
	)
	_assert_true(replay_scene.get("ok", false), "Replay of same idempotent invocation should succeed")
	_assert_true(
		replay_scene.get("idempotent_replay", false),
		"Replay should return idempotent_replay marker"
	)
	_assert_true(handlers.scene_calls == 1, "Replay should not invoke handler twice")

	var conflicting_replay := gateway.execute(
		ToolInvocation.new("scene_edit", {"op": "paint", "color": "zielony"}, "scene-idem-1"),
		{"actor_id": "kid-1"}
	)
	_assert_true(
		not conflicting_replay.get("ok", false),
		"Reusing idempotency key with different args should fail"
	)

	var first_asset := gateway.execute(
		ToolInvocation.new("asset_import", {"asset_ref": "res://coin.glb"}, "asset-1"),
		{"actor_id": "parent-1"}
	)
	_assert_true(first_asset.get("ok", false), "First non-idempotent asset_import should succeed")
	_assert_true(handlers.asset_calls == 1, "Asset handler should be called once")

	var replay_asset := gateway.execute(
		ToolInvocation.new("asset_import", {"asset_ref": "res://coin.glb"}, "asset-1"),
		{"actor_id": "parent-1"}
	)
	_assert_true(
		not replay_asset.get("ok", false),
		"Non-idempotent invocation replay should fail"
	)
	_assert_true(handlers.asset_calls == 1, "Rejected replay should not call asset handler twice")

	var nondeterministic := gateway.execute(
		ToolInvocation.new(
			"scene_edit",
			{"callback": Callable(self, "run")},
			"scene-bad-2"
		),
		{}
	)
	_assert_true(
		not nondeterministic.get("ok", false),
		"Gateway should reject non-deterministic arguments"
	)

	var undo_token: Dictionary = first_scene.get("undo_token", {})
	var rollback_ok := gateway.rollback(undo_token, {"actor_id": "kid-1"})
	_assert_true(rollback_ok, "Gateway rollback should call registered rollback handler")
	_assert_true(handlers.rollback_calls == 1, "Rollback handler should be called once")

	return _build_result("DeterministicToolExecutionGateway")
