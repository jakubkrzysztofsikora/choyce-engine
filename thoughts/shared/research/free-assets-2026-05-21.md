---
date: 2026-05-21
researcher: deep-research-free-assets
status: complete
---
# Research: Free Phonk-Friendly Assets for choyce-engine

## TL;DR
- Drop the web-app generation pipeline. **Quaternius + KayKit + Kenney + Poly Pizza** alone deliver 300+ rigged characters, 1000+ props, 161+ humanoid animations under CC0 — enough for the entire ninja/sigma vibe at 0 attribution cost.
- For phonk audio, **Pixabay (Pixabay Content License, no-attribution)** is the cleanest legal fit for a kid-safe shipping product; Tallbeard Studios (CC0) is the genre-flex backup; Freesound CC0 filter is the SFX/one-shot source. Avoid Looperman (royalty-free ≠ free to bundle in a commercial product, mixed licenses).
- Textures: **ambientCG + Poly Haven + Kenney Prototype Textures** for PBR base; **Glitch (CC0 archive)** + **Texture Ninja** for graffiti/glitch overlays.
- Fonts: switch from Nunito-Bold to **Rubik Glitch + Audiowide + Rajdhani** (all SIL OFL on Google Fonts) for sigma headers + kid-readable body.
- Total: ~17 vetted sources, all commercial-safe, mostly CC0; only **Mixamo and Soundimage require attribution**, and Mixamo's ML-training restriction must be flagged because the engine bundles Ollama.

## Decision Framework
Criteria applied to every source:
1. **License clarity** — CC0 / Pixabay / SIL OFL preferred. Anything ambiguous (Looperman, Sketchfab non-tagged) gets rejected.
2. **Kid-safety** — no horror gore, no profanity in track titles/lyrics, no occult sigils. Phonk is borderline genre — must preview every track.
3. **Format fit** — glTF/GLB for 3D (Godot native), OGG for music loops (Godot native, no encoding patent issues), PNG/JPG for textures.
4. **API ergonomics** — single-rig retarget (KayKit + Quaternius share humanoid rig naming v2.0 since 2026-01) > pack-by-pack one-offs.
5. **No ML-training clause** — Mixamo explicitly bans ML training; Synty requires custom license for any generative AI. Both flagged because Ollama is bundled.

## Catalog by Category

### 3D Characters & Creatures
| Source | License | Asset count | Kid-safe? | Quality | URL | Notes |
|---|---|---|---|---|---|---|
| Quaternius — Universal Base Characters | CC0 | 6 base + modular | Yes | 5/5 | https://quaternius.com/packs/universalbasecharacters.html | Humanoid rig v2.0 (2026-01); retargets to KayKit. Best ninja base via modular outfits. |
| Quaternius — Universal Animation Library 2 | CC0 | 130+ anims (parkour, combat combos) | Yes | 5/5 | https://quaternius.itch.io/universal-animation-library | Sigma/ninja moveset. 30fps GLB exports (2026-01 fix). |
| Quaternius — Cyberpunk Game Kit | CC0 | ~50 | Yes | 4/5 | https://quaternius.com/ | Direct phonk fit. |
| KayKit — Character Pack: Adventurers | CC0 | 4 chars + 75 anims + 25 accessories | Yes | 5/5 | https://kaylousberg.itch.io/kaykit-adventurers | Same rig as skeletons. |
| KayKit — Character Pack: Skeletons | CC0 | 4 skeletons + 90+ anims | **Verify** | 5/5 | https://kaylousberg.itch.io/kaykit-skeletons | "Skeleton sidekick" gap filler. Angry/Happy blendshapes — friendly faces possible. Preview for PEGI-7 fit. |
| KayKit — Character Animations | CC0 | 161 humanoid anims | Yes | 5/5 | https://kaylousberg.itch.io/kaykit-character-animations | Retarget to Quaternius. |
| Kenney — Blocky Characters | CC0 | 20 | Yes | 4/5 | https://kenney.nl/assets/blocky-characters | Already partial in project. |
| Mixamo | Adobe EULA (free, no attribution, **no ML training**) | 100+ chars, 2500+ anims | Yes | 5/5 | https://www.mixamo.com/ | **RISK**: ML-training ban conflicts with bundled Ollama. Safe if Ollama only acts on user-typed input, not on Mixamo geometry. Document this carefully. |
| Poly Pizza — search "ninja" | per-model (mostly CC0, some CC-BY) | ~30 ninja-tagged | Yes | 3/5 | https://poly.pizza/search/ninja | Per-asset license check required. |

### 3D Environment Props (phonk / urban / dojo / brutalist)
| Source | License | Asset count | Kid-safe? | Quality | URL | Notes |
|---|---|---|---|---|---|---|
| KayKit — Dungeon Pack Remastered | CC0 | 200+ | Yes | 5/5 | https://kaylousberg.itch.io/kaykit-dungeon-remastered | Dojo / brutalist interior. |
| Quaternius — Sci-Fi Essentials / Modular Sci-Fi Megakit | CC0 | hundreds | Yes | 5/5 | https://quaternius.com/ | Neon-friendly. |
| Poly Pizza — search "katana", "shuriken", "neon", "graffiti" | mostly CC0 | 100s | Yes | 3/5 | https://poly.pizza/ | Per-asset license. |
| Kenney — current bundled set (1600 props) | CC0 | 1600 | Yes | 4/5 | https://kenney.nl/ | Already in project. |
| Synty — POLYGON Starter Pack | Synty/Unity EULA (no ML, no resale) | ~150 | Yes | 5/5 | https://syntystore.com/products/polygon-starter-pack | **RISK**: custom license required for any AI features. Recommend SKIP for choyce-engine because Ollama is bundled. |

### Audio: Music (phonk / drift / lo-fi / sigma)
| Source | License | Asset count | Kid-safe? | Quality | URL | Notes |
|---|---|---|---|---|---|---|
| Pixabay — "drift phonk" / "phonk" | Pixabay Content License (no attribution, commercial OK) | 100s | **Preview required** | 4/5 | https://pixabay.com/music/search/drift%20phonk/ | Best legal/quality balance for shipping. Curators: White_Records (Neon Drift, Turbo Pulse). |
| Tallbeard Studios — Music Loop Bundle | CC0 | 200+ loops, multi-genre | Yes | 5/5 | https://tallbeard.itch.io/music-loop-bundle | True CC0. Not phonk-native — repurpose synth/action loops with bass boost. |
| Freesound (CC0 filter) | CC0 | 1000s of one-shots | Yes | mixed | https://freesound.org/ | 808 kicks, vinyl crackle, cassette hiss for layering. CC0 license filter mandatory. |
| Eric Matyas — Soundimage.org | Custom royalty-free (in-product attribution required) | 2500+ tracks | Yes | 4/5 | https://soundimage.org/ | Backup only — attribution overhead. |
| itch.io 5ercine / Free Cafe Radio phonk tracks | royalty-free, per-author | dozens | **Preview required** | 4/5 | https://itch.io/soundtracks/tag-phonk | Genre-native but mixed licenses; preview each. |
| Looperman | royalty-free for use in derivative works, **NOT for redistribution** | — | n/a | — | — | **REJECT**: license forbids bundling loops as standalone files. |

### 2D Textures, Decals, VFX Sheets
| Source | License | Asset count | Kid-safe? | Quality | URL | Notes |
|---|---|---|---|---|---|---|
| ambientCG | CC0 | 2800+ PBR | Yes | 5/5 | https://ambientcg.com/ | Concrete (Concrete012/020/047A) for brutalist. |
| Poly Haven — HDRIs Urban/Night | CC0 | 100s | Yes | 5/5 | https://polyhaven.com/hdris/urban/night | Shanghai Bund HDRI = direct neon fit. |
| Kenney — Prototype Textures + UI Pack | CC0 | 100s | Yes | 4/5 | https://kenney.nl/ | Already idiomatic for Godot. |
| Glitch (CC0 archive) | CC0 | 10000+ tiles/decals | Yes | 4/5 | https://opengameart.org/content/huge-cc0-asset-release-from-glitch | Stylized urban/decorative — graffiti substitutes. |
| Texture Ninja | CC0 | 5000+ photo refs | Yes | 4/5 | https://texture.ninja/ | Concrete + paint + cutouts; need tiling pass. |
| OpenGameArt — VFX / cc0-special-effects | CC0 | ~200 | Yes | 3/5 | https://opengameart.org/content/cc0-special-effects | Glow rings, energy bursts. |

### Fonts (replace Nunito-Bold)
| Source | License | Asset count | Kid-safe? | Quality | URL | Notes |
|---|---|---|---|---|---|---|
| Google Fonts — Rubik Glitch | SIL OFL 1.1 | 1 | Yes | 5/5 | https://fonts.google.com/specimen/Rubik+Glitch | Sigma title font. |
| Google Fonts — Audiowide | SIL OFL 1.1 | 1 | Yes | 5/5 | https://fonts.google.com/specimen/Audiowide | Phonk headers. |
| Google Fonts — Zen Dots | SIL OFL 1.1 | 1 | Yes | 4/5 | https://fonts.google.com/specimen/Zen+Dots | Logo alt. |
| Google Fonts — Rajdhani | SIL OFL 1.1 | 1 weight family | Yes | 5/5 | https://fonts.google.com/specimen/Rajdhani | Narrow body / tracklist text. Good Polish diacritic coverage. |
| Google Fonts — Orbitron | SIL OFL 1.1 | 1 | Yes | 4/5 | https://fonts.google.com/specimen/Orbitron | Alt header. |

### Particles + VFX
| Source | License | Asset count | Kid-safe? | Quality | URL | Notes |
|---|---|---|---|---|---|---|
| Kenney — Particle Pack | CC0 | 80 sprites | Yes | 5/5 | https://kenney.nl/assets/particle-pack | Already idiomatic. |
| JangaFX — VDB Volumes | CC0 | dozens | Yes | 5/5 | (via awesome-cc0) | Smoke/fire VDB for neon trails. |
| OpenGameArt — Special Effects (CC0) | CC0 | 100s | Yes | 3/5 | https://opengameart.org/content/special-effects-cc0 | Hit flashes. |

## Integration Plan

### File layout (extends current `data/`)
```
data/
  models/
    props/           # existing 26 Blender low-poly
    kenney/          # existing
    quaternius/
      characters/    # Universal Base + Cyberpunk
      anims/         # Universal Animation Library 2 GLB
    kaykit/
      adventurers/
      skeletons/     # if PEGI-7 preview passes
      dungeon/
      anims/         # 161 humanoid anims
    poly_pizza/      # cherry-picked CC0 only
  audio/
    music/
      phonk/         # Pixabay-sourced .ogg conversions
      cc0_loops/     # Tallbeard
    sfx/
      freesound_cc0/
  textures/
    ambientcg/
    polyhaven_hdri/
    glitch_archive/
    decals/          # graffiti from Texture Ninja
  fonts/
    rubik_glitch/
    audiowide/
    rajdhani/
NOTICES.md           # NEW — required even for CC0 (best practice)
```

### NOTICES.md format (additions)
```markdown
## 3D Assets
- Quaternius Universal Base Characters — CC0 — https://quaternius.com/
- KayKit Adventurers / Skeletons / Dungeon — CC0 — https://kaylousberg.itch.io/
- Kenney Blocky Characters / Particle Pack — CC0 — https://kenney.nl/

## Audio
- Pixabay tracks — Pixabay Content License (no attribution required, listed here voluntarily)
- Tallbeard Studios "Abstraction" — CC0 — https://tallbeard.itch.io/music-loop-bundle
- Eric Matyas / Soundimage.org — "Music by Eric Matyas / soundimage.org" (REQUIRED if used)

## Fonts
- Rubik Glitch, Audiowide, Rajdhani — SIL OFL 1.1 (license file copied to data/fonts/<font>/OFL.txt)

## Restricted
- Mixamo: free per Adobe EULA; NOT used for ML training (see src/adapters/outbound/llm/ — Ollama touches user text only, never Mixamo geometry).
- Synty POLYGON Starter Pack: NOT BUNDLED (license conflict with Ollama).
```

### Pipeline — download → import → asset_id mapping
1. Add `scripts/assets/fetch_free_assets.sh` — curl/unzip from each source into `data/models/<provider>/raw/`, run a Blender headless `--background --python` script to re-export at unified scale (1m baseline) and 30fps anims.
2. Extend `src/adapters/inbound/gameplay/world_renderer.gd::PROP_GLTF_MAP` with new keys: `ninja_kid`, `skeleton_sidekick`, `dojo_pillar`, `neon_sign_lime`, `graffiti_decal_01..05`, `katana`, `shuriken`. Each maps to a `res://data/models/<provider>/<file>.glb` path.
3. Audio: register Pixabay tracks via `src/adapters/inbound/shared/audio/audio_bank.gd` — add keys `music.phonk.combat_01`, `music.phonk.drift_01..05`, `music.sigma.idle`. Keep existing combat_phonk.mp3 / drift_phonk.mp3 as fallbacks during transition.
4. Fonts: drop OTF/TTF + OFL.txt into `data/fonts/<font>/`, swap the default `Nunito-Bold` reference in `theme.tres` to `Rubik Glitch` (titles), `Audiowide` (headers), `Rajdhani` (body). Verify Polish diacritic coverage with `tools/font_check.py`.
5. Run `scripts/audio/preview_phonk_pack.py` (NEW) — pulls track titles via Pixabay API, flags any with "drift", "neon", "ghost" (OK) vs profanity / drug refs (REJECT). Manual ear-check pass on every survivor.

### 3-week phased rollout
- **Week 1 (small)**: Fonts swap + KayKit Adventurers + Pixabay phonk pack (10 tracks). Touches: theme.tres, audio_bank.gd, NOTICES.md. ~50 MB.
- **Week 2 (medium)**: Quaternius Universal Base + Animation Library 2 + ambientCG concrete pack + Glitch archive decals. Touches: world_renderer PROP_GLTF_MAP (15 new keys), texture import settings. ~300 MB.
- **Week 3 (large)**: KayKit Dungeon Remastered + Skeletons (if PEGI-7 review passes) + Tallbeard CC0 loop bundle + Poly Haven night HDRI. ~600 MB.

## Risks
- **License share-alike trap**: Some Sketchfab models tagged "CC0" by uploader but original was CC-BY-SA upstream — always read the model description, not just the tag. Skip Sketchfab unless desperate.
- **Mixamo ML-training clause vs bundled Ollama**: Adobe EULA forbids using Mixamo content "for training machine learning models." Ollama in choyce-engine acts on user prompts, never on Mixamo geometry — so usage is compliant *if* we never feed Mixamo meshes/anims into any future training/fine-tuning pipeline. Add a comment in CLAUDE.md memory and a unit-test or doc gate that catches violations.
- **Synty license**: Even free starter pack bans Roblox-style UGC distribution and explicitly requires custom license for "generative AI." choyce-engine bundles Ollama — recommend **don't bundle Synty** to avoid ambiguity.
- **File-size bloat**: 950 MB total in Week 3. Mitigate via per-pack `.gitignore` + a download-on-first-run flow (`scripts/assets/fetch_free_assets.sh`) so the repo itself stays slim. Already established pattern for non-committed binaries.
- **Polish naming overlap**: existing localization keys use snake_case `prop.apple`, `prop.barn`. New keys must follow same scheme (`prop.shuriken`, `prop.dojo_pillar`, `prop.neon_sign`). Add to `data/localization/pl.csv` in same PR — `_t()` will hard-fail otherwise.
- **Phonk lyrics**: Even instrumentals are sometimes mis-tagged. Run all Pixabay/itch.io tracks through a quick STT moderation pass (re-use existing voice_input_moderation_service.gd) before bundling, to catch any spoken-word phonk.
- **HDRI file size**: Single 8K HDRI can be 100+ MB. Use 2K versions only for runtime; keep 8K source out of distribution.

## Sources
- https://quaternius.com/
- https://quaternius.itch.io/universal-animation-library
- https://quaternius.com/packs/universalbasecharacters.html
- https://gamefromscratch.com/quaternius-free-3d-assets/
- https://kenney.nl/
- https://kenney.nl/assets/blocky-characters
- https://kenney.nl/assets/particle-pack
- https://kaylousberg.itch.io/kaykit-adventurers
- https://kaylousberg.itch.io/kaykit-skeletons
- https://kaylousberg.itch.io/kaykit-dungeon-remastered
- https://kaylousberg.itch.io/kaykit-character-animations
- https://godotengine.org/asset-library/asset/2566
- https://godotengine.org/asset-library/asset/2129
- https://helpx.adobe.com/creative-cloud/faq/mixamo-faq.html
- https://www.syntystudios.com/
- https://syntystore.com/community/faq
- https://pixabay.com/music/search/drift%20phonk/
- https://pixabay.com/music/phonk-phonk-music-drift-phonk-2026-472829/
- https://tallbeard.itch.io/music-loop-bundle
- https://freesound.org/
- https://soundimage.org/
- https://soundimage.org/attribution-info/
- https://opengameart.org/content/cc0-textures-0
- https://opengameart.org/content/special-effects-cc0
- https://opengameart.org/content/huge-cc0-asset-release-from-glitch
- https://opengameart.org/content/cc0-special-effects
- https://ambientcg.com/
- https://ambientcg.com/list?q=concrete
- https://polyhaven.com/hdris/urban/night
- https://polyhaven.com/a/shanghai_bund
- https://poly.pizza/
- https://poly.pizza/search/ninja
- https://poly.pizza/search/katana
- https://texture.ninja/
- https://github.com/madjin/awesome-cc0
- https://fonts.google.com/specimen/Rubik+Glitch
- https://fonts.google.com/specimen/Audiowide
- https://fonts.google.com/specimen/Rajdhani
- https://fonts.google.com/specimen/Orbitron
- https://fonts.google.com/specimen/Zen+Dots
- https://developers.google.com/fonts/faq
- https://itch.io/soundtracks/tag-phonk
- https://itch.io/game-assets/assets-cc0/tag-music

Report by deep-research-free-assets, ready for synthesis.
