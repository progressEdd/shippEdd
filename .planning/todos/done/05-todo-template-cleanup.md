---
name: todo-template-cleanup
captured: 2026-11-17
what: "clean up .planning/todos/PENDING-TODO.md so it doesn't have to live in the planning folder"
severity: low
context: "the PENDING-TODO template is duplicated into the state dir by bootstrap and todo's capture step prefers it over the skill copy — drop the state copy and source solely from the skill's bootstrap/templates/todos/, mirroring the phase-template retarget 02-04 already did"
files:
  - .planning/todos/PENDING-TODO.md
---

## Problem

`.planning/todos/PENDING-TODO.md` is a runtime copy of the skill's template that bootstrap drops into the state dir. Phase 02 already moved every phase template into `.agents/skills/shippEdd/bootstrap/templates/` (02-04, commit b5b49e3) — but todo's capture step still sources the state-dir copy first, falling back to the skill's. A leftover dual-source convention: the planning folder should hold named documents and banked todos, not skill machinery.

## Solution

Delete the state-dir copy; retarget todo's mode-A template sourcing to `.agents/skills/shippEdd/bootstrap/templates/todos/PENDING-TODO.md` only (keep the "missing → recommend `/skill:bootstrap`" guard against the skill path); update bootstrap's skeleton step so it stops writing the file; sweep README/docs mentions.

## Research

- Both copies exist today: `.planning/todos/PENDING-TODO.md` and `.agents/skills/shippEdd/bootstrap/templates/todos/PENDING-TODO.md`
- todo/SKILL.md mode-A step 3: "source `<state>/todos/PENDING-TODO.md`, falling back to `.agents/skills/shippEdd/bootstrap/templates/todos/PENDING-TODO.md`" — state copy is primary, the leftover
- The phase templates went through this exact retarget in 02-04 (b5b49e3) — the pattern to follow, including the skill-path guard

## Decisions

- The PENDING-TODO template lives in the skill's `bootstrap/templates/todos/` only — never in the planning folder
