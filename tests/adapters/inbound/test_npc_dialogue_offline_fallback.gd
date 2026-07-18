## NPC dialogue must remain playable when the optional model cannot answer.
extends SceneTree

const GameplayRuntimeScene = preload("res://src/adapters/inbound/gameplay/gameplay_runtime.tscn")
const NPCCharacter = preload("res://src/domain/world_authoring/npc_character.gd")

var _failures := 0


class ModelFailureLLM:
	extends LLMPort
	func complete(_envelope: PromptEnvelope, _options: Dictionary, _on_token: Callable, on_done: Callable) -> void:
		on_done.call({
			"text": "Nie moge skorzystac z modelu.",
			"provider": "litellm",
			"model": "unavailable",
			"stopped": false,
		})


func _init() -> void:
	call_deferred("_run")


func _assert(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		print("FAIL: %s" % message)
		_failures += 1


func _run() -> void:
	var runtime := GameplayRuntimeScene.instantiate()
	runtime.name = "NpcDialogueFallbackRuntime"
	get_root().add_child(runtime)
	await process_frame
	runtime._build_hud()
	var explorer := NPCCharacter.new("npc_explorer", NPCCharacter.ROLE_GUIDE, "Olek", {
		"greeting_pl": "Hej! Jestem Olek.",
		"hint_pl": "Nie ma pośpiechu — ciekawe miejsca znajdziesz też poza ścieżką.",
	})
	runtime.setup_npcs([explorer])
	runtime.setup_npc_llm(ModelFailureLLM.new(), null)
	runtime._active_npc_id = "npc_explorer"
	runtime._show_npc_dialogue("Olek", explorer.line_for("greeting"), false)
	var input := runtime._npc_dialogue_input as LineEdit
	_assert(input != null and input.focus_mode == Control.FOCUS_CLICK and not input.has_focus(),
		"optional NPC text input is click-to-focus and never steals gameplay keys on greeting")
	var enter := InputEventKey.new()
	enter.keycode = KEY_ENTER
	enter.pressed = true
	runtime._input(enter)
	_assert(input != null and input.has_focus(),
		"Enter explicitly focuses the visible NPC conversation composer")
	_assert(runtime._player_controller != null and runtime._player_controller.is_input_disabled(),
		"focused NPC composer suspends gameplay action polling so typed E/G/W stay text")
	runtime._execute_npc_completions("co robimy?")
	var caption := runtime._npc_dialogue_label as Label
	_assert(caption != null and caption.text.contains(explorer.line_for("hint"))
		and not caption.text.to_lower().contains("model"),
		"model failure is replaced with the NPC's authored local hint")
	input.release_focus()
	_assert(runtime._player_controller != null and not runtime._player_controller.is_input_disabled(),
		"leaving NPC composer restores normal world controls")
	runtime.queue_free()
	quit(_failures)
