# Roadmap: shippEdd

## Overview

<One paragraph describing the journey from start to finish.>

## Next up

**none — roadmap complete**

## Phases

- [x] **Phase 01: multi-harness-persona-wiring** — bootstrap works on eight harnesses, not just pi
- [x] **Phase 02: execution-record-rework** — implement records live in SUMMARY frontmatter, not the runs dir; executors own git in per-plan worktrees
- [ ] **Phase 03: <slug>** — <one-line description>

## Phase details

### Phase 01: multi-harness-persona-wiring

- **Goal:** bootstrap works on eight harnesses, not just pi: a harness question in step 3b feeds a new `scripts/wire-agents.sh` that wires the four personas into the chosen harness's agent directory (with per-harness conversion where needed)
- **Depends on:** nothing
- **Requirements:** REQ-01, REQ-02, REQ-03, REQ-04, REQ-05
- **Success criteria** (what must be TRUE):
  1. Running bootstrap with any of the eight harnesses selected wires the four personas into that harness's project agent dir in its native format — straight copy (pi, cursor, claude, gemini, github copilot), `mode: subagent` injected (opencode), TOML (codex) — proven by dry-run output plus real runs against throwaway temp dirs
  2. Selecting hermes reports and skips with a note pointing at `~/.hermes/config.yaml` profiles; selecting custom copies personas adapted to any existing examples/docs found, plain md as fallback
  3. Re-running bootstrap on a wired repo skips identical files and never silently overwrites a modified one (diff goes to the confirmation gate); a missing agents dir is created and the receipt says so
  4. The confirmation gate shows `wire   personas → <dir> (4 agents)`

Plans:
- [x] 01-01: wire-agents.sh — the multi-harness wiring matrix (all modes, repair semantics, dry-run; proven via temp-dir runs)
- [x] 01-02: bootstrap SKILL.md harness question + gate/README sync (step 1 probe, step 3b flow, receipts)

### Phase 02: execution-record-rework

- **Goal:** `/skill:implement` execution writes nothing per-run into the repo — plan state is derived from artifacts (SUMMARY frontmatter subsuming marker/TSV/log), executors commit atomically inside per-plan agent worktrees, and merge-back is serialized and orchestrator-owned (EXEC-01…EXEC-09)
- **Depends on:** Phase 01
- **Requirements:** EXEC-01, EXEC-02, EXEC-03, EXEC-04, EXEC-05, EXEC-06, EXEC-07, EXEC-08, EXEC-09, EXEC-10
- **Success criteria** (what must be TRUE):
  1. Running `/skill:implement` on a plan creates nothing under `.planning/runs/` — no markers, TSVs, or prompt files; transient dispatch state lives in `$TMPDIR` with its path printed at dispatch, and `.planning/` holds only named documents
  2. Each executed plan leaves exactly one durable artifact, `NN-YY-SUMMARY.md`, whose frontmatter carries `status`, `duration`, `key-files`, `requirements-completed`, `key-decisions`, `deviations`; plan state is derived from artifacts (SUMMARY present → executed; absent + changed files or plan-id commits → interrupted, with explicit recovery choices), and re-running implement is safe and idempotent
  3. Executors commit each task atomically in their own agent worktree (fork base recorded), never write STATE.md/ROADMAP.md, never merge; same-wave plans dispatch concurrently with a target-overlap check that demotes to sequential with a visible warning; merge-back is serialized in plan order with fork-base validation (drift halts with a recovery handoff) and worktree cleanup
  4. The reworked skill (SKILL.md + dispatch/merge-back scripts; slice/replay scripts removed) lands on the canonical `master` worktree via the phase loop, and the vendored `.agents/skills/shippEdd/` copy refreshes via the squash-merge flow carrying the interim vendored deltas (promptless dispatch, worktree-aware routing)
  5. `.planning/` has no `_`-prefixed dirs: `phases/` holds only phase folders with phase 01 restored flat from `_archive/`, templates live in the skill's `bootstrap/templates/`, implement never writes `runs/` (schema/docs drop it; define/review's dispatch may transiently recreate it until their migration phase — Decision 10), and define/review/bootstrap reference no removed convention

Plans:
- [x] 02-01: shared `--state-dir` dispatcher + `dispatch-plan.sh` (agent-worktree fork, $TMPDIR run state) + reworked templates with `target:`
- [x] 02-02: `merge-back.sh` (serialized --no-ff, fork-base validation) + implement SKILL.md/README rework; slicer and replay deleted
- [x] 02-03: personas reworked (executor owns git in its worktree) + bootstrap skeleton drops runs/_templates rows
- [x] 02-04: retarget define/review/todo/wayfind — SUMMARY-based gates and evidence, no _templates/_archive/runs conventions
- [x] 02-05: flatten live .planning/ — _templates deleted, phase 01 restored flat, legacy runs cleared
- [x] 02-06: vendored refresh — interim deltas committed, reworked master squash-merged, byte-parity verified

## Progress

| Phase | Plans complete | Status | Completed |
|-------|----------------|--------|-----------|
| 01 `multi-harness-persona-wiring` | 2/2 | Shipped | 2026-11-17 |
| 02 `execution-record-rework` | 6/6 | Shipped | 2026-11-17 |

<!--
Conventions:
- Integer phases (1, 2, 3) are planned work; decimal phases (2.1) are urgent insertions.
- Phase numbering never restarts; completed milestones collapse into <details> blocks.
- Only /skill:review (ship) ticks boxes or edits history here.
-->
