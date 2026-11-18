# Requirements: shippEdd

**Defined:** 2026-11-16

## v1 requirements

| ID | Requirement | Phase | Status |
|-------|-------------------------------------------|---------|---------|
| REQ-01 | Bootstrap step 3b asks a harness question every run (fixed order: pi, opencode, hermes, cursor, codex, claude, gemini, github copilot, custom) — no detection-first inference | 01-multi-harness-persona-wiring | Pending |
| REQ-02 | `bootstrap/scripts/wire-agents.sh` wires the four personas per the researched matrix: straight md copy (pi, cursor, claude, gemini, github copilot); copy + inject `mode: subagent` (opencode); md → TOML conversion (codex); report-and-skip with note pointing at `~/.hermes/config.yaml` (hermes) | 01-multi-harness-persona-wiring | Pending |
| REQ-03 | Repair semantics throughout: create the target agents dir if absent (receipt notes creation), skip identical files (compared as converted output), never silently overwrite — diffs surface at the confirmation gate for replace-or-keep | 01-multi-harness-persona-wiring | Pending |
| REQ-04 | Custom option: copy the personas into the user-named directory, adapting to existing agent examples in that dir and/or the harness's documented subagent format where found; plain pi-format md copy as fallback | 01-multi-harness-persona-wiring | Pending |
| REQ-05 | `wire-agents.sh --dry-run` prints the wiring plan (target dir, per-persona action, conversion) without writing | 01-multi-harness-persona-wiring | Pending |

## v2 requirements (phase 02: execution-record rework — GSD-style, no runs dir)

| ID | Requirement | Phase | Status |
|-------|-------------------------------------------|---------|---------|
| EXEC-01 | `/skill:implement` execution writes nothing per-run into the repo: no `.planning/runs/`, no prompt files, no marker files, no commit-spec TSVs — transient dispatch state (composed prompt, run log) lives in `$TMPDIR` with its path printed at dispatch; `.planning/` remains a closed schema of named documents only | 02-execution-record-rework | Pending |
| EXEC-02 | Each executed plan leaves exactly one durable artifact, `NN-YY-SUMMARY.md`, whose frontmatter is the machine-readable execution record — `status: complete\|blocked`, `duration`, `key-files: {created, modified}` (repo-relative), `requirements-completed`, `key-decisions`, `deviations` — subsuming the roles of the old marker, TSV, and log | 02-execution-record-rework | Pending |
| EXEC-03 | Plan state is derived from artifacts, never stored: SUMMARY present → executed; SUMMARY absent but plan-targeted files changed or commits bearing the plan id exist → interrupted run, surfaced with explicit recovery choices (close out manually / re-execute / mark-and-skip); re-running implement at any moment is safe and idempotent | 02-execution-record-rework | Pending |
| EXEC-04 | Executors own git for their plan: each task committed atomically (conventional message carrying the plan id) inside their own agent worktree of the plan's target branch; the SUMMARY is written in full before the executor returns (its planning-repo commit belongs to the gate, EXEC-05) — no replay sequencer, `replay-commits.sh` and `commits.tsv` are deleted | 02-execution-record-rework | Pending |
| EXEC-05 | Executors never write STATE.md or ROADMAP.md; the implement gate owns shared-file sync (phase status, plan ticks, `next_action`) and the docs-side commit on the planning branch after each plan completes | 02-execution-record-rework | Pending |
| EXEC-06 | Per-plan worktree isolation: same-wave plans dispatch concurrently, each executor in its own agent worktree forked from its plan's target-branch HEAD (fork base SHA recorded at dispatch); executors never share a working tree; an intra-wave target-overlap check demotes that wave to sequential with a visible warning (flagged as a planning defect) to avoid merge conflicts — never silently | 02-execution-record-rework | Pending |
| EXEC-07 | Merge-back is orchestrator-owned and serialized after the wave: each agent branch merges into its target branch in plan order, its recorded fork base validated before the merge (drift halts that merge with a recovery handoff naming what is stranded), agent worktrees removed after their merge — executors never merge, and docs-side STATE/ROADMAP commits (EXEC-05) land only after all merges | 02-execution-record-rework | Pending |
| EXEC-08 | Dispatched executors are idempotent: work already on disk (files matching the task contracts, commits bearing the plan id) is verified and continued from, never redone or reverted | 02-execution-record-rework | Pending |
| EXEC-09 | The reworked implement skill (SKILL.md + dispatch and merge-back scripts; slicer and replay scripts removed) lands on the canonical `master` worktree via the phase loop; the vendored `.agents/skills/shippEdd/` copy refreshes via the existing squash-merge flow, carrying the interim vendored deltas (promptless dispatch, worktree-aware routing) with it | 02-execution-record-rework | Pending |
| EXEC-10 | `.planning/` schema flattening: `phases/` contains only `<NN>-<slug>` phase folders (shipped phases stay flat — no `_archive/`), `_templates/` is deleted with template files living in the skill's `bootstrap/templates/` and all scaffold fallback chains retargeted there, implement execution never writes `runs/` and the schema/inventory/docs drop it (define/review's dispatch may transiently recreate it until their migration phase — Decision 10), no `_`-prefixed convention dir is introduced again — define/review/bootstrap SKILL.md updated accordingly | 02-execution-record-rework | Pending |

## v3 requirements (phase 03: skill polish sweep — the three promoted todos + vendored refresh)

| ID | Requirement | Phase | Status |
|-------|-------------------------------------------|---------|---------|
| POL-01 | Every skill handoff that names a next in-session command (review's ship step, define's step 8, implement's complete step, wayfind's exit, todo's promote exit, bootstrap's setup handoff) also tells the user to run it in a fresh/cleared session; the README explains why that is safe (everything durable is on disk; STATE.md `next_action` is the router) | 03-skill-polish-sweep | Pending |
| POL-02 | Dispatch receipts and `--status` output print repo-relative paths (e.g. `.planning/runs/<id>.log`), never machine-absolute ones, across every dispatcher sharing the pattern (review, define, implement, wayfind — and dispatch-plan.sh if it prints paths) | 03-skill-polish-sweep | Pending |
| POL-03 | The PENDING-TODO template lives solely in `.agents/skills/shippEdd/bootstrap/templates/todos/`: the `.planning/todos/PENDING-TODO.md` state copy is deleted, todo mode-A sources the skill path only (keeping the missing → `/skill:bootstrap` guard), bootstrap's skeleton step stops writing it, and README/docs mentions are swept | 03-skill-polish-sweep | Pending |
| POL-04 | The phase ends with a vendored refresh: canonical `02-worktrees/master/` skills squash-merged into `.agents/skills/shippEdd/` with byte-parity verification (the 02-06 flow), so the running copy carries POL-01..03 | 03-skill-polish-sweep | Pending |
| POL-05 | Phase scaffolding is lazy: define's step 2 scaffolds only the phase folder and `NN-CONTEXT.md`; `NN-RESEARCH.md`, `NN-YY-PLAN.md`→`NN-0N-PLAN.md`, `NN-YY-SUMMARY.md`→`NN-0N-SUMMARY.md`, and `VERIFICATION.md` are written on demand by their producing agents (researcher / planner / executors / review) from the skill's `bootstrap/templates/`; no placeholder copies are pre-copied into the phase dir, and the template-deletion and YY-placeholder logic is removed from the skills | 03-skill-polish-sweep | Pending |

## v4 requirements (phase 04: unattended implement loop — todos 06 + 07)

| ID | Requirement | Phase | Status |
|-------|-------------------------------------------|---------|---------|
| AUTO-01 | `merge-back.sh` deletes each agent branch via `git -C <target checkout> branch -d` — safe `-d` kept, never `-D`; worktree remove/prune unchanged; a clean merge-back never halts (todo 06) | 04-unattended-implement-loop | Pending |
| AUTO-02 | `/skill:implement` defaults to auto: one visit dispatches the phase's plans sequentially — one temp worktree per target branch, plans in plan order — watches each run to resolution, gates on the SUMMARY oracle, and proceeds without re-entry; `/skill:implement manual` is the opt-out that stops between plans | 04-unattended-implement-loop | Pending |
| AUTO-03 | Model-driven failure recovery, bounded: a failed run's result returns to the orchestrating session, which diagnoses and re-dispatches the plan with fix instructions; 2 retries / 3 attempts per plan, enforced mechanically by the watch script (not model discretion); an earlier stop is allowed when a retry clearly cannot help (e.g. blocked on a missing decision); on exhaustion the loop stops and presents the full failure dossier | 04-unattended-implement-loop | Pending |
| AUTO-04 | Merge-back halts (fork-base drift, merge conflict) receive the same bounded model-driven recovery within the 2-retry/3-attempt budget; on failure the loop stops and hands the dossier to the human | 04-unattended-implement-loop | Pending |
| AUTO-05 | Sequential topology: one agent branch per target forked from its HEAD at phase start, all of that target's plans executing in its worktree, merge-back per target at phase end or right before the first later plan consuming it — revising EXEC-06 (concurrent same-wave dispatch) and EXEC-07 (per-wave serialized merge-back); EXEC-01…05 and EXEC-08 unchanged; wave/depends_on remain the logical order, executed sequentially | 04-unattended-implement-loop | Pending |
| AUTO-06 | Plan state stays artifact-derived (SUMMARY `status: complete` oracle); the watch script resolves from artifacts with `$TMPDIR` markers advisory only, PID-liveness aware; nothing new writes per-run state into the repo | 04-unattended-implement-loop | Pending |
| AUTO-07 | Proof, two layers: a deterministic temp-repo simulation with scripted executors including a deliberate failure case (bounded recovery exercised, clean stop verified), then phase 04's own remaining waves executed via the new auto mode as the inaugural live run | 04-unattended-implement-loop | Pending |
| AUTO-08 | Docs and refresh: the implement skill README documents auto-default, the manual opt-out, recovery bounds and stop semantics; the phase ends with the vendored refresh — canonical skills squash-merged into `.agents/skills/shippEdd/` with byte-parity verification | 04-unattended-implement-loop | Pending |

## Deferred (v2+)

- Hybrid same-wave parallel dispatch (concurrency only where plan targets differ): deferred by user decision 2026-11-17 — sequential ships first; hybrid returns "at some future point when I want to return"

## Out of scope

| Feature | Reason |
|--------------|--------------------------------------|
| <feature> | <why explicitly excluded> |

<!--
Conventions:
- Statuses: Pending → In progress → Complete | Blocked.
- IDs are <CAT>-<NN> (e.g. AUTH-01) once categories emerge; plain REQ-NN is fine to start.
- Every v1 requirement maps to exactly one phase; unmapped = roadmap gap.
- /skill:review verifies each requirement and flips its status to Complete.
-->
