## Bulldozer.gd - Bulldozer vehicle with destruction capabilities
##
## Part of VS-021: Add rare drivable vehicles and bounded bulldozer destruction sandbox
##
## Extends VehicleBase with:
## - Blade control (raise/lower)
## - Destruction Area3D for bulldozing
## - Protection system for indestructible objects
##
class_name Bulldozer
extends VehicleBase


# Bulldozer-specific configuration
@export var blade: MeshInstance3D = null
@export var blade_collision: CollisionShape3D = null
@export var blade_speed: float = 2.0
@export var blade_down: bool = false

# Destruction
@export var destroyer_area: Area3D = null
@export var destruction_category_meta: String = "destruction_category"
var destruction_tracker: Node = null

# Bulldozer-specific physics
@export var dozer_max_speed: float = 8.0
@export var dozer_engine_force: float = 250.0
@export var dozer_brake_force: float = 500.0

# Protected tags - these cannot be destroyed
const PROTECTED_TAGS := ["protected", "homestead", "npc", "bridge", "boundary"]
const DESTRUCTIBLE_TAGS := ["destructible", "temporary_scenery", "build_block"]
const DESTRUCTIBLE_CATEGORIES := ["destructible", "temporary_scenery", "build_block"]

var _blade_raised_y: float = 0.0
var _blade_collision_raised_y: float = 0.0
var _destroyer_raised_y: float = 0.0


func _ready() -> void:
	super()

	# Override max speed for bulldozer
	max_speed = dozer_max_speed
	max_engine_force = dozer_engine_force
	max_brake_force = dozer_brake_force

	# Find blade
	if blade == null:
		blade = find_child("Blade", true, false) as MeshInstance3D
	if blade != null:
		_blade_raised_y = blade.position.y
	if blade_collision == null:
		blade_collision = find_child("BladeCollision", true, false) as CollisionShape3D
	if blade_collision != null:
		_blade_collision_raised_y = blade_collision.position.y

	# Find destroyer area
	if destroyer_area == null:
		destroyer_area = find_child("DestroyerArea", true, false) as Area3D
	if destroyer_area != null:
		_destroyer_raised_y = destroyer_area.position.y
		if not destroyer_area.body_entered.is_connected(_on_destroyer_body_entered):
			destroyer_area.body_entered.connect(_on_destroyer_body_entered)
		destroyer_area.set_deferred("monitoring", true)
		destroyer_area.set_deferred("monitorable", true)
	if destruction_tracker == null and get_parent() != null:
		destruction_tracker = get_parent().get_node_or_null("DestructionTracker")


func setup_destruction_tracker(tracker: Node) -> void:
	destruction_tracker = tracker


func _configure_wheels() -> void:
	# Bulldozer has larger, heavier wheels
	set_wheel_count(4)

	# Front wheels (larger for bulldozer)
	set_wheel_position(0, Vector3(-1.02, 0.62, -1.12))
	set_wheel_position(1, Vector3(1.02, 0.62, -1.12))

	# Rear wheels
	set_wheel_position(2, Vector3(-1.02, 0.62, 1.02))
	set_wheel_position(3, Vector3(1.02, 0.62, 1.02))
	for index in 4:
		set_wheel_dimensions(index, 0.58, 0.4)

	# Heavy vehicle suspension
	set_suspension_travel(0.15)
	set_suspension_stiffness(50.0)
	set_suspension_damping(5.0)


func _input(event: InputEvent) -> void:
	super(event)

	if not is_active:
		return

	# Blade control
	# InputEvent does not have is_action_just_pressed() - use Input singleton
	if Input.is_action_just_pressed("blade_toggle"):
		blade_down = not blade_down


func _physics_process(delta: float) -> void:
	super(delta)

	if not is_active:
		return

	# Update blade position
	if blade != null:
		var target_y := _blade_raised_y - 0.42 if blade_down else _blade_raised_y
		blade.position.y = move_toward(blade.position.y, target_y, blade_speed * delta)
	if blade_collision != null:
		var collision_target_y := (
			_blade_collision_raised_y - 0.42 if blade_down else _blade_collision_raised_y)
		blade_collision.position.y = move_toward(
			blade_collision.position.y, collision_target_y, blade_speed * delta)
	if destroyer_area != null:
		var area_target_y := _destroyer_raised_y - 0.42 if blade_down else _destroyer_raised_y
		destroyer_area.position.y = move_toward(
			destroyer_area.position.y, area_target_y, blade_speed * delta)


func _on_destroyer_body_entered(body: Node3D) -> void:
	# Check if body can be destroyed
	if _can_destroy(body):
		destroy_object(body)


func _can_destroy(node: Node3D) -> bool:
	# Destruction is deny-by-default. Only temporary scenery and player build
	# blocks carrying an explicit tag/category are eligible, while a protected
	# ancestor always wins.
	var current: Node = node
	var explicitly_destructible := false
	while current != null:
		for tag in PROTECTED_TAGS:
			if current.is_in_group(tag):
				return false
		for tag in DESTRUCTIBLE_TAGS:
			if current.is_in_group(tag):
				explicitly_destructible = true
		var category := String(current.get_meta(destruction_category_meta, "")).to_lower()
		if category in ["indestructible", "protected"]:
			return false
		if category in DESTRUCTIBLE_CATEGORIES:
			explicitly_destructible = true
		current = current.get_parent()
	return explicitly_destructible


func destroy_object(target: Node3D) -> void:
	# Track destruction for potential restore
	if destruction_tracker != null and destruction_tracker.has_method("track_destruction"):
		var restore_info := {
			"original_position": target.get_meta("original_position", target.global_position),
			"prop_name": target.get_meta("prop_name", target.name),
			"rotation": target.rotation,
			"scale": target.scale
		}
		destruction_tracker.call_deferred("track_destruction", target, restore_info)

	# Visual effects
	_spawn_destruction_effects(target.global_position, target.scale.length())

	# Destroy the object
	emit_signal("destroyed", target)
	target.queue_free()


func _spawn_destruction_effects(effect_position: Vector3, effect_scale: float) -> void:
	# Spawn debris particles
	var particles := GPUParticles3D.new()
	particles.global_position = effect_position
	particles.emitting = true

	# Configure particle emission. In Godot 4 the emission shape belongs to
	# ParticleProcessMaterial, not GPUParticles3D.
	var process_mat := ParticleProcessMaterial.new()
	process_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process_mat.emission_sphere_radius = effect_scale * 0.5
	particles.process_material = process_mat
	particles.amount = 20
	particles.lifetime = 1.0
	particles.one_shot = true

	# Add to scene
	if get_parent() != null:
		get_parent().add_child(particles)
	else:
		get_tree().current_scene.add_child(particles)

	# Remove after effect
	var tree := get_tree()
	if tree != null:
		tree.create_timer(2.0).timeout.connect(func() -> void:
			if is_instance_valid(particles):
				particles.queue_free()
		)
