---
name: single-branch-phase-pr
captured: 2026-11-19
what: "phases should accumulate all work on one branch and open a single PR at phase end into a phase-declared landing branch — no mid-loop per-target merges"
severity: low
context: "triggered by phase 07's mid-loop PR #76; single-target phases already behave this way — the change is scoped to this repo's two-branch dogfood architecture (canonical master + vendored progressEdd, where the refresh plan consumes master mid-phase)"
files:
  - .agents/skills/shippEdd/implement/SKILL.md
  - .agents/skills/shippEdd/implement/scripts/merge-back.sh
  - .agents/skills/shippEdd/bootstrap/templates/NN-0N-PLAN.md
  - .planning/config.json
---

## Problem

The user's expected phase shape is the classic feature-branch flow: when a phase starts, all its changes accumulate on one branch; when it finishes, one PR opens into a branch of their choosing. Today the per-plan `target:` frontmatter can split a phase across branches, and implement's consumer merge point (step 2 rule (a)) then fires mid-loop — phase 07 opened PR #76 into master before 07-04 could run, exactly as phase 06 did with #60 before 06-06. In this repo every suite-touching phase is multi-target by construction (canonical plans → master, vendored refresh → progressEdd), so the mid-loop PR is structural, not a config flip — no `config.json` key can make a refresh plan see unlanded work.

## Solution

- Phase declares its one landing branch at define time ("a branch we want"); the planner never splits targets within a phase; merge-back runs once, at phase end, opening the single PR
- The refresh plan's cross-branch dependency needs a new home — options floated at capture: split the vendored refresh into its own follow-up mini-phase, or target the phase-end PR at master and let a standing refresh job carry it to progressEdd afterward
- No change needed for default single-target repos — they already get exactly the desired shape

## Research

Verified in this conversation (post-07 ship, 2026-11-19):

- Merge-point law is implement SKILL.md step 2: (a) consumer case — a target's agent branch merges right before the first not-yet-executed plan on a different branch whose `depends_on` names it; (b) phase-end case. Single-target phases only ever hit (b)
- Phase 07: PR #76 (master, cbb99e2) merged mid-loop before 07-04; PR #77 (progressEdd, 1d0b241 + squash badba3a) at phase end. Phase 06: identical dance (#60 then #61)
- Phases touching only `.planning` or only `master` would already get the one-branch/one-PR shape
- `disposition` config is already `pr`; it governs how merge-backs land, not when they fire — the timing comes from `wave`/`depends_on`/`target` in plan frontmatter

## Decisions

none
