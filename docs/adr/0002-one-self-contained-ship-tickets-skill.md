# One self-contained ship-tickets skill, with merge approval as config

`/ship-tickets` and `/ship-tickets-reviewed` become one `ship-tickets` skill whose loop lives inside its own folder, and the shipping template moves into `setup-ship-tickets`. The neutral installers that serve harnesses other than Claude Code (`npx skills add`, `gemini skills install`) copy only each skill's folder, so the old `shared/` directory never reaches those users. The two skills differed only at the merge step, so that difference becomes **Merge approval** (`ask | auto`) in `docs/agents/shipping.md`, overridable per run with `ship-tickets ask|auto <issues…>`. A file without the field means `ask`.

## Considered options

- **A model-invoked `ship-tickets-loop` skill that both user-invoked skills call.** This is how mattpocock/skills shares material between skills. We rejected it because the model could then start a loop that merges PRs without the user asking.
- **A copy of the loop in each skill, kept in sync by a script and a CI check.** That makes two sources of truth for the same instructions, which is the reason mattpocock/skills gives for avoiding generated copies.

## Consequences

`/ship-tickets-reviewed` goes away in 0.3.0. Repos whose `shipping.md` predates the field now stop before each merge to ask, where `/ship-tickets` used to merge on green, until someone sets `Merge approval: auto` or reruns `/setup-ship-tickets`.
