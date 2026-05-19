## Roll-once-on-defeat loot table. Holds Array[LootEntry]. Each
## entry rolls independently against its `chance` field. Returns a
## flat Array of {"item_id": String, "quantity": int} drops.
##
## Replaces the inline Array[Dictionary] previously stored on
## EnemyDefinition.loot_table (Adv 1 M3 fix).
class_name LootTableData
extends Resource

@export var entries: Array[LootEntry] = []


## Sample the table once. RNG injected so wave_director_service +
## tests can seed deterministically. Returns Array[Dictionary] with
## the same shape the existing _on_enemy_defeated handler expects,
## so the upgrade is drop-in for callers.
func generate(rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	for entry in entries:
		if entry == null:
			continue
		if rng.randf() > entry.chance:
			continue
		var lo := entry.min_qty
		var hi := maxi(entry.max_qty, lo)
		var qty := rng.randi_range(lo, hi)
		if qty <= 0:
			continue
		out.append({"item_id": entry.item_id, "quantity": qty})
	return out
