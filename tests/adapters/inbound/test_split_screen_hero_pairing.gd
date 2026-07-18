## Regression coverage for the two-protagonist local co-op join path.
## Run: godot --headless --path . --script tests/adapters/inbound/test_split_screen_hero_pairing.gd
extends SceneTree

const GAMEPLAY_SCENE := preload("res://src/adapters/inbound/gameplay/gameplay_runtime.tscn")
const SPLIT_SCREEN := preload("res://src/adapters/inbound/gameplay/split_screen_runtime.gd")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		_failures.append(message)
		printerr("FAIL: ", message)


func _run() -> void:
	var runtime := GAMEPLAY_SCENE.instantiate()
	root.add_child(runtime)
	await process_frame
	var split: SplitScreenRuntime = SPLIT_SCREEN.new().setup(runtime)
	root.add_child(split)
	split.attach_second_player()
	await process_frame
	var p2 := split.get_node_or_null("P2Container/P2Viewport/Player2") as PlayerController
	_expect(p2 != null, "co-op path creates a second playable character")
	if p2 != null:
		var capsule := p2.get_node_or_null("CollisionShape3D") as CollisionShape3D
		_expect(capsule != null and capsule.shape is CapsuleShape3D and is_equal_approx((capsule.shape as CapsuleShape3D).height, 1.8), "P2 uses P1's grounded 1.8m capsule")
		var camera := p2.get_node_or_null("Camera3D") as Camera3D
		_expect(camera != null and camera.position.is_equal_approx(Vector3(0.0, 1.7, 4.2)), "P2 camera matches the third-person P1 framing")
		var character := p2.get_node_or_null("CharacterMesh") as Node3D
		var layer := character.get_node_or_null("HeroIdentityLayer") if character != null else null
		_expect(layer != null and not layer.has_node("ZiemekBackpack"), "P2 selects Gniewko, not a second backpacked Ziemek")
		var body := _find_mesh(character, "body-mesh")
		if body != null and body.material_override is ShaderMaterial:
			var material := body.material_override as ShaderMaterial
			_expect(material.get_shader_parameter("garment_color").is_equal_approx(PlayerController.GNIEWKO_POLO), "P2 has Gniewko's light polo colour")
			_expect(material.get_shader_parameter("trouser_color").is_equal_approx(PlayerController.GNIEWKO_NAVY), "P2 has Gniewko's navy trouser colour")
		else:
			_expect(false, "P2 body keeps the hero garment shader")
		var facial := _find_facial_performance(p2)
		_expect(facial != null, "P2 has a facial performance layer")
		_expect(_is_bone_anchored(facial), "P2 facial performance is bone-anchored to the shared humanoid rig")
	split.teardown()
	runtime.queue_free()
	await process_frame
	if _failures.is_empty():
		print("[test_split_screen_hero_pairing] OK")
		quit(0)
	else:
		printerr("[test_split_screen_hero_pairing] FAIL count=", _failures.size())
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
