---
name: skill-md-example-leak
captured: 2026-11-17
what: "implement SKILL.md's step-2 structure illustration hardcodes this repo's phase-04 plan IDs and branch names into the canonical, distributable skill"
severity: low
context: "Dogfood-specific example shipped in the product prose; the fix belongs on master plus a vendored refresh, not on the progressEdd copy alone"
files:
  - 02-worktrees/master/implement/SKILL.md:78-81
  - .agents/skills/shippEdd/implement/SKILL.md:78-81
---

## Problem

Canonical `implement/SKILL.md` step 2 ("show the structure before dispatching anything") uses this repo's live phase-04 execution data as its illustration —

```
order:   04-01 (master) → 04-02 (master) → 04-04 (master) → 04-05 (progressEdd)
merges:  master before 04-05 (first consumer) · progressEdd at end
```

— so every consumer repo reads an example naming plan IDs and branch names that cannot exist for them. The consumer-case parenthetical ("e.g. the vendored refresh consuming `master`") a few lines above has the same dogfood flavor. Behaviorally harmless (the rule text above it is generic; the 04-verify run passed it as AUTO-05 evidence), but it is hyperspecific prose in a distributable skill. Byte-parity holds, so both the canonical and vendored copies carry it.

## Solution

Two-line fix on canonical master: replace the illustration with a neutral one (e.g. `order: 05-01 (main) → 05-02 (docs) → 05-03 (main)` / `merges: main before 05-02 (first consumer) · docs at end`) and reword the consumer-case example to something repo-agnostic; then the standard vendored refresh (subtree squash-merge + `diff -r` byte-parity). Small enough to ride the next skill-touching phase rather than open one.

## Research

- Verified live on 2026-11-17: `diff -r --exclude=.git .agents/skills/shippEdd 02-worktrees/master` → `PARITY OK` (both copies carry the leak)
- The machinery is fully parameterized — only the prose leaks: `dispatch-plan.sh:49` `agent="agent/$slug_dir/$target"` (from plan frontmatter `target:`), `merge-back.sh` takes `<state> <NN> <slug> <target-branch>` as args, landed-oracle greps `merge($nn-$slug/$target):` interpolate
- 04-verify quoted `SKILL.md:75-81` as AUTO-05 covered-evidence without flagging the example (requirements are behavioral; this is a docs-polish defect)

## Decisions

- Fix lands on canonical master first, then vendored refresh — never edit only the vendored copy (would break byte-parity)
