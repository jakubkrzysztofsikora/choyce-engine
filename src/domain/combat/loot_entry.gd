## Typed loot table entry — replaces `Array[Dictionary]` per Adv 1 M3.
## Pure data Resource, no Godot Node coupling. Authored as `.tres`
## files under res://data/loot/ so parents (or designers) can tune in
## Godot inspector without code touch.
class_name LootEntry
extends Resource

@export var item_id: String = ""
## Inclusive range [min_qty .. max_qty] sampled uniformly on roll.
@export var min_qty: int = 1
@export var max_qty: int = 1
## 0.0 = never, 1.0 = always. Independent roll per entry.
@export_range(0.0, 1.0, 0.01) var chance: float = 1.0
## Rarity tier: 0=COMMON, 1=UNCOMMON, 2=RARE, 3=EPIC. Drives orb
## color in LootPickup.RARITY_COLORS (will move to here once
## RARITY_COLORS is fully Resource-driven).
@export_range(0, 3, 1) var rarity_tier: int = 0
