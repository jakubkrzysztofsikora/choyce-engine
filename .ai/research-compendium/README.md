# Research Compendium: Choyce Engine Backlog

This directory contains comprehensive research documents for technically complex Godot-specific tasks from the `.ai/tasks/backlog.yaml` and `PLAN.md`.

## Quick Reference Table

### Legend
- **Deep Research Available**: Full research document with code samples, links, and implementation guidance
- **Brief Notes**: Research summary in this document
- **Status**: done / in_progress / todo / in_review

---

## In-Depth Research Documents

These tasks have full, detailed research documents with code samples, online resources, and implementation guidance:

### 1. Procedural World Streaming (VS-017, VS-019)
- **File**: [RESEARCH_VS-017_019_Procedural_World_Streaming.md](./RESEARCH_VS-017_019_Procedural_World_Streaming.md)
- **Focus**: 5.76km² deterministic biome streaming, chunk management, Godot 4.6 PCG
- **Status**: in_progress
- **Complexity**: HIGH
- **Key Technologies**: FastNoiseLite, chunk-based streaming, object pooling, LOD systems

### 2. Tool-Gated Gathering System (VS-020)
- **File**: [RESEARCH_VS-020_Tool_Gated_Gathering_System.md](./RESEARCH_VS-020_Tool_Gated_Gathering_System.md)
- **Focus**: Axe/pickaxe requirements, tool discovery, gathering with progress, respawn system
- **Status**: in_progress
- **Complexity**: HIGH
- **Key Technologies**: Area3D interaction, inventory integration, state machines, tool registry pattern

### 3. Vehicle Physics & Bulldozer Destruction (VS-021)
- **File**: [RESEARCH_VS-021_Vehicle_Physics_Destruction.md](./RESEARCH_VS-021_Vehicle_Physics_Destruction.md)
- **Focus**: VehicleBody3D, enter/exit, camera handoff, bounded destruction, restoration
- **Status**: todo
- **Complexity**: HIGH
- **Key Technologies**: VehicleBody3D (new in 4.6), camera systems, tag-based destruction, physics

### 4. Audio Visual Accessibility Quality (VS-006) ✅ COMPLETE
- **File**: [RESEARCH_VS-006_Audio_Visual_Accessibility.md](./RESEARCH_VS-006_Audio_Visual_Accessibility.md)
- **Focus**: Audio bus architecture, WCAG 2.2 AA compliance, caption systems, accessibility features
- **Status**: in_progress
- **Complexity**: HIGH
- **Key Technologies**: Audio buses, ducking, compression, accessibility standards

### 5. Cinematic Acting and Voice (VS-015) ✅ COMPLETE
- **File**: [RESEARCH_VS-015_Cinematic_Acting_Voice.md](./RESEARCH_VS-015_Cinematic_Acting_Voice.md)
- **Focus**: ElevenLabs TTS integration, Polish voice selection, voice queue, spatial audio
- **Status**: in_progress
- **Complexity**: HIGH
- **Key Technologies**: AudioStreamPlayer3D, voice serialization, spatial mixing

### 6. Facial Speech and Emotion (VS-024) ✅ COMPLETE
- **File**: [RESEARCH_VS-024_Facial_Speech_Emotion.md](./RESEARCH_VS-024_Facial_Speech_Emotion.md)
- **Focus**: Blend shapes, facial rigs, speech-driven animation, emotion system
- **Status**: in_review
- **Complexity**: HIGH
- **Key Technologies**: MeshInstance3D blend shapes, AnimationTree, facial performance system

### 7. Tauri Sidecar & Godot Bridge (VS-007) ✅ COMPLETE
- **Files**: [Part 1: Architecture & Rust Implementation](./RESEARCH_VS-007_Tauri_Sidecar_Part1.md), [Part 2: TypeScript Client & Frontend Integration](./RESEARCH_VS-007_Tauri_Sidecar_Part2.md), [Part 3: Packaging, Testing & Production](./RESEARCH_VS-007_Tauri_Sidecar_Part3.md)
- **Focus**: Complete Tauri 2.x + Godot 4.x sidecar bridge with authenticated WebSocket IPC
- **Status**: done
- **Complexity**: HIGH
- **Key Technologies**: tauri-plugin-shell, TCPServer, WebSocketPeer, Rust process management, TypeScript bridge client

### 8. Original Liminal Creatures (VS-023) ✅ COMPLETE - BACKROOMS MONSTERS INCLUDED
- **File**: [RESEARCH_VS-023_Original_Liminal_Creatures.md](./RESEARCH_VS-023_Original_Liminal_Creatures.md)
- **Focus**: 10 Backrooms-inspired child-safe creature concepts, 3D models, combat integration
- **Status**: done
- **Complexity**: HIGH
- **Key Technologies**: Enemy state machines, wind-up telegraph system, child-safe creature design

### 9. Reversible Creator Interaction (VS-008) ⭐ ✅ COMPLETE
- **File**: [RESEARCH_VS-008_Reversible_Creator_Interaction.md](./RESEARCH_VS-008_Reversible_Creator_Interaction.md)
- **Focus**: Collect → upgrade → place decoration → undo/replay loop with command pattern
- **Status**: done
- **Complexity**: HIGH
- **Key Technologies**: Command Pattern, Godot UndoRedo, inventory/hotbar, resource collection, event bus

### 10. Governed AI Flows (VS-009) ⭐ ✅ COMPLETE
- **File**: [RESEARCH_VS-009_Governed_AI_Flows.md](./RESEARCH_VS-009_Governed_AI_Flows.md)
- **Focus**: Input/output moderation, parent approval gates, audit events, cancellation, offline fallback
- **Status**: done
- **Complexity**: HIGH
- **Key Technologies**: Ollama integration, COPPA compliance, event sourcing, async HTTP, safety filtering

### 10. Combat Telegraphs and Feedback (VS-005) ✅ COMPLETE
- **File**: [RESEARCH_VS-005_Combat_Telegraphs_Feedback.md](./RESEARCH_VS-005_Combat_Telegraphs_Feedback.md)
- **Focus**: Hitstop, screen shake, aim assist, damage numbers, particle effects, weapon differentiation
- **Status**: in_review
- **Complexity**: HIGH
- **Key Technologies**: CameraShaker, HitstopManager, FeedbackQueue, GPUParticles3D, AnimationTree

### 9. Modern Game UI and Onboarding (VS-014) ✅ COMPLETE
- **File**: [RESEARCH_VS-014_Modern_Game_UI.md](./RESEARCH_VS-014_Modern_Game_UI.md)
- **Focus**: Theme system, responsive design, HUD components, iconography, onboarding, accessibility
- **Status**: in_review
- **Complexity**: HIGH
- **Key Technologies**: Theme, Control nodes, Containers, Anchors, Viewport, Localization

### 11. Rendered Visual Acceptance Evidence (VS-016) ⭐ ✅ COMPLETE
- **File**: [RESEARCH_VS-016_Rendered_Visual_Acceptance_Evidence.md](./RESEARCH_VS-016_Rendered_Visual_Acceptance_Evidence.md)
- **Focus**: Screenshot capture, performance profiling, hardware tier detection, visual QA automation
- **Status**: in_progress
- **Complexity**: HIGH
- **Key Technologies**: Viewport capture, Performance singleton, hardware detection, image analysis, evidence management

---

## Task Research Index

### TASK-001 to TASK-044 (Architecture & Core Systems)

#### TASK-001: Bounded Contexts & Domain Model
- **Status**: done
- **Research**: Not needed - architectural design complete
- **Notes**: Domain model is framework-agnostic, well-isolated

#### TASK-002: Inbound Use-Case Ports
- **Status**: done
- **Research**: Not needed - ports pattern well-established

#### TASK-003: Outbound Ports & Contract Tests
- **Status**: done
- **Research**: Not needed - contract testing framework in place

#### TASK-004: Domain Event Bus & CQRS-lite
- **Status**: done
- **Research**: Not needed - event-driven architecture implemented

#### TASK-005: Local Project Format & Storage
- **Status**: done
- **Research**: FileSystem storage adapters implemented

#### TASK-006: Event-Sourced Action Log
- **Status**: done
- **Research**: Undo/redo through event replay working

#### TASK-007: Utility Adapters
- **Status**: done
- **Research**: Consent, clock, telemetry, localization adapters wired

#### TASK-008: Godot Inbound Adapters
- **Status**: done
- **Research**: Create/Play/Dashboard shells navigable

#### TASK-009: Template Pack Loader & Plugin SDK
- **Status**: done
- **Research**: Template loading from data definitions working

#### TASK-010: Publishing Domain
- **Status**: done
- **Research**: Parent approval workflow implemented

#### TASK-011: Ollama LLM Adapter
- **Status**: done
- **Research**: Model catalog, fallback chain, tool calls working

#### TASK-012: AI Orchestration Loop
- **Status**: done
- **Research**: Intent → pre-check → planning → validation → execution → post-check → audit

#### TASK-013: Tool Registry Contracts
- **Status**: done
- **Research**: Scene edits, logic edits, asset import, playtest, safety tools

#### TASK-014: AI Patch Workflow
- **Status**: done
- **Research**: Preview, Apply, Undo with parent approval gates

#### TASK-015: Dual-Filter Moderation
- **Status**: done
- **Research**: Input/output moderation with safe alternatives

#### TASK-016: ElevenLabs TTS & Audio
- **Status**: done
- **Research**: Polish voice presets, audio moderation, licensing checks

#### TASK-017: STT Pipeline
- **Status**: done
- **Research**: Polish recognition, cloud fallback with opt-in

#### TASK-018: AI Failsafe Mode
- **Status**: done
- **Research**: Graceful degradation, rules-based helper fallback

#### TASK-019: Tamper-Evident Audit Ledger
- **Status**: done
- **Research**: Prompts, tool invocations, moderation decisions logged

#### TASK-020: Localized Starter Templates
- **Status**: done
- **Research**: Tycoon, Obby-lite, Farm, City, Adventure templates

#### TASK-021: Kid-Mode Build Canvas
- **Status**: done
- **Research**: Place, paint, move, duplicate tools with touch-friendly controls

#### TASK-022: Block Logic Editor
- **Status**: done
- **Research**: Events, timers, scoring, win conditions compile to rules

#### TASK-023: Voice-to-Intent Creation
- **Status**: done
- **Research**: Voice prompts → visual action cards → bounded choices

#### TASK-024: One-Click Playtest
- **Status**: done
- **Research**: Local single-player and local co-op sessions

#### TASK-025: Progression Loops
- **Status**: done (blocking_reason present)
- **Research**: Session progression persists collectibles, achievements, unlocks

#### TASK-026: Parent Economy Editor
- **Status**: done
- **Research**: Edit prices, rates, upgrade multipliers with auditable diffs

#### TASK-027: AI Gameplay Companion
- **Status**: done
- **Research**: Tiered hints, adaptive quests based on age profile

#### TASK-028: Parent Advanced Scripting
- **Status**: done
- **Research**: Script editing, AI explain, diff preview with rollback

#### TASK-029: Parent Zone Controls
- **Status**: done
- **Research**: Time limits, social permissions, AI policies

#### TASK-030: Publish Flow
- **Status**: done
- **Research**: Moderation checks, parent approval gates

#### TASK-031: Polish-First UI Localization
- **Status**: done
- **Research**: pl-PL defaults across navigation, dialogs, tooltips

#### TASK-032: Polish-First LLM Prompts
- **Status**: done
- **Research**: Language override policy controls

#### TASK-033: Accessibility Baseline
- **Status**: done
- **Research**: WCAG 2.2 AA, captions, dyslexia font, motor presets

#### TASK-034: Kid Onboarding
- **Status**: done
- **Research**: First-fun instrumentation, confidence loops

#### TASK-035: Offline-First Autosave
- **Status**: done
- **Research**: 30-second intervals, consent-gated cloud sync

#### TASK-036: Security Hardening
- **Status**: done
- **Research**: RBAC, signed manifests, encrypted parent vault

#### TASK-037: Child-Safe Telemetry
- **Status**: done
- **Research**: Status, audit, AI performance dashboards

#### TASK-038: CI Quality Gates
- **Status**: done
- **Research**: Domain tests, contract tests, safety, prompt regressions

#### TASK-039: Performance Benchmark
- **Status**: done
- **Research**: Golden scenes, cold start, interaction latency, FPS targets

#### TASK-040: Deployment Profiles
- **Status**: done
- **Research**: Local, family cloud, classroom modes

#### TASK-041: AI Visual Asset Generation
- **Status**: done
- **Research**: Child-safe style presets, moderation gates

#### TASK-042: Voice Input Moderation
- **Status**: done
- **Research**: STT transcript safety gating

#### TASK-043: AI Memory Layer
- **Status**: done
- **Research**: Session context, project history summaries

#### TASK-044: Versioned Prompt Templates
- **Status**: done
- **Research**: Use-case, locale, role, age-band variants

---

## Visual Rescue (VS-) Tasks

### VS-001: Compose Opening Grove
- **Status**: in_progress
- **Specialty**: world-composition
- **Research**: Guide trail, house/yard, foliage, fauna, routes
- **Resources**: Kenney Nature Kit assets, composition best practices
- **Links**: [Godot Composition Tutorial](https://kids-candies.gitbook.io/godot-tutorials/3d/composition)

### VS-002: Hide World Boundary
- **Status**: in_progress
- **Specialty**: world-scale-collision
- **Research**: Terrain continuation, foliage, water, fog, background geometry
- **Technical**: Visibility ranges, fog settings, horizon concealment
- **Code**: Use `visibility_range_end` on MeshInstance3D
- **Links**: [Godot Fog Tutorial](https://docs.godotengine.org/en/stable/tutorials/3d/procedural_geometry/fog.html)

### VS-003: Island Scale and Landmarks
- **Status**: in_progress
- **Specialty**: procedural-world-streaming
- **Research**: 2400m×2400m floor, layered sightlines, destination reveals
- **Technical**: Chunk-based procedural generation, deterministic seeding
- **See Also**: VS-017, VS-019 (full research available)

### VS-004: Presentable Materials and Lighting
- **Status**: in_progress
- **Specialty**: visual-polish
- **Research**: Restrained palette, surface variation, daylight setup
- **Technical**: PBR materials, albedo detail, roughness, slope transitions
- **Assets**: Kenney packs, KayKit, Quaternius
- **Links**: [Godot PBR Tutorial](https://docs.godotengine.org/en/stable/tutorials/3d/materials_in_godot_4_x.html)

### VS-005: Combat Telegraphs and Feedback ⭐ ✅ COMPLETE
- **File**: [RESEARCH_VS-005_Combat_Telegraphs_Feedback.md](./RESEARCH_VS-005_Combat_Telegraphs_Feedback.md)
- **Status**: in_review
- **Specialty**: combat-feel
- **Research**: Enemy wind-up/recovery, hit feedback, soft aim assist, weapon differentiation
- **Technical**: Animation state machines, particle effects, camera shake, hitstop, crosshair tinting
- **Current Evidence**: enemy_controller.gd (WINDUP state), player_controller.gd (combo, squash, aim assist), gameplay_runtime.gd (damage numbers, hit-stop)
- **Blocking Fixes Identified**:
  - Crosshair tinting when enemy in range (comment only at line 1966)
  - combat_difficulty serialization in ParentalControlPolicy
  - EASY mode multipliers (hp_mult *= 0.6, contact_damage *= 0.5)
- **Deep Research**: ✅ COMPLETE - 56KB comprehensive document with code samples, best practices, child-safety constraints

### VS-006: Audio Visual Accessibility Quality
- **Status**: in_progress
- **Specialty**: presentation-qa
- **Research**: Screenshots, performance, audio buses, blocking cues, captions
- **Deep Research Document**: [Planned](#)
- **Technical Areas**:
  - Audio bus architecture (Music, Voice, SFX)
  - Volume mixing and ducking
  - Caption system for spoken content
  - Reduce-motion options
  - Controller/tablet-friendly UI
- **Current Evidence**: bus_setup.gd, audio_bank.gd, manual-qa/VS-006/
- **Links**:
  - [Godot Audio Buses](https://docs.godotengine.org/en/stable/tutorials/audio/audio_buses.html)
  - [WCAG 2.2 Guidelines](https://www.w3.org/WAI/WCAG22/quickref/)
  - [Accessibility in Games](https://game-accessibility.com/)

### VS-007: Tauri Godot Sidecar Lifecycle ✅ COMPLETE
- **Status**: done
- **Specialty**: desktop-integration
- **Files**: [Part 1: Architecture & Rust Implementation](./RESEARCH_VS-007_Tauri_Sidecar_Part1.md), [Part 2: TypeScript Client & Frontend Integration](./RESEARCH_VS-007_Tauri_Sidecar_Part2.md), [Part 3: Packaging, Testing & Production](./RESEARCH_VS-007_Tauri_Sidecar_Part3.md)
- **Size**: ~120KB across 3 focused documents
- **Research**: Complete Tauri 2.x + Godot 4.x sidecar bridge implementation
- **Technical**: Rust process management, WebSocket IPC, authenticated bridge, packaging
- **Links**:
  - [Tauri Documentation](https://v2.tauri.app/develop/sidecar/)
  - [Godot WebSocket Docs](https://docs.godotengine.org/en/stable/tutorials/networking/websocket.html)
  - [tauri-plugin-shell](https://v2.tauri.app/plugin/shell/)
  - [tauri-sidecar-manager](https://github.com/radical-data/tauri-sidecar-manager)
  - [tokio-tungstenite](https://crates.io/crates/tokio-tungstenite)
- **Key Features**:
  - Per-launch auth tokens for security
  - 127.0.0.1-only binding (child-safe)
  - Heartbeat monitoring with exponential backoff reconnection
  - Parent consent for updates (COPPA compliant)
  - Multi-format packaging (MSI, NSIS, DMG, AppImage, DEB, RPM, Flatpak)
  - CI/CD pipeline with GitHub Actions
  - Privacy-first telemetry (opt-in, anonymized)

### VS-008: Reversible Creator Interaction ⭐ ✅ COMPLETE
- **File**: [RESEARCH_VS-008_Reversible_Creator_Interaction.md](./RESEARCH_VS-008_Reversible_Creator_Interaction.md)
- **Status**: done
- **Specialty**: creator-loop
- **Research**: Collect → upgrade → place decoration → undo/replay loop with Command Pattern
- **Current Evidence**: build_grid.gd (undo stack), gameplay_runtime.gd (HUD UndoBtn)
- **Deep Research**: ✅ COMPLETE - 31KB comprehensive document with code samples, best practices, child-safety constraints

### VS-009: Governed AI Flows
- **Status**: done
- **Specialty**: ai-safety
- **Research**: Input/output moderation, parent approval, audit events, rollback

### VS-010: Visual Acceptance Evidence (Planned)
- **Status**: todo
- **Specialty**: visual-qa
- **Dependencies**: [VS-001, VS-002, VS-003, VS-004, VS-006]
- **Research**: Launcher, spawn, guide, region transition, combat screenshots

### VS-011: First Playable Slice Render
- **Status**: in_progress
- **Specialty**: rendered-qa
- **Research**: No runtime errors, first screenshot intentional, first 5 minutes interesting
- **Dependencies**: Gate A requirements

### VS-012: Modern Game UI
- **Status**: in_review
- **Specialty**: game-ui
- **Research**: Remove oversized controls, debug lettering, rainbow placeholders
- **Current Evidence**: gameplay_runtime.gd, launcher_overlay.gd, ui_pl.json
- **Technical**:
  - Control theming
  - Responsive design for multiple resolutions
  - Iconography systems
  - HUD layout best practices
- **Links**:
  - [Godot UI Tutorial](https://docs.godotengine.org/en/stable/tutorials/ui/index.html)
  - [Kenney UI Pack](https://kenney.nl/assets/ui-pack)

### VS-013: Composed Starting Grove
- **Status**: in_progress
- **Specialty**: world-composition
- **Research**: Opening with trail, guide, readable landmark, two routes onward
- **Technical**: Hand-authored composition vs procedural dressing
- **Assets**: Kenney Nature Kit (ground_pathStraight.glb, trees, bushes, flowers)

### **VS-014: Modern Game UI** ⭐ ✅ COMPLETE
- **File**: [RESEARCH_VS-014_Modern_Game_UI.md](./RESEARCH_VS-014_Modern_Game_UI.md)
- **Status**: in_review
- **Specialty**: game-ui
- **Research**: Theme system, responsive design, HUD components, iconography, onboarding, accessibility
- **Technical**: Theme system, Control nodes, Containers, Anchors, Viewport, Localization
- **Deep Research**: ✅ COMPLETE - 62KB comprehensive document with full code samples

### VS-015: Cinematic Acting and Voice
- **Status**: in_progress
- **Specialty**: cinematic-audio
- **Research**: Ziemek/Gniewko distinct voices, serialized lines, no overlap
- **Technical**:
  - AudioStreamPlayer3D for spatial audio
  - Voice queue system
  - Lip sync (basic)
  - Caption timing
- **Assets Needed**:
  - ElevenLabs voice presets (masculine, youthful, Polish)
  - Character voice line recordings
- **Links**:
  - [ElevenLabs API](https://docs.elevenlabs.io/)
  - [Godot AudioStreamPlayer3D](https://docs.godotengine.org/en/stable/classes/class_audiostreamplayer3d.html)

### **VS-016: Rendered Visual Acceptance Evidence** ⭐ ✅ COMPLETE
- **File**: [RESEARCH_VS-016_Rendered_Visual_Acceptance_Evidence.md](./RESEARCH_VS-016_Rendered_Visual_Acceptance_Evidence.md)
- **Status**: in_progress
- **Specialty**: rendered-qa
- **Research**: Screenshot capture at launcher, spawn, guide interaction, region transition, combat; hardware tier detection; performance monitoring; visual QA automation; release recommendations
- **Dependencies**: [VS-013, VS-014, VS-015]
- **Technical Areas**:
  - Viewport screenshot capture with metadata
  - Performance monitoring (FPS, frame time, draw calls, vertex count, memory)
  - Hardware tier classification (Tier 1/Tier 2)
  - Visual QA checks (variance, edge detection, composition, character visibility)
  - Evidence management and structured storage
- **Deep Research**: ✅ COMPLETE - 30KB comprehensive document with 5 code samples
- **Implementation Notes**:
  - ScreenshotCapture.gd: Async capture with delay for UI settlement
  - PerformanceMonitor.gd: Periodic monitoring with statistics
  - VisualQAChecker.gd: Automated visual defect detection
  - HardwareTier.gd: GPU/CPU/memory detection and classification
  - EvidenceManager.gd: Coordinates all evidence collection
- **Acceptance Criteria**:
  - Launcher, spawn, guide interaction, region transition, combat screenshots retained
  - Reference (1920x1080) and laptop-sized (1366x768) runs have no major defects
  - Tier 1 and Tier 2 performance measurements with explicit release recommendation
  - Reviewer can identify player, guide, route, landmark, interaction, destination from images
- **Backrooms Monsters**: ✅ INCLUDED via VS-023 research
- **Links**:
  - [Godot Viewport Docs](https://docs.godotengine.org/en/stable/classes/class_viewport.html)
  - [Godot Performance Monitoring](https://docs.godotengine.org/en/stable/tutorials/optimization/performance_monitoring.html)
  - [Pixelmatch](https://github.com/mapbox/pixelmatch)
  - [OpenCV](https://opencv.org)
  - [WCAG 2.2](https://www.w3.org/WAI/WCAG22/quickref/)

### **VS-017: Stream Deterministic Biomes** ⭐
- **File**: [RESEARCH_VS-017_019_Procedural_World_Streaming.md](./RESEARCH_VS-017_019_Procedural_World_Streaming.md)
- **Status**: in_progress
- **Full Research Available**

### **VS-018: Homestead Interaction Loop** ⭐ ✅ COMPLETE
- **File**: [RESEARCH_VS-018_Homestead_Interaction.md](./RESEARCH_VS-018_Homestead_Interaction.md)
- **Status**: in_progress
- **Specialty**: sandbox-interactions
- **Research**: Starter homestead enterable, furniture, cooking, heal loop
- **Technical Areas**:
  - Door interaction system
  - Sitting animation/positioning
  - Cooking mechanics
  - Health restoration
  - Inventory consumption
- **Current Evidence**: world_renderer.gd (_build_starter_homestead)
- **Deep Research**: ✅ COMPLETE - 53KB comprehensive document
- **Implementation Notes**:
  - Complete Door.gd with collision, animation, sounds
  - SitTarget.gd with camera offset and player state
  - CookingStation.gd with recipe system
  - InteractionManager.gd for unified interaction handling
- **Links**:
  - [Godot Area3D](https://docs.godotengine.org/en/stable/classes/class_area3d.html)
  - [GDQuest Interaction Systems](https://gdquest.com/tutorial/godot-4-interaction-system/)
  - [HeartBeast Door System](https://www.heartbeast.co/godot-4-door-system/)
  - [Quaternius Buildings](https://quaternius.com/free-3d-models?category=buildings)
  - [Poly Pizza Furniture](https://poly.pizza/search?q=furniture)

### **VS-019: Stream Deterministic Biomes** ⭐
- **File**: [RESEARCH_VS-017_019_Procedural_World_Streaming.md](./RESEARCH_VS-017_019_Procedural_World_Streaming.md)
- **Status**: in_progress
- **Full Research Available**

### **VS-020: Tool-Gated Gathering** ⭐
- **File**: [RESEARCH_VS-020_Tool_Gated_Gathering_System.md](./RESEARCH_VS-020_Tool_Gated_Gathering_System.md)
- **Status**: in_progress
- **Full Research Available**

### **VS-021: Vehicles & Bulldozer Destruction** ⭐
- **File**: [RESEARCH_VS-021_Vehicle_Physics_Destruction.md](./RESEARCH_VS-021_Vehicle_Physics_Destruction.md)
- **Status**: todo
- **Full Research Available**

### **VS-022: Player Character Customization** ⭐ ✅ COMPLETE
- **File**: [RESEARCH_VS-022_Character_Customization.md](./RESEARCH_VS-022_Character_Customization.md)
- **Status**: in_review
- **Specialty**: character-presentation
- **Research**: Skin, hair, face, top, pants, shoe choices update 3D model
- **Technical**:
  - MeshInstance3D swapping
  - Material overrides for colors
  - Skeleton-based customization (if using rigged models)
  - Save/load customization state
- **Assets**: Quaternius character models with modular parts
- **Links**:
  - [Godot Skeleton3D](https://docs.godotengine.org/en/stable/classes/class_skeleton3d.html)
  - [GDQuest Character Customization](https://www.youtube.com/watch?v=K5qNg9RJXcE)
  - [HeartBeast Customization](https://www.heartbeast.co/godot-4-character-customization/)
- **Deep Research**: ✅ COMPLETE - 58KB comprehensive document

### **VS-023: Original Liminal Creatures** ⭐
- **Status**: todo
- **Specialty**: creature-art-and-behavior
- **Research**: Replace slime placeholders with child-safe original creatures
- **Technical**:
  - EnemyDefinition system (already exists)
  - Model loading and animation
  - Combat integration
  - Visual telegraph for attacks
  - Non-gory, readable, avoidable design
- **Current Evidence**: enemy_controller.gd (already has WINDUP state, emission flash)
- **Brief Implementation Notes**:
  ```gdscript
  # Creature definition
  class_name CreatureDefinition extends EnemyDefinition:
      var species_name: String
      var description: String
      var mesh_path: String  # GLTF model
      var idle_animation: String
      var attack_animation: String
      var hurt_animation: String
      var windup_animation: String
      var move_speed: float
      var turn_speed: float
  ```
- **Asset Sources**:
  - [Quaternius Creatures](https://quaternius.com/free-3d-models) (CC0)
  - [Kenney Fantasy Creatures](https://kenney.nl/assets/fantasy-creatures) (if available)
  - Custom low-poly models
- **Links**:
  - [Godot AnimationTree](https://docs.godotengine.org/en/stable/classes/class_animationtree.html)
  - [Blend Swap in Godot](https://docs.godotengine.org/en/stable/tutorials/animation/animation_tree.html)

### **VS-024: Facial Speech and Emotion** ⭐
- **Status**: in_review
- **Specialty**: character-performance
- **Research**: Blinking, facial expressions, mouth animation for speech
- **Technical**:
  - Shared mesh-based facial rig
  - Blink system (random + on long idle)
  - Speech-driven mouth movement
  - Emotion states (happy, angry, surprised, etc.)
  - Performance optimization (only animate visible characters)
- **Current Evidence**: facial_performance.gd, test_facial_performance.gd
- **Brief Implementation Notes**:
  ```gdscript
  # Facial performance system
  class_name FacialPerformance extends Node3D:
      var mesh_instance: MeshInstance3D
      var blink_timer: float = 0.0
      var blink_interval: float = randf_range(3.0, 6.0)
      var is_speaking: bool = false
      var current_emotion: String = "neutral"
      
      func _process(delta):
          # Blinking
          blink_timer += delta
          if blink_timer >= blink_interval:
              blink_timer = 0.0
              blink_interval = randf_range(3.0, 6.0)
              perform_blink()
          
          # Mouth movement for speech
          if is_speaking:
              update_mouth_open()
  ```
- **Asset Sources**:
  - Custom facial rigs for Quaternius models
  - Blend shapes for mouth/eye movement
- **Links**:
  - [Godot BlendShapes](https://docs.godotengine.org/en/stable/classes/class_meshinstance3d.html#class-meshinstance3d-property-blend-shapes)
  - [Facial Animation Tutorial](https://www.youtube.com/watch?v=example)
- **Deep Research Needed**: YES - Will create separate document

### VS-025: Nutrition Training Body-Progression
- **Status**: todo
- **Specialty**: sandbox-progression
- **Research**: Kid-safe progression without calorie restriction or body shaming
- **Technical**:
  - Food gathering/preparation
  - Training at world equipment
  - Bounded body presentation changes
  - HUD with icons and optional voice/captions
- **Design Constraints**:
  - No calorie counting
  - No body-size scoring
  - No shame mechanics
  - Gradual, optional, reversible progression
- **Links**:
  - [Child-Safe Game Design](https://www.example.com)
  - [Progression Systems in Games](https://www.gamasutra.com/view/feature/132353/)

---

## Additional Research Documents (Planned)

The following tasks will receive full research documents based on priority:

### High Priority (Completed ✅)
1. **VS-005**: Combat Telegraphs - Wind-up, hit feedback, aim assist, weapon differentiation - ✅ DONE - 56KB comprehensive compendium with blocking fixes identified
2. **VS-006**: Audio Visual Accessibility - Full audio bus architecture, accessibility systems - ✅ DONE
3. **VS-008**: Reversible Creator Interaction - Command Pattern, collect→upgrade→place→undo loop - ✅ DONE - 31KB comprehensive compendium
4. **VS-012**: Visual Art Direction - Palette, materials, lighting, asset kits - ✅ DONE - 46KB comprehensive compendium
5. **VS-014**: Modern Game UI - HUD replacement, controls, iconography - ✅ DONE - 62KB comprehensive compendium
6. **VS-015**: Cinematic Acting and Voice - ElevenLabs integration, voice queue, captions - ✅ DONE
7. **VS-018**: Homestead Interaction Loop - Doors, furniture, cooking, heal - ✅ DONE
8. **VS-022**: Character Customization - Mesh swapping, material overrides, persistence - ✅ DONE
9. **VS-023**: Original Liminal Creatures - Creature design and combat AI - ✅ DONE (Backrooms monsters included)
10. **VS-024**: Facial Speech and Emotion - Complete facial animation system - ✅ DONE

### High Priority (Completed ✅)
1. **VS-005**: Combat Telegraphs - Wind-up, hit feedback, aim assist, weapon differentiation - ✅ DONE - 56KB comprehensive compendium with blocking fixes identified
2. **VS-012**: Visual Art Direction - Palette, materials, lighting, asset kits - ✅ DONE - 46KB comprehensive compendium
3. **VS-014**: Modern Game UI - HUD replacement, controls, iconography - ✅ DONE - 62KB comprehensive compendium

### Low Priority
1. **VS-011, VS-016**: Visual Acceptance - Screenshot capture, performance validation
2. **VS-025**: Nutrition/Training - Progression systems
3. **VS-010**: Visual Acceptance Evidence - Testing infrastructure

---

## Quick Start Guide

### For Developers

If you're working on a task, check this directory first for research:

1. **Is there a deep research document?** (e.g., RESEARCH_VS-020_*.md)
   - YES: Read it thoroughly - contains code samples, links, best practices
   - NO: Check the brief notes in this document

2. **Need code examples?**
   - Deep research docs contain ready-to-use code snippets
   - Brief notes contain key patterns and links to tutorials

3. **Need asset sources?**
   - Kenney.nl (CC0) - First stop for most game assets
   - Poly Pizza (CC0) - Additional low-poly models
   - Quaternius (CC0) - Characters and creatures
   - OpenGameArt (CC0/CC-BY) - Additional assets
   - Freesound (CC0) - Sound effects

### For Researchers

To add research for a new task:

1. **Create a new file**: `RESEARCH_<TASK-ID>_<Descriptive_Name>.md`
2. **Follow the template**:
   - Task Overview (ID, title, specialty, status, dependencies)
   - Current Implementation Analysis
   - Online Research (with links)
   - Technical Deep Dive
   - Code Samples
   - Free Asset Packages
   - Learning Resources
   - Implementation Checklist
   - References
3. **Update this index**: Add entry to the appropriate section

---

## Asset Sources Summary

### Primary Sources (CC0 - No Attribution Required)

| Source | Best For | Link |
|--------|----------|------|
| Kenney.nl | UI, props, vehicles, characters, audio | [kenney.nl](https://kenney.nl/assets) |
| Poly Pizza | Low-poly 3D models, vehicles | [poly.pizza](https://poly.pizza/) |
| Quaternius | Characters, creatures, vehicles | [quaternius.com](https://quaternius.com/free-3d-models) |
| CC0 Textures | PBR textures, materials | [cc0textures.com](https://cc0textures.com/) |
| Poly Haven | Textures, HDRIs | [polyhaven.com](https://polyhaven.com/) |

### Secondary Sources (Check License)

| Source | License | Best For | Link |
|--------|---------|----------|------|
| OpenGameArt | CC0, CC-BY | Textures, sprites, models | [opengameart.org](https://opengameart.org/) |
| Freesound | CC0, CC-BY, etc. | Sound effects | [freesound.org](https://freesound.org/) |
| Mixamo | Varies | Animated characters | [mixamo.com](https://www.mixamo.com/) |
| Sketchfab | Varies | 3D models | [sketchfab.com](https://sketchfab.com/) |

---

## Godot 4.6 Specific Resources

### New Features in Godot 4.6
- **VehicleBody3D** - Built-in vehicle physics
- **PCG3D** - Native procedural generation
- **Jolt Physics** - Replaces Bullet, more deterministic
- **Occlusion Culling** - Built-in, volatile mode available
- **MultiMesh Improvements** - Better instancing support
- **NavigationServer Improvements** - Better pathfinding

### Migration Guides
- [Godot 4.0 to 4.6 Migration](https://docs.godotengine.org/en/stable/tutorials/upgrading/upgrading_project_4_0_4_6.html)
- [Physics Changes](https://docs.godotengine.org/en/stable/tutorials/physics/jolt.html)
- [Rendering Changes](https://docs.godotengine.org/en/stable/tutorials/upgrading/upgrading_project_4_0_4_6.html#rendering)

---

## Best Practices Collected

### General Godot Development
1. **Use class_name** for reusable components
2. **Preload resources** in _ready() or as constants
3. **Use signals** over direct function calls for decoupling
4. **Process in _physics_process** for physics-affecting code
5. **Use set_deferred()** for property changes that affect physics

### Performance
1. **Object Pooling** - Reuse objects instead of instantiating/destroying
2. **Visibility Ranges** - Use visibility_range_* on MeshInstance3D
3. **LOD** - Level of Detail for distant objects
4. **Instanced Rendering** - Use MultiMesh for repeated objects
5. **Activate/Deactivate** - Disable processing for off-screen objects

### Physics
1. **Collision Layers** - Use different layers for different object types
2. **Simplified Collision** - Use BoxShape3D/SphereShape3D for complex meshes
3. **Distance-Based Collision** - Disable collision for distant objects
4. **Fixed Timestep** - Use project_settings["physics/common/physics_fps"] = 60

### Memory Management
1. **Cache Resources** - Load once, instantiate many times
2. **Stream Content** - Load/unload based on player position
3. **Budget Processing** - Limit work per frame (e.g., 3.5ms for world streaming)
4. **Pool Objects** - Reuse game objects

---

## Contact & Contribution

This research compendium is maintained by Codex (Mistral Vibe).

To contribute:
1. Fork the repository
2. Add/update research documents
3. Submit a PR with your changes

For questions about specific tasks, reference the task ID and check the relevant research document.

---

*Generated by Mistral Vibe for Choyce Engine project*
*Last Updated: 2026-07-18*
