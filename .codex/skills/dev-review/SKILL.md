---
name: dev-review
description: Perform cross-agent code and design reviews with explicit findings, severity, and decision outputs.
---

# Dev Review Skill

## Output contract
Return JSON-like review aligned to `.ai/contracts/review.schema.json`:
- task_id
- reviewer
- decision
- findings[]

## Review areas
- Correctness
- Safety/compliance
- UX for ages 6-8
- Hexagonal boundary integrity
