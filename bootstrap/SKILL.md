---
name: bootstrap
description: One-time setup wizard for shippEdd, the phase-loop workflow (plan → execute → verify → ship) — detects the repo, chooses the workflow state dir, writes the planning skeleton, asks which agent harness you run (pi, opencode, hermes, cursor, codex, claude, gemini, github copilot, or a custom directory) and wires the subagent personas into that harness's agent directory via scripts/wire-agents.sh, configures toggles and model tiers, and wires AGENTS.md. Run /skill:bootstrap once per repository.
disable-model-invocation: true
---

# shippEdd bootstrap — once per repo, idempotent

You are running an interactive wizard. You read the repo, ask the user only what cannot be detected, then — after one explicit confirmation — write the workflow skeleton. It also settles run placement (worktrees vs branch-in-checkout) and the merge-back disposition. You are the only skill that creates the state dir; every other skill reads it.

All paths below are relative to this skill's folder (`templates/`, `personas/`, `scripts/wire-agents.sh`); the suite's shared scripts — `state-dir.sh`, `runs-dir.sh`, `dispatch.sh` — live at `.agents/skills/shippEdd/scripts/` (repo-relative).

## Ground rules

1. **Detect, never ask** — anything readable from the repo is a fact. Only genuinely undetectable preferences become questions. (One exception: the harness question in step 3b is asked every run — wired-dir evidence may set its recommendation, never replace it.)
2. **One question at a time**, grilling-style but short. Every question uses exactly this format:

   ```
   ❓ <question>
     ➡️ 1. <recommended answer>
       2. <option>
       3. <option>
   ```

   The ➡️ line is your recommendation; the user may answer by number or free text.
3. **Zero side effects before the confirmation gate** — everything above the gate is reading and asking. No file is created, modified, or committed until the user approves the complete write list (see *Confirmation gate*).
4. **Repair, never overwrite** — existing files are read and left alone. Templates fill gaps only; `<placeholders>` inside an existing file belong to its author.
5. **Absent = default** — write config only for non-default choices (see *Persistence rules*).
6. **Recommend and stop** — the wizard ends by naming the next command (`/skill:define`). Never run it yourself.

## Step 0 — resolve the state dir

Run `.agents/skills/shippEdd/scripts/state-dir.sh`. It prints exactly one line: the state dir path relative to the repo root (`$PLANNING_DIR` env → `.pi/planning.json` `state_dir` → `.planning`). That is the *current* resolution; step 2 below may decide to change what gets persisted.

## Step 1 — DETECT (facts, not questions)

Gather all of this quietly before asking anything:

- **Repo root**: `git rev-parse --show-toplevel` (if this fails, treat as non-git and skip git/github steps later)
- **Tracked files**: `git ls-files | wc -l` and a sample — enough to judge greenfield (empty/skeleton repo) vs brownfield (real code tracked)
- **Existing workflow state**: dirs containing both `STATE.md` and `ROADMAP.md` — probe `.planning/` and `.gsd/` directly, plus `git ls-files | grep -E '(STATE|ROADMAP)\.md$'` for any git-tracked candidates
- **`.pi/planning.json`**: exists? what `state_dir` / `models` keys does it carry?
- **Wired agent dirs**: for each of `.pi/agents/`, `.opencode/agents/`, `.cursor/agents/`, `.codex/agents/`, `.claude/agents/`, `.gemini/agents/`, `.github/agents/` — note which of the four personas (`planner` / `researcher` / `executor` / `verifier`, as `.md` or `.toml`) already exist there. This evidence only sets the ➡️ recommendation on step 3b's harness question — the question itself is asked every run. (No `personas/` folder in this skill = dev install — see step 3b.)
- **`$PLANNING_DIR`**: set in the environment?
- **GitHub**: `command -v gh` and `gh auth status`; `git remote` (only if git detected)
- **Worktree topology**: `git worktree list --porcelain` — count the linked worktrees (entries after the first), and note the common folder of the first linked one (its dirname — e.g. `02-worktrees/`). Zero linked worktrees = worktree-less repo.
- **`AGENTS.md`**: exists? already contains a `## Workflow` heading?

Report a two-line summary of what you found (repo type, existing state, gh availability), then move to step 2. If this is a **rerun** (state markers already exist), jump to *Rerun behavior* instead of the fresh wizard.

## Step 2 — STATE DIR

Discovery order — stop at the first case that applies:

**a. `.pi/planning.json` exists (with a `state_dir`):**
```
❓ Keep the existing state dir `<dir>` (from .pi/planning.json)?
  ➡️ 1. keep it
    2. change it → treat as case d
```

**b. `$PLANNING_DIR` is set (and a says nothing):** the env var wins for this session but is ephemeral —
```
❓ `$PLANNING_DIR=<dir>` is session-only. Persist it to .pi/planning.json so it sticks?
  ➡️ 1. yes — write it to .pi/planning.json
    2. no — keep it env-only (you must export it every session)
```

**c. State markers found (STATE.md + ROADMAP.md together) in `.planning/`, `.gsd/`, or a git-tracked dir:**
```
❓ Adopt `<dir>` as the shippEdd state dir?
  ➡️ 1. adopt, keep the name `<dir>` (persist to .pi/planning.json)
    2. adopt, but rename to `.planning` (git mv — keeps history)
    3. ignore it, choose a fresh location → case d
```
Adopting GSD-style state is safe — shippEdd templates are near-verbatim descendants; only fill gaps.

**d. Fresh (nothing found):**
```
❓ Where should workflow state live?
  ➡️ 1. `.planning` (default)
    2. custom path
```

Persist `state_dir` to `.pi/planning.json` **only** if the resolved dir ≠ `.planning`.

## Step 3 — SKELETON (planned now, written after confirmation)

The skeleton copies from `templates/` into the state dir:

| From `templates/` | To state dir | Notes |
|---|---|---|
| `ROADMAP.md` | `<state>/ROADMAP.md` | fill `<project-name>` if detectable |
| `STATE.md` | `<state>/STATE.md` | — |
| `REQUIREMENTS.md` | `<state>/REQUIREMENTS.md` | — |
| `config.json` | `<state>/config.json` | toggle values exactly as chosen in step 4 |
| `README.md` | `<state>/README.md` | documents every file + the absent=enabled convention |
| `codebase/stack.md` … `testing.md` | `<state>/codebase/` | four stub probes |

Repair semantics: a destination file that already exists is **left untouched**; only missing files are created. The skeleton also creates empty `<state>/todos/pending/` — the capture inbox `/skill:todo` fills.

Phase templates (`NN-CONTEXT.md`, `NN-RESEARCH.md`, `NN-0N-PLAN.md`, `NN-0N-SUMMARY.md`, `VERIFICATION.md`) and the todo note template (`todos/PENDING-TODO.md`) are never scaffolded into the state dir — they live only in this skill's `templates/` folder (repo-relative in the vendored install). Phase scaffolding is lazy: `define` and `/skill:todo` copy just `NN-CONTEXT.md` when a phase is minted, and every other artifact is created on demand by its producing agent — `NN-RESEARCH.md` by the researcher, `NN-0N-PLAN.md` by the planner, `NN-0N-SUMMARY.md` by each executor, `VERIFICATION.md` by the verifier — straight from that folder when it is written.

## Step 3b — PERSONAS (repo wiring, written after confirmation)

The four subagent personas — planner, researcher, executor, verifier — power every skill that dispatches subagents. Skills live in the harness-shared `.agents/skills/` convention, so the personas travel inside this skill (`personas/*.md` — the canonical copy; wiring only ever copies/converts outward) and bootstrap wires them into your harness's own agent directory. First, ask which harness — every run, never inferred from detection (step 1's wired-dir evidence only sets the recommendation):

```
❓ Which agent harness is this repo wired for?
  ➡️ 1. pi             (.pi/agents/)
    2. opencode       (.opencode/agents/)
    3. hermes         (no agents dir — profiles instead; report and skip)
    4. cursor         (.cursor/agents/)
    5. codex          (.codex/agents/, TOML)
    6. claude         (.claude/agents/)
    7. gemini         (.gemini/agents/)
    8. github copilot (.github/agents/)
    9. custom         (name any agent directory)
```

➡️ marks the harness whose dir showed wired personas in step 1; on a fresh repo it marks pi. Users may answer by number or free text (map free text to the closest option).

**Named harnesses (options 1–8):** `scripts/wire-agents.sh` does the wiring — pass the harness as one token (`pi`, `opencode`, `hermes`, `cursor`, `codex`, `claude`, `gemini`, `github-copilot`; option 8's "github copilot" becomes `github-copilot`). Run `scripts/wire-agents.sh <harness> --dry-run [--diff]` and read its output:

- It prints the target dir, one line per persona — `create` (missing, with its conversion: `md + mode: subagent` for opencode, `md → TOML` for codex), `skip` (identical), or `differs` (kept) — and the receipt `wire   personas → <dir> (4 agents)` (`— dir created in project directory` appended when the agents dir is absent).
- Add `--diff` when any persona shows `differs`: the script prints a unified diff (canonical-converted vs the installed file). Show each diff and ask replace-or-keep, one file at a time:
  ```
  ❓ `<target path>` differs from the canonical persona (diff above) — replace it?
    ➡️ 1. keep mine
      2. replace with the canonical persona
  ```
- **hermes** needs no follow-up: the script reports and skips — no writes, no further questions. Relay its note verbatim (it also lands in the gate): `skip    personas — hermes has no agents dir; subagents run as profiles in ~/.hermes/config.yaml`.
- After the gate approves, run `scripts/wire-agents.sh <harness>` for real, adding `--replace <persona>` for each differing persona the user chose to replace. The script creates the agents dir if absent, skips identical files (compared as converted output), and never touches an un-replaced file.

**Custom (option 9):** the script stays deterministic — the format inspection is yours (the LLM). Ask for the directory, then:

1. Read the named directory: list any existing agent-definition files and read one or two for format (plain md frontmatter? a `mode:` field? TOML? something else?).
2. If the directory is empty or new, check the harness's documentation for its subagent format.
3. Map the evidence to a mode and dry-run it, then continue with the named-harness flow above (diff / replace-or-keep, gate, real run):
   - plain md with frontmatter → `scripts/wire-agents.sh custom <dir> --mode copy --dry-run [--diff]`
   - md needing a subagent flag → `--mode inject`
   - TOML → `--mode toml`
   - no evidence at all → plain pi-format md copy is the fallback: `custom <dir> --dry-run` (no `--mode`)
4. Evidence shows a format none of copy/inject/toml can express (e.g. JSON definitions): convert the four personas yourself into a scratch dir mirroring the discovered format, then run `scripts/wire-agents.sh custom <dir> --mode copy --source <scratch-dir> --dry-run [--diff]` — the same repair semantics, applied to your converted files. Say in the gate that the conversion was hand-derived from examples/docs.

If this skill folder has no `personas/` (a hand-rolled install), report "personas already wired" and skip.

## Step 4 — TOGGLES

One question, recommended combo first:
```
❓ Workflow toggles — go with the recommended set?
  ➡️ 1. recommended: research ON · UI phase OFF · UI safety gate ON
    2. customize (I'll then ask one toggle at a time)
```
Chosen values are written explicitly to `<state>/config.json` → `workflow`. (Convention: any key *absent* from config means **enabled** — but `ui_phase` defaults to off at setup, so it is always written explicitly.)

## Step 4b — RUN PLACEMENT & DISPOSITION

Facts first (step 1 gathered them): how many linked worktrees, and their common folder. Explain the trade in one breath before asking: **worktrees** give each run its own working tree — the main checkout stays untouched, runs survive reboots when placed in the repo's worktrees folder, and parallel branches stay checked out side by side; **branch mode** needs nothing extra but the main checkout switches onto the run's branch while work executes; the **tmp default** is transient only — markers and ledgers under `$TMPDIR`, wiped on reboot, worktree-less repos fall back to branch mode for work contexts.

```
❓ Run placement — where should executor work contexts and transient run state (markers, logs, prompts) live?
  ➡️ 1. worktrees under <detected folder — or "a worktree we create first" when none is detected>
    2. worktrees — create a worktree at a path I name (absolute or relative input both accepted)
    3. branch in the main checkout — executors work on a new branch in the checkout; it switches branches while runs execute (invasiveness accepted)
    4. defaults — transient `$TMPDIR` home; work contexts auto-detect (worktrees when the repo has them, branch otherwise)
```

- ➡️ marks option 1 when linked worktrees exist, option 3 when the repo is worktree-less and the user seems minimal, otherwise option 1.
- **Option 1, no worktrees detected yet** (or option 2): ask for the path — absolute or relative to the repo root, free text. Create the worktree (it lands in the confirmation gate):

  ```bash
  git worktree add <path> -b <basename-of-path>
  ```

  (forked from HEAD; branch named after the path's basename). Then treat it like option 1 with `<path>`'s dirname as the folder.
- **Option 1, worktrees detected**: the folder is the detected common folder; nothing is created.
- **Option 3**: branch mode.
- **Option 4**: the documented defaults — write nothing (absent keys are the defaults).

Persist per the persistence rules — non-default choices only, merged into `<state>/config.json`: options 1/2 → `{"runs": {"mode": "worktrees", "dir": "<the folder, repo-relative unless the user gave absolute>"}}`; option 3 → `{"runs": {"mode": "branch"}}`; option 4 → nothing. When `runs.dir` points inside the repo and is not already gitignored, append it to `.gitignore` (gate line: `append .gitignore — <dir> (runs home)`).

Then the landing question:

```
❓ Disposition at merge-back — how should finished work land?
  ➡️ 1. pull request (default) — merge-back pushes the phase's branch and opens a PR; without gh or a remote it leaves the branch with a receipt naming the options
    2. auto-merge — merge locally into the target branch (the pre-phase-05 behavior)
```

Option 1 writes nothing (absent = pr); option 2 writes `"disposition": "auto-merge"`.

## Step 5 — TIERS

```
❓ Model tiers for subagents — use defaults?
  ➡️ 1. defaults: researcher = cheap/fast model · planner + verifier = strongest · executor = default model
    2. customize (name a model id per role, one at a time)
```
Defaults write nothing (absent = default). Custom tiers persist to `.pi/planning.json` → `models: { researcher, planner, verifier, executor }` — write **only the roles the user actually changed**.

## Step 6 — GIT

```
❓ Commit the state dir to git?
  ➡️ 1. commit (the paper trail is the point — plans, summaries, verification age with the code)
    2. ignore it (append the state dir to .gitignore)
```

## Step 7 — GITHUB MIRROR (asked every run; facts from step 1)

Default is local markdown — the mirror is opt-in documentation on top of it, never a write path back. Step 1 already gathered: `command -v gh`, `gh auth status` (all accounts + which is active), and the git remote. "Primary" below means the preferred documentation surface for the human, nothing more.

❓ Document phases to GitHub as issues while the workflow runs? (shippEdd's GitHub mirror)
  ➡️ 1. local markdown only (default — can enable later by editing config)
    2. mirror — define captures decisions/plans as a parent issue + sub-issues, executors post task progress, merge-back PRs close their plan issues, ship closes the phase

- **gh absent or not authenticated + the user picks 2:** relay GitHub's official setup guide — `https://docs.github.com/en/github-cli/github-cli/quickstart` (install + `gh auth login`). Either they authenticate now (re-check `gh auth status`) or you write the config anyway — the mirror stays dormant until gh works; every mirror path is never-block, so nothing else changes.
- **When enabling, gather from detection (ask only what detection can't settle):**
  - `host` — default `github.com`; ask only for a GitHub Enterprise Server host.
  - `account` — the active account from `gh auth status`; ask only when multiple accounts are stored on the host.
  - `repo` — `OWNER/REPO`: detect via `gh repo view --json nameWithOwner -q .nameWithOwner` (or parse `git remote`), confirm with the user when detection is ambiguous or fails. The helper passes `-R` explicitly on every call and NEVER infers the repo from remotes at runtime — this key is the binding.
  - optional `labels` (default `["shippedd"]` — ask only if the user points at an existing label scheme) and optional `token_env` (a name like `SHIPPEDD_GH_TOKEN` for headless/CI; it names an env var, NEVER a secret value — no secret ever lands in the repo or config).
- Write on enable (merged into `<state>/config.json`): `{"github": {"mirror": true, "host": "<host>", "account": "<account>", "repo": "<OWNER/REPO>"}}` — plus `labels`/`token_env` only when customized. Absent `github` section or absent `mirror` key = off.

## Step 8 — HANDOFF

- **Brownfield**: offer the 4 codebase probes now:
  ```
  ❓ Run the 4 codebase probes (stack / architecture / conventions / testing) now?
    ➡️ 1. yes — dispatch 4 parallel researcher subagents to fill <state>/codebase/
      2. later — stubs stay; fill them via /skill:wayfind anytime
  ```
  If the researcher persona is still not usable after step 3b (the user kept a differing existing file), say so and offer to fill the stubs inline instead.
- **Either way**, end with (and do not run it yourself):

  > Setup complete. Next: `/skill:define` to grill out your first phase — in a fresh session (clear this context first; everything durable is on disk).

## Confirmation gate

Before any write, show the complete list:

```
I will create/modify:
  STATE DIR  <dir>
    create   <each new file path>
    repair   <each missing template in an existing skeleton — existing files untouched>
  PERSONAS
    wire     personas → <dir> (4 agents)   — append "— dir created in project directory" when the agents dir is absent
      create   <path>   (each missing persona, with its conversion — or: none, all wired)
      replace  <path>   (each differing persona the user chose to replace)
      keep     <path>   (each differing persona the user kept)
    skip     personas — hermes has no agents dir; subagents run as profiles in ~/.hermes/config.yaml   (hermes only — instead of the wire line)
  CONFIG
    write    .pi/planning.json   (only the non-default keys chosen) — or: none, all defaults
    write    <state>/config.json (toggles [+ github mirror: host/account/repo] [+ runs placement] [+ disposition])
    append   AGENTS.md — "## Workflow" block   (or: merge — block already exists)
  RUNS   (only when applicable — placement created a worktree / gitignored a dir)
    create   worktree <path> (branch <basename>)   — the runs worktrees folder
    append   .gitignore — <dir> (runs home)
  GIT
    commit   "chore: shippEdd setup"   |   append .gitignore entry

❓ Proceed?
  ➡️ 1. yes — write it all
    2. adjust something first
```

Then execute in that order, and finally show the handoff line from step 8.

## The AGENTS.md Workflow block

Append this block to the repo's `AGENTS.md` (create the file if absent). If a `## Workflow` section already exists, merge: update only the shippEdd bullets, keep all unrelated content.

```markdown
## Workflow

This repo runs **shippEdd** — a phase loop (discuss → research → plan → execute → verify → ship) driven by explicit skills.

- Workflow state lives in `<state-dir>/`. `ROADMAP.md` is the source of truth for what's next; `STATE.md` frontmatter (`next_action`, `progress`) is the machine-read surface.
- Phases advance **only** via explicit skills: `/skill:define`, `/skill:implement`, `/skill:review`. Nothing auto-fires.
- Stray work → `/skill:todo`. Lost → `/skill:wayfind`.
```

(Resolve `<state-dir>` to the chosen dir before writing.)

## Persistence rules

| Choice | Written to | When |
|---|---|---|
| state dir ≠ `.planning` | `.pi/planning.json` → `state_dir` | only non-default |
| model tier overrides | `.pi/planning.json` → `models.<role>` | only changed roles |
| workflow toggles | `<state>/config.json` → `workflow` | always (explicit values) |
| github mirror | `<state>/config.json` → `github.*` (mirror/host/account/repo [+ labels/token_env]) | only if chosen |
| runs placement (mode/dir) | `<state>/config.json` → `runs` | only non-default choices (worktrees+folder or branch) |
| disposition | `<state>/config.json` → `disposition` | only "auto-merge"; pr is the absent default |
| everything default | **no `.pi/planning.json` at all** | absent = default |

If `.pi/planning.json` already exists, merge: update only the keys decided in this wizard, never remove or rewrite unknown keys.

## Rerun behavior (idempotent)

If state markers already exist when you reach step 1, skip the fresh wizard:

1. Report what was found: state dir, the harness question from step 3b (asked again every run — recommend the harness whose dir shows wired personas), a persona check via `scripts/wire-agents.sh <harness> --dry-run` (missing or differing personas), and a skeleton check listing any missing template files.
2. ```
   ❓ Repair the skeleton and wire missing personas?
     ➡️ 1. yes — create only the missing files (a differing persona gets a diff and a replace-or-keep choice first)
       2. no — leave everything as is
   ```
3. Show the current config (state dir, tiers, toggles, runs placement, disposition, GitHub mirror) and offer to change any single setting — placement changes re-ask the step 4b questions — GitHub mirror changes re-ask the step 7 question.
4. Never overwrite user content. Only re-run the full wizard if the user explicitly asks to "start over".
