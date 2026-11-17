#!/usr/bin/env bash
# shippEdd per-plan executor dispatch (EXEC-01/04/06/08). Forks (or
# re-attaches) the plan's agent worktree, records the fork base SHA, composes
# the executor prompt into the transient run dir, and hands it to the shared
# dispatch.sh with --state-dir pointed there. Repo-visible per-run state:
# none — prompt, log, markers, pid, and fork-base all live under $TMPDIR.
#
# Usage:
#   dispatch-plan.sh <NN-YY> <plan-file> <target-branch> [--summary-template <path>] [--model <model-id>] [--force]
#
# Re-dispatch (--force): markers cleared; a surviving worktree/branch is
# reused so the executor verifies and continues prior work, never redoes it.
# The fork base is re-derived from the merge-base only when the run dir was
# wiped (branch survived, tmp did not).
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
state="$("$here/state-dir.sh")"
skill_tpl="$here/../../bootstrap/templates"
persona="$here/../../bootstrap/personas/executor.md"
usage='usage: dispatch-plan.sh <NN-YY> <plan-file> <target> [--summary-template <path>] [--model <model-id>] [--force]'

id="${1:?$usage}"
plan="${2:?$usage}"
target="${3:?$usage}"
shift 3
summary_tpl=""; model=(); force=0
while [ $# -gt 0 ]; do
  case "$1" in
    --summary-template) summary_tpl="${2:?$usage}"; shift 2 ;;
    --model) model=(--model "${2:?$usage}"); shift 2 ;;
    --force) force=1; shift ;;
    *) echo "unknown option: $1" >&2; exit 1 ;;
  esac
done

phase_dir="$(dirname "$plan")"          # .../phases/<NN>-<slug>
slug_dir="$(basename "$phase_dir")"     # <NN>-<slug>
run_dir="${TMPDIR:-/tmp}/shippEdd/$slug_dir/$id"
agent="agent/$id"

case "$plan" in /*) ;; *) plan="$PWD/$plan" ;; esac
[ -f "$plan" ] || { echo "no such plan file: $plan" >&2; exit 1; }
git rev-parse --verify --quiet "refs/heads/$target" >/dev/null \
  || { echo "no such target branch: $target" >&2; exit 1; }
[ -f "$persona" ] || { echo "no executor persona at: $persona" >&2; exit 1; }
[ -n "$summary_tpl" ] || summary_tpl="$skill_tpl/NN-0N-SUMMARY.md"
case "$summary_tpl" in /*) ;; *) summary_tpl="$PWD/$summary_tpl" ;; esac
[ -f "$summary_tpl" ] || { echo "no such summary template: $summary_tpl" >&2; exit 1; }

mkdir -p "$run_dir"
if [ "$force" -eq 1 ]; then rm -f "$run_dir/$id.running" "$run_dir/$id.done" "$run_dir/$id.failed"; fi
if [ -e "$run_dir/$id.running" ] || [ -e "$run_dir/$id.done" ] || [ -e "$run_dir/$id.failed" ]; then
  echo "refused: run '$id' already has a marker in $run_dir (use --force to redispatch)" >&2; exit 1
fi

if [ -d "$run_dir/worktree" ] && [ -e "$run_dir/worktree/.git" ]; then
  [ -f "$run_dir/fork-base" ] || git merge-base "$agent" "$target" > "$run_dir/fork-base"
  fork_note="reused worktree (prior commits on $agent preserved)"
elif git rev-parse --verify --quiet "refs/heads/$agent" >/dev/null; then
  git worktree add --quiet "$run_dir/worktree" "$agent"
  [ -f "$run_dir/fork-base" ] || git merge-base "$agent" "$target" > "$run_dir/fork-base"
  fork_note="re-attached branch $agent (fork base re-derived)"
else
  fork_base="$(git rev-parse "refs/heads/$target")"
  printf '%s\n' "$fork_base" > "$run_dir/fork-base"
  git worktree add --quiet -b "$agent" "$run_dir/worktree" "$fork_base"
  fork_note="forked $target@$(git rev-parse --short "$fork_base")"
fi

plan_disp="${plan#"$root"/}"
summary_dst="$root/$state/phases/$slug_dir/$id-SUMMARY.md"
context_disp="$state/phases/$slug_dir/${slug_dir%%-*}-CONTEXT.md"
prompt="$run_dir/$id.prompt.md"
{
  echo "Read $persona and operate as that agent for the assignment below."
  echo
  echo "## Assignment"
  echo "You are executing plan $id for the shippEdd workflow. Your own agent worktree:"
  echo "  $run_dir/worktree"
  echo "— a fork of branch $target. Make it your working directory; every implementation"
  echo "change lands inside it. Two paths outside it are yours to use and nothing else:"
  echo "the plan (read-only) and the SUMMARY destination (write the file there, never"
  echo "commit it)."
  echo
  echo "Your spec is the plan: $plan_disp (absolute: $plan). Read it, then walk its"
  echo "task sections in order, one at a time. Implement each task's action exactly"
  echo "(cwd notes and exact-string contracts are part of the spec), verify per its"
  echo "verify block, and only then move on. Never skip, reorder, or merge sections."
  echo
  echo "Idempotent by law: work already on disk — files matching a task's contracts,"
  echo "or commits bearing the plan id in your worktree's git log — is verified and"
  echo "continued from, never redone or reverted. You are a resumed run, not a fresh"
  echo "start, whenever prior work exists."
  echo
  echo "Git contract — you own git inside your worktree. After each task passes its"
  echo "verify, commit atomically:"
  echo "  git add <exactly that task's files> && git commit -m \"<type>($id): <subject>\""
  echo "Conventional message carrying the plan id; a verify-only task that changed"
  echo "nothing commits nothing. Never: merge, rebase, push, or any git command"
  echo "outside your worktree. Never write STATE.md or ROADMAP.md — the orchestrator"
  echo "owns them and the merge-back."
  echo
  echo "After the LAST task section: run the plan's verification checklist (every box"
  echo "demonstrably checked), then write the SUMMARY IN FULL to:"
  echo "  $summary_dst"
  echo "(outside your worktree — the one sanctioned cross-tree write; write it, do"
  echo "not commit it; the gate owns its commit). Model it on $summary_tpl. Frontmatter"
  echo "keys exactly: status (complete|blocked) / duration / key-files with created and"
  echo "modified lists (worktree-relative paths) / requirements-completed /"
  echo "key-decisions / deviations. The body's task-commits list carries your real"
  echo "commit hashes from your worktree's git log."
  echo
  echo "Inputs you may consult:"
  echo "- Phase context (read-only): $context_disp — the decisions behind the plan; don't revisit them."
  echo
  echo "## Completion contract"
  echo "1. Write the SUMMARY artifact named above, fully, per its template — with"
  echo "   status: blocked and the partial record if you cannot complete."
  echo "2. Then run: mv $run_dir/$id.running $run_dir/$id.done"
  echo "3. If you cannot complete: mv the marker to $run_dir/$id.failed and append a"
  echo "   one-line reason to the marker file."
  echo "Your final message must end with the sentinel: ## EXECUTION COMPLETE (or ## EXECUTION BLOCKED)"
} > "$prompt"

"$here/dispatch.sh" "$id" "$prompt" --state-dir "$run_dir" ${model[@]+"${model[@]}"}
printf 'worktree %s (%s)\n' "$run_dir/worktree" "$fork_note"
