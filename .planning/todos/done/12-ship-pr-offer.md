---
name: ship-pr-offer
captured: 2026-11-18
what: "review's ship step offers a PR on every ship (gh+remote gate only) — ignores the repo's push-first convention and the disposition config"
severity: low
context: "review/SKILL.md step 5.5 fires its push/PR question on any ship where gh and a remote exist, regardless of change type — asked on a docs-only ship against this repo's documented push-first policy"
files:
  - .agents/skills/shippEdd/review/SKILL.md:177
---

## Problem

The review skill's ship step asks "Push and open a PR?" on every ship gated only on `gh` installed + `git remote` non-empty. It fired on phase 05's ship even though that ship's commits were docs-only state-dir bookkeeping, the repo's documented convention is push-first with PR only when the human wants one, `config.json` already opts into `"disposition": "auto-merge"`, and gh was unauthenticated — so the top recommendation had to be reworded around a dead option. Every future ship re-asks this.

## Solution

Make the PR offer respect policy: gate it on the configured `disposition` (offer PR only when it resolves to `pr`) and/or on the ship containing code changes beyond state-dir docs; when the gate doesn't pass, default to the push question alone (or silence, per push-first). Keep gh-auth status as a fact that shapes the recommendation, not a post-hoc caveat.

## Research

Verified 2026-11-18 in this repo:

- `review/SKILL.md:177` — `**Push / PR** — only if \`command -v gh\` succeeds **and** \`git remote\` is non-empty` — the gate is binary, no condition on change type or config
- Repo convention, commit `4997686`: "agent branch flow is push-first — PR only if the human wants one" (documented in 02-worktrees/README.md)
- `.planning/config.json` carries `"disposition": "auto-merge"` — the documented decision-8 opt-in (default is `pr`); phase 05's code merge-backs already honored it locally
- This ship was docs-only: 2 state-dir commits (`7361be8` verification artifacts, `9eb16ff` roadmap tick); gh installed but unauthenticated (`gh auth status` read-only probe)
- Any fix to review/SKILL.md lands canonical-master-first, then the vendored refresh — the standing suite law (phases 02–05 precedent)

## Decisions

none
