# Phase 01 multi-harness-persona-wiring Research

**Researched:** 2026-11-16 — imported from `todos/pending/01-multi-harness-persona-wiring.md` (subagent research, verified against official docs; not re-run by this phase)

## Question

Where does each supported harness discover custom subagents, and in what format?

## Findings

- **pi** → project `.pi/agents/` · user `~/.pi/agent/agents/` — md + YAML frontmatter (`name`, `description`, `tools`, `model`)
- **opencode** → project `.opencode/agents/` (v2; singular `agent/` is legacy) · user `~/.config/opencode/agents/` — md + frontmatter; subagents need `mode: subagent`
- **hermes** → no agents dir — custom subagents run as profiles in `~/.hermes/config.yaml` (NousResearch/hermes-agent#9459 tracks profiles-for-delegation)
- **cursor** → project `.cursor/agents/` · user `~/.cursor/agents/` — md + frontmatter; also reads `.claude/agents/` and `.codex/agents/` natively
- **codex** → project `.codex/agents/` · user `~/.codex/agents/` — **TOML** (`name`, `description`, `model`, `developer_instructions` = body) — the format outlier
- **claude** → project `.claude/agents/` · user `~/.claude/agents/` — md + frontmatter, same shape as pi's
- **gemini** → project `.gemini/agents/` · user `~/.gemini/agents/` — md + frontmatter (`name`, `description` required)
- **github copilot** → repo `.github/agents/` · user `~/.copilot/agents/` — md + frontmatter
- `.claude/agents/` is the de-facto compat format (claude + cursor + goose all read it)
- `.agents/skills/` — where shippEdd already lives — is the emerging shared skills convention (pi, crush, goose read it), so only the personas need per-harness wiring

## Recommendation

The planner treats the table above as the wiring matrix for `scripts/wire-agents.sh <harness>`: three wiring modes (straight copy, inject-then-copy, TOML convert) plus one skip-with-note (hermes) and the custom-directory escape hatch. Project-level dirs are the default targets (decision 4).

## Risks / unknowns

- Harness formats drift (e.g. opencode's v1→v2 dir rename); research verified against docs as of 2026-11-16.
- Hermes profiles are the only no-file path; the skip note should point at `~/.hermes/config.yaml` so users aren't stranded.
