extends SceneTree

const CONFIG_PATH := "res://data/performance/golden_scenes.json"
const DEFAULT_TIER := "tier1"

var _failures: Array[String] = []

func _init() -> void:
	var config := _load_config()
	if config.is_empty():
		quit(1)
		return

	var scenes_variant: Variant = config.get("scenes", [])
	if not (scenes_variant is Array):
		print("[FAIL] Performance config invalid: scenes must be an array")
		quit(1)
		return
	var scenes: Array = scenes_variant

	var tiers_variant: Variant = config.get("hardware_tiers", {})
	if not (tiers_variant is Dictionary):
		print("[FAIL] Performance config invalid: hardware_tiers must be a dictionary")
		quit(1)
		return
	var hardware_tiers: Dictionary = tiers_variant

	var tiers_to_run: Array[String] = _resolve_tiers(hardware_tiers)
	if tiers_to_run.is_empty():
		for failure in _failures:
			print("[FAIL] %s" % failure)
		quit(1)
		return

	var report: Dictionary = {
		"timestamp_utc": Time.get_datetime_string_from_system(true),
		"config_version": str(config.get("version", "unknown")),
		"tiers": {},
	}

	for tier in tiers_to_run:
		var tier_results: Array = []

		for scene_variant in scenes:
			if not (scene_variant is Dictionary):
				_failures.append("Scene config entry must be a dictionary")
				continue

			var scene: Dictionary = scene_variant
			var scene_id := str(scene.get("id", "unknown_scene"))
			var targets_variant: Variant = scene.get("targets", {})
			if not (targets_variant is Dictionary):
				_failures.append("%s targets must be a dictionary" % scene_id)
				continue
			var targets: Dictionary = targets_variant

			if not targets.has(tier):
				_failures.append("%s missing target budget for tier '%s'" % [scene_id, tier])
				continue

			var budget_variant: Variant = targets.get(tier, {})
			if not (budget_variant is Dictionary):
				_failures.append("%s target budget for tier '%s' is invalid" % [scene_id, tier])
				continue
			var budget: Dictionary = budget_variant

			var metrics := _benchmark_scene(scene)
			metrics["scene_id"] = scene_id
			metrics["tier"] = tier
			tier_results.append(metrics)
			_evaluate_budget(metrics, budget)

			print("PERF[%s/%s] cold_start_ms=%.2f interaction_latency_ms=%.4f fps=%.2f checksum=%d" % [
				tier,
				scene_id,
				float(metrics.get("cold_start_ms", 0.0)),
				float(metrics.get("interaction_latency_ms", 0.0)),
				float(metrics.get("fps", 0.0)),
				int(metrics.get("checksum", 0)),
			])

		report["tiers"][tier] = tier_results

	print("PERF_REPORT_JSON=%s" % JSON.stringify(report))

	if _failures.is_empty():
		print("Performance benchmarks passed for tiers: %s" % ", ".join(tiers_to_run))
		quit(0)
		return

	for failure in _failures:
		print("[FAIL] %s" % failure)
	quit(1)

func _load_config() -> Dictionary:
	if not FileAccess.file_exists(CONFIG_PATH):
		print("[FAIL] Missing performance config file: %s" % CONFIG_PATH)
		return {}

	var file := FileAccess.open(CONFIG_PATH, FileAccess.READ)
	if file == null:
		print("[FAIL] Failed to open performance config: %s" % CONFIG_PATH)
		return {}

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		print("[FAIL] Performance config is not a dictionary")
		return {}

	return parsed

func _resolve_tiers(hardware_tiers: Dictionary) -> Array[String]:
	var run_all := _env_flag("CHOYCE_PERF_RUN_ALL_TIERS")
	if run_all:
		return _sorted_tier_keys(hardware_tiers)

	var requested := OS.get_environment("CHOYCE_HARDWARE_TIER").strip_edges().to_lower()
	if requested.is_empty():
		requested = DEFAULT_TIER

	if not hardware_tiers.has(requested):
		_failures.append(
			"Unknown hardware tier '%s'. Available tiers: %s" % [requested, ", ".join(_sorted_tier_keys(hardware_tiers))]
		)
		return []

	return [requested]

func _sorted_tier_keys(tiers: Dictionary) -> Array[String]:
	var keys: Array = tiers.keys()
	keys.sort()
	var output: Array[String] = []
	for key_variant in keys:
		output.append(str(key_variant).to_lower())
	return output

func _env_flag(key: String) -> bool:
	var value := OS.get_environment(key).strip_edges().to_lower()
	return value == "1" or value == "true" or value == "yes" or value == "on"

func _benchmark_scene(scene: Dictionary) -> Dictionary:
	var workload_variant: Variant = scene.get("workload", {})
	var workload: Dictionary = {}
	if workload_variant is Dictionary:
		workload = workload_variant

	var node_count := int(workload.get("node_count", 200))
	var interaction_ops := int(workload.get("interaction_ops", 8000))
	var frame_samples := int(workload.get("frame_samples", 24))
	var frame_ops := int(workload.get("frame_ops", 16000))

	node_count = max(node_count, 1)
	interaction_ops = max(interaction_ops, 1)
	frame_samples = max(frame_samples, 1)
	frame_ops = max(frame_ops, 1)

	var scene_root := Node3D.new()
	scene_root.name = "benchmark_%s" % str(scene.get("id", "scene"))
	get_root().add_child(scene_root)

	var nodes: Array = []
	nodes.resize(node_count)

	var cold_start_begin := Time.get_ticks_usec()
	for node_idx in range(node_count):
		var node := Node3D.new()
		node.name = "bench_node_%d" % node_idx
		node.position = Vector3(float(node_idx % 19), float(node_idx % 11), float(node_idx % 13))
		scene_root.add_child(node)
		nodes[node_idx] = node
	var cold_start_ms := _to_msec(Time.get_ticks_usec() - cold_start_begin)

	var checksum := 146959810
	var interaction_begin := Time.get_ticks_usec()
	for op_idx in range(interaction_ops):
		var node_variant: Variant = nodes[op_idx % node_count]
		if node_variant is Node3D:
			var node: Node3D = node_variant
			var angle := deg_to_rad(float((op_idx * 13) % 360))
			node.position.x = wrapf(node.position.x + sin(angle) * 0.07, -100.0, 100.0)
			node.position.z = wrapf(node.position.z + cos(angle) * 0.07, -100.0, 100.0)
			checksum = int((checksum ^ int((node.position.x + 100.0) * 1000.0)) * 16777619) & 0x7fffffff
	var interaction_total_ms := _to_msec(Time.get_ticks_usec() - interaction_begin)
	var interaction_latency_ms := interaction_total_ms / float(interaction_ops)

	var frame_total_ms := 0.0
	for frame_idx in range(frame_samples):
		var frame_begin := Time.get_ticks_usec()
		var accumulator := 0.0
		for work_idx in range(frame_ops):
			var phase := deg_to_rad(float((work_idx + frame_idx * 17) % 360))
			accumulator += sin(phase) * cos(phase * 0.5)

		var target_variant: Variant = nodes[frame_idx % node_count]
		if target_variant is Node3D:
			var target: Node3D = target_variant
			target.rotation.y = wrapf(target.rotation.y + accumulator * 0.00005, 0.0, TAU)
			checksum = int((checksum + int(abs(accumulator) * 1000.0)) & 0x7fffffff)

		frame_total_ms += _to_msec(Time.get_ticks_usec() - frame_begin)

	var avg_frame_ms := frame_total_ms / float(frame_samples)
	var fps := 0.0
	if avg_frame_ms > 0.0:
		fps = 1000.0 / avg_frame_ms

	scene_root.free()

	return {
		"cold_start_ms": _round_to(cold_start_ms, 3),
		"interaction_latency_ms": _round_to(interaction_latency_ms, 6),
		"avg_frame_ms": _round_to(avg_frame_ms, 6),
		"fps": _round_to(fps, 3),
		"checksum": checksum,
	}

func _evaluate_budget(metrics: Dictionary, budget: Dictionary) -> void:
	var scene_id := str(metrics.get("scene_id", "unknown"))
	var tier := str(metrics.get("tier", "unknown"))

	var cold_start := float(metrics.get("cold_start_ms", INF))
	var cold_limit := float(budget.get("cold_start_ms_max", INF))
	if cold_start > cold_limit:
		_failures.append(
			"%s (%s) cold start regression: %.3fms > %.3fms" % [scene_id, tier, cold_start, cold_limit]
		)

	var interaction_latency := float(metrics.get("interaction_latency_ms", INF))
	var latency_limit := float(budget.get("interaction_latency_ms_max", INF))
	if interaction_latency > latency_limit:
		_failures.append(
			"%s (%s) interaction latency regression: %.6fms > %.6fms" % [
				scene_id,
				tier,
				interaction_latency,
				latency_limit,
			]
		)

	var fps := float(metrics.get("fps", 0.0))
	var fps_min := float(budget.get("fps_min", 0.0))
	if fps < fps_min:
		_failures.append("%s (%s) FPS regression: %.3f < %.3f" % [scene_id, tier, fps, fps_min])

func _to_msec(usec: int) -> float:
	return float(usec) / 1000.0

func _round_to(value: float, digits: int) -> float:
	var factor := pow(10.0, float(digits))
	return round(value * factor) / factor
