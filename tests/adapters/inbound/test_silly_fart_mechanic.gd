## Regression coverage for the optional G-key sandbox gag: input, shipped
## ElevenLabs SFX asset, and a bounded 3D cloud (no global screen overlay).
extends SceneTree

const InputMapInitializer = preload("res://src/adapters/inbound/shared/input_map_initializer.gd")
const EffectSpawner = preload("res://src/adapters/inbound/gameplay/effect_spawner.gd")
const GameplayRuntime = preload("res://src/adapters/inbound/gameplay/gameplay_runtime.gd")
const FART_SFX := "res://data/audio/sfx/eleven/fart_kid_safe.mp3"

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
	var initializer := InputMapInitializer.new()
	get_root().add_child(initializer)
	await process_frame
	_assert(InputMap.has_action("silly_fart"), "G-key sandbox action is registered")
	_assert(ResourceLoader.exists(FART_SFX), "generated ElevenLabs family-safe fart SFX is shipped")
	_test_role_aware_npc_reactions()
	var spawner := EffectSpawner.new()
	get_root().add_child(spawner)
	spawner.spawn_stink_cloud(Vector3(2.0, 0.4, -1.0))
	var cloud := spawner.get_node_or_null("FartStinkCloud") as Node3D
	_assert(cloud != null and cloud.get_child_count() == 4, "fart creates a small four-puff 3D cloud")
	await create_timer(1.35).timeout
	_assert(spawner.get_node_or_null("FartStinkCloud") == null, "fart cloud cleans itself up")
	spawner.queue_free()
	initializer.queue_free()
	quit(_exit_code)


func _test_role_aware_npc_reactions() -> void:
	var runtime := GameplayRuntime.new()
	var pirate := Node3D.new()
	pirate.set_meta("npc_id", "npc_pirate")
	pirate.set_meta("npc_role", "guide")
	var parrot := Node3D.new()
	parrot.set_meta("npc_id", "npc_parrot")
	parrot.set_meta("npc_role", "guide")
	var vendor := Node3D.new()
	vendor.set_meta("npc_id", "npc_vendor")
	vendor.set_meta("npc_role", "vendor")
	_assert(String(runtime._fart_reaction_for(pirate).get("action", "")) == "swat",
		"pirate reacts angrily with one harmless swat")
	_assert(String(runtime._fart_reaction_for(parrot).get("action", "")) == "laugh",
		"parrot has its own laughing reaction")
	_assert(String(runtime._fart_reaction_for(vendor).get("action", "")) == "recoil",
		"vendor has a disgust/recoil reaction")
	runtime.free()
	pirate.free()
	parrot.free()
	vendor.free()
