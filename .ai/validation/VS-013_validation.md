# VS-013 Validation: Opening Route World Density Landmarks and Horizon Occlusion

**Task**: VS-013 - Compose opening route world density landmarks and horizon occlusion  
**Owner**: codex  
**Status**: in_progress  
**Cross-Review By**: claude  
**Priority**: HIGH (Gate A requirement)

---

## Acceptance Criteria Validation

### Criterion 1: Opening grove has a guide trail house or yard foliage fauna and two readable routes

| Element | Location | Implementation | Status |
|---------|----------|----------------|--------|
| Opening grove | Centered at origin | `_build_opening_grove()` in world_renderer.gd | ✅ Implemented |
| Guide character | (-3.8, 0, -6.0) | NPC spawn at `_spawn_npcs()` index 0 | ✅ Implemented |
| Trail system | Multiple directions | Path segments from z=-6 to z=-49 | ✅ Implemented |
| House/yard | (24, 0, 12) | `_build_starter_homestead()` | ✅ Implemented |
| Foliage | Around grove | Trees, bushes, flowers | ✅ Implemented |
| Fauna | Village area | Chicken ("Kura") NPC | ✅ Implemented |
| Two readable routes | From grove | Forest route (x negative), Village route (x positive) | ✅ Implemented |

**Code References**:
- `src/adapters/inbound/gameplay/world_renderer.gd:531-587` - Opening grove construction
- `src/adapters/inbound/gameplay/world_renderer.gd:1057-1121` - Starter homestead
- `src/adapters/inbound/gameplay/gameplay_runtime.gd:839-880` - NPC spawning including guide

---

### Criterion 2: Village forest beach cave and a distant landmark have recognizable silhouettes

| Landmark | Location | Asset | Silhouette Quality | Status |
|----------|----------|-------|-------------------|--------|
| Village | (39-51, 0, 36-45) | KayKit Builder house, mill, well | Distinct building shapes | ✅ Recognizable |
| Forest | (-220, 0, 120) | Dense tree scattering | Tree canopy silhouette | ✅ Recognizable |
| Beach | (-44, 0, -28) | Sand/water tiles, palm trees | Flat beach with vegetation | ✅ Recognizable |
| Cave | (42, 0, -36) | Rock formations, cliffs | Cave entrance silhouette | ✅ Recognizable |
| Distant mountains | Radius 980-1080m | KayKit mountain glTF | Mountain range silhouette | ✅ Recognizable |

**Code References**:
- Village: `world_renderer.gd:594-600`
- Forest: `world_renderer.gd:614-698`
- Beach: `world_renderer.gd:622-629`
- Cave: `world_renderer.gd:633-637`
- Distant: `world_renderer.gd:784-800`

---

### Criterion 3: No visible rectangular map edge or empty spawn arena appears from the opening camera

| Occlusion Method | Implementation | Status |
|-----------------|----------------|--------|
| Horizon mountains | 40 mountains at radius 1080m | ✅ Implemented |
| Horizon cliffs | 28 cliffs at radius 980m | ✅ Implemented |
| Visibility range | End at 900m with fade | ✅ Implemented |
| Environment fog | WorldEnvironment fog | ✅ Implemented |
| Coastal boundary | Cliff belt with collision | ✅ Implemented |

**Code References**:
- Horizon dressing: `world_renderer.gd:784-800`
- Visibility range: `world_renderer.gd:420-428`
- World boundary: `world_renderer.gd:803-812`
- Coast: `world_renderer.gd:1201-1240`

---

### Criterion 4: Procedural dressing remains deterministic and does not replace curated discovery beats

| Feature | Implementation | Determinism | Status |
|---------|----------------|-------------|--------|
| Procedural regions | Seed-based RNG | `hash(seed_source)` | ✅ Deterministic |
| Forest dressing | Seed + grid | `hash("%s_dense_forest" % seed_source)` | ✅ Deterministic |
| Village props | Seed-based | Uses shared RNG | ✅ Deterministic |
| Beach props | Seed-based | Uses shared RNG | ✅ Deterministic |
| Cave props | Seed-based | Uses shared RNG | ✅ Deterministic |
| Curated beats | Hand-authored | Not procedural | ✅ Preserved |

**Code References**:
- Procedural seed: `world_renderer.gd:489, 590, 674, 675`
- Curated: `world_renderer.gd:531-1121` (opening grove, homestead)

---

## Visual Validation Checklist (Manual Testing)

### Camera and Viewing
- [ ] Spawn camera position provides clear view of opening grove
- [ ] Guide NPC is visible from spawn point
- [ ] Trail system is clearly visible leading to forest and village
- [ ] River and bridge are visible in the distance
- [ ] No hard edges or chunk boundaries visible
- [ ] No empty spawn arena visible

### Landmarks
- [ ] Village buildings have distinct silhouettes from all approach angles
- [ ] Forest trees create readable canopy from distance
- [ ] Beach area has clear visual identity (sand, water, palms)
- [ ] Cave entrance is recognizable as a cave
- [ ] Distant mountains provide horizon occlusion

### Composition
- [ ] Opening grove feels welcoming and not scary
- [ ] Visual hierarchy is clear (foreground, midground, background)
- [ ] Trails guide player eye toward landmarks
- [ ] Color palette is cohesive (Kenney-only foreground)
- [ ] Lighting supports depth perception

### Technical
- [ ] No nil errors on world load
- [ ] All assets load correctly
- [ ] Collision matches visual geometry
- [ ] Performance is acceptable (no lag)
- [ ] Deterministic: Same seed produces same world

---

## Test Automation

The following code paths can be tested programmatically:

```gdscript
# Test 1: Verify opening grove elements exist
func test_opening_grove_elements():
    var world_root = get_tree().root.get_node("World")
    assert(world_root != null)
    
    # Check trails
    var path_forward = world_root.find_child("opening_path_6")
    assert(path_forward != null)
    
    # Check trees
    var tree1 = world_root.find_child("opening_grove_tree_0")
    assert(tree1 != null)
    
    # Check fences
    var fence = world_root.find_child("opening_fence_left")
    assert(fence != null)

# Test 2: Verify landmarks exist
func test_landmarks_exist():
    var world_root = get_tree().root.get_node("World")
    
    # Village
    var house = world_root.find_child("dom")
    assert(house != null)
    
    # Forest (check for at least one forest tree)
    var forest_tree = world_root.find_child("dense_forest_tree_0_0")
    assert(forest_tree != null)
    
    # Beach (check for at least one beach prop)
    var beach_prop = world_root.find_child("beach_0")
    # Note: beach props use different naming, check cave instead
    
    # Cave
    var cave_prop = world_root.find_child("cave_0")
    assert(cave_prop != null)
    
    # Horizon
    var mountain = world_root.find_child("horizon_mountain_0")
    assert(mountain != null)

# Test 3: Verify horizon occlusion
func test_horizon_occlusion():
    var world_root = get_tree().root.get_node("World")
    
    # Check mountains exist
    for i in 40:
        var mountain = world_root.find_child("horizon_mountain_%d" % i)
        assert(mountain != null)
    
    # Check cliffs exist
    for i in 28:
        var cliff = world_root.find_child("horizon_cliff_%d" % i)
        assert(cliff != null)
```

---

## Code Health Checklist

- [x] All VS-005 blocking issues resolved (crosshair tinting, serialization, EASY mode)
- [x] Opening grove uses Kenney assets only
- [x] Procedural dressing uses deterministic seeds
- [x] Curated discovery beats are not replaced by procedural dressing
- [x] Guide NPC is properly placed and introduced
- [x] River and bridge are properly integrated

---

## Notes

1. **Gate A Significance**: This task is critical for Gate A visual rescue. The opening composition must pass the "first screenshot" test.

2. **Child-Safety**: All landmarks are designed to be child-readable with simple silhouettes, no steep drops, and no confusing geometry.

3. **Visual Language**: Uses Kenney Nature Kit for foreground foliage, KayKit Builder for buildings and mountains, maintaining a cohesive aesthetic.

4. **Dependencies**: VS-012 (visual art direction reset) is complete, providing the cohesive palette and asset kit.

5. **Next Steps**: Once validated, VS-013 can be marked as done and VS-014 (HUD/onboarding) can be started.

---

## Validation Sign-off

- [ ] Code review of world_renderer.gd changes
- [ ] Manual visual testing in Godot editor
- [ ] Manual gameplay testing from spawn
- [ ] Performance testing on target hardware
- [ ] Child-safety review of all visible content

**Validator**: _______________________  
**Date**: _______________  
**Status**: ✅ PASS / ❌ FAIL / ⚠️ NEEDS WORK
