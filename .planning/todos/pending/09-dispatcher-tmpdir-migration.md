---
name: dispatcher-tmpdir-migration
captured: 2026-11-17
what: "define/review/wayfind dispatchers still write transient run state to .planning/runs/ instead of $TMPDIR via the shared --state-dir dispatcher"
severity: medium
context: "Phase-02 Decision 10 sanctioned runs/ as define/review's transitional home 'until their migration phase' — that migration has never been planned; nothing in any todo or roadmap covers it"
files:
  - .agents/skills/shippEdd/review/scripts/dispatch.sh:19
  - .agents/skills/shippEdd/define/scripts/dispatch.sh:19
  - .agents/skills/shippEdd/wayfind/scripts/dispatch.sh:19
  - .agents/skills/shippEdd/implement/scripts/dispatch.sh:1-30
---

## Problem

Phase 02 moved implement's execution state to `$TMPDIR` and built one shared `--state-dir` dispatcher, but review/define/wayfind still carry their own near-duplicate dispatchers that hardcode `runs="$root/$(state-dir.sh)/runs"` (identical line 19 in all three). Every verifier/planner/researcher dispatch recreates `.planning/runs/` in-repo with marker/log/prompt files; review's ship step must `rm -rf` it before committing so transient state never lands in git. Three copies of the same script to maintain, plus the transitional in-repo dir the schema already dropped.

## Solution

Migrate the three skills to call the shared dispatcher (`implement/scripts/dispatch.sh`) with a `$TMPDIR` run dir, delete their local copies (or reduce them to thin wrappers), and update review/define/wayfind SKILL.mds' dispatch/watch/readout wording accordingly. One design point a planning session must settle first: their SKILL.mds say "markers are truth" across session re-entry — moving markers to `$TMPDIR` means a reboot wipes them, so the migration needs implement's answer (artifact oracle first, markers advisory — VERIFICATION.md / phase files already exist as oracles) adopted for their readout gates.

## Research

- `implement/scripts/dispatch.sh:4-5` header names this exact debt: "define/review/wayfind's transitional home until their migration; implement passes a $TMPDIR run dir explicitly"
- Phase-02 CONTEXT Decision 1: "Implement + extract a shared dispatcher … implement calls it now, define/review migrate to it later (out of this phase)"; Decision 10: "define/review's dispatch transiently recreates it until their migration phase"
- Phase-02 CONTEXT line 37 research note anticipated the interface question: "what implement needs (transient $TMPDIR run state, liveness without repo markers) vs what define/review will later call"
- Review's ship step (review SKILL.md step 5) already `rm -rf <state>/runs` before committing — the dir never lands in git today
- `AUTO-06`'s SUMMARY-first/PID-liveness pattern in `watch-wave.sh:35-47` is the oracle-model precedent to adopt
- Confirmed 2026-11-17: identical `runs=` line 19 in review, define, and wayfind dispatchers (vendored copy, byte-parity with master)

## Decisions

- Migrate to the existing shared dispatcher — not a new design (phase-02 Decision 1)
- The `.planning` schema stays runs/-free; nothing doc-side to redo (Decision 10 / EXEC-10)
