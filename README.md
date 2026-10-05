# agent-skills

Agent skills that ship GitHub tickets for you, from Claude Code, OpenCode or another harness that loads `SKILL.md` skills. They take the issues in your repo and work through them one at a time: an agent builds each one test-first, another opens the PR, then the loop waits for CI and merges. The next ticket starts from the branch the last one merged into.

**Documentation:** https://samfaina.github.io/agent-skills/

## Skills

| Skill | What it does |
| --- | --- |
| `/setup-ship-tickets` | Checks the repo is ready for the loop and opens a PR adding `docs/agents/shipping.md`, filled from the repo's settings and PR history. Run it once per repo. |
| `/ship-tickets [ask\|auto] [#n…]` | Ships the tickets one at a time: implement, open the PR, wait for CI, merge. With **Merge approval** `ask` it waits for your approval before each merge; with `auto` it merges as soon as CI is green. |

With no issue numbers, `/ship-tickets` takes every open issue labelled `ready-for-agent`. Without `ask` or `auto`, it uses the **Merge approval** field in `shipping.md`, which defaults to `ask`.

## Requirements

- A harness that loads `SKILL.md` skills, running inside an [Orca](https://github.com/stablyai/orca) terminal. Claude Code and OpenCode are tested; see [Harnesses](https://samfaina.github.io/agent-skills/harnesses) for the rest. Your session is the **coordinator**, and every ticket gets its own Orca worktree and worker agents, each in the harness `shipping.md` names for its role.
- The [GitHub CLI](https://cli.github.com/) (`gh`), authenticated against the repo.
- [mattpocock/skills](https://github.com/mattpocock/skills), in each harness your workers run in. Workers build with its `tdd` skill and review with `code-review`.
- Tickets as GitHub issues. Dependencies are GitHub blocking links or `Blocked by: #n` lines in the issue body, as `/to-tickets` writes them.

## Install

In Claude Code, as a plugin:

```
/plugin marketplace add samfaina/agent-skills
/plugin install agent-skills@samfaina
```

In OpenCode and other harnesses, with [skills.sh](https://skills.sh/):

```
npx skills add samfaina/agent-skills
```

Use one or the other in a given harness: installing both gives every skill twice. [Harnesses](https://samfaina.github.io/agent-skills/harnesses#install) has the commands for each harness, Matt Pocock's skills included.

## Quick start

1. In the repo you want to ship from, run `/setup-ship-tickets`. It reports anything missing and opens a PR with `docs/agents/shipping.md`.
2. Merge that PR. The loop reads the file from the default branch.
3. Label the issues you want shipped `ready-for-agent`, or pass their numbers.
4. Run `/ship-tickets`. With **Merge approval** `ask` you approve each merge yourself. Once you trust the loop, set it to `auto` in `shipping.md`, or run `/ship-tickets auto`.

When a ticket can't be finished, the loop stops and leaves its worktree and PR as they are, so you can see what happened. The [troubleshooting page](https://samfaina.github.io/agent-skills/troubleshooting) covers each stop.

## Upgrading to 0.3.0

- `/ship-tickets-reviewed` is gone. `/ship-tickets` is the only shipping skill, and the **Merge approval** field in `shipping.md` decides whether it asks before each merge.
- **Merge approval** defaults to `ask`. A `shipping.md` written before 0.3.0 doesn't have the field, so `/ship-tickets` now asks before each merge where it used to merge on green CI. Set `Merge approval: auto` to keep the old behavior, or run `/setup-ship-tickets` to fill in the new fields.
- The new **Workers** field picks the harness each worker runs in. Without it, every worker runs in Claude Code as before.

## Repository layout

| Path | Contents |
| --- | --- |
| `skills/` | One folder per skill, each with its `SKILL.md` and an `agents/openai.yaml` for Codex CLI. |
| `skills/ship-tickets/ship-tickets-loop.md` | The loop `ship-tickets` runs, with the specs sent to each worker. |
| `skills/ship-tickets/skill-provenance.md` | The check that workers will load Matt Pocock's `tdd` and `code-review`. |
| `skills/setup-ship-tickets/shipping-template.md` | The format of `docs/agents/shipping.md`. |
| `docs/` | The documentation site, published with GitHub Pages. |

Every skill is user-invoked. Codex CLI ignores `disable-model-invocation: true` in `SKILL.md` and reads `allow_implicit_invocation: false` in `agents/openai.yaml` instead, so change the two together.

## Local development

In Claude Code, add your checkout as a marketplace instead of the GitHub repo:

```
/plugin marketplace add <path-to-checkout>
/plugin install agent-skills@samfaina
```

In other harnesses, install from the checkout with `npx skills add <path-to-checkout>`.

GitHub Pages publishes the documentation site in `docs/` on every push to `main`.
