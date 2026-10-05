# strkit

A tiny string library with no dependencies.

## Commands

- `npm test` runs every test with `node --test`. Needs Node 22 or later. There is nothing to install.
- `node --test test/<name>.test.js` runs one test file.

## Conventions

- ES modules. Every public function is a named export of `src/index.js`.
- One test file per function, `test/<name>.test.js`, using `node:test` and `node:assert/strict`.
- No dependencies.

## Agent docs

- Issue tracker: `docs/agents/issue-tracker.md`
- Triage labels: `docs/agents/triage-labels.md`
- Shipping: `docs/agents/shipping.md`
