---
name: implement-auto-mode
captured: 2026-11-17
what: "/skill:implement runs a whole phase unattended — dispatch, watch, gate, merge-back, docs sync, next wave — stopping only when a human is needed"
severity: medium
context: "user doesn't want to re-run the skill between waves; merge-back already needs no input — only the per-wave re-entry was babysitting"
files:
  - .agents/skills/shippEdd/implement/SKILL.md
  - .agents/skills/shippEdd/implement/scripts/watch-wave.sh
---

## Problem

`/skill:implement` stops after dispatching each wave and waits for the user to re-run it to gate the wave and dispatch the next. For a multi-wave phase that's N hands-on re-entries doing work that needs no decisions — gate, merge-back, docs sync, and dispatch are all mechanical once the wave's SUMMARYs land. The user asked to stop babysitting this.

## Solution

Opt-in auto mode for the implement skill, same steps otherwise:

- new `scripts/watch-wave.sh` — blocks until every plan of the wave resolves (executed / blocked / failed / skipped), polling the `$TMPDIR` run markers (PID-liveness aware) and the SUMMARY oracle, printing one line per resolved plan
- SKILL.md: in auto mode, step 3 dispatches then invokes `watch-wave.sh`; step 4 gates/merges/syncs and loops to step 2 in the same visit, instead of stopping; rule 6 gains the auto-mode clause — the visit ends at step 5 or at the first question (blocked/failed plan, merge-back halt, interrupted run)
- README of the skill updated to describe the mode

## Research

- Plan-state oracle and marker semantics: `implement/SKILL.md` step 1 (`.running` with live/dead PID, `.failed` with one-line reason, SUMMARY `status: complete` as truth; `$TMPDIR` state advisory only)
- `dispatch.sh --status --state-dir <dir>` already reports run states; the watch loop can reuse its semantics
- In-session dry run on 2026-11-17: waves 4→5 of phase 03 driven by hand with sleep loops — pattern works; no code changes were needed to drive it

## Decisions

- merge-back stays per-wave, between dispatches — deferred-to-end merging would fork dependent waves from target HEADs missing their dependencies' work (wave-5 vendored refresh consumes wave-4's `master` output); no branch stacking (mixed targets like `master`/`progressEdd` cannot stack)
- watch-wave resolves from artifacts (SUMMARY) with `$TMPDIR` markers advisory only, mirroring SKILL.md rule 2
