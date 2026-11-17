# shippEdd
A series of prompts for your ai coding agent

> Repo structure is based on [project-template](https://github.com/progressEdd/project-template).

## Getting Started
This repo uses git submodules to embed other repos. To get started, clone the repository and initialize the submodules:

If you would like a quick one line clone, you can use this command:
```bash
git clone --recurse-submodules https://github.com/progressEdd/shippEdd.git
```

If you have already cloned the repository, you can initialize the submodules with the following commands:
```bash
git pull
git submodule update --init --recursive
```

If you only need specific submodules, you can initialize them individually:
```bash
# For just the dev-onboarding submodule
git submodule update --init 01-dev-onboarding
```

## Repo Structure
| Path | Purpose |
|------|---------|
| `00-dev-log/` | Development log entries |
| `00-supporting-files/` | Supporting data files (e.g. sample env files) |
| `01-dev-onboarding/` | Submodule: [dev-onboarding](https://github.com/progressEdd/dev-onboarding) |
| `02-worktrees/` | Git worktrees for active experiments |
| `.agents/` | Agent assets; skills subtree mirroring `master` (see [Agent Skills](#agent-skills-git-subtree)) |

## Agent Skills (git subtree)

The skill definitions from the `master` branch are embedded into `progressEdd` at `.agents/skills/shippEdd/` using `git subtree`, so they are available from a fresh clone.

After committing changes to `master` (e.g. in `02-worktrees/master`), sync the embedded copy from the main repo root:

```bash
git subtree merge --prefix=.agents/skills/shippEdd master --squash
```

> Note: `git subtree pull` expects a remote-style `<repository> <ref>` argument pair and will fail with
> `fatal: you must provide <repository> <ref>` when given just a branch name. For a local branch in
> this repo, use `subtree merge` as shown above.

## Active Experiments

Projects branched from `00-experiments`, each with its own worktree in `02-worktrees/`.

| Branch | Description | Worktree Path | Created |
|--------|-------------|---------------|---------|
| `progressEdd` | Restructure shippEdd to be based on project-template. | — | — |

To set up a worktree for an existing branch:
```bash
git worktree add 02-worktrees/<branch-name> <branch-name>
```
