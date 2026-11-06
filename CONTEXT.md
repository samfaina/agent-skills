# Ship tickets

Skills that ship GitHub tickets one at a time: a coordinator session drives the loop, and Orca runs a worker for each job in the ticket's worktree.

## Language

**Harness**:
The agent program that loads the skills and runs a session, such as Claude Code, Codex CLI or Gemini CLI.
_Avoid_: agent (for the program), runtime, client, CLI

**Coordinator**:
The session that runs the loop for a ticket set, in any harness inside an Orca terminal.
_Avoid_: orchestrator, main agent

**Worker**:
A fresh agent that Orca starts for a single job on one ticket, in any harness.
_Avoid_: subagent, child agent

**Merge approval**:
Whether the coordinator asks the user before each merge (`ask`) or merges as soon as CI is green (`auto`). Set per repo, overridable per run.
_Avoid_: reviewed mode, auto-merge mode

**External PR**:
A PR whose head branch lives in another repo, such as a fork, or that belongs to a repo other than the one being shipped from. A PR from a collaborator's fork counts.
_Avoid_: fork PR, foreign PR, third-party PR

**Worker role**:
The job a worker is started for: implement, PR or fix. A repo can run each role in a different harness.
_Avoid_: worker type, step
