---
status: complete
duration: 45min
key-files:
  created:
    - scripts/gh-mirror.sh
  modified: []
requirements-completed:
  - MIR-02
key-decisions:
  - "Path translation law for this phase's shared master worktree: the suite root IS the worktree root (phase-05 DISP-01 layout), so the plan's vendored-install prefix `.agents/skills/shippEdd/` maps to the worktree root — the helper lives at `scripts/gh-mirror.sh`. Plan 06-06's byte-parity gate (`git subtree merge --prefix=.agents/skills/shippEdd master` + `diff -r .agents/skills/shippEdd 02-worktrees/master`) and its explicit `scripts/gh-mirror.sh is THE file this phase must deliver` confirm this is the only placement that can satisfy the phase capstone."
  - "jq (decision 17's frozen config reader) is NOT on this machine's PATH — binaries exist only in the Nix store (e.g. /nix/store/1bp02949k0xdihbgphpwbzba1741pknk-jq-1.8.2-bin). All fixture/smoke runs prepended that bin dir to PATH ephemerally; no repo or profile writes. Before any live mirror use (06-05) or vendored-copy run, jq must be linked into PATH."
  - "The plan's fake-gh fixtures under-simulate real gh in two places and were made faithful (test harness only, never the product file): (1) `gh api … --jq <filter>` now actually filters (raw `[]`/array output made ensure_milestone see garbage as a milestone number and skip creation); (2) `issue view` arg parsing accepts gh's `-q` shorthand alongside `--jq` (the helper's `-q .body`/`-q .state` views returned raw JSON without it). Sibling plans 06-02..06-05 and the 06-05 selftest formalization must carry the same fidelity in their fakes."
  - "Three product-side output contracts were off by the plan's own expected-output greps and minimally fixed: (a) `created` accumulation now omits the stray leading space (`created=\"${created:+$created }…\"`, 5 sites: cmd_capture ×3, cmd_backfill ×2) so receipts print `created  parent #41` exactly; (b) refresh_context_cache's NUM→awk map strips the `D` prefix from decision keys so the Issue column prints `| #42 |` instead of `—`; (c) backfill inherits the same accumulation fix (BF-PARENT-OK greps the identical 2-space form)."
  - "Task 2's verify `[ \"$(grep -c 'cmd_capture' …)\" = 1 ]` is unsatisfiable as written (definition + mandatory dispatcher wiring = 2 lines); read as definition-count (`grep -c 'cmd_capture()'` = 1), the only interpretation consistent with its own `capture)    cmd_capture` requirement."
  - "Observations (not fixed — no plan contract demands it, per stop-at-the-plan-boundary): (1) refresh_context_cache's Gathered rule re-inserts `**GitHub parent:** #N` on every sweep, so the line count grows by one per capture run (values stay correct); (2) the capture/backfill receipt renders the milestone as the literal `--milestone` because `${ms_args[0]#--milestone }` strips from `ms_args[0]` (the flag) instead of `ms_args[1]` (the title)."
deviations:
  - "File placement: created `scripts/gh-mirror.sh` (suite root, worktree-relative) instead of the plan's literal `.agents/skills/shippEdd/scripts/gh-mirror.sh` — the master worktree's root IS the suite (no `.agents/` exists on master), and 06-06's subtree-merge byte-parity contract names `scripts/gh-mirror.sh` as the master-side deliverable. All plan smoke/verify commands were run with the same prefix translation; file contents are otherwise verbatim."
  - "Product code, 5 lines + 1 line: the `created` accumulation sites (cmd_capture ×3, cmd_backfill ×2) use `created=\"${created:+$created }…\"` and refresh_context_cache builds its map with `${k#D}=` — the minimum edits that make the plan's own fixture greps (`created  parent #41`, `| #42 |`, BF-PARENT-OK) pass; without them the plan's acceptance criteria are unachievable."
  - "Proof harness (not committed — fixtures are ephemeral): fake gh emulates `--jq` filtering on `gh api repos/*/milestones` list calls and accepts `-q` as `--jq` in `issue view`, matching real gh behavior the plan's fake omitted."
  - "Environment, not code: fixture/smoke runs prepend /nix/store/…-jq-1.8.2-bin to PATH because this machine has no jq on PATH (plan lists jq as a frozen dependency). Task 1's smoke sequence also cannot print OFF/GATE-NEVERBLOCK until Task 2 lands the real capture arm (the Task-1 stub prints its own mirror:-prefixed note and exits 0); both halves were re-proven after Task 2 and in the final checklist."
  - "Task 2 verify reading: `grep -c 'cmd_capture'` counted as `cmd_capture()` (definition-count = 1) — see key-decisions."
---

# Plan 06-01 Summary: gh-mirror.sh — the opt-in GitHub mirror helper

`scripts/gh-mirror.sh` (suite-root) now carries the full command surface — ready/capture/backfill/progress/pr-body/close-plan/ship — with the config law, account chain, 2.94.0 floor, `-R`-on-every-call wrapper, lookup-key issue identity, and never-block receipts, all proven offline against a stateful fake gh (31 fixture echoes green, idempotence included).

## Accomplishments

- The suite-root helper exists and passes `bash -n`; every subcommand the rest of phase 06 wires in is live (no stub arms remain): `ready`, `capture`, `backfill`, `progress`, `pr-body`, `close-plan`, `ship --verdict`.
- Config law (MIR-01 keys via jq), account chain (`token_env` → `gh auth token --user <acct>` → stored creds; `GH_TOKEN` vs `GH_ENTERPRISE_TOKEN` by host), gh ≥ 2.94.0 gate, and `ghm()` `-R` wrapper are in place and smoke-proven: `ready` prints `off` with no github config; `VERSION 2.60.0 below floor 2.94.0` with a fake old gh; both never-block paths exit 0 with a `mirror:` note.
- Capture sweep proven offline: parent #41 + D1 #42/D2 #43 decision sub-issues + plan 11-01 #44 (`--parent 41`) with a `- [ ] [11-01] T1 — Do the thing` tasklist line; label list-then-create; milestone via `gh api … -f title=Phase 11: mir`; advisory caches written (CONTEXT `**GitHub parent:** #41` + `| #42 |` Issue column; plan frontmatter `issue: "#44"`) and stable; second run creates nothing.
- progress/pr-body/close-plan/ship proven offline: tasklist flip to `[x]`, exit 0 with gh broken; `Closes #44` on stdout (stdout stays clean); guarded close reports `already-closed 1` with zero second close calls; ship closes parent #41 with the verdict comment, sweeps sub-issues 42/43, PATCHes milestone 7 closed.
- Backfill proven offline against era-shaped git history: parent #41 + plans #42/#43 created CLOSED `--parent 41`, zero decision issues, per-plan and phase-gate merge SHAs resolved into the bodies (`**Merged in:** <sha>`), milestone created-then-closed, re-run reports `already closed` with no create/close calls.

## Task commits

1. **Core — config law, account chain, version gate, readiness, stub dispatcher** — `d25af08` feat(06-01): gh-mirror.sh core — config law, account chain, version gate, readiness, issue-identity helpers, stub dispatcher
2. **Capture sweep — parent + decision/plan sub-issues, lookup keys, drift re-sync, advisory cache write-back** — `ef161fb` feat(06-01): capture sweep — parent + decision/plan sub-issues, lookup keys, drift re-sync, advisory cache write-back
3. **progress / pr-body / close-plan / ship** — `e16eff6` feat(06-01): progress tasklist flip, pr-body closing keywords, guarded close-plan, ship verdict+sweep-up
4. **backfill — shipped-history seeding** — `98dff74` feat(06-01): backfill — shipped-history seeding: parent + plan sub-issues created closed with era-aware merge SHAs, milestone closed

## Files created/modified

- `scripts/gh-mirror.sh` — the phase's mirror helper: readiness/preflight gates, capture re-sync sweep, per-task progress flips, PR closing keywords, guarded close, ship sweep, backfill seeding (created executable; 425 lines)

## Decisions & deviations

See frontmatter `key-decisions` and `deviations`. The load-bearing one for the phase: **the helper lives at `scripts/gh-mirror.sh` (suite root = worktree root on master), not under a nested `.agents/skills/shippEdd/` prefix** — the plan's prefix is the vendored-install location, and 06-06's subtree-merge byte-parity plus its "scripts/gh-mirror.sh is THE file" note pin the master-side path. Plans 06-02..06-05 (same shared worktree) must apply the same translation for their file paths and their `[ -x .agents/skills/shippEdd/scripts/gh-mirror.sh ]` checks, or they will false-block. jq must be on PATH (currently Nix-store only) before any live run.

## Next phase readiness

- 06-02 (define/bootstrap prose) can proceed in this shared worktree using the same `.agents/skills/shippEdd/` → worktree-root path translation (its verify targets `define/SKILL.md`, `bootstrap/SKILL.md`, `bootstrap/README.md`, `README.md` at suite root).
- 06-03/06-04 consumers get the exact CLI they reference: `capture`, `progress <plan-id> <task#>`, `pr-body <target>` (stdout = Closes lines only), `close-plan <target>` (guarded), `ship --verdict "<line>"`.
- 06-05's selftest formalization should seed its fake gh from the fidelity-corrected fake used here (--jq filtering on api lists, `-q` shorthand on issue view) and needs jq on PATH; its live leg additionally needs real gh ≥ 2.94.0 + auth, and jq linked into PATH.
- 06-06's byte-parity will find `scripts/gh-mirror.sh` exactly where its `Only in …/master` note expects it.
