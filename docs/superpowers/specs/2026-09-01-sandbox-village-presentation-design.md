# Sandbox Village Presentation Design

## Goal

Turn Piaskownica into a readable, lived-in Choyce countryside at first view while preserving the migrated rpg-asserts sandbox mechanics, safety limits, and persistence boundary.

## Evidence And Problem

The GPU-backed sandbox audit on 2026-09-01 captured a sparse field of pale imported geometry, random props, and seeded blocks. The failure is not an environment-light setting: `levels/sandbox_level.gd` instantiates visual scenes without the material application used by the Adventure renderer, and its random prop field has no authored composition. The audit midpoint therefore rendered near-neutral rather than a warm, legible village frame.

## Experience

The first playable space is a small sunlit meadow clearing. A textured path leads toward two readable homes; a friendly NPC and useful loose props sit close to the player; trees, rocks, and a low fence frame the clearing. The child can immediately build, grab, throw, and explore without scattered objects or a starter block wall competing with the village.

## Presentation Adapters

`levels/sandbox_level.gd` remains the inbound Godot composition adapter. It will compose an authored `VillageLand` with named meadow, path, cottage, camp/workbench, loose-prop, NPC, and woodland groups. Runtime physics, `BuildSystem`, `PlayerRegistrySystem`, and `SandboxKitBridge` remain untouched.

Imported scenes must receive the same texture-preserving material rules as Adventure assets: preserve a source albedo texture when valid, but apply a restrained Choyce fallback material to near-white or untextured surfaces. This presentation helper stays local to the Sandbox level and does not cross the domain boundary.

`gameplay/props/prop_factory.gd` retains the rpg-asserts component body and collision contract. It mounts committed local crate/barrel scenes only under its existing rigid-body roots.

## Constraints

- Use only committed local assets in `data/models` and `data/textures`.
- No pirate theme, generated art, remote asset, AI, chat, network, domain, or persistence changes.
- Preserve SandboxKitBridge as the sole Choyce save/event boundary.
- Preserve player/block caps, keyboard/P1 and controller/P2 isolation, mouse recapture, build persistence, grab, throw, and interaction components.
- Avoid randomized visual clutter near the opening; loose props are named and bounded.
- Visual acceptance requires GPU-backed capture inspection plus existing Kit E2E regression coverage. A normal launcher-window capture remains a separate handoff gate when this environment can keep the debug bridge alive.

## Acceptance Criteria

1. The sandbox opening frame has a textured meadow, warm path/wood focal anchors, homes, natural framing, friendly NPCs, and no dominant scattered white geometry.
2. Named `VillageLand` groups expose the authored clearing, path, houses, props, NPCs, and woodland for structural regression.
3. Imported village and prop meshes preserve real albedo textures where present and receive a restrained fallback material only where their source material is near-white or lacks texture.
4. Crate/barrel visuals remain imported scenes under the original sandbox rigid body, collision, health, grab, interaction, highlight, FX, and destruction components.
5. The existing Sandbox Kit E2E suite continues to pass, proving safety limits, bridge persistence, roster behavior, and teardown remain unchanged.
6. The render audit writes an inspectable frame and passes an opening-composition color/readability contract; that frame is manually inspected before a ready claim.
