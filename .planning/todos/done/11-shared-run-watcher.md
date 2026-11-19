---
name: shared-run-watcher
captured: 2026-11-18
what: "all skills should get a watcher like implement's watch-wave.sh; and why does implement's script home differ from the shared scripts/ (review suspected on an old dispatcher)"
severity: low
context: "idea: generalize watch-wave.sh's products-first blocking watcher into the shared scripts/ home so define/review background runs (research/verify) get the same watch primitive; the 'old dispatcher' suspicion is factually wrong — see Research"
files:
  - .agents/skills/shippEdd/implement/scripts/watch-wave.sh
  - .agents/skills/shippEdd/scripts/dispatch.sh
  - .agents/skills/shippEdd/implement/scripts/dispatch-plan.sh
---

## Problem

Implement has a first-class watcher (`watch-wave.sh`) for its waves — block until resolved, exit-code protocol, artifact oracle — but the prose skills' background runs (define's research, review's verify, wayfind) offer only `dispatch.sh --status`, `tail`, and "re-run the skill later": no blocking watch driven by the products-first oracle. The note also questions the script-home split and suspects review of still using an old dispatcher (it does not — see Research).

## Solution

Generalize the watcher into the shared home (e.g. `scripts/watch-run.sh`): same blocking shape and exit-code contract as `watch-wave.sh`, but oracle-driven per run type — RESEARCH.md present ⇒ research ran, VERIFICATION.md verdict ⇒ verify state, SUMMARY frontmatter ⇒ plan executed — with PID-checked advisory markers and timeout. Each skill's SKILL.md gains a watch option alongside walk-away. Skill-specific scripts (dispatch-plan, merge-back, watch-wave itself if subsumed) stay in or move per the DISP-01 split.

## Research

Verified 2026-11-18 in this repo:

- `implement/scripts/watch-wave.sh` — blocks until every named plan resolves; exit 0 = all executed, 2 = blocked/failed (recovery allowed), 3 = attempts exhausted (stop, hand dossier), 4 = timeout (default 3600s); artifact-oracle source of truth (SUMMARY frontmatter), markers advisory with PID checks, 10s poll, ~60s heartbeat
- Review does NOT use an old dispatcher: review/define/wayfind SKILL.mds all dispatch via the shared `.agents/skills/shippEdd/scripts/dispatch.sh` (used live this session for `05-verify2`); no duplicate dispatchers exist (`scripts/` holds exactly auto-selftest.sh, dispatch.sh, runs-dir.sh, state-dir.sh)
- Implement does use the shared home: `dispatch-plan.sh:24` resolves `shared="$here/../../scripts"` and rides it; `merge-back.sh:18` likewise — they are plan-execution wrappers around the shared dispatcher, not second dispatchers
- The split is settled design, phase 05 CONTEXT decision 1 (shared scripts dedup: dispatch.sh + state-dir.sh moved; skill-specific wire-agents.sh, dispatch-plan.sh stay) and decision 7 (runs that commit code get work contexts; researcher/verifier stay in the main checkout)

## Decisions

none
