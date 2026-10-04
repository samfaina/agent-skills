---
title: Home
layout: landing
nav_order: 1
---

<section class="hero">
<div class="wrap">
  <div>
    <h1>Ship GitHub tickets, one at a time.<em>Each one built on the last.</em></h1>
    <p class="lede">A Claude Code plugin that ships GitHub tickets for you, one at a time. For each ticket it opens an Orca worktree, has one agent build it test-first and another open the PR, waits for CI, and merges. The next ticket starts from the branch the last one merged into, so it builds on the code before it.</p>
    <p class="facts"><span>test-first workers</span><span>one worktree per ticket</span></p>
  </div>
  <div class="term" aria-label="Example run of /ship-tickets 41 42" role="img">
    <div class="term-bar" aria-hidden="true"><i></i><i></i><i></i><span>~/your-repo — claude</span></div>
<pre aria-hidden="true"><span class="c-prompt">&gt;</span> <span class="c-cmd">/ship-tickets 41 42</span>

<span class="c-coord">[coordinator]</span> read docs/agents/shipping.md from origin/main
<span class="c-coord">[coordinator]</span> ticket set <span class="c-num">#41</span> <span class="c-num">#42</span> -> picking <span class="c-num">#41</span>, no open blockers
<span class="c-coord">[coordinator]</span> worktree <span class="c-str">ship/41-retry-webhooks</span> from origin/main
<span class="c-impl">[worker:implement]</span> 3 tests added, suite passing, committed
<span class="c-pr">[worker:pr]</span> opened PR <span class="c-num">#58</span>, body ends <span class="c-str">"Closes #41"</span>
<span class="c-coord">[coordinator]</span> CI <span class="c-ok">green</span> (3/3 checks) => squash merge
<span class="c-coord">[coordinator]</span> issue <span class="c-num">#41</span> closed -> worktree removed
<span class="c-coord">[coordinator]</span> picking <span class="c-num">#42</span> from updated origin/main <span class="cursor"></span></pre>
  </div>
</div>
</section>

<section class="block block--band">
<div class="wrap">
  <div class="head-row">
    <div><p class="eyebrow">Before you install</p><h2 id="requirements">Requirements</h2></div>
    <p class="head-note"><code>/setup-ship-tickets</code> checks each of these for you and tells you how to fix what's missing.</p>
  </div>
  <div class="grid grid--4">
    <a class="cell cell--link" href="https://github.com/anthropics/claude-code" target="_blank" rel="noopener"><span class="k">runtime</span><h3>Claude Code <i aria-hidden="true">↗</i></h3><p>Runs the skills. Your session is the coordinator.</p></a>
    <a class="cell cell--link" href="https://github.com/stablyai/orca" target="_blank" rel="noopener"><span class="k">worktrees</span><h3>Orca <i aria-hidden="true">↗</i></h3><p>Gives each ticket its own worktree and runs the workers. Start the coordinator session from an Orca terminal.</p></a>
    <a class="cell cell--link" href="https://cli.github.com/" target="_blank" rel="noopener"><span class="k">github</span><h3>GitHub CLI <i aria-hidden="true">↗</i></h3><p>Reads issues, opens and merges PRs, watches CI. Run <code>gh auth login</code> first.</p></a>
    <a class="cell cell--link" href="https://github.com/mattpocock/skills" target="_blank" rel="noopener"><span class="k">skills</span><h3>mattpocock-skills <i aria-hidden="true">↗</i></h3><p>Workers build with its <code>tdd</code> skill and review with <code>code-review</code>.</p></a>
  </div>
</div>
</section>

<section class="block block--band">
<div class="wrap">
  <div class="head-row">
    <div><p class="eyebrow">Then</p><h2 id="installation">Installation</h2></div>
    <p class="head-note">Install the plugin once in Claude Code, then set up each repo you want the loop to ship.</p>
  </div>
  <div class="grid grid--2">
    <div class="cell">
      <span class="k">once · any Claude Code session</span>
      <h3>Install the plugin</h3>
      <div class="install"><code>/plugin marketplace add samfaina/agent-skills
/plugin install agent-skills@samfaina</code><button class="copy-button" type="button" aria-label="Copy the install commands">copy</button></div>
    </div>
    <div class="cell">
      <span class="k">per repo · from an Orca terminal</span>
      <h3>Set up a repo</h3>
      <div class="install"><code>/setup-ship-tickets</code><button class="copy-button" type="button" aria-label="Copy the setup command">copy</button></div>
      <p>Checks the repo is ready and opens a PR with <code>docs/agents/shipping.md</code>. Merge it before the first run. <a href="{{ '/getting-started#set-up-a-repo' | relative_url }}">How setup works →</a></p>
    </div>
  </div>
</div>
</section>

<section class="block">
<div class="wrap">
  <div class="head-row">
    <div><p class="eyebrow">How it works</p><h2 id="the-loop">The loop, one ticket at a time</h2></div>
    <a class="more" href="{{ '/how-it-works' | relative_url }}">Every step in detail →</a>
  </div>
  <ol class="grid grid--4 steps">
    <li class="cell"><span class="k"><b>01</b> / pick</span><h3>Next ready ticket</h3><p>The lowest-numbered open issue whose blockers are all closed, from <span class="gh-label">ready-for-agent</span> or your arguments.</p></li>
    <li class="cell"><span class="k"><b>02</b> / worktree</span><h3>Its own Orca worktree</h3><p>Branched from the remote base, which already has the previous ticket merged.</p></li>
    <li class="cell"><span class="k"><b>03</b> / implement + pr</span><h3>Fresh workers</h3><p>One builds it test-first and reviews its own diff. Another opens the PR in your repo's format.</p></li>
    <li class="cell"><span class="k"><b>04</b> / ci + merge</span><h3>Green, then merged</h3><p>Red runs go to a fix worker, at most twice. Then it merges and cleans up.</p></li>
  </ol>
</div>
</section>

<section class="block">
<div class="wrap">
  <div class="head-row">
    <div><p class="eyebrow">Command reference</p><h2 id="the-skills">The skills</h2></div>
    <p class="head-note note"><span>With no issue numbers, the shipping skills take every open issue labelled <span class="gh-label">ready-for-agent</span>.</span></p>
  </div>
  <div class="table-scroll">
    <table class="skills">
      <thead><tr><th>Skill</th><th>When to run it</th><th>Merge</th></tr></thead>
      <tbody>
        <tr><td class="cmd">/setup-ship-tickets</td><td>Once per repo. Checks the repo is ready and opens a PR with <code>docs/agents/shipping.md</code>, the file the loop reads.</td><td><span class="mode mode--setup">setup</span></td></tr>
        <tr><td class="cmd">/ship-tickets-reviewed <span>[#n…]</span></td><td>To ship tickets and approve each merge yourself, or ask for changes first.</td><td><span class="mode mode--human">you approve</span></td></tr>
        <tr><td class="cmd">/ship-tickets <span>[#n…]</span></td><td>To ship tickets and merge each PR as soon as its CI is green.</td><td><span class="mode mode--auto">on green CI</span></td></tr>
      </tbody>
    </table>
  </div>
</div>
</section>

<section class="block">
<div class="wrap">
  <p class="eyebrow">Who does what</p>
  <h2 id="coordinator-and-workers">Coordinator and workers</h2>
  <p class="lead">Your Claude Code session is the <b>coordinator</b>. It picks the order, waits for CI and merges. The coding happens in <b>workers</b>: fresh Orca agents, each started for one job in the ticket's worktree, with a written spec of what to do and how the coordinator will check it.</p>
  <div class="coord">
    <span class="tag">coordinator</span>
    <div><h3>Your Claude Code session</h3><p>Picks the order, starts the workers, checks their work, waits for CI and merges.</p></div>
  </div>
  <div class="workers">
    <div class="worker worker--implement"><span class="k">worker 01</span><h3>Implement</h3><p>Builds the ticket test-first, reviews its own diff, commits.</p><div class="accept"><small>accepted when</small>The branch has commits and a clean working tree.</div></div>
    <div class="worker worker--pr"><span class="k">worker 02</span><h3>PR</h3><p>Pushes the branch and opens the PR in your repo's format.</p><div class="accept"><small>accepted when</small>The PR exists on the ticket's branch and its body says <code>Closes #&lt;n&gt;</code>.</div></div>
    <div class="worker worker--fix"><span class="k">worker 03</span><h3>Fix</h3><p>Fixes a red CI run, or the changes you asked for in review.</p><div class="accept"><small>accepted when</small>The fix is pushed.</div></div>
  </div>
  <p class="callout"><b>Empty context.</b> Each worker starts with an empty context, so the PR worker writes from the commits and the ticket, not from the implementer's reasoning.</p>
</div>
</section>

<section class="block">
<div class="wrap">
  <p class="eyebrow">Docs</p>
  <h2 id="next">Next</h2>
  <div class="next">
    <a href="{{ '/getting-started' | relative_url }}"><span class="k">01<i aria-hidden="true">→</i></span><h3>Getting started</h3><p>Requirements, install, and setting up a repo.</p></a>
    <a href="{{ '/how-it-works' | relative_url }}"><span class="k">02<i aria-hidden="true">→</i></span><h3>How the loop works</h3><p>Every step, from picking a ticket to cleaning up.</p></a>
    <a href="{{ '/shipping-md' | relative_url }}"><span class="k">03<i aria-hidden="true">→</i></span><h3>shipping.md reference</h3><p>The per-repo settings file.</p></a>
    <a href="{{ '/troubleshooting' | relative_url }}"><span class="k">04<i aria-hidden="true">→</i></span><h3>Troubleshooting</h3><p>Why the loop stops and what to do.</p></a>
  </div>
</div>
</section>
