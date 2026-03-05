class_name AudioGovernanceServiceContractTest
extends PortContractTest


class MockConsentPort:
	extends IdentityConsentPort

	var _consents: Dictionary = {}

	func has_consent(profile_id: String, consent_type: String) -> bool:
		if not _consents.has(profile_id):
			return false
		var granted: Array = _consents[profile_id]
		return granted.has(consent_type)

	func request_consent(_profile_id: String, _consent_type: String) -> bool:
		return false


class MockLocalizationPolicy:
	extends LocalizationPolicyPort

	func get_locale() -> String:
		return "pl-PL"

	func translate(key: String) -> String:
		return key

	func is_term_safe(_term: String) -> bool:
		return true


class MockClock:
	extends ClockPort

	var _tick: int = 0

	func now_iso() -> String:
		_tick += 1
		return "2026-03-02T15:00:%02dZ" % _tick

	func now_msec() -> int:
		_tick += 1
		return 1767423600000 + _tick


class UnlicensedTTSAdapter:
	extends TextToSpeechPort

	func synthesize(text: String, _voice_id: String, _language: String) -> PackedByteArray:
		return ("UNLICENSED|%s" % text).to_utf8_buffer()

	func get_last_request_metadata() -> Dictionary:
		return {
			"provider": "test",
			"language": "pl-PL",
			"voice_preset": "test_voice",
			"license_id": "unknown-license",
			"attribution": "test",
			"allow_publish": true,
		}


func run() -> Dictionary:
	_reset()

	var consent := MockConsentPort.new()
	var moderation := LocalModerationAdapter.new().setup("")
	var localization := MockLocalizationPolicy.new()
	var clock := MockClock.new()
	var event_bus := DomainEventBus.new()

	var tts := ElevenLabsTTSAdapter.new().setup()
	var ambient := ElevenLabsAudioGenerationAdapter.new().setup()
	var service := AudioGovernanceService.new().setup(
		tts,
		ambient,
		moderation,
		consent,
		localization,
		clock,
		event_bus
	)

	var kid := PlayerProfile.new("kid-audio", PlayerProfile.Role.KID)
	kid.language = "en-US"

	var blocked_consent := service.generate_narration("Witaj, bohaterze!", kid, "narration")
	_assert_true(
		not bool(blocked_consent.get("allowed", true)),
		"Kid narration should be blocked when cloud audio consent is missing"
	)
	_assert_true(
		not bool(blocked_consent.get("playback_allowed", true)),
		"Playback should be blocked without consent"
	)

	consent._consents["kid-audio"] = ["cloud_audio_generation"]

	var allowed_narration := service.generate_narration("Witaj, bohaterze!", kid, "narration")
	_assert_true(
		bool(allowed_narration.get("allowed", false)),
		"Narration should pass with consent and safe text"
	)
	_assert_true(
		bool(allowed_narration.get("playback_allowed", false)),
		"Narration playback should be allowed when governance checks pass"
	)
	_assert_true(
		bool(allowed_narration.get("publish_allowed", false)),
		"Narration publish flag should be allowed for approved licensed output"
	)
	var narration_meta: Dictionary = allowed_narration.get("metadata", {})
	_assert_true(
		str(narration_meta.get("language", "")) == "pl-PL",
		"Governed narration should enforce Polish voice language by default"
	)
	_assert_true(
		str(narration_meta.get("watermark_tag", "")) == "ai_audio",
		"Governed narration should include AI audio watermark tag metadata"
	)
	var narration_provenance_variant: Variant = narration_meta.get("provenance", {})
	_assert_true(
		narration_provenance_variant is Dictionary,
		"Governed narration should include provenance metadata payload"
	)
	if narration_provenance_variant is Dictionary:
		var narration_provenance: Dictionary = narration_provenance_variant
		_assert_true(
			int(narration_provenance.get("source", -1)) == int(ProvenanceData.SourceType.AI_AUDIO),
			"Narration provenance source should be AI_AUDIO"
		)
		_assert_true(
			not str(narration_provenance.get("audit_id", "")).is_empty(),
			"Narration provenance should include audit linkage id"
		)

	var blocked_moderation := service.generate_narration("Chce zabic potwora", kid, "npc")
	_assert_true(
		not bool(blocked_moderation.get("allowed", true)),
		"Narration should be blocked when moderation rejects unsafe text"
	)

	var allowed_music := service.generate_ambient_audio("Spokojne dzwieki farmy", kid, "music")
	_assert_true(
		bool(allowed_music.get("allowed", false)),
		"Ambient music should pass when moderation and license checks pass"
	)
	_assert_true(
		bool(allowed_music.get("playback_allowed", false)),
		"Ambient playback should be allowed for approved output"
	)
	var music_meta: Dictionary = allowed_music.get("metadata", {})
	var music_provenance_variant: Variant = music_meta.get("provenance", {})
	_assert_true(
		music_provenance_variant is Dictionary,
		"Ambient audio metadata should include provenance payload"
	)

	var policy_store := InMemoryParentalPolicyStore.new().setup()
	policy_store.save_policy(
		"parent-audio",
		ParentalControlPolicy.new(
			60,
			30,
			ParentalControlPolicy.AIAccessLevel.CREATIVE_ONLY,
			false,
			true,
			false
		)
	)
	var override_tts := ElevenLabsTTSAdapter.new().setup("", {}, "pl-PL", true)
	var override_service := AudioGovernanceService.new().setup(
		override_tts,
		ambient,
		moderation,
		consent,
		localization,
		clock,
		event_bus,
		[],
		policy_store
	)

	var parent := PlayerProfile.new("parent-audio", PlayerProfile.Role.PARENT)
	parent.language = "en-US"
	var parent_override := override_service.generate_narration("Welcome, builder!", parent, "narration")
	_assert_true(
		bool(parent_override.get("allowed", false)),
		"Parent narration should be allowed when policy override is enabled"
	)
	var parent_meta: Dictionary = parent_override.get("metadata", {})
	_assert_true(
		str(parent_meta.get("language", "")) == "en-US",
		"Parent language override policy should permit non-Polish voice locale"
	)

	var kid_override := PlayerProfile.new("kid-audio-override", PlayerProfile.Role.KID)
	kid_override.language = "en-US"
	consent._consents["kid-audio-override"] = ["cloud_audio_generation"]
	var kid_override_result := override_service.generate_narration("Witaj ponownie!", kid_override, "narration")
	var kid_override_meta: Dictionary = kid_override_result.get("metadata", {})
	_assert_true(
		str(kid_override_meta.get("language", "")) == "pl-PL",
		"Kid voice output should remain Polish even when parent override exists"
	)

	var unlicensed_service := AudioGovernanceService.new().setup(
		UnlicensedTTSAdapter.new(),
		ambient,
		moderation,
		consent,
		localization,
		clock,
		event_bus
	)
	var blocked_license := unlicensed_service.generate_narration("Bezpieczny tekst", kid, "narration")
	_assert_true(
		not bool(blocked_license.get("allowed", true)),
		"Narration should be blocked when license metadata is not approved"
	)
	_assert_true(
		str(blocked_license.get("blocked_reason", "")).to_lower().contains("licens"),
		"Blocked reason should explain licensing policy failure"
	)

	var safety_events: Array[DomainEvent] = event_bus.get_history("SafetyInterventionTriggered")
	_assert_true(
		safety_events.size() >= 3,
		"Governance failures should emit safety intervention events"
	)
	var provenance_events: Array[DomainEvent] = event_bus.get_history("AIContentGenerated")
	_assert_true(
		provenance_events.size() >= 2,
		"Allowed AI audio generations should emit AIContentGenerated audit-link events"
	)

	return _build_result("AudioGovernanceService")
