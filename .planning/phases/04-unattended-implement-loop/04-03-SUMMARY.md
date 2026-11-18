---
status: complete
duration: 27min
key-files:
  created:
    - implement/scripts/auto-selftest.sh
  modified:
    - implement/scripts/merge-back.sh
requirements-completed:
  - AUTO-01 — safe `-d` branch delete from the target's own checkout, preserved through the per-target rework and proven by selftest case 5
  - AUTO-04 — merge-back attempts bounded to 3 per agent-branch generation, counted under $TMPDIR, idempotent landed-first re-runs burning nothing; proven by selftest cases 5/6/7
  - AUTO-05 — sequential per-target topology exercised end-to-end (refusal of a second live executor, worktree reuse across a target's plans) by selftest cases 1/2
  - AUTO-07 — layer-1 deterministic selftest: temp-repo simulation of the full loop driving the real dispatch-plan.sh / watch-wave.sh / merge-back.sh via SHIPPEDD_EXECUTOR_CMD
key-decisions:
  - "merge-back.sh applied verbatim from the plan (diff-verified byte-identical, modulo shebang); the selftest likewise verbatim except the two recorded deviations below"
  - "Selftest green runs demonstrated three times, including from the exact state the plan's verify requires (post-commit, script tracked at the source): 22/22 checks each time; sandbox fully self-cleaning, repo tree never touched"
  - "Task 2's commit was amended once (75b9356 → 5c6ba70) to fold in the vendored-copy gitlink fix, keeping one atomic commit per task with the plan's exact message"
deviations:
  - "Path prefix (recorded precedent of 04-01/04-02): the plan names `.agents/skills/shippEdd/implement/scripts/*.sh`, the vendored location in the progressEdd checkout; this agent worktree is a fork of `master`, where the canonical skill tree sits at the repo root — files were edited, verified, and committed at worktree-root-relative `implement/scripts/*.sh` (verify commands' paths adapted identically)"
  - "auto-selftest.sh: added `2>&1` to two command substitutions (case 1's `disp ok 09-02 prod`, case 4's 4th-dispatch refusal check) — the plan grepped stdout-only captures for the REFUSED/BUDGET lines that dispatch-plan.sh prints to stderr (04-02's frozen contract), so both checks structurally could not pass as written; assertion strings and exit-code checks unchanged"
  - "auto-selftest.sh: added `rm -rf \"$repo/.agents/skills/shippEdd/.git\"` after the skill-tree copy — without it the vendored copy commits as an embedded-repo gitlink, and once auto-selftest.sh is tracked at the source (this task's own commit), the plan's `rm -f` of the vendored script copy dirties the embedded worktree, making case 6's trunk precheck HALT dirty on every post-commit run (reproduced, root-caused, and verified fixed); vendoring as plain files is deterministic and also silences the embedded-repo warning"
  - "TMPDIR was unset in the executor environment (04-02 precedent) — no external export was needed this time: the selftest constructs and exports its own $TMPDIR sandbox internally"
---

# Plan 04-03 Summary: per-target merge-back + the deterministic auto-loop selftest (AUTO-01/04/05/07)

The merge-back layer now speaks 04-02's per-target interface with a bounded budget, and the whole sequential auto loop — dispatch, watch, recovery, budget stops, merge-back, drift — is proven by a deterministic 22-check temp-repo simulation driving the real scripts with scripted executors.

## Accomplishments

- `merge-back.sh` reworked per-target (AUTO-04/AUTO-05): one merge of `agent/<NN>-<slug>/<target>` into the named target branch in that target's own checkout; landed-first idempotence (an already-merged generation exits 0 before any attempt is counted); a 3-attempt budget per agent-branch generation recorded in `$tgt_dir/merge-attempts` with the `BUDGET:` refusal on the fourth; prechecks before the merge; DRIFT/CONFLICT/HALT handoffs naming every stranded artifact and recovery; AUTO-01's safe `git -C <target checkout> branch -d` delete preserved (no `-D` anywhere in the file, grep-proven).
- `auto-selftest.sh` created (AUTO-07 layer 1) and green: a throwaway git repo mirroring this repo's topology (orchestrator branch `trunk` at the repo root, target `prod` in a sibling worktree, per-target agent worktrees under its own $TMPDIR sandbox), the real skill tree vendored in, six fixture plans, and scripted executors injected exclusively via 04-02's `SHIPPEDD_EXECUTOR_CMD` hook. Seven cases, 22 checks: sequential-guard refusal; happy-path watch + per-target worktree reuse; fail-once recovery through `--fix-instructions` (attempt ledger = 2); dispatch budget exhaustion (watch exits 2, 2, then 3 with the BUDGET stop line; the 4th dispatch mechanically refused); clean per-target merge-back with the AUTO-01 branch delete from the sibling checkout plus an idempotent no-burn re-run; a corrupted-fork-base DRIFT halt recovered within the merge budget (2 of 3 attempts used); and the merge-budget refusal on a fresh generation (3 DRIFTs then `BUDGET: merge of agent/09-demo/prod at 3 attempts`).
- Determinism demonstrated: three consecutive `SELFTEST PASSED (22 checks)` runs (including once piped through `tail`/`grep` as the verify specifies), the repo tree clean after every run, sandbox fully removed by its EXIT trap; both selftest deviations were root-caused with minimal repros before fixing (see Decisions).
- Both scripts pass `bash -n`; `merge-back.sh` and the selftest body are byte-identical to the plan text except the three recorded deviations; worktree `git status --porcelain` empty after all commits.

## Task commits

1. **Task 1: Rework merge-back.sh — per-target merge, bounded attempts, -C branch delete** — `12725e0` feat(04-03): merge-back goes per-target with a bounded 3-attempt budget (AUTO-04/05), keeping the -C branch delete
2. **Task 2: Create auto-selftest.sh — the deterministic temp-repo simulation (AUTO-07 layer 1)** — `5c6ba70` test(04-03): auto-selftest.sh — deterministic temp-repo simulation of the sequential auto loop (AUTO-07)

## Files created/modified

- `implement/scripts/merge-back.sh` — per-target merge-back: landed-first idempotence, `merge-attempts` budget gate (≥3 refuses), target-checkout/dirty/fork-base prechecks, fork-base drift validation, `--no-ff` merge with the `merge(<nn-slug>/<target>):` message template, worktree remove + prune, and the AUTO-01 `git -C <target checkout> branch -d` delete
- `implement/scripts/auto-selftest.sh` — new deterministic AUTO-07 layer-1 selftest (executable): builds the mirrored temp repo + vendored skill copy, plays the executor role through `SHIPPEDD_EXECUTOR_CMD`, and asserts all seven loop behaviors end-to-end in ~1–2 minutes

## Decisions & deviations

Followed the plan's scripts verbatim (diff-verified) with three deviations, each a blocker-only minimum recorded in frontmatter: the established path-prefix mapping (04-01/04-02 precedent — same content, worktree-root-relative paths); two `2>&1` stderr captures in the selftest, without which the plan's own case-1/case-4 assertions inspect empty variables (the expected lines are 04-02's frozen stderr contracts — weakening those scripts instead was never an option); and stripping the `.git` pointer from the vendored sandbox copy, without which the plan's verify sequence (commit the selftest, then re-run it green) deterministically fails case 6 — the vendored copy commits as an embedded-repo gitlink that reads dirty once the plan's `rm -f` removes the now-tracked script copy. The amend of Task 2's commit kept the task atomic; the final hash above is the one in the log.

## Next phase readiness

- 04-04 (SKILL.md) can document the exact interfaces now proven by the selftest: `merge-back.sh <state-dir> <NN> <slug> <target-branch>`, the per-target run dir (`worktree/`, `fork-base`, `merge-attempts`), budget lines (`BUDGET: merge of <agent> at 3 attempts`), the landed-first `landed <nn-slug>/<target> → <target> (already merged — nothing to do)` line, and `auto-selftest.sh` as the layer-1 gate for script changes.
- Gate note for the orchestrator (from the plan, unchanged): master's merge-back.sh now speaks the NEW per-target interface and cannot merge this wave's per-plan branch `agent/04-03` — run the gate with the vendored per-plan script (`bash .agents/skills/shippEdd/implement/scripts/merge-back.sh .planning 04 unattended-implement-loop 04-03`) and expect the known post-merge halt at the branch delete, recovering with exactly `git -C 02-worktrees/master branch -d agent/04-03`.
- AUTO-07 layer 2 (the phase's own wave 5 in auto mode, 04-05) can build directly on the selftest's proven mechanics: the SHIPPEDD_EXECUTOR_CMD injection shape, watch-wave's 0/2/3 exit contract, and the merge-budget-per-generation semantics.
