#!/usr/bin/env bash
# run-ai-vision-tests.sh — TASK-066
# Runs AI vision scenario tests against a live Godot 4 debug instance.
#
# Usage:
#   ./scripts/ci/run-ai-vision-tests.sh [OPTIONS]
#
# Options:
#   --task TASK-ID       Evidence output task folder (default: TASK-055)
#   --tier 1|2           Hardware tier (default: 1)
#   --scenarios DIR      Scenario YAML directory (default: tests/ai-scenarios)
#   --bridge-port PORT   Debug bridge port (default: 9876)
#   --headless           Use Xvfb virtual display (Linux CI)
#   --dry-run            Check prerequisites only, do not run scenarios
#
# Environment:
#   ANTHROPIC_API_KEY    Required for vision assertions
#   GODOT_BIN            Godot binary (auto-detected if not set)

set -euo pipefail

TASK_ID="${TASK_ID:-TASK-055}"
TIER="${TIER:-1}"
SCENARIOS_DIR="${SCENARIOS_DIR:-tests/ai-scenarios}"
BRIDGE_PORT="${BRIDGE_PORT:-9876}"
BRIDGE_URL="http://127.0.0.1:${BRIDGE_PORT}"
HEADLESS=false
DRY_RUN=false
GODOT_PID=""

# ── Argument parsing ──────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --task) TASK_ID="$2"; shift 2 ;;
    --tier) TIER="$2"; shift 2 ;;
    --scenarios) SCENARIOS_DIR="$2"; shift 2 ;;
    --bridge-port) BRIDGE_PORT="$2"; BRIDGE_URL="http://127.0.0.1:${BRIDGE_PORT}"; shift 2 ;;
    --headless) HEADLESS=true; shift ;;
    --dry-run) DRY_RUN=true; shift ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

# ── Prerequisites ─────────────────────────────────────────────────────────────
if [[ -z "${ANTHROPIC_API_KEY:-}" ]]; then
  echo "ERROR: ANTHROPIC_API_KEY not set" >&2
  exit 1
fi

if ! python3 -c "import anthropic, yaml, requests" 2>/dev/null; then
  echo "ERROR: Python dependencies missing. Run: pip install anthropic pyyaml requests" >&2
  exit 1
fi

if [[ -n "${GODOT_BIN:-}" ]]; then
  : # already set
elif command -v godot4 &>/dev/null; then
  GODOT_BIN="godot4"
elif command -v godot &>/dev/null; then
  GODOT_BIN="godot"
else
  echo "ERROR: Godot not found. Set GODOT_BIN or install Godot 4." >&2
  exit 1
fi

if [[ "$DRY_RUN" == "true" ]]; then
  echo "Dry run: prerequisites OK (Godot: ${GODOT_BIN})"
  exit 0
fi

# ── Virtual display (Linux headless CI) ───────────────────────────────────────
cleanup() {
  if [[ -n "$GODOT_PID" ]]; then
    kill "$GODOT_PID" 2>/dev/null || true
  fi
  if [[ "$HEADLESS" == "true" ]] && [[ -n "${XVFB_PID:-}" ]]; then
    kill "$XVFB_PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT

if [[ "$HEADLESS" == "true" ]]; then
  if ! command -v Xvfb &>/dev/null; then
    echo "ERROR: Xvfb not found. Install xvfb for headless display." >&2
    exit 1
  fi
  export DISPLAY=:99
  Xvfb :99 -screen 0 1920x1080x24 &
  XVFB_PID=$!
  sleep 2
  echo "Virtual display started (PID ${XVFB_PID})"
fi

# ── Warm-up Godot import cache ────────────────────────────────────────────────
echo "Warming up Godot import cache…"
"${GODOT_BIN}" --headless --import --quit 2>/dev/null || true
sleep 2

# ── Launch Godot with debug bridge ───────────────────────────────────────────
echo "Launching Godot with debug bridge on port ${BRIDGE_PORT}…"
DISPLAY="${DISPLAY:-:0}" "${GODOT_BIN}" \
  --path . \
  --debug-bridge-port "${BRIDGE_PORT}" \
  2>&1 | tee /tmp/godot-ai-test.log &
GODOT_PID=$!

# Wait for bridge to become available
echo "Waiting for bridge at ${BRIDGE_URL}…"
MAX_WAIT=30
ELAPSED=0
until curl -sf "${BRIDGE_URL}/health" &>/dev/null; do
  if [[ $ELAPSED -ge $MAX_WAIT ]]; then
    echo "ERROR: Bridge did not start within ${MAX_WAIT}s" >&2
    exit 1
  fi
  sleep 2
  ELAPSED=$((ELAPSED + 2))
done
echo "Bridge ready."

# ── Run scenarios ─────────────────────────────────────────────────────────────
EVIDENCE_ROOT=".ai/manual-qa/${TASK_ID}/evidence"
mkdir -p "${EVIDENCE_ROOT}"

echo ""
echo "Running AI vision scenarios for ${TASK_ID} (Tier ${TIER})…"
echo "  Scenarios: ${SCENARIOS_DIR}"
echo "  Evidence:  ${EVIDENCE_ROOT}"
echo ""

python3 scripts/testing/ai_vision_runner.py \
  --bridge-url "${BRIDGE_URL}" \
  --scenarios "${SCENARIOS_DIR}" \
  --task "${TASK_ID}" \
  --tier "${TIER}" \
  --output ".ai/manual-qa"

STATUS=$?

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
if [[ $STATUS -eq 0 ]]; then
  echo "AI vision tests: PASS/REVIEW — see ${EVIDENCE_ROOT}"
else
  echo "AI vision tests: FAIL — see ${EVIDENCE_ROOT}" >&2
fi

exit $STATUS
