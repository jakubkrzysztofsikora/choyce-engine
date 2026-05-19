---
date: 2026-05-19
author: claude (architecture)
status: synthesis — port-this list for next 3 sprints
sources:
  - thoughts/shared/research/godot-combat-patterns-2026-05-19.md
  - thoughts/shared/research/godot-quest-npc-patterns-2026-05-19.md
  - thoughts/shared/research/godot-ui-patterns-2026-05-19.md
  - thoughts/shared/research/godot-procedural-patterns-2026-05-19.md
  - thoughts/shared/research/godot-input-patterns-2026-05-19.md
---

# Godot Games Adoption Plan — synthesis of 5 deep-research passes

Pattern haul across 5 parallel research agents reviewing Brotato, Dome Keeper, Cruelty Squad references + open-source MIT/CC0 Godot projects: gdquest-demos, HeartBeast Action RPG, Zylann/voxelgame, peter-kish/gloot, sempitern0/Lootie, dialogic-godot/dialogic, shomykohai/quest-system, TheWalruzz/godot-questify, MarcoFazioRandom/Virtual-Joystick, limbonaut/limboai, godot-demo-projects, godotneers/G.U.I.D.E.

All findings cross-checked against existing choyce-engine code (Wave 0 Jolt + rules engine + combat layer + voxel build + gear loop + parental gates already shipped). Patterns ranked by **ROI for the 7yo target user** + **portability** (license + Godot 4.6 compatibility + minimal blast radius).

---

## TL;DR — top 12 to port

| # | Pattern | Source | Replaces / unblocks | Cost | Wave |
|---|---|---|---|---|---|
| 1 | `GameModeService` (build vs combat from equipped slot) | research §input | Mouse-rebind concern (Adv 5 #1) — single input set, mode inferred | S | next |
| 2 | HitArea3D / HurtArea3D typed split | gdquest hitbox-hurtbox MIT | Duck-typed `apply_damage_from_enemy` call_deferred (Adv 1, Adv 6 race) | M | next |
| 3 | Boolean iframe + `_already_collected` flag pattern | gdquest combat MIT | `set_deferred("monitoring")` race in loot_pickup (regression flag!) | S | hot-fix |
| 4 | AnimationTree Method Call Track hitbox | gdquest juicy-attack MIT | Per-frame group-scan in _perform_attack | M | next |
| 5 | SubViewport cube icons for hotbar | godot-docs + Zylann voxelgame | Flat ColorRect tiles (Adv 5 #8) | M | next |
| 6 | GLoot inventory plugin (922★ MIT) | peter-kish/gloot | Hand-rolled `_inventory_labels` Dict | M | wave+1 |
| 7 | Crosshair + ghost block preview | Zylann/voxelgame MIT | No targeting feedback (Adv 5 #2) | S | next |
| 8 | Lootie typed LootTable Resource | sempitern0/Lootie MIT | `Array[Dictionary]` loot tables (Adv 1 M3) | S | next |
| 9 | Gear tiers as Resource files | godot-docs + spaceyjase/godot-crafting | `_weapon_tiers` array literal in adapter (Adv 1 H1) | M | wave+1 |
| 10 | XP curve + level-up card chooser | GDQuest + DEV.to RPG | No dopamine (Adv 4 ROI 2) | M | wave+1 |
| 11 | Dialogic 2 text-stripped (icon+audio only) | dialogic-godot/dialogic MIT | NPC dialog gap | L | wave+2 |
| 12 | MarcoFazioRandom virtual joystick (touch) | MIT | Tablet players locked out today | S | wave+2 |

---

## Critical regression flag (must fix before next push)

Adv 6 race: `set_deferred("monitoring", false)` does NOT prevent same-frame double-pickup on Godot 4.6.2 (confirmed in [Godot forum thread on hurtbox disable](https://forum.godotengine.org/t/best-way-to-disable-hurtboxes-or-hitboxes-after-first-hit-set_deferred-is-too-slow/136234) + Dre Dyson Godot 4.6.2 writeup). I used this pattern in `loot_pickup.gd` commit `5c74d6c` as the P0 double-pickup fix. The real-world race is unaffected.

**Replace with boolean guard**:
```gdscript
var _already_collected: bool = false

func _on_body_entered(body: Node3D) -> void:
    if _already_collected:
        return
    if not (body is PlayerController):
        return
    _already_collected = true
    picked_up.emit(item_id, quantity)
    # … tween + queue_free
```

Single-line P0 hotfix. Apply to `loot_pickup.gd` and check `enemy_controller.gd._on_defeat` doesn't have the same race (it disables `_collision` via `set_deferred("disabled", true)` — same class of bug if any signal re-enters before the deferred call lands).

---

## Cross-cutting themes (where 3+ agents agree)

### Theme 1 — Replace Array/Dict literals with `extends Resource` files
- Combat agent: HitArea3D `@export var damage := 10`
- Procedural agent: `WaveConfig`, `GearTierResource`, `RecipeResource`, `LootTableData`
- Quest agent: `Quest extends RefCounted` with `steps[]` + `QuestStatus` enum
- UI agent: global `.theme` resource with type variations (`ButtonLarge`, `HotbarSlot`)

**Action**: convert all in-code data tables to `.tres` files under `res://data/{combat,gear,waves,quests,ui}/`. Parent zone can later expose a "World Editor" mode that edits these directly. Godot inspector becomes the design tool — no code touch for difficulty tuning.

### Theme 2 — Replace per-frame scans with signal-driven dispatch
- Combat: AnimationTree Method Call Track fires `enable_hitbox()` at exact contact frame, kills per-frame `get_nodes_in_group("enemies")` scan in PlayerController._perform_attack
- Procedural: `defeated` signal counter drops the `_check_enemy_wave_respawn` poll (already flagged by Adv 3 perf)
- UI: SubViewport `update_mode = UPDATE_ONCE` (not per-frame) — render cube icon once per kind, cache as ImageTexture
- Input: `InputDeviceTracker.device_changed` signal flips HUD glyphs — no per-frame device polling

**Action**: audit every `_process` / `_physics_process` body for content that could be event-driven. Already-known: wave respawn + group scan. Newly-flagged: hotbar icon refresh, controller-prompt refresh.

### Theme 3 — Kid-friendly defaults > theoretically-optimal defaults
- Input: deadzone 0.28 (not Godot default 0.5) + curve 2.0 — kids' thumbs rest on stick
- UI: 80×80 touch targets, ≥ 32px separation — above 48dp floor, kids need 80–96dp
- Combat: HP cap max_hp/3 per hit, 400ms iframes — already shipped, reaffirmed by HeartBeast pattern
- Procedural: difficulty curve `hp_mult = 1 + sqrt(N) * 0.25` not linear — flat early, slow ramp
- Tunic-style icon-only dialog — no text required → kid non-reader OK + zero text moderation cost

**Action**: codify these as project-wide constants in a `KidFriendly` autoload or constant module.

### Theme 4 — One mode inferred, not switched (Minecraft Bedrock parity)
Single input set. Mode = equipped slot. Block in hotbar slot → build (LMB=break, RMB=place). Weapon in hotbar slot → combat (LMB=attack). No mode-toggle button.

**Action**: introduce `GameModeService` (application/) keyed by `PlayerInventory.equipped_slot`. PlayerController dispatches LMB to either `_perform_attack` or `_try_break_block` based on `GameModeService.current_mode()`. Adv 5 mouse-rebind concern dissolves.

---

## Domain additions (delta from current code)

### Resources (`extends Resource`, file-backed `.tres`)
| Type | Path | Notes |
|---|---|---|
| `LootEntry` | `src/domain/combat/loot_entry.gd` | Replaces `Array[Dictionary]` in EnemyDefinition.loot_table. Fields: `item_id`, `min_qty`, `max_qty`, `chance`, `rarity_tier`. |
| `LootTableData` | `src/domain/combat/loot_table_data.gd` | Holds `Array[LootEntry]` + roll mode (UNIFORM / TIERED). Provides `.generate(rng) -> Array[Dropped]` |
| `WaveConfig` | `src/domain/combat/wave_config.gd` | `wave_number`, `pack_size`, `hp_mult`, `speed_mult`, `is_boss_wave`, `archetype_weights: Dictionary[EnemyArchetype, float]` |
| `GearTierResource` | `src/domain/combat/gear_tier_resource.gd` | `tier_id`, `display_name`, `weapon_damage`, `unlock_level: int`, `recipe: Dictionary[item_id, int]` |
| `RecipeResource` | `src/domain/crafting/recipe_resource.gd` | `ingredients: Dictionary[item_id, int]`, `output_item: GearItem`, `tier_required: int` |
| `Quest` | `src/domain/gameplay/quest.gd` | `quest_id`, `title_key`, `steps: Array[QuestStep]`, `current_step: int`, `QuestStatus` enum |
| `QuestStep` | `src/domain/gameplay/quest_step.gd` | `kind: QuestStepKind`, `target_id`, `target_count`, `current_count`, `complete: bool` |
| `UpgradeCard` | `src/domain/combat/upgrade_card.gd` | XP level-up choice. `display_key`, `icon`, `effect_kind`, `effect_params: Dictionary` |

### Enums (extend `CompiledRule`)
- `TriggerKind`: add `ON_DIALOG_DONE`, `ON_QUEST_STEP`, `ON_LEVEL_UP`
- `ActionKind`: add `NPC_TALK`, `QUEST_START`, `QUEST_ADVANCE`, `QUEST_COMPLETE`, `GRANT_XP`

### Ports (outbound)
| Port | File | Purpose |
|---|---|---|
| `NpcDialogPort` | `src/ports/outbound/npc_dialog_port.gd` | `play_line(npc_id, line_id, context)` — wraps Dialogic |
| `QuestStorePort` | `src/ports/outbound/quest_store_port.gd` | `start_quest`, `advance_quest`, `complete_quest`, `get_active_quests` |
| `EnemyCatalogPort` | `src/ports/outbound/enemy_catalog_port.gd` | `list_archetypes()`, `definition_for(enemy_id)` — replaces static factories in EnemyDefinition (Adv 1 H3) |
| `BlockCatalogPort` | `src/ports/outbound/block_catalog_port.gd` | `kid_safe_kinds()`, `kind_for(block_id)` — replaces BlockKind.default_catalog static |
| `WaveDirectorPort` | `src/ports/outbound/wave_director_port.gd` | `next_wave(wave_number, seed) -> WaveConfig` |
| `InputDeviceTrackerPort` | `src/ports/outbound/input_device_tracker_port.gd` | `device_changed` signal; `current_device() -> Device` enum |

### Application services
| Service | File | Responsibility |
|---|---|---|
| `GameModeService` | `src/application/game_mode_service.gd` | Read `PlayerInventory.equipped_slot` → return `BUILD` or `COMBAT` mode enum. Used by PlayerController to route LMB. |
| `WaveDirectorService` | `src/application/wave_director_service.gd` | Consume `Array[WaveConfig]` from `data/waves/*.tres`. Seed `run_seed + wave_index` for reproducibility. Adv 1 H1 fix. |
| `GearProgressionService` | `src/application/gear_progression_service.gd` | Inventory + `Array[GearTierResource]` → next-tier eligibility. Adv 1 H1 fix. Drops `_weapon_tiers` literal from adapter. |
| `CombatService` | `src/application/combat_service.gd` | Damage compute (with `max_hp/3` cap moved here, per Adv 1 H2). |
| `XpProgressionService` | `src/application/xp_progression_service.gd` | `xp_required(level) = int(pow(level, 1.8) + level*4)`. Per-kill XP via `defeated` signal. Multi-level skip via `await popup.closed`. |
| `CraftingService` | `src/application/crafting_service.gd` | Validate all `RecipeResource.ingredients` resolve in `MaterialLibrary` on `_ready` — fail loud at world load, not silently mid-play. |
| `QuestService` | `src/application/quest_service.gd` | Wraps QuestStorePort. Forwards `quest_added/advanced/completed` events to rules engine. |

### Adapters
| Adapter | File | Notes |
|---|---|---|
| `DialogicNpcDialogAdapter` | `src/adapters/outbound/dialogic_npc_dialog_adapter.gd` | Wraps Dialogic 2. Adapter-init swaps Text events for Portrait+Audio (kid-safety: no text rendering). |
| `QuestifyQuestStoreAdapter` | `src/adapters/outbound/questify_quest_store_adapter.gd` | Handles `condition_query_requested(type, key, value, requester)` → reads from existing `_context` dict, calls `requester.set_completed(true)`. |
| `StaticEnemyCatalogAdapter` | `src/adapters/outbound/static_enemy_catalog_adapter.gd` | Loads `data/enemies/*.tres`. |
| `StaticBlockCatalogAdapter` | `src/adapters/outbound/static_block_catalog_adapter.gd` | Loads `data/blocks/*.tres` + curated kid_safe_allowlist.txt (Adv 5 review). |
| `ResourceWaveDirectorAdapter` | `src/adapters/outbound/resource_wave_director_adapter.gd` | Loads `data/waves/*.tres`. RNG seeded by run_seed + wave_index. |
| `GodotInputDeviceTrackerAdapter` | `src/adapters/inbound/shared/godot_input_device_tracker.gd` | Autoload. Subscribes `Input.joy_connection_changed` + reads `InputEvent` types in `_input` to infer device. Emits `device_changed`. |

### Scenes / nodes
| Scene | Notes |
|---|---|
| `src/adapters/inbound/gameplay/hitbox_hurtbox/hit_area_3d.gd` + `hurt_area_3d.gd` | Typed Area3D pair per gdquest pattern. `damage: int`, `knockback_strength: float` exports. |
| `src/adapters/inbound/gameplay/hotbar/hotbar_slot.tscn` | PanelContainer 80×80 → TextureRect → SubViewport(128, transparent) → Camera3D + BoxMesh. `update_mode = UPDATE_ONCE` per icon. |
| `src/adapters/inbound/gameplay/hud/crosshair.tscn` | CanvasLayer → CenterContainer FULL_RECT → TextureRect 16×16. |
| `src/adapters/inbound/gameplay/ghost_preview.tscn` | Node3D under Player. MeshInstance3D with semi-transparent BoxMesh, shown on raycast hit snapped to grid. |
| `src/adapters/inbound/gameplay/hud/control_hint_overlay.tscn` | RichTextLabel with BBCode `[img]` glyphs per device (Kenney Input Prompts CC0). Listens to `InputDeviceTracker.device_changed`. |
| `src/adapters/inbound/gameplay/hud/level_up_popup.tscn` | 3 `UpgradeCard` choice buttons, `PROCESS_MODE_WHEN_PAUSED`. Pauses tree until kid picks. |
| `src/adapters/inbound/gameplay/hud/speech_bubble.tscn` | NPC portrait + reaction icon. No text. `VoicePromptPort` audio cue. Auto-clear 2.5s. |
| `addons/dialogic/` | Drop-in MIT plugin, fork text events to Portrait+Audio at adapter init. |
| `addons/gloot/` | Drop-in MIT plugin for inventory grid + serialize/deserialize. |
| `addons/virtual_joystick/` | MarcoFazioRandom MIT for touch. `use_input_actions=true` fires `move_*` directly. |

### Project settings + autoloads
- New autoload: `InputDeviceTracker` (singleton).
- New ProjectSetting: `controls/keybinds_path = "user://keybinds.cfg"`.
- Bind global `.theme` via `gui/theme/custom = "res://data/ui/choyce.theme"`.
- Bind Kenney Input Prompts CC0 atlas at `gui/icons/input_prompts_kbm/xbox/ps`.

---

## Hex-arch verdict (Adv 1 follow-up)

This synthesis closes Adv 1's three H-rank findings:
- **H1 (services extracted)**: `GearProgressionService`, `WaveDirectorService`, `CombatService` move policy out of `gameplay_runtime.gd` adapter.
- **H2 (damage cap in service)**: `CombatService.compute_damage` owns the kid-safe cap; `HealthState.apply_damage` becomes raw mechanical primitive.
- **H3 (catalog ports)**: `EnemyCatalogPort` + `BlockCatalogPort` replace `static func slime_green()` factories in domain. Domain stays pure spec; adapters serve concrete data from `.tres` files.

---

## Sequenced wave plan

### Wave NEXT (~2 days solo / ~1 day /batch)
**Theme: hot-fix race + start mode-aware controls + ghost preview**

1. **HOTFIX**: replace `set_deferred("monitoring", false)` with `_already_collected` boolean in `loot_pickup.gd`. Audit `enemy_controller._on_defeat` for same race class on the collision disable. (S, ½ day)
2. `GameModeService` + LMB dispatch in PlayerController. (S, ½ day)
3. Crosshair + ghost-preview Node3D under Player. Show on raycast hit snapped to grid. (S, ½ day)
4. HitArea3D / HurtArea3D typed split — replace duck-typed `apply_damage_from_enemy`. (M, 1 day)
5. AnimationTree Method Call Track for sword hitbox enable/disable. (M, 1 day)

### Wave NEXT+1 (~3 days solo / ~2 days /batch)
**Theme: Resource-ify data + service extraction + SubViewport icons**

1. Migrate `EnemyDefinition.loot_table` → `Array[LootEntry] .tres`. Use `sempitern0/Lootie` if license permits or roll equivalent. (M, 1 day)
2. Migrate `_weapon_tiers` literal → `Array[GearTierResource]` `.tres` files. Extract `GearProgressionService`. (M, 1 day)
3. Migrate `_spawn_next_wave` body → `WaveDirectorService` + `Array[WaveConfig] .tres`. Adv 1 H1 close. (M, 1 day)
4. SubViewport cube-icon hotbar slot scene. UPDATE_ONCE + ImageTexture cache by kind_id. (M, 1 day)
5. CombatService `compute_damage` with kid-safe cap. HealthState simplified. (S, ½ day)

### Wave NEXT+2 (~3 days)
**Theme: NPCs + quests + dopamine**

1. Dialogic 2 addon drop-in + text-stripped fork at adapter init. NpcDialogPort + adapter. (M, 1 day)
2. Quest domain + Questify addon adapter. QuestStorePort. (M, 1 day)
3. SpeechBubble HUD + audio-only NPC interactions. (S, ½ day)
4. XP curve + level-up popup with 3 UpgradeCards. (M, 1 day)

### Wave NEXT+3 (~2 days)
**Theme: input device adaptation + touch + rebind UI**

1. `InputDeviceTracker` autoload + `device_changed` signal. (S, ½ day)
2. Adaptive HUD hint overlay swapping Kenney glyphs. (S, ½ day)
3. MarcoFazioRandom virtual joystick + tablet layout. (S, ½ day)
4. Rebind UI in parent zone Controls tab. (M, 1 day)

---

## Skipped / deferred (and why)

- **LimboAI**: full BT for waves + NPCs. Drop-in C++ GDExtension. Worth it once enemy variety > 3 archetypes AND multiple NPC roles need branching idle behavior. Defer until WaveNext+2 minimum.
- **G.U.I.D.E plugin**: heavyweight input system. Roll the `InputDeviceTracker` autoload first; reach for G.U.I.D.E only if rebind UX needs more sophistication.
- **Brotato code**: Godot 3.5 proprietary + addressed in research but not directly portable. Pattern-only lift.
- **Cruelty Squad**: closed source + violence misaligned with kid-safe constraint. Style only.
- **Roblox-spring-arm with mouse capture**: existing RMB-drag without capture is fine for desktop. Reconsider when touch UX requires camera-anywhere.

---

## Open questions for next session

1. **Asset licensing audit**: which plugins commit to repo vs git submodule? Both Dialogic and GLoot are MIT — committing is fine; submodule keeps upstream syncable.
2. **`.tres` editing UX for parents**: parent zone needs a UI to edit `WaveConfig.tres` + `GearTierResource.tres` from inside the game (without crashing Godot editor). Or do we ship game + editor split?
3. **Multi-language quest text**: Dialogic 2 supports CSV translation. Verify pipeline integrates with existing `LocalizationPolicyPort` + Polish-first defaults.
4. **Save format migration**: if we ship Resource-ified loot/gear/waves and a kid has played the old version, do `SessionProgressStorePort` saves migrate cleanly? Greenfield wipe is the policy per memory but verify.

---

## References

See per-axis docs:
- `thoughts/shared/research/godot-combat-patterns-2026-05-19.md`
- `thoughts/shared/research/godot-quest-npc-patterns-2026-05-19.md`
- `thoughts/shared/research/godot-ui-patterns-2026-05-19.md`
- `thoughts/shared/research/godot-procedural-patterns-2026-05-19.md`
- `thoughts/shared/research/godot-input-patterns-2026-05-19.md`

Key external sources consolidated:
- [gdquest-demos/godot-4-hitbox-hurtbox](https://github.com/gdquest-demos/godot-4-hitbox-hurtbox)
- [gdquest-demos/godot-4-juicy-attack](https://github.com/gdquest-demos/godot-4-juicy-attack)
- [Zylann/voxelgame](https://github.com/Zylann/voxelgame)
- [peter-kish/gloot](https://github.com/peter-kish/gloot)
- [sempitern0/Lootie](https://github.com/sempitern0/Lootie)
- [dialogic-godot/dialogic](https://github.com/dialogic-godot/dialogic)
- [shomykohai/quest-system](https://github.com/shomykohai/quest-system)
- [TheWalruzz/godot-questify](https://github.com/TheWalruzz/godot-questify)
- [MarcoFazioRandom/Virtual-Joystick-Godot](https://github.com/MarcoFazioRandom/Virtual-Joystick-Godot)
- [godotneers/G.U.I.D.E](https://godotneers.github.io/G.U.I.D.E/)
- [limbonaut/limboai](https://github.com/limbonaut/limboai)
- [Dre Dyson — Godot 4.6.2 hurtbox race fix](https://dredyson.com/fix-duplicate-hit-detection-in-godot-4-6-2-area3d-hurt-hit-boxes-a-beginners-step-by-step-guide-to-resolving-race-conditions-collisionshape3d-vs-area3d-disabling-and-blacklist-dictionary-workarou/)
