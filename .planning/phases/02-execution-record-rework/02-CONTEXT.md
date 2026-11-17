# Phase 02 execution-record-rework Context

**Gathered:** 2026-11-17 — via `/skill:define` grilling

## Goal

`/skill:implement` execution writes nothing per-run into the repo — plan state is derived from artifacts (SUMMARY frontmatter subsuming marker/TSV/log), executors commit atomically inside per-plan agent worktrees, and merge-back is serialized and orchestrator-owned.

## Decisions

| # | Question | Decision | Why |
|---|-----------------------------------|-------------------|------------------------|
| 1 | Scope of runs-dir removal: implement only, or all skills? | Implement + extract a shared dispatcher — the new transient-$TMPDIR model lands as one common script; implement calls it now, define/review migrate to it later (out of this phase) | One dispatch model to maintain; keeps this phase's blast radius on implement while not forking a second dispatcher design |
| 2 | Same-wave executor concurrency cap? | No cap — dispatch the whole wave | Planner already sizes waves small (2–3 plans); capping is a second knob doing the same job |
| 3 | Merge-back history shape for agent branch → target? | `git merge --no-ff` — one merge-commit bubble per plan | Consistent plan boundaries for audit, stable commit hashes, drift still halts per EXEC-07 |
| 4 | Gate autonomy on merge-back | Auto-merge clean cases; halt with recovery handoff only on drift, conflict, or failed verify | Unattended by design; halts are the exception path, not a checkpoint |
| 5 | Where does the executor's run narrative live? | SUMMARY-first: `NN-YY-SUMMARY.md` (frontmatter + body) is the durable record; the $TMPDIR log is incidental debug only — nothing of value is dumped into logs, no retention/cleanup machinery | The record belongs in a named document, not transient logs |
| 6 | Dispatch mode for executors | Background-only, as today | Walk-away UX; SUMMARY covers the durable record, $TMPDIR log the debug one |
| 7 | Fate of shipped phase folders once `_archive/` is gone | Keep flat in `phases/` forever — ROADMAP's Progress table is the index | The md files are the record; matches NeuroNarrate reference (phases 01–20 all flat, none archived) |
| 8 | Other `.planning/` subdirs in scope for slimming? | `todos/` and `codebase/` stay — but hard rule going forward: no `_`-prefixed convention dirs anywhere, topic dirs hold md files at one level | Slimming targets the `_archive`/`_templates`/`runs` convention, not the topic dirs |
| 9 | Blast radius: slimming edits define/review/bootstrap too | Accepted — one phase, one coherent `.planning/` schema | Half-measures would leave the schema incoherent |
| 10 | EXEC-10 ruling: does `runs/` vanish outright this phase? (research-flagged collision with Decision 1) | Schema-level — implement never writes `runs/`; schema, inventory, and docs drop it; define/review's dispatch transiently recreates it until their migration phase | Preserves Decision 1's scope; the alternative re-opened a locked decision (02-RESEARCH.md, Risks) |

## Constraints

- Merge strategy must not silently resolve fork-base drift — EXEC-07's halt-with-recovery-handoff semantics hold regardless of strategy chosen
- `.planning/` stays a closed schema of named documents; implement execution writes no per-run files there (EXEC-01)
- `slice-tasks.sh`, `replay-commits.sh`, and `commits.tsv` are deleted (EXEC-04/09)
- `.planning/phases/` contains only `<NN>-<slug>` phase folders — no `_templates/`, no `_archive/`; template files live in the skill's own `bootstrap/templates/` and scaffold fallback chains retarget there (EXEC-10)
- Shipped phases stay flat in `phases/` — no archive step exists (EXEC-10)
- `.planning/` shape norm: root-level md files plus single-level topic dirs, no `_`-prefixed convention dirs (reference: NeuroNarrate `.planning/`)

## Open questions

- (research) Inventory every `_templates` / `_archive` / `runs` reference across the four skills' SKILL.md + scripts and `bootstrap` templates — the retarget map for plans
- (research) Current implement flow mapped step-by-step (marker gate, wave order, replay sequencer, TSV writes) — what exactly the rework replaces or deletes
- (research) Shared-dispatcher interface: what implement needs (transient $TMPDIR run state, liveness without repo markers) vs what define/review will later call — extraction without migrating them this phase
- (research) Command-level recipe for the git mechanics: per-plan worktree fork + fork-base SHA recording, liveness/death detection from $TMPDIR state, serialized `merge --no-ff` in plan order, drift halt, worktree cleanup
