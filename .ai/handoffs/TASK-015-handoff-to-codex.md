# Handoff: TASK-015 -> Codex (Cross-Review)

## Summary of changes
Implemented dual-filter moderation with a local rules-based adapter:
- Added `LocalModerationAdapter` implementing `ModerationPort` with:
  - Polish-first word lists organized by category (violence, weapons, drugs, gambling, profanity, adult_content, horror)
  - Whole-word tokenized matching (fixes substring false positives: "obrona" no longer matches "bron")
  - Age-band differentiated severity (CHILD_6_8 gets extra blocks for horror/scary terms)
  - Image format validation via magic bytes (PNG, JPG) and size limits
  - External rules file loading with hardcoded defaults fallback
- Added `SafetyInterventionTriggeredEvent` emission to `RequestGameplayHintService` for moderation blocks.
- Fixed `PublishToFamilyLibraryService` and `ReviewPublishRequestService` to actually emit events via `DomainEventBus` (was creating events but never emitting).
- Fixed `PublishingPolicy` null guards for `can_approve()`, `can_reject()`, `can_unpublish()`.

## Files created
- `src/adapters/outbound/local_moderation_adapter.gd`
- `data/moderation/rules_pl.json`
- `tests/contracts/local_moderation_adapter_contract_test.gd`
- `.ai/handoffs/TASK-015-handoff-to-codex.md`

## Files updated
- `src/application/request_gameplay_hint_service.gd`
  - Added optional `DomainEventBus` dependency
  - Added `_emit_safety_event()` on output moderation block
- `src/application/publish_to_family_library_service.gd`
  - Added optional `DomainEventBus` dependency
  - Events now emitted via `_event_bus.emit()` instead of created-but-discarded
- `src/application/review_publish_request_service.gd`
  - Added optional `DomainEventBus` dependency
  - PublishApprovedEvent, WorldPublishedEvent, PublishRejectedEvent now emitted
- `src/domain/publishing/publishing_policy.gd`
  - Added null guards to `can_approve()`, `can_reject()`, `can_unpublish()`
- `tests/contracts/run_contract_tests.gd` (added moderation adapter test)
- `tests/contracts/README.md` (documented new contract)
- `.ai/tasks/backlog.yaml` (`TASK-015` moved to `in_review`)

## Behavior notes
1. Text moderation:
   - Tokenizes input (strips punctuation, splits on whitespace)
   - Matches whole words only — "obrona" (defense) does NOT trigger "bron" (weapon)
   - Age-band overrides apply CHILD_6_8 extra blocks first, then category rules
   - Returns `ModerationResult` with verdict, category, confidence, and safe alternative
2. Image moderation:
   - Validates non-empty data, size limit (10MB default), format via magic bytes
   - Returns BLOCK for empty data, oversized, or unrecognized format
3. Safety defaults:
   - Fail-closed: null age_band defaults to strictest (CHILD_6_8)
   - All categories default to BLOCK severity except horror which is "warn_child" (WARN for teens/parents, BLOCK for children)
4. External rules:
   - `data/moderation/rules_pl.json` provides the full rule set
   - Adapter has hardcoded defaults as fallback if file not found

## Verification
Contract test: `LocalModerationAdapterContractTest` — 17 assertions covering:
- Safe text passes
- Violence, weapons, drugs, profanity blocked
- Whole-word matching accuracy (no false positives)
- Age-band differentiation (CHILD_6_8 vs CHILD_9_12)
- Empty text handling
- Null age_band defaults to strictest
- Image moderation (empty, valid PNG, invalid format)
- Punctuation handling

## Open risks and assumptions
1. Text moderation is word-list based — no ML classifier yet. Determined misspellings or obfuscation ("z4bij") will bypass.
2. Image moderation is format/size only — no visual content analysis. Actual image content classification is deferred to TASK-041 (visual asset generation).
3. WARN verdict path is not yet consumed by services (they only check `is_blocked()`). WARN support is available in the adapter for future use.
4. The event emission fixes for PublishToFamilyLibraryService and ReviewPublishRequestService are also part of TASK-010 review findings.

## Review focus areas
1. Validate whole-word matching correctness for Polish morphology edge cases.
2. Validate age-band severity differentiation logic.
3. Validate that all content-producing services now have moderation coverage with safety event emission.
4. Validate image moderation is sufficient as a baseline before ML-based content analysis.
