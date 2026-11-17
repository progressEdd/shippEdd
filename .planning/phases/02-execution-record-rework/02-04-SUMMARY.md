---
status: complete
provides:
  - define/todo retargeted to the skill's own bootstrap/templates/ — no state-dir stash hop, no `_templates/` fallback chain
  - define's planner contract extended with `target` frontmatter (fork-from/merge-back branch) alongside wave + depends_on
  - review's plan gate and verifier evidence rebuilt on SUMMARY `status: complete` (+ CONTEXT.md `## Skipped plans`) instead of `.done`+`committed` run markers
  - review's ship step de-archived: clears transient `runs/` before the state-dir commit, no archive move, receipt keyed to git log; fix plans gain `target:`
  - wayfind's routing retargeted to SUMMARY-based state with worktree/merge-back wording
key-files:
  created: []
  modified:
    - 02-worktrees/master/define/SKILL.md
    - 02-worktrees/master/todo/SKILL.md
    - 02-worktrees/master/review/SKILL.md
    - 02-worktrees/master/review/README.md
    - 02-worktrees/master/wayfind/MAP.md
    - 02-worktrees/master/wayfind/SKILL.md
key-decisions:
  "Phase-numbering law is flat-forever: shipped phases stay in phases/ and reserve their numbers, no _archive scan"
  "Review's plan gate reads the SUMMARY artifact (status: complete or a recorded skip) — implement's completion signature is the artifact, not a marker"
  "Verifier commit evidence = SUMMARY task-commit hashes cross-checked with git log --grep and merge(<NN>-YY>): merge commits on each plan's target branch"
  "rm -rf <state>/runs precedes review's state-dir commit so transient dispatch state can never be committed (dispatchers recreate it on demand)"
  "wayfind's marker readout now describes only define/review runs (research/verify); execution's record is the SUMMARY"
actuals:
  duration: 10min
  tasks: 3
  completed: 2026-11-17
---

# Plan 02-04 Summary: define/review/todo/wayfind retargeted — no _templates/_archive/runs conventions, SUMMARY gates, target frontmatter

EXEC-10's sweep over the remaining canonical skills landed: define and todo source phase templates from the skill's own `bootstrap/templates/` (single path, no stash), review gates plans on completed SUMMARYs and derives commit evidence from SUMMARY hashes + merge commits, review's ship step no longer archives (it clears transient `runs/` before committing), todo numbers phases flat-forever, wayfind routes on SUMMARY presence — and fix plans/plans gain the `target:` key.

## Accomplishments

- define/SKILL.md: intro and SCAFFOLD template-source paragraphs retargeted to `.agents/skills/shippEdd/bootstrap/templates/` as the single repo-relative source (missing → stop, recommend `/skill:bootstrap`); planner contract's "what comes back" bullet now computes `wave` + `depends_on` + `target` across plans (`target` = the branch the plan's executor forks from and merges back into; `master` unless the phase says otherwise).
- todo/SKILL.md: intro and ground rule 4 retargeted to the skill's `bootstrap/templates/`; mode B numbering simplifies to "one more than the highest `NN-*` across `phases/`" with shipped-flat numbering law; scaffold step copies straight from the skill's templates with no `_templates/` hop.
- review/SKILL.md: frontmatter/intro/ground rules drop archive and replay wording ("merges back like any wave"); target-phase shipped-ness derives from state (ROADMAP checkbox / STATE.md `progress: shipped`), never a directory location; "Marker-gate every plan" became "Gate every plan on its artifact" (SUMMARY `status: complete` or CONTEXT.md skip record) with a stop message naming worktree dispatch and merge-back; the verify prompt's Commits input names SUMMARY task-commit hashes cross-checked via `git log --grep "<NN>-YY>:"` and `merge(<NN>-YY>):` merges; fix-plan template is the skill's templates folder and its frontmatter gains `target: <the affected plan's target branch>`; SHIP step 1 clears `<state>/runs` before the tracked-check commit, the Archive step is deleted (steps renumbered 1–6), the ship-mutations commit message is `chore(<NN>-<slug>): ship — tick roadmap`, and the receipt drops the archive row (`commits   <k> (the phase's merge and docs commits)`).
- review/README.md: prerequisites gate on completed SUMMARYs; ship description, gated-sequence, "working if", and wayfind pointer match the de-archived, SUMMARY-based flow.
- wayfind/MAP.md + SKILL.md: implement line names per-plan agent worktrees and merge-back, gated on SUMMARY presence; review line has no archive clause; session hygiene splits marker-based runs (research/verification) from execution's SUMMARY record; live-phases item drops the `_`-prefix exclusion; the diagnosis ladder's implement rung uses the SUMMARY-or-skip rule and the runs-line translation no longer describes implement's dead `committed`-marker model.
- Review's and define's own runs-dir dispatch flows (local `dispatch.sh` copies, run-id allocation, marker reads for research/verify runs) are byte-untouched, per Decision 1/10 — they migrate in a later phase.

## Task commits

1. **Task 1: Retarget define's template source + planner contract; simplify todo's scaffold chain and numbering** — `pending` (refactor)
2. **Task 2: Retarget review — SUMMARY-based plan gate and evidence, ship step loses the archive, fix plans gain target** — `pending` (refactor)
3. **Task 3: Retarget wayfind's routing to SUMMARY-based state and merge-back wording** — `pending` (refactor)

## Files created/modified

- `02-worktrees/master/define/SKILL.md` — template source is the skill's own `bootstrap/templates/`; planner contract adds `target`
- `02-worktrees/master/todo/SKILL.md` — skill-templates scaffold chain, flat-forever phase numbering, shipped-phase wording
- `02-worktrees/master/review/SKILL.md` — artifact-based plan gate, SUMMARY/merge-commit evidence, de-archived ship sequence with `runs/` clearing, fix-plan `target:`
- `02-worktrees/master/review/README.md` — prerequisites, ship narrative, and success checks match the SUMMARY-based flow
- `02-worktrees/master/wayfind/MAP.md` — implement/review flow lines and session hygiene retargeted to worktrees/merge-back/SUMMARYs
- `02-worktrees/master/wayfind/SKILL.md` — live-phases item, runs-line translation, render example, and diagnosis ladder retargeted to SUMMARY-based state

## Decisions & deviations

Plan followed as written for every named edit; task-commit hashes read `pending` (the sequencer creates them from `.planning/runs/02-04.commits.tsv` after the wave lands). Beyond the named edit lists, the plan's preamble rule ("stray references to removed conventions get same-convention rewording, never leave them") forced these minimal rewordings, all inside the six named files:

- todo/SKILL.md — "same law as archived phases" → "same law as shipped phases"; "a phase that is archived or absent" → "a phase that is shipped or absent"
- review/SKILL.md — intro paragraph's "tick the roadmap, archive the phase, optionally push" clause dropped the archive step (parallel to the named frontmatter edit); ground rule 1 "never replays a commit" → "never merges back" (dead replay machinery)
- wayfind/SKILL.md — runs-line `committed`-line bullets collapsed to `.done` → `<id> done`; render example ids switched to define/review-style run ids (`02-verify`/`02-research`/`01-verify`); the ladder's review rung ("all plans `done+committed`") became "every plan has a completed SUMMARY"; the diagnosis e.g. line reworded to SUMMARY wording — each was a literal `done+committed`/dead-marker hit that Task 3's verify grep bans

Out-of-scope observation: sibling executors (02-01/02-02/02-03/02-05) were concurrently modifying `02-worktrees/master/{bootstrap,implement}/` in the shared tree during this run — expected wave-parallel behavior; this plan touched none of their files.

## Next phase readiness

- All three task verify greps pass; `grep -rn '_templates\|_archive'` across `02-worktrees/master/{define,review,todo,wayfind}` finds nothing; no `done+committed` remains in the six files.
- This plan's edits are confined to the six named files — `git diff --name-only` under the four skill dirs lists exactly those six, and all `scripts/` dirs are byte-untouched (define/review/wayfind `dispatch.sh` copies unchanged, per Decision 1/10).
- Ready for the phase verifier and the schema/inventory plans downstream: define, todo, review, and wayfind now speak the SUMMARY + worktree/merge-back + skill-templates model consistently with the personas (02-03) and implement (02-02).
- Nothing blocking.
