---
status: complete
duration: 25min
key-files:
  created: []
  modified:
    - review/SKILL.md
    - review/README.md
    - scripts/runs-dir.sh
    - bootstrap/README.md
requirements-completed:
  - todo 12 — review's ship step offers a PR iff disposition is `pr` AND the ship changed files outside `<state>/` (no REQ-IDs are mapped to phase 07; the plan rides todos 10 + 12)
  - todo 10 — cadence-gated RELEASES.md archive offer in review's ship step, with `archive_cadence` config key (default 5) in runs-dir.sh and bootstrap's README
key-decisions:
  - "Kept the PR question's tooling facts as recommendation-shapers only — disposition + change scope are the gate (decision 6)"
  - "Release-entry SHA sourcing reuses the era-aware merge_sha() chain law at phase granularity: gate bubbles → PR-merge → plan-id commits → bare phase-name mentions (07-RESEARCH Q1)"
  - "archive_cadence lives as a sibling top-level key beside disposition, read by the one config reader (runs-dir.sh); absent/0/garbage = documented default 5 (decisions 1+5+8)"
  - "phases/ folders are never pruned or moved; the archive sweep touches ROADMAP.md, REQUIREMENTS.md, RELEASES.md only"
deviations:
  - "review/SKILL.md archive step: wrote 'phases/ folders are never pruned or moved' without backticks around phases/ — the plan's verify greps the phrase backtick-free while its action prose backticks it; the verify is binding, so the sentence matches the grep (all other verbatim content intact)"
  - "Task 3's dry-run snippets ran with minimal corrections to satisfy their own acceptance criteria: the chain dry-run exercises all four chain links (the plan's snippet tested only links 1–2, which cannot resolve phases 03/04 — they landed as plan-id merges 'merge(03-05):', resolved by link 3 'grep \"(<NN>-\"' to the research-verified SHAs), and the trigger dry-run's second printf used a per-line loop (the plan's literal '%-' sequences are invalid printf format specs). No SKILL/README/script content was affected — dry-run-only"
  - "gh-mirror progress ran as 'bash scripts/gh-mirror.sh …' (worktree-root path) — the assignment's '.agents/skills/shippEdd/scripts/gh-mirror.sh' does not exist in this master worktree (suite lives at the worktree root); mirror is off, silent no-op, nothing failed"
---

# Plan 07-02 Summary: review's ship step — disposition-gated PR offer (todo 12) + cadence-gated RELEASES.md archive offer (todo 10)

Review's SHIP sequence is now seven steps: the PR question fires only on policy (disposition `pr` AND non-planning changes in scope), a new cadence-gated archive offer can prune history into RELEASES.md, and `archive_cadence` is a documented config key read by the one config reader.

## Accomplishments

- Step 5 (now 6) **Push / PR** gates on disposition + change scope, not gh/remote availability: the resolver (`runs-dir.sh disposition`) and the scope command (`git diff … ":(exclude)$state"`) are quoted verbatim; `auto-merge` and docs-only ships get a plain push with a one-line reason; tooling facts only shape the recommendation. The receipt's `PR` line carries the no-PR-why form; `review/README.md` carries all three policy sentences.
- New step 5 **Archive offer (cadence-gated, suggested — never automatic)**: shipped-phase count vs `archive_cadence`, a yes/no question, era-aware SHA resolution per archived phase (first hit wins, `not resolvable from git history` for misses), the RELEASES.md entry shape (R<k> heading, phase table, superseded-REQUIREMENTS details block), ROADMAP cleared to live content, REQUIREMENTS folded, and the archive commit — `phases/` folders never pruned or moved.
- `runs-dir.sh` gained the `archive-cadence` query (absent/0/garbage → 5, numeric config honored), both usage strings name it, and `bootstrap/README.md` documents the `archive_cadence` row (default 5) plus the FAQ sentence.
- Dry-runs verified against real history: the four-link chain resolves all four research-verified SHAs (03→6e61d95, 04→5aac779, 05→73af3f8, 06→560d1d5); the trigger shows 7 shipped → no offer, 10 → offer fires.

## Task commits

1. **Task 1: step 5 Push/PR disposition + change-scope gate; receipt + README sync** — `f1f40db` fix(07-02): review ship step 5 — disposition + change-scope PR gate (todo 12)
2. **Task 2: runs-dir.sh archive-cadence query + bootstrap/README.md config row** — `84b6f9e` feat(07-02): runs-dir.sh archive-cadence query + documented archive_cadence default 5 (todo 10)
3. **Task 3: archive offer as new step 5, renumber 6/7, receipt archive line** — `653777d` feat(07-02): review ship step 5 — cadence-gated archive offer, steps renumbered 6/7 (todo 10)

## Files created/modified

- `review/SKILL.md` — SHIP sequence rewritten: policy-gated PR step (now 6), new archive-offer step 5, receipt gains `archive` line and no-PR-why PR line
- `review/README.md` — three policy sentences swapped to the disposition/scope gate wording
- `scripts/runs-dir.sh` — `archive_cadence_cfg()` + `archive-cadence` case arm with numeric guard; header/usage/defaults comments extended
- `bootstrap/README.md` — `archive_cadence` config row (default 5) + FAQ sentence

## Decisions & deviations

Deviations are listed in the frontmatter; all three are minimal and none touches the shipped prose contracts beyond the one backtick fix the plan's own verify demanded. Otherwise followed plan as written: exact strings, resolver verbatim, chain law verbatim, defaults 5.

## Next phase readiness

Wave 1 (with 07-01) is complete on `agent/07-suite-refinements/master`; 07-03/07-04 can build on these commits — the vendored refresh (07-04) carries the new ship step to `.agents/skills/shippEdd/` per the standing suite law. All three task verifies print their tokens (PR-GATE-OK, CADENCE-OK, ARCHIVE-STEP-OK) and the plan's checklist is demonstrably checked.
