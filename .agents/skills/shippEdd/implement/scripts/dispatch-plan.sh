#!/usr/bin/env bash
# shippEdd per-plan executor dispatch (EXEC-01/04/08; AUTO-02/03/05/06). Sends
# one plan to a detached executor inside the phase's PER-TARGET agent worktree
# — forked from the target branch HEAD when the loop first dispatches into
# that target, re-attached on re-runs; all of a target's plans share it, one
# executor at a time (sequential topology — a live sibling executor in the
# same target worktree is refused below). Attempt budget: 3 dispatches per
# plan (initial + 2 retries), enforced here and surfaced by watch-wave.sh;
# counts live under $TMPDIR only (advisory-consistent with AUTO-06 — a wiped
# tmp resets them). Repo-visible per-run state: none.
#
# Usage:
#   dispatch-plan.sh <NN-YY> <plan-file> <target> [--summary-template <path>]
#                    [--fix-instructions <file>] [--model <model-id>] [--force]
#
# Re-dispatch (--force): this plan's markers are cleared; the surviving
# per-target worktree/branch is reused so the executor verifies and continues
# prior work, never redoes it. --fix-instructions <file> (recovery
# dispatches): its content is appended to the executor prompt verbatim.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
shared="$here/../../scripts"
state="$("$shared/state-dir.sh")"
skill_tpl="$here/../../bootstrap/templates"
persona="$here/../../bootstrap/personas/executor.md"
usage='usage: dispatch-plan.sh <NN-YY> <plan-file> <target> [--summary-template <path>] [--fix-instructions <file>] [--model <model-id>] [--force]'

id="${1:?$usage}"
plan="${2:?$usage}"
target="${3:?$usage}"
shift 3
summary_tpl=""; fix=""; model=(); force=0
while [ $# -gt 0 ]; do
  case "$1" in
    --summary-template) summary_tpl="${2:?$usage}"; shift 2 ;;
    --fix-instructions) fix="${2:?$usage}"; shift 2 ;;
    --model) model=(--model "${2:?$usage}"); shift 2 ;;
    --force) force=1; shift ;;
    *) echo "unknown option: $1" >&2; exit 1 ;;
  esac
done

phase_dir="$(dirname "$plan")"          # .../phases/<NN>-<slug>
slug_dir="$(basename "$phase_dir")"     # <NN>-<slug>
phase_runs="$("$shared/runs-dir.sh" home)/$slug_dir"
run_dir="$phase_runs/$id"               # this plan's dispatch state
tgt_dir="$phase_runs/$target"           # the target's shared worktree home
wt_base="$("$shared/runs-dir.sh" worktree-base)"
agent="agent/$slug_dir/$target"         # ONE agent branch per (phase, target)
tgt_wt="$wt_base/$agent"                # the target's agent worktree (DISP-04 layout)
mode="$("$shared/runs-dir.sh" mode)"          # work context: worktrees | branch (DISP-04)

case "$plan" in /*) ;; *) plan="$PWD/$plan" ;; esac
[ -f "$plan" ] || { echo "no such plan file: $plan" >&2; exit 1; }
git rev-parse --verify --quiet "refs/heads/$target" >/dev/null \
  || { echo "no such target branch: $target" >&2; exit 1; }
[ -f "$persona" ] || { echo "no executor persona at: $persona" >&2; exit 1; }
[ -n "$summary_tpl" ] || summary_tpl="$skill_tpl/NN-0N-SUMMARY.md"
case "$summary_tpl" in /*) ;; *) summary_tpl="$PWD/$summary_tpl" ;; esac
[ -f "$summary_tpl" ] || { echo "no such summary template: $summary_tpl" >&2; exit 1; }
if [ -n "$fix" ] && [ ! -f "$fix" ]; then
  echo "no such fix-instructions file: $fix" >&2; exit 1
fi

# Attempt budget (AUTO-03): 3 dispatches per plan, mechanically enforced —
# the model cannot burn a fourth attempt, only stop earlier on judgment.
attempts=0
[ -f "$run_dir/attempts" ] && attempts="$(wc -l < "$run_dir/attempts" | tr -d '[:space:]')"
if [ "$attempts" -ge 3 ]; then
  echo "BUDGET: plan $id already used $attempts attempts (2 retries) — refusing dispatch; hand the failure dossier to the human" >&2
  exit 1
fi

# Sequential-topology guard (AUTO-05): refuse to start a second executor in a
# target worktree that already has a live one (markers advisory, PID-checked —
# dead PIDs never block).
for sibling in "$phase_runs"/*/; do
  [ -d "$sibling" ] || continue
  s_id="$(basename "$sibling")"
  [ "$s_id" = "$id" ] && continue
  if [ "$mode" = worktrees ]; then
    [ "$(cat "$sibling/$s_id.target" 2>/dev/null || true)" = "$target" ] || continue
  fi   # branch mode: one main checkout shared by all targets — any live sibling refuses
  for marker in "$sibling"/*.running; do
    [ -f "$marker" ] || continue
    pid="$(head -n1 "$marker" 2>/dev/null | grep -oE '[0-9]+' || true)"
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
      branch_note=""
      if [ "$mode" = branch ]; then branch_note=" (branch mode)"; fi
      echo "REFUSED: plan $s_id is still executing in the $target worktree (sequential topology)$branch_note — let it resolve first (watch-wave.sh $state ${slug_dir%%-*} ${slug_dir#*-} $s_id)" >&2
      exit 1
    fi
  done
done

mkdir -p "$run_dir" "$tgt_dir"
if [ "$force" -eq 1 ]; then rm -f "$run_dir/$id.running" "$run_dir/$id.done" "$run_dir/$id.failed"; fi
if [ -e "$run_dir/$id.running" ] || [ -e "$run_dir/$id.done" ] || [ -e "$run_dir/$id.failed" ]; then
  echo "refused: run '$id' already has a marker in $run_dir (use --force to redispatch)" >&2; exit 1
fi

agent_wt=""
if [ "$mode" = branch ]; then
  # Branch mode (DISP-04): no agent worktree — the executor works on the agent
  # branch in the MAIN CHECKOUT. The repo switches branches during the run:
  # invasiveness accepted (phase-05 Decision 4). Requires a clean main checkout
  # (untracked files are fine — a pending SUMMARY is the gate's to commit).
  dirty="$(git -C "$root" status --porcelain)"
  if [ -n "$dirty" ] && printf '%s\n' "$dirty" | grep -qv '^??'; then
    echo "REFUSED: branch mode needs a clean main checkout (tracked changes present at $root) — commit or stash first" >&2; exit 1
  fi
  if git rev-parse --verify --quiet "refs/heads/$agent" >/dev/null; then
    git -C "$root" checkout --quiet "$agent"
    [ -f "$tgt_dir/fork-base" ] || git merge-base "$agent" "$target" > "$tgt_dir/fork-base"
    fork_note="re-attached branch $agent in the main checkout"
  else
    fork_base="$(git rev-parse "refs/heads/$target")"
    printf '%s\n' "$fork_base" > "$tgt_dir/fork-base"
    rm -f "$tgt_dir/merge-attempts"
    git -C "$root" checkout --quiet -b "$agent" "$fork_base"
    fork_note="forked $target@$(git rev-parse --short "$fork_base") onto the main checkout"
  fi
else
  agent_wt="$(git worktree list --porcelain | awk -v want="refs/heads/$agent" '
    /^worktree / { wt = substr($0, 10); bra = ""; det = 0 }
    /^detached/  { det = 1 }
    /^branch /   { bra = substr($0, 8) }
    bra == want && !det { print wt; exit }
  ')"   # an existing checkout of the agent branch wins — idempotence across base moves
  if [ -n "$agent_wt" ]; then
    [ -f "$tgt_dir/fork-base" ] || git merge-base "$agent" "$target" > "$tgt_dir/fork-base"
    fork_note="reused $target worktree (branch $agent)"
  elif git rev-parse --verify --quiet "refs/heads/$agent" >/dev/null; then
    git worktree add --quiet "$tgt_wt" "$agent"
    [ -f "$tgt_dir/fork-base" ] || git merge-base "$agent" "$target" > "$tgt_dir/fork-base"
    rm -f "$tgt_dir/merge-attempts"
    fork_note="re-attached branch $agent (fork base re-derived)"
  else
    fork_base="$(git rev-parse "refs/heads/$target")"
    printf '%s\n' "$fork_base" > "$tgt_dir/fork-base"
    rm -f "$tgt_dir/merge-attempts"   # fresh agent-branch generation: merge budget restarts
    git worktree add --quiet -b "$agent" "$tgt_wt" "$fork_base"
    fork_note="forked $target@$(git rev-parse --short "$fork_base")"
  fi
fi

plan_disp="${plan#"$root"/}"
summary_dst="$root/$state/phases/$slug_dir/$id-SUMMARY.md"
context_disp="$state/phases/$slug_dir/${slug_dir%%-*}-CONTEXT.md"
attempt_no=$((attempts + 1))
prompt="$run_dir/$id.prompt.md"
{
  echo "Read $persona and operate as that agent for the assignment below."
  echo
  echo "## Assignment"
  echo "You are executing plan $id for the shippEdd workflow (attempt $attempt_no of at most 3). Your working tree:"
  if [ "$mode" = branch ]; then
    echo "  $root"
    echo "— the repo's MAIN CHECKOUT, switched onto the phase's agent branch $agent"
    echo "(branch mode: this repo runs executors without worktrees — runs-dir.sh mode"
    echo "resolved 'branch'). The checkout is shared, sequentially, by this phase's"
    echo "plans: commits from earlier plans may already be on the branch — prior work"
    echo "to build on, verified and continued per the idempotence law, never redone."
    echo "Your tree is the whole repo: implementation changes land ONLY in your tasks'"
    echo "files; the SUMMARY destination below is written, never committed; STATE.md"
    echo "and ROADMAP.md are never yours."
  else
    echo "  ${agent_wt:-$tgt_wt}"
    echo "— the phase's agent worktree for branch $target (branch $agent). It is shared,"
    echo "sequentially, by this phase's $target-targeting plans: commits from earlier plans"
    echo "of this phase may already be on the branch — that is prior work to build on,"
    echo "verified and continued per the idempotence law, never redone or reverted. Make"
    echo "it your working directory; every implementation change lands inside it. Two"
    echo "paths outside it are yours to use and nothing else: the plan (read-only) and the"
    echo "SUMMARY destination (write the file there, never commit it)."
  fi
  echo
  echo "Your spec is the plan: $plan_disp (absolute: $plan). Read it, then walk its"
  echo "task sections in order, one at a time. Implement each task's action exactly"
  echo "(cwd notes and exact-string contracts are part of the spec), verify per its"
  echo "verify block, and only then move on. Never skip, reorder, or merge sections."
  echo
  echo "Idempotent by law: work already on disk — files matching a task's contracts,"
  echo "or commits bearing a plan id in your worktree's git log — is verified and"
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
  echo "GitHub mirror progress (opt-in, never-block): after each task's atomic"
  echo "commit, run:"
  echo "  bash .agents/skills/shippEdd/scripts/gh-mirror.sh $state ${slug_dir%%-*} ${slug_dir#*-} progress $id <task-number>"
  echo "where <task-number> is the 1-based index of the task section you just"
  echo "completed (Task 1 → 1, Task 2 → 2, ...). It is a silent no-op when the"
  echo "mirror is off (github.mirror absent in $state/config.json); any failure"
  echo "prints a note and NEVER fails your task — note it in the SUMMARY's"
  echo "deviations and move on."
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
  if [ -n "$fix" ]; then
    echo
    echo "## Fix instructions from the orchestrator (attempt $attempt_no)"
    echo
    echo "The previous attempt of this plan failed or blocked. Diagnose from the"
    echo "instructions below (together with the plan's own verify blocks); fix, then"
    echo "execute the plan from where the prior work stands:"
    echo
    cat "$fix"
  fi
  echo
  echo "## Completion contract"
  echo "1. Write the SUMMARY artifact named above, fully, per its template — with"
  echo "   status: blocked and the partial record if you cannot complete."
  echo "2. Then run: mv $run_dir/$id.running $run_dir/$id.done"
  echo "3. If you cannot complete: mv the marker to $run_dir/$id.failed and append a"
  echo "   one-line reason to the marker file."
  echo "Your final message must end with the sentinel: ## EXECUTION COMPLETE (or ## EXECUTION BLOCKED)"
} > "$prompt"

printf '%s  attempt %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$attempt_no" >> "$run_dir/attempts"
printf '%s\n' "$target" > "$run_dir/$id.target"

"$shared/dispatch.sh" "$id" "$prompt" --state-dir "$run_dir" ${model[@]+"${model[@]}"}
if [ "$mode" = branch ]; then
  printf 'worktree %s (main checkout, branch mode)\n' "$root"
else
  printf 'worktree %s (%s)\n' "${agent_wt:-$tgt_wt}" "$fork_note"
fi
printf 'attempt %s/3\n' "$attempt_no"
