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
	# Co-op attaches after session setup in the real game. Mount the shared grid
	# here too so this test covers building, not only the second camera/avatar.
	runtime.call("_setup_build_grid")
	var split: SplitScreenRuntime = SPLIT_SCREEN.new().setup(runtime)
	root.add_child(split)
	split.attach_second_player()
	await process_frame
	var p2 := split.get_node_or_null("P2Container/P2Viewport/Player2") as PlayerController
	_expect(p2 != null, "co-op path creates a second playable character")
	if p2 != null:
		var shared_grid := runtime.get("_build_grid") as BuildGrid
		_expect(shared_grid != null and p2.get("_build_grid") == shared_grid, "P2 builds against the same authoritative grid")
		var p1 := runtime.get_node_or_null("PlayerController") as PlayerController
		if shared_grid != null and p1 != null:
			var undo_cell := Vector3i(170, 1, 170)
			shared_grid.place_block(undo_cell, "grass")
			Input.action_press("undo")
			p1.call("_process_build_input")
			p2.call("_process_build_input")
			Input.action_release("undo")
			_expect(not shared_grid.has_block_at(undo_cell), "P1 undo removes exactly one shared build edit; P2 ignores P1's key")
		p2.select_creative_item("brick")
		_expect("brick" in p2.get("_hotbar"), "P2 can select a creative material into its own hotbar")
		var capsule := p2.get_node_or_null("CollisionShape3D") as CollisionShape3D
		_expect(capsule != null and capsule.shape is CapsuleShape3D and is_equal_approx((capsule.shape as CapsuleShape3D).height, 1.8), "P2 uses P1's grounded 1.8m capsule")
		var camera := p2.get_node_or_null("Camera3D") as Camera3D
		_expect(camera != null and camera.position.is_equal_approx(Vector3(0.0, 1.7, 4.2)), "P2 camera matches the third-person P1 framing")
		_expect(InputMap.has_action("p2_look_left") and _action_has_key("p2_look_left", KEY_KP_7) and _action_has_key("p2_look_right", KEY_KP_9), "P2 has an independent keypad camera-look pair")
		_expect(not p2.get("_act_prefix").is_empty(), "P2 camera and build input are action-prefixed away from P1")
		var p2_yaw_before := p2.rotation.y
		var shared_mouse := InputEventMouseMotion.new()
		shared_mouse.relative = Vector2(45, 0)
		p2.call("_input", shared_mouse)
		_expect(is_equal_approx(p2.rotation.y, p2_yaw_before), "P2 ignores P1's shared mouse instead of mirroring its camera")
		Input.action_press("p2_look_left")
		p2.call("_process", 0.1)
		Input.action_release("p2_look_left")
		_expect(p2.rotation.y > p2_yaw_before, "P2 can rotate its own camera with the keypad look control")
		var character := p2.get_node_or_null("CharacterMesh") as Node3D
		# New hero-GLB architecture: P2's CharacterMesh is the gniewko.glb scene
		# (no HeroIdentityLayer, no Kenney backpack). Verify P2 carries Gniewko's
		# rig/mesh and never a second Ziemek backpack.
		var has_backpack := false
		if character != null:
			for m in character.find_children("*", "MeshInstance3D", true, false):
				if String((m as Node3D).name).to_lower().find("backpack") >= 0:
					has_backpack = true
					break
		_expect(not has_backpack, "P2 (Gniewko) carries no backpack — only Ziemek has one")
		# P2's mesh must contain the Mage-derived geometry baked into gniewko.glb.
		var has_gniewko_mesh := false
		if character != null:
			for m in character.find_children("*", "MeshInstance3D", true, false):
				if String((m as Node3D).name).find("Mage") >= 0 or String((m as Node3D).name).find("Gniewko") >= 0:
					has_gniewko_mesh = true
					break
		_expect(has_gniewko_mesh, "P2 uses the gniewko.glb mesh (Mage-derived)")
		var facial := _find_facial_performance(p2)
		_expect(facial != null, "P2 has a facial performance layer")
		_expect(_is_bone_anchored(facial), "P2 facial performance is bone-anchored to the shared humanoid rig")
		# Three direct tool signals model the normal three-hit harvest and prove
		# that P2's actor-targeting signal writes into GameplayRuntime's inventory.
		var p2_tree := Node3D.new()
		p2_tree.name = "P2HarvestTestTree"
		p2_tree.add_to_group("world_interactable")
		p2_tree.set_meta("interaction_action", "gather_wood")
		p2_tree.set_meta("resource_action", "gather_wood")
		p2_tree.set_meta("resource_item_id", "wood_oak")
		runtime.add_child(p2_tree)
		p2_tree.global_position = p2.global_position + Vector3(0, 0, -1.0)
		for _hit in 3:
			p2.tool_used.emit("tool_axe", p2.global_position, Vector3(0, 0, -1))
		var inventory_after_p2_harvest: Dictionary = runtime.call("_get_inventory") as Dictionary
		_expect(int(inventory_after_p2_harvest.get("wood_oak", 0)) == 1, "P2 harvesting writes to the shared inventory")
		inventory_after_p2_harvest["food_apple"] = 1
		runtime.call("_commit_inventory", inventory_after_p2_harvest, "food_apple")
		var p2_crafted := bool(runtime.call("_craft_inventory_recipe_for", p2, "meal"))
		var inventory_after_p2_craft: Dictionary = runtime.call("_get_inventory") as Dictionary
		_expect(p2_crafted and int(inventory_after_p2_craft.get("meal", 0)) == 1, "P2 crafting consumes and creates items in that same inventory")
		inventory_after_p2_craft["wood_oak"] = 3
		inventory_after_p2_craft["ore_iron"] = 2
		runtime.call("_commit_inventory", inventory_after_p2_craft, "ore_iron")
		var p2_sword := bool(runtime.call("_craft_inventory_recipe_for", p2, "sword_iron"))
		_expect(p2_sword and int(p2.get("_equipped_weapon_damage")) == 12 and (p1 == null or int(p1.get("_equipped_weapon_damage")) != 12), "P2-crafted gear equips P2 instead of teleporting to P1")
		var co_op_snapshot: SandboxState = runtime.get_sandbox_state()
		_expect(int(co_op_snapshot.inventory.get("meal", 0)) == 1 and int(co_op_snapshot.inventory.get("sword_iron", 0)) == 1, "Co-op snapshot retains the shared inventory before teardown")
	var p2_inventory := split.get_node_or_null("P2SharedInventoryOverlay") as PanelContainer
	_expect(p2_inventory != null and not p2_inventory.visible, "P2 receives its own initially closed shared-inventory panel")
	if p2_inventory != null and p2 != null:
		# tree_oak is a mineable producer (drop_id != block_id) and is now
		# intentionally filtered OUT of the creative catalog. Verify a
		# placeable block (stone) IS present instead.
		_expect(split.find_child("P2Creative_stone", true, false) != null, "P2 creative panel exposes placeable block kinds")
		split.call("_toggle_p2_inventory_overlay")
		_expect(p2_inventory.visible and p2.get("_input_disabled"), "P2 can open the shared inventory without moving in the world")
		split.call("_toggle_p2_inventory_overlay")
		_expect(not p2_inventory.visible and not p2.get("_input_disabled"), "P2 inventory closes and restores only P2 controls")
	split.teardown()
	_expect(_action_has_key("move_forward", KEY_UP), "Co-op teardown restores P1's arrow-key binding for the next solo session")
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


func _action_has_key(action: StringName, keycode: Key) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey and (event as InputEventKey).keycode == keycode:
			return true
	return false
