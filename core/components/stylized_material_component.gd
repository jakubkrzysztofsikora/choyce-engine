class_name StylizedMaterialComponent
extends SandboxComponent
## The component that makes a random free asset look like it belongs in YOUR
## game. Applies the project-wide StyleGuide to every MeshInstance3D under the
## entity: palette-consistent roughness/specular, rim light, outline width.
##
## Drop this on everything. It is the cheapest visual-cohesion tool in the kit,
## and asset-soup is the number-one reason free-asset games look cheap.

@export var style: StyleGuide
## Leave true unless a hero asset needs its authored material untouched.
@export var apply_to_children: bool = true
@export var tint: Color = Color.WHITE
@export var use_tint: bool = false

var _applied: int = 0


func _component_key() -> StringName:
	return &"stylized_material"


func _on_registered() -> void:
	if style == null:
		style = StyleGuide.fallback()
	_apply(entity)


func _apply(n: Node) -> void:
	if n is MeshInstance3D:
		_apply_to(n as MeshInstance3D)
	if not apply_to_children and n != entity:
		return
	for child in n.get_children():
		_apply(child)


func _apply_to(mi: MeshInstance3D) -> void:
	var mat := mi.material_override as StandardMaterial3D
	if mat == null:
		mat = StandardMaterial3D.new()
		var src := mi.get_active_material(0) as StandardMaterial3D
		if src:
			mat.albedo_color = src.albedo_color
			mat.albedo_texture = src.albedo_texture
		mi.material_override = mat

	mat.roughness = style.roughness
	mat.metallic = style.metallic
	# Godot 4 renamed this. `specular` is the Godot 3.x SpatialMaterial name and
	# silently no-ops with a remap warning.
	mat.metallic_specular = style.specular
	mat.rim_enabled = style.rim_enabled
	mat.rim = style.rim_strength
	mat.rim_tint = style.rim_tint
	if use_tint:
		mat.albedo_color = mat.albedo_color * tint

	# Inverted-hull outline. Cheap, works on every mesh, no CompositorEffect
	# needed. On 4.5+ a stencil-buffer outline pass is strictly better; swap the
	# implementation here and every asset in the project updates at once.
	if style.outline_enabled:
		mat.grow = true
		mat.grow_amount = 0.0   # the outline itself is a second pass, see below
		_ensure_outline(mi)

	_applied += 1


func _ensure_outline(mi: MeshInstance3D) -> void:
	if mi.has_meta(&"outline_done"):
		return
	mi.set_meta(&"outline_done", true)
	var outline := StandardMaterial3D.new()
	outline.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	outline.albedo_color = style.outline_colour
	outline.cull_mode = BaseMaterial3D.CULL_FRONT
	outline.grow = true
	outline.grow_amount = style.outline_width
	outline.render_priority = -1
	mi.material_overlay = outline


func applied_count() -> int:
	return _applied
