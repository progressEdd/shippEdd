# Phase 04-unattended-implement-loop Context

**Gathered:** 2026-11-17 — via `/skill:define` grilling

## Goal

`/skill:implement` runs a whole phase unattended by default — sequential plan execution in a single worktree per target branch, model-driven failure recovery, and one merge at the end.

## Decisions

| # | Question | Decision | Why |
|---|-----------------------------------|-------------------|------------------------|
| 1 | What should Phase 04 deliver? | Both banked todos — 06 (merge-back fix) + 07 (implement auto-mode) as one phase | the fix is prerequisite to unattended waves; one coherent polish phase |
| 2 | Branch-delete semantics? *(todo 06, locked)* | keep safe `-d`, never `-D`; redirect via `git -C "$wt"` | forced deletes would mask real regressions |
| 3 | Fix scope? *(todo 06, locked)* | merge-back.sh line 63 only; worktree remove/prune unchanged | observed evidence; minimal change |
| 4 | Auto mode opt-in or default? *(todo 07 — reopened by user)* | **auto by default** — unattended is the normal path | user directive 2026-11-17: "by default we want it to be auto" |
| 5 | Merge-back timing? *(todo 07 — reopened, pending topology confirmation)* | per-target: one merge at the end of that target's plan run — or right before the first later plan that consumes it (vendored-refresh pattern) — replacing per-wave | consequence of the sequential single-worktree proposal |
| 6 | watch-wave's source of truth? *(todo 07, locked)* | artifacts (SUMMARY oracle); `$TMPDIR` markers advisory only, PID-liveness aware | mirrors implement's rule 2 |
| 7 | Invocation? *(superseded)* | auto is the default; opt-out mechanism pending Q6 | reopened by auto-default directive |
| 8 | Failure policy? *(reopened by user)* | model-driven recovery — the failed run's result returns to the orchestrating session, which diagnoses and re-dispatches the plan with fix instructions; retry bound pending | user directive: "send the result back… let the model determine how to fix it"; EXEC-08 idempotence makes re-dispatch safe |
| 9 | Proof bar for the loop? | both layers — temp-repo simulation incl. a deliberate failure case, then phase 04's own remaining waves run in the new auto mode as the inaugural live run | deterministic mechanics + real-stakes evidence |
| 10 | Execution topology? | **sequential now** — one temp worktree per target branch, plans run in plan order, merged at end (or right before the first later plan consuming that target); hybrid same-wave parallelism **deferred** to a future phase | user: "default to sequential, hybrid at some future point when I want to return"; revises EXEC-06/07 |
| 11 | Manual mode? | kept as the opt-out — `/skill:implement manual` stops between plans (today's re-entry cadence); auto is the default | debugging path preserved |
| 12 | Retry bound for self-healing? | 2 retries (3 attempts total) per plan, **enforced mechanically by the loop** — then stop and hand the failure dossier to the human; the orchestrator may stop *earlier* when a retry clearly won't help (e.g. blocked on a missing decision — don't burn attempts on it) | user picked 2-retries; "the model itself will stop right?" — yes: hard bound + earlier judgment stop |
| 13 | Merge-back halt recovery? | model-driven, same as plan failures — the orchestrator diagnoses and attempts the git recovery it judges safe, within the same 2-retry/3-attempt bound; if it fails, stop and hand the dossier to the human for review | user: "let the ai model take care of it, if it fails then give back to human to review"; bound carried over from decision 12 for consistency |

## Constraints

- Human stops shrink to the minimum: auto ends at phase completion or when the model genuinely can't proceed
- Phase 02's execution contracts (EXEC-01…05, EXEC-08) hold; EXEC-06/07 (concurrent dispatch, per-wave merge-back) may be revised by the topology decision
- Nothing new writes per-run state into the repo
- Phase ends with the vendored refresh (squash-merge + byte-parity, the 02-06/03-04 flow)

## Open questions

- none — frontier is clear
