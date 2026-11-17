# Phase execution-record-rework Research

**Researched:** 2026-11-17 — background run `02-research`

Four questions, answered in order from the repo itself. Canonical skill source = `02-worktrees/master/` (branch `master`); vendored copy = `.agents/skills/shippEdd/` (branch `progressEdd` checkout). Verified before writing: exactly four files differ between the trees — `implement/SKILL.md`, `implement/scripts/dispatch.sh`, `implement/scripts/replay-commits.sh` (all modified) and `implement/scripts/slice-tasks.sh` (deleted on disk). Those four deltas are **uncommitted working-tree changes** in the root checkout (`git status`: `M M M D` vs `progressEdd` HEAD `1dd1cfb`, mtime 2026-11-17 11:18) — these are the "interim vendored deltas (promptless dispatch, worktree-aware routing)" that EXEC-09 names. Every other file in both trees is byte-identical. The codebase maps (`.planning/codebase/*.md`) are stubs; everything below comes from direct inspection.

---

## Q1 — Retarget map: every `_templates` / `_archive` / `runs` reference

### Canonical side (`02-worktrees/master/`)

**bootstrap** (owns the skeleton that creates the dirs)

| File:line | What it does today | Must become |
|---|---|---|
| `bootstrap/SKILL.md:99` | Skeleton row: copies `templates/runs/.gitkeep` → `<state>/runs/.gitkeep` | **Delete row** — no runs dir is scaffolded; dispatch state is transient in `$TMPDIR`, needs no scaffold |
| `bootstrap/SKILL.md:100` | Skeleton row: copies 5 phase templates → `<state>/phases/_templates/` stash | **Delete row** — no `_templates` stash is written; the templates live only in the skill's own `bootstrap/templates/` (EXEC-10) |
| `bootstrap/README.md:35` | Documents state-dir contents incl. `runs/` and `phases/_templates/` (5 templates) | **Rewrite** — `runs/` and `_templates/` drop out of the inventory; note templates live in the skill |
| `bootstrap/templates/runs/.gitkeep` | The scaffold source for `<state>/runs/` | **Delete file** (empty dir `bootstrap/templates/runs/` goes with it) |
| `bootstrap/templates/README.md:16` | Bullet documenting `runs/` in the skeleton list | **Delete bullet** |
| `bootstrap/templates/README.md:13` | Documents `NN-YY-SUMMARY.md` frontmatter as `provides / key-files / key-decisions / actuals` | **Rewrite** to the EXEC-02 record keys: `status / duration / key-files{created,modified} / requirements-completed / key-decisions / deviations` |
| `bootstrap/templates/NN-YY-SUMMARY.md` | Template with the old frontmatter (`provides`/`actuals`) and a `## Task commits` section fed by the TSV flow | **Rework** — frontmatter becomes the EXEC-02 execution record; "Task commits" becomes executor-known commit hashes (executor now commits itself, EXEC-04) |
| `bootstrap/templates/NN-YY-PLAN.md:38–42` | Trailing comment: "Executors are fed one task block at a time (/skill:implement slices this file per task)" | **Rewrite** — one executor per plan walks the sections; and if plans gain a `target:` frontmatter key (see Q4 gap), this template's frontmatter block (lines 1–4) is where it is authored |
| `bootstrap/SKILL.md:233`, `README.md:13` | Verb "runs" — false positives | No change |

**define**

| File:line | What it does today | Must become |
|---|---|---|
| `define/SKILL.md:76` | Scaffold fallback chain, hop 1 = `<state>/phases/_templates/` (bootstrap's stash); hop 2 = `.agents/skills/shippEdd/bootstrap/templates/` | **Retarget** — drop the `_templates` hop; single source = the skill's `bootstrap/templates/` (repo-relative) |
| `define/SKILL.md:160` | Composes research prompt file at `<state>/runs/<id>.prompt.md` | Keep this phase (define not migrated — Decision 1); resolve per the runs-tension flag in Risks |
| `define/SKILL.md:180,187,191–194,258` | Completion-contract `mv` paths, dispatch line, marker gate (`.done`/live-`.running`/dead-`.running`), approval gate — all under `<state>/runs/` | Keep this phase (Decision 1); same tension |
| `define/scripts/dispatch.sh:19–59` | `runs="$root/$("$here/state-dir.sh")/runs"`; `mkdir -p`; `--status` scans `$runs/*.running|*.done|*.failed`; collision guard on existing markers; `--force` clears them; `nohup pi --print … < prompt > $runs/$id.log &`; PID → `$runs/$id.running` | Unchanged this phase; at define/review migration time becomes a wrapper over the shared dispatcher (Q3) |
| `define/README.md:32,35,45` | User docs for runs-dir status/stale-marker flows | Keep this phase; rewrite at migration |

**review**

| File:line | What it does today | Must become |
|---|---|---|
| `review/SKILL.md:50` | "If that phase already lives under `phases/_archive/`, it shipped" — archive check | **Retarget** — no archive exists; shipped-ness derives from `STATE.md` `progress: shipped` / ROADMAP tick, never a dir location |
| `review/SKILL.md:52` | Verifiability gate: each plan needs `<state>/runs/NN-YY.done` **carrying a `committed` line** (implement's completion signature) | **Retarget** — the signature becomes the artifact one: `NN-YY-SUMMARY.md` present with `status: complete` (EXEC-02/03); committed-ness cross-checked via git log for plan-id commits |
| `review/SKILL.md:64,66,79,85,90,92,97,100,107,112–113` | Verify run-id scan, prompt path, evidence list ("committed `<sha>` lines in runs/NN-*.done markers"), completion contract, dispatch, watch, stale/failed handling — all under `<state>/runs/` | Keep this phase (Decision 1), **except** line 79's evidence list: markers/TSVs no longer exist for implement plans — evidence becomes SUMMARY frontmatter + read-only `git log` |
| `review/SKILL.md:142` | Fix-plan template fallback: `<state>/phases/_templates/NN-YY-PLAN.md` (fallback skill templates) | **Retarget** — skill templates only |
| `review/SKILL.md:143–144` | Fix plans get frontmatter `wave` + `depends_on` only | If plans gain `target:` (Q4 gap), fix plans need it too |
| `review/SKILL.md:171` | Ship step 3: `mkdir -p <state>/phases/_archive && mv <phase> → _archive/` ("The `_` prefix marks it non-live, matching `_templates/`") | **Delete** — Decision 7: phases stay flat forever; no archive step exists |
| `review/SKILL.md:192` | Ship receipt line `archive <state>/phases/_archive/<NN>-<slug>` | **Delete line** (receipt loses the archive row) |
| `review/SKILL.md:26`, `review/README.md:29` | "dispatches **and replays** like any wave" / "implement's wave/**commit** machinery" | **Retarget wording** — replay is gone; fixes are dispatched and merged like any wave |
| `review/README.md:44` | Success check: "`phases/` holds only `_archive/` and `_templates/`" | **Rewrite** — `phases/` holds only phase folders |
| `review/README.md:32,48`, `review/scripts/dispatch.sh:19–59` | runs-dir flows, dispatcher copy | Keep this phase (Decision 1) |

**implement** (canonical tree — the rework lands here per EXEC-09; rows describe what the rework replaces)

| File:line | What it does today | Must become |
|---|---|---|
| `implement/SKILL.md:3,7,9` | "per task … then replays their recorded commit specs" title/description/intro | **Rewrite** — per-plan executor, own-worktree git, orchestrator-owned merge-back |
| `implement/SKILL.md:16` | "Markers are truth" — resume state = `<state>/runs/NN-YY.done` + `committed` line | **Rewrite** — plan state derived from artifacts (EXEC-02/03): SUMMARY present → executed |
| `implement/SKILL.md:50` | Plan finished iff `.done` + `committed` line | **Rewrite** — same artifact-derived rule |
| `implement/SKILL.md:55–56` | Live/dead PID read from runs markers | **Rewrite** — liveness from the `$TMPDIR` run dir (Q3/Q4) |
| `implement/SKILL.md:85` | Slicer writes `runs/<NN>-<YY>-T1..k.prompt.md` | **Delete** — slicer gone; no prompt files anywhere |
| `implement/SKILL.md:87` | Summary-template fallback chain hop 2 = `<state>/phases/_templates/NN-YY-SUMMARY.md` | **Retarget** — drop `_templates` hop (chain: on-deck → skill templates) |
| `implement/SKILL.md:89,94,97` | Dispatch into runs dir; example line `dispatched … → .planning/runs/01-01-T2.log`; watch via `tail <state>/runs/…` | **Rewrite** — dispatch state in `$TMPDIR`, path printed at dispatch (EXEC-01) |
| `implement/SKILL.md:103` | Wave gate: stamp plan marker, run `replay-commits.sh`, stamp `committed <sha>`, prune logs | **Delete/Replace** — serialized `merge --no-ff` merge-back with fork-base drift halt and worktree cleanup (EXEC-07); docs-side STATE/ROADMAP commit after all merges (EXEC-05) |
| `implement/SKILL.md:109` | Failed-plan log tail at runs path | **Rewrite** — `$TMPDIR` log |
| `implement/scripts/dispatch.sh:19–59` | runs-dir dispatcher (identical skeleton to define/review's) | **Replace** — call into the shared dispatcher with a `$TMPDIR` state dir (Q3) |
| `implement/scripts/replay-commits.sh` (whole file, incl. runs refs at :10,:17,:20) | Commit sequencer: validates TSVs, commits specs in plan order, stamps markers | **Delete** (EXEC-04) — replaced by executor-owned atomic commits + orchestrator merge-back |
| `implement/scripts/slice-tasks.sh:9,22–23,30–43,62,78,81` | Slicer: per-task prompts into runs/, TSV contract, marker mv paths | **Delete** (EXEC-04/09) — canonical keeps it today; the rework removes it |
| `implement/scripts/state-dir.sh` | State-dir resolver (`$PLANNING_DIR` → `.pi/planning.json` → `.planning`) | **Keep unchanged** (byte-identical in both trees already) |
| `implement/README.md:3,20,29,32,44` | Per-task + TSV/replay + runs docs | **Rewrite** to the new model |

### Vendored side (`.agents/skills/shippEdd/`) and deltas vs canonical

All vendored files except the four `implement` ones are byte-identical to canonical (verified by full-tree diff) — their rows above apply unchanged. The four deltas, all **uncommitted in the root checkout** (EXEC-09's "interim vendored deltas"):

| Vendored file:line | Delta vs canonical | Disposition under the rework |
|---|---|---|
| `implement/SKILL.md:3,7,9,11,16,50,54–56,83,90,93,99,105,113,120` | **Promptless dispatch**: one executor per *plan* (no slicer, no per-task prompts/markers); executor reads the plan and walks `<task>` sections; plan id `NN-YY` (not `NN-YY-TT`); line 99 wave gate adds log-prune and names the vendored replay's `02-worktrees/<name>/` routing; line 83 `_templates` fallback | The rework **keeps per-plan dispatch** (it is the shape EXEC-04/06 assume), **replaces** marker/TSV state with artifact-derived state + `$TMPDIR` run dirs, **replaces** the line-99 replay gate with serialized merge-back, **retargets** line 83's chain |
| `implement/scripts/dispatch.sh:22–33,39–43,55–60,63–88` | Args `<id> <plan-file> <summary-template>`; composes the executor prompt inline via heredoc (persona pointer → plan walk → TSV contract at :76 → marker mv contract :82–83); writes **no prompt files** ("the prompt is piped in and lives only in the log") | **Replace** — the shared dispatcher (Q3); the executor prompt contract changes: atomic git commits in its own worktree (EXEC-04), SUMMARY before return, `$TMPDIR` marker flip |
| `implement/scripts/replay-commits.sh:10–14,22,25,45–72` | Adds **worktree-aware routing**: specs whose paths share a `02-worktrees/<name>/` prefix commit inside that worktree's own git; plus `last`-sha tracking for the marker stamp | **Delete** — sequencer role eliminated by EXEC-04/07; its routing knowledge is subsumed by per-plan worktrees + merge-back |
| `implement/scripts/slice-tasks.sh` | **Absent on disk** (deleted, still tracked at HEAD) | Canonical deletion confirmed by this phase (EXEC-04/09) |

Also vendored-only quirk: the dispatch heredoc (line ~64) hard-codes `Read .pi/agents/executor.md` — a pi-specific persona path in the multi-harness kit (phase 01 wired eight harnesses). Worth folding into the rework's prompt composition; not a `_templates`/`_archive`/`runs` reference, noted as a delta callout.

### The repo's live state dir (`.planning/` in the `progressEdd` checkout — EXEC-10's flattening targets)

| Path | Today | Must become |
|---|---|---|
| `.planning/phases/_templates/` (5 files: NN-CONTEXT, NN-RESEARCH, NN-YY-PLAN, NN-YY-SUMMARY, VERIFICATION — SUMMARY template byte-identical to skill's) | The stash `define`/`implement`/`todo`/`review` fall back to | **Delete** (EXEC-10) |
| `.planning/phases/_archive/01-multi-harness-persona-wiring/` (8 files) | Phase 01 archived at ship | **Restore flat**: `mv .planning/phases/_archive/01-multi-harness-persona-wiring .planning/phases/01-multi-harness-persona-wiring`; `_archive/` then removed (EXEC-10, success criterion 5) |
| `.planning/runs/` (phase-01 `01-01/01-02.commits.tsv` + `.done` markers; phase-02 research `.prompt.md`/`.running`/`.log`/`.done`) | Implement/review/define/wayfind state + this phase's own research markers | **Delete dir** once its content is subsumed (research record = this file; plan completion = SUMMARYs + git). Review's `committed`-line gate retargets to artifacts (row above) |
| `.planning/README.md:16` | Documents `runs/` in the skeleton | **Delete bullet** |
| `.planning/README.md:13` | Old SUMMARY frontmatter keys | **Update** to EXEC-02 keys |
| `.gitignore:7` | `.planning/runs/` ignore rule | **Delete line** (dir no longer exists) |

### Callouts — outside the four named skills, touched by the same schema change

| File:line | Today | Must become |
|---|---|---|
| `todo/SKILL.md:18` | Scaffold "from the `_templates/` stash" | **Retarget** to skill `bootstrap/templates/` |
| `todo/SKILL.md:108` | Phase numbering counts `NN-*` "ignoring `_templates/`" **and** `phases/_archive/` ("archived phases reserve their numbers forever") | **Simplify** — no `_` dirs exist; count `phases/` dirs directly (flat-forever makes archived dirs ordinary dirs) |
| `todo/SKILL.md:114` | Scaffold copy chain starting `<state>/phases/_templates/` | **Retarget** |
| `wayfind/SKILL.md:16,68–78` | Markers-are-truth, stale-marker cleanup, failed-run ownership — all runs-dir based | Keep this phase (wayfind reads whatever define/review still write); rewrite at their migration |
| `wayfind/SKILL.md:37` | Live phases = dirs under `phases/` **excluding `_`-prefixed entries** | Becomes vestigial once no `_` dirs exist — simplify or leave harmless |
| `wayfind/MAP.md:11` | "implement … replays their recorded commits in plan order" | **Retarget wording** to merge-back |
| `wayfind/MAP.md:30,32` | "markers in `<state>/runs/`"; stale-marker/kill-PID guidance | Partially stale after this phase (implement's markers vanish); full rewrite at define/review migration |
| `wayfind/scripts/dispatch.sh:19–59` | A fifth byte-identical copy of the runs-dir dispatcher | Becomes a fifth consumer of the shared dispatcher at define/review migration time |
| `bootstrap/personas/executor.md:3` | "Never runs git; a sequencer commits later from the recorded spec. … flips the run marker" | **Rewrite** (EXEC-04) — executor commits atomically in its own worktree, never merges, writes SUMMARY, flips its `$TMPDIR` marker |
| `bootstrap/personas/verifier.md:48` | Reads "committed lines" implicitly via review's evidence list | Retarget evidence description to SUMMARY + `git log` |

---

## Q2 — Current implement flow (vendored SKILL.md, end-to-end) and what the rework does to it

### Flow as it exists today (`.agents/skills/shippEdd/implement/SKILL.md`)

- **Step 0 — resolve state dir**: `scripts/state-dir.sh` prints one line (`$PLANNING_DIR` env → `.pi/planning.json` `state_dir` → `.planning`); no `STATE.md`+`ROADMAP.md` → stop, point at bootstrap. (`.pi/planning.json` currently has `models` only — no `state_dir`, no `models.executor`, so implement inherits the session model.)
- **Step 1 — ORIENT**: read `STATE.md`, `ROADMAP.md` (Plans: list), enumerate `NN-YY-PLAN.md` in the phase dir (stem containing `YY` = on-deck template, not a plan). **Marker gate**: plan finished iff `<state>/runs/NN-YY.done` exists **and carries a `committed` line** (rule 2, "Markers are truth"). Per-marker semantics: `.done` = awaits wave gate; live-`.running` = report + wait/watch offer (`--status`, `tail …/NN-YY.log`); dead-`.running` = abort cleanup offer (inspect log, delete stale marker, redispatch); `.failed` = read reason, offer inspect/`--force` redispatch. STATE.md is advisory; markers win.
- **Step 2 — WAVE ORDER**: sort unfinished plans by frontmatter `wave` ascending (rule 3: wave data is plan-time data, never recomputed); current wave = lowest wave with an unfinished plan; all its plans dispatch in parallel (rule 4: planner guarantees file-disjointness across same-wave plans; sections within a plan are sequential). One-line wave display.
- **Step 3 — DISPATCH**: per plan, `scripts/dispatch.sh NN-YY <plan-file> <summary-template>` with `--model` only if `.pi/planning.json` `models.executor` names a concrete id. **Promptless**: the dispatcher pipes an inline heredoc to a detached `pi --print` — persona pointer (`Read .pi/agents/executor.md`), the plan as spec (walk `## Tasks <task>` sections in order, verify-not-redo on re-attempt — EXEC-08's seed), final-task duties (run `## Verification` checklist, instantiate summary template as `NN-YY-SUMMARY.md` next to the plan), commit-spec contract (append `<msg>\t<path,…>` to `$state/runs/NN-YY.commits.tsv`; never run git), completion contract (write summary → `mv …running …done` / `…failed` + reason; sentinel `## EXECUTION COMPLETE|BLOCKED`). Summary-template fallback chain: on-deck `NN-YY-SUMMARY.md` → `<state>/phases/_templates/NN-YY-SUMMARY.md` → `.agents/skills/shippEdd/bootstrap/templates/NN-YY-SUMMARY.md` → stop. Report dispatch line verbatim (`dispatched 01-02 (PID 1234) → .planning/runs/01-02.log`), tell the user to walk away, stop — never wait/poll/chain (rule 6).
- **Step 4 — GATE (on re-entry)**: every plan `.done` → wave landed: run `scripts/replay-commits.sh` — the sequencer validates every TSV line (refuses nonexistent paths, naming plan+path), commits each spec sequentially in plan order with **worktree routing** (`02-worktrees/<name>/`-prefixed specs commit inside that worktree's git), stamps `committed <short-sha>` (or `committed none`) into the plan marker so re-runs never double-commit; then prune each committed plan's log. Any `.failed` → one grilling question (inspect / redispatch `--force` / skip with `skipped <reason>` marker + `## Skipped plans` in CONTEXT.md); a failure never blocks siblings. Live `.running` → report and stop. Stale `.running` → cleanup then redispatch. Loop back to step 2 for the next wave.
- **Step 5 — COMPLETE**: every plan `.done` + `committed` → update `STATE.md` (`next_action: /skill:review`, `progress: executed` + body line), hand off to `/skill:review`, stop.

### What the rework does to this flow

**Replaces** — the execution contract around a preserved skeleton (waves, walk-away, idempotent re-entry all survive):

1. *Plan-state oracle* (rule 2 + step 1 gate): marker+`committed` line → **artifact-derived state** (EXEC-02/03): `NN-YY-SUMMARY.md` with `status: complete` → executed; absent SUMMARY + plan-targeted file changes or plan-id commits → interrupted, surfaced with recovery choices; re-runs safe/idempotent.
2. *Dispatch target* (step 3): executors get a **per-plan agent worktree** forked from the plan's target-branch HEAD, fork-base SHA recorded at dispatch (EXEC-06); dispatch state (composed prompt, run log, pid/marker) lives in `$TMPDIR` with its path printed (EXEC-01); **intra-wave target-overlap check** added — same-target same-wave plans demote that wave to sequential with a visible warning flagged as a planning defect (EXEC-06 — new behavior, nothing like it today; today disjointness is by file, not by target).
3. *Executor contract* (dispatch heredoc + executor persona): "you never run git" + TSV append → **executor owns git for its plan**: atomic per-task commits carrying the plan id in its worktree (EXEC-04); SUMMARY written in full before the executor returns (EXEC-04); never STATE.md/ROADMAP.md, never merge (EXEC-04/05).
4. *Wave gate* (step 4): stamp+replay+prune → **serialized orchestrator-owned merge-back**: plans in order, each agent branch `git merge --no-ff` into its target after fork-base validation, drift halts with a recovery handoff naming what is stranded, worktree removed after merge; docs-side STATE/ROADMAP commit only after all merges (EXEC-05/07).
5. *STATE.md sync* (step 5): one final sync → sync lands **per wave/after merges** as part of the gate's docs-side commit (EXEC-05).

**Deletes** — `slice-tasks.sh`, `replay-commits.sh`, `commits.tsv`, per-run repo files of every kind (markers, prompt files, logs), the log-prune step, the `committed`-line stamping, the marker-stamp-before-replay hand-shake, and every `<state>/runs/` path in the skill (SKILL.md, scripts, README).

**Keeps** — steps 0's state-dir resolution; wave/`depends_on` as plan-time data; one-wave-at-a-time with parallel dispatch; walk-away stop rule and grilling question format; `--model` via `.pi/planning.json`; dispatch-time collision guard + `--force`; verify-not-redo executor resumability (EXEC-08); background-only dispatch (Decision 6); the per-plan (not per-task) executor granularity the vendored delta introduced.

---

## Q3 — Shared-dispatcher interface: implement's needs vs define/review's current usage

The three existing dispatchers (`define/scripts/dispatch.sh`, `review/scripts/dispatch.sh`, `wayfind/scripts/dispatch.sh`) are byte-identical 60-line scripts; implement's vendored one shares the same skeleton but swaps the args and pipes a composed prompt. Common machinery already shared: runs-dir wiring (`$root/$state/runs`, `mkdir -p`), `--status` scan (marker glob → id, PID from marker line 1, `kill -0` liveness, log size), collision guard on any existing marker, `--force` clearing all three, `nohup pi --print [model] < input > log 2>&1 &` + PID write, one printed dispatch line. This is exactly the extractable core — the only real variable is **where run state lives** and **where the prompt comes from**.

**What implement needs under the new model (EXEC-01/06):**

- **Run state in a caller-chosen dir** — `${TMPDIR:-/tmp}/…/<id>/` holding: `pid` file, `<id>.log`, a `.running` marker (PID inside) the run itself flips to `.done`/`.failed`. No repo-visible marker at all; the dispatcher must **print the run-dir path at dispatch** (EXEC-01: "transient dispatch state … lives in `$TMPDIR` with its path printed at dispatch") so the skill/user can `tail` the log and the gate can find the state on re-entry.
- **Liveness/death with no repo markers**: `kill -0 $(cat pid)` for alive; dead + no `.done`/`.failed` marker = aborted (stale). Same semantics as today's `--status`, just pointed at the transient dir. Cross-session wrinkle: if `$TMPDIR` is wiped between sessions the run dir is gone entirely — the gate must then fall through to artifact-derived plan state (EXEC-03 is designed for exactly this: SUMMARY present → executed; absent + changed files/plan-id commits → interrupted). Transient state is advisory; artifacts are truth.
- **Prompt composition is implement-side**: EXEC-01 lists the "composed prompt" as transient state. The clean extraction is a dispatcher that takes a **prompt file** and nothing implement-specific — implement's SKILL/gate composes the executor prompt (persona pointer, plan walk contract, commit/SUMMARY contract) to a `$TMPDIR` file, then hands it over. The vendored dispatcher's own header already states the principle ("Generic by design: the ROLE lives in the persona + plan the prompt points at, not here"). Alternative — keep implement's `<plan-file> <summary-template>` composition inside the shared script — works but couples the common script to executor semantics for no gain.
- **Kept mechanics**: collision guard + `--force` (redispatch after abort), `--model` passthrough from `.pi/planning.json` `models.executor`, `--status` against the transient dir, the one-line dispatch report. Merge-back is **not** dispatcher work — it is a separate orchestrator-owned script (EXEC-07/09 name "dispatch and merge-back scripts" as distinct artifacts).

**What define/review's current usage needs (unmigrated this phase — Decision 1):**

- Run state under `<state>/runs/` — repo-visible and session-surviving, because research/verify runs outlive their orchestrator sessions and the marker is the cross-visit resume state (define `SKILL.md:191–194,258`; review `SKILL.md:64,100,107`).
- **Prompt-file persistence** at `<state>/runs/<id>.prompt.md` — redispatch from the saved prompt is a documented flow (wayfind `README.md:21`, review `SKILL.md:113`), unlike implement's ephemeral prompt.
- **Cross-run id hygiene** in a shared dir — review allocates next-free verify ids by scanning `<state>/runs/` (`review/SKILL.md:64`), and wayfind renders the whole board from that dir (`wayfind/MAP.md:30`).
- `--status` listing across all runs of all types (the board).

**Extraction that works now without migrating define/review:** one shared script with signature ≈ `dispatch.sh <id> <prompt-file> [--state-dir <dir>] [--model <id>] [--force]` (plus `--status [--state-dir <dir>]`), defaulting `--state-dir` to `<state>/runs` so define/review keep byte-identical behavior, while implement passes its `$TMPDIR` run dir explicitly. The common core above moves once; implement's wrapper keeps only prompt composition; the `02-worktrees/` routing and TSV machinery of today's replay die with the sequencer, not with the dispatcher. Define/review/wayfind migrate to the shared script (and drop their runs-dir state) in a later phase.

---

## Q4 — Git mechanics recipe (command-level; every step exercised in a throwaway clone, real branches untouched)

Test harness: `git clone` of this repo into `/tmp/t2git`, throwaway branches `t2-target`/`t2-agent-*`, worktrees under `${TMPDIR:-/tmp}/t2`. All probes removed afterwards; `git worktree list` / branch list / `git status` in the real repo verified unchanged (only the pre-existing uncommitted vendored deltas remain).

### 1. Per-plan worktree fork, fork-base recorded atomically at dispatch

```bash
target="<branch from the plan's target>"          # see gap note below
fork_base="$(git rev-parse "refs/heads/$target")" # record THIS value at dispatch…
run_dir="${TMPDIR:-/tmp}/shippEdd/<NN>-<slug>/<id>"; mkdir -p "$run_dir"
printf '%s\n' "$fork_base" > "$run_dir/fork-base"
git worktree add -q -b "agent/<NN>-YY" "$run_dir/worktree" "$fork_base"   # …and fork AT it
```

Verified: the SHA passed to `git worktree add` **is** the recorded fork base, so recording and forking cannot drift apart — capture the sha first, create the worktree at that exact sha. `-b` creates the agent branch at the base and checks it out in the new worktree in one step. Worktree path under `$TMPDIR` matches EXEC-01's transient-state rule (alternatives and one risk below).

### 2. Executor works and commits in its worktree (EXEC-04)

```bash
cd "$run_dir/worktree"
git add <task files> && git commit -m "feat(02-YY): task k — <name>"   # atomic, conventional, plan id in scope
# … per task; final task also writes NN-YY-SUMMARY.md IN FULL before returning
printf '%s\n' "$$" > /dev/null   # executor flips its transient marker, not a repo marker:
mv "$run_dir/<id>.running" "$run_dir/<id>.done"    # or .failed + one-line reason
```

Executor never: merges, pushes, touches `STATE.md`/`ROADMAP.md`, or works outside its worktree (EXEC-04/05/07).

### 3. Liveness/death detection from `$TMPDIR` state (no repo markers)

```bash
pid="$(cat "$run_dir/pid")"
if kill -0 "$pid" 2>/dev/null; then :; fi                     # alive
# dead + marker still .running  -> aborted (stale): offer cleanup + redispatch
# marker flipped to .done       -> completed regardless of pid state
```

Verified with real processes: live PID → `kill -0` succeeds; killed PID with flipped `.done` → completed; killed PID with `.running` → aborted. This is the existing `--status` logic (dispatcher line ~32: `kill -0 "$pid"`) retargeted to the transient dir. Caveats: PID reuse can fake "alive" (`ps -p "$pid" -o comm=` matching `pi` is a cheap tightening); a tmp-wiped run dir means "state unknown" → artifact-derived recovery (EXEC-03), not "aborted".

### 4. Serialized merge-back in plan order, drift check first (EXEC-07)

The merge must run in a checkout that has the target branch checked out — a branch is checked out in exactly one worktree (verified: `fatal: 't2-target' is already used by worktree …`). Mapping in this repo: `master` is checked out in `02-worktrees/master/`, `progressEdd` in the root checkout. Merge via `git -C`:

```bash
for plan in <wave plans in plan order>; do
  agent="agent/$plan"; target=…; fork_base="$(cat "$run_dir/$plan/fork-base")"
  mb="$(git merge-base "$agent" "$target")"
  if [ "$mb" != "$fork_base" ]; then
    echo "DRIFT: plan $plan stranded — branch $agent forked at $(git rev-parse --short "$fork_base"),"
    echo "but merge-base with $target is $(git rev-parse --short "$mb"); worktree $run_dir/worktree left in place."
    exit 1                                            # halt THIS merge; later plans also halt (order is serialized)
  fi
  if ! git -C "<checkout holding $target>" merge --no-ff --no-edit "$agent" \
        -m "merge($plan): plan $plan into $target"; then
    git -C "<checkout holding $target>" merge --abort
    echo "CONFLICT: plan $plan stranded — branch $agent, worktree $run_dir/worktree, target $target"; exit 1
  fi
done
```

Verified behaviors, all exercised:

- **`--no-ff` bubble shape**: one merge commit per plan, agent commits intact and stable (`* merge(02-01) /|\ | * feat(02-01): task 2 …`).
- **Benign sibling advance passes the drift check**: after merging plan A, `git merge-base agent-B target` **still equals** B's fork base (A's merge commit doesn't change B's common ancestor) — serialized plan-order merging is not falsely halted.
- **Target-side drift halts**: `git reset --hard HEAD~2` on the target (history rewrite) → merge-base ≠ recorded fork base → halt. `git merge-base --is-ancestor "$fork_base" "$target"` fails identically (belt-and-braces option).
- **Executor-side drift halts**: rebasing the agent branch onto the target tip → merge-base ≠ fork base → halt. The single equality check catches both directions.
- **Conflict halts cleanly**: same-base branches editing one file; second `merge --no-ff` exits 1 leaving conflict markers; `git merge --abort` restores the pre-merge tree exactly (`git status` clean).
- **Naming what is stranded**: the halt message carries plan id, agent branch, worktree path, recorded fork sha, and current merge-base — the recovery handoff names every stranded artifact.

### 5. Worktree + agent-branch cleanup after merge

```bash
cd <orchestrator checkout>                 # never clean up from inside a worktree being removed
git worktree remove "$run_dir/worktree"    # clean tree → plain remove
git branch -d "agent/$plan"                # merged → -d succeeds
# unmerged/stranded branch, only on explicit user acceptance:
git worktree remove --force "$run_dir/worktree"; git branch -D "agent/$plan"
git worktree prune                          # stale registrations (e.g. tmp-wiped worktree dirs)
```

Verified: `git branch -d` **refuses** while the branch is checked out in a worktree (`error: cannot delete branch … used by worktree at …`) — order is remove-then-delete. `-d` also refuses an unmerged branch (observed after a reset orphaned earlier merges) — correct behavior; `-D` is the explicit-acceptance escape for a stranded branch the user chose to abandon. Removing a worktree while a shell sits inside it breaks the shell's `git` calls ("Unable to read current working directory") — cleanup runs from the orchestrator's checkout.

### Gaps the planner must close (facts, not decisions)

- **No target-branch field exists in plan frontmatter.** `bootstrap/templates/NN-YY-PLAN.md:1–4` carries only `wave` + `depends_on` (confirmed in the real `01-01-PLAN.md`); today's target is implicit (phase 01 targeted `master` via `02-worktrees/master/` path prefixes + replay routing). EXEC-06 says "the plan's target branch", so the rework must add a `target:` key (or equivalent) to the plan template — with knock-ons in `planner.md:3,34,62–65` (frontmatter authoring), `define/SKILL.md:238–256` (plan approval spec), and the fix-plan frontmatter at `review/SKILL.md:143–144`.
- **No agent branch/worktree naming convention exists.** `02-worktrees/README.md` documents only manual worktrees (`git worktree add 02-worktrees/<name> -b <branch>`); nothing reserves names for agent branches. Suggestion-shaped, for the planner to decide: `agent/<NN>-YY` branch names; worktree location `$TMPDIR` (transient, EXEC-01-aligned, but a tmp wipe before merge-back orphans the agent branch — recovery = the drift/strand handoff naming the branch and its commits, and `git worktree prune` cleans the registration) vs `02-worktrees/agent-<NN>-YY` (repo-visible, gitignored via `02-worktrees/*`, follows the existing convention dir but persists visibly and borrows the manual-worktree namespace).
- **`git merge` cannot target a branch checked out nowhere.** With only `master` and `progressEdd` as realistic targets, both are always checked out somewhere in this repo — but the merge script should fail loudly if the target branch has no checkout rather than silently fast-forwarding via plumbing.

---

## Recommendation

Build the phase on three moves the evidence supports directly: (1) extract the shared dispatcher as the parameterized core every dispatch.sh already shares (`<id> <prompt-file> [--state-dir] [--model] [--force]` + `--status`), have implement compose its executor prompt into a `$TMPDIR` run dir and pass that dir — define/review keep their defaults untouched; (2) replace implement's step-4 replay gate with the tested merge-back loop (merge-base == fork-base check, `--no-ff` merge in the checkout owning the target, remove-then-delete cleanup, conflict/drift halts naming plan id + branch + worktree + shas); (3) retarget every `_templates`/`_archive` chain to the skill's `bootstrap/templates/` per the Q1 map, restore phase 01 flat, and delete `runs/` + its ignore rule + doc bullets when the schema flattening lands. The per-plan executor granularity, promptless dispatch, and worktree-aware thinking of the vendored deltas are the right foundation — the rework should evolve that vendored shape onto canonical `master` rather than re-deriving from canonical's per-task flow.

## Risks / unknowns

- **Decision 1 vs EXEC-10 tension (needs an orchestrator ruling):** Decision 1 keeps define/review on the marker model this phase, but EXEC-10 and roadmap success criterion 5 say "`runs/` is gone" and "define/review/bootstrap no longer reference any removed dir". If define/review still write `<state>/runs/` markers, the dir inevitably re-exists (their `dispatch.sh` even `mkdir -p`s it). Readings: (a) EXEC-10's "runs/ is gone" means the *schema/inventory* loses it while define/review's transitional usage recreates it on demand until their migration; (b) define/review's SKILL.md references get retargeted to the shared dispatcher with `$TMPDIR` state this phase after all (re-opens Decision 1's scope); (c) runs/ survives as a define/review-only dir with docs saying so. This is a wording collision between locked decisions, not a research gap — surface it at plan approval.
- **Uncommitted vendored deltas collide with the EXEC-09 refresh:** `git status` shows `.agents/skills/shippEdd/implement/{SKILL.md,dispatch.sh,replay-commits.sh}` modified and `slice-tasks.sh` deleted, untracked-by-commit. The squash refresh (`git subtree merge --prefix=.agents/skills/shippEdd master --squash`, `.agents/skills/shippEdd/README.md:28`) merges into a checkout whose vendored tree is dirty — git refuses merges that would overwrite locally-modified files. The phase must commit or otherwise resolve the interim deltas before/as part of the refresh; EXEC-09 says the refresh "carries" them, which implies they land as a commit first.
- **`.planning/runs/` currently holds this phase's own research state** (markers, log, this run's prompt) plus phase-01 TSVs/done markers whose information review's gate and ship receipt still consume (`review/SKILL.md:52,79`, receipt line 192). Deleting `runs/` is only safe after review's evidence derivation retargets to SUMMARY + git log — sequence the schema flattening so the gate change lands in the same phase (it does, per EXEC-10), and don't delete the dir mid-phase while a define/review run is live.
- **SUMMARY template rework touches three surfaces at once** (skill template, `.planning/README.md:13` doc, executor prompt contract) — EXEC-02's exact key set (`status`, `duration`, `key-files{created,modified}`, `requirements-completed`, `key-decisions`, `deviations`) should be written once into `bootstrap/templates/NN-YY-SUMMARY.md` and referenced, not re-specified in the dispatch prompt.
- **PID-reuse false-alive** in `kill -0` liveness (long uptimes recycle PIDs); optional `ps -p <pid> -o comm=` tightening. Also `$TMPDIR` reapers (systemd-tmpfiles, macOS periodic cleanup) can vanish run state mid-phase — by design the gate must treat missing run dirs as "derive from artifacts", never as failure.
- **Merge-back ordering vs live target checkouts**: if a future plan targets a branch checked out nowhere (or checked out in a worktree with uncommitted changes), the merge step fails mid-sequence — the merge script should pre-check per-plan (target has a clean checkout) before the first merge, not discover it at plan k.
- **Unanswered here by design** (planner decisions, inputs provided): plan `target:` frontmatter key name and default; agent branch/worktree naming; whether the shared dispatcher's default `--state-dir` remains `<state>/runs` (recommended) or becomes explicit everywhere.
