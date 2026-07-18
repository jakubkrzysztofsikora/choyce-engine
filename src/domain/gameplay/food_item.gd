## Domain value object: represents a consumable food item with nutritional properties.
## Part of the Nutrition sandbox loop for VS-025.
##
## Design notes:
## - Framework-agnostic (extends RefCounted, not Node)
## - Uses child-safe terminology: "Power" for protein, "Zoom" for carbs
## - NO calorie counting, NO body-size references
## - All values are positive (no "bad" foods, only age-appropriate choices)
class_name FoodItem
extends RefCounted


## Food categories - age-appropriate for children 6-12
enum FoodCategory {
	FRUIT,      ## Apple, banana, berries - natural sugars + vitamins
	VEGETABLE,  ## Carrot, broccoli, spinach - fiber + vitamins
	PROTEIN,    ## Chicken, fish, eggs, beans, tofu - builds Power (strength)
	GRAIN,      ## Bread, rice, pasta, oatmeal - provides Zoom (energy/carbs)
	DAIRY,      ## Milk, cheese, yogurt - calcium + protein
	TREAT       ## Cookie, cake - limited, occasional
}


## Nutrient types - child-friendly names
enum NutrientType {
	POWER,      ## Protein - makes you stronger
	ZOOM,       ## Carbohydrates - gives you energy to run and play
	HEALTH,     ## Vitamins/minerals - keeps you healthy
	ENDURANCE,  ## Fiber - helps you keep going
	LONG_LASTING## Fat - lasting energy reserve
}


# Unique identifier for this food type
var id: String

# Human-readable name (localized via LocalizationPolicyPort)
var name: String

# Category classification
var category: FoodCategory

# Primary nutrient this food provides (child-safe terminology)
var primary_nutrient: NutrientType

# Nutrient values (0-10 scale, child-friendly)
# These map to the child-safe names: Power, Zoom, Health, Endurance, Long-Lasting
var nutrient_values: Dictionary

# Energy contribution (0-20 scale, NOT calories)
var energy_value: int

# Icon texture path for HUD display
var icon_path: String

# Sound to play when eaten
var eat_sound: String = "eat_generic"

# Whether this food is safe for children (all should be true)
var is_child_safe: bool = true

# Short description for captions
var description: String

# Whether this food can be found in the world (vs crafted)
var is_forageable: bool = false

# Tags for filtering (e.g., ["sweet", "crunchy", "juicy"])
var tags: Array[String]


## Construct a new FoodItem with required properties
func _init(p_id: String = "", p_name: String = "", p_category: FoodCategory = FoodCategory.FRUIT, p_primary_nutrient: NutrientType = NutrientType.ZOOM, p_energy: int = 5, p_nutrients: Dictionary = {}) -> void:
	id = p_id
	name = p_name
	category = p_category
	primary_nutrient = p_primary_nutrient
	energy_value = p_energy
	nutrient_values = p_nutrients if p_nutrients.size() > 0 else _default_nutrients(p_category)
	tags = []


## Get default nutrient values based on category
func _default_nutrients(p_category: FoodCategory) -> Dictionary:
	match p_category:
		FoodCategory.FRUIT:
			return {"zoom": 3, "health": 2, "endurance": 1}
		FoodCategory.VEGETABLE:
			return {"health": 3, "endurance": 2, "zoom": 1}
		FoodCategory.PROTEIN:
			return {"power": 3, "health": 1, "long_lasting": 1}
		FoodCategory.GRAIN:
			return {"zoom": 3, "long_lasting": 2}
		FoodCategory.DAIRY:
			return {"power": 2, "health": 2, "zoom": 1}
		FoodCategory.TREAT:
			return {"zoom": 2, "health": 0}  ## Limited nutritional value
		_:
			return {}


## Check if this food can be eaten
func can_eat() -> bool:
	return is_child_safe


## Get the child-friendly nutrient name
func get_nutrient_name(nutrient_key: String) -> String:
	match nutrient_key.to_lower():
		"power":
			return "Power"
		"zoom":
			return "Zoom"
		"health":
			return "Health"
		"endurance":
			return "Endurance"
		"long_lasting":
			return "Long-Lasting"
		_:
			return nutrient_key.capitalize()


## Get category name for display
func get_category_name() -> String:
	match category:
		FoodCategory.FRUIT:
			return "Fruit"
		FoodCategory.VEGETABLE:
			return "Vegetable"
		FoodCategory.PROTEIN:
			return "Protein"
		FoodCategory.GRAIN:
			return "Grain"
		FoodCategory.DAIRY:
			return "Dairy"
		FoodCategory.TREAT:
			return "Treat"
		_:
			return "Food"
