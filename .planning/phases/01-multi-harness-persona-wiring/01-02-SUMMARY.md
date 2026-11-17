---
provides:
  - bootstrap skill whose step 3b asks the harness question every run (nine options in locked order) and drives scripts/wire-agents.sh — dry-run before the gate, diffs with replace-or-keep at the gate, real run after approval — with step 1's probe reduced to wired-dir evidence, the confirmation gate and rerun behavior speaking the script's receipt contract, and the README documenting multi-harness bootstrap
key-files:
  created: []
  modified:
    - 02-worktrees/master/bootstrap/SKILL.md
    - 02-worktrees/master/bootstrap/README.md
key-decisions:
  - "Harness question is asked every run — never inferred, never persisted; step 1's wired-dir evidence only moves the ➡️ recommendation (decision 2 / REQ-01, baked into ground rule 1's exception clause)"
  - "Sequencing reconciled: step 1 no longer diffs personas against .pi/agents/ — the diff moved into step 3b via wire-agents.sh <harness> --dry-run [--diff], after the harness answer"
  - "Custom stays LLM-inspected, script-deterministic (decision 9): evidence maps to --mode copy|inject|toml, no evidence falls back to plain md copy, and inexpressible formats get hand-converted into a scratch dir wired via --source"
actuals:
  duration: ~10min
  tasks: 2
  completed: 2026-11-16
---

# Plan 01-02 Summary: bootstrap asks the harness question and drives wire-agents.sh

The bootstrap wizard now wires personas for all eight harnesses plus custom: step 3b asks which harness every run, drives `wire-agents.sh` through dry-run → diff/replace-or-keep → gate → real run, and the confirmation gate, rerun behavior, and README all speak the script's receipt contract from plan 01-01.

## Accomplishments

- SKILL.md frontmatter now advertises the harness question and `scripts/wire-agents.sh` wiring; the old "wires the subagent personas into .pi/agents/" phrasing is gone (REQ-01)
- Ground rule 1 carries the explicit exception — the step 3b harness question is asked every run; detection evidence may set the recommendation, never replace the question (decision 2)
- Step 1's persona probe became a **Wired agent dirs** evidence sweep over all seven agent dirs (`.pi`, `.opencode`, `.cursor`, `.codex`, `.claude`, `.gemini`, `.github`), feeding only step 3b's ➡️ — the sequencing open question from CONTEXT is resolved exactly as planned
- Step 3b rewritten in full: nine-option question in the locked order (pi, opencode, hermes, cursor, codex, claude, gemini, github copilot, custom — lines 110–118, strictly ascending), named-harness flow quoting the script's byte-exact output contract (per-persona `create`/`skip`/`differs`, conversion notes, receipt `wire   personas → <dir> (4 agents)` with the dir-created suffix, the verbatim hermes skip note), `--replace <persona>` after gate approval, and the custom ladder ending in `--mode copy --source <scratch-dir>` for hand-converted formats (REQ-03, REQ-04)
- Confirmation gate's PERSONAS block now shows `wire`/`skip` lines with `create`/`replace`/`keep` sub-lines — success criterion 4's receipt shape in the gate — and rerun item 1 re-asks the harness question and checks personas via `wire-agents.sh <harness> --dry-run`
- README synced: "What it does" names all eight harnesses plus custom and the copy/inject/TOML/hermes behavior; new "Does bootstrap work outside pi?" question; "It's working if" gains the dry-run bullet (`wire-agents.sh` mentioned 3×)
- Plan verification checklist fully green: both task verifies PASS, flag coverage in the script 26 ≥ 10, throwaway-dir opencode dry-run spot-check PASS (`md + mode: subagent`), master worktree shows only the two expected file modifications, amp/crush appear nowhere

## Task commits

1. **Task 1: Rewrite bootstrap step 1 evidence probe and step 3b harness question + wiring flow** — `<hash>` (feat) — `feat(01-02): bootstrap step 1 gathers wired-dir evidence and step 3b asks the harness question, driving wire-agents.sh` → `02-worktrees/master/bootstrap/SKILL.md`
2. **Task 2: Update the confirmation gate receipt block, rerun behavior, and bootstrap README** — `<hash>` (feat) — `feat(01-02): confirmation gate and rerun behavior drive wire-agents.sh; README documents multi-harness bootstrap` → `02-worktrees/master/bootstrap/SKILL.md,02-worktrees/master/bootstrap/README.md`

## Files created/modified

- `02-worktrees/master/bootstrap/SKILL.md` — modified (T1, T2): frontmatter description, ground-rule exception, step 1 evidence probe, full step 3b rewrite, gate PERSONAS block, rerun item 1
- `02-worktrees/master/bootstrap/README.md` — modified (T2): "What it does" harness sentence, new common question, "It's working if" bullet
- `.planning/runs/01-02.commits.tsv` — both commit-spec lines (T1's line landed by the earlier attempt; T2's appended this run)
- `.planning/runs/01-02.done` — run marker flipped per the completion contract
- `.planning/phases/01-multi-harness-persona-wiring/01-02-SUMMARY.md` — this summary (final task)

## Decisions & deviations

- No content deviations — plan followed as written; every old→new replacement matched exactly.
- **Task 1 was verified, not redone:** its four edits were already on disk from an earlier attempt with the TSV line already recorded — this run re-ran the verify (PASS) and every acceptance criterion against the on-disk state, then moved on, per the not-redone rule.
- Process note: the checklist's `git -C 02-worktrees/master status --porcelain` was run with `--no-optional-locks` — identical output, but honors the executor rule against taking the shared index lock; `git rev-parse --show-toplevel` was used only inside the plan's own verify commands.
- Out-of-scope observation: this checkout's vendored `.agents/skills/shippEdd/implement/` (SKILL.md, dispatch.sh, replay-commits.sh, deleted slice-tasks.sh) shows uncommitted modifications made by activity concurrent with this run (mtimes 23:05–23:07, outside my two writes) — not touched by this plan; decision 10 held for everything this plan's executors did. Worth the sequencer's awareness when committing.

## Next phase readiness

- Phase 01 execution is complete: 01-01 delivered the proven script, 01-02 the skill-side question/gate/README — all four success criteria now have their implementing artifacts (criterion 4's gate receipt included)
- Ready for `/skill:review` to fill `VERIFICATION.md` (its REQ/decision tables map 1:1 onto the CONTEXT decisions and the receipts quoted in SKILL.md); both plans' verify commands and the 01-01 temp-dir matrix are re-runnable from the checkout root as evidence
- The vendored `.agents/skills/shippEdd/` copy still reflects pre-01-01 bootstrap (by design — decision 10); the squash-merge refresh is the existing flow, outside this phase
- Nothing blocking
