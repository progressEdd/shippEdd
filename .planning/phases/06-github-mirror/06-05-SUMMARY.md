---
status: complete
duration: 50m
key-files:
  created: []
  modified:
    - scripts/auto-selftest.sh
    - scripts/gh-mirror.sh
requirements-completed:
  - MIR-09
key-decisions:
  - "Inaugural live mirror tree on progressEdd/shippEdd: parent #1 + decision sub-issues D1–D20 = #2–#21 (CONTEXT carries 20 decisions, not the plan's stated 19 — D20 was added after drafting; plan verify bound ≥25 satisfied by the actual 26) + plan sub-issues 06-01 #22 · 06-02 #23 · 06-03 #24 · 06-04 #25 · 06-05 #26 · 06-06 #27; label shippedd; milestone 'Phase 06: github-mirror' open; all 26 sub-issues open."
  - "Live capture idempotence: first receipt 'created parent #1 D1 #2 … plan 06-06 #27'; re-run receipts show 'updated' body rewrites only — zero 'created' lines, exit 0 (verified across three runs)."
  - "Phase 06's plan issues close at review's ship sweep (post-refresh), not at PR merge — the phase's own merge-backs ran pre-refresh."
  - "Backfill parents (created closed): phase 01 #28 · 02 #31 · 03 #38 · 04 #44 · 05 #51. Plan sub-issues (all created closed): 01-01 #29, 01-02 #30 · 02-01 #32, 02-02 #33, 02-03 #34, 02-04 #35, 02-05 #36, 02-06 #37 · 03-01 #39 … 03-05 #43 · 04-01 #45 … 04-05 #49, 04-FX1 #50 · 05-01 #52 … 05-06 #57, 05-FX1 #58, 05-FX2 #59. Sub-issue counts exactly 2/6/5/6/8 (hence zero decision sub-issues), per-phase milestones 'Phase 01: multi-harness-persona-wiring' … 'Phase 05: dispatcher-consolidation' all closed."
  - "Backfill idempotence re-run (final helper): 0 '  created  ' lines, 5 'already closed' receipts (3+7+6+7+9 = 32 already-closed = 5 parents + 27 plans)."
  - "Era spots all OK: 05-01…05-05 + 05-FX1 → master gate 73af3f863288b1b6ce8af0daaf2cac0e03027c6f; 05-06 + 05-FX2 → progressEdd gate 143807e419b94623ab4f2418be489ae93d2f0a24; 04-FX1 → 4634433d1d931611da1ef881dd3ae9242e672a9f; 01-01 → c1cac58bd06a9e9fa028b604cc79d4799a6807a0."
  - "Backfilled phase 01–05 trees are created-closed history (decision 20); ship's sweep leaves them untouched."
  - "Merge SHAs: 24/27 bodies carry a history-valid 40-hex SHA; the three misses recorded as deviations per the plan's own 'never invent a SHA' note (see deviations)."
deviations:
  - "Path translation (phase law, 06-01 precedent): the plan's `.agents/skills/shippEdd/` prefix maps to the worktree root — task 1's file is scripts/auto-selftest.sh; all plan commands run with the same translation."
  - "Environment: jq is not on this machine's PATH (Nix-store only); every selftest/live run prepends /nix/store/1bp02949k0xdihbgphpwbzba1741pknk-jq-1.8.2-bin. The header's new 'needs git + bash + jq' documents the dependency."
  - "Fake-gh fidelity corrections inside the plan's own case-14 block (scripts/auto-selftest.sh), exactly the corrections 06-01's summary prescribed seeding here: (a) `issue view` parses `-q` as the `--jq` shorthand — gh-mirror.sh uses `-q` on every state/body read, so without it cases 15–17's own checks fail; (b) the `api` arm applies the caller's `--jq` filter to emitted JSON (create + list) — without it ensure_milestone/ship read a raw array as the number."
  - "Case 16 adds one sandbox line: `git --git-dir=\"$tmp/remote.git\" update-ref -d refs/heads/agent/09-demo/prod` — case 12's push left the prior generation's tip on the bare remote, so the re-forked generation's push would be non-fast-forward and hit the PR fallback instead of pr create (05-05-D1's between-cases-cleanup precedent)."
  - "Task 2 config: the plan's CONFIG-OK predicate expects `disposition: \"auto-merge\"`, but the main checkout's disposition is `pr` — deliberately switched by phase-06 gate commit ffc5896 after this plan was drafted. Preserved untouched (as the plan also demands); mirror keys merged in alongside. Task 2's verify block does not test disposition."
  - "Task 2 cache normalization: 06-01's refresh_context_cache appends a fresh `**GitHub parent:**` line on every sweep (three capture runs → three lines), breaking the plan's single-number sed contract; the main checkout's 06-CONTEXT.md was normalized to exactly one `**GitHub parent:** #1` line. Helper quirk recorded as an observation for a future plan."
  - "Live-gh shapes vs plan assertions (plan drafted against the flat fake): `--json subIssues` is a connection object — assertions/verify adapted to `.subIssues.nodes` (26 ≥ 25 ✓); `gh label view` does not exist in gh 2.103.3 — label proven via `gh label list`; `--json state` emits uppercase OPEN/CLOSED — verify comparisons lowercased (ascii_downcase)."
  - "Product code, scripts/gh-mirror.sh, two commits — live-run fidelity fixes without which this plan's own checks and the phase's decision-9 backstop cannot work: (1) 13ff3a6 — `issue list --limit 1000` (gh's 30/page default made phase 01's already-created tree invisible to the helper — the idempotence re-run tried to re-create its parent; would equally blind review's post-refresh ship sweep) + `?state=all` on the three milestone api lookups (closed milestones are invisible to the default listing); (2) b6344de — `ascii_downcase` on the six `--json state` reads (uppercase states made pr-body/close-plan/ship's open-checks dead code against live gh — the sweep would silently close nothing). The selftest fake was updated in lockstep (arm reorder tolerating the `?state=all` suffix); full selftest re-run green after each commit."
  - "Merge-SHA misses, recorded per the plan's task-3 note ('never invent a SHA'): #32/02-01 — its plan file's `target:` is an unfilled template placeholder, so all five chain greps ran against a garbage branch; the SHA exists on master as 77c0bfbba021ea3e7f8f21b08828931d6aaa3648 (`feat(02-01)`, chain step 3's pattern) and resolves the moment the placeholder is treated as master. #36/02-05 — no commit in this repo's history mentions 02-05 at all (its work product was the replay spec for phase-01's commits, landed under other ids); the era-truthful gate is the phase-02 gate on progressEdd, 1d7a40618bbf7527d69c79e66bc8b2cc326f38c0 ('chore(02-execution-record-rework): waves 1-2 executed — plans 02-01…02-06 landed'). #37/02-06 — same gate 1d7a406 on progressEdd names it, but the plan's target says master and phase-02 gate commits exist only on progressEdd. None of these were hand-injected; the three bodies carry the helper's 'not resolvable' wording. Unblocking decision belongs to the orchestrator (fix 02-01's placeholder target and/or teach the chain a progressEdd fallback, then re-run backfill)."
---

# Plan 06-05 Summary: fake-gh selftest cases 13–17 + the inaugural live run + the phases 01–05 backfill (MIR-09)

Decision 16's two-layer proof is complete: the mirror machinery is now regression-guarded offline (five new selftest cases, 55 checks green) and proven live on progressEdd/shippEdd (phase 06's open tree + five closed backfilled phase trees, 59 issues, both sweeps idempotent).

## Accomplishments

- `auto-selftest.sh` carries cases 13–17: mirror-off no-op + version-floor gate (never-block, exit 0 both), the stateful fake-gh capture sweep (parent/decision/plan sub-issues, tasklist bodies, milestone via `gh api`, label list-then-create, cache write-backs, idempotence), the tasklist flip + broken-gh never-block, the guarded explicit close (both directions: open → one `issue close`; already-closed → `already-closed 1`, no second close) plus the merge-back integration proving `Closes #N` from the helper's pr-body reaches the real `gh pr create --body`, and the ship sweep (verdict as the parent's closing comment, sub-issue sweep-up, milestone PATCH-closed). Header documents cases 13–17 and the jq dependency; `SELFTEST PASSED (55 checks)` from the worktree root.
- The inaugural live capture ran for real: parent #1 + 26 sub-issues + label + open milestone on progressEdd/shippEdd, caches written back in the main checkout (never committed — gate-owned), idempotence proven across repeated runs (updates only, zero creations).
- The decision-20 backfill ran live for phases 01–05: five closed parents with exactly 2/6/5/6/8 closed plan sub-issues (27 total, no decision issues), per-phase milestones created closed, era-aware merge SHAs in 24/27 bodies (all ten era spots OK), idempotence re-run 0 created / 5 already-closed.
- Two live-fidelity defects in 06-01's helper were caught and fixed in-flight (pagination, closed-milestone visibility, uppercase state guards) — without them the phase's own decision-9 backstop (review's post-refresh ship sweep) would silently no-op once the repo passed 30 issues.

## Task commits

1. **Task 1: selftest cases 13–17** — `ee355f7` test(06-05): selftest cases 13-17 — off/gate, fake-gh capture, tasklist flip, guarded close + pr-body (merge-back integration), ship sweep (MIR-09)
2. **Live-run fidelity fix (task 3 blocker)** — `13ff3a6` fix(06-05): gh-mirror live-run fidelity — full issue page (--limit 1000), closed-milestone lookups (?state=all); selftest fake matches
3. **State-guard fix (phase backstop)** — `b6344de` fix(06-05): state guards read gh's uppercase OPEN/CLOSED via ascii_downcase — pr-body/close-plan/ship guards are dead code live otherwise

(Task 2 and task 3's sweeps commit nothing — cross-tree writes are gate-owned per the 05-06 supersession pattern.)

## Files created/modified

- `scripts/auto-selftest.sh` — cases 13–17 appended (232 lines added), header case list + jq note; fake-gh api arm reorder for `?state=all`
- `scripts/gh-mirror.sh` — `--limit 1000` on refresh_issues, `?state=all` on the three milestone lookups, `ascii_downcase` on the six state reads

Main checkout (written, never committed by the executor — the gate owns these): `.planning/config.json` (github mirror keys merged), `.planning/phases/06-github-mirror/06-CONTEXT.md` (parent line + Issue column), `.planning/phases/06-github-mirror/06-0{1..6}-PLAN.md` (`issue:` frontmatter caches).

## Decisions & deviations

See frontmatter `key-decisions` and `deviations`. The load-bearing ones:

- **Live-gh reality vs the plan's flat-fake assumptions** drove every adaptation: subIssues connection shape, absent `gh label view`, uppercase states, 30-per-page listing, closed-milestone invisibility. The first two only changed assertion commands; the last three were product defects in the phase's helper, fixed minimally in two commits with the selftest kept green — the pagination and state-case bugs would have broken review's ship sweep (decision 9's backstop) and every future define capture in this repo.
- **Three merge-SHA misses (02-01, 02-05, 02-06)** are recorded exactly as the plan's note prescribes, with the resolvable commits identified for the orchestrator (77c0bfbb on master for 02-01 once its placeholder `target:` counts as master; 1d7a406 on progressEdd as the phase-02 era gate for 02-05/02-06). Nothing was invented or hand-injected.
- **Disposition is `pr`, not the plan's expected `auto-merge`** (phase-06 gate commit ffc5896) — preserved untouched; nothing in tasks 2–3 depends on it.

## Next phase readiness

- 06-06 (vendored refresh + byte parity) will pick up a master branch whose `scripts/gh-mirror.sh` and `scripts/auto-selftest.sh` carry this plan's commits — byte-parity will vendor the live-fixed helper, which review's ship sweep needs (pagination + state-case fixes are load-bearing for closing phase 06's tree).
- Phase 06's tree is open by design: 26 open sub-issues under parent #1 close at review's post-refresh ship sweep, not at merge-back.
- For the orchestrator's radar (observed, not fixed — outside this plan): (a) refresh_context_cache appends a duplicate `**GitHub parent:**` line per sweep run; (b) the capture receipt prints `milestone --milestone` (ms_args[0] is the flag; the title-strip yields empty); (c) a fresh backfill after its milestone closed would fail `gh issue create --milestone` against the closed milestone title; (d) the plan-tasklist extraction also picks up `<name>Task N:` echoes inside plan code blocks (cosmetic, advisory mirror content); (e) the three backfill SHA misses above.
