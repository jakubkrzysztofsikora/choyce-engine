# Mistral Execution Prompt — Wave 2–3 Tasks

## Context
TASK-001 is complete. The domain model is defined in `src/domain/` with 5 bounded contexts, all as framework-agnostic GDScript classes extending `RefCounted`.

Read these before starting:
- `src/ARCHITECTURE.md` — hexagonal rules and port patterns
- `src/domain/CONTEXT_MAP.md` — bounded context boundaries
- `.mistral/agents/systems-specialist.md` — your operating rules

**Your tasks are blocked until TASK-002 (inbound ports) and TASK-003 (outbound ports) complete.**

---

## TASK-009: Implement template pack data loader and plugin SDK boundaries
**Blocked by: TASK-002 (inbound ports — claude), TASK-003 (outbound ports — codex)**

### Objective
Build the template loading system and plugin SDK with strict capability enforcement.

### Template pack loader
Templates are data packs (not hardcoded logic). The loader must:

1. Read template definition files (JSON format) from a known data directory
2. Parse template metadata: name (Polish), description (Polish), theme, default rules, scene node definitions
3. Instantiate domain types from template data:
   - Create a `Project` from template
   - Populate `World` with `SceneNode` tree defined in template
   - Create default `GameRule` instances defined in template
4. Wire through the `CreateProjectFromTemplate` inbound port

### Template JSON schema (suggested)
```json
{
  "template_id": "tycoon",
  "name": "Tycoon",
  "name_pl": "Tycoon — Zarządzaj Biznesem",
  "description_pl": "Buduj sklepy, zarabiaj i rozwijaj swój biznes!",
  "theme": "business",
  "default_world": {
    "name_pl": "Mój Biznes",
    "nodes": [
      { "type": "TERRAIN", "display_name_pl": "Podłoże", "position": [0,0,0] },
      { "type": "OBJECT", "display_name_pl": "Sklep", "position": [5,0,0] }
    ],
    "rules": [
      { "type": "TIMER", "display_name_pl": "Zarabianie co 10s", "compiled_logic": "..." }
    ]
  },
  "onboarding_hints_pl": [
    "Postaw sklep, aby zacząć zarabiać!",
    "Kliknij na budynek, aby go ulepszyć."
  ]
}
```

### Plugin SDK boundaries
Plugins extend the engine through declared ports only (AR-EXT-001):

1. Define a `PluginManifest` type:
   - `plugin_id`, `name`, `version`
   - `declared_ports`: list of port names the plugin uses (e.g., `["LLMPort", "AssetRepositoryPort"]`)
   - `declared_tools`: list of tool names the plugin registers
2. Enforce: if a plugin tries to access a port not in its manifest, reject the call
3. Reject plugins with unsigned manifests (future-proofing for TASK-036 security hardening)

### Key domain types to use
- `Project` (created from template)
- `World`, `SceneNode`, `GameRule` (populated from template data)
- `PlayerProfile` (owner of the created project)

### Files to create
```
src/application/template_loader.gd       # Loads template JSON, creates domain entities
src/application/plugin_sdk.gd            # Manifest validation, port access enforcement
src/domain/shared/plugin_manifest.gd     # PluginManifest value object
data/templates/schema.json               # Template pack JSON schema
tests/application/test_template_loader.gd
tests/application/test_plugin_sdk.gd
```

### Acceptance criteria
- Template packs load from data definitions rather than hardcoded logic
- Plugin SDK enforces declared ports and rejects undeclared capabilities

---

## TASK-017: Implement Polish-first STT pipeline with local-first and opt-in fallback
**Blocked by: TASK-003 (outbound ports — codex), TASK-007 (utility adapters — codex)**

### Objective
Implement the `SpeechToTextPort` adapter with Polish speech recognition optimized for child pronunciation.

### Requirements (from TR-INT-001, TR-L10N-004, FR-030)
1. **Local-first**: Primary STT runs on-device (e.g., Whisper via Ollama or a local model)
2. **Polish language**: Default recognition language is `pl-PL`
3. **Child speech tolerance**: Model/config should handle young children's pronunciation patterns
4. **Cloud fallback**: Optional cloud STT (e.g., ElevenLabs STT) requires:
   - Parent opt-in via `IdentityConsentPort.has_consent(profile_id, "cloud_stt")`
   - Polish intent extraction preserved even if cloud provider returns slightly different transcription
5. **Intent extraction**: Raw transcription → normalized intent string for AI orchestration

### Architecture
```
Voice input → SpeechToTextPort
                  ├── LocalSTTAdapter (Whisper/local model, Polish default)
                  └── CloudSTTAdapter (ElevenLabs, consent-gated)
                        ↓
              IntentExtractor (normalize Polish child speech → structured intent)
```

### Key domain types to use
- `PromptEnvelope` (receives the extracted intent text)
- `AgeBand` (child speech patterns differ by age tier)
- `PlayerProfile` (language preference, consent checks)

### Files to create
```
src/adapters/outbound/local_stt_adapter.gd       # Implements SpeechToTextPort locally
src/adapters/outbound/cloud_stt_adapter.gd       # Consent-gated cloud fallback
src/application/stt_fallback_chain.gd            # Local → cloud fallback orchestration
src/application/polish_intent_extractor.gd       # Normalize Polish child speech to intent
tests/adapters/test_local_stt_adapter.gd
tests/application/test_stt_fallback_chain.gd
```

### Acceptance criteria
- SpeechToTextPort supports Polish recognition tuned for child pronunciation
- Cloud fallback requires parent opt-in and preserves Polish intent extraction

---

## Later tasks (Wave 7–8, for awareness)

### TASK-025: Progression loops (collectibles/achievements/unlocks/remix reset)
- **Depends on**: TASK-024 (playtest sessions — codex)
- Uses `ProgressState` value object from `src/domain/shared/progress_state.gd`
- Design the unlock tree and achievement definitions as data (like templates)
- Remix/reset: clone `World` entity and reset `ProgressState`

### TASK-026: Parent economy data model editor
- **Depends on**: TASK-022 (block logic — codex), TASK-024 (playtest — codex)
- Economy data model: prices, rates, upgrade multipliers as editable `GameRule` properties
- Balance changes generate auditable diffs (use `RuleChangedEvent` with previous/new state)

---

## Execution order
```
TASK-009 (after TASK-002 + TASK-003)
TASK-017 (after TASK-003 + TASK-007)
```

## Cross-review
- TASK-009 reviewed by: codex
- TASK-017 reviewed by: claude

Submit each task as a separate PR for focused review.
