#!/usr/bin/env bash
## Direct-launch the Choyce Engine with the freshest compiled binary and the
## project's main scene. Use this when you just want to look at the launcher
## without booting through the test harness or the autoplay env var.
##
## Usage:  scripts/launch-game.sh           # open the launcher
##         scripts/launch-game.sh --solo    # autoplay solo straight in
##         scripts/launch-game.sh --coop    # autoplay co-op straight in
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
    export CHOYCE_AUTOPLAY="${CHOYCE_AUTOPLAY_OVERRIDE:-local_kid_1_starter_adventure}"
    ;;
  --coop)
    export CHOYCE_AUTOPLAY="${CHOYCE_AUTOPLAY_OVERRIDE:-local_kid_1_starter_adventure}"
    export CHOYCE_FORCE_COOP=1
    ;;
  --help|-h)
    sed -n '2,9p' "$0"
    exit 0
    ;;
  "") ;;
  *)
    echo "Unknown flag: $1" >&2
    sed -n '2,9p' "$0"
    exit 2
    ;;
esac

exec "$GODOT_BIN" --path "$REPO_ROOT"
