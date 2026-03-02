# Technology Requirements

## 1) Research-informed technology direction
Based on current tooling trends for kid-friendly creation and agentic AI, use a **hybrid local-first stack**:
- 3D engine optimized for rapid iteration and cross-platform distribution.
- Ollama for local/private LLM inference and tool-calling workflows.
- Block coding + optional scripting bridge.
- Safety and observability first-class for children’s product constraints.

---

## 2) Candidate stack options

## Option A (recommended for MVP): Godot + GDScript + Ollama
- Engine: Godot 4.x (open source, strong 2D/3D, scriptable, lightweight exports).
- Runtime language: GDScript for rapid development; optional C# modules.
- AI runtime: Ollama local service (REST API).
- Agent orchestration: lightweight internal planner + tool registry (or LangGraph-like flow if needed).
- Pros: low cost, no license friction, fast prototyping, good education fit.

## Option B: Unity + C# + Ollama
- Strong ecosystem and asset tooling, but higher complexity and heavier runtime footprint.
- Better if team already deeply experienced in Unity pipelines.

## Option C: Web-first (Babylon.js/PlayCanvas) + Ollama
- Easy sharing, but 3D performance and offline support may be harder on low-end devices.

Recommendation: start with **Option A**, design adapters so engine core can migrate if needed.

---

## 3) AI/LLM technology requirements
- TR-AI-001: Support Ollama model catalog strategy:
  - Small fast model for intent classification and hinting.
  - Medium model for code/planning.
  - Optional multimodal model for image-based world editing support.
- TR-AI-002: Tool-calling contract for deterministic operations:
  - Scene graph edits
  - Logic graph edits
  - Asset lookup/import
  - Playtest execution
  - Safety checker
- TR-AI-003: Prompt templates versioned in repository.
- TR-AI-004: Context window strategy: short-term session memory + summarized long-term project memory.
- TR-AI-005: Local moderation models/rules before generation and before render.

---

## 4) Data and storage requirements
- TR-DATA-001: Local project format (JSON + binary assets + metadata manifest).
- TR-DATA-002: Event-sourced action log for undo/redo and AI auditability.
- TR-DATA-003: Parent settings vault (encrypted at rest for local profile).
- TR-DATA-004: Optional cloud sync with explicit consent and tenant isolation.

---

## 5) Integration requirements
- TR-INT-001: Voice input pipeline:
  - STT local-first when possible
  - fallback to cloud STT with parent opt-in
  - optional ElevenLabs STT integration where available
- TR-INT-002: Block programming integration:
  - Blockly/Scratch-like blocks mapped to engine behavior DSL
- TR-INT-003: Scripting bridge:
  - generated code from blocks is editable in advanced mode
- TR-INT-004: Telemetry pipeline with child-safe analytics (no ad-tech identifiers).
- TR-INT-005: ElevenLabs integration for:
  - text-to-speech narration (NPC helper + accessibility narration)
  - generated safe sound effects and background music for kid-friendly worlds
  - voice profile presets restricted to approved child-safe voices
- TR-INT-006: Audio governance controls:
  - watermark/tag AI-generated audio metadata
  - enforce policy filters and parent approval before publish
  - maintain attribution/licensing metadata in project manifest

---

## 6) Platform requirements
- TR-PLAT-001: Desktop first (Windows/macOS) for creation tools.
- TR-PLAT-002: Tablet-friendly play mode (larger controls, low-text).
- TR-PLAT-003: Hardware profile tiers:
  - Tier 1: low-end integrated GPU
  - Tier 2: mid-range family laptop
- TR-PLAT-004: Target 30+ FPS on Tier 1 with default template scenes.

---

## 7) Security and compliance requirements
- TR-SEC-001: COPPA/GDPR-K aligned data minimization.
- TR-SEC-002: Role-based policy gates (kid vs parent privileges).
- TR-SEC-003: Signed plugin/tool manifest to prevent unsafe tool execution.
- TR-SEC-004: Tamper-evident logs for AI actions and moderation decisions.

---

## 8) DevOps and quality requirements
- TR-OPS-001: CI checks for gameplay tests, content safety tests, and prompt regression tests.
- TR-OPS-002: Golden test scenes for performance benchmarking.
- TR-OPS-003: Red-team suite for unsafe prompt attempts and jailbreak patterns.
- TR-OPS-004: Feature flags for experimental AI capabilities.

---

## 9) External references used in research
- Ollama tool support and streaming tool calls.
- Godot official docs and stable branch.
- Roblox Creator Docs (UGC platform patterns).
- Minecraft Education resources (learning-through-building patterns).
- Scratch parent/ideas pages (child-first creativity workflows).
- Blockly docs (block programming integration model).
- Code.org CS Fundamentals (age-appropriate learning progression).
- LangGraph docs (agent orchestration patterns).
- ElevenLabs API docs (voice, sound effects, and music generation capabilities).
- NIST AI RMF and ISO/IEC 42001 (AI governance practices).
- Hexagonal architecture and CQRS references for system design baseline.
