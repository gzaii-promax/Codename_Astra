import { spawnSync } from 'node:child_process';

// Keep this list narrow: rules and module contracts need the complete CI path.
const navigation = new Set(['docs/status.md', 'docs/status-history.md', 'docs/git-history.md', 'docs/index.md']);
export function classifyChangedFiles(files) {
  if (!Array.isArray(files) || !files.length) return { scope: 'full', reason: 'No nonempty verified change list.' };
  return files.every((file) => navigation.has(file))
    ? { scope: 'docs', reason: 'Only current/history status and navigation documents changed.' }
    : { scope: 'full', reason: 'Runtime, tooling, configuration, contracts, or unclassified paths changed.' };
}

export function classifyRevision(root, base, head) {
  if (![base, head].every((ref) => /^[0-9a-f]{40}$/i.test(ref ?? '') && !/^0+$/.test(ref))) {
    return { scope: 'full', reason: 'Revision identity is missing or invalid.', base, head, files: [] };
  }
  const diff = spawnSync('git', ['diff', '--no-renames', '--name-only', '-z', base, head, '--'], {
    cwd: root, encoding: 'utf8', timeout: 5000, maxBuffer: 8 * 1024 * 1024,
  });
  if (diff.error || diff.status !== 0) return { scope: 'full', reason: 'Revision diff could not be verified.', base, head, files: [] };
  const files = diff.stdout.split('\0').filter(Boolean);
  return { ...classifyChangedFiles(files), base, head, files };
}
