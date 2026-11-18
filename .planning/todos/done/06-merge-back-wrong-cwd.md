---
name: merge-back-wrong-cwd
captured: 2026-11-17
what: "merge-back.sh deletes the agent branch from the orchestrator's cwd, so every merge-back halts after a successful merge"
severity: medium
context: "git branch -d verifies ancestry against HEAD, not the target branch — run it via git -C from the target's checkout instead"
files:
  - .agents/skills/shippEdd/implement/scripts/merge-back.sh:63
---

## Problem

`merge-back.sh` line 63 runs `git branch -d "$agent"` from the orchestrator's checkout (this repo: `progressEdd`). `git branch -d` refuses unless the branch is merged into the **current HEAD** (or its upstream) — not into the merge target. In this repo's worktree layout every target branch is checked out elsewhere (`02-worktrees/master`, …), so the delete is refused even right after a clean `--no-ff` merge into the target, and the script exits 1 with `HALT: branch agent/NN-YY could not be deleted after merge`. Observed on phase 03 wave 2 (03-02): the merge itself landed (`e61f30d` on master, `agent/03-02` a verified ancestor), worktree removed and pruned — then the halt stranded the branch ref. Every wave in this repo will halt the same way, each costing a manual cleanup and an interrupt of the implement loop.

## Solution

Redirect the delete to the target's checkout — the script already resolves it (`$wt`, via `checkout_of`): change line 63 to `git -C "$wt" branch -d "$agent"`. One-word fix; the ancestry check then passes because `$wt`'s HEAD is the target branch that just absorbed the merge. Worktree removal and `git worktree prune` (lines 59–62) are already correct and run repo-wide, so only the branch delete needs the `-C`.

## Research

- `merge-back.sh:63`: `git branch -d "$agent" || { echo "HALT: … could not be deleted after merge — inspect manually" >&2; exit 1; }` — runs in cwd, no `-C`
- `git branch -d` semantics: safe delete requires the branch to be reachable from HEAD or its upstream — the target branch containing it is irrelevant from another checkout
- Evidence from 03-02's wave-2 merge-back (this phase, 2026-11-17): precheck → `02-worktrees/master`, merge by 'ort' (4 dispatcher files, 20+/17-), then `error: the branch 'agent/03-02' is not fully merged` from the `progressEdd` checkout
- Proof of fix: `git merge-base --is-ancestor agent/03-02 master` → YES; manual `git -C 02-worktrees/master branch -d agent/03-02` → `Deleted branch agent/03-02 (was a479f71)` — the safe `-d` succeeds from the target checkout
- Repo layout (`git worktree list`): orchestrator on `progressEdd` at repo root; `master` and `empty-master` in `02-worktrees/`; per-plan agent worktrees under `$TMPDIR` — so orchestrator cwd never equals the target checkout

## Decisions

- Keep the safe `-d` (never `-D`) — just redirect the cwd with `git -C "$wt"`; forced deletes would mask real regressions
- Fix scope is line 63 only — worktree remove/prune behavior stays as-is
