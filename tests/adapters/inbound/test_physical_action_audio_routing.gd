## Regression guard: a contact hit must not layer the old tonal whoosh, while
## misses and gathering still give the player a dry, action-specific cue.
extends SceneTree

var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _assert(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		print("FAIL: %s" % message)
		_failures += 1


func _run() -> void:
	var runtime_source := FileAccess.get_file_as_string("res://src/adapters/inbound/gameplay/gameplay_runtime.gd")
	var sfx_source := FileAccess.get_file_as_string("res://src/adapters/inbound/gameplay/sfx_player.gd")
	var bank_source := FileAccess.get_file_as_string("res://src/adapters/inbound/shared/audio/audio_bank.gd")
	var attack_start := runtime_source.find("func _on_player_attacked")
	var attack_end := runtime_source.find("func _on_enemy_damaged", attack_start)
	var attack_handler := runtime_source.substr(attack_start, attack_end - attack_start)
	_assert(not attack_handler.contains("swing_whoosh"), "landed attacks do not layer the old tonal whoosh")
	_assert(runtime_source.contains("physical_swing_%s") and runtime_source.contains("tool_axe_wood") and runtime_source.contains("tool_pickaxe_stone"),
		"runtime emits action-specific dry swing and tool events")
	_assert(sfx_source.contains("play_physical_action") and bank_source.contains("func play_physical_action"),
		"SFX dispatcher routes physical actions to the dry audio generator")
	_assert(bank_source.contains('var asset_key := "kick_impact" if style == "kick" else "punch_thud"')
		and bank_source.contains("if _load_sfx(asset_key) != null:"),
		"landed melee impacts prefer the bundled ElevenLabs punch and kick clips")
	quit(_failures)
