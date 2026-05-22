#!/bin/sh
# fetch_free_assets.sh - first-run downloader for choyce-engine free assets.
#
# Pobiera paczki CC0/CC-BY zdefiniowane w scripts/assets/manifest.yaml,
# weryfikuje SHA-256 i rozpakowuje do drzewa data/. Idempotentny:
# zainstalowane paczki sa pomijane wedlug data/.assets_complete.
#
# Downloads CC0/CC-BY packs declared in scripts/assets/manifest.yaml,
# verifies SHA-256, and extracts into the data/ tree. Idempotent:
# installed packs are skipped via data/.assets_complete.
#
# Usage:
#   scripts/assets/fetch_free_assets.sh           # download + extract
#   scripts/assets/fetch_free_assets.sh --dry-run # list what WOULD download
#   scripts/assets/fetch_free_assets.sh --force   # re-download even if marked complete
#
# POSIX sh only - no bash-isms (no [[ ]], no arrays, no process substitution).
# Works on Linux + macOS.

set -eu

DRY_RUN=0
FORCE=0
for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=1 ;;
        --force)   FORCE=1 ;;
        -h|--help)
            cat <<'EOF'
Usage: fetch_free_assets.sh [--dry-run] [--force]

  --dry-run   List packs that would be downloaded, then exit.
  --force     Re-download even if pack id is in data/.assets_complete.

Exit codes:
  0  OK (or nothing to do)
  1  manifest parse error / missing tool
  2  download or SHA-256 mismatch
  3  extraction failure
EOF
            exit 0
            ;;
        *)
            printf 'fetch_free_assets: unknown arg %s\n' "$arg" >&2
            exit 1
            ;;
    esac
done

# Resolve repo root from script location (POSIX-safe).
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "${SCRIPT_DIR}/../.." && pwd)
MANIFEST="${SCRIPT_DIR}/manifest.yaml"
MARKER="${REPO_ROOT}/data/.assets_complete"
CACHE_DIR="${REPO_ROOT}/data/.assets_cache"

log_pl_en() {
    # $1 = PL, $2 = EN
    printf '[assets] PL: %s | EN: %s\n' "$1" "$2"
}

err() {
    printf '[assets] ERR: %s\n' "$1" >&2
}

require_tool() {
    if ! command -v "$1" >/dev/null 2>&1; then
        err "missing required tool: $1"
        exit 1
    fi
}

require_tool curl
require_tool python3
# tar is in POSIX base; unzip is best-effort (only for .zip packs).

if [ ! -f "$MANIFEST" ]; then
    err "manifest not found: $MANIFEST"
    exit 1
fi

# Use python3 to parse YAML (no yq dependency on dev machines).
# Emits one tab-separated line per pack:
#   id<TAB>url<TAB>sha256<TAB>dest<TAB>size_mb<TAB>license<TAB>source
PACK_LIST=$(python3 - "$MANIFEST" <<'PY'
import sys, yaml
with open(sys.argv[1]) as fh:
    data = yaml.safe_load(fh) or {}
if data.get("version") != 1:
    sys.stderr.write("manifest version must be 1\n")
    sys.exit(1)
packs = data.get("packs") or []
required = ("id", "url", "sha256", "dest", "size_mb", "license", "source")
for p in packs:
    for k in required:
        if k not in p:
            sys.stderr.write("pack missing field %s: %r\n" % (k, p))
            sys.exit(1)
    if not str(p["dest"]).startswith("data/") or not str(p["dest"]).endswith("/"):
        sys.stderr.write("pack %s: dest must start with data/ and end with /\n" % p["id"])
        sys.exit(1)
    print("\t".join(str(p[k]) for k in required))
PY
)

if [ -z "$PACK_LIST" ]; then
    log_pl_en "Manifest pusty - nic do pobrania." "Manifest empty - nothing to fetch."
    exit 0
fi

mkdir -p "$CACHE_DIR"
touch "$MARKER"

is_complete() {
    # $1 = pack id
    [ "$FORCE" -eq 0 ] && grep -qxF "$1" "$MARKER" 2>/dev/null
}

mark_complete() {
    # $1 = pack id
    if ! grep -qxF "$1" "$MARKER" 2>/dev/null; then
        printf '%s\n' "$1" >>"$MARKER"
    fi
}

sha256_of() {
    # $1 = file path -> prints lowercase hex digest
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1" | awk '{print $1}'
    else
        # macOS fallback
        shasum -a 256 "$1" | awk '{print $1}'
    fi
}

extract_archive() {
    # $1 = archive path, $2 = dest dir (absolute)
    archive=$1
    dest=$2
    mkdir -p "$dest"
    case "$archive" in
        *.zip)
            if ! command -v unzip >/dev/null 2>&1; then
                err "unzip required for $archive"
                return 3
            fi
            unzip -q -o "$archive" -d "$dest"
            ;;
        *.tar.gz|*.tgz)
            tar -xzf "$archive" -C "$dest"
            ;;
        *.tar)
            tar -xf "$archive" -C "$dest"
            ;;
        *)
            err "unsupported archive type: $archive"
            return 3
            ;;
    esac
}

# Iterate via heredoc -> while read (POSIX-safe, preserves env).
echo "$PACK_LIST" | while IFS='	' read -r id url expected_sha dest size_mb license source; do
    [ -z "$id" ] && continue
    abs_dest="${REPO_ROOT}/${dest}"

    if is_complete "$id"; then
        log_pl_en \
            "Paczka ${id} juz zainstalowana - pomijam." \
            "Pack ${id} already installed - skipping."
        continue
    fi

    if [ "$DRY_RUN" -eq 1 ]; then
        log_pl_en \
            "[dry-run] Pobralbym ${id} (${size_mb} MB, ${license}) z ${source}: ${url}" \
            "[dry-run] Would download ${id} (${size_mb} MB, ${license}) from ${source}: ${url}"
        continue
    fi

    if [ "$expected_sha" = "TBD" ]; then
        err "pack ${id}: sha256 is TBD - refusing to install. Update manifest with real digest."
        exit 2
    fi

    log_pl_en \
        "Pobieram ${id} (${size_mb} MB) z ${source}..." \
        "Downloading ${id} (${size_mb} MB) from ${source}..."

    # Archive filename derived from URL path.
    archive_name=$(printf '%s' "$url" | awk -F/ '{print $NF}' | awk -F? '{print $1}')
    [ -z "$archive_name" ] && archive_name="${id}.bin"
    archive_path="${CACHE_DIR}/${id}__${archive_name}"

    if ! curl -L --fail --progress-bar -o "$archive_path" "$url"; then
        err "download failed: ${id} (${url})"
        exit 2
    fi

    actual_sha=$(sha256_of "$archive_path")
    if [ "$actual_sha" != "$expected_sha" ]; then
        err "SHA-256 mismatch for ${id}: expected ${expected_sha}, got ${actual_sha}"
        rm -f "$archive_path"
        exit 2
    fi
    log_pl_en \
        "SHA-256 OK dla ${id}." \
        "SHA-256 verified for ${id}."

    log_pl_en \
        "Rozpakowuje ${id} do ${dest}..." \
        "Extracting ${id} to ${dest}..."
    if ! extract_archive "$archive_path" "$abs_dest"; then
        err "extraction failed: ${id}"
        exit 3
    fi

    mark_complete "$id"
    log_pl_en \
        "Paczka ${id} gotowa." \
        "Pack ${id} ready."
done

log_pl_en \
    "Wszystkie paczki przetworzone." \
    "All packs processed."
