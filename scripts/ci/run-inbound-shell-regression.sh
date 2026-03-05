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

run_and_check() {
  local label="$1"
  shift
  local output
  local status

  set +e
  output="$("$@" 2>&1)"
  status=$?
  set -e

  printf '%s\n' "$output"
  if [[ $status -ne 0 ]]; then
    return "$status"
  fi

  if printf '%s\n' "$output" | rg -q "SCRIPT ERROR: Parse Error|SCRIPT ERROR: Compile Error|Failed to load script"; then
    echo "Detected parse/compile/load errors in ${label}." >&2
    return 1
  fi

  return 0
}

"${GODOT_BIN}" --headless --path . --editor --quit >/dev/null
run_and_check "Accessibility integration" "${GODOT_BIN}" --headless --path . --script tests/adapters/inbound/test_accessibility_integration.gd
run_and_check "Onboarding integration" "${GODOT_BIN}" --headless --path . --script tests/adapters/inbound/test_onboarding_integration.gd
run_and_check "Parent controls integration" "${GODOT_BIN}" --headless --path . --script tests/adapters/inbound/test_parent_zone_controls_integration.gd
run_and_check "Voice assistant integration" "${GODOT_BIN}" --headless --path . --script tests/adapters/inbound/test_voice_assistant_integration.gd
run_and_check "Provenance integration" "${GODOT_BIN}" --headless --path . --script tests/adapters/inbound/test_provenance_integration.gd
