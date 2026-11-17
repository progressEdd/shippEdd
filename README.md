# shippEdd
A series of prompts for your ai coding agent

## Embedded into `progressEdd`

This branch's contents are embedded into `progressEdd` at `.agents/skills/shippEdd/` via `git subtree`.

After committing changes here, sync the embedded copy from the main repo root:

```bash
git subtree merge --prefix=.agents/skills/shippEdd master --squash
```

> Note: `git subtree pull` expects a remote-style `<repository> <ref>` argument pair and will fail with
> `fatal: you must provide <repository> <ref>` when given just a branch name. Use `subtree merge` for
> local branches, as shown above.
