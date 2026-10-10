# The implement spec copies Matt Pocock's implement skill instead of calling it

The implement spec in `skills/ship-tickets/ship-tickets-loop.md` copies the steps of `implement` from mattpocock/skills (`skills/engineering/implement/SKILL.md`): build with `tdd` at the seams, typecheck and run single test files as you go, run the full suite at the end, review with `code-review`, commit. It adds what the loop needs: read the issue with `gh`, keep the commits local, report the folders of the `tdd` and `code-review` the worker loaded, and fail if either skill is missing. The spec can't call `implement`, because `implement` sets `disable-model-invocation: true` in its frontmatter and `allow_implicit_invocation: false` in `agents/openai.yaml`. Only a person typing `/implement` can run it, so a worker started with `orca orchestration worker-start --spec` can't load it with the Skill tool the way it loads `tdd` and `code-review`.

## Considered options

- **Ask Matt to make `implement` model-invocable.** That is his design decision, and the spec would still need the additions above.
- **Start the worker with `/implement` as the first line of its spec.** The spec isn't the whole prompt: `worker-start` wraps it in Orca's preamble, with the Task and Dispatch IDs and the worker's obligations, and some workers have no terminal to type a command into. Claude Code expands a slash command only at the start of a prompt, and whether the other harnesses in **Workers** expand one that arrives through Orca is something [ADR 0003](0003-orca-is-the-portability-layer.md) doesn't guarantee.
- **Keep a model-invocable copy of `implement` in this repo.** It would drift from upstream just as the spec does, and the loop would still need the additions above. As a skill of its own it would also sit outside the `ship-tickets` folder, which [ADR 0002](0002-one-self-contained-ship-tickets-skill.md) keeps self-contained because installers copy only that folder.

## Consequences

The spec can fall behind upstream. That doesn't affect users: their loop doesn't read Matt's `implement`, so it keeps working, and they get changes when they update `ship-tickets`. The maintainer brings the spec in line, prompted by the drift check from [#48](https://github.com/samfaina/agent-skills/issues/48), which opens an issue when upstream `implement` changes. `tdd` and `code-review` are different: workers load them live, so their changes reach users right away, and the provenance check in `skills/ship-tickets/skill-provenance.md` guards where they come from.
