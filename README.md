# agent-skills

Claude Code plugin with my agent skills.

| Skill | What it does |
| --- | --- |
| `/setup-ship-tickets` | Checks the repo is ready for the loop and opens a PR adding `docs/agents/shipping.md`, filled from the repo's settings and PR history. Run it once per repo. |
| `/ship-tickets [#n…]` | Ships GitHub tickets one at a time with supervised Orca workers: implement, open the PR, wait for CI, merge. |
| `/ship-tickets-reviewed [#n…]` | Same loop, pausing for your approval before each merge. |

Both follow `shared/ship-tickets-loop.md` and read the target repo's `docs/agents/shipping.md` (template: `shared/shipping-template.md`), which `/setup-ship-tickets` writes. They assume the [mattpocock-skills](https://github.com/mattpocock/skills) plugin (`tdd`, `code-review`), tickets with GitHub blocking links as `/to-tickets` writes them, and a coordinator session running inside an Orca terminal.

## Install

```
/plugin marketplace add samfaina/agent-skills
/plugin install agent-skills@samfaina
```

For local development, add the checkout instead: `/plugin marketplace add E:\projects\agent-skills`.
