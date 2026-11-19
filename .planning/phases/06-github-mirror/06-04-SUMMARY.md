---
status: complete  # complete | blocked — a blocked run still writes this record in full
duration: 5min
key-files:
  created: []  # none — prose edits only
  modified:
    - review/SKILL.md
    - review/README.md
requirements-completed:
  - MIR-07
  - MIR-04  # the FX-minting half: `fixes:` frontmatter in the fix-plan planner prompt + capture mint on return
key-decisions:
  - "Ship item 6 delegates the whole sweep to `gh-mirror.sh … ship --verdict` — verdict comment, guarded sub-issue closes, milestone close — with never-block receipt relay replacing the old audit issue"
  - "FX minting reuses the helper's idempotent `capture` (the same sweep define runs at approval) rather than a bespoke mint path; `fixes:` frontmatter is the nesting key"
deviations:
  - "Path prefix: the plan names `.agents/skills/shippEdd/review/SKILL.md` etc., but this worktree is a checkout of the skill repo itself (phase-05 consolidation), so files live at worktree-root `review/SKILL.md`, `review/README.md`, `scripts/gh-mirror.sh`. Guard's intent verified — 06-01's helper is on-branch, executable, with capture/ship subcommands (usage line 37). Both verify commands and the mirror_issues sweep were run against the worktree-root paths, unchanged otherwise."
---

# Plan 06-04 Summary: Review ship sweep — verdict comment, close parent/sub-issues/milestone, FX minting with `fixes:`

Review's v1 audit issue is gone: ship now runs the mirror's `ship --verdict` sweep and the gap loop mints FX sub-issues under the plan they fix — the whole suite reads `github.mirror`, never `mirror_issues`.

## Accomplishments

- `review/SKILL.md` step 1 reads `github.mirror` (pointing at bootstrap's README Configuration reference) — the last `mirror_issues` read in the suite is swept (MIR-08 sweep)
- The fix-plan planner prompt stamps `fixes: <the id of the affected plan>` (MIR-04 half), and the gap loop runs one idempotent `gh-mirror.sh … capture` after fix plans return to mint FX sub-issues under the plan they fix — opt-in, never-block
- Ship item 6 is the **mirror ship sweep**: `gh-mirror.sh <state> <NN> <slug> ship --verdict "<one-line verdict>"` posts the verdict as the parent issue's closing comment, closes still-open decision/plan sub-issues (guarded, state-checked), and closes the phase milestone — a mirror miss is one receipt line, never a failed ship (MIR-07)
- The ship receipt gains the `mirror` line (`parent #<N> closed · verdict posted · milestone closed`, or `—` when off); `review/README.md`'s three audit-issue spots now describe the mirror ship sweep

## Task commits

1. **Task 1: review/SKILL.md — config key rename, FX minting + `fixes:`, ship sweep, receipt mirror line** — `0be3ad5` feat(06-04): review ship sweep — mirror verdict comment, guarded closes, milestone close; FX minting via fixes: (MIR-07)
2. **Task 2: review/README.md — audit-issue prose swapped for the mirror ship sweep** — `6d1bc37` docs(06-04): review README — audit-issue prose swapped for the mirror ship sweep (never-block)

## Files created/modified

- `review/SKILL.md` — step 1 config bullet; step 4 option 1 planner-prompt `fixes:` key + Mirror-mint-for-FX paragraph; step 5 item 6 mirror ship sweep; ship receipt `mirror` line
- `review/README.md` — "What it does", "Prerequisites", "What does review do to git?" now name the mirror ship sweep; no audit-issue wording remains

## Decisions & deviations

Decisions: none beyond the plan — every edit applied verbatim, including the `.agents/skills/shippEdd/scripts/gh-mirror.sh` invocation paths inside the prose (correct for the skill's installed location).

Deviations: one, path mapping only (see frontmatter) — the plan's `.agents/skills/shippEdd/` prefixed paths resolve to worktree-root paths in this skill-repo worktree; verified against sibling commits from 06-02/06-03 (e.g. `fb9d7f5` touching `implement/SKILL.md`). No content deviation; both verify commands print their OK lines and `grep -r mirror_issues review/` is clean.

## Next phase readiness

Wave 2's review-skill surface is complete and coherent with 06-01's helper (capture/ship subcommands exist and match the prose's exact args). The refreshed review skill is live for THIS phase's own `/skill:review` — phase 06's live mirror tree closes at ship through it. No open blockers for waves 3–4.
