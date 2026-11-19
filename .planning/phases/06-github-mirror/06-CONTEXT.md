# Phase 06 github-mirror Context

**Gathered:** 2026-11-18 — via `/skill:define` grilling — **locked** (17 decisions, 4 facts parked on research)

**GitHub parent:** #1

## Goal

Opt-in GitHub mirror: define captures decisions as issues/sub-issues via `gh`, and implement/review ship PRs that close those issues.

## Decisions

| # | Question | Decision | Why | Issue |
|---|-----------------------------------|-------------------|---------------------------|
| 1 | Mirror hierarchy — what maps to what on GitHub? | Phase → one parent issue; **decisions → sub-issues** and **plans → sub-issues** of it; each plan's PR closes its own sub-issue | Issue tree mirrors ROADMAP's phase block; matches roadmap wording (decisions captured, PRs close their issues) | #2 |
| 2 | When does capture happen? | At approval (define step 7) — one batched sweep after plans lock; issue numbers written back to CONTEXT/plans before implement runs | Keeps grilling fast (no gh round-trips mid-interview); implement starts with numbers already on disk | #3 |
| 3 | Where does the opt-in live? | `config.json` key (e.g. `github.mirror`), set by a new bootstrap setup question or hand-edit; absent key = off | Same config-driven law as 05's placement/disposition | #4 |
| 4 | Where do issue numbers persist? | At point of use (CONTEXT `issue` column, PLAN frontmatter `issue:`, parent # in CONTEXT header) — **but numbers resolve from GitHub** via a stable per-item lookup key; local fields are an optional cache the sweep refreshes, never load-bearing | Local/GitHub can't authoritatively drift — GitHub owns issue identity, the sweep re-derives numbers every run | #5 |
| 5 | Opted in but `gh` unavailable / sweep fails partway? | Never-block receipt fallback (05-consistent): define completes; receipt names what was created/missed + retry command; sweep idempotent. **Extended to the PR path:** when gh fails but `git push` works, merge-back pushes the agent branch anyway so a human can open the PR (receipt shows branch + compare URL); if push also fails, branch stays local with by-hand commands | Mirror must never block the workflow; a pushable branch is the maximal useful fallback | #6 |
| 6 | Drift after issues exist (replan, approval-edit, FX plans)? | Helper re-syncs in place at every define touch: edited decision → issue body rewritten; dropped/superseded decision or plan → issue closed with comment; new rows/plans → issues created | Mirror tracks truth at each touch; no stale ghosts | #7 |
| 7 | How do issue numbers resolve (Q4 refinement)? | GitHub owns the numbers — each item carries a stable lookup key derived from local identity (e.g. `[06] D4`, `[06] plan 06-01`); the sweep queries gh and re-derives numbers every run. Local ordering and GitHub numbers are fully independent (phase 1 ↔ issue #42 is fine); the GitHub number lives in a separate cached field (`issue:`) the sweep refreshes — never load-bearing | No authoritative drift possible; local identity stays stable and human-readable | #8 |
| 8 | Per-repo GitHub accounts? | Yes — optional config entries (host + account/token *reference* read from env; never a secret in the repo); helper exports `GH_HOST`/`GH_TOKEN`-style overrides when invoking gh. Git transport (push) is untouched — per-directory ssh keys via git's `includeIf`/`core.sshCommand` already work and are orthogonal to gh | gh has no native repo-level accounts; env overrides scope the API identity without hijacking global gh state; exact mechanism parked on research | #9 |
| 9 | When do issues close? | Plan sub-issues close automatically when their PR merges (closing keywords emitted by merge-back from the plan's issue); decision sub-issues close early only when superseded (re-sync); review's ship closes the phase parent + any remaining decision issues | GitHub-native closing where possible; ship is the sweep-up point | #10 |
| 10 | "Primary" semantics at bootstrap | Default = local markdown. The setup question asks whether to document to GitHub; it first checks gh presence/auth (`gh auth status`) and, when enabling, links GitHub's install/setup article. "Primary" = preferred documentation surface for the human — never a GitHub→markdown write path | Documentation-surface preference without breaking mirror-not-source | #11 |
| 11 | Which rows get mirrored? | Everything in CONTEXT at the approval sweep — decisions (sub-issues), goal + constraints + UI spec (parent body), still-open questions included as they stand; resolved-by-research items update via re-sync. Plans mirror as sub-issues (decision 1), so the single sweep runs at approval when plans exist | "Everything, mirrored at lock-in" — one coherent snapshot | #12 |
| 12 | Live updates + fixes during the phase? | Plan issues receive progress updates during implement as tasks complete (never-block: an update failure never fails a task). FX/gap-fix plans become **sub-issues of the plan they fix**, minted when the FX plan is created (review/gap-fix touch). Closes stay at review | Human can watch execution on GitHub; fixes nest under what they fix | #13 |
| 13 | Ship-time verdict post? | Yes — review's ship posts the one-line verdict from VERIFICATION.md as the closing comment on the parent issue (`gh issue close --comment`), then closes it (+ milestone if any) | Closing reply carries the outcome; no extra noise | #14 |
| 14 | How does the agent pick the right GitHub account per repo? | Config binds repo → account (`github.host` + `github.account`, written by bootstrap's setup question); the helper resolves the token via gh's own store (`gh auth token --user <account>`) and invokes gh with per-call `GH_HOST`/`GH_TOKEN` exports — global gh state never touched, no secrets in the repo; optional `token_env` config key names an env var for headless/CI fallback | Multi-account without `gh auth switch` global churn; SSH push half already solved by the repo's own remote alias | #15 |
| 15 | Labels & milestones? | `shippedd` label (auto-created per repo if missing) + one milestone per phase (progress bars); ship closes both. **Label configurable** — `github.labels` in config overrides the default | Filter aid + phase progress; user can point it at an existing label scheme | #16 |
| 16 | Verification story? | Live runs on this repo are primary proof (real gh, real issues — prerequisite: `gh auth login`), **plus** minimal fake-gh cases in `auto-selftest.sh` so offline refresh gates catch regressions | Real-world proof + regression safety | #17 |
| 17 | Config format & docs home? | JSON stays (frozen 05 contract, `jq` everywhere); full config reference lives as a subheading in `bootstrap/README.md` (every key, default, absent-means-default law, GitHub account binding); suite README cross-links; no `_doc` keys | Bootstrap owns config creation, so its README is where users look; JSON can't self-document | #18 |
| 18 | Who decides the PR/fork branch? | Define's grilling asks once per phase (recommended answer: config default, else `master`); recorded in CONTEXT, planner stamps `target:` on all plans; vendored-refresh plan pinned to `progressEdd` by convention; FX plans inherit the phase answer | Topology becomes a settled per-phase fact, not an assumption | #19 |
| 19 | D9 amendment: closing mechanics | Keywords in PR bodies **plus** guarded explicit `gh issue close` in merge-back's merged path (state-checked, idempotent, never-block) — correct for any target branch; ship sweep stays backstop | Q18 makes non-default targets first-class; closing can't silently break | #20 |
| 20 | Live proof scope: backfill past phases? | Yes — the live run also backfills phases 01–05: one parent per phase + their plan sub-issues (27 plans), **created closed** with each plan's merge-commit SHA embedded (from git log's `merge(<NN>-<slug>/…)` gate commits); per-phase milestones created closed; no decision sub-issues for past phases (plans only) | Proves create-closed + bulk sweep beyond phase 06's own open tree; seeds the tracker with shipped history | #21 |

## Constraints

- Local markdown is always complete source of truth; the workflow must function fully with the mirror off or `gh` absent (exclusive-local-markdown is the standing baseline mode)
- No secrets stored in the repo (config may reference, never contain, tokens)
- Thin prose + helper: skills reference a helper script; no gh incantation walls inside SKILL.md bodies
- PRs close their issues (plan sub-issues) via closing keywords
- Repo topology (user-settled): feature/plan PRs target `master` (the repo default — closing keywords fire natively); `progressEdd` is the user's working branch, receiving only the phase-end vendored-refresh squash-merge

## Open questions

- none — frontier is clear; the four research-parked facts are answered in `06-RESEARCH.md` (sub-issue flags ≥ v2.94 · account chain via `GH_TOKEN` + `-R` always · tasklist bodies for progress · milestone/label/closing command surface)
