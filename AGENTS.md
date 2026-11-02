# Agent Instructions

1. **Use relative directories** — Always use `~/` instead of absolute paths like `/home/user/...`. This ensures portability across different machines and environments.

2. **Screenshots and images** — When adding screenshots or other images, place them in:
   ```
   00-supporting-files/images/${fileBasenameNoExtension}/${datetime|yyyyMMddHHmmss}
   ```
   For example, a screenshot from `feature-demo.md` would go in:
   ```
   00-supporting-files/images/feature-demo/20260524153000.png
   ```

3. **Worktrees** — If a `02-worktrees` folder exists in the project root, create git worktrees by default when branching. Follow the conventions described in the `02-worktrees/README.md` for naming, structure, and usage.

4. Reusable agent assets live in `.agents/` — skills in `.agents/skills/`, and any scripts a skill needs should stay inside that skill's own folder (e.g. on the progressEdd branch `.agents/skills/log-sessions/scripts/`).
## Workflow

This repo runs **shippEdd** — a phase loop (discuss → research → plan → execute → verify → ship) driven by explicit skills.

- Workflow state lives in `.planning/`. `ROADMAP.md` is the source of truth for what's next; `STATE.md` frontmatter (`next_action`, `progress`) is the machine-read surface.
- Phases advance **only** via explicit skills: `/skill:define`, `/skill:implement`, `/skill:review`. Nothing auto-fires.
- Stray work → `/skill:todo`. Lost → `/skill:wayfind`.
