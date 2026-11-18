# Phase 05 dispatcher-consolidation Context

**Gathered:** 2026-11-17 — via `/skill:define` grilling — **LOCKED** (user confirmed; 11 decisions)

## Goal

define/review/wayfind dispatch through implement's shared `--state-dir` dispatcher with transient run state in `$TMPDIR` (oracle-first liveness, no more `.planning/runs/`), and the implement SKILL.md example-leak fix (todo 08) rides the phase's vendored refresh.

## Decisions

| # | Question | Decision | Why |
|---|-----------------------------------|-------------------|------------------------|
| 1 | Where does the one shared dispatcher live? | Suite-root `scripts/` dir — `.agents/skills/shippEdd/scripts/` — and all skills reference the new path (shared scripts dedup: dispatch.sh + state-dir.sh move; skill-specific scripts like wire-agents.sh, dispatch-plan.sh stay in their skill folders) | one canonical copy instead of 3 dispatchers + 6 state-dir.sh copies; Q2 answer 2026-11-17 |
| 2 | Runs-location premise | REOPENED by user: location becomes config-driven, worktree-aware — setup explains worktree benefits, user picks tmp or a custom folder; scripts auto-place when worktrees detected | free-text answer to round 1 Q1/Q3; conflicts with shipped schema — see Open questions |
| 3 | Who decides placement? | config-first — bootstrap's setup asks the question (worktree benefits explained, `git worktree list` prefills the suggestion) and writes the choice to `config.json`; scripts read one key and never guess; absent key = documented default | round 2 Q2 answer 1 |
| 4 | Which layers does the config govern? | both — run work context (worktree when the repo has the habit; new branch in main checkout otherwise) and bookkeeping marker location; one config key, one mental model | round 3 Q1 answer 1 |
| 5 | Readout oracle | products first — RESEARCH.md exists ⇒ research ran, VERIFICATION.md verdict ⇒ verify state; when products are ambiguous, fall back to the durable planning docs (REQUIREMENTS.md); status markers are advisory, for live-watching only | round 3 Q2 answer 1 |
| 6 | Setup worktree creation + path style | setup lets a worktree-less user create one at a path they choose (absolute or relative input accepted); all documented/stored paths default repo-relative, switchable to absolute via config | user free-text, round 3 |
| 7 | Which runs get work contexts? | runs that commit code — implement's executors, config-driven placement; researcher/verifier work in the main checkout (single `.planning` artifact, no merge step); define's dispatcher + prose explicitly in migration scope alongside review/wayfind (user: "don't forget define as well") | round 4 Q1 answer 1 |
| 8 | Post-run disposition | PR by default — merge-back opens a pull request; config opt-in switches to auto-merge (today's behavior) | round 4 Q2 free-text; pulls `gh` CLI into scope, no-remote fallback pending |
| 9 | Proof bar | extend `auto-selftest.sh` with migration/placement/fallback scenarios + one deliberate failure — one cumulative audit surface, one command re-proves every phase, verifier cites it | round 5 Q1; user criterion: simple and easy to audit |
| 10 | GitHub integration scope | split — phase 05 ships only the PR-by-default slice it needs; the full decisions→issues/sub-issues mirror is Phase 06 (`github-mirror`), minted in the roadmap now | round 5 Q2 answer 1 |
| 11 | PR fallback (no remote / no `gh`) | receipt fallback — the run never fails: branch stays, receipt says PR unavailable and names the options (open by hand or rerun with auto-merge) | round 5 Q3 answer 1 |

## Constraints

- Shipped schema (Phase 02 EXEC + Phase 04 AUTO): nothing per-run lands in the repo; `.planning/` holds only named documents; review's ship step currently `rm -rf`s `runs/` precisely because in-repo run state must never be committed — any "current branch" fallback amends these requirements explicitly
- Canonical-master-first, then vendored refresh (squash-merge + byte-parity) — never edit only the vendored copy (todo 08's recorded decision, phases 02–04 precedent)
- `config.json` absent-means-default law: a missing key = the documented default
- AGENTS.md: use `~/`-relative paths, never machine-absolute, in docs/prose — now a config-backed law: default relative, opt-in absolute
- Review's ship step must never again need `rm -rf runs/` — `.planning/` stays runs/-free after this phase

## Open questions

- none — frontier is clear; remaining shape (config key names, marker-dir layout, prompt-file home, review ship-step cleanup removal, SKILL.md/README rewording scope) is planner territory under the recorded constraints
- Note for Phase 06: exact `gh` sub-issues CLI support is young — research it at 06's define time (`gh api` fallback exists regardless)
