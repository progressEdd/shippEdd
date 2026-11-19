# Roadmap: shippEdd

## Overview

<One paragraph describing the journey from start to finish.>

## Next up

**none — roadmap complete**

## Phases

- [x] **Phase 01: multi-harness-persona-wiring** — bootstrap works on eight harnesses, not just pi
- [x] **Phase 02: execution-record-rework** — implement records live in SUMMARY frontmatter, not the runs dir; executors own git in per-plan worktrees
- [x] **Phase 03: skill-polish-sweep** — the three banked todos land: clear-context guidance at phase-boundary handoffs, repo-relative dispatch receipts, and the PENDING-TODO template sourced solely from the skill
- [x] **Phase 04: unattended-implement-loop** — the two banked todos land: merge-back never halts on the branch delete (todo 06), and opt-in auto mode runs whole phases unattended (todo 07)
- [x] **Phase 05: dispatcher-consolidation** — todos 08 + 09 land plus the grilled expansion: suite-root shared scripts, config-driven worktree-aware run placement, PR-by-default disposition, oracle readout — no more `.planning/runs/`
- [x] **Phase 06: github-mirror** — decisions captured as GitHub issues/sub-issues via `gh` (opt-in); plans ship as PRs that close their issues; builds on 05's config + `gh` groundwork
- [x] **Phase 07: suite-refinements** — deliver the 4 promoted todos: planning archive pruning (10), shared run watcher (11), disposition-gated ship PR offer (12), mirror-ship live shape + jq-free helper (13)

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

### Phase 03: skill-polish-sweep

- **Goal:** the three pending todos (03 clear-context-after-phase, 04 relative-dispatch-paths, 05 todo-template-cleanup) land: skills tell the user to clear context at phase boundaries, dispatch receipts print repo-relative paths, and the PENDING-TODO template lives only in the skill's `bootstrap/templates/todos/`
- **Depends on:** Phase 02 (its skill conventions and vendored-refresh flow)
- **Requirements:** POL-01, POL-02, POL-03, POL-04, POL-05 (minted in REQUIREMENTS.md v3)
- **Success criteria** (what must be TRUE) — seeded from the todos, refined by grilling:
  1. Every phase-boundary handoff (review's ship step, define's step 8, implement's complete step) names the next command **and** says to run it in a fresh/cleared session; the README explains why that's safe
  2. `dispatch.sh --status` and every dispatch receipt line print repo-relative paths (`.planning/runs/<id>.log`), not machine-absolute ones, across all skills' dispatchers that share the pattern
  3. `.planning/todos/` holds no `PENDING-TODO.md`; todo mode-A sources the template solely from `.agents/skills/shippEdd/bootstrap/templates/todos/` with the bootstrap-repair guard; bootstrap's skeleton step no longer writes the state copy; README/docs mentions swept
  4. Phase scaffolding is lazy: define creates only the phase folder + `NN-CONTEXT.md`; every other phase artifact (RESEARCH, PLAN, SUMMARY, VERIFICATION) is written on demand from the skill's `bootstrap/templates/` by the agent that produces it, with no placeholder copies or template-deletion logic

Plans:
- [x] 03-01: clear-context clause at all six in-session handoffs + README why-safe note (POL-01)
- [x] 03-02: repo-relative paths in dispatch receipts and --status across all four dispatchers (POL-02)
- [x] 03-03: PENDING-TODO template sourced solely from the skill — canonical half (POL-03)
- [x] 03-04: state-dir sweep + vendored refresh with byte-parity verification (POL-03 state half, POL-04 — refresh carries POL-01..05; runs wave 5, after 03-05)
- [x] 03-05: lazy phase scaffolding — define scaffolds folder + CONTEXT.md only; artifacts written on demand from skill templates (POL-05; runs wave 4)

### Phase 04: unattended-implement-loop

- **Goal:** `/skill:implement` runs a whole phase unattended **by default** — sequential plan execution in one temp worktree per target branch, bounded model-driven failure recovery (plans and merge-back halts alike), one merge at the end — plus the merge-back branch-delete fix (todo 06)
- **Depends on:** Phase 02 (worktree/merge-back architecture), Phase 03 (skill conventions, vendored-refresh flow)
- **Requirements:** AUTO-01…AUTO-08 (minted in REQUIREMENTS.md v4)
- **Success criteria** (what must be TRUE) — settled by grilling (13 decisions, several reopening todo 07):
  1. `merge-back.sh` deletes agent branches via `git -C <target checkout> branch -d` (safe `-d`, never `-D`) — a clean merge-back never halts; proven by a temp-repo merge-back simulation mirroring this repo's worktree layout
  2. `/skill:implement` defaults to auto: one visit runs the phase's plans sequentially (one temp worktree per target, plan order), recovering failures via bounded model-driven re-dispatch — 2 retries / 3 attempts, mechanically enforced, merge-back halts recovered the same way — stopping only at completion or budget exhaustion, then handing over the full failure dossier
  3. `/skill:implement manual` preserves today's stop-between-plans cadence; the skill README documents both modes, the recovery bounds, and the stop semantics
  4. Sequential topology lands as the documented revision of EXEC-06/07 (REQUIREMENTS v4); plan state stays artifact-derived; nothing new writes per-run state into the repo
  5. Proof: temp-repo simulation incl. a deliberate failure case, then phase 04's own remaining waves run in the new auto mode as the inaugural live run; phase ends with the vendored refresh (squash-merge + byte-parity)

Plans:
- [x] 04-01: todo-06 fix — merge-back branch delete via `git -C "$wt"` + temp-repo differential proof (AUTO-01)
- [x] 04-02: loop mechanics — sequential per-target dispatch-plan.sh (attempt budget, --fix-instructions), new watch-wave.sh, dispatch.sh test hook (AUTO-02/03/05/06)
- [x] 04-03: per-target merge-back rework (bounded merge budget, idempotent) + auto-selftest.sh — 7-case simulation incl. deliberate failure (AUTO-01/04/05/07)
- [x] 04-04: SKILL.md rewrite — auto default, `/skill:implement manual` opt-out, recovery protocol + dossier; README and template sweep (AUTO-02/03/04/05/06/08)
- [x] 04-05: EXEC-06/07 revised-by annotations + vendored refresh with byte-parity — ran on the transitional per-plan machinery; the inaugural auto-mode live run landed as 04-FX1 (AUTO-05/07/08)
- [x] 04-FX1: gap fix from verification run 04-verify — 04-05-SUMMARY corrected, REQUIREMENTS AUTO-07 amended, and this plan itself run end-to-end through the refreshed auto loop as the inaugural auto-mode live run (AUTO-07 layer 2)

### Phase 05: dispatcher-consolidation

- **Goal:** one shared dispatcher at the suite-root `scripts/` dir drives every skill; run placement (work context + markers) is config-driven and worktree-aware (bootstrap setup explains the benefits, detects via `git worktree list`, can create a worktree at a user-chosen path; absent config = documented defaults; paths default repo-relative, opt-in absolute); disposition is PR-by-default with receipt fallback; readout is products-first; todo 08's example-leak fix rides the vendored refresh
- **Depends on:** Phase 02 (shared dispatcher architecture), Phase 04 (auto-mode machinery, oracle precedent, selftest harness)
- **Requirements:** DISP-01…DISP-08 (minted in REQUIREMENTS.md v5)
- **Success criteria** (what must be TRUE) — settled by grilling (11 decisions):
  1. `.agents/skills/shippEdd/scripts/` holds the one dispatcher + one `state-dir.sh`; define/review/wayfind (and bootstrap/todo/wayfind's state-dir.sh copies) reference the new path; no duplicate dispatchers remain
  2. Dispatching from any skill writes markers/logs/prompts per the config location — never under `.planning/`; review's ship step no longer needs `rm -rf runs/`
  3. Bootstrap setup asks the placement question (worktree benefits explained, `git worktree list --porcelain` prefill), can create a worktree at a user-chosen abs/rel path, writes `config.json`; absent keys = documented defaults; documented paths stay repo-relative unless config switches to absolute
  4. Executors' work contexts follow the config: existing-worktree repos place run worktrees under the detected folder; worktree-less repos fall back to a new branch in the main checkout (switching the repo, invasiveness accepted); researcher/verifier stay in the main checkout
  5. Disposition: PR-by-default at merge-back (`gh pr create`), config opt-in restores auto-merge; no remote/no `gh` ⇒ receipt fallback, the run never fails
  6. Re-entry reads products first (RESEARCH.md / VERIFICATION.md verdict), REQUIREMENTS.md as tiebreak, markers advisory only — proven by extended `auto-selftest.sh` incl. one deliberate-failure case
  7. Todo 08's SKILL.md example leak fixed on canonical master, riding the phase-end vendored refresh (squash-merge + byte-parity)

Plans:
- [x] 05-01: suite-root `scripts/` home — runs-dir.sh placement resolver (frozen config contract), dispatch.sh + auto-selftest.sh moved, 8 per-skill copies deleted, implement machinery retargeted (DISP-01, DISP-04 layout)
- [x] 05-02: dispatch-plan branch mode + merge-back PR-by-default with receipt fallback; implement SKILL.md/README wording incl. todo 08 neutral example (DISP-04, DISP-05, DISP-07)
- [x] 05-03: define/review/wayfind/todo onto the shared dispatcher — run-dir prompt homes, products-first re-entry, review drops `rm -rf runs/` (DISP-02)
- [x] 05-04: bootstrap step 4b placement question — worktree benefits, porcelain prefill, worktree creation, disposition question (DISP-03)
- [x] 05-05: auto-selftest extended to 12 cases — migration, placement, branch fallback, PR receipt, fake-gh PR, deliberate failure (DISP-06)
- [x] 05-06: vendored refresh on progressEdd — squash-merge, straggler sweep, byte-parity, required selftest run (DISP-08)
- [x] 05-FX1: gap fix from verification run 05-verify — bootstrap/README.md lines 21/37 reworded to the shared scripts path (DISP-01)
- [x] 05-FX2: vendored refresh of the FX1 fix — squash-merge, byte-parity, selftest sanity (DISP-08)

### Phase 06: github-mirror

- **Goal:** opt-in GitHub mirror — define captures decisions as issues/sub-issues via `gh` (thin prose + helper, mirror-not-source-of-truth), implement/review link PRs that close them; exact sub-issue CLI support researched at 06's define time
- **Depends on:** Phase 05 (config groundwork, PR-by-default flow)
- **Requirements:** from grilling (at 06's define)
- **Success criteria:** from grilling (at 06's define)

Plans:
- [x] 06-01: `gh-mirror.sh` suite-root helper — config law, account chain + `-R` always, gh ≥ 2.94 gate, capture/backfill/progress/pr-body/close-plan/ship subcommands, never-block receipts (MIR-02)
- [x] 06-02: define approval capture sweep (the re-sync) + bootstrap GitHub setup question + Configuration reference in bootstrap/README.md (MIR-01, MIR-03, MIR-04, MIR-08)
- [x] 06-03: implement path — executor per-task progress contract, merge-back closing keywords + push-with-compare fallback + guarded explicit close (MIR-05, MIR-06)
- [x] 06-04: review ship sweep — verdict comment, guarded closes, milestone close; FX plans mint as sub-issues via `fixes:` (MIR-07, MIR-04, MIR-08)
- [x] 06-05: proof — fake-gh selftest cases 13–17 + inaugural live run: phase-06 self-mirror (open tree) + phases 01–05 backfill (27 plans, created closed with merge-commit SHAs) (MIR-09)
- [x] 06-06: vendored refresh on progressEdd — squash-merge + byte-parity + straggler sweep + required selftest (MIR-10)

### Phase 07: suite-refinements

- **Goal:** deliver the 4 promoted todos: planning archive pruning (10), shared run watcher (11), disposition-gated ship PR offer (12), mirror-ship live shape + jq-free helper (13)
- **Depends on:** nothing
- **Requirements:** none recorded — promoted from todos
- **Success criteria** (what must be TRUE):
  1. `.planning`'s growing history files (REQUIREMENTS.md, ROADMAP.md, STATE.md) get a prune/archive pass after every N shipped phases, offered as a suggested action in review's ship step — never automatic (todo 10)
  2. Every skill's background runs can block on a shared watcher generalized from implement's watch-wave.sh into the suite-root scripts/ — same exit-code contract, oracle-driven per run type — with the script-home split on the record (todo 11)
  3. Review's ship step offers a PR only per policy — gated on the configured disposition and/or actual code changes, honoring the repo's push-first convention (todo 12)
  4. `cmd_ship` reads live gh's `subIssues` object shape so sub-issues actually close at ship, fake-gh fixtures match live shapes, and the helper depends on bash + gh only — gh's own `--jq` for gh output, flat-key bash config reader that fails loud (todo 13)

Plans:
- [x] 07-01: gh-mirror.sh jq-free — flat-key fail-loud config reader, TSV issue cache via gh's embedded --jq, live subIssues.nodes shape; fake-gh bash --jq + selftest case 18 (todo 13, D4+D9)
- [x] 07-02: review ship step — disposition+change-scope-gated PR offer (todo 12) + cadence-gated RELEASES.md archive offer with era-aware SHA chain (todo 10) + runs-dir.sh archive-cadence query (D1, D5, D6, D8)
- [x] 07-03: shared scripts/watch-run.sh engine (plan|research|verify) + thin watch-wave.sh wrapper + define/review watcher prose + selftest case 19 (todo 11, D7)
- [x] 07-04: vendored refresh on progressEdd — squash-merge + byte-parity + straggler sweep + required 19-case selftest on bare PATH

## Progress

| Phase | Plans complete | Status | Completed |
|-------|----------------|--------|-----------|
| 01 `multi-harness-persona-wiring` | 2/2 | Shipped | 2026-11-17 |
| 02 `execution-record-rework` | 6/6 | Shipped | 2026-11-17 |
| 03 `skill-polish-sweep` | 5/5 | Shipped | 2026-11-17 |
| 04 `unattended-implement-loop` | 6/6 | Shipped | 2026-11-17 |
| 05 `dispatcher-consolidation` | 8/8 | Shipped | 2026-11-18 |
| 06 `github-mirror` | 6/6 | Shipped | 2026-11-18 |
| 07 `suite-refinements` | 4/4 | Shipped | 2026-11-19 |

<!--
Conventions:
- Integer phases (1, 2, 3) are planned work; decimal phases (2.1) are urgent insertions.
- Phase numbering never restarts; completed milestones collapse into <details> blocks.
- Only /skill:review (ship) ticks boxes or edits history here.
-->
