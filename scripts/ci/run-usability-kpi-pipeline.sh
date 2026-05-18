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

set +e
output="$("${GODOT_BIN}" --headless --path . --script tests/usability/run_usability_kpi_pipeline.gd 2>&1)"
status=$?
set -e

printf '%s\n' "$output"
if [[ $status -ne 0 ]]; then
  exit "$status"
fi

if printf '%s\n' "$output" | grep -q 'SCRIPT ERROR'; then
  exit 1
fi

echo "Running full log-ingestion pipeline..."
# Generate mock logs
"${GODOT_BIN}" --headless --path . --script scripts/pipeline/test_pipeline_generation.gd

# Run reporting tool
REPORT_JSON=$("${GODOT_BIN}" --headless --path . --script scripts/pipeline/generate_usability_kpi_report.gd user://pipeline_test 2026-03)

if echo "$REPORT_JSON" | grep -q '"sample_size":2'; then
  echo "PASS: Pipeline generated valid report for 2 sessions."
else
  echo "FAIL: Report validation failed."
  echo "$REPORT_JSON"
  exit 1
fi

if [[ $status -ne 0 ]]; then
  exit "$status"
fi

if printf '%s\n' "$output" | grep -E -q "SCRIPT ERROR: Parse Error|SCRIPT ERROR: Compile Error|Failed to load script"; then
  echo "Detected parse/compile/load errors in usability KPI pipeline." >&2
  exit 1
fi

report_line="$(printf '%s\n' "$output" | grep -E '^USABILITY_KPI_REPORT_JSON=' | tail -n 1 || true)"
if [[ -z "$report_line" ]]; then
  echo "Missing machine-readable usability report line." >&2
  exit 1
fi

artifact_dir=".ai/reports/TASK-051"
artifact_file="${artifact_dir}/latest-kpi-report.json"
mkdir -p "$artifact_dir"
printf '%s\n' "${report_line#USABILITY_KPI_REPORT_JSON=}" > "$artifact_file"

echo "USABILITY_KPI_REPORT_PATH=${artifact_file}"
