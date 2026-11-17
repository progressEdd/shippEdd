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
