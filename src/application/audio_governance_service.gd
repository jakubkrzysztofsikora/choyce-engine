## Application service for governed AI audio generation.
## Enforces consent, moderation, licensing, and metadata tagging before
## allowing playback/publishing of generated voice and ambient audio.
class_name AudioGovernanceService
extends RefCounted

const DEFAULT_APPROVED_LICENSE_IDS := [
	"elevenlabs-default",
	"elevenlabs-child-safe",
]
const CONSENT_TYPE := "cloud_audio_generation"

var _tts: TextToSpeechPort
var _audio_generation: AudioGenerationPort
var _moderation: ModerationPort
var _consent: IdentityConsentPort
var _localization: LocalizationPolicyPort
var _clock: ClockPort
var _event_bus: DomainEventBus
var _approved_license_ids: Array[String] = []
var _parental_policy_store: ParentalPolicyStorePort
var _language_policy: PolishFirstLanguagePolicyService


func setup(
	tts: TextToSpeechPort,
	audio_generation: AudioGenerationPort,
	moderation: ModerationPort,
	consent: IdentityConsentPort,
	localization: LocalizationPolicyPort,
	clock: ClockPort = null,
	event_bus: DomainEventBus = null,
	approved_license_ids: Array[String] = [],
	parental_policy_store: ParentalPolicyStorePort = null,
	language_policy: PolishFirstLanguagePolicyService = null
) -> AudioGovernanceService:
	_tts = tts
	_audio_generation = audio_generation
	_moderation = moderation
	_consent = consent
	_localization = localization
	_clock = clock
	_event_bus = event_bus
	_approved_license_ids = []
	var source: Array = approved_license_ids
	if source.is_empty():
		source = DEFAULT_APPROVED_LICENSE_IDS
	for item in source:
		_approved_license_ids.append(str(item))
	_parental_policy_store = parental_policy_store
	_language_policy = language_policy if language_policy != null else PolishFirstLanguagePolicyService.new().setup(localization, parental_policy_store)
	return self


func generate_narration(text: String, actor: PlayerProfile, voice_role: String = "narration") -> Dictionary:
	if _tts == null:
		return _blocked_result(
			"Narration adapter unavailable.",
			"",
			"AUDIO_PROVIDER_UNAVAILABLE",
			text,
			actor.profile_id if actor != null else ""
		)

	var consent_check := _check_consent(actor)
	if not consent_check.get("ok", false):
		return _blocked_result(
			"Audio generation requires parent cloud consent.",
			"Wlacz zgode rodzica, aby odtworzyc glos AI.",
			"CLOUD_AUDIO_CONSENT_REQUIRED",
			text,
			actor.profile_id
		)

	var moderation_check := _moderation.check_text(text, actor.age_band)
	if moderation_check.is_blocked():
		var safe_alt := moderation_check.safe_alternative if not moderation_check.safe_alternative.is_empty() else "Sprobuj lagodniejszego opisu glosu."
		return _blocked_result(
			"Narration blocked by moderation: %s" % moderation_check.reason,
			safe_alt,
			"AUDIO_MODERATION_BLOCK",
			text,
			actor.profile_id
		)

	var language := _resolve_audio_language(actor)
	var voice_id := _tts.resolve_voice_for_role(voice_role, language)

	var bytes := _tts.synthesize(text, voice_id, language)
	var metadata := _extract_tts_metadata()
	metadata = _augment_metadata(metadata, "voice", actor)
	metadata["voice_role"] = voice_role
	var override_enabled := (
		actor != null
		and actor.is_parent()
		and _is_parent_override_enabled(actor.profile_id, actor)
	)
	metadata["language"] = str(metadata.get("language", language)) if override_enabled else "pl-PL"

	var license_check := _check_license(metadata)
	if not license_check.get("ok", false):
		var reason_code := str(license_check.get("reason", ""))
		var blocked_reason := "Narration blocked by licensing policy."
		if reason_code == "metadata_unavailable":
			blocked_reason = "Narration blocked: provider metadata unavailable for licensing checks."
		return _blocked_result(
			blocked_reason,
			"Wybierz zatwierdzony glos rodziny.",
			"AUDIO_LICENSE_BLOCK",
			text,
			actor.profile_id
		)

	metadata = _attach_provenance(metadata, actor, "voice", text)
	return _allowed_result(bytes, metadata)


func generate_npc_voice(text: String, actor: PlayerProfile, voice_role: String = "npc") -> Dictionary:
	return generate_narration(text, actor, voice_role)


func generate_ambient_audio(description: String, actor: PlayerProfile, kind: String = "music") -> Dictionary:
	if _audio_generation == null:
		return _blocked_result(
			"Audio generation adapter unavailable.",
			"",
			"AUDIO_PROVIDER_UNAVAILABLE",
			description,
			actor.profile_id if actor != null else ""
		)

	var consent_check := _check_consent(actor)
	if not consent_check.get("ok", false):
		return _blocked_result(
			"Audio generation requires parent cloud consent.",
			"Wlacz zgode rodzica, aby odtworzyc dzwieki AI.",
			"CLOUD_AUDIO_CONSENT_REQUIRED",
			description,
			actor.profile_id
		)

	var moderation_check := _moderation.check_text(description, actor.age_band)
	if moderation_check.is_blocked():
		var safe_alt := moderation_check.safe_alternative if not moderation_check.safe_alternative.is_empty() else "Opisz spokojny i bezpieczny klimat."
		return _blocked_result(
			"Ambient audio blocked by moderation: %s" % moderation_check.reason,
			safe_alt,
			"AUDIO_MODERATION_BLOCK",
			description,
			actor.profile_id
		)

	var normalized_kind := kind.to_lower().strip_edges()
	var bytes: PackedByteArray
	if normalized_kind == "sfx":
		bytes = _audio_generation.generate_sfx(description)
		normalized_kind = "sfx"
	else:
		bytes = _audio_generation.generate_music(description)
		normalized_kind = "music"

	var metadata := _extract_audio_generation_metadata()
	metadata = _augment_metadata(metadata, normalized_kind, actor)

	var license_check := _check_license(metadata)
	if not license_check.get("ok", false):
		var reason_code := str(license_check.get("reason", ""))
		var blocked_reason := "Ambient audio blocked by licensing policy."
		if reason_code == "metadata_unavailable":
			blocked_reason = "Ambient audio blocked: provider metadata unavailable for licensing checks."
		return _blocked_result(
			blocked_reason,
			"Wybierz zatwierdzony styl audio.",
			"AUDIO_LICENSE_BLOCK",
			description,
			actor.profile_id
		)

	metadata = _attach_provenance(metadata, actor, normalized_kind, description)
	return _allowed_result(bytes, metadata)


func _check_consent(actor: PlayerProfile) -> Dictionary:
	if actor == null:
		return {"ok": false}

	if actor.is_parent():
		return {"ok": true}

	if _consent == null:
		return {"ok": false}

	var profile_id := actor.profile_id.strip_edges()
	if profile_id.is_empty():
		return {"ok": false}

	var has_audio_consent := _consent.has_consent(profile_id, CONSENT_TYPE)
	var has_legacy_tts_consent := _consent.has_consent(profile_id, "cloud_tts")
	return {"ok": has_audio_consent or has_legacy_tts_consent}


func _check_license(metadata: Dictionary) -> Dictionary:
	var license_id := str(metadata.get("license_id", "")).strip_edges()
	var attribution := str(metadata.get("attribution", "")).strip_edges()
	if license_id.is_empty() or attribution.is_empty():
		return {"ok": false, "reason": "metadata_unavailable"}

	if _approved_license_ids.has(license_id):
		return {"ok": true}

	return {"ok": false, "reason": "license_not_approved"}


func _resolve_audio_language(actor: PlayerProfile) -> String:
	if _language_policy != null:
		return _language_policy.resolve_locale(actor)

	var preferred := "pl-PL"
	if _localization != null:
		var locale := str(_localization.get_locale()).strip_edges()
		if not locale.is_empty():
			preferred = locale
	if actor != null and not actor.language.strip_edges().is_empty():
		preferred = actor.language.strip_edges()
	if actor == null or actor.is_kid():
		return "pl-PL"
	if preferred.begins_with("pl"):
		return preferred
	if _is_parent_override_enabled(actor.profile_id, actor):
		return preferred
	return "pl-PL"


func _is_parent_override_enabled(parent_id: String, actor: PlayerProfile = null) -> bool:
	if _parental_policy_store != null and not parent_id.strip_edges().is_empty():
		var policy := _parental_policy_store.load_policy(parent_id)
		if policy != null and policy.language_override_allowed:
			return true

	# Backward-compat path for callers that still set profile prefs directly.
	if actor != null:
		return bool(actor.preferences.get("allow_non_polish_audio", false))
	return false


func _extract_tts_metadata() -> Dictionary:
	if _tts == null:
		return {}
	var raw: Variant = _tts.get_last_request_metadata()
	if raw is Dictionary:
		return (raw as Dictionary).duplicate(true)
	return {}


func _extract_audio_generation_metadata() -> Dictionary:
	if _audio_generation == null:
		return {}
	var raw: Variant = _audio_generation.get_last_generation_metadata()
	if raw is Dictionary:
		return (raw as Dictionary).duplicate(true)
	return {}


func _augment_metadata(metadata: Dictionary, content_kind: String, actor: PlayerProfile) -> Dictionary:
	var result := metadata.duplicate(true)
	result["ai_generated"] = true
	result["watermark_tag"] = str(result.get("watermark_tag", "ai_audio"))
	result["content_kind"] = content_kind
	result["actor_role"] = "parent" if actor != null and actor.is_parent() else "kid"
	result["generated_at"] = _clock.now_iso() if _clock != null else ""
	result["allow_publish"] = bool(result.get("allow_publish", false))
	return result


func _allowed_result(audio_bytes: PackedByteArray, metadata: Dictionary) -> Dictionary:
	var publish_allowed := bool(metadata.get("allow_publish", false))
	return {
		"allowed": true,
		"playback_allowed": true,
		"publish_allowed": publish_allowed,
		"blocked_reason": "",
		"safe_alternative": "",
		"audio_bytes": audio_bytes,
		"metadata": metadata.duplicate(true),
	}


func _blocked_result(
	reason: String,
	safe_alternative: String,
	policy_rule: String,
	trigger_context: String,
	actor_id: String
) -> Dictionary:
	_emit_safety_intervention(policy_rule, trigger_context, safe_alternative, actor_id)
	return {
		"allowed": false,
		"playback_allowed": false,
		"publish_allowed": false,
		"blocked_reason": reason,
		"safe_alternative": safe_alternative,
		"audio_bytes": PackedByteArray(),
		"metadata": {
			"policy_rule": policy_rule,
			"ai_generated": true,
			"watermark_tag": "ai_audio",
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
	var unique_suffix := _clock.now_msec() if _clock != null else 0
	var decision_id := "audio_%d_%d" % [
		absi(("%s|%s|%s" % [policy_rule, actor_id, trigger_context]).hash()),
		unique_suffix,
	]
	var timestamp := _clock.now_iso() if _clock != null else ""
	var event := SafetyInterventionTriggeredEvent.new(decision_id, actor_id, timestamp)
	event.decision_type = "BLOCK"
	event.policy_rule = policy_rule
	event.trigger_context = trigger_context
	event.safe_alternative_offered = not safe_alternative.is_empty()
	_event_bus.emit(event)


func _attach_provenance(
	metadata: Dictionary,
	actor: PlayerProfile,
	content_kind: String,
	input_summary: String
) -> Dictionary:
	var output := metadata.duplicate(true)
	var model_name := _resolve_generator_model(output)
	var actor_id := actor.profile_id if actor != null else ""
	var audit_id := _emit_generation_audit_event(actor_id, content_kind, model_name, input_summary)
	output["provenance"] = {
		"source": int(ProvenanceData.SourceType.AI_AUDIO),
		"generator_model": model_name,
		"audit_id": audit_id,
		"timestamp": Time.get_unix_time_from_system(),
	}
	return output


func _resolve_generator_model(metadata: Dictionary) -> String:
	for key in [
		"generator_model",
		"model",
		"model_id",
		"provider_model",
		"voice_preset",
		"provider",
	]:
		var value := str(metadata.get(key, "")).strip_edges()
		if not value.is_empty():
			return value
	return ""


func _emit_generation_audit_event(
	actor_id: String,
	content_kind: String,
	model_name: String,
	input_summary: String
) -> String:
	var base_seed := "%s|%s|%s|%s" % [actor_id, content_kind, model_name, input_summary]
	var audit_id := "ai_audio_%d" % absi(base_seed.hash())
	if _event_bus == null:
		return audit_id
	var event := DomainEvent.new("AIContentGenerated", actor_id, _clock.now_iso() if _clock != null else "")
	event.event_id = audit_id
	event.payload = {
		"content_kind": content_kind,
		"generator_model": model_name,
		"input_summary": input_summary,
	}
	_event_bus.emit(event)
	return event.event_id
