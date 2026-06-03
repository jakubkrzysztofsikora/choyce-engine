## Application service: translates a moderated Polish voice transcript
## into a concrete WorldEditCommand the runtime can apply.
##
## Pipeline (fail-closed at every step):
##   1) reject empty / whitespace-only transcripts
##   2) PolishIntentExtractor -> intent label
##   3) map intent -> WorldEditCommand.Action
##   4) extract object name from the transcript via a kid-safe noun
##      whitelist. Unknown nouns -> return null (don't make stuff up).
##   5) build a fully-formed WorldEditCommand with deterministic defaults
##      (spawn position, palette colour, mesh kind).
##
## Why not the LLM: the kid-facing "buduj X" / "usuń Y" loop needs to be
## millisecond-deterministic and survive offline. LLM-mediated authoring
## ships in W2-A behind ai_stream_v2; this service is the no-LLM floor
## so voice always works.
class_name VoiceWorldCommandService
extends RefCounted

const INTENT_CREATE := "CREATE_OBJECT"
const INTENT_DELETE := "DELETE_OBJECT"
const INTENT_MOVE := "MOVE_OBJECT"
const INTENT_HELP := "REQUEST_HELP"

## Kid-safe Polish noun -> (mesh_kind, color hex, display_name_pl).
## Adding a noun here is the one place authoring needs to touch to grow
## the vocabulary. Hostile / weapon nouns are intentionally absent.
const _NOUN_CATALOG := {
	"drzewo":      {"mesh": "cylinder", "color": "#4CAF50", "name": "Drzewo"},
	"drzewa":      {"mesh": "cylinder", "color": "#4CAF50", "name": "Drzewo"},
	"kwiat":       {"mesh": "box",      "color": "#F06292", "name": "Kwiat"},
	"kwiatek":     {"mesh": "box",      "color": "#F06292", "name": "Kwiat"},
	"dom":         {"mesh": "box",      "color": "#8D6E63", "name": "Dom"},
	"domek":       {"mesh": "box",      "color": "#8D6E63", "name": "Domek"},
	"most":        {"mesh": "box",      "color": "#A1887F", "name": "Most"},
	"wieża":       {"mesh": "cylinder", "color": "#7986CB", "name": "Wieża"},
	"wieza":       {"mesh": "cylinder", "color": "#7986CB", "name": "Wieża"},
	"klucz":       {"mesh": "box",      "color": "#FFD54F", "name": "Klucz"},
	"skrzynia":    {"mesh": "box",      "color": "#FFB300", "name": "Skrzynia"},
	"platforma":   {"mesh": "box",      "color": "#90CAF9", "name": "Platforma"},
	"flaga":       {"mesh": "box",      "color": "#E57373", "name": "Flaga"},
	"sprężyna":    {"mesh": "cylinder", "color": "#FF7043", "name": "Sprężyna"},
	"sprezyna":    {"mesh": "cylinder", "color": "#FF7043", "name": "Sprężyna"},
}

var _intent_extractor: IntentExtractorPort = null
var _voice_moderation = null   # Optional VoiceInputModerationService; duck-typed
var _node_id_counter: int = 0


func setup(
	intent_extractor: IntentExtractorPort,
	voice_moderation = null
) -> VoiceWorldCommandService:
	if intent_extractor == null:
		push_error("VoiceWorldCommandService.setup(): intent_extractor must not be null")
		return self
	_intent_extractor = intent_extractor
	_voice_moderation = voice_moderation
	return self


## Public entry. Returns a WorldEditCommand or null when:
##   - transcript fails moderation
##   - intent isn't actionable (HELP / GENERAL_QUERY)
##   - no whitelisted noun in transcript
##
## `spawn_position` is the player's current XYZ — caller supplies it so
## this service stays pure (no Godot Node3D / scene-tree access).
func interpret(
	transcript: String,
	spawn_position: Vector3 = Vector3.ZERO
) -> WorldEditCommand:
	if _intent_extractor == null:
		push_error("VoiceWorldCommandService.interpret(): not configured")
		return null
	var clean := transcript.strip_edges()
	if clean.is_empty():
		return null

	# 1) Moderation gate when wired. Service falls open ONLY for the
	# null-adapter path used by tests; production main.gd always wires
	# the real VoiceInputModerationService so kid-unsafe transcripts
	# never reach this point.
	if _voice_moderation != null and _voice_moderation.has_method("is_transcript_safe"):
		if not _voice_moderation.is_transcript_safe(clean):
			return null

	# 2) Intent label.
	var intent := _intent_extractor.extract_intent(clean)

	# 3+4) Noun lookup. Required for CREATE / DELETE / MOVE.
	var noun_key := _find_noun(clean)
	match intent:
		INTENT_CREATE:
			if noun_key.is_empty():
				return null
			return _build_create_command(noun_key, spawn_position)
		INTENT_DELETE:
			if noun_key.is_empty():
				return null
			return _build_delete_command(noun_key)
		INTENT_MOVE:
			if noun_key.is_empty():
				return null
			return _build_move_command(noun_key, spawn_position)
		_:
			# HELP / GENERAL_QUERY / START_GAME: caller surfaces these
			# via the voice prompt overlay instead of WorldEditCommand.
			return null


## Friendly per-intent feedback line for the kid. Caller pipes this to
## VoicePromptPort.speak() so the kid hears confirmation even when no
## edit was produced.
func feedback_line(command: WorldEditCommand, transcript: String) -> String:
	if command == null:
		var clean := transcript.strip_edges()
		if clean.is_empty():
			return "Nie słyszę. Powtórz proszę."
		var intent := _intent_extractor.extract_intent(clean) if _intent_extractor != null else ""
		match intent:
			INTENT_HELP:
				return "Powiedz: 'buduj drzewo' albo 'usuń kwiat'."
			INTENT_CREATE, INTENT_DELETE, INTENT_MOVE:
				return "Nie znam tego słowa. Spróbuj: drzewo, kwiat, dom, most."
			_:
				return "Nie rozumiem. Powtórz po polsku."
	var name_pl: String = String(command.node_data.get("display_name_pl", "obiekt"))
	match command.action:
		WorldEditCommand.Action.ADD_NODE:
			return "Dodaję: %s." % name_pl
		WorldEditCommand.Action.REMOVE_NODE:
			return "Usuwam: %s." % name_pl
		WorldEditCommand.Action.MOVE_NODE:
			return "Przesuwam: %s." % name_pl
		_:
			return "Robię to."


func _find_noun(transcript: String) -> String:
	var lower := transcript.to_lower()
	for noun in _NOUN_CATALOG.keys():
		# Whole-word match to avoid substring false positives
		# (e.g. "domek" inside "domkowy"). Mirrors the recurring
		# review-finding rule from MEMORY.md.
		var pattern := "\\b%s\\b" % noun
		var regex := RegEx.new()
		if regex.compile(pattern) != OK:
			continue
		if regex.search(lower) != null:
			return noun
	return ""


func _build_create_command(noun_key: String, spawn_position: Vector3) -> WorldEditCommand:
	var entry: Dictionary = _NOUN_CATALOG[noun_key]
	var node_id := _generate_node_id()
	var cmd := WorldEditCommand.new(WorldEditCommand.Action.ADD_NODE, node_id)
	cmd.node_data = {
		"type": "OBJECT",
		"display_name_pl": entry["name"],
		"position": [spawn_position.x, spawn_position.y, spawn_position.z],
		"properties": {
			"color": entry["color"],
			"mesh_type": entry["mesh"],
			"size": [1.0, 1.0, 1.0],
		},
		"source": "voice",
	}
	cmd.new_state = cmd.node_data.duplicate(true)
	return cmd


func _build_delete_command(noun_key: String) -> WorldEditCommand:
	var entry: Dictionary = _NOUN_CATALOG[noun_key]
	var cmd := WorldEditCommand.new(WorldEditCommand.Action.REMOVE_NODE, "")
	cmd.node_data = {
		"display_name_pl": entry["name"],
		"target_label": noun_key,
		"source": "voice",
	}
	return cmd


func _build_move_command(noun_key: String, target_position: Vector3) -> WorldEditCommand:
	var entry: Dictionary = _NOUN_CATALOG[noun_key]
	var cmd := WorldEditCommand.new(WorldEditCommand.Action.MOVE_NODE, "")
	cmd.node_data = {
		"display_name_pl": entry["name"],
		"target_label": noun_key,
		"source": "voice",
	}
	cmd.new_state = {
		"position": [target_position.x, target_position.y, target_position.z],
	}
	return cmd


func _generate_node_id() -> String:
	_node_id_counter += 1
	return "voice_node_%d_%d" % [Time.get_ticks_msec(), _node_id_counter]
