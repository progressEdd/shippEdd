---
status: complete
provides:
  - Reworked executor persona owning git inside its agent worktree (atomic per-task commits, SUMMARY record, idempotency) — EXEC-04/02/08
  - Verifier persona cross-checking commits via SUMMARY task-commit hashes and merge(<NN>-YY>) merge commits instead of run markers
  - Planner persona authoring `target:` frontmatter with the same-target-never-same-wave rule (EXEC-10 knock-on)
  - Bootstrap SKILL.md/README.md with `runs/` and `phases/_templates/` dropped from the scaffolded skeleton (EXEC-10)
key-files:
  created: []
  modified:
    - 02-worktrees/master/bootstrap/personas/executor.md
    - 02-worktrees/master/bootstrap/personas/verifier.md
    - 02-worktrees/master/bootstrap/personas/planner.md
    - 02-worktrees/master/bootstrap/SKILL.md
    - 02-worktrees/master/bootstrap/README.md
key-decisions:
  "Executor SUMMARY is the one sanctioned cross-tree write: written in full before returning, never committed — the gate owns its commit"
  "Verifier's commit cross-check keys on SUMMARY task-commits sections + one merge(<NN>-YY>) merge commit per executed plan; skipped plans judged from CONTEXT.md's ## Skipped plans record"
  "Phase templates are never scaffolded into the state dir — define and /skill:todo copy them straight from the skill's templates/ folder"
actuals:
  duration: 5min
  tasks: 3
  completed: 2026-11-17
---

# Plan 02-03 Summary: Personas reworked (executor owns git) + bootstrap drops the runs/_templates skeleton rows

The canonical personas now describe the new execution model — executor commits atomically in its worktree and writes the SUMMARY record, verifier cross-checks SUMMARYs and merge commits, planner authors `target:` frontmatter — and bootstrap no longer scaffolds `runs/` or `phases/_templates/`.

## Accomplishments

- executor.md rewritten for the worktree execution model: owns git inside its agent worktree (atomic per-task commits carrying the plan id), never merges/rebases/pushes or writes STATE.md/ROADMAP.md, writes the SUMMARY in full before returning (written, never committed — the gate owns its commit), is idempotent by law (verify-and-continue, never redo), and flips only its transient `$TMPDIR` marker. All TSV/commit-spec/sequencer/"Never runs git" language is gone.
- verifier.md's commit cross-check retargeted from run markers' `committed <sha>` lines to the execution record: SUMMARY task-commit hashes exist on the plan's target branch (`git log --grep`), each executed plan landed as exactly one `merge(<NN>-YY>):` merge commit, files in `key-files` appear in those commits (`git show --stat`), and plans under CONTEXT.md's `## Skipped plans` are judged from that record rather than a missing SUMMARY. Rest of the file byte-for-byte unchanged.
- planner.md now authors `target:` frontmatter (description, template-structure sentence, and the same-target-never-same-wave rule: two plans with the same target never share a wave — sequence with `depends_on`).
- bootstrap SKILL.md's skeleton table lost the `runs/.gitkeep` and `phases/_templates/` rows, with a new sentence recording that phase templates are not scaffolded into the state dir; README.md's "It's working if" bullet matches.

## Task commits

1. **Task 1: Rewrite the executor persona** — `pending` (refactor)
2. **Task 2: Retarget the verifier persona's commit cross-check** — `pending` (refactor)
3. **Task 3: Planner target frontmatter + bootstrap skeleton drops** — `pending` (feat)

## Files created/modified

- `02-worktrees/master/bootstrap/personas/executor.md` — full rewrite: worktree git ownership, atomic per-task commits, SUMMARY record, idempotency, two-sentinel output contract
- `02-worktrees/master/bootstrap/personas/verifier.md` — Inputs sentence and coverage-check item 3 retargeted to SUMMARY hashes, merge commits, and skipped-plan records
- `02-worktrees/master/bootstrap/personas/planner.md` — `target` added to description and template structure; new `target:` computation bullet in Waves and dependencies
- `02-worktrees/master/bootstrap/SKILL.md` — skeleton table drops `runs/.gitkeep` and `phases/_templates/` rows; adds the not-scaffolded phase-templates sentence
- `02-worktrees/master/bootstrap/README.md` — "It's working if" bullet lists no `runs/` or `phases/_templates/`; points at the skill's `bootstrap/templates/`

## Decisions & deviations

none — plan followed as written. (Task-commit hashes read `pending`: the sequencer creates them after the wave lands, from `.planning/runs/02-03.commits.tsv`.) Out-of-scope observation: sibling executors (02-01/02-02/04/05) were concurrently modifying `02-worktrees/master/{define,implement,todo}/` in the shared tree during this run — expected wave-parallel behavior, untouched by this plan.

## Next phase readiness

- Canonical personas and bootstrap docs now match the new execution model; EXEC-10's schema-level removal of `runs/` and `phases/_templates/` is consistent across executor/verifier/planner personas and the bootstrap skeleton description.
- Ready for the wave's dependent plans and the phase verifier: all three task verify greps pass, and `commits.tsv`/`_templates`/`runs/` references are demonstrably absent from the personas and bootstrap docs.
- Nothing blocking: the plan's four verification boxes are all checked (task verifies pass; `commits.tsv` absent from personas; `_templates`/`runs/` absent from SKILL.md/README.md; this plan modified nothing outside `02-worktrees/master/bootstrap/`).
