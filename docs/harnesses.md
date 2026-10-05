---
title: Harnesses
nav_order: 5
---

# Harnesses
{: .no_toc }

A **harness** is the agent program that loads the skills and runs a session, such as Claude Code or OpenCode. The skills are plain `SKILL.md` folders and Orca starts the workers, so the loop is the same in every harness. What changes is how you install the skills, how the coordinator asks you a question and waits on CI, and which shell it runs commands in.

The coordinator and the workers don't have to share a harness. Your session can run in OpenCode while the workers run in Claude Code, or the other way round.

1. TOC
{:toc}

## Supported harnesses

| Harness | Version | Status |
| --- | --- | --- |
| [Claude Code](https://github.com/anthropics/claude-code) | 2.1.289 | Tested |
| [OpenCode](https://opencode.ai/) | 1.18.21 | Tested |
| Codex CLI, Gemini CLI and others | | Untested |

Tested with Orca 1.4.220, in October 2026.

Any other harness should work if it loads `SKILL.md` skills and Orca supports it as an agent. `orca orchestration worker-start --help` lists the agent ids Orca knows.

These docs write the skills as `/ship-tickets` and `/setup-ship-tickets`, as Claude Code and OpenCode run them. Other harnesses may use a different syntax.

## Install

Install the skills in each harness you run a coordinator in, and Matt Pocock's skills in each harness you run workers in. Within one harness, use one installer or the other: installing both gives every skill twice.

| Harness | These skills | [mattpocock/skills](https://github.com/mattpocock/skills) |
| --- | --- | --- |
| Claude Code | The plugin | The plugin |
| OpenCode | `npx skills add samfaina/agent-skills --agent opencode` | `npx skills add mattpocock/skills --agent opencode` |
| Others | `npx skills add samfaina/agent-skills` | `npx skills add mattpocock/skills` |

The Claude Code plugins:

```
/plugin marketplace add samfaina/agent-skills
/plugin install agent-skills@samfaina
/plugin marketplace add mattpocock/skills
/plugin install mattpocock-skills@mattpocock
```

`mattpocock-skills@claude-plugins-official`, from Anthropic's official marketplace, works too. A Claude Code worker needs Matt's skills as a plugin: it calls them as `mattpocock-skills:tdd` and `mattpocock-skills:code-review`, because Claude Code has a built-in `code-review`.

OpenCode doesn't read Claude Code plugin skills, so if you use both harnesses, install through `npx skills add` for OpenCode as well. `--agent opencode` keeps that install out of Claude Code. `npx skills add` installs into the current repo; add `-g` to install for every repo.

## Asking you a question

Setup asks about the fields it can't settle, and with Merge approval `ask` the loop asks before each merge. Workers' questions that the coordinator can't answer from the ticket and the repo reach you the same way.

| Harness | How the coordinator asks |
| --- | --- |
| Claude Code | The `AskUserQuestion` tool, with the options to pick from. |
| OpenCode | The `question` tool. |
| Others | Plain text in the session. Reply in the chat. |

## Waiting on CI

Once the PR is open, the coordinator waits for GitHub to list the checks and then runs `gh pr checks --watch` until they finish, which can take many minutes. How it waits depends on the harness:

| Harness | How the coordinator waits |
| --- | --- |
| Claude Code | Runs the watch in the background and gets notified when it exits. |
| OpenCode | Has no background shell commands, so it runs the watch in the foreground. When the command times out, it runs it again. The watch is safe to rerun. |
| Codex CLI | Polls the command until it exits. |
| Gemini CLI | Runs the watch in the background, if its settings inject the result when a background command exits (below). |

For Gemini CLI, set this in `settings.json`:

```json
{
  "tools": {
    "shell": {
      "backgroundCompletionBehavior": "inject"
    }
  }
}
```

## Shell

The loop runs in bash and in PowerShell 7 (`pwsh`). The one command that differs is the one that passes a worker its spec: a quoted heredoc in bash, a single-quoted here-string in PowerShell. PowerShell before 7.3 strips the double quotes from the spec, so use 7.3 or later.

- **OpenCode on Windows** runs commands in `pwsh` unless the `SHELL` environment variable is set. Set `SHELL` to a bash path, such as Git Bash's, to use bash instead.
- **`orca` on Windows** must resolve to `orca.exe`. `orca.cmd` runs its arguments through `cmd.exe`, which cuts a multi-line spec at its first newline. The coordinator calls the `orca.exe` beside it when `orca` resolves to `orca.cmd`.

## Keeping the skills user-invoked

Both skills are meant to run only when you ask for them by name, because `/ship-tickets` merges PRs. Each harness has its own way to say so, and each skill also opens with a line telling the agent to stop if you didn't invoke it.

- **Claude Code** reads `disable-model-invocation: true` in `SKILL.md`.
- **Codex CLI** reads `allow_implicit_invocation: false` in the skill's `agents/openai.yaml`.
- **OpenCode** reads neither. Deny the skills to the model in `opencode.json`, in the repo or in `~/.config/opencode/`. This hides both skills from the model, and `/ship-tickets` and `/setup-ship-tickets` still work when you type them:

  ```json
  {
    "permission": {
      "skill": {
        "ship-tickets": "deny",
        "setup-ship-tickets": "deny"
      }
    }
  }
  ```

## Workers

The **Workers** field in [`shipping.md`](shipping-md) names the Orca agent id each worker starts in. Use one id for every worker role, or one per role:

```markdown
- **Workers:** `claude` (all roles)
- **Workers:** implement `claude`, PR `opencode`, fix `claude`
```

A role the field leaves out gets `claude`, and a file without the field runs every worker in Claude Code. `/setup-ship-tickets` asks for it and proposes `claude`.

### The skill provenance check

The implement worker builds with Matt Pocock's `tdd` and reviews with his `code-review`. Another skill with the same name would break the loop without anyone noticing: Claude Code has a built-in `code-review`, and when OpenCode finds two skills with one name, it loads either and logs only a warning. So `/setup-ship-tickets`, and `/ship-tickets` before its first ticket, check where the implement worker's harness will load both skills from:

| Harness | Passes when |
| --- | --- |
| Claude Code | `claude plugin list` shows `mattpocock-skills` enabled, from a marketplace whose source is `mattpocock/skills` (Matt's own marketplace or Anthropic's official one). |
| OpenCode | `opencode debug skill`, run from the repo, lists one `tdd` and one `code-review`, or duplicates that are links to the same folder. That folder's install record (`skills-lock.json` in the repo, or `~/.agents/.skill-lock.json`) gives `mattpocock/skills` as the source. |
| Others, or no install record | Can't pass. The coordinator checks the skills' content instead, shows you their paths and asks you to confirm before it goes on. |

Each implement worker then reports the folders it loaded the two skills from, and the coordinator stops the loop if they aren't the folders the check found.

### When the check fails

The report names the skill and the path the worker would load it from.

- **Claude Code, plugin missing or from another source:** install `mattpocock-skills` from Matt's marketplace or Anthropic's official one, as in [Install](#install).
- **OpenCode, skill missing:** OpenCode doesn't see Claude Code plugins. Run `npx skills add mattpocock/skills --agent opencode`.
- **OpenCode, two different copies:** remove the copy that isn't Matt's. OpenCode may load either one.
- **A copy with no install record,** such as a `git clone`: the check asks you to confirm the paths. Decline if they aren't Matt's skills, and install them as above.
- **A worker loaded a different copy than the check found:** the loop stops at that ticket and reports both paths. A plugin update during the run moves the Claude Code skills to a new versioned folder, which stops the loop the same way. If both paths are Matt's, run `/ship-tickets` again.
