#!/usr/bin/env bash
set -euo pipefail

BACKLOG=".ai/tasks/backlog.yaml"
REVIEWS_DIR=".ai/reviews"
AGENT="${1:-${AGENT_NAME:-codex}}"
AGENT="$(printf '%s' "$AGENT" | tr '[:upper:]' '[:lower:]')"

if [[ ! "$AGENT" =~ ^(codex|claude|copilot|mistral)$ ]]; then
  echo "Unsupported agent '$AGENT'. Use one of: codex, claude, copilot, mistral." >&2
  exit 2
fi

if [[ ! -f "$BACKLOG" ]]; then
  echo "Missing backlog file: $BACKLOG" >&2
  exit 1
fi

TMP_TSV="$(mktemp)"
trap 'rm -f "$TMP_TSV"' EXIT

awk '
  function trim(s) { gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
  function emit_task() {
    if (id != "") {
      print id "\t" owner "\t" status "\t" deps "\t" reviewer
    }
  }

  /^  - id:/ {
    emit_task()
    id = trim(substr($0, index($0, ":") + 1))
    owner = ""
    status = ""
    deps = ""
    reviewer = ""
    next
  }

  id != "" && /^[[:space:]]+owner:/ {
    owner = trim(substr($0, index($0, ":") + 1))
    next
  }

  id != "" && /^[[:space:]]+status:/ {
    status = trim(substr($0, index($0, ":") + 1))
    next
  }

  id != "" && /^[[:space:]]+dependencies:/ {
    deps = trim(substr($0, index($0, ":") + 1))
    gsub(/^\[/, "", deps)
    gsub(/\]$/, "", deps)
    gsub(/, /, ",", deps)
    next
  }

  id != "" && /^[[:space:]]+cross_review_by:/ {
    reviewer = trim(substr($0, index($0, ":") + 1))
    next
  }

  END { emit_task() }
' "$BACKLOG" > "$TMP_TSV"

declare -A TASK_STATUS
while IFS=$'\t' read -r tid owner status deps reviewer; do
  [[ -z "$tid" ]] && continue
  TASK_STATUS["$tid"]="$status"
done < "$TMP_TSV"

is_deps_done() {
  local deps_csv="$1"
  [[ -z "$deps_csv" ]] && return 0

  IFS=',' read -r -a dep_arr <<< "$deps_csv"
  for dep in "${dep_arr[@]}"; do
    dep="${dep// /}"
    [[ -z "$dep" ]] && continue
    if [[ "${TASK_STATUS[$dep]:-}" != "done" ]]; then
      return 1
    fi
  done
  return 0
}

extract_reviewer_name() {
  local review_file="$1"
  local reviewer_name
  reviewer_name="$(grep -E '"reviewer"|"responder"' "$review_file" | head -n1 | sed -E 's/.*"(reviewer|responder)"[[:space:]]*:[[:space:]]*"([^"]+)".*/\2/' || true)"
  if [[ -z "$reviewer_name" ]]; then
    reviewer_name="unknown"
  fi
  printf "%s" "$reviewer_name"
}

echo "== ${AGENT} Task Monitor =="
echo

echo "[1/5] Reviews assigned to ${AGENT} (cross_review_by=${AGENT}, status=in_review)"
found=0
while IFS=$'\t' read -r tid owner status deps reviewer; do
  if [[ "$reviewer" == "$AGENT" && "$status" == "in_review" ]]; then
    echo "- $tid"
    found=1
  fi
done < "$TMP_TSV"
[[ $found -eq 0 ]] && echo "- none"
echo

echo "[2/5] ${AGENT}-owned tasks with external review files"
AGENT_TASK_IDS=()
while IFS=$'\t' read -r tid owner status deps reviewer; do
  if [[ "$owner" == "$AGENT" ]]; then
    AGENT_TASK_IDS+=("$tid")
  fi
done < "$TMP_TSV"

review_found=0
if [[ -d "$REVIEWS_DIR" ]]; then
  for tid in "${AGENT_TASK_IDS[@]}"; do
    while IFS= read -r rf; do
      reviewer_name="$(extract_reviewer_name "$rf")"
      echo "- $tid reviewed by $reviewer_name ($(basename "$rf"))"
      review_found=1
    done < <(grep -l "\"task_id\"[[:space:]]*:[[:space:]]*\"$tid\"" "$REVIEWS_DIR"/*.json 2>/dev/null || true)
  done
fi
[[ $review_found -eq 0 ]] && echo "- none"
echo

echo "[3/5] ${AGENT} tasks waiting for external review (owner=${AGENT}, status=in_review, no review file)"
waiting_found=0
while IFS=$'\t' read -r tid owner status deps reviewer; do
  [[ "$owner" != "$AGENT" ]] && continue
  [[ "$status" != "in_review" ]] && continue
  has_review=0
  if [[ -d "$REVIEWS_DIR" ]]; then
    while IFS= read -r rf; do
      [[ -z "$rf" ]] && continue
      review_reviewer="$(extract_reviewer_name "$rf")"
      if [[ -n "$reviewer" && "$review_reviewer" == "$reviewer" ]]; then
        has_review=1
        break
      fi
    done < <(grep -l "\"task_id\"[[:space:]]*:[[:space:]]*\"$tid\"" "$REVIEWS_DIR"/*.json 2>/dev/null || true)
  fi
  if [[ $has_review -eq 0 ]]; then
    echo "- $tid (cross_review_by=${reviewer:-unknown})"
    waiting_found=1
  fi
done < "$TMP_TSV"
[[ $waiting_found -eq 0 ]] && echo "- none"
echo

echo "[4/5] ${AGENT} tasks ready to implement now (owner=${AGENT}, status=todo, deps done)"
ready_found=0
while IFS=$'\t' read -r tid owner status deps reviewer; do
  [[ "$owner" != "$AGENT" ]] && continue
  [[ "$status" != "todo" ]] && continue
  if is_deps_done "$deps"; then
    if [[ -n "$deps" ]]; then
      echo "- $tid (deps: $deps)"
    else
      echo "- $tid (no dependencies)"
    fi
    ready_found=1
  fi
done < "$TMP_TSV"
[[ $ready_found -eq 0 ]] && echo "- none"
echo

echo "[5/5] Other agents active work (owner!=${AGENT}, status=in_progress|in_review)"
active_found=0
while IFS=$'\t' read -r tid owner status deps reviewer; do
  [[ "$owner" == "$AGENT" ]] && continue
  if [[ "$status" == "in_progress" || "$status" == "in_review" ]]; then
    echo "- $tid (owner=$owner, status=$status, review_by=${reviewer:-n/a})"
    active_found=1
  fi
done < "$TMP_TSV"
[[ $active_found -eq 0 ]] && echo "- none"
echo

echo "[Info] To monitor continuously, run:"
echo "  watch -n 15 ./scripts/agent-watch.sh ${AGENT}"
echo "[Info] If 'watch' is unavailable (default macOS), run:"
echo "  while true; do ./scripts/agent-watch.sh ${AGENT}; sleep 15; clear; done"
