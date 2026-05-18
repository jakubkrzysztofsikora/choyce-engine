class_name EffectSpawner extends Node3D

func spawn_collect_effect(position: Vector3) -> void:
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
	await get_tree().create_timer(0.8).timeout
	particles.queue_free()

func spawn_dust_puff(position: Vector3) -> void:
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
	await get_tree().create_timer(0.6).timeout
	particles.queue_free()

func spawn_sparkle_burst(position: Vector3) -> void:
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
	await get_tree().create_timer(1.2).timeout
	particles.queue_free()

func spawn_confetti(position: Vector3) -> void:
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
	await get_tree().create_timer(2.2).timeout
	particles.queue_free()
