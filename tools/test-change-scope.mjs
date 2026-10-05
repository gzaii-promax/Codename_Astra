import assert from 'node:assert/strict';
import test from 'node:test';
import { spawnSync } from 'node:child_process';
import { mkdir, mkdtemp, rm, writeFile } from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { classifyChangedFiles, classifyRevision } from './change-scope.mjs';

test('only the explicit status and navigation paths take the lightweight CI path', () => {
  assert.equal(classifyChangedFiles(['docs/status.md', 'docs/index.md']).scope, 'docs');
  for (const file of ['AGENTS.md', 'docs/testing.md', 'docs/design-baselines.md', 'world/README.md', 'project.godot', 'tools/check.mjs', 'docs/status.md/../testing.md']) {
    assert.equal(classifyChangedFiles(['docs/status.md', file]).scope, 'full', file);
  }
});
test('a real rename from a contract path to an allowed history path remains full validation', async (t) => {
  const root = await mkdtemp(path.join(os.tmpdir(), 'astra-change-scope-'));
  t.after(() => rm(root, { recursive: true, force: true }));
  const git = (...args) => { const p = spawnSync('git', ['-C', root, ...args], { encoding: 'utf8' }); assert.equal(p.status, 0, p.stderr); return p.stdout.trim(); };
  git('init', '--quiet'); await mkdir(path.join(root, 'docs'));
  await writeFile(path.join(root, 'docs/testing.md'), '# Contract\n'); git('add', '.');
  git('-c', 'user.name=fixture', '-c', 'user.email=fixture@example.invalid', 'commit', '--quiet', '-m', 'base'); const base = git('rev-parse', 'HEAD');
  git('mv', 'docs/testing.md', 'docs/status-history.md'); git('-c', 'user.name=fixture', '-c', 'user.email=fixture@example.invalid', 'commit', '--quiet', '-m', 'rename');
  const result = classifyRevision(root, base, git('rev-parse', 'HEAD'));
  assert.equal(result.scope, 'full'); assert.ok(result.files.includes('docs/testing.md'));
});
test('empty, invalid and unavailable revision evidence defaults to complete validation', () => {
  assert.equal(classifyChangedFiles([]).scope, 'full'); assert.equal(classifyChangedFiles(null).scope, 'full');
  assert.equal(classifyRevision('.', undefined, 'a'.repeat(40)).scope, 'full');
  assert.equal(classifyRevision('.', '0'.repeat(40), 'a'.repeat(40)).scope, 'full');
  assert.equal(classifyRevision('.', 'f'.repeat(40), 'e'.repeat(40)).scope, 'full');
});
