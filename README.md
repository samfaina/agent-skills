# agent-skills

A Claude Code plugin that ships GitHub tickets for you. It takes the issues in your repo and works through them one at a time: an agent builds each one test-first, another opens the PR, then the loop waits for CI and merges. The next ticket starts from the branch the last one merged into.

**Documentation:** https://samfaina.github.io/agent-skills/

## Skills

| Skill | What it does |
| --- | --- |
| `/setup-ship-tickets` | Checks the repo is ready for the loop and opens a PR adding `docs/agents/shipping.md`, filled from the repo's settings and PR history. Run it once per repo. |
| `/ship-tickets [#n…]` | Ships the tickets one at a time: implement, open the PR, wait for CI, merge. |
| `/ship-tickets-reviewed [#n…]` | The same loop, pausing for your approval before each merge. |

With no issue numbers, both shipping skills take every open issue labelled `ready-for-agent`.

## Requirements

- [Claude Code](https://github.com/anthropics/claude-code), running inside an [Orca](https://github.com/stablyai/orca) terminal. Your session is the **coordinator**, and every ticket gets its own Orca worktree and worker agents.
- The [GitHub CLI](https://cli.github.com/) (`gh`), authenticated against the repo.
- The [mattpocock-skills](https://github.com/mattpocock/skills) plugin. Workers build with its `tdd` skill and review with `code-review`.
- Tickets as GitHub issues. Dependencies are GitHub blocking links or `Blocked by: #n` lines in the issue body, as `/to-tickets` writes them.

## Install

```
/plugin marketplace add samfaina/agent-skills
/plugin install agent-skills@samfaina
```

## Quick start

1. In the repo you want to ship from, run `/setup-ship-tickets`. It reports anything missing and opens a PR with `docs/agents/shipping.md`.
2. Merge that PR. The loop reads the file from the default branch.
3. Label the issues you want shipped `ready-for-agent`, or pass their numbers.
4. Run `/ship-tickets-reviewed` the first few times to approve each merge yourself, and `/ship-tickets` once you trust the loop.

When a ticket can't be finished, the loop stops and leaves its worktree and PR as they are, so you can see what happened. The [troubleshooting page](https://samfaina.github.io/agent-skills/troubleshooting) covers each stop.

## Repository layout

| Path | Contents |
| --- | --- |
| `skills/` | One folder per skill, each with its `SKILL.md` and an `agents/openai.yaml` for Codex CLI. |
| `shared/ship-tickets-loop.md` | The loop both shipping skills run, with the specs sent to each worker. |
| `shared/shipping-template.md` | The format of `docs/agents/shipping.md`. |
| `docs/` | The documentation site, published with GitHub Pages. |

Every skill is user-invoked. Codex CLI ignores `disable-model-invocation: true` in `SKILL.md` and reads `allow_implicit_invocation: false` in `agents/openai.yaml` instead, so change the two together.

## Local development

Add your checkout as a marketplace instead of the GitHub repo:

```
/plugin marketplace add <path-to-checkout>
/plugin install agent-skills@samfaina
```

GitHub Pages publishes the documentation site in `docs/` on every push to `main`.
