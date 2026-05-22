# Free-asset bulk-download infrastructure

This directory holds the first-run asset fetcher for choyce-engine. The
heavy art/audio/vfx trees (KayKit, Quaternius, voxel textures, voxel VFX,
voxel music - roughly 950 MB) are **not** committed to git; instead they
are pulled on demand from their CC0/CC-BY sources, verified by SHA-256,
and extracted into `data/`.

## Files

| File | Purpose |
| --- | --- |
| `manifest.yaml` | Declarative list of every pack: URL, SHA-256, license, destination. Single source of truth. |
| `fetch_free_assets.sh` | POSIX shell downloader. Verifies SHA-256, extracts archives, idempotent via `data/.assets_complete`. |
| `README.md` | This file. |

## Manifest schema (v1)

```yaml
version: 1
packs:
  - id: kaykit_adventurers       # ascii_snake_case, stable, unique
    source: itch.io              # human label (itch.io, opengameart, ...)
    url: https://.../pack.zip    # HTTPS direct download
    sha256: <lowercase-hex>      # 64 hex chars, OR "TBD" during proposal PRs
    license: CC0                 # SPDX-ish tag
    dest: data/models/kaykit/adventurers/   # MUST start with data/ and end with /
    size_mb: 80                  # approx. compressed size
    attribution: "Kay Lousberg - KayKit Adventurers"  # required for non-CC0
```

### Field rules

- `id` is the row key in `data/.assets_complete`. Renaming an id forces a
  re-download.
- `url` must point at an archive (`.zip`, `.tar.gz`, `.tgz`, `.tar`).
  Other extensions are rejected by the extractor.
- `sha256` of `TBD` is only acceptable on draft pack-proposal PRs. The
  fetcher refuses to install a TBD pack.
- `dest` is repo-relative and must be one of the ignored data trees
  (`data/models/kaykit/`, `data/models/quaternius/`, `data/textures/voxel/`,
  `data/vfx/voxel/`, `data/audio/music/voxel/`). Adding a new ignored
  tree requires a parallel `.gitignore` update.
- `attribution` is the line that lands in `NOTICES.md`. Non-CC0 packs
  MUST set this field.

## Validating the manifest

```sh
# Pure-Python validation (no extra tools required):
python3 -c "import yaml; yaml.safe_load(open('scripts/assets/manifest.yaml'))"

# With yq (homebrew/apt package):
yq '.packs[] | .id + " -> " + .dest' scripts/assets/manifest.yaml
```

The fetcher performs the same structural check at startup and exits
non-zero if any required field is missing or `dest` violates the prefix
rule.

## Usage

```sh
# Show what would download without touching the filesystem:
bash scripts/assets/fetch_free_assets.sh --dry-run

# Run for real (also reachable via `make assets`):
make assets

# Force re-download even if data/.assets_complete already lists the pack:
bash scripts/assets/fetch_free_assets.sh --force
```

The script logs every status line bilingually (`PL: ... | EN: ...`). It is
written in POSIX `sh` and tested on Linux and macOS - no `bash` features
(`[[ ]]`, arrays, process substitution) are used.

## Adding a pack (other agents)

1. Identify a CC0 (preferred) or CC-BY source. Record the canonical
   download URL.
2. Download once locally, compute `sha256sum pack.zip`, and paste the
   digest into a new entry in `manifest.yaml`.
3. Append a matching block to `NOTICES.md` under the right
   `### data/...` heading.
4. Open a PR. The `notices-gate` workflow
   (`.github/workflows/notices-gate.yml`) fails CI if any commit touches
   `data/` without also updating `NOTICES.md`.

## Why not commit the assets

Tracked binary blobs make `git clone` slow and inflate every fork. CC0
packs are hosted by their original authors at stable URLs, so caching
them once per workstation is cheap and keeps the repo lean.
