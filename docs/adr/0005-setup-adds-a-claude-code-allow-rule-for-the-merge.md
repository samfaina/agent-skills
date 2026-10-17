# Setup adds a Claude Code allow rule for the merge, in the repo

Claude Code's auto mode classifier began refusing `gh pr merge` under its built-in `Merge Without Review` rule ("merging a PR before any human has approved it"). The rule lives server-side: no Claude Code binary contains it, and on 2026-10-17 it blocked both coordinators running Merge approval `auto`, where the day before the same loop had merged. So in auto mode `auto` behaves as `ask`. When the user picks `auto`, `setup-ship-tickets` offers two narrow `permissions.allow` entries, `Bash(gh pr merge * --<method>)` and `PowerShell(gh pr merge * --<method>)`, in the repo's `.claude/settings.json`, committed in the same PR as `shipping.md`. Claude Code settles allow rules before the classifier, and auto mode keeps narrow rules where it drops blanket ones. The loop runs the merge as a command of its own so the rule matches it, and when a harness still refuses the merge it handles that ticket as `ask` and doesn't stop.

## Considered options

- **An `autoMode.allow` entry in `~/.claude/settings.json`.** The classifier reads `autoMode` only from user or managed settings, never from a repo, so setup would edit a file outside the repo that affects every project. The entry is prose the classifier weighs rather than a rule it obeys, so it would also stay non-deterministic.
- **The skill's `allowed-tools` frontmatter.** It ships with the plugin and needs no setup. But the grant lasts only the turn that invokes the skill, so it clears when the user answers any question, and the docs don't say whether auto mode honours it.
- **A plugin mod that approves the merge on `tool.check`.** This is documented to skip the classifier and needs no setup. But it would have the plugin switch off a safety rule for the user on its own, and a mod is more code to maintain than a settings entry.
- **One approval at the start of each run.** Conversational approval "covers the destructive action you named", and the docs don't say how to make it last a whole run. Context compaction can also drop it, and the question defeats `auto`.

## Consequences

The rule is visible and reviewed in the setup PR, and it is scoped to one repo. It also lets any Claude Code session in that repo run the merge command without asking, which setup tells the user before adding it. Claude Code reads the file from the local checkout, so the user pulls the setup PR before the next run. The rule names the merge method, so changing **Merge method** needs a new setup run. The release test gains an `auto-mode` run, the only Claude Code run with permission checks on. The others skip them, which is why they missed this.
