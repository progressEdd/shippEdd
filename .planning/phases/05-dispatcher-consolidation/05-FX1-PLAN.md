---
wave: 5
depends_on: []
target: master
---

# Plan 05-FX1: bootstrap/README.md's two state-dir.sh references reworded to the shared scripts path (DISP-01 — verification gap 1, canonical half)

**Objective:** Close gap 1 from verification run 05-verify: `bootstrap/README.md:21` ("Everything resolves through `scripts/state-dir.sh`") and `:37` ("Running `scripts/state-dir.sh` prints exactly one line — the state dir") still name the skill-relative script deleted by commit `94b211c`, and the file carries **zero** references to the shared home (`.agents/skills/shippEdd/scripts/`) — `grep -c '.agents/skills/shippEdd/scripts/' bootstrap/README.md` → 0, the only SKILL.md/README straggler against DISP-01 ("every SKILL.md/README references the new path"). Two-line reword on canonical master; plan 05-FX2 (wave 6) then rides it to the vendored copy. Nothing else in the suite changes.

**cwd note:** your agent worktree is a fork of `master` — the canonical skill tree sits at your worktree root (`bootstrap/`, `define/`, `implement/`, `review/`, `todo/`, `wayfind/`, `README.md`, `scripts/`). All paths below are worktree-root-relative. Exactly one file changes in this plan.

## Tasks

<task>
<name>Task 1: Reword both stale state-dir.sh references in bootstrap/README.md to the shared path</name>
<files>bootstrap/README.md</files>
<action>
Idempotence first: if both target lines already carry `.agents/skills/shippEdd/scripts/state-dir.sh`, this task is done — run the verify, commit nothing, record `nothing to do` in the SUMMARY's deviations.

**Edit 1 — line 21**, inside the "Can I move the state dir later?" answer. Current text:

```markdown
Yes — edit `state_dir` in `.pi/planning.json` (or export `PLANNING_DIR` for a session) and move the folder. Everything resolves through `scripts/state-dir.sh`; the toggles in `config.json` travel with the state dir.
```

becomes (only the script path changes — the sentence shape and everything after the semicolon stay byte-identical):

```markdown
Yes — edit `state_dir` in `.pi/planning.json` (or export `PLANNING_DIR` for a session) and move the folder. Everything resolves through `.agents/skills/shippEdd/scripts/state-dir.sh`; the toggles in `config.json` travel with the state dir.
```

**Edit 2 — line 37**, the first bullet of "It's working if". Current text:

```markdown
- Running `scripts/state-dir.sh` prints exactly one line — the state dir (`$PLANNING_DIR` → `.pi/planning.json` → `.planning`).
```

becomes:

```markdown
- Running `.agents/skills/shippEdd/scripts/state-dir.sh` prints exactly one line — the state dir (`$PLANNING_DIR` → `.pi/planning.json` → `.planning`).
```

Both replacements mirror bootstrap/SKILL.md's own step-0 form ("Run `.agents/skills/shippEdd/scripts/state-dir.sh`.") — repo-relative prose per the AGENTS.md path law. **Do not touch anything else**: the `scripts/wire-agents.sh` references in this file are correct as-is (that script still lives in this skill's own `scripts/` folder, alongside no other file), and every other section is gap-free per verification run 05-verify.

Expected diff shape: `git diff --stat` → `1 file changed, 2 insertions(+), 2 deletions(-)`.

Commit atomically:

```bash
git add bootstrap/README.md
git commit -m "fix(05-FX1): bootstrap README — both state-dir.sh references point at the shared scripts path (DISP-01, gap 1)"
```
</action>
<verify>cd "$(git rev-parse --show-toplevel)" && grep -qF 'Everything resolves through `.agents/skills/shippEdd/scripts/state-dir.sh`; the toggles' bootstrap/README.md && grep -qF '- Running `.agents/skills/shippEdd/scripts/state-dir.sh` prints exactly one line' bootstrap/README.md && [ -z "$(grep -n 'scripts/state-dir.sh' bootstrap/README.md | grep -vF '.agents/skills/shippEdd/scripts/state-dir.sh')" ] && [ "$(grep -cF '.agents/skills/shippEdd/scripts/' bootstrap/README.md)" -eq 2 ] && git diff HEAD~1 HEAD --stat | grep -qF 'bootstrap/README.md | 4' && git show --stat --oneline HEAD | grep -qF 'fix(05-FX1)' && echo "GAP-1 CANONICAL FIX VERIFIED"</verify>
<acceptance_criteria>
- `bootstrap/README.md` line 21 reads "Everything resolves through `.agents/skills/shippEdd/scripts/state-dir.sh`; the toggles in `config.json` travel with the state dir." and the first "It's working if" bullet reads "- Running `.agents/skills/shippEdd/scripts/state-dir.sh` prints exactly one line — the state dir (`$PLANNING_DIR` → `.pi/planning.json` → `.planning`)."
- The verifier's own probe flips: `grep -cF '.agents/skills/shippEdd/scripts/' bootstrap/README.md` prints exactly `2` (was 0)
- No other `state-dir.sh` form survives: `grep -n 'scripts/state-dir.sh' bootstrap/README.md | grep -vF '.agents/skills/shippEdd/scripts/state-dir.sh'` is empty; `scripts/wire-agents.sh` references untouched
- `git diff HEAD~1 HEAD --stat` shows exactly `bootstrap/README.md | 4 +-` — one commit carrying `fix(05-FX1)`, no other file changed
</acceptance_criteria>
</task>

## Verification

Before declaring this plan complete:

- [ ] Task 1 verify passes and ends `GAP-1 CANONICAL FIX VERIFIED`
- [ ] `git status --porcelain` in your worktree is empty (nothing uncommitted beyond the task commit)
- [ ] SUMMARY (05-FX1-SUMMARY.md) written per the dispatch prompt's destination with frontmatter `status: complete`, the task commit hash under task commits, and `requirements-completed: [DISP-01]`

**For the gate/orchestrator (not executor work):** after this plan resolves, commit its SUMMARY docs-side, then merge master's agent branch — `bash .agents/skills/shippEdd/implement/scripts/merge-back.sh .planning 05 dispatcher-consolidation master`. Disposition note: `.planning/config.json` carries no `disposition` key, so this runs PR-by-default and origin exists — a real PR may open, leaving the branch as PR head with master's ref NOT yet carrying the fix. That is success-shaped for the loop, but 05-FX2's preflight requires the fix on master's ref: land it before FX2 dispatches (merge the PR then fast-forward the master worktree: `git -C 02-worktrees/master fetch origin && git -C 02-worktrees/master merge --ff-only origin/master`; or set `"disposition": "auto-merge"` in `<state>/config.json` and re-run master's merge-back — a user decision). FX2's guard stops with a blocked SUMMARY naming this exact recovery otherwise.

<!--
Fix plan for verification gap 1 (05-verify), wave 5 (phase max wave was 4).
Canonical master first per the suite law ("never edit only the vendored copy");
05-FX2 (wave 6) rides this commit to the vendored copy — FX2's depends_on names
this plan, which is exactly what makes implement's merge-point machinery merge
master right before FX2 dispatches (the consumer case). A two-line docs fix:
no script changes, no selftest changes, no prose beyond the two lines.
-->
