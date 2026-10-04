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
| [Claude Code](https://github.com/anthropics/claude-code) | Runs the skills. Your session is the coordinator. |
| [Orca](https://github.com/stablyai/orca) | Gives each ticket its own worktree and runs the workers. Start the coordinator session from an Orca terminal. |
| [GitHub CLI](https://cli.github.com/) | Reads issues, opens and merges PRs, watches CI. Run `gh auth login` first. |
| [mattpocock-skills](https://github.com/mattpocock/skills) | Workers build with its `tdd` skill and review with `code-review`. |

`/setup-ship-tickets` checks each of these for you.

## Install the plugin

```
/plugin marketplace add samfaina/agent-skills
/plugin install agent-skills@samfaina
```

## Set up a repo

Open a Claude Code session in an Orca terminal, inside the repo, and run:

```
/setup-ship-tickets
```

It works in three steps.

1. **Preflight.** It checks that `gh` is logged in, that Orca is reachable, that the session runs in an Orca terminal, that the mattpocock skills are installed, and that the repo has a `ready-for-agent` label. It offers to create the label. Anything else that fails is reported with the fix, and setup carries on.
2. **Gather.** It fills in every field of [`shipping.md`](shipping-md) from what the repo already says: allowed merge methods, the auto-delete-branch setting, CI workflows and recent check runs, past branch names, the PR template or recent PR bodies. You get asked only about the fields it can't settle, with its best guess as the first option.
3. **Open the PR.** It writes `docs/agents/shipping.md` in a separate worktree, so your checkout isn't touched, and shows it to you. Once you approve, it opens a PR.

**Merge that PR.** The loop always reads `shipping.md` from the remote default branch, so it runs the same from any worktree, and it won't start until the file is there.

Running `/setup-ship-tickets` again later updates the file: it keeps the values you have and fills in fields it lacks, such as ones added in newer plugin versions.

## Write tickets the loop can ship

Each ticket is one GitHub issue that a worker can finish without asking around:

- **Acceptance criteria.** The implement worker treats them as its definition of done, and the full test suite has to pass.
- **Links to specs or parent issues** when the ticket depends on them. The worker reads what the issue links.
- **Dependencies** as GitHub blocking links, or `Blocked by: #12, #15` lines in the body. A ticket ships only once all its blockers are closed.

Label the ones that are ready `ready-for-agent`, or pass issue numbers to the skill.

## Ship

Start with the reviewed variant:

```
/ship-tickets-reviewed
```

After CI goes green on each PR, it shows you the PR link, title and size, and asks you to **Merge**, **Request changes** (a fix worker takes your notes, then CI runs again) or **Stop**.

Once you trust the loop on a repo, switch to `/ship-tickets`, which merges as soon as CI is green.

Either way, you can pass specific tickets:

```
/ship-tickets 41 42 47
```

The coordinator still orders them by their blockers. At the end it reports each ticket as **merged** (with the PR link), **stopped** (where, why and what you need to do) or **not started** (the blockers holding it).
