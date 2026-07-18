## The Adventure uses the locally installed Sky3D addon instead of a frozen
## procedural sky, while retaining the project's established Environment data.
extends SceneTree

const GameplayRuntimeScene = preload("res://src/adapters/inbound/gameplay/gameplay_runtime.tscn")

var _exit_code := 0


func _init() -> void:
	call_deferred("_run")


func _assert(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		print("FAIL: %s" % message)
		_exit_code = 1


func _run() -> void:
	var runtime := GameplayRuntimeScene.instantiate() as GameplayRuntime
	get_root().add_child(runtime)
	await process_frame
	var adventure_world := World.new("sky_test", "Sky test")
	adventure_world.theme = "adventure"
	runtime.start_session(adventure_world, Session.new("sky_session", adventure_world.world_id))
	await process_frame
	var sky := runtime.get_node_or_null("AdventureSky3D") as WorldEnvironment
	_assert(sky != null and sky.environment != null, "Adventure replaces the frozen sky with Sky3D")
	_assert(sky != null and sky.environment != null and sky.environment.sky != null
		and sky.environment.sky.sky_material is ShaderMaterial,
		"the transferred Environment receives Sky3D's animated shader material")
	_assert(get_root().get_viewport().world_3d.environment == sky.environment,
		"Sky3D's Environment is the active viewport atmosphere")
	var dome := sky.get_node_or_null("SkyDome")
	_assert(dome != null and dome.get("sky_material") == sky.environment.sky.sky_material,
		"SkyDome animates the same shader material the viewport renders")
	_assert(sky != null and sky.get_node_or_null("SunLight") is DirectionalLight3D,
		"Sky3D provides a real shadow-casting sun")
	_assert(sky != null and sky.get_node_or_null("MoonLight") is DirectionalLight3D,
		"Sky3D provides a moonlight transition for night exploration")
	_assert(sky != null and sky.get_node_or_null("SkyDome") != null,
		"Sky3D creates its cloud-and-atmosphere dome")
	var legacy_environment := runtime.get_node_or_null("WorldEnvironment") as WorldEnvironment
	_assert(legacy_environment != null and legacy_environment.environment == null,
		"the static Environment is detached while Sky3D is active")
	_assert(not (runtime.get_node_or_null("DirectionalLight3D") as DirectionalLight3D).visible
		and not (runtime.get_node_or_null("FillLight") as DirectionalLight3D).visible,
		"legacy lights do not double-light the Sky3D world")
	if sky != null:
		sky.set("current_time", 22.0)
		await process_frame
		_assert(bool(sky.call("is_night")), "Sky3D exposes a usable night state for future monster behavior")
	runtime.end_session()
	await process_frame
	_assert(runtime.get_node_or_null("AdventureSky3D") == null,
		"ending the Adventure session removes the dynamic sky")
	_assert(legacy_environment != null and legacy_environment.environment != null,
		"ending the Adventure session restores the baseline Environment")
	_assert((runtime.get_node_or_null("DirectionalLight3D") as DirectionalLight3D).visible
		and (runtime.get_node_or_null("FillLight") as DirectionalLight3D).visible,
		"ending the Adventure session restores baseline lights")
	var plain_world := World.new("plain_sky_test", "Plain sky test")
	runtime.start_session(plain_world, Session.new("plain_sky_session", plain_world.world_id))
	await process_frame
	_assert(runtime.get_node_or_null("AdventureSky3D") == null,
		"a non-adventure world does not inherit the Adventure sky")
	runtime.end_session()
	runtime.queue_free()
	quit(_exit_code)
