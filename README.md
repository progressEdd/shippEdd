# shippEdd
A series of prompts for your ai coding agent

## Use shippEdd in your project

Embed these skills into any repo with `git subtree`. They'll live under `.agents/skills/shippEdd/`, where agent harnesses can discover them.

### Add
```bash
git subtree add --prefix=.agents/skills/shippEdd https://github.com/progressEdd/shippEdd.git master --squash
```

### Pull updates
```bash
git subtree pull --prefix=.agents/skills/shippEdd https://github.com/progressEdd/shippEdd.git master --squash
```

### Contribute changes back
Edits made in your embedded copy can be pushed back as a branch for review:
```bash
git subtree push --prefix=.agents/skills/shippEdd https://github.com/progressEdd/shippEdd.git my-changes
```

> Tip: `git subtree` commands accept any prefix path — `.agents/skills/shippEdd` just matches the
> convention used by this repo's agent harness. To see this subtree setup in action, look at this
> repo's [`progressEdd`](https://github.com/progressEdd/shippEdd/tree/progressEdd/.agents/skills/shippEdd)
> branch, which embeds `master` at that path and keeps it synced with:
> `git subtree merge --prefix=.agents/skills/shippEdd master --squash`.

## Configuration reference

Every shippEdd config key — workflow toggles, run placement, merge-back disposition, and the opt-in GitHub mirror (`github.*`) — is documented in one place: [`bootstrap/README.md`](bootstrap/README.md#configuration-reference). Absent keys mean documented defaults; two exceptions are noted there (`workflow.ui_phase` is always written at setup, and `github.mirror` is opt-in — absent means off).

## Fresh sessions at every handoff

Every skill ends by naming the next command — run it in a fresh session (clear the current context first). That is always safe: nothing load-bearing lives in the conversation. Grilled decisions sit in `.planning/phases/<NN>-<slug>/NN-CONTEXT.md`, execution records in the `NN-YY-SUMMARY.md` files, run state in transient markers under the config-driven runs home (advisory; artifacts are the truth), and `STATE.md` frontmatter (`next_action`, `progress`) is the machine-read router — the next session rebuilds its position from disk alone. Research, verification, and execution already run detached in fresh contexts by design; clearing between skill invocations gives your orchestrating session the same clean start.
