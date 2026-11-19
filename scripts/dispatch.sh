#!/usr/bin/env bash
# shippEdd shared background dispatcher. Generic by design: the ROLE lives in
# the prompt file, not here, and run state lives wherever --state-dir says.
# Suite-root shared dispatcher (DISP-01): one copy serves every skill. Default
# state dir is the runs home resolved by runs-dir.sh (config-driven; default
# ${TMPDIR:-/tmp}/shippEdd) — NEVER under the planning state dir (DISP-02).
# The detached `pi --print` run flips its own marker (.running -> .done /
# .failed) and is never waited on or post-processed by this script.
#
# Usage:
#   dispatch.sh <id> <prompt-file> [--state-dir <dir>] [--model <model-id>] [--force]
#   dispatch.sh --status [--state-dir <dir>]
#
# Abort semantics: to stop a run, kill the PID recorded in its .running marker.
# An aborted run never flips — a stale .running marker whose PID is dead means
# aborted/failed; the next orchestrator visit offers cleanup (inspect the log,
# then delete the stale marker before redispatching). A MISSING state dir
# means "state unknown" — never a failure: derive plan state from artifacts.
# SHIPPEDD_EXECUTOR_CMD (env): when set, dispatched runs launch that command
# instead of `pi --print` — the deterministic-selftest hook (AUTO-07).
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
default_dir="$("$here/runs-dir.sh" home)"
disp_path() {  # POL-02 + DISP-03 display law: repo-relative unless runs.absolute_paths
  if [ "$("$here/runs-dir.sh" display)" = absolute ]; then printf '%s' "$1"
  else printf '%s' "${1#"$root"/}"; fi   # paths outside the repo root print absolute
}

if [ "${1:-}" = "--status" ]; then
  shift
  runs="$default_dir"
  if [ "${1:-}" = "--state-dir" ]; then runs="${2:?--state-dir needs a value}"; shift 2; fi
  for marker in "$runs"/*.running "$runs"/*.done "$runs"/*.failed \
                "$runs"/*/*.running "$runs"/*/*.done "$runs"/*/*.failed; do
    [ -f "$marker" ] || continue
    id="$(basename "${marker%.*}")"
    pid="$(head -n1 "$marker" 2>/dev/null | grep -oE '[0-9]+' || true)"
    alive=dead
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then alive=alive; fi
    size=0
    [ -f "${runs}/$id.log" ] && size="$(wc -c < "${runs}/$id.log" | tr -d '[:space:]')"
    printf '%s  %s  pid %s %s  log %s bytes  %s\n' "$id" "${marker##*.}" "${pid:-?}" "$alive" "$size" "$(disp_path "${runs}/$id.log")"
  done
  exit 0
fi

usage='usage: dispatch.sh <id> <prompt-file> [--state-dir <dir>] [--model <model-id>] [--force] | dispatch.sh --status [--state-dir <dir>]'
id="${1:?$usage}"
prompt="${2:?$usage}"
shift 2
runs="$default_dir"; model=(); force=0
while [ $# -gt 0 ]; do
  case "$1" in
    --state-dir) runs="${2:?$usage}"; shift 2 ;;
    --model) model=(--model "${2:?$usage}"); shift 2 ;;
    --force) force=1; shift ;;
    *) echo "unknown option: $1" >&2; exit 1 ;;
  esac
done

mkdir -p "$runs"
case "$prompt" in /*) ;; *) prompt="$PWD/$prompt" ;; esac
if [ "$force" -eq 0 ] && { [ -e "$runs/$id.running" ] || [ -e "$runs/$id.done" ] || [ -e "$runs/$id.failed" ]; }; then
  echo "refused: run '$id' already has a marker in $(disp_path "$runs") (use --force to redispatch)" >&2; exit 1
fi
[ -f "$prompt" ] || { echo "no such prompt file: $prompt" >&2; exit 1; }
if [ "$force" -eq 1 ]; then rm -f "$runs/$id.running" "$runs/$id.done" "$runs/$id.failed"; fi

cd "$root"
exec_cmd="${SHIPPEDD_EXECUTOR_CMD:-}"   # 05-01 deviation: hoisted so the env var is named once in code
if [ -n "$exec_cmd" ]; then
  # Deterministic-testing hook (AUTO-07): run an arbitrary command as the
  # executor instead of `pi --print` (auto-selftest.sh injects scripted
  # executors this way; the command reads the prompt on stdin, exactly like
  # pi). Split on spaces; --model is ignored in this mode.
  read -r -a runner <<< "$exec_cmd"
  nohup "${runner[@]}" < "$prompt" > "${runs}/$id.log" 2>&1 &
else
  nohup pi --print ${model[@]+"${model[@]}"} < "$prompt" > "${runs}/$id.log" 2>&1 &
fi
pid=$!
printf '%s\n' "$pid" > "$runs/$id.running"
printf 'dispatched %s (PID %s) → %s\n' "$id" "$pid" "$(disp_path "${runs}/$id.log")"
