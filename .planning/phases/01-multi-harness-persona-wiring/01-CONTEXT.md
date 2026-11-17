# Phase 01 multi-harness-persona-wiring Context

**Gathered:** 2026-11-16 — via `/skill:define` grilling (seeded from `todos/pending/01-multi-harness-persona-wiring.md`)
**Locked:** 2026-11-16 — confirmed, frontier clear

## Goal

Bootstrap works on eight harnesses, not just pi: a harness question in step 3b feeds a new `scripts/wire-agents.sh` that wires the four personas into the chosen harness's agent directory (with per-harness conversion where needed).

## Decisions

| # | Question | Decision | Why |
|---|-----------------------------------|-------------------|------------------------|
| 1 | Which harnesses are supported, and how does each get wired? | pi, opencode, hermes, cursor, codex, claude, gemini, github copilot. Straight md copy: pi, cursor, claude, gemini, github copilot. opencode: copy + inject `mode: subagent`. codex: convert md → TOML (frontmatter maps 1:1; body becomes `developer_instructions`). hermes: report and skip (no agents dir — subagents are profiles in `~/.hermes/config.yaml`). amp and crush excluded entirely. | Research-verified per-harness formats (see 01-RESEARCH.md); hermes has no file-based agents; amp/crush have no file-defined subagents. |
| 2 | Harness detection vs asking? | Always ask — no detection-first inference. | Decision recorded in todo; predictable over clever. |
| 3 | Option order for the harness question? | Fixed: pi, opencode, hermes, cursor, codex, claude, gemini, github copilot, then a final custom option (user names any directory). | Decision recorded in todo. |
| 4 | Project-level or user-level agent dirs? | Project-local dot-folder by default (e.g. `.opencode/agents/`), per the custom option too. | Decision recorded in todo; keeps wiring repo-visible and committed. |
| 5 | Where do canonical personas live? | `bootstrap/personas/` stays canonical — every target gets a copy. | Single source of truth; one folder-copy adopts the harness. |
| 6 | Receipt format for the confirmation gate? | `wire   personas → <dir> (4 agents)` | Decision recorded in todo. |
| 7 | What does wire-agents.sh do with the target dir and existing persona files? | Repair semantics: target agents dir is created if absent (receipt says so — "created in project directory"); missing files → copy in, identical → skip, different → diff surfaced to the confirmation gate for replace-or-keep; never silently overwrite. "Identical" compares converted output for opencode/codex. | Matches bootstrap's repo-wide repair semantics; dir creation makes first-run on any harness just work. |
| 8 | Verification bar? | `--dry-run` mode built into the script (prints target dir, per-persona action, conversion); plan tasks verify by running real wiring against throwaway temp dirs per harness mode. No test framework. | Proves every wiring mode (copy/inject/TOML/skip) cheaply; repo has no test infra. |
| 9 | Custom option: what lands in the user-named dir? | Copy the personas, then adapt to evidence: the skill checks the named directory for existing agent-definition examples to mimic, and checks the harness's documentation for its subagent format, before deciding conversion; plain pi-format md copy is the fallback when neither yields an answer. | Unknown harnesses get best-effort native format instead of a guaranteed-wrong one; the skill (LLM) does the inspecting/docs lookup, the script stays deterministic. |
| 10 | Which copy of the skills does this phase edit? | The canonical master worktree: `02-worktrees/master/` (branch `master`), e.g. `02-worktrees/master/bootstrap/scripts/wire-agents.sh`, `02-worktrees/master/bootstrap/SKILL.md`. | Master is the source of truth (progressEdd vendored it via squash-merge); the `.agents/skills/shippEdd/` copy in this checkout is refreshed later via the existing squash-merge flow, not by this phase's executors. |

## Constraints

- Canonical personas stay in `bootstrap/personas/`; wiring only ever copies/converts outward.
- amp and crush are excluded entirely — no wiring, no mention as options.
- Bootstrap repair semantics hold repo-wide: never silently overwrite existing files.
- `personas/*.md` frontmatter is already compatible with pi/claude/gemini/copilot/cursor — only opencode (inject) and codex (TOML) need conversion.
- Implementation target is the master worktree at `02-worktrees/master/` — never the vendored `.agents/skills/shippEdd/` copy in the progressEdd checkout.

## Open questions

- Carried into planning: step 1's persona diff detection is currently hard-coded to `.pi/agents/` and runs before the harness question lands in step 3b — the planner must reconcile the sequencing (e.g. harness question first, then diff against the chosen dir).
- Carried into planning: how the skill passes a decided custom format to the script (interface between the LLM-driven inspection and the deterministic wiring).
