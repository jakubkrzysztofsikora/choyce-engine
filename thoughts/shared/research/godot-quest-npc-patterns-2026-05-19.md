# Godot Quest + NPC + Dialog Patterns Research
_2026-05-19 - Architecture & Review Specialist_

## Sources Evaluated

| # | Project | License | Godot 4? |
|---|---------|---------|---------|
| 1 | [Dialogic](https://github.com/dialogic-godot/dialogic) | MIT | Yes (4.3+) |
| 2 | [QuestSystem shomykohai](https://github.com/shomykohai/quest-system) | MIT | Yes (4.4+) |
| 3 | [Questify TheWalruzz](https://github.com/TheWalruzz/godot-questify) | MIT | Yes (4.4+) |
| 4 | [GDQuest Open RPG](https://github.com/gdquest-demos/godot-open-rpg) | MIT | Yes (4.6) |
| 5 | HeartBeast integer-state dialog | N/A tutorial | Yes |
| 6 | Tunic symbol+audio UX GDC 2023 | N/A postmortem | N/A |
| 7 | For The King II / Kingdoms of Dump | Closed source | No postmortem found |

---

## Per-Source Findings

### 1. Dialogic 2

Key runtime signals from DialogicGameHandler autoload:
- `timeline_ended` - fired when a .dtl timeline finishes; main hook for gameplay
- `Subsystem_Choices.choice_made(choice_index)` - fires on branching choice
- `Subsystem_Variables.variable_changed(var_name, old, new)` - track story flags

Branching model: Visual node-based .dtl files. Condition branches read Dialogic variables across timelines in the same session.

Kid-safe adaptation:
- Strip Text events; replace with Portrait + Audio events only (Tunic-style icon+sound)
- Disable typewriter text-scroll (speed=0, show icon immediately)
- Modular subsystem architecture makes stripping surgical

Integration hook:
```gdscript
Dialogic.start("res://dialog/npc_farmer.dtl")
Dialogic.timeline_ended.connect(_on_dialog_done, CONNECT_ONE_SHOT)
```

---

### 2. QuestSystem (shomykohai) - resource-driven

Manager API (autoload QuestSystem):
```gdscript
QuestSystem.add_quest(my_quest)     # activates
QuestSystem.advance_quest(my_quest) # move to next step
QuestSystem.complete_quest(my_quest)
```

Signals: `quest_added`, `quest_advanced`, `quest_completed` - carry the quest resource.

Integration fit: Strong. quest_id maps cleanly to _context["quest"] dict already in GodotRulesRuntimeAdapter.

---

### 3. Questify (TheWalruzz) - graph-based

Signals:
```
quest_started(quest)
quest_objective_added(quest, objective)
quest_objective_completed(quest, objective)
quest_completed(quest)
```

Query system: `condition_query_requested(type, key, value, requester)` - architecture-agnostic.
Game answers with `requester.set_completed(true/false)`. Maps to existing on_event() in GodotRulesRuntimeAdapter.

Serialization: Questify.serialize() / deserialize() - plugs into FilesystemPublishStore flush cycle.

Verdict: More complex than QuestSystem but graph editor is excellent for non-programmer parents designing quests.

---

### 4. GDQuest Open RPG

Uses Dialogic 2 for NPC dialog. NPC dialog triggered by Area3D proximity - same pattern as _on_trigger_area_entered.
Pattern worth porting: Area3D proximity -> timeline start -> timeline_ended -> rules event.

---

### 5. HeartBeast integer-state dialog

```gdscript
var dialog_state: int = 0 :
    set(v):
        dialog_state = v
        _refresh_bubble()

func _refresh_bubble():
    match dialog_state:
        0: show_icon("question_mark"); speak("npc_greeting")
        1: show_icon("thumbs_up");     speak("npc_accept")
        2: quest_accepted = true;      emit_signal("quest_given")
```

Strength: Zero external dependency. Trivially auditable. Works offline.
Use for: Tutorial guide mascot or single-step farm NPC quest.

---

### 6. Tunic symbol+audio UX (GDC 2023)

Designer Andrew Shouldice: glyphs evoke being pre-literate.
Audio designer Kevin Regamey: pentatonic arpeggio note clusters unique per NPC character.

Pattern for age-7 non-readers:
- Replace text with icon sprites + color coding
- Each NPC speaks via a short audio cue unique to that character
- Progress shown via icon sequences, not strings
- Fits VoicePromptPort fire-and-forget model already in choyce-engine
- Kid-safety bonus: no text = no text moderation needed

---

### 7. For The King II / Kingdoms of Dump

No public postmortems or open NPC/quest code found. Not actionable.

---

## Top 5 Portable Patterns

### P-1: Area3D trigger_type=npc -> NPC_TALK ActionKind
Reuse existing _on_trigger_area_entered path. Map trigger_type="npc" to new ActionKind.NPC_TALK.
GameplayRuntime reads area.get_meta("npc_id") and starts Dialogic timeline.

### P-2: Dialogic timeline_ended -> on_event(dialog_done, {npc_id, outcome})
Feed outcome back to rules engine. Enables: on_dialog_done_farmer:quest_start("harvest_quest")

### P-3: Questify condition_query_requested bridged to GodotRulesRuntimeAdapter
Answer inventory/score conditions from _context dict. Keeps quest conditions DRY with existing tracking.

### P-4: Quest domain RefCounted (framework-isolated)
```gdscript
class_name Quest extends RefCounted
var quest_id: String
var title_key: String     # i18n key, never raw string
var steps: Array[String]  # step_id list
var current_step: int = 0
enum QuestStatus { INACTIVE, ACTIVE, COMPLETED, FAILED }
var status: QuestStatus = QuestStatus.INACTIVE
```
No Node, no Resource - pure domain type per hex-arch constraints.

### P-5: Icon-only speech bubble HUD (Tunic pattern)
SpeechBubble CanvasLayer inside _build_hud(). Shows NPC portrait icon + reaction icon.
Plays VoicePromptPort audio cue. No text rendered. Clears after 2.5s or on input.

---

## Concrete Implementation Plan

### New ActionKinds (add to compiled_rule.gd)
```gdscript
NPC_TALK,       ## params: npc_id: String, timeline: String
QUEST_START,    ## params: quest_id: String
QUEST_ADVANCE,  ## params: quest_id: String, step_id: String
QUEST_COMPLETE, ## params: quest_id: String
```

### New TriggerKinds (add to compiled_rule.gd)
```gdscript
ON_DIALOG_DONE,  ## params: npc_id: String, outcome: String
ON_QUEST_STEP,   ## params: quest_id: String, step_id: String
```

### New domain type: src/domain/gameplay/quest.gd
Pure RefCounted as in P-4.

### New outbound port: src/ports/outbound/npc_dialog_port.gd
```gdscript
class_name NpcDialogPort extends RefCounted
func start_dialog(npc_id: String, timeline_path: String) -> void: pass
signal dialog_ended(npc_id: String, outcome: String)
```

### New outbound port: src/ports/outbound/quest_store_port.gd
```gdscript
class_name QuestStorePort extends RefCounted
func save_quest(quest: Quest) -> void: pass
func load_quest(quest_id: String) -> Quest: pass
func list_active() -> Array[Quest]: pass
```

### New adapter: src/adapters/outbound/dialogic_npc_dialog_adapter.gd
Wraps Dialogic. Translates Dialogic.timeline_ended to NpcDialogPort.dialog_ended.
Strips Text events at timeline load for kid-safe mode.

### HUD addition: SpeechBubble inside _build_hud()
Listens to NpcDialogPort.dialog_ended. Shows icon + plays VoicePromptPort cue. Zero text.

### DSL examples
```
on_reach_npc_farmer:npc_talk('farmer','farmer_intro.dtl')
on_dialog_done_farmer:quest_start('harvest_quest')
on_collect_carrot_10:quest_advance('harvest_quest','done')
on_quest_complete_harvest_quest:win_level()
```

---

## Risk Notes

- Dialogic 2 requires Godot 4.3+. Verify project target version before adding.
- Questify graph editor is Godot 4.4+ only. For 4.3 use QuestSystem v1.x branch.
- Text-strip must be enforced at adapter init, not runtime.
- dialog_ended outcome string must pass through VoiceInputModerationService if it feeds AI input pipeline.
- Questify and QuestSystem autoloads conflict if both imported - pick one.
