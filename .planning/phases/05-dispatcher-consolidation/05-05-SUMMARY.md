---
status: complete
duration: 75m
key-files:
  created: []
  modified:
    - scripts/auto-selftest.sh
requirements-completed:
  - DISP-06
key-decisions:
  - "The plan's frozen premise (cases 1–7 already green) was false on this branch: 05-02's pr-default disposition made every auto-merge-era merge-back take the PR receipt fallback — so the seven existing cases are pinned to the disposition they test via sandbox config instead of rewriting their substance"
  - "One command now re-proves phases 04+05: 12 cases, 35 checks, zero failures — the verifier-citable DISP-06 proof bar"
deviations:
  - "05-05-D0 (scripts/auto-selftest.sh): cases 5–7 run under a sandbox config {\"disposition\":\"auto-merge\"} (written before case 5, removed before case 8) — the plan claimed they 'currently pass', but 05-02 flipped the default to pr and they failed 6 checks via the no-remote receipt fallback; pinning preserves their substance exactly (merge/delete/DRIFT/budget) and mirrors the plan's own case-10 pattern"
  - "05-05-D3 (scripts/auto-selftest.sh): case 8's --status check captures output then greps instead of piping into grep -qF — grep -q exits at first match, dispatch.sh takes SIGPIPE(141) mid-list, and the selftest's pipefail fails the pipeline despite the match (reproduced deterministically)"
  - "05-05-D4 (scripts/auto-selftest.sh): fake-executor wt extraction prepends a normalizer sed ('s/^.* \\(Your working tree:\\)$/\\1/') before the plan's extractor — the composed prompt carries 'Your working tree:' as a sentence tail, so the plan's ^Your working tree:$ address never matched (every fake run failed with an empty wt); the plan's exact sed expression is retained verbatim after the normalizer, satisfying Task 2's verify grep"
  - "05-05-D1 (scripts/auto-selftest.sh): case 11 removes the case-7/9 prod strand (git worktree remove + git branch -D) before dispatching 09-07 — case 7 deliberately strands the generation with an exhausted merge budget and corrupted fork-base, so case 11's merge-back would BUDGET-refuse instead of exercising the PR path; the plan presumes a fresh generation it never resets"
  - "05-05-D2 (scripts/auto-selftest.sh): cases 11/12 assert 'no NEW merge(09-demo/prod) commit' via before/after count equality instead of the plan's history-wide negated git-log grep — case 5 legitimately landed exactly such a merge commit on prod, making the plan's assertion permanently false"
  - "05-05-D5 (scripts/auto-selftest.sh): case 10 writes repo2's auto-merge config with the fixture (committed) instead of after the watch — as planned, the untracked config made branch-mode merge-back HALT 'dirty beyond phase artifacts' (the dirt filter tolerates only .planning/phases/ artifacts); the untracked-SUMMARY tolerance the case means to prove still applies"
---

# Plan 05-05 Summary: auto-selftest.sh extended to the twelve-case phase-04+05 cumulative proof (DISP-06)

`scripts/auto-selftest.sh` now proves the whole dispatcher consolidation in one command: the seven phase-04 cases (pinned to the auto-merge disposition they were written for) plus five new phase-05 cases — shared dispatch, config placement, branch-mode fallback, PR receipt fallback, PR create — 35 checks, zero failures.

## Accomplishments

- Case 8 (DISP-01/02): a scripted define-style dispatch through `.agents/skills/shippEdd/scripts/dispatch.sh` lands marker+log under the runs home and leaves `.planning/` runs-free (asserted twice, including a bad() if `.planning/runs` appears); `--status --state-dir` lists the run.
- Case 9 (DISP-03/04): `{"runs":{"dir":"wt-home"}}` relocates markers to `wt-home/09-demo/`, the agent branch's worktree is honored under the configured base or via existing-checkout reuse, and watch-wave resolves through the config-driven home; config restored to absent-defaults afterward.
- Case 10 (DISP-04): a worktree-less second sandbox auto-detects `branch`; dispatch switches its main checkout onto `agent/10-demo/main` (receipt `worktree <repo2> (main checkout, branch mode)`); branch-mode merge-back lands the merge, restores `main`, deletes the agent branch — tolerating the uncommitted SUMMARY under `.planning/phases/`.
- Case 11 (DISP-05): with no remote, merge-back exits 0 with the `PR unavailable:` receipt, `branch agent/09-demo/prod stays`, and the `"disposition": "auto-merge"` option; branch present, no new merge — deterministic on `no git remote` even on hosts with gh installed and authenticated (as here).
- Case 12 (DISP-05): fake gh (PATH-shadowing) + bare remote → `PR <url>` receipt, `pr create --base prod --head agent/09-demo/prod` recorded in the gh-calls log, branch pushed and present locally and in the remote, its worktree removed, no local merge commit.
- Fake executor made mode-blind (working tree read from the line after "Your working tree:"), serving worktrees and branch modes with one extraction; cases 1–7 untouched in substance and green.
- `bash scripts/auto-selftest.sh` → `SELFTEST PASSED (35 checks)`, stable across repeated runs; leaves nothing outside its own $TMPDIR sandbox.

## Task commits

1. **Task 1: Cases 8 (dispatcher migration) and 9 (config-driven placement)** — `dfa0fb9` test(05-05): selftest cases 8–9 — dispatcher migration + config placement (DISP-06)
2. **Task 2: Cases 10 (branch fallback), 11 (PR receipt fallback), 12 (PR create via fake gh)** — `66286b1` test(05-05): selftest cases 10–12 — branch fallback, PR receipt fallback, PR create (DISP-04/05/06)

## Files created/modified

- `scripts/auto-selftest.sh` — the cumulative selftest: header names all twelve cases + DISP-06; fixture loop writes seven plans (09-01…09-07); mode-blind fake executor; cases 8–12 appended; cases 5–7 pinned to auto-merge disposition (deviation D0)

## Decisions & deviations

Six deviations, all forced by reality contradicting the plan's premises, each the minimum change that unblocked the affected task (full what/why in frontmatter):

- **D0** — pin cases 5–7 to `auto-merge` via sandbox config (plan premise "currently passes with cases 1–7" was false; 05-02's pr default broke them).
- **D3** — case 8 `--status` check captures then greps (SIGPIPE × pipefail made the plan's pipeline always-fail despite matching).
- **D4** — normalize the prompt's sentence-tail "Your working tree:" to a standalone line before the plan's verbatim sed extractor (its `^…$` address otherwise never matched; every fake run failed).
- **D1** — case 11 tears down case 7's budget-exhausted, fork-base-corrupted prod strand so the PR-fallback case gets the fresh generation the plan presumes.
- **D2** — cases 11/12 assert no *new* merge commit via count equality (case 5's legitimate merge makes the plan's history-wide negation unsatisfiable).
- **D5** — case 10 commits repo2's auto-merge config with the fixture (as planned it was untracked and HALTed branch-mode merge-back's dirt filter).

Observations outside plan scope (no work done, for the orchestrator's ledger): `dispatch.sh --status` reports `log 0 bytes` for dispatch-plan-shaped runs because their logs sit beside the markers in run subdirs rather than at `$home/<id>.log` (cosmetic); `runs-dir.sh` exits 128 when invoked outside a git repo (`git worktree list | awk` under pipefail) — encountered only in scratch tooling, not in any skill flow.

## Next phase readiness

The DISP-06 proof bar is met: one command re-proves phases 04+05 end to end and is citable by the verifier. The branch (agent/05-dispatcher-consolidation/master) carries all wave-3 plans' work through 05-05 with a clean tree; ready for the gate's review and merge-back.
