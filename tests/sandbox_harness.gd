extends Node
## Live acceptance test for the whole kit. Runs in-game, asserts real behaviour
## against the real systems, and prints a PASS/FAIL table.
##
## This is deliberately an integration harness, not unit tests: every bug found
## so far in this project (0x0 viewports, SubViewportContainer layout, world_host
## render spam) was an integration bug that unit tests would have missed.

@export var auto_join_players: int = 4
@export var report_after_seconds: float = 2.5

var _manager: SplitScreenManager
var _results: Array[Dictionary] = []


func _ready() -> void:
	_manager = get_parent() as SplitScreenManager
	await get_tree().process_frame
	var reg := PlayerRegistrySystem.instance
	for i in auto_join_players:
		reg.join(-1 if i == 0 else i - 1)
	await get_tree().create_timer(report_after_seconds).timeout
	_run()


func _check(name: String, condition: bool, detail: String = "") -> void:
	_results.append({"name": name, "ok": condition, "detail": detail})


func _run() -> void:
	var reg := PlayerRegistrySystem.instance
	var build := BuildSystem.instance
	var profiles := reg.profiles()

	# --- split screen -------------------------------------------------------
	_check("players joined", profiles.size() == auto_join_players,
		"%d/%d" % [profiles.size(), auto_join_players])

	var host_space := _manager.world_host.world_3d.space
	var shared := true
	var sizes_ok := true
	for p in profiles:
		if p.viewport == null:
			shared = false
			continue
		shared = shared and p.viewport.world_3d.space == host_space and not p.viewport.own_world_3d
		sizes_ok = sizes_ok and p.viewport.size.x > 100 and p.viewport.size.y > 60
	_check("one shared World3D across all panes", shared, str(host_space))
	_check("every pane has a real size", sizes_ok,
		str(profiles[0].viewport.size) if profiles.size() > 0 else "n/a")

	# --- graphics tiering ---------------------------------------------------
	var g := _manager.last_graphics
	_check("graphics tier applied", not g.is_empty(), str(g))
	if not g.is_empty():
		_check("shadow cascades reduced at 4 players", int(g.get("splits", 4)) <= 2,
			"splits=%s dist=%s" % [g.get("splits"), g.get("shadow_distance")])
		_check("directional lights actually touched", int(g.get("lights_touched", 0)) > 0,
			"lights=%s viewports=%s" % [g.get("lights_touched"), g.get("viewports_touched")])

	# --- component substrate ------------------------------------------------
	var crate := _find_first_crate()
	_check("found a componented prop", crate != null, crate.name if crate else "none")
	if crate:
		var health := Components.get_comp(crate, Components.HEALTH) as HealthComponent
		var grab := Components.get_comp(crate, Components.GRAB) as GrabComponent
		var inter := Components.get_comp(crate, Components.INTERACTABLE)
		var dest := Components.get_comp(crate, Components.DESTRUCTIBLE)
		_check("prop resolves health/grab/interactable/destructible",
			health != null and grab != null and inter != null and dest != null)
		_check("Components.entity_of walks up from a child",
			Components.entity_of(crate.get_child(0)) == crate)

		# Damage routing through the real DamageInfo -> Hurtbox -> Health path.
		if health:
			var before := health.current
			var info := DamageInfo.make(5.0, DamageInfo.Type.IMPACT, 0,
				crate.global_position, Vector3.UP)
			HurtboxComponent.deliver(crate, info)
			_check("damage routes through HurtboxComponent.deliver",
				health.current < before, "%.1f -> %.1f" % [before, health.current])

			# Threshold rejection: a 0.1 nudge must NOT chip the crate.
			var mid := health.current
			HurtboxComponent.deliver(crate, DamageInfo.make(0.1, DamageInfo.Type.IMPACT))
			_check("sub-threshold damage is ignored", is_equal_approx(health.current, mid),
				"%.2f" % health.current)

	# --- destruction + debris budget ---------------------------------------
	var victim := _find_first_crate()
	if victim:
		var vh := Components.get_comp(victim, Components.HEALTH) as HealthComponent
		if vh:
			HurtboxComponent.deliver(victim, DamageInfo.make(9999.0,
				DamageInfo.Type.EXPLOSIVE, 0, victim.global_position, Vector3.UP))
			await get_tree().physics_frame
			await get_tree().physics_frame
			var d := DebrisBudget.instance.stats()
			_check("destroying a prop spawns budgeted debris", int(d["live"]) > 0, str(d))
			_check("debris stays under cap", int(d["live"]) <= int(d["cap"]), str(d))

	# --- building -----------------------------------------------------------
	var bs := build.stats()
	_check("block palette registered", int(bs["palette"]) >= 4, str(bs))
	_check("starter structure placed into chunks", int(bs["blocks"]) > 0, str(bs))
	_check("chunks exist", int(bs["chunks"]) > 0, str(bs))

	var id: StringName = build.palette[0]
	var free_spot := Transform3D(Basis.IDENTITY, Vector3(20, 6, 20))
	_check("can_place accepts empty space", build.can_place(id, free_spot))
	var placed := build.place(id, free_spot, 0)
	_check("place() succeeds in empty space", placed)
	_check("can_place rejects an occupied cell", not build.can_place(id, free_spot),
		"same transform after placing")

	var removed := build.remove_at(Vector3(20, 6, 20), 0)
	_check("remove_at removes the block just placed", removed)

	# --- chunk hot/cold -----------------------------------------------------
	var far := Transform3D(Basis.IDENTITY, Vector3(300, 2, 300))
	var saved_grace := build.hot_grace_seconds
	# A freshly-edited chunk stays HOT for hot_grace_seconds by design (you must
	# not cold-bake a chunk a player is actively building in). Shorten the grace
	# for the test instead of sleeping through it.
	build.hot_grace_seconds = 0.05
	build.place(id, far, 0, Color.WHITE, false)
	_check("far chunk is hot immediately after an edit (grace window)",
		int(build.stats()["chunks_hot"]) > 0, str(build.stats()))
	await get_tree().create_timer(0.3).timeout
	var bs2 := build.stats()
	build.hot_grace_seconds = saved_grace
	_check("far chunk goes cold once grace expires (MultiMesh bake)",
		int(bs2["chunks"]) > int(bs["chunks"]) and int(bs2["chunks_hot"]) < int(bs2["chunks"]),
		str(bs2))

	# --- save / load round trip --------------------------------------------
	var saves := SaveSystem.instance
	var before_blocks := int(build.stats()["blocks"])
	_check("save writes a slot", saves.save("harness"))
	_check("loading round-trips block count", saves.load_into_world("harness")
		and int(build.stats()["blocks"]) == before_blocks,
		"%d -> %d" % [before_blocks, int(build.stats()["blocks"])])
	_check("load rejected nothing on a clean file", saves.last_rejected == 0,
		"rejected=%d" % saves.last_rejected)
	_check("hostile record is rejected by validation",
		PlacedBlockComponent.from_record({"id": 42, "pos": "not a vector"}).is_empty())
	_check("NaN position is rejected",
		PlacedBlockComponent.from_record(
			{"id": "x", "pos": Vector3(NAN, 0, 0), "rot": Vector3.ZERO}).is_empty())

	# --- audio (Spike B) ----------------------------------------------------
	var router := AudioRouter.instance
	_check("audio router exists", router != null)

	# --- player identity (regression: setup() must precede add_child) -------
	var identity_ok := true
	var devices_seen := {}
	for p in profiles:
		if not is_instance_valid(p.body):
			identity_ok = false
			continue
		var mesh := p.body.get_node_or_null("Body") as MeshInstance3D
		var mat := mesh.material_override as StandardMaterial3D if mesh else null
		if mat == null or not mat.albedo_color.is_equal_approx(p.colour):
			identity_ok = false
		devices_seen[p.body.get("device")] = true
	_check("each player wears its own colour (setup ran before _ready)", identity_ok)
	_check("each player bound to a distinct input device",
		devices_seen.size() == profiles.size(), str(devices_seen.keys()))

	# --- post-review regression checks --------------------------------------
	# 1. Aim rays must originate at the player's head and point where they look,
	#    NOT from the camera through the player's head.
	var aim_ok := true
	for p in profiles:
		if not is_instance_valid(p.body):
			aim_ok = false
			continue
		var head: Vector3 = (p.body as Node3D).global_position + Vector3.UP
		if p.aim_origin().distance_to(head) > 1.5:
			aim_ok = false
		# The aim must not point back toward the camera.
		if is_instance_valid(p.camera):
			var to_cam: Vector3 = (p.camera.global_position - p.aim_origin()).normalized()
			if p.aim_direction().dot(to_cam) > 0.2:
				aim_ok = false
	_check("aim originates at the head and points away from the camera", aim_ok)

	# 2. Each player's build ghost must be visible only in their own pane.
	var cull_ok := true
	var seen_masks := {}
	for p in profiles:
		if not is_instance_valid(p.camera):
			cull_ok = false
			continue
		seen_masks[p.camera.cull_mask] = true
		var own_bit := 1 << (10 + p.player_id)
		if (p.camera.cull_mask & own_bit) == 0:
			cull_ok = false
		for other in profiles:
			if other.player_id == p.player_id:
				continue
			if (p.camera.cull_mask & (1 << (10 + other.player_id))) != 0:
				cull_ok = false
	_check("per-player cull masks isolate build ghosts", cull_ok,
		"%d distinct masks" % seen_masks.size())

	# 3. Players must be damageable (they had no hurtbox at all).
	var hurt_ok := true
	for p in profiles:
		var hb := Components.get_comp(p.body, Components.HURTBOX) as HurtboxComponent
		if hb == null or hb.collision_layer != Layers.PLAYER_HURTBOX:
			hurt_ok = false
	_check("players have a PLAYER_HURTBOX hurtbox", hurt_ok)

	# 4. Bulk load must not be O(n^2). 3000 records into one chunk used to
	#    allocate ~4.5M CollisionShape3D nodes held resident in a single frame.
	var bulk := []
	for i in 3000:
		bulk.append({"id": String(id), "by": 0,
			"pos": Vector3(600.0 + float(i % 20) * 1.5, 1.0, 600.0 + float(i / 20) * 1.5),
			"rot": Vector3.ZERO, "tint": Color.WHITE})
	var t0 := Time.get_ticks_msec()
	var bulk_placed: int = build.place_bulk(bulk, 0)
	var bulk_ms := Time.get_ticks_msec() - t0
	_check("place_bulk handles 3000 records", bulk_placed > 0, "%d placed" % bulk_placed)
	_check("place_bulk is not O(n^2)", bulk_ms < 2000, "%d ms" % bulk_ms)

	# 5. Hostile save-record rejections found by review.
	_check("oversized block id rejected", PlacedBlockComponent.from_record(
		{"id": "x".repeat(500), "pos": Vector3.ZERO, "rot": Vector3.ZERO}).is_empty())
	_check("non-dictionary record rejected (untyped param)",
		PlacedBlockComponent.from_record(12345).is_empty())
	var hdr := PlacedBlockComponent.from_record({"id": "x", "pos": Vector3.ZERO,
		"rot": Vector3.ZERO, "tint": Color(1e30, 1e30, 1e30, 1.0)})
	_check("HDR flashbang tint clamped to 0..1",
		not hdr.is_empty() and (hdr["tint"] as Color).r <= 1.0, str(hdr.get("tint")))
	_check("out-of-range owner id rejected", PlacedBlockComponent.from_record(
		{"id": "x", "pos": Vector3.ZERO, "rot": Vector3.ZERO, "by": 99}).is_empty())
	var wrapped := PlacedBlockComponent.from_record({"id": "x", "pos": Vector3.ZERO,
		"rot": Vector3(1e30, 1e30, 1e30)})
	_check("huge finite rotation wrapped into 0..TAU",
		not wrapped.is_empty() and (wrapped["rot"] as Vector3).x < TAU,
		str(wrapped.get("rot")))

	# --- interaction --------------------------------------------------------
	_check("interactables registered with the system",
		InteractionSystem.instance.registry_size() > 0,
		str(InteractionSystem.instance.registry_size()))

	_print_report()


func _find_first_crate() -> RigidBody3D:
	var props := _manager.level.get_node_or_null("Props")
	if props == null:
		return null
	for child in props.get_children():
		if child is RigidBody3D and Components.has(child, Components.HEALTH):
			var h := Components.get_comp(child, Components.HEALTH) as HealthComponent
			if h and not h.is_dead:
				return child
	return null


func _print_report() -> void:
	var passed := 0
	print("[KIT] ================ acceptance report ================")
	for r in _results:
		var mark := "PASS" if r["ok"] else "FAIL"
		if r["ok"]:
			passed += 1
		print("[KIT] %s  %s %s" % [mark, r["name"],
			("(" + str(r["detail"]) + ")") if r["detail"] != "" else ""])
	print("[KIT] ---------------------------------------------------")
	print("[KIT] %d/%d passed" % [passed, _results.size()])
	print("[KIT] fps=%.1f draw_calls=%d prims=%d" % [
		Engine.get_frames_per_second(),
		int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))])
	print("[KIT] build=%s debris=%s fx=%s" % [
		str(BuildSystem.instance.stats()),
		str(DebrisBudget.instance.stats()),
		str(FXPool.instance.stats())])
	print("[KIT] ===================================================")
