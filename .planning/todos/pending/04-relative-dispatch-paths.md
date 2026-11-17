---
name: relative-dispatch-paths
captured: 2026-11-17
what: "let's use relative paths rather than absolutes"
severity: low
context: "the review dispatcher's output line printed the log path absolutely (dispatched 02-verify → <absolute machine path>/.planning/runs/02-verify.log) — print repo-relative paths instead, matching the skills' own relative-path rule"
files:
  - .agents/skills/shippEdd/review/scripts/dispatch.sh
---

## Problem

The dispatch receipt line prints an absolute, machine-specific path — observed live: `dispatched 02-verify (PID 1979907) → <absolute machine path>/.planning/runs/02-verify.log`. That contradicts AGENTS.md rule 1 (relative paths for portability across machines) and the review SKILL.md's own discipline — "keep every path repo-relative (no absolute paths…) — nothing machine-specific lands in the runs folder" — which the prompt file honors but the script output violates. The skill's example output (`.planning/runs/01-verify.log`) and the actual script output already disagree.

## Solution

Make `dispatch.sh` print repo-relative paths in its dispatch line (and `--status` output, if it prints paths too): resolve the log/prompt paths against the repo root instead of emitting absolutes. If define's and implement's dispatchers share the pattern, apply the same fix there.

## Research

- Script in question: `.agents/skills/shippEdd/review/scripts/dispatch.sh` — its dispatch line produced the absolute path above during the 02-verify dispatch on 2026-11-17
- `scripts/state-dir.sh` (same folder) already prints repo-relative (`.planning`) — the convention exists in the codebase
- review SKILL.md instructs reporting the output "verbatim" with a relative example, so fixing the script output fixes the receipt too

## Decisions

- Dispatch output uses repo-relative paths rather than absolute ones
