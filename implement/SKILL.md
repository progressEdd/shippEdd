---
name: implement
description: Runs the approved plans of the current phase in background waves — one detached executor per task (plans are sliced into self-contained per-task prompts; parallel across the plans of a wave, sequential within a plan, one wave at a time) — then replays their recorded commit specs in plan order. Safe to re-run at any time; run markers are the resume state. Run /skill:implement after /skill:define approves plans.
disable-model-invocation: true
---

# shippEdd implement — dispatch the waves, replay the commits

You are the orchestrator for the execution half of the phase loop. You dispatch one detached executor per **task** — each plan is sliced into self-contained per-task prompts, so a fresh context is fed one task block, never the whole plan — and after a wave lands you replay the commit specs those executors recorded. You never implement anything yourself, never touch git, and never wait on a running wave — executors don't commit (parallel siblings share the working tree, so one sequencer commits for all of them, sequentially, after the wave is done).

`<state>` is the workflow state dir resolved in step 0; all other paths are relative to it or to the repo root. This skill is self-contained: its scripts (`scripts/state-dir.sh`, `scripts/dispatch.sh`, `scripts/replay-commits.sh`, `scripts/slice-tasks.sh`) live in this folder.

## Ground rules

1. **Orchestrate, don't labor** — executors implement in fresh, detached contexts, each fed a single task block. `slice-tasks.sh` composes the per-task prompts mechanically, so your session sees dispatch lines, markers, and commit lines — never implementation detail.
2. **Markers are truth** — a run's state is its marker file in `<state>/runs/`, never session memory. Task runs carry ids `NN-YY-TT` (plan `NN-YY`, task `TT` in plan order); a plan's own `.done` marker (stamped at the gate once every task marker is `.done`) plus its `committed` line is the resume state. This skill is idempotent and may be re-run at any moment, mid-task, mid-wave, or between waves.
3. **Wave data is plan-time data** — `wave` and `depends_on` were precomputed by the planner into each plan's frontmatter. You read them as-is; you never recompute, re-derive, or second-guess them.
4. **Tasks are disjoint or sequential** — the planner guarantees no two same-wave plans touch the same file, so tasks from different plans of one wave are file-disjoint and dispatch in parallel; tasks *within* a plan always run sequentially, in plan order (later tasks build on earlier ones). Same-file plans were sequenced into different waves via `depends_on` at plan time (see README for the collision case).
5. **Facts from disk, decisions to the user** — anything readable (markers, logs, STATE.md) is read, never asked about. Questions use exactly this format (identical to bootstrap's and define's):

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
- `<state>/phases/<NN>-<slug>/` — the phase folder: enumerate the `NN-YY-PLAN.md` files. A filename whose stem still contains `YY` is the on-deck template, not a plan.

Read each plan's frontmatter `wave` and `depends_on` as written — precomputed at plan time (rule 3).

**Which plans remain**: for each plan, enumerate its task blocks in order (task `T<k>` = its k-th `<task>` block). Plan `NN-YY` is finished iff `<state>/runs/NN-YY.done` exists and carries a `committed` line; `.running`, `.failed`, or no marker means it isn't. STATE.md's `next_action` is advisory here, not a gate — markers and `committed` lines are the resume state, so re-running mid-phase, mid-task, mid-wave, or after an interruption works without ceremony. If STATE.md and the markers disagree, trust the markers; step 5 re-syncs STATE.md at the end.

**Marker-gate every task run** — for each `NN-YY-TT` that has a marker:

- `.done` — that task is finished; the plan's next task (if any) becomes dispatchable.
- `.running` with a **live** PID — report it as running; offer to wait (re-run `/skill:implement` later) or watch: `bash <this skill's folder>/scripts/dispatch.sh --status`, `tail <state>/runs/NN-YY-TT.log`.
- `.running` with a **dead** PID — an aborted or crashed run: aborted runs never flip their markers. Offer cleanup: inspect the log, then delete the stale marker and redispatch (step 3).
- `.failed` — read the one-line reason appended to the marker; offer inspect / redispatch `--force` on that task id. If the failure blocks the wave gate, step 4 handles it.

A plan whose task markers are all `.done` but which has no plan marker yet is awaiting its gate stamp (step 4) — not an error, nothing to dispatch.

If no plans remain — everything `.done` with a `committed` line — go to step 5.

## Step 2 — WAVE ORDER

Sort the unfinished plans by `wave`, ascending. The **current wave** is the lowest wave containing an unfinished plan; all of its plans dispatch in parallel — they are file-disjoint by the planner's guarantee (rule 4). Higher waves wait: their `depends_on` entries point into the current wave or below.

**The dispatch set**: for each plan in the current wave, its first task that has no `.done` marker and whose predecessors are all `.done` — at most one task per plan per visit (tasks within a plan never run concurrently; later visits pick up its next tasks).

Show the wave structure, one line per wave, e.g.:

```
wave 1: 01-01, 01-02 · wave 2: 01-03 (needs 01-01)
```

## Step 3 — DISPATCH THE NEXT TASKS

For each plan `NN-YY` in the current wave, slice it and dispatch its next unfinished task (step 2's dispatch set).

**Slice** — prompts are composed mechanically, never by hand:

```
bash <this skill's folder>/scripts/slice-tasks.sh <state> <NN> <YY> <slug> <summary-template-path>
```

It reads the plan and writes `<state>/runs/<NN>-<YY>-T1..Tk.prompt.md`, each fully self-contained (the detached run loads nothing else): the executor persona, the plan's objective, that one task block verbatim, the commit-spec contract, and — for the final task — the plan's verification checklist and the summary artifact. Existing prompts are never overwritten; after editing a plan, delete its `*-T*.prompt.md` files before re-slicing. If it reports no `<task>` blocks, the plan is malformed — report and stop.

**Summary template fallback chain** (pass the resolved path to the slicer): the phase's on-deck `<NN>-YY-SUMMARY.md` (left there by `define`); if missing, `<state>/phases/_templates/NN-YY-SUMMARY.md`; if that is missing too, `.agents/skills/shippEdd/bootstrap/templates/NN-YY-SUMMARY.md`. If all three are absent, stop and recommend rerunning `/skill:bootstrap` (it repairs the skeleton without touching existing content).

**Dispatch** each dispatchable task with `scripts/dispatch.sh <NN>-<YY>-T<T> <state>/runs/NN-YY-TT.prompt.md`, passing `--model <id>` **only if** `.pi/planning.json` has a `models.executor` entry naming a concrete model id — an absent key (or a tier word like "default", which is not a model id) means inherit the session default.

Report each dispatch.sh output line to the user verbatim, e.g.:

```
dispatched 01-01-T2 (PID 1234) → .planning/runs/01-01-T2.log
```

Then tell the user they can walk away: re-run `/skill:implement` at any time to gate the tasks and dispatch the next ones, or watch progress with `bash <this skill's folder>/scripts/dispatch.sh --status` / `tail <state>/runs/NN-YY-TT.log`. Stop there — never wait, never poll, never chain the next tasks or wave in this visit.

## Step 4 — GATE (on re-entry)

Check every plan in the current wave (step 2), task markers first:

- **Every task of every plan `.done`** — the wave landed. Stamp each plan marker: `printf 'tasks complete\n' > <state>/runs/NN-YY.done` for each plan of the wave. Then run `scripts/replay-commits.sh` and report its output lines verbatim (they read `committed 01-01: a1b2c3d feat(01-01): …`). The sequencer validates every TSV line first, then commits each plan's recorded task specs sequentially in plan order, then appends `committed <short-sha>` to each plan's `.done` marker — so re-runs never double-commit, and a plan that recorded no TSV is stamped `committed none`. If replay refuses (a spec lists a path that doesn't exist), its message names the plan and path: fix or remove that TSV line, rerun replay, and continue. Then loop back to step 2 — the next wave becomes current — and dispatch its first tasks (step 3).
- **Tasks still dispatchable** (some plan's next task has all predecessors `.done`) — dispatch them (step 3) and stop.
- **Any task `.failed`** — one question, grilling format (rule 5):

  ```
  ❓ Task NN-YY-TT failed: <one-line reason from the marker>. What now?
    ➡️ 1. inspect — show tail of <state>/runs/NN-YY-TT.log and decide from there
      2. redispatch — run that task again from scratch: dispatch.sh NN-YY-TT <its prompt> --force (on-disk work from the failed attempt stays for it to build on or overwrite)
      3. skip the plan — continue without it: append `skipped <reason>` to each of its task markers, create the plan marker with the same skipped line, and record the gap in CONTEXT.md under a `## Skipped plans` heading (plan id, reason, what's missing) so /skill:review catches it
  ```

  A failure never blocks its siblings — the rest of the wave keeps running while the user decides. Later tasks of the failed task's plan wait: their predecessors aren't `.done`.
- **Any `.running` with a live PID** — the wave is still in flight. Report which tasks are pending and how to watch them (`--status`, `tail`), then stop: re-run `/skill:implement` to check again. Nothing waits here.
- **A stale `.running` (dead PID)** — offer cleanup per step 1, then redispatch that task (step 3).

Visits repeat — gate, stamp, replay, dispatch — until every wave's plans are `.done` and committed; then step 5.

## Step 5 — COMPLETE

Every plan is `.done` and carries a `committed` line. Update `<state>/STATE.md`:

- frontmatter: `next_action: /skill:review`, `progress: executed`
- body: the phase name and a one-line status ("executed — N plans (K tasks) across M waves, commits replayed in plan order; awaiting review")

Then hand off:

> Phase `<NN>-<slug>` executed — <N> plans across <M> waves, commits in git history in plan order. Next: `/skill:review` to verify coverage and ship.

And stop (rule 6).
