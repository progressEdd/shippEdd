---
wave: <N>
depends_on: [<plan-ids this plan requires, e.g. "01-01", or [] >]
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
Waves run in parallel within a number, sequentially across numbers; depends_on
lists the plan IDs that must finish first. Both are precomputed at plan time —
/skill:implement reads them from this frontmatter, no runtime analysis.
Executors are fed one task block at a time (/skill:implement slices this file
per task), so every block must stand alone: its code exact, its context inside
its own <action>.
On completion the final task's executor writes NN-YY-SUMMARY.md next to this
file.
-->
