---
title: Getting started
nav_order: 2
---

# Getting started
{: .no_toc }

1. TOC
{:toc}

## Requirements

| What | Why |
| --- | --- |
| A [harness](harnesses) | Runs the skills, such as Claude Code or OpenCode. Your session is the coordinator. |
| [Orca](https://github.com/stablyai/orca) | Gives each ticket its own worktree and runs the workers. Start the coordinator session from an Orca terminal. |
| [GitHub CLI](https://cli.github.com/) | Reads issues, opens and merges PRs, watches CI. Run `gh auth login` first. |
| [mattpocock/skills](https://github.com/mattpocock/skills) | Workers build with its `tdd` skill and review with `code-review`. |

`/setup-ship-tickets` checks each of these for you.

## Install the skills

In Claude Code, install the plugin:

```
/plugin marketplace add samfaina/agent-skills
/plugin install agent-skills@samfaina
```

In any other harness, install with [skills.sh](https://skills.sh/):

```
npx skills add samfaina/agent-skills
```

Use one or the other in a given harness, not both, or every skill shows up twice. Install Matt Pocock's skills the same way in each harness your workers run in. [Harnesses](harnesses#install) has the commands for each harness.

## Set up a repo

Open a session in an Orca terminal, inside the repo, and run:

```
/setup-ship-tickets
```

It works in three steps.

1. **Preflight.** It checks that `gh` is logged in, that `orca` is on your `PATH` and serves its orchestration guide, that the session runs in an Orca terminal, and that the repo has a `ready-for-agent` label. It offers to create the label. Anything else that fails is reported with the fix, and setup carries on.
2. **Gather.** It fills in every field of [`shipping.md`](shipping-md) from what the repo already says: allowed merge methods, the auto-delete-branch setting, CI workflows and recent check runs, past branch names, the PR template or recent PR bodies. It asks you about the fields it can't settle, with its best guess as the first option. Two of them no repo setting covers: **Merge approval** (it proposes `ask`) and **Workers**, the harness each worker runs in (it proposes `claude`). Once it knows which harness runs the implement worker, it checks that the worker will load the `tdd` and `code-review` from mattpocock/skills and not another skill with the same name. [Harnesses](harnesses#workers) explains the check.
3. **Open the PR.** It writes `docs/agents/shipping.md` in a separate worktree, so your checkout isn't touched, and shows it to you. Once you approve, it opens a PR.

**Merge that PR.** The loop always reads `shipping.md` from the remote default branch, so it runs the same from any worktree, and it won't start until the file is there.

Running `/setup-ship-tickets` again later updates the file: it keeps the values you have and fills in fields it lacks, such as ones added in newer versions of the skills. If the file already matches, it opens no PR and tells you `shipping.md` is up to date.

## Write tickets the loop can ship

Each ticket is one GitHub issue that a worker can finish without asking around:

- **Acceptance criteria.** The implement worker treats them as its definition of done, and the full test suite has to pass.
- **Links to specs or parent issues** when the ticket depends on them. The worker reads what the issue links.
- **Dependencies** as GitHub blocking links, or `Blocked by: #12, #15` lines in the body. A ticket ships only once all its blockers are closed.

Label the ones that are ready `ready-for-agent`, or pass issue numbers to the skill.

## Ship

```
/ship-tickets
```

With **Merge approval** set to `ask`, the default, the loop stops after CI goes green on each PR. It shows you the PR link, title and size, and asks you to **Merge**, **Request changes** (a fix worker takes your notes, then CI runs again) or **Stop**. Once you trust the loop on a repo, set `Merge approval: auto` in `shipping.md` and it merges as soon as CI is green.

A first word of `ask` or `auto` overrides the field for one run, and issue numbers pick the tickets:

```
/ship-tickets auto 41 42 47
```

The coordinator still orders the tickets by their blockers. At the end it reports each ticket as **merged** (with the PR link), **stopped** (where, why and what you need to do) or **not started** (the blockers holding it, or the failed provenance check).
