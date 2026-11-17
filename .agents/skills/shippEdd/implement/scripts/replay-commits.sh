#!/usr/bin/env bash
# shippEdd commit sequencer. Executors never run git — parallel siblings in a
# wave share the working tree, and concurrent git would race on the index lock.
# Each executor records a per-task commit spec instead; this script replays the
# specs sequentially (one commit per task line, plans in glob order) and stamps
# each plan's .done marker so re-entry never double-commits. Only plan markers
# (NN-YY.done) are replayed; per-task markers (NN-YY-TT.done) are sequenced by
# the implement gate, not here.
#
# Worktree routing: a spec whose paths all share a 02-worktrees/<name>/ prefix
# (that dir being a git worktree) commits inside that worktree's own git —
# the root checkout ignores 02-worktrees/* by convention; canonical work lands
# on the worktree's branch. Mixed/other paths commit in the root as before.
#
# Usage: replay-commits.sh     (no args — scans <state>/runs/*.done)
# TSV line: <commit message><TAB><path1,path2,...>  — message single-line, no
# tabs; paths repo-relative, comma-separated; blank/pathless lines are skipped.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
runs="$root/$("$here/state-dir.sh")/runs"
cd "$root"

for marker in "$runs"/[0-9][0-9]-[0-9][0-9].done; do  # plan markers only — NN-YY.done, not NN-YY-TT.done
  [ -f "$marker" ] || continue
  grep -q '^committed ' "$marker" && continue                 # already replayed
  id="$(basename "${marker%.done}")"
  tsv="${marker%.done}.commits.tsv"
  msgs=(); specs=()
  if [ -f "$tsv" ]; then
    while IFS=$'\t' read -r msg paths || [ -n "${msg:-}" ]; do
      [ -n "${msg:-}" ] && [ -n "${paths:-}" ] || continue   # blank / no files
      IFS=',' read -r -a files <<< "$paths"
      for f in "${files[@]}"; do
        if [ ! -e "$f" ] && ! git ls-files --error-unmatch -- "$f" >/dev/null 2>&1; then
          echo "refused: $id commit spec lists a path that does not exist: $f" >&2
          echo "  fix or remove that line in $tsv, then rerun" >&2
          exit 1
        fi
      done
      msgs+=("$msg"); specs+=("$paths")
    done < "$tsv"
  fi
  last="$(git rev-parse --short HEAD)"                        # newest commit sha for the marker
  for i in "${!msgs[@]}"; do                                  # validate all, then commit
    IFS=',' read -r -a files <<< "${specs[$i]}"
    gwd="$root"; pfx=""                                      # route: worktree prefix -> its own git
    case "${files[0]}" in
      02-worktrees/*)
        wt="${files[0]#02-worktrees/}"; wt="${wt%%/*}"
        if [ -n "$wt" ] && [ -e "$root/02-worktrees/$wt/.git" ]; then
          shared=1
          for f in "${files[@]}"; do
            case "$f" in "02-worktrees/$wt/"*) ;; *) shared=0; break ;; esac
          done
          if [ "$shared" -eq 1 ]; then gwd="$root/02-worktrees/$wt"; pfx="02-worktrees/$wt/"; fi
        fi
        ;;
    esac
    rfiles=(); for f in "${files[@]}"; do rfiles+=("${f#"$pfx"}"); done
    git -C "$gwd" add -- "${rfiles[@]}"
    if git -C "$gwd" diff --cached --quiet; then
      echo "skip: $id nothing new to commit: ${msgs[$i]}" >&2 # partial-replay recovery
    else
      git -C "$gwd" commit -q -m "${msgs[$i]}"
      last="$(git -C "$gwd" rev-parse --short HEAD)"
      echo "committed $id: $last ${msgs[$i]}"
    fi
  done
  if [ "${#msgs[@]}" -gt 0 ]; then
    echo "committed $last" >> "$marker"
  else
    echo "committed none" >> "$marker"                        # done, no spec to replay
  fi
done
