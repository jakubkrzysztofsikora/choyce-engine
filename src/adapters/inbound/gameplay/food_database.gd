## Adapter resource: defines all available food items in the game.
## Part of the Nutrition sandbox loop for VS-025.
##
## Design notes:
## - Extends Resource for Godot editor integration
## - Contains all food definitions
## - Uses child-safe terminology
class_name FoodDatabase
extends Resource


# Dictionary of all food items: food_id -> FoodItem
var food_items: Dictionary = {}

# Food items by category for easy lookup
var food_by_category: Dictionary = {}

# Food items that can be foraged in the world
var forageable_foods: Array[String] = []


## Initialize the database with default food items
func _init() -> void:
	_initialize_food_items()


## Initialize all food items
func _initialize_food_items() -> void:
	food_items = {}
	food_by_category = {}
	forageable_foods = []

	## FRUITS
	_add_food("apple", "Apple", FoodItem.FoodCategory.FRUIT, FoodItem.NutrientType.ZOOM, 10, {"zoom": 3, "health": 2}, "res://assets/icons/apple.png", "eat_fruit", true)
	_add_food("banana", "Banana", FoodItem.FoodCategory.FRUIT, FoodItem.NutrientType.ZOOM, 12, {"zoom": 4, "health": 1, "endurance": 1}, "res://assets/icons/banana.png", "eat_fruit", true)
	_add_food("berries", "Berries", FoodItem.FoodCategory.FRUIT, FoodItem.NutrientType.HEALTH, 8, {"health": 3, "zoom": 2}, "res://assets/icons/berries.png", "eat_fruit", true)

	## VEGETABLES
	_add_food("carrot", "Carrot", FoodItem.FoodCategory.VEGETABLE, FoodItem.NutrientType.HEALTH, 8, {"health": 3, "endurance": 2}, "res://assets/icons/carrot.png", "eat_vegetable", true)
	_add_food("broccoli", "Broccoli", FoodItem.FoodCategory.VEGETABLE, FoodItem.NutrientType.HEALTH, 10, {"health": 4, "endurance": 1}, "res://assets/icons/broccoli.png", "eat_vegetable", true)

	## PROTEINS
	_add_food("chicken", "Grilled Chicken", FoodItem.FoodCategory.PROTEIN, FoodItem.NutrientType.POWER, 15, {"power": 4, "health": 1, "long_lasting": 1}, "res://assets/icons/chicken.png", "eat_protein", false)
	_add_food("fish", "Baked Fish", FoodItem.FoodCategory.PROTEIN, FoodItem.NutrientType.POWER, 12, {"power": 3, "health": 2}, "res://assets/icons/fish.png", "eat_protein", false)
	_add_food("eggs", "Scrambled Eggs", FoodItem.FoodCategory.PROTEIN, FoodItem.NutrientType.POWER, 10, {"power": 3, "health": 1, "long_lasting": 1}, "res://assets/icons/eggs.png", "eat_protein", false)
	_add_food("beans", "Beans", FoodItem.FoodCategory.PROTEIN, FoodItem.NutrientType.POWER, 8, {"power": 2, "health": 1, "endurance": 2}, "res://assets/icons/beans.png", "eat_protein", false)

	## GRAINS
	_add_food("bread", "Bread", FoodItem.FoodCategory.GRAIN, FoodItem.NutrientType.ZOOM, 12, {"zoom": 4, "long_lasting": 2}, "res://assets/icons/bread.png", "eat_grain", false)
	_add_food("rice", "Rice", FoodItem.FoodCategory.GRAIN, FoodItem.NutrientType.ZOOM, 10, {"zoom": 3, "long_lasting": 1}, "res://assets/icons/rice.png", "eat_grain", false)
	_add_food("oatmeal", "Oatmeal", FoodItem.FoodCategory.GRAIN, FoodItem.NutrientType.LONG_LASTING, 15, {"zoom": 2, "long_lasting": 4}, "res://assets/icons/oatmeal.png", "eat_grain", false)

	## DAIRY
	_add_food("milk", "Milk", FoodItem.FoodCategory.DAIRY, FoodItem.NutrientType.POWER, 8, {"power": 2, "health": 2}, "res://assets/icons/milk.png", "eat_dairy", false)
	_add_food("cheese", "Cheese", FoodItem.FoodCategory.DAIRY, FoodItem.NutrientType.POWER, 10, {"power": 2, "health": 1, "long_lasting": 1}, "res://assets/icons/cheese.png", "eat_dairy", false)

	## TREATS (limited)
	_add_food("cookie", "Cookie", FoodItem.FoodCategory.TREAT, FoodItem.NutrientType.ZOOM, 5, {"zoom": 2}, "res://assets/icons/cookie.png", "eat_treat", false)


## Add a food item to the database
func _add_food(p_id: String, p_name: String, p_category: FoodItem.FoodCategory, p_primary_nutrient: FoodItem.NutrientType, p_energy: int, p_nutrients: Dictionary, p_icon: String, p_sound: String, p_forageable: bool) -> void:
	var food: FoodItem = FoodItem.new()
	food.id = p_id
	food.name = p_name
	food.category = p_category
	food.primary_nutrient = p_primary_nutrient
	food.energy_value = p_energy
	food.nutrient_values = p_nutrients
	food.icon_path = p_icon
	food.eat_sound = p_sound
	food.is_child_safe = true
	food.is_forageable = p_forageable
	food.description = _get_description(p_id)
	food.tags = _get_tags(p_id)

	food_items[p_id] = food

	## Add to category index
	var category_name: String = food.get_category_name()
	if not food_by_category.has(category_name):
		food_by_category[category_name] = []
	food_by_category[category_name].append(p_id)

	## Add to forageable list
	if p_forageable:
		forageable_foods.append(p_id)


## Get a food item by ID
func get_food(p_id: String) -> FoodItem:
	return food_items.get(p_id) if food_items.has(p_id) else null


## Get all food items
func get_all_foods() -> Array[FoodItem]:
	var result: Array[FoodItem] = []
	for food_id in food_items:
		result.append(food_items[food_id])
	return result


## Get food items by category
func get_foods_by_category(p_category: String) -> Array[FoodItem]:
	var result: Array[FoodItem] = []
	if food_by_category.has(p_category):
		for food_id in food_by_category[p_category]:
			if food_items.has(food_id):
				result.append(food_items[food_id])
	return result


## Get forageable food items
func get_forageable_foods() -> Array[FoodItem]:
	var result: Array[FoodItem] = []
	for food_id in forageable_foods:
		if food_items.has(food_id):
			result.append(food_items[food_id])
	return result


## Get a random forageable food
func get_random_forageable_food() -> FoodItem:
	if forageable_foods.size() == 0:
		return null
	var random_id: String = forageable_foods[randi() % forageable_foods.size()]
	return food_items.get(random_id) if food_items.has(random_id) else null


## Get food by nutrient type (returns foods that have this nutrient)
func get_foods_by_nutrient(p_nutrient: String) -> Array[FoodItem]:
	var result: Array[FoodItem] = []
	for food_id in food_items:
		var food: FoodItem = food_items[food_id]
		if food.nutrient_values.has(p_nutrient) and food.nutrient_values[p_nutrient] > 0:
			result.append(food)
	return result


## Get description for a food
func _get_description(p_id: String) -> String:
	match p_id:
		"apple":
			return "A juicy red apple. Full of vitamins!"
		"banana":
			return "A sweet yellow banana. Gives you energy!"
		"berries":
			return "Fresh berries. Packed with health!"
		"carrot":
			return "A crunchy carrot. Good for your eyes!"
		"broccoli":
			return "Green broccoli. Makes you strong!"
		"chicken":
			return "Grilled chicken. Full of power!"
		"fish":
			return "Baked fish. Tasty and healthy!"
		"eggs":
			return "Scrambled eggs. Protein packed!"
		"beans":
			return "Fresh beans. Good for you!"
		"bread":
			return "Fresh bread. Gives you energy!"
		"rice":
			return "Steamed rice. Long-lasting energy!"
		"oatmeal":
			return "Warm oatmeal. Keeps you going!"
		"milk":
			return "Cold milk. Strong bones!"
		"cheese":
			return "Tasty cheese. Full of calcium!"
		"cookie":
			return "A sweet cookie. Enjoy in moderation!"
		_:
			return "Delicious food!"


## Get tags for a food
func _get_tags(p_id: String) -> Array[String]:
	match p_id:
		"apple":
			return ["sweet", "juicy", "fruit"]
		"banana":
			return ["sweet", "soft", "fruit"]
		"berries":
			return ["sweet", "tart", "fruit", "small"]
		"carrot":
			return ["crunchy", "orange", "vegetable"]
		"broccoli":
			return ["green", "crunchy", "vegetable"]
		"chicken":
			return ["savory", "meat", "protein"]
		"fish":
			return ["savory", "meat", "protein"]
		"eggs":
			return ["savory", "protein"]
		"beans":
			return ["savory", "protein", "vegetable"]
		"bread":
			return ["soft", "grain", "starchy"]
		"rice":
			return ["soft", "grain", "starchy"]
		"oatmeal":
			return ["warm", "grain", "filling"]
		"milk":
			return ["cold", "dairy", "refreshing"]
		"cheese":
			return ["savory", "dairy"]
		"cookie":
			return ["sweet", "treat", "crunchy"]
		_:
			return []
