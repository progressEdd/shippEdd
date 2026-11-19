#!/usr/bin/env bash
# shippEdd plan-run watcher (AUTO-02/03/06) — thin wrapper since phase 07
# (todo 11, SR watch): the blocking/poll/heartbeat/exit-code machinery is the
# shared engine at scripts/watch-run.sh (one engine for every skill's
# background runs — plan | research | verify kinds); this wrapper preserves
# implement's stable CLI, mapping plan IDs onto the engine's `plan` kind
# (SUMMARY frontmatter oracle, 3-attempt budget, exit contract 0/2/3/4 —
# the phase-04 recovery contract, untouched).
#
# Script-home split, on the record (todo 11's second question): the ENGINE
# is suite infrastructure and lives in scripts/ beside dispatch.sh, so every
# skill's runs are watchable through one script; implement's plan-execution
# wrappers (dispatch-plan.sh, watch-wave.sh, merge-back.sh) are
# implement-specific and stay in implement/scripts/, composing the shared
# engine — the same shared-core/skill-wrapper split the dispatcher took in
# phase 05 (decision 1). Not a duplicate dispatcher: dispatch-plan.sh and
# merge-back.sh resolve the shared scripts dir and ride it.
#
# Usage: watch-wave.sh <state-dir> <NN> <slug> <plan-id> [plan-id ...] [--timeout <seconds>]
set -uo pipefail
usage='usage: watch-wave.sh <state-dir> <NN> <slug> <plan-id>... [--timeout <seconds>]'
[ $# -ge 4 ] || { echo "$usage" >&2; exit 1; }
shared="$(cd "$(dirname "$0")/../.." && pwd)/scripts"
exec bash "$shared/watch-run.sh" "$1" "$2" "$3" plan "${@:4}"
