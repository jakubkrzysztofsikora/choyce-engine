#!/usr/bin/env bash
# Idempotent clean-run helper for Choyce Engine.
#
# Usage:
#   scripts/dev/run.sh              # boot game (auto-build cache if missing)
#   scripts/dev/run.sh --fresh      # wipe runtime user data, then boot
#   scripts/dev/run.sh --rebuild    # wipe .godot cache (forces editor scan), then boot
#   scripts/dev/run.sh --nuke       # wipe BOTH user data and .godot cache, then boot
#   scripts/dev/run.sh --editor     # open the editor (and build cache) instead of running
#   scripts/dev/run.sh --check      # parse-clean check only (no boot)
#
# The script is idempotent: re-running it without flags is safe and skips
# any step that already completed.

set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

USER_DATA_DIR="$HOME/Library/Application Support/choyce_engine"
GODOT_CACHE_DIR="$REPO_ROOT/.godot"
CLASS_CACHE_FILE="$GODOT_CACHE_DIR/global_script_class_cache.cfg"

FRESH=0
REBUILD=0
EDITOR=0
CHECK=0

for arg in "$@"; do
  case "$arg" in
    --fresh)   FRESH=1 ;;
    --rebuild) REBUILD=1 ;;
    --nuke)    FRESH=1; REBUILD=1 ;;
    --editor)  EDITOR=1 ;;
    --check)   CHECK=1 ;;
    -h|--help)
      sed -n '2,16p' "${BASH_SOURCE[0]}" | sed 's/^# //; s/^#//'
      exit 0
      ;;
    *)
      echo "unknown flag: $arg (try --help)" >&2
      exit 2
      ;;
  esac
done

step() { printf '\n→ %s\n' "$*"; }
ok()   { printf '  ✓ %s\n' "$*"; }
warn() { printf '  ! %s\n' "$*" >&2; }

# 1. Sanity: godot binary present
if ! command -v godot >/dev/null 2>&1; then
  echo "godot not on PATH — install Godot 4.6.x and ensure 'godot' resolves" >&2
  exit 1
fi

GODOT_VERSION="$(godot --version 2>/dev/null | tail -1)"
ok "godot: $GODOT_VERSION"

# 2. Sanity: in a Choyce Engine checkout
if [[ ! -f "$REPO_ROOT/project.godot" ]]; then
  echo "project.godot not found at $REPO_ROOT — run from the choyce-engine checkout" >&2
  exit 1
fi

GIT_HEAD="$(git -C "$REPO_ROOT" log --oneline -1 2>/dev/null || echo '(not a git repo)')"
ok "head: $GIT_HEAD"

# 3. Optional: wipe runtime user data
if [[ $FRESH -eq 1 ]]; then
  if [[ -d "$USER_DATA_DIR" ]]; then
    step "wiping runtime user data ($USER_DATA_DIR)"
    rm -rf "$USER_DATA_DIR"
    ok "user data wiped — starter worlds will reseed on boot"
  else
    ok "user data already empty"
  fi
fi

# 4. Optional: wipe Godot cache
if [[ $REBUILD -eq 1 ]]; then
  if [[ -d "$GODOT_CACHE_DIR" ]]; then
    step "wiping Godot cache ($GODOT_CACHE_DIR)"
    rm -rf "$GODOT_CACHE_DIR"
    ok "cache wiped — full reimport on next editor open"
  else
    ok "Godot cache already empty"
  fi
fi

# 5. Ensure class-name cache exists + optional parse-clean check.
# Skip the editor scan when the cache is already present unless --check is set.
# Editor scan takes ~30 s; redundant work bothers the user every boot.
if [[ ! -f "$CLASS_CACHE_FILE" || $CHECK -eq 1 ]]; then
  step "running editor scan (~30 s, builds class cache + parse-clean check)"
  PARSE_OUTPUT="$(timeout 90 godot --editor --headless --quit 2>&1)"
  PARSE_ERRORS="$(echo "$PARSE_OUTPUT" | grep -E "SCRIPT ERROR|Parse Error" | head -10)"
  if [[ -n "$PARSE_ERRORS" ]]; then
    echo "$PARSE_ERRORS"
    warn "parse errors detected"
    [[ $CHECK -eq 1 ]] && exit 1
  else
    ok "no parse errors"
  fi
  if [[ -f "$CLASS_CACHE_FILE" ]]; then
    ok "class cache built"
  else
    warn "class cache still missing — open editor manually once: godot -e --path ."
  fi
else
  ok "class cache present (skipped scan — re-run with --check to force)"
fi

if [[ $CHECK -eq 1 ]]; then
  step "check-only mode — exiting"
  exit 0
fi

# 7. Boot
if [[ $EDITOR -eq 1 ]]; then
  step "opening editor (close window to exit)"
  exec godot --editor --path .
else
  step "booting game"
  echo "  (close window or Cmd+Q to quit)"
  exec godot --path .
fi
