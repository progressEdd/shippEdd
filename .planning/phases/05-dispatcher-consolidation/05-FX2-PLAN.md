---
wave: 6
depends_on: ["05-FX1"]
target: progressEdd
---

# Plan 05-FX2: vendored refresh — the gap-1 fix rides to the running copy with byte-parity (DISP-01 vendored half, DISP-08 end-state)

**Objective:** DISP-08's law is that the phase **ends** with the vendored copy byte-identical to canonical master, and verification run 05-verify already proved `diff -r --exclude=.git .agents/skills/shippEdd 02-worktrees/master` silent at `PARITY OK`. 05-FX1 (wave 5, master) now adds a two-line change to `bootstrap/README.md` — without this plan, the re-verification's DISP-08 parity diff fails on exactly that file and the running copy keeps telling users to run a script that no longer exists. This plan squash-merges master into `.agents/skills/shippEdd/` (the 05-06 flow at one-commit scale), proves byte-parity both ways, and re-runs the selftest sanity against the refreshed copy. Master gained exactly one commit since 05-06's refresh; expect a one-file delta.

**cwd note:** your agent worktree is a fork of `progressEdd` — the full repo tree (`.planning/`, `.agents/`, `AGENTS.md`, …) sits at your worktree root; all repo paths below are worktree-root-relative. The canonical master worktree is NOT inside your fork (`02-worktrees/` contents are untracked); resolve the main checkout root with:

```bash
main_root="$(dirname "$(cd "$(git rev-parse --git-common-dir)" && pwd)")"
```

(sanity-check it prints a path ending in `shippEdd` — the repo root holding `02-worktrees/master`.)

**Narrow persona supersession (this plan only, read-only):** the preflight and parity checks run read-only git against `$main_root` (`git -C … status`, `git -C … ls-tree`, `diff -r` on the master worktree). The executor persona's "no git outside your worktree" law is superseded for exactly these reads; all writes happen inside your worktree via the subtree merge itself. Nothing else outside your worktree is written by you at any point.

## Tasks

<task>
<name>Task 1: Preflight (master carries the fix), subtree squash-merge, byte-parity proof, selftest sanity</name>
<files>.agents/skills/shippEdd/ (whole subtree, via git operations)</files>
<action>
Idempotence first: if the vendored `bootstrap/README.md` already carries both `.agents/skills/shippEdd/scripts/state-dir.sh` references AND the parity checks below pass, this task is done — run the verify, record `nothing to do` in the SUMMARY's deviations.

**1. Preflight (all from your worktree root):**

```bash
git status --porcelain                          # expect empty
main_root="$(dirname "$(cd "$(git rev-parse --git-common-dir)" && pwd)")"
git log master --oneline -5                     # context: expect the fix(05-FX1) commit (or the master merge bubble carrying it)
git -C "$main_root" status --porcelain -- .agents/skills/shippEdd   # sanctioned read-only check — expect empty
```

Third command non-empty = uncommitted interim vendored deltas in the main checkout your fork cannot carry — do not proceed: SUMMARY `status: blocked`, name the dirty paths, recovery = orchestrator commits them then re-dispatches with `--force`.

**2. The load-bearing guard — master's ref must carry the 05-FX1 fix:**

```bash
[ "$(git show master:bootstrap/README.md | grep -cF '.agents/skills/shippEdd/scripts/')" -eq 2 ] \
  || { echo "GUARD FAILED: master does not carry the 05-FX1 fix"; git log master --oneline -5; }
```

If the guard fails, the 05-FX1 agent branch is an unmerged PR head (disposition pr; origin exists) or stranded by the receipt fallback — refreshing now would silently re-ship the stale README. Stop: SUMMARY `status: blocked`, recovery verbatim: "orchestrator lands the fix on master's ref — merge the open PR then fast-forward the master worktree (`git -C 02-worktrees/master fetch origin && git -C 02-worktrees/master merge --ff-only origin/master`), or set `"disposition": "auto-merge"` in `<state>/config.json` and re-run master's merge-back — then re-dispatch this plan with `--force`."

**3. The refresh:**

```bash
git subtree merge --prefix=.agents/skills/shippEdd master --squash
```

On conflicts (none expected — a docs-only delta at parity): resolve in favor of master: `git checkout --theirs -- .agents/skills/shippEdd && git add -A .agents/skills/shippEdd && git commit --no-edit`. If `git subtree` misbehaves inside a linked worktree, take the minimum deviation that reaches the same end state and record it (04-05/05-06 precedent). Deliverables are the commits these commands create (subtree squash + merge, auto-generated messages); do not hand-commit over them. Expected shape: one content delta — `.agents/skills/shippEdd/bootstrap/README.md`, 2 insertions/2 deletions.

**4. Parity — two sanctioned forms, primary first:**

```bash
diff -r --exclude=.git .agents/skills/shippEdd "$main_root/02-worktrees/master" && echo "PARITY OK"
```

If `diff -r` reports `Only in "$main_root/02-worktrees/master"` lines, check `git -C "$main_root/02-worktrees/master" status --porcelain` (read-only): paths reported as untracked (`??`) are worktree junk (the 05-verify run once left an empty `.planning/` there), not master content — never `git add` them, never write into that worktree. Prove tracked-content parity instead (mode + blob + path, junk-immune):

```bash
wt="$main_root/02-worktrees/master"
diff <(git -C "$wt" ls-tree -r HEAD --format='%(objectmode) %(objectname) %(path)' | LC_ALL=C sort) \
     <(git ls-tree -r HEAD --format='%(objectmode) %(objectname) %(path)' -- .agents/skills/shippEdd \
       | sed 's#^\([0-9]* [0-9a-f]*\) \.agents/skills/shippEdd/#\1 #' | LC_ALL=C sort) \
  && echo "PARITY OK (tracked content; worktree diff showed only untracked junk)"
```

Record which form ran, and any junk paths, in the SUMMARY's deviations. Any real content difference on either form = not at parity — investigate and record a deviation before proceeding.

**5. Sanity — the fix actually rode, and the suite still proves itself:**

```bash
grep -qF 'Everything resolves through `.agents/skills/shippEdd/scripts/state-dir.sh`; the toggles' .agents/skills/shippEdd/bootstrap/README.md
grep -qF '- Running `.agents/skills/shippEdd/scripts/state-dir.sh` prints exactly one line' .agents/skills/shippEdd/bootstrap/README.md
[ -z "$(grep -n 'scripts/state-dir.sh' .agents/skills/shippEdd/bootstrap/README.md | grep -vF '.agents/skills/shippEdd/scripts/state-dir.sh')" ]
bash .agents/skills/shippEdd/scripts/auto-selftest.sh 2>&1 | tail -n 2
```

Expect `SELFTEST PASSED` (it sandboxes itself under `$TMPDIR`; nothing in the repo is touched). Record the tally line verbatim in the SUMMARY's `key-decisions`.
</action>
<verify>cd "$(git rev-parse --show-toplevel)" && main_root="$(dirname "$(cd "$(git rev-parse --git-common-dir)" && pwd)")" && wt="$main_root/02-worktrees/master" && [ "$(git show master:bootstrap/README.md | grep -cF '.agents/skills/shippEdd/scripts/')" -eq 2 ] && diff <(git -C "$wt" ls-tree -r HEAD --format='%(objectmode) %(objectname) %(path)' | LC_ALL=C sort) <(git ls-tree -r HEAD --format='%(objectmode) %(objectname) %(path)' -- .agents/skills/shippEdd | sed 's#^\([0-9]* [0-9a-f]*\) \.agents/skills/shippEdd/#\1 #' | LC_ALL=C sort) && grep -qF 'Everything resolves through `.agents/skills/shippEdd/scripts/state-dir.sh`; the toggles' .agents/skills/shippEdd/bootstrap/README.md && [ -z "$(grep -n 'scripts/state-dir.sh' .agents/skills/shippEdd/bootstrap/README.md | grep -vF '.agents/skills/shippEdd/scripts/state-dir.sh')" ] && bash .agents/skills/shippEdd/scripts/auto-selftest.sh 2>&1 | tail -n 1 | grep -qF 'SELFTEST PASSED' && [ -z "$(git status --porcelain .agents/skills/shippEdd)" ] && echo "REFRESH VERIFIED"</verify>
<acceptance_criteria>
- The preflight guard held: `git show master:bootstrap/README.md | grep -cF '.agents/skills/shippEdd/scripts/'` printed exactly 2 before the refresh ran (or the run stopped with a blocked SUMMARY carrying the named recovery)
- Tracked-content parity holds: the ls-tree diff (mode+blob+path) is silent — and where no untracked junk exists in the master worktree, `diff -r --exclude=.git .agents/skills/shippEdd "$main_root/02-worktrees/master"` is also silent
- The vendored `bootstrap/README.md` carries both shared-path lines; `grep -n 'scripts/state-dir.sh' … | grep -vF '.agents/skills/shippEdd/scripts/state-dir.sh'` is empty; `grep -cF '.agents/skills/shippEdd/scripts/'` prints exactly 2
- `bash .agents/skills/shippEdd/scripts/auto-selftest.sh` prints `SELFTEST PASSED` against the refreshed copy (tally recorded in the SUMMARY)
- `git log --oneline -3` shows the subtree squash(+merge) commits; `git status --porcelain .agents/skills/shippEdd` is empty; the verify ends `REFRESH VERIFIED`
</acceptance_criteria>
</task>

## Verification

Before declaring this plan complete:

- [ ] The Task 1 verify runs clean and ends `REFRESH VERIFIED`; the parity form that ran (worktree diff or tracked-content fallback) and any junk paths are recorded in deviations
- [ ] `git log master --oneline -5` still shows the canonical commits — master was only read, never rewritten
- [ ] SUMMARY written in full (selftest tally under `key-decisions`, the guard outcome under `key-decisions`) and the marker flipped

**For the gate/orchestrator (not executor work):** after this plan resolves, commit its SUMMARY docs-side, then merge progressEdd's agent branch — `bash .agents/skills/shippEdd/implement/scripts/merge-back.sh .planning 05 dispatcher-consolidation progressEdd`. With no `disposition` key configured, expect the PR-by-default path — a real PR when gh + a remote are available, otherwise the `PR unavailable` receipt (exit 0, branch stays; open by hand or set `"disposition": "auto-merge"` and re-run to land locally). Then re-run `/skill:review` in a fresh session — it re-verifies DISP-01…08 against the refreshed copy; gap 1's probes (the shared-path grep in `bootstrap/README.md`, count ≥ 1) and the DISP-08 parity diff both run there.

<!--
Fix loop wave 6: consumes 05-FX1 through master's merge point — FX2's
depends_on names a master plan while targeting progressEdd, the consumer case
that fires master's merge-back right before this plan dispatches (which is why
its preflight guard can demand the fix on master's ref). Mirrors 05-06's
vendored-refresh flow at one-commit scale; without it the phase cannot re-verify
green (DISP-08's parity diff would fail on bootstrap/README.md). No SKILL.md,
script, selftest, STATE.md, or ROADMAP.md changes — files via git operations only.
-->
