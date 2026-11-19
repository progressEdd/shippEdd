---
name: mirror-ship-live-shape-and-jq-free
captured: 2026-11-18
what: "cmd_ship read 0 sub-issues on live gh (wrong subIssues shape) and the helper silently reads mirror=off when jq is missing — fix the shape and eliminate the standalone jq dependency"
severity: medium
context: "surfaced live at phase 06's ship: sweep printed '0 sub-issue(s) closed' with 26 open subs; tree was closed manually (26/26 via gh) — the code defect remains for every future ship"
files:
  - .agents/skills/shippEdd/scripts/gh-mirror.sh:53-59
  - .agents/skills/shippEdd/scripts/gh-mirror.sh:385-397
  - .agents/skills/shippEdd/scripts/auto-selftest.sh
---

## Problem

Two linked defects in the mirror helper, both exposed by phase 06's live ship:

1. **Live-shape bug** — `cmd_ship`'s sub-issue loop reads `.subIssues[].number`, but live `gh issue view --json subIssues` returns `subIssues` as an **object** (`{nodes: [...], totalCount}`), so the iteration yields nothing: the sweep reported `0 sub-issue(s) closed` while 26 sub-issues stood OPEN under the just-closed parent #1. The fake-gh fixture in selftest case 17 emits `subIssues` as a plain array — the fixture proved the wrong shape green (offline layer passed, live layer failed; exactly the two-layer proof doing its job).
2. **Silent jq dependency** — `j()` wraps jq with `2>/dev/null || true`, so when `jq` is absent from PATH (this NixOS machine's interactive sessions: jq lives at `/nix/store/1bp02949k0xdihbgphpwbzba1741pknk-jq-1.8.2-bin/bin/jq`, not on PATH), every config read returns empty and the helper reports `mirror: off — github.mirror is absent/false` against a config that carries `github.mirror: true`. The first ship-sweep invocation silently no-op'd this way.

## Solution

- Fix the shape: `.subIssues.nodes[].number` in `cmd_ship` (and grep the helper for other `.subIssues`/`.subIssuesSummary` reads — the verifier's live checks used `.subIssues.nodes` throughout).
- Fix the fixture: fake-gh's sub-issues payload must match live gh's object shape (`{nodes, totalCount}`) so case 17 (and any other mirror case touching sub-issues) proves the real shape.
- Eliminate standalone jq: parse all **gh output** via gh's own embedded jq engine (`--json x --jq '<filter>'` — gojq inside the gh binary, zero new dependencies), and read `config.json` with a minimal bash flat-key reader (bootstrap writes the config in a known pretty-printed shape; keys are flat scalars). Net dependency set: bash + gh — both already hard requirements of the mirror path. While there, make the config reader **fail loud** on a config it cannot parse (receipt naming the file) instead of reading as mirror=off.

## Research

- Verified live: `gh issue view 1 -R progressEdd/shippEdd --json state,subIssues` → `subIssues` object; `[.subIssues.nodes[] | select(.state=="OPEN")] | length` = 26 pre-fix, 0 after manual close.
- gh's `--jq` flag runs gojq embedded in the gh binary (v2.103.3 on this machine) — no jq install needed for gh-side parsing; phase 06 RESEARCH.md documents the flag surface.
- jq on this machine: nix store path above; NOT on interactive-session PATH (executors/verifier worked around by prepending it — recorded in their SUMMARY deviations).
- Manual remediation already done at ship (2026-11-18): 26/26 sub-issues closed via `gh issue close`, parent #1 + milestone closed by the sweep itself.

## Decisions

- Fix approach settled in the ship conversation: correct the live shape AND go jq-free (gh `--jq` for gh output, flat-key bash reader for config) — not just a PATH workaround.
- The fake-gh fixtures must mirror live gh's JSON shapes wherever the helper parses them; a fixture/live divergence is itself a defect to fix in the same pass.
- Config-read failures must be loud (named receipt), never a silent `mirror: off`.
