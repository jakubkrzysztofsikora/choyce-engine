class_name DestructibleComponent
extends SandboxComponent
## Three-tier destruction, driven entirely by HealthComponent signals.
##
## Tier 0 cosmetic  : hit flash + particles. ~90% of hits. Near-zero cost.
## Tier 1 mesh swap : intact -> cracked -> wrecked. Cheap, deterministic,
##                    art-directable, and READABLE, which matters more in a
##                    stylized game than physical accuracy.
## Tier 2 fracture  : swap in PRE-BAKED fragments (Blender Cell Fracture) as
##                    debris. Fragment count is authored, so the budget is known
##                    at design time instead of discovered at runtime.
##
## Deliberately NOT runtime Voronoi and NOT runtime CSG. Godot's own docs frame
## CSG as a prototyping tool ("Prototyping levels with CSG") and every CSG op
## rebuilds mesh AND collision. It cannot survive gameplay-frequency use with
## four players.

signal stage_changed(stage: int)
signal destroyed(info: DamageInfo)

## Health fractions at which the mesh swaps. Descending.
@export var stage_thresholds: PackedFloat32Array = PackedFloat32Array([0.66, 0.33])
@export var stage_meshes: Array[Mesh] = []
## Pre-fractured scene. If null, a procedural box-shard fallback is used so the
## system is testable before art exists.
@export var fracture_scene: PackedScene
@export var fallback_shard_count: int = 8
@export var burst_impulse: float = 4.0
@export var flash_colour: Color = Color(1, 1, 1)

var stage: int = 0
var _mesh_instance: MeshInstance3D
var _health: HealthComponent


func _component_key() -> StringName:
	return Components.DESTRUCTIBLE


func _on_registered() -> void:
	_mesh_instance = _find_mesh(entity)
	_health = sibling(Components.HEALTH) as HealthComponent
	if _health == null:
		push_warning("DestructibleComponent on %s has no HealthComponent; it will never fire."
			% entity.name)
		return
	_health.damaged.connect(_on_damaged)
	_health.died.connect(_on_died)


func _find_mesh(n: Node) -> MeshInstance3D:
	for child in n.get_children():
		if child is MeshInstance3D:
			return child
		var found := _find_mesh(child)
		if found:
			return found
	return null


func _on_damaged(info: DamageInfo, _remaining: float) -> void:
	_flash()
	var fx := sibling(Components.FX) as FXComponent
	if fx:
		fx.play(&"hit", info.impact_point, info.impact_normal)
	_update_stage()


func _update_stage() -> void:
	var frac := _health.fraction()
	var new_stage := 0
	for i in stage_thresholds.size():
		if frac <= stage_thresholds[i]:
			new_stage = i + 1
	if new_stage == stage:
		return
	stage = new_stage
	if _mesh_instance and stage - 1 < stage_meshes.size() and stage > 0:
		var m := stage_meshes[stage - 1]
		if m:
			_mesh_instance.mesh = m
	stage_changed.emit(stage)


func _flash() -> void:
	if _mesh_instance == null:
		return
	# Per-instance shader uniform: no material duplication, no allocation.
	_mesh_instance.set_instance_shader_parameter(&"hit_flash", 1.0)
	var tw := create_tween()
	tw.tween_method(
		func(v: float): _mesh_instance.set_instance_shader_parameter(&"hit_flash", v),
		1.0, 0.0, 0.18)


func _on_died(info: DamageInfo) -> void:
	var fx := sibling(Components.FX) as FXComponent
	if fx:
		fx.play(&"destroyed", info.impact_point, info.impact_normal)
	_spawn_fragments(info)
	destroyed.emit(info)
	entity.queue_free()


func _spawn_fragments(info: DamageInfo) -> void:
	var parent := entity.get_parent()
	if parent == null:
		return
	var origin: Vector3 = (entity as Node3D).global_position
	var budget := DebrisBudget.instance

	if fracture_scene:
		var frag_root := fracture_scene.instantiate() as Node3D
		parent.add_child(frag_root)
		frag_root.global_position = origin
		for child in frag_root.get_children():
			if child is RigidBody3D and budget:
				var dir: Vector3 = ((child as Node3D).global_position - origin).normalized()
				budget.adopt(child, dir * burst_impulse)
		return

	# Fallback: procedural shards so this is exercisable with zero art.
	var base_size := 0.35
	for i in fallback_shard_count:
		var shard := RigidBody3D.new()
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3.ONE * base_size
		cs.shape = bs
		shard.add_child(cs)

		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3.ONE * base_size
		mi.mesh = bm
		if _mesh_instance and _mesh_instance.material_override:
			mi.material_override = _mesh_instance.material_override
		shard.add_child(mi)

		var angle := TAU * float(i) / float(fallback_shard_count)
		var dir := Vector3(cos(angle), 0.6, sin(angle)).normalized()
		parent.add_child(shard)
		shard.global_position = origin + dir * 0.3
		if budget:
			budget.adopt(shard, dir * burst_impulse)
