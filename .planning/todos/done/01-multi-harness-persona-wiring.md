---
name: multi-harness-persona-wiring
captured: 2026-11-16
what: "Add a harness question to /skill:bootstrap (step 3b) that wires personas/ into the chosen harness's agent directory via a new scripts/wire-agents.sh"
severity: medium
context: "Bootstrap asks which harness (pi default), then copies/converts personas into that harness's agents dir; canonical source stays bootstrap/personas/"
files:
  - .agents/skills/shippEdd/bootstrap/SKILL.md:104
  - .agents/skills/shippEdd/bootstrap/scripts/wire-agents.sh
  - .agents/skills/shippEdd/bootstrap/personas/
---

## Problem

shippEdd's four personas (planner, researcher, executor, verifier) wire only into `.pi/agents/` — bootstrap step 3b hard-codes that target. On any other harness, cloning the skill folder does not adopt the workflow: the personas exist in `personas/` but nothing registers them where that harness looks.

## Solution

- New `bootstrap/scripts/wire-agents.sh <harness>` — copies personas into the target agents dir; converts per harness (below); skips with a note for hermes (no agents dir).
- Generalize bootstrap step 3b: always ask the harness question → wire → receipt line `wire   personas → <dir> (4 agents)`.
- Copy rules:
  - straight md copy (frontmatter already compatible): pi, cursor, claude, gemini, github copilot
  - opencode: copy + inject `mode: subagent` into frontmatter
  - codex: convert md → TOML per persona (frontmatter fields map 1:1; body becomes `developer_instructions`)
  - hermes: no file-based agents — custom subagents are profiles in `~/.hermes/config.yaml`; report and skip
  - amp and crush: excluded entirely (no file-defined subagents)

## Research

Subagent research (2026-11-16), verified against official docs:

- pi → project `.pi/agents/` · user `~/.pi/agent/agents/` — md + YAML frontmatter (`name`, `description`, `tools`, `model`)
- opencode → project `.opencode/agents/` (v2; singular `agent/` is legacy) · user `~/.config/opencode/agents/` — md + frontmatter; subagents need `mode: subagent`
- hermes → no agents dir — custom subagents run as profiles in `~/.hermes/config.yaml` (NousResearch/hermes-agent#9459 tracks profiles-for-delegation)
- cursor → project `.cursor/agents/` · user `~/.cursor/agents/` — md + frontmatter; also reads `.claude/agents/` and `.codex/agents/` natively
- codex → project `.codex/agents/` · user `~/.codex/agents/` — **TOML** (`name`, `description`, `model`, `developer_instructions` = body) — the format outlier
- claude → project `.claude/agents/` · user `~/.claude/agents/` — md + frontmatter, same shape as pi's
- gemini → project `.gemini/agents/` · user `~/.gemini/agents/` — md + frontmatter (`name`, `description` required)
- github copilot → repo `.github/agents/` · user `~/.copilot/agents/` — md + frontmatter
- Key facts: `.claude/agents/` is the de-facto compat format (claude + cursor + goose all read it); `.agents/skills/` — where shippEdd already lives — is the emerging shared skills convention (pi, crush, goose read it), so only the personas need per-harness wiring

## Decisions

- The harness question is asked every bootstrap run — no detection-first inference
- Option order fixed: pi, opencode, hermes, cursor, codex, claude, gemini, github copilot — plus a final custom option where the user names any directory; default location is a project-local dot-folder
- opencode wiring injects `mode: subagent`; codex wiring converts md → TOML
- amp and crush are excluded entirely
- Canonical personas stay in `bootstrap/personas/` — every target gets a copy
