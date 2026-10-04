# Hand-built landing page on top of just-the-docs, dark only

The docs site stays on Jekyll with the just-the-docs remote theme, built by GitHub Pages' legacy branch build from `main:/docs`, so the repo needs no GitHub Actions workflow and no Node toolchain. just-the-docs can't produce the landing page we wanted (top nav, terminal hero, requirement and install blocks, no sidebar), so `index.md` uses a hand-written layout in `docs/_layouts/`, while the inner pages keep just-the-docs and share its colour and type tokens. The site is dark only: no light palette and no theme toggle, which keeps one palette to maintain.

## Considered options

- **Astro Starlight or VitePress.** More layout control and built-in theming, but they need an Actions deploy and a Node toolchain in a repo that is otherwise Markdown skills.
- **Minimal Mistakes** (`splash` layout, `dark` skin). Works as a remote theme, but we would have overridden nearly all of its look.
- **A fully custom Jekyll theme with no remote theme.** Feasible for five pages, but we would have to own nav, search and TOC.

## Consequences

The landing layout doesn't follow just-the-docs upgrades on its own: bumping the theme version means checking that the shared header and the search still work on the landing page. The inner pages carry part of that risk too, because they replace the theme's `components/header.html` and `components/sidebar.html` with the shared header and a sidebar without its own title.
