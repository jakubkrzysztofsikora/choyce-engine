extends SceneTree

const TEMPLATE_IDS := ["tycoon", "obby", "farm", "city", "adventure"]

func _init() -> void:
	var loader := TemplateLoader.new().setup(MockProjectStore.new(), MockClock.new())
	var failures: Array[String] = []

	for template_id in TEMPLATE_IDS:
		var project := loader.create_project_from_template(template_id, _build_owner())
		if project == null:
			failures.append("%s: project is null" % template_id)
			continue
		if project.worlds.is_empty():
			failures.append("%s: no worlds created" % template_id)
			continue

		var world: World = project.worlds[0]
		if world.scene_nodes.is_empty():
			failures.append("%s: no scene nodes created" % template_id)
		if world.game_rules.is_empty():
			failures.append("%s: no game rules created" % template_id)

	if failures.is_empty():
		print("STARTER_TEMPLATE_SMOKE: PASS")
		quit(0)
		return

	for message in failures:
		print("STARTER_TEMPLATE_SMOKE: FAIL - %s" % message)
	quit(1)


func _build_owner() -> PlayerProfile:
	var owner := PlayerProfile.new()
	owner.profile_id = "smoke_owner"
	return owner


class MockProjectStore extends ProjectStorePort:
	func save_project(_project: Project) -> bool:
		return true

	func load_project(_project_id: String) -> Project:
		return null

	func list_projects() -> Array:
		return []


class MockClock extends ClockPort:
	func now_iso() -> String:
		return "2026-03-02T00:00:00Z"
