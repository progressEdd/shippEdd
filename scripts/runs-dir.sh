#!/usr/bin/env bash
# shippEdd runs-placement resolver (DISP-02/03/04/05). One config source —
# <state>/config.json's "runs" section + the sibling "disposition" key — plus
# the repo's worktree topology. Absent config = documented defaults, never a
# guess beyond them (the absent-means-default law).
#
# Usage: runs-dir.sh <what>   — prints exactly one line:
#   home          the runs home (markers, logs, prompt files, ledgers), absolute
#   mode          work-context mode: "worktrees" | "branch"
#   worktree-base the dir agent worktrees are created under (worktrees mode), absolute
#   display       "relative" | "absolute" — how receipts and docs print paths
#   disposition   "pr" | "auto-merge" — how merge-back lands finished work
#
# Documented defaults (absent config): home ${TMPDIR:-/tmp}/shippEdd; mode
# auto-detect (worktrees iff git worktree list reports a linked worktree, else
# branch); worktree-base = detected worktrees folder, else the home; display
# relative; disposition pr.
# Guard: a runs.dir resolving inside the state dir is refused (DISP-02) —
# nothing per-run may ever land under the state dir.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
state="$("$here/state-dir.sh")"

runs_cfg() {  # runs_cfg <key> — prints the "runs.<key>" string value, or nothing
  [ -f "$root/$state/config.json" ] || return 0
  grep -o "\"$1\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" "$root/$state/config.json" \
    | head -n1 | sed -e 's/^[^:]*://' -e 's/[[:space:]]*"//' -e 's/"$//' || true
}
runs_flag() {  # runs_flag <key> — exit 0 iff "<key>": true is set
  [ -f "$root/$state/config.json" ] && grep -q "\"$1\"[[:space:]]*:[[:space:]]*true" "$root/$state/config.json"
}
disposition_cfg() {  # top-level "disposition" — merge-back's landing mode
  [ -f "$root/$state/config.json" ] || return 0
  grep -o '"disposition"[[:space:]]*:[[:space:]]*"[^"]*"' "$root/$state/config.json" \
    | head -n1 | sed -e 's/^[^:]*://' -e 's/[[:space:]]*"//' -e 's/"$//' || true
}

mode_cfg="$(runs_cfg mode)"
dir_cfg="$(runs_cfg dir)"

# --- home ---------------------------------------------------------------------
if [ -n "$dir_cfg" ]; then
  case "$dir_cfg" in
    /*) home="$dir_cfg" ;;
    *)  home="$root/$dir_cfg" ;;
  esac
else
  home="${TMPDIR:-/tmp}/shippEdd"
fi

# --- guard: nothing per-run may live under the state dir (DISP-02) -------------
case "$home/" in
  "$root/$state"/*)
    echo "runs-dir: runs.dir '$dir_cfg' resolves inside the state dir '$state' — nothing per-run may live there (DISP-02)" >&2
    exit 1 ;;
esac

# --- mode + worktree base ------------------------------------------------------
linked="$(git worktree list --porcelain 2>/dev/null | awk '/^worktree /{n++} END{print n+0}')"
detected=""
if [ "$linked" -ge 2 ]; then
  # first LINKED worktree (entry 2+ of the porcelain list); its dirname is the worktrees folder
  first="$(git worktree list --porcelain | awk 'f&&/^worktree /{print substr($0,10);exit} /^worktree /{f=1}')"
  [ -n "$first" ] && detected="$(dirname "$first")"
fi
if [ -n "$mode_cfg" ]; then
  mode="$mode_cfg"
elif [ "$linked" -ge 2 ]; then
  mode="worktrees"
else
  mode="branch"
fi
if [ -n "$dir_cfg" ]; then
  base="$home"
elif [ -n "$detected" ]; then
  base="$detected"
else
  base="$home"
fi

case "${1:?usage: runs-dir.sh home|mode|worktree-base|display|disposition}" in
  home)          printf '%s\n' "$home" ;;
  mode)          printf '%s\n' "$mode" ;;
  worktree-base) printf '%s\n' "$base" ;;
  display)       if runs_flag absolute_paths; then echo absolute; else echo relative; fi ;;
  disposition)   d="$(disposition_cfg)"; printf '%s\n' "${d:-pr}" ;;
  *) echo "unknown query: $1 (want home|mode|worktree-base|display|disposition)" >&2; exit 1 ;;
esac
