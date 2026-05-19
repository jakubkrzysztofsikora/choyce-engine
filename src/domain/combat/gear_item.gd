## Gear item descriptor — weapons, armor, tools. RefCounted, pure data.
## Loot drops produce one of these; inventory holds them as
## (gear_item, quantity) pairs in PlayerInventory.gear[].
class_name GearItem
extends RefCounted

enum Slot {
	WEAPON,        ## sword / wand / bow — drives damage
	ARMOR,         ## chest / helmet — drives damage reduction
	TOOL,          ## pickaxe / shovel — drives mining speed / break power
	CONSUMABLE,    ## potion / apple — heals or buffs on use
	MATERIAL,      ## crafting reagent — wood, stone, iron
}

enum Rarity {
	COMMON,        ## white  — starter loot, no glow
	UNCOMMON,      ## green  — basic upgrade
	RARE,          ## blue   — quest reward, glows softly
	EPIC,          ## purple — boss drop, sparkles
}

var item_id: String                ## "sword_wood", "ore_iron", etc.
var display_name: String           ## kid-friendly Polish noun, e.g. "Drewniany miecz"
var slot: Slot
var rarity: Rarity
var icon_id: String                ## look up icon mesh / sprite in catalog
var mesh_asset_id: String          ## 3D mesh path for held / dropped representation
## Numeric stats keyed by name. Conventions:
##   "damage"        weapon hit value
##   "armor"         flat damage reduction
##   "mining_power"  blocks broken per swing
##   "heal_amount"   consumable on-use HP restored
##   "stack_max"     max stack size (default 64 for materials, 1 for gear)
var stats: Dictionary
## Crafting recipe — Dictionary[item_id, count] of inputs. Empty for
## non-craftable items (boss drops, starter weapons).
var recipe: Dictionary


func _init(p_id: String = "") -> void:
	item_id = p_id
	display_name = ""
	slot = Slot.MATERIAL
	rarity = Rarity.COMMON
	icon_id = ""
	mesh_asset_id = ""
	stats = {}
	recipe = {}


func stack_max() -> int:
	var declared := int(stats.get("stack_max", 0))
	if declared > 0:
		return declared
	if slot == Slot.MATERIAL or slot == Slot.CONSUMABLE:
		return 64
	return 1


func is_weapon() -> bool:
	return slot == Slot.WEAPON


func is_craftable() -> bool:
	return not recipe.is_empty()
