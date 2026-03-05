## Entity representing a gameplay rule defined via the block logic editor.
## Rules compile from visual blocks into executable logic. They drive
## events, timers, scoring, win conditions, and item spawns.
class_name GameRule
extends RefCounted

enum RuleType {
	EVENT_TRIGGER,
	TIMER,
	SCORING,
	WIN_CONDITION,
	ITEM_SPAWN,
}

var rule_id: String
var rule_type: RuleType
var display_name: String
var source_blocks: Array  # serialized block definitions
var compiled_logic: String
var is_active: bool
var properties: Dictionary  # extensible properties for balance tweaks


func _init(p_id: String = "", p_type: RuleType = RuleType.EVENT_TRIGGER) -> void:
	rule_id = p_id
	rule_type = p_type
	display_name = ""
	source_blocks = []
	compiled_logic = ""
	is_active = true
	properties = {}


func deactivate() -> void:
	is_active = false


func activate() -> void:
	is_active = true
