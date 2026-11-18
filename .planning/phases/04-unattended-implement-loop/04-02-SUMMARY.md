---
status: complete
duration: 12min
key-files:
  created:
    - implement/scripts/watch-wave.sh
  modified:
    - implement/scripts/dispatch.sh
    - implement/scripts/dispatch-plan.sh
requirements-completed:
  - AUTO-02 — per-target agent worktree/branch (agent/<NN>-<slug>/<target>), shared sequentially by a target's plans
  - AUTO-03 — attempt budget, 3 dispatches per plan, mechanically enforced before any state mutation and surfaced by the watcher
  - AUTO-05 — sequential guard: a live sibling executor in the same target worktree is refused (PID-checked, dead PIDs never block)
  - AUTO-06 — watch-wave.sh resolves on the SUMMARY artifact oracle; $TMPDIR markers advisory liveness only; dead-PID .running resolves failed
  - AUTO-07 — SHIPPEDD_EXECUTOR_CMD deterministic-testing hook in dispatch.sh (04-03's selftest injection point)
key-decisions:
  - "dispatch-plan.sh rewritten verbatim from the plan: per-target run dir ${TMPDIR:-/tmp}/shippEdd/<NN>-<slug>/<target>/ (worktree/, fork-base, merge-attempts) beside the per-plan dir (prompt, log, markers, attempts, NN-YY.target)"
  - "Budget gate (≥3 → BUDGET line + exit 1) and the sibling guard run BEFORE marker clearing, mkdir, and worktree forking; attempts/$id.target are appended only after both pass — a refused dispatch leaves no new state"
  - "merge-attempts cleared whenever a fresh agent-branch generation is forked or re-attached, so 04-03's merge budget is per generation"
  - "watch-wave.sh: exactly three exit statements (exit \"$rc\" with rc ∈ {0,2,3} reachable, exit 4 on --timeout, exit 1 usage); polls every 10s, heartbeat every ~60s"
deviations:
  - "Path prefix (same recorded precedent as 04-01): the plan names `.agents/skills/shippEdd/implement/scripts/*.sh`, the vendored location in the progressEdd checkout; this agent worktree is a fork of `master`, where the canonical skill tree sits at the repo root — files were edited, verified, and committed at worktree-root-relative `implement/scripts/*.sh` (verify commands' paths adapted identically). Content, exact contract strings, and commit messages unchanged."
  - "TMPDIR was unset in the executor environment; exported TMPDIR=/tmp (the scripts' own fallback) for verify runs — matching the 04-01 precedent."
---

# Plan 04-02 Summary: the loop mechanics — per-target dispatch, attempt budget, watch-wave.sh (AUTO-02/03/05/06)

The dispatch machinery now runs the sequential auto loop: one agent worktree/branch per (phase, target) shared by that target's plans, a hard 3-attempt budget per plan, a PID-checked refusal for a second live executor in a target worktree, recovery dispatches via --fix-instructions, and a blocking watcher that resolves plans on the SUMMARY artifact oracle with budget-aware exit codes 0/2/3/4.

## Accomplishments

- `dispatch.sh` gains the `SHIPPEDD_EXECUTOR_CMD` hook (AUTO-07): when set, the dispatcher launches that space-split command as the executor (prompt on stdin, like `pi --print`); the default path still has exactly one `nohup pi --print` line. The `--status` format and the `dispatched <id> (PID <pid>) → <log>` receipt are byte-identical (printf lines hash-equal before/after).
- `dispatch-plan.sh` reworked (AUTO-02/03/05): per-target worktree + single agent branch `agent/<NN>-<slug>/<target>` forked from the target HEAD on first dispatch and reused by every later plan of that target; the attempt budget (3 dispatches — `attempts` lines under $TMPDIR) is enforced before anything is touched; a sequential guard refuses dispatch while a sibling plan of the same target has a live PID in its `.running` marker; `--fix-instructions <file>` appends orchestrator recovery instructions verbatim to the executor prompt; the prompt itself now names the shared worktree and the attempt number.
- `watch-wave.sh` created (AUTO-06): blocks until every named plan resolves — SUMMARY frontmatter first (executed/blocked), markers only for liveness, a dead-PID `.running` marker resolves `failed` (aborted/crashed, never forgiven). Resolution lines carry the attempt count; a failed plan at 3 attempts prints the `BUDGET:` stop line and exits 3; blocked/failed-but-recoverable exit 2; timeout exits 4. Exactly three `exit` statements.
- Cross-plan contracts verified byte-for-byte against the objective (branch/run-dir naming, both BUDGET lines, REFUSED line, the three resolution-line templates) — 04-03 and 04-04 consume them verbatim.
- Both rewritten scripts and the new one pass `bash -n`; Task 2's dispatch-plan.sh and Task 3's watch-wave.sh were extracted from the plan text and diff-confirmed byte-identical; worktree `git status --porcelain` empty after all commits.

## Task commits

1. **Task 1: Add the SHIPPEDD_EXECUTOR_CMD testing hook to dispatch.sh** — `27c3537` feat(04-02): dispatch.sh SHIPPEDD_EXECUTOR_CMD hook for deterministic selftests
2. **Task 2: Rework dispatch-plan.sh — per-target worktree, attempt budget, sequential guard, --fix-instructions** — `c94f4f9` feat(04-02): dispatch-plan forks per-target worktrees, enforces the 3-attempt budget and the sequential guard
3. **Task 3: Create watch-wave.sh — block until the named plans resolve on the SUMMARY oracle** — `28d9c0c` feat(04-02): watch-wave.sh — blocking run watcher on the SUMMARY oracle with budget-aware exit codes

## Files created/modified

- `implement/scripts/dispatch.sh` — conditional launch: `SHIPPEDD_EXECUTOR_CMD` (space-split into `runner[@]`) or the unchanged `nohup pi --print`; header documents the env hook
- `implement/scripts/dispatch-plan.sh` — per-target worktree/branch forking & reuse, attempts budget gate, PID-checked sequential sibling guard keyed on `$id.target`, `--fix-instructions` recovery section, merge-attempts reset per agent-branch generation, `worktree`/`attempt n/3` receipt lines
- `implement/scripts/watch-wave.sh` — new blocking watcher on the SUMMARY oracle; status_of/attempts_of/reason_of helpers; heartbeated 10s poll loop; exits 0/2/3/4

## Decisions & deviations

Followed the plan as written; both scripts' bodies are byte-identical to the plan text (diff-verified). Two environment deviations, both matching the 04-01 precedent and recorded in frontmatter deviations: worktree-root-relative paths (`implement/scripts/...` instead of the plan's `.agents/skills/shippEdd/implement/scripts/...` prefix — the worktree is a fork of `master`, the canonical skill tree), and exporting `TMPDIR=/tmp` (unset in the executor environment; the scripts fall back to the same value themselves).

## Next phase readiness

- 04-03 (merge-back rework + selftest) can consume the frozen contracts directly: per-target run dir layout with `merge-attempts` (cleared per agent-branch generation), the `SHIPPEDD_EXECUTOR_CMD` injection point in dispatch.sh, watch-wave exit codes 0/2/3/4, and the exact BUDGET/REFUSED/resolved line formats.
- 04-04 (SKILL.md) can document the per-target worktree topology, the 3-attempt budget, `--fix-instructions`, and watch-wave semantics as implemented.
- Gate note honored from the plan: wave 2's merge-back should run the canonical fixed per-plan script from the master checkout (`bash 02-worktrees/master/.agents/skills/shippEdd/implement/scripts/merge-back.sh .planning 04 unattended-implement-loop 04-02` from the main checkout root) — the orchestrator's call, not this executor's.
