---
date: 2026-05-18
reviewer: game-design
commit: 68d73a3
status: complete
---
# Review: Game Design

## Summary
The game has no playable game loop. Templates define rich rules, quests, items, and NPCs in JSON, but zero of this content is executed at runtime. Kids land on static 3D boxes, walk around collecting invisible nothing, and see a celebration screen with "0 znajdzki, 0 osiagniecia, 0s" regardless of what happened. Three sharpest findings: (1) `compiled_logic` rules in all 5 templates are dead strings never parsed or executed, (2) GameplayRuntime only handles "win" and "collectible" triggers, ignoring all other trigger types from templates, (3) undo button, paint tool, and move tool are non-functional for the target age group.

## Findings (severity-ranked)
### Critical (block release)
- **G-001: No rules engine exists.** All 5 templates define TIMER, SCORING, ITEM_SPAWN, WIN_CONDITION, and EVENT_TRIGGER rules via `compiled_logic` strings (e.g., `"every_30s:advance_crop_stage()"`, `"on_happiness_50:unlock_area('school_zone')"`). The domain entity `GameRule` stores these strings. Nothing parses or executes them. Crops never grow, happiness never ticks, items never spawn, areas never unlock. The entire gameplay promise is vaporware. Files: `data/templates/*.json` (rules arrays), `src/domain/world_authoring/game_rule.gd`, `src/adapters/inbound/gameplay/gameplay_runtime.gd`.
- **G-002: Trigger types from templates are silently ignored.** GameplayRuntime `_on_trigger_area_entered` only matches `"win"` and falls everything else to `"collectible"`. Templates define `treasure_zone`, `puzzle_zone`, `harvest_zone`, `sell_zone`, `park_zone`, `school_zone`, `checkpoint`, `bonus_zone` trigger types. None of these have runtime behavior. The obby checkpoint system, the adventure puzzle gate, the farm sell zone -- all dead. File: `src/adapters/inbound/gameplay/gameplay_runtime.gd:96-104`.
- **G-003: Quest system is decorative.** Templates define 4 quests each with `objective_type`, `target_count`, `reward_score`, and `reward_unlocks`. KidStatusReadModelAdapter has a `quest_progress` dictionary. But no code ever increments quest progress during gameplay. The quest tracker in PlayShell shows "Brak misji" (No quests) because starter worlds carry no quest metadata. The quest data in `data/templates/*.json` is never loaded into a world's metadata. Files: `data/templates/*.json` (quests arrays), `src/adapters/inbound/scenes/play/play_shell.gd:392-425`, `src/adapters/kid_status_read_model_adapter.gd`.

### High
- **G-004: Starter worlds are static prop arrangements.** The 3 seeded worlds ("Wyspa skarbów", "Mała farma", "Las grzybów") are lists of DECORATION/OBJECT nodes placed on a featureless plane. There is no gameplay mechanic attached to any of them. A 5-year-old enters "Treasure Island" and sees rocks, palm trees, and a chest -- but there is no treasure to find, no puzzle to solve, no path to follow. The chest is just a box. File: `src/adapters/inbound/main.gd:432-539` (`_seed_starter_content_if_empty`).
- **G-005: No fail state or challenge exists anywhere.** For ages 5-8, gentle failure + recovery teaches persistence. The obby template should have falling (failed jump) that respawns at checkpoint. The adventure template should have dead-end paths. There is zero consequence for any action. Even the "hard landing" in GameplayRuntime only triggers a screen shake -- no health loss, no respawn, no setback. This makes the experience flat and unrewarding. File: `src/adapters/inbound/gameplay/gameplay_runtime.gd:92-94`.
- **G-006: Celebration always shows empty stats.** Session end reads from KidStatusReadModel, but the gameplay runtime never writes stats to it. Every session ends with 0 collectibles, 0 achievements, 0 time. The title switches to "Swietnie! Wroc po wiecej" (positive framing) which is good psychology, but the counters tween from 0 to 0, which is visually confusing. The confetti fires for nothing. File: `src/adapters/inbound/scenes/play/play_shell.gd:280-303, 306-373`.
- **G-007: Template JSON content never reaches the game.** TemplateLoader (`src/application/template_loader.gd`) can load `data/templates/*.json` and BuildContentService can use it. But neither is wired into the inbound flow. The template picker in CreateShell is cosmetic (changes palette only, line 808-812). The starter worlds in main.gd are hardcoded node arrays, not loaded from templates. The rich worlds defined in JSON (with 12+ nodes, rules, quests, NPC dialogue, onboarding hints) are unreachable content.
- **G-008: All 5 templates share identical difficulty.** Every template is `"difficulty": "easy"`, `"suggested_age": "6-8"`, `"estimated_playtime_min": 10-15`. A 5-year-old and 8-year-old have very different spatial reasoning and reading skills. No adaptive difficulty. The obby (platformer) is marked the same difficulty as the farm (planting simulator). No progression between templates.

### Medium
- **G-009: Undo button is dead.** CreateShell has an `_undo_button` that renders with label "Cofnij" but has no `pressed.connect()` call anywhere. The EventSourcedActionLog supports checkpoints and undo, but the button is not wired to it. For a 5-8 year old, undo is critical for safe exploration. File: `src/adapters/inbound/scenes/create/create_shell.gd:79` (declaration), `_wire_actions()` has no undo wiring.
- **G-010: PAINT tool applies wrong property key.** Paint applies `{"paint": "kolor_przyjazny"}` but the 3D preview reads `sn.properties.get("color", ...)`. The paint action has no visual effect. MOVE always applies a fixed Vector3(1,0,0) offset regardless of direction. These are the two most intuitive tools for young children and both are broken. File: `src/adapters/inbound/scenes/create/create_shell.gd:405-410`.
- **G-011: 3D preview truncates to 8 nodes.** `_update_3d_preview()` caps at `mini(nodes.size(), 8)`. All templates have 10-13 nodes. Kids will see incomplete previews of their worlds. The cap exists without explanation or user feedback. File: `src/adapters/inbound/scenes/create/create_shell.gd:877`.
- **G-012: No audio-world theme matching.** GameplayRuntime audio is limited to generic "step", "land", "jump", "collect" SFX. PlayShell selects music by template_id (`_play_world_music`) but the gameplay session itself has no ambient audio tied to the world theme. No farm animals, no city traffic, no jungle ambiance. The templates define LIGHT nodes with named colors ("Pochodnia", "Lampa Placu") but these have no audio counterpart. File: `src/adapters/inbound/gameplay/gameplay_runtime.gd`.
- **G-013: NPC dialogue is unused content.** `data/templates/npc_dialogue.json` defines 14 NPCs across 5 templates with greeting/hint/celebration lines. No NPC system exists in the gameplay runtime. The characters (npc_farmer, npc_pirate, npc_parrot, npc_coach) are defined but never appear. This is wasted content that should either be implemented or removed to avoid confusion.
- **G-014: Landing world picker may be empty on first frame.** Starter worlds are seeded in `_build_default_ports_phase_2()` which runs via `call_deferred`. If the kid clicks "ZAGRAJ" before Phase 2 completes, the world picker shows zero cards. The timing window is small but exists on slow hardware. File: `src/adapters/inbound/main.gd:136-137` (Phase 2 scheduling), `src/adapters/inbound/scenes/landing/landing_screen.gd:279-284` (picker population).
- **G-015: Onboarding relies on text that 5-year-olds cannot read.** The OnboardingOverlay shows text instructions. The 3-second idle TTS prompt is optional and fires late. Polish text like "Wybrales: Umiesc" or "Wybierz narzedzie. Zacznij od Umiesc" is inaccessible to pre-readers. No icon-only or voice-only onboarding path exists.

### Low / nits
- **G-016: "Choyce" brand name in 96px text is meaningless to 5-year-olds.** Landing screen title serves adults, not the target audience. Consider a mascot or visual logo instead.
- **G-017: Template card emojis are font-dependent.** The emoji icons (island, tractor, city, runner, money bag) may render differently across platforms. For consistent kid experience, use custom sprites.
- **G-018: Confetti position assumes standard viewport.** `Vector2(vp_size.x / 2.0, 80.0)` places confetti at top-center, which may look wrong on non-16:9 displays or tablets in portrait mode.
- **G-019: item_catalog.json defines score values but scoring is not implemented.** Carrot=8, gem=50, pearl=30, coin=10 -- these values are balanced for an economy that does not exist.
- **G-020: Parent button at 0.72 alpha is hard for kids to find but easy for parents.** This is actually good safety design but should be documented as intentional.

## Manual test log
- Code-level review only. No live Godot instance available for E2E testing.
- Verification gap: cannot confirm visual rendering, audio playback, or controller input responsiveness.
- All findings are based on static code analysis and cross-referencing templates against runtime code.

## Recommendations
1. **Build a minimal rules engine** (G-001). Start with TIMER + SCORING rules only -- they cover 80% of template gameplay. Parse `compiled_logic` strings into callable actions. Wire into GameplayRuntime `_process()`.
2. **Wire the quest tracker to the rules engine** (G-003). When a SCORING rule fires, increment matching quest progress. Show quest completion in the side panel.
3. **Connect TemplateLoader to starter world seeding** (G-007). Replace hardcoded node arrays in `_seed_starter_content_if_empty` with template JSON loading. This gives starter worlds their rules, quests, and NPC data.
4. **Add checkpoint/respawn triggers** (G-002). At minimum, handle `checkpoint` (save respawn point) and fall-below-plane detection (respawn at last checkpoint). This enables the obby template.
5. **Wire the undo button** (G-009). Connect to EventSourcedActionLog's undo capability. This is already built, just not connected.
6. **Fix PAINT and MOVE tools** (G-010). Paint should write to the `"color"` property. MOVE should use a drag UI or direction picker, not a fixed offset.
7. **Add fail-and-recover for obby** (G-005). Plane-below-Y=-10 detection + respawn at last checkpoint. This is 10 lines of code that makes the obby actually playable.
8. **Seed stats during gameplay** (G-006). Increment collectibles counter when `_trigger_collectible` fires. Increment time counter per frame. Write to KidStatusReadModel or a session stats dictionary.
