# Phase 06-github-mirror Research

**Researched:** 2026-11-18 — background run 06-research (`/tmp/shippEdd/06-github-mirror`)

## Question

Five open questions parked during phase 06 grilling (see `06-CONTEXT.md` "Open questions"), all about the `gh` mechanics the mirror helper will sit on:

1. Sub-issue CLI support at the installed gh **v2.103.3** (2026-10-26): create-with-parent, list/remove sub-issues — flag or dedicated command? Is a REST/GraphQL fallback needed?
2. Per-repo account mechanics: `gh auth token --user <account>` with multiple stored accounts; `GH_TOKEN`/`GH_HOST` precedence over stored auth; interaction with `gh auth status`; whether the chain `GH_HOST=github.com GH_TOKEN="$(gh auth token --u <account>)" gh issue create …` picks the named account without touching global gh state; gh's ability to resolve this repo's SSH-aliased remote (`git@github.com-secondary:progressEdd/shippEdd.git`).
3. Canonical official "install GitHub CLI" doc URL for bootstrap's setup guidance.
4. Progress-update mechanics for plan issues: markdown tasklists vs sub-issue tasklists, check-off via API/CLI vs per-task comments — recommend one mechanism.
5. Exact commands for per-phase milestones (create/assign/close), auto-create a label if missing, and PR-closes-issue mechanics via `gh pr create --body`.

Method note: for every question about gh behavior, the **primary source is the installed v2.103.3 itself** — `--help` text probed locally (read-only; no global state touched) plus empirically safe probes (scratch git repos in `/tmp/gh-probe/`, one deliberate 401 API call). Release notes and docs.github.com URLs were fetched live to pin citations. Nothing was taken from memory without verification.

## Findings

### Q1 — Sub-issue command surface at gh v2.103.3

**Verdict: full sub-issue support via flags on `gh issue create`/`gh issue edit` — no REST/GraphQL fallback needed. No dedicated `gh issue sub-issue` command group exists at this version.**

All from local `--help` probes on the installed binary (`gh version 2.103.3 (2026-10-26)`, `https://github.com/cli/cli/releases/tag/v2.103.3`):

- **Create with parent:** `gh issue create --parent number` — help verbatim: `--parent number   Add the new issue as a sub-issue of the specified parent number or URL`. Examples in help: `gh issue create --parent 100`, `gh issue create --parent https://github.com/cli/go-gh/issues/42` (accepts number or URL).
- **Set/remove parent on an existing issue:** `gh issue edit <n> --parent 100`, `gh issue edit <n> --remove-parent` (both in help examples verbatim) — this is the re-sync path for re-parenting without delete/recreate.
- **Add/remove sub-issues on a parent:** `gh issue edit 100 --add-sub-issue 123,124` (comma-separated), `--remove-sub-issue number` ("Remove sub-issues by number or URL"). Help examples verbatim: `gh issue edit 23 --parent 100`, `gh issue edit 100 --add-sub-issue 123,124`.
- **List sub-issues:** no dedicated list subcommand, but `gh issue view --json` fields (verbatim from help) include `parent`, `subIssues`, `subIssuesSummary`, plus `blockedBy`/`blocking` — the sweep reads the whole tree with plain `gh issue view <n> --json subIssues,subIssuesSummary`. No GraphQL needed.
- **No `gh issue sub-issue` command:** `gh issue --help` lists no such group (TARGETED COMMANDS: artifact, close, comment, delete, develop, edit, lock, pin, reopen, transfer, unlock, unpin, view); `gh issue sub-issue …` falls through to the parent help.
- Adjacent capability shipped in the same surface (useful later, not in decisions): issue dependencies — `gh issue create --blocked-by/--blocking`, `gh issue edit --add-blocked-by/--add-blocking/--remove-blocked-by`.

**Citations (fetched live):**
- Release **v2.94.0** — "Issue types, sub-issues, and relationships in `gh issue`" (`https://github.com/cli/cli/releases/tag/v2.94.0`, verified HTTP 200): "This release brings GitHub's advanced issue features to `gh issue create`, `edit`, `view`, and `list`. You can set and view an issue's type, organize work with sub-issues…" with verbatim examples `gh issue create --parent 100`, `gh issue edit 100 --add-sub-issue 123`. PR: **#13057** "Add Issues 2.0 support: issue types, sub-issues, and relationships". Platform note verbatim: "Issue types and sub-issues are available on GitHub.com and GHES 3.17+; relationships require GHES 3.19+." → **gh ≥ v2.94.0 is the version floor for the helper's sub-issue surface**; installed 2.103.3 clears it.
- GitHub changelog announcement of the same feature set: `https://github.blog/changelog/2026-06-10-manage-sub-issues-types-and-dependencies-from-github-cli/` (2026-06-10).
- Local help docs the version too: `gh --version` → 2.103.3.

### Q2 — Per-repo account mechanics

**Token selection — `gh auth token` (local help, verbatim):**
- "This command outputs the authentication token for an account on a given GitHub host. Without the `--hostname` flag, the default host is chosen. **Without the `--user` flag, the active account for the host is chosen.**"
- Flags: `-u/--user <login>`, `-h/--hostname <host>`.
- Multi-account store: supported since **v2.40.0** "Support for multiple accounts on a single host" (`https://github.com/cli/cli/releases/tag/v2.40.0`, verified 200; PR #8425) — multiple accounts per host in hosts.yml, exactly one **active** per host, `gh auth switch` changes it, `gh auth status` shows all accounts and marks the active one.
- **Side effect to know:** help verbatim — "If the token is an expired or near-expiry token that supports refreshing, it is refreshed automatically before being printed, unless `--no-refresh` is given." So `gh auth token --user X` is read-only *except* sanctioned token refresh; pass `--no-refresh` for a strictly no-touch read.
- Empirical (this machine): `gh auth token --user ghost-acc-nope` → `no oauth token found for github.com account ghost-acc-nope` — clean per-account lookup, no API call, no state change, clear error when the account isn't stored.

**Precedence — `gh help environment` (local, v2.103.3, verbatim; manual mirror: `https://cli.github.com/manual/gh_help_environment`, verified 200):**
- `GH_TOKEN`, `GITHUB_TOKEN` (in that order): "an authentication token that will be used when a command targets either `github.com` or a subdomain of `ghe.com`. … **takes precedence over previously stored credentials.**"
- `GH_HOST`: "specify the GitHub hostname for commands where a hostname has not been provided, or **cannot be inferred from the context of a local Git repository**. If this host was previously authenticated with, the stored credentials will be used."
- Enterprise tokens are separate: `GH_ENTERPRISE_TOKEN`/`GITHUB_ENTERPRISE_TOKEN` for GitHub Enterprise Server hosts — **`GH_TOKEN` does not apply to GHES**; the helper must pick the env var by configured host.
- Empirical proof that env wins for API calls: `GH_TOKEN=invalid_token_xyz gh api user` → HTTP 401 `{"message":"Bad credentials"}` — the env token was used even though a valid keyring token was stored.

**`gh auth status` interaction:** shows every known host, every account on it, and which is active ("Each host section will indicate the active account, which will be used when targeting that host" — local help). Env tokens don't appear there; it reports the stored state. On this machine right now: single host `github.com`, single account `progressEdd`, `Active account: true`, token in system keyring (`hosts.yml` itself was deliberately not read — it stores non-secret fields; the secret is in the keyring).

**The proposed chain — confirmed, with one refinement:**
`GH_HOST=github.com GH_TOKEN="$(gh auth token --user <account>)" gh issue create …` authenticates the API call as the named account (GH_TOKEN precedence beats stored credentials) and never switches the active account (`gh auth token` only prints; hosts.yml/keyring untouched apart from token refresh). It works, but **GH_HOST is not the load-bearing half** — host alone doesn't tell gh which repo to target, and on github.com with GH_TOKEN set, GH_HOST is usually unnecessary. The load-bearing half is the explicit repo: `GH_REPO=OWNER/REPO` (env) or `-R [HOST/]OWNER/REPO` (flag). Minimal robust chain for the helper:

```bash
GH_TOKEN="$(gh auth token --user "$account")" gh issue create -R "$owner/$repo" …
```

Empirics backing that: in a scratch repo with an unresolvable remote, `GH_REPO=cli/cli gh issue list` and `-R cli/cli` both succeeded (read-only API hits), while `GH_HOST=github.com` alone did not rescue resolution (see below).

**SSH-aliased remote — premise partially corrected (this matters for the helper):**
- **True in general:** a repo whose *stored* remote is an unknown-host alias cannot be resolved by gh. Scratch probes (`/tmp/gh-probe/t1`, `t2`): remote `git@weirdhost-alias:owner/repo.git` and even `git@github.com-enterprise.local:owner/repo.git` → `none of the git remotes configured for this repository point to a known GitHub host. To tell gh about a new GitHub host, please use 'gh auth login'`. Adding `GH_HOST=github.com` does NOT rescue: `none of the git remotes configured for this repository correspond to the GH_HOST environment variable` — gh parses owner/repo from any scp-style URL but requires the remote host to match a known host (or GH_HOST), and an arbitrary alias is not one.
- **True of THIS repo specifically:** gh resolves fine here with *no* env at all (`gh repo view` → `progressEdd/shippEdd`). Reason, verified in git config: the local `.git/config` stores `remote.origin.url=git@github.com:progressEdd/shippEdd.git` (canonical github.com); the `github.com-secondary` form seen in `git remote -v` is a **transport-time `insteadOf` rewrite**, not the stored URL — two rules in `/nix/store/zg5y84y4zaz3nxpr3bn70p21sxi7l58x-hm_gitconfig` (included via `includeIf gitdir:*/progressEdd_projects/`): `url.git@github.com-secondary:.insteadOf` for both `https://github.com/` and `git@github.com:`. gh resolves remotes through the canonical github.com URL (hence success with only the github.com account stored); the alias governs only ssh push, which gh never touches.
- **Helper requirement:** never rely on remote inference. Resolve `OWNER/REPO` from config (`github.host` + repo identity — bootstrap's setup question owns this) and pass `-R`/`GH_REPO` on every call. That behaves identically on this machine, on a machine where the stored remote really is the raw alias, and in CI (plus the `token_env` headless path from decision 14). Known quirk: no-arg `gh repo view` ignores `GH_REPO` (empirically exit 1 in the scratch repo even with it set) — irrelevant for the helper, which uses issue/pr commands; those honor both `-R` and `GH_REPO`.

### Q3 — Canonical "install GitHub CLI" doc URL

- **`https://docs.github.com/en/github-cli/github-cli/quickstart`** — official GitHub Docs "GitHub CLI quickstart", verified HTTP 200. Page covers installing gh on macOS/Windows/Linux and `gh auth login`. This is the link for bootstrap's setup guidance (decision 10).
- Do **not** use `https://docs.github.com/en/github-cli/quickstart` — verified HTTP 404 (the docs path requires the doubled `github-cli/github-cli/` segment).
- Secondary stable surfaces (both verified 200): product site `https://cli.github.com/` and the manual `https://cli.github.com/manual/` / `https://cli.github.com/manual/gh_help_environment`.

### Q4 — Progress-update mechanics for plan issues

Three candidate mechanisms, each verified:

1. **Markdown tasklist in the issue body (`- [ ]`)** — doc: "About tasklists" `https://docs.github.com/en/get-started/writing-on-github/working-with-advanced-formatting/about-tasklists` (verified 200): tasklists break an issue's work into tasks with an aggregate N/M progress bar in the GitHub UI. **Mechanics:** the checkboxes are markdown inside the body, not a separate API object — there is no per-checkbox API. Check-off = update the body: `gh issue view <n> --json body -q .body` → rewrite the one `- [ ]` line for the completed task → `gh issue edit <n> --body-file -` (REST equivalent: PATCH `/repos/{owner}/{repo}/issues/{n}`, docs `https://docs.github.com/en/rest/issues/issues`, verified 200). Whole-body replace = last-write-wins; safe under the helper's single-writer pattern.
2. **Sub-issue tasklists (aggregate)** — sub-issues of a parent render native progress on the parent ("Adding sub-issues", `https://docs.github.com/en/issues/tracking-your-work-with-issues/using-issues/adding-sub-issues`, verified 200); gh exposes it as `gh issue view <parent> --json subIssuesSummary`. Reading it is free; *writing* it means minting one GitHub issue per plan task (a parent has a hard cap of ~100 direct sub-issues) — noisy, and not what decision 12 describes ("plan issues receive progress updates", not per-task issues).
3. **Per-task comments (`gh issue comment`)** — append-only log; no aggregate progress bar, no un-check, noisy; fine as an audit trail or fallback, weak as the primary tracker.

**Recommendation:** markdown tasklist in the plan issue's body, keyed on the plan's stable task identifiers (decision 7's lookup-key law carried into GitHub: e.g. `- [ ] [06-01] T1 — task title`). On task completion the helper fetches the body, flips the matching line, PATCHes it back; on update failure it never blocks the task (decision 12) and notes the miss in the receipt. The **phase parent needs no body maintenance for progress** — its sub-issues (the plan issues) render the native aggregate progress automatically, and decision 13's verdict comment + close finishes it. Reserve comments for the verdict and re-sync notes. This keeps all writes on the v2.94.0+ REST/flags surface (no GraphQL, no per-task issues) and matches decisions 1, 7, and 12 exactly.

### Q5 — Milestones + labels + closing keywords

All verified against local v2.103.3 help plus live doc/release fetches.

**Milestones — there is no `gh milestone` command** (probe: `unknown command "milestone" for "gh"`), so create/close go through `gh api` (REST milestones docs: `https://docs.github.com/en/rest/issues/milestones`, verified 200):

```bash
# create (returns JSON with .number)
gh api repos/"$owner/$repo"/milestones -f title="Phase 06: github-mirror" [-f due_on=… -f description=…]
# find an existing one by title (helper's idempotence check)
gh api repos/"$owner/$repo"/milestones --jq '.[] | select(.title=="Phase 06: github-mirror") | .number'
# assign to an issue — confirmed flag on gh issue edit at v2.103.3:
#   "-m, --milestone name   Edit the milestone the issue belongs to by name"
gh issue edit <n> --milestone "Phase 06: github-mirror"        # by title
gh issue edit <n> --remove-milestone                            # unassign
# close the milestone at ship (decision 13): state ∈ {open, closed}
gh api repos/"$owner/$repo"/milestones/<number> -X PATCH -f state=closed
```

**Labels — `gh label` group at v2.103.3 is `clone|create|delete|edit|list` (no `view`; probe: `unknown command "view" for "gh label"`).** Local `gh label create --help` verbatim: "Create a new label on GitHub, **or update an existing one with `--force`**", flags `-c/--color`, `-d/--description`. Idempotent create-if-missing, checked empirically (`gh label list --json name -q '.[].name'` works; `--search` available):

```bash
if ! gh label list --json name -q '.[].name' | grep -Fxq "shippEdd"; then
  gh label create "shippEdd" --color 5319E7 --description "shippEdd workflow artifact"
fi
```

Avoid `--force` for this: it *overwrites* color/description, and decision 15 lets `github.labels` point at a **user's existing label** — `--force` would silently restyle it. (Idempotent-again via `gh label create … --force` is acceptable only for the default `shippEdd` label on a repo the skill owns.)

**PR closes issue — no `--close` flag exists.** Probe of `gh pr create --help`: the only "close" match is the documented behavior, verbatim: "**If the body text mentions `Fixes #123` or `Closes #123`, the referenced issue will automatically get closed when the pull request gets merged.**" Closing keywords per GitHub docs (`https://docs.github.com/en/get-started/writing-on-github/working-with-advanced-formatting/using-keywords-in-issues-and-pull-requests`, verified 200): `close(s|d)`, `fix(es|ed)`, `resolve(s|d)` + `#N` (or `owner/repo#N`), honored in the PR **body** — exactly where merge-back already puts text (`gh pr create --base … --head … --title … --body …` in `.agents/skills/shippEdd/implement/scripts/merge-back.sh`). Phase 06's PR-body builder appends `Closes #<plan issue number>` from the plan's cached `issue:` field (decision 9).

## Recommendation

Build the helper on the flag surface, not GraphQL: `gh issue create --parent` + `gh issue edit --add-sub-issue/--remove-sub-issue/--parent/--remove-parent` for the tree, `gh issue view --json parent,subIssues,subIssuesSummary` for lookups — present in full at gh ≥ v2.94.0, and this machine's 2.103.3 clears it (add a `gh --version` gate so older installs fall into decision 5's never-block receipt). For per-repo accounts: resolve `OWNER/REPO` from config and pass `-R`/`GH_REPO` on **every** call (never remote inference), source the token with `gh auth token --user <account>` exported as `GH_TOKEN` (`GH_ENTERPRISE_TOKEN` for non-github.com hosts), optionally `--no-refresh`; that satisfies the decision-14 law with zero global gh state changes. Progress = markdown tasklists in plan-issue bodies (body fetch → line flip → `gh issue edit --body-file`), with the parent's sub-issue aggregate doing parent-level progress for free. Milestones via `gh api` (create/find/PATCH-close), label via list-check-then-`gh label create` (never `--force` against a user-configured label), and `Closes #N` in `gh pr create --body` for issue-closing — plus an explicit `gh issue close` in the merged-PR path whenever the target branch isn't the repo default (see risk below).

## Risks / unknowns

- **gh version floor elsewhere:** the sub-issue flag surface needs gh ≥ v2.94.0 (June 2026). On machines running older gh, `gh issue create --parent` errors as an unknown flag — the helper must gate on `gh --version` and route to the never-block fallback (decision 5), not crash mid-sweep.
- **Closing keywords fire only on merge into the repo's *default* branch.** Decision 9 says plan sub-issues "close automatically when their PR merges" — true only for default-branch PRs. merge-back supports arbitrary target branches; for non-default targets the PR body keyword will not close anything. Mitigation: after a PR merge (or at review's ship sweep), explicitly `gh issue close <n>` any plan sub-issues still open, or document default-branch-only auto-close.
- **Whole-body replace on tasklist check-off is last-write-wins.** Two concurrent writers (helper + human editing in the browser) can clobber one side. Acceptable under the helper's single-writer sweep pattern; worth one line in the helper's docs.
- **`gh auth token` auto-refresh touches the keyring-backed store** (benign, gh-sanctioned, but technically a write) — pass `--no-refresh` if strict no-touch matters; refresh-on-read is otherwise desirable (prevents mid-phase expiry).
- **`GH_TOKEN` covers github.com and `*.ghe.com` subdomains only;** a configured GHES host needs `GH_ENTERPRISE_TOKEN` — the helper must choose the env var from the configured `github.host`.
- **Un-exercised path:** this machine currently stores exactly one account (`github.com` / `progressEdd`, per `gh auth status`), so the two-accounts-in-hosts.yml flow is doc-verified (v2.40.0 + `gh auth token --user` help) but not yet exercised live; phase 06's first real sweep with a second account is the proof (decision 16's live-run story).
- **Premise correction recorded:** on this machine the stored `origin` URL is canonical `github.com`; the `github.com-secondary` alias exists only as a transport-time `insteadOf` rewrite (nix-store included gitconfig, scoped to `*/progressEdd_projects/`). Bootstrap/docs must not assume the stored remote is aliased — but the helper should still pass `-R` explicitly, because a raw-aliased remote (no rewrite) is genuinely unresolvable by gh, as the scratch probes prove.
- **Not researched (adjacent, out of scope):** issue types (`gh issue edit --type` exists at this version) and Projects v2 integration — CONTEXT decisions don't require either.
