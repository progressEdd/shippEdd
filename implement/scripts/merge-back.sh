#!/usr/bin/env bash
# shippEdd merge-back, per-target (EXEC-07 as revised by AUTO-04/AUTO-05).
# Orchestrator-owned merge of the phase's ONE agent branch for the named
# target into that target branch, in the target's own checkout. Validates the
# recorded fork base before the merge — drift or conflict halts with a
# handoff naming every stranded artifact; nothing is silently resolved.
# Attempts are bounded (2 retries / 3 per agent-branch generation, AUTO-04),
# counted under $TMPDIR; a fresh generation (dispatch-plan.sh re-forks the
# branch) resets the count. Idempotent: an already-landed merge exits 0
# without burning an attempt. After a clean merge: per-target worktree
# removed, branch deleted via `git -C <target checkout> branch -d` (AUTO-01:
# the safe -d verifies ancestry against that checkout's HEAD — never -D).
#
# Usage: merge-back.sh <state-dir> <NN> <slug> <target-branch>
set -euo pipefail

root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
state="${1:?usage: merge-back.sh <state-dir> <NN> <slug> <target-branch>}"
nn="${2:?NN required}"; slug="${3:?slug required}"; target="${4:?target branch required}"
agent="agent/$nn-$slug/$target"
tgt_dir="${TMPDIR:-/tmp}/shippEdd/$nn-$slug/$target"

checkout_of() {  # path of the worktree holding branch $target, or empty
  git worktree list --porcelain | awk -v want="refs/heads/$target" '
    /^worktree / { wt = substr($0, 10); bra = ""; det = 0 }
    /^detached/  { det = 1 }
    /^branch /   { bra = substr($0, 8) }
    bra == want && !det { print wt; exit }
  '
}

git rev-parse --verify --quiet "refs/heads/$target" >/dev/null \
  || { echo "HALT: target branch '$target' not found" >&2; exit 1; }

# Idempotence first: already landed → nothing to do, no attempt burned.
if ! git rev-parse --verify --quiet "refs/heads/$agent" >/dev/null; then
  if git log "$target" --merges --grep "merge($nn-$slug/$target):" -1 --format=%H 2>/dev/null | grep -q .; then
    echo "landed $nn-$slug/$target → $target (already merged — nothing to do)"
    exit 0
  fi
  echo "HALT: no agent branch '$agent' and no merge($nn-$slug/$target): commit on $target — nothing to merge" >&2
  exit 1
fi

# Attempt budget (AUTO-04): 3 invocations per agent-branch generation.
mkdir -p "$tgt_dir"
attempts=0
[ -f "$tgt_dir/merge-attempts" ] && attempts="$(wc -l < "$tgt_dir/merge-attempts" | tr -d '[:space:]')"
if [ "$attempts" -ge 3 ]; then
  echo "BUDGET: merge of $agent at $attempts attempts (2 retries) — refusing; hand the dossier to the human" >&2
  exit 1
fi
printf '%s  attempt %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$((attempts + 1))" >> "$tgt_dir/merge-attempts"

# Prechecks: fail loud, fail early — each halt names its recovery.
wt="$(checkout_of)"
[ -n "$wt" ] || { echo "HALT: target '$target' is checked out nowhere — the merge needs its checkout" >&2; exit 1; }
[ -z "$(git -C "$wt" status --porcelain 2>/dev/null)" ] || { echo "HALT: target checkout '$wt' is dirty — commit or stash it first" >&2; exit 1; }
[ -f "$tgt_dir/fork-base" ] || { echo "HALT: fork base not recorded at $tgt_dir/fork-base (tmp wiped?); merge-base($agent,$target) = $(git merge-base "$agent" "$target" | cut -c1-7) — record it there to proceed" >&2; exit 1; }
echo "precheck $nn-$slug/$target → $target (checkout ${wt#"$root"/})"

fork_base="$(cat "$tgt_dir/fork-base")"
mb="$(git merge-base "$agent" "$target")"
if [ "$mb" != "$fork_base" ]; then
  echo "DRIFT: $agent stranded — forked at $(git rev-parse --short "$fork_base"), but merge-base with $target is $(git rev-parse --short "$mb"); worktree $tgt_dir/worktree left in place. Recover: inspect $agent, then either re-record $tgt_dir/fork-base (if $target's advance is legitimate) or re-plan the slice." >&2
  exit 1
fi
if ! git -C "$wt" merge --no-ff --no-edit "$agent" -m "merge($nn-$slug/$target): phase $nn-$slug into $target"; then
  git -C "$wt" merge --abort
  echo "CONFLICT: $agent stranded — worktree $tgt_dir/worktree, target $target. Recover: merge $agent into $target by hand in $wt, or resolve the collision and re-dispatch the plan." >&2
  exit 1
fi
if [ -d "$tgt_dir/worktree" ]; then
  git worktree remove "$tgt_dir/worktree" \
    || { echo "HALT: worktree $tgt_dir/worktree is not clean to remove — inspect it, remove it manually, then delete branch $agent" >&2; exit 1; }
fi
git worktree prune
git -C "$wt" branch -d "$agent" \
  || { echo "HALT: branch $agent could not be deleted after merge — inspect manually" >&2; exit 1; }
echo "merged $nn-$slug/$target → $target ($(git rev-parse --short "$target")) · worktree removed · branch $agent deleted"
