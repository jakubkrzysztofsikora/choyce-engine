## Domain entity: the kid's per-session item counter.
## Drives the `inventory.<item>` identifier seen by
## WinConditionInterpreter, and the loot/HUD readout. Pure data, no
## Godot types. Mutated by the gear-loop service; read by the rules
## runtime context builder.
##
## Capacity per item is unbounded for MVP; per-world block cap lives on
## BuildGrid (500). A future Hard Mode parental toggle can lower this.
class_name PlayerInventory
extends RefCounted

var items: Dictionary  # String -> int


func _init() -> void:
	items = {}


## Add `count` of `item_id`. Negative counts are clamped to zero —
## subtraction goes through `take()` which fails closed.
func add(item_id: String, count: int = 1) -> void:
	if item_id == "" or count <= 0:
		return
	items[item_id] = int(items.get(item_id, 0)) + count


## Try to remove `count` of `item_id`. Returns true if the kid had
## enough; returns false (and doesn't mutate) if not. The kid never
## sees a negative count.
func take(item_id: String, count: int = 1) -> bool:
	if item_id == "" or count <= 0:
		return false
	var have: int = int(items.get(item_id, 0))
	if have < count:
		return false
	items[item_id] = have - count
	return true


func count_of(item_id: String) -> int:
	return int(items.get(item_id, 0))


func total() -> int:
	var s: int = 0
	for v in items.values():
		s += int(v)
	return s


func clear() -> void:
	items.clear()


## Snapshot suitable for the WinConditionInterpreter context.
## Returns a shallow copy so callers can't mutate state by reference.
func to_context_dict() -> Dictionary:
	return items.duplicate()
