# Orca stays required, because it is what makes the loop harness-neutral

The skills run in any harness that loads SKILL.md skills, and Orca remains a hard requirement for both the coordinator and the workers. Orca starts a worker in any of its supported agents (`worker-start --agent claude`, `opencode`, `codex`…) and gives every terminal the same orchestration commands, whatever harness runs in it. The loop therefore needs one version, and the harness differences shrink to how the coordinator asks the user, waits on CI and quotes the spec in its shell.

## Considered options

- **Drop Orca and use each harness's own subagents.** Claude Code, OpenCode and Codex each start subagents differently, with different ways to settle and report back. That would mean one loop per harness, and a coordinator in one harness could not run workers in another.

## Consequences

The workers' harness is configuration, not code: `shipping.md` names an Orca agent id for all worker roles or one per role. Tested support covers Claude Code and OpenCode. Any other harness depends on Orca supporting it as an agent and on that harness loading SKILL.md skills.
