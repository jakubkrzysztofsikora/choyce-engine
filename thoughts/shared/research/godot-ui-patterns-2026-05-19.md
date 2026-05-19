# Godot UI/HUD/Inventory Patterns for choyce-engine
_Research date: 2026-05-19 | Target: Polish-locale, 7-year-old player_

---

## 1. Inventory Plugins

### GLoot — peter-kish/gloot
- **URL**: https://github.com/peter-kish/gloot
- **License**: MIT | **Stars**: 922
- **Key files**: `addons/gloot/` — `InventoryItem`, `ItemSlot`, `CtrlItemSlot`, `CtrlInventoryGrid`
- `InventoryItem` is an inherent stack (stack_size + max_stack_size). No native hotbar class; build one from 8x `ItemSlot` nodes in an `HBoxContainer`.
- **choyce-engine fit**: Replace current 5 `ColorRect` tiles with 8x `CtrlItemSlot`. Connect `serialize()`/`deserialize()` to the hexagonal `SessionProgressStorePort` for persistence.
- **Kid fit**: `CtrlItemSlot` renders item icon via `InventoryItem.properties[icon]`; swap for SubViewport texture (see section 5). Touch target: set `custom_minimum_size = Vector2(80, 80)` — above 48dp floor.

### expressobits/inventory-system
- **URL**: https://github.com/expressobits/inventory-system
- **License**: MIT | **Stars**: 716
- **Key files**: C++ GDExtension (addon branch); hotbar, stacks, crafting all supported.
- **choyce-engine fit**: Heavier than needed — skip unless crafting recipes required later. Hotbar logic in pure GDScript (GLoot) is easier to sandbox.
- **Kid fit**: Same as GLoot; icon rendering is caller responsibility.

### arkeve/Godot-Inventory-System
- **URL**: https://github.com/arkeve/Godot-Inventory-System
- **License**: unlicensed | **Stars**: 56
- **Key files**: `Hotbar.gd`, `Hotbar.tscn`, `Inventory.gd`, `Item.gd`
- Compact pure-GDScript reference showing hotbar scroll (mouse wheel) and drag-drop between hotbar and inventory grid.
- **choyce-engine fit**: Reference `Hotbar.gd` for mouse-wheel slot selection pattern; port to our hexagonal `ManageProgressionPort` signal.
- **Kid fit**: Minimal; needs 9-slice StyleBox and icon upgrade.

---

## 2. GDQuest UI Demos

- **URL**: https://github.com/gdquest-demos
- **License**: MIT
- Theme editor guidance: `StyleBoxTexture` with 9-slice = cartoony panels without bespoke art. `StyleBoxFlat` with large `corner_radius` = pill buttons. Custom type variations let us register a `ButtonLarge` theme type with `custom_minimum_size = Vector2(96, 96)` globally.
- **choyce-engine fit**: Define one `.theme` resource with `ButtonLarge`, `HotbarSlot`, `HUDLabel` type variations. Load via `ProjectSettings` so all shells share it without per-scene overrides.
- **Kid fit**: Rounded corners + high `content_margin_*` (>=16 px) reduces mis-tap. Keep text >= 20 pt; Polish diacritics (a e o s z) render fine in Noto Sans — already used via `_t()`.

---

## 3. Dome Keeper / Brotato HUD Lessons

Neither is open source, but community analysis surfaces two transferable patterns:

1. **Minimal base HUD, no stat dumps**: Brotato hides per-wave stats during combat; Dome Keeper gates HUD upgrades behind economy. For a 7-year-old, show only: hotbar + HP bar + back button. No number spam.
2. **Delta readout over absolute values**: Brotato's 'What's new' mode shows only changed stats. Choyce equivalent: briefly animate the slot that just changed (tween scale 1 > 1.2 > 1) rather than always-visible counters.

---

## 4. Brotato Auto-Attack HUD (inspiration only)

- Wave counter as primary pacing clock.
- Level-up choice cards: large, icon-first, 2-3 options max. Useful model for the 'remiksuj swiat' choice screen — keep to 3 options with big icons.

---

## 5. SubViewport Cube-Icon Rendering

**Source**: https://docs.godotengine.org/en/4.4/tutorials/shaders/using_viewport_as_texture.html

Pattern (per slot):

    HotbarSlot (PanelContainer, custom_minimum_size = 80x80)
    └── TextureRect             <- texture = ViewportTexture -> SubViewport
        └── SubViewport         <- size 128x128, transparent_bg = true, update_mode = ONCE
            ├── Camera3D        <- current = true, orthographic, framed on cube
            ├── DirectionalLight3D
            └── MeshInstance3D  <- BoxMesh, material albedo = kind.color

Set `update_mode = UPDATE_ONCE` after item assigned; `UPDATE_NEVER` otherwise. Cost: one extra viewport per unique mesh — cache with a `Dictionary[kind_id -> ImageTexture]` (bounded to MAX_KINDS, evict LRU).

**choyce-engine fit**: Swap each `ColorRect` for this pattern. `kind.color` already on domain model. Add `kind.mesh_path: String` to `WorldKind` resource.

---

## 6. Theme + StyleBox Kid-Friendly

| Requirement | Godot impl |
|---|---|
| Touch target >= 80x80 px | `custom_minimum_size` on all interactive nodes |
| Spacing >= 32 px between slots | `separation` theme override on HBox/VBox |
| Rounded corners | `StyleBoxFlat.corner_radius_*` = 12-16 |
| Soft drop shadow | `StyleBoxFlat.shadow_color` alpha = 0.3, `shadow_size` = 4 |
| Polish text | Noto Sans (diacritics), size >= 20 pt |
| No sensory overload | Calm palette, single tween at a time, no flashing |

Sources: Toca Boca design process (motionographer.com), Android 48dp floor (logrocket.com), GDQuest StyleBox guide (school.gdquest.com).

---

## 7. Crosshair + Ghost Block Preview

**Source**: https://github.com/Zylann/voxelgame (MIT, 736 stars) — `project/blocky_game/main.tscn`

Pattern:
1. Raycast from `Camera3D` each `_physics_process`; snap hit position to voxel grid.
2. Show semi-transparent `MeshInstance3D` (BoxMesh, same `kind.color` + alpha 0.4) at snapped position.
3. Crosshair: `CenterContainer > TextureRect` with a 16x16 crosshair PNG, anchored to screen center in a CanvasLayer.
4. Hide ghost when no raycast hit or when moderation blocks action.

**choyce-engine fit**: Wire ghost preview visibility through `ports_ready` gate (already used for voice/AI in Wave B Phase 8d). Disable placement entirely when `ParentalPolicyStore.get_policy().build_allowed == false`.

---

## Top 5 Patterns to Implement

| # | Pattern | Source | Priority |
|---|---|---|---|
| 1 | SubViewport cube-icon per hotbar slot | Godot docs / voxelgame | High — replaces flat ColorRect |
| 2 | GLoot CtrlItemSlot x8 + mouse-wheel select | peter-kish/gloot | High — 8-slot + Minecraft rebind |
| 3 | Crosshair CenterContainer + ghost BoxMesh | Zylann/voxelgame | High — core UX missing |
| 4 | Global .theme with HotbarSlot + ButtonLarge type variations | GDQuest / Godot docs | Medium — consistency across shells |
| 5 | Delta-tween on slot change (no stat dump) | Brotato pattern | Medium — kid cognitive load |

---

## Proposed HUD Scene Graph

    HUD (CanvasLayer, layer = 10)
    |
    +-- CrosshairOverlay (CenterContainer, anchor FULL_RECT)
    |   └── TextureRect  <- crosshair.svg 16x16, modulate white
    |
    +-- TopBar (HBoxContainer, anchor TOP_FULL)
    |   +-- BackButton (Button, custom_min 80x80)  <- top-left
    |   └── HPBar (TextureProgressBar, anchor top-right, min_size 200x32)
    |
    +-- Hotbar (HBoxContainer, anchor BOTTOM_CENTER)
    |   └── HotbarSlot x8 (PanelContainer 80x80 each, separation 8)
    |       └── TextureRect <- ViewportTexture (SubViewport cube icon)
    |
    └── InventoryPanel (VBoxContainer, anchor BOTTOM_LEFT, visible = false)
        └── [toggled by inventory key / parental gate]

Ghost preview lives in the 3D scene tree (Node3D child of Player), not in CanvasLayer.

---

## Sources

1. [peter-kish/gloot](https://github.com/peter-kish/gloot) — MIT, 922 stars, universal inventory + ItemSlot
2. [expressobits/inventory-system](https://github.com/expressobits/inventory-system) — MIT, 716 stars, C++ hotbar/stack/craft
3. [arkeve/Godot-Inventory-System](https://github.com/arkeve/Godot-Inventory-System) — 56 stars, Hotbar.gd drag-drop reference
4. [jlucaso1/drag-drop-inventory](https://github.com/jlucaso1/drag-drop-inventory) — Godot 4 drag-drop slots
5. [Zylann/voxelgame](https://github.com/Zylann/voxelgame) — MIT, 736 stars, blocky_game crosshair + placement
6. [gdquest-demos org](https://github.com/gdquest-demos) — MIT, theme/StyleBox tutorials
7. [Godot SubViewport docs](https://docs.godotengine.org/en/4.4/tutorials/shaders/using_viewport_as_texture.html) — cube-icon rendering
8. [GameDev Academy SubViewport guide](https://gamedevacademy.org/subviewport-in-godot-complete-guide/) — 3D mesh to TextureRect workflow
9. [LogRocket touch target sizes](https://blog.logrocket.com/ux-design/all-accessible-touch-target-sizes/) — 48dp floor, kids need 80-96dp
10. [Toca Boca design process](https://motionographer.com/2016/04/27/the-design-process-behind-toca-bocas-infectious-apps/) — minimal choices, rounded warmth
11. [Designing for Kids UX](https://www.ungrammary.com/post/designing-for-kids-ux-design-tips-for-children-apps) — sensory balance, no fail states
12. [Brotato MoreUI mod](https://github.com/JNBG/Brotato-MoreUI) — delta-readout / wave-start diff pattern
