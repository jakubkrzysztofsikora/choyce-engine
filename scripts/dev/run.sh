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
#   scripts/dev/run.sh --smoke      # automated click-to-play probe (autoplay + log scan)
#
# --smoke needs a display server. On Linux CI wrap with xvfb-run; --headless is
# intentionally NOT used because the runtime needs the rendering server to
# exercise the click chain.
#
# The script is idempotent: re-running it without flags is safe and skips
# any step that already completed.

set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

USER_DATA_DIR="$HOME/Library/Application Support/choyce_engine"
GODOT_CACHE_DIR="$REPO_ROOT/.godot"
CLASS_CACHE_FILE="$GODOT_CACHE_DIR/global_script_class_cache.cfg"
SMOKE_DIR="$REPO_ROOT/.smoke"
SMOKE_AUTOPLAY_PROJECT_ID="local_kid_1_starter_adventure"
SMOKE_TIMEOUT_SECONDS=25

FRESH=0
REBUILD=0
EDITOR=0
CHECK=0
SMOKE=0

for arg in "$@"; do
  case "$arg" in
    --fresh)   FRESH=1 ;;
    --rebuild) REBUILD=1 ;;
    --nuke)    FRESH=1; REBUILD=1 ;;
    --editor)  EDITOR=1 ;;
    --check)   CHECK=1 ;;
    --smoke)   SMOKE=1 ;;
    -h|--help)
      sed -n '2,19p' "${BASH_SOURCE[0]}" | sed 's/^# //; s/^#//'
      exit 0
      ;;
    *)
      echo "unknown flag: $arg (try --help)" >&2
      exit 2
      ;;
  esac
done

if [[ $SMOKE -eq 1 && $EDITOR -eq 1 ]]; then
  echo "--smoke and --editor are mutually exclusive" >&2
  exit 2
fi

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
#
# Re-scan if any data/models or data/themes asset is newer than the cache —
# Godot's .godot/imported .scn caches don't auto-refresh on git pull, so
# glTF material edits would otherwise stay invisible.
ASSET_NEWER=0
if [[ -f "$CLASS_CACHE_FILE" ]]; then
  if find data/models data/themes -newer "$CLASS_CACHE_FILE" -type f \
       \( -name '*.gltf' -o -name '*.glb' -o -name '*.tres' -o -name '*.bin' \) \
       2>/dev/null | grep -q .; then
    ASSET_NEWER=1
  fi
fi

if [[ ! -f "$CLASS_CACHE_FILE" || $CHECK -eq 1 || $ASSET_NEWER -eq 1 ]]; then
  if [[ $ASSET_NEWER -eq 1 ]]; then
    step "asset files newer than cache — wiping .godot/imported + rescanning"
    rm -rf "$GODOT_CACHE_DIR/imported"
  fi
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

# 6. Smoke mode: automated click-to-play probe + log scan.
# Uses CHOYCE_AUTOPLAY env var (read in main.gd) to fire _on_world_card_pressed
# without a human click. Boots godot in background, kills after timeout,
# greps log for FATAL + REQUIRED signals.
if [[ $SMOKE -eq 1 ]]; then
  step "smoke mode — autoplay probe (timeout ${SMOKE_TIMEOUT_SECONDS}s)"
  mkdir -p "$SMOKE_DIR"
  SMOKE_LOG="$SMOKE_DIR/run-$(date +%s).log"
  ok "log: $SMOKE_LOG"

  CHOYCE_AUTOPLAY="$SMOKE_AUTOPLAY_PROJECT_ID" godot --path . -d >"$SMOKE_LOG" 2>&1 &
  GODOT_PID=$!
  sleep "$SMOKE_TIMEOUT_SECONDS"
  if kill -0 "$GODOT_PID" 2>/dev/null; then
    kill "$GODOT_PID" 2>/dev/null || true
    sleep 1
    kill -9 "$GODOT_PID" 2>/dev/null || true
  fi
  wait "$GODOT_PID" 2>/dev/null || true
  ok "godot exited (pid $GODOT_PID)"

  # FATAL signals — any match fails the job (with allowlist for known warning).
  FATAL_PATTERNS=(
    "SCRIPT ERROR"
    "Parse Error"
    "port not ready"
    "session creation failed"
    "project not found"
  )
  FATAL_HITS=""
  for pat in "${FATAL_PATTERNS[@]}"; do
    hit="$(grep -F "$pat" "$SMOKE_LOG" || true)"
    if [[ -n "$hit" ]]; then
      FATAL_HITS+="$hit"$'\n'
    fi
  done
  # "not wired" with allowlist (OnboardingService event_bus is W2.4 deferred).
  NOT_WIRED_HITS="$(grep -F "not wired" "$SMOKE_LOG" | grep -vF "OnboardingService: event_bus not wired" || true)"
  if [[ -n "$NOT_WIRED_HITS" ]]; then
    FATAL_HITS+="$NOT_WIRED_HITS"$'\n'
  fi

  # REQUIRED positive signals — any missing fails the job.
  REQUIRED_PATTERNS=(
    "[autoplay] firing world_card_pressed"
    "[gameplay] start_session"
    "[world_renderer]"
    "[gameplay] session live"
  )
  MISSING_SIGNALS=()
  for pat in "${REQUIRED_PATTERNS[@]}"; do
    if ! grep -qF "$pat" "$SMOKE_LOG"; then
      MISSING_SIGNALS+=("$pat")
    fi
  done

  SMOKE_FAIL=0
  if [[ -n "$FATAL_HITS" ]]; then
    SMOKE_FAIL=1
    warn "fatal signals detected:"
    printf '%s' "$FATAL_HITS" | sed 's/^/    /'
  fi
  if [[ ${#MISSING_SIGNALS[@]} -gt 0 ]]; then
    SMOKE_FAIL=1
    warn "missing required signals:"
    for sig in "${MISSING_SIGNALS[@]}"; do
      printf '    %s\n' "$sig" >&2
    done
  fi

  if [[ $SMOKE_FAIL -eq 0 ]]; then
    printf '\nSMOKE PASS — log: %s\n' "$SMOKE_LOG"
    exit 0
  else
    printf '\nSMOKE FAIL — log: %s\n' "$SMOKE_LOG"
    exit 1
  fi
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
