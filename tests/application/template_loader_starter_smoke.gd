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
		if template_id == "adventure":
			if not world.game_rules.is_empty():
				failures.append("adventure: sandbox must not seed compulsory rules")
			var terrain: SceneNode = world.scene_nodes[0] as SceneNode
			var size: Variant = terrain.properties.get("size", []) if terrain != null else []
			if not (size is Array and (size as Array).size() >= 3 and float((size as Array)[0]) >= 2400.0 and float((size as Array)[2]) >= 2400.0):
				failures.append("adventure: terrain must cover at least 2.4km × 2.4km")
		elif world.game_rules.is_empty():
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
