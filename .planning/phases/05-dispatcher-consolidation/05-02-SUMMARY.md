---
status: complete
duration: 30min
key-files:
  created: []
  modified:
    - implement/scripts/dispatch-plan.sh
    - implement/scripts/merge-back.sh
    - implement/SKILL.md
    - implement/README.md
requirements-completed:
  - DISP-04
  - DISP-05
  - DISP-07
key-decisions:
  - "tgt_wt now derives from $agent (tgt_wt=\"$wt_base/$agent\") so the literal agent-branch path is spelled once — the task's verify requires exactly one occurrence and 05-01's file had two"
  - "the executor prompt's working-tree line is mode-aware (prints $root in branch mode) — in branch mode the unchanged ${agent_wt:-$tgt_wt} would name a nonexistent worktree path"
  - "SKILL.md step 5's facts-gathering worktree path reworded to the 05-01 layout (<runs-dir.sh worktree-base>/agent/<NN>-<slug>/<target>) — the old <target>/worktree path predates 05-01 and no longer exists"
  - "runs-home phrasing carries the full parenthetical (runs-dir.sh — config-driven, default ${TMPDIR:-/tmp}/shippEdd) at its named locations (ground rule 2, step 1 oracle) and <runs home> shorthand in step 5"
deviations:
  - "dispatch-plan.sh: agent= moved above tgt_wt=, tgt_wt=\"$wt_base/$agent\" — the verify's `grep -cF 'agent/$slug_dir/$target' | grep -qx 1` cannot pass against 05-01's twice-spelled path; behavior identical"
  - "dispatch-plan.sh: the heredoc's `echo \"  ${agent_wt:-$tgt_wt}\"` is wrapped in the task-1 mode switch (branch mode prints `  $root`) — the plan anchored the paragraph 'after the working-tree line' but left it printing $tgt_wt in branch mode, which would direct the executor to a path that does not exist"
---

# Plan 05-02 Summary: Config-driven work contexts (branch mode) and PR-by-default disposition — dispatch-plan modes, merge-back landing, implement docs + todo 08

The executor dispatch and merge-back now honor the two config-driven work contexts and landing dispositions: branch mode runs executors on the agent branch in the main checkout, and `pr` disposition (default) pushes the agent branch and opens a PR with a never-fail receipt fallback; implement's docs describe both and carry todo 08's repo-neutral example.

## Accomplishments

- `dispatch-plan.sh` resolves `runs-dir.sh mode`: worktrees mode is byte-identical to 05-01 (fork/reuse/re-attach, receipts, prompt paragraph, same-target sequential guard, output anchors — verified live in a temp repo); branch mode refuses a tracked-dirty main checkout (`REFUSED: branch mode needs a clean main checkout`), creates/reuses `agent/<NN>-<slug>/<target>` checked out in the main checkout, records `fork-base` under the runs home, never calls `git worktree add`, prompts the executor with the main-checkout/whole-repo contract, and receipts `worktree <root> (main checkout, branch mode)`. The sequential guard refuses ANY live sibling in branch mode (`(sequential topology) (branch mode)`), same-target only in worktrees mode — both verified live.
- `merge-back.sh` resolves `mode` + `disposition`: `pr` pushes the agent branch and opens `gh pr create --base <target> --head <agent>` (already-open PR is idempotent; success keeps the branch as PR head and removes the worktree); every PR-path failure (no gh / no remote / unauthenticated / push / create) hits the never-fail `pr_fallback` — exit 0, nothing merged or deleted, receipt naming the by-hand `gh` command and the `"disposition": "auto-merge"` switch. `auto-merge` keeps 05-01's flow byte-for-byte; branch mode merges in the main checkout (switching it back to the target first, restoring the agent checkout on conflict, tolerating dirt only under `<state>/phases/`). All verified live in a temp-repo matrix: auto-merge × both modes, conflict, drift, already-landed idempotence, and both fallback shapes.
- implement `SKILL.md` + `README.md`: shared-scripts sentence (`.agents/skills/shippEdd/scripts/`) and full-path `state-dir.sh` invocation; branch-mode ground-rule 4 appendix; runs-home phrasing replacing every hardcoded `${TMPDIR:-/tmp}/shippEdd` path; Landed-oracle PR clause and step 3.2's success-shaped `PR unavailable` guidance; README disposition/`runs.mode` documentation, branch-mode prerequisites, truthful-receipts bullet. Todo 08 fixed (DISP-07): the `04-0x (master/progressEdd)` illustration is now the neutral `03-0x (main/docs)` one and the consumer-case parenthetical is repo-agnostic.
- Plan checklist: all task verifies green; `bash -n` clean; resolver probe prints `branch` (no linked worktrees) then `worktrees` (after `git worktree add`); every header grep anchor verified unchanged against 05-01's commits (line-level comparison; the three intentional deltas are the plan-prescribed REFUSED interpolation — byte-identical output in worktrees mode, proven live — and strings duplicated into the new branch/PR arms exactly as the plan's code blocks specify).

## Task commits

1. **Task 1: dispatch-plan.sh branch mode + mode-aware guard** — `aa827cf` feat(05-02): dispatch-plan branch mode — executors on a new branch in the main checkout, config-driven (DISP-04)
2. **Task 2: merge-back.sh branch-mode merge + PR-by-default disposition** — `332bf62` feat(05-02): merge-back PR-by-default disposition + receipt fallback, branch-mode merge (DISP-04/05)
3. **Task 3: implement SKILL.md + README.md wording, todo 08 fix** — `c9b700a` docs(05-02): implement skill/README — modes + disposition wording, shared-script paths; todo 08 example fix (DISP-04/05/07)

## Files created/modified

- `implement/scripts/dispatch-plan.sh` — mode resolution, branch-mode fork block (dirty-checkout refusal, branch re-attach/fork in the main checkout), mode-aware guard/prompt/receipt
- `implement/scripts/merge-back.sh` — mode-aware prechecks (single `agent_wt` computation, branch-mode dirt tolerance), `pr` disposition with never-fail receipt fallback, branch-mode switch-back and conflict restore, reworded DRIFT/CONFLICT handoff paths
- `implement/SKILL.md` — shared-script paths, branch-mode sequential rule, runs-home phrasing, PR landing record + fallback guidance, todo-08-neutral example
- `implement/README.md` — disposition + `runs.mode` documentation, per-mode prerequisites, truthful-receipt bullet, runs-home run-dir phrasing

## Decisions & deviations

Decisions: the four in the frontmatter — the `$agent`-derived `tgt_wt` (verify contract), the mode-aware prompt working-tree line (branch mode must name the real checkout), the 05-01-layout facts-gathering path in step 5, and the runs-home phrasing placement. Deviations: the two in the frontmatter, both minimum edits that unblocked a verify/spec contradiction; neither changes worktrees-mode behavior or any anchored output string.

## Next phase readiness

Machinery + docs shipped for DISP-04/05/07. 05-05's extended selftest (DISP-06) can now exercise both modes and both dispositions end-to-end; 05-03/05-04 (define/review sides, disjoint files) proceed unaffected. The happy-path PR create (real remote + gh) was grep- and code-verified but not live-tested here (no remote in the sandbox) — the fallback paths and auto-merge were live-tested.
