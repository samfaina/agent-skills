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
Whether the coordinator asks the user before each merge (`ask`) or merges as soon as the PR's checks are green (`auto`). Set per repo, overridable per run.
_Avoid_: reviewed mode, auto-merge mode

**Base CI**:
The CI runs that each push to the base branch starts, such as the one a merge commit starts, as opposed to the checks that run on a PR. A repo can run a wider set of jobs there than on its PRs, so a PR whose checks are green can still turn the base branch red.
_Avoid_: post-merge CI, main CI, push checks

**Known failure**:
A Base CI job that was already failing on the base branch before the first ticket, which the user chose to ship on top of. It stays known until it passes once; a ticket that breaks it in a new way can't be told apart from it.
_Avoid_: pre-existing failure, expected failure, flaky job

**External PR**:
A PR whose head branch lives in another repo, such as a fork, or that belongs to a repo other than the one being shipped from. A PR from a collaborator's fork counts.
_Avoid_: fork PR, foreign PR, third-party PR

**Follow-up**:
Work in the repo being shipped that a worker finds already wrong on the base branch before its ticket's first commit, such as a bug it saw in passing, or that a fix worker's reason asks for outside the ticket. A review finding about code the ticket's diff introduced is part of the ticket, not a follow-up. The coordinator offers follow-ups to the user, to open as new issues or fold into an open same-code match; trouble with the loop itself is not a follow-up.
_Avoid_: pending ticket, leftover, TODO

**Same-code match**:
An issue about the same code as a follow-up, though not necessarily the same work: unlike a possible duplicate, it can be a different symptom of that code. The Gather step of the loop's Follow-ups sets how the coordinator finds them.
_Avoid_: related issue, overlap

**Fold**:
Posting a follow-up as one comment on an open same-code match, instead of opening a new issue. The issue's body and labels stay as they were.
_Avoid_: merge, append, attach

**Worker role**:
The job a worker is started for: implement, PR or fix. A repo can run each role in a different harness.
_Avoid_: worker type, step
