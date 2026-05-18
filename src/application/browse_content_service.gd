## Service for browsing available content (curated templates + family creations).
## Enforces moderation/approval visibility with private-by-default behavior.
class_name BrowseContentService
extends RefCounted

var _publish_store: PublishStorePort
var _template_loader: TemplateLoader
var _policy: PublishingPolicy

func setup(
	publish_store: PublishStorePort,
	template_loader: TemplateLoader,
	policy: PublishingPolicy = null
) -> BrowseContentService:
	_publish_store = publish_store
	_template_loader = template_loader
	_policy = policy
	return self

## Returns curated template cards with safety/approval metadata for browsing surfaces.
func list_templates(_actor: PlayerProfile, filters: Dictionary = {}, limit: int = 50) -> Array[Dictionary]:
	var templates: Array[Dictionary] = []
	var data_dir := "res://data/templates/"
	var dir := DirAccess.open(data_dir)
	if dir:
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".json") and file_name != "schema.json":
				var id := file_name.replace(".json", "")
				var data := _template_loader.load_template(id)
				if not data.is_empty():
					var entry := {
						"entry_type": "template",
						"id": id,
						"title": data.get("name_pl", data.get("name", id)),
						"description": data.get("description_pl", ""),
						"icon": data.get("icon", "default"),
						"curation_status": str(data.get("curation_status", "curated")),
						"safety_status": str(data.get("safety_status", "safe")),
						"approval_status": "approved",
						"visibility": "public_template",
					}
					if _matches_template_filters(entry, filters):
						templates.append(entry)
			file_name = dir.get_next()
	if limit > 0 and templates.size() > limit:
		templates = templates.slice(0, limit)
	return templates

## Returns published family/classroom creations visible to the actor.
## Private-by-default is enforced: PRIVATE is visible to the requester only.
func list_family_library(actor: PlayerProfile) -> Array[PublishRequest]:
	if actor == null or _publish_store == null:
		return []
	var all_published := _publish_store.list_published()
	var visible: Array[PublishRequest] = []
	
	for req: PublishRequest in all_published:
		if req == null:
			continue
		if req.state != PublishRequest.PublishState.PUBLISHED:
			continue
		if not req.all_moderation_passed():
			continue
		if not _is_request_visible_to_actor(req, actor):
			continue
		visible.append(req)

	return visible


## Returns normalized catalog cards with filterable metadata for kid/parent browsing.
func list_catalog_entries(viewer: PlayerProfile, filters: Dictionary = {}, limit: int = 50) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []

	var template_cards := list_templates(viewer, filters, limit if limit > 0 else 50)
	for card_variant in template_cards:
		if card_variant is Dictionary:
			entries.append(card_variant)

	var published_cards := list_family_library(viewer)
	for req_variant in published_cards:
		if not (req_variant is PublishRequest):
			continue
		var req: PublishRequest = req_variant
		var card := _to_publish_catalog_entry(req)
		if _matches_publish_filters(card, filters):
			entries.append(card)
		if limit > 0 and entries.size() >= limit:
			break

	return entries


func _to_publish_catalog_entry(req: PublishRequest) -> Dictionary:
	return {
		"entry_type": "family_creation",
		"id": req.request_id,
		"project_id": req.project_id,
		"world_id": req.world_id,
		"requester_id": req.requester_id,
		"reviewer_id": req.reviewer_id,
		"family_id": req.family_id,
		"classroom_id": req.classroom_id,
		"state": _state_name(req.state),
		"visibility": _visibility_name(req.visibility),
		"approval_status": _approval_status(req.state),
		"safety_status": _safety_status(req),
		"private_by_default": req.visibility == PublishRequest.Visibility.PRIVATE,
		"created_at": req.created_at,
		"published_at": req.published_at,
		"rejection_reason": req.rejection_reason,
	}


func _is_request_visible_to_actor(req: PublishRequest, actor: PlayerProfile) -> bool:
	if req == null or actor == null:
		return false
	if req.requester_id == actor.profile_id:
		return true

	var actor_family_id := _actor_family_id(actor)
	var actor_classroom_id := _actor_classroom_id(actor)

	match req.visibility:
		PublishRequest.Visibility.PRIVATE:
			return false
		PublishRequest.Visibility.FAMILY:
			if req.family_id.strip_edges().is_empty():
				return false
			return req.family_id == actor_family_id
		PublishRequest.Visibility.CLASSROOM:
			if req.classroom_id.strip_edges().is_empty():
				return false
			return req.classroom_id == actor_classroom_id
		_:
			return false


func _actor_family_id(actor: PlayerProfile) -> String:
	if actor == null:
		return ""
	return str(actor.preferences.get("family_id", "")).strip_edges()


func _actor_classroom_id(actor: PlayerProfile) -> String:
	if actor == null:
		return ""
	return str(actor.preferences.get("classroom_id", "")).strip_edges()


func _safety_status(req: PublishRequest) -> String:
	if req == null or req.moderation_results.is_empty():
		return "unknown"
	var has_warn := false
	for result_variant in req.moderation_results:
		if not (result_variant is ModerationResult):
			continue
		var result: ModerationResult = result_variant
		if result.is_blocked():
			return "blocked"
		if result.is_warning():
			has_warn = true
	return "warn" if has_warn else "passed"


func _approval_status(state: PublishRequest.PublishState) -> String:
	match state:
		PublishRequest.PublishState.PENDING_REVIEW:
			return "pending_review"
		PublishRequest.PublishState.APPROVED, PublishRequest.PublishState.PUBLISHED:
			return "approved"
		PublishRequest.PublishState.REJECTED:
			return "rejected"
		PublishRequest.PublishState.UNPUBLISHED:
			return "unpublished"
		_:
			return "draft"


func _state_name(state: PublishRequest.PublishState) -> String:
	match state:
		PublishRequest.PublishState.DRAFT: return "draft"
		PublishRequest.PublishState.MODERATION_PASSED: return "moderation_passed"
		PublishRequest.PublishState.PENDING_REVIEW: return "pending_review"
		PublishRequest.PublishState.APPROVED: return "approved"
		PublishRequest.PublishState.PUBLISHED: return "published"
		PublishRequest.PublishState.REJECTED: return "rejected"
		PublishRequest.PublishState.UNPUBLISHED: return "unpublished"
	return "draft"


func _visibility_name(visibility: PublishRequest.Visibility) -> String:
	match visibility:
		PublishRequest.Visibility.PRIVATE: return "private"
		PublishRequest.Visibility.FAMILY: return "family"
		PublishRequest.Visibility.CLASSROOM: return "classroom"
	return "private"


func _matches_template_filters(entry: Dictionary, filters: Dictionary) -> bool:
	if filters.is_empty():
		return true
	var requested_type := str(filters.get("entry_type", "")).strip_edges()
	if not requested_type.is_empty() and requested_type != str(entry.get("entry_type", "")):
		return false
	var requested_safety := str(filters.get("safety_status", "")).strip_edges()
	if not requested_safety.is_empty() and requested_safety != str(entry.get("safety_status", "")):
		return false
	return true


func _matches_publish_filters(entry: Dictionary, filters: Dictionary) -> bool:
	if filters.is_empty():
		return true
	var requested_type := str(filters.get("entry_type", "")).strip_edges()
	if not requested_type.is_empty() and requested_type != str(entry.get("entry_type", "")):
		return false
	var requested_visibility := str(filters.get("visibility", "")).strip_edges()
	if not requested_visibility.is_empty() and requested_visibility != str(entry.get("visibility", "")):
		return false
	var requested_safety := str(filters.get("safety_status", "")).strip_edges()
	if not requested_safety.is_empty() and requested_safety != str(entry.get("safety_status", "")):
		return false
	var requested_approval := str(filters.get("approval_status", "")).strip_edges()
	if not requested_approval.is_empty() and requested_approval != str(entry.get("approval_status", "")):
		return false
	return true
