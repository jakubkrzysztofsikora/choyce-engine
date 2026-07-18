## Runtime contract test for VS-048 adventure music state transitions.
##
## Verifies that GameplayRuntime._tick_adventure_music() drives AudioBank through
## the three required states: exploration, nearby danger, and driving. The test
## subclasses GameplayRuntime to skip the heavy scene setup and stubs the audio
## bank as a simple state recorder so no real audio streams are needed.
extends SceneTree

const GameplayRuntime = preload("res://src/adapters/inbound/gameplay/gameplay_runtime.gd")
const PlayerController = preload("res://src/adapters/inbound/gameplay/player_controller.gd")
const VehicleBase = preload("res://src/adapters/inbound/gameplay/vehicles/vehicle_base.gd")
const EnemyController = preload("res://src/adapters/inbound/gameplay/enemy_controller.gd")
const EnemyDefinition = preload("res://src/domain/combat/enemy_definition.gd")
const HealthState = preload("res://src/domain/combat/health_state.gd")
const World = preload("res://src/domain/world_authoring/world.gd")
const Session = preload("res://src/domain/gameplay/session.gd")
const SandboxState = preload("res://src/domain/gameplay/sandbox_state.gd")


## Skip the full Adventure scene composition; we only need the music tick path.
class TestGameplayRuntime extends GameplayRuntime:
	func _ready() -> void:
		pass


class TestPlayerController extends PlayerController:
	func _ready() -> void:
		pass


class TestVehicle extends VehicleBase:
	func _ready() -> void:
		pass


var _failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _assert(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		print("FAIL: %s" % message)
		_failures += 1


func _run() -> void:
	var bank: Node = get_root().get_node_or_null("AudioBank")
	if bank == null:
		push_error("AudioBank autoload not found")
		quit(1)
		return

	var runtime := TestGameplayRuntime.new()
	get_root().add_child(runtime)
	await process_frame

	var player := TestPlayerController.new()
	player.name = "PlayerController"
	runtime.add_child(player)
	await process_frame
	player.global_position = Vector3.ZERO
	runtime._player_controller = player

	# exploration: no vehicle, no nearby enemy
	runtime._adventure_music_state = ""
	bank._adventure_music_state = ""
	runtime._tick_adventure_music()
	_assert(runtime._adventure_music_state == "explore",
		"exploration state selected with no vehicle or nearby enemy")
	_assert(bank._adventure_music_state == "explore",
		"audio bank is set to explore")

	# danger: alive enemy within 15 m
	var enemy: EnemyController = await _spawn_enemy(runtime, player, Vector3(5, 0, 0))
	runtime._adventure_music_state = ""
	bank._adventure_music_state = ""
	runtime._tick_adventure_music()
	_assert(runtime._adventure_music_state == "danger",
		"danger state selected when alive enemy is within 15 m")
	_assert(bank._adventure_music_state == "danger",
		"audio bank is set to danger")

	# danger falls back to explore when enemy is too far
	enemy.global_position = Vector3(20, 0, 0)
	runtime._adventure_music_state = ""
	bank._adventure_music_state = ""
	runtime._tick_adventure_music()
	_assert(runtime._adventure_music_state == "explore",
		"explore state reselected when nearest enemy is beyond 15 m")

	# danger falls back to explore when enemy is defeated
	enemy.global_position = Vector3(5, 0, 0)
	enemy.health.is_alive = false
	runtime._adventure_music_state = ""
	bank._adventure_music_state = ""
	runtime._tick_adventure_music()
	_assert(runtime._adventure_music_state == "explore",
		"explore state reselected when nearby enemy is defeated")

	# drive: active vehicle takes priority over nearby enemy
	enemy.health.is_alive = true
	var vehicle := TestVehicle.new()
	vehicle.name = "TestVehicle"
	vehicle.is_active = true
	vehicle.current_player = player
	runtime.add_child(vehicle)
	await process_frame
	runtime._active_vehicle = vehicle
	runtime._adventure_music_state = ""
	bank._adventure_music_state = ""
	runtime._tick_adventure_music()
	_assert(runtime._adventure_music_state == "drive",
		"drive state selected when vehicle is active")
	_assert(bank._adventure_music_state == "drive",
		"audio bank is set to drive")

	# drive returns to explore when vehicle is exited and no danger remains
	enemy.health.is_alive = false
	runtime._active_vehicle = null
	runtime._adventure_music_state = ""
	bank._adventure_music_state = ""
	runtime._tick_adventure_music()
	_assert(runtime._adventure_music_state == "explore",
		"explore state reselected when active vehicle is cleared")

	# no duplicate requests when state hasn't changed
	runtime._adventure_music_state = "explore"
	bank._adventure_music_state = "explore"
	runtime._tick_adventure_music()
	_assert(bank._adventure_music_state == "explore",
		"unchanged explore state remains stable")

	runtime.queue_free()
	quit(_failures)


func _spawn_enemy(runtime: Node, player: Node3D, pos: Vector3) -> EnemyController:
	var enemy := EnemyController.new()
	var def := EnemyDefinition.slime_green()
	enemy.setup(def, player)
	enemy.add_to_group("enemies")
	runtime.add_child(enemy)
	await process_frame
	enemy.global_position = pos
	return enemy
