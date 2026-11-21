# Skill version check

The harness loads whichever copy of these skills was installed, and an install stays at its version until someone updates it. So the same `ship-tickets` can run 0.6.0 in one repo and 0.9.0 in another, and a loop that lacks steps added since behaves differently with nobody noticing. This check finds the version that runs and the latest release.

The **skill's folder** is the base directory of the skill that sent you here, `ship-tickets` or `setup-ship-tickets`, as your harness reported it when the skill loaded. Both sit in the same plugin, so they give the same result. It ends with one of three results:

- **current**: the running version is the latest release, or newer, as a checkout ahead of the release is;
- **older**: the running version is older than the latest release. Record both versions and the update command;
- **unknown**: either version can't be read. Record which one and why, and the other version if you read it.

## The running version

The **plugin root** is two folders above the skill's folder: `<skill folder>/../..`. Read `.claude-plugin/plugin.json` there with your file-reading tool and take its `version`. In Claude Code's plugin cache, the root's folder name is that version too, as in `…/plugins/cache/samfaina/agent-skills/0.9.0/skills/ship-tickets`.

A copy that `npx skills add` installed has no `plugin.json` there: the version is unknown.

## The latest release

```text
gh api -H 'Accept: application/vnd.github.raw+json' repos/samfaina/agent-skills/contents/.claude-plugin/plugin.json --jq .version
```

It reads `plugin.json` from the default branch, the version a plugin update installs, and runs the same in bash and PowerShell. A release is the commit on that branch that bumps this version; its `v<version>` tag comes only later, once the release test passes, so don't read the version from tags. If it fails, such as with no network, the latest release is unknown.

Compare the two versions as numbers, part by part: 0.10.0 is newer than 0.9.0.

## The update command

Only for **older**. In Claude Code, find the entry of `claude plugin list --json` whose `installPath` or `readFromFolder` has the same realpath as the plugin root (realpaths as `skill-provenance.md` defines them). An install from a marketplace on GitHub loads from its `installPath`, in the plugin cache. One from a marketplace in a local folder has a `readFromFolder` and loads from that folder instead. The command is `claude plugin update <id> --scope <scope>`, with that entry's `id` and `scope`, and the update applies to sessions started after it.

With no such entry, the harness loads the skills from a folder no plugin install manages, such as a checkout or Claude Code's `--plugin-dir`. Instead of a command, say to update the copy at the plugin root to the latest release.

Done when the check has a result: current or older with both versions, or unknown with the reason. An unknown version never stops the skill that runs this check.
