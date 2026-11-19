---
name: review
description: Verifies the executed phase with a fresh-context verifier subagent (requirement, decision, and task coverage — actually run), walks any gaps into fix plans via the planner, and ships when green — commit, optional PR, tick the roadmap. Run /skill:review after /skill:implement finishes all plans.
disable-model-invocation: true
---

# shippEdd review — verify it, then ship it

You are the orchestrator for the verify→ship half of the phase loop. You dispatch a fresh-context verifier to coverage-check the executed phase, read its report, and — this is your second half — when the verdict is green, ship in the same breath: commit the state dir, tick the roadmap, optionally push and open a PR. Between those halves sits the gap loop: gaps become fix plans written by the planner and executed by `/skill:implement`; you re-verify after. You are the only skill allowed to touch git remotely or mutate roadmap history.

`<state>` is the workflow state dir resolved in step 0; all other paths are relative to it or to the repo root. This skill is self-contained: dispatch runs through the suite's shared scripts at `.agents/skills/shippEdd/scripts/` (repo-relative). Gap fixes route through implement's wave/merge-back machinery, never through review.

## Ground rules

1. **Orchestrate, don't labor** — verification runs in a detached fresh-context run; fix plans are written by the planner; implementation happens in executors. Review itself never implements, never fixes, never merges back. Your session carries the report digest and the ship receipt, never implementation detail.
2. **Products are truth** — the verify run's state is its artifact (VERIFICATION.md's verdict line), never session memory; REQUIREMENTS.md is the tiebreak when products are ambiguous; markers in the phase run dir are advisory liveness. `/skill:review` may be re-run at any moment, mid-verify or mid-gap-loop; it reads state, it doesn't remember it.
3. **Every question uses exactly this format** (identical to bootstrap's, define's, implement's):

   ```
   ❓ <question>
     ➡️ 1. <recommended answer>
       2. <option>
       3. <option>
   ```

4. **Gaps route through implement** — a gap becomes a fix plan (`NN-FX1-PLAN.md`, …) that `/skill:implement` dispatches and merges back like any wave; then the user re-runs `/skill:review` to re-verify. Keeping fixes out of review keeps the judge out of the implementation.
5. **Ship is gated** — shipping happens only on `## VERIFICATION PASSED` with zero unaccepted gaps. A gap the user explicitly accepts, with a reason, is recorded in VERIFICATION.md under `## Accepted gaps` and stops counting against the gate.
6. **Review owns the ship-time git surface** — commit tracked state-dir changes, tick ROADMAP, and (only if `gh` and a remote exist) push/PR/audit issue. Whether the state dir is tracked was bootstrap's decision: test with `git check-ignore`, never force-add an ignored state dir.
7. **Recommend and stop** — nothing auto-fires. The skill ends by naming the next command (`/skill:implement`, `/skill:define`, or `/skill:todo`). Never run it yourself.

## Step 0 — resolve the state dir

Run `.agents/skills/shippEdd/scripts/state-dir.sh`. It prints exactly one line: the state dir path relative to the repo root (`$PLANNING_DIR` env → `.pi/planning.json` `state_dir` → `.planning`).

If that dir lacks both `STATE.md` and `ROADMAP.md`, no workflow state exists. Say:

> No workflow state found. Run `/skill:bootstrap` first — it creates the skeleton this skill reads.

Then stop.

## Step 1 — ORIENT

Read (never ask for) the state:

- `<state>/STATE.md` — where the loop stands; its body names the current phase (implement set it)
- `<state>/ROADMAP.md` — this phase's entry, its `Plans:` list, what comes next
- `<state>/phases/<NN>-<slug>/` — the phase folder: enumerate the `NN-*-PLAN.md` files. Every one is a real plan — placeholder copies are never scaffolded into a phase dir.
- `<state>/config.json` — `github.mirror` (absent = off; the full `github.*` contract is documented in the bootstrap skill's README, Configuration reference)

**Target phase**: the phase named in STATE.md's body; if STATE.md and the phase dir disagree, the dir wins. Shipped-ness derives from state, never a directory location: ROADMAP's phase checkbox ticked or STATE.md's `progress: shipped` means it shipped — recommend `/skill:define` (or `/skill:todo` if the roadmap is complete) and stop.

**Gate every plan on its artifact** — the phase is verifiable iff each of its `NN-YY` plans has a `NN-YY-SUMMARY.md` whose frontmatter carries `status: complete` (implement's completion signature is the artifact) or is recorded skipped under `## Skipped plans` in the phase's `NN-CONTEXT.md`. Anything else — a SUMMARY with `status: blocked`, or no SUMMARY at all (in flight, interrupted, never started) — means execution isn't finished, and execution is implement's lane (worktree dispatch, cleanup, merge-back all live there). Say:

> Phase `<NN>-<slug>` isn't fully executed yet — plan `<NN-YY>` has no completed SUMMARY. Run `/skill:implement` first; it owns worktree dispatch and merge-back.

Then stop.

**Re-verify detection**: if the phase's `VERIFICATION.md` is a filled report (a real verdict line, no `<…>` placeholders — the verifier creates the file on demand, so presence means a prior round; only a legacy phase minted before lazy scaffolding can carry a raw copy), this is a re-entry after a gap loop; note it — the next verify run takes a suffixed id (step 2).

Report a two-line summary (phase, plans with completed SUMMARYs, prior verification if any), then dispatch.

## Step 2 — DISPATCH the verifier (background)

**Run id**: `<NN>-verify` if no `<NN>-verify*` marker exists in the phase run dir (`$(bash .agents/skills/shippEdd/scripts/runs-dir.sh home)/<NN>-<slug>/` — same resolution as dispatch, below); otherwise `<NN>-verify<k>` for the smallest `k ≥ 2` with no marker (first re-verify is `NN-verify2`, the next `NN-verify3`, …). The dispatcher's collision guard refuses duplicate ids — never `--force` over an existing verification; `--force` clears markers and is only ever for re-running a `.failed` verify of the same id (step 3).

Template source for the artifact: `.agents/skills/shippEdd/bootstrap/templates/VERIFICATION.md` (repo-relative — the skill's own templates; there is no scaffolded copy). If it is missing, stop and recommend rerunning `/skill:bootstrap` (it repairs the skill folder's templates without touching existing content).

Resolve `home="$(bash .agents/skills/shippEdd/scripts/runs-dir.sh home)"` (config-driven; default `${TMPDIR:-/tmp}/shippEdd` — transient state never under `<state>/`) and compose `$home/<NN>-<slug>/<id>.prompt.md` — a fully self-contained prompt (the detached run loads nothing else):

```
Read .pi/agents/verifier.md and operate as that agent for the task below.

## Task
You are verifying phase <NN>-<slug> of the shippEdd workflow in this repo (the repo root is this run's working directory).

Inputs:
- Phase goal: <one sentence, from ROADMAP's phase details>
- Phase dir: <state>/phases/<NN>-<slug>/ — <NN>-CONTEXT.md (settled decisions), every <NN>-<YY>-PLAN.md, every <NN>-<YY>-SUMMARY.md, and VERIFICATION.md if a prior round filled it (its `## Accepted gaps` section carries forward)
- Requirements: <state>/REQUIREMENTS.md — REQ-IDs mapped to this phase: <comma-separated REQ-IDs, or "none recorded">
- Roadmap: <state>/ROADMAP.md — this phase's entry (goal, requirements, success criteria)
- Commits: the task-commit hashes recorded in each plan's `NN-YY-SUMMARY.md` — cross-check read-only with `git log --grep "<NN>-YY>:"` and the `merge(<NN>-YY>):` merge commits on each plan's target branch

Artifact: write <state>/phases/<NN>-<slug>/VERIFICATION.md from the skill's template `.agents/skills/shippEdd/bootstrap/templates/VERIFICATION.md` — create the file if it is absent, replace whatever a prior round left — per your persona's report contract.

## Completion contract
1. Write the artifact named above, fully, per its template.
2. Then run: mv <run dir>/<id>.running <run dir>/<id>.done   (the phase run dir: <runs home>/<NN>-<slug>/)
3. If you cannot complete: mv the marker to .failed and append a one-line reason to the marker file.
Your final message must end with the sentinel: ## VERIFICATION PASSED (or ## VERIFICATION FAILED / ## VERIFICATION BLOCKED)
```

Substitute the state dir, phase, REQ-IDs, and run id into every path — keep every path repo-relative (no absolute paths; the detached run starts at the repo root, so relative paths resolve and nothing machine-specific lands in the run dir). The completion contract is canonical — copied verbatim from the define skill's, with only the run id, the `mv` paths, and the sentinel names substituted. If `.pi/agents/verifier.md` is not installed, stop and say so — the framework's personas travel in `.pi/agents/`.

Dispatch with `bash .agents/skills/shippEdd/scripts/dispatch.sh <id> $home/<NN>-<slug>/<id>.prompt.md --state-dir $home/<NN>-<slug>`, passing `--model <id>` **only if** `.pi/planning.json` has a `models.verifier` entry naming a concrete model id — an absent key (or a tier word like "strong", which is not a model id) means inherit the session default.

Report dispatch.sh's output line to the user verbatim, e.g.:

```
dispatched 01-verify (PID 1234) → /tmp/shippEdd/01-auth/01-verify.log
```

Then tell the user they can walk away: re-run `/skill:review` at any time — when VERIFICATION.md carries a fresh verdict it reads it and continues from there; products are truth, same as implement. Watching live: `bash .agents/skills/shippEdd/scripts/watch-run.sh <state> <NN> <slug> verify <id>` (opt-in, user-run — blocks until the verdict lands; exit 0 done · 2 failed · 4 timeout), `bash .agents/skills/shippEdd/scripts/dispatch.sh --status --state-dir $home/<NN>-<slug>`, `tail $home/<NN>-<slug>/<id>.log`. Stop — never wait, never poll.

## Step 3 — READOUT (on re-entry, marker `.done`)

Find the newest verify run for the phase (highest id suffix) and gate on its products first:

- **VERIFICATION.md carries a fresh verdict** (a real verdict line, not the template — and newer than the last readout's report if re-entering) — read it, present the digest below, and proceed by its verdict. Markers only refine the picture (a live PID means a NEWER verify is still running).
- **`.running` with a live PID** — report it as running, show the watch commands (`watch-run.sh verify`, `--status`, `tail`), and stop: re-run `/skill:review` to check again. Nothing waits here.
- **`.running` with a dead PID** — an aborted or crashed run; an aborted run never flips its marker. Offer cleanup: inspect the log (`tail $home/<NN>-<slug>/<id>.log`), then delete the stale marker — the next `/skill:review` dispatches a fresh verify. Stop.
- **`.failed`** — the verify couldn't run (a named input was missing). Show the marker's reason line, then:

  ```
  ❓ Verification couldn't run: <one-line reason from the marker>. What now?
    ➡️ 1. inspect — show the tail of $home/<NN>-<slug>/<id>.log and decide from there
      2. redispatch — bash .agents/skills/shippEdd/scripts/dispatch.sh <id> $home/<NN>-<slug>/<id>.prompt.md --state-dir $home/<NN>-<slug> --force (clears the failed marker, fresh verify of the same id)
  ```

- **`.done`** — read `<state>/phases/<NN>-<slug>/VERIFICATION.md` and present it compactly, never dump it:
  - the verdict line and the counts — `requirements X/Y covered · decisions A/B honored · verifies C/D passed`
  - one line per task verify: `<plan> <task> → ✅/❌`
  - gaps, numbered, each with its taxonomy and smallest fix
  - accepted gaps, if any, one line each

  If the verdict is PASSED with zero unaccepted gaps → step 5. Anything else → step 4.
- **Products ambiguous** (markers claim done but no verdict) — tiebreak against REQUIREMENTS.md's rows for this phase, then treat the verify as not-run and redispatch.

## Step 4 — GAPS

```
❓ Verification found <N> unaccepted gap(s). What now?
  ➡️ 1. create fix plans — dispatch the planner to write <NN>-FX plan files; /skill:implement runs them like any wave
    2. fix manually — fix it outside this skill, then re-run /skill:review to re-verify
    3. accept gap(s) — name the number(s) and give your reason; each is recorded in VERIFICATION.md and stops counting against the ship gate
```

1. **Create fix plans** — dispatch the **planner** subagent (agent name `planner`, agentScope both) in the foreground with a self-contained prompt:

   ```
   Fix-plan phase <NN>-<slug> for the shippEdd workflow in this repo (the repo root is the subagent's working directory).

   Inputs — read them all before writing:
   - Gaps: <state>/phases/<NN>-<slug>/VERIFICATION.md — the `## Gaps found` section is your spec; every gap must be covered by exactly one fix plan (gaps sharing a root cause may share one)
   - Context: <state>/phases/<NN>-<slug>/<NN>-CONTEXT.md — decisions, locked
   - Pattern: the phase's existing <NN>-<YY>-PLAN.md files — match their task-block shape exactly
   - Template: `.agents/skills/shippEdd/bootstrap/templates/NN-0N-PLAN.md`

   Write one fix plan per gap: <NN>-FX1-PLAN.md, <NN>-FX2-PLAN.md, … continuing the numbering from any FX files already in the phase dir. Frontmatter: wave: <current max wave across the phase's plans> + 1, depends_on: [], target: <the affected plan's target branch>, fixes: <the id of the affected plan, e.g. 06-03 — the GitHub mirror nests FX issues under the plan they fix>. Same task-block discipline as any plan: exact files, actions, runnable verify commands, acceptance criteria. Fix plans write files only — never STATE.md or ROADMAP.md.
   ```

   On return, check every gap is covered by a plan (a gap without a plan goes back to the planner).

   **Mirror mint for FX plans (opt-in, never-block)** — iff `github.mirror: true` in `<state>/config.json`: run `bash .agents/skills/shippEdd/scripts/gh-mirror.sh <state> <NN> <slug> capture` once after the fix plans return. It mints each FX plan's sub-issue under the plan its `fixes:` frontmatter names (idempotent — existing issues are only re-synced). Report the receipt's `created` line verbatim; a miss never blocks the fix loop.

   Then update `<state>/STATE.md`: `next_action: /skill:implement`, `progress: planned`, body — "review: <N> gaps found — fix plans <ids> awaiting execution". Then:

   > Fix plans ready: `<ids>`. Next: `/skill:implement` to run them — then `/skill:review` again to re-verify.

   And stop.

2. **Fix manually** — stop. The user fixes outside the skill, then re-runs `/skill:review`; the fresh verify takes the next free run id (step 2), and the verifier re-checks the tree from scratch.

3. **Accept** — for each gap the user names, append a row to VERIFICATION.md (create the section if absent, after `## Gaps found`):

   ```
   ## Accepted gaps

   - Gap <n> (<taxonomy>): <gap title> — accepted <YYYY-MM-DD>: "<the user's reason, verbatim>"
   ```

   When every gap is accepted → step 5; otherwise re-ask the question for the remaining ones.

## Step 5 — SHIP

Runs only on `## VERIFICATION PASSED` or "every gap accepted" — never with an open gap. In order:

1. **Commit the state dir** (iff tracked). Transient dispatch state lives under the runs home — never in the repo — so there is nothing to clear. `git check-ignore -q <state>` — exit 0 means ignored: skip silently, bootstrap's git policy already decided, never force-add. Otherwise `git add -- <state>` and, if anything staged, `git commit -m "chore(<NN>-<slug>): verification + phase artifacts"`.
2. **ROADMAP** — tick the phase checkbox (`- [ ] **Phase <NN>:` → `- [x]`), tick its `Plans:` checkboxes, update its Progress-table row (`<N>/<N>`, `Shipped`, today's date), and advance `## Next up` to the next unchecked phase — or write `**none — roadmap complete**`.
3. **STATE.md** — frontmatter: `next_action: /skill:define`, `progress: shipped`. Body: the phase, `shipped — <verdict line; accepted gaps if any>`, and the next phase (or "roadmap complete").
4. **Commit the ship mutations** — same tracked check as (1): `git add -- <state>` and, if anything staged, `git commit -m "chore(<NN>-<slug>): ship — tick roadmap"`.
5. **Archive offer (cadence-gated, suggested — never automatic)** — after the roadmap tick (step 2), count the shipped phases and offer the history prune when the cadence hits:

   ```bash
   shipped="$(grep -c '^- \[x\] \*\*Phase' <state>/ROADMAP.md)"
   cadence="$(bash .agents/skills/shippEdd/scripts/runs-dir.sh archive-cadence)"   # absent key = 5 (bootstrap/README.md)
   ```

   If `shipped > 0` and `$((shipped % cadence))` is `0`, offer (question format):

   ```
   ❓ <shipped> phases shipped — the archive cadence (<cadence>) hit. Prune the history files?
     ➡️ 1. yes — append a RELEASES.md release entry (dates, commit hashes, phases), clear ROADMAP to live content, fold superseded REQUIREMENTS versions under the entry
       2. no — skip this ship; the offer returns at the next cadence hit
   ```

   On **no** — nothing changes; say one line (`archive offer declined — returns at <next multiple> shipped phases`) and continue at step 6.

   On **yes** — the sweep touches `<state>/ROADMAP.md`, `<state>/REQUIREMENTS.md`, and `<state>/RELEASES.md` ONLY. phases/ folders are never pruned or moved; STATE.md and config.json stay as they are.

   1. **Resolve each archived phase's records** (every phase whose ROADMAP checkbox is ticked). Ship record — one clock, the ship docs commit on progressEdd is the entry's date source:

      ```bash
      git log progressEdd --grep "chore(<NN>-<slug>): ship — tick roadmap" -1 --format='%h %cI'
      ```

      Master landing SHA — era-aware, first hit wins, newest match (the `merge_sha()` chain law from `scripts/gh-mirror.sh`, at phase granularity — 07-RESEARCH Q1):

      ```bash
      git log master --merges --grep "merge(<NN>-<slug>/" -1 --format='%h %cI %s'         # per-phase / per-plan gate bubbles (phases 03+; the newest closes the phase)
      git log master --merges --grep "agent/<NN>-<slug>/master" -1 --format='%h %cI %s'   # PR-disposition landings (phase 06+ era)
      git log master --grep "(<NN>-" -1 --format='%h %cI %s'                              # conventional plan-id commits (phases 01/02, linear era)
      git log master --grep "<NN>-<slug>" -1 --format='%h %cI %s'                         # bare phase-name mentions (last resort)
      ```

      An unresolved phase is recorded as `not resolvable from git history` — never guessed, never hand-injected.
   2. **Append the release entry** to `<state>/RELEASES.md` (create the file with a `# Releases: shippEdd` header if absent) as the next `## Release R<k> — <YYYY-MM-DD>` heading, where `k` = the number of existing `## Release` headings + 1 and the date is today's:

      ```markdown
      ## Release R<k> — <YYYY-MM-DD>

      Pruned at ship of phase <NN>-<slug> — <n> phases archived (cadence <cadence>; `archive_cadence` in <state>/config.json, default 5).

      | Phase | Shipped | Ship commit (progressEdd) | Master landing |
      |---|---|---|---|
      | 01-multi-harness-persona-wiring | <date> | <sha> | <sha> — <subject> |
      | … | … | … | … |

      <details><summary>Superseded REQUIREMENTS versions (v1–v<k-1>)</summary>

      (the superseded `## v<j> requirements` sections, moved verbatim from REQUIREMENTS.md)

      </details>
      ```
   3. **Clear ROADMAP to live content only**: delete every ticked `- [x] **Phase` line under `## Phases` (keep unchecked ones); delete every archived phase's `### Phase <NN>:` details block under `## Phase details` (keep live phases' blocks, including their `Plans:` lists); keep only unshipped rows in the `## Progress` table. `## Overview`, `## Next up`, and the conventions comment stay.
   4. **Fold REQUIREMENTS.md**: keep the `# Requirements: shippEdd` header and the current (highest) `## v<k> requirements` section in place, verbatim; every earlier `## v<j> requirements` section moves verbatim into the release entry's details block (step 2).
   5. **Commit** (same tracked check as step 1): `git add -- <state>` and, if anything staged, `git commit -m "chore(<NN>-<slug>): archive — release R<k>, ROADMAP pruned to live content"`. Report one line: `archive R<k> — phases <first>..<last> → RELEASES.md`.
6. **Push / PR** — gated on disposition and change scope, not tooling alone. Resolve the disposition with `bash .agents/skills/shippEdd/scripts/runs-dir.sh disposition` (absent key = `pr` — the same resolver merge-back uses), and the ship's change scope — the paths outside `<state>/` across this phase's commits on the current branch:

   ```bash
   base="$(git log --grep 'ship — tick roadmap' --format=%H | sed -n 2p)"      # the PREVIOUS phase's ship commit (this phase's own was just made in step 4)
   [ -n "$base" ] || base="$(git rev-list --max-parents=0 HEAD | tail -n1)"    # first-ever phase: the root commit
   git diff --name-only "$base"..HEAD -- . ":(exclude)$state"
   ```

   **Offer the PR question iff the disposition is `pr` AND the scope is non-empty** — planning rides the push; code-carrying ships get PR treatment. Tooling facts shape the recommendation, never the gate: no `git remote` → recommend "neither"; `gh` absent or unauthenticated but a remote exists → recommend "just push":

   ```
   ❓ Push and open a PR for this phase?
     ➡️ 1. create PR — push the branch and open a pull request; body = the phase digest
       2. just push — push the branch, no PR
       3. neither — leave the commits local
   ```

   The **phase digest** (PR title/body) is built from the phase's SUMMARY files (frontmatter `provides` + Accomplishments) plus the verification verdict (the counts and any accepted gaps). Title: `Phase <NN>-<slug>: <goal>`.

   **Otherwise** (disposition `auto-merge`, or a docs-only ship — empty scope): push-first, no question. If `git remote` is empty: one line — "no git remote — commits stay local". Else push the branch (`git push <remote> <branch>`) and report one line — `pushed <branch> — no PR offered (<docs-only ship | disposition auto-merge>)`.
7. **Mirror ship sweep** — iff `<state>/config.json` has `"github": { "mirror": true }` (absent = off): run

   ```
   bash .agents/skills/shippEdd/scripts/gh-mirror.sh <state> <NN> <slug> ship --verdict "<the one-line verdict from VERIFICATION.md>"
   ```

   It posts the verdict as the parent issue's closing comment, closes any still-open decision and plan sub-issues (guarded, state-checked — the sweep-up point), and closes the phase milestone. Never-block: its receipt (or its miss note, when gh/auth is unavailable) is relayed as one line; a mirror failure never fails the ship.

Then present the **ship receipt**:

```
Phase <NN>-<slug> — shipped
  commits   <k> (the phase's merge and docs commits)
  archive   <"R<k> — phases <first>..<last>", or "—">
  PR        <url, or "— (no PR offered: <docs-only ship | disposition auto-merge>)">
  mirror    <"parent #<N> closed · verdict posted · milestone closed", or "—">
  next up   <next phase — start with /skill:define, or "roadmap complete">
```

## Step 6 — handoff

If a next unchecked phase exists on the roadmap:

> Phase `<NN>-<slug>` shipped — <one line: verdict, PR if any>. Next: `/skill:define` for `<next phase>` — in a fresh session (clear this context first; everything durable is on disk).

If the roadmap is complete:

> Phase `<NN>-<slug>` shipped — that was the last one. Next: `/skill:todo` to bank what comes next (or `/skill:define` to mint a new phase from a one-line intent) — in a fresh session (clear this context first; everything durable is on disk).

Then stop (rule 7).
