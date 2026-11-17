#!/usr/bin/env bash
# shippEdd merge-back (EXEC-07). Orchestrator-owned, serialized merge of each
# plan's agent branch into its target branch, in the order given on the
# command line (plan order). Validates the recorded fork base before every
# merge — any drift (target or agent history moved since dispatch) halts that
# merge with a handoff naming every stranded artifact; nothing is silently
# resolved. Removes each plan's worktree and deletes its branch after a clean
# merge. Never touches STATE.md/ROADMAP.md — the gate's docs-side commit
# follows only after all merges succeed.
#
# Usage: merge-back.sh <state-dir> <NN> <slug> <plan-id> [<plan-id> ...]
set -euo pipefail

root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
state="${1:?usage: merge-back.sh <state-dir> <NN> <slug> <plan-id>...}"
nn="${2:?NN required}"; slug="${3:?slug required}"; shift 3
[ $# -gt 0 ] || { echo "usage: merge-back.sh <state-dir> <NN> <slug> <plan-id>..." >&2; exit 1; }

checkout_of() {  # path of the worktree holding branch $1, or empty
  git worktree list --porcelain | awk -v want="refs/heads/$1" '
    /^worktree / { wt = substr($0, 10); bra = ""; det = 0 }
    /^detached/  { det = 1 }
    /^branch /   { bra = substr($0, 8) }
    bra == want && !det { print wt; exit }
  '
}
plan_of()   { printf '%s\n' "$root/$state/phases/$nn-$slug/$1-PLAN.md"; }
target_of() { local t; t="$(sed -n 's/^target:[[:space:]]*//p' "$(plan_of "$1")" | head -n1)"; printf '%s\n' "${t:-master}"; }
rundir_of() { printf '%s\n' "${TMPDIR:-/tmp}/shippEdd/$nn-$slug/$1"; }

# Pre-check every plan BEFORE the first merge: fail loud, fail early.
for id in "$@"; do
  [ -f "$(plan_of "$id")" ] || { echo "HALT: no plan file for $id: $(plan_of "$id")" >&2; exit 1; }
  target="$(target_of "$id")"; agent="agent/$id"; run_dir="$(rundir_of "$id")"
  git rev-parse --verify --quiet "refs/heads/$agent"  >/dev/null || { echo "HALT: $id has no agent branch '$agent'" >&2; exit 1; }
  git rev-parse --verify --quiet "refs/heads/$target" >/dev/null || { echo "HALT: $id target branch '$target' not found" >&2; exit 1; }
  wt="$(checkout_of "$target")"
  [ -n "$wt" ] || { echo "HALT: $id target '$target' is checked out nowhere — the merge needs its checkout" >&2; exit 1; }
  [ -z "$(git -C "$wt" status --porcelain 2>/dev/null)" ] || { echo "HALT: $id target checkout '$wt' is dirty — commit or stash it first" >&2; exit 1; }
  [ -f "$run_dir/fork-base" ] || { echo "HALT: $id fork base not recorded at $run_dir/fork-base (tmp wiped?); merge-base(agent,$target) = $(git merge-base "$agent" "$target" | cut -c1-7) — record it there to proceed" >&2; exit 1; }
  echo "precheck $id → $target (checkout ${wt#"$root"/})"
done

for id in "$@"; do
  target="$(target_of "$id")"; agent="agent/$id"; run_dir="$(rundir_of "$id")"
  wt="$(checkout_of "$target")"
  fork_base="$(cat "$run_dir/fork-base")"
  mb="$(git merge-base "$agent" "$target")"
  if [ "$mb" != "$fork_base" ]; then
    echo "DRIFT: plan $id stranded — branch $agent forked at $(git rev-parse --short "$fork_base"), but merge-base with $target is $(git rev-parse --short "$mb"); worktree $run_dir/worktree left in place. Recover: inspect $agent, then either re-record $run_dir/fork-base (if $target's advance is legitimate) or re-plan the slice." >&2
    exit 1
  fi
  if ! git -C "$wt" merge --no-ff --no-edit "$agent" -m "merge($id): plan $id into $target"; then
    git -C "$wt" merge --abort
    echo "CONFLICT: plan $id stranded — branch $agent, worktree $run_dir/worktree, target $target. Recover: merge $agent into $target by hand in $wt, or resolve the collision and re-dispatch." >&2
    exit 1
  fi
  if [ -d "$run_dir/worktree" ]; then
    git worktree remove "$run_dir/worktree" \
      || { echo "HALT: $id worktree $run_dir/worktree is not clean to remove — inspect it, remove it manually, then delete branch $agent" >&2; exit 1; }
  fi
  git worktree prune
  git branch -d "$agent" \
    || { echo "HALT: branch $agent could not be deleted after merge — inspect manually" >&2; exit 1; }
  echo "merged $id → $target ($(git rev-parse --short "$target")) · worktree removed · branch $agent deleted"
done
