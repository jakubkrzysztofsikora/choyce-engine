class_name VisualAssetGenerationServiceContractTest
extends PortContractTest


class InMemoryAssetRepository:
	extends AssetRepositoryPort

	var _assets: Dictionary = {}

	func store(asset_id: String, data: PackedByteArray) -> bool:
		if asset_id.strip_edges().is_empty():
			return false
		_assets[asset_id] = data
		return true

	func load(asset_id: String) -> PackedByteArray:
		if not _assets.has(asset_id):
			return PackedByteArray()
		var value: Variant = _assets.get(asset_id, PackedByteArray())
		return value if value is PackedByteArray else PackedByteArray()

	func exists(asset_id: String) -> bool:
		return _assets.has(asset_id)


class MockClock:
	extends ClockPort

	var _tick: int = 0

	func now_iso() -> String:
		_tick += 1
		return "2026-03-02T17:00:%02dZ" % _tick

	func now_msec() -> int:
		_tick += 1
		return 1767430800000 + _tick


class FlakyImageModeration:
	extends ModerationPort

	var _image_checks: int = 0

	func check_text(_text: String, _age_band: AgeBand) -> ModerationResult:
		return ModerationResult.new(ModerationResult.Verdict.PASS, "")

	func check_image(_image_data: PackedByteArray, _age_band: AgeBand) -> ModerationResult:
		_image_checks += 1
		if _image_checks == 1:
			return ModerationResult.new(ModerationResult.Verdict.PASS, "")
		return ModerationResult.new(ModerationResult.Verdict.BLOCK, "blocked_on_apply")


func run() -> Dictionary:
	_reset()

	var kid := PlayerProfile.new("kid-visual", PlayerProfile.Role.KID)
	var event_bus := DomainEventBus.new()
	var assets := InMemoryAssetRepository.new()
	var generator := SafePresetVisualGenerationAdapter.new().setup()
	var moderation := LocalModerationAdapter.new().setup("")
	var service := VisualAssetGenerationService.new().setup(
		generator,
		moderation,
		assets,
		MockClock.new(),
		event_bus
	)

	var preview := service.request_preview(
		"project-v1",
		"world-v1",
		"Przyjazny smok na lace",
		"cartoon",
		kid
	)
	_assert_true(bool(preview.get("ok", false)), "Safe kid visual request should produce preview")
	_assert_true(
		bool(preview.get("preview_allowed", false)),
		"Safe kid visual request should allow preview"
	)
	var preview_meta: Dictionary = preview.get("metadata", {})
	var preview_provenance_variant: Variant = preview_meta.get("provenance", {})
	_assert_true(
		preview_provenance_variant is Dictionary,
		"Visual preview metadata should include provenance payload"
	)
	if preview_provenance_variant is Dictionary:
		var preview_provenance: Dictionary = preview_provenance_variant
		_assert_true(
			int(preview_provenance.get("source", -1)) == int(ProvenanceData.SourceType.AI_VISUAL),
			"Visual preview provenance source should be AI_VISUAL"
		)
		_assert_true(
			not str(preview_provenance.get("audit_id", "")).is_empty(),
			"Visual preview provenance should include audit linkage id"
		)
	var preview_id := str(preview.get("preview_id", ""))
	_assert_true(not preview_id.is_empty(), "Preview should return a preview_id")

	var apply := service.apply_preview(preview_id, kid)
	_assert_true(bool(apply.get("ok", false)), "Applying approved preview should succeed")
	_assert_true(bool(apply.get("applied", false)), "apply_preview should mark preview as applied")
	_assert_true(
		assets.exists(str(apply.get("asset_id", ""))),
		"Applied preview should persist generated asset through AssetRepositoryPort"
	)
	var applied_meta_variant: Variant = apply.get("metadata", {})
	_assert_true(
		applied_meta_variant is Dictionary,
		"Applied visual result should return metadata for persistence/tagging flow"
	)
	if applied_meta_variant is Dictionary:
		var applied_meta: Dictionary = applied_meta_variant
		var applied_provenance: Dictionary = applied_meta.get("provenance", {})
		_assert_true(
			str(applied_provenance.get("audit_id", "")) == str(preview_meta.get("provenance", {}).get("audit_id", "")),
			"Applied visual provenance should keep preview audit linkage id"
		)

	var blocked := service.request_preview(
		"project-v2",
		"world-v2",
		"Photoreal human portrait in city",
		"cartoon",
		kid
	)
	_assert_true(
		not bool(blocked.get("ok", true)),
		"Kid mode should block photoreal-human generation prompts by default"
	)
	_assert_true(
		not bool(blocked.get("preview_allowed", true)),
		"Blocked photoreal-human request should not allow preview"
	)

	var flaky_service := VisualAssetGenerationService.new().setup(
		generator,
		FlakyImageModeration.new(),
		assets,
		MockClock.new(),
		event_bus
	)
	var flaky_preview := flaky_service.request_preview(
		"project-v3",
		"world-v3",
		"Przyjazny robot ogrodnik",
		"cartoon",
		kid
	)
	_assert_true(
		bool(flaky_preview.get("ok", false)),
		"Flaky moderation should allow preview on first image check"
	)
	var flaky_apply := flaky_service.apply_preview(str(flaky_preview.get("preview_id", "")), kid)
	_assert_true(
		not bool(flaky_apply.get("ok", true)),
		"Visual apply should re-run moderation and block if image check fails"
	)

	var many_ids: Array[String] = []
	for i in range(26):
		var many_preview := service.request_preview(
			"project-v4",
			"world-v4",
			"Przyjazny stworek %d" % i,
			"cartoon",
			kid
		)
		_assert_true(
			bool(many_preview.get("ok", false)),
			"Bulk preview generation should succeed for safe prompts"
		)
		many_ids.append(str(many_preview.get("preview_id", "")))
	_assert_true(
		many_ids[0] != many_ids[1],
		"Preview IDs should remain unique across consecutive requests"
	)
	var oldest_apply := service.apply_preview(many_ids[0], kid)
	_assert_true(
		not bool(oldest_apply.get("ok", true)),
		"Oldest preview should be evicted when cache exceeds MAX_PREVIEW_CACHE"
	)

	var safety_events: Array[DomainEvent] = event_bus.get_history("SafetyInterventionTriggered")
	_assert_true(
		safety_events.size() >= 2,
		"Visual policy blocks should emit safety intervention events"
	)
	var provenance_events: Array[DomainEvent] = event_bus.get_history("AIContentGenerated")
	_assert_true(
		provenance_events.size() >= 1,
		"Visual generation should emit AIContentGenerated audit-link events"
	)

	return _build_result("VisualAssetGenerationService")
