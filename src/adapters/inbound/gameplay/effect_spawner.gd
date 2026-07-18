class_name EffectSpawner extends Node3D

## Spawned effects still awaiting their timed cleanup. _exit_tree()
## frees them as a last resort so a forceful teardown (test quit, scene
## change, runtime disposal) doesn't strand GPUParticles3D +
## ParticleProcessMaterial resources.
var _active_effects: Array[Node] = []


func _exit_tree() -> void:
	for effect in _active_effects:
		if is_instance_valid(effect):
			effect.queue_free()
	_active_effects.clear()


## Helper to check if reduce-motion is enabled via the global accessibility policy
func _is_reduce_motion_enabled() -> bool:
	var AccessibilityPolicyPort_class := load("res://src/ports/outbound/accessibility_policy_port.gd")
	if AccessibilityPolicyPort_class != null:
		return AccessibilityPolicyPort_class._global_instance.is_reduce_motion_enabled() if AccessibilityPolicyPort_class._global_instance else false
	return false

func spawn_collect_effect(position: Vector3) -> void:
	# Respect reduce-motion accessibility setting
	if _is_reduce_motion_enabled():
		return
	# Create a GPUParticles3D burst
	var particles := GPUParticles3D.new()
	particles.emitting = true
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = 12
	particles.lifetime = 0.6
	# Create a simple particle material
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 0.3
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 60.0
	mat.initial_velocity_min = 2.0
	mat.initial_velocity_max = 4.0
	mat.gravity = Vector3(0, -8, 0)
	mat.color = Color(1.0, 0.9, 0.2)
	particles.process_material = mat
	particles.position = position
	add_child(particles)
	_active_effects.append(particles)
	await get_tree().create_timer(0.8).timeout
	if is_instance_valid(particles):
		particles.queue_free()
		_active_effects.erase(particles)

func spawn_dust_puff(position: Vector3) -> void:
	# Respect reduce-motion accessibility setting
	if _is_reduce_motion_enabled():
		return
	var particles := GPUParticles3D.new()
	particles.emitting = true
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = 8
	particles.lifetime = 0.4
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 0.2
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 45.0
	mat.initial_velocity_min = 1.0
	mat.initial_velocity_max = 2.5
	mat.gravity = Vector3(0, -4, 0)
	mat.color = Color(0.85, 0.8, 0.7)
	particles.process_material = mat
	particles.position = position
	add_child(particles)
	_active_effects.append(particles)
	await get_tree().create_timer(0.6).timeout
	if is_instance_valid(particles):
		particles.queue_free()
		_active_effects.erase(particles)

func spawn_sparkle_burst(position: Vector3) -> void:
	# Respect reduce-motion accessibility setting
	if _is_reduce_motion_enabled():
		return
	var particles := GPUParticles3D.new()
	particles.emitting = true
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = 20
	particles.lifetime = 1.0
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 0.5
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 90.0
	mat.initial_velocity_min = 1.0
	mat.initial_velocity_max = 3.0
	mat.gravity = Vector3(0, -2, 0)
	mat.color = Color(1.0, 1.0, 0.6)
	particles.process_material = mat
	particles.position = position
	add_child(particles)
	_active_effects.append(particles)
	await get_tree().create_timer(1.2).timeout
	if is_instance_valid(particles):
		particles.queue_free()
		_active_effects.erase(particles)

func spawn_confetti(position: Vector3) -> void:
	# Respect reduce-motion accessibility setting
	if _is_reduce_motion_enabled():
		return
	var particles := GPUParticles3D.new()
	particles.emitting = true
	particles.one_shot = true
	particles.explosiveness = 0.8
	particles.amount = 40
	particles.lifetime = 2.0
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 1.0
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 120.0
	mat.initial_velocity_min = 3.0
	mat.initial_velocity_max = 6.0
	mat.gravity = Vector3(0, -6, 0)
	mat.color = Color(1.0, 0.3, 0.5)
	particles.process_material = mat
	particles.position = position
	add_child(particles)
	_active_effects.append(particles)
	await get_tree().create_timer(2.2).timeout
	if is_instance_valid(particles):
		particles.queue_free()
		_active_effects.erase(particles)


## A family-friendly, non-toxic cartoon cloud for the optional silly action.
## It uses a few readable mesh puffs rather than a full-screen overlay, so the
## third-person player can see both the gag and nearby NPC reactions.
func spawn_stink_cloud(position: Vector3) -> void:
	var cloud := Node3D.new()
	cloud.name = "FartStinkCloud"
	cloud.position = position
	add_child(cloud)
	var offsets := [
		Vector3(-0.16, 0.02, 0.0), Vector3(0.10, 0.12, -0.06),
		Vector3(0.22, 0.28, 0.07), Vector3(-0.08, 0.38, 0.13),
	]
	for index in offsets.size():
		var puff := MeshInstance3D.new()
		puff.name = "StinkPuff%d" % index
		var mesh := SphereMesh.new()
		mesh.radius = 0.22
		mesh.height = 0.42
		puff.mesh = mesh
		var material := StandardMaterial3D.new()
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = Color(0.54, 0.72, 0.18, 0.72)
		material.emission_enabled = true
		material.emission = Color(0.24, 0.42, 0.05)
		material.emission_energy_multiplier = 0.22
		puff.material_override = material
		puff.position = offsets[index]
		puff.scale = Vector3.ONE * 0.18
		cloud.add_child(puff)
		if not _is_reduce_motion_enabled():
			var tween := create_tween()
			tween.tween_property(puff, "scale", Vector3.ONE * (0.72 + float(index) * 0.08), 0.25)
			tween.parallel().tween_property(puff, "position:y", puff.position.y + 0.46, 0.75)
			tween.tween_property(puff, "scale", Vector3.ONE * 0.08, 0.35)
	await get_tree().create_timer(1.25).timeout
	if is_instance_valid(cloud):
		cloud.queue_free()
		_active_effects.erase(cloud)
