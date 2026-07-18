## Domain entity: the single visible goal a kid is chasing in a session.
## Surfaces in the Quest HUD as a PL label + progress bar + icon.
##
## Per MVP plan §5 + §10.MVP-I.3, four `kind`s map to the four goal types
## a 6-8yo can read at a glance:
##
##   "collect"      — target N items into inventory.<item>
##   "enter_zone"   — reach a named zone (in_zone.<name> == true)
##   "talk"         — complete N NPC interactions (quest.<id> == 'complete')
##   "build_count"  — place N catalog props (blocks_placed >= N)
##
## `win_condition` is a parsed DSL expression (see
## WinConditionInterpreter) the rules runtime evaluates each frame /
## event tick. When it goes true, EvaluateGoalService fires
## SessionEndedEvent(win=true). Pure data, RefCounted, no Godot types.
class_name GameGoal
extends RefCounted

const KIND_COLLECT := "collect"
const KIND_ENTER_ZONE := "enter_zone"
const KIND_TALK := "talk"
const KIND_BUILD_COUNT := "build_count"

const _ALL_KINDS := [
	KIND_COLLECT,
	KIND_ENTER_ZONE,
	KIND_TALK,
	KIND_BUILD_COUNT,
]

var kind: String
var target: int
## Polish label for the HUD, already _t()-resolved by the loader.
var label: String
## Icon resource id (e.g. "icon_carrot"). Adapter looks up actual texture.
var icon_id: String
## Source DSL string (e.g. "inventory.carrot>=5"). Parsed once at load.
var win_condition: String


func _init(
	p_kind: String = KIND_COLLECT,
	p_target: int = 0,
	p_label: String = "",
	p_icon_id: String = "",
	p_win_condition: String = "",
) -> void:
	kind = p_kind
	target = p_target
	label = p_label
	icon_id = p_icon_id
	win_condition = p_win_condition


## Compute 0..1 progress from a context dictionary (shape matches the
## one EvaluateGoalService hands to WinConditionInterpreter). Used by
## the Quest HUD's progress bar. Always returns 0 when target is 0
## (nothing to scale against).
func progress_ratio(ctx: Dictionary) -> float:
	if target <= 0:
		return 0.0
	# Score-based collect goals (win_condition "score>=N", e.g. defeat-N-enemies)
	# track the live score, not inventory — the bar fills as the kid scores.
	if kind == KIND_COLLECT and win_condition.strip_edges().begins_with("score"):
		return clampf(float(int(ctx.get("score", 0))) / float(target), 0.0, 1.0)
	var current: int = 0
	match kind:
		KIND_COLLECT:
			# Goal label is the only place we know the item name; for the
			# MVP we read the first non-zero key under "inventory". A
			# future Goal subclass can carry the item id explicitly.
			var inv: Variant = ctx.get("inventory", {})
			if inv is Dictionary:
				for v in (inv as Dictionary).values():
					if v is int:
						current = max(current, int(v))
		KIND_BUILD_COUNT:
			current = int(ctx.get("blocks_placed", 0))
		KIND_TALK:
			# Count completed quests.
			var quests: Variant = ctx.get("quest", {})
			if quests is Dictionary:
				for v in (quests as Dictionary).values():
					if String(v) == "complete":
						current += 1
		KIND_ENTER_ZONE:
			# Binary; clamp to 0/target.
			var zones: Variant = ctx.get("in_zone", {})
			if zones is Dictionary:
				for v in (zones as Dictionary).values():
					if bool(v):
						current = target
						break
	return clampf(float(current) / float(target), 0.0, 1.0)


static func is_valid_kind(k: String) -> bool:
	return k in _ALL_KINDS
