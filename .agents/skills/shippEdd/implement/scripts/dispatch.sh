#!/usr/bin/env bash
# shippEdd background dispatcher. Generic by design: the ROLE lives in the
# persona + plan the prompt points at, not here. The detached `pi --print` run
# gets an inline assignment — read the persona, read the plan, walk its
# <task> sections in order — flips its own marker (.running -> .done /
# .failed), and is never waited on or post-processed by this script. No
# prompt files are written; the prompt is piped in and lives only in the log.
#
# Usage:
#   dispatch.sh <id> <plan-file> <summary-template-file> [--model <model-id>] [--force]
#   dispatch.sh --status
#
# Abort semantics: to stop a run, kill the PID recorded in its .running marker.
# An aborted run never flips — a stale .running marker whose PID is dead means
# aborted/failed; the next orchestrator command should offer cleanup (inspect
# the log, then delete the stale marker before redispatching).
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
state="$("$here/state-dir.sh")"
runs="$root/$state/runs"
mkdir -p "$runs"

if [ "${1:-}" = "--status" ]; then
  for marker in "$runs"/*.running "$runs"/*.done "$runs"/*.failed; do
    [ -f "$marker" ] || continue
    id="$(basename "${marker%.*}")"
    pid="$(head -n1 "$marker" 2>/dev/null | grep -oE '[0-9]+' || true)"
    alive=dead
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then alive=alive; fi
    size=0
    [ -f "$runs/$id.log" ] && size="$(wc -c < "$runs/$id.log" | tr -d '[:space:]')"
    printf '%s  %s  pid %s %s  log %s bytes\n' "$id" "${marker##*.}" "${pid:-?}" "$alive" "$size"
  done
  exit 0
fi

usage='usage: dispatch.sh <id> <plan-file> <summary-template-file> [--model <model-id>] [--force] | dispatch.sh --status'
id="${1:?$usage}"
plan="${2:?$usage}"
summary_tpl="${3:?$usage}"
shift 3
model=(); force=0
while [ $# -gt 0 ]; do
  case "$1" in
    --model) model=(--model "${2:?$usage}"); shift 2 ;;
    --force) force=1; shift ;;
    *) echo "unknown option: $1" >&2; exit 1 ;;
  esac
done

case "$plan" in /*) ;; *) plan="$PWD/$plan" ;; esac
case "$summary_tpl" in /*) ;; *) summary_tpl="$PWD/$summary_tpl" ;; esac
if [ "$force" -eq 0 ] && { [ -e "$runs/$id.running" ] || [ -e "$runs/$id.done" ] || [ -e "$runs/$id.failed" ]; }; then
  echo "refused: run '$id' already has a marker (use --force to redispatch)" >&2; exit 1
fi
[ -f "$plan" ] || { echo "no such plan file: $plan" >&2; exit 1; }
[ -f "$summary_tpl" ] || { echo "no such summary template: $summary_tpl" >&2; exit 1; }
if [ "$force" -eq 1 ]; then rm -f "$runs/$id.running" "$runs/$id.done" "$runs/$id.failed"; fi

cd "$root"
nohup pi --print ${model[@]+"${model[@]}"} > "$runs/$id.log" 2>&1 <<PROMPT &
Read .pi/agents/executor.md and operate as that agent for the assignment below.

## Assignment
You are executing plan $id for the shippEdd workflow in this repo (repo root: $root). Work from the repo root unless a task block says otherwise.

Your spec is the plan itself: ${plan#"$root"/}. Read it, then go through its ## Tasks <task> sections in order, one at a time. Implement each task's action exactly as written (cwd notes and exact-string contracts are part of the spec), verify per its verify block, and only then move on. Never skip, reorder, or merge sections; a section whose work is already on disk from an earlier attempt gets verified, not redone.

After the LAST task section: run the plan's ## Verification checklist (every box demonstrably checked), then instantiate the summary template as a new file next to the plan — ${plan%/*}/$(basename "${plan%-PLAN.md}")-SUMMARY.md — modeled on ${summary_tpl#"$root"/}. The summary covers the whole plan.

Inputs you may consult:
- Phase context (read-only): the plan's sibling *-CONTEXT.md — the decisions behind the plan; don't revisit them.

Commit specs — you never run git. After each task, append one line to $state/runs/$id.commits.tsv (tab-separated):
<conventional commit message><TAB><path1,path2,...>
Paths repo-relative, comma-separated; a verify-only task records no line. Before appending, read the TSV: if a line for your task's paths is already recorded, do not duplicate it.

## Completion contract
1. Write the summary artifact named above, fully, per its template.
2. Then run: mv $state/runs/$id.running $state/runs/$id.done
3. If you cannot complete: mv the marker to $state/runs/$id.failed and append a one-line reason to the marker file.
Your final message must end with the sentinel: ## EXECUTION COMPLETE (or ## EXECUTION BLOCKED)
PROMPT
pid=$!
printf '%s\n' "$pid" > "$runs/$id.running"
log_disp="${runs#"$root"/}/$id.log"
printf 'dispatched %s (PID %s) → %s\n' "$id" "$pid" "$log_disp"
