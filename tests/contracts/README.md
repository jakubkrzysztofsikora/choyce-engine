# Port Contract Tests

This directory contains the `TASK-003` outbound port contract harness.

## Scope
- Verifies all required outbound port methods exist.
- Verifies default return values satisfy the declared contract type.
- Verifies empty/null-oriented inputs do not break default method behavior.

## Contracts covered
- `LLMPort`
- `ModerationPort`
- `SpeechToTextPort`
- `TextToSpeechPort`
- `AudioGenerationPort`
- `VisualGenerationPort`
- `AssetRepositoryPort`
- `ProjectStorePort`
- `CloudProjectSyncPort`
- `TelemetryPort`
- `ClockPort`
- `IdentityConsentPort`
- `LocalizationPolicyPort`
- `PromptTemplateRegistryPort`
- `AIMemoryStorePort`
- `ScriptRepositoryPort`
- `PublishStorePort`
- `FilesystemProjectStore` adapter (`ProjectStorePort` contract + manifest layout behavior)
- `FilesystemAssetRepository` adapter (`AssetRepositoryPort` contract + binary IO behavior)
- `SystemClock` adapter (`ClockPort`)
- `LocalTelemetry` adapter (`TelemetryPort` + ad-tech key stripping)
- `LocalConsentStore` adapter (`IdentityConsentPort` + file persistence)
- `InMemoryCloudProjectSync` adapter (`CloudProjectSyncPort` + deterministic opt-in sync behavior)
- `PolishLocalizationPolicy` adapter (`LocalizationPolicyPort` + glossary safety)
- `InRepoPromptTemplateRegistry` adapter (`PromptTemplateRegistryPort` + versioned use-case/locale/role/age-band resolution)
- `InMemoryAIMemoryStore` adapter (`AIMemoryStorePort` + deterministic in-memory behavior)
- `InMemoryScriptRepository` adapter (`ScriptRepositoryPort` + deterministic in-memory behavior)
- `InMemoryPublishStore` adapter (`PublishStorePort` + deterministic workflow persistence)
- `DomainEventBus` domain contract (subscribe/emit/history behavior)
- `EventSourcedActionLog` application contract (replay, undo/redo, checkpoints)
- `ApplyWorldEditServiceProvenance` application contract (runtime AI provenance stamping for add/edit flows)
- `OfflineAutosaveService` application contract (30-second scheduling + non-blocking queue + consent-gated cloud sync)
- `PolishFirstLanguagePolicyService` application contract (kid-forced Polish + parent override gate)
- `CompileBlockLogicService` application contract (block DSL compilation + parent script bridge)
- `RunPlaytestService` application contract (one-click launch baseline + solo/co-op session mode semantics)
- `AIFailsafeController` application contract (emergency-mode switch + deterministic rules-based helper hints)
- `RequestGameplayHintService` application contract (scaffold hints + adaptive difficulty/quest suggestions + model-unavailable rules fallback)
- `RequestAICreationHelpService` application contract (deterministic orchestration + approval gates)
- `PromptTemplatePolicyIntegration` application contract (template-registry selection + Polish-first kid default + parent override locale path)
- `AIPatchWorkflowService` application contract (Preview/Apply/Undo action-card flow + parent gating)
- `ParentScriptEditorService` application contract (parent edit/explain/refactor + preview diff + rollback)
- `AIMemoryLayerService` application contract (session memory + safe project-summary compaction)
- `VisualAssetGenerationService` application contract (child-safe style policy + moderation gates for preview/apply)
- `AIToolRegistry` application contract (tool schemas + deterministic argument validation)
- `DeterministicToolExecutionGateway` application contract (idempotency key enforcement + replay semantics)
- `KidStatusReadModel` port
- `ParentAuditReadModel` port
- `AIPerformanceReadModel` port
- `OllamaLLMAdapter` adapter (`LLMPort` + model catalog + consent-gated cloud fallback)
- `LocalModerationAdapter` adapter (`ModerationPort` + Polish word lists + age-band + image validation)
- `SafePresetVisualGenerationAdapter` adapter (`VisualGenerationPort` + child-safe style presets + PNG output envelope)
- `ElevenLabsTTSAdapter` adapter (`TextToSpeechPort` + Polish-first voice preset enforcement)
- `ElevenLabsAudioGenerationAdapter` adapter (`AudioGenerationPort` + non-lyrical child-safe defaults)
- `AudioGovernanceService` application contract (consent + moderation + licensing gates for playback/publish + Polish-first voice language policy with parent override)
- `ParentalPolicyStorePort` port + `InMemoryParentalPolicyStore` adapter + `EncryptedParentalPolicyStore` adapter + `SetParentalControlsService` application contract
- `VoiceInputModerationService` application contract (transcribe → moderate → intent, with safety event emission)
- `PublishWorkflowServices` application contract (publish request + moderation + parent review/approve/reject + unpublish flow)
- `ProvenanceBadgeLocalization` inbound UI contract (localized provenance labels/tooltips for Polish-first surfaces)

## Run
From repository root:

```bash
./scripts/run-contract-tests.sh
```

Focused TASK-032 language-policy suite:

```bash
godot4 --headless --path . --script tests/contracts/run_task_032_tests.gd
```

Focused TASK-027 gameplay-companion suite:

```bash
godot4 --headless --path . --script tests/contracts/run_task_027_tests.gd
```

Focused TASK-044 prompt-registry suite:

```bash
godot4 --headless --path . --script tests/contracts/run_task_044_tests.gd
```

Focused TASK-047 provenance/transparency suite:

```bash
godot4 --headless --path . --script tests/contracts/run_task_047_tests.gd
```

The script bootstraps Godot's global `class_name` registry and then runs
the headless contract suite.

Because port interfaces intentionally call `push_error(...)` in abstract
methods, those log lines are expected during contract execution.
