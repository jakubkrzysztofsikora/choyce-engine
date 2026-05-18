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

: "${CHOYCE_HARDWARE_TIER:=tier1}"
: "${CHOYCE_PERF_RUN_ALL_TIERS:=1}"
export CHOYCE_HARDWARE_TIER
export CHOYCE_PERF_RUN_ALL_TIERS

if [[ "${CHOYCE_PERF_RUN_ALL_TIERS}" == "1" || "${CHOYCE_PERF_RUN_ALL_TIERS}" == "true" || "${CHOYCE_PERF_RUN_ALL_TIERS}" == "yes" ]]; then
  echo "Running performance gates for all configured hardware tiers"
else
  echo "Running performance gates for hardware tier: ${CHOYCE_HARDWARE_TIER}"
fi
"${GODOT_BIN}" --headless --path . --editor --quit >/dev/null
run_and_check "Performance benchmark suite" "${GODOT_BIN}" --headless --path . --script tests/performance/run_performance_benchmarks.gd
