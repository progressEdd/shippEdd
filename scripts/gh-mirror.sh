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

# --- capture: CONTEXT + plans -> issue tree (MIR-03/MIR-04) ----------------------
decision_rows() {  # prints "<n>\t<question>\t<decision>\t<why>" per decisions-table row
  [ -f "$context" ] || return 0
  awk -F'|' '/^\|[[:space:]]*[0-9]+[[:space:]]*\|/ {
    gsub(/^ +| +$/, "", $2); gsub(/^ +| +$/, "", $3); gsub(/^ +| +$/, "", $4); gsub(/^ +| +$/, "", $5)
    print $2 "\t" $3 "\t" $4 "\t" $5
  }' "$context"
}
md_section() { awk -v h="## $2" '$0==h{f=1;next} /^## /{f=0} f' "$1" 2>/dev/null; }
goal_line()  { md_section "$context" "Goal" | grep -v '^[[:space:]]*$' | head -n1; }

plans_of_phase() {  # prints "<plan-id>\t<plan-file>" sorted (FX plans included)
  local f id
  for f in "$phase_dir"/"$nn"-*-PLAN.md; do
    [ -f "$f" ] || continue
    id="$(basename "${f%-PLAN.md}")"
    printf '%s\t%s\n' "$id" "$f"
  done | sort
}
plans_of_target() {  # plans_of_target <target> — plans whose frontmatter target matches (missing target = master)
  local pid pf t
  while IFS=$'\t' read -r pid pf; do
    t="$(sed -n 's/^target:[[:space:]]*//p' "$pf" | head -n1)"; [ -z "$t" ] && t=master
    [ "$t" = "$1" ] && printf '%s\t%s\n' "$pid" "$pf"
  done < <(plans_of_phase)
}
fixes_of() { sed -n 's/^fixes:[[:space:]]*//p' "$1" | head -n1; }

ensure_label() {  # list-then-create; never --force (a configured user label is never restyled)
  ghm label list --json name --jq '.[].name' 2>/dev/null | grep -Fxq "$label0" && { label_ok=1; return 0; }
  if ghm label create "$label0" --color 5319E7 --description "shippEdd workflow artifact" >/dev/null 2>&1; then
    label_ok=1
  else
    label_ok=0; note "label '$label0' create failed — issues will carry no label"
  fi
}
ensure_milestone() {  # sets ms_args=() or (--milestone "Phase NN: slug")  [gh api: no gh milestone command]
  local title="Phase $nn: $slug" n
  n="$("$gh_bin" api "repos/$cfg_repo/milestones" --jq ".[] | select(.title==\"$title\") | .number" 2>/dev/null | head -n1)"
  if [ -z "$n" ]; then
    n="$("$gh_bin" api "repos/$cfg_repo/milestones" -f title="$title" --jq .number 2>/dev/null || true)"
    [ -n "$n" ] || note "milestone '$title' create/find failed — issues will carry no milestone"
  fi
  ms_args=(); [ -n "$n" ] && ms_args=(--milestone "$title")
}
create_issue() {  # create_issue <title> <body-file> [extra ghm issue create args...] -> prints the number (empty on miss)
  local title="$1" body="$2"; shift 2
  local out
  out="$(ghm issue create --title "$title" --body-file "$body" ${tag_args[@]+"${tag_args[@]}"} "$@")" \
    || { note "issue create failed: $title"; return; }
  printf '%s\n' "$out" | grep -oE '/issues/[0-9]+' | grep -oE '[0-9]+' | head -n1
}

refresh_plan_cache() {  # refresh_plan_cache <plan-file> <number> — advisory `issue:` frontmatter cache
  awk -v n="issue: \"#$2\"" '
    NR==1 && $0=="---" { print; print n; infm=1; next }
    infm && $0=="---" { infm=0; print; next }
    infm && /^issue:/ { next }
    { print }
  ' "$1" > "$work/plan.new" && mv "$work/plan.new" "$1"
}

refresh_context_cache() {  # refresh_context_cache <parent-number-or-empty> — parent line + Issue column, best-effort
  local parent="$1" map="" k
  [ -f "$context" ] || return 1
  for k in "${!NUM[@]}"; do case "$k" in D*) map="$map ${k#D}=${NUM[$k]}";; esac; done
  awk -v parent="${parent:-}" -v map="$map" '
    BEGIN { n=split(map, m, " "); for (i=1; i<=n; i++) { split(m[i], kv, "="); num[kv[1]]=kv[2] } }
    /^\*\*Gathered:/ { print; if (parent != "") { print ""; print "**GitHub parent:** #" parent }; next }
    /^\*\*GitHub parent:\*\*/ { if (parent != "") print "**GitHub parent:** #" parent; next }
    /^\|[[:space:]]*#[[:space:]]*\|[[:space:]]*Question/ {
      if ($0 !~ /Issue/) { $0 = $0 " Issue |"; addsep = 1 }
      print; next
    }
    addsep == 1 && /^\|[-|]+[[:space:]]*$/ { sub(/\|$/, ""); $0 = $0 "---|"; addsep = 0; print; next }
    /^\|[[:space:]]*[0-9]+[[:space:]]*\|/ {
      split($0, f, "|"); d = f[2]; gsub(/[[:space:]]/, "", d)
      if ($0 ~ /\|[[:space:]]*(#[0-9]+|—)[[:space:]]*\|[[:space:]]*$/) sub(/\|[[:space:]]*(#[0-9]+|—)[[:space:]]*\|[[:space:]]*$/, "|", $0)
      print $0 " " ((d in num) ? "#" num[d] : "—") " |"; next
    }
    { print }
  ' "$context" > "$work/context.new" && mv "$work/context.new" "$context"
}

cmd_capture() {
  preflight
  local label_ok=0; ensure_label; ensure_milestone
  tag_args=(); [ "$label_ok" = 1 ] && tag_args+=(--label "$label0")
  [ "${#ms_args[@]}" -gt 0 ] && tag_args+=("${ms_args[@]}")
  refresh_issues
  local created="" updated="" closedr="" cached=0

  # -- parent issue (goal + constraints + UI spec + open questions in the body) --
  local pn; pn="$(find_issue "$(key_parent)")"
  if [ -n "$pn" ]; then
    NUM[parent]="$pn"
  else
    { echo "Phase $nn \`$slug\` — captured by shippEdd's define approval sweep. The local markdown in \`$state/phases/$nn-$slug/\` is the source of truth; this issue tree is its mirror."
      echo; echo "## Goal"; md_section "$context" "Goal"; echo
      echo "## Constraints"; md_section "$context" "Constraints"; echo
      ui="$(md_section "$context" "UI Spec")"
      [ -n "$ui" ] && { echo "## UI Spec"; printf '%s\n\n' "$ui"; }
      echo "## Open questions (at capture)"; md_section "$context" "Open questions"
      echo; echo "Lookup keys: \`$(key_parent)\`(parent) · \`[$nn] D<n>\`(decisions) · \`[$nn] plan <id>\`(plans)"
    } > "$work/parent.md"
    pn="$(create_issue "$(key_parent)— $(goal_line)" "$work/parent.md")"
    [ -n "$pn" ] && { NUM[parent]="$pn"; created="${created:+$created }parent #$pn"; }
  fi

  # -- decision sub-issues: create missing, rewrite drifted bodies --
  local dn q d w key n
  while IFS=$'\t' read -r dn q d w; do
    [ -n "${dn:-}" ] || continue
    key="$(key_decision "$dn")"
    n="$(find_issue "$key")"
    { echo "**Question:** $q"; echo; echo "**Decision:** $d"; echo; echo "**Why:** $w"; echo
      echo "Sub-issue of #${NUM[parent]} · lookup key \`$key\`— local row $dn; GitHub owns this number"
    } > "$work/d.md"
    if [ -n "$n" ]; then
      ghm issue edit "$n" --title "$key— $(short "$d")" --body-file "$work/d.md" >/dev/null 2>&1 \
        && updated="$updated D$dn #$n" || note "body rewrite failed: D$dn"
      NUM["D$dn"]="$n"
    else
      n="$(create_issue "$key— $(short "$d")" "$work/d.md" --parent "${NUM[parent]}")"
      [ -n "$n" ] && { NUM["D$dn"]="$n"; created="${created:+$created }D$dn #$n"; }
    fi
  done < <(decision_rows)

  # -- plan sub-issues: tasklist bodies; FX plans nest under the plan they fix --
  local pid pf obj fx fxn parent_for_plan old_body mark tk tname
  while IFS=$'\t' read -r pid pf; do
    [ -n "${pid:-}" ] || continue
    key="$(key_plan "$pid")"
    parent_for_plan="${NUM[parent]}"
    fx="$(fixes_of "$pf")"
    if [ -n "$fx" ]; then
      fxn="$(find_issue "$(key_plan "$fx")")"
      if [ -n "$fxn" ]; then parent_for_plan="$fxn"; else note "FX $pid fixes $fx but that plan has no issue yet — parenting under the phase parent"; fi
    fi
    n="$(find_issue "$key")"
    obj="$(sed -n 's/^\*\*Objective:\*\* //p' "$pf" | head -n1)"
    old_body=""; [ -n "$n" ] && old_body="$(ghm issue view "$n" --json body -q .body 2>/dev/null || true)"
    { echo "**Objective:** ${obj:-<see plan>}"; echo
      echo "**Tasks** (flipped automatically as execution completes):"
      while IFS=$'\t' read -r tk tname; do
        [ -n "${tk:-}" ] || continue
        mark="[ ]"
        printf '%s\n' "$old_body" | grep -qF -- "- [x] [$pid] T$tk " && mark="[x]"   # preserve checked lines on rewrite
        echo "- $mark [$pid] T$tk — $tname"
      done < <(sed -n 's/^<name>Task \([0-9][0-9]*\): \(.*\)<\/name>$/\1\t\2/p' "$pf")
      echo
      echo "Closes via this plan's PR (closing keywords) or review's ship sweep · sub-issue of #${parent_for_plan} · lookup key \`$key\`"
    } > "$work/p.md"
    if [ -n "$n" ]; then
      ghm issue edit "$n" --title "$key— $(short "${obj:-$pid}")" --body-file "$work/p.md" >/dev/null 2>&1 \
        && updated="$updated plan $pid #$n" || note "body rewrite failed: plan $pid"
      NUM["plan:$pid"]="$n"
    else
      n="$(create_issue "$key— $(short "${obj:-$pid}")" "$work/p.md" --parent "$parent_for_plan")"
      [ -n "$n" ] && { NUM["plan:$pid"]="$n"; created="${created:+$created }plan $pid #$n"; }
    fi
  done < <(plans_of_phase)

  # -- drift: GitHub items carrying a [$nn] key with no local counterpart -> close --
  refresh_issues
  local num t k
  while IFS=$'\t' read -r num t; do
    [ -n "${num:-}" ] || continue
    case "$t" in
      "$(key_parent)"*) continue ;;
      "[$nn] D"*)     k="$(printf '%s' "$t" | awk '{print $2}')";      [ -n "${NUM[$k]:-}" ] && continue ;;
      "[$nn] plan "*) k="plan:$(printf '%s' "$t" | awk '{print $3}')"; [ -n "${NUM[$k]:-}" ] && continue ;;
      *) continue ;;
    esac
    ghm issue close "$num" --comment "shippedd re-sync: no longer present in CONTEXT/plans (edited or superseded)" >/dev/null 2>&1 \
      && closedr="$closedr #$num" || note "drift close failed: #$num $t"
  done < <(jq -r '.[] | "\(.number)\t\(.title)"' "$issues_json")

  # -- advisory cache write-back (GitHub owns the numbers; these never load-bear) --
  refresh_context_cache "${NUM[parent]:-}" && cached=$((cached+1))
  while IFS=$'\t' read -r pid pf; do
    [ -n "${NUM[plan:$pid]:-}" ] && refresh_plan_cache "$pf" "${NUM[plan:$pid]}" && cached=$((cached+1))
  done < <(plans_of_phase)

  # -- receipt (never-block: exit 0 whatever happened above) --
  echo "mirror capture $nn-$slug → $cfg_repo (label '$label0'${ms_args[0]:+, milestone ${ms_args[0]#--milestone }})"
  [ -n "$created" ] && echo "  created  $created"
  [ -n "$updated" ] && echo "  updated  $updated"
  [ -n "$closedr" ] && echo "  closed   $closedr  (re-sync: dropped/superseded)"
  [ "$cached" -gt 0 ] && echo "  cache    refreshed $cached local fields (advisory — GitHub owns the numbers)"
  [ "${#misses[@]}" -gt 0 ] && printf '  missed   %s\n' "${misses[*]}"
  echo "  retry    $retry"
}

# === command dispatcher ===
case "$cmd" in
  ready)      ready_line ;;
  capture)    cmd_capture "$@" ;;
  progress)   echo "gh-mirror: progress lands in plan 06-01 task 3 (stub)" >&2 ;;
  pr-body)    echo "gh-mirror: pr-body lands in plan 06-01 task 3 (stub)" >&2 ;;
  close-plan) echo "gh-mirror: close-plan lands in plan 06-01 task 3 (stub)" >&2 ;;
  ship)       echo "gh-mirror: ship lands in plan 06-01 task 3 (stub)" >&2 ;;
  *)          echo "$usage" >&2; exit 2 ;;
esac
