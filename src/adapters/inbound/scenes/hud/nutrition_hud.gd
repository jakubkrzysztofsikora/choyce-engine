## Adapter: Nutrition HUD controller.
## Part of the Nutrition sandbox loop for VS-025.
##
## Design notes:
## - Displays energy, nutrition, and training progression
## - Child-safe with icons and simple terminology
## - Responds to signals from NutritionManager and TrainingManager
class_name NutritionHUD
extends CanvasLayer


## Node references (set in _ready or editor)
@onready var _energy_bar: ProgressBar = $Panel/MarginContainer/VBoxContainer/EnergyBar
@onready var _nutrition_icons: HBoxContainer = $Panel/MarginContainer/VBoxContainer/NutritionIcons
@onready var _training_bar: ProgressBar = $Panel/MarginContainer/VBoxContainer/TrainingBar
@onready var _caption_label: Label = $Panel/MarginContainer/VBoxContainer/CaptionLabel


## Signals
signal hud_updated()


## Reference to NutritionManager (optional, for direct updates)
var _nutrition_manager: NutritionManager = null

## Reference to TrainingManager (optional, for direct updates)
var _training_manager: TrainingManager = null

## Icon textures (would be loaded from assets in actual implementation)
var _power_icon: Texture2D = null
var _zoom_icon: Texture2D = null
var _health_icon: Texture2D = null
var _endurance_icon: Texture2D = null

## Caption display timer
var _caption_timer: float = 0.0
var _caption_duration: float = 3.0


## Called when the node enters the scene tree for the first time
func _ready() -> void:
	## Try to find managers in the scene
	_nutrition_manager = get_node_or_null("/root/Main/World/GameplayRuntime/NutritionManager")
	_training_manager = get_node_or_null("/root/Main/World/GameplayRuntime/TrainingManager")
	
	## Connect signals if managers are found
	if _nutrition_manager != null:
		_nutrition_manager.nutrition_changed.connect(_on_nutrition_changed)
		_nutrition_manager.energy_changed.connect(_on_energy_changed)
		_nutrition_manager.caption_requested.connect(_on_caption_requested)
	
	if _training_manager != null:
		_training_manager.training_completed.connect(_on_training_completed)
		_training_manager.training_level_up.connect(_on_training_level_up)
		_training_manager.body_progression_updated.connect(_on_body_progression_updated)
		_training_manager.caption_requested.connect(_on_caption_requested)
	
	## Setup icon textures (placeholder - would use actual textures)
	_setup_placeholder_icons()
	
	## Initial update
	_update_display()


## Process caption timer
func _process(delta: float) -> void:
	if _caption_label.visible:
		_caption_timer += delta
		if _caption_timer >= _caption_duration:
			_caption_label.visible = false


## Setup placeholder icons (for testing without actual assets)
func _setup_placeholder_icons() -> void:
	## Create simple colored rectangles as placeholder icons
	_power_icon = _create_placeholder_icon(Color.RED)
	_zoom_icon = _create_placeholder_icon(Color.YELLOW)
	_health_icon = _create_placeholder_icon(Color.GREEN)
	_endurance_icon = _create_placeholder_icon(Color.BLUE)
	
	## Assign to icon nodes
	if _nutrition_icons.get_child_count() >= 4:
		_nutrition_icons.get_child(0).texture = _power_icon
		_nutrition_icons.get_child(1).texture = _zoom_icon
		_nutrition_icons.get_child(2).texture = _health_icon
		_nutrition_icons.get_child(3).texture = _endurance_icon


## Create a simple colored rectangle texture
func _create_placeholder_icon(color: Color) -> Texture2D:
	var image: Image = Image.create(24, 24, false, Image.FORMAT_RGBA8)
	image.fill(color)
	var texture: ImageTexture = ImageTexture.create_from_image(image)
	return texture


## Handle nutrition changed
func _on_nutrition_changed(energy_percent: float, power_percent: float, zoom_percent: float, health_percent: float, endurance_percent: float) -> void:
	## Update energy bar
	if _energy_bar != null:
		_energy_bar.value = energy_percent
	
	## Update icon opacities based on nutrient levels
	_update_nutrient_icon_opacities(power_percent, zoom_percent, health_percent, endurance_percent)
	
	hud_updated.emit()


## Handle energy changed
func _on_energy_changed(current: int, max: int) -> void:
	if _energy_bar != null:
		_energy_bar.value = float(current) / float(max) * 100.0
	
	hud_updated.emit()


## Handle training completed
func _on_training_completed(training_type: TrainingStats.TrainingType, level_up: bool, new_level: int) -> void:
	_update_training_display()
	
	if level_up:
		_show_caption("Level %d reached!" % [new_level])
	
	hud_updated.emit()


## Handle training level up
func _on_training_level_up(training_type: TrainingStats.TrainingType, new_level: int) -> void:
	_show_caption("Level Up! Level %d" % [new_level])
	_update_training_display()
	hud_updated.emit()


## Handle body progression updated
func _on_body_progression_updated(level: int, state_name: String) -> void:
	_show_caption("Body: %s" % [state_name])
	hud_updated.emit()


## Handle caption requested
func _on_caption_requested(text: String, duration: float = 3.0) -> void:
	_show_caption(text, duration)


## Show a caption message
func _show_caption(text: String, duration: float = 3.0) -> void:
	if _caption_label == null:
		return
	
	_caption_label.text = text
	_caption_label.visible = true
	_caption_timer = 0.0
	_caption_duration = duration


## Update nutrient icon opacities based on levels
func _update_nutrient_icon_opacities(power_percent: float, zoom_percent: float, health_percent: float, endurance_percent: float) -> void:
	if _nutrition_icons.get_child_count() < 4:
		return
	
	## Set opacity based on nutrient level (0-100%)
	_nutrition_icons.get_child(0).modulate.a = power_percent / 100.0 + 0.3  ## Ensure minimum visibility
	_nutrition_icons.get_child(1).modulate.a = zoom_percent / 100.0 + 0.3
	_nutrition_icons.get_child(2).modulate.a = health_percent / 100.0 + 0.3
	_nutrition_icons.get_child(3).modulate.a = endurance_percent / 100.0 + 0.3


## Update training display
func _update_training_display() -> void:
	if _training_manager == null:
		return
	
	if _training_bar != null:
		_training_bar.value = _training_manager.get_total_progress_percent()


## Update all display elements
func _update_display() -> void:
	if _nutrition_manager != null:
		var energy_percent: float = _nutrition_manager.get_energy_percent()
		var nutrients: Dictionary = _nutrition_manager.get_nutrient_percentages()
		_on_nutrition_changed(
			energy_percent,
			nutrients.get("power", 0.0),
			nutrients.get("zoom", 0.0),
			nutrients.get("health", 0.0),
			nutrients.get("endurance", 0.0)
		)
	
	if _training_manager != null:
		_update_training_display()


## Set NutritionManager reference
func set_nutrition_manager(manager: NutritionManager) -> void:
	if _nutrition_manager != null:
		_nutrition_manager.nutrition_changed.disconnect(_on_nutrition_changed)
		_nutrition_manager.energy_changed.disconnect(_on_energy_changed)
		_nutrition_manager.caption_requested.disconnect(_on_caption_requested)
	
	_nutrition_manager = manager
	
	if _nutrition_manager != null:
		_nutrition_manager.nutrition_changed.connect(_on_nutrition_changed)
		_nutrition_manager.energy_changed.connect(_on_energy_changed)
		_nutrition_manager.caption_requested.connect(_on_caption_requested)
	
	_update_display()


## Set TrainingManager reference
func set_training_manager(manager: TrainingManager) -> void:
	if _training_manager != null:
		_training_manager.training_completed.disconnect(_on_training_completed)
		_training_manager.training_level_up.disconnect(_on_training_level_up)
		_training_manager.body_progression_updated.disconnect(_on_body_progression_updated)
		_training_manager.caption_requested.disconnect(_on_caption_requested)
	
	_training_manager = manager
	
	if _training_manager != null:
		_training_manager.training_completed.connect(_on_training_completed)
		_training_manager.training_level_up.connect(_on_training_level_up)
		_training_manager.body_progression_updated.connect(_on_body_progression_updated)
		_training_manager.caption_requested.connect(_on_caption_requested)
	
	_update_display()


## Reset the HUD
func reset() -> void:
	if _energy_bar != null:
		_energy_bar.value = 50.0
	
	if _training_bar != null:
		_training_bar.value = 0.0
	
	_update_nutrient_icon_opacities(0.0, 0.0, 0.0, 0.0)
	_caption_label.visible = false
