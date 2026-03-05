## Offline-first autosave coordinator.
## Schedules snapshots every N milliseconds, keeps save I/O out of the
## active interaction path, and performs optional cloud sync only when
## explicit consent is available.
class_name OfflineAutosaveService
extends RefCounted

const DEFAULT_AUTOSAVE_INTERVAL_MSEC := 30000
const MAX_PENDING_SNAPSHOTS := 8

var _project_store: ProjectStorePort
var _clock: ClockPort
var _consent: IdentityConsentPort
var _cloud_sync: RefCounted
var _autosave_interval_msec: int = DEFAULT_AUTOSAVE_INTERVAL_MSEC
var _interaction_active: bool = false
var _last_scheduled_at: Dictionary = {}
var _pending: Array = []


func setup(
	project_store: ProjectStorePort,
	clock: ClockPort,
	consent: IdentityConsentPort,
	cloud_sync: RefCounted = null,
	autosave_interval_msec: int = DEFAULT_AUTOSAVE_INTERVAL_MSEC
) -> OfflineAutosaveService:
	_project_store = project_store
	_clock = clock
	_consent = consent
	_cloud_sync = cloud_sync
	_autosave_interval_msec = maxi(1000, autosave_interval_msec)
	_interaction_active = false
	_last_scheduled_at = {}
	_pending = []
	return self


func set_interaction_active(active: bool) -> void:
	_interaction_active = active


func maybe_schedule(
	project: Project,
	actor: PlayerProfile = null,
	consent_profile_id: String = ""
) -> bool:
	if _project_store == null or _clock == null:
		return false
	if project == null or project.project_id.strip_edges().is_empty():
		return false

	var now := _clock.now_msec()
	var project_id := project.project_id
	var last_seen := -1
	if _last_scheduled_at.has(project_id):
		last_seen = int(_last_scheduled_at.get(project_id, -1))
	if last_seen >= 0 and now - last_seen < _autosave_interval_msec:
		return false

	var actor_id := ""
	if actor != null:
		actor_id = actor.profile_id
	_enqueue_snapshot(_clone_project(project), actor_id, consent_profile_id, now)
	_last_scheduled_at[project_id] = now
	return true


func process_pending(max_items: int = 1) -> int:
	if _interaction_active:
		return 0

	var limit := maxi(1, max_items)
	var processed := 0
	while processed < limit and not _pending.is_empty():
		var payload_variant: Variant = _pending.pop_front()
		if not (payload_variant is Dictionary):
			continue
		var payload: Dictionary = payload_variant
		var snapshot_variant: Variant = payload.get("project", null)
		if not (snapshot_variant is Project):
			continue
		var snapshot: Project = snapshot_variant

		if not _project_store.save_project(snapshot):
			continue

		var actor_id := str(payload.get("actor_id", ""))
		var consent_profile_id := str(payload.get("consent_profile_id", ""))
		if _should_cloud_sync(snapshot, actor_id, consent_profile_id):
			_cloud_sync.call("sync_project", snapshot)

		processed += 1

	return processed


func get_pending_count() -> int:
	return _pending.size()


func get_autosave_interval_msec() -> int:
	return _autosave_interval_msec


func _enqueue_snapshot(
	project_snapshot: Project,
	actor_id: String,
	consent_profile_id: String,
	queued_at_msec: int
) -> void:
	if _pending.size() >= MAX_PENDING_SNAPSHOTS:
		_pending.pop_front()
	_pending.append({
		"project": project_snapshot,
		"actor_id": actor_id,
		"consent_profile_id": consent_profile_id,
		"queued_at_msec": queued_at_msec,
	})


func _should_cloud_sync(
	project: Project,
	actor_id: String,
	consent_profile_id: String
) -> bool:
	if _cloud_sync == null:
		return false
	if not _cloud_sync.has_method("is_available") or not _cloud_sync.has_method("sync_project"):
		return false
	if not bool(_cloud_sync.call("is_available")):
		return false
	if _consent == null:
		return false

	var candidate_ids: Dictionary = {}
	for raw_id in [consent_profile_id, actor_id, project.owner_profile_id]:
		var profile_id := str(raw_id).strip_edges()
		if not profile_id.is_empty():
			candidate_ids[profile_id] = true

	for profile_id in candidate_ids.keys():
		if _has_cloud_sync_consent(str(profile_id)):
			return true

	return false


func _has_cloud_sync_consent(profile_id: String) -> bool:
	return (
		_consent.has_consent(profile_id, "cloud_sync")
		or _consent.has_consent(profile_id, "parental_control_cloud_sync_consent")
	)


func _clone_project(project: Project) -> Project:
	var clone := Project.new(project.project_id, project.title)
	clone.description = project.description
	clone.template_id = project.template_id
	clone.owner_profile_id = project.owner_profile_id
	clone.created_at = project.created_at
	clone.updated_at = project.updated_at

	for world_variant in project.worlds:
		if world_variant is World:
			clone.add_world(_clone_world(world_variant))

	return clone


func _clone_world(world: World) -> World:
	var clone := World.new(world.world_id, world.name)
	clone.theme = world.theme
	clone.is_playable = world.is_playable

	for node_variant in world.scene_nodes:
		if node_variant is SceneNode:
			clone.add_node(_clone_scene_node(node_variant))

	for rule_variant in world.game_rules:
		if rule_variant is GameRule:
			clone.add_rule(_clone_game_rule(rule_variant))

	return clone


func _clone_scene_node(node: SceneNode) -> SceneNode:
	var clone := SceneNode.new(node.node_id, node.node_type)
	clone.display_name = node.display_name
	clone.position = node.position
	clone.rotation = node.rotation
	clone.scale = node.scale
	clone.properties = node.properties.duplicate(true)
	clone.parent_id = node.parent_id
	clone.provenance = node.provenance

	for child_variant in node.children:
		if child_variant is SceneNode:
			clone.add_child_node(_clone_scene_node(child_variant))

	return clone


func _clone_game_rule(rule: GameRule) -> GameRule:
	var clone := GameRule.new(rule.rule_id, rule.rule_type)
	clone.display_name = rule.display_name
	clone.source_blocks = rule.source_blocks.duplicate(true)
	clone.compiled_logic = rule.compiled_logic
	clone.is_active = rule.is_active
	return clone
