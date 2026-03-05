#!/usr/bin/env bash
set -euo pipefail

./scripts/ci/check-domain-isolation.sh
./scripts/ci/run-prompt-regression.sh
./scripts/ci/run-safety-gates.sh
./scripts/run-contract-tests.sh
./scripts/ci/run-application-suite.sh
./scripts/ci/run-stt-suite.sh
./scripts/ci/run-inbound-shell-regression.sh

# Focused baseline suites already used in active development flow.
if command -v godot4 >/dev/null 2>&1; then
  GODOT_BIN="godot4"
elif command -v godot >/dev/null 2>&1; then
  GODOT_BIN="godot"
else
  echo "Godot not found. Install Godot 4 first." >&2
  exit 127
fi

"${GODOT_BIN}" --headless --path . --script tests/contracts/run_task_027_tests.gd
"${GODOT_BIN}" --headless --path . --script tests/contracts/run_task_032_tests.gd
"${GODOT_BIN}" --headless --path . --script tests/contracts/run_task_044_tests.gd
"${GODOT_BIN}" --headless --path . --script tests/contracts/run_task_047_tests.gd
