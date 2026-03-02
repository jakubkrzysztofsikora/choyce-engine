# /plan

Use this command to decompose a feature request into backlog tasks ready for multi-agent execution.

## Steps
1. Read current `.ai/tasks/backlog.yaml` to identify existing tasks and the next available TASK-ID. IDs are zero-padded three-digit numbers (TASK-001, TASK-002, …); increment from the highest existing one.
2. Break the feature into 3–7 small, single-specialty tasks.
3. For each task, fill in the template below.
4. Append the new tasks to `.ai/tasks/backlog.yaml` (do not overwrite existing tasks).
5. Confirm the updated backlog to the user.

## Task template
```yaml
- id: TASK-XXX
  title: <concise imperative title>
  owner: codex | claude | copilot | mistral
  specialty: architecture | ai-safety | gameplay-ux | systems-design | implementation
  inputs:
    - <path to relevant requirement or doc>
  dependencies: []          # list TASK-IDs this task must wait for; omit the field entirely if there are no dependencies
  acceptance_criteria:
    - <verifiable criterion>
  cross_review_by: codex | claude | copilot | mistral
  status: todo
```

## Owner selection guide
| Specialty needed | Preferred owner | Cross-reviewer |
|---|---|---|
| Architecture / domain design | claude | codex |
| AI safety / moderation gates | codex | claude |
| Kid/parent UI flows | copilot | claude |
| Economy / gameplay balance | mistral | copilot |
| Implementation / refactoring | codex or copilot | claude |

## Constraints
- One owner and one specialty per task.
- No task is done without cross-agent review (see `.ai/workflows/definition-of-done.md`).
- Safety-critical tasks must have `claude` or `codex` as cross-reviewer.
- Keep each task small enough for a single focused PR.
