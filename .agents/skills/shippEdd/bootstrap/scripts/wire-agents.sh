#!/usr/bin/env bash
# shippEdd persona wire-up.
# Wires the canonical personas (../personas/*.md relative to this script) into
# the chosen harness's project agent directory, converting format where the
# harness requires it. Wiring matrix (verified 2026-11-16, phase 01 research):
#
#   pi, cursor, claude, gemini, github-copilot -> straight md copy
#   opencode  -> .opencode/agents/ (v2; singular agent/ is legacy),
#                inject `mode: subagent` into the frontmatter
#   codex     -> .codex/agents/, md -> TOML (frontmatter keys map 1:1;
#                body becomes developer_instructions)
#   hermes    -> no agents dir: report and skip (profiles in ~/.hermes/config.yaml)
#   custom    -> any named directory; --mode picks the conversion (default copy)
#
# Repair semantics: agents dir created if absent (receipt notes the creation);
# missing files wired in; identical files skipped (compared as CONVERTED
# output); a differing file is overwritten only when named via --replace,
# otherwise kept and reported. Never silently overwrites.
#
# Usage:
#   wire-agents.sh <harness> [--dry-run] [--diff] [--replace <persona>]...
#   wire-agents.sh custom <dir> [--mode copy|inject|toml] [--source <dir>]
#                              [--dry-run] [--diff] [--replace <persona>]...
#
#   harnesses: pi | opencode | hermes | cursor | codex | claude | gemini
#              | github-copilot (alias: copilot)
#   --dry-run  print the wiring plan (target dir, per-persona action,
#              conversion) without writing anything
#   --diff     additionally print a unified diff for every differing persona
#   --replace  name a differing persona that may be overwritten (repeatable)
#   --mode     custom only: copy (default) | inject | toml
#   --source   custom only: personas dir to wire from (default: ../personas
#              next to this script); use it to wire LLM-converted files
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_SOURCE="$SCRIPT_DIR/../personas"
# Targets are relative to the repo root (cwd when outside a git repo), so the
# script can be proven against throwaway non-git temp dirs.
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

usage() {
  cat >&2 <<'EOF'
usage:
  wire-agents.sh <harness> [--dry-run] [--diff] [--replace <persona>]...
  wire-agents.sh custom <dir> [--mode copy|inject|toml] [--source <dir>]
                             [--dry-run] [--diff] [--replace <persona>]...
harnesses: pi opencode hermes cursor codex claude gemini github-copilot
           (alias: copilot = github-copilot; custom = any named directory)
EOF
}

HARNESS="${1:-}"
if [ -z "$HARNESS" ]; then
  usage
  exit 2
fi
shift

TARGET=""
MODE=""
case "$HARNESS" in
  pi)                     TARGET=".pi/agents";       MODE="copy"   ;;
  opencode)               TARGET=".opencode/agents"; MODE="inject" ;;
  hermes)                 TARGET="";                 MODE="skip"   ;;
  cursor)                 TARGET=".cursor/agents";   MODE="copy"   ;;
  codex)                  TARGET=".codex/agents";    MODE="toml"   ;;
  claude)                 TARGET=".claude/agents";   MODE="copy"   ;;
  gemini)                 TARGET=".gemini/agents";   MODE="copy"   ;;
  github-copilot|copilot) TARGET=".github/agents";   MODE="copy"   ;;
  custom)
    TARGET="${1:-}"
    if [ -z "$TARGET" ]; then
      echo "error: custom requires a target directory" >&2
      usage
      exit 2
    fi
    shift
    MODE="copy"
    ;;
  *)
    echo "error: unknown harness '$HARNESS'" >&2
    usage
    exit 2
    ;;
esac

DRY_RUN=0
SHOW_DIFF=0
SOURCE="$DEFAULT_SOURCE"
REPLACE_LIST=" "
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY_RUN=1 ;;
    --diff)    SHOW_DIFF=1 ;;
    --replace)
      if [ $# -lt 2 ]; then echo "error: --replace needs a persona name" >&2; exit 2; fi
      REPLACE_LIST="$REPLACE_LIST$2 "
      shift
      ;;
    --mode)
      if [ $# -lt 2 ]; then echo "error: --mode needs copy|inject|toml" >&2; exit 2; fi
      if [ "$HARNESS" != "custom" ]; then echo "error: --mode applies to custom only" >&2; exit 2; fi
      case "$2" in
        copy|inject|toml) MODE="$2" ;;
        *) echo "error: --mode must be copy|inject|toml (got '$2')" >&2; exit 2 ;;
      esac
      shift
      ;;
    --source)
      if [ $# -lt 2 ]; then echo "error: --source needs a directory" >&2; exit 2; fi
      if [ "$HARNESS" != "custom" ]; then echo "error: --source applies to custom only" >&2; exit 2; fi
      SOURCE="$2"
      shift
      ;;
    *)
      echo "error: unknown option '$1'" >&2
      usage
      exit 2
      ;;
  esac
  shift
done

is_replace() {
  case "$REPLACE_LIST" in *" $1 "*) return 0 ;; *) return 1 ;; esac
}

# hermes: no agents dir exists anywhere — report and skip, nothing written.
if [ "$MODE" = "skip" ]; then
  printf '%s\n' "skip    personas — hermes has no agents dir; subagents run as profiles in ~/.hermes/config.yaml"
  exit 0
fi

if [ ! -d "$SOURCE" ]; then
  echo "error: personas dir not found: $SOURCE (hand-rolled install? nothing to wire)" >&2
  exit 1
fi
if [ -e "$TARGET" ] && [ ! -d "$TARGET" ]; then
  echo "error: target exists but is not a directory: $TARGET" >&2
  exit 1
fi

# inject: prepend `mode: subagent` as the first frontmatter key. Idempotent:
# if the frontmatter already carries it, the file passes through unchanged —
# which is what makes the converted-output comparison land on "identical".
convert_inject() { # $1 = md file; prints converted content
  if awk '
    NR == 1 { if ($0 !~ /^---[[:space:]]*$/) exit 1; next }
    /^---[[:space:]]*$/ { exit }
    /^mode:[[:space:]]*subagent[[:space:]]*$/ { found = 1 }
    END { exit found ? 0 : 1 }
  ' "$1"; then
    cat "$1"
  else
    awk 'NR == 1 && $0 ~ /^---[[:space:]]*$/ { print; print "mode: subagent"; next } { print }' "$1"
  fi
}

# toml: md + YAML frontmatter -> TOML. String frontmatter keys map 1:1 to
# `key = "value"`; `tools:` becomes a string array; comment lines are dropped;
# the body becomes `developer_instructions` as a literal ('''…''') multi-line
# string (no escape processing — persona bodies never contain '''). Pure
# function of the input file, byte-identical across runs, which is what makes
# the identical-skip comparison sound. Exit 3 when there is no frontmatter.
convert_toml() { # $1 = md file; prints converted content
  # q carries the TOML literal-string fence ('''); passed via -v because three
  # single quotes cannot appear literally inside this single-quoted program.
  awk -v q="'''" '
    function trim(s) { gsub(/^[[:space:]]+|[[:space:]]+$/, "", s); return s }
    function esc(s)  { gsub(/\\/, "\\\\", s); gsub(/"/, "\\\"", s); return s }
    NR == 1 {
      if ($0 !~ /^---[[:space:]]*$/) { bad = 1; exit 3 }
      state = "fm"; next
    }
    state == "fm" {
      if ($0 ~ /^---[[:space:]]*$/) { state = "body"; next }
      if ($0 ~ /^[[:space:]]*#/) next
      if ($0 ~ /^tools:/) {
        val = $0; sub(/^tools:[[:space:]]*/, "", val)
        n = split(val, arr, ",")
        line = "tools = ["
        for (i = 1; i <= n; i++) line = line (i > 1 ? ", " : "") "\"" esc(trim(arr[i])) "\""
        print line "]"
        next
      }
      if ($0 ~ /^[a-zA-Z0-9_-]+:/) {
        key = $0; sub(/:.*/, "", key)
        val = $0; sub(/^[^:]*:[[:space:]]*/, "", val)
        printf "%s = \"%s\"\n", key, esc(trim(val))
        next
      }
      next
    }
    state == "body" { body = body $0 "\n" }
    END {
      if (bad || state != "body") exit 3
      print ""
      print "developer_instructions = " q
      printf "%s", body
      print q
    }
  ' "$1"
}

# Wiring plan first, then (unless --dry-run) the writes.
dir_created=""
if [ ! -d "$TARGET" ]; then
  dir_created="yes"
  if [ "$DRY_RUN" = "0" ]; then
    mkdir -p "$TARGET"
  fi
  printf 'create  %s/ (agents dir)\n' "$TARGET"
fi

count=0
for f in "$SOURCE"/*.md; do
  [ -f "$f" ] || continue
  base="$(basename "$f" .md)"
  case "$MODE" in
    copy)
      out="$TARGET/$base.md"
      content="$(cat "$f")"
      conv=""
      ;;
    inject)
      out="$TARGET/$base.md"
      content="$(convert_inject "$f")"
      conv="md + mode: subagent"
      ;;
    toml)
      out="$TARGET/$base.toml"
      if ! content="$(convert_toml "$f")"; then
        echo "error: personas/$base.md has no frontmatter — cannot convert to TOML, skipped" >&2
        continue
      fi
      conv="md → TOML"
      ;;
  esac
  count=$((count + 1))

  if [ ! -f "$out" ]; then
    action="create"
  elif printf '%s\n' "$content" | cmp -s - "$out"; then
    action="skip"
  elif is_replace "$base"; then
    action="replace"
  else
    action="differs"
  fi

  case "$action" in
    create)  printf 'create  %s%s\n' "$out" "${conv:+   ($conv)}" ;;
    skip)    printf 'skip    %s (identical)\n' "$out" ;;
    replace) printf 'replace %s%s\n' "$out" "${conv:+   ($conv)}" ;;
    differs) printf 'differs %s (kept — re-run with --replace %s to overwrite)\n' "$out" "$base" ;;
  esac

  if [ "$action" = "differs" ] && [ "$SHOW_DIFF" = "1" ]; then
    printf '%s\n' "$content" | diff -u -L "canonical" -L "$out" - "$out" || true
  fi

  if [ "$DRY_RUN" = "0" ]; then
    case "$action" in
      create | replace) printf '%s\n' "$content" > "$out" ;;
    esac
  fi
done

note=""
if [ -n "$dir_created" ]; then
  note=" — dir created in project directory"
fi
printf 'wire   personas → %s (%d agents)%s\n' "$TARGET" "$count" "$note"
if [ "$DRY_RUN" = "1" ]; then
  printf '%s\n' "dry-run nothing written"
fi
