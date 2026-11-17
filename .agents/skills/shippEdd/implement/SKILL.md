---
name: implement
description: Runs the approved plans of the current phase in background waves — one detached executor per plan, which reads the plan markdown and walks its task sections itself (parallel across the plans of a wave, sequential within a plan, one wave at a time) — then replays their recorded commit specs in plan order. Safe to re-run at any time; run markers are the resume state. Run /skill:implement after /skill:define approves plans.
disable-model-invocation: true
---

# shippEdd implement — dispatch the waves, replay the commits

You are the orchestrator for the execution half of the phase loop. You dispatch one detached executor per **plan** — a fresh context that reads the plan markdown and walks its `<task>` sections itself, in order — and after a wave lands you replay the commit specs that executor recorded. You never implement anything yourself, never touch git, and never wait on a running wave — executors don't commit (parallel siblings share the working tree, so one sequencer commits for all of them, sequentially, after the wave is done).

`<state>` is the workflow state dir resolved in step 0; all other paths are relative to it or to the repo root. This skill is self-contained: its scripts (`scripts/state-dir.sh`, `scripts/dispatch.sh`, `scripts/replay-commits.sh`) live in this folder.

## Ground rules

1. **Orchestrate, don't labor** — executors implement in fresh, detached contexts; each is dispatched with an inline assignment (persona → plan → walk the task sections → record commit specs → flip your marker). Your session sees dispatch lines, markers, and commit lines — never implementation detail.
2. **Markers are truth** — a run's state is its marker file in `<state>/runs/`, never session memory. Plan `NN-YY` is finished iff `<state>/runs/NN-YY.done` exists and carries a `committed` line. This skill is idempotent and may be re-run at any moment, mid-run, mid-wave, or between waves.
3. **Wave data is plan-time data** — `wave` and `depends_on` were precomputed by the planner into each plan's frontmatter. You read them as-is; you never recompute, re-derive, or second-guess them.
4. **Plans are disjoint, sections are sequential** — the planner guarantees no two same-wave plans touch the same file, so the wave's plans dispatch in parallel; the sections *within* a plan are the executor's to run sequentially, in plan order. Same-file plans were sequenced into different waves via `depends_on` at plan time (see README for the collision case).
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

**Which plans remain**: plan `NN-YY` is finished iff `<state>/runs/NN-YY.done` exists and carries a `committed` line; `.running`, `.failed`, or no marker means it isn't. STATE.md's `next_action` is advisory here, not a gate — markers and `committed` lines are the resume state, so re-running mid-phase, mid-run, mid-wave, or after an interruption works without ceremony. If STATE.md and the markers disagree, trust the markers; step 5 re-syncs STATE.md at the end.

**Marker-gate each plan run** — for each `NN-YY` that has a marker:

- `.done` — the plan's sections are complete (the executor also recorded its commit specs in `<state>/runs/NN-YY.commits.tsv` and wrote the plan summary); it awaits the wave gate (step 4), nothing to dispatch.
- `.running` with a **live** PID — report it as running; offer to wait (re-run `/skill:implement` later) or watch: `bash <this skill's folder>/scripts/dispatch.sh --status`, `tail <state>/runs/NN-YY.log`.
- `.running` with a **dead** PID — an aborted or crashed run: aborted runs never flip their markers. Offer cleanup: inspect the log, then delete the stale marker and redispatch (step 3).
- `.failed` — read the one-line reason appended to the marker; offer inspect / redispatch `--force` on that plan. If the failure blocks the wave gate, step 4 handles it.

If no plans remain — everything `.done` with a `committed` line — go to step 5.

## Step 2 — WAVE ORDER

Sort the unfinished plans by `wave`, ascending. The **current wave** is the lowest wave containing an unfinished plan; all of its plans dispatch in parallel — they are file-disjoint by the planner's guarantee (rule 4). Higher waves wait: their `depends_on` entries point into the current wave or below.

**The dispatch set**: every unfinished plan of the current wave (one executor per plan; that executor owns all of the plan's task sections).

Show the wave structure, one line per wave, e.g.:

```
wave 1: 01-01, 01-02 · wave 2: 01-03 (needs 01-01)
```

## Step 3 — DISPATCH THE CURRENT WAVE

For each plan `NN-YY` in the dispatch set, dispatch it:

```
bash <this skill's folder>/scripts/dispatch.sh NN-YY <state>/phases/<NN>-<slug>/NN-YY-PLAN.md <summary-template-path>
```

passing `--model <id>` **only if** `.pi/planning.json` has a `models.executor` entry naming a concrete model id — an absent key (or a tier word like "default", which is not a model id) means inherit the session default.

**Summary template fallback chain** (the template the executor instantiates as `NN-YY-SUMMARY.md` after its final section): the phase's on-deck `<NN>-YY-SUMMARY.md` (left there by `define`); if missing, `<state>/phases/_templates/NN-YY-SUMMARY.md`; if that is missing too, `.agents/skills/shippEdd/bootstrap/templates/NN-YY-SUMMARY.md`. If all three are absent, stop and recommend rerunning `/skill:bootstrap` (it repairs the skeleton without touching existing content).

The dispatcher pipes an inline assignment to a detached `pi --print` run — it writes no prompt files; the run's only artifacts are its marker, its commit-spec TSV, and one log while in flight. Executors are resumable: a redispatched plan re-verifies work already on disk instead of redoing it.

Report each dispatch.sh output line to the user verbatim, e.g.:

```
dispatched 01-02 (PID 1234) → .planning/runs/01-02.log
```

Then tell the user they can walk away: re-run `/skill:implement` at any time to gate the runs and dispatch the next wave, or watch progress with `bash <this skill's folder>/scripts/dispatch.sh --status` / `tail <state>/runs/NN-YY.log`. Stop there — never wait, never poll, never chain the next wave in this visit.

## Step 4 — GATE (on re-entry)

Check every plan in the current wave (step 2):

- **Every plan of the wave `.done`** — the wave landed. Run `scripts/replay-commits.sh` and report its output lines verbatim (they read `committed 01-01: a1b2c3d feat(01-01): …`). The sequencer validates every TSV line first, then commits each plan's recorded task specs sequentially in plan order (routing `02-worktrees/<name>/` specs into that worktree's own git), then appends `committed <short-sha>` to each plan's `.done` marker — so re-runs never double-commit, and a plan that recorded no TSV is stamped `committed none`. If replay refuses (a spec lists a path that doesn't exist), its message names the plan and path: fix or remove that TSV line, rerun replay, and continue. Then prune: `rm -f` each committed plan's `NN-YY.log` — a finished plan keeps only its `.done` marker and its `.commits.tsv`. Then loop back to step 2 — the next wave becomes current — and dispatch it (step 3).
- **Any plan still `.running` with a live PID** — the wave is still in flight. Report which plans are running and how to watch them (`--status`, `tail`), then stop: re-run `/skill:implement` to check again. Nothing waits here.
- **Any `.failed`** — one question, grilling format (rule 5):

  ```
  ❓ Plan NN-YY failed: <one-line reason from the marker>. What now?
    ➡️ 1. inspect — show tail of <state>/runs/NN-YY.log and decide from there
      2. redispatch — run it again from scratch: dispatch.sh NN-YY <its plan> <its template> --force (on-disk work from the failed attempt stays for it to verify and build on)
      3. skip the plan — continue without it: append `skipped <reason>` to its marker, and record the gap in CONTEXT.md under a `## Skipped plans` heading (plan id, reason, what's missing) so /skill:review catches it
  ```

  A failure never blocks its siblings — the rest of the wave keeps running while the user decides.
- **A stale `.running` (dead PID)** — offer cleanup per step 1, then redispatch that plan (step 3).

Visits repeat — gate, replay, prune, dispatch — until every wave's plans are `.done` and committed; then step 5.

## Step 5 — COMPLETE

Every plan is `.done` and carries a `committed` line. Update `<state>/STATE.md`:

- frontmatter: `next_action: /skill:review`, `progress: executed`
- body: the phase name and a one-line status ("executed — N plans across M waves, commits replayed in plan order; awaiting review")

Then hand off:

> Phase `<NN>-<slug>` executed — <N> plans across <M> waves, commits in git history in plan order. Next: `/skill:review` to verify coverage and ship.

And stop (rule 6).
