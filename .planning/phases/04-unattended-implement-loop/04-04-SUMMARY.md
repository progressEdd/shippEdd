---
status: complete
duration: 8min
key-files:
  created: []
  modified:
    - implement/SKILL.md
    - implement/README.md
    - bootstrap/templates/NN-0N-PLAN.md
requirements-completed:
  - AUTO-02 — auto is the default: SKILL.md's frontmatter and body make one visit run the whole phase (dispatch → watch → gate → recover → … → merge → complete), stopping only at completion, budget exhaustion, or a judgment stop
  - AUTO-03 — sequential loop: one executor at a time in the phase's per-target worktree, wave/depends_on read as logical order only, each run watched to resolution on the SUMMARY oracle with watch-wave's 0/2/3/4 exit ladder
  - AUTO-04 — bounded recovery documented: 2 retries / 3 attempts per plan and per merge, enforced mechanically (dispatch-plan.sh/merge-back.sh refuse the fourth, watch-wave exits 3), with the judgment-stop carve-out and the verbatim failure-dossier block
  - AUTO-05 — per-wave machinery and the target-overlap check removed coherently (grep-proven absent); merge points computed per target from frontmatter (phase end, or right before the first later consumer), per-target landed oracle `merge(<NN>-<slug>/<target>):`
  - AUTO-06 — `/skill:implement manual` opt-out preserved: stops after each dispatch (classic re-entry cadence), grilling-format questions at every failure, manual re-entry gate at step 4
  - AUTO-08 — README rewritten: both modes, the recovery bounds, merge-point rule, failure dossier, auto-selftest.sh mention, and stop semantics; no `one merge bubble per plan` per-wave language survives
key-decisions:
  - "Both rewrites were extracted mechanically from the plan's 4-backtick fenced blocks (sed line-ranges) rather than retyped, guaranteeing byte-identical content; the template-comment sweep was applied as an exact-text edit and cat-A-verified against the plan's own bytes"
  - "Path prefix follows the recorded precedent of 04-01/04-02/04-03: the plan's `.agents/skills/shippEdd/…` paths are the progressEdd vendored location; this fork-of-master worktree carries the canonical skill tree at its root, so files were edited, verified, and committed at worktree-root-relative paths with verify paths adapted identically"
  - "One verify grep structurally could not pass as written (plan-side wrap), resolved content-first — see deviations; the assertion string itself was never weakened"
deviations:
  - "Path prefix (04-01/02/03 precedent): plan names `.agents/skills/shippEdd/implement/SKILL.md` etc., the vendored location; files edited/verified/committed at worktree-root-relative `implement/SKILL.md`, `implement/README.md`, `bootstrap/templates/NN-0N-PLAN.md`; verify commands' paths adapted identically"
  - "Task 2's verify greps `grep -F \"executes the phase's plans sequentially\"` on the template, but the plan's own replacement text wraps that phrase across two lines of the comment (`…/skill:implement executes` / newline / `the phase's plans sequentially…`) and grep -F is line-based, so the check can never pass on the plan's prescribed content. Content was applied verbatim (byte-verified); the single grep was made wrap-tolerant (`tr '\\n' ' ' < file | grep -F …`) — assertion string unchanged, same deviation class as 04-03's stderr-capture fixes"
---

# Plan 04-04 Summary: SKILL.md + README rework — auto default, sequential loop, bounded recovery (AUTO-02/03/04/05/06/08)

The implement skill's canonical text now describes the machinery 04-02/04-03 landed: auto mode as the default single-visit sequential loop with bounded model-driven recovery and per-target merge points, manual mode as the documented opt-out, and the README + plan template telling the same story.

## Accomplishments

- `implement/SKILL.md` fully rewritten (AUTO-02/03/04/05/06): auto is the default — one visit runs the whole phase (dispatch → watch → gate → recover → … → merge → complete); plans execute sequentially (waves are logical order, not parallelism) one executor at a time in the phase's per-target agent worktree; each run is watched to resolution by `watch-wave.sh` with the 0/2/3/4 exit ladder; recovery is model-driven and bounded (2 retries / 3 attempts per plan and per merge, mechanically enforced, judgment-stop carve-out, verbatim failure-dossier block); merge points are computed per target from frontmatter — phase end or right before the first later consumer — with merge recovery naming fork-base re-record, checkout cleanup, hand-merge, never `branch -D`; the landed oracle is the per-target `merge(<NN>-<slug>/<target>):` commit; `/skill:implement manual` is the opt-out stopping between plans; the fresh-session clause is preserved in the step-6 handoff. All per-wave machinery, the target-overlap check, and the "never wait, never poll" rule are gone (grep-proven: no `target-overlap`, no `dispatch concurrently`, exactly 7 `Step [0-6]` headers).
- `implement/README.md` rewritten wholesale (AUTO-08): what auto mode does end-to-end, when to reach for the skill, prerequisites (clean target checkouts at merge time), the sequential rationale (hybrid parallelism deferred, not rejected), who merges and when, failure handling within the budget, the dossier contents, live-run observation, "It's working if" including `auto-selftest.sh` and the `merge(<NN>-<slug>/<target>):` one-bubble-per-target check, and where the skill fits; no `one merge bubble per plan` per-wave language survives.
- `bootstrap/templates/NN-0N-PLAN.md` trailing comment swept: waves are now described as LOGICAL order executed sequentially by /skill:implement (one executor at a time, one temp worktree per target branch, per-target merge at its merge point); `Waves run in parallel` is gone.
- Both task verifies pass (one recorded wrap-adaptation), the two commits carry the plan's exact conventional messages with the plan id, and `git status --porcelain` is empty after all commits.

## Task commits

1. **Task 1: Rewrite implement/SKILL.md — auto-default sequential loop with bounded recovery** — `4dd9895` feat(04-04): implement SKILL.md — auto-default sequential loop, bounded recovery, per-target merge points
2. **Task 2: Rewrite implement/README.md and sweep the plan template's trailing comment** — `fd15701` docs(04-04): implement README documents auto/manual modes, bounds, and stop semantics; plan template comment goes sequential

## Files created/modified

- `implement/SKILL.md` — the reworked canonical skill text: auto-default single-visit sequential loop, SUMMARY-oracle plan states, per-target merge points, bounded recovery with dossier, manual opt-out, steps 0–6
- `implement/README.md` — the reworked user-facing documentation of both modes, recovery bounds, merge semantics, dossier, and selftest gate
- `bootstrap/templates/NN-0N-PLAN.md` — trailing comment now tells planners/readers the frontmatter carries logical order executed sequentially

## Decisions & deviations

Followed the plan's text verbatim — both rewrites were extracted mechanically from the plan's fenced blocks (byte-identical by construction), and the template sweep was cat-A-verified against the plan's own replacement bytes. Two deviations, both blocker-only minimums with recorded precedent: the established path-prefix mapping (04-01/02/03 — same content at worktree-root-relative paths in this fork-of-master worktree), and one Task 2 verify grep made wrap-tolerant because the plan's own replacement text breaks the grepped phrase across two comment lines, making the check as written structurally unpassable; the content contract was never bent to fit the check.

## Next phase readiness

- 04-05 (vendored-copy refresh onto progressEdd) can now diff its sources cleanly: the canonical reworked skill sits at this worktree's `implement/` and `bootstrap/templates/`, with the exact interfaces the selftest proved (`dispatch-plan.sh`, `watch-wave.sh` 0/2/3/4, per-target `merge-back.sh`).
- Gate note for the orchestrating session (from the plan, unchanged): master's `merge-back.sh` is per-target now and cannot merge this wave's per-plan branch `agent/04-04` — gate with the vendored per-plan script (`bash .agents/skills/shippEdd/implement/scripts/merge-back.sh .planning 04 unattended-implement-loop 04-04` from the main checkout root), expect the known post-merge halt at the branch delete, recover with exactly `git -C 02-worktrees/master branch -d agent/04-04`.
- After this merge, master carries the complete reworked skill — from here on (plan 04-05) the phase runs in the NEW auto mode, driven by the canonical SKILL.md at `02-worktrees/master/.agents/skills/shippEdd/implement/` (the vendored copy lags until 04-05's own merge refreshes it). Wave 5 is the inaugural auto-mode run (AUTO-07 layer 2).
