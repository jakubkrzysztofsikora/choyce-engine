## Regression coverage for VS-048 camp civilians:
## starter-camp residents spawn even with an empty NPC roster, are grounded
## human characters with collision, wander loops, and safe interaction lines.
extends SceneTree

const GameplayRuntime = preload("res://src/adapters/inbound/gameplay/gameplay_runtime.gd")
const NPCCharacter = preload("res://src/domain/world_authoring/npc_character.gd")
const PlayerController = preload("res://src/adapters/inbound/gameplay/player_controller.gd")


## The focused camp tests exercise only the NPC spawn and interaction adapter,
## so avoid constructing the complete Adventure scene tree (world, player, SFX).
class TestGameplayRuntime extends GameplayRuntime:
	func _ready() -> void:
		pass


class TestPlayerController extends PlayerController:
	func _ready() -> void:
		pass


var _exit_code := 0


func _init() -> void:
	call_deferred("_run")


func _assert(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		print("FAIL: %s" % message)
		_exit_code = 1


func _run() -> void:
	var runtime := TestGameplayRuntime.new()
	get_root().add_child(runtime)
	await process_frame

	var player := TestPlayerController.new()
	player.name = "Player"
	runtime.add_child(player)
	runtime._player_controller = player

	var hud := CanvasLayer.new()
	hud.name = "HUD"
	runtime.add_child(hud)

	runtime.setup_npcs([])
	await process_frame
	runtime._spawn_npcs()
	await process_frame

	_assert(runtime._npc_root != null and is_instance_valid(runtime._npc_root),
		"NPC root exists after spawn")
	var root: Node3D = runtime._npc_root
	_assert(root.get_child_count() == 3,
		"starter-camp residents spawn even with empty Adventure roster")

	var expected := {"npc_hania": true, "npc_bartek": true, "npc_lena": true}
	for child in root.get_children():
		var npc_id: String = String(child.get_meta("npc_id", ""))
		_assert(npc_id in expected, "resident has expected id %s" % npc_id)
		_assert(child is StaticBody3D, "%s is a grounded StaticBody3D" % npc_id)
		_assert(child.has_meta("npc_role"), "%s has role meta" % npc_id)
		var role: String = child.get_meta("npc_role")
		_assert(role == NPCCharacter.ROLE_GUIDE or role == NPCCharacter.ROLE_VENDOR,
			"%s has a peaceful role" % npc_id)
		_assert(child.has_meta("npc_base_y"), "%s has base_y meta" % npc_id)
		_assert(child.has_meta("npc_wander_origin") and child.has_meta("npc_wander_radius") \
			and child.has_meta("npc_wander_speed") and child.has_meta("npc_wander_phase"),
			"%s has complete wander metadata" % npc_id)
		var radius: float = float(child.get_meta("npc_wander_radius"))
		_assert(radius > 0.0, "%s has positive wander radius" % npc_id)
		var base_y: float = float(child.get_meta("npc_base_y"))
		_assert(is_finite(base_y), "%s base_y is finite" % npc_id)
		var collision := child.get_node_or_null("CollisionShape3D") as CollisionShape3D
		_assert(collision != null and collision.shape is CapsuleShape3D,
			"%s has a CapsuleShape3D collision body" % npc_id)
		var trigger := child.get_node_or_null("GreetTrigger") as Area3D
		_assert(trigger != null and trigger.get_child_count() >= 1,
			"%s has an interaction trigger" % npc_id)
		var visual := child.get_child(0) as Node3D
		_assert(visual != null and visual.get_child_count() > 0,
			"%s has a non-empty visual node" % npc_id)
		var greeting: String = String(child.get_meta("greeting_pl", ""))
		_assert(not greeting.is_empty(), "%s has a greeting line" % npc_id)
		var reaction: Variant = child.get_meta("fart_reaction", {})
		_assert(reaction is Dictionary and not String((reaction as Dictionary).get("line", "")).is_empty(),
			"%s has a safe fart-reaction line" % npc_id)

	await _test_wander_loop_keeps_ground(runtime)
	await _test_interaction_trigger_shows_dialogue(runtime)

	runtime.queue_free()
	quit(_exit_code)


func _test_wander_loop_keeps_ground(runtime) -> void:
	var root: Node3D = runtime._npc_root
	var body := root.get_child(0) as StaticBody3D
	var origin: Vector3 = body.global_position
	var wander_origin: Vector3 = body.get_meta("npc_wander_origin") as Vector3
	var base_y: float = float(body.get_meta("npc_base_y"))
	var radius: float = float(body.get_meta("npc_wander_radius"))

	var end := origin
	var elapsed := 0.0
	while elapsed < 1.0:
		runtime._tick_npcs(0.05)
		await create_timer(0.05).timeout
		elapsed += 0.05
		end = body.global_position

	var horizontal_offset := Vector3(end.x - wander_origin.x, 0.0, end.z - wander_origin.z)
	var displacement := horizontal_offset.length()
	_assert(displacement <= radius + 0.2, "civilian stays within wander radius")
	_assert(end.y == base_y, "civilian stays at authored terrain height")
	_assert(not end.is_equal_approx(origin), "civilian changes position during wander loop")


func _test_interaction_trigger_shows_dialogue(runtime) -> void:
	var root: Node3D = runtime._npc_root
	var body := root.get_child(0) as StaticBody3D
	var npc_id: String = String(body.get_meta("npc_id", ""))
	var name_pl: String = String(body.get_meta("npc_name_pl", ""))
	var greeting: String = String(body.get_meta("greeting_pl", ""))

	runtime._on_npc_trigger_entered(runtime._player_controller, body)
	await process_frame
	_assert(runtime._active_npc_id == npc_id, "trigger sets active NPC id")
	var label: Label = runtime._npc_dialogue_label
	_assert(label != null and label.visible, "dialogue label is visible")
	_assert(label.text.contains(name_pl), "dialogue label shows NPC name")
	_assert(label.text.contains(greeting), "dialogue label shows greeting line")

	runtime._on_npc_trigger_exited(runtime._player_controller, body)
	await process_frame
	_assert(not label.visible, "dialogue hides when player leaves trigger")
