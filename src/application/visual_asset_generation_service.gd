## Application service for child-safe AI visual asset generation.
## Enforces style policy, moderation checks, and deterministic preview/apply flow.
class_name VisualAssetGenerationService
extends RefCounted

const CHILD_SAFE_STYLES := [
	"cartoon",
	"storybook",
	"lowpoly",
	"pixel_fantasy",
	"watercolor",
]
const PHOTOREAL_HUMAN_TERMS := [
	"photoreal",
	"photo-real",
	"realistic human",
	"human portrait",
	"selfie",
	"fotorealistyczny",
	"realistyczny czlowiek",
	"portret czlowieka",
]
const MAX_PREVIEW_CACHE := 24

var _visual_generator: VisualGenerationPort
var _moderation: ModerationPort
var _asset_repository: AssetRepositoryPort
var _clock: ClockPort
var _event_bus: DomainEventBus
var _preview_cache: Dictionary = {}
var _preview_order: Array[String] = []
var _preview_sequence: int = 0


func setup(
	visual_generator: VisualGenerationPort,
	moderation: ModerationPort,
	asset_repository: AssetRepositoryPort,
	clock: ClockPort = null,
	event_bus: DomainEventBus = null
) -> VisualAssetGenerationService:
	_visual_generator = visual_generator
	_moderation = moderation
	_asset_repository = asset_repository
	_clock = clock
	_event_bus = event_bus
	_preview_cache = {}
	_preview_order = []
	_preview_sequence = 0
	return self


func list_child_safe_styles() -> Array[String]:
	return CHILD_SAFE_STYLES.duplicate()


func request_preview(
	project_id: String,
	world_id: String,
	prompt: String,
	style_preset: String,
	actor: PlayerProfile
) -> Dictionary:
	var clean_project := project_id.strip_edges()
	var clean_world := world_id.strip_edges()
	var clean_prompt := prompt.strip_edges()
	if clean_project.is_empty() or clean_world.is_empty() or clean_prompt.is_empty():
		return _blocked_preview("Missing project/world/prompt data.", "", "VISUAL_REQUEST_INVALID", clean_prompt, actor.profile_id)

	var style_resolution := _resolve_style_for_actor(style_preset, actor)
	var resolved_style := str(style_resolution.get("style", "cartoon"))
	if actor != null and actor.is_kid() and _is_photoreal_human_request(clean_prompt, resolved_style):
		return _blocked_preview(
			"Photoreal human generation is blocked in kid mode.",
			"Uzyj stylu 'cartoon' i przyjaznej postaci kreskowkowej.",
			"VISUAL_PHOTOREAL_HUMAN_BLOCK",
			clean_prompt,
			actor.profile_id
		)
	if bool(style_resolution.get("blocked", false)):
		var safe_style := str(style_resolution.get("safe_style", "cartoon"))
		return _blocked_preview(
			"Photoreal human generation is blocked in kid mode.",
			"Uzyj stylu '%s' i przyjaznej postaci kreskowkowej." % safe_style,
			"VISUAL_PHOTOREAL_HUMAN_BLOCK",
			clean_prompt,
			actor.profile_id
		)

	var prompt_check := _moderation.check_text(clean_prompt, actor.age_band)
	if prompt_check.is_blocked():
		var safe_alt := prompt_check.safe_alternative if not prompt_check.safe_alternative.is_empty() else "Opisz spokojny, przyjazny obraz."
		return _blocked_preview(
			"Visual prompt blocked by moderation: %s" % prompt_check.reason,
			safe_alt,
			"VISUAL_PROMPT_BLOCK",
			clean_prompt,
			actor.profile_id
		)

	var generation := _visual_generator.generate_image(clean_prompt, resolved_style, "pl-PL")
	if not (generation is Dictionary):
		return _blocked_preview(
			"Visual generator returned invalid payload.",
			"",
			"VISUAL_PROVIDER_INVALID",
			clean_prompt,
			actor.profile_id
		)

	var generated_bytes: Variant = generation.get("image_bytes", PackedByteArray())
	if not (generated_bytes is PackedByteArray) or (generated_bytes as PackedByteArray).is_empty():
		return _blocked_preview(
			"Visual generator returned empty image.",
			"",
			"VISUAL_PROVIDER_EMPTY",
			clean_prompt,
			actor.profile_id
		)

	var image_bytes: PackedByteArray = generated_bytes
	var image_check := _moderation.check_image(image_bytes, actor.age_band)
	if image_check.is_blocked():
		return _blocked_preview(
			"Generated image blocked by moderation: %s" % image_check.reason,
			"Zmien opis i sprobuj ponownie z lagodniejszym stylem.",
			"VISUAL_IMAGE_BLOCK",
			clean_prompt,
			actor.profile_id
		)

	var provider_asset_id := str(generation.get("provider_asset_id", ""))
	if provider_asset_id.is_empty():
		provider_asset_id = "provider_%d" % absi(("%s|%s" % [clean_prompt, resolved_style]).hash())
	var preview_id := _build_preview_id(clean_project, clean_world, provider_asset_id, resolved_style)
	var asset_id := "%s/generated/%s.png" % [clean_project, preview_id]

	var raw_metadata: Variant = generation.get("metadata", {})
	var metadata: Dictionary = {}
	if raw_metadata is Dictionary:
		metadata = (raw_metadata as Dictionary).duplicate(true)
	var out_metadata: Dictionary = metadata.duplicate(true)
	out_metadata["style_preset"] = resolved_style
	out_metadata["child_safe"] = actor.is_kid()
	out_metadata["style_forced"] = bool(style_resolution.get("forced", false))
	out_metadata["moderated"] = true
	out_metadata["provider_asset_id"] = provider_asset_id
	out_metadata["world_id"] = clean_world
	out_metadata["project_id"] = clean_project
	out_metadata["watermark_tag"] = "ai_visual"
	out_metadata["generated_at"] = _clock.now_iso() if _clock != null else ""
	var generator_model := _resolve_generator_model(out_metadata)
	var audit_id := _emit_generation_audit_event(
		actor.profile_id,
		clean_project,
		clean_world,
		preview_id,
		generator_model,
		clean_prompt
	)
	out_metadata["provenance"] = _build_provenance_payload(generator_model, audit_id)

	_preview_cache[preview_id] = {
		"asset_id": asset_id,
		"image_bytes": image_bytes,
		"metadata": out_metadata.duplicate(true),
		"actor_id": actor.profile_id,
		"project_id": clean_project,
		"world_id": clean_world,
	}
	_track_preview_id(preview_id)
	_evict_old_previews()

	return {
		"ok": true,
		"preview_allowed": true,
		"preview_id": preview_id,
		"asset_id": asset_id,
		"style_preset": resolved_style,
		"image_bytes": image_bytes,
		"metadata": out_metadata,
	}


func apply_preview(preview_id: String, actor: PlayerProfile) -> Dictionary:
	var clean_preview := preview_id.strip_edges()
	if clean_preview.is_empty() or not _preview_cache.has(clean_preview):
		return {"ok": false, "applied": false, "reason": "Preview not found"}

	var preview_entry: Variant = _preview_cache.get(clean_preview, {})
	if not (preview_entry is Dictionary):
		return {"ok": false, "applied": false, "reason": "Preview payload invalid"}
	var entry: Dictionary = (preview_entry as Dictionary).duplicate(true)

	var image_bytes: Variant = entry.get("image_bytes", PackedByteArray())
	if not (image_bytes is PackedByteArray):
		return {"ok": false, "applied": false, "reason": "Preview image bytes invalid"}

	# Re-check moderation before apply to enforce gate for both preview and apply.
	var image_check := _moderation.check_image(image_bytes as PackedByteArray, actor.age_band)
	if image_check.is_blocked():
		_emit_safety_intervention(
			"VISUAL_APPLY_IMAGE_BLOCK",
			str(entry.get("asset_id", "")),
			"Zmien opis i wygeneruj nowy obraz.",
			actor.profile_id
		)
		return {
			"ok": false,
			"applied": false,
			"reason": "Image blocked before apply",
		}

	var asset_id := str(entry.get("asset_id", ""))
	if asset_id.is_empty():
		return {"ok": false, "applied": false, "reason": "Missing asset id"}

	var stored := _asset_repository.store(asset_id, image_bytes)
	if not stored:
		return {"ok": false, "applied": false, "reason": "Asset store failed"}

	var metadata_variant: Variant = entry.get("metadata", {})
	var metadata: Dictionary = {}
	if metadata_variant is Dictionary:
		metadata = (metadata_variant as Dictionary).duplicate(true)

	_preview_cache.erase(clean_preview)
	_remove_preview_id(clean_preview)
	return {
		"ok": true,
		"applied": true,
		"asset_id": asset_id,
		"publish_allowed": true,
		"metadata": metadata,
		"provenance": metadata.get("provenance", {}),
	}


func discard_preview(preview_id: String) -> bool:
	var clean_preview := preview_id.strip_edges()
	if clean_preview.is_empty():
		return false
	if not _preview_cache.has(clean_preview):
		return false
	_preview_cache.erase(clean_preview)
	_remove_preview_id(clean_preview)
	return true


func _resolve_style_for_actor(style_preset: String, actor: PlayerProfile) -> Dictionary:
	var normalized := style_preset.strip_edges().to_lower()
	var allowed_styles: Array = CHILD_SAFE_STYLES.duplicate()
	if _visual_generator != null and _visual_generator.has_method("get_allowed_styles"):
		var generator_styles: Variant = _visual_generator.call("get_allowed_styles")
		if generator_styles is Array and not generator_styles.is_empty():
			allowed_styles = []
			for style in generator_styles:
				allowed_styles.append(str(style).to_lower())

	var safe_style := str(allowed_styles[0]) if not allowed_styles.is_empty() else "cartoon"
	var chosen := normalized if not normalized.is_empty() else safe_style
	var forced := false

	if actor != null and actor.is_kid():
		if chosen.contains("photoreal") and _contains_human_terms(chosen):
			return {
				"style": safe_style,
				"safe_style": safe_style,
				"forced": true,
				"blocked": true,
			}
		if not allowed_styles.has(chosen):
			forced = true
			chosen = safe_style

	return {
		"style": chosen,
		"safe_style": safe_style,
		"forced": forced,
		"blocked": false,
	}


func _contains_human_terms(text: String) -> bool:
	var normalized := text.to_lower()
	for term in PHOTOREAL_HUMAN_TERMS:
		if normalized.contains(str(term)):
			return true
	if normalized.contains("human"):
		return true
	if normalized.contains("czlowiek"):
		return true
	return false


func _is_photoreal_human_request(prompt: String, style: String) -> bool:
	var normalized_prompt := prompt.to_lower()
	var normalized_style := style.to_lower()
	var photoreal_requested := (
		normalized_prompt.contains("photoreal")
		or normalized_prompt.contains("fotorealistyczny")
		or normalized_style.contains("photoreal")
	)
	if not photoreal_requested:
		return false
	return _contains_human_terms(normalized_prompt)


func _build_preview_id(project_id: String, world_id: String, provider_asset_id: String, style_preset: String) -> String:
	var seed := "%s|%s|%s|%s" % [project_id, world_id, provider_asset_id, style_preset]
	_preview_sequence += 1
	var tick := _clock.now_msec() if _clock != null else 0
	return "preview_%d_%d_%d" % [absi(seed.hash()), tick, _preview_sequence]


func _blocked_preview(
	reason: String,
	safe_alternative: String,
	policy_rule: String,
	trigger_context: String,
	actor_id: String
) -> Dictionary:
	_emit_safety_intervention(policy_rule, trigger_context, safe_alternative, actor_id)
	return {
		"ok": false,
		"preview_allowed": false,
		"reason": reason,
		"safe_alternative": safe_alternative,
		"image_bytes": PackedByteArray(),
		"metadata": {
			"policy_rule": policy_rule,
			"watermark_tag": "ai_visual",
		},
	}


func _emit_safety_intervention(
	policy_rule: String,
	trigger_context: String,
	safe_alternative: String,
	actor_id: String
) -> void:
	if _event_bus == null:
		return
	var decision_id := "visual_%d" % absi(("%s|%s|%s" % [policy_rule, actor_id, trigger_context]).hash())
	var timestamp := _clock.now_iso() if _clock != null else ""
	var event := SafetyInterventionTriggeredEvent.new(decision_id, actor_id, timestamp)
	event.decision_type = "BLOCK"
	event.policy_rule = policy_rule
	event.trigger_context = trigger_context
	event.safe_alternative_offered = not safe_alternative.is_empty()
	_event_bus.emit(event)


func _track_preview_id(preview_id: String) -> void:
	if _preview_order.has(preview_id):
		_preview_order.erase(preview_id)
	_preview_order.append(preview_id)


func _remove_preview_id(preview_id: String) -> void:
	if _preview_order.has(preview_id):
		_preview_order.erase(preview_id)


func _evict_old_previews() -> void:
	while _preview_order.size() > MAX_PREVIEW_CACHE:
		var oldest := _preview_order[0]
		_preview_order.remove_at(0)
		_preview_cache.erase(oldest)


func _resolve_generator_model(metadata: Dictionary) -> String:
	for key in [
		"generator_model",
		"model",
		"model_id",
		"provider_model",
		"provider",
	]:
		var value := str(metadata.get(key, "")).strip_edges()
		if not value.is_empty():
			return value
	return ""


func _build_provenance_payload(model_name: String, audit_id: String) -> Dictionary:
	return {
		"source": int(ProvenanceData.SourceType.AI_VISUAL),
		"generator_model": model_name,
		"audit_id": audit_id,
		"timestamp": Time.get_unix_time_from_system(),
	}


func _emit_generation_audit_event(
	actor_id: String,
	project_id: String,
	world_id: String,
	preview_id: String,
	model_name: String,
	prompt: String
) -> String:
	var base_seed := "%s|%s|%s|%s|%s" % [actor_id, project_id, world_id, preview_id, model_name]
	var audit_id := "ai_visual_%d" % absi(base_seed.hash())
	if _event_bus == null:
		return audit_id
	var event := DomainEvent.new("AIContentGenerated", actor_id, _clock.now_iso() if _clock != null else "")
	event.event_id = audit_id
	event.payload = {
		"content_kind": "visual",
		"project_id": project_id,
		"world_id": world_id,
		"preview_id": preview_id,
		"generator_model": model_name,
		"prompt": prompt,
	}
	_event_bus.emit(event)
	return event.event_id
