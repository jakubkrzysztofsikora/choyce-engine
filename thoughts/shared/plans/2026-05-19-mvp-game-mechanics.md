---
date: 2026-05-19
author: claude (architecture)
status: draft — for backlog grooming + parent (codex) review
target: MVP — "a kid can sit down, pick a game type, play it OR build it, hear NPCs talk to them, and win"
horizon: 3-4 calendar weeks (single dev) / ~2 weeks with /batch parallelism
related:
  - thoughts/shared/research/aaa-upgrade-synthesis-2026-05-19.md
  - thoughts/shared/research/godot-mechanics-aaa-2026-05-19.md
---

# MVP Game Mechanics Plan — Kid-Playable Platform

## 1. North star

A 6-year-old can:
1. Boot → see 3 game-type cards (PLAY / BUILD / ADVENTURE).
2. Pick type → land in working world with clear goal icon.
3. Move, jump, interact via controller/keyboard/touch.
4. Talk to NPC → NPC speaks contextual PL line via ElevenLabs streamed audio.
5. Complete goal → fanfare → return to landing.
6. (Creator loop) ZRÓB → place 5 Kenney props on blank world → spawn NPC → set personality prompt → playtest.

Non-goals: voxel terrain editing, multiplayer, asset import, marketplace publishing.

## 2. Current state (recon 2026-05-19)

| Subsystem | State |
|---|---|
| Domain (RefCounted, hex-clean) | ✅ keep |
| Block-logic compiler (5 RuleTypes) | ⚠️ no NPC blocks |
| Rules execution engine | ❌ does not exist (AAA Wave 1 fixes) |
| Win condition interpreter | ❌ DSL stored, never parsed |
| 5 templates (adventure/city/farm/obby/tycoon) | ⚠️ cosmetic-only diff, no game_type |
| NPCs | ❌ static JSON only, no spawn, no port |
| LLMPort | ✅ async complete + sync shim |
| AI dialog generation | ❌ only world-creation help, no NPC service |
| TextToSpeechPort | ❌ sync full-buffer, not streaming |
| ElevenLabs adapter | ❌ only pre-baked AudioBank |
| AudioGovernanceService | ✅ keep critical path |
| Asset palette / inventory | ❌ no mesh picker, no inventory |
| WorldEditCommand | ✅ enough |
| Session lifecycle | ❌ no ended_at, no win_state |

**Net**: authoring exists; runtime executor missing.

## 3. Gap vs user's 4 asks

| Ask | Current | MVP |
|---|---|---|
| Different game types (Roblox/Minecraft) | no enum | GameType enum, 3 runtime modes, landing 3 cards |
| World/game creation | palette swap, no mesh picker | AssetPaletteService + PlaceObjectFromCatalogService |
| Game goals | JSON only, no HUD | rules engine + Quest HUD, canonical goal per type |
| NPCs with AI + ElevenLabs on-the-fly | static JSON, no streaming | streaming TTS + GenerateNpcLineService + NpcDialoguePort |

## 4. Game-type catalog for MVP

### 4.1 PLATFORMER ("Wyspa skarbów" / "Las grzybów")
Spawn on terrain, camera follow. Goal: collect N items OR reach end zone. NPCs: 1-2 hint-helpers when stuck >5s. Win: collect-count or area-enter → complete_session(win=true). Roblox-obby vibe: jumps, hover, double-jump (AAA Wave 2).

### 4.2 BUILDER ("Plac budowy" — new)
Spawn on flat ground, palette button in HUD. Goal: "place 10 blocks" OR sandbox (parent toggle). Tap palette → grid → ghost cursor → click place / B remove / Y rotate. NPCs: optional builder buddy at 5/10/20 placements. Minecraft-lite: place/remove only, NO voxel dig in MVP.

### 4.3 ADVENTURE ("Mała farma" + new "Miasto przygody")
Spawn near 1-2 quest-giver NPCs. Goal: complete NPC quest ("bring 3 jabłka"). First interact → AI dialog; re-interact cached. 2-3 quest steps per scene. Win: all quests done → NPC victory line → fanfare. Toca-Boca/Sago vibe: short vignettes, no fail state.

Selection on landing: 3 cards above/replacing ZAGRAJ. PLAY → game-type picker → world picker filtered by type.

## 5. Domain additions (hex-clean, all RefCounted)

| Type | Path | Purpose |
|---|---|---|
| GameType enum | src/domain/world_authoring/game_type.gd | PLATFORMER/BUILDER/ADVENTURE |
| GameGoal | src/domain/world_authoring/game_goal.gd | {kind, target, label, icon_id} |
| NpcDefinition | src/domain/world_authoring/npc_definition.gd | {npc_id, display_name, role, mesh_asset_id, voice_id, personality_prompt, dialogue_cache} |
| NpcRole enum | same | COMPANION/QUEST_GIVER/SHOPKEEPER/HINT_HELPER |
| NpcInteractionContext | src/domain/gameplay/npc_interaction_context.gd | {npc_id, player_profile_id, world_id, recent_events, locale} |
| GeneratedNpcLine | src/domain/gameplay/generated_npc_line.gd | {text, audio_bytes_callback, moderation_flags, generated_at} |
| AssetCatalogEntry | src/domain/world_authoring/asset_catalog_entry.gd | {catalog_id, mesh_path, category, kid_safe_rating, default_scale} |
| WinOutcome | src/domain/gameplay/win_outcome.gd | {won, reason, score, completed_at} |
| PlayerInventory | src/domain/gameplay/player_inventory.gd | {items: Dictionary[String, int]} |

### New ports (outbound)
- `NpcDialoguePort.generate_line(context, on_text_chunk, on_done)` — async streamed
- `StreamingTtsPort.synthesize_stream(text, voice_id, locale, on_chunk, on_done)` — chunked PCM/MP3
- `AssetCatalogPort.list_kid_safe(category) → Array[AssetCatalogEntry]`
- `NpcAgentPort` — spawn, despawn, face, play_anim, play_speech_at
- `RulesRuntimePort` (AAA Wave 1.C-3)
- `PhysicsToyPort` (AAA Wave 2.K)

### New application services
- `GenerateNpcLineService` — build LLM prompt → LLMPort.complete() → moderate chunks → GeneratedNpcLine
- `WinConditionInterpreter` — parse DSL → expression tree → evaluate → emit SessionEndedEvent
- `PlaceObjectFromCatalogService` — catalog_id + position + world → WorldEditCommand(ADD_NODE) + kid-safety check
- `EvaluateGoalService` — on rules event → check active GameGoal → emit progress
- `NpcDialogueOrchestrator` — coordinate GenerateNpcLineService → StreamingTtsPort → spatial NpcAgentPort.play_speech_at
- `TextModerationService` (rename from VoiceInputModerationService.check_text) — bi-directional PL filter, already has 5000-term blocklist

### New adapters
- `ElevenLabsStreamingTtsAdapter` — /v1/text-to-speech/{voice_id}/stream, chunked HTTPRequest → AudioStreamGeneratorPlayback
- `OllamaNpcDialogueAdapter` — wraps LLM adapter, injects NPC personality prompt
- `GodotNpcAgentAdapter` — instantiates npc_base.tscn, FSM (IDLE/SPEAK/WAVE/POINT), AudioStreamPlayer3D
- `KenneyAssetCatalogAdapter` — scans data/models/kenney/**/*.glb, filters by kid_safe_allowlist.txt
- `GodotRulesRuntimeAdapter` (AAA Wave 1) — extend to eval WIN_CONDITION

## 6. Streaming TTS pipeline

Current TextToSpeechPort returns full PackedByteArray after synthesis — 1.5-3s latency, too long for kid attention.

```
GenerateNpcLineService
  └→ LLMPort.complete(prompt, on_token, on_done)
       │
       ├→ on_token: TextModerationService.check_chunk(chunk)
       │     ├→ BLOCK: cancel TTS, play fallback ("...")
       │     └→ else: forward to StreamingTtsPort
       │
       └→ on_done: StreamingTtsPort.finalize()

StreamingTtsPort (ElevenLabsStreamingTtsAdapter)
  └→ HTTPRequest POST /v1/text-to-speech/{voice_id}/stream
       optimize_streaming_latency=3
       └→ bytes → AudioStreamGeneratorPlayback.push_buffer(pcm_chunk)

NpcAgentPort (GodotNpcAgentAdapter)
  └→ AudioStreamPlayer3D plays at NPC head
```

**Latency target**: token-1 → first-audio-byte ≤ 800ms; first playback ≤ 1.2s after interact.

### Safety gates (non-negotiable)
1. **Personality prompt server-controlled**. Kid cannot inject. Prompt = data/npc/personalities/{npc_id}.txt + auto-appended hard rules ("Reply in Polish. No scary words. ≤2 sentences.").
2. **TextModerationService.check_chunk()** intercepts every LLM token before TTS. Fail-closed.
3. **AudioGovernanceService.may_speak(npc_id, profile_id)** consulted before TTS call.
4. **AuditLedgerPort.append()** records every line: prompt, output, moderation result, profile_id.
5. **Cache + rate limit**: hash (npc_id, profile_id, context_hash) → reuse. 30s re-interact cap. 50 lines/day quota.

### Offline fallback
If LLM/TTS unavailable → fall back to npc_dialogue.json static lines via AudioBank. Kid never sees broken NPC. Fallback is **default for new profiles** until parent toggles AI on — COPPA opt-in.

## 7. Win-condition interpreter

Grammar (MVP):
```
expr := atom | expr "and" expr | expr "or" expr | "not" expr | "(" expr ")"
atom := identifier op literal | identifier
op   := ">=" | "<=" | ">" | "<" | "==" | "!="
identifier := "score" | "inventory."NAME | "quest."NAME | "time" | "blocks_placed" | "in_zone."NAME
literal := INT | STRING
```

Real strings templates emit: `score>=100`, `inventory.carrot>=5`, `quest.harvest=='complete'`, `blocks_placed>=10`, `in_zone.win==true`.

~120 lines recursive-descent GDScript, pure RefCounted. Eval ctx built per frame by GodotRulesRuntimeAdapter. On `true` and rule not yet fired → emit SessionEndedEvent(win=true). **No Expression.parse() / no eval()** — strict descent over grammar.

## 8. Asset palette + placement (BUILDER mode)

Scan data/models/kenney/{nature_kit,food_kit,pirate_kit,survival_kit,mini_characters,toon_characters}/**/*.glb.
- Include: trees, plants, food, blocks, fences, signs, animals, toy-vehicles, benches, buildings.
- Exclude: weapons, zombies/monsters from survival_kit, prisoner skins.

Curated allow-list at data/models/kenney/kid_safe_allowlist.txt. ~400 props estimated.

### Categories (kid-readable, PL icons)
TREES_PLANTS "Rośliny", FOOD "Jedzenie", BUILDINGS "Budynki", BLOCKS "Klocki", ANIMALS "Zwierzęta", VEHICLES "Pojazdy", DECORATION "Ozdoby", CHARACTERS "Postacie".

### Build HUD
Bottom palette bar with 8 category icons. Tap → grid ~12 props/page. Tap prop → ghost cursor. Click place / right-click remove / long-press rotate. All edits flow through WorldEditCommand → BlockEditWorldService (existing commit + audit).

### Spawn NPC in BUILDER
CHARACTERS category: tap → modal with personality prompt + voice picker (3 PL voices). Parent master switch disables AI NPCs entirely for younger kids.

## 9. Block-logic compiler extensions

```gdscript
enum RuleType { EVENT_TRIGGER, TIMER, SCORING, WIN_CONDITION, ITEM_SPAWN,
                NPC_SPAWN,    # NEW
                NPC_SAY       # NEW
              }
```

New DSL strings:
- `on_zone_enter:spawn_npc(<npc_def_id>, <position>)`
- `on_interact:npc_say(<npc_id>, <prompt_seed>)`
- `on_collect:npc_say_cached(<npc_id>, <key>)`

Rules runtime dispatches NPC actions to NpcDialogueOrchestrator.

## 10. Wave sequence (3-4 wks solo, ~2 wks /batch)

Layers on AAA roadmap. AAA Wave 0+1 prerequisites.

### MVP-I Foundations (depends on AAA W1.C-3 rules engine)
- I.1 Win-condition interpreter (recursive descent) — 1 day
- I.2 Extend GodotRulesRuntimeAdapter to eval WIN_CONDITION, emit SessionEndedEvent — ½ day
- I.3 EvaluateGoalService + GameGoal domain + progress events — ½ day
- I.4 Quest HUD listens to goal-progress events; 4 goal kinds — ½ day
- I.5 Session lifecycle: ended_at, win_outcome, complete_session(win) — ¼ day

Exit: boot, autoplay starter_adventure, collect 5 items, fanfare, return to landing.

### MVP-II Game types + landing redesign (1.5 days)
- II.1 GameType enum + game_type field on World — ¼ day
- II.2 Migrate 5 templates: tag with game_type; add "Plac budowy" BUILDER — ½ day
- II.3 Landing: 3 game-type cards + PL labels + icons — ½ day
- II.4 Game-type → world picker filter — ¼ day

Exit: kid taps "Buduj!" → builder worlds only → enters blank Plac budowy.

### MVP-III BUILDER runtime (3 days)
- III.1 KenneyAssetCatalogAdapter + kid_safe_allowlist.txt (~400 props) — 1 day
- III.2 AssetPaletteService + PlaceObjectFromCatalogService — ½ day
- III.3 BUILDER HUD: palette bar, ghost cursor, undo last — 1 day
- III.4 Build-mode goal "place 10 blocks" → WIN_CONDITION via inventory.blocks_placed — ¼ day
- III.5 Parent toggle "free sandbox" disables win — ¼ day

Exit: kid enters blank world, opens palette, places 10 trees, fanfare, returns to landing.

### MVP-IV NPC base + static dialog (2 days)
NPCs use pre-baked npc_dialogue.json first. Tests entire interaction surface without depending on Ollama/ElevenLabs runtime. Wave V swaps source.

- IV.1 NpcDefinition, NpcRole, NpcInteractionContext domain — ¼ day
- IV.2 npc_base.tscn: CharacterBody3D + AnimationTree FSM + AudioStreamPlayer3D + Area3D — ½ day
- IV.3 GodotNpcAgentAdapter + NpcAgentPort — ½ day
- IV.4 NpcDialogueOrchestrator V1 (static path via AudioBank) — ½ day
- IV.5 NPC spawn from template (extend TemplateLoader, read npcs[]) — ¼ day
- IV.6 Interact action (E / Y / tap) → NpcAgentPort.interact() — ¼ day
- IV.7 Speech-bubble HUD: PL subtitle over NPC head (accessibility) — ¼ day

Exit: kid walks to farmer NPC, presses E, NPC turns, plays static greeting_pl, subtitle floats.

### MVP-V Streaming AI dialog (3 days)
- V.1 StreamingTtsPort + ElevenLabsStreamingTtsAdapter; latency=3; chunked HTTPRequest → AudioStreamGeneratorPlayback; back-pressure — 1.5 days
- V.2 NpcDialoguePort + OllamaNpcDialogueAdapter; personality prompt template; pipe Ollama tokens → moderation → StreamingTtsPort — 1 day
- V.3 GenerateNpcLineService full: orchestrate LLM + moderation + TTS; emit GeneratedNpcLine; record to AuditLedger — ½ day
- V.4 Cache: hash (npc_id, profile_id, context_hash); 30s re-interact cap; 50/day quota in AudioGovernanceService — ½ day
- V.5 NpcDialogueOrchestrator V2: try AI path; on any failure fall back to V1 static — ¼ day
- V.6 Parent toggle "AI NPC voices ON/OFF" default OFF (COPPA opt-in) — ¼ day
- V.7 Smoke + integration tests: mock LLM + TTS assert latency budget; fail closed on moderation hit — ½ day

Exit: kid presses E on farmer, within ~1s farmer says live PL contextual line ("Dzień dobry! Widzę, że masz 2 jabłka. Zbierz jeszcze 3, dobrze?"). Re-interact within 30s plays cached. Disconnect Ollama → static fallback. Parent toggles AI off → only static. Audit log shows every generated line.

### MVP-VI Polish + onboarding (2 days)
- VI.1 Onboarding overlay updated for game-type picker — 30s skippable tutorial on first boot — ½ day
- VI.2 Goal icons for 4 GameGoal kinds; PL copy through _t(); subtitles in PL — ½ day
- VI.3 ADVENTURE starter "Miasto przygody" — new template, 2 quest-giver NPCs, 3 steps; AI prompts in template JSON — 1 day

Exit: cold boot → onboarding → kid picks ADVENTURE → enters Miasto → meets baker NPC → AI dialog "Hej! Pomożesz mi znaleźć 3 owoce?" → kid collects 3 → returns → "Dziękuję! Brawo!" → fanfare → landing. End-to-end MVP loop.

## 11. Out of scope (deferred)

Voxel/Minecraft terrain dig & build; multiplayer / Roblox-style published worlds; world marketplace; NPC-to-NPC dialog; custom NPC mesh upload (Kenney only); asset import from outside engine; ElevenLabs voice cloning by parents; AI-generated quest design (parent block editor still authors quests; runtime only generates NPC speech); 3D voice modulation; multi-locale (PL only); save & resume mid-session (sessions ≤ 8min).

## 12. Risk register

| Risk | L | I | Mitigation |
|---|---|---|---|
| ElevenLabs streaming latency >1.2s on cell | M | H | fallback to static after 1.5s first-byte timeout; UI distinguishes AI vs static |
| LLM token stream produces unsafe text mid-stream | M | C | TextModerationService.check_chunk() **before** TTS; on flag, kill pipeline, play fallback |
| Personality prompt injection via voice input | L | H | NPC context **never** includes raw kid speech — structured events only |
| Ollama OOMs on long conversations | M | M | line cap 200 chars; context = last 3 events; per-NPC reset on world re-load |
| Cache grows unbounded | M | L | LRU 1000 entries; daily wipe; debounced fs store |
| AI voice billing surprise | M | M | per-profile daily quota 50 in AudioGovernanceService; parent dashboard counter |
| Streaming TTS adapter doesn't drain → memory leak | M | H | get_frames_available() polled each frame; on overrun drop oldest; integration test asserts |
| Kid spams interact → 20 LLM calls/sec | H | H | per-NPC cooldown 5s (cached line); orchestrator rate-limit |
| Parent "AI off" forgotten | L | C | default OFF for new profiles; toggle requires PIN; AudioGovernanceService.may_speak() single chokepoint |
| WIN_CONDITION DSL eval injection | L | M | strict recursive-descent parser; **no Expression.parse() / no eval()** |
| BUILDER kid places 10000 blocks | M | M | per-world block cap 500; "magazyn pełny" overlay; Jolt handles 500 sleeping bodies |
| Asset allowlist drift (new Kenney pack adds unsafe prop) | M | M | **explicit allow** not deny; new packs need manual review |

## 13. Composition root impact

main.gd._build_default_ports adds 6 KEY_* entries: KEY_NPC_DIALOGUE, KEY_STREAMING_TTS, KEY_ASSET_CATALOG, KEY_NPC_AGENT, KEY_WIN_INTERPRETER, KEY_GENERATE_NPC_LINE. Wave B composition-root CI gate catches missing wires. No new infra.

## 14. COPPA / safety summary

3 gates already proven:
1. **Consent** — FilesystemConsentStore (Wave B). AI-voice opt-in default OFF; parent enables with PIN.
2. **Moderation** — TextModerationService (rename of VoiceInputModerationService.check_text); PL 5000-term blocklist + injection patterns. Fail-closed.
3. **Audit** — AuditLedgerPort (Wave B, hash-chain). Every generated line: prompt, output, moderation, voice, profile_id, timestamp. Retrievable via parent "Dane" + ManageDataLifecycleService COPPA export.

New parental settings:
- ai_voices_enabled: bool = false
- ai_voice_quota_per_day: int = 50
- ai_npc_personality_visible: bool = false (parent transparency opt-in)
- block_npc_speech_after_minutes: int = 0 (anti-attention-trap)

## 15. Test strategy

| Layer | What | Where |
|---|---|---|
| Unit (domain) | WIN_CONDITION grammar, GameGoal progress, NpcInteractionContext | tests/domain/ |
| Contract (port) | LLMPort streaming order, StreamingTtsPort chunk sequencing, NpcAgentPort lifecycle | tests/ports/ |
| Application | GenerateNpcLineService e2e with fake LLM+TTS; moderation injection; cache hit | tests/application/ |
| Adapter (integration) | ElevenLabsStreamingTtsAdapter vs mock chunked HTTP server; OllamaNpcDialogueAdapter vs fixture LLM | tests/adapters/ |
| AI vision (TASK-061-066) | KF-005 builder palette, KF-006 NPC interact, KF-007 win-fanfare | tests/ai-scenarios/kid-flows/ |
| Smoke (run.sh --smoke) | Extend autoplay to cycle 3 game-type cards | scripts/dev/run.sh |
| L1 boot warning gate | composition-root-gate.yml already catches missing wires | existing |

## 16. Estimated total cost

| Wave | Solo | /batch |
|---|---|---|
| MVP-I | 2.75 | 2 |
| MVP-II | 1.5 | 1 |
| MVP-III | 3 | 2 |
| MVP-IV | 2 | 1.5 |
| MVP-V | 3 | 3 (serial — single critical path) |
| MVP-VI | 2 | 1.5 |
| **MVP total** | **~14d** | **~11d** |

Plus AAA prerequisites: W0 0.5d + W1.A 1d + W1.C-1 0.5d + W1.C-2 1d + W1.C-3 1.5d = ~4.5d.

**Total to MVP**: ~18-20 days solo, ~14-15 with /batch. ≈ 3 calendar weeks.

## 17. Next 3 commits (concrete)

1. **AAA Wave 0 + Jolt swap** (½ day) — project.godot import defaults + physics/3d/physics_engine = "Jolt Physics" + Terrain3D addon + MetalFX gate skeleton. Smoke test must pass.
2. **AAA W1.C-3 rules engine** (1.5d) — CompiledRule domain, RuleCompilerService regex parser, RulesRuntimePort + GodotRulesRuntimeAdapter, wire into GameplayRuntime. 5 templates' compiled_logic strings start firing. No AI yet.
3. **MVP-I.1+I.2 win-condition interpreter** (1.5d) — recursive-descent parser + rules adapter integration. farm.json auto-wins on inventory.carrot>=5. End-to-end smoke.

After these 3, fork: Wave II (cards), III (BUILDER), IV (NPC base) are independent → ship parallel via /batch. Wave V (streaming AI) waits for IV.

## 18. References

- thoughts/shared/research/aaa-upgrade-synthesis-2026-05-19.md
- thoughts/shared/research/godot-mechanics-aaa-2026-05-19.md
- src/ports/outbound/llm_port.gd
- src/application/request_ai_creation_help_service.gd (pattern for GenerateNpcLineService)
- src/application/voice_input_moderation_service.gd (rename → TextModerationService)
- src/application/audio_governance_service.gd
- src/ports/outbound/audit_ledger_port.gd
- data/templates/{adventure,city,farm,obby,tycoon}.json
- data/templates/npc_dialogue.json (static fallback source)
- ElevenLabs: /v1/text-to-speech/{voice_id}/stream optimize_streaming_latency=3
- Godot AudioStreamGenerator + AudioStreamGeneratorPlayback (chunked playback primitive)
