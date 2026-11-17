# Phase 03 skill-polish-sweep Context

**Gathered:** 2026-11-17 — via `/skill:define` grilling (seeded from todos/pending 03, 04, 05)

## Goal

The three banked todos land: skills tell the user to clear context at phase-boundary handoffs, dispatch receipts print repo-relative paths, and the PENDING-TODO template lives only in the skill's `bootstrap/templates/todos/`.

## Decisions

| # | Question | Decision | Why |
|---|-----------------------------------|-------------------|------------------------|
| 1 | Todo file lifecycle — move to done/ now or at ship? | Move to `todos/done/` now, at promote time | Matches promote semantics (mode B); content already lives in the phase — done, moved this session |
| 2 | Which handoffs carry the clear-context instruction? | All of them — every skill handoff naming a next in-session command (review ship, define step 8, implement complete, wayfind, todo promote exit, bootstrap setup) + README note | "We want fresh context whenever we aren't using subagents" — safe because everything durable is on disk |
| 3 | Include a vendored-refresh plan in this phase? | Yes — final wave: squash-merge canonical master → .agents/skills/shippEdd/ with byte-parity check (the 02-06 flow) | The vendored copy is the one that runs; without the refresh the fixes never reach it |
| 4 | Phase scaffolding — eager template copies or lazy creation? | Lazy: define scaffolds only the phase folder + NN-CONTEXT.md; RESEARCH, PLAN, SUMMARY, and VERIFICATION artifacts are written on demand by their producing agents from the skill's bootstrap/templates/ | The sequential router (STATE.md next_action) + real-artifact presence already carry the state; placeholders are vestigial — matches GSD's lazy pattern and shippEdd's own todo capture (added post-approval, user-directed) |

## Constraints

- Edit the canonical skills in `02-worktrees/master/`; the vendored `.agents/skills/shippEdd/` copy picks changes up via the squash-merge refresh flow (from todos 03/04 research — settled there)
- Dispatch output uses repo-relative paths rather than absolute ones (todo 04 decision — settled)
- The PENDING-TODO template lives in the skill's `bootstrap/templates/todos/` only — never in the planning folder (todo 05 decision — settled)

## Open questions

- <Question carried into planning> (or "none — frontier is clear")

## Banked research (from the promoted todos)

**Todo 03 — clear-context-after-phase** (`todos/done/03-clear-context-after-phase.md`):
- A fresh `/skill:define` session resumes cleanly mid-phase — nothing depends on session memory
- Implement's executors run detached; STATE.md frontmatter (`next_action`, `progress`) is the machine-read router surface
- Canonical skill source: `02-worktrees/master/` (review/, implement/, define/, README.md); vendored copy differs by interim deltas only

**Todo 04 — relative-dispatch-paths** (`todos/done/04-relative-dispatch-paths.md`):
- Receipt line `printf 'dispatched %s (PID %s) → %s\n' "$id" "$pid" "$runs/$id.log"` with `runs="$root/$(...)/runs"` and `$root` from `git rev-parse --show-toplevel` (absolute) — shared by review, define, implement/dispatch.sh, and wayfind dispatchers; vendored and canonical copies identical
- `scripts/state-dir.sh` already prints repo-relative (`.planning`) — the convention exists

**Todo 05 — todo-template-cleanup** (`todos/done/05-todo-template-cleanup.md`):
- Both copies exist today: `.planning/todos/PENDING-TODO.md` and `.agents/skills/shippEdd/bootstrap/templates/todos/PENDING-TODO.md`
- todo/SKILL.md mode-A step 3 sources the state copy first, falls back to the skill's — the leftover dual-source
- Phase templates went through this exact retarget in 02-04 (commit b5b49e3) — the pattern to follow, including the skill-path guard
