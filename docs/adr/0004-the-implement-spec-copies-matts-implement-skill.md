# The implement spec copies Matt's implement skill instead of calling it

The implement spec in `skills/ship-tickets/ship-tickets-loop.md` copies the steps of `implement` from mattpocock/skills (`skills/engineering/implement/SKILL.md`): build with `tdd` at the seams, typecheck and run single test files as you go, run the full suite at the end, review with `code-review`, commit. It adds what the loop needs: read the issue with `gh`, keep the commits local, report the folders of the `tdd` and `code-review` the worker loaded, and fail if either skill is missing. The spec can't call `implement`, because `implement` sets `disable-model-invocation: true` in its frontmatter and `allow_implicit_invocation: false` in `agents/openai.yaml`. Only a person typing `/implement` can run it, so a worker started with `orca orchestration worker-start --spec` can't load it with the Skill tool the way it loads `tdd` and `code-review`.

## Considered options

- **Ask Matt to make `implement` model-invocable.** That is his design decision, and the spec would still need the additions above.
- **Start the worker with `/implement` as the first line of its spec.** A harness expands a slash command only when it opens the prompt, and the prompt a worker gets is not the spec: `worker-start` injects Orca's preamble, with the Task and Dispatch IDs and the worker's obligations, ahead of the Task block that holds the spec. Some workers have no terminal at all, so nothing types the command into a TUI either. Even if Orca put the spec first, this would depend on every harness in **Workers** expanding a slash command in a prompt that arrives through Orca, which [ADR 0003](0003-orca-is-the-portability-layer.md) doesn't guarantee.
- **Keep a model-invocable copy of `implement` in this repo.** That is a second copy with the same drift, and [ADR 0002](0002-one-self-contained-ship-tickets-skill.md) already rejects generated copies.

## Consequences

The spec can fall behind upstream. That doesn't affect users: their loop doesn't read Matt's `implement`, so it keeps working, and they get changes when they update `ship-tickets`. The maintainer brings the spec in line, prompted by the drift check from [#48](https://github.com/samfaina/agent-skills/issues/48), which opens an issue when upstream `implement` changes. `tdd` and `code-review` are different: workers load them live, so their changes reach users right away, and the provenance check in `skill-provenance.md` guards where they come from.
