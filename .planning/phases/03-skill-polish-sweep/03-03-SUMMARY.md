---
status: complete
duration: 4min
key-files:
  created: []
  modified:
    - todo/SKILL.md
    - bootstrap/SKILL.md
    - bootstrap/templates/README.md
requirements-completed: []
key-decisions:
  - "Applied the plan's two-paragraph replacement block verbatim, which reorders the paragraphs after bootstrap's skeleton table (Repair semantics now precedes Phase templates) — the plan's Replace-with text is the target state and makes the 'same repair semantics' back-reference read correctly."
deviations:
  - none  # plan's Current quote listed the two paragraphs in the opposite order than the file; replacement text applied exactly as given, content identical either way
---

# Plan 03-03 Summary: PENDING-TODO template sourced solely from the skill — canonical half (POL-03)

POL-03's master-side half landed: todo mode A now copies the note template only from the skill's own `bootstrap/templates/todos/PENDING-TODO.md` (missing → `/skill:bootstrap` guard kept), bootstrap's skeleton no longer scaffolds a state-dir template copy, and the state-dir README template documents the `todos/pending/` capture inbox instead of a doomed file.

## Accomplishments

- `todo/SKILL.md` mode-A step 3 sources the template solely from `.agents/skills/shippEdd/bootstrap/templates/todos/PENDING-TODO.md` — no state-dir fallback — and the missing-template guard now recommends `/skill:bootstrap` as repairing the skill folder's templates. Mode A now matches mode B step 4.3's skill-only sourcing.
- `bootstrap/SKILL.md` step 3: the `todos/PENDING-TODO.md` row is gone from the copy table; the skeleton still creates empty `<state>/todos/pending/` (documented in the Repair-semantics paragraph), and the not-scaffolded paragraph now names the todo note template alongside the phase templates as living in the skill's `templates/` folder.
- `bootstrap/templates/README.md` replaces the `todos/PENDING-TODO.md` line with a `todos/pending/` line (parked stray work → `todos/done/` on promote) and states the capture-note template never lives in the state dir.
- The template itself, `bootstrap/templates/todos/PENDING-TODO.md`, is byte-unchanged (sha256 `05b2921a…`) — it is the sole surviving home.

## Task commits

1. **Retarget todo mode-A template sourcing; drop the state copy from bootstrap's skeleton** — `73f6fed` feat(03-03): todo template sourced solely from the skill — no state-dir scaffold
2. **Sweep the PENDING-TODO row from the state-dir README template** — `2ef0b51` docs(03-03): state-dir README template documents todos/pending/, not a scaffolded template

## Files created/modified

- `todo/SKILL.md` — mode-A step 3 retargeted to the skill's templates; guard reworded accordingly
- `bootstrap/SKILL.md` — skeleton table row deleted; the two paragraphs after it rewritten (inbox creation kept, template named as skill-resident)
- `bootstrap/templates/README.md` — todos line now documents `todos/pending/`, not a scaffolded template

## Decisions & deviations

Decision: the plan's Replace-with block for the two paragraphs after bootstrap's skeleton table orders them Repair-semantics-first; the file had them Phase-templates-first. The replacement text was applied verbatim (the target state), which also turns the "same repair semantics" phrase into a proper back-reference. Both verbatim greps pass either way, so this is recorded as a decision, not a deviation.

Deviations: none.

## Next phase readiness

Canonical half of POL-03 is on `agent/03-03` (branched from master) awaiting the orchestrator's merge-back. The state-dir half — deleting the live `.planning/todos/PENDING-TODO.md` and sweeping `.planning/README.md` — is plan 03-04 task 1 on `progressEdd`, untouched here. No skill text points a reader at a state-dir template copy anymore (`grep -rn 'state>/todos/PENDING-TODO'` over the three touched files is empty).
