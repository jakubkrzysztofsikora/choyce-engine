## SimpleVehicle.gd - Basic drivable vehicle (car/tractor)
##
## Part of VS-021: Add rare drivable vehicles and bounded bulldozer destruction sandbox
##
## A simple vehicle without destruction capabilities.
## Extend this for non-destructive vehicles like tractors or cars.
##
class_name SimpleVehicle
extends VehicleBase


# Vehicle-specific configuration
@export var max_speed_override: float = 12.0
@export var engine_force_override: float = 180.0
@export_enum("tractor", "car") var vehicle_visual_profile := "tractor"
@export var use_authored_vehicle_visual := false


func _ready() -> void:
	super()

	# Apply overrides
	if max_speed_override > 0:
		max_speed = max_speed_override
	if engine_force_override > 0:
		max_engine_force = engine_force_override
	if use_authored_vehicle_visual:
		_hide_prototype_vehicle_visuals()


## Imported ready-made cars already include a coherent body and wheels. The
## old primitive chassis and runtime tire cylinders were useful as a fallback,
## but layering them over that model produces the reported tractor/bike hybrid.
func _hide_prototype_vehicle_visuals() -> void:
	for child in get_children():
		if child is MeshInstance3D and child.name != "VehicleVisual":
			(child as MeshInstance3D).visible = false


func _configure_wheels() -> void:
	if vehicle_visual_profile == "car":
		_configure_car_wheels()
		return
	# Compact farm tractor: small steering tires at the front (-Z), larger
	# driven-looking tires at the rear. All four retain traction for forgiving
	# kid-friendly handling on uneven terrain.
	set_wheel_count(4)

	# Front wheels
	set_wheel_position(0, Vector3(-0.78, 0.58, -1.0))
	set_wheel_position(1, Vector3(0.78, 0.58, -1.0))
	set_wheel_dimensions(0, 0.48, 0.3)
	set_wheel_dimensions(1, 0.48, 0.3)

	# Rear wheels
	set_wheel_position(2, Vector3(-0.82, 0.72, 0.92))
	set_wheel_position(3, Vector3(0.82, 0.72, 0.92))
	set_wheel_dimensions(2, 0.7, 0.42)
	set_wheel_dimensions(3, 0.7, 0.42)

	# Standard suspension
	set_suspension_travel(0.22)
	set_suspension_stiffness(32.0)
	set_suspension_damping(3.2)


func _configure_car_wheels() -> void:
	set_wheel_count(4)
	for index in 4:
		var front := index < 2
		var side := -1.0 if index % 2 == 0 else 1.0
		set_wheel_position(index, Vector3(side * 0.78, 0.53, -1.30 if front else 1.30))
		set_wheel_dimensions(index, 0.43, 0.30)
	set_suspension_travel(0.20)
	set_suspension_stiffness(30.0)
	set_suspension_damping(3.0)
