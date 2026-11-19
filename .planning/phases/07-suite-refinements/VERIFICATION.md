# Phase 07-suite-refinements Verification

**Verified:** 2026-11-19 — fresh-context verifier run 07-verify

## Verdict

PASSED — ready to ship

## Requirement coverage

REQUIREMENTS.md maps no REQ-IDs to phase 07 (roadmap: "none recorded — promoted from todos"); the requirement surface is the 4 promoted todos plus CONTEXT decisions 5–9 (covered below).

| REQ-ID | Status | Evidence |
|--------|--------|----------|
| todo 10 — planning archive pruning (offered in review's ship step after every N shipped phases, never automatic) | ✅ covered | `.agents/skills/shippEdd/review/SKILL.md:181` — step 5 "Archive offer (cadence-gated, suggested — never automatic)" with the trigger (`grep -c '^- \[x\] \*\*Phase'` + `runs-dir.sh archive-cadence`, :183-184), the yes/no question (:190-194), the RELEASES.md entry shape (:216-231), ROADMAP-clear (:225) and REQUIREMENTS-fold (:226); `runs-dir.sh:40` `archive_cadence_cfg()`; `bootstrap/README.md:53` config row. Verify run: `ARCHIVE-STEP-OK` (see task table) |
| todo 11 — shared run watcher generalized from watch-wave.sh into suite-root scripts/ | ✅ covered | `.agents/skills/shippEdd/scripts/watch-run.sh` (153 lines, executable, :33 usage, :38 kind guard `plan\|research\|verify`, :112/:126 plan-kind contract strings verbatim) + `implement/scripts/watch-wave.sh` (24 lines, `exec bash "$shared/watch-run.sh" … plan`, Script-home split on the record in header); define/SKILL.md:185, 189, 255 and review/SKILL.md:102 name the watcher for their kinds, each opt-in/user-run; selftest case 19 green. Verify runs: `WATCHER-OK` + `PROSE-OK` (see task table) |
| todo 12 — disposition-gated ship PR offer | ✅ covered | `.agents/skills/shippEdd/review/SKILL.md:237` — step 6 "Push / PR — gated on disposition and change scope" (resolver quoted verbatim, :240; scope command with `":(exclude)$state"`, :244; iff rule :247; push-first fallback naming both no-PR reasons :253); receipt `PR` line :271 carries the no-PR-why form; old binary gate string absent (verified by negated grep). Verify run: `PR-GATE-OK` (see task table) |
| todo 13 — mirror-ship live subIssues shape + jq-free helper | ✅ covered | `.agents/skills/shippEdd/scripts/gh-mirror.sh:425` — `--jq '.subIssues.nodes[].number'` (live connection-object shape); :138 `issues_tsv` TSV cache; :142 bash `find_issue`; :114/:124 `cfg_guard` first statement of `ready_line()`/`preflight()`; jq-as-shell-word grep over both scripts: zero matches; suite-wide sweep (all `.sh`/`.md` under the vendored tree): zero matches; `command -v jq` → none on this machine and `SELFTEST PASSED (61 checks)` ran anyway. Verify runs: `MIRROR-JQFREE-OK` + `SELFTEST-GREEN-BARE-PATH` + the three offline smoke lines (see task table) |

## Decision coverage

| Decision (CONTEXT #) | Honored? | Evidence |
|----------------------|----------|----------|
| 1: planning-archive-pruning — prune/archive after every N shipped phases, offered as a suggested action in review's ship step | ✅ | review/SKILL.md:181 step title "suggested — never automatic"; two-option question :190-194 |
| 2: shared-run-watcher — all skills get a watcher; script-home split on the record | ✅ | scripts/watch-run.sh engine + define/SKILL.md:185 (research), review/SKILL.md:102 (verify); `implement/scripts/watch-wave.sh` header: "Script-home split, on the record (todo 11's second question)" (verified by grep, WATCHER-OK) |
| 3: ship-pr-offer — stop offering a PR on every ship; honor disposition + push-first convention | ✅ | review/SKILL.md:237-253 (gate + fallback); old gate string absent from SKILL.md (negated grep in PR-GATE-OK); review/README.md three policy sentences (grep `offering a PR only per policy`, PR-GATE-OK) |
| 4: mirror-ship-live-shape-and-jq-free — fix the subIssues shape AND eliminate the standalone jq dependency; fixtures match live; config failures loud | ✅ | gh-mirror.sh:425 (live shape); jq shell-word grep zero on both scripts; selftest case 17 runs through the nested shape and case 18 the config law (61-check PASS); smoke: corrupt config → `config miss:` receipt exit 0 (run this round, line 2 of 3) |
| 5: archive shape — RELEASES.md entries (dates, hashes, phases); ROADMAP clears to live only; superseded REQUIREMENTS ride under the entry; phases/ never pruned | ✅ | review/SKILL.md:216-231 (entry template with `## Release R<k>`, ship-commit + master-landing SHA columns, superseded-REQUIREMENTS details block); :225 ROADMAP-clear rules; :197 "phases/ folders are never pruned or moved; STATE.md and config.json stay as they are" |
| 6: PR-offer gate at ship — iff disposition `pr` AND files outside `<state>/` changed; docs-only = push-first, no question | ✅ | review/SKILL.md:247 "Offer the PR question iff the disposition is `pr` AND the scope is non-empty — planning rides the push"; :251-253 push-first fallback with `no PR offered (<docs-only ship \| disposition auto-merge>)`; receipt :271 |
| 7: watcher architecture — one engine `scripts/watch-run.sh`; watch-wave.sh thin wrapper; opt-in user-run, never a blocking subagent | ✅ | watch-run.sh:1-30 header ("ONE engine… Watching is always an opt-in user-run command — no skill blocks on this engine as a subagent (phase 07 decision 7)"); wrapper = 24 lines (`wc -l`), delegates via `exec bash "$shared/watch-run.sh"`; define/SKILL.md:185 "**Watching the run (opt-in, user-run — never the skill's)**" |
| 8: archive cadence default N=5, config key overrides, documented in README | ✅ | runs-dir.sh:40-46 `archive_cadence_cfg()` + case arm with numeric guard (absent/0/garbage → 5); live runs this round: no-config → `5`, `"archive_cadence": 3` → `3`, `"x"` → `5`, `disposition` → `pr` (CADENCE-OK); bootstrap/README.md:53 row (default `5`) + :24 FAQ sentence |
| 9: jq-free law scope — whole suite; gh-mirror.sh AND auto-selftest.sh drop standalone jq; fake-gh fixed programs in bash | ✅ | `grep -rnE '(^|[[:space:]|(;&])jq([[:space:]]|$)'` across every `.sh`/`.md` in the vendored tree → zero matches; fake-gh answers fixed `--jq` programs from TSV state with a loud FAKEGH tripwire for unknown pairs (auto-selftest.sh issue-view arm, verified by selftest cases 17/18 green); net deps bash + gh + git: selftest passed with `command -v jq` → none |

## Task verification

Verify commands run in each plan's target tree (07-01…07-03 in `02-worktrees/master` at cbb99e2; 07-04 in the main checkout at 4057a89), per each plan's cwd note.

| Plan | Task | Verify command | Outcome |
|------|------|----------------|---------|
| 07-01 | gh-mirror.sh jq-free (config reader, TSV cache, subIssues.nodes) | `bash -n … && [ -x … ] && ! grep -qF 'j()' … && ! grep -nE 'jq-as-word' … && grep -qF ×5 … && echo MIRROR-JQFREE-OK` | ✅ passed: `MIRROR-JQFREE-OK` |
| 07-01 | (acceptance) offline smoke — nesting parses, corrupt config loud, absent = off | action-block smoke under a gh-free PATH (`env PATH=/tmp/07verify/bin`, bash/git/grep/coreutils symlinks only — plan precondition "no gh anywhere on PATH") | ✅ passed: all three lines echoed (`NOGH, not silent off` / `config miss:` with exit 0 / `off`) |
| 07-01 | auto-selftest.sh — fake-gh --jq in bash, nested fixture, case 18 | `bash -n … && ! grep -nE 'jq-as-word' … && grep -qF ×3 … && out="$(bash scripts/auto-selftest.sh)" … grep -qF 'SELFTEST PASSED' && echo SELFTEST-GREEN-BARE-PATH` | ✅ passed: `SELFTEST PASSED (61 checks)` / `SELFTEST-GREEN-BARE-PATH` |
| 07-02 | review/SKILL.md step 5 disposition+scope PR gate + README sync | `grep -qF ×5 … && ! grep -qF '<old binary gate>' … && echo PR-GATE-OK` | ✅ passed: `PR-GATE-OK` |
| 07-02 | runs-dir.sh archive-cadence + bootstrap/README.md row | `bash -n … && archive-cadence → 5 … && temp-repo: 3 / garbage→5 / disposition→pr && echo CADENCE-OK` | ✅ passed: `CADENCE-OK` (all four resolver outcomes exact) |
| 07-02 | archive offer step 5 + renumber 6/7 + receipt | `grep -qF ×9 … && echo ARCHIVE-STEP-OK` | ✅ passed: `ARCHIVE-STEP-OK` |
| 07-02 | (acceptance) chain + trigger dry-runs | plan's literal 2-link snippet, then the full four-link chain as shipped in SKILL.md; trigger via fixture ROADMAP counts | ✅ passed with a recorded deviation: the plan's literal snippet misses phases 03/04 (`→ none (want 6e61d95/5aac779)`) exactly as 07-02-SUMMARY's deviation records; the four-link chain shipped in SKILL.md resolves all four (`03→6e61d95 OK · 04→5aac779 OK · 05→73af3f8 OK · 06→560d1d5 OK`); trigger: 7 shipped → no offer, 10 → offer fires |
| 07-03 | watch-run.sh engine + watch-wave.sh wrapper + selftest case 19 | `bash -n ×2 && [ -x ×2 ] && grep -qF ×3 … && selftest … && echo WATCHER-OK` | ✅ passed: `SELFTEST PASSED (61 checks)` / `WATCHER-OK`; wrapper 24 lines (≤30); kind guard rejects bogus kinds with usage, exit 1 (spot-checked) |
| 07-03 | define/review watcher prose + README sync | `grep -qF ×5 … && echo PROSE-OK` | ✅ passed: `PROSE-OK`; all three define/SKILL.md parentheticals present (:185, :189, :255). Note: :189's dispatch parenthetical reads `dispatch.sh --state-dir …` without `--status` — the plan's own quoted target string omitted it; executor applied verbatim and recorded the flag-drop in 07-03-SUMMARY key-decisions; the binding verify and acceptance criteria pass, and :255 + review/SKILL.md:102 keep `--status` |
| 07-04 | vendored refresh — squash-merge, parity, sanity, selftest | `diff -r --exclude=.git .agents/skills/shippEdd "$main_root/02-worktrees/master" && echo "PARITY OK" && grep/… && selftest … && status clean && echo "REFRESH VERIFIED"` | ✅ passed: `PARITY OK` (silent both directions) + `REFRESH VERIFIED` |
| 07-04 | (acceptance) 17-line sanity proof + bare-PATH | the action block's 17 greps/negations over the vendored copy | ✅ passed: all 17 lines echoed (todo 13 ×5, todo 11 ×6, todo 12 ×2, todo 10 ×4); `command -v jq` → none |

Commit bookkeeping cross-check: every task SHA recorded in the SUMMARYs exists and its `git show --stat` matches the SUMMARY's file list — 07-01 `c400451` (scripts/gh-mirror.sh), `4de33de` (scripts/auto-selftest.sh); 07-02 `f1f40db` (review/SKILL.md+README), `84b6f9e` (scripts/runs-dir.sh+bootstrap/README.md), `653777d` (review/SKILL.md); 07-03 `6eac92b` (watch-run.sh created + wrapper + selftest), `f86f18c` (define/review SKILL+README); 07-04 `badba3a` (squash, 10 files +381/−170) + `0fb4c66` (subtree merge). Master landing PR #76 = `cbb99e2` on `git log master`; progressEdd landing PR #77 = `1d0b241`. No `committed <sha>` lines exist in the run markers (they record SUMMARY-written lines) — judged on files and commits, which all check out. 07-04's one deviation (ff-only pull of `02-worktrees/master` 560d1d5→cbb99e2 to unblock an already-merged PR #76 preflight) is recorded in 07-04-SUMMARY deviations; master's history is unwritten (560d1d5 remains an ancestor of cbb99e2).

## Gaps found

none
