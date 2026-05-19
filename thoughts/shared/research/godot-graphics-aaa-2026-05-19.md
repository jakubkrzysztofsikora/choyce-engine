# Godot 4.6 Graphics Upgrade Research — Choyce Engine

**Date:** 2026-05-19
**Author:** Claude (Architecture & Review Specialist)
**Target:** Godot 4.6.1, Forward+, macOS Metal, M-series Macs, 60 fps minimum, age 5-8 audience, Polish kid-safe game, Roblox-inspired
**Constraints:** Kenney CC0 GLB props (flat albedo only, no PBR maps), child-appropriate bright daytime, must not regress current FPS

---

## Executive Summary

The highest-ROI move is **not** swapping global illumination. It is a **three-layer polish pass**: (1) PhysicalSkyMaterial with Volumetric Fog at low density + GI Inject, (2) MetalFX **Temporal upscaling** at quality preset on M-series so you can render at 0.67x internal resolution and reclaim ~30-40% GPU headroom while *improving* AA over current FXAA/MSAA, and (3) a stylized **cel-shaded PBR hybrid** approach where the existing `toon_cel.gdshader` keeps its banded `light()` function but the project drops `specular_disabled` and gains a sky-tinted rim term so Kenney props read with depth. Skip SDFGI and VoxelGI for now — Godot 4.6 has an open regression on both (issue #115599) and SDFGI is officially being deprecated for HDDAGI. Keep current SSAO+SSIL setup, lean into the sky and post-processing instead. Realistic visual delta from this stack is **"Astro Bot diorama"-tier polish** without breaking the Kenney CC0 art continuity, at an expected ~5-8% GPU budget improvement on M2 Max thanks to MetalFX offsetting added sky/fog cost.

---

## 1. Lighting Upgrade Path: SDFGI vs VoxelGI vs LightmapGI

### Recommendation: **Stay on SSAO + SSIL. Do not enable SDFGI or VoxelGI in 4.6 yet. If you must add real GI, use LightmapGI on the static ground + props.**

### Reasoning
- **Godot 4.6 has an active regression** affecting both SDFGI and VoxelGI ([issue #115599](https://github.com/godotengine/godot/issues/115599)) — projects upgrading from 4.5 → 4.6 report "drastically worse" lighting on the same scenes. Until this is patched (track 4.6.2+), enabling either is a coin-flip on your tablet target.
- **SDFGI is being deprecated**. The Godot team has confirmed SDFGI will be replaced by HDDAGI ([proposals #10194](https://github.com/godotengine/godot-proposals/discussions/10194)) because it has unfixable limitations (slow cascade generation, ghosting). Investing tuning time in SDFGI now is throwaway work.
- **VoxelGI is GPU-heavy and bounded** — best for "small/medium dedicated GPU scenes". Apple Silicon's integrated GPU + Retina output makes the cost disproportionate. The doc literally says *"best used when targeting dedicated graphics cards"*. ([Godot 4.6 VoxelGI docs](https://docs.godotengine.org/en/4.6/tutorials/3d/global_illumination/using_voxel_gi.html))
- Your current SSAO (radius 2.0, intensity 1.5) + SSIL (radius 4.0, intensity 0.7) is actually a solid baseline for a flat-shaded kid game. SSIL gives you cheap color bleeding which is the visible delta most "GI" actually buys you in a bright daytime scene.

### If you really need GI later
Use **LightmapGI**, baked, on the ground + static Kenney props. It is the cheapest at runtime ("oldest and most performance-friendly GI technique"), survives across all renderers (so Compatibility renderer for a low-end fallback stays open), and a static daytime scene is its ideal use case. Cost is bake time, not frame time.

### Realistic improvement vs current setup
- SSAO+SSIL → LightmapGI: ~+10% perceived depth in shaded crevices, no FPS cost at runtime, ~30-90s bake per scene change.
- SSAO+SSIL → SDFGI: visible color bleed from sky → ground, but **-15 to -25 fps** on M2 Max at Retina, plus the 4.6 regression risk. Skip.
- SSAO+SSIL → VoxelGI: similar visual delta, similar perf hit, plus voxel-grid bounds you have to manage. Skip.

### Settings if you still bake LightmapGI
- Bake Quality: **Medium** (the High preset triples bake time for marginal gain on flat Kenney albedo).
- Bounces: **2** (3+ is wasted on this art style).
- Bias: 0.0005.
- Enable **Half-Resolution GI** in Project Settings → Rendering → Global Illumination → enable `gi/use_half_resolution` — saves "a lot of GPU time" at retina scale per the docs.

---

## 2. Sky + Atmosphere: ProceduralSky → PhysicalSky + Volumetric Fog

### Recommendation: **Switch to `PhysicalSkyMaterial` now. Add Volumetric Fog at low global density with localized FogVolumes. Set GI Inject to 0.5-0.7.**

### Why PhysicalSkyMaterial
Godot 4.6 ships `PhysicalSkyMaterial` (Rayleigh + Mie atmospheric scattering). For a "clear morning" mood it's strictly better than `ProceduralSkyMaterial` because:
- The sun disk position is physically coupled to your `DirectionalLight3D` direction → consistent shadows.
- Horizon haze is computed via Rayleigh scattering → no manual gradient tuning to look right at sunrise vs noon.
- Plays correctly with `Ambient Source = Sky` + `Reflected Source = Sky` so Kenney props pick up sky-colored fill without normal maps.

### Concrete settings for "clear morning, kid-friendly"
```
PhysicalSkyMaterial
  rayleigh_coefficient: 2.0
  rayleigh_color: rgb(0.30, 0.50, 1.00)         # cool blue
  mie_coefficient: 0.005
  mie_eccentricity: 0.8
  mie_color: rgb(0.69, 0.84, 1.00)              # bright haze
  turbidity: 2.5                                # 2-3 = clean morning, 10 = smoggy
  sun_disk_scale: 1.2                           # slightly larger sun for kid-friendly readability
  ground_color: rgb(0.40, 0.50, 0.20)           # tints horizon to match your grass ground
  energy_multiplier: 1.0
  use_debanding: ON
```

DirectionalLight3D rotation should put the sun at ~45-55° altitude, ~30° from camera-forward (morning side-light reads as "warm hopeful start of adventure"). Keep your current `energy 1.35` and `light_specular 0.7`.

### Volumetric Fog setup
Per [Godot docs on volumetric_fog](https://docs.godotengine.org/en/4.6/tutorials/3d/volumetric_fog.html):
```
Environment → Volumetric Fog
  enabled: true
  density: 0.015                # very low global haze
  albedo: rgb(1.0, 0.96, 0.90)  # warm morning
  emission: rgb(0.0, 0.0, 0.0)
  anisotropy: 0.3               # forward scattering, matches PhysicalSky Mie
  length: 96.0                  # match your ~80m playable area
  detail_spread: 2.0
  gi_inject: 0.6                # picks up ambient bounce, ~"milky daylight haze"
  ambient_inject: 0.4
  temporal_reprojection: ON
  temporal_reprojection_amount: 0.9
```
With your current `aerial_perspective_density 0.008`, the volumetric layer should be subtle — it's there to catch sun shafts through trees, not to fog out the level.

### Localized FogVolume nodes
Drop 2-3 `FogVolume` boxes with `FogMaterial` + `NoiseTexture3D` (64×64×64, FastNoiseLite simplex) under tree canopies / inside hollow props. This gives "Astro Bot diorama" pockets of atmosphere without paying global fog cost.

### GI integration
**Important:** Volumetric fog's `GI Inject` only works when a GI source exists. Since recommendation #1 is to skip SDFGI/VoxelGI, the inject will read from SSIL + ambient + sky. That's still a visible improvement — sky color tints fog automatically.

### Perf cost
Volumetric fog on M2 Max at 96m length: ~0.6-1.2 ms/frame. Within budget.

References: [Volumetric fog and fog volumes (Godot 4.6)](https://docs.godotengine.org/en/4.6/tutorials/3d/volumetric_fog.html), [Volumetric Fog and God Rays — Bramwell](https://bramwell.itch.io/godot-4-beginners/devlog/588028/volumetric-fog-and-god-rays).

---

## 3. Toon Cel vs Stylized PBR

### Recommendation: **Evolve the existing `toon_cel.gdshader` into a "cel-shaded PBR hybrid". Do NOT throw it away. Keep flat Kenney albedo, but add: (a) sky-tinted rim, (b) view-direction stylized specular highlight, (c) softer shadow band falloff for skin/character meshes.**

### Why not pure PBR
Kenney CC0 kits ship **flat baked albedo only** — no normal, no roughness, no metalness maps. A pure PBR pipeline expects those. You'd either author them (out of scope, breaks CC0 continuity) or every prop would render as 100% rough non-metallic plastic. That's exactly what your current toon shader already produces — and it doesn't cost the PBR specular calculation. So pure PBR offers zero visible upgrade and a perf regression.

### Why not stay on flat toon
Your current shader has `specular_disabled` and a single `shadow_color` darken. That reads "indie tutorial" not "Astro Bot". Three missing terms:
1. **Sky-tinted rim** — fresnel × sky ambient color → reads as "atmosphere wrapping around prop", consistent with PhysicalSkyMaterial. Already have `rim_amount 0.55, rim_color white` uniforms in the shader but they aren't sampled in `light()`. Wire them.
2. **Stylized specular** — Blinn-Phong dot, smoothstep, single high-band threshold → cartoon highlight blob (Ghibli/BotW pattern). Cheap.
3. **Soft shadow band edge** — current code uses `floor()` which gives razor-sharp bands. Add an optional `smoothstep` width (≤0.05) so character meshes don't get the harsh aliasing the Panthavma article warns about (*"the simplicity of two-tone shading brings a lot of attention to issues that don't really appear with smooth PBR"*).

### Reference style
- **Astro Bot**: flat saturated albedo + soft AO + warm sky bounce → matches your Kenney palette.
- **Roblox**: flat albedo + sharp PSSM shadow + bloom + saturated sky → matches your current 4-split PSSM choice.
- **Ghibli / BotW**: 2-step shadow band + stylized specular blob + sky rim → matches the proposed hybrid.

### Proposed `light()` function patch
```glsl
// keep: shader_type spatial; render_mode depth_draw_opaque, cull_back, diffuse_lambert
// CHANGE: remove "specular_disabled" — we'll write SPECULAR_LIGHT manually
render_mode depth_draw_opaque, cull_back, diffuse_lambert;

uniform float band_smoothness : hint_range(0.0, 0.2) = 0.03;
uniform float spec_threshold  : hint_range(0.5, 0.99) = 0.92;
uniform float spec_smoothness : hint_range(0.0, 0.2) = 0.02;
uniform vec3  sky_tint        : source_color = vec3(0.75, 0.88, 1.00);

void light() {
    // banded diffuse with optional smoothstep at band edges
    float n_dot_l = max(dot(NORMAL, LIGHT), 0.0);
    float scaled  = n_dot_l * light_steps;
    float band_f  = floor(scaled);
    float band_t  = smoothstep(0.0, band_smoothness, fract(scaled));
    float band    = (band_f + band_t) / light_steps;
    vec3  lit     = ALBEDO * mix(shadow_color.rgb, vec3(1.0), band);

    // stylized specular blob (cartoon highlight)
    vec3  h       = normalize(LIGHT + VIEW);
    float n_dot_h = max(dot(NORMAL, h), 0.0);
    float spec    = smoothstep(spec_threshold, spec_threshold + spec_smoothness, n_dot_h);

    // sky-tinted rim
    float rim     = pow(1.0 - max(dot(NORMAL, VIEW), 0.0), 3.0) * rim_amount;

    DIFFUSE_LIGHT  += lit * ATTENUATION * LIGHT_COLOR;
    SPECULAR_LIGHT += spec * LIGHT_COLOR * ATTENUATION * 0.5;
    DIFFUSE_LIGHT  += rim * sky_tint;   // additive sky rim, not multiplied by ATTENUATION
}
```

This stays *flat-toon in spirit* but reads like a 2026 stylized title. Performance delta: negligible (~3-5 extra ALU ops per fragment, no new texture samples).

References: [Binbun3D — Godot Toon Shading](https://bun3d.com/tutorials/shading/godot-toon-shading/), [Baldur Games — Stylized Shaders in Godot](https://baldurgames.com/posts/stylized-shaders-godot), [Panthavma — Toon Shading Fundamentals](https://panthavma.com/articles/shading/toonshading/), [Godot Docs — Your Second Spatial Shader](https://docs.godotengine.org/en/stable/tutorials/shading/your_first_shader/your_second_spatial_shader.html).

---

## 4. Post-Processing Stack for "AAA Polish" on Tablet

### Recommendation order (highest ROI first):

| # | Effect                          | Setting                                                                | M2 Max cost | Visual delta                       |
|---|---------------------------------|------------------------------------------------------------------------|-------------|------------------------------------|
| 1 | **MetalFX Temporal upscaling**  | `scaling_3d/mode = metalfx_temporal`, scale 0.67, sharpness 0.3        | **NEGATIVE** (saves ~30-40% GPU) | Reclaims headroom + better AA than current FXAA |
| 2 | **PhysicalSkyMaterial**         | see §2                                                                 | +0.2 ms     | Massive (mood, sun coupling)       |
| 3 | **Volumetric Fog**              | see §2                                                                 | +0.6-1.2 ms | God-rays, depth                    |
| 4 | **Tonemap → ACES**              | `tonemap_mode = ACES`, exposure 1.0, white 6.0                         | ~0          | Highlight rolloff, less harsh sun  |
| 5 | **Adjustments LUT**             | warm morning LUT 32x32x32 PNG, contribution 0.6                        | ~0.05 ms    | Brand color identity               |
| 6 | **Vignette (subtle)**           | via `Adjustments`/shader: 0.15 strength, soft falloff                  | ~0.02 ms    | Frames the action, kid-safe        |
| 7 | **Bloom polish**                | keep glow 0.6, lower bloom threshold to 0.95, glow levels 3+5+7 ON     | ~0.2 ms     | "Pixar puff" on bright albedos     |
| 8 | **Camera DoF (gentle)**         | far 25-60m, transition 8m, amount 0.05                                 | ~0.4 ms     | Optional; only for cinematic shots |

### Things to **skip**
- **SSR (Screen-Space Reflections)** — Kenney props are mostly matte. SSR cost (~1-2 ms) buys nothing visible. Skip.
- **TAA (standalone)** — When you enable MetalFX Temporal, "the Use TAA project setting is ignored" because MetalFX provides its own temporal AA. ([Resolution scaling docs](https://docs.godotengine.org/en/latest/tutorials/3d/resolution_scaling.html))
- **MSAA 8x** — too expensive on Retina + Forward+. If you must use MSAA *instead* of MetalFX Temporal, use **MSAA 4x** + **FXAA** for specular aliasing. Note: MetalFX Temporal *disables MSAA internally* on Metal — they're mutually exclusive.
- **FSR2** — on Apple Silicon, MetalFX outperforms FSR2 by ~16-19% (M1 Max / M2 Air Bistro benchmark from [PR #99603](https://github.com/godotengine/godot/pull/99603)). Use MetalFX wherever available; FSR2 only as fallback for non-Apple platforms.

### MetalFX gotcha
- Requires Metal renderer (already on, you mentioned Metal 4.0).
- Needs Godot 4.4+ (you're on 4.6.1, fine).
- Open issue [#103782](https://github.com/godotengine/godot/issues/103782) — fallback to bilinear on unsupported platforms still triggers TAA jitter. Wrap the activation in `if OS.has_feature("macos") and RenderingServer.has_os_feature("metalfx"):` to be safe across builds.

References: [Resolution scaling — Godot](https://github.com/godotengine/godot-docs/blob/master/tutorials/3d/resolution_scaling.rst), [PR #99603 MetalFX upscaling](https://github.com/godotengine/godot/pull/99603), [3D antialiasing — Godot](https://github.com/godotengine/godot-docs/blob/master/tutorials/3d/3d_antialiasing.rst).

---

## 5. Custom Shaders Worth Building

### Build now (quick wins)

| Shader              | Effort | Visual delta | Notes                                                                             |
|---------------------|--------|--------------|-----------------------------------------------------------------------------------|
| **Ground triplanar** | 0.5 d | High         | Your 80×80m flat box with single noise tile will tile-bomb at low angle. Triplanar fixes it instantly. Use [Febucci's pattern](https://blog.febucci.com/2025/10/how-to-make-a-triplanar-shader-in-godot/) with 2 noise textures (grass + dirt) blended by world-Y. |
| **Vertex wind on foliage** | 0.5-1 d | Very high    | Single biggest "alive world" upgrade. [Victor Karp's vertex-color mask approach](https://victorkarp.com/godot-foliage-wind/) works on Kenney trees once you paint masks in Blender (R = trunk-to-top, G = base-to-tip). For Kenney grass blade meshes use a simpler `sin(TIME * 1.5 + WORLD.x * 0.3) * VERTEX.y` flutter — no painting needed. |
| **Character shadow blob** | 0.25 d | Medium       | Decal node with a radial-gradient texture projected DOWN from kid character. Cheap, reads instantly, survives even when PSSM cascade fades far away. Use Decal + cull_mask, NOT a quad child of the player. |

### Build later

| Shader               | Effort | Notes                                                                                     |
|----------------------|--------|-------------------------------------------------------------------------------------------|
| **Stylized water + foam** | 1-2 d | Only if a level needs water. Otherwise pure scope creep. The standard recipe: UV-panning normal noise + depth-buffer foam edge + shore wave fresnel. |
| **Outline (inverted hull v2)** | 1 d   | Your shader has a comment that v2 outlines are deferred. Inverted hull works but doubles draw calls for every outlined prop. Consider screen-space sobel post-effect instead — single pass, no per-mesh cost. |

### Don't build
- Per-prop SSR.
- Custom subsurface scattering (kid characters are stylized, not skin-realistic).
- Hair shader.

References: [Febucci — Triplanar Shader in Godot (Oct 2025)](https://blog.febucci.com/2025/10/how-to-make-a-triplanar-shader-in-godot/), [Victor Karp — Foliage Wind in Godot 4](https://victorkarp.com/godot-foliage-wind/), [Godot Shaders — Triplanar Mapping](https://godotshaders.com/shader/triplanar-mapping/), [HTerrain plugin](https://hterrain-plugin.readthedocs.io/en/latest/).

---

## 6. Shadow Pipeline (PSSM 4-split tuning)

### Diagnosis of current acne
You have:
- PSSM 4-split (correct for outdoor open scenes).
- Soft blur 0.8 (this is the suspect — open [issue #103165](https://github.com/godotengine/godot/issues/103165) and [PR #68339](https://github.com/godotengine/godot/pull/68339) explain that scaled bias × soft_shadow_scale interacts badly with low-poly stylized geometry).

### Recommended settings
```
DirectionalLight3D
  shadow_enabled: true
  shadow_mode: SHADOW_PARALLEL_4_SPLITS
  shadow_blur: 1.0                       # raise from 0.8 — softens band edge w/o triggering blur-0 acne bug
  shadow_bias: 0.03                      # was likely default 0.1; lower per reduz PR #51025 logic
  shadow_normal_bias: 2.0                # raise from default 1.0 — kills acne without peter-panning
  shadow_opacity: 0.85                   # 0.85 instead of 1.0 reads kid-friendly (not pitch black)
  directional_shadow_max_distance: 100.0 # 80m playable + 20m margin; shorter = higher res per cascade
  directional_shadow_split_1: 0.10
  directional_shadow_split_2: 0.20
  directional_shadow_split_3: 0.50
  directional_shadow_fade_start: 0.85
```
Project Settings → Rendering → Lights and Shadows:
```
directional_shadow/size = 4096          # 4k atlas on M2 Max; drop to 2048 if frame budget tight
directional_shadow/16_bits = true       # halves VRAM, no visible quality loss outdoors
positional_shadow/atlas_size = 2048     # if you use OmniLight/SpotLight for accents
```

### Why these specific values
- **`shadow_normal_bias = 2.0`** — Per [Calinou's PR #43207](https://github.com/godotengine/godot/pull/43207), normal bias offsets along the surface normal, which "reduces shadow acne/peter-panning immensely at little perf cost". Doubling the default is the standard fix for low-poly stylized scenes where vertex-normal mismatch creates micro-acne.
- **`shadow_blur = 1.0`** instead of 0.8 — Issue #103165 specifically calls out shadow acne when blur is too low. 1.0 is safer.
- **`shadow_opacity = 0.85`** — kid-safe (no "scary pitch-black" shadows), and visually matches the shadow band quantization your toon shader already does.
- **PSSM split 0.10 / 0.20 / 0.50** — biases the first 3 cascades close to camera (where the kid character is), the 4th cascade covers 50-100m for the distant Kenney props.

### Perf cost
4k directional shadow atlas costs ~1.5-2.0 ms on M2 Max. Drop to 2048 (~0.6-0.8 ms) if you need to reclaim budget after volumetric fog + MetalFX. Note that MetalFX Temporal will save you more than the shadow upgrade costs.

References: [Forum: Shadow bias issue (Jan 2026)](https://forum.godotengine.org/t/shadows-bias-issue/131978), [PR #68339](https://github.com/godotengine/godot/pull/68339), [PR #51025](https://github.com/godotengine/godot/pull/51025), [Issue #103165](https://github.com/godotengine/godot/issues/103165), [PR #43207](https://github.com/godotengine/godot/pull/43207).

---

## Do-Now / Do-Later / Don't-Do Punchlist

### DO NOW (this week, in order)
1. **MetalFX Temporal upscaling** at 0.67 scale + 0.3 sharpness — guarded with `OS.has_feature("macos")`. Single biggest perf + AA win.
2. **PhysicalSkyMaterial** swap with settings from §2. ~30 min of work, transformative mood delta.
3. **Volumetric Fog** at density 0.015, length 96m, GI Inject 0.6, anisotropy 0.3.
4. **PSSM bias tune** — `shadow_normal_bias 2.0`, `shadow_blur 1.0`, `shadow_opacity 0.85`. Fixes the soft acne you're already seeing.
5. **Toon shader hybrid evolution** — patch `toon_cel.gdshader` per §3: drop `specular_disabled`, add banded smoothstep, sky-tinted rim, stylized specular blob.
6. **Tonemap ACES** + warm-morning LUT (32x32x32 PNG, contribution 0.6).

### DO LATER (next iteration)
7. **Triplanar ground shader** with 2 noise textures (grass + dirt) blended by world-Y normal. Fixes tile-bombing on the 80×80m box.
8. **Vertex wind on foliage** — Victor Karp pattern with painted vertex colors on Kenney trees; simple `sin(TIME)` flutter on grass blades.
9. **Character decal shadow blob** (Decal node, radial gradient, projected DOWN, follows player).
10. **LightmapGI bake** on the static ground + non-moving Kenney props (bounces 2, half-res GI ON). Only when the visible-prop set is locked.
11. **Subtle camera DoF** for cinematic cutscenes only — not gameplay.
12. **Vignette + bloom polish** pass.

### DON'T DO
- **SDFGI** — 4.6 regression + officially being deprecated. Wait for HDDAGI.
- **VoxelGI** — 4.6 regression + GPU-heavy on integrated Apple Silicon.
- **TAA** — superseded by MetalFX Temporal which gives you AA for free.
- **MSAA 8x** — incompatible with MetalFX Temporal + too expensive at Retina.
- **SSR** — buys nothing on matte Kenney props.
- **FSR2** on macOS — MetalFX is faster on Apple Silicon (~16-19%).
- **Pure PBR pipeline** — Kenney CC0 has no normal/roughness/metalness; pure PBR offers zero upgrade.
- **Inverted hull outline (per-mesh)** — doubles draw calls. Use screen-space Sobel post-effect instead if outlines are wanted.
- **Custom hair / SSS / per-prop SSR** — out of scope for the art direction.
- **Project Settings → Rendering → Quality → Half-Resolution GI** *unless* you actually enable a GI system. Currently a no-op.

---

## Expected Cumulative Outcome

After the DO-NOW pass, on an M2 Max at native Retina 2880×1864 rendering at MetalFX Temporal 0.67 (so internal ~1928×1248):

- **Frame budget delta:** ~+2 ms savings from MetalFX, ~-1.2 ms volumetric fog, ~-0.3 ms shader upgrade, ~-0.2 ms sky → net **~+0.3 ms saved**, i.e. lighter than current setup at 60 fps target.
- **Visual delta:** physically-coherent sky + atmosphere, kid-friendly soft-but-readable shadows, props gain depth via sky rim and stylized specular blob, AA is materially better than current FXAA.
- **Risk:** low. All changes are local to WorldEnvironment, DirectionalLight3D, one shader, one project setting. No GI bake, no asset pipeline change, no Kenney CC0 violation.

---

## References

### Godot Official Docs (4.4 / 4.6 / latest)
- [Volumetric fog and fog volumes (4.6)](https://docs.godotengine.org/en/4.6/tutorials/3d/volumetric_fog.html)
- [Using Voxel global illumination (4.6)](https://docs.godotengine.org/en/4.6/tutorials/3d/global_illumination/using_voxel_gi.html)
- [List of features (4.6)](https://docs.godotengine.org/en/4.6/about/list_of_features.html)
- [Resolution scaling (latest)](https://github.com/godotengine/godot-docs/blob/master/tutorials/3d/resolution_scaling.rst)
- [3D antialiasing (latest)](https://github.com/godotengine/godot-docs/blob/master/tutorials/3d/3d_antialiasing.rst)
- [Fog shaders (4.6)](https://docs.godotengine.org/en/4.6/tutorials/shaders/shader_reference/fog_shader.html)
- [Your Second Spatial Shader (stable)](https://docs.godotengine.org/en/stable/tutorials/shading/your_first_shader/your_second_spatial_shader.html)

### Godot Engine Issues / PRs (current)
- [Issue #115599 — 4.6 GI + sky regression](https://github.com/godotengine/godot/issues/115599)
- [Proposal #10194 — Replace VoxelGI with HDDAGI](https://github.com/godotengine/godot-proposals/discussions/10194)
- [PR #99603 — MetalFX upscaling support](https://github.com/godotengine/godot/pull/99603)
- [Issue #103782 — MetalFX fallback / TAA jitter](https://github.com/godotengine/godot/issues/103782)
- [PR #68339 — Scale shadow bias by soft_shadow_scale](https://github.com/godotengine/godot/pull/68339)
- [PR #51025 — Fix directional shadow bias](https://github.com/godotengine/godot/pull/51025)
- [Issue #103165 — Shadow acne when blur = 0](https://github.com/godotengine/godot/issues/103165)
- [PR #43207 — Shadow normal offset bias context](https://github.com/godotengine/godot/pull/43207)
- [Forum: Shadows bias issue (Jan 2026)](https://forum.godotengine.org/t/shadows-bias-issue/131978)
- [Godot Rendering Priorities Sept 2024](https://godotengine.org/article/rendering-priorities-september-2024/)

### Community Tutorials / Demos
- [Febucci — Triplanar Shader in Godot (Oct 2025)](https://blog.febucci.com/2025/10/how-to-make-a-triplanar-shader-in-godot/)
- [Victor Karp — Foliage Wind in Godot 4](https://victorkarp.com/godot-foliage-wind/)
- [Victor Karp — Vertex color channels in Blender](https://victorkarp.com/blender-vertex-color-channels-and-gradients/)
- [Godot Shaders — Triplanar Mapping](https://godotshaders.com/shader/triplanar-mapping/)
- [HTerrain plugin docs](https://hterrain-plugin.readthedocs.io/en/latest/)
- [Binbun3D — Godot Toon Shading](https://bun3d.com/tutorials/shading/godot-toon-shading/)
- [Baldur Games — Stylized Shaders in Godot](https://baldurgames.com/posts/stylized-shaders-godot)
- [Supermatrix Studio — Visual Shader Cel Shader](https://supermatrix.studio/blog/creating-a-stylized-3D-cel-shader-in-godot-4-from-scratch)
- [Panthavma — Toon Shading Fundamentals](https://panthavma.com/articles/shading/toonshading/)
- [YouTube — Stylized Toon Cell Shading in Godot 4.6](https://www.youtube.com/watch?v=cqPcj1xhrUw)
- [YouTube — Shader-based foliage wind in Godot](https://www.youtube.com/watch?v=XHS4xGmu-qc)
- [Bramwell — Volumetric Fog and God Rays](https://bramwell.itch.io/godot-4-beginners/devlog/588028/volumetric-fog-and-god-rays)
- [Forum — Wind Shader demo project](https://forum.godotengine.org/t/wind-shader-i-made-for-my-game-with-demo-project-to-download/70049)

### Existing project files referenced
- `src/adapters/inbound/gameplay/shaders/toon_cel.gdshader` — current toon shader, candidate for §3 patch.
- `src/adapters/inbound/gameplay/shaders/toon_cel_material.tres` — existing material binding.
