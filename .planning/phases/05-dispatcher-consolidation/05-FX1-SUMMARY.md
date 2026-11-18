---
status: complete
duration: 3min
key-files:
  created: []
  modified:
    - bootstrap/README.md
requirements-completed:
  - DISP-01
key-decisions:
  - "Kept the fix to exactly the two stale state-dir.sh lines per the plan's do-not-touch-anything-else contract — the three scripts/wire-agents.sh references in the same file are correct as-is and were left alone."
deviations:
  - "Task 1's verify block, run verbatim, dies with `grep: invalid option -- ' '` — its second probe (`grep -qF '- Running …' bootstrap/README.md`) passes a dash-leading pattern that GNU grep parses as options, so the check errors before reading the file. Ran that one probe as `grep -qF -e '- Running …'` (identical semantics, pattern protected); every other verify clause byte-identical. Output still ended `GAP-1 CANONICAL FIX VERIFIED`. No file impact."
---

# Plan 05-FX1 Summary: bootstrap/README.md's two state-dir.sh references reworded to the shared scripts path (DISP-01 — verification gap 1, canonical half)

Both stale `scripts/state-dir.sh` references in canonical `bootstrap/README.md` (lines 21 and 37) now point at `.agents/skills/shippEdd/scripts/state-dir.sh`, closing verification gap 1 from run 05-verify and clearing the last SKILL.md/README straggler against DISP-01.

## Accomplishments

- `bootstrap/README.md:21` ("Can I move the state dir later?" answer) now reads "Everything resolves through `.agents/skills/shippEdd/scripts/state-dir.sh`; the toggles in `config.json` travel with the state dir." — only the script path changed, sentence shape byte-identical.
- The first "It's working if" bullet (line 37) now reads "- Running `.agents/skills/shippEdd/scripts/state-dir.sh` prints exactly one line — the state dir (`$PLANNING_DIR` → `.pi/planning.json` → `.planning`)."
- The verifier's own probe flipped: `grep -cF '.agents/skills/shippEdd/scripts/' bootstrap/README.md` prints exactly `2` (was 0); zero other `scripts/state-dir.sh` forms survive, and the file's three `scripts/wire-agents.sh` references are untouched.
- Canonical master now carries the fix for plan 05-FX2 (wave 6) to ride to the vendored copy — the consumer case the suite law ("never edit only the vendored copy") ordered.

## Task commits

1. **Task 1: Reword both stale state-dir.sh references in bootstrap/README.md to the shared path** — `10dd0d9` fix(05-FX1): bootstrap README — both state-dir.sh references point at the shared scripts path (DISP-01, gap 1)

## Files created/modified

- `bootstrap/README.md` — the two stale script-path references (lines 21 and 37) reworded to `.agents/skills/shippEdd/scripts/state-dir.sh`; nothing else in the file changed (diff: 2 insertions, 2 deletions).

## Decisions & deviations

Decision: no scope beyond the plan — the neighboring `scripts/wire-agents.sh` references (correct as-is, that script still lives in the skill's own `scripts/` folder) and every other section were left untouched, per the plan's explicit contract.

Deviation (verify-command defect, not implementation): Task 1's verify block, run verbatim, fails at its second probe — `grep -qF '- Running …' bootstrap/README.md` hands GNU grep a dash-leading pattern, which it parses as options (`grep: invalid option -- ' '`), erroring before reading the file. Minimum unblocking deviation: ran that single probe as `grep -qF -e '- Running …'` — identical semantics, pattern protected from option parsing. All other verify clauses byte-identical; the verify passed and ended `GAP-1 CANONICAL FIX VERIFIED`. No files affected.

## Next phase readiness

- Canonical master (branch `agent/05-dispatcher-consolidation/master`, commit `10dd0d9`) carries the gap-1 fix; worktree porcelain is clean.
- Gate/orchestrator next steps per the plan's note: commit this SUMMARY docs-side, then merge master's agent branch. Because `.planning/config.json` carries no `disposition` key (PR-by-default), a real PR may open leaving master's ref without the fix — that must land on master's ref before 05-FX2 dispatches (merge the PR then fast-forward the master worktree, or set `"disposition": "auto-merge"` and re-run master's merge-back), or FX2's guard will stop with a blocked SUMMARY naming this recovery.
