# Phase 07-suite-refinements Context

**Gathered:** 2026-11-18 — via `/skill:todo promote` (the four todos were banked mid-work across phases 05–06 ships, not grilled — their Research and Decisions below are pre-settled input)

**GitHub parent:** #62

## Goal

Deliver the 4 promoted todos: planning archive pruning (10), shared run watcher (11), disposition-gated ship PR offer (12), mirror-ship live shape + jq-free helper (13).

## Decisions

| # | Question | Decision | Why | Issue |
|---|-----------------------------------|-------------------|---------------------------|
| 1 | planning-archive-pruning | prune/archive .planning's growing history files (REQUIREMENTS.md, ROADMAP.md, STATE.md) after every N shipped phases, offered as a suggested action in review's ship step | promoted todo 10 (low), captured 2026-11-17 | #63 |
| 2 | shared-run-watcher | all skills should get a watcher like implement's watch-wave.sh; and why does implement's script home differ from the shared scripts/ (review suspected on an old dispatcher) | promoted todo 11 (low), captured 2026-11-18 | #64 |
| 3 | ship-pr-offer | review's ship step offers a PR on every ship (gh+remote gate only) — ignores the repo's push-first convention and the disposition config | promoted todo 12 (low), captured 2026-11-18 | #65 |
| 4 | mirror-ship-live-shape-and-jq-free | cmd_ship read 0 sub-issues on live gh (wrong subIssues shape) and the helper silently reads mirror=off when jq is missing — fix the shape and eliminate the standalone jq dependency | promoted todo 13 (medium), captured 2026-11-18 | #66 |
| 5 | archive shape — where pruned history lands | `.planning/RELEASES.md`: each prune event appends one release entry carrying the dates, commit hashes, and phases it archives; ROADMAP clears to live content only (unchecked phases, live details, unshipped progress rows); superseded REQUIREMENTS versions ride under their release entry with the current version staying in place; `phases/` folders are never pruned or moved | user, 2026-11-18: "releases.md with dates, commit hashes and phases; clear out ROADMAP; don't clean up the phases" | #67 |
| 6 | PR-offer gate at ship | offer a PR iff disposition resolves to `pr` AND the ship changed files outside `.planning/`; docs-only ships get commit + push (today's push-first behavior) with no PR question — planning rides the push, code from worktree branches gets PR treatment | user, 2026-11-18 — matches option 1; gh-auth facts shape the recommendation, never gate it | #68 |
| 7 | watcher architecture | one engine: `scripts/watch-run.sh` owns the blocking/poll/heartbeat/exit-code machinery; implement's `watch-wave.sh` becomes a thin wrapper mapping plan IDs → SUMMARY oracles onto it; watching stays an opt-in user-run command, never a blocking subagent | user, 2026-11-18 — kills the loop duplication without touching implement's phase-04 recovery contract | #69 |
| 8 | archive cadence default | N = 5 — review's ship step offers the RELEASES.md prune whenever `(phases shipped) % 5 == 0`; config key overrides (absent key = 5, documented in README) | user, 2026-11-18 — matches the suite's pace, keeps ROADMAP under ~150 live lines | #70 |
| 9 | jq-free law scope | whole suite jq-free — gh-mirror.sh AND auto-selftest.sh drop the standalone jq dependency (fake-gh's fixed `--jq` programs re-implemented in bash, approximate gojq behavior acceptable for fixtures) | user, 2026-11-19 — the PATH pain that spawned todo 13 hits selftest runs from interactive sessions too; net suite dependency set: bash + gh (+ git) | #71 |

## Constraints

- none — promoted todos
- `phases/` folders are never pruned or moved — the archive sweep touches ROADMAP.md, REQUIREMENTS.md, and RELEASES.md only

## Open questions

- Facts parked on research (step 4):
  - How phase ship commits are identified on master (squash-merge SHAs per phase) — the exact git command RELEASES.md entries will cite, incl. how phase 06's backfill sourced its merge-commit SHAs
  - Exact current shape of review's ship-step PR offer and every site that reads `disposition` today (review SKILL prose, merge-back.sh, gh-mirror.sh) so todo 12's edit lands precisely
  - Full inventory of saved-JSON parses in gh-mirror.sh (line 299's `issues_json` etc.) — which move to gh `--jq` at fetch time vs need re-query, for the jq-free rewrite

## Banked research

Pre-settled input carried verbatim from the promoted todos — `/skill:define` reads this; it does not re-grill it.

### From todo 10 — planning-archive-pruning

Research:
- ROADMAP.md's own conventions comment: "completed milestones collapse into <details> blocks" — a convention with no trigger today
- Precedent: phase 02 flattened `_archive/` into `phases/` flat; archive naming/shape should not resurrect a `_`-prefixed dir (schema constraint from EXEC-10 era)

Decisions:
- Trigger lives in review's ship step as a suggested action, never automatic
- Cadence N is config-driven (absent key = documented default)

### From todo 11 — shared-run-watcher

Research:
- `implement/scripts/watch-wave.sh` — blocks until every named plan resolves; exit 0 = all executed, 2 = blocked/failed (recovery allowed), 3 = attempts exhausted (stop, hand dossier), 4 = timeout (default 3600s); artifact-oracle source of truth (SUMMARY frontmatter), markers advisory with PID checks, 10s poll, ~60s heartbeat
- Review does NOT use an old dispatcher: review/define/wayfind SKILL.mds all dispatch via the shared `.agents/skills/shippEdd/scripts/dispatch.sh` (used live this session for `05-verify2`); no duplicate dispatchers exist (`scripts/` holds exactly auto-selftest.sh, dispatch.sh, runs-dir.sh, state-dir.sh)
- Implement does use the shared home: `dispatch-plan.sh:24` resolves `shared="$here/../../scripts"` and rides it; `merge-back.sh:18` likewise — they are plan-execution wrappers around the shared dispatcher, not second dispatchers
- The split is settled design, phase 05 CONTEXT decision 1 (shared scripts dedup: dispatch.sh + state-dir.sh moved; skill-specific wire-agents.sh, dispatch-plan.sh stay) and decision 7 (runs that commit code get work contexts; researcher/verifier stay in the main checkout)

### From todo 12 — ship-pr-offer

Research:
- `review/SKILL.md:177` — `**Push / PR** — only if \`command -v gh\` succeeds **and** \`git remote\` is non-empty` — the gate is binary, no condition on change type or config
- Repo convention, commit `4997686`: "agent branch flow is push-first — PR only if the human wants one" (documented in 02-worktrees/README.md)
- `.planning/config.json` carries `"disposition": "auto-merge"` — the documented decision-8 opt-in (default is `pr`); phase 05's code merge-backs already honored it locally
- This ship was docs-only: 2 state-dir commits (`7361be8` verification artifacts, `9eb16ff` roadmap tick); gh installed but unauthenticated (`gh auth status` read-only probe)
- Any fix to review/SKILL.md lands canonical-master-first, then the vendored refresh — the standing suite law (phases 02–05 precedent)

### From todo 13 — mirror-ship-live-shape-and-jq-free

Research:
- Verified live: `gh issue view 1 -R progressEdd/shippEdd --json state,subIssues` → `subIssues` object; `[.subIssues.nodes[] | select(.state=="OPEN")] | length` = 26 pre-fix, 0 after manual close.
- gh's `--jq` flag runs gojq embedded in the gh binary (v2.103.3 on this machine) — no jq install needed for gh-side parsing; phase 06 RESEARCH.md documents the flag surface.
- jq on this machine: nix store path above; NOT on interactive-session PATH (executors/verifier worked around by prepending it — recorded in their SUMMARY deviations).
- Manual remediation already done at ship (2026-11-18): 26/26 sub-issues closed via `gh issue close`, parent #1 + milestone closed by the sweep itself.

Decisions:
- Fix approach settled in the ship conversation: correct the live shape AND go jq-free (gh `--jq` for gh output, flat-key bash reader for config) — not just a PATH workaround.
- The fake-gh fixtures must mirror live gh's JSON shapes wherever the helper parses them; a fixture/live divergence is itself a defect to fix in the same pass.
- Config-read failures must be loud (named receipt), never a silent `mirror: off`.
