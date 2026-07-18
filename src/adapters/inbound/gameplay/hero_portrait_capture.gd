## Programmatic close-up capture for hero identity review.
## Creates a transient SubViewport framing the player's FacialPerformance node
## and writes a PNG for adversarial visual review.
class_name HeroPortraitCapture
extends RefCounted

const DEFAULT_SIZE := Vector2i(512, 512)


static func is_headless() -> bool:
	return DisplayServer.get_name() == "headless"


## Capture a portrait of the hero's face to `output_path`.
## Returns OK on success, ERR_UNAVAILABLE when running headless (no GPU output),
## or another Error code on setup failure.
static func capture(player: PlayerController, output_path: String, size: Vector2i = DEFAULT_SIZE) -> Error:
	if is_headless():
		return ERR_UNAVAILABLE
	if player == null or output_path.is_empty():
		return ERR_INVALID_PARAMETER

	var face := _find_face_node(player)
	if face == null:
		push_warning("HeroPortraitCapture: no FacialPerformance node found on player")
		return ERR_DOES_NOT_EXIST

	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return ERR_UNAVAILABLE

	var viewport := SubViewport.new()
	viewport.name = "HeroPortraitViewport"
	viewport.size = size
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var player_viewport := player.get_viewport()
	if player_viewport != null:
		viewport.world_3d = player_viewport.world_3d

	var camera := Camera3D.new()
	camera.name = "HeroPortraitCamera"
	camera.fov = 22.0
	camera.near = 0.03
	camera.far = 4.0

	viewport.add_child(camera)
	tree.root.add_child(viewport)

	var face_pos := face.global_position
	var forward := -player.global_transform.basis.z.normalized()
	var cam_pos := face_pos + forward * 0.48 + Vector3.UP * 0.04
	camera.global_position = cam_pos
	camera.look_at(face_pos, Vector3.UP)
	camera.current = true

	await tree.process_frame
	await tree.process_frame

	var texture := viewport.get_texture()
	var result: Error = ERR_CANT_CREATE
	if texture != null:
		var image := texture.get_image()
		if image != null and not image.is_empty():
			result = image.save_png(output_path)

	viewport.queue_free()
	return result


static func _find_face_node(player: PlayerController) -> Node3D:
	if player == null:
		return null
	return player.find_child("FacialPerformance", true, false) as Node3D
