# Third-party asset notices

choyce-engine ships a hand-curated bundle of CC0/CC-BY assets that are
**not** stored in git. They are fetched on first run by
`scripts/assets/fetch_free_assets.sh` (declared in
`scripts/assets/manifest.yaml`) and extracted under `data/`.

This file is the authoritative attribution catalog. Every asset source
listed here corresponds to a pack that the engine consumes, regardless
of whether the SHA-256 has been locked in yet. CI
(`.github/workflows/notices-gate.yml`) blocks merging any change that
adds a file under `data/` without updating this file in the same commit.

If you add a new pack to `manifest.yaml`, add a matching block here.

## Asset attributions

### data/models/kaykit/

- Kay Lousberg - KayKit Adventurers (CC0) - https://kaylousberg.itch.io/kaykit-adventurers
- Kay Lousberg - KayKit Dungeon Remastered (CC0) - https://kaylousberg.itch.io/kaykit-dungeon-remastered
- Kay Lousberg - KayKit Medieval Builder (CC0) - https://kaylousberg.itch.io/kaykit-medieval-builder-pack
- Kay Lousberg - KayKit Skeletons (CC0) - https://kaylousberg.itch.io/kaykit-skeletons
- Kay Lousberg - KayKit Animals (CC0) - https://kaylousberg.itch.io/kaykit-animals
- Kay Lousberg - KayKit Furniture Bits (CC0) - https://kaylousberg.itch.io/furniture-bits
- Kay Lousberg - KayKit Restaurant Bits (CC0) - https://kaylousberg.itch.io/restaurant-bits

### data/models/quaternius/

- Quaternius - Ultimate Animated Animals Pack (CC0) - https://quaternius.com/packs/ultimateanimatedanimals.html
- Quaternius - Ultimate Modular Characters (CC0) - https://quaternius.com/packs/ultimatemodularcharacters.html
- Quaternius - Ultimate Nature Pack (CC0) - https://quaternius.com/packs/ultimatenature.html
- Quaternius - Ultimate Stylized Nature (CC0) - https://quaternius.com/packs/ultimatestylizednature.html
- Quaternius - Ultimate Platformer Pack (CC0) - https://quaternius.com/packs/ultimateplatformer.html
- Quaternius - Ultimate Modular Ruins (CC0) - https://quaternius.com/packs/ultimatemodularruins.html
- Quaternius - Ultimate Food Pack (CC0) - https://quaternius.com/packs/ultimatefood.html

### data/textures/voxel/

- Kenney - Voxel Pack (CC0) - https://kenney.nl/assets/voxel-pack
- Kenney - Pattern Pack (CC0) - https://kenney.nl/assets/pattern-pack
- Kenney - Prototype Textures (CC0) - https://kenney.nl/assets/prototype-textures
- ambientCG - Stylized Wood (CC0) - https://ambientcg.com/
- ambientCG - Stylized Stone (CC0) - https://ambientcg.com/

### data/vfx/voxel/

- Kenney - Particle Pack (CC0) - https://kenney.nl/assets/particle-pack
- Kenney - Smoke Particles (CC0) - https://kenney.nl/assets/smoke-particles
- Pixel Frog (itch.io) - VFX Voxel Burst (CC0) - https://pixelfrog-assets.itch.io/
- OpenGameArt - Stylized Magic FX (CC0) - https://opengameart.org/

### data/audio/music/voxel/

- Kenney - Music Loops (CC0) - https://kenney.nl/assets/music-loops
- Kenney - Music Jingles (CC0) - https://kenney.nl/assets/music-jingles
- Joel Steudler / OpenGameArt - Kid-friendly Adventure Loops (CC0) - https://opengameart.org/
- Free Music Archive - CC0 Kids Themes - https://freemusicarchive.org/genre/Kids/

## How to add a new attribution

1. Add the pack entry to `scripts/assets/manifest.yaml` (id, url, sha256, dest, size_mb, license, attribution).
2. Append the credit to the matching `### data/...` block above. Format:
   `Author - Pack name (LICENSE) - URL`.
3. If you introduce a new top-level `data/<x>/` tree, also extend
   `.gitignore` and add a new `### data/<x>/` heading here.

Format intentionally kept plain so `grep -E '^###|^- '` enumerates the
full catalog.
