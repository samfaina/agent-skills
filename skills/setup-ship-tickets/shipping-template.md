# Shipping

Read by the `ship-tickets` skill (samfaina/agent-skills). Run the `setup-ship-tickets` skill to fill this in as `docs/agents/shipping.md` and open the PR, or copy it there by hand. Either way it has to be merged to the default branch: the loop reads it from there.

- **Base branch:** `main`
- **Merge method:** `merge` | `squash` | `rebase` (passed to `gh pr merge --<method>`)
- **Merge approval:** `ask` (once CI is green, the loop shows you the PR and waits for Merge, Request changes or Stop) | `auto` (the loop merges as soon as CI is green)
- **Branch naming:** how to derive the worktree `--name` from the ticket, e.g. kebab-case issue title. Note any prefix Orca adds to the branch.
- **After merge:** e.g. "delete the remote branch with `git push origin --delete <branch>`", or "nothing".
- **CI:** `required` (PRs get checks, and the loop waits for them to pass) | `none` (no checks run on PRs, and the loop merges without waiting)
- **Workers:** the Orca agent id each worker starts in (passed to `worker-start --agent`). Either one id for every role, written `<id>` (all roles), or one per role, written implement `<id>`, PR `<id>`, fix `<id>`. A role left out gets `claude`.

## PR format

- **Title:** e.g. the issue title, unchanged.
- **Body:** the sections, in order, and what each holds. End with `Closes #<n>`.
