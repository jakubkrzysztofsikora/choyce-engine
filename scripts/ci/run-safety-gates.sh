#!/usr/bin/env bash
set -euo pipefail

if command -v godot4 >/dev/null 2>&1; then
  GODOT_BIN="godot4"
elif command -v godot >/dev/null 2>&1; then
  GODOT_BIN="godot"
else
  echo "Godot not found. Install Godot 4 first." >&2
  exit 127
fi

"${GODOT_BIN}" --headless --path . --editor --quit >/dev/null
"${GODOT_BIN}" --headless --path . --script tests/safety/run_safety_redteam_tests.gd
"${GODOT_BIN}" --headless --path . --script tests/safety/run_prompt_regression_tests.gd
