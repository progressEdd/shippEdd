---
name: implement
description: Runs the approved plans of the current phase sequentially and unattended (auto mode, the default) — one executor at a time in the phase's per-target agent worktree (one temp worktree per target branch), each run watched to resolution on the SUMMARY oracle, failures recovered by bounded model-driven re-dispatch (2 retries / 3 attempts per plan and per merge), merged per target at phase end or right before the first later plan consuming it. /skill:implement manual is the opt-out that stops between plans. Plan state derives from artifacts (NN-YY-SUMMARY.md), never from repo markers; execution writes no per-run files into the repo. Safe to re-run at any time. Run /skill:implement after /skill:define approves plans.
disable-model-invocation: true
---

# shippEdd implement — run the phase unattended, merge per target

You are the orchestrator for the execution half of the phase loop. The phase's plans run one at a time, in plan order, each a detached executor inside the phase's per-target agent worktree; you watch each run to resolution, gate it on the SUMMARY oracle, recover failures within the bound, and merge each target's agent branch when its merge point comes. You never implement anything yourself and never wait idly — the watch script blocks for you. Executors own git inside their worktrees; you own git everywhere else: merge-back and the docs-side commits. Nothing this skill runs writes per-run state into the repo — dispatch state (prompt, log, markers, fork base, attempt ledgers) is transient under `$TMPDIR`, and plan state is derived from artifacts.

**Auto is the default** — a single visit runs the whole phase: dispatch → watch → gate → recover → … → merge → complete, stopping only at completion, budget exhaustion, or a judgment stop. **`/skill:implement manual` is the opt-out**: it stops after each dispatch (the classic re-entry cadence) and asks — in the grilling format — instead of auto-recovering, at every failure. The mode is the skill's first argument; anything other than `manual` is auto.

`<state>` is the workflow state dir resolved in step 0; all other paths are relative to it or to the repo root. The suite's shared scripts (`dispatch.sh`, `state-dir.sh`, `runs-dir.sh`, `auto-selftest.sh`) live at `.agents/skills/shippEdd/scripts/` (repo-relative); this skill's own scripts (`dispatch-plan.sh`, `watch-wave.sh`, `merge-back.sh`) live in this folder; phase templates live in the skill's own `bootstrap/templates/` (sibling of this skill's folder).

## Ground rules

1. **Orchestrate, don't labor** — executors implement in fresh, detached contexts, inside the phase's per-target worktree. Your session sees dispatch lines, resolution lines, and merge lines — never implementation detail; `watch-wave.sh` does the blocking.
2. **Artifacts are truth** — plan `NN-YY` is **executed** iff `<state>/phases/<NN>-<slug>/NN-YY-SUMMARY.md` exists with `status: complete` in its frontmatter, and **landed** iff, in addition, its target's log carries the phase's per-target merge commit `merge(<NN>-<slug>/<target>):`. Transient run state in the runs home (runs-dir.sh — config-driven, default `${TMPDIR:-/tmp}/shippEdd`) is advisory (liveness, logs, ledgers); when it is missing — wiped tmp, reboot — derive from artifacts, never treat missing transient state as failure. This skill is idempotent and may be re-run at any moment, mid-plan, mid-phase, or after a crash.
3. **Plan-time data is logical order** — `wave`, `depends_on`, and `target` were precomputed by the planner into each plan's frontmatter (a missing `target` means `master`). You read them as-is and never recompute them; they define the sequential order you execute and the merge points you compute in step 2.
4. **Sequential by law** — one executor at a time. All of a target's plans share that target's agent worktree (forked from the target HEAD when the loop first dispatches into it; branch `agent/<NN>-<slug>/<target>`), so later same-target plans build on earlier ones' commits. `dispatch-plan.sh` refuses a second live executor in a target worktree — never race it, never work around the refusal. In branch mode (worktree-less repos, resolved by runs-dir.sh mode) the shared context is the main checkout itself — it switches onto the phase's agent branch while a plan runs; a second live executor is refused the same way.
5. **Facts from disk, decisions to the user** — anything readable (summaries, run state, git log, STATE.md) is read, never asked about. Questions — manual mode and genuine blocks only — use exactly this format:

   ```
   ❓ <question>
     ➡️ 1. <recommended answer>
       2. <option>
       3. <option>
   ```

6. **Bounded recovery** — every failed plan and every merge-back halt gets model-driven recovery: diagnose from the artifacts, repair, retry — at most **2 retries / 3 attempts per plan and per merge**, enforced mechanically (`dispatch-plan.sh` and `merge-back.sh` refuse the fourth; `watch-wave.sh` exits 3 at exhaustion). You may stop **earlier** when a retry clearly cannot help (a missing decision, contradictory instructions) — never burn attempts on hopeless retries; never exceed the budget; never auto-skip a plan. On exhaustion or a judgment stop, present the failure dossier (step 5) and stop.
7. **Recommend and stop** — the visit ends at phase completion or when you genuinely cannot proceed; the skill ends by naming the next command (`/skill:review`). Never run it yourself.

## Step 0 — resolve the state dir

Run `.agents/skills/shippEdd/scripts/state-dir.sh`. It prints exactly one line: the state dir path relative to the repo root (`$PLANNING_DIR` env → `.pi/planning.json` `state_dir` → `.planning`).

If that dir lacks both `STATE.md` and `ROADMAP.md`, no workflow state exists. Say:

> No workflow state found. Run `/skill:bootstrap` first — it creates the skeleton this skill reads.

Then stop.

## Step 1 — ORIENT

Read (never ask about) the state:

- `<state>/STATE.md` — the loop position; the body names the current phase
- `<state>/ROADMAP.md` — this phase's entry and its `Plans:` list (plan IDs + one-liners)
- `<state>/phases/<NN>-<slug>/` — the phase folder: enumerate the `NN-*-PLAN.md` files. Every one is a real plan — placeholder copies are never scaffolded into a phase dir.

Read each plan's frontmatter `wave`, `depends_on`, and `target` as written (rule 3).

**Plan-state oracle** — for each plan `NN-YY`, first match wins:

- **Landed** — `NN-YY-SUMMARY.md` with `status: complete`, and `git log <target> --merges --grep "merge(<NN>-<slug>/<target>):"` finds the phase's per-target merge. When disposition is `pr` (the default), merge-back instead opens a pull request — its receipt line (`PR <url> …` or the `PR unavailable` fallback) is the landing record, and the agent branch stays as the PR head until the PR merges. Done; nothing to do.
- **Executed, awaiting merge-back** — SUMMARY with `status: complete`, its target's phase merge absent. Not dispatchable; it feeds the merge points (step 2) and the gate (step 4).
- **Blocked** — SUMMARY with `status: blocked`. Read its `deviations`; step 5's recovery owns it (manual mode: the failure question).
- **Skipped** — the plan is recorded under `## Skipped plans` in the phase's `NN-CONTEXT.md`. Closed; /skill:review catches it.
- **No SUMMARY** — consult the transient run dir under the runs home (runs-dir.sh — config-driven, default `${TMPDIR:-/tmp}/shippEdd`), `<NN>-<slug>/NN-YY/` (advisory only; it may not exist):
  - `NN-YY.running` with a **live** PID (`kill -0 $(head -n1 …)` succeeds) — in flight; watch it: `bash <skill>/scripts/watch-wave.sh <state> <NN> <slug> NN-YY`.
  - `NN-YY.running` with a **dead** PID, or `NN-YY.failed` — aborted, crashed, or failed; step 5's recovery owns it (read the reason line on `.failed`, the log tail otherwise).
  - Run dir absent — check for an interrupted run: does branch `agent/<NN>-<slug>/<target>` exist with commits, or do any of the plan's task `<files>` paths show uncommitted changes in your checkout? **Auto mode**: an interrupted run is recovered by redispatching with `--force` — the executor verifies and continues the work already done, never redoes it (EXEC-08); only if the on-disk work contradicts the plan (genuine ambiguity) stop and put the EXEC-03 question to the user. **Manual mode**: ask the EXEC-03 question (re-execute / close out manually / mark-and-skip) exactly as before.

STATE.md's `next_action` is advisory here, not a gate — artifacts are the resume state (rule 2). If STATE.md and the artifacts disagree, trust the artifacts; the gate re-syncs STATE.md as plans land.

If every plan is landed or skipped — go to step 6.

## Step 2 — PLAN ORDER AND MERGE POINTS

Sort the unfinished plans by `wave` ascending, then by plan id — **that list is the execution order**; execute it sequentially, one plan at a time, regardless of wave numbers (waves are logical order, not parallelism).

**Merge points** (AUTO-05) — compute from the frontmatter as-is: a target's agent branch merges
(a) right before dispatching the first not-yet-executed plan whose `depends_on` names a plan of that target while itself targeting a different branch — the consumer case (a later plan on a different branch whose `depends_on` names an earlier plan targeting it), or
(b) when that target's last plan (in the order above) has executed — the phase-end case;
whichever comes first. A target with all plans already executed merges at the next merge point unconditionally.

Show the structure before dispatching anything:

```
order:   03-01 (main) → 03-02 (main) → 03-03 (docs) → 03-04 (main)
merges:  main before 03-03 (first consumer) · docs at end
```

## Step 3 — DISPATCH ONE PLAN

1. Resolve the **summary template**: this skill's sibling `bootstrap/templates/NN-0N-SUMMARY.md`. If it is missing, stop and recommend rerunning `/skill:bootstrap` (it repairs the skill folder's templates without touching existing content).
2. **Merge point due?** For each due target whose agent branch is unmerged: run the docs-side commit of every pending SUMMARY first (step 4's first bullet — it keeps the target checkout clean), then

   ```
   bash <this skill's folder>/scripts/merge-back.sh <state> <NN> <slug> <target>
   ```

   Report its output verbatim. When the GitHub mirror is on (`github.mirror` in config), the PR body carries `Closes #N` keywords for the target's open plan issues, and a `PR unavailable` receipt that still pushed the branch names the compare URL — mirror behavior is never-block either way (a mirror miss never halts or fails a merge). In `pr` disposition a successful merge-back prints `PR <url> …`; a `PR unavailable: …` receipt is a success-shaped fallback (exit 0) — report it and continue; the branch waits for a hand-opened PR or an auto-merge re-run. **On halt** (exit 1 with `HALT:` / `DRIFT:` / `CONFLICT:` / `BUDGET:` lines) — step 5's merge recovery.
3. Dispatch:

   ```
   bash <this skill's folder>/scripts/dispatch-plan.sh NN-YY <state>/phases/<NN>-<slug>/NN-YY-PLAN.md <target> --summary-template <resolved-template> [--model <id>]
   ```

   passing `--model <id>` **only if** `.pi/planning.json` has a `models.executor` entry naming a concrete model id. Recovery re-dispatches add `--force` (reuses the surviving worktree/branch) and `--fix-instructions <file>`. Report the output lines verbatim (`dispatched …`, `worktree …`, `attempt n/3`).
4. **Auto mode**: in the same visit, watch the run to resolution —

   ```
   bash <this skill's folder>/scripts/watch-wave.sh <state> <NN> <slug> NN-YY
   ```

   It blocks (heartbeats every ~60s) and prints one resolution line. Exit 0 → step 4. Exit 2 → step 5. Exit 3 → budget exhausted: build the dossier (step 5) and stop. Exit 4 → timeout: report the run dir under the runs home (runs-dir.sh — config-driven, default `${TMPDIR:-/tmp}/shippEdd`), `<NN>-<slug>/NN-YY/`, and stop — inspection needs a human's eyes (or a fresh judgment pass).
   **Manual mode**: stop here. Tell the user: re-run `/skill:implement manual` to gate the plan and dispatch the next, or watch with `tail <run dir>/NN-YY.log`.

## Step 4 — GATE ONE PLAN

- **Docs-side commit (EXEC-05)** — after a plan resolves, commit its SUMMARY so target checkouts stay clean for merge-back:

  ```
  git add -- <state>/phases/<NN>-<slug>/NN-YY-SUMMARY.md
  git commit -m "chore(<NN>-<slug>): NN-YY executed — summary recorded"
  ```

  (skip the commit when nothing staged — e.g. an unchanged re-gate). Executors also flip their plan issue's tasklist line after each task (the prompt contract's `gh-mirror.sh progress` call — config-gated, never-block; a miss lands in their SUMMARY's deviations and is otherwise ignored).
- **More plans remain** → back to step 3 for the next plan in order.
- **Last plan resolved** → for each target with an unmerged agent branch (in first-dispatch order): `bash <this skill's folder>/scripts/merge-back.sh <state> <NN> <slug> <target>` — halts go to step 5. After **all** merges succeed: tick the merged plans' checkboxes in ROADMAP's `Plans:` list, update STATE.md's body ("executed — <ids> merged into their targets"), then `git add -- <state>` and, if anything staged, `git commit -m "chore(<NN>-<slug>): phase executed — plans <ids> merged, summaries recorded"` in this checkout. → step 6.
- **Manual mode re-entry** starts here: re-run the oracle (step 1) on the just-watched plan; a failed or blocked plan gets the grilling question (inspect the log tail / redispatch with `--force` / record the skip in CONTEXT.md's `## Skipped plans`), never silent auto-recovery; merge points fire by the same step 2 rule.

## Step 5 — RECOVERY (auto mode)

**A plan failed or blocked** (watch exit 2/3, or a failed/blocked oracle state):

1. Gather the facts: `tail -n 40` the run log `<NN>-<slug>/NN-YY/NN-YY.log` under the runs home (runs-dir.sh — config-driven, default `${TMPDIR:-/tmp}/shippEdd`); the `.failed` marker's reason line (or the SUMMARY's `deviations`); `git -C <runs-dir.sh worktree-base>/agent/<NN>-<slug>/<target> log --oneline -5` (what already landed).
2. **Judgment stop**: if a retry clearly cannot help — the plan is blocked on a missing decision, the spec contradicts itself, the failure is outside the plan's reach — stop now, dossier below; do not burn attempts.
3. Otherwise write `<runs home>/<NN>-<slug>/NN-YY/fix-<n>.md`: what failed, your diagnosis, and concrete fix instructions for the executor (files, exact changes, what to re-verify).
4. Re-dispatch and watch again (step 3): `dispatch-plan.sh NN-YY <plan> <target> --summary-template <tpl> --force --fix-instructions <fix file>`. The machinery refuses the fourth attempt (`BUDGET:`) — respect it: dossier and stop.

**A merge-back halt** (`HALT:`/`DRIFT:`/`CONFLICT:` lines): they name the stranded artifacts and the sanctioned recovery. Perform the git recovery you judge safe — re-record the fork base after legitimate target advance (`git merge-base agent/<NN>-<slug>/<target> <target> > <tgt run dir>/fork-base`), clean or stash unrelated dirt in the target checkout, resolve a trivial conflict by hand in the target checkout — never `branch -D`, never rewriting published history, nothing beyond what the halt names. Then re-run `merge-back.sh` — the same 2-retry/3-attempt budget applies per agent-branch generation, and it refuses the fourth. Exhausted → dossier and stop.

**Failure dossier** — the exact shape to present when the loop stops:

```
⛔ Plan NN-YY (attempt n/3) — auto recovery exhausted   [or: judgment stop — a retry will not help]
  log:      <runs home>/<NN>-<slug>/NN-YY/NN-YY.log   (tail below)
  reason:   <the .failed marker line, or the SUMMARY's deviations>
  branch:   agent/<NN>-<slug>/<target> — git log --oneline -5
  attempts: <contents of <run dir>/attempts>
Decide: fix by hand and redispatch (--force), re-plan, or record the skip in CONTEXT.md's `## Skipped plans`.
```

(For a merge-back stop, swap in the merge-back halt lines and `<tgt run dir>/merge-attempts`.)

## Step 6 — COMPLETE

Every plan is landed or skipped. Update `<state>/STATE.md`:

- frontmatter: `next_action: /skill:review`, `progress: executed`
- body: the phase name and a one-line status ("executed — N plans sequential, merged per target; awaiting review")

Then hand off:

> Phase `<NN>-<slug>` executed — <N> plans run sequentially and merged into their targets per the merge points. Next: `/skill:review` to verify coverage and ship — in a fresh session (clear this context first; everything durable is on disk).

And stop (rule 7).
