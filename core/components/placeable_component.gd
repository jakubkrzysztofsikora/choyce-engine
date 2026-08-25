class_name PlaceableComponent
extends SandboxComponent
## Metadata that puts a prefab in the build palette.
##
## block_id is a STRING, never an index. Reordering the palette must not corrupt
## every save file players have ever made. This is not hypothetical: index-based
## block ids are the single most common way user-generated-content games destroy
## their own community's builds.

enum SnapMode { GRID, SURFACE, FREE }

@export var block_id: StringName = &""
@export var display_name: String = ""
@export var category: StringName = &"basic"
@export var footprint: Vector3i = Vector3i.ONE
@export var default_snap: SnapMode = SnapMode.GRID
@export var yaw_step_degrees: float = 90.0
@export var cost: int = 1
@export var preview_icon: Texture2D
## Set false for decoration that may overlap other geometry (grass, decals).
@export var requires_clear_space: bool = true


func _component_key() -> StringName:
	return Components.PLACEABLE


func _on_registered() -> void:
	if block_id == &"":
		push_error("PlaceableComponent on %s has no block_id. Saves will be unloadable."
			% entity.name)
	if display_name == "":
		display_name = String(block_id).capitalize()
