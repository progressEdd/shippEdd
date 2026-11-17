---
provides:
  - wire-agents.sh — the deterministic persona wiring engine for eight harnesses (copy, inject, toml, report-and-skip) plus the custom-directory escape hatch, with repair semantics and --dry-run, every mode proven by real runs in throwaway temp dirs
key-files:
  created:
    - 02-worktrees/master/bootstrap/scripts/wire-agents.sh
  modified: []
key-decisions:
  - "Byte-exact output contract (per-persona lines, receipt + dir-created note, hermes note, dry-run footer) is now proven stable — plan 01-02 and the bootstrap gate may quote it verbatim"
  - "Proof is the plan's temp-dir matrix (decision 8: no test framework) — real wirings only ever ran inside throwaway temp dirs; the dev repo and the master worktree stayed clean"
  - "Identical-skip compares CONVERTED output for inject/toml, so re-runs are idempotent in every mode; --replace upgrades only a named differing persona"
actuals:
  duration: ~15min
  tasks: 2
  completed: 2026-11-16
---

# Plan 01-01 Summary: wire-agents.sh — the multi-harness wiring matrix

The four canonical personas can now be wired into any of eight harnesses' project agent directories by one deterministic script — every mode (copy, inject, toml, report-and-skip, custom) proven end-to-end by real runs against throwaway temp dirs.

## Accomplishments

- `wire-agents.sh` wires all eight harnesses per decision 1: straight md copy (pi, cursor, claude, gemini, github-copilot), `mode: subagent` injection (opencode), md → TOML conversion (codex), report-and-skip with the exact `~/.hermes/config.yaml` note (hermes), plus `custom <dir> [--mode copy|inject|toml] [--source <dir>]` as the escape hatch (decisions 1, 9)
- Repair semantics (decision 7) hold end-to-end: agents dir created if absent and the receipt notes it (`— dir created in project directory`), missing files wired, identical files skipped compared as **converted** output, a differing file kept and reported with its `--replace <name>` hint — never silently overwritten
- The full proof matrix passed with `ALL WIRING MODES PROVEN` — all 26 `OK` checks across dry-run, byte-identical copy, inject idempotence, TOML determinism, hermes skip, all remaining harnesses, custom fallback/mode/source, differs-kept/`--replace`, dir-creation receipt, and rejection of unknown harnesses (amp) and missing arguments
- Second runs report 4 × `skip … (identical)` for copy, inject, and toml alike — converted-output comparison is sound; a tampered persona reports `differs … (kept`, survives plain re-runs, and `--replace` overwrites exactly the named file
- No stray writes: real wirings ran only in throwaway temp dirs; the dev checkout's own agent dirs (`.pi`, `.opencode`, `.cursor`, `.codex`, `.claude`, `.gemini`, `.github`) are untouched, the master worktree shows only the new script, and the vendored `.agents/skills/shippEdd/` tree is untouched (decision 10)

## Task commits

1. **Task 1: Implement wire-agents.sh with all wiring modes, repair semantics, and dry-run** — `<hash>` (feat) — `feat(01-01): add wire-agents.sh persona wiring engine for eight harnesses` → `02-worktrees/master/bootstrap/scripts/wire-agents.sh`
2. **Task 2: Prove every wiring mode with real runs against throwaway temp dirs** — no commit (verify-only; no TSV line recorded)

## Files created/modified

- `02-worktrees/master/bootstrap/scripts/wire-agents.sh` — created (T1): the wiring engine; executable, `bash -n` clean
- `.planning/runs/01-01.commits.tsv` — T1's commit-spec line (the only line; T2 is verify-only)
- `.planning/runs/01-01-T1.done`, `01-01-T2.done` (+ T1/T2 logs) — run markers flipped per the completion contract
- `.planning/phases/01-multi-harness-persona-wiring/01-01-SUMMARY.md` — this summary (final task)

## Decisions & deviations

- **T1 deviation (recorded by T1's executor, carried here for the whole-plan record):** the plan's verbatim `convert_toml` awk embedded `'''` inside a single-quoted awk program — shell quoting terminates the string, so every codex conversion failed. Minimum fix: pass the fence via `awk -v q="'''"`; emitted bytes identical to intent. Only `wire-agents.sh` touched.
- **T2 deviation (this task):** the matrix's step 5b check `grep -qx 'tools = ["read", "grep", "find", "ls", "write"]'` is unsatisfiable as written — in POSIX BRE the bracketed part is a character class matching ONE character, so the pattern can only match 9-char lines like `tools = d` (empirically proven: it matches `tools = d`, and fails the script's actual emitted line `tools = ["read", "grep", "find", "ls", "write"]`). The script's output is byte-exact per the plan's task-1 code, so "fix the script" cannot apply. Minimum unblocking deviation: added `-F` (`grep -qxF`) to that one line of the throwaway `/tmp/wire-matrix.sh` — the check's literal-intent preserved exactly, all other 25 checks verbatim, matrix re-run from the top. No repo file touched by this deviation.
- Out-of-scope observation: under `bash -e`, a failing left side of an `a && echo OK` chain skips the OK line silently instead of aborting (why the first run "passed" with OK 5b missing). Worth remembering when plan authors compose future proof matrices.
- Otherwise none — plan followed as written; decisions 1, 4, 5, 7, 8, 9 implemented exactly.

## Next phase readiness

- Plan 01-02 (bootstrap SKILL.md harness question + gate/README sync) can start immediately: the script's output contract is proven byte-stable for quoting in SKILL.md, the gate receipt `wire   personas → <dir> (4 agents)`, and README examples; the `custom <dir> --mode … --source …` surface is fixed for the skill-side inspection flow (decision 9)
- The matrix stays reproducible as `/tmp/wire-matrix.sh` (regenerate from plan 01-01 task 2 if lost); the verifier can re-run it from the checkout root
- Nothing blocking
