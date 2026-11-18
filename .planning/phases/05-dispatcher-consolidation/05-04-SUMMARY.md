---
status: complete
duration: 10min
key-files:
  created: []
  modified:
    - bootstrap/SKILL.md
    - bootstrap/README.md
    - bootstrap/templates/README.md
requirements-completed:
  - DISP-03
  - DISP-05
key-decisions:
  - "Step 4b persists only non-default choices per the frozen absent-means-default law: options 1/2 write runs.mode+runs.dir, option 3 writes runs.mode=branch, option 4 (defaults) writes nothing; disposition writes only \"auto-merge\" — pr is the absent default"
  - "Worktree creation (git worktree add <path> -b <basename-of-path>) and the .gitignore append are gate lines (new RUNS section), never pre-gate side effects — ground rule 3 holds for both new questions"
  - "Detection prefill: step 1's new worktree-topology bullet (git worktree list --porcelain, count linked worktrees, first linked one's dirname) feeds step 4b's recommendation — option 1 when worktrees exist, option 3 for a minimal worktree-less user"
  - "Machinery cross-check passed: every key documented in bootstrap prose is consumed by scripts/runs-dir.sh (runs_cfg mode, runs_cfg dir, runs_flag absolute_paths, disposition_cfg) and vice versa — no documented key the resolver ignores"
deviations:
  - "bootstrap/SKILL.md gate: kept [+ github] alongside the plan's [+ runs placement] [+ disposition] brackets on the <state>/config.json write line — the plan's verbatim line omitted it, which would have unlisted step 7's (unchanged) github-mirror write from the gate, contradicting ground rule 3's complete-write-list"
  - "bootstrap/SKILL.md gate: the plan's 'when applicable' instruction rendered as an inline annotation on the RUNS header (only when applicable — placement created a worktree / gitignored a dir), matching the file's existing annotation style (cf. the hermes-only note)"
---

# Plan 05-04 Summary: Bootstrap asks the placement question — worktree benefits, detection prefill, worktree creation, config.json + documented defaults (DISP-03)

Bootstrap's wizard now settles run placement and merge-back disposition: step 1 detects the worktree topology, new Step 4b explains the trade, prefills from detection, can create a worktree at a user-named path (decision 6), and lands non-default choices in `<state>/config.json`; the disposition question fixes pr-default/auto-merge (DISP-05's config surface). READMEs document all four keys with their absent-means-default values.

## Accomplishments

- Step 4b sits between TOGGLES and TIERS: the 4-option placement question (detected-folder prefill), the worktree-creation path (`git worktree add <path> -b <basename-of-path>`, forked from HEAD, branch named after the path's basename), persistence per the absent-means-default law, gitignore hygiene for in-repo runs dirs, and the disposition question (pr recommended, auto-merge opt-in)
- Step 1 gains the **Worktree topology** detection bullet (`git worktree list --porcelain` — linked-worktree count + first linked one's common folder; zero = worktree-less)
- The confirmation gate's config line carries the new optional writes, and a new RUNS section (when applicable) lists `create worktree …` and `append .gitignore …`; persistence table gains the runs-placement and disposition rows; rerun item 3 shows placement/disposition and re-asks step 4b on placement changes
- Step 0 and the paths preamble now name the shared `.agents/skills/shippEdd/scripts/` home (suite's `state-dir.sh`, `runs-dir.sh`, `dispatch.sh`; skill-local `scripts/wire-agents.sh`)
- bootstrap/README.md gains the placement/disposition FAQ (naming the single-setting rerun path), a "What it does" mention, and a non-default-keys working-if bullet; the state-dir README template's config.json bullet carries the full four-key default table matching the frozen 05-01 contract

## Task commits

1. **bootstrap/SKILL.md — worktree detection, Step 4b, persistence, gate, rerun** — `bce90ea` feat(05-04): bootstrap step 4b — run-placement question (detect, explain, create worktree, config) + disposition (DISP-03/05)
2. **bootstrap/README.md + templates/README.md — document runs/disposition keys** — `d13d54c` docs(05-04): bootstrap README + state-dir README template document runs/disposition defaults (DISP-03)

## Files created/modified

- `bootstrap/SKILL.md` — header intro sentence, shared-scripts paths preamble, step 0 full-path invocation, step 1 worktree-topology detection, new Step 4b (placement + disposition questions, worktree creation, persistence rules, gitignore hygiene), gate CONFIG/RUNS lines, persistence-table rows, rerun item 3
- `bootstrap/README.md` — "What it does" placement/disposition clause, "Can I change run placement or disposition later?" FAQ, non-default-keys "It's working if" bullet
- `bootstrap/templates/README.md` — config.json bullet rewritten: toggles plus run placement and disposition, with the full absent-means-default table for `runs.mode` / `runs.dir` / `runs.absolute_paths` / `disposition`

## Decisions & deviations

No blocking deviations. Two minimal gate-rendering adaptations (both in `bootstrap/SKILL.md`, recorded in frontmatter deviations): kept `[+ github]` on the gate's config.json write line — the plan's verbatim string dropped it, which would have unlisted step 7's unchanged github-mirror write from the complete-write-list gate; and rendered the plan's "when applicable" as an inline annotation on the RUNS header per the file's annotation style. Observation for a future plan (not this plan's work): bootstrap/README.md's "Can I move the state dir later?" FAQ and "It's working if" bullet still name the skill-relative `scripts/state-dir.sh` — the plan quoted both verbatim, so they were left as-is.

Plan verification checklist: both task verifies passed as written; the machinery cross-check passed (all four documented keys are consumed by `scripts/runs-dir.sh`'s readers — `runs_cfg mode`/`runs_cfg dir`/`runs_flag absolute_paths`/`disposition_cfg` — and no reader key is undocumented); two commits, each carrying `05-04` (`bce90ea`, `d13d54c`).

## Next phase readiness

DISP-03 is fully delivered at the setup surface: a fresh bootstrap run now produces a config.json whose runs/disposition keys are exactly the frozen contract `runs-dir.sh` resolves, with absent keys meaning the documented defaults. DISP-05's bootstrap config surface (the disposition question) is in place on top of 05-02's machinery. The template README a fresh bootstrap writes becomes `<state>/README.md` carrying the default table; the dogfood repo's live `.planning/README.md` catches up via a bootstrap rerun (repair semantics), per the plan's wave note — no phase plan edits the live state dir.
