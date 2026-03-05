# GitHub Copilot Execution Prompt — Wave 3–4 Tasks

## Context
TASK-001 is complete. The domain model is defined in `src/domain/` with 5 bounded contexts, all as framework-agnostic GDScript classes extending `RefCounted`.

Read these before starting:
- `src/ARCHITECTURE.md` — hexagonal rules and port patterns
- `src/domain/CONTEXT_MAP.md` — bounded context boundaries
- `.github/copilot-instructions.md` — your operating rules

**Your tasks are blocked until Wave 2 completes.** Use this prompt to prepare once prerequisites are met.

---

## TASK-008: Build Godot inbound adapters for create, play, and parent dashboard surfaces
**Blocked by: TASK-002 (inbound ports — claude), TASK-007 (utility adapters — codex)**

### Objective
Create Godot scene shells that call inbound use-case ports without leaking domain concerns into UI scenes. These are the first files that depend on Godot's Node system.

### Shells to create
| Shell | Scene file | Script | Purpose |
|---|---|---|---|
| Create Mode | `scenes/create/create_shell.tscn` | `create_shell.gd` | Template picker → canvas → logic editor → playtest |
| Play Mode | `scenes/play/play_shell.tscn` | `play_shell.gd` | World list → active session → progress |
| Family Library | `scenes/library/library_shell.tscn` | `library_shell.gd` | Published worlds → details → play |
| Parent Zone | `scenes/parent/parent_zone_shell.tscn` | `parent_zone_shell.gd` | Safety → limits → policy → publish |

### Architecture rules
1. Shell scripts extend `Control` or `Node` (adapter layer — Godot dependency is expected here)
2. Shells receive port references via dependency injection (constructor or `setup()` method), never instantiate domain types directly
3. UI → port calls only. No domain logic in shell scripts.
4. Navigation between shells via a simple scene manager (can be an autoload)

### Key domain types to reference
- `PlayerProfile` (Role.KID vs Role.PARENT determines which shells are accessible)
- `Project`, `World` (displayed in Create/Library shells)
- `Session` (created when entering Play mode)

### Acceptance criteria
- Godot adapters call inbound ports without leaking domain concerns into UI scenes
- Create, Play, Family Library, and Parent Zone shells are navigable
- Kid mode hides Parent Zone (gated by profile role)

### Files to create
```
src/adapters/inbound/
├── scenes/
│   ├── create/create_shell.tscn + create_shell.gd
│   ├── play/play_shell.tscn + play_shell.gd
│   ├── library/library_shell.tscn + library_shell.gd
│   └── parent/parent_zone_shell.tscn + parent_zone_shell.gd
├── navigation/
│   └── shell_navigator.gd
└── main.tscn + main.gd
```

### UI/UX constraints (from ui-ux-requirements.md)
- 44px minimum touch targets (UX-001)
- Color + icon + shape redundancy (UX-002)
- Always-visible undo control (UX-003)
- Polish text labels from localization port (UX-LANG-001)

---

## TASK-020: Build localized starter templates and theme palette selection
**Blocked by: TASK-009 (template pack loader — mistral)**

### Objective
Create the 5 starter template data packs and a theme palette picker.

### Templates to create (from FR-001)
| Template | Description | Theme |
|---|---|---|
| Tycoon | Build-and-earn loop with shop, upgrades, customers | Business/city |
| Obby-lite | Simple obstacle course with checkpoints | Colorful/arcade |
| Farm | Plant, grow, harvest, sell cycle | Nature/pastoral |
| City | Place buildings, roads, zones, manage resources | Urban/modern |
| Adventure Island | Explore, collect, solve puzzles | Tropical/fantasy |

### Requirements
- Each template is a data pack (JSON + default assets), not hardcoded logic
- Template packs load through the template loader from TASK-009
- All template text (names, descriptions, onboarding hints, quest text) must be in Polish (FR-031)
- Theme palettes: each template ships with a default color palette + 2-3 alternatives

### Files to create
```
data/templates/
├── tycoon/template.json + assets/
├── obby/template.json + assets/
├── farm/template.json + assets/
├── city/template.json + assets/
└── adventure/template.json + assets/
data/themes/
├── palettes.json
```

### Acceptance criteria
- 5 starter templates available and loadable
- Template text and onboarding hints are QA-verified in Polish
- Theme palette selection works with at least 3 palettes per template

---

## TASK-021: Implement kid-mode build canvas tools with touch-friendly controls
**Blocked by: TASK-008 (Godot adapters), TASK-020 (templates)**

### Objective
Implement the core creation tools: place, paint, move, duplicate — all with 44px+ targets and clear visual feedback.

### Tools to implement
| Tool | Action | Key UX |
|---|---|---|
| Place | Add object from palette to world | Drag from panel, snap to grid |
| Paint | Apply material/color to terrain/object | Brush size selector, undo per stroke |
| Move | Reposition object in 3D space | Handle gizmo, constrain to axis |
| Duplicate | Clone selected object | One-tap duplicate, offset placement |

### Requirements
- Tools call `ApplyWorldEditCommand` inbound port (from TASK-002)
- Each tool operation emits a `WorldEditedEvent` with previous/new state
- Undo/safe restore controls always visible (UX-003)
- Minimum target sizes: 44px (UX-001)
- Visual cues: color + icon + shape redundancy (UX-002)
- Polish labels for all tool names and tooltips

### Acceptance criteria
- Place, paint, move, and duplicate tools support minimum target sizes and clear visual cues
- Undo and safe restore controls remain always accessible

---

## TASK-031: Implement Polish-first UI localization pipeline and glossary constraints
**Blocked by: TASK-008 (Godot adapters), TASK-020 (templates)**

### Objective
Set up the localization pipeline so all UI strings default to `pl-PL`.

### Requirements (from TR-L10N-001, TR-L10N-005)
- Use Godot's built-in localization system (`.po` or `.csv` translation files)
- Default locale: `pl-PL`
- Glossary file enforcing child-safe Polish wording
- Parent mode uses technical Polish terminology consistently
- All navigation labels, dialog text, tooltips, and error messages in Polish

### Files to create
```
localization/
├── pl_PL.po (or .csv)
├── glossary_kid.json    # child-safe term constraints
├── glossary_parent.json # technical terminology
└── README.md            # localization contributor guide
```

### Acceptance criteria
- Child and parent interfaces default to pl-PL strings
- Localization glossary enforces child-safe wording and parent technical terminology consistency

---

## Execution order
```
TASK-008 (after TASK-002 + TASK-007)
    ├── TASK-020 (after TASK-009)
    │   ├── TASK-021 (after TASK-008 + TASK-020)
    │   └── TASK-031 (after TASK-008 + TASK-020)
```

## Cross-review
- TASK-008 reviewed by: claude
- TASK-020 reviewed by: codex
- TASK-021 reviewed by: codex
- TASK-031 reviewed by: codex

Submit each task as a separate PR for focused review.
