#!/usr/bin/env bash
set -euo pipefail

DOMAIN_DIR="src/domain"
if [[ ! -d "$DOMAIN_DIR" ]]; then
  echo "Missing domain directory: $DOMAIN_DIR" >&2
  exit 1
fi

# Domain should not depend on Godot scene/runtime classes or network I/O APIs.
forbidden_patterns=(
  "extends[[:space:]]+(Node|Control|Node2D|Node3D|SceneTree|CanvasLayer|Panel|Button|Label|AcceptDialog)"
  "HTTPRequest"
  "HTTPClient"
  "WebSocket"
  "PacketPeer"
  "FileAccess"
  "DirAccess"
  "OS\.execute"
  "res://src/adapters"
)

failures=0
for pattern in "${forbidden_patterns[@]}"; do
  if rg -n -e "$pattern" "$DOMAIN_DIR" >/tmp/domain-isolation-match.txt; then
    echo "[FAIL] Domain isolation violation for pattern: $pattern" >&2
    cat /tmp/domain-isolation-match.txt >&2
    failures=$((failures + 1))
  fi
done

if [[ $failures -gt 0 ]]; then
  echo "Domain isolation gate failed with $failures violation group(s)." >&2
  exit 1
fi

echo "Domain isolation gate passed."
