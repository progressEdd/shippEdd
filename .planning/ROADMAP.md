# Roadmap: shippEdd

## Overview

<One paragraph describing the journey from start to finish.>

## Next up

**none — roadmap complete**

## Phases

- [x] **Phase 01: multi-harness-persona-wiring** — bootstrap works on eight harnesses, not just pi
- [ ] **Phase 02: <slug>** — <one-line description>
- [ ] **Phase 03: <slug>** — <one-line description>

## Phase details

### Phase 01: multi-harness-persona-wiring

- **Goal:** bootstrap works on eight harnesses, not just pi: a harness question in step 3b feeds a new `scripts/wire-agents.sh` that wires the four personas into the chosen harness's agent directory (with per-harness conversion where needed)
- **Depends on:** nothing
- **Requirements:** REQ-01, REQ-02, REQ-03, REQ-04, REQ-05
- **Success criteria** (what must be TRUE):
  1. Running bootstrap with any of the eight harnesses selected wires the four personas into that harness's project agent dir in its native format — straight copy (pi, cursor, claude, gemini, github copilot), `mode: subagent` injected (opencode), TOML (codex) — proven by dry-run output plus real runs against throwaway temp dirs
  2. Selecting hermes reports and skips with a note pointing at `~/.hermes/config.yaml` profiles; selecting custom copies personas adapted to any existing examples/docs found, plain md as fallback
  3. Re-running bootstrap on a wired repo skips identical files and never silently overwrites a modified one (diff goes to the confirmation gate); a missing agents dir is created and the receipt says so
  4. The confirmation gate shows `wire   personas → <dir> (4 agents)`

Plans:
- [x] 01-01: wire-agents.sh — the multi-harness wiring matrix (all modes, repair semantics, dry-run; proven via temp-dir runs)
- [x] 01-02: bootstrap SKILL.md harness question + gate/README sync (step 1 probe, step 3b flow, receipts)

### Phase 02: <slug>

- **Goal:** <what this phase delivers>
- **Depends on:** Phase 01
- **Requirements:** <REQ-03>
- **Success criteria** (what must be TRUE):
  1. <Observable behavior from the user's perspective>

Plans:
- [ ] 02-01: <brief description>

## Progress

| Phase | Plans complete | Status | Completed |
|-------|----------------|--------|-----------|
| 01 `multi-harness-persona-wiring` | 2/2 | Shipped | 2026-11-17 |
| 02 `<slug>` | 0/1 | Not started | — |

<!--
Conventions:
- Integer phases (1, 2, 3) are planned work; decimal phases (2.1) are urgent insertions.
- Phase numbering never restarts; completed milestones collapse into <details> blocks.
- Only /skill:review (ship) ticks boxes or edits history here.
-->
