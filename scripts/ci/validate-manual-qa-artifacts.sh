#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=".ai/manual-qa"
REPORT_PATH=".ai/reports/manual-qa/latest-validation.json"
DEFAULT_TASKS=("TASK-055" "TASK-056" "TASK-059" "TASK-060")
REQUIRED_FILES=("tier1-run.md" "tier2-run.md" "triage.md" "traceability.md")

if [[ $# -gt 0 ]]; then
  TASKS=("$@")
else
  TASKS=("${DEFAULT_TASKS[@]}")
fi

failed_tasks=0
report_items=()

echo "Manual QA artifact validation root: ${ROOT_DIR}"

for task_id in "${TASKS[@]}"; do
  task_dir="${ROOT_DIR}/${task_id}"
  task_issues=0

  if [[ ! -d "${task_dir}" ]]; then
    echo "[FAIL] ${task_id}: missing directory ${task_dir}"
    task_issues=$((task_issues + 1))
  else
    for rel_file in "${REQUIRED_FILES[@]}"; do
      file_path="${task_dir}/${rel_file}"
      if [[ ! -f "${file_path}" ]]; then
        echo "[FAIL] ${task_id}: missing required file ${rel_file}"
        task_issues=$((task_issues + 1))
        continue
      fi

      if rg -n -i '\bTODO\b|\bTBD\b' "${file_path}" >/dev/null; then
        echo "[FAIL] ${task_id}: placeholder markers remain in ${rel_file}"
        task_issues=$((task_issues + 1))
      fi
    done

    evidence_dir="${task_dir}/evidence"
    if [[ ! -d "${evidence_dir}" ]]; then
      echo "[FAIL] ${task_id}: missing evidence directory ${evidence_dir}"
      task_issues=$((task_issues + 1))
    else
      evidence_count="$(find "${evidence_dir}" -type f ! -name '.gitkeep' | wc -l | tr -d ' ')"
      if [[ "${evidence_count}" -eq 0 ]]; then
        echo "[FAIL] ${task_id}: no evidence files found under evidence/"
        task_issues=$((task_issues + 1))
      fi
    fi
  fi

  if [[ "${task_issues}" -eq 0 ]]; then
    echo "[PASS] ${task_id}: artifacts complete"
    report_items+=("{\"task_id\":\"${task_id}\",\"passed\":true,\"issues\":0}")
  else
    failed_tasks=$((failed_tasks + 1))
    report_items+=("{\"task_id\":\"${task_id}\",\"passed\":false,\"issues\":${task_issues}}")
  fi
done

report_tasks="$(IFS=,; echo "${report_items[*]}")"
if [[ "${failed_tasks}" -eq 0 ]]; then
  passed_literal="true"
else
  passed_literal="false"
fi

report_json="$(printf '{"timestamp_utc":"%s","tasks":[%s],"failed_tasks":%d,"passed":%s}' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "${report_tasks}" "${failed_tasks}" "${passed_literal}")"
echo "MANUAL_QA_VALIDATION_REPORT_JSON=${report_json}"

mkdir -p "$(dirname "${REPORT_PATH}")"
printf '%s\n' "${report_json}" > "${REPORT_PATH}"
echo "MANUAL_QA_VALIDATION_REPORT_PATH=${REPORT_PATH}"

if [[ "${failed_tasks}" -gt 0 ]]; then
  exit 1
fi
