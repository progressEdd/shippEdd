---
status: complete
duration: 5min
key-files:
  created: []
  modified:
    - define/SKILL.md
    - bootstrap/SKILL.md
    - bootstrap/README.md
    - README.md
    - bootstrap/templates/README.md
requirements-completed:
  - MIR-01
  - MIR-03
  - MIR-04
  - MIR-08
key-decisions:
  "Step 7's sweep bullet and bootstrap's mirror question were inserted verbatim in the installed-path prose form (`.agents/skills/shippEdd/scripts/gh-mirror.sh`), matching every existing script reference in the touched files — thin prose holds: skills name the helper, never gh incantations."
  "The v1 `mirror_issues` key is superseded everywhere in bootstrap except one deliberate mention: the Configuration reference's supersession note, per the plan's own text."
deviations:
  - "Path translation only: the plan writes paths (and its helper precondition) as `.agents/skills/shippEdd/<X>`, but this master worktree holds the skill suite at repo root — the installed-path form lives in the prose, not the tree. The 06-01 helper is present and executable at `scripts/gh-mirror.sh` (worktree form of the plan's path), so the precondition's intent holds and no block was taken. All file edits and both verify commands were run with the prefix translated to the worktree root; every inserted/verified string is otherwise verbatim from the plan."
---

# Plan 06-02 Summary: Define capture at approval + bootstrap mirror question + the config reference

The capture path's prose surfaces are wired to 06-01's helper: define now runs the idempotent capture sweep at every approval (never-block), bootstrap asks the mirror question every run with detection-first facts, and the full config reference — every `workflow.*`, `runs.*`, `disposition`, and `github.*` key — is documented in one place with cross-links from the suite README and templates README.

## Accomplishments

- `define/SKILL.md` step 7 gains the mirror capture sweep as its first "On approval" bullet: gated on `github.mirror: true`, invoking `bash .agents/skills/shippEdd/scripts/gh-mirror.sh <state> <NN> <slug> capture`, reporting the receipt verbatim, never blocking approval (missing gh / auth failure / partial sweep are all non-blocking; local markdown is the complete record), refreshing the advisory caches (CONTEXT `issue` column, plan frontmatter `issue:`, parent number), and serving as the drift re-sync at every approval — fresh or post-edit (edit → body rewrite, drop → close with comment, new → create, FX → nest under `fixes:`). Step 1's Resume bullet carries the re-sync sentence.
- `bootstrap/SKILL.md` step 7 is now the GITHUB MIRROR question, asked every run from step 1's facts (`command -v gh`, `gh auth status`, git remote): default local markdown, mirror opt-in; gh-absent picks relay GitHub's quickstart URL; enabling gathers `host`/`account`/`repo` from detection (plus optional `labels`/`token_env` — a name, never a secret) and writes `{"github": {"mirror": true, "host", "account", "repo"}}`. Persistence table, rerun item 3, and the confirmation-gate CONFIG line all name the new `github.*` key set; no `mirror_issues` remains in the file.
- `bootstrap/README.md` gains the `## Configuration reference` section before "It's working if": the absent = documented-default law with its two exceptions (`workflow.ui_phase` written at setup, `github.mirror` absent = off), a defaults table for every config key, the `.pi/planning.json` surface, the v1 `mirror_issues` supersession note, and the end-to-end GitHub account-binding paragraph. "What it does", "Prerequisites", and "Common questions" are synced (new "Can I change the GitHub mirror later?" entry).
- Suite `README.md` cross-links `bootstrap/README.md#configuration-reference` before "Fresh sessions at every handoff"; `bootstrap/templates/README.md`'s config.json bullet now documents the `github.*` keys.

## Task commits

1. **Define step 7 — mirror capture sweep at approval + re-sync note** — `15123ca` feat(06-02): define step 7 — mirror capture sweep at approval (never-block) + resume re-sync note
2. **Bootstrap step 7 mirror question + config reference + README cross-links** — `ef8401b` feat(06-02): bootstrap step 7 mirror question, config reference, README cross-links (MIR-03/04/08)

## Files created/modified

- `define/SKILL.md` — step 7 sweep bullet (first "On approval" item) + step 1 Resume re-sync sentence; no other changes (step 6 planner prompt untouched per plan)
- `bootstrap/SKILL.md` — step 7 replaced in full (mirror question); persistence-rules row, rerun item 3, and confirmation-gate CONFIG line updated to `github.*`
- `bootstrap/README.md` — new `## Configuration reference` section; "What it does" / "Prerequisites" / "Common questions" synced to the new key
- `README.md` — new `## Configuration reference` cross-link section before "Fresh sessions at every handoff"
- `bootstrap/templates/README.md` — config.json bullet extended with the `github.*` keys

## Decisions & deviations

Key decisions: none beyond the plan — all inserted text is verbatim.

Deviations: one, path translation only (see frontmatter). The plan's `.agents/skills/shippEdd/` prefix describes the installed form; this master worktree holds the suite at repo root (the same reality 06-01's executor already committed against — its helper lives at `scripts/gh-mirror.sh`). The precondition `[ -x .agents/skills/shippEdd/scripts/gh-mirror.sh ]` was checked in worktree form and passed; file paths in edits and verify commands were translated accordingly, and the inserted prose deliberately keeps the installed-path form so it resolves in user repos.

## Next phase readiness

Plans 06-03/06-04 (implement executor progress posts; review's `mirror_issues` → `github.mirror` swap + ship sweep) can proceed — the helper (06-01) and both prose surfaces are in place, and review/ was left untouched for 06-04's lane as instructed.
