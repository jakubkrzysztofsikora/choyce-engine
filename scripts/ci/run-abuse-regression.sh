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
  output="$($@ 2>&1)"
  status=$?
  set -e

  printf '%s\n' "$output"
  if [[ $status -ne 0 ]]; then
    echo "Abuse regression failed: ${label}" >&2
    return "$status"
  fi

  if printf '%s\n' "$output" | rg -q "SCRIPT ERROR: Parse Error|SCRIPT ERROR: Compile Error|Failed to load script"; then
    echo "Detected parse/compile/load errors in ${label}." >&2
    return 1
  fi

  return 0
}

"${GODOT_BIN}" --headless --path . --editor --quit >/dev/null

run_and_check "Safety red-team suite" "${GODOT_BIN}" --headless --path . --script tests/safety/run_safety_redteam_tests.gd
run_and_check "Safety/compliance suite" "${GODOT_BIN}" --headless --path . --script tests/safety/run_safety_compliance_regression_suite.gd
run_and_check "Family session abuse guards" "${GODOT_BIN}" --headless --path . --script tests/application/run_task_045_tests.gd
run_and_check "Catalog visibility abuse guards" "${GODOT_BIN}" --headless --path . --script tests/application/run_task_046_tests.gd
run_and_check "Data lifecycle abuse guards" "${GODOT_BIN}" --headless --path . --script tests/application/run_task_048_tests.gd
run_and_check "Feature flag tamper guards" "${GODOT_BIN}" --headless --path . --script tests/application/run_application_tests.gd

report='{"suite":"AbuseRegressionPack","timestamp_utc":"'"$(date -u +%Y-%m-%dT%H:%M:%SZ)"'","passed":true,"suites":["safety_redteam","safety_compliance","task045","task046","task048","application_suite"]}'
printf 'ABUSE_REGRESSION_REPORT_JSON=%s\n' "$report"
