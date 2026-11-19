# Workflow state skeleton

Templates for the shippEdd workflow state dir. The `bootstrap` skill copies this folder's files into the state dir (`<placeholders>` are filled by the wizard or by the first skill that uses the file); existing files are never overwritten — repair only.

- `ROADMAP.md` — phase checkbox list and the "Next up" pointer; the source of truth for what's next. Only `/skill:review` (ship) ticks boxes.
- `STATE.md` — frontmatter `next_action` / `progress` (the machine-read surface) plus a one-glance status body.
- `REQUIREMENTS.md` — REQ-ID table mapping every requirement to a phase.
- `config.json` — workflow toggles plus run placement and disposition, written as chosen at setup; every absent key means its documented default: `runs.mode` (`"worktrees"` | `"branch"`; absent → auto-detect: worktrees iff `git worktree list` reports a linked worktree, else branch), `runs.dir` (runs home for markers/logs/prompts and run worktrees; absent → `${TMPDIR:-/tmp}/shippEdd`), `runs.absolute_paths` (absent → false: repo-relative paths), `disposition` (`"pr"` | `"auto-merge"`; absent → pr), and `github.*` (the opt-in GitHub mirror: `mirror` absent = off, `host`/`account`/`repo` bind the target repo and gh account, `labels` defaults `["shippedd"]`, `token_env` names a headless token env var — never a secret value; full reference in the bootstrap skill's README).
- `NN-CONTEXT.md` — decisions captured by `/skill:define` grilling for a phase.
- `NN-RESEARCH.md` — background researcher output for a phase.
- `NN-0N-PLAN.md` — executable-plan template; the planner instantiates it once per plan: `wave` / `depends_on` / `target` frontmatter + task blocks (`<files>` / `<action>` / `<verify>` / `<acceptance_criteria>`).
- `NN-0N-SUMMARY.md` — execution-record template; each executor instantiates it at write time: `status` / `duration` / `key-files` / `requirements-completed` / `key-decisions` / `deviations` frontmatter + body.
- `VERIFICATION.md` — requirement coverage (REQ-IDs) + decision coverage + gaps found.
- `todos/pending/` — parked stray work from `/skill:todo`; promoted todos graduate to `todos/done/`. The capture-note template lives in the skill's `bootstrap/templates/todos/`, never in the state dir.
- `codebase/` — four stub probes (stack, architecture, conventions, testing) the researcher fills in brownfield repos.

**Config convention — absent = enabled:** JSON has no comments, so the rule lives here: any key missing from `config.json` (or the entire file) means the feature is **enabled**. `ui_phase` defaults to *off* at setup, so it is always written explicitly. Toggles only ever disable.
