## Unit tests for Nutrition domain class.
## Run: godot --headless --script tests/domain/test_nutrition.gd
##
class_name TestNutrition
extends SceneTree

const NutritionClass := preload("res://src/domain/gameplay/nutrition.gd")


func _init() -> void:
	var failures: Array = []

	_test_add_food(failures)
	_test_consume_food(failures)
	_test_average_nutrition(failures)
	_test_persistence(failures)
	_test_total_food(failures)
	_test_has_food_category(failures)

	if failures.is_empty():
		print("[test_nutrition] OK")
		quit(0)
	else:
		printerr("[test_nutrition] FAIL ", failures.size())
		for f in failures:
			printerr("  - ", f)
		quit(1)


func _test_add_food(failures: Array) -> void:
	var nutrition := NutritionClass.new()
	
	# Test adding valid food
	var result := nutrition.add_food("apple", 1)
	if result != true:
		failures.append("Should be able to add apple")
	if nutrition.food_items.get("apple", 0) != 1:
		failures.append("Should have 1 apple")
	
	# Test adding more of the same food
	result = nutrition.add_food("apple", 2)
	if result != true:
		failures.append("Should be able to add more apples")
	if nutrition.food_items.get("apple", 0) != 3:
		failures.append("Should have 3 apples")
	
	# Test adding invalid food
	result = nutrition.add_food("invalid_food", 1)
	if result != false:
		failures.append("Should not be able to add invalid food")
	
	# Test exceeding max food items
	for i in range(20):
		nutrition.add_food("bread", 1)
	# Should now be at max (20 items)
	result = nutrition.add_food("banana", 1)
	if result != false:
		failures.append("Should not exceed MAX_FOOD_ITEMS")


func _test_consume_food(failures: Array) -> void:
	var nutrition := NutritionClass.new()
	# Add food first
	nutrition.add_food("apple", 2)
	
	# Consume food
	var category := nutrition.consume_food("apple", 1)
	if category != NutritionClass.FoodCategory.FRUIT:
		failures.append("Apple should be FRUIT category")
	if nutrition.food_items.get("apple", 0) != 1:
		failures.append("Should have 1 apple left")
	
	# Check nutrition level increased
	if nutrition.fruit_level <= 0:
		failures.append("Fruit level should increase after consuming")
	
	# Consume remaining apple
	category = nutrition.consume_food("apple", 1)
	if nutrition.food_items.has("apple") == true:
		failures.append("Should have no apples left")


func _test_average_nutrition(failures: Array) -> void:
	var nutrition := NutritionClass.new()
	# No food consumed yet
	if nutrition.average_nutrition() != 0.0:
		failures.append("Average should be 0 with no food")
	
	# Add and consume some food
	nutrition.add_food("apple", 1)
	nutrition.consume_food("apple", 1)  # FRUIT: +20%
	nutrition.add_food("bread", 1)
	nutrition.consume_food("bread", 1)  # CARBOHYDRATE: +25%
	
	# Average should be (0 + 25 + 20 + 0) / 4 = 11.25
	var avg := nutrition.average_nutrition()
	if avg != 11.25:
		failures.append("Average should be 11.25 with one fruit and one carb, got %s" % [avg])


func _test_persistence(failures: Array) -> void:
	var nutrition := NutritionClass.new()
	nutrition.add_food("apple", 2)
	nutrition.consume_food("apple", 1)
	nutrition.add_food("bread", 1)
	
	# Serialize to dict
	var data := nutrition.to_dict()
	if not data.has("protein_level"):
		failures.append("Should have protein_level")
	if not data.has("carbohydrate_level"):
		failures.append("Should have carbohydrate_level")
	if not data.has("food_items"):
		failures.append("Should have food_items")
	
	# Deserialize from dict
	var nutrition2 := NutritionClass.from_dict(data)
	if nutrition2.protein_level != nutrition.protein_level:
		failures.append("Protein level should match")
	if nutrition2.carbohydrate_level != nutrition.carbohydrate_level:
		failures.append("Carb level should match")
	if nutrition2.food_items != nutrition.food_items:
		failures.append("Food items should match")


func _test_total_food(failures: Array) -> void:
	var nutrition := NutritionClass.new()
	if nutrition.total_food() != 0:
		failures.append("Total should be 0 initially")
	
	nutrition.add_food("apple", 3)
	nutrition.add_food("bread", 2)
	if nutrition.total_food() != 5:
		failures.append("Total should be 5")


func _test_has_food_category(failures: Array) -> void:
	var nutrition := NutritionClass.new()
	if nutrition.has_food_category(NutritionClass.FoodCategory.FRUIT) != false:
		failures.append("Should not have fruit initially")
	
	nutrition.add_food("apple", 1)
	if nutrition.has_food_category(NutritionClass.FoodCategory.FRUIT) != true:
		failures.append("Should have fruit after adding apple")
