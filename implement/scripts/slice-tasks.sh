#!/usr/bin/env bash
# shippEdd plan slicer. /skill:implement feeds each task block to its own
# detached executor — one focused context per task, never a whole plan in one
# read — and this script composes those prompts mechanically, so the
# orchestrator session never carries implementation detail.
#
# Usage: slice-tasks.sh <state-dir> <NN> <YY> <slug> [summary-template]
#   Reads   <state>/phases/<NN>-<slug>/<NN>-<YY>-PLAN.md
#   Writes  <state>/runs/<NN>-<YY>-T{1..k}.prompt.md   (existing files kept)
#   Prints  one "sliced <id>" line per prompt written, then "tasks <k>"
#
# To re-slice after a plan was edited: delete that plan's *-T*.prompt.md
# files first (existing prompts are never overwritten — repair, not clobber).
set -euo pipefail

state="${1:?usage: slice-tasks.sh <state> <NN> <YY> <slug> [summary-template]}"
nn="${2:?}"; yy="${3:?}"; slug="${4:?}"; summary_tpl="${5:-}"

here="$(cd "$(dirname "$0")" && pwd)"
root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
plan="$root/$state/phases/$nn-$slug/$nn-$yy-PLAN.md"
runs="$root/$state/runs"
mkdir -p "$runs"
[ -f "$plan" ] || { echo "no such plan: ${plan#"$root"/}" >&2; exit 1; }

# Extract pieces: the objective line, the Verification section, one temp file
# per <task>..</task> block (in plan order).
objective="$(sed -n 's/^\*\*Objective:\*\* //p' "$plan" | head -n1)"
verification="$(awk '/^## Verification/{flag=1;next}/^<!--/{flag=0}flag' "$plan" | sed '/./,$!d')"
awk -v runs="$runs" -v pid="$nn-$yy" '
  /^<task>$/ { n++; out = sprintf("%s/.slice-%s-T%d", runs, pid, n) }
  out && /^<task>$/,/^<\/task>$/ { print > out }
' "$plan"

shopt -s nullglob
blocks=("$runs"/.slice-"$nn-$yy"-T*)
shopt -u nullglob
k=${#blocks[@]}
[ "$k" -gt 0 ] || { echo "no <task> blocks found in ${plan#"$root"/}" >&2; exit 1; }

i=0
for block in "${blocks[@]}"; do
  i=$((i+1)); id="$nn-$yy-T$i"; out="$runs/$id.prompt.md"
  if [ -f "$out" ]; then rm -f "$block"; continue; fi
  last=0; [ "$i" -eq "$k" ] && last=1
  {
    echo "Read $root/.pi/agents/executor.md and operate as that agent for the task below."
    echo
    echo "## Task"
    echo "You are executing task $i of $k from plan $nn-$yy of phase $nn-$slug for the shippEdd workflow in this repo (repo root: $root)."
    echo
    echo "Plan objective: ${objective:-<none stated in plan>}"
    echo
    echo "Your spec — this task block, verbatim from the plan (other task blocks are NOT yours):"
    echo
    cat "$block"
    echo
    echo "Inputs you may consult:"
    echo "- Plan (read-only, for neighboring interfaces only): $state/phases/$nn-$slug/$nn-$yy-PLAN.md"
    echo "- Phase context: $state/phases/$nn-$slug/$nn-CONTEXT.md — the decisions behind the plan; don't revisit them"
    echo
    echo "Commit spec: append one line to $state/runs/$nn-$yy.commits.tsv (tab-separated):"
    echo "<conventional commit message><TAB><path1,path2,...>"
    echo "Paths repo-relative, comma-separated; a verify-only task records no line."
    if [ "$last" -eq 1 ]; then
      echo
      echo "You are the final task of this plan. After your task block passes:"
      echo "1. Run the plan's verification checklist (below) — every box demonstrably checked:"
      echo
      echo "$verification"
      echo
      echo "2. Instantiate the summary template as $state/phases/$nn-$slug/$nn-$yy-SUMMARY.md${summary_tpl:+ (template: $summary_tpl)} — the summary covers the whole plan; earlier tasks speak through their TSV lines and their plan blocks. Task commit specs must match the TSV line for line."
    fi
    echo
    echo "## Completion contract"
    if [ "$last" -eq 1 ]; then
      echo "1. Write the artifact named above, fully, per its template."
      echo "2. Then run: mv $state/runs/$id.running $state/runs/$id.done"
      echo "3. If you cannot complete: mv the marker to .failed and append a one-line reason to the marker file."
    else
      echo "1. Then run: mv $state/runs/$id.running $state/runs/$id.done"
      echo "2. If you cannot complete: mv the marker to .failed and append a one-line reason to the marker file."
    fi
    echo "Your final message must end with the sentinel: ## EXECUTION COMPLETE (or ## EXECUTION BLOCKED)"
  } > "$out"
  rm -f "$block"
  echo "sliced $id → ${out#"$root"/}"
done
echo "tasks $k"
