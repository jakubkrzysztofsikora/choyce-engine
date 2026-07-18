# Universal Animation Library (Standard)

`UAL1_Standard.glb` is the non-root-motion Godot-ready library from
Quaternius' Universal Animation Library [Standard]. It is dedicated to the
public domain under CC0 1.0.

Source supplied locally: `/Users/jakubsikora/Downloads/Universal Animation Library[Standard]`.
Use these clips only through a skeleton-compatible retarget profile; do not
replace the Ziemek/Gniewko visual rigs with the library's source character.

## Compatibility check — 2026-07-18

The current active `character-male-a.glb` player mesh has a deliberately
simplified seven-bone skeleton (`root`, paired legs/arms, `torso`, `head`).
UAL has a 65-bone humanoid rig with spine, clavicle, hand/finger, and foot
chains. These are **not directly compatible**. Do not assign UAL clips to the
current child rig: a forced mapping would lose core limb motion and cause the
root sliding / backwards acting the cinematic review is intended to eliminate.

Before VS-032 proceeds, choose a licensed child-style visual rig that shares a
retargetable humanoid layout (or author a tested BoneMap plus rendered proof).
