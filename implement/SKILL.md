---
name: implement
description: Runs the approved plans of the current phase in background waves — one detached executor per plan, each in its own agent worktree forked from the plan's target branch (parallel across the plans of a wave, one wave at a time) — then merges every agent branch back into its target, serialized in plan order with fork-base validation. Plan state derives from artifacts (NN-YY-SUMMARY.md), never from repo markers; execution writes no per-run files into the repo. Safe to re-run at any time. Run /skill:implement after /skill:define approves plans.
disable-model-invocation: true
---

# shippEdd implement — dispatch the waves, merge the branches

You are the orchestrator for the execution half of the phase loop. You dispatch one detached executor per **plan** into its own agent worktree, and when a wave lands you merge each agent branch back into its target branch — serialized, in plan order, drift-checked, worktrees cleaned up. You never implement anything yourself and never wait on a running wave. Executors own git inside their worktrees; you own git everywhere else: merge-back and the docs-side commit. Nothing this skill runs writes per-run state into the repo — dispatch state (prompt, log, markers, fork base) is transient under `$TMPDIR`, and plan state is derived from artifacts.

`<state>` is the workflow state dir resolved in step 0; all other paths are relative to it or to the repo root. This skill is self-contained: its scripts (`scripts/state-dir.sh`, `scripts/dispatch.sh`, `scripts/dispatch-plan.sh`, `scripts/merge-back.sh`) live in this folder; phase templates live in the skill's own `bootstrap/templates/` (sibling of this skill's folder).

## Ground rules

1. **Orchestrate, don't labor** — executors implement in fresh, detached contexts, each inside its own worktree. Your session sees dispatch lines, run states, and merge lines — never implementation detail.
2. **Artifacts are truth** — plan `NN-YY` is **executed** iff `<state>/phases/<NN>-<slug>/NN-YY-SUMMARY.md` exists with `status: complete` in its frontmatter, and **landed** iff, in addition, its target branch's log carries a `merge(NN-YY):` merge commit. Transient run state in `$TMPDIR` is advisory (liveness, logs); when it is missing — wiped tmp, reboot — derive from artifacts, never treat missing transient state as failure. This skill is idempotent and may be re-run at any moment, mid-run, mid-wave, or between waves.
3. **Wave data is plan-time data** — `wave`, `depends_on`, and `target` were precomputed by the planner into each plan's frontmatter (a missing `target` means `master`). You read them as-is; you never recompute, re-derive, or second-guess them.
4. **Isolation by worktree** — every executor gets its own worktree forked from its plan's target-branch HEAD (fork base recorded at dispatch), so same-wave plans never share a working tree. Same-**target** plans in one wave are a planning defect: step 2's overlap check demotes them to sequential with a visible warning — never silently.
5. **Facts from disk, decisions to the user** — anything readable (summaries, run state, git log, STATE.md) is read, never asked about. Questions use exactly this format (identical to bootstrap's and define's):

   ```
   ❓ <question>
     ➡️ 1. <recommended answer>
       2. <option>
       3. <option>
   ```

6. **Recommend and stop** — nothing auto-fires. After dispatching you stop and tell the user how to come back; the skill ends by naming the next command (`/skill:review`). Never run it yourself.

## Step 0 — resolve the state dir

Run `scripts/state-dir.sh`. It prints exactly one line: the state dir path relative to the repo root (`$PLANNING_DIR` env → `.pi/planning.json` `state_dir` → `.planning`).

If that dir lacks both `STATE.md` and `ROADMAP.md`, no workflow state exists. Say:

> No workflow state found. Run `/skill:bootstrap` first — it creates the skeleton this skill reads.

Then stop.

## Step 1 — ORIENT

Read (never ask for) the state:

- `<state>/STATE.md` — the loop position; the body names the current phase
- `<state>/ROADMAP.md` — this phase's entry and its `Plans:` list (plan IDs + one-liners)
- `<state>/phases/<NN>-<slug>/` — the phase folder: enumerate the `NN-*-PLAN.md` files. Every one is a real plan — placeholder copies are never scaffolded into a phase dir.

Read each plan's frontmatter `wave`, `depends_on`, and `target` as written (rule 3).

**Plan-state oracle** — for each plan `NN-YY`, first match wins:

- **Landed** — `NN-YY-SUMMARY.md` with `status: complete`, and `git log <target> --merges --grep "merge(NN-YY):"` finds the merge commit. Done; nothing to do.
- **Executed, awaiting merge-back** — SUMMARY with `status: complete`, no merge commit yet. Not dispatchable; it feeds the wave gate (step 4).
- **Blocked** — SUMMARY with `status: blocked`. Read its `deviations`; the gate's failure question (step 4) owns it.
- **Skipped** — the plan is recorded under `## Skipped plans` in the phase's `NN-CONTEXT.md`. Closed; /skill:review catches it.
- **No SUMMARY** — consult the transient run dir `${TMPDIR:-/tmp}/shippEdd/<NN>-<slug>/NN-YY/` (advisory only; it may not exist):
  - `NN-YY.running` with a **live** PID (`kill -0 $(head -n1 …)` succeeds) — in flight; report it, offer to watch: `tail <run dir>/NN-YY.log`.
  - `NN-YY.running` with a **dead** PID — aborted or crashed (aborted runs never flip their markers). Offer cleanup: inspect the log, delete the stale marker, redispatch (step 3 — `--force` reuses the worktree and its commits).
  - `NN-YY.failed` — read the one-line reason appended to the marker; the gate's failure question (step 4) owns it.
  - Run dir absent — check for an interrupted run: does branch `agent/NN-YY` exist with commits (`git log agent/NN-YY --oneline`), or do any of the plan's task `<files>` paths show uncommitted changes in your checkout (`git status --porcelain -- <paths>`)? If yes — **interrupted**; put recovery to the user (below). If no — not started; dispatchable.

  An interrupted run gets exactly this question (EXEC-03):

  ```
  ❓ Plan NN-YY shows work on disk but no SUMMARY — an interrupted run. Recover how?
    ➡️ 1. re-execute — redispatch it: the executor verifies and continues the work already committed on agent/NN-YY (never redoes it)
      2. close out manually — you finish or commit the work yourself, then write the SUMMARY or record the skip
      3. mark-and-skip — record it in CONTEXT.md under `## Skipped plans` (plan id, reason, what's missing) so /skill:review catches it
  ```

STATE.md's `next_action` is advisory here, not a gate — artifacts are the resume state (rule 2). If STATE.md and the artifacts disagree, trust the artifacts; the gate re-syncs STATE.md after each wave.

If every plan is landed or skipped — go to step 5.

## Step 2 — WAVE ORDER

Sort the unfinished plans by `wave`, ascending. The **current wave** is the lowest wave containing an unfinished plan; all of its plans dispatch in parallel — each in its own worktree, so parallelism is safe regardless of files. Higher waves wait: their `depends_on` entries point into the current wave or below.

**Target-overlap check** — if two or more plans of the current wave resolve to the same `target`, that wave is demoted to sequential: dispatch one plan, wait until it is landed, then dispatch the next. Announce it visibly and call it what it is:

> ⚠️ wave <n>: plans <ids> share target <branch> — dispatching sequentially. Planning defect: same-target plans belong in different waves (sequence them with `depends_on`).

Show the wave structure, one line per wave, e.g.:

```
wave 1: 02-01, 02-02 · wave 2: 02-03 (needs 02-01, 02-02)
```

## Step 3 — DISPATCH THE CURRENT WAVE

For each plan `NN-YY` of the current wave (parallel unless demoted by the overlap check):

1. Resolve the **summary template**: this skill's sibling `bootstrap/templates/NN-0N-SUMMARY.md` — the skill's own templates; there is no phase copy (nothing scaffolds one, and each executor instantiates the skill's template at write time). If it is missing, stop and recommend rerunning `/skill:bootstrap` (it repairs the skill folder's templates without touching existing content).
2. Dispatch:

   ```
   bash <this skill's folder>/scripts/dispatch-plan.sh NN-YY <state>/phases/<NN>-<slug>/NN-YY-PLAN.md <target> --summary-template <resolved-template> [--model <id>]
   ```

   passing `--model <id>` **only if** `.pi/planning.json` has a `models.executor` entry naming a concrete model id — an absent key (or a tier word like "default", which is not a model id) means inherit the session default. Pass `--force` only when redispatching (it reuses the surviving worktree/branch).

`dispatch-plan.sh` forks the worktree, records the fork base, composes the executor prompt into the run dir, and dispatches via the shared `dispatch.sh` with `--state-dir` pointed at `${TMPDIR:-/tmp}/shippEdd/<NN>-<slug>/NN-YY/`. Report its output lines verbatim, e.g.:

```
dispatched 02-01 (PID 1234) → /tmp/shippEdd/02-auth/02-01/02-01.log
worktree /tmp/shippEdd/02-auth/02-01/worktree (forked master@a1b2c3d)
```

The run-dir path is printed at dispatch — that is where the transient state lives; nothing per-run lands in the repo. Then tell the user they can walk away: re-run `/skill:implement` at any time to gate the wave and dispatch the next, or watch with `tail <run dir>/NN-YY.log` or `bash <this skill's folder>/scripts/dispatch.sh --status --state-dir ${TMPDIR:-/tmp}/shippEdd/<NN>-<slug>`. Stop there — never wait, never poll, never chain the next wave in this visit.

## Step 4 — GATE (on re-entry)

Check every plan of the current wave against the oracle (step 1):

- **Every plan executed or skipped** (every SUMMARY in place, `status: complete` or skipped) — the wave landed. Merge back, serialized, in plan order:

  ```
  bash <this skill's folder>/scripts/merge-back.sh <state> <NN> <slug> <NN-YY>...
  ```

  (every plan id of the wave, YY ascending). Report its output verbatim (`precheck 02-01 → master (checkout …)` then `merged 02-01 → master (d41f2aa) · worktree removed · branch agent/02-01 deleted`). The script pre-checks every plan (target branch exists, has a checkout, checkout clean), then per plan validates the recorded fork base against the current merge-base before its `--no-ff` merge, removes the worktree, deletes the branch. **On halt** (exit 1 with `HALT:` / `DRIFT:` / `CONFLICT:` lines) it names every stranded artifact; present them and one question:

  ```
  ❓ Merge-back halted: <the halt lines>. Recover how?
    ➡️ 1. inspect — show the stranded artifacts named in the halt (git log <branch>, the worktree path) and decide
      2. manual recovery — follow the halt's handoff (fix the target checkout, merge by hand, or re-record the fork base), then re-run /skill:implement to finish the remaining merges
      3. abandon the stranded plan — git worktree remove --force <path>; git branch -D agent/<NN-YY>; record it in CONTEXT.md under `## Skipped plans`
  ```

  After **all** merges succeed — and only now — the docs-side sync and commit (EXEC-05/07): tick the merged plans' checkboxes in ROADMAP's `Plans:` list, update STATE.md's body ("wave <n> executed — <ids> merged into their targets"), then `git add -- <state>` and, if anything staged, `git commit -m "chore(<NN>-<slug>): wave <n> executed — plans <ids> merged, summaries recorded"` in this checkout. Then loop back to step 2 — the next wave becomes current — and dispatch it (step 3).

- **Any plan in flight** (live run) — the wave is still running. Report which plans and how to watch (`tail`, `--status`), then stop: re-run `/skill:implement` to check again. Nothing waits here.
- **Any blocked or failed plan** — one question, grilling format (rule 5):

  ```
  ❓ Plan NN-YY <blocked — its deviations say: … | failed — one-line reason from the marker>. What now?
    ➡️ 1. inspect — show the tail of the run log (path from its dispatch line) and decide from there
      2. redispatch — run it again: dispatch-plan.sh NN-YY <plan> <target> --summary-template <tpl> --force (work already committed on agent/NN-YY is verified and continued, never redone)
      3. skip the plan — record it in CONTEXT.md under `## Skipped plans` (plan id, reason, what's missing) so /skill:review catches it
  ```

  A failure never blocks its siblings — the rest of the wave keeps running while the user decides.
- **A stale run** (dead PID, marker still `.running`) — offer cleanup per step 1, then redispatch (step 3).
- **An interrupted plan** (no SUMMARY, work on disk) — step 1's recovery question.

Visits repeat — gate, merge, sync, dispatch — until every wave's plans are landed or skipped; then step 5.

## Step 5 — COMPLETE

Every plan is landed or skipped. Update `<state>/STATE.md`:

- frontmatter: `next_action: /skill:review`, `progress: executed`
- body: the phase name and a one-line status ("executed — N plans across M waves, merged into their targets in plan order; awaiting review")

Then hand off:

> Phase `<NN>-<slug>` executed — <N> plans across <M> waves, merged into their targets in plan order. Next: `/skill:review` to verify coverage and ship — in a fresh session (clear this context first; everything durable is on disk).

And stop (rule 6).
