# VS-046 Hero Asset Specification

## Overview
This document specifies the requirements for rig-compatible hero assets for Ziemek and Gniewko based on the approved concept art (`data/concepts/ziemek-gniewko-character-turnarounds-v1.png`).

## Current State
The existing implementation uses Kenney toon characters with shader-based recoloring:
- **Ziemek**: Uses turquoise hoodie color (`#27b8b4`), dark trousers (`#126f76`), and a Kenney food-kit bag as backpack
- **Gniewko**: Uses light polo color (`#e9e1d2`), navy trousers (`#202e43`)
- **Shader**: `hero_clothing.gdshader` applies selective recoloring with patterned texture overlay

**Limitation**: The generic Kenney source rig cannot achieve the child-proportioned silhouette, patterned hoodie detail, or detailed backpack from the concept art.

## Requirements

### Ziemek
- **Hoodie**: Turquoise graphic hoodie with visible pattern (not just solid color)
- **Trousers**: Dark trousers
- **Backpack**: Detailed backpack with child-appropriate proportions
- **Proportions**: Child-sized humanoid rig (not adult proportions)
- **Rig**: Must be compatible with existing facial performance system (BoneAttachment3D)

### Gniewko  
- **Top**: Light-colored top (polo or similar)
- **Trousers**: Dark trousers
- **Proportions**: Child-sized humanoid rig, matching Ziemek's proportions
- **Rig**: Must share the same rig structure as Ziemek for consistent facial performance

### Technical Requirements
1. **Rig Compatibility**: Same bone hierarchy as existing Kenney humanoid rig for facial performance attachment
2. **Material Setup**: PBR materials with proper albedo, normal, roughness maps
3. **Texture Resolution**: Minimum 1024x1024 for main textures, 2048x2048 preferred
4. **UV Layout**: Clean UV unwrapping for pattern application
5. **Collision**: Optional: simplified collision meshes or use existing capsule

### Asset Files Required
- `data/models/heroes/ziemek.glb` - Ziemek complete character
- `data/models/heroes/gniewko.glb` - Gniewko complete character
- `data/models/heroes/ziemek_backpack.glb` - Optional: separate backpack mesh
- `data/textures/heroes/ziemek_hoodie_pattern.png` - Enhanced pattern texture
- `data/textures/heroes/ziemek_albedo.png` - Albedo map
- `data/textures/heroes/ziemek_normal.png` - Normal map
- `data/textures/heroes/gniewko_albedo.png` - Albedo map
- `data/textures/heroes/gniewko_normal.png` - Normal map

## Integration Points

### Player Controller
The existing `player_controller.gd` has:
- `HERO_IDENTITY_ZIEMEK := "ziemek"`
- `HERO_IDENTITY_GNIEWKO := "gniewko"`
- `_apply_hero_identity_layer()` method for visual customization

### Split Screen
`split_screen_runtime.gd` currently uses:
- P1: Kenney character-male-a.glb with Ziemek identity
- P2: Kenney character-male-b.glb with Gniewko identity

Update to use new hero assets once available.

### Facial Performance
`facial_performance.gd` has `attach_kenney_humanoid()` method. This must work with new rigs or be extended to support them.

## Acceptance Criteria
1. Default hero no longer reads as unrelated blue uniform
2. Both heroes use the same grounded humanoid rig
3. No detached face, floating weapon, or child-photo texture
4. Local split-screen selects two visually distinct heroes
5. Close and third-person live captures retained
6. Independent visual review completed

## Blockers
- Requires 3D modeling tools (Blender or similar) to create child-proportioned rigs
- Requires texture painting for patterned hoodie and detailed backpack
- Requires testing in Godot to verify rig compatibility with facial performance

## Next Steps
1. Create child-proportioned base humanoid rig
2. Model Ziemek with turquoise patterned hoodie, dark trousers, detailed backpack
3. Model Gniewko with light top, dark trousers
4. Create PBR textures for both characters
5. Export as GLB with embedded textures
6. Integrate into `player_controller.gd` identity system
7. Test in split-screen mode
8. Capture third-person and close-up evidence
9. Submit for visual review

## References
- Concept art: `data/concepts/ziemek-gniewko-character-turnarounds-v1.png`
- Existing implementation: `src/adapters/inbound/gameplay/player_controller.gd`
- Shader: `src/adapters/inbound/gameplay/shaders/hero_clothing.gdshader`
- VS-036: Delivers initial Ziemek/Gniewko rigs (using Kenney base)
- PLAN.md: Sections 680-731 describe hero identity requirements
