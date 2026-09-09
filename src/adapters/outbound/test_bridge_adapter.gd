class_name TestBridgeAdapter
extends TestBridgePort

## Debug-only adapter that exposes game state, screenshots, and input injection
## to an external AI test agent via a localhost HTTP server.
##
## PRODUCTION SAFETY: This adapter only activates when the debug feature flag
## "debug_test_bridge" is enabled. It must never be included in production exports.
## The HTTP server binds to 127.0.0.1 only — never 0.0.0.0.
## No child PII is transmitted; all state uses anonymised session IDs.
##
## Integration: gdGSI-compatible section-based state pushes.
## Input injection: GoPeak MCP server routes mouse/key events here.

const DEFAULT_PORT: int = 9876
const BIND_ADDRESS: String = "127.0.0.1"

var _http_server: TCPServer
var _clients: Array = []
var _state_store: Dictionary = {}
var _feature_flags: Object  # FeatureFlagService duck-typed
var _port: int = DEFAULT_PORT
var _active: bool = false


func setup(p_feature_flags: Object, p_port: int = DEFAULT_PORT) -> void:
	_feature_flags = p_feature_flags
	_port = p_port


func start() -> bool:
	if _feature_flags != null and _feature_flags.has_method("is_enabled"):
		if not _feature_flags.is_enabled("debug_test_bridge"):
			return false
	_http_server = TCPServer.new()
	var err: int = _http_server.listen(_port, BIND_ADDRESS)
	if err != OK:
		push_warning("TestBridgeAdapter: failed to bind on %s:%d (err %d)" % [BIND_ADDRESS, _port, err])
		return false
	_active = true
	return true


func stop() -> void:
	_active = false
	if _http_server != null:
		_http_server.stop()
	_clients.clear()


## Called each frame from the adapter owner to accept and service HTTP clients.
func poll() -> void:
	if not _active or _http_server == null:
		return
	if _http_server.is_connection_available():
		var conn: StreamPeerTCP = _http_server.take_connection()
		if conn != null:
			_clients.append(conn)
	var done: Array = []
	for conn in _clients:
		conn.poll()
		if conn.get_status() == StreamPeerTCP.STATUS_NONE or \
		   conn.get_status() == StreamPeerTCP.STATUS_ERROR:
			done.append(conn)
			continue
		_service_connection(conn)
		if conn.get_status() == StreamPeerTCP.STATUS_NONE or \
		   conn.get_status() == StreamPeerTCP.STATUS_ERROR:
			done.append(conn)
	for conn in done:
		_clients.erase(conn)


# ── TestBridgePort overrides ─────────────────────────────────────────────────

func get_game_state() -> Dictionary:
	var state := _state_store.duplicate(true)
	var runtime := get_tree().root.get_node_or_null("GameplayRuntime")
	if runtime != null:
		var runtime_state := {
			"sandbox_active": bool(runtime.get("_sandbox_kit_active")),
			"session_active": runtime.get("_session") != null,
			"mouse_mode": Input.mouse_mode,
			"players": [],
			"inventory": runtime.call("_get_inventory") if runtime.has_method("_get_inventory") else {},
			"dialogue_visible": _runtime_dialogue_visible(runtime) or _state_store.has("dialogue"),
			"enemies_alive": _alive_enemy_count(),
			"slice_repaired": bool(runtime.get("_sandbox_slice_repaired")),
			"slice_reward_claimed": bool(runtime.get("_sandbox_slice_reward_claimed")),
			"score": int(runtime.get("_score")),
			"weapon_tier": int(runtime.get("_current_weapon_index")),
			"objective_step": int(runtime.get("_sandbox_objective_step")),
		}
		var registry := get_node_or_null("/root/PlayerRegistry")
		if registry != null and registry.has_method("profiles"):
			for profile in registry.profiles():
				var body: Node3D = profile.body if profile != null else null
				if body == null or not is_instance_valid(body):
					continue
				var player_state := {
					"player_id": int(profile.player_id),
					"yaw": float(body.get("_yaw")),
					"position": _vector_to_dict(body.global_position),
					"is_on_floor": body.is_on_floor(),
					"animation": String(body.get("_current_animation")),
				}
				var floor_normal: Vector3 = body.get_floor_normal()
				player_state["floor_normal"] = _vector_to_dict(floor_normal)
				var query := PhysicsRayQueryParameters3D.create(
					body.global_position + Vector3.UP * 4.0,
					body.global_position + Vector3.DOWN * 6.0)
				query.collision_mask = Layers.SOLID_WORLD
				query.exclude = [body.get_rid()]
				var hit := body.get_world_3d().direct_space_state.intersect_ray(query)
				if not hit.is_empty():
					player_state["floor_probe"] = {
						"position": _vector_to_dict(hit["position"]),
						"name": (hit["collider"] as Node).name,
						"collider": str((hit["collider"] as Node).get_path()),
					}
				player_state["collision"] = {
					"shape_count": body.find_children("*", "CollisionShape3D", true, false).size(),
					"layer": body.collision_layer,
					"mask": body.collision_mask,
				}
				var camera := profile.camera as Camera3D
				if camera != null and is_instance_valid(camera):
					player_state["camera_position"] = _vector_to_dict(camera.global_position)
				var spring_arm := body.get("_spring_arm") as SpringArm3D
				if spring_arm != null and is_instance_valid(spring_arm):
					player_state["spring_arm"] = {
						"target_length": spring_arm.spring_length,
						"hit_length": spring_arm.get_hit_length(),
						"collision_mask": spring_arm.collision_mask,
					}
				runtime_state["players"].append(player_state)
		runtime_state["environment"] = _runtime_environment_probe(runtime)
		runtime_state["feedback"] = {
			"action_icon_visible": _control_visible(runtime.get("_action_feedback_icon")),
			"interaction_icon_present": runtime.get("_interaction_prompt_icon") != null,
			"objective_icon_count": (runtime.get("_sandbox_objective_icons") as Array).size(),
		}
		runtime_state["companions"] = _runtime_companion_probe(runtime)
		runtime_state["probes"] = _runtime_probes(runtime)
		state["runtime"] = runtime_state
	return state


func _runtime_dialogue_visible(runtime: Node) -> bool:
	var label := runtime.get("_npc_dialogue_label") as Control
	return label != null and is_instance_valid(label) and label.visible


func _control_visible(value: Variant) -> bool:
	var control := value as Control
	return control != null and is_instance_valid(control) and control.visible


func _runtime_companion_probe(runtime: Node) -> Array:
	var companions: Array = []
	for candidate in get_tree().get_nodes_in_group("navigation_agent"):
		var agent := candidate as NavigationAgent3D
		if agent == null or not is_instance_valid(agent):
			continue
		var owner := agent.get_parent() as Node3D
		if owner == null or not is_instance_valid(owner):
			continue
		companions.append({
			"name": owner.name,
			"position": _vector_to_dict(owner.global_position),
			"moving": bool(owner.get("_moving")) if owner.get_script() != null else false,
			"animation": String((owner.get("_animator") as AnimationPlayer).current_animation)
				if owner.get("_animator") is AnimationPlayer else "",
		})
	return companions


func _runtime_environment_probe(runtime: Node) -> Dictionary:
	for candidate in runtime.find_children("*", "WorldEnvironment", true, false):
		var world_environment := candidate as WorldEnvironment
		if world_environment == null or world_environment.environment == null:
			continue
		var environment := world_environment.environment
		return {
			"found": true,
			"background_mode": environment.background_mode,
			"ssao_enabled": environment.ssao_enabled,
			"glow_enabled": environment.glow_enabled,
			"fog_enabled": environment.fog_enabled,
			"tonemap_mode": environment.tonemap_mode,
			"ambient_energy": environment.ambient_light_energy,
		}
	return {"found": false}


func _alive_enemy_count() -> int:
	var count := 0
	for candidate in get_tree().get_nodes_in_group("enemies"):
		if candidate == null or not is_instance_valid(candidate):
			continue
		var health := candidate.get("health") as Node
		if health == null or bool(health.get("is_alive")):
			count += 1
	return count


func _runtime_probes(runtime: Node) -> Dictionary:
	var interactables: Array = []
	for candidate in get_tree().get_nodes_in_group("world_interactable"):
		if candidate == null or not is_instance_valid(candidate) or not candidate is Node3D:
			continue
		var node := candidate as Node3D
		interactables.append({
			"name": node.name,
			"action": String(node.get_meta("interaction_action", "")),
			"has_collision": node.find_children("*", "CollisionShape3D", true, false).size() > 0,
			"position": _vector_to_dict(node.global_position),
		})
	var navigation_regions := get_tree().get_nodes_in_group("navigation_region")
	var navigation_agents := get_tree().get_nodes_in_group("navigation_agent")
	var reachable_agents := 0
	for agent_variant in navigation_agents:
		var agent := agent_variant as NavigationAgent3D
		if agent != null and agent.is_target_reachable():
			reachable_agents += 1
	var missing_materials := 0
	var materialized_meshes := 0
	for mesh_variant in runtime.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := mesh_variant as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		materialized_meshes += 1
		for surface_index in mesh_instance.mesh.get_surface_count():
			if mesh_instance.get_active_material(surface_index) == null:
				missing_materials += 1
	return {
		"interactables": interactables,
		"navigation": {
			"regions": navigation_regions.size(),
			"agents": navigation_agents.size(),
			"reachable_agents": reachable_agents,
			"reachable": navigation_regions.size() > 0 and reachable_agents > 0,
		},
		"materials": {
			"meshes": materialized_meshes,
			"missing_surfaces": missing_materials,
		},
		"scene_path": str(runtime.get_path()),
	}


func _vector_to_dict(value: Vector3) -> Dictionary:
	return {"x": value.x, "y": value.y, "z": value.z}


func capture_screenshot() -> PackedByteArray:
	if not _active:
		return PackedByteArray()
	if OS.has_feature("headless"):
		return PackedByteArray()
	var img: Image = null
	var runtime := get_tree().root.get_node_or_null("GameplayRuntime")
	if runtime != null:
		var stage := runtime.get("_sandbox_kit_stage") as Node
		var pane := stage.get_node_or_null("PaneGrid/Pane0/SubViewport") if stage != null else null
		if pane is SubViewport and pane.get_texture() != null:
			img = pane.get_texture().get_image()
	if img == null or img.is_empty():
		var viewport := get_tree().root
		if viewport != null and viewport.get_texture() != null:
			img = viewport.get_texture().get_image()
	if img == null or img.is_empty():
		img = DisplayServer.screen_get_image(0)
	if img == null:
		return PackedByteArray()
	return img.save_png_to_buffer()


func inject_input(p_event: Dictionary) -> bool:
	if not _active:
		return false
	var type: String = p_event.get("type", "")
	match type:
		"action":
			var ev := InputEventAction.new()
			ev.action = p_event.get("action_name", "")
			ev.pressed = p_event.get("pressed", true)
			Input.parse_input_event(ev)
			return true
		"mouse_button":
			var ev := InputEventMouseButton.new()
			ev.button_index = p_event.get("button_index", MOUSE_BUTTON_LEFT)
			ev.pressed = p_event.get("pressed", true)
			var pos: Vector2 = _normalised_to_screen(p_event.get("position", Vector2(0.5, 0.5)))
			ev.position = pos
			ev.global_position = pos
			Input.parse_input_event(ev)
			return true
		"key":
			var ev := InputEventKey.new()
			ev.keycode = p_event.get("keycode", KEY_NONE)
			ev.pressed = p_event.get("pressed", true)
			Input.parse_input_event(ev)
			return true
		"mouse_motion":
			var ev := InputEventMouseMotion.new()
			var pos: Vector2 = _normalised_to_screen(p_event.get("position", Vector2(0.5, 0.5)))
			ev.position = pos
			ev.global_position = pos
			var relative_variant: Variant = p_event.get("relative", Vector2.ZERO)
			if relative_variant is Vector2:
				ev.relative = relative_variant
			elif relative_variant is Dictionary:
				ev.relative = Vector2(
					float(relative_variant.get("x", 0.0)),
					float(relative_variant.get("y", 0.0)))
			var velocity_variant: Variant = p_event.get("velocity", Vector2.ZERO)
			if velocity_variant is Vector2:
				ev.velocity = velocity_variant
			elif velocity_variant is Dictionary:
				ev.velocity = Vector2(
					float(velocity_variant.get("x", 0.0)),
					float(velocity_variant.get("y", 0.0)))
			Input.parse_input_event(ev)
			return true
	return false


func execute_action(p_action: Dictionary) -> bool:
	if not _active:
		return false
	var runtime := get_tree().root.get_node_or_null("GameplayRuntime")
	if runtime == null:
		return false
	match String(p_action.get("action", "")):
		"dialogue":
			var line := "Hej! Jestem Olek. Wybierz kierunek i zobaczmy, co odkryjemy."
			runtime.call("_show_npc_dialogue", "Hania", line, true)
			_state_store["dialogue"] = {"npc": "Hania", "line": line, "offline_voice": true}
			return true
		"gather":
			var anchor := runtime.get_node_or_null("SandboxKitStage/WorldHost/SandboxLevel/AuthoredVillagePresentation/%s" % String(p_action.get("node", ""))) as Node3D
			if anchor == null:
				return false
			runtime.call("_gather_world_resource", anchor)
			return true
		"craft":
			runtime.call("_craft_inventory_recipe", String(p_action.get("recipe", "stick")))
			return true
		"repair", "reward":
			var node_name := "OpeningSliceHouseRepair" if String(p_action.get("action")) == "repair" else "OpeningSliceReward"
			var interaction := runtime.get_node_or_null("SandboxKitStage/WorldHost/SandboxLevel/AuthoredVillagePresentation/%s" % node_name) as Node3D
			if interaction == null:
				return false
			runtime.set("_nearby_world_interactable", interaction)
			runtime.call("_activate_world_interaction")
			return true
		"attack":
			var player := runtime.get("_player_controller") as Node
			if player == null:
				return false
			var enemy := get_tree().get_first_node_in_group("enemies") as Node3D
			if enemy == null:
				return false
			player.global_position = enemy.global_position + Vector3(0.0, 0.0, 1.4)
			player.set("_yaw", PI)
			for _hit in range(4):
				var health := enemy.get("health") as Object
				if health != null:
					health.set("invuln_remaining", 0.0)
				enemy.call("apply_damage", 10, player.global_position, "punch")
			return true
		"save":
			_state_store["save"] = {"inventory": runtime.call("_get_inventory").duplicate(true), "score": int(runtime.get("_score"))}
			return true
		"reset":
			runtime.call("reset_sandbox_slice_state")
			return true
	return false


func set_state_section(p_section: String, p_data: Dictionary) -> void:
	_state_store[p_section] = p_data


# ── HTTP request dispatch ─────────────────────────────────────────────────────

func _service_connection(conn: StreamPeerTCP) -> void:
	conn.poll()
	if conn.get_available_bytes() == 0:
		return
	var raw: String = conn.get_string(conn.get_available_bytes())
	var first_line: String = raw.split("\n")[0].strip_edges()
	var parts: PackedStringArray = first_line.split(" ")
	if parts.size() < 2:
		_send_response(conn, 400, "Bad Request", "text/plain", "Bad request line")
		return
	var method: String = parts[0]
	var path: String = parts[1]
	match path:
		"/state":
			var body: String = JSON.stringify(get_game_state())
			_send_response(conn, 200, "OK", "application/json", body)
		"/screenshot":
			var png: PackedByteArray = capture_screenshot()
			if png.is_empty():
				_send_response(conn, 503, "Service Unavailable", "text/plain", "No display")
			else:
				_send_binary_response(conn, 200, "OK", "image/png", png)
		"/input":
			if method != "POST":
				_send_response(conn, 405, "Method Not Allowed", "text/plain", "POST only")
				return
			var body_start: int = raw.find("\r\n\r\n")
			if body_start == -1:
				body_start = raw.find("\n\n")
			var json_body: String = raw.substr(body_start + 4) if body_start != -1 else ""
			var parsed = JSON.parse_string(json_body)
			if parsed == null or not parsed is Dictionary:
				_send_response(conn, 400, "Bad Request", "text/plain", "Invalid JSON")
				return
			var ok: bool = inject_input(parsed)
			_send_response(conn, 200, "OK", "application/json", JSON.stringify({"accepted": ok}))
		"/action":
			if method != "POST":
				_send_response(conn, 405, "Method Not Allowed", "text/plain", "POST only")
				return
			var action_body_start: int = raw.find("\r\n\r\n")
			if action_body_start == -1:
				action_body_start = raw.find("\n\n")
			var action_json: String = raw.substr(action_body_start + 4) if action_body_start != -1 else ""
			var action_parsed = JSON.parse_string(action_json)
			if action_parsed == null or not action_parsed is Dictionary:
				_send_response(conn, 400, "Bad Request", "text/plain", "Invalid JSON")
				return
			var action_ok := execute_action(action_parsed)
			_send_response(conn, 200, "OK", "application/json", JSON.stringify({"accepted": action_ok}))
		"/health":
			_send_response(conn, 200, "OK", "application/json", JSON.stringify({"status": "ok", "active": _active}))
		_:
			_send_response(conn, 404, "Not Found", "text/plain", "Unknown endpoint")


func _send_response(conn: StreamPeerTCP, code: int, status: String,
		content_type: String, body: String) -> void:
	var encoded: PackedByteArray = body.to_utf8_buffer()
	var headers: String = "HTTP/1.1 %d %s\r\nContent-Type: %s\r\nContent-Length: %d\r\nConnection: close\r\n\r\n" \
		% [code, status, content_type, encoded.size()]
	conn.put_data(headers.to_utf8_buffer())
	conn.put_data(encoded)


func _send_binary_response(conn: StreamPeerTCP, code: int, status: String,
		content_type: String, body: PackedByteArray) -> void:
	var headers: String = "HTTP/1.1 %d %s\r\nContent-Type: %s\r\nContent-Length: %d\r\nConnection: close\r\n\r\n" \
		% [code, status, content_type, body.size()]
	conn.put_data(headers.to_utf8_buffer())
	conn.put_data(body)


func _normalised_to_screen(p_norm: Variant) -> Vector2:
	var viewport_size: Vector2 = DisplayServer.screen_get_size()
	var nv: Vector2 = Vector2(0.5, 0.5)
	if p_norm is Vector2:
		nv = p_norm
	elif p_norm is Dictionary:
		nv = Vector2(float(p_norm.get("x", 0.5)), float(p_norm.get("y", 0.5)))
	return Vector2(nv.x * viewport_size.x, nv.y * viewport_size.y)
