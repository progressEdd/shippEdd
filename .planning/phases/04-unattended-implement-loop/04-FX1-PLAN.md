---
wave: 6
depends_on: []
target: progressEdd
---

# Plan 04-FX1: the inaugural auto-mode live run + honest records — the AUTO-07 layer-2 gap

**Objective:** Close the single gap from verification run 04-verify: AUTO-07 layer 2 (the inaugural auto-mode live run) never ran on the new machinery — plan 04-05 was dispatched, watched, and merged by the old per-plan scripts (old prompt text, old run-dir layout, branch `agent/04-05`, gate merge message `merge(04-05): plan 04-05 into progressEdd`), while 04-05-SUMMARY.md nonetheless claims it was "executed by the canonical auto-mode loop (AUTO-07 layer 2, the inaugural live run)". The fix has two halves: (1) **this plan's own execution** is dispatched, watched, and merged per-target by the refreshed loop (canonical `dispatch-plan.sh` + `watch-wave.sh` + `merge-back.sh`) — minting the missing evidence: the per-target prompt ("attempt N of at most 3", branch `agent/04-unattended-implement-loop/progressEdd`), the new run-dir layout (`attempts`, `04-FX1.target`, sibling per-target `progressEdd/` dir), and the `merge(04-unattended-implement-loop/progressEdd):` gate commit on progressEdd; (2) **the records are made honest**: the false claim in 04-05-SUMMARY.md is struck and corrected in place, and REQUIREMENTS.md's AUTO-07 row + VERIFICATION.md's gap entry record the 04-FX1 run as layer 2's inaugural live proof. Master's plans 04-01..04-04 stay landed via their transitional old-format merge bubbles — real merges carrying the work; no history is rewritten.

**Orchestrator note (read before dispatching this plan — this run IS half the fix):** run this plan through the refreshed loop, from the main checkout root (progressEdd's checkout; the vendored skill is byte-identical to canonical after 04-05's parity refresh — use either path, they are the same files). In order:

1. **Commit this plan file first** (keeps progressEdd clean for merge-back and puts the plan inside the executor's fork):

   ```bash
   git add .planning/phases/04-unattended-implement-loop/04-FX1-PLAN.md
   git commit -m "chore(04-unattended-implement-loop): fix plan 04-FX1 recorded (verification gap 1)"
   ```

2. **Clean transient leftovers if present:** `git status --porcelain` may show `?? .planning/runs/` holding the review dispatcher's stale `04-verify.{log,prompt.md,running}` files (named in VERIFICATION.md's AUTO-06 row). Confirm with `ls .planning/runs/` that it holds only those, then remove the directory — merge-back halts on any dirt. Anything else dirty: commit or stash exactly those paths (the halt's own recovery rule).

3. **Dispatch + watch in the same visit** (no `--model` — `.pi/planning.json` has no `models.executor` entry):

   ```bash
   bash .agents/skills/shippEdd/implement/scripts/dispatch-plan.sh 04-FX1 .planning/phases/04-unattended-implement-loop/04-FX1-PLAN.md progressEdd --summary-template .agents/skills/shippEdd/bootstrap/templates/NN-0N-SUMMARY.md
   bash .agents/skills/shippEdd/implement/scripts/watch-wave.sh .planning 04 unattended-implement-loop 04-FX1
   ```

   Expect dispatch lines `worktree … (forked progressEdd@<sha>)` and `attempt 1/3`, then watch resolution `resolved 04-FX1: executed (SUMMARY complete)`. Failure/block: recover per SKILL.md step 5 (`--force` + `--fix-instructions`) — a machinery mismatch found by task 1 is a judgment stop, not a retry candidate.
   **If you arrived via full `/skill:implement` auto mode:** its merge-point check fires for `master` first — plans 04-01..04-04 are executed and the new-format grep misses because they landed via the transitional old-format bubbles `fcbd83f`/`4bce285`/`170b994`/`5aac779`. The resulting `HALT: no agent branch 'agent/04-unattended-implement-loop/master' … nothing to merge` is informational: verify with `git log master --oneline -12` that the phase-04 commits are there, do NOT re-run merge-back for master (each run burns one of its 3 merge attempts), never fabricate that branch — proceed to this plan's dispatch.

4. **Gate:** commit the SUMMARY docs-side, then merge progressEdd's agent branch:

   ```bash
   git add -- .planning/phases/04-unattended-implement-loop/04-FX1-SUMMARY.md
   git commit -m "chore(04-unattended-implement-loop): 04-FX1 executed — summary recorded"
   bash .agents/skills/shippEdd/implement/scripts/merge-back.sh .planning 04 unattended-implement-loop progressEdd
   ```

   Expect `merged 04-unattended-implement-loop/progressEdd → progressEdd (<sha>) · worktree removed · branch agent/04-unattended-implement-loop/progressEdd deleted` — that commit is the missing inaugural-run merge evidence.

5. **Post-merge proof** (record the output for the re-review):

   ```bash
   git log progressEdd --merges --grep 'merge(04-unattended-implement-loop/progressEdd):' --format='%h %s' | head -n1
   ```

   must print the new-format merge. Then re-run `/skill:review` in a fresh session to verify the gap closed and flip statuses.

**cwd note:** your agent worktree is a fork of `progressEdd` — the full repo tree sits at your worktree root; all repo paths below are worktree-root-relative. The files you edit (`.planning/REQUIREMENTS.md`, `.planning/phases/04-unattended-implement-loop/{04-05-SUMMARY.md,VERIFICATION.md}`) are tracked on progressEdd and present in your fork.

**Narrow supersession (task 1 only, read-only):** the dispatch prompt already directs your completion-marker moves into your run dir; for task 1 you may additionally READ files under your own run dir `${TMPDIR:-/tmp}/shippEdd/04-unattended-implement-loop/04-FX1/` and the sibling per-target dir `${TMPDIR:-/tmp}/shippEdd/04-unattended-implement-loop/progressEdd/`. Nothing outside your worktree is written by you at any point (the SUMMARY destination excepted, per the dispatch prompt).

## Tasks

<task>
<name>Task 1: Verify this run IS the new auto loop — capture the layer-2 observables (go/no-go)</name>
<files>(none in the repo — evidence capture under $TMPDIR; deliverable is the go/no-go record that feeds tasks 2–3 and the SUMMARY)</files>
<action>
This task is the gate for the whole fix: the evidence AUTO-07 layer 2 needs is THIS run's own dispatch shape. Run, from your worktree root:

```bash
git branch --show-current
# expect exactly: agent/04-unattended-implement-loop/progressEdd
```

Then inspect your run dir (read-only, per the supersession above):

```bash
run="${TMPDIR:-/tmp}/shippEdd/04-unattended-implement-loop/04-FX1"
grep -F 'of at most 3' "$run/04-FX1.prompt.md"          # attempt bound in the prompt text
grep -F 'agent/04-unattended-implement-loop/progressEdd' "$run/04-FX1.prompt.md"
cat "$run/04-FX1.target"                                 # expect: progressEdd
wc -l < "$run/attempts"                                  # the attempt ledger (1 on a clean run)
ls "${run%/*}/progressEdd/"                              # the per-target dir: fork-base, worktree/
git rev-parse --short "$(cat "${run%/*}/progressEdd/fork-base")"   # fork-base short SHA
```

**No-go path (any observable wrong = the run is not the new loop):** if `git branch --show-current` prints anything other than `agent/04-unattended-implement-loop/progressEdd`, or the prompt lacks the attempt bound, or `04-FX1.target`/`attempts`/the sibling `progressEdd/` dir is missing — this execution cannot mint the evidence. Stop: do NOT run tasks 2–3; write the SUMMARY with `status: blocked`, naming the mismatching observable verbatim. That is a judgment stop (the orchestrator re-dispatches properly via the scripts — see the orchestrator note), not a retry candidate.

**Go path:** record the four observables verbatim — (a) the branch name, (b) the prompt's attempt sentence (with the actual attempt number; expected `attempt 1 of at most 3`), (c) `04-FX1.target`'s content plus the attempts-ledger line count, (d) the fork-base short SHA — they go into the SUMMARY's `key-decisions` (the durable record; `$TMPDIR` is transient by design). This task changes nothing and commits nothing.
</action>
<verify>cd "$(git rev-parse --show-toplevel)" && [ "$(git branch --show-current)" = "agent/04-unattended-implement-loop/progressEdd" ] && grep -F 'of at most 3' "${TMPDIR:-/tmp}/shippEdd/04-unattended-implement-loop/04-FX1/04-FX1.prompt.md" && grep -F 'agent/04-unattended-implement-loop/progressEdd' "${TMPDIR:-/tmp}/shippEdd/04-unattended-implement-loop/04-FX1/04-FX1.prompt.md" && [ "$(cat "${TMPDIR:-/tmp}/shippEdd/04-unattended-implement-loop/04-FX1/04-FX1.target")" = "progressEdd" ] && [ -f "${TMPDIR:-/tmp}/shippEdd/04-unattended-implement-loop/04-FX1/attempts" ] && [ -f "${TMPDIR:-/tmp}/shippEdd/04-unattended-implement-loop/progressEdd/fork-base" ] && [ -z "$(git status --porcelain)" ]</verify>
<acceptance_criteria>
- `git branch --show-current` in the worktree prints `agent/04-unattended-implement-loop/progressEdd` (per-target branch naming, AUTO-05)
- The run dir shows the NEW layout: `04-FX1.prompt.md` contains `of at most 3` and `agent/04-unattended-implement-loop/progressEdd`; `04-FX1.target` contains `progressEdd`; the `attempts` ledger exists; the sibling `progressEdd/` dir holds `fork-base`
- Nothing in the repo changed: `git status --porcelain` empty after this task
- On any mismatch the executor stops (blocked SUMMARY naming the observable) instead of running tasks 2–3; the four observables are recorded verbatim in the SUMMARY's `key-decisions` on the go path
</acceptance_criteria>
</task>

<task>
<name>Task 2: Correct the false AUTO-07 layer-2 claim in 04-05-SUMMARY.md</name>
<files>.planning/phases/04-unattended-implement-loop/04-05-SUMMARY.md</files>
<action>
Idempotence first: if the file already contains exactly two `**Correction (04-FX1):**` markers and the `**Correction (04-FX1, post-verification):**` paragraph, this task is done — verify and commit nothing.

Annotate, never erase — the record must show what was claimed and what is true. Three edits, nothing else (frontmatter untouched):

**Edit 1 — `## Accomplishments`, last bullet.** Replace:

```markdown
- This plan was itself executed by the canonical auto-mode loop (AUTO-07 layer 2, the inaugural live run) — the loop that this plan's merge now refreshes into the running copy.
```

with:

```markdown
- ~~This plan was itself executed by the canonical auto-mode loop (AUTO-07 layer 2, the inaugural live run) — the loop that this plan's merge now refreshes into the running copy.~~ **Correction (04-FX1):** false as written — this plan ran on the transitional per-plan machinery (per-plan prompt and run dir, branch `agent/04-05`, gate merge message `merge(04-05): plan 04-05 into progressEdd`), as verification run 04-verify established from all four observables; the inaugural auto-mode live run (AUTO-07 layer 2) is fix plan 04-FX1.
```

**Edit 2 — `## Next phase readiness`, last line.** Replace:

```markdown
- Phase 04's own execution (this run included) is AUTO-07 layer 2's live proof; `/skill:review` owns declaring it.
```

with:

```markdown
- ~~Phase 04's own execution (this run included) is AUTO-07 layer 2's live proof~~ **Correction (04-FX1):** AUTO-07 layer 2's live proof is the 04-FX1 run — dispatched, watched, and merged per-target by the refreshed loop (per-target prompt and run-dir layout; gate merge `merge(04-unattended-implement-loop/progressEdd):`); `/skill:review` verifies it.
```

**Edit 3 — append at the end of `## Decisions & deviations`** (after the paragraph ending "…Future sanity blocks should grep a fragment that survives wrapping.", before `## Next phase readiness`):

```markdown
**Correction (04-FX1, post-verification):** verification run 04-verify found this SUMMARY's AUTO-07 layer-2 claim false — this plan was dispatched and merged by the transitional per-plan machinery (per-plan prompt and run dir, branch `agent/04-05`, gate merge `a9a3bc5` with message `merge(04-05): plan 04-05 into progressEdd`), not the new auto-mode loop. The inaugural auto-mode live run is fix plan 04-FX1 itself; both struck-through corrections above carry the corrected statements. Nothing else in this record changes.
```

Commit atomically:

```bash
git add .planning/phases/04-unattended-implement-loop/04-05-SUMMARY.md
git commit -m "fix(04-FX1): correct 04-05 SUMMARY's false AUTO-07 layer-2 claim (verification gap 1)"
```
</action>
<verify>cd "$(git rev-parse --show-toplevel)" && grep -cF '**Correction (04-FX1):**' .planning/phases/04-unattended-implement-loop/04-05-SUMMARY.md | grep -qx 2 && grep -F '**Correction (04-FX1, post-verification):**' .planning/phases/04-unattended-implement-loop/04-05-SUMMARY.md && grep -F 'the inaugural auto-mode live run (AUTO-07 layer 2) is fix plan 04-FX1' .planning/phases/04-unattended-implement-loop/04-05-SUMMARY.md && grep -F '~~This plan was itself executed by the canonical auto-mode loop' .planning/phases/04-unattended-implement-loop/04-05-SUMMARY.md && git show --stat --oneline HEAD | grep -F 'fix(04-FX1)'</verify>
<acceptance_criteria>
- `04-05-SUMMARY.md` contains exactly two inline `**Correction (04-FX1):**` markers (Accomplishments bullet and Next-phase-readiness line, original claims struck through with `~~…~~`) and the `**Correction (04-FX1, post-verification):**` paragraph closing `## Decisions & deviations`
- The frontmatter (`status`/`duration`/`key-files`/`requirements-completed`/`key-decisions`/`deviations`) is byte-identical to before
- One commit `fix(04-FX1): correct 04-05 SUMMARY's false AUTO-07 layer-2 claim (verification gap 1)` touching exactly that file
</acceptance_criteria>
</task>

<task>
<name>Task 3: Record the 04-FX1 run as AUTO-07 layer-2 evidence — REQUIREMENTS amendment + VERIFICATION resolution</name>
<files>.planning/REQUIREMENTS.md, .planning/phases/04-unattended-implement-loop/VERIFICATION.md</files>
<action>
Idempotence first: if REQUIREMENTS.md already carries the `**Amended by 04-FX1 (fix):**` note and VERIFICATION.md the `**Resolution (04-FX1,` paragraph, this task is done — verify and commit nothing.

**Edit 1 — `.planning/REQUIREMENTS.md`, AUTO-07 row (v4 table).** Append the amendment inside the requirement cell, between `…as the inaugural live run` and ` | 04-unattended-implement-loop | Pending |`. The full target row:

```markdown
| AUTO-07 | Proof, two layers: a deterministic temp-repo simulation with scripted executors including a deliberate failure case (bounded recovery exercised, clean stop verified), then phase 04's own remaining waves executed via the new auto mode as the inaugural live run. **Amended by 04-FX1 (fix):** layer 2's inaugural live run is fix plan 04-FX1 itself — dispatched, watched, and merged per-target by the refreshed canonical loop (attempt-bounded per-target prompt and run-dir layout; gate merge `merge(04-unattended-implement-loop/progressEdd):`); phase 04's own waves ran on the transitional per-plan machinery, flagged by verification run 04-verify and corrected in 04-05-SUMMARY.md | 04-unattended-implement-loop | Pending |
```

Nothing else in the file changes — status cells stay `Pending` (`/skill:review` flips them), and the AUTO-01..06/08 rows and the Deferred entry are untouched.

**Edit 2 — `.planning/phases/04-unattended-implement-loop/VERIFICATION.md`.** Under `## Gaps found`, append immediately after the gap-1 paragraph (the one ending "…also correct or annotate the false claim in 04-05-SUMMARY.md's Accomplishments/Next-phase-readiness lines.") — substituting the actual date (`date -u +%Y-%m-%d`) and the actual attempt sentence captured in task 1 (expected `(attempt 1 of at most 3)`):

```markdown
**Resolution (04-FX1, <date>):** gap 1 closed by fix plan 04-FX1, run end-to-end through the refreshed auto loop — canonical `dispatch-plan.sh` + `watch-wave.sh` + per-target `merge-back.sh` — as the inaugural auto-mode live run (AUTO-07 layer 2): per-target prompt carrying "(attempt <N> of at most 3)" and branch `agent/04-unattended-implement-loop/progressEdd`; new run-dir layout (`attempts` ledger, `04-FX1.target`, sibling per-target `progressEdd/` dir holding `fork-base` and the shared worktree); and, at this plan's gate, the per-target merge `merge(04-unattended-implement-loop/progressEdd): phase 04-unattended-implement-loop into progressEdd` on progressEdd — this annotation reaches progressEdd only through that very merge. The false claim in 04-05-SUMMARY.md is struck and corrected in place; REQUIREMENTS.md's AUTO-07 row carries the matching `**Amended by 04-FX1 (fix):**` note. Master's plans 04-01..04-04 remain landed via their transitional old-format merge bubbles (`fcbd83f`, `4bce285`, `170b994`, `5aac779`) — real merges carrying the work; no history was rewritten to fit the new message template.
```

The verdict line and every table above `## Gaps found` stay untouched — the re-review re-derives them from the repo.

Commit atomically:

```bash
git add .planning/REQUIREMENTS.md .planning/phases/04-unattended-implement-loop/VERIFICATION.md
git commit -m "chore(04-FX1): record the 04-FX1 inaugural auto-mode run as AUTO-07 layer-2 evidence"
```
</action>
<verify>cd "$(git rev-parse --show-toplevel)" && grep -cF '**Amended by 04-FX1 (fix):**' .planning/REQUIREMENTS.md | grep -qx 1 && grep -F 'inaugural live run is fix plan 04-FX1 itself' .planning/REQUIREMENTS.md && grep -F '**Resolution (04-FX1,' .planning/phases/04-unattended-implement-loop/VERIFICATION.md && grep -F 'no history was rewritten to fit the new message template' .planning/phases/04-unattended-implement-loop/VERIFICATION.md && git show --stat --oneline HEAD | grep -F 'chore(04-FX1)'</verify>
<acceptance_criteria>
- REQUIREMENTS.md's AUTO-07 row — and only that row — gains the `**Amended by 04-FX1 (fix):**` note naming the 04-FX1 run as layer 2's inaugural live proof; exactly one occurrence; every status cell still `Pending`
- VERIFICATION.md's `## Gaps found` section carries the `**Resolution (04-FX1,` paragraph directly under gap 1, embedding the actual date and attempt sentence, naming the three dispatch-side observables, the gate merge format `merge(04-unattended-implement-loop/progressEdd):`, and the master old-format-bubble acceptance
- One commit `chore(04-FX1): record the 04-FX1 inaugural auto-mode run as AUTO-07 layer-2 evidence` touching exactly those two files
</acceptance_criteria>
</task>

## Verification

Before declaring this plan complete:

- [ ] Task 1 verify passes: this run IS the new loop (per-target branch, attempt-bounded prompt, new run-dir layout) — the four observables recorded verbatim, nothing in the repo changed
- [ ] Task 2 verify passes: two struck-through corrections + the post-verification paragraph, one commit; frontmatter untouched
- [ ] Task 3 verify passes: exactly one REQUIREMENTS amendment, the VERIFICATION resolution paragraph, one commit
- [ ] `git status --porcelain` in your worktree is empty (nothing uncommitted)
- [ ] SUMMARY written in full: task 1's four observables under `key-decisions`, both commits under task commits, `requirements-completed: [AUTO-07]` (layer 2 closed by this run), and the deviations noting that the gate merge (the evidence's fourth observable) lands via the orchestrator's merge-back immediately after this SUMMARY is committed

**For the gate/orchestrator (not executor work):** follow the orchestrator note at the top of this plan in order — commit this plan file, clean `.planning/runs/` leftovers, dispatch + watch, commit the SUMMARY docs-side, then `bash .agents/skills/shippEdd/implement/scripts/merge-back.sh .planning 04 unattended-implement-loop progressEdd` and confirm the post-merge grep prints the new-format `merge(04-unattended-implement-loop/progressEdd):` commit. Then re-run `/skill:review` in a fresh session (clear this context first; everything durable is on disk) to verify the gap closed and flip statuses. STATE.md/ROADMAP.md remain the orchestrator's/review's own — this plan's tasks never touch them.

<!--
Fix plan for verification gap 1 (04-verify): AUTO-07 layer 2 was never minted —
04-05 ran on the transitional per-plan machinery while claiming otherwise. The
fix is self-instantiating: dispatching THIS plan through the refreshed loop
(dispatch-plan.sh + watch-wave.sh + per-target merge-back.sh) produces the
missing inaugural-run evidence, and the executor's tasks make the records
honest (04-05-SUMMARY correction, REQUIREMENTS AUTO-07 amendment, VERIFICATION
resolution). After the gate merge, the SKILL.md landed-oracle recognizes
04-05 and 04-FX1 on progressEdd via the one per-target bubble; master's four
plans stay landed via their real old-format bubbles (documented, not rewritten).
-->
