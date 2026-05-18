# Choyce Engine — Comprehensive Analysis & Delivery Plan

**Date:** 2026-05-18
**Analyst:** Codex Orchestrator
**Scope:** Full codebase audit, gap analysis, and swarm delivery plan for production-ready family-friendly 3D game engine with AI co-creation.

---

## 1. Project Intent & Vision

**Choyce Engine** is a **family-safe 3D sandbox/tycoon game creation engine** built on Godot 4.x + GDScript, targeting children ages 6–8 with parent co-creation support. It is designed around a core philosophy:

> *"Kids build worlds. Parents guide safety. AI assists creation. Polish comes first."*

### Key Design Pillars
1. **Child Safety First**: Multi-layered AI safety with input/output moderation, parent approval gates, reversible AI mutations, and tamper-evident audit trails.
2. **Hexagonal Architecture**: Strict separation between domain logic (pure GDScript `RefCounted`), ports (abstract contracts), application services (orchestration), and adapters (Godot UI + external services).
3. **Polish-First Localization**: Default language is Polish (`pl-PL`) for all child-facing interfaces, AI prompts, and voice interactions. Parent mode allows override.
4. **Offline-First, Cloud-Optional**: All creation happens locally. Cloud features (STT, LLM fallback, sync) require explicit parent consent.
5. **AI as Co-Creator, Not Replacement**: AI provides hints, scaffolded suggestions, and voice-to-intent translation — but the child remains the author.

### Target Experience
- **Build**: Template-based world creation (Tycoon, Obby-lite, Farm, City, Adventure Island)
- **Play**: One-click playtest with local solo/co-op, 10–20 minute session goals
- **Share**: Family-library publishing with moderation and parent approval
- **Learn**: Tiered hint scaffolding (nudge → clue → near-solution) with adaptive difficulty

---

## 2. Current Architecture Assessment

### 2.1 Hexagonal Boundary Compliance: ⭐⭐⭐⭐⭐ (Excellent)

| Layer | Files | Base Class | Compliance |
|-------|-------|------------|------------|
| **Domain** | 40+ | `RefCounted` | ✅ Pure — only `Vector3` used (math value). No Godot scene-tree imports. |
| **Ports** | 46+ | `RefCounted` | ✅ Pure interfaces. `push_error` stubs for unimplemented methods. |
| **Application** | 35+ | `RefCounted` / port subclasses | ✅ Depends only on ports and domain. Constructor injection via `setup()`. |
| **Inbound Adapters** | 8 | `Control`, `PanelContainer` | ✅ Godot UI confined to `src/adapters/inbound/`. |
| **Outbound Adapters** | 25+ | port subclasses | ✅ External service implementations behind ports. |

### 2.2 Domain Model Richness: ⭐⭐⭐⭐⭐ (Excellent)

Five bounded contexts are well-defined:
- **World Authoring**: `Project`, `World`, `SceneNode`, `GameRule`
- **Gameplay**: `Session`, `PlayerProfile`, `GameEconomy`, `ProgressState`
- **AI Orchestration**: `AIAssistantAction`, `PromptEnvelope`, `ToolInvocation`
- **Identity & Safety**: `SafetyPolicyDecision`, `ParentalControlPolicy`, `RoleToken`, `AgeBand`
- **Publishing**: `PublishRequest`, `PublishingPolicy`

### 2.3 AI Safety Architecture: ⭐⭐⭐⭐⭐ (Excellent)

All 5 required controls from the `ai-safety` skill are implemented:
1. ✅ Dual-filter moderation (input + output)
2. ✅ Parent approval gates for high-impact actions
3. ✅ Reversible AI mutations with undo/redo
4. ✅ Structured audit events with hash-chain integrity
5. ✅ Age-band prompt templates and policy enforcement

### 2.4 Godot Integration: ⭐☆☆☆☆ (Critical Gap)

The project is a **UI shell and domain model, not yet a playable game**:
- **Zero 3D rendering**: No `Node3D`, `Camera3D`, `MeshInstance3D`, physics, or collision.
- **Zero imported assets**: No textures, models, audio, or fonts.
- **No gameplay loop**: `_process()` and `_physics_process()` are absent from gameplay code.
- **Minimal project config**: `project.godot` has only name, features, and main scene.

### 2.5 AI Integration: ⭐⭐☆☆☆ (Stubbed)

- **Ollama adapter**: Fully simulated — returns prefixed echo strings, no HTTP calls.
- **STT adapters**: Hardcoded size-based transcripts, no Whisper/Ollama speech integration.
- **TTS adapter**: Returns UTF-8 bytes of text, not actual audio.
- **Visual generation**: Creates 256-byte fake PNGs.

### 2.6 Test Coverage: ⭐⭐⭐⭐☆ (Good)

- 70+ contract tests covering ports, adapters, and services.
- E2E MVP flow test with mocks.
- Safety red-team, prompt regression, and compliance regression suites.
- **Gap**: No automated runner for YAML AI-scenario tests; some contract test preloads may fail on parse errors.

---

## 3. Critical Bugs Identified

### 🔴 High Severity (Fix Immediately)

| # | File | Bug | Impact |
|---|------|-----|--------|
| 1 | `src/domain/events/world_remixed_event.gd:13` | `super._init(p_timestamp)` — wrong arity. Should pass `(type, actor_id, timestamp)`. | Event type becomes timestamp string; actor_id empty. Breaks audit and read models. |
| 2 | `src/application/remix_world_service.gd:29` | Calls `_clock_port.now_iso8601()` which does not exist on `ClockPort`. | **Runtime crash** on every world remix. |
| 3 | `src/application/approve_ai_patch_service.gd:33` | Creates a *new* `AIAssistantAction` instead of loading the pending action from workflow/log. | Approval can never actually approve a real pending action. |
| 4 | `src/application/manage_economy_service.gd:41` | `adjust_parameter()` validates bounds but **never persists** the change. | Economy adjustments are silently lost. |
| 5 | `src/adapters/kid_status_read_model_adapter.gd:75-102` | Listens for non-existent events: `ProjectCreatedEvent`, `SessionCompletedEvent`, `CollectibleFoundEvent`, `AchievementUnlockedEvent`. | Read model stays permanently empty. |
| 6 | `src/adapters/ai_performance_read_model_adapter.gd:100-105` | Listens for non-existent events: `AIToolExecutedEvent`, `ModeratedContentBlockedEvent`, `PolicyGateTriggeredEvent`. | AI metrics never update. |

### 🟡 Medium Severity

| # | File | Bug | Impact |
|---|------|-----|--------|
| 7 | `src/application/manage_progression_service.gd:29-33` | Saves progress only for `player_ids[0]`. | Co-op sessions lose progress for all other players. |
| 8 | `src/adapters/inbound/main.gd:148-187` | `KEY_REQUEST_AI_HELP_PORT` and `KEY_SPEECH_TO_TEXT_PORT` declared but **not added** to defaults dictionary. | Create shell receives `null` for AI help and STT unless externally injected. |
| 9 | `src/adapters/outbound/cloud_stt_adapter.gd:21` | `transcribe()` mutates `_language` state on every call. | Breaks idempotency; concurrent calls race. |
| 10 | `src/adapters/outbound/http_publish_store.gd` | Does not close `HTTPClient` connection after request. | Connection leaks in long-running Godot process. |
| 11 | `src/application/parent_script_editor_service.gd` | Calls `_llm.complete()` without null-checking `_llm`. | **Runtime crash** if LLM port not wired. |
| 12 | `src/application/request_ai_creation_help_service.gd` | Calls `_llm.call("get_last_selected_model")` — violates port contract. | Only works with `OllamaLLMAdapter`, not generic `LLMPort`. |
| 13 | `src/application/ai_patch_workflow_service.gd` | `_requires_parent_gate()` checks hardcoded tool names but misses `logic_edit` (which registry marks as `requires_parent_approval`). | Gate logic inconsistent with tool registry. |

---

## 4. Missing Capabilities for Production Delivery

### 4.1 3D Gameplay Runtime (Highest Priority)

**Current State**: The "playtest" creates a `Session` domain object and returns it. Nothing renders.

**Required**:
- `WorldRenderer` adapter that traverses `World.scene_nodes` and instantiates Godot 3D nodes.
- `GameplayRuntime` scene with `Camera3D`, environment lighting, and floor plane.
- Node type mapping:
  - `SceneNode.NodeType.OBJECT` → `MeshInstance3D` + `StaticBody3D` + basic collision shape
  - `SceneNode.NodeType.TERRAIN` → `MeshInstance3D` (large plane) or `GridMap`
  - `SceneNode.NodeType.LIGHT` → `OmniLight3D` or `DirectionalLight3D`
  - `SceneNode.NodeType.SPAWN_POINT` → `Marker3D`
  - `SceneNode.NodeType.TRIGGER` → `Area3D`
  - `SceneNode.NodeType.DECORATION` → `MeshInstance3D` (no collision)
- Player controller (`CharacterBody3D`) for sandbox exploration.
- Play shell integration: launch the runtime scene and pass the active `World`.
- Input mappings in `project.godot` for movement, jump, camera rotate.

### 4.2 Real Ollama HTTP Integration (High Priority)

**Current State**: `OllamaLLMAdapter._complete_local()` echoes prompts.

**Required**:
- `HTTPRequest`-based client calling `POST /api/generate` and `POST /api/chat`.
- JSON-mode structured output for tool-call planning.
- Streaming response handling with timeout and cancellation.
- Connection pooling or reuse strategy.
- Error handling for model-not-found, OOM, and network failures.
- Tool invocation parsing from model output (regex + JSON fallback).

### 4.3 Real STT Integration (High Priority)

**Current State**: `LocalSTTAdapter` returns canned transcripts based on `audio.size()`.

**Required**:
- Option A: Ollama speech endpoint (`/api/speech` if available) or local Whisper via subprocess.
- Option B: HTTP integration with ElevenLabs STT or OpenAI Whisper API (cloud fallback).
- Polish child-voice tuning (higher pitch tolerance, simplified vocabulary).

### 4.4 Safety Hardening (Medium-High Priority)

**Required**:
- Unicode normalization (NFC) in `LocalModerationAdapter._tokenize()`.
- Homoglyph defense map (e.g., Cyrillic 'а' vs Latin 'a').
- Rate limiting / per-session token budget in `RequestAICreationHelpService`.
- Persistent audit ledger adapter (`FilesystemAuditLedger`) writing append-only JSONL.
- Prompt injection filtering (detect `ignore previous instructions`, `system:`, etc.).

### 4.5 Godot Project Configuration (Medium Priority)

**Required**:
- Display/window settings (title, resolution, stretch mode).
- Input map definitions (`move_forward`, `move_back`, `move_left`, `move_right`, `jump`, `interact`).
- Rendering backend (Forward+ or Mobile).
- Autoloads for `DomainEventBus` or global services if needed.
- Basic placeholder materials (colored StandardMaterial3D for block types).

---

## 5. Delivery Swarm Plan

To bring Choyce Engine to production-ready quality, we will execute **5 parallel workstreams**:

### Workstream A: Critical Bug Fixes
**Scope:** Fix all 🔴 high and 🟡 medium severity bugs identified above.
**Estimated Impact:** 12 files, ~80 lines changed.
**Acceptance:** All contract tests pass; no runtime crashes on core flows.

### Workstream B: 3D Gameplay Runtime
**Scope:** Build `WorldRenderer`, `GameplayRuntime` scene, player controller, and wire into `PlayShell`.
**Estimated Impact:** 4–6 new files, 2 modified files.
**Acceptance:** Launching playtest from Create shell renders a 3D world with navigable player camera.

### Workstream C: Real Ollama AI Integration
**Scope:** Implement HTTP-based Ollama adapter with JSON-mode tool parsing. Add rate limiting.
**Estimated Impact:** 1 major file rewrite, 1 new file, 2 modified service files.
**Acceptance:** AI help requests reach a real (or mockable) HTTP endpoint and return parsed `ToolInvocation` arrays.

### Workstream D: Safety Hardening & Persistent Audit
**Scope:** Unicode normalization, homoglyph defense, persistent audit ledger, prompt injection filter.
**Estimated Impact:** 3 modified files, 2 new files.
**Acceptance:** Moderation tests pass with homoglyph inputs; audit ledger persists across restarts.

### Workstream E: Godot Config & Test Hardening
**Scope:** `project.godot` enrichment, input maps, placeholder materials, test fixes for event types.
**Estimated Impact:** 3–4 files modified, 2 new resource files.
**Acceptance:** Project opens in Godot Editor with correct settings; all automated tests pass.

---

## 6. Risk Assessment

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Godot 3D runtime complexity exceeds agent capacity | Medium | Keep renderer simple: basic shapes, no custom shaders, no physics beyond CharacterBody3D. |
| Ollama HTTP integration requires external testing | High | Implement with toggleable mock mode; add contract tests for JSON parsing. |
| Fixing event type mismatches breaks existing tests | Medium | Update test assertions to match real event types; run full suite after fix. |
| Co-ordination conflicts between swarm agents | Low | Each workstream touches disjoint file sets (bug fixes span many small files; runtime is new files; AI is isolated adapter; safety is moderation; config is project.godot). |

---

## 7. Definition of Done

Choyce Engine is **production-ready** when:
1. ✅ All 🔴 high-severity bugs are fixed.
2. ✅ A 3D world can be created in the UI, launched in playtest, and explored with keyboard/mouse.
3. ✅ Ollama adapter makes real HTTP calls (or has robust mock fallback for offline use).
4. ✅ Safety moderation handles Unicode homoglyphs and basic prompt injection.
5. ✅ Audit ledger persists to disk and survives engine restarts.
6. ✅ All automated contract, domain, and safety regression tests pass.
7. ✅ `project.godot` is configured for desktop deployment with proper input, display, and rendering settings.

---

*Report generated by Codex Orchestrator swarm analysis. Next step: delegate to implementation subagents.*
