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
#   - bash + gh only (phase 07, todo 13): config reads are a flat-key bash
#     reader (absent key = documented default; an unparseable config is a
#     LOUD named receipt, never a silent mirror=off), and saved-JSON parses
#     ride gh's embedded --jq — the standalone jq(1) binary is not needed
#
# Usage: gh-mirror.sh <state-dir> <NN> <slug> <command> [args...]
#   ready                      off | NOREPO | NOGH | VERSION ... | NOAUTH ... | ok <owner/repo>
#   capture                    idempotent capture/re-sync sweep
#   backfill                  shipped-history seeding: parent + plan sub-issues created CLOSED, merge SHAs, milestone closed
#   progress <plan-id> <task#> flip one tasklist line on the plan's issue
#   pr-body <target>           print `Closes #N` lines for the target's open plan issues
#   close-plan <target>        guarded explicit close (state-checked, idempotent)
#   ship --verdict "<line>"    verdict comment + close parent, open sub-issues, milestone
set -uo pipefail   # NOT -e: never-block is the law; every gh call is guarded

here="$(cd "$(dirname "$0")" && pwd)"
root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
usage='usage: gh-mirror.sh <state-dir> <NN> <slug> <ready|capture|backfill|progress <plan-id> <task#>|pr-body <target>|close-plan <target>|ship --verdict <line>>'
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

# --- config law (MIR-01; jq-free since phase 07 — todo 13: bash + gh only) --------
# Flat-key bash reader (runs-dir.sh precedent). Limitation, documented: keys
# match anywhere in the file, so a second object carrying the same key name
# could shadow it (the labels array is read single-line) — accepted, same law
# as runs-dir.sh. Absent key = documented default. An unparseable config is
# LOUD (named receipt, exit 0 — never-block): a silent mirror=off is banned.
cfg="$root/$state/config.json"
cfg_sane() {  # absent file = fine (all defaults); a present file must look like JSON
  [ -f "$cfg" ] || return 0
  [ -r "$cfg" ] || return 1
  local o c
  o="$(grep -o '{' "$cfg" | wc -l)"; c="$(grep -o '}' "$cfg" | wc -l)"
  [ "$o" -gt 0 ] && [ "$o" -eq "$c" ]
}
cfg_guard() {  # runs before ANY config-derived behavior (ready_line + preflight)
  cfg_sane || offline "config miss: $state/config.json exists but is unreadable or not JSON — the mirror refuses to guess (a silent mirror=off is banned); fix the file, then retry: $retry"
}
jstr() {  # jstr <key> — flat string value of "<key>": "<val>"; empty when absent
  [ -f "$cfg" ] || return 0
  grep -o "\"$1\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" "$cfg" 2>/dev/null | head -n1 \
    | sed -e 's/^[^:]*://' -e 's/^[[:space:]]*"//' -e 's/"$//' || true
}
mirror_on() { [ -f "$cfg" ] && grep -q '"mirror"[[:space:]]*:[[:space:]]*true' "$cfg"; }
cfg_host="$(jstr host)";  [ -n "$cfg_host" ] || cfg_host=github.com
cfg_account="$(jstr account)"
cfg_repo="$(jstr repo)"
label0="$(grep -o '"labels"[[:space:]]*:[[:space:]]*\[[^]]*\]' "$cfg" 2>/dev/null | grep -o '"[^"]*"' | sed -n '2p' | sed -e 's/^"//' -e 's/"$//' || true)"
[ -n "$label0" ] || label0=shippedd
cfg_token_env="$(jstr token_env)"

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
  cfg_guard
  mirror_on      || { echo off; return; }
  [ -n "$cfg_repo" ]   || { echo NOREPO; return; }
  [ -n "$gh_bin" ]     || { echo NOGH;   return; }
  version_ok           || { echo "VERSION $(gh_version 2>/dev/null || echo '?') below floor $floor"; return; }
  resolve_env          || { echo "NOAUTH (no token for account '${cfg_account:-<active>}')"; return; }
  echo "ok $cfg_repo"
}

preflight() {  # every gh-touching command starts here; any failure exits 0 with a receipt
  cfg_guard
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
issues_tsv="$work/issues.tsv"   # number<TAB>title lines — fetched with gh's embedded --jq (no standalone jq(1) call)
refresh_issues() {  # ONE gh call per sweep; --limit: gh's 30/page default silently hides older issues (live-run finding)
  ghm issue list --state all --limit 1000 --json number,title --jq '.[] | "\(.number)\t\(.title)"' > "$issues_tsv" 2>/dev/null || : > "$issues_tsv"
}
find_issue() {  # find_issue <key prefix> -> first matching issue number, or nothing (glob prefix — trailing-space keys stay load-bearing)
  local num title
  while IFS=$'\t' read -r num title; do
    case "$title" in "$1"*) printf '%s\n' "$num"; return 0 ;;
    esac
  done < "$issues_tsv"
  return 0
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
  n="$("$gh_bin" api "repos/$cfg_repo/milestones?state=all" --jq ".[] | select(.title==\"$title\") | .number" 2>/dev/null | head -n1)"
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
  done < "$issues_tsv"

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

# --- progress / pr-body / close-plan / ship (MIR-05/06/07) -----------------------
cmd_progress() {  # <plan-id> <task#> — flip one tasklist line; NEVER fails the task
  local pid="${1:?progress needs <plan-id> <task#>}" tk="${2:?progress needs <plan-id> <task#>}"
  preflight
  refresh_issues
  local n; n="$(find_issue "$(key_plan "$pid")")"
  [ -n "$n" ] || offline "progress miss: no issue for lookup key $(key_plan "$pid") (run capture first) — task NOT blocked"
  local body; body="$(ghm issue view "$n" --json body -q .body 2>/dev/null)" || offline "progress miss: issue view #$n failed — task NOT blocked"
  printf '%s\n' "$body" | sed "s|^- \[ \] \[$pid\] T$tk |- [x] [$pid] T$tk |" > "$work/flip.md"
  ghm issue edit "$n" --body-file "$work/flip.md" >/dev/null 2>&1 \
    && echo "mirror progress: [$pid] T$tk ✓ (issue #$n)" >&2 \
    || note "tasklist flip failed: [$pid] T$tk (issue #$n) — task NOT blocked"
  exit 0
}

cmd_pr_body() {  # <target> — stdout prints ONLY the Closes lines (merge-back embeds stdout in the PR body)
  local want="${1:?pr-body needs <target>}"
  preflight
  refresh_issues
  local pid pf n st
  while IFS=$'\t' read -r pid pf; do
    n="$(find_issue "$(key_plan "$pid")")"
    [ -n "$n" ] || continue
    st="$(ghm issue view "$n" --json state -q ".state | ascii_downcase" 2>/dev/null || true)"
    [ "$st" = open ] && printf 'Closes #%s\n' "$n"
  done < <(plans_of_target "$want")
  exit 0
}

cmd_close_plan() {  # <target> — guarded explicit close: state-checked, idempotent, never-block (D19)
  local want="${1:?close-plan needs <target>}"
  preflight
  refresh_issues
  local pid pf n st closed=0 skipped=0
  while IFS=$'\t' read -r pid pf; do
    n="$(find_issue "$(key_plan "$pid")")"
    if [ -z "$n" ]; then note "close-plan: no issue for $pid"; continue; fi
    st="$(ghm issue view "$n" --json state -q ".state | ascii_downcase" 2>/dev/null || true)"
    if [ "$st" = open ]; then
      ghm issue close "$n" >/dev/null 2>&1 && closed=$((closed+1)) || note "close failed: #$n ($pid)"
    else
      skipped=$((skipped+1))   # already closed (closing keyword or a prior sweep) — that is the guard
    fi
  done < <(plans_of_target "$want")
  echo "mirror close-plan ($want): closed $closed · already-closed $skipped (guarded, idempotent)" >&2
  [ "${#misses[@]}" -gt 0 ] && printf 'mirror: %s\n' "${misses[@]}" >&2
  exit 0
}

cmd_ship() {  # ship --verdict "<one line from VERIFICATION.md>"
  local verdict=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --verdict) verdict="${2:?--verdict needs a value}"; shift 2 ;;
      *) shift ;;
    esac
  done
  preflight
  refresh_issues
  local pn; pn="$(find_issue "$(key_parent)")"
  [ -n "$pn" ] || offline "ship miss: no parent issue for $(key_parent) — nothing to close (never-block)"
  # 1. verdict as the parent's closing comment (D13); an already-closed parent still gets the comment
  if ! ghm issue close "$pn" --comment "${verdict:-shipped}" >/dev/null 2>&1; then
    st="$(ghm issue view "$pn" --json state -q ".state | ascii_downcase" 2>/dev/null || true)"
    { [ "$st" = closed ] && ghm issue comment "$pn" --body "${verdict:-shipped}" >/dev/null 2>&1; } \
      || note "parent close/comment failed: #$pn"
  fi
  # 2. remaining open sub-issues — the sweep-up point (D9)
  local sub n st closed=0
  while read -r n; do
    [ -n "$n" ] || continue
    st="$(ghm issue view "$n" --json state -q ".state | ascii_downcase" 2>/dev/null || true)"
    if [ "$st" = open ]; then
      ghm issue close "$n" >/dev/null 2>&1 && closed=$((closed+1)) || note "sub-issue close failed: #$n"
    fi
  done < <(ghm issue view "$pn" --json subIssues --jq '.subIssues.nodes[].number' 2>/dev/null)   # live shape: subIssues is a connection object {nodes:[…]} — the flat form returned 0 (07-RESEARCH Q3)
  # 3. milestone close (gh api PATCH — there is no gh milestone command)
  local title="Phase $nn: $slug" ms
  ms="$("$gh_bin" api "repos/$cfg_repo/milestones?state=all" --jq ".[] | select(.title==\"$title\") | .number" 2>/dev/null | head -n1)"
  if [ -n "$ms" ]; then
    "$gh_bin" api "repos/$cfg_repo/milestones/$ms" -X PATCH -f state=closed >/dev/null 2>&1 \
      || note "milestone close failed: $title"
  fi
  echo "mirror ship $nn-$slug: parent #$pn closed (verdict posted) · $closed sub-issue(s) closed · milestone '$title' closed" >&2
  [ "${#misses[@]}" -gt 0 ] && printf 'mirror: %s\n' "${misses[@]}" >&2
  exit 0
}

# --- backfill: shipped-history seeding (D20, MIR-09 live-proof leg) -------------
# One parent + plan sub-issues per PAST phase, created CLOSED (the work already
# merged), each plan issue body carrying that plan's merge-commit SHA resolved
# from git history; per-phase milestone created closed; NO decision sub-issues;
# FX plans parent flat under the phase parent (D20 says plans only — no fixes
# nesting, no decision rows). The merge-commit format evolved across eras, so
# resolution is a chain (first hit wins):
#   1. merge(<pid>):                 transitional per-plan gate bubbles (phases 03/04)
#   2. merge(<nn>-<slug>/<target>):  current per-target gate (04-FX1 onward) — NEWEST
#                                    match: a later sweep's gate contains all earlier
#                                    work of that phase on that target (e.g. 05-FX1's
#                                    master gate contains 05-01..05-05's)
#   3. (<pid>)                       conventional plan-id commits (replay era, 01/02)
#   4. <pid>                         bare plan-id mentions (docs-side gate commits)
#   5. <nn>-<slug>                   phase-named docs commits (last resort, e.g. 02-06)
# Unresolved -> the body says so and the receipt notes the miss (never-block).
plan_target() {  # plan_target <plan-file> — frontmatter target (missing = master)
  local t; t="$(sed -n 's/^target:[[:space:]]*//p' "$1" | head -n1)"
  printf '%s' "${t:-master}"
}
merge_sha() {  # merge_sha <target> <plan-id> — prints "<sha>\t<subject>" (empty if unresolved)
  local t="$1" pid="$2" out
  out="$(git log "$t" --merges --grep "merge($pid):" -1 --format='%H%x09%s' 2>/dev/null)"
  [ -n "$out" ] || out="$(git log "$t" --merges --grep "merge($nn-$slug/$t):" -1 --format='%H%x09%s' 2>/dev/null)"
  [ -n "$out" ] || out="$(git log "$t" --grep "($pid)" -1 --format='%H%x09%s' 2>/dev/null)"
  [ -n "$out" ] || out="$(git log "$t" --grep "$pid" -1 --format='%H%x09%s' 2>/dev/null)"
  [ -n "$out" ] || out="$(git log "$t" --grep "$nn-$slug" -1 --format='%H%x09%s' 2>/dev/null)"
  printf '%s' "$out"
}
cmd_backfill() {
  preflight
  local label_ok=0; ensure_label; ensure_milestone
  tag_args=(); [ "$label_ok" = 1 ] && tag_args+=(--label "$label0")
  [ "${#ms_args[@]}" -gt 0 ] && tag_args+=("${ms_args[@]}")
  refresh_issues
  local created="" closedcnt=0 already=0 pn pid pf key n st tgt sha subj

  # -- parent: goal line; created closed (guarded-closed if it somehow exists open) --
  pn="$(find_issue "$(key_parent)")"
  if [ -n "$pn" ]; then
    NUM[parent]="$pn"
    st="$(ghm issue view "$pn" --json state -q ".state | ascii_downcase" 2>/dev/null || true)"
    if [ "$st" = open ]; then ghm issue close "$pn" >/dev/null 2>&1 && closedcnt=$((closedcnt+1)) || note "parent close failed: #$pn"
    else already=$((already+1)); fi
  else
    { echo "Phase $nn \`$slug\` — shipped history, backfilled by shippEdd (this work merged before the mirror existed). Local markdown in \`$state/phases/$nn-$slug/\` remains the source of truth."
      echo; echo "## Goal"; md_section "$context" "Goal"; echo
      echo "Lookup keys: \`$(key_parent)\`(parent) · \`[$nn] plan <id>\`(plans — backfilled phases carry no decision sub-issues)"
    } > "$work/bp.md"
    pn="$(create_issue "$(key_parent)— $(goal_line)" "$work/bp.md")"
    if [ -n "$pn" ]; then
      NUM[parent]="$pn"; created="${created:+$created }parent #$pn"
      ghm issue close "$pn" >/dev/null 2>&1 && closedcnt=$((closedcnt+1)) || note "parent close failed: #$pn"
    fi
  fi
  [ -n "${NUM[parent]:-}" ] || offline "backfill miss: no parent issue for $(key_parent) and creation failed — see notes above"

  # -- plan sub-issues: created closed, body carries the merge SHA --
  while IFS=$'\t' read -r pid pf; do
    [ -n "${pid:-}" ] || continue
    key="$(key_plan "$pid")"
    tgt="$(plan_target "$pf")"
    IFS=$'\t' read -r sha subj <<< "$(merge_sha "$tgt" "$pid")"
    { echo "**Objective:** $(sed -n 's/^\*\*Objective:\*\* //p' "$pf" | head -n1)"
      echo
      echo "**Merged in:** ${sha:-not resolvable from git history (no gate bubble or plan-id commit on '$tgt')}"
      [ -n "$subj" ] && echo "> $subj"
      echo
      echo "Created closed by the backfill sweep — this work shipped before the mirror existed · sub-issue of #${NUM[parent]} · lookup key \`$key\`"
    } > "$work/bplan.md"
    n="$(find_issue "$key")"
    if [ -n "$n" ]; then
      NUM["plan:$pid"]="$n"
      st="$(ghm issue view "$n" --json state -q ".state | ascii_downcase" 2>/dev/null || true)"
      if [ "$st" = open ]; then
        ghm issue close "$n" --comment "shippedd backfill: phase $nn already shipped${sha:+ (merged in ${sha:0:7})}" >/dev/null 2>&1 \
          && closedcnt=$((closedcnt+1)) || note "close failed: $pid #$n"
      else already=$((already+1)); fi
    else
      n="$(create_issue "$key— $(short "$(sed -n 's/^\*\*Objective:\*\* //p' "$pf" | head -n1)")" "$work/bplan.md" --parent "${NUM[parent]}")"
      if [ -n "$n" ]; then
        NUM["plan:$pid"]="$n"; created="${created:+$created }plan $pid #$n"
        ghm issue close "$n" --comment "shippedd backfill: phase $nn already shipped${sha:+ (merged in ${sha:0:7})}" >/dev/null 2>&1 \
          && closedcnt=$((closedcnt+1)) || note "close failed: $pid #$n"
      fi
    fi
    [ -z "$sha" ] && note "merge SHA unresolved: $pid (target $tgt)"
  done < <(plans_of_phase)

  # -- milestone created closed (D20) --
  if [ "${#ms_args[@]}" -gt 0 ]; then
    local title="Phase $nn: $slug" ms
    ms="$("$gh_bin" api "repos/$cfg_repo/milestones?state=all" --jq ".[] | select(.title==\"$title\") | .number" 2>/dev/null | head -n1)"
    [ -n "$ms" ] && { "$gh_bin" api "repos/$cfg_repo/milestones/$ms" -X PATCH -f state=closed >/dev/null 2>&1 || note "milestone close failed: $title"; }
  fi

  echo "mirror backfill $nn-$slug → $cfg_repo (label '$label0'${ms_args[0]:+, milestone ${ms_args[0]#--milestone }} closed)"
  [ -n "$created" ] && echo "  created  $created  (created closed)"
  echo "  closed   $closedcnt issue(s) closed this run · $already already closed (idempotent)"
  [ "${#misses[@]}" -gt 0 ] && printf '  missed   %s\n' "${misses[*]}"
  echo "  retry    $retry"
  exit 0
}

# === command dispatcher ===
case "$cmd" in
  ready)      ready_line ;;
  capture)    cmd_capture "$@" ;;
  progress)   cmd_progress "$@" ;;
  pr-body)    cmd_pr_body "$@" ;;
  close-plan) cmd_close_plan "$@" ;;
  ship)       cmd_ship "$@" ;;
  backfill)   cmd_backfill "$@" ;;
  *)          echo "$usage" >&2; exit 2 ;;
esac
