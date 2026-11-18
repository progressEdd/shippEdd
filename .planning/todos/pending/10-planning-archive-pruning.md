---
name: planning-archive-pruning
captured: 2026-11-17
what: "prune/archive .planning's growing history files (REQUIREMENTS.md, ROADMAP.md, STATE.md) after every N shipped phases, offered as a suggested action in review's ship step"
severity: low
context: "Banked by user during phase-05 define grilling; .planning grows unboundedly across phases and nothing today ever compacts it"
files:
  - .agents/skills/shippEdd/review/SKILL.md
  - .planning/REQUIREMENTS.md
  - .planning/ROADMAP.md
---

## Problem

Every phase appends to REQUIREMENTS.md (now v4), ROADMAP.md (phases + details blocks + progress table), and STATE.md's history; completed milestones already collapse into `<details>` blocks per the roadmap's own conventions comment, but no skill ever triggers a prune. After dozens of phases the state dir becomes slow to read for humans and skills alike.

## Solution

- Review's ship step, when `(phases shipped) % N == 0` (N from `config.json`, absent = some sane default), offers archive/prune as a suggested action — user accepts or skips
- Archive shape to settle at define time: collapse shipped-phase details into an `archive/` doc (or `<details>` block) keeping only the progress table row per phase; REQUIREMENTS keeps current version + pointers to superseded ones
- Follows the canonical-master-first + vendored-refresh constraint (it edits review's SKILL.md)

## Research

- ROADMAP.md's own conventions comment: "completed milestones collapse into <details> blocks" — a convention with no trigger today
- Precedent: phase 02 flattened `_archive/` into `phases/` flat; archive naming/shape should not resurrect a `_`-prefixed dir (schema constraint from EXEC-10 era)

## Decisions

- Trigger lives in review's ship step as a suggested action, never automatic
- Cadence N is config-driven (absent key = documented default)
