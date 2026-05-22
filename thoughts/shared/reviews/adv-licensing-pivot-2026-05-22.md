# Adversarial License + IP Audit — choyce-engine pivot assets (`eeaeebd..f683184`)

Reviewer: Claude (architecture/review specialist). Scope: 7 commits, asset trees under `data/`.

---

## P0 — Release blockers

### P0-1. Root `NOTICES.md` is incomplete: fonts, textures/voxel, vfx/voxel are not catalogued
`NOTICES.md` (root) lists only `data/models/{kaykit,quaternius}`, `data/textures/voxel/` (claims Kenney/ambientCG), `data/vfx/voxel/` (claims Kenney/Pixel Frog/OpenGameArt), `data/audio/music/voxel/`. Yet committed asset trees include:
- `data/fonts/voxel/{rubik_glitch,audiowide,rajdhani}/` — **no entry in root NOTICES.md**
- `data/textures/voxel/polyhaven_hdri/` — **no entry**
- `data/textures/voxel/glitch_overlays/` — **no entry** (procedural CC0)
- `data/vfx/voxel/vdb_volumes/` — **no entry** (procedural CC0)
- `data/vfx/voxel/kenney_particles/` — listed as Kenney Particle Pack but the on-disk files are 8 procedural extensions, not the real pack
- `data/models/kenney/`, `data/models/mascot/`, `data/models/props/` — tracked but unattributed in either NOTICES.md

Per the CI gate's own contract ("authoritative attribution catalog … every asset source listed here corresponds to a pack that the engine consumes"), this fails. Remediation: append `### data/fonts/voxel/`, `### data/textures/voxel/polyhaven_hdri/`, `### data/textures/voxel/glitch_overlays/`, `### data/vfx/voxel/vdb_volumes/`, `### data/vfx/voxel/kenney_particles/` (procedural extensions), `### data/models/{kenney,mascot,props}/` blocks.

### P0-2. CI gate is structurally bypassable
`.github/workflows/notices-gate.yml:21` triggers only `on: pull_request`. The five asset-landing commits (`2becff3`, `2b9c795`, `b295d0b`, `9500421`, plus voxel music) were direct merges of squashed worktree branches — not PRs against `main`. The gate never ran. Furthermore the gate only verifies that `NOTICES.md` was *touched in the same diff*, not that the new asset paths actually appear as entries. Trivial false-negative: add `data/foo/secret.glb` + append a whitespace-only line to NOTICES.md → green.

Remediation snippet (extend gate):
```bash
# After "NOTICES.md updated" check:
for f in $data_real_changes; do
  top="$(printf '%s\n' "$f" | cut -d/ -f1-3)/"
  if ! grep -qF "### $top" NOTICES.md; then
    echo "ERROR: $f lives under $top but no '### $top' heading exists in NOTICES.md"
    exit 1
  fi
done
```
Also add a `push: branches: [main]` trigger so direct merges are not exempt.

### P0-3. Kenney "Music Loops/Jingles" attribution does not match shipped tracks
Root `NOTICES.md:55-58` credits `data/audio/music/voxel/` to Kenney + Joel Steudler + Free Music Archive. The directory's own `NOTICES.md` correctly credits **Freesound contributors** (Doctor_Dreamchip, SouljaUnit, ir0nwave, HAHAVOID, kontraamusic). Root catalog contradicts ground truth — attribution chain breaks. Fix root entry to match the per-directory truth:
```
### data/audio/music/voxel/
- Doctor_Dreamchip / Freesound (CC0) - https://freesound.org/people/Doctor_Dreamchip/
- SouljaUnit / Freesound (CC0) - https://freesound.org/people/SouljaUnit/
- ir0nwave / Freesound (CC0)
- HAHAVOID / Freesound (CC0)
- kontraamusic / Freesound (CC0)
```

### P0-4. Procedural-CC0 declarations by an AI agent — chain-of-title risk
`data/textures/voxel/glitch_overlays/LICENSE.txt`, `data/textures/voxel/polyhaven_hdri/LICENSE.txt` (placeholder branch), `data/vfx/voxel/vdb_volumes/LICENSE.txt`, `data/vfx/voxel/kenney_particles/LICENSE.txt` all declare CC0 for "ORIGINAL PROCEDURAL WORKS generated locally by scripts/assets/gen_*.py". The author is a Claude-Code agent invoked by the user. Under EU + US copyright doctrine the human who configured/ran the script is the rights-holder; CC0 is valid only when that human applies it. Add explicit declaration:
```
Author: Jakub Sikora (jksikora90@gmail.com), via scripts/assets/gen_glitch_overlays.py
Date: 2026-05-22
The author hereby releases these files into the public domain under CC0 1.0.
```
Place in each procedural directory. Without this, the CC0 claim is unenforceable in Poland (PL copyright law has no public-domain dedication; only `licencja CC0` with explicit waiver by the natural-person author works).

---

## P1 — Pre-shipping must-fix

### P1-1. Rubik Glitch OFL has corrupted copyright URL
`data/fonts/voxel/rubik_glitch/OFL.txt:1` reads:
```
Copyright 2020 The Rubik Filtered Project Authors (https://https://github.com/NaN-xyz/Rubik-Filtered)
```
Double `https://https://`. OFL §1 requires preserving the original copyright notice verbatim; a corrupted URL is a modification of the OFL header. Restore to the upstream Google Fonts / Rubik Glitch repo line. Verify the other two OFL bodies match SIL upstream (Audiowide uses `http://scripts.sil.org/OFL`, Rajdhani uses same; SIL canonical is `https://`).

### P1-2. KayKit Poly Pizza provenance not authoritative
`data/models/NOTICES.md` ships 7 KayKit GLBs sourced via **Poly Pizza** because itch.io was firewalled. Poly Pizza re-hosts under its own IDs (`itasw0GWNf`, `Gq38E7hFZw`, etc.) but the **original** author (Kay Lousberg) and the **original** pack name (e.g. "KayKit Dungeon Remastered") must both be credited. Current table omits the upstream pack name per row. Also: Kay Lousberg's CC0 terms on itch.io carry no "no-ai" restriction on inference; the `no-ai` tag on his pages means "I didn't use AI to make this" — confirmed safe for use alongside bundled Ollama. Add a second column "Original pack" to the table.

### P1-3. Procedural Poly Haven LICENSE still claims procedural — stale after commit `9500421`
`data/textures/voxel/polyhaven_hdri/LICENSE.txt` still describes the file as "CC0 PROCEDURAL PLACEHOLDER generated locally". Commit `9500421` swapped in the real 6.4 MB Greg Zaal HDR (verified `file` reports `Radiance HDR image data`, 8.4 MB→6.5 MB size drop in diff stats). LICENSE.txt now misrepresents the file. Replace body with the actual Poly Haven CC0 + author credit:
```
shanghai_bund_2k.hdr
Source:  https://polyhaven.com/a/shanghai_bund (2K .hdr, 6.5 MB)
Author:  Greg Zaal
License: CC0 1.0 Universal — https://creativecommons.org/publicdomain/zero/1.0/
Credit recommended (not required). Downloaded 2026-05-22 by Jakub Sikora.
```

### P1-4. `manifest.yaml packs: []` is empty — fetch script declares zero packs
The catalog says "every asset source listed here corresponds to a pack that the engine consumes" and points to `manifest.yaml`, yet the manifest contains **no packs**. The shipped trees were filled by ad-hoc curl/worktree commits, not by `fetch_free_assets.sh`. Either populate the manifest with the 7 KayKit + 5 Quaternius + Polyhaven + ambientCG + 10 Freesound entries (with real SHA-256), or document in `manifest.yaml` that the v1 ship is git-bundled and the fetch path is reserved for v2 community packs.

---

## P2 — Should-fix

### P2-1. Pixabay phonk backup not yet shipped — verify clauses before importing
`data/audio/music/voxel/NOTICES.md:31` flags Pixabay phonk as a future expansion source under "Pixabay Content License". That license explicitly bans "sale or resale of unaltered content" and prohibits "redistribution of Content on similar stock/wallpaper platforms". A premium kid-app sold on Polish app stores **bundles** but does not **redistribute as stock**, so the inclusion-in-a-product carve-out applies. However the license also blocks any track depicting "identifiable persons" or "registered brands/logos" in audio metadata. When the Pixabay track ban lifts, run `id3v2 -l` on each file to confirm no embedded artwork/branding before importing. Block via manifest until verified.

### P2-2. Music tracks: `hahavoid_type_beat`, `tokyo_trap`, `whiskey_thoughts`, `space_prism_rnb` need title vetting
Track titles "Whiskey Thoughts" and "Tokyo Trap" surface adult-coded vocabulary (whiskey, trap-music-as-genre) that the kid-safe positioning excludes. Even if the audio passed STT moderation (instrumental, confirmed), the **filename** appears in error logs, in the AudioBank registry, and in any future content moderation export. Rename filenames to genre-neutral ids (e.g. `phonk_01.mp3 … phonk_10.mp3`) and keep human titles only inside the per-track NOTICES table. Also: "HAHAVOID" Freesound profile — verify the creator is not a flagged adult-content uploader.

### P2-3. No-AI tag audit — KayKit + Quaternius + Kenney + Greg Zaal all clean
Verified: Kay Lousberg's `no-ai` tag = "no AI was used in production"; not a usage restriction. Quaternius CC0 has no AI clause. Kenney CC0 has no AI clause. Greg Zaal's Poly Haven CC0 has no AI clause. **Mixamo (Adobe) and Synty deliberately omitted** — confirmed via `grep -ri "Mixamo\|Synty"` returning zero hits in `data/`, `NOTICES.md`, `scripts/`. Bundled Ollama inference is safe against the current 4 import sources. Document this in NOTICES.md under a `## AI-bundling clearance` heading so the next adversary review doesn't re-litigate.

### P2-4. Gitignore allow-list inconsistency
`.gitignore` excludes `data/models/kaykit/`, `data/audio/music/voxel/`, `data/textures/voxel/`, `data/vfx/voxel/` and only allow-lists `.gitkeep`, yet 7 KayKit GLBs, 10 phonk MP3s, all texture LICENSE.txt + HDRI files, and all vfx files are **tracked in git**. Either:
- The worktree merges used `git add -f` to bypass the ignore (confirmed: `git ls-files` lists `data/models/kaykit/mur.glb` while `git check-ignore` reports it ignored), creating an inconsistent state that future `git add` won't reach, **or**
- The ignore intent ("fetch on first run, never ship binaries") is contradicted by current tracking.
Decide one model. If shipping binaries directly, drop those lines from `.gitignore`. If fetch-on-first-run, `git rm --cached -r data/models/kaykit data/audio/music/voxel data/textures/voxel data/vfx/voxel` and populate the manifest. Current state is the worst of both: binaries shipped but invisible to `git add`.

---

## P3 — Cosmetic / nice-to-have

### P3-1. Polish bilingual NOTICES
Audience is Polish kids + Polish parents. Polish consumer-protection law (Ustawa o prawach konsumenta) doesn't require asset attribution to be bilingual, but a parent-facing legal page should be PL. Add a `NOTICES.pl.md` mirror, or include PL summary at the top of `NOTICES.md`:
```
# Atrybucje zasobów (PL)
choyce-engine używa zasobów CC0 i CC-BY od następujących twórców … (link to root)
```

### P3-2. `Voxel Pack` and `Pattern Pack` entries unverified — never imported
Root NOTICES lists Kenney Voxel Pack + Pattern Pack + Prototype Textures + Smoke Particles + Pixel Frog VFX + OpenGameArt Stylized Magic, none of which appear on disk under `data/textures/voxel/` or `data/vfx/voxel/`. Either remove the unused entries (drift to fiction) or import the assets. Phantom credits are not a license violation but harm audit credibility.

### P3-3. ambientCG TOS — verify slim variant repackaging is allowed
ambientCG TOS permits unlimited commercial use under CC0 but its API ToS restricts automated re-zipping. We ship only `Color + NormalGL + Roughness + Metalness` per material (slim variant) rather than the full archive. CC0 itself permits remixing, but ambientCG's brand guidance asks attribution when displaying the credit. Since `LICENSE.txt` already credits ambientCG, this is satisfied. No action required, but record the slim-variant rationale in the NOTICES root entry for the next legal review.

### P3-4. `data/audio/music/voxel/.transcripts/*.txt` and `MODERATION_LOG.md` tracked
The `scribe_v1` STT transcripts are derivative works of CC0 audio — themselves CC0 by inheritance. No legal issue. But tracked transcripts include song lyrics if any track turns out to be vocal-mixed (the NOTICES says "confirmed instrumental"; verify the log shows zero-token transcripts for all 10 tracks).

---

## Summary

| Severity | Count | Examples |
|---|---|---|
| P0 (block release) | 4 | Missing NOTICES entries; CI gate bypassed; AI-author CC0 chain |
| P1 (fix pre-ship) | 4 | Corrupted OFL URL; stale Polyhaven LICENSE; empty manifest |
| P2 (should fix) | 4 | Pixabay clauses; track filenames; gitignore drift |
| P3 (cosmetic) | 4 | PL bilingual; phantom credits; transcript tracking |

**Top-3 actions before Polish kid-market launch:**
1. Patch `notices-gate.yml` to validate per-directory `### data/<x>/` headings exist + add `push: main` trigger (P0-2).
2. Append missing fonts/HDRI/glitch/VDB/kenney_particles/kenney+mascot+props blocks to root `NOTICES.md` (P0-1).
3. Refresh `data/textures/voxel/polyhaven_hdri/LICENSE.txt` to match the real Greg Zaal CC0 HDR shipped in `9500421` (P1-3).

Path: `/Users/jakubsikora/Repos/choyce-engine/thoughts/shared/reviews/adv-licensing-pivot-2026-05-22.md`
