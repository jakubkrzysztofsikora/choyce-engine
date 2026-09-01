# Sandbox Village Presentation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the live Piaskownica sandbox read as an authored, textured Choyce village clearing rather than a sparse procedural test field.

**Architecture:** Keep rpg-asserts mechanics and Choyce persistence untouched. `SandboxLevel` owns named visual composition and a local asset-material application helper; `PropFactory` mounts ready local assets below unchanged sandbox physics/component roots. The GPU render audit is the rendering proof path.

**Tech Stack:** Godot 4.6, GDScript, committed Kenney/Quaternius model packs, existing Choyce shaders, SandboxKitBridge, GPU SubViewport render audit.

**Spec:** `docs/superpowers/specs/2026-09-01-sandbox-village-presentation-design.md`

## Global Constraints

- Preserve SandboxKitBridge as the sole Choyce save/event boundary.
- Do not alter player/block caps, input routing, build persistence, grab/throw, or component contracts.
- Use committed local assets only; no remote, generated, pirate-themed, AI, chat, or network content.
- Keep the authored visual presentation inside Godot inbound adapters.
- Do not claim readiness without a GPU-backed frame inspection and the Kit E2E suite.

---

### Task 1: Texture-Safe Village Assets

**Files:**
- Modify: `levels/sandbox_level.gd`
- Test: `tests/gameplay/test_sandbox_art_assets.gd`

**Interfaces:**
- Consumes: imported `PackedScene` assets and `StandardMaterial3D` source materials.
- Produces: `_add_imported_visual(...) -> Node3D` whose mesh descendants preserve an albedo texture or receive a restrained named fallback material.

- [x] **Step 1: Write a failing material-mount regression.**

```gdscript
var cottage := level.get_node_or_null("VillageLand/VillageHouses/WillowCottage")
_check(cottage != null and _has_readable_material(cottage),
    "Village house receives a textured or warm fallback material")
```

- [x] **Step 2: Run it and confirm failure on the pale imported meshes.**

Run: `godot --headless --path . --script tests/gameplay/test_sandbox_art_assets.gd`

- [x] **Step 3: Add a local material traversal; do not import `WorldRenderer`.**

```gdscript
func _apply_village_materials(root: Node, fallback: Color) -> void:
    for node in root.find_children("*", "MeshInstance3D", true, false):
        var mesh := node as MeshInstance3D
        var source := mesh.get_active_material(0) as StandardMaterial3D
        if source != null and source.albedo_texture != null:
            continue
        var material := StandardMaterial3D.new()
        material.albedo_color = fallback
        material.roughness = 0.78
        mesh.material_override = material
```

Call it from `_add_imported_visual` using wood, stone, or foliage fallbacks chosen by node name.

- [x] **Step 4: Re-run the focused art test.**

Run: `godot --headless --path . --script tests/gameplay/test_sandbox_art_assets.gd`

- [ ] **Step 5: Commit.**

```sh
git add levels/sandbox_level.gd tests/gameplay/test_sandbox_art_assets.gd
git commit -m "feat: style sandbox village assets"
```

### Task 2: Authored Starter Clearing

**Files:**
- Modify: `levels/sandbox_level.gd`
- Test: `tests/gameplay/test_sandbox_art_assets.gd`

**Interfaces:**
- Consumes: the Task 1 styled asset mount and existing `PropFactory` bodies.
- Produces: `VillageLand/StarterClearing`, `VillageLand/MeadowPath`, `VillageLand/StarterProps`, and `VillageLand/Woodland` groups.

- [x] **Step 1: Add failing named-composition assertions.**

```gdscript
_check(level.get_node_or_null("VillageLand/StarterClearing") != null,
    "Sandbox level provides an authored starter clearing")
_check(level.get_node_or_null("VillageLand/MeadowPath") != null,
    "Sandbox level provides a visible path through the clearing")
_check(level.get_node_or_null("VillageLand/StarterProps") != null
    and level.get_node_or_null("VillageLand/StarterProps").get_child_count() >= 4,
    "Sandbox level groups bounded starter props near the village")
```

- [x] **Step 2: Run the focused regression and confirm the groups are absent.**

Run: `godot --headless --path . --script tests/gameplay/test_sandbox_art_assets.gd`

- [x] **Step 3: Replace random opening clutter and the starter block wall.**

```gdscript
func _build_starter_clearing(land: Node3D) -> void:
    var clearing := Node3D.new()
    clearing.name = "StarterClearing"
    land.add_child(clearing)
    _build_meadow_path(clearing)
    _build_starter_props(clearing)
```

Use Nature Kit paths, fences, trees, grass, rocks, and campfire; use a bounded crate/barrel/chest cluster for interactive props. Keep world-root and palette registration unchanged. Do not call `_seed_starter_structure()` and do not scatter `crate_count` props through the centre.

- [x] **Step 4: Run art and Kit E2E regressions.**

```sh
godot --headless --path . --script tests/gameplay/test_sandbox_art_assets.gd
godot --headless --path . --script tests/e2e/run_sandbox_kit_suite.gd
```

- [ ] **Step 5: Commit.**

```sh
git add levels/sandbox_level.gd tests/gameplay/test_sandbox_art_assets.gd
git commit -m "feat: compose sandbox village clearing"
```

### Task 3: Ground-Level Render Proof

**Files:**
- Modify: `tests/play/run_render_audit.gd`
- Generated evidence: `tests/play/screenshots/audit_01_sandbox_level.png`
- Generated report: `render_audit_report.txt`

**Interfaces:**
- Consumes: the authored Sandbox level and GPU-backed `SubViewport` capture.
- Produces: a ground-level opening frame with a warm, readable focal area.

- [x] **Step 1: Change the audit to a failing ground-level camera and focal assertion.**

```gdscript
cam.position = Vector3(0, 2.8, 9.5)
cam.look_at_from_position(cam.position, Vector3(0, 1.0, -8.0), Vector3.UP)
_assert(c.r > c.b and c.r > 0.35,
    "sandbox opening focal area is warm and readable")
```

- [x] **Step 2: Run the GPU audit and observe failure before implementing visual changes.**

Run: `godot --path . --script tests/play/run_render_audit.gd`

- [x] **Step 3: Let the authored clearing satisfy the assertion; do not weaken the threshold.**

- [x] **Step 4: Re-run the GPU audit and manually inspect the PNG.**

Run: `godot --path . --script tests/play/run_render_audit.gd`

Inspect: `tests/play/screenshots/audit_01_sandbox_level.png`

- [ ] **Step 5: Commit the accepted evidence.**

```sh
git add tests/play/run_render_audit.gd tests/play/screenshots/audit_01_sandbox_level.png render_audit_report.txt
git commit -m "test: verify sandbox village opening frame"
```

### Task 4: Regression And Independent Review

**Files:**
- Create: `.ai/reviews/sandbox-village-presentation-review-2026-09-01.json`

**Interfaces:**
- Consumes: Task 1-3 diff, regressions, and the rendered frame.
- Produces: review evidence of visual readability and preserved sandbox boundaries.

- [x] **Step 1: Run all proof commands.**

```sh
godot --headless --path . --script tests/gameplay/test_sandbox_art_assets.gd
godot --headless --path . --script tests/e2e/run_sandbox_kit_suite.gd
godot --path . --script tests/play/run_render_audit.gd
git diff --check
```

- [x] **Step 2: Request independent review.**

The review must confirm readable materials, bounded authored props, the unchanged SandboxKitBridge boundary, and passing E2E safety coverage.

- [x] **Step 3: Record the review verdict and evidence.**

```json
{"task":"sandbox-village-presentation-2026-09-01","verdict":"APPROVE","checks":{"art_assets":"PASS","sandbox_kit_e2e":"PASS","gpu_opening_capture":"PASS"}}
```

- [ ] **Step 4: Commit review evidence after approval.**

```sh
git add .ai/reviews/sandbox-village-presentation-review-2026-09-01.json
git commit -m "docs: review sandbox village presentation"
```
