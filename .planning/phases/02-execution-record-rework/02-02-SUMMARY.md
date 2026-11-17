---
status: complete
provides:
  - merge-back.sh — the orchestrator-owned, serialized merge gate for landed waves: pre-checks every plan before the first merge, validates each recorded fork base against the current merge-base, merges each agent branch with --no-ff (one bubble per plan) in plan order, halts with recovery handoffs (HALT/DRIFT/CONFLICT naming every stranded artifact), then removes worktrees and deletes branches — proven end-to-end by the throwaway-clone smoke test including the drift halt
  - implement/SKILL.md — full rewrite onto the artifact-derived execution contract: plan-state oracle (Landed / awaiting merge-back / Blocked / Skipped / interrupted with the three EXEC-03 recovery choices), per-plan worktree dispatch via dispatch-plan.sh, target-overlap demotion, the serialized merge-back gate with docs-side sync only after all merges, zero runs/ references
  - implement/README.md — rewritten to match (worktree isolation, executor-owned commits, serialized merge-back, artifact-derived state; no replay/slicer/TSV/runs-dir language)
  - deletion of implement/scripts/replay-commits.sh and slice-tasks.sh (EXEC-04/09) — the sequencer and slicer are gone from disk; deletions stage at the gate's replay
key-files:
  created:
    - 02-worktrees/master/implement/scripts/merge-back.sh
  modified:
    - 02-worktrees/master/implement/SKILL.md
    - 02-worktrees/master/implement/README.md
    - 02-worktrees/master/implement/scripts/replay-commits.sh
    - 02-worktrees/master/implement/scripts/slice-tasks.sh
key-decisions:
  - "merge-back.sh landed byte-exact per the plan's 'verified recipe, command for command' contract — the smoke-test harness deviation (fixtures committed into the scenario's ancestry) touched only the proof harness, never the deliverable"
  - "The two deleted scripts stay tracked at HEAD with their paths in this plan's commit-spec line, so the gate's replay stages the deletions alongside the README rewrite — per the wave's shared path convention"
  - "git branch -d cleanup semantics verified empirically: -d succeeds only when the script's cwd HEAD contains the merged agent branch; the smoke harness runs the merge in the invoking checkout, which is the shape research Q4 §5 verified"
actuals:
  duration: ~30min
  tasks: 3
  completed: 2026-11-17
---

# Plan 02-02 Summary: merge-back script + reworked implement SKILL.md/README, slicer and replay deleted

The orchestrator half of the execution-record rework is on master's tree: a drift-checked serialized `merge-back.sh` proven by a throwaway-clone smoke test (clean merge bubble + branch cleanup + drift halt), `implement/SKILL.md` and `README.md` fully rewritten around artifact-derived plan state and per-plan worktree dispatch, and the replay sequencer + task slicer deleted.

## Accomplishments

- `merge-back.sh` (EXEC-07) implements the full behavior contract: one precheck pass over every plan before the first merge (plan file, agent branch, target branch exists / has a checkout / checkout clean, fork base recorded), then per plan in command-line order — fork-base equality against the current merge-base or a `DRIFT:` halt naming plan, branch, worktree path, recorded sha, and current merge-base; `merge --no-ff --no-edit` or a `CONFLICT:` halt after `merge --abort`; remove-then-delete cleanup (`git worktree remove` before `git branch -d`). `bash -n` clean, executable, no replay/TSV/runs references, never touches STATE.md/ROADMAP.md
- The smoke test proved the script end-to-end in a throwaway clone: `precheck 9-01 → tgt` then `merged 9-01 → tgt (1f14bf5) · worktree removed · branch agent/9-01 deleted` with exit 0, exactly one `merge(9-01):` bubble on the target, `branch gone (correct)`, and the tampered-fork-base scenario halting with `DRIFT` (`drift halt (correct)`). The real repo's `git worktree list` and branch list were verified unchanged afterwards
- `implement/SKILL.md` rewritten whole: ground rules with "Artifacts are truth" (SUMMARY + `merge(NN-YY):` commit = landed), the plan-state oracle with all five states and the EXEC-03 interrupted-run recovery question, target-overlap demotion with the visible planning-defect warning, `dispatch-plan.sh` dispatch with `$TMPDIR` run dirs and the two-hop summary-template fallback (on-deck → skill's `bootstrap/templates/`), the step-4 gate running `merge-back.sh` serialized in plan order with the halt question, and the docs-side STATE/ROADMAP commit strictly after all merges. Zero occurrences of `runs/`, `commits.tsv`, `replay-commits`, `slice-tasks`, `Markers are truth`
- `implement/README.md` rewritten to the same model (worktree isolation, executor-owned atomic commits, orchestrator-owned merge-back, artifact-derived resume state) with no replay/slicer/TSV/runs-dir language
- `replay-commits.sh` and `slice-tasks.sh` deleted (EXEC-04/09); `implement/scripts/` on disk now holds exactly `dispatch-plan.sh` (02-01's), `dispatch.sh`, `merge-back.sh`, `state-dir.sh`, and the index still lists the two deleted scripts — deletions stage only at the gate's replay, as the plan specifies

## Task commits

1. **Task 1: Add merge-back.sh — serialized --no-ff merge with fork-base validation and worktree cleanup** — `<hash>` (feat) — `feat(02-02): add merge-back.sh — serialized --no-ff merge-back with fork-base validation and worktree cleanup` → `02-worktrees/master/implement/scripts/merge-back.sh`
2. **Task 2: Rewrite implement/SKILL.md around artifact-derived state, worktree dispatch, and the merge-back gate** — `<hash>` (feat) — `feat(02-02): rewrite implement SKILL.md around artifact-derived plan state, per-plan worktree dispatch, and the serialized merge-back gate` → `02-worktrees/master/implement/SKILL.md`
3. **Task 3: Rewrite implement/README.md; delete replay-commits.sh and slice-tasks.sh** — `<hash>` (feat) — `feat(02-02): rewrite implement README for the worktree/merge-back execution model; delete replay-commits.sh and slice-tasks.sh` → `02-worktrees/master/implement/README.md,02-worktrees/master/implement/scripts/replay-commits.sh,02-worktrees/master/implement/scripts/slice-tasks.sh`

## Files created/modified

- `02-worktrees/master/implement/scripts/merge-back.sh` — created (T1): the serialized merge gate; executable, `bash -n` clean, smoke-proven (clean merge, branch cleanup, drift halt)
- `02-worktrees/master/implement/SKILL.md` — rewritten (T2): artifact-derived orchestration contract; verify chain green (0 `runs/` hits)
- `02-worktrees/master/implement/README.md` — rewritten (T3): user-facing doc for the new execution model
- `02-worktrees/master/implement/scripts/replay-commits.sh` — deleted (T3, EXEC-04)
- `02-worktrees/master/implement/scripts/slice-tasks.sh` — deleted (T3, EXEC-09)
- `.planning/runs/02-02.commits.tsv` — the three commit-spec lines above (tab-separated, `02-worktrees/master/`-prefixed paths)
- `.planning/phases/02-execution-record-rework/02-02-SUMMARY.md` — this summary (final task)

## Decisions & deviations

One deviation, in Task 1's **smoke-test harness only** (the deliverable script is byte-exact to the plan):

- **What differed:** the harness as transcribed checks `tgt` out in the clone's main worktree (`git checkout -q tgt`) and then runs `git worktree add "$t/twt" tgt` — which fatal-errors, because a branch is checked out in exactly one worktree (the very behavior research Q4 verified: `fatal: 'tgt' is already used by worktree`). Worse, the two fixture plan files were left **untracked** in that same main worktree, so merge-back's dirty precheck halted (`HALT: 9-01 target checkout '…' is dirty`) before any merge — run verbatim, both required echoes are missing. **Why:** plan-transcription bug in the proof harness, contradicting the research it cites. **Minimum fix (4 inserted lines):** commit both fixture plan files into the scenario's ancestry before `git branch -q tgt` (plans are committed docs in the real system, so this is the realistic shape). All plan lines kept verbatim; with the fixtures committed, the merge runs in the invoking checkout and every assertion passes. The plan's `git worktree add` scaffolding line still prints its `fatal:` (single-checkout rule in action) — benign noise, flow unaffected.

Out-of-scope observations (not mine to fix; for /skill:review):

- **`git branch -d` HEAD-containment:** `-d` succeeds only when the script's cwd HEAD contains the merged agent branch. In the smoke test the merge ran in the invoking checkout, so cleanup succeeded; but in a real gate run invoked from the root checkout (progressEdd, which does **not** contain master — verified `merge-base --is-ancestor` fails), the post-merge `git branch -d agent/NN-YY` would refuse with "not fully merged" and HALT. Research Q4 §5's "cd <orchestrator checkout>" implicitly assumed a checkout containing the merges. The gate's invocation cwd (or a `-d`→upstream-aware check) deserves a look when 02-01's dispatch/merge integration is exercised for real.
- **Index listing:** Task 3's verify annotation expected `git ls-files` to list "all six paths"; it lists the four HEAD-tracked ones (including both deleted scripts — the criterion's actual point). The two new scripts (`merge-back.sh`, `dispatch-plan.sh`) are untracked until the gate's replay stages them — executors never run `git add`, so that is the correct pre-replay state, not an omission.

## Next phase readiness

- implement/ is fully on the new execution model: SKILL.md, README.md, merge-back.sh, and the four-script folder are consistent with 02-01's `dispatch-plan.sh` (already on disk from the sibling) once this wave's commits are replayed onto master.
- The drift-halt, conflict-halt, and precheck semantics are proven; what remains unproven by this plan (by design) is the live end-to-end flow — dispatch-plan.sh forking agent worktrees, then merge-back consuming them — which the first real phase run under the new model will exercise; the `git branch -d` cwd nuance above is the one thing to watch there.
- `/skill:review` for this phase should verify coverage against EXEC-01/02/03/04/05/06/07/09 and the CONTEXT decisions (notably Decision 3's one-bubble-per-plan shape, visible in the smoke output).
