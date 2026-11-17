---
status: complete
duration: 5min
key-files:
  created:
    - .planning/phases/02-execution-record-rework/02-05-SUMMARY.md
    - .planning/phases/01-multi-harness-persona-wiring/01-CONTEXT.md
    - .planning/phases/01-multi-harness-persona-wiring/01-RESEARCH.md
    - .planning/phases/01-multi-harness-persona-wiring/01-01-PLAN.md
    - .planning/phases/01-multi-harness-persona-wiring/01-01-SUMMARY.md
    - .planning/phases/01-multi-harness-persona-wiring/01-02-PLAN.md
    - .planning/phases/01-multi-harness-persona-wiring/01-02-SUMMARY.md
    - .planning/phases/01-multi-harness-persona-wiring/01-YY-SUMMARY.md
    - .planning/phases/01-multi-harness-persona-wiring/VERIFICATION.md
  modified:
    - .gitignore
    - .planning/README.md
    - .planning/phases/02-execution-record-rework/02-YY-SUMMARY.md
requirements-completed:
  - EXEC-10
  - EXEC-02
key-decisions:
  - "Phase-01 restore staged as one commit-spec line listing both old and new paths, so the replay sequencer's git add stages both sides of the rename in one commit"
  - "Legacy runs cleared by explicit filename list — this phase's own live 02-0X.* markers/TSVs untouched until review's retargeted ship step removes the dir (Decision 10)"
deviations:
  - none
---

# Plan 02-05 Summary: Flatten the live .planning/ schema — _templates deleted, phase 01 restored flat, runs legacy cleared, docs dropped

The live `.planning/` state dir now matches the flattened schema: `phases/` holds exactly the two phase folders (01 restored flat), the `_templates/` stash is gone, legacy `runs/` content is cleared, and the docs plus on-deck SUMMARY template describe the new record shape.

## Accomplishments

- `.planning/phases/` lists exactly `01-multi-harness-persona-wiring/` and `02-execution-record-rework/` — `_templates/` deleted (5 files) and `_archive/` gone via the verbatim move of all 8 phase-01 files
- Legacy `runs/` content cleared (phase-01 TSVs/markers, `01-verify.done`, this phase's `02-research.*`); only the live `02-0X.*` transitional markers of this phase's own runs remain, per Decision 10
- `.gitignore` no longer ignores `.planning/runs/` — the workflow-run-state block (comment + rule + blank line) removed
- `.planning/README.md` re-documented: PLAN bullet gains `target`, SUMMARY bullet rewritten to the six EXEC-02 record keys, `runs/` bullet deleted
- On-deck `02-YY-SUMMARY.md` replaced with the EXEC-02 record template (identical to the skill template authored by plan 02-01), so this phase's own executors instantiate the new keys — this record is the first written against it

## Task commits

1. **Task 1: Delete the _templates stash** — `<short-sha>` chore(planning): delete phases/_templates stash — templates live in the skill's bootstrap/templates
2. **Task 1: Restore phase 01 flat from _archive** — `<short-sha>` chore(planning): restore phase 01 flat from _archive — phases stay flat forever
3. **Task 2: Clear legacy runs, drop .gitignore rule, re-document README, rework on-deck template** — `<short-sha>` chore(planning): drop runs from the schema — new SUMMARY record keys, target in PLAN docs, on-deck template reworked

## Files created/modified

- `.planning/phases/01-multi-harness-persona-wiring/` — 8 files restored flat from `_archive/` (moved verbatim, content unchanged)
- `.planning/phases/_templates/` — 5 template files deleted; templates now live only in the skill's `bootstrap/templates/`
- `.planning/runs/` — legacy `01-*` and `02-research.*` files removed (untracked; dir itself survives until review's ship step)
- `.gitignore` — workflow-run-state ignore block removed
- `.planning/README.md` — PLAN/SUMMARY bullets updated to the new frontmatter contract; `runs/` bullet deleted
- `.planning/phases/02-execution-record-rework/02-YY-SUMMARY.md` — replaced with the EXEC-02 record template
- `.planning/runs/02-05.commits.tsv` — 3 replay commit-spec lines, byte-identical to the plan

## Decisions & deviations

None — plan followed as written. Commit-spec lines were appended by extracting them byte-exact from the plan file (verified `diff`-identical). Observations, out of scope: sibling executor 02-03 wrote its own TSV mid-run (expected parallel-wave behavior); with the ignore rule gone, the live transitional markers in `runs/` are now untracked-not-ignored — by design until review's ship step removes the dir.

## Next phase readiness

- EXEC-10's live-state portion is landed; plans 02-02/02-03/02-04 own the remaining skill-side retargeting
- The 3-line `.commits.tsv` is ready for the sequencer's replay (deletions staged via listed old paths; the phase-01 move stages both sides on one line)
- Review's retargeted ship step (02-04) removes `.planning/runs/` once verification consumes this phase's markers — nothing else blocks it
