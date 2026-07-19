## Runtime contract for the Ziemek/Gniewko visual-identity seam.
## Run: godot --headless --path . --script tests/adapters/inbound/test_hero_identity_layer.gd
extends SceneTree

const GAMEPLAY_SCENE := preload("res://src/adapters/inbound/gameplay/gameplay_runtime.tscn")
const CUSTOMIZATION := preload("res://src/domain/gameplay/character_customization.gd")
const PORTRAIT_CAPTURE := preload("res://src/adapters/inbound/gameplay/hero_portrait_capture.gd")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
		printerr("FAIL: ", message)
	else:
		print("PASS: ", message)


func _run() -> void:
	var runtime := GAMEPLAY_SCENE.instantiate()
	root.add_child(runtime)
	await process_frame
	var player := runtime.get_node_or_null("PlayerController") as PlayerController
	_expect(player != null, "gameplay scene exposes PlayerController")
	_expect(is_equal_approx(PlayerController.BASE_FOV, 50.0)
		and is_equal_approx(PlayerController.SPRINT_FOV, 54.0),
		"third-person hero camera uses the tighter composed opening lens")
	if player != null:
		var customization := CUSTOMIZATION.new()
		customization.face = "e"
		player.apply_customization(customization, true)
		await process_frame
		var character := player.get_node_or_null("CharacterMesh") as Node3D
		_expect(character != null, "Ziemek character GLB mesh is mounted on the player controller")
		_expect(player._hero_identity == PlayerController.HERO_IDENTITY_ZIEMEK, "default hero identity is Ziemek")
		var facial := _find_facial_performance(player)
		_expect(facial != null, "Ziemek facial performance is attached")
		_expect(_is_bone_anchored(facial), "Ziemek facial performance is bone-anchored to head")
		_expect(await _speech_opens_mouth(facial), "Ziemek speech animates the mouth")
		var portrait_err := await PORTRAIT_CAPTURE.capture(player, "/tmp/choyce-ziemek-identity-closeup.png")
		if PORTRAIT_CAPTURE.is_headless():
			_expect(portrait_err == ERR_UNAVAILABLE, "portrait capture reports headless unavailability")
		else:
			_expect(portrait_err == OK, "Ziemek close-up portrait writes to disk")
			_expect(FileAccess.file_exists("/tmp/choyce-ziemek-identity-closeup.png"), "Ziemek close-up portrait file exists")

		player.set_hero_identity(PlayerController.HERO_IDENTITY_GNIEWKO)
		await process_frame
		_expect(player._hero_identity == PlayerController.HERO_IDENTITY_GNIEWKO, "switches hero identity to Gniewko")
		character = player.get_node_or_null("CharacterMesh") as Node3D
		_expect(character != null, "Gniewko character GLB mesh is mounted after identity switch")
		facial = _find_facial_performance(player)
		_expect(facial != null, "Gniewko identity keeps a facial performance")
		_expect(_is_bone_anchored(facial), "Gniewko facial performance stays bone-anchored after identity switch")

		player.set_weapon_visual("tool_axe")
		customization.face = "b"
		player.apply_customization(customization, true)
		await process_frame
		_expect(player._held_weapon != null and is_instance_valid(player._held_weapon), "face swap restores the held tool on the replacement rig")
		facial = _find_facial_performance(player)
		_expect(facial != null, "face swap recreates the facial performance")
		_expect(_is_bone_anchored(facial), "face swap keeps the facial performance bone-anchored")
		_expect(await _speech_opens_mouth(facial), "Gniewko speech animates the mouth after face swap")
		portrait_err = await PORTRAIT_CAPTURE.capture(player, "/tmp/choyce-gniewko-identity-closeup.png")
		if PORTRAIT_CAPTURE.is_headless():
			_expect(portrait_err == ERR_UNAVAILABLE, "portrait capture reports headless unavailability")
		else:
			_expect(portrait_err == OK, "Gniewko close-up portrait writes to disk")
			_expect(FileAccess.file_exists("/tmp/choyce-gniewko-identity-closeup.png"), "Gniewko close-up portrait file exists")
	runtime.queue_free()
	await process_frame
	if _failures.is_empty():
		print("[test_hero_identity_layer] OK")
		quit(0)
	else:
		printerr("[test_hero_identity_layer] FAIL count=", _failures.size())
		quit(1)


func _find_mesh(root_node: Node, wanted_name: String) -> MeshInstance3D:
	if root_node == null:
		return null
	if root_node is MeshInstance3D and root_node.name == wanted_name:
		return root_node as MeshInstance3D
	for child in root_node.get_children():
		var found := _find_mesh(child, wanted_name)
		if found != null:
			return found
	return null


func _find_first_mesh(root_node: Node) -> MeshInstance3D:
	if root_node == null:
		return null
	if root_node is MeshInstance3D:
		return root_node as MeshInstance3D
	for child in root_node.get_children():
		var found := _find_first_mesh(child)
		if found != null:
			return found
	return null


func _find_meshes(root_node: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	if root_node == null:
		return result
	if root_node is MeshInstance3D:
		result.append(root_node as MeshInstance3D)
	for child in root_node.get_children():
		result.append_array(_find_meshes(child))
	return result


func _all_meshes_use_explorer_material(meshes: Array[MeshInstance3D]) -> bool:
	for mesh in meshes:
		if not (mesh.material_override is StandardMaterial3D):
			return false
		var material := mesh.material_override as StandardMaterial3D
		if not material.albedo_color.is_equal_approx(Color("#30373a")):
			return false
		if mesh.mesh == null:
			return false
		for surface_index in mesh.mesh.get_surface_count():
			var surface_material := mesh.get_surface_override_material(surface_index)
			if not (surface_material is StandardMaterial3D) \
				or not (surface_material as StandardMaterial3D).albedo_color.is_equal_approx(Color("#30373a")):
				return false
	return true


func _find_facial_performance(player: PlayerController) -> FacialPerformance:
	if player == null:
		return null
	return player.find_child("FacialPerformance", true, false) as FacialPerformance


func _is_bone_anchored(facial: FacialPerformance) -> bool:
	if facial == null:
		return false
	var parent := facial.get_parent()
	if parent is BoneAttachment3D:
		var anchor := parent as BoneAttachment3D
		return anchor.bone_name == "head" and anchor.get_parent() is Skeleton3D
	return false


func _speech_opens_mouth(facial: FacialPerformance) -> bool:
	if facial == null:
		return false
	var mouth := facial.get_node_or_null("FaceMouth") as MeshInstance3D
	if mouth == null:
		return false
	var before := mouth.scale.y
	facial.speak_for(1.0, FacialPerformance.Emotion.HAPPY)
	for i in range(5):
		await process_frame
	return mouth.scale.y > before + 0.01
