class_name HighlightComponent
extends SandboxComponent
## Tints every mesh under the entity in the focusing player's colour.
##
## SPLIT-SCREEN SUBTLETY, and it is a real design decision rather than a bug:
## the highlight lives in the shared World3D, so if two players look at the same
## crate they cannot each see their own colour. This implementation shows the
## FIRST focuser's colour and is honest about it. Per-player highlight would
## need either per-viewport render layers or a CompositorEffect outline pass
## keyed off a stencil bit — deliberately deferred, not forgotten.

@export var emission_strength: float = 0.55

var _meshes: Array[MeshInstance3D] = []
var _originals: Array[Color] = []
var _active_for: int = -1


func _component_key() -> StringName:
	return Components.HIGHLIGHT


func _on_registered() -> void:
	_collect(entity)
	var inter := sibling(Components.INTERACTABLE) as InteractableComponent
	if inter:
		inter.focus_gained.connect(_on_focus_gained)
		inter.focus_lost.connect(_on_focus_lost)


func _collect(n: Node) -> void:
	for child in n.get_children():
		if child is MeshInstance3D:
			var mi := child as MeshInstance3D
			var mat := mi.material_override
			if mat == null:
				mat = StandardMaterial3D.new()
				mi.material_override = mat
			elif not mat.resource_local_to_scene:
				# Duplicate so highlighting one crate does not light up all 200
				# crates sharing that material resource.
				mat = mat.duplicate()
				mi.material_override = mat
			if mat is StandardMaterial3D:
				_meshes.append(mi)
				_originals.append((mat as StandardMaterial3D).emission)
		_collect(child)


func _on_focus_gained(player_id: int) -> void:
	if _active_for != -1:
		return
	_active_for = player_id
	var reg := PlayerRegistrySystem.instance
	var profile := reg.get_profile(player_id) if reg else null
	var col: Color = profile.colour if profile else Color.WHITE
	for mi in _meshes:
		var mat := mi.material_override as StandardMaterial3D
		if mat:
			mat.emission_enabled = true
			mat.emission = col
			mat.emission_energy_multiplier = emission_strength


func _on_focus_lost(player_id: int) -> void:
	if _active_for != player_id:
		return
	_active_for = -1
	for i in _meshes.size():
		var mat := _meshes[i].material_override as StandardMaterial3D
		if mat:
			mat.emission = _originals[i]
			mat.emission_enabled = false
