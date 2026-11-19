## What it does

`/skill:implement` turns approved plans into finished work — **unattended by default**. Auto mode runs the phase's whole plan list sequentially in one visit: each plan goes to a detached executor inside the phase's **per-target agent worktree** (one temp worktree per target branch, forked from the target HEAD when the loop first dispatches into it, shared sequentially by that target's plans), the loop watches each run to resolution on the SUMMARY oracle, commits each SUMMARY as it lands, and merges every target's agent branch at its merge point — at phase end, or right before the first later plan that consumes that target (the vendored-refresh pattern). **Auto mode is the default**; `/skill:implement manual` is the opt-out that stops between plans (the classic re-entry cadence) and asks, rather than auto-recovers, at every failure.

Recovery is model-driven and bounded: a failed run's result returns to the orchestrating session, which diagnoses and re-dispatches the plan with fix instructions — at most **2 retries / 3 attempts per plan, and the same per merge**, enforced mechanically (the scripts refuse the fourth; the watcher reports exhaustion). The loop may stop earlier when a retry clearly cannot help (e.g. blocked on a missing decision), and on exhaustion it stops and hands over a full failure dossier: log path, failure reason, branch state, attempt ledger. Nothing per-run is written into the repo — dispatch state, attempt ledgers, and fork bases live under `$TMPDIR`; plan state derives from artifacts (`NN-YY-SUMMARY.md` with `status: complete` = executed; the target's `merge(<NN>-<slug>/<target>):` commit = landed). Merge-back lands work per the config's `disposition` — `pr` by default (push + `gh pr create`, receipt fallback when gh or a remote is absent: the branch stays and the receipt names the options), `auto-merge` for the local merge. The GitHub mirror rides along opt-in: executors flip tasklist lines on their plan's issue as tasks complete, PR bodies carry `Closes #N` for the plan issues they land, and a gh failure with a working push leaves the branch pushed with a compare URL — never-block on every path. Executor work contexts are config-driven too (`runs.mode` in config.json): worktrees under the detected/configured folder when the repo has them, a new branch in the main checkout otherwise.

## When to reach for it

- `/skill:define` just approved plans — implement is the command define ends by naming; with auto mode you can walk away for the whole phase.
- A plan failed mid-phase — auto mode recovers it (diagnose → fix instructions → redispatch) within the budget; manual mode offers inspect / redispatch / skip in the grilling format.
- After a crash, reboot, or abandoned session — re-run it; artifacts and git log say exactly what finished. Missing `$TMPDIR` state is never a failure: the oracle derives from artifacts (attempt ledgers reset with a wiped tmp — the budget is per-loop-run).
- You want to watch a live run — `tail` the log path printed at dispatch, or `bash <skill>/scripts/dispatch.sh --status --state-dir <run dir>`.

## Prerequisites

- A shippEdd state dir (`/skill:bootstrap`) with a phase that has approved plans (`/skill:define`).
- git identity configured (`user.name` / `user.email`) — executors and the gate commit with it.
- In worktrees mode: every plan's `target` branch checked out in some worktree with a clean tree at merge time. In branch mode (worktree-less repos): the main checkout clean of tracked changes at dispatch and merge time — it switches onto the phase's agent branch while plans run. The gate commits each SUMMARY as it lands precisely so the target checkouts stay clean.

## Common questions

**Why sequential now?**
One executor at a time, all of a target's plans sharing its worktree, was chosen over same-wave parallelism: later same-target plans build directly on earlier ones' commits, merges become one bubble per target, and the loop needs no babysitting between waves. Hybrid parallelism (concurrent plans on different targets) is deferred, not rejected — the `wave`/`depends_on` frontmatter still carries the logical order, so a future phase can re-introduce parallelism without re-planning old phases.

**Who merges, and when?**
The orchestrator gate, never the executor. A target's agent branch merges with `--no-ff` right before the first later plan that consumes it, or when its last plan has executed — validated against the recorded fork base first; drift or conflict halts with a handoff naming the plan, branch, worktree, and SHAs. Docs-side commits (each SUMMARY as it lands; ROADMAP ticks + STATE sync after the merges) land on the planning branch.

**What happens when a plan fails?**
The watcher resolves the failure and hands the facts to the loop; the loop diagnoses (log tail, marker reason, branch state) and, unless a retry is clearly hopeless, writes fix instructions and re-dispatches with `--force` (prior commits are verified and continued, never redone). Three attempts is the hard ceiling — the fourth dispatch is mechanically refused and the loop stops with the dossier. The human then fixes by hand, re-plans, or records the skip.

**What's in the failure dossier?**
The run log's path (with tail), the one-line failure reason, the agent branch's last commits, and the attempt ledger — everything needed to decide without re-deriving context.

**How do I check on a running phase?**
The dispatch line prints the run dir (under the runs home — runs-dir.sh resolves it; default `${TMPDIR:-/tmp}/shippEdd`): `tail` the log there, or run `dispatch.sh --status --state-dir` against it. The loop itself prints a heartbeat while watching.

## It's working if

- One `/skill:implement` visit takes a phase from approved plans to merged targets without re-entry — sequential dispatches, one resolution line per plan, one merge bubble per target per phase (`merge(<NN>-<slug>/<target>):` on each target's log).
- Each executed plan leaves exactly one durable artifact: `NN-YY-SUMMARY.md`, committed by the gate as it lands.
- A deliberately failing plan recovers via fix-instructions within 3 attempts, or stops the loop with the dossier — never a fourth silent attempt; a clean merge-back never halts (the branch delete runs from the target's own checkout).
- `bash <skill>/scripts/auto-selftest.sh` passes — the deterministic temp-repo simulation of the whole loop (scripted executors, a deliberate failure case, budget and drift halts).
- Merge-back receipts tell the truth: a PR line carries a real URL; without gh/remote the receipt names the by-hand command and the auto-merge switch, exits 0, and leaves the branch in place.
- Mirror receipts never lie either: with the mirror on, PR bodies carry `Closes #N` lines for the target's open plan issues; a gh failure with a working push leaves the branch pushed with a compare URL in the receipt; nothing mirror-related ever fails a task, a merge, or the loop.
- Re-running `/skill:implement` at any moment is safe: landed plans are skipped, in-flight ones watched, interrupted ones re-dispatched with `--force` (idempotence by law).

## Where it fits

Role: the execution step of the phase loop — the only skill that dispatches implementation work. Neighbours: `/skill:define` before it, which produces the approved plans (and precomputes the waves, dependencies, and targets); `/skill:review` after it, which verifies coverage against requirements and decisions, then ships. `/skill:todo` takes stray ideas mid-execution so they don't derail a running phase.
