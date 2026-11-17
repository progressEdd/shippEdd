---
status: complete  # complete | blocked — a blocked run still writes this record in full
duration: <Xmin>
key-files:
  created:
    - <repo-relative path created>
  modified:
    - <repo-relative path modified>
requirements-completed:
  - <REQ-ID>
key-decisions:
  - "<decision>"
deviations:
  - none  # or one line per deviation: what differed, why, which files
---

# Plan <NN-YY> Summary: <title>

<Substantive one-liner describing the outcome — not "plan complete".>

## Accomplishments

- <Key outcome 1>
- <Key outcome 2>

## Task commits

1. **<task name>** — `<short-sha>` <type>(<NN-YY>): <subject>
2. **<task name>** — `<short-sha>` <type>(<NN-YY>): <subject>

## Files created/modified

- `<path/to/file>` — <what it does>
- `<path/to/another>` — <what it does>

## Decisions & deviations

<Key decisions, or "none — followed plan as written".>
<Deviations from the plan and why, or "none".>

## Next phase readiness

<What is ready — or blocking — for the next phase.>
