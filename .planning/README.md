# Workflow state skeleton

Templates for the shippEdd workflow state dir. The `bootstrap` skill copies this folder's files into the state dir (`<placeholders>` are filled by the wizard or by the first skill that uses the file); existing files are never overwritten — repair only.

- `ROADMAP.md` — phase checkbox list and the "Next up" pointer; the source of truth for what's next. Only `/skill:review` (ship) ticks boxes.
- `STATE.md` — frontmatter `next_action` / `progress` (the machine-read surface) plus a one-glance status body.
- `REQUIREMENTS.md` — REQ-ID table mapping every requirement to a phase.
- `config.json` — workflow toggles, written explicitly as chosen at setup.
- `NN-CONTEXT.md` — decisions captured by `/skill:define` grilling for a phase.
- `NN-RESEARCH.md` — background researcher output for a phase.
- `NN-0N-PLAN.md` — executable-plan template; the planner instantiates it once per plan: `wave` / `depends_on` / `target` frontmatter + task blocks (`<files>` / `<action>` / `<verify>` / `<acceptance_criteria>`).
- `NN-0N-SUMMARY.md` — execution-record template; each executor instantiates it at write time: `status` / `duration` / `key-files` / `requirements-completed` / `key-decisions` / `deviations` frontmatter + body.
- `VERIFICATION.md` — requirement coverage (REQ-IDs) + decision coverage + gaps found.
- `todos/pending/` — parked stray work from `/skill:todo`; promoted todos graduate to `todos/done/`. The capture-note template lives in the skill's `bootstrap/templates/todos/`, never in the state dir.
- `codebase/` — four stub probes (stack, architecture, conventions, testing) the researcher fills in brownfield repos.

**Config convention — absent = enabled:** JSON has no comments, so the rule lives here: any key missing from `config.json` (or the entire file) means the feature is **enabled**. `ui_phase` defaults to *off* at setup, so it is always written explicitly. Toggles only ever disable.
