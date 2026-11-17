---
status: complete
provides:
  - dispatch.sh — the shared state-dir-parameterized background dispatcher (same skeleton as define/review/wayfind's copies, `--state-dir` so implement points it at a $TMPDIR run dir while the default keeps `<state>/runs` for the later define/review migration)
  - dispatch-plan.sh — the per-plan executor dispatch (EXEC-01/04/06/08): forks or re-attaches the plan's agent worktree at the recorded fork base, keeps prompt/log/markers/pid/fork-base entirely under ${TMPDIR:-/tmp}/shippEdd/, composes the executor prompt, hands it to the shared dispatcher
  - reworked bootstrap templates — SUMMARY frontmatter as the EXEC-02 execution record (status / duration / key-files / requirements-completed / key-decisions / deviations), PLAN frontmatter gaining the `target:` key, `runs/` scaffold deleted from the skeleton and README
key-files:
  created:
    - 02-worktrees/master/implement/scripts/dispatch-plan.sh
  modified:
    - 02-worktrees/master/implement/scripts/dispatch.sh
    - 02-worktrees/master/bootstrap/templates/NN-YY-SUMMARY.md
    - 02-worktrees/master/bootstrap/templates/NN-YY-PLAN.md
    - 02-worktrees/master/bootstrap/templates/README.md
    - 02-worktrees/master/bootstrap/templates/runs/.gitkeep (deleted)
key-decisions:
  "Naming convention (research Q4 gap) fixed here: agent branches `agent/<NN-YY>`; run dir and worktree under $TMPDIR per EXEC-01 — a tmp wipe orphans at most the worktree dir, the branch survives in git, `git worktree prune` cleans the registration"
  "Persona pointer resolves skill-relative (`implement/../bootstrap/personas/executor.md`), install-agnostic, replacing the pi-specific `.pi/agents/executor.md` hard-code the interim vendored delta carried"
  "`runs/.gitkeep` recorded in Task 3's commit-spec line so the replay sequencer stages the deletion (file tracked at HEAD)"
  "This summary follows the dispatch prompt's named model (the phase-local 02-YY-SUMMARY.md as it stood, provides/actuals keys); the new-key execution-record template lands in bootstrap for future runs, and every later surface references that file rather than re-specifying the keys"
actuals:
  duration: ~20min
  tasks: 3
  completed: 2026-11-17
---

# Plan 02-01 Summary: shared dispatcher + per-plan worktree dispatch + reworked templates

The dispatch machinery EXEC-01/06 promised now exists on canonical master: one shared `--state-dir`-parameterized dispatcher, a per-plan wrapper that forks an agent worktree with all run state in `$TMPDIR`, and the reworked skill templates (SUMMARY execution record, PLAN `target:` key, runs scaffold dropped) that every other plan in this wave references.

## Accomplishments

- `dispatch.sh` rewritten as the shared core: `--state-dir` parsing in both the `--status` branch and the dispatch path (grep count 6 ≥ 4), default `default_dir="$root/$("$here/state-dir.sh")/runs"` preserved for the later define/review migration, header documenting abort semantics and the "missing state dir = state unknown, derive from artifacts" law; no slicing/TSV/plan-composition references remain
- `dispatch-plan.sh` created (executable, `bash -n` clean): validates plan/target/persona/template, refuses existing markers without `--force`, and forks (`git worktree add -b` + fork-base SHA recorded atomically at fork), re-attaches (branch survived, tmp wiped → fork base re-derived from merge-base), or reuses (worktree + prior commits preserved) the plan's agent worktree — re-dispatch continues prior work, never redoes it
- The composed executor prompt carries the full contract: persona pointer → plan walk (never skip/reorder/merge) → "Idempotent by law" → git contract (atomic per-task commits carrying the plan id, never outside the worktree, never STATE.md/ROADMAP.md) → SUMMARY contract (exact frontmatter keys, write-don't-commit) → completion contract (`mv` marker to `.done`/`.failed`, sentinel-terminated final message)
- Templates reworked: `NN-YY-SUMMARY.md` frontmatter is exactly `status / duration / key-files{created,modified} / requirements-completed / key-decisions / deviations` (no `provides:`/`actuals:`, no TSV language — task-commit hashes are the executor's own worktree commits); `NN-YY-PLAN.md` gains `target:` and its comment now names "One executor per plan" with the slicer wording dropped; `README.md` documents the new keys and the `runs/` bullet is gone along with the `runs/` scaffold itself
- Repo-visible per-run state is now zero for implement execution: prompt, log, markers, pid, and fork-base all live under `${TMPDIR:-/tmp}/shippEdd/<NN>-<slug>/<NN-YY>/`

## Task commits

1. **Task 1: Rewrite implement's dispatch.sh as the shared, state-dir-parameterized dispatcher** — `<hash>` (refactor) — `refactor(02-01): rewrite implement dispatch.sh as shared state-dir-parameterized dispatcher` → `02-worktrees/master/implement/scripts/dispatch.sh`
2. **Task 2: Add dispatch-plan.sh — per-plan agent-worktree fork, $TMPDIR run state, composed executor prompt** — `<hash>` (feat) — `feat(02-01): add dispatch-plan.sh per-plan agent-worktree fork with $TMPDIR run state and composed executor prompt` → `02-worktrees/master/implement/scripts/dispatch-plan.sh`
3. **Task 3: Rework bootstrap templates — SUMMARY execution record, PLAN target key, drop runs from the skeleton** — `<hash>` (feat) — `feat(02-01): rework templates into SUMMARY execution record and PLAN target key, drop runs scaffold` → `02-worktrees/master/bootstrap/templates/NN-YY-SUMMARY.md,02-worktrees/master/bootstrap/templates/NN-YY-PLAN.md,02-worktrees/master/bootstrap/templates/README.md,02-worktrees/master/bootstrap/templates/runs/.gitkeep`

## Files created/modified

- `02-worktrees/master/implement/scripts/dispatch.sh` — rewritten (T1): shared dispatcher, `--state-dir`-parameterized, `bash -n` clean, `--status` on an empty state dir exits 0 silently
- `02-worktrees/master/implement/scripts/dispatch-plan.sh` — created (T2): per-plan worktree fork/re-attach/reuse + composed executor prompt; executable
- `02-worktrees/master/bootstrap/templates/NN-YY-SUMMARY.md` — rewritten (T3): EXEC-02 execution-record template
- `02-worktrees/master/bootstrap/templates/NN-YY-PLAN.md` — edited (T3): `target:` frontmatter key + reworked trailing comment
- `02-worktrees/master/bootstrap/templates/README.md` — edited (T3): PLAN/SUMMARY bullets updated, `runs/` bullet deleted
- `02-worktrees/master/bootstrap/templates/runs/.gitkeep` — deleted (T3), `runs/` directory removed
- `.planning/runs/02-01.commits.tsv` — the three commit-spec lines above (tab-separated, `02-worktrees/master/`-prefixed paths per phase-01 convention)
- `.planning/phases/02-execution-record-rework/02-01-SUMMARY.md` — this summary (final task)

## Decisions & deviations

- No deviations — plan followed as written; all three task verifies and every acceptance criterion ran clean (bash -n, grep counts, refusal message, template key greps, silent `--status`, no out-of-scope plan writes)
- Naming decisions fixed per the plan's action text (research Q4 gap): `agent/<NN-YY>` branches, `${TMPDIR:-/tmp}/shippEdd/<NN>-<slug>/<NN-YY>/` run dirs; persona resolved skill-relative, not `.pi/agents`
- This summary itself uses the `provides`/`actuals` key set because the dispatch prompt names the phase-local `02-YY-SUMMARY.md` (as it stood at dispatch time) as the model; the new-key execution-record template this plan lands in `bootstrap/templates/` governs future executor-written summaries
- Observation (out of scope, not mine to fix): sibling executors 02-02…02-05 run in parallel in this shared tree — their writes (`bootstrap/SKILL.md`, `bootstrap/README.md`, `bootstrap/personas/*`, `define|review|todo/SKILL.md`, `slice-tasks.sh`/`replay-commits.sh` removals) were visible during my box-5 check; attribution for the box-5 checklist is by my own write inventory, all inside the two sanctioned dirs

## Next phase readiness

- Plans 02-02…02-06 can reference the landed artifacts: the EXEC-02 key set in `bootstrap/templates/NN-YY-SUMMARY.md`, the `target:` key contract in `NN-YY-PLAN.md`, and the dispatch surface (`dispatch-plan.sh <NN-YY> <plan> <target> [--summary-template] [--model] [--force]`)
- define/review keep their transitional `<state>/runs` default via the shared dispatcher's `default_dir` until their own migration phase (context decision 1)
- Nothing blocking; the three commit-spec lines await the sequencer's replay
