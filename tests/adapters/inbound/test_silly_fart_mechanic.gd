## Regression coverage for the optional G-key sandbox gag: input, shipped
## ElevenLabs SFX asset, and a bounded 3D cloud (no global screen overlay).
extends SceneTree

const InputMapInitializer = preload("res://src/adapters/inbound/shared/input_map_initializer.gd")
const EffectSpawner = preload("res://src/adapters/inbound/gameplay/effect_spawner.gd")
const GameplayRuntime = preload("res://src/adapters/inbound/gameplay/gameplay_runtime.gd")
const NPCDialogueLoader = preload("res://src/application/npc_dialogue_loader.gd")
const FART_SFX := "res://data/audio/sfx/eleven/fart_kid_safe.mp3"
const ADVENTURE_NPC_VOICE_FILES := [
	"res://data/audio/voice/adventure_olek_greeting.mp3",
	"res://data/audio/voice/adventure_pablo_greeting.mp3",
	"res://data/audio/voice/adventure_pestka_greeting.mp3",
	"res://data/audio/voice/adventure_olek_fart.mp3",
	"res://data/audio/voice/adventure_pablo_fart.mp3",
	"res://data/audio/voice/adventure_pestka_fart.mp3",
]


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
	_test_shipped_adventure_npc_voice_fallback()
	_test_sandbox_fart_affordance()
	_test_adventure_roster_has_authored_fart_reactions()
	_test_role_aware_npc_reactions()
	await _test_nearby_npc_reactions_take_turns()
	await _test_fart_collects_all_nearby_npc_turns()
	await _test_skipped_voice_falls_back_and_drains()
	await _test_stale_duplicate_voice_callback_is_ignored()
	await _test_reaction_waits_for_normal_greeting()
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


func _test_shipped_adventure_npc_voice_fallback() -> void:
	for path in ADVENTURE_NPC_VOICE_FILES:
		_assert(ResourceLoader.exists(path), "shipped ElevenLabs Adventure NPC take exists: %s" % path.get_file())
	var runtime := TestGameplayRuntime.new()
	get_root().add_child(runtime)
	runtime._setup_local_npc_voice()
	var played := runtime._speak_npc_line("Hej! Jestem Olek. Wybierz kierunek i zobaczmy, co odkryjemy.", 77)
	_assert(played and runtime._local_npc_voice != null and runtime._local_npc_voice.bus == "Voice",
		"Adventure greeting has a local ElevenLabs Voice-bus fallback without an API key")
	runtime.queue_free()


func _test_sandbox_fart_affordance() -> void:
	var runtime := TestGameplayRuntime.new()
	var hud := CanvasLayer.new()
	get_root().add_child(runtime)
	runtime.add_child(hud)
	runtime._build_sandbox_fart_hint(hud)
	var hint := runtime._sandbox_hint_panel.get_node_or_null("HintKeyLabel") as Label if runtime._sandbox_hint_panel != null else null
	var hint_icon := runtime._sandbox_hint_panel.get_node_or_null("HintIcon") as TextureRect if runtime._sandbox_hint_panel != null else null
	_assert(runtime._sandbox_hint_panel != null and runtime._sandbox_hint_panel.visible \
		and hint != null and hint.text == "G" and hint_icon != null and hint_icon.texture != null,
		"optional fart mechanic has one compact image-led G-key affordance")
	runtime._on_player_farted(Vector3.ZERO)
	_assert(not runtime._sandbox_hint_panel.visible,
		"fart hint dismisses after the child discovers the gag")
	runtime.queue_free()


func _test_role_aware_npc_reactions() -> void:
	var runtime := GameplayRuntime.new()
	var pirate := _make_reaction_npc("npc_pirate", "Kapitan", "hostile")
	var parrot := _make_reaction_npc("npc_parrot", "Papuga", "guide")
	var vendor := _make_reaction_npc("npc_vendor", "Kupiec", "vendor")
	var explorer := _make_reaction_npc("npc_explorer", "Olek", "guide")
	var hostile := _make_reaction_npc("npc_backrooms", "Cień", "hostile")
	var pirate_guide := _make_reaction_npc("npc_pirate", "Kapitan", "guide")
	_assert(String(runtime._fart_reaction_for(pirate).get("action", "")) == "swat",
		"pirate reacts angrily with one harmless swat")
	_assert(String(runtime._fart_reaction_for(parrot).get("action", "")) == "laugh",
		"parrot has its own laughing reaction")
	_assert(String(runtime._fart_reaction_for(vendor).get("action", "")) == "recoil",
		"vendor has a disgust/recoil reaction")
	_assert(String(runtime._fart_reaction_for(explorer).get("action", "")) == "laugh",
		"explorer has a curious, good-humoured character reaction")
	_assert(String(runtime._fart_reaction_for(explorer).get("line", "")) == "Ojej! Ten wiatr ma własny plan podróży!",
		"explorer reaction is character-specific without assuming which child avatar is active")
	_assert(String(runtime._fart_reaction_for(hostile).get("action", "")) == "swat",
		"angry hostile has exactly one harmless swat reaction")
	_assert(String(runtime._fart_reaction_for(pirate_guide).get("action", "")) == "recoil",
		"combat-disabled pirate never performs a pretend strike")
	runtime.free()
	pirate.free()
	parrot.free()
	vendor.free()
	explorer.free()
	hostile.free()
	pirate_guide.free()


func _test_adventure_roster_has_authored_fart_reactions() -> void:
	var loader := NPCDialogueLoader.new()
	var roster: Array = loader.load_npcs_for_template("adventure")
	_assert(not roster.is_empty(), "adventure has an NPC roster to author")
	for npc_variant in roster:
		var npc := npc_variant as NPCCharacter
		var reaction: Variant = npc.lines_pl.get("fart_reaction", {}) if npc != null else {}
		_assert(reaction is Dictionary and not String((reaction as Dictionary).get("line_pl", "")).is_empty()
			and not String((reaction as Dictionary).get("action", "")).is_empty(),
			"%s has a safe authored character reaction" % (npc.npc_id if npc != null else "unknown"))


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
	var pirate := _make_reaction_npc("npc_pirate", "Kapitan", "hostile")
	var vendor := _make_reaction_npc("npc_vendor", "Kupiec", "vendor")
	var parrot := _make_reaction_npc("npc_parrot", "Papuga", "guide")
	var explorer := _make_reaction_npc("npc_explorer", "Olek", "guide")
	var friendly := _make_reaction_npc("npc_friendly", "Maja", "guide")
	npc_root.add_child(pirate)
	npc_root.add_child(vendor)
	npc_root.add_child(parrot)
	npc_root.add_child(explorer)
	npc_root.add_child(friendly)
	var far_away := _make_reaction_npc("npc_far", "Daleki", "guide")
	far_away.position = Vector3(30.0, 0.0, 0.0)
	npc_root.add_child(far_away)
	await process_frame
	runtime._on_player_farted(Vector3.ZERO)
	await create_timer(0.35).timeout
	_assert(voice.lines == [
		"Arrr! Jeszcze jeden taki podmuch i wymachnę szablą w powietrzu!",
		"Fuj! Otwarte okno i świeże powietrze, natychmiast!",
		"Ćwir-haha! Pestka słyszała głośniejsze fale!",
	], "only the first three nearby reactions use the bounded shared voice channel")
	_assert(pirate.get_node_or_null("FartReaction") != null and vendor.get_node_or_null("FartReaction") != null
		and parrot.get_node_or_null("FartReaction") != null and explorer.get_node_or_null("FartReaction") != null
		and friendly.get_node_or_null("FartReaction") != null,
		"every nearby NPC still receives its own immediate in-world character line")
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


## Two characters can legitimately say the same short line. Completion from a
## prior voice request must not end the newer NPC's turn.
func _test_stale_duplicate_voice_callback_is_ignored() -> void:
	var runtime := TestGameplayRuntime.new()
	get_root().add_child(runtime)
	await process_frame
	runtime._active_npc_reaction_line = "Haha!"
	runtime._active_npc_reaction_request_id = 42
	runtime._active_npc_reaction_audio_finished = false
	runtime._on_npc_voice_playback_finished("Haha!", 41)
	_assert(not runtime._active_npc_reaction_audio_finished,
		"stale duplicate-line voice callback cannot finish a newer NPC turn")
	runtime._on_npc_voice_playback_finished("Haha!", 42)
	_assert(runtime._active_npc_reaction_audio_finished,
		"matching voice request finishes the active NPC turn")
	runtime.queue_free()
	await process_frame


## A fart pressed while a regular greeting is playing must wait on the same
## narration channel. The cloud and world-space reactions can appear at once,
## but no second ElevenLabs request may begin early.
func _test_reaction_waits_for_normal_greeting() -> void:
	var runtime := TestGameplayRuntime.new()
	var hud := CanvasLayer.new()
	hud.name = "HUD"
	var voice := MockVoicePrompt.new()
	voice.hold_lines = ["Cześć!"]
	var npc_root := Node3D.new()
	get_root().add_child(runtime)
	runtime.add_child(hud)
	runtime.add_child(npc_root)
	runtime._npc_root = npc_root
	runtime._npc_voice = voice
	voice.playback_started.connect(runtime._on_npc_voice_playback_started)
	voice.playback_finished.connect(runtime._on_npc_voice_playback_finished)
	voice.playback_skipped.connect(runtime._on_npc_voice_playback_skipped)
	npc_root.add_child(_make_reaction_npc("npc_parrot", "Papuga", "guide"))
	await process_frame
	runtime._show_npc_dialogue("Olek", "Cześć!")
	runtime._on_player_farted(Vector3.ZERO)
	await create_timer(0.08).timeout
	_assert(voice.lines == ["Cześć!"], "reaction voice waits for the active normal greeting")
	voice.finish_held("Cześć!")
	await create_timer(0.12).timeout
	_assert(voice.lines == ["Cześć!", "Ćwir-haha! Pestka słyszała głośniejsze fale!"],
		"reaction voice starts only after the normal greeting finishes")
	runtime.queue_free()
	await process_frame


func _make_reaction_npc(npc_id: String, name_pl: String, role: String) -> Node3D:
	var npc := Node3D.new()
	npc.set_meta("npc_id", npc_id)
	npc.set_meta("npc_name_pl", name_pl)
	npc.set_meta("npc_role", role)
	npc.set_meta("facial_performance", FacialPerformance.new())
	match npc_id:
		"npc_explorer":
			npc.set_meta("fart_reaction", {"line_pl": "Ojej! Ten wiatr ma własny plan podróży!", "emotion": "happy", "action": "laugh"})
		"npc_pirate":
			npc.set_meta("fart_reaction", {"line_pl": "Arrr! Jeszcze jeden taki podmuch i wymachnę szablą w powietrzu!", "emotion": "angry", "action": "swat"})
		"npc_parrot":
			npc.set_meta("fart_reaction", {"line_pl": "Ćwir-haha! Pestka słyszała głośniejsze fale!", "emotion": "happy", "action": "laugh"})
	return npc


class MockVoicePrompt extends VoicePromptPort:
	var lines: Array[String] = []
	var skip_lines: Array[String] = []
	var hold_lines: Array[String] = []
	var held_request_ids: Dictionary = {}

	func speak(text: String, _locale: String = "pl-PL", request_id: int = 0) -> void:
		lines.append(text)
		if text in skip_lines:
			call_deferred("_skip_line", text, request_id)
			return
		playback_started.emit(text, request_id)
		if text in hold_lines:
			held_request_ids[text] = request_id
			return
		call_deferred("_finish_line", text, request_id)

	func is_available() -> bool:
		return true

	func _finish_line(text: String, request_id: int) -> void:
		playback_finished.emit(text, request_id)

	func _skip_line(text: String, request_id: int) -> void:
		playback_skipped.emit(text, request_id)

	func finish_held(text: String) -> void:
		if not held_request_ids.has(text):
			return
		var request_id := int(held_request_ids[text])
		held_request_ids.erase(text)
		playback_finished.emit(text, request_id)
