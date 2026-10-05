// Every PR adds a line to CHANGELOG.md, under "## Unreleased".
import { execFileSync } from 'node:child_process';

const base = process.env.BASE_REF || 'main';
const diff = execFileSync(
  'git',
  ['diff', '--unified=0', `origin/${base}...HEAD`, '--', 'CHANGELOG.md'],
  { encoding: 'utf8' },
);
const added = diff.split('\n').filter((line) => /^\+- \S/.test(line));

if (added.length === 0) {
  console.error(
    'CHANGELOG.md has no new entry. Add a line under "## Unreleased" that describes this change, such as "- Add `slugify()`.".',
  );
  process.exit(1);
}
console.log(`CHANGELOG.md: ${added.length} new line(s).`);
