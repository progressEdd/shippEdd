---
status: complete
duration: 12min
key-files:
  created:
    - bootstrap/templates/NN-0N-PLAN.md  # pure rename from NN-YY-PLAN.md (100%, contents byte-identical)
    - bootstrap/templates/NN-0N-SUMMARY.md  # pure rename from NN-YY-SUMMARY.md (100%, contents byte-identical)
  modified:
    - define/SKILL.md
    - bootstrap/personas/planner.md
    - bootstrap/personas/researcher.md
    - implement/SKILL.md
    - implement/scripts/dispatch-plan.sh
    - review/SKILL.md
    - todo/SKILL.md
    - wayfind/SKILL.md
    - bootstrap/SKILL.md
    - bootstrap/templates/README.md
requirements-completed: []
key-decisions:
  - "Honored the plan's two deliberate wordings verbatim: template contents keep their <NN-YY> placeholders (the plan's own id notation — implement/review's NN-YY-SUMMARY.md artifact references untouched), and only the two template filenames changed YY → 0N; review/wayfind keep their no-placeholders raw-template checks but now explain that legacy phases may legitimately carry raw copies."
  - "The CONTEXT.md template-source guard survived verbatim in define step 2; review step 2 gained the new VERIFICATION.md guard; implement step 3's guard was reworded to point solely at the skill's NN-0N-SUMMARY.md."
deviations:
  - "Two replacement strings in the plan contained the exact token its own verify blocks forbid: define/SKILL.md step 6's closing paragraph ended 'nothing scaffolded an on-deck copy' and implement/SKILL.md step 3 ended 'there is no on-deck phase copy', but the task verifies demand `! grep -q 'on-deck'` on both files and the final checklist demands `grep -rn 'on-deck' … --include='SKILL.md'` print nothing. Minimum deviation: dropped the word 'on-deck' from those two clauses ('nothing scaffolded a copy' / 'there is no phase copy'); all other text applied exactly as written. Files: define/SKILL.md, implement/SKILL.md."
---

# Plan 03-05 Summary: Lazy phase scaffolding — artifacts written on demand from the skill's templates (POL-05)

POL-05 landed on master: `define` (and todo's promote) scaffold only the phase folder plus `NN-CONTEXT.md`; RESEARCH, PLAN, SUMMARY, and VERIFICATION artifacts are now created on demand by the researcher / planner / executors / verifier straight from the skill's `bootstrap/templates/` (renamed `NN-0N-PLAN.md` / `NN-0N-SUMMARY.md`), with the template-deletion and YY-placeholder/on-deck logic swept out of all six skills and the missing-template → `/skill:bootstrap` guard present at every source.

## Accomplishments

- `define/SKILL.md` step 2 scaffolds exactly one file (`cp <templates>/NN-CONTEXT.md` — the sole `cp` line left) and names the on-demand producing agents; step 4 no longer deletes a scaffolded RESEARCH.md (nothing scaffolds one — the researcher creates it from `.agents/skills/shippEdd/bootstrap/templates/NN-RESEARCH.md`), and step 6 points the planner at the skill's `NN-0N-PLAN.md` template with no leftover-template cleanup. `NN-YY`, `on-deck`, and `delete the scaffolded` appear nowhere in the file.
- `bootstrap/personas/planner.md` instantiates the skill's `NN-0N-PLAN.md` (input 3 + the "Instantiate the skill's `NN-0N-PLAN.md` template" opener) with no phase-dir template path; `bootstrap/personas/researcher.md` MODE A creates the artifact from the skill's NN-RESEARCH.md template (MODE B's "Fill the template already in place for that probe" untouched — codebase stubs are still scaffolded by bootstrap).
- `implement/SKILL.md` step 1 treats every `NN-*-PLAN.md` as a real plan; step 3 resolves the summary template solely to the sibling `bootstrap/templates/NN-0N-SUMMARY.md` with the `/skill:bootstrap` guard kept; `implement/scripts/dispatch-plan.sh` defaults `summary_tpl` to `NN-0N-SUMMARY.md` (bash -n clean).
- `review/SKILL.md` gains a template-source guard for VERIFICATION.md, its verifier prompt writes the artifact from the skill's template (create-if-absent / replace-prior-round), re-verify detection says the verifier creates the file on demand (raw copies only in legacy phases), and the fix-plan dispatch points at `NN-0N-PLAN.md`.
- `todo/SKILL.md` mode B step 4.3 copies only `NN-CONTEXT.md` under the same lazy rule; `wayfind/SKILL.md`'s checklist intro explains scaffolding is lazy (a present file is filled; only CONTEXT can sit half-raw, legacy phases may carry raw copies); `bootstrap/SKILL.md` documents the lazy regime; `bootstrap/templates/README.md` names the renamed templates with their producing agents.
- The two renames are pure (100%, zero insertions/deletions): `NN-YY-PLAN.md → NN-0N-PLAN.md`, `NN-YY-SUMMARY.md → NN-0N-SUMMARY.md`; contents keep their `<NN-YY>` id placeholders by design.

## Task commits

1. **Lazy scaffold in define — CONTEXT only; research and plans created on demand** — `893b0d8` feat(03-05): lazy phase scaffolding — define seeds CONTEXT only; research and plans created on demand
2. **SUMMARY and VERIFICATION instantiated from the skill's templates on demand** — `6f90bed` feat(03-05): SUMMARY and VERIFICATION instantiated from the skill's templates on demand
3. **Sweep todo/wayfind/bootstrap; rename the plan and summary templates to NN-0N** — `e03d152` feat(03-05): lazy-scaffold sweep in todo/wayfind/bootstrap; plan and summary templates renamed NN-0N

## Files created/modified

- `define/SKILL.md` — step 2 seeds CONTEXT only + names on-demand producers; step 4 drops deletion logic and rewrites the research artifact line; step 6 rewrites the plan-template input, first "what comes back" bullet, and closing paragraph
- `bootstrap/personas/planner.md` — input 3 and the template-filling opener point at the skill's `NN-0N-PLAN.md`
- `bootstrap/personas/researcher.md` — MODE A creates the artifact from the skill's NN-RESEARCH.md template
- `implement/SKILL.md` — step 1 bullet + step 3 summary-template resolution rewritten
- `implement/scripts/dispatch-plan.sh` — default summary template `NN-0N-SUMMARY.md`
- `review/SKILL.md` — step 1 bullet, re-verify detection, new template-source guard, verifier artifact line, fix-plan template pointer
- `todo/SKILL.md` — mode B step 4.3 lazy scaffold (CONTEXT only)
- `wayfind/SKILL.md` — artifact-checklist intro + PLAN/SUMMARY pair bullet
- `bootstrap/SKILL.md` — phase-templates paragraph rewritten for the lazy regime
- `bootstrap/templates/README.md` — the two template-entry lines renamed NN-0N with producing-agent notes
- `bootstrap/templates/NN-0N-PLAN.md` (renamed from `NN-YY-PLAN.md`) / `bootstrap/templates/NN-0N-SUMMARY.md` (renamed from `NN-YY-SUMMARY.md`) — byte-identical contents

## Decisions & deviations

Decisions: the plan's two deliberate wordings were applied without re-derivation — template contents keep their `<NN-YY>` placeholders (only the two filenames changed YY → 0N), and review/wayfind keep their no-placeholder raw-template checks with the new legacy-phase explanation. Guards survive at every template source: define (CONTEXT.md, verbatim), implement (NN-0N-SUMMARY.md), review (VERIFICATION.md, new), todo (`recommend /skill:bootstrap`).

Deviations: one, taken twice for the same cause — the plan's replacement text for define/SKILL.md step 6's closing paragraph ("nothing scaffolded an on-deck copy") and implement/SKILL.md step 3 ("there is no on-deck phase copy") contain the literal token `on-deck`, which those tasks' own verify blocks and the plan's final checklist (`grep -rn 'on-deck' … prints nothing`) forbid in those files. The verify blocks are the binding contract, so the minimum deviation dropped only the word "on-deck" from those two clauses; every other character of the replacements is as written.

## Next phase readiness

Branch `agent/03-05` (3 commits on top of master with 03-01…03-03 merged) awaits the orchestrator's wave-4 merge-back. Every plan verification box is checked: the three task verifies pass verbatim, `on-deck`/`still contains` sweeps are empty across all six skills, `NN-0N-PLAN.md` resolves in define/review/bootstrap/templates-README/planner-persona with the template present, and the three `feat(03-05):` commits carry exactly the plan's 12 files. The vendored `.agents/skills/shippEdd/` copy picks these changes up via 03-04's squash-merge refresh, per plan; the phase-03 state dir's legacy on-deck `03-YY-SUMMARY.md` is left in place deliberately — state-dir files are not master's lane.
