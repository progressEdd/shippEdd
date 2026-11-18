#!/usr/bin/env bash
# shippEdd GitHub mirror helper (phase 06; MIR-02..MIR-07). Opt-in GitHub
# issues mirror for the phase loop: define's approval sweep captures the
# phase as a parent issue + decision/plan sub-issues, executors flip
# tasklist lines as tasks complete, merge-back PRs close their plan issues,
# and review's ship posts the verdict and sweeps up. The local markdown
# state dir is ALWAYS the complete source of truth (mirror-not-source);
# every path here is never-block: a failure prints what was created/missed
# plus a retry command and exits 0.
#
# Verified mechanics (gh v2.103.3, 06-RESEARCH):
#   - explicit -R OWNER/REPO on every repo-scoped call — remote inference
#     never (an SSH-aliased remote is genuinely unresolvable by gh)
#   - account chain: token_env (headless) -> `gh auth token --user <acct>`
#     -> stored active creds; GH_TOKEN (github.com, *.ghe.com) or
#     GH_ENTERPRISE_TOKEN (GHES hosts); global gh state is never switched
#   - sub-issue flags need gh >= 2.94.0 — older installs gate to the
#     never-block receipt
#   - issue identity = stable title lookup keys; GitHub owns the numbers,
#     local `issue:` caches are advisory, refreshed every sweep
#   - milestones via gh api (no gh milestone command exists); labels via
#     list-then-create, never --force (a configured user label is never
#     restyled)
#
# Usage: gh-mirror.sh <state-dir> <NN> <slug> <command> [args...]
#   ready                      off | NOREPO | NOGH | VERSION ... | NOAUTH ... | ok <owner/repo>
#   capture                    idempotent capture/re-sync sweep
#   progress <plan-id> <task#> flip one tasklist line on the plan's issue
#   pr-body <target>           print `Closes #N` lines for the target's open plan issues
#   close-plan <target>        guarded explicit close (state-checked, idempotent)
#   ship --verdict "<line>"    verdict comment + close parent, open sub-issues, milestone
set -uo pipefail   # NOT -e: never-block is the law; every gh call is guarded

here="$(cd "$(dirname "$0")" && pwd)"
root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
usage='usage: gh-mirror.sh <state-dir> <NN> <slug> <ready|capture|progress <plan-id> <task#>|pr-body <target>|close-plan <target>|ship --verdict <line>>'
state="${1:?$usage}"; nn="${2:?$usage}"; slug="${3:?$usage}"; cmd="${4:?$usage}"
shift 4 || true
phase_dir="$root/$state/phases/$nn-$slug"
context="$phase_dir/$nn-CONTEXT.md"
floor=2.94.0
work="$(mktemp -d -t shippedd-gh-mirror.XXXXXX)"
trap 'rm -rf "$work"' EXIT
misses=()

note()    { misses+=("$*"); printf 'mirror: %s\n' "$*" >&2; }
offline() { printf 'mirror: %s\n' "$*" >&2; exit 0; }   # never-block hard gate (exit 0)
retry="bash .agents/skills/shippEdd/scripts/gh-mirror.sh $state $nn $slug $cmd"   # repo-relative (POL-02)

# --- config law (MIR-01) --------------------------------------------------------
cfg="$root/$state/config.json"
j() { jq -r "$1" "$cfg" 2>/dev/null || true; }
mirror_on() { [ "$(j '.github.mirror // false')" = true ]; }
cfg_host="$(j '.github.host // "github.com"')"
cfg_account="$(j '.github.account // ""')"
cfg_repo="$(j '.github.repo // ""')"
label0="$(j '(.github.labels // ["shippedd"])[0] // "shippedd"')"
cfg_token_env="$(j '.github.token_env // ""')"

gh_bin="$(command -v gh || true)"

# --- readiness + account chain (MIR-02) -----------------------------------------
gh_version() { "$gh_bin" --version 2>/dev/null | head -n1 | grep -oE '[0-9]+(\.[0-9]+){2}' | head -n1; }
version_ok() {
  local v; v="$(gh_version)"
  [ -n "$v" ] || return 1
  [ "$(printf '%s\n%s\n' "$floor" "$v" | sort -V | head -n1)" = "$floor" ]
}

resolve_env() {  # exports GH_HOST + the host-appropriate token env; returns 1 on a hard auth miss
  local tok=""
  if [ -n "$cfg_token_env" ]; then
    tok="${!cfg_token_env:-}"
    [ -n "$tok" ] || note "token_env '$cfg_token_env' is set but its env var is empty — falling through to the account chain"
  fi
  if [ -z "$tok" ] && [ -n "$cfg_account" ]; then
    tok="$("$gh_bin" auth token --user "$cfg_account" 2>/dev/null)" \
      || { note "gh auth token --user $cfg_account found no token for that account"; return 1; }
  fi
  export GH_HOST="$cfg_host"
  case "$cfg_host" in
    github.com|*.ghe.com) [ -n "$tok" ] && export GH_TOKEN="$tok" ;;
    *)                    [ -n "$tok" ] && export GH_ENTERPRISE_TOKEN="$tok" ;;  # GHES: GH_TOKEN does not apply
  esac
  return 0
}

ready_line() {
  mirror_on      || { echo off; return; }
  [ -n "$cfg_repo" ]   || { echo NOREPO; return; }
  [ -n "$gh_bin" ]     || { echo NOGH;   return; }
  version_ok           || { echo "VERSION $(gh_version 2>/dev/null || echo '?') below floor $floor"; return; }
  resolve_env          || { echo "NOAUTH (no token for account '${cfg_account:-<active>}')"; return; }
  echo "ok $cfg_repo"
}

preflight() {  # every gh-touching command starts here; any failure exits 0 with a receipt
  mirror_on || offline "off — github.mirror is absent/false in $state/config.json; nothing to do"
  [ -n "$cfg_repo" ] || offline "miss: github.repo (OWNER/REPO) is not set in $state/config.json — the helper never infers it from remotes; set it, then retry: $retry"
  [ -n "$gh_bin" ]   || offline "miss: gh CLI not found — install it (https://docs.github.com/en/github-cli/github-cli/quickstart), then retry: $retry"
  version_ok         || offline "miss: gh $(gh_version 2>/dev/null || echo '?') is below the sub-issue floor $floor — upgrade gh, then retry: $retry"
  resolve_env        || offline "miss: no usable token (account '${cfg_account:-<active>}', token_env '${cfg_token_env:-none}') — gh auth login, then retry: $retry"
  "$gh_bin" api user >/dev/null 2>&1 || offline "miss: gh api user failed as account '${cfg_account:-<active>}' on $cfg_host — check auth/host, then retry: $retry"
  return 0
}

ghm() { "$gh_bin" "$@" -R "$cfg_repo"; }   # repo-scoped gh: -R on EVERY call (never remote inference)

# --- issue identity: stable title lookup keys (MIR-03) ---------------------------
# NOTE: every key ends with a trailing space — it is load-bearing ([06] D4 must not match [06] D40)
issues_json="$work/issues.json"
refresh_issues() { ghm issue list --state all --json number,title > "$issues_json" 2>/dev/null || printf '[]' > "$issues_json"; }
find_issue() {  # find_issue <key prefix> -> prints the issue number, or nothing
  jq -r --arg k "$1" 'map(select(.title|startswith($k))) | .[0].number // empty' "$issues_json" 2>/dev/null
}
key_parent()   { printf '[%s] phase %s ' "$nn" "$slug"; }
key_decision() { printf '[%s] D%s ' "$nn" "$1"; }
key_plan()     { printf '[%s] plan %s ' "$nn" "$1"; }
declare -A NUM   # lookup-key -> issue number: this run's identity map (GitHub is authoritative)
short() { printf '%s' "$1" | tr -d '\n' | cut -c1-72; }

# === command dispatcher ===
case "$cmd" in
  ready)      ready_line ;;
  capture)    echo "gh-mirror: capture lands in plan 06-01 task 2 (stub)" >&2 ;;
  progress)   echo "gh-mirror: progress lands in plan 06-01 task 3 (stub)" >&2 ;;
  pr-body)    echo "gh-mirror: pr-body lands in plan 06-01 task 3 (stub)" >&2 ;;
  close-plan) echo "gh-mirror: close-plan lands in plan 06-01 task 3 (stub)" >&2 ;;
  ship)       echo "gh-mirror: ship lands in plan 06-01 task 3 (stub)" >&2 ;;
  *)          echo "$usage" >&2; exit 2 ;;
esac
