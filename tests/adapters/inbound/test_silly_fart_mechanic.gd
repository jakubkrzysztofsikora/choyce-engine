## Regression coverage for the optional G-key sandbox gag: input, shipped
## ElevenLabs SFX asset, and a bounded 3D cloud (no global screen overlay).
extends SceneTree

const InputMapInitializer = preload("res://src/adapters/inbound/shared/input_map_initializer.gd")
const EffectSpawner = preload("res://src/adapters/inbound/gameplay/effect_spawner.gd")
const GameplayRuntime = preload("res://src/adapters/inbound/gameplay/gameplay_runtime.gd")
const FART_SFX := "res://data/audio/sfx/eleven/fart_kid_safe.mp3"


## The focused social tests exercise only the runtime's reaction adapter, so
## avoid constructing the complete Adventure scene tree (world, player, SFX).
class TestGameplayRuntime extends GameplayRuntime:
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
	var initializer := InputMapInitializer.new()
	get_root().add_child(initializer)
	await process_frame
	_assert(InputMap.has_action("silly_fart"), "G-key sandbox action is registered")
	_assert(ResourceLoader.exists(FART_SFX), "generated ElevenLabs family-safe fart SFX is shipped")
	_test_role_aware_npc_reactions()
	await _test_nearby_npc_reactions_take_turns()
	await _test_fart_collects_all_nearby_npc_turns()
	await _test_skipped_voice_falls_back_and_drains()
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


## All nearby characters now receive a speech turn, in FIFO order. This keeps
## the varied social reaction the kid asked for without reintroducing competing
## captions/voices.
func _test_nearby_npc_reactions_take_turns() -> void:
	var runtime := TestGameplayRuntime.new()
	var hud := CanvasLayer.new()
	hud.name = "HUD"
	var voice := MockVoicePrompt.new()
	get_root().add_child(runtime)
	runtime.add_child(hud)
	runtime._npc_voice = voice
	voice.playback_started.connect(runtime._on_npc_voice_playback_started)
	voice.playback_finished.connect(runtime._on_npc_voice_playback_finished)
	voice.playback_skipped.connect(runtime._on_npc_voice_playback_skipped)
	var pirate := _make_reaction_npc("npc_pirate", "Kapitan", "guide")
	var vendor := _make_reaction_npc("npc_vendor", "Kupiec", "vendor")
	runtime.add_child(pirate)
	runtime.add_child(vendor)
	await process_frame
	runtime._queue_npc_reaction(pirate, {"line": "Arrr!", "emotion": FacialPerformance.Emotion.ANGRY})
	runtime._queue_npc_reaction(vendor, {"line": "Fuj!", "emotion": FacialPerformance.Emotion.SURPRISED})
	_assert(runtime._npc_reaction_queue_active, "nearby NPC reactions use one active dialogue queue")
	# Each short line holds the shared channel for its 0.75s minimum duration
	# plus the scheduler gap. Leave frame headroom beyond the 1.74s total.
	await create_timer(2.1).timeout
	_assert(voice.lines == ["Arrr!", "Fuj!"],
		"every nearby NPC receives one in-character speech turn in order")
	_assert(not runtime._npc_reaction_queue_active and runtime._npc_reaction_queue.is_empty(),
		"reaction queue drains after every nearby NPC has spoken")
	runtime.queue_free()
	await process_frame


func _test_fart_collects_all_nearby_npc_turns() -> void:
	var runtime := TestGameplayRuntime.new()
	var hud := CanvasLayer.new()
	hud.name = "HUD"
	var voice := MockVoicePrompt.new()
	var npc_root := Node3D.new()
	get_root().add_child(runtime)
	runtime.add_child(hud)
	runtime.add_child(npc_root)
	runtime._npc_root = npc_root
	runtime._npc_voice = voice
	voice.playback_started.connect(runtime._on_npc_voice_playback_started)
	voice.playback_finished.connect(runtime._on_npc_voice_playback_finished)
	voice.playback_skipped.connect(runtime._on_npc_voice_playback_skipped)
	npc_root.add_child(_make_reaction_npc("npc_pirate", "Kapitan", "guide"))
	npc_root.add_child(_make_reaction_npc("npc_vendor", "Kupiec", "vendor"))
	npc_root.add_child(_make_reaction_npc("npc_parrot", "Papuga", "guide"))
	var far_away := _make_reaction_npc("npc_far", "Daleki", "guide")
	far_away.position = Vector3(30.0, 0.0, 0.0)
	npc_root.add_child(far_away)
	await process_frame
	runtime._on_player_farted(Vector3.ZERO)
	await create_timer(0.35).timeout
	_assert(voice.lines == [
		"Arrr! Dość tych gazowych armat!",
		"Fuj! Otwórzmy okno, proszę!",
		"Ćwir! To był bąbelkowy podmuch!",
	], "fart collects every nearby NPC, skips distant NPCs, and preserves character lines")
	_assert(not runtime._npc_reaction_queue_active and runtime._npc_reaction_queue.is_empty(),
		"all nearby fart reactions drain without accumulating stale turns")
	runtime.queue_free()
	await process_frame


func _test_skipped_voice_falls_back_and_drains() -> void:
	var runtime := TestGameplayRuntime.new()
	var hud := CanvasLayer.new()
	hud.name = "HUD"
	var voice := MockVoicePrompt.new()
	voice.skip_lines = ["Fuj!"]
	get_root().add_child(runtime)
	runtime.add_child(hud)
	runtime._npc_voice = voice
	voice.playback_started.connect(runtime._on_npc_voice_playback_started)
	voice.playback_finished.connect(runtime._on_npc_voice_playback_finished)
	voice.playback_skipped.connect(runtime._on_npc_voice_playback_skipped)
	var pirate := _make_reaction_npc("npc_pirate", "Kapitan", "guide")
	var vendor := _make_reaction_npc("npc_vendor", "Kupiec", "vendor")
	runtime.add_child(pirate)
	runtime.add_child(vendor)
	await process_frame
	runtime._queue_npc_reaction(pirate, {"line": "Arrr!", "emotion": FacialPerformance.Emotion.ANGRY})
	runtime._queue_npc_reaction(vendor, {"line": "Fuj!", "emotion": FacialPerformance.Emotion.SURPRISED})
	await create_timer(1.5).timeout
	_assert(voice.lines == ["Arrr!", "Fuj!"], "a skipped ElevenLabs line still gets its dialogue turn")
	_assert(not runtime._npc_reaction_queue_active and runtime._npc_reaction_queue.is_empty(),
		"failed or saturated voice falls back to caption and never deadlocks NPC turns")
	runtime.queue_free()
	await process_frame


func _make_reaction_npc(npc_id: String, name_pl: String, role: String) -> Node3D:
	var npc := Node3D.new()
	npc.set_meta("npc_id", npc_id)
	npc.set_meta("npc_name_pl", name_pl)
	npc.set_meta("npc_role", role)
	npc.set_meta("facial_performance", FacialPerformance.new())
	return npc


class MockVoicePrompt extends VoicePromptPort:
	var lines: Array[String] = []
	var skip_lines: Array[String] = []

	func speak(text: String, _locale: String = "pl-PL") -> void:
		lines.append(text)
		if text in skip_lines:
			call_deferred("_skip_line", text)
			return
		playback_started.emit(text)
		call_deferred("_finish_line", text)

	func is_available() -> bool:
		return true

	func _finish_line(text: String) -> void:
		playback_finished.emit(text)

	func _skip_line(text: String) -> void:
		playback_skipped.emit(text)
