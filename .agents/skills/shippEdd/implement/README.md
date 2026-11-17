## What it does

`/skill:implement` turns approved plans into background work. It reads the phase's `NN-YY-PLAN.md` files, orders them by the `wave` frontmatter the planner precomputed, and dispatches one detached executor per **plan** — each into its own agent worktree forked from the plan's `target` branch (fork base recorded at dispatch). Executors walk the plan's task sections in order, commit each task atomically inside their worktree, and write `NN-YY-SUMMARY.md` in full before returning. Dispatch state (prompt, log, markers, fork base) is transient under `$TMPDIR` — nothing per-run is written into the repo. When a wave lands, the gate merges every agent branch back into its target, serialized in plan order with fork-base validation (drift halts with a recovery handoff naming what is stranded), removes the worktrees, and makes one docs-side commit (summaries, STATE/ROADMAP sync). Plan state is derived from artifacts: a SUMMARY with `status: complete` means executed; the `merge(NN-YY):` commit on the target means landed. You can close the session between visits — artifacts and git are the entire resume state.

## When to reach for it

- `/skill:define` just approved plans — implement is the command define ends by naming.
- You want work running while you do something else — waves are detached by design; walk away and re-run `/skill:implement` to gate a wave, merge it back, and dispatch the next.
- After a crash, reboot, or abandoned session — re-run it; artifacts and git log say exactly what finished. Missing `$TMPDIR` state is never a failure: the oracle derives from artifacts.
- One plan failed or blocked mid-wave — re-run; the gate offers inspect / redispatch (`--force` reuses the worktree; prior commits are continued, not redone) / skip.

## Prerequisites

- A shippEdd state dir (`/skill:bootstrap`) with a phase that has approved plans (`/skill:define`).
- git identity configured (`user.name` / `user.email`) — executors and the gate commit with it.
- Every plan's `target` branch checked out in some worktree with a clean tree at merge time (the merge runs in that checkout; `merge-back.sh` pre-checks and halts loudly otherwise).

## Common questions

**Why do executors commit now?**
Each executor works in its own worktree — no shared index to race on. Per-task commits make the work atomic and resumable: a re-dispatched plan verifies and continues prior commits (idempotent by law), and the merge-back has a real branch to merge.

**Who merges?**
The orchestrator gate, never the executor. After a wave lands, `merge-back.sh` merges each agent branch into its target with `--no-ff` (one merge bubble per plan), validating the recorded fork base first — if the target or the agent branch moved since dispatch, that merge halts with a handoff naming the plan, branch, worktree, and SHAs. Docs-side commits (summaries, STATE.md, ROADMAP plan ticks) land only after all merges.

**What if two plans of a wave target the same branch?**
Each still runs isolated in its own worktree, but their merges would collide — so the wave is demoted to sequential dispatch with a visible warning, flagged as a planning defect. The planner puts same-target plans in different waves via `depends_on`.

**How do I check on a running wave?**
The dispatch line prints the run dir (`${TMPDIR:-/tmp}/shippEdd/<phase>/<plan>/`): `tail` the log there, or run `dispatch.sh --status --state-dir` against that dir. Finishers write their SUMMARY and flip their own marker — nothing needs babysitting.

**When do the commits appear?**
Continuously inside each executor's worktree; on the target branch at the gate, as serialized `--no-ff` merges in plan order. The planning-repo side (summaries, STATE/ROADMAP) commits once per wave, after the merges.

## It's working if

- Dispatching a plan creates nothing under `.planning/` — the run dir lives under `$TMPDIR` and its path is printed at dispatch.
- Each executed plan leaves exactly one durable artifact: `NN-YY-SUMMARY.md` with `status` / `duration` / `key-files` / `requirements-completed` / `key-decisions` / `deviations` frontmatter.
- `git log <target> --merges` shows one `merge(NN-YY):` bubble per landed plan, in plan order; the agent branches and worktrees are gone.
- Re-running `/skill:implement` at any moment is safe: landed plans are skipped, in-flight ones reported, interrupted ones surfaced with recovery choices.
- Nothing runs git on the target branches except the gate; executors never merge; nothing auto-runs `/skill:review`.

## Where it fits

Role: the execution step of the phase loop — the only skill that dispatches implementation work. Neighbours: `/skill:define` before it, which produces the approved plans (and precomputes the waves and targets); `/skill:review` after it, which verifies coverage against requirements and decisions, then ships. `/skill:todo` takes stray ideas mid-execution so they don't derail a running wave.
