# Functionality Requirements

## 1) Product vision
A family-co-creation 3D sandbox/tycoon engine where kids (6–8) and parents can **build, play, and remix** worlds together, with an Ollama-powered AI copilot that supports both:
- **Game creation** (ideas, assets, logic, debugging help).
- **Gameplay** (NPC companions, hints, adaptive quests, safety-aware moderation).

Target game feel: approachable like kid-friendly sandbox/tycoon loops (build → earn → unlock → decorate → share), with low-friction creation like block coding and optional advanced scripting.

---

## 2) User personas and jobs-to-be-done

## 2.1 Kid creator/player (6–8)
- Build simple worlds with drag/drop blocks and templates.
- Use voice prompts: “Make a farm tycoon with pets.”
- Test game instantly and get celebratory feedback.
- Play short sessions (10–20 minutes) with clear goals.

## 2.2 Parent co-creator
- Configure safety, privacy, spending, and social limits.
- Unlock advanced mode (scripting, logic graphs, AI behavior prompts).
- Review AI suggestions before applying high-impact changes.
- Co-play and co-build with the child in shared sessions.

## 2.3 Educator/mentor (optional)
- Reuse curriculum-like templates (physics, resource economy, simple automation).
- Track child progress (creativity, sequencing, problem solving).

---

## 3) Core functional requirements

## 3.1 Creation mode (kid-first)
- FR-001: Provide starter templates (Tycoon, Obby-lite, Farm, City, Adventure Island).
- FR-002: Allow world editing with large, touch-friendly tools (place, paint, move, duplicate).
- FR-003: Provide block-based logic (events, timers, scoring, win conditions, item spawns).
- FR-004: Support voice-to-intent creation (“add coins every 10 seconds”) with visual confirmation cards.
- FR-005: One-click playtest from current scene.
- FR-006: Undo/redo stack with “safe checkpoint restore.”
- FR-007: AI-assisted asset generation pipeline limited to safe preset styles (no photoreal humans by default).

## 3.2 Parent advanced mode
- FR-008: Script extensions (e.g., Lua/GDScript/TypeScript subset depending on runtime choice).
- FR-009: Data model editor for economy balancing (prices, rates, upgrade multipliers).
- FR-010: AI-assisted refactor/explain for scripts (“explain this in child-friendly words”).
- FR-011: Parent approval workflow for AI-generated script/assets before publishing.

## 3.3 Gameplay mode
- FR-012: Local single-player and local co-op first; optional private online sessions.
- FR-013: AI gameplay companion that offers hints, tutorial scaffolding, and adaptive quests.
- FR-014: AI difficulty adaptation that modifies challenge gently (spawn rates, objective complexity) by age profile.
- FR-015: Session-based progression with collectibles, achievements, and building unlocks.
- FR-016: Fast reset/remix: clone world and iterate.

## 3.4 Social and sharing
- FR-017: Family/private sharing by default.
- FR-018: Publish flow with child-safe content checks and parent gate.
- FR-019: Template marketplace model (curated packs + family-shared creations).

## 3.5 Safety, privacy, and compliance
- FR-020: Age band profiles (6–8 default restrictions).
- FR-021: Profanity/toxicity filtering for text + prompt safety filters.
- FR-022: Voice input moderation and optional on-device transcription.
- FR-022a: ElevenLabs API SHOULD be used for child-friendly TTS voices and non-lyrical ambient audio generation, subject to parental controls and regional policy settings.
- FR-022b: Any AI-generated voice, sound effect, or music MUST pass automated audio/content moderation and licensing checks before playback or publishing.
- FR-023: Minimal data collection; explicit parental consent for cloud features.
- FR-024: Explainable AI actions log (“AI changed: spawn rate from 1.0 to 0.7”).
- FR-025: Parent dashboard with time limits, friend controls, and AI access policies.
- FR-026: All AI-generated visual assets MUST pass through an automated content moderation filter before being presented to the user.

## 3.6 Polish language experience (mandatory)
- FR-027: The engine UI MUST be fully available in Polish as the default and primary language for kid and parent modes.
- FR-028: AI-generated in-game text (quests, hints, NPC dialogue, labels, tutorials) MUST be generated in Polish by default.
- FR-029: Voice experiences (TTS narration, NPC voices, generated audio prompts) MUST use Polish language voices by default, including ElevenLabs integrations.
- FR-030: Voice input handling MUST prioritize Polish speech recognition and intent parsing for child pronunciation patterns.
- FR-031: Template content shipped for MVP (starter worlds, quests, helper prompts) MUST be localized and QA-verified in Polish.

---

## 4) AI agent requirements (Ollama-powered)

## 4.1 Creation agent
- FR-AI-001: Interpret child voice/text intent into engine actions.
- FR-AI-002: Produce multi-step plans (“To build your zoo tycoon, first place paths…”).
- FR-AI-003: Generate/modify block-logic graphs and scripts through tool-calling.
- FR-AI-004: Enforce policy layer before applying changes.
- FR-AI-004a: Maintain Polish-first responses in all child and parent interactions unless parent explicitly changes language settings.

## 4.2 Gameplay agent
- FR-AI-005: Observe gameplay events and suggest context-aware hints.
- FR-AI-006: Never reveal full solutions by default; use scaffolding strategy (hint level 1→3).
- FR-AI-007: Roleplay as friendly NPC helper with strict safety persona.

## 4.3 Parent agent
- FR-AI-008: Offer “parent explain mode” for balancing, bug causes, and educational mapping.
- FR-AI-009: Generate co-play activity ideas (15-minute parent-child missions).

## 4.4 Guardrails
- FR-AI-010: Hard policies for disallowed content categories.
- FR-AI-011: Model fallback chain (small local model → larger local model → optional cloud with consent).
- FR-AI-012: Full observability of prompts/tools/results for audit.

---

## 5) Non-functional requirements (product-level)
- NFR-001: Cold start to playable template under 90 seconds on target hardware.
- NFR-002: Child-facing UI interactions under ~100 ms for basic actions.
- NFR-003: Autosave every 30 seconds without blocking gameplay.
- NFR-004: Offline-first creation and play for core features.
- NFR-005: Graceful degradation when AI unavailable (rules-based helper fallback).

---

## 6) Acceptance criteria (MVP)
- Kid can create a simple tycoon world using template + 5 block rules in <20 minutes.
- Parent can add one scripted mechanic and publish to family library.
- AI can successfully perform: intent-to-action, one bug explanation, one gameplay hint.
- Safety policy blocks unsafe prompt/output and logs the intervention.
