#!/usr/bin/env bash
set -euo pipefail

./scripts/ci/check-domain-isolation.sh
./scripts/ci/run-safety-gates.sh
./scripts/run-contract-tests.sh
./scripts/ci/run-application-suite.sh
./scripts/ci/run-stt-suite.sh
./scripts/ci/run-inbound-shell-regression.sh
./scripts/ci/run-persistence-resilience.sh
./scripts/ci/run-mvp-acceptance-suite.sh
./scripts/ci/run-kid-parent-ai-regression-matrix.sh
./scripts/ci/run-usability-kpi-pipeline.sh
./scripts/ci/run-performance-gates.sh

# AI vision scenario tests (requires ANTHROPIC_API_KEY and running Godot instance)
if [[ -n "${ANTHROPIC_API_KEY:-}" ]] && [[ "${SKIP_AI_VISION_TESTS:-false}" != "true" ]]; then
  ./scripts/ci/run-ai-vision-tests.sh --task "${AI_VISION_TASK:-TASK-055}" \
    --tier "${AI_VISION_TIER:-1}" \
    ${AI_VISION_HEADLESS:+--headless}
fi

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
