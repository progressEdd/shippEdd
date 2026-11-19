---
status: complete
duration: 25min
key-files:
  created: []
  modified:
    - scripts/gh-mirror.sh
    - scripts/auto-selftest.sh
requirements-completed:
  - todo 13 (decision 9: whole suite jq-free — net deps bash + gh + git)
  - decision 4 (live subIssues is a connection object; ship sweep reads .subIssues.nodes[].number)
  - banked decision (a silent mirror=off on an unparseable config is banned — loud named receipt)
key-decisions:
  - "Task 1 smoke ran under a purpose-built gh-free PATH (symlink bin minus gh): the plan's smoke precondition says 'no gh anywhere on PATH', but this machine has gh at /etc/profiles — running the smoke verbatim under the ambient PATH would have hit the real gh and returned ok o/r instead of NOGH"
  - "Mirror progress calls ran via scripts/gh-mirror.sh (worktree-root path per the plan's cwd note) rather than the prompt's literal .agents/skills/shippEdd/scripts/ form, which does not exist in this master-root worktree; mirror is off in the worktree (no .planning/config.json) so both calls were the documented never-block off receipt"
deviations:
  - none  # both tasks implemented exactly as written; the two notes above are environment adaptations at the plan's own stated preconditions, not spec changes
---

# Plan 07-01 Summary: gh-mirror.sh goes jq-free + reads live gh's subIssues shape

The suite no longer shells out to standalone jq anywhere: gh-mirror.sh reads its config with a fail-loud flat-key bash reader, caches issues as a number<TAB>title TSV fetched with gh's embedded --jq, and the ship sweep now reads gh's real nested subIssues.nodes shape; auto-selftest.sh's fake-gh answers the known fixed --jq programs in bash and a new case 18 proves the config law.

## Accomplishments

- `scripts/gh-mirror.sh` is standalone-jq-free (verify grep for `jq` as a shell word: zero matches): the `j()` jq config reader became `cfg_sane`/`cfg_guard`/`jstr` + a flat-key bash reader (runs-dir.sh precedent) where an absent key keeps its documented default and an unparseable config is a LOUD named receipt (exit 0, never a silent mirror=off); `ready_line()` and `preflight()` open with `cfg_guard`
- The saved `issues.json` became `issues.tsv` (number<TAB>title, one gh call via `--jq '.[] | "\(.number)\t\(.title)"'`); `find_issue` is now a bash glob-prefix matcher and the capture drift loop feeds from the TSV
- `cmd_ship()` reads `--jq '.subIssues.nodes[].number'` — the live connection-object shape whose flat form returned 0 sub-issues (07-RESEARCH Q3, decision 4)
- `scripts/auto-selftest.sh` is jq-free in lockstep: the fake-gh `api` block answers its known fixed `--jq` programs from its own TSV state (unknown pairs fail loud), `issue list` emits the TSV directly, `issue view` is a quoted `what:jqprog` pair table with the nested subIssues fixture and a FAKEGH tripwire, and case 18 proves labels[0], the fetch-time `--json number,title --jq`, and the loud `config miss:` receipt
- Offline smoke: nested pretty-printed config parses through bash (NOGH, not silent off); corrupt config → `config miss:` with exit 0; absent config → quiet `off`
- Full selftest green on this machine's bare interactive PATH (jq is not on it at all): `SELFTEST PASSED (58 checks)` across all 18 cases — the 06-06 jq-PATH workaround is dead

## Task commits

1. **gh-mirror.sh — flat-key bash config reader (fail-loud), TSV issue cache with bash lookup, subIssues.nodes shape, jq-free header** — `c400451` fix(07-01): gh-mirror jq-free — flat-key bash config reader (fail-loud cfg_guard), TSV issue cache with bash find_issue, live subIssues.nodes shape
2. **auto-selftest.sh — fake-gh's fixed --jq programs in bash, nested subIssues fixture, TSV issue list, case 18 (config law), jq dropped from deps** — `4de33de` fix(07-01): auto-selftest jq-free — fake-gh answers fixed --jq programs in bash, nested subIssues fixture, TSV issue list, case 18 config law

## Files created/modified

- `scripts/gh-mirror.sh` — config law (flat-key bash reader, cfg_guard loud gate), issue identity (issues.tsv + bash find_issue), drift loop feed, cmd_ship subIssues.nodes fix, header notes
- `scripts/auto-selftest.sh` — header/usage (needs git + bash — jq-free), fake-gh api/issue-list/issue-view arms, new case 18

## Decisions & deviations

None — both tasks implemented exactly per the plan's action blocks; every acceptance criterion demonstrated (MIRROR-JQFREE-OK, SELFTEST-GREEN-BARE-PATH, 18/18 cases, three offline smoke lines).
Environment notes (not spec deviations): the Task 1 offline smoke was executed under a gh-free constructed PATH because this machine has gh on its ambient PATH — the smoke's own precondition is "no gh anywhere on PATH" (with ambient gh the ready probe would return `ok o/r`, not `NOGH`). The per-task mirror progress calls used the worktree-root helper path `scripts/gh-mirror.sh` (master-root worktree; the prompt's `.agents/skills/shippEdd/scripts/` form exists only on progressEdd post-07-04) and returned the never-block `mirror: off` receipt — the mirror is opt-in and off in this worktree.

## Next phase readiness

- The suite's net dependency set is now bash + gh + git (decision 9); nothing anywhere in it execs standalone jq — later phase-07 plans (07-02..) and the 07-04 vendored refresh build on this
- The live-shape subIssues fix ships in cmd_ship; the first live review ship on a real mirrored phase will exercise it (fake parity is proven by case 17 end-to-end through the nested shape)
- Case 18 anchors the config law: defaults, labels[0], loud corrupt-config receipt — any future reader regression fails the selftest loudly
