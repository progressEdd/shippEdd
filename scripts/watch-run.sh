#!/usr/bin/env bash
# shippEdd shared run watcher (phase 07; todo 11). ONE engine for every
# skill's background runs — define's research runs, implement's plan
# executors, review's verify runs — each resolved by its own artifact
# oracle. Blocks until every named run resolves, printing one line per
# resolved run, then exits with the code the orchestrating loop reads:
#   0  every named run resolved done/executed
#   2  at least one blocked or failed — recovery allowed (plan runs carry
#      the attempt budget in the resolution lines; the loop may re-dispatch
#      with fix instructions; research/verify recovery is the owning
#      skill's redispatch --force)
#   3  a failed plan run exhausted its 3 attempts (2 retries) — stop the
#      loop and hand the failure dossier to the human (plan kind only)
#   4  --timeout seconds elapsed (default 3600) with a run still unresolved
# Source of truth is the artifact oracle per kind; the $TMPDIR markers are
# advisory liveness only (PID-checked — a .running marker with a dead PID
# means aborted or crashed: failed, never forgiven). Polls every 10s;
# heartbeat every ~60s. Watching is always an opt-in user-run command —
# no skill blocks on this engine as a subagent (phase 07 decision 7).
#
# Kinds and their oracles:
#   plan     markers in <home>/<NN>-<slug>/<id>/     · <state>/phases/<NN>-<slug>/<id>-SUMMARY.md
#            (status: complete → executed · status: blocked → blocked · attempts ledger → budget)
#   research markers in <home>/<NN>-<slug>/          · <state>/phases/<NN>-<slug>/<NN>-RESEARCH.md exists
#   verify   markers in <home>/<NN>-<slug>/          · <state>/phases/<NN>-<slug>/VERIFICATION.md filled
#            (the first non-blank line after `## Verdict` is real, not the template placeholder)
#
# Usage: watch-run.sh <state-dir> <NN> <slug> <plan|research|verify> <run-id> [run-id ...] [--timeout <seconds>]
set -uo pipefail

root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
here="$(cd "$(dirname "$0")" && pwd)"
usage='usage: watch-run.sh <state-dir> <NN> <slug> <plan|research|verify> <run-id>... [--timeout <seconds>]'
state="${1:?$usage}"
nn="${2:?NN required}"; slug="${3:?slug required}"; kind="${4:?kind required: plan|research|verify}"
shift 4
[ $# -gt 0 ] || { echo "$usage" >&2; exit 1; }
case "$kind" in plan|research|verify) ;; *) echo "$usage" >&2; exit 1 ;; esac
timeout=3600
ids=()
while [ $# -gt 0 ]; do
  case "$1" in
    --timeout) timeout="${2:?--timeout needs a value}"; shift 2 ;;
    *) ids+=("$1"); shift ;;
  esac
done

phase_runs="$("$here/runs-dir.sh" home)/$nn-$slug"
phase_dir="$root/$state/phases/$nn-$slug"

marker_of() {  # marker file stem <dir>/<id> — plan runs keep a per-id subdir, research/verify sit flat
  local dir="$phase_runs"
  [ "$kind" = plan ] && dir="$phase_runs/$1"
  printf '%s/%s' "$dir" "$1"
}

verdict_filled() {  # true iff VERIFICATION.md's `## Verdict` line is real (not the `<GREEN … | …>` placeholder)
  local v="$phase_dir/VERIFICATION.md"
  [ -f "$v" ] || return 1
  awk '/^## Verdict/ { f=1; next }
       f && /^## /  { exit 1 }          # next section before any content: not filled
       f && NF      { exit ($0 ~ /^</) ? 1 : 0 }   # first non-blank line: placeholder ⇒ not filled
       END { if (!f) exit 1 }' "$v" 2>/dev/null
}

status_of() {  # prints done | executed | blocked | inflight | failed for one run id (artifacts first)
  local id="$1" m
  m="$(marker_of "$id")"
  case "$kind" in
    plan)
      local smry="$phase_dir/$id-SUMMARY.md"
      if [ -f "$smry" ]; then
        grep -q '^status:[[:space:]]*complete' "$smry" && { echo executed; return; }
        grep -q '^status:[[:space:]]*blocked'  "$smry" && { echo blocked;  return; }
        # SUMMARY present but status unreadable: fall through — poll on (timeout surfaces it)
      fi ;;
    research)
      [ -s "$phase_dir/$nn-RESEARCH.md" ] && { echo done; return; } ;;
    verify)
      verdict_filled && { echo done; return; } ;;
  esac
  if [ -f "$m.failed" ]; then echo failed; return; fi
  if [ -f "$m.running" ]; then
    local pid; pid="$(head -n1 "$m.running" 2>/dev/null | grep -oE '[0-9]+' || true)"
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then echo inflight; return; fi
    echo failed   # dead PID: aborted or crashed — the marker never flips back
    return
  fi
  echo inflight   # no marker, no artifact: unknown — keep polling (artifacts first)
}

attempts_of() {  # advisory attempt count for one plan id ($TMPDIR only)
  local f="$phase_runs/$1/attempts"
  if [ -f "$f" ]; then wc -l < "$f" | tr -d '[:space:]'; else printf '0'; fi
}

reason_of() {  # one-line failure reason from the .failed marker (advisory)
  local f; f="$(marker_of "$1").failed"
  if [ -f "$f" ]; then tail -n1 "$f"; else printf 'no marker reason (derive from the log)'; fi
}

declare -A seen
deadline=$((SECONDS + timeout))
heartbeat=0
while :; do
  rc=0; unresolved=0
  for id in "${ids[@]}"; do
    [ -n "${seen[$id]:-}" ] && continue
    case "$(status_of "$id")" in
      done|executed)
        case "$kind" in
          plan)     echo "resolved $id: executed (SUMMARY complete)" ;;
          research) echo "resolved $id: done (RESEARCH.md present)" ;;
          verify)   echo "resolved $id: done (VERIFICATION.md verdict)" ;;
        esac
        seen[$id]=1 ;;
      blocked)
        echo "resolved $id: blocked — deviations in $state/phases/$nn-$slug/$id-SUMMARY.md (attempt $(attempts_of "$id")/3)"
        seen[$id]=1; [ "$rc" -lt 2 ] && rc=2 ;;
      failed)
        if [ "$kind" = plan ]; then
          n="$(attempts_of "$id")"; [ "$n" -eq 0 ] && n=1
          echo "resolved $id: failed — $(reason_of "$id") (attempt $n/3)"
          seen[$id]=1
          if [ "$n" -ge 3 ]; then
            echo "BUDGET: plan $id exhausted 3 attempts (2 retries) — stop the loop, hand the failure dossier to the human"
            [ "$rc" -lt 3 ] && rc=3
          else
            [ "$rc" -lt 2 ] && rc=2
          fi
        else
          echo "resolved $id: failed — $(reason_of "$id") (run log: $(dirname "$(marker_of "$id")")/$id.log)"
          seen[$id]=1; [ "$rc" -lt 2 ] && rc=2
        fi ;;
      inflight) unresolved=1 ;;
    esac
  done
  if [ "$unresolved" -eq 0 ]; then exit "$rc"; fi
  if [ "$SECONDS" -ge "$deadline" ]; then
    for id in "${ids[@]}"; do
      [ -n "${seen[$id]:-}" ] || echo "unresolved $id: no resolution after ${timeout}s — inspect the artifacts and $(dirname "$(marker_of "$id")")/" >&2
    done
    exit 4
  fi
  sleep 10
  heartbeat=$((heartbeat + 10))
  if [ "$heartbeat" -ge 60 ]; then
    pending=""
    for id in "${ids[@]}"; do [ -n "${seen[$id]:-}" ] || pending="$pending $id"; done
    echo "waiting:${pending} (${SECONDS}s elapsed)"
    heartbeat=0
  fi
done
