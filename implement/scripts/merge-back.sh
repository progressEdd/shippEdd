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
shared="$(cd "$(dirname "$0")/../.." && pwd)/scripts"
state="${1:?usage: merge-back.sh <state-dir> <NN> <slug> <target-branch>}"
nn="${2:?NN required}"; slug="${3:?slug required}"; target="${4:?target branch required}"
agent="agent/$nn-$slug/$target"
tgt_dir="$("$shared/runs-dir.sh" home)/$nn-$slug/$target"
mode="$("$shared/runs-dir.sh" mode)"
disposition="$("$shared/runs-dir.sh" disposition)"
mirror="$shared/gh-mirror.sh"   # MIR-06: closing keywords + guarded close (never-block; absent = no-op)

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
agent_wt="$(git worktree list --porcelain | awk -v want="refs/heads/$agent" '
  /^worktree / { wt = substr($0, 10); bra = ""; det = 0 }
  /^detached/  { det = 1 }
  /^branch /   { bra = substr($0, 8) }
  bra == want && !det { print wt; exit }
')"
if [ "$mode" = branch ]; then
  wt="$root"                      # the main checkout holds the agent branch
  agent_wt=""
  dirty="$(git -C "$wt" status --porcelain)"
  if [ -n "$dirty" ] && printf '%s\n' "$dirty" | grep -v " $state/phases/" | grep -q .; then
    echo "HALT: main checkout '$wt' is dirty beyond phase artifacts — commit or stash first" >&2; exit 1
  fi
else
  wt="$(checkout_of)"
  [ -n "$wt" ] || { echo "HALT: target '$target' is checked out nowhere — the merge needs its checkout" >&2; exit 1; }
  [ -z "$(git -C "$wt" status --porcelain 2>/dev/null)" ] || { echo "HALT: target checkout '$wt' is dirty — commit or stash it first" >&2; exit 1; }
fi
[ -f "$tgt_dir/fork-base" ] || { echo "HALT: fork base not recorded at $tgt_dir/fork-base (tmp wiped?); merge-base($agent,$target) = $(git merge-base "$agent" "$target" | cut -c1-7) — record it there to proceed" >&2; exit 1; }
echo "precheck $nn-$slug/$target → $target (checkout ${wt#"$root"/})"

fork_base="$(cat "$tgt_dir/fork-base")"
mb="$(git merge-base "$agent" "$target")"
if [ "$mb" != "$fork_base" ]; then
  echo "DRIFT: $agent stranded — forked at $(git rev-parse --short "$fork_base"), but merge-base with $target is $(git rev-parse --short "$mb"); worktree ${agent_wt:-$tgt_dir} (agent branch checkout) left in place. Recover: inspect $agent, then either re-record $tgt_dir/fork-base (if $target's advance is legitimate) or re-plan the slice." >&2
  exit 1
fi

if [ "$disposition" = pr ]; then
  remote="$(git remote | head -n1)"
  pr_fallback() {  # DISP-05 + MIR-06 receipt fallback (the run never fails); when gh fails but
    # git push works, push anyway so a human can open the PR (receipt shows the compare URL)
    local why="$1"
    if [ -n "$remote" ] && git push "$remote" "$agent" 2>/dev/null; then
      echo "PR unavailable: $why (disposition: pr) — branch pushed; open the PR by hand"
      echo "  compare: $(compare_url)"
      echo "  branch $agent pushed to $remote; branch kept (PR head)"
      if [ -n "$agent_wt" ]; then
        git worktree remove "$agent_wt" || true
        git worktree prune
      fi
      exit 0
    fi
    echo "PR unavailable: $why (disposition: pr) — nothing merged, nothing deleted"
    echo "  branch $agent stays${agent_wt:+ (worktree $agent_wt left in place)}"
    echo "  options: open the PR by hand — git push ${remote:-<remote>} $agent && gh pr create --base $target --head $agent"
    echo "           or set \"disposition\": \"auto-merge\" in $state/config.json and re-run merge-back"
    exit 0
  }
  compare_url() {  # best-effort web compare URL from the first remote (receipt aid; not gh identity)
    local u host repo
    u="$(git remote get-url "$remote" 2>/dev/null || true)"
    case "$u" in
      git@*:*)
        host="${u%%:*}"; host="${host#git@}"
        repo="${u##*:}" ;;
      ssh://git@*)
        host="$(printf '%s' "$u" | sed -e 's|^ssh://git@||' -e 's|[/:].*||')"
        repo="$(printf '%s' "$u" | sed -e 's|^ssh://git@[^/]*[:/]||')" ;;
      https://*)
        host="$(printf '%s' "$u" | sed -e 's|^https://||' -e 's|/.*||')"
        repo="$(printf '%s' "$u" | sed -e 's|^https://[^/]*/||')" ;;
      *)
        printf 'git remote get-url %s' "${remote:-?}"; return ;;
    esac
    repo="${repo%.git}"
    printf 'https://%s/%s/compare/%s...%s' "$host" "$repo" "$target" "$agent"
  }
  command -v gh >/dev/null 2>&1 || pr_fallback "gh CLI not found"
  [ -n "$remote" ] || pr_fallback "no git remote"
  gh auth status >/dev/null 2>&1 || pr_fallback "gh not authenticated"
  if url="$(gh pr view "$agent" --json url -q .url 2>/dev/null)" && [ -n "$url" ]; then
    echo "PR $url (already open) — agent branch $agent; nothing to do (disposition: pr)"
    exit 0
  fi
  git push "$remote" "$agent" || pr_fallback "git push to $remote failed"
  body="shippEdd merge-back opened this PR (disposition: pr). Agent branch \`$agent\`, forked from \`$target\` at $(git rev-parse --short "$fork_base")."
  if [ -x "$mirror" ]; then
    if closes="$(bash "$mirror" "$state" "$nn" "$slug" pr-body "$target" 2>/dev/null)" && [ -n "$closes" ]; then
      body="$body

Closes the phase's plan issues (GitHub mirror):
$closes"
    fi
  fi
  url="$(gh pr create --base "$target" --head "$agent" \
        --title "Phase $nn-$slug: merge into $target" \
        --body "$body")" \
    || pr_fallback "gh pr create failed"
  if [ -n "$agent_wt" ]; then
    git worktree remove "$agent_wt" \
      || { echo "HALT: worktree $agent_wt is not clean to remove — inspect it, remove it manually, then delete branch $agent" >&2; exit 1; }
    git worktree prune
  fi
  echo "PR $url — branch $agent pushed to $remote (disposition: pr); worktree removed; branch kept (PR head)"
  exit 0
fi
if [ "$mode" = branch ]; then
  git -C "$wt" checkout --quiet "$target" \
    || { echo "HALT: main checkout '$wt' could not switch back to $target — resolve by hand" >&2; exit 1; }
fi
if ! git -C "$wt" merge --no-ff --no-edit "$agent" -m "merge($nn-$slug/$target): phase $nn-$slug into $target"; then
  git -C "$wt" merge --abort
  if [ "$mode" = branch ]; then
    git -C "$wt" checkout --quiet "$agent"   # restore the stranded branch's checkout
  fi
  echo "CONFLICT: $agent stranded — worktree ${agent_wt:-$tgt_dir} (agent branch checkout), target $target. Recover: merge $agent into $target by hand in $wt, or resolve the collision and re-dispatch the plan." >&2
  exit 1
fi
if [ -n "$agent_wt" ]; then
  git worktree remove "$agent_wt" \
    || { echo "HALT: worktree $agent_wt is not clean to remove — inspect it, remove it manually, then delete branch $agent" >&2; exit 1; }
fi
git worktree prune
git -C "$wt" branch -d "$agent" \
  || { echo "HALT: branch $agent could not be deleted after merge — inspect manually" >&2; exit 1; }
echo "merged $nn-$slug/$target → $target ($(git rev-parse --short "$target")) · worktree removed · branch $agent deleted"
if [ -x "$mirror" ]; then
  bash "$mirror" "$state" "$nn" "$slug" close-plan "$target" >&2 || true   # MIR-06: guarded, state-checked, idempotent, never-block
fi
