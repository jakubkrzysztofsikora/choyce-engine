## Nutrition.gd - Domain model for food and nutrition tracking
##
## Part of VS-025: Add child-safe nutrition, training, and visible body-progression sandbox loop
##
## Tracks food consumption and provides nutrition values.
## All values are bounded and child-safe (no calorie counting, no body-shaming).
##

class_name Nutrition
extends RefCounted


# Food categories - child-friendly, no negative connotations
enum FoodCategory {
	PROTEIN,
	CARBOHYDRATE,
	FRUIT,
	VEGETABLE
}

# Food types with their categories and child-friendly names (Polish)
const FOOD_TYPES := {
	"apple": {"category": FoodCategory.FRUIT, "name": "Jabłko", "icon": "🍎"},
	"banana": {"category": FoodCategory.FRUIT, "name": "Banan", "icon": "🍌"},
	"bread": {"category": FoodCategory.CARBOHYDRATE, "name": "Chleb", "icon": "🍞"},
	"carrot": {"category": FoodCategory.VEGETABLE, "name": "Marchew", "icon": "🥕"},
	"cheese": {"category": FoodCategory.PROTEIN, "name": "Ser", "icon": "🧀"},
	"chicken": {"category": FoodCategory.PROTEIN, "name": "Kurczak", "icon": "🍗"},
	"eggs": {"category": FoodCategory.PROTEIN, "name": "Jajka", "icon": "🥚"},
	"fish": {"category": FoodCategory.PROTEIN, "name": "Ryba", "icon": "🐟"},
	"grains": {"category": FoodCategory.CARBOHYDRATE, "name": "Zboża", "icon": "🌾"},
	"grapes": {"category": FoodCategory.FRUIT, "name": "Winogrona", "icon": "🍇"},
	"milk": {"category": FoodCategory.PROTEIN, "name": "Mleko", "icon": "🥛"},
	"potato": {"category": FoodCategory.CARBOHYDRATE, "name": "Ziemniak", "icon": "🥔"},
	"rice": {"category": FoodCategory.CARBOHYDRATE, "name": "Ryż", "icon": "🍚"}
}

# Maximum food items a kid can carry (bounded)
const MAX_FOOD_ITEMS := 20

# Nutrition state per category (0-100%)
var protein_level: float = 0.0
var carbohydrate_level: float = 0.0
var fruit_level: float = 0.0
var vegetable_level: float = 0.0

# Tracked food items (food_type -> count)
var food_items: Dictionary = {}


## Add food to inventory
func add_food(food_type: String, count: int = 1) -> bool:
	if not FOOD_TYPES.has(food_type):
		return false
	
	var total_items := 0
	for existing_count in food_items.values():
		total_items += int(existing_count)
	
	if total_items + count > MAX_FOOD_ITEMS:
		return false
	
	food_items[food_type] = int(food_items.get(food_type, 0)) + count
	return true


## Consume food (eat it to gain nutrition)
## Returns the category of food consumed
func consume_food(food_type: String, count: int = 1) -> FoodCategory:
	if not food_items.has(food_type) or int(food_items[food_type]) < count:
		return FoodCategory.PROTEIN  # Default, shouldn't happen
	
	var category: FoodCategory = FOOD_TYPES[food_type].category
	food_items[food_type] = int(food_items[food_type]) - count
	
	if int(food_items[food_type]) <= 0:
		food_items.erase(food_type)
	
	# Increase nutrition level for this category (bounded to 100)
	match category:
		FoodCategory.PROTEIN:
			protein_level = min(protein_level + 25.0 * float(count), 100.0)
		FoodCategory.CARBOHYDRATE:
			carbohydrate_level = min(carbohydrate_level + 25.0 * float(count), 100.0)
		FoodCategory.FRUIT:
			fruit_level = min(fruit_level + 20.0 * float(count), 100.0)
		FoodCategory.VEGETABLE:
			vegetable_level = min(vegetable_level + 20.0 * float(count), 100.0)
	
	return category


## Get total food count
func total_food() -> int:
	var total := 0
	for count in food_items.values():
		total += int(count)
	return total


## Check if kid has any food of a specific category
func has_food_category(category: FoodCategory) -> bool:
	for food_type in food_items.keys():
		if FOOD_TYPES.has(food_type) and FOOD_TYPES[food_type].category == category:
			return true
	return false


## Get nutrition summary as dictionary
func to_dict() -> Dictionary:
	return {
		"protein_level": protein_level,
		"carbohydrate_level": carbohydrate_level,
		"fruit_level": fruit_level,
		"vegetable_level": vegetable_level,
		"food_items": food_items.duplicate(true)
	}


## Create from dictionary
static func from_dict(data: Dictionary) -> Nutrition:
	var nutrition := Nutrition.new()
	if data.has("protein_level"):
		nutrition.protein_level = float(data["protein_level"])
	if data.has("carbohydrate_level"):
		nutrition.carbohydrate_level = float(data["carbohydrate_level"])
	if data.has("fruit_level"):
		nutrition.fruit_level = float(data["fruit_level"])
	if data.has("vegetable_level"):
		nutrition.vegetable_level = float(data["vegetable_level"])
	if data.has("food_items"):
		nutrition.food_items = data["food_items"].duplicate(true)
	return nutrition


## Get average nutrition level (0-100%)
func average_nutrition() -> float:
	return (protein_level + carbohydrate_level + fruit_level + vegetable_level) / 4.0
