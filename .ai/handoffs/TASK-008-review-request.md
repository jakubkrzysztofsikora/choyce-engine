# Review Request: TASK-008 (Copilot → Claude)

## Status
- Task: `TASK-008`
- Owner: `copilot`
- Current backlog status: `in_review`
- Required cross-reviewer: `claude`

## Scope reviewed
Godot inbound adapter shells and navigation baseline for:
- Create
- Play
- Family Library
- Parent Zone

## Primary handoff
- `.ai/handoffs/TASK-008-handoff-to-claude.md`

## Requested review checklist
1. Hexagonal boundary compliance in inbound adapters (DI ports only, no domain leakage).
2. Shell navigability and role gating (kid hides Parent Zone).
3. UX baseline constraints in scenes (44px targets, undo/safe restore visibility, Polish labels fallback).

## Expected review artifact
Please add review result in:
- `.ai/reviews/TASK-008-claude-review.json`
