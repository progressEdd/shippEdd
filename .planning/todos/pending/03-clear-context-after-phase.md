---
name: clear-context-after-phase
captured: 2026-11-17
what: "Add an explicit instruction to clear the context after a phase finishes"
severity: low
context: "The workflow is built for fresh-context resumes but no skill ever tells the user to clear — the guidance only exists conversationally"
files:
  - 02-worktrees/master/review/SKILL.md
  - 02-worktrees/master/implement/SKILL.md
  - 02-worktrees/master/define/SKILL.md
  - 02-worktrees/master/README.md
---

## Problem

Every skill's handoff names the next command but never says to run it in a fresh session. The whole design — decisions landing in `.planning/` md files as they settle, detached background runs that flip their own markers, subagents carrying research/planning detail — means nothing in a session's context is load-bearing, yet the user only learns "clear between phases" if they happen to ask (as happened mid-define for phase 02: "so I should clear the context for implement?").

## Solution

Add a one-line "clear your context / start fresh" instruction at the phase-boundary handoffs — review's ship step (phase complete → next phase), and ideally define's step 8 and implement's complete step too, since clearing between skill invocations is equally safe — plus a short note in the README explaining why it's safe (everything durable is on disk; STATE.md's `next_action` is the router). Edit the canonical skills in `02-worktrees/master/`; the vendored `.agents/skills/shippEdd/` copy picks changes up via the existing squash-merge refresh.

## Research

- Verified in this conversation: a fresh `/skill:define` session resumes cleanly mid-phase (resolves the phase from ROADMAP `## Next up`, locks existing CONTEXT decisions, re-checks the research marker gate) — nothing depends on session memory
- Implement's executors run detached (`dispatch.sh`, `pi --print`, PID + log); its orchestrator carries digests only; STATE.md frontmatter (`next_action`, `progress`) is the machine-read router surface
- Canonical skill source lives in the `02-worktrees/master/` worktree (skills at the worktree root: `review/`, `implement/`, `define/`); vendored copy at `.agents/skills/shippEdd/` differs by interim deltas (promptless dispatch, worktree-aware routing)
- Phase 02 (`execution-record-rework`) is mid-planning and reworks these same skill files — this todo may want to ride along with phase 02's execution rather than wait for its own phase

## Decisions

none
