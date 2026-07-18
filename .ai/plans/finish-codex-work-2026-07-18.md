# Plan v2: Finish Codex's in-flight choyce-engine work + branch/worktree hygiene

Authored: 2026-07-18 (v2 — supersedes v1 after hostile self-review)
v1 BLOCKERS fixed: stale baseline (hardening already in `1f2e571`), worktree
data-loss (3 worktrees hold uncommitted source), open-PR destruction (PR #14/#15
heads would be silent-deleted).

## 0. State (re-verified 2026-07-18, build mode)

- `main` HEAD: `45f8afa feat(NPC): implement ready answers library and dynamic response growth`
- 4 new commits since v1 baseline `d96fb6c`:
  - `45f8afa feat(NPC): implement ready answers library and dynamic response growth`
  - `082f152 feat(voice): integrate tailnet-hosted voice agent with ElevenLabs fallback`
  - `1e8a633 feat(NPC): add Dark Triad personality traits`
  - `1f2e571 feat(NPC): implement psychology-backed personality…` — **also contains the co-op hardening + Kenney bridge + new test files** (Codex's uncommitted batch got committed by another agent during v1 review)
- Working tree on main: clean except `.ai/plans/`
- 2 OPEN PRs:
  - PR #15 `test(adapters): revalidate + fix adapter tests after recent prod drift` → `fix/adapter-tests-revalidate-2026-05-20` @ `96aa8cd`
  - PR #14 `test(e2e): align MockLLM with Phase 8a async LLMPort contract` → `worktree-agent-a9b9c79c1d0a4ed19` @ `da34cc6`
- 1 May commit not in any PR, not in main: `1953e5d fix(shell-bridge): kid-safety + hex-arch adv pivots…`
- 8 stale worktrees under `.claude/worktrees/` from May 22
- Codex's 3 cut-off deliverables: VS-051 design doc, VS-050 co-op audit JSON, orchestrator adversarial review — all missing
- `fix/adventure-thin-slice-combat-first-run` already merged via `550c621`; 0 commits ahead

## Phase 1 — Salvage worktree uncommitted state (BLOCKER 2 fix)

Before any removal, snapshot these 3 worktrees' working-tree state to `/tmp/worktree-salvage/`:

| Worktree | Uncommitted state | Likely disposition |
|---|---|---|
| `agent-a216a1c60ca1b2ab3` | `Makefile`, `NOTICES.md`, `.github/workflows/notices-gate.yml`, `scripts/assets/`, `.gitignore` mod | Real asset-attribution CI gate feature. Open follow-up PR. |
| `agent-a2fba307a77a1f196` | `world_renderer.gd` mod (+31), `ui_pl.json` mod (+13) | Inspect diff. Likely superseded by current `1f2e571` world_renderer changes. |
| `agent-ad137c2314478d78f` | `choyce_theme.tres` mod (+14/-13) | Inspect diff. Likely small theme polish. |

The other 5 worktrees (`a226ade9`, `a5e9adab`, `a79db992`, `a9b9c79c`, `afd25434`) only have `*.ogg.import` Godot-runtime artifacts as untracked — safe to remove without salvage.

Action:
```
mkdir -p /tmp/worktree-salvage
for w in agent-a216a1c60ca1b2ab3 agent-a2fba307a77a1f196 agent-ad137c2314478d78f; do
  mkdir -p /tmp/worktree-salvage/$w
  git -C .claude/worktrees/$w diff > /tmp/worktree-salvage/$w/tracked.diff
  git -C .claude/worktrees/$w status --porcelain | awk '$1=="??" {print $2}' | while read f; do
    mkdir -p /tmp/worktree-salvage/$w/untracked/$(dirname "$f")
    cp .claude/worktrees/$w/"$f" /tmp/worktree-salvage/$w/untracked/"$f"
  done
done
```

Inspect each salvage; decide per file: open PR, archive tag, or drop with note.

## Phase 2 — Resolve the 3 unique May commits via PR flow (BLOCKER 3 fix)

For each commit, use the proper PR resolution path, not cherry-pick-and-delete:

- **`96aa8cd` (PR #15)** — rebase PR onto main, run tests. If green, merge via PR. If conflict, close with comment "folded into later work" then delete branch.
- **`da34cc6` (PR #14)** — rebase PR onto main, run tests. If green, merge via PR. If conflict, close with comment then delete.
- **`1953e5d` (no PR)** — try `git cherry-pick --no-commit 1953e5d` on main. If conflicts are non-trivial, park as `archive/shell-bridge-kid-safety-2026-05-22` tag. If clean and tests pass, commit as `chore(cherry-pick): shell-bridge kid-safety hardening`.

## Phase 3 — Finish Codex's 3 cut-off deliverables

### 3a. VS-051 design doc

Author `.ai/specifications/VS-051-private-family-session-design.md` mirroring the format of existing `.ai/specifications/VS-046-hero-asset-specification.md`. Inputs per backlog:
- `.ai/research-compendium/RESEARCH_VS-030_BasicMultiplayer_Evaluation.md`
- `.codex/skills/ai-safety/SKILL.md`
- `.codex/skills/hex-architecture/SKILL.md`
- `src/domain/gameplay/player_inventory.gd`

Required sections: host authority; explicit private invite + parental consent; child-safe roles; save-conflict resolution; offline fallback; no public discovery; no unrestricted chat; explicit non-goal of any runtime implementation before Gate-A.

### 3b. VS-050 co-op audit review

Adversarially review **commit `1f2e571`** (the committed hardening work), not an uncommitted diff. Focus files: `player_controller.gd`, `input_map_initializer.gd`, `split_screen_runtime.gd`, `gameplay_runtime.gd`, `test_split_screen_hero_pairing.gd`. Criteria: input isolation, shared `BuildGrid` single-undo, P2 build/craft access, save correctness, solo regression.

Output `.ai/reviews/VS-050-local-coop-hardening-audit-2026-07-18.json` matching the shape of `.ai/reviews/VS-050-claude-review-2026-07-18.json`: `{task_id, reviewer, decision, findings[{severity, file:line, message, fix}]}`.

### 3c. Orchestrator adversarial review

Run `~/.config/adversarial-reviewer/review.sh` from repo root against `git show 1f2e571` (the committed hardening). If LiteLLM still down, fall back to direct git inspection by this agent.

Fix every BLOCKER/MAJOR from 3b/3c before Phase 4.

## Phase 4 — Commit deliverables as per-task commits (MAJOR 2 fix)

No squash. Separate commits matching repo style:

1. `docs(VS-051): private family session design` — adds `.ai/specifications/VS-051-private-family-session-design.md`
2. `docs(VS-050): retain co-op hardening audit review` — adds `.ai/reviews/VS-050-local-coop-hardening-audit-2026-07-18.json`
3. `docs(backlog): update VS-044/VS-050/VS-051 evidence pointers` — appends to `evidence:` lists in `.ai/tasks/backlog.yaml`

If Phase 2 produced cherry-picks or PR merges, those are already separate commits.

Update `PLAN.md` only if it needs a new dated entry summarizing the audit outcome (mirror existing entry style).

## Phase 5 — Branch + worktree cleanup (BLOCKER 2 fix applied first)

### 5a. Worktrees — remove all 8 AFTER Phase 1 salvage is verified

```
git worktree remove --force .claude/worktrees/agent-a216a1c60ca1b2ab3
git worktree remove --force .claude/worktrees/agent-a226ade92252f4fa5
git worktree remove --force .claude/worktrees/agent-a2fba307a77a1f196
git worktree remove --force .claude/worktrees/agent-a5e9adab231b2a5c6
git worktree remove --force .claude/worktrees/agent-a79db992a061ae9a1
git worktree remove --force .claude/worktrees/agent-a9b9c79c1d0a4ed19
git worktree remove --force .claude/worktrees/agent-ad137c2314478d78f
git worktree remove --force .claude/worktrees/agent-afd25434be47bf103
git worktree prune
```

### 5b. Local branches

- `fix/adventure-thin-slice-combat-first-run` — delete (merged)
- `fix/adapter-tests-revalidate-2026-05-20` — delete only AFTER PR #15 resolution
- `feat/mvp-push-2026-05-23` — 0 ahead, delete
- `shell/tauri-skeleton-2026-05-22` — 0 ahead, delete
- All `worktree-agent-*` — delete only AFTER PR #14 resolution and after salvage

### 5c. Origin remote cleanup

Check first: `gh repo view --json deleteBranchOnMerge,mergeCommitAllowed,squashMergeAllowed`.
Check open PRs: `gh pr list --state open --json number,title,headRefName`.
Per-branch rule: older than 3-4 days AND not useful → delete; recent/useful → PR or keep.

PR-bound:
- `origin/fix/adapter-tests-revalidate-2026-05-20` (PR #15) — handle via PR merge or close
- `origin/worktree-agent-a9b9c79c1d0a4ed19` (PR #14) — handle via PR merge or close

Stale local-only origins to triage by `git log --oneline main..origin/<branch>`:
- `origin/ci/boot-warning-gate`, `origin/codex/create-requirements-for-game-engine-with-ai`, `origin/copilot/sub-pr-1`, `origin/feat/smoke-run-sh-clean`, `origin/fix/wave-1-release-blockers`, `origin/godot-arch-review-2026-05-18`, `origin/review/safety-coppa-2026-05-18`, `origin/review/ux-kid-flow-2026-05-18`, `origin/test/world-card-click-flow-l3`, `origin/worktree-agent-a48d87ac5c3c56938`, `origin/worktree-agent-a5fba0a1231e4ff89`, `origin/worktree-agent-ad34d07c34043d11e`, `origin/worktree-agent-afa97719955fbb649`

Same for paired: `origin/feat/mvp-push-2026-05-23`, `origin/shell/tauri-skeleton-2026-05-22`, `origin/fix/adventure-thin-slice-combat-first-run`, `origin/worktree-agent-a226ade92252f4fa5`, etc.

`git remote prune origin` at the end.

## Phase 6 — Plan-level adversarial review (DONE)

This v2 plan exists because the v1 hostile self-review found 3 BLOCKERS.
Phase 6 is satisfied by the v1 addendum review already in this file's
history; no second plan-level pass needed.

## Out of scope

- VS-046 hero Blender assets
- VS-044 visual-rescue gate (still REQUEST_CHANGES)
- VS-042 tailnet LiteLLM experiment (blocked on Gate-A)

## Execution order

1. Phase 1 — salvage 3 worktrees' uncommitted state to /tmp/worktree-salvage/
2. Inspect salvages; decide PR/archive/drop per file
3. Phase 2 — resolve PRs #14/#15 (merge or close), handle `1953e5d`
4. Phase 3a — author VS-051 design doc
5. Phase 3b — audit commit `1f2e571` → write VS-050 hardening audit JSON
6. Phase 3c — adversarial review of `1f2e571`
7. Fix BLOCKER/MAJOR findings from 3b/3c
8. Phase 4 — per-task commits for design doc + audit JSON + backlog update
9. Phase 5a — remove 8 worktrees
10. Phase 5b/5c — delete branches, push-delete origin branches, prune
11. Final verification: clean `git status`, `gh pr list --state open` shows expected state, `git worktree list` shows 1 entry

## References

- `PLAN.md` (visual-rescue gate + sandbox-loop + co-op priority sections)
- `.ai/tasks/backlog.yaml` (VS-044, VS-046, VS-050, VS-051 entries)
- `AGENTS.md` (cross-review rule, hex-architecture, AI-safety)
- `.codex/skills/ai-safety/SKILL.md`
- `.codex/skills/hex-architecture/SKILL.md`
- `.ai/research-compendium/RESEARCH_VS-030_BasicMultiplayer_Evaluation.md`
- `.ai/specifications/VS-046-hero-asset-specification.md` (template for 3a)
- `.ai/reviews/VS-050-claude-review-2026-07-18.json` (template for 3b)

---

## v1 hostile self-review addendum (2026-07-18, retained for audit)

External fable-5 review unavailable — LiteLLM gateway rate-limited, all
fallbacks (deepseek-v4-pro, kimi-k3) out of balance. Findings below verified
against live repo by direct git inspection.

### BLOCKER 1 — Plan baseline is stale; co-op hardening already committed

- **Section**: 0 (State observed), Phase 1, Phase 4
- **Failure**: Plan was drafted against `main @ d96fb6c` with 9 modified + 6
  untracked files. During review, main moved 4 commits ahead to `45f8afa`;
  commit `1f2e571 feat(NPC): implement psychology-backed personality…`
  absorbed the entire co-op hardening batch. Phase 4's squash is impossible.
- **Evidence**: `git log --oneline d96fb6c..45f8afa`; `git diff --stat
  d96fb6c..45f8afa -- src/adapters/inbound/gameplay/split_screen_runtime.gd
  tests/adapters/inbound/test_local_coop_sandbox_snapshot.gd` shows files
  now in main.
- **Fix**: Drop Phase 4 squash. Phase 3b audits `1f2e571`, not uncommitted
  diff. **Applied in v2.**

### BLOCKER 2 — Worktree removal destroys 3 sets of real uncommitted source

- **Section**: 5a
- **Failure**: `git worktree remove --force` discards working-tree changes.
  Three worktrees hold non-trivial uncommitted source:
  - `agent-a216a1c60ca1b2ab3`: Makefile + NOTICES.md + notices-gate.yml +
    scripts/assets/ + .gitignore mod (real asset-attribution CI gate feature)
  - `agent-a2fba307a77a1f196`: world_renderer.gd (+31) + ui_pl.json (+13)
  - `agent-ad137c2314478d78f`: choyce_theme.tres (+14/-13)
- **Evidence**: `git -C <worktree> status --porcelain` for each.
- **Fix**: Phase 1 in v2 salvages before removal. **Applied in v2.**

### BLOCKER 3 — Phase 5c would delete heads of 2 OPEN pull requests

- **Section**: 5c
- **Failure**: PR #15 head = `fix/adapter-tests-revalidate-2026-05-20`; PR
  #14 head = `worktree-agent-a9b9c79c1d0a4ed19`. Cherry-pick-and-delete
  closes them as unmerged.
- **Evidence**: `gh pr list --state open --json number,title,headRefName`.
- **Fix**: Phase 2 in v2 resolves via PR merge-or-close, not silent delete.
  **Applied in v2.**

### MAJOR 1 — Phase 1 test list wildly incomplete

- **Section**: Phase 1
- **Failure**: 20+ other tests touch the modified files (e.g.
  `test_npc_dialogue_offline_fallback`, `test_combat_hit_feedback`,
  `test_evidence_capture`, `test_adventure_sky3d_atmosphere`,
  `test_hotbar_image_hud_contract`, `test_vehicle_runtime`,
  `test_terrain3d_world_adapter`, `test_starter_homestead_village_shell`,
  `test_world_renderer_kaykit_loads`, `test_opening_route_traversal`,
  `test_sandbox_inventory_crafting_loop`, `test_silly_fart_mechanic`, etc.).
- **Evidence**: `rg -l '<basename>' tests/` for each modified file.
- **Fix**: v2 drops Phase 1 hard list; regression scope is now moot because
  the hardening is already committed in `1f2e571`. Audit (Phase 3b) and
  adversarial review (Phase 3c) cover the validation need.

### MAJOR 2 — Phase 4 "single squash commit" violates traceability rule

- **Section**: Phase 4
- **Failure**: AGENTS.md line 10 mandates cross-agent review per task;
  backlog evidence lists point at specific commits. Squash destroys bisect.
- **Evidence**: Any `evidence:` list in `.ai/tasks/backlog.yaml`.
- **Fix**: v2 Phase 4 splits into per-task commits. **Applied in v2.**

### MAJOR 3 — Phase 3 deliverable shapes under-specified

- **Section**: 3a, 3b
- **Failure**: No format anchor.
- **Evidence**: `.ai/specifications/` and `.ai/reviews/` have many shape variants.
- **Fix**: v2 anchors 3a on `VS-046-hero-asset-specification.md`, 3b on
  `VS-050-claude-review-2026-07-18.json`. **Applied in v2.**

### MAJOR 4 — Adversarial review ordering wrong

- **Section**: Phase 3c + Phase 6
- **Failure**: Plan-level review should run before impl, not interleaved.
- **Evidence**: CLAUDE.md global rule.
- **Fix**: v2 Phase 6 marks plan-level review as DONE via this addendum.
  **Applied in v2.**

### MINOR 1 — Cherry-pick of `1953e5d` shell-bridge is risky

- **Section**: Phase 2
- **Fix**: v2 parks it as archive tag if conflicts are non-trivial.

### MINOR 2 — Phase 5c misses `deleteBranchOnMerge` setting

- **Section**: 5c
- **Fix**: v2 adds `gh repo view --json deleteBranchOnMerge` query first.

### NIT 1 — Codex transcript parsing incomplete

- **Section**: 0
- **Fix**: v2 states limitation: orchestrator transcript content is encrypted;
  inferences come from spawned-subagent prompts + on-disk artifacts.

### VERDICT v1: FIX-FIRST → v2 applies all BLOCKER + MAJOR fixes.
