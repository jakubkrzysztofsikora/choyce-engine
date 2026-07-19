#!/usr/bin/env bash
## Clean rebuild of choyce-engine's Godot caches. Wipes all auto-generated
## files (imported meshes / textures, editor session, GDScript class cache)
## and re-imports everything once via Godot's headless --import. Use this
## after adding new .glb/.png/.tres assets or when weird runtime errors
## point to a stale import cache.
##
## Usage:  scripts/rebuild-game.sh              # clean + import + exit
##         scripts/launch-game.sh --rebuild     # clean + import + launch
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT_BIN="${CHOYCE_GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"

cd "$REPO_ROOT"

if [[ ! -x "$GODOT_BIN" ]]; then
  GODOT_BIN="$(command -v godot4 || true)"
fi
if [[ -z "${GODOT_BIN:-}" || ! -x "$GODOT_BIN" ]]; then
  echo "Cannot find a Godot 4 binary. Set CHOYCE_GODOT_BIN to its absolute path." >&2
  exit 127
fi

echo "[rebuild] wiping .godot/imported + .godot/editor + .godot/global_script_class_cache.cfg"
rm -rf .godot/imported .godot/editor .godot/global_script_class_cache.cfg

echo "[rebuild] headless import pass on $(pwd)"
"$GODOT_BIN" --headless --path "$REPO_ROOT" --import 2>&1 | tail -10 || true

echo "[rebuild] done. Launch with:  $GODOT_BIN --path $REPO_ROOT"
