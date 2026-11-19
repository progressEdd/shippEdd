# Phase 07-suite-refinements Research

**Researched:** 2026-11-19 — background run 07-research (`/tmp/shippEdd/07-suite-refinements`)

## Question

Three open questions parked at 07 grilling (07-CONTEXT.md "Open questions"):

1. How are phase ship commits identified on master — the exact git command(s) a RELEASES.md entry would cite to record each shipped phase's commit hash, incl. how phase 06's backfill sourced its merge-commit SHAs (`gh-mirror.sh` backfill logic + this repo's git history).
2. The exact current shape of review's ship-step PR offer, and every site that reads `disposition` today (review SKILL prose, `merge-back.sh`, `gh-mirror.sh`, README/docs) — so todo 12's gating edit lands precisely.
3. Full inventory of saved-JSON / standalone-jq parses in `gh-mirror.sh` — which move to gh's embedded `--jq` at fetch time vs need re-query/restructure, for the bash+gh-only, fail-loud rewrite.

One premise correction up front, since the question's framing says "squash-merge SHAs per phase": **master landings are not squash merges.** The squash step in this repo is the *vendored refresh* — `git subtree merge --prefix=.agents/skills/shippEdd master --squash` (`.planning/phases/06-github-mirror/06-06-PLAN.md:45`) — which lands master content onto `progressEdd` as a `Squashed '.agents/skills/shippEdd/' changes from <a>..<b>` commit. Master itself receives, depending on era: direct linear commits (01/02), per-plan `merge(<pid>): plan <pid> into master` gate bubbles (03/04), per-phase `merge(<NN>-<slug>/<target>):` gates (05+), or a GitHub PR merge commit when disposition is `pr` (06). Details per question below.

## Question 1 — phase ship commits on master + the backfill's SHA sourcing

### Findings

**Repo topology (context for every command):** `.planning/` is tracked **only on `progressEdd`** (verified: `git ls-tree master --name-only` has no `.planning`; `progressEdd` has it). `master` is the canonical skill source; `progressEdd` is the live dogfood branch where the vendored copy (`.agents/skills/shippEdd/`), `.planning/`, and every `chore(<NN>-<slug>): ship — tick roadmap` docs commit live. RELEASES.md will therefore live on `progressEdd`.

**Verified per-phase master landings** (all from `git log master --format='%h %cI %s'` on this repo):

| Phase | Landing shape on master | Ship SHA(s) | Ship docs commit (progressEdd) |
|---|---|---|---|
| 01 | linear commits, no merges (pre-merge-back) | era: `c1cac58`/`a3d7b62`/`ff08970`, endpoint `fa1f042` (2026-11-17T00:22) | `04d6356` "ship — tick roadmap, archive phase" |
| 02 | linear commits, no merges | era `7d27ac5`…`b0e3566` (all 13:32:31), endpoint `9cfdf5a` (13:50) | `20c9833` |
| 03 | per-plan gate merges `merge(03-0N): plan …` | `2fc280c`, `e61f30d`, `ad80f53`, endpoint `6e61d95` (17:41) | `ae838a6` |
| 04 | per-plan gate merges `merge(04-0N): plan …` | `fcbd83f`, `4bce285`, `170b994`, endpoint `5aac779` (21:13); 04-FX1 rode `progressEdd` gate `4634433` (its `target:` is progressEdd) | `7a91099` |
| 05 | per-phase gates `merge(05-dispatcher-consolidation/master):` | `5a48f5d` (00:45) then `73af3f8` (11:55) — newest contains all earlier work (verified `git merge-base --is-ancestor 5a48f5d 73af3f8`); 05-06/05-FX2 rode `progressEdd` gate `143807e` | `9eb16ff` |
| 06 | GitHub PR merge (disposition `pr`) | `560d1d5` "Merge pull request #60 from progressEdd/agent/06-github-mirror/master" (2026-11-19T04:47Z); progressEdd leg = PR #61 merge `80830cb` + subtree squash `07234cf` (range `73af3f8..560d1d5`) | `47ae25a` |

**Exact commands a RELEASES.md entry would cite** — era-aware, mirroring what the scripts themselves use:

- Phase-landed idempotence probe (what `merge-back.sh:41` itself runs): `git log <target> --merges --grep "merge(<NN>-<slug>/<target>):" -1 --format=%H`
- Per-phase gate era (05+): `git log master --merges --grep "merge(<NN>-<slug>/master):" -1 --format='%H %cI %s'` — the newest match is the landing record; a later sweep's gate contains all earlier work of the phase on that target.
- Per-plan era (03/04): `git log master --merges --grep "merge(<NN>-<slug>/" --format='%h %cI %s'` — lists the plan gate bubbles; the newest (`6e61d95` for 03, `5aac779` for 04) closes the phase on master.
- PR-disposition era (06): `git log master --merges --grep "agent/<NN>-<slug>/master" -1 --format='%h %cI %s'` (PR-merge subject carries the agent branch name).
- Pre-merge-back eras (01/02): **no merge commits exist** — the era endpoint is a linear commit (`fa1f042`, `9cfdf5a`); identify via chain steps 3–5 below or via the subtree squash ranges.
- Ship dates: `git log progressEdd --grep "ship — tick roadmap" --format='%h %cI %s'` — yields all six docs commits (`04d6356`…`47ae25a`).
- Master-range bound per refresh (the actual squash-merge record): `git log progressEdd --format='%h %s' --grep "^Squashed '.agents/skills/shippEdd/'"` — e.g. `07234cf` = `73af3f8..560d1d5` (phase 06), `343f18b` = `5a48f5d..73af3f8` (05-FX1). Each names the master range the refresh carried.

**How phase 06's backfill sourced its merge-commit SHAs** — `.agents/skills/shippEdd/scripts/gh-mirror.sh:448-460`, `plan_target()` (:446-449) + `merge_sha()` (:450-460): for each plan sub-issue it reads the plan's frontmatter `target:` (missing = master) and resolves the SHA **from git history on that branch** via a first-hit-wins chain:

1. `git log "$t" --merges --grep "merge($pid):" -1 --format='%H%x09%s'` — transitional per-plan gate bubbles (03/04 era)
2. `git log "$t" --merges --grep "merge($nn-$slug/$t):" -1` — per-phase gate, **newest match** (04-FX1 onward; a later gate contains the phase's earlier work)
3. `git log "$t" --grep "($pid)" -1` — conventional plan-id commits (01/02 era)
4. `git log "$t" --grep "$pid" -1` — bare plan-id mentions
5. `git log "$t" --grep "$nn-$slug" -1` — phase-named docs commits (last resort)

Live results, recorded in `.planning/phases/06-github-mirror/06-05-SUMMARY.md` (frontmatter `key-decisions`/`deviations`): 24/27 plan-issue bodies carry a history-valid 40-hex SHA. Era spots verified: 05-01…05-FX1 → `73af3f86…` (master gate, chain step 2), 05-06 + 05-FX2 → `143807e4…` (progressEdd gate), 04-FX1 → `4634433d…` (progressEdd gate), 01-01 → `c1cac58b…` (step 3), 02-01 → `77c0bfbb…` (step 3 on master, once its placeholder `target:` counts as master). Three misses recorded verbatim, never hand-injected: 02-05 and 02-06 (their era gate `1d7a406` "chore(02-execution-record-rework): waves 1-2 executed" exists on **progressEdd** but the chain greps only the plan's `target:` branch, which says master) and 02-01 (placeholder target; resolvable as `77c0bfbb` on master).

### Recommendation

RELEASES.md entries should cite the era-aware command chain above, not a single pattern: for phases 03+ the newest `merge(<NN>-<slug>/<target>):` gate (or the PR merge when disposition was `pr`) is the master ship SHA; for 01/02 the era endpoint is a linear commit bounded by the subtree squash ranges. The backfill's `merge_sha()` chain in `gh-mirror.sh` is the repo's own precedent and the natural thing for a prune-time helper (or review prose) to reuse — it already encodes the newest-match law and the per-plan `target:` branching, and its three known misses document exactly where the chain needs a progressEdd fallback if RELEASES.md ever needs phases 01/02's era gates.

## Question 2 — review's ship-step PR offer + every disposition site

### Findings

**The offer's exact current shape** — `.agents/skills/shippEdd/review/SKILL.md`, Step 5 — SHIP (:173), ordered steps:

- **:181 (step 5, "Push / PR")** — verbatim gate: "**Push / PR** — only if `command -v gh` succeeds **and** `git remote` is non-empty; otherwise one line — "no gh or no git remote — commits stay local" — and skip:". Then the question block (:183-188):

  ```
  ❓ Push and open a PR for this phase?
    ➡️ 1. create PR — push the branch and open a pull request; body = the phase digest
      2. just push — push the branch, no PR
      3. neither — leave the commits local
  ```

- **:190** — the **phase digest** (PR title/body) is built from the phase's SUMMARY files (frontmatter `provides` + Accomplishments) plus the verification verdict; title `Phase <NN>-<slug>: <goal>`.
- **:192-196 (step 6, "Mirror ship sweep")** — gated on `github.mirror: true` only; runs `gh-mirror.sh … ship --verdict`; never-block.
- **:199-205** — the ship receipt: `commits <k> (the phase's merge and docs commits)` / `PR <url, or "—">` / `mirror <…>` / `next up <…>`.

**The step reads NO disposition and NO change-scope signal** — that is exactly todo 12's gap (CONTEXT decision 6: offer a PR iff disposition resolves to `pr` AND the ship changed files outside `.planning/`; docs-only ships get commit + push with no PR question; gh-auth facts shape the recommendation, never the gate).

**Every site that reads `disposition` today** (grep over the vendored suite + state dir):

1. **`scripts/runs-dir.sh`** — the only config reader: `disposition_cfg()` :34-38 (grep -o on `<state>/config.json`), query `disposition` :88 → prints the value, **default `pr` when the key is absent**.
2. **`implement/scripts/merge-back.sh`** — the only behavior consumer: :24 resolves via `runs-dir.sh disposition`; :88 `if [ "$disposition" = pr ]` opens the PR path (push + `gh pr create --base <target> --head <agent>` :141-143, PR body literally titled "shippEdd merge-back opened this PR (disposition: pr)" :136, receipt strings :94/:103/:106/:132/:154); `pr_fallback` (:90-108) covers no-gh/no-remote/unauth/push/create failures, exit 0; the auto-merge fallthrough (:156-161) does `git merge --no-ff --no-edit -m "merge(<NN>-<slug>/<target>): phase … into <target>"`.
3. **`gh-mirror.sh`** — **does NOT read disposition at all** (verified: zero matches; it reads only the `github.*` config keys). The CONTEXT question listed it as a possible site; it is not one.
4. **Docs/prose (no behavior):** `bootstrap/SKILL.md` :9, :192 ("Option 1 writes nothing (absent = pr); option 2 writes `"disposition": "auto-merge"`"), :257, :297, :312 (step 4b + persistence + gate + rerun); `bootstrap/README.md` :23-24 (FAQ), :52 (Configuration reference table: `pr` (push + `gh pr create`, receipt fallback) or `auto-merge`), :72; `bootstrap/templates/README.md` :8 (state-dir README default table); `implement/SKILL.md` :55 (Landed oracle: PR receipt = landing record under pr), :93 (PR-unavailable fallback guidance); `implement/README.md` :5; suite `README.md` :32; `scripts/auto-selftest.sh` :175-178, :287-290, :332, :372 (sandbox fixtures **pin `"disposition": "auto-merge"`** for the merge cases).
5. **Live config:** `.planning/config.json` reads **`"disposition": "pr"`** — the CONTEXT's banked research ("carries auto-merge") is stale: it was switched at phase-06 definition (commit `ffc5896`, "disposition switched to pr"), recorded in 06-05-SUMMARY's deviations. **Todo 12's gate will evaluate to `pr` on this repo today**, and phase 06's own master landing went through a real PR (#60) under it.
6. Push-first convention (unchanged): `02-worktrees/README.md`, commit `4997686` "agent branch flow is push-first — PR only if the human wants one".

### Recommendation

Todo 12's edit is one prose block: replace `review/SKILL.md:181-190`'s binary gh+remote gate with the decision-6 gate — resolve disposition via the same resolver merge-back uses (`bash .agents/skills/shippEdd/scripts/runs-dir.sh disposition`, absent = `pr`), compute the ship's change scope (paths outside `<state>/` across the ship's commits), and offer the three-option question only when disposition = `pr` AND scope is non-empty; otherwise the push-first one-liner. Everything else (digest builder, mirror sweep :192-196, receipt) keeps its shape, with the receipt's `PR` line and the step's skip line updated to say why no PR was offered. No `gh-mirror.sh` change is involved; `merge-back.sh`/`runs-dir.sh` already implement the disposition semantics the prose should mirror, so the gate can quote their resolver verbatim.

## Question 3 — saved-JSON / standalone-jq inventory in `gh-mirror.sh`

### Findings

Complete inventory of every jq dependency in `.agents/skills/shippEdd/scripts/gh-mirror.sh` (the vendored copy that actually runs). "Standalone jq" = the external `jq` binary (not on this machine's interactive PATH — nix-store only, per 06-05-SUMMARY deviations); "gh --jq/-q" = the gojq embedded in gh ≥ 2.94, no install needed.

**Standalone-jq sites (the todo-13 targets):**

1. **`:53` `j()` — the config reader.** `j() { jq -r "$1" "$cfg" 2>/dev/null || true; }` over `$cfg` = `<state>/config.json`. Six call sites :55-60: `mirror_on` (`.github.mirror // false`), `cfg_host`, `cfg_account`, `cfg_repo`, `label0` (array-first: `(.github.labels // ["shippedd"])[0]`), `cfg_token_env`. **Cannot move to gh --jq:** gh's `--jq`/`-q` filter *gh command output* (API responses) — gh cannot parse a local file (`gh api --input <file>` only sends a file as a request body; verified against `gh api --help`). **Needs the flat-key bash restructure**: a grep-based reader on the `runs-dir.sh` precedent (`runs_cfg`/`disposition_cfg` :33-41 — `grep -o '"key"[[:space:]]*:[[:space:]]*"…"'`) with three shape notes: `mirror` is a bare boolean (`grep -q '"mirror"[[:space:]]*:[[:space:]]*true'`, the `runs_flag` pattern); `labels` needs the first string inside `[ … ]`; the rest are flat strings. **Fail-loud requirement:** today a parse failure is silent — `2>/dev/null || true` yields empty, `mirror_on` reads false, and `preflight` exits 0 with "off — github.mirror is absent/false" (the exact silent-mirror=off defect todo 13 bans). The rewrite must distinguish *key absent* (documented default) from *file unparseable* (named receipt, per CONTEXT decision: "Config-read failures must be loud").
2. **`:112-113` `issues_json` — the saved issue list.** `refresh_issues()` makes ONE call: `ghm issue list --state all --limit 1000 --json number,title > "$work/issues.json"`. Parsed standalone at:
   - **`:115` `find_issue()`** — `jq -r --arg k … 'map(select(.title|startswith($k))) | .[0].number // empty' "$issues_json"` — prefix lookup, called many times per sweep (parent, every decision, every plan, FX lookups) against the same cache.
   - **`:299` drift loop** — `jq -r '.[] | "\(.number)\t\(.title)"' "$issues_json"` feeding the re-sync close.
   
   **Both move to fetch time — no re-query needed.** Append `--jq '.[] | "\(.number)\t\(.title)"'` to the single `ghm issue list` call and keep the TSV lines instead of JSON; `find_issue` becomes a bash prefix match over those lines (`case "$title" in "$key"*)` — the load-bearing trailing-space lookup keys (:82-83 comment, `[06] D4` vs `[06] D40`) survive verbatim as glob prefixes), and the drift loop becomes `while IFS=$'\t' read -r num title`. One gh call per sweep is preserved; the saved file's format changes from JSON to TSV, which is inside the helper's own contract.
3. **`:392` subIssues sweep in `cmd_ship`** — `ghm issue view "$pn" --json subIssues --jq '.subIssues[].number'`. **Already gh --jq — no standalone jq.** The live defect is shape-only: gh's `subIssues` is a connection object (`{ "subIssues": { "nodes": [ … ] } }`), so the correct program is `.subIssues.nodes[].number` (verified live pre-fix: 26 nodes; the flat form returned 0 — CONTEXT decision 4, 06-05-SUMMARY deviations). The fake-gh fixture in `scripts/auto-selftest.sh` must emit the nested shape in lockstep (fixture/live divergence = defect per CONTEXT).

**Already gh-side — no change, no standalone jq:** `:152` label list `--jq '.[].name'`; milestone lookups `:161`, `:163`, `:395`, `:497` (`gh api … --jq`); body reads `:264`, `:324` (`-q .body`); the six state guards `:340`, `:354`, `:380`, `:388`, `:446`, `:478` (`-q ".state | ascii_downcase"`). The backfill's `merge_sha()` (:450-460) is pure git — no jq.

**Adjacent dependency worth pinning:** `scripts/auto-selftest.sh` itself requires standalone jq (`:22` "needs git + bash + jq"): its fake-gh implements gh's `--jq`/`-q` by piping emitted JSON through external `jq` (:450-452, :463, :478, :491-507). The CONTEXT decision scopes the bash+gh-only law to **the helper**; the selftest's fake would still need jq unless its handful of fixed `--jq` programs are re-implemented in bash too — the planner should state which side of that line the law lands on.

### Recommendation

The jq-free rewrite is three local changes, no re-query anywhere: (a) replace `j()` with a flat-key bash reader that fails loud on unparseable config while keeping absent-means-default; (b) re-fetch the issue list once with an embedded `--jq` printing `number\ttitle` TSV and do `find_issue`/drift matching in bash; (c) fix the subIssues shape to `.subIssues.nodes[].number` and mirror it in the fake-gh fixtures. Every other parse already rides gh's embedded gojq.

## Risks / unknowns

- **Config-reader nesting ambiguity (todo 13):** a flat grep-based reader matches `"mirror"` anywhere in the file, not just under `github.*`. Today's config has no colliding key and the `runs-dir.sh` precedent accepts the same limitation; a pathological user config (a second object with a `mirror` key) could false-positive. Mitigation if wanted: require the key inside the `github` block by grepping the block's span, or document the flat-key limitation next to the config reference.
- **TSV fragility at the `issues_json` restructure (todo 13):** issue titles can contain tabs/newlines in theory (GitHub titles are single-line, so tab is safe; newline is impossible). The current drift loop already relies on the same tab contract (`:299`), so this is not a new assumption — but the receipt's `short()` cut (72 chars) must keep operating on the bash variable, not re-read the file.
- **The three backfill SHA misses (02-05, 02-06) stay unresolved in the live mirror:** their issue bodies carry "not resolvable" wording because the chain never greps progressEdd for a master-targeted plan. RELEASES.md's phase-02 entry will need the era gate `1d7a406` (progressEdd) or the linear master endpoint `9cfdf5a` — decided by whoever writes the first release entry; both commands are verified above.
- **Stale banked fact corrected:** `.planning/config.json` is `pr`, not `auto-merge` (CONTEXT decision-3/6 rows and the todo-12 banked research say auto-merge; the switch happened at `ffc5896` during phase-06 definition). Todo 12's gate and any phase-07 PR-flow testing should expect `pr` semantics live.
- **`auto-selftest.sh` still needs standalone jq** for its fake-gh `--jq` emulation even after the helper goes jq-free — the "bash + gh only" law's scope (helper vs whole suite) is the planner's call; fixtures must gain the nested `subIssues.nodes` shape either way.
- **Phase-06 progressEdd ship anomaly (cosmetic):** PR #61's merge `80830cb` carries a UTC timestamp (2026-11-19T05:16Z) while the neighboring local commits read 2026-11-18T23:xx-06:00 — GitHub-side merge clock vs local clock. Any RELEASES.md entry citing dates should pick one clock (the `chore(…): ship — tick roadmap` commits are the local-clock record).
- Unanswered: none — all three questions resolved from the repo, its git history, and the vendored scripts. (Phase-01's ship docs commit says "tick roadmap, **archive phase**" — an early-era archive convention that predates and doesn't conflict with decision 5's RELEASES.md shape; noted only so the planner doesn't read it as an existing prune law.)
