---
wave: <N>
depends_on: [<plan-ids this plan requires, e.g. "01-01", or [] >]
target: <branch this plan's executor forks from and merges back into, e.g. "master" — omitted means master>
---

# Plan <NN-YY>: <title>

**Objective:** <What this plan accomplishes and why it matters for the phase goal.>

## Tasks

<task>
<name>Task 1: <action-oriented name></name>
<files><files to create/modify, comma-separated</files>
<action>
<What to do and how — shown as code wherever code is the instruction: the
complete function/class/interface to add or the exact edit to make, config
blocks with real values, the commands to run. Prose carries only what code
cannot show — order, intent, pitfalls. Never describe a target state you can
display; never "align X with Y" without the exact target.>
</action>
<verify><command or check that proves it worked></verify>
<acceptance_criteria>
- <Grep-verifiable condition: "file.ext contains 'exact string'">
- <Measurable condition: "output uses 'expected-value', NOT 'wrong-value'">
</acceptance_criteria>
</task>

<task>
<name>Task 2: <action-oriented name></name>
<files><files></files>
<action><Code-first: the implementation, config block, or exact edit; prose only for what code cannot show.></action>
<verify><Command or check></verify>
<acceptance_criteria>
- <Grep-verifiable condition>
</acceptance_criteria>
</task>

## Verification

Before declaring this plan complete:

- [ ] <Test/build command passes>
- [ ] <Behavior verification check>

<!--
wave/depends_on carry the phase's LOGICAL order — /skill:implement executes
the phase's plans sequentially in that order (one executor at a time, one
temp worktree per target branch); target names the branch whose per-target
agent worktree the plan's executor works in and that the phase merges back
into at its merge point. All three are precomputed at plan time —
/skill:implement reads them from this frontmatter, no runtime analysis.
Each plan's executor walks the task sections in order, commits each task
atomically inside the phase's per-target worktree, and writes NN-YY-SUMMARY.md
next to this file on completion.
-->
