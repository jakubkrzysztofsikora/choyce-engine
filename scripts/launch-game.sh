#!/usr/bin/env bash
## Direct-launch the Choyce Engine with the authored sandbox kit as the
## default playable demo. Use this when you want to inspect the launcher or
## boot straight into the same route covered by the GPU feedback loop.
##
## Usage:  scripts/launch-game.sh             # open the launcher
##         scripts/launch-game.sh --solo      # autoplay sandbox solo
##         scripts/launch-game.sh --coop      # autoplay sandbox co-op
##         scripts/launch-game.sh --rebuild   # wipe import cache, re-import, then launch
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT_BIN="${CHOYCE_GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"

if [[ ! -x "$GODOT_BIN" ]]; then
  GODOT_BIN="$(command -v godot4 || true)"
fi
if [[ -z "${GODOT_BIN:-}" || ! -x "$GODOT_BIN" ]]; then
  echo "Cannot find a Godot 4 binary. Set CHOYCE_GODOT_BIN to its absolute path." >&2
  exit 127
fi

case "${1:-}" in
  --solo)
    export CHOYCE_AUTOPLAY="${CHOYCE_AUTOPLAY_OVERRIDE:-local_kid_1_starter_sandbox_kit}"
    ;;
  --coop)
    export CHOYCE_AUTOPLAY="${CHOYCE_AUTOPLAY_OVERRIDE:-local_kid_1_starter_sandbox_kit}"
    export CHOYCE_FORCE_COOP=1
    ;;
  --rebuild)
    "$REPO_ROOT/scripts/rebuild-game.sh"
    ;;
  --rebuild-solo)
    "$REPO_ROOT/scripts/rebuild-game.sh"
    export CHOYCE_AUTOPLAY="${CHOYCE_AUTOPLAY_OVERRIDE:-local_kid_1_starter_sandbox_kit}"
    ;;
  --help|-h)
    sed -n '2,8p' "$0"
    exit 0
    ;;
  "") ;;
  *)
    echo "Unknown flag: $1" >&2
    sed -n '2,8p' "$0"
    exit 2
    ;;
esac

exec "$GODOT_BIN" --path "$REPO_ROOT"
