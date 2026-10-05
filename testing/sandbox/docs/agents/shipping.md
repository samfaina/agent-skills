# Shipping

Read by the `ship-tickets` skill (samfaina/agent-skills).

- **Base branch:** `main`
- **Merge method:** `squash`
- **Merge approval:** `ask`
- **Branch naming:** kebab-case issue title, prefixed with the issue number: `3-add-slugify`. Orca may add its own prefix to the branch, such as `samfaina/`.
- **After merge:** delete the remote branch with `git push origin --delete <branch>`.
- **CI:** `required`
- **Workers:** `claude` (all roles)

## PR format

- **Title:** the issue title, unchanged.
- **Body:**
  1. **Summary**: what changed and why, in two or three sentences.
  2. **Testing**: the tests added and how to check the change by hand.
  3. `Closes #<n>`
