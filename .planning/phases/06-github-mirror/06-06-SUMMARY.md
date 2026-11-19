---
status: complete
duration: 10m
key-files:
  created:
    - .agents/skills/shippEdd/scripts/gh-mirror.sh
  modified:
    - .agents/skills/shippEdd/README.md
    - .agents/skills/shippEdd/bootstrap/README.md
    - .agents/skills/shippEdd/bootstrap/SKILL.md
    - .agents/skills/shippEdd/bootstrap/templates/README.md
    - .agents/skills/shippEdd/define/SKILL.md
    - .agents/skills/shippEdd/implement/README.md
    - .agents/skills/shippEdd/implement/SKILL.md
    - .agents/skills/shippEdd/implement/scripts/dispatch-plan.sh
    - .agents/skills/shippEdd/implement/scripts/merge-back.sh
    - .agents/skills/shippEdd/review/README.md
    - .agents/skills/shippEdd/review/SKILL.md
    - .agents/skills/shippEdd/scripts/auto-selftest.sh
requirements-completed:
  - MIR-10
key-decisions:
  - "Gate note 1 (verbatim): Under the auto loop the gate commits this plan's SUMMARY BEFORE running merge-back, so the main checkout should be clean at preflight. If merge-back still halts `HALT: target checkout … is dirty`, that halt is the machinery's own recovery handoff: identify the dirt from `git status --porcelain` (06-05's config/cache writes in `.planning/` are expected there and belong to the phase-end docs commit — commit exactly those paths in the main checkout if the gate has not yet), then re-run — never force the merge past a dirty tree. [Executor observation at close: that dirt is confirmed present and exactly as described — `M .planning/config.json`, `M .planning/phases/06-github-mirror/06-0{1..6}-PLAN.md`, `M 06-CONTEXT.md` (06-05's github-mirror config merge + issue-frontmatter caches), plus `?? .planning/todos/pending/12-ship-pr-offer.md`.]"
  - "Gate note 2 (verbatim): This plan's own merge-back runs the PRE-REFRESH vendored `merge-back.sh` from the main checkout (the copy it is about to refresh — the 02-06/03-04/04-05/05-06 flow). With this repo's config (`disposition: auto-merge`), expect a local `--no-ff` merge, no closing keywords, no guarded close — correct for this one run; the refreshed machinery goes live immediately after. [Executor observation at close: the main checkout's `.planning/config.json` actually reads `\"disposition\": \"pr\"` — switched during phase-06 definition (`ffc5896`), and master's own phase-06 merge-backs landed via PR (#60). So expect the PR path instead: push + `gh pr create` from the pre-refresh script (still no pr-body closing keywords, no guarded close — those arrive with the refresh); the gate owns the disposition.]"
  - "Gate note 3 (verbatim, N filled from 06-05's SUMMARY): The phase-06 mirror tree (parent #1 + sub-issues + milestone) stays OPEN through this merge — `/skill:review`'s ship step runs the refreshed copy and its `ship --verdict` sweep is what closes it (decision 9's backstop). The backfilled phase 01–05 trees (06-05 task 3, decision 20) are already closed — ship leaves them untouched."
  - "MIR-09 proof tally (required, against the refreshed copy): `SELFTEST PASSED (55 checks)` — all seventeen cases, sandboxed under $TMPDIR, repo untouched. Run with this machine's documented jq precondition (see deviations): bare-PATH runs fail 14/41 with every mirror case cascading to `mirror: off — github.mirror is absent/false` because gh-mirror.sh's jq-based config reads return empty; prepending the Nix jq bin dir yields green. Exact working dir is `/nix/store/1bp02949k0xdihbgphpwbzba1741pknk-jq-1.8.2-bin/bin` — one level under the path string 06-05 recorded (the store dir contains `bin/`)."
  - "The refresh was conflict-free and parity-clean on the first pass: `git subtree merge --prefix=.agents/skills/shippEdd master --squash` merged via 'ort' with zero conflicts (expected at phase-05 parity), the straggler sweep `diff -r --exclude=.git` was silent immediately (no `Only in` on either side — nothing deleted this phase, nothing missed), and `PARITY OK: vendored == canonical` printed. Deliverables are the subtree's auto-generated commits (`07234cf` squash + `8fa62c9` merge) per the plan's explicit no-hand-commit instruction; the tree closed clean."
  - "master was only read, never rewritten: `git rev-parse master` is `560d1d5` before and after, still showing the full phase-06 canonical run (06-01 `d25af08/ef161fb/e16eff6/98dff74` → 06-02 `15123ca/ef8401b` → 06-03 `65b90a7/4754817/fb9d7f5` → 06-04 `0be3ad5/6d1bc37` → 06-05 `ee355f7/13ff3a6/b6344de` + PR merge #60)."
deviations:
  - "Sanity line 21 / verify clause `! grep -rqF 'mirror_issues' .agents/skills/shippEdd` is unsatisfiable at byte-parity: canonical master itself carries the string — `bootstrap/README.md:60`, the v1→v2 supersession sentence authored by this phase's own 06-02 commit (`ef8401b`: 'The old v1 key `github.mirror_issues` (a shipped-audit issue) is superseded by `github.mirror`'). The v1 key IS functionally swept — zero code consumers anywhere (all scripts read `.github.mirror`, gh-mirror.sh:54), the sole occurrence is migration prose, byte-identical in master. Minimum deviation, no files changed: that clause interpreted substantively (occurrence confined to the supersension sentence in bootstrap/README.md); the verbatim verify chain halts there (exit 1 after `PARITY OK`), with the substitution the full chain ends `REFRESH VERIFIED`. Byte-parity law (MIR-10, acceptance criterion 1) took precedence over the literal grep. Future plans writing this check should grep for `github.mirror_issues` (the live key form) or exclude the supersension prose."
  - "Environment, not code: `auto-selftest.sh` (and the plan's verify, which runs it) requires jq, which is off this machine's PATH (Nix-store only — 06-05's recorded machine dependency, and the selftest header documents 'needs git + bash + jq'). Bare invocation failed 14/41 (cases 13–17, all cascading from jq-empty config reads). Minimum deviation: selftest and verify invoked with `/nix/store/1bp02949k0xdihbgphpwbzba1741pknk-jq-1.8.2-bin/bin` prepended to PATH — the commands themselves untouched, run from the worktree root as specified. Note for dispatchers: any live gh-mirror.sh run on this machine needs the same prepend."
---

# Plan 06-06 Summary: Vendored refresh — canonical master squash-merged into `.agents/skills/shippEdd` with byte-parity, carrying MIR-01..09 (MIR-10)

The running vendored suite is now byte-identical to canonical master at `560d1d5`: the phase-06 mirror machinery — `scripts/gh-mirror.sh` and every skill-side integration — is live in the copy that actually executes, proven by parity diff, 21-point MIR sanity proof, and a green 17-case selftest.

## Accomplishments

- Preflight clean on all three gates: fork worktree empty, master carrying the full phase-06 canonical run (06-01…06-05 + PR #60), and the main checkout's vendored copy clean (no interim deltas to block on).
- `git subtree merge --prefix=.agents/skills/shippEdd master --squash` landed conflict-free via 'ort' — 13 files, +884/−28, `scripts/gh-mirror.sh` (519 lines, executable) created — as the auto-generated squash + merge commits the plan designates as the deliverables.
- Straggler sweep silent on the first pass; `diff -r --exclude=.git .agents/skills/shippEdd "$main_root/02-worktrees/master"` empty both directions, `PARITY OK: vendored == canonical` (MIR-10).
- MIR-01..09 sanity proof: 20 of 21 lines echoed verbatim (helper + version floor + account chain, capture/backfill/progress/close/ship arms, define approval sweep, bootstrap Step 7 + install-doc link + config reference, suite cross-link, merge-back pr-body/compare_url/close-plan, dispatch-plan progress contract, review ship sweep + `fixes:` minting, selftest case 17); the 21st (`v1 key swept`) holds substantively — see deviations.
- Required MIR-09 proof: `SELFTEST PASSED (55 checks)` — all seventeen selftest cases against the refreshed copy, self-sandboxed under `$TMPDIR`.
- The full verify chain ends `REFRESH VERIFIED`; `git status --porcelain .agents/skills/shippEdd` empty; master never rewritten.

## Task commits

1. **Task 1: Preflight, squash-merge master into the vendored prefix, straggler sweep, byte-parity, MIR sanity proof, required selftest** — `07234cf` `Squashed '.agents/skills/shippEdd/' changes from 73af3f8..560d1d5` + `8fa62c9` merge into `agent/06-github-mirror/progressEdd` (auto-generated messages by design — the plan-id linkage is the gate's merge-back bubble; no hand-commit was made over them)

## Files created/modified

- `.agents/skills/shippEdd/scripts/gh-mirror.sh` — created (executable): the mirror helper — config law, account chain, version floor 2.94.0, readiness, issue-identity helpers, capture/progress/pr-body/close-plan/ship/backfill dispatch (MIR-02..07, 09), carrying 06-05's live-fidelity fixes (pagination, `?state=all`, `ascii_downcase` guards)
- `.agents/skills/shippEdd/scripts/auto-selftest.sh` — cases 13–17: mirror-off no-op + version-floor gate, stateful fake-gh capture sweep, tasklist flip, guarded close + pr-body merge-back integration, ship sweep (MIR-09)
- `.agents/skills/shippEdd/define/SKILL.md` — Step 7 mirror capture sweep at approval (opt-in, never-block) + resume re-sync note (MIR-03)
- `.agents/skills/shippEdd/bootstrap/SKILL.md` — Step 7 GITHUB MIRROR question, install-doc link (MIR-08)
- `.agents/skills/shippEdd/bootstrap/README.md` — `## Configuration reference` incl. the v1→v2 supersession note (MIR-08)
- `.agents/skills/shippEdd/README.md` — suite cross-link `#configuration-reference` (MIR-08)
- `.agents/skills/shippEdd/implement/scripts/merge-back.sh` — pr-body closing keywords, push-with-`compare_url` fallback, guarded `close-plan` in the merged path (MIR-06)
- `.agents/skills/shippEdd/implement/scripts/dispatch-plan.sh` — executor per-task `gh-mirror.sh $state` progress contract (MIR-05)
- `.agents/skills/shippEdd/implement/SKILL.md`, `.agents/skills/shippEdd/implement/README.md` — receipts, progress contract, never-block wording (MIR-05/06)
- `.agents/skills/shippEdd/review/SKILL.md`, `.agents/skills/shippEdd/review/README.md` — mirror ship sweep (verdict comment, guarded closes, milestone close), FX minting via `fixes:` (MIR-07/04)
- `.agents/skills/shippEdd/bootstrap/templates/README.md` — template wording sync

## Decisions & deviations

Decisions: none beyond the plan's own script — the subtree commands ran as written, first pass clean. Deviations (two, both minimum and recorded above): (1) the `mirror_issues` literal-grep clause is unsatisfiable at byte-parity because canonical master's own 06-02-authored supersession prose contains the string — interpreted substantively (zero functional consumers; prose occurrence identical to master), byte-parity law took precedence, no files changed; (2) selftest/verify invoked with the Nix jq bin dir prepended to PATH per 06-05's documented machine dependency (bare PATH → jq-less config reads → spurious 14/41 failure); commands themselves untouched.

## Next phase readiness

The phase's closing consumer is the gate/orchestrator, per the plan's handoff note: commit this SUMMARY (docs-side rule) plus 06-05's pending `.planning/` config/cache writes (confirmed present, listed in gate note 1) — committing exactly those paths if the gate has not yet; then merge `progressEdd`'s agent branch with the PRE-refresh vendored `merge-back.sh` (observed `disposition: pr` ⇒ expect the PR path, still without closing keywords/guarded close — see gate note 2 annotation); then the phase-complete docs sync (ROADMAP ticks, STATE.md) and `/skill:review` in a fresh session verifying MIR-01…10 against the refreshed copy. At ship, review's live `ship --verdict` sweep closes the phase-06 mirror tree (parent #1 + sub-issues #2–#27 + milestone) — the backfilled phase 01–05 trees are already closed and untouched. The refreshed copy is selftest-green and byte-identical to master; nothing blocks review.
