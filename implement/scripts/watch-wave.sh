#!/usr/bin/env bash
# shippEdd run watcher (AUTO-02/03/06). Blocks until every named plan of the
# phase resolves, printing one line per resolved plan, then exits with the
# code the orchestrating loop reads:
#   0  every named plan resolved executed
#   2  at least one blocked or failed — recovery allowed (attempt budget in
#      the resolution lines; the loop may re-dispatch with fix instructions)
#   3  a failed plan exhausted its 3 attempts (2 retries) — stop the loop and
#      hand the failure dossier to the human
#   4  --timeout seconds elapsed (default 3600) with a plan still unresolved
# Source of truth is the artifact oracle: SUMMARY frontmatter decides; the
# $TMPDIR markers are advisory liveness only (PID-checked — a .running marker
# with a dead PID means aborted or crashed: failed, never forgiven). Polls
# every 10s; heartbeat every ~60s.
#
# Usage: watch-wave.sh <state-dir> <NN> <slug> <plan-id> [plan-id ...] [--timeout <seconds>]
set -uo pipefail

root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
shared="$(cd "$(dirname "$0")/../.." && pwd)/scripts"
usage='usage: watch-wave.sh <state-dir> <NN> <slug> <plan-id>... [--timeout <seconds>]'
state="${1:?$usage}"
nn="${2:?NN required}"; slug="${3:?slug required}"; shift 3
[ $# -gt 0 ] || { echo "$usage" >&2; exit 1; }
timeout=3600
ids=()
while [ $# -gt 0 ]; do
  case "$1" in
    --timeout) timeout="${2:?--timeout needs a value}"; shift 2 ;;
    *) ids+=("$1"); shift ;;
  esac
done

phase_runs="$("$shared/runs-dir.sh" home)/$nn-$slug"

status_of() {  # prints executed | blocked | inflight | failed for one plan id
  local id="$1"
  local smry="$root/$state/phases/$nn-$slug/$id-SUMMARY.md"
  local run="$phase_runs/$id"
  if [ -f "$smry" ]; then
    if grep -q '^status:[[:space:]]*complete' "$smry"; then echo executed; return; fi
    if grep -q '^status:[[:space:]]*blocked'  "$smry"; then echo blocked;  return; fi
    # SUMMARY present but status unreadable: fall through — poll on (timeout surfaces it)
  fi
  if [ -f "$run/$id.failed" ]; then echo failed; return; fi
  if [ -f "$run/$id.running" ]; then
    local pid; pid="$(head -n1 "$run/$id.running" 2>/dev/null | grep -oE '[0-9]+' || true)"
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then echo inflight; return; fi
    echo failed   # dead PID: aborted or crashed — the marker never flips back
    return
  fi
  echo inflight   # no marker, no SUMMARY: unknown — keep polling (artifacts first)
}

attempts_of() {  # advisory attempt count for one plan id ($TMPDIR only)
  local f="$phase_runs/$1/attempts"
  if [ -f "$f" ]; then wc -l < "$f" | tr -d '[:space:]'; else printf '0'; fi
}

reason_of() {  # one-line failure reason from the .failed marker (advisory)
  local f="$phase_runs/$1/$1.failed"
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
      executed)
        echo "resolved $id: executed (SUMMARY complete)"
        seen[$id]=1 ;;
      blocked)
        echo "resolved $id: blocked — deviations in $state/phases/$nn-$slug/$id-SUMMARY.md (attempt $(attempts_of "$id")/3)"
        seen[$id]=1; [ "$rc" -lt 2 ] && rc=2 ;;
      failed)
        n="$(attempts_of "$id")"; [ "$n" -eq 0 ] && n=1
        echo "resolved $id: failed — $(reason_of "$id") (attempt $n/3)"
        seen[$id]=1
        if [ "$n" -ge 3 ]; then
          echo "BUDGET: plan $id exhausted 3 attempts (2 retries) — stop the loop, hand the failure dossier to the human"
          [ "$rc" -lt 3 ] && rc=3
        else
          [ "$rc" -lt 2 ] && rc=2
        fi ;;
      inflight) unresolved=1 ;;
    esac
  done
  if [ "$unresolved" -eq 0 ]; then exit "$rc"; fi
  if [ "$SECONDS" -ge "$deadline" ]; then
    for id in "${ids[@]}"; do
      [ -n "${seen[$id]:-}" ] || echo "unresolved $id: no resolution after ${timeout}s — no SUMMARY, no live marker; inspect the artifacts and $phase_runs/$id/" >&2
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
