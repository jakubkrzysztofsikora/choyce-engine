#!/usr/bin/env bash
set -euo pipefail

# Unified dispatch helper for cross-CLI collaboration.
# Usage: ./scripts/agent-dispatch.sh <agent> <task-id>

AGENT="${1:-}"
TASK_ID="${2:-}"

if [[ -z "$AGENT" || -z "$TASK_ID" ]]; then
  echo "Usage: $0 <codex|claude|copilot|mistral> <TASK-ID>"
  exit 1
fi

case "$AGENT" in
  codex)
    echo "[dispatch] codex should execute task $TASK_ID and update .ai/tasks/backlog.yaml"
    ;;
  claude)
    echo "[dispatch] claude should run architecture/review workflow for $TASK_ID using CLAUDE.md"
    ;;
  copilot)
    echo "[dispatch] copilot should implement scoped changes for $TASK_ID following .github/copilot-instructions.md"
    ;;
  mistral)
    echo "[dispatch] mistral should produce systems analysis/review for $TASK_ID following .mistral/config.yml"
    ;;
  *)
    echo "Unknown agent: $AGENT"
    exit 2
    ;;
esac
