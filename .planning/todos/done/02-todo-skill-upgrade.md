---
name: todo-skill-upgrade
captured: 2026-11-16
what: "Rework /skill:todo — new capture format (frontmatter + Problem/Solution/Research/Decisions) and a standing phase-plan offer that hands off to /skill:define"
severity: medium
context: "Format modeled on NeuroNarrate's done todos; implemented the same session it was captured, so it goes straight to done/"
files:
  - 02-worktrees/master/todo/SKILL.md
  - 02-worktrees/master/todo/README.md
  - 02-worktrees/master/bootstrap/templates/todos/PENDING-TODO.md
  - .planning/todos/PENDING-TODO.md
---

## Problem

The old PENDING-TODO format (H1 + bullet list) couldn't hold research already performed in the conversation — findings survived only in scrollback and were re-derived (or lost) later. And capture ended with a once-per-repo hint; there was no direct path from a freshly banked todo into planning.

## Solution

- New template: YAML frontmatter (`name`, `captured`, `what`, `severity`, `context`, plus a `files` list **last** — touched paths with optional `:line`/`:start-end` suffixes, `files: none` when unnamed) + four fixed body sections — **Problem / Solution / Research / Decisions** — filled only from what the conversation established; absent sections keep their placeholder (`not stated` / `none`)
- Mode A step 5: standing **phase-plan offer** after the receipt line — *no* → stop clean; *yes* → promote that single todo (mode B steps 3–5, skipping its listing/question) then execute `/skill:define` (rule 5's one carve-out)
- Mode B: third entry path (the handoff), todos carrying Research preserve it as `## Banked research` in the phase CONTEXT; listing reads frontmatter fields
- Shipped: `todo/SKILL.md` + bootstrap template on the master worktree; live stash `.planning/todos/PENDING-TODO.md`; todo 01 converted to the new format

## Research

- Format reference: `NeuroNarrate/.planning/todos/done/2026-05-22-add-multi-backend-llm-support-with-backend-selection.md` (frontmatter: created/title/area/files, body: Problem/Solution) — extended with Research + Decisions, keeping shippEdd's field names
- Ground-rule tension resolved: the phase-plan offer fires only after the todo is safely on disk, so it can't block intake (rule 1); rule 5 gains one explicit exception (a yes to the offer)
- Compatible consumers verified: mode B promote reads `what`/`severity`/`files` from frontmatter; define receives Research via CONTEXT's Banked research section

## Decisions

- Keep the existing field names (name/captured/what/severity/context) — moved into frontmatter, not renamed; `where` folds into the `files` list, placed last (NeuroNarrate convention)
- Body sections in fixed order: Problem, Solution, Research, Decisions
- Capture never invents content — honest placeholders over fabrication
- Phase-plan offer fires on every capture, replacing the once-per-repo first-capture hint
- No new scripts — the format lives in the template, the logic in SKILL.md prose
