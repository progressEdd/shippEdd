## What it does

`/skill:bootstrap` is the once-per-repo onboarding wizard for shippEdd. It detects what it can from the repo (git state, existing planning dirs, `gh` availability, greenfield vs brownfield), walks you through the few decisions it can't make for you — which agent harness you run (pi, opencode, hermes, cursor, codex, claude, gemini, github copilot, or a custom directory), where workflow state lives, which toggles and model tiers, git policy, the opt-in GitHub mirror (phases as parent issues + decision/plan sub-issues, PRs that close them — see the Configuration reference below) — the run-placement question (worktrees vs branch-in-checkout, with worktree creation at a path you name) and the merge-back disposition (PR by default) — then, after showing you the complete write list and getting a yes, creates the planning skeleton (`ROADMAP.md`, `STATE.md`, `REQUIREMENTS.md`, `config.json`, phase templates, todo/probe/run folders), wires the four subagent personas into that harness's agent directory via `scripts/wire-agents.sh` (straight md copy; `mode: subagent` injection for opencode; TOML conversion for codex; report-and-skip for hermes), appends a `## Workflow` block to `AGENTS.md`, and points you at `/skill:define`.

## When to reach for it

- Starting shippEdd in any repo, greenfield or brownfield.
- Adopting an existing planning state dir (`.planning/` or a GSD-style `.gsd/`) — the wizard detects markers and offers to adopt or rename.
- Something feels off after cloning a repo that uses shippEdd — rerun it: it verifies the skeleton and repairs gaps without touching your content.

## Prerequisites

- A git repo. Without one the wizard still runs, but the git/GitHub steps are skipped.
- The `gh` CLI, authenticated — only for the opt-in GitHub mirror. The mirror question appears either way (it defaults to local markdown and links GitHub's setup guide when gh is absent).

Nothing else: no packages, no build step. Markdown plus one bash script.

## Common questions

**Can I move the state dir later?**
Yes — edit `state_dir` in `.pi/planning.json` (or export `PLANNING_DIR` for a session) and move the folder. Everything resolves through `.agents/skills/shippEdd/scripts/state-dir.sh`; the toggles in `config.json` travel with the state dir.

**Can I change run placement or disposition later?**
Yes — edit `<state>/config.json`: `runs.mode` (`"worktrees"` | `"branch"`; absent = auto-detect: worktrees when `git worktree list` finds a linked worktree, else branch), `runs.dir` (the runs home — markers, logs, prompts, worktrees; absent = `${TMPDIR:-/tmp}/shippEdd`; repo-relative or absolute), `runs.absolute_paths` (`true` makes receipts print absolute paths), and `disposition` (`"pr"` | `"auto-merge"`; absent = pr — merge-back pushes and opens a PR, falling back to a receipt when gh or a remote is absent). The archive cadence is `archive_cadence` (default 5) — review offers the history prune at every multiple of it. Rerunning `/skill:bootstrap` re-asks placement as a single-setting change.

**Can I change the GitHub mirror later?**
Yes: edit `github.*` in `<state>/config.json` (or rerun `/skill:bootstrap` and pick the mirror setting). Every key is in the Configuration reference above.

**Why is there no `.pi/planning.json` after setup?**
Absent = default. The file only exists when you chose something non-default (a custom state dir or model tiers). No choices made, no file written.

**Does bootstrap work outside pi?**
Yes — step 3b asks which harness you run: pi, opencode, hermes, cursor, codex, claude, gemini, github copilot, or a custom directory. `scripts/wire-agents.sh` wires the personas in that harness's native format (straight copy, injected `mode: subagent`, or TOML), with repair semantics throughout — a missing agents dir is created, identical files are skipped, a modified one is never silently overwritten. Hermes has no agents dir, so bootstrap reports and skips, pointing at `~/.hermes/config.yaml` profiles.

**Will rerunning break my planning files?**
No. A rerun detects existing state, reports what's missing, and offers to create only the gaps. Existing files are never overwritten.

## Configuration reference

One law covers every key: **absent = its documented default** (JSON can't carry comments, so the law lives here). Two exceptions are called out below. Written by `/skill:bootstrap`, editable by hand any time — rerunning bootstrap re-asks any single setting.

**`<state>/config.json`** (the workflow config):

| Key | Default when absent | Meaning |
|---|---|---|
| `workflow.research` | `true` (enabled) | background research during `/skill:define` |
| `workflow.ui_phase` | `false` — **always written explicitly at setup** (exception #1) | UI-spec grilling round per phase |
| `workflow.ui_safety_gate` | `true` (enabled) | confirmation gate before UI changes |
| `runs.mode` | auto-detect: `worktrees` iff `git worktree list` reports a linked worktree, else `branch` | where executor work contexts live |
| `runs.dir` | `${TMPDIR:-/tmp}/shippEdd` | runs home — markers, logs, prompts, run worktrees (repo-relative or absolute) |
| `runs.absolute_paths` | `false` (repo-relative receipts) | print absolute paths in receipts/`--status` |
| `disposition` | `pr` | how merge-back lands work: `pr` (push + `gh pr create`, receipt fallback) or `auto-merge` (local merge) |
| `archive_cadence` | `5` | review's ship step offers the RELEASES.md history prune whenever the shipped-phase count hits a multiple of this — ROADMAP clears to live content, superseded REQUIREMENTS versions ride under the release entry, `phases/` folders are never pruned |
| `github.mirror` | `false` (off) — **opt-in: absent means OFF** (exception #2; the mirror is documentation on top of local markdown, never a source of truth) | the GitHub issues mirror |
| `github.host` | `github.com` | GitHub host (`*.ghe.com` subdomains use `GH_TOKEN`; a GHES host uses `GH_ENTERPRISE_TOKEN`) |
| `github.account` | the active account in gh's store | which stored gh account the mirror acts as (resolved via `gh auth token --user <account>`; global gh state is never switched) |
| `github.repo` | none — **required when `mirror` is on** | `OWNER/REPO` binding; every mirror call passes `-R` explicitly and never infers from git remotes |
| `github.labels` | `["shippedd"]` | issue labels (first entry is the default; created list-then-never-`--force`) |
| `github.token_env` | none | headless/CI escape hatch: names an env var holding the token — a NAME, never a secret value. No secret ever lives in the repo |

The old v1 key `github.mirror_issues` (a shipped-audit issue) is superseded by `github.mirror` — review's ship step now posts the verification verdict on the phase's parent issue and closes the mirror tree.

**`.pi/planning.json`** (harness-level, repo root): `state_dir` (only when ≠ `.planning`) and `models.<role>` overrides (only changed roles). Absent file = all defaults.

**GitHub account binding, end to end:** bootstrap writes `host` + `account` + `repo`; the mirror helper (`scripts/gh-mirror.sh`) chains `token_env` (if its env var is set) → `gh auth token --user <account>` → gh's stored active credentials, exports `GH_TOKEN` (or `GH_ENTERPRISE_TOKEN` on GHES hosts) per call, and targets `-R <github.repo>` on every repo-scoped call. Git push transport is untouched — per-directory SSH keys via git's `includeIf`/`core.sshCommand` are orthogonal and keep working.

## It's working if

- Running `.agents/skills/shippEdd/scripts/state-dir.sh` prints exactly one line — the state dir (`$PLANNING_DIR` → `.pi/planning.json` → `.planning`).
- The state dir contains `ROADMAP.md`, `STATE.md`, `REQUIREMENTS.md`, `config.json`, `README.md`, `todos/`, and `codebase/` (4 stubs) — phase templates live in the skill's `bootstrap/templates/`, never in the state dir.
- `AGENTS.md` gained a `## Workflow` block naming the state dir and the "phases advance only via explicit skills" rule — with all prior content intact.
- `.pi/planning.json` exists only if a non-default choice was made.
- The state dir's `config.json` carries only non-default keys — every absent key has a documented default (`runs.mode`, `runs.dir`, `runs.absolute_paths`, `disposition`).
- `scripts/wire-agents.sh <harness> --dry-run` prints the target dir, a per-persona action, and any conversion — without writing anything; a real run lands all four personas in that harness's project agent dir.
- Rerunning `/skill:bootstrap` offers verify/repair and writes nothing you already wrote.

## Where it fits

Role: run-once setup — the front door of shippEdd. It creates the state every other skill reads; nothing else creates it. Neighbours: `/skill:define` is the immediate next step (bootstrap ends by naming it), and `/skill:wayfind` is the compass if you come back to a repo later and feel lost.
