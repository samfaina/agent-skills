# Shipping

Read by `/ship-tickets` and `/ship-tickets-reviewed` (samfaina/agent-skills). Copy this file to `docs/agents/shipping.md` and fill it in.

- **Base branch:** `main`
- **Merge method:** `merge` | `squash` | `rebase` (passed to `gh pr merge --<method>`)
- **Branch naming:** how to derive the worktree `--name` from the ticket, e.g. kebab-case issue title. Note any prefix Orca adds to the branch.
- **After merge:** e.g. "delete the remote branch with `git push origin --delete <branch>`", or "nothing".

## PR format

- **Title:** e.g. the issue title, unchanged.
- **Body:** the sections, in order, and what each holds. End with `Closes #<n>`.
