---
status: complete
duration: 10min
key-files:
  created:
    - scripts/watch-run.sh
  modified:
    - implement/scripts/watch-wave.sh
    - scripts/auto-selftest.sh
    - define/SKILL.md
    - review/SKILL.md
    - define/README.md
    - review/README.md
requirements-completed:
  - todo 11 — one shared watcher engine: scripts/watch-run.sh owns the blocking/poll/heartbeat/exit-code machinery for plan | research | verify kinds, each resolved by its own artifact oracle; watch-wave.sh is a thin wrapper preserving implement's stable CLI and phase-04 recovery contract byte-for-byte; the script-home split is on the record in the wrapper header (no REQ-IDs are mapped to phase 07; the plan rides todo 11 / decision 7, issue #74)
  - decision 7 — define and review name the watcher for their own run kinds (research / verify) in SKILL.md watch lines and READMEs, every mention opt-in/user-run, never a blocking subagent
key-decisions:
  - "The plan arm's resolution strings, budget line, and exit codes are byte-identical to the old watch-wave.sh — selftest cases 1–4 pass through the wrapper unmodified, proving plan-kind parity transitively (61 checks green, three of them the new case 19)"
  - "Applied the plan's insertion (2) verbatim, including its literal target string dropping `--status` from the products-gate bullet's dispatch command (`dispatch.sh --state-dir …` without the flag) — the plan's exact-string contract is binding and its quoted original matched reality; insertion (3)'s pause line and review's walk-away line keep `--status` per their own contracts. Flagging here in case the gate wants the flag restored"
  - "README appends landed mid-paragraph, directly after the plan's anchor sentences (`…streams its output.` / `…streams it.`), keeping each "how do I check on the run" answer one paragraph"
deviations:
  - "gh-mirror progress ran as 'bash scripts/gh-mirror.sh .planning 07 suite-refinements progress 07-03 <n>' (worktree-root path) — the assignment's '.agents/skills/shippEdd/scripts/gh-mirror.sh' does not exist in this master worktree (the suite lives at the worktree root per the plan's cwd note); mirror is off (no .planning/config.json in the worktree), clean silent no-op both times, nothing failed"
---

# Plan 07-03 Summary: shared run watcher — one engine for every skill's background runs (todo 11, decision 7)

`scripts/watch-run.sh` is the suite's one watcher engine (plan | research | verify kinds, artifact-oracle-driven, exit 0/2/3/4); implement's `watch-wave.sh` is now a 24-line thin wrapper whose phase-04 recovery contract is untouched, and define/review both name the watcher for their own run kinds as an opt-in user-run command.

## Accomplishments

- `scripts/watch-run.sh` (executable) owns the blocking/poll/heartbeat/exit-code machinery for all three run kinds, each resolved by its own artifact oracle: plan → SUMMARY frontmatter (+ attempts ledger budget), research → `<NN>-RESEARCH.md` exists, verify → VERIFICATION.md's `## Verdict` filled (first non-blank line real, not the `<GREEN … | …>` placeholder); $TMPDIR markers stay advisory liveness with PID checks (dead PID = failed)
- `implement/scripts/watch-wave.sh` rewritten as a thin wrapper (24 lines, executable) keeping the stable CLI and delegating via `exec bash "$shared/watch-run.sh" … plan …`; the script-home split is on the record in its header (engine in `scripts/` beside dispatch.sh, implement-specific wrappers stay in `implement/scripts/` — the phase-05 shared-core/skill-wrapper law)
- Selftest case 19 added (header case list + three checks): research kind resolves on the artifact oracle (exit 0), a filled verify verdict beats a stale dead-PID `.running` marker (products first, exit 0), a `.failed` research run exits 2 with the marker reason; full selftest 19 cases / 61 checks ends SELFTEST PASSED
- define/SKILL.md names the research-kind watcher in step 4's Background paragraph (marked opt-in/user-run — never the skill's) and in both watch-it parentheticals (products gate + step 7 pause); review/SKILL.md names the verify-kind watcher in step 2's walk-away line and step 3's watch-commands parenthetical; both READMEs' "how do I check on the run" answers name `watch-run.sh` with their kind and the 0/2/4 exit semantics — all inserted prose in the installed `.agents/skills/shippEdd/scripts/watch-run.sh` path form (POL-02)

## Task commits

1. **scripts/watch-run.sh engine (plan | research | verify kinds) + watch-wave.sh thin wrapper + selftest case 19** — `6eac92b` feat(07-03): shared watch-run.sh engine (plan|research|verify) + watch-wave.sh thin wrapper + selftest case 19 (todo 11)
2. **name the watcher in define and review — SKILL.md watch lines + README sync** — `f86f18c` docs(07-03): name the shared watcher in define and review — research/verify watch lines, READMEs synced (todo 11)

## Files created/modified

- `scripts/watch-run.sh` — created: the shared run watcher engine (three kinds, artifact oracles, 0/2/3/4 exit contract, 10s poll, ~60s heartbeat)
- `implement/scripts/watch-wave.sh` — rewritten as the thin wrapper over the engine's `plan` kind; script-home split recorded in its header
- `scripts/auto-selftest.sh` — header case list gains case 19; case 19 block (three checks) inserted after case 18, before the closing tally
- `define/SKILL.md` — research-kind watcher in the Background paragraph, products-gate bullet, step 7 pause line
- `review/SKILL.md` — verify-kind watcher in step 2's walk-away line and step 3's watch-commands parenthetical
- `define/README.md`, `review/README.md` — "how do I check on the run" answers name watch-run.sh with their kind and exit semantics

## Decisions & deviations

Followed the plan as written; both verifies green (WATCHER-OK with SELFTEST PASSED (61 checks); PROSE-OK). Two records, not blockers: the products-gate bullet's target string was applied verbatim including the plan's literal `--status` drop (see key-decisions — insertion (3) and review's lines keep the flag), and the gh-mirror progress call used the worktree-root script path (suite at worktree root on master; mirror off — silent no-op, nothing failed). No files outside the plan's contracts were touched.

## Next phase readiness

The watcher engine, wrapper, and prose are in place and regression-proven (cases 1–19 green through the wrapper). Wayfind/README documentation of the engine beyond these contracts was not this plan's scope — none of the plan's tasks required it. Wave-2 sibling plans already landed (07-01, 07-02) on this branch; the worktree is clean and ready for the phase merge-back.
