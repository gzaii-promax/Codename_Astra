import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { createHash } from 'node:crypto';
import { chmod, copyFile, lstat, mkdir, mkdtemp, readFile, readdir, realpath, rm, symlink, writeFile } from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import test from 'node:test';
import { prepareWorktree } from './prepare-worktree.mjs';
import { loadToolchain, toolPath } from './toolchain-config.mjs';

const tools = path.dirname(fileURLToPath(import.meta.url));
const hash = (bytes) => createHash('sha256').update(bytes).digest('hex');
const json = async (file) => JSON.parse(await readFile(file, 'utf8'));
const derived = (root) => path.join(root, '.tools', 'worktree', 'toolchain.json');
async function run(argv, cwd, env = process.env) {
  return new Promise((resolve, reject) => {
    const child = spawn(argv[0], argv.slice(1), { cwd, env });
    let stdout = '', stderr = '';
    child.stdout.on('data', (bytes) => { stdout += bytes; });
    child.stderr.on('data', (bytes) => { stderr += bytes; });
    const timer = setTimeout(() => child.kill('SIGKILL'), 15000);
    child.once('error', reject);
    child.once('close', (code) => { clearTimeout(timer); resolve({ code, stdout, stderr }); });
  });
}
async function git(root, ...args) {
  const actual = await run(['git', '-C', root, ...args], root);
  assert.equal(actual.code, 0, `${args.join(' ')}: ${actual.stderr}`);
  return actual.stdout.trim();
}
function manifest() {
  return { schema_version: 1, platform: 'test-platform', scope: 'fixture', tools: {
    godot: { path: '.tools/runtime/godot', version: '4.7.2.stable.official.ed1daf0bf' },
    gut: { addons_path: '.tools/gut/addons/gut', version: '9.7.1' },
    python: { path: '.tools/runtime/python', version: '3.12.14' },
    gdlint: { path: '.tools/runtime/gdlint', version: '4.5.0' },
    gdformat: { path: '.tools/runtime/gdformat', version: '4.5.0' },
    node: { path: process.execPath, version: process.versions.node },
    git: { path: '/usr/bin/git', version: '2.54.0' },
    gh: { path: '.tools/runtime/gh', version: '2.102.0' },
  } };
}
async function fakeTools(root) {
  await mkdir(path.join(root, '.tools', 'runtime'), { recursive: true });
  for (const name of ['godot', 'python', 'gdlint', 'gdformat', 'gh']) {
    const executable = path.join(root, '.tools', 'runtime', name);
    await writeFile(executable, '#!/bin/sh\nexit 0\n');
    await chmod(executable, 0o755);
  }
  await mkdir(path.join(root, '.tools', 'gut', 'addons', 'gut'), { recursive: true });
}
async function fixture(t) {
  const temporary = await mkdtemp(path.join(os.tmpdir(), 'astra worktree tests '));
  t.after(() => rm(temporary, { recursive: true, force: true }));
  const directory = await realpath(temporary);
  const remote = path.join(directory, 'bare remote.git');
  const primary = path.join(directory, 'primary checkout');
  const a = path.join(directory, 'linked A'), b = path.join(directory, 'linked B');
  const initialized = await run(['git', 'init', '--bare', '--initial-branch=main', remote], directory);
  assert.equal(initialized.code, 0, initialized.stderr);
  const cloned = await run(['git', 'clone', remote, primary], directory);
  assert.equal(cloned.code, 0, cloned.stderr);
  await git(primary, 'config', 'user.name', 'Worktree Test');
  await git(primary, 'config', 'user.email', 'worktree-test@example.invalid');
  await mkdir(path.join(primary, 'tools'));
  for (const name of ['prepare-worktree.mjs', 'toolchain-config.mjs']) await copyFile(path.join(tools, name), path.join(primary, 'tools', name));
  await writeFile(path.join(primary, 'tools', 'toolchain.json'), JSON.stringify(manifest(), null, 2) + '\n');
  await writeFile(path.join(primary, '.gitignore'), '.tools/\nartifacts/\n');
  await git(primary, 'add', '.');
  await git(primary, 'commit', '-m', 'test fixture');
  await git(primary, 'push', 'origin', 'main');
  await git(primary, 'worktree', 'add', '-b', 'fixture/a', a, 'main');
  await git(primary, 'worktree', 'add', '-b', 'fixture/b', b, 'main');
  await fakeTools(primary);
  return { directory, remote, primary, a, b };
}
async function report(root, result) {
  const saved = await json(path.join(root, result.report_path));
  assert.equal(saved.run_id, result.run_id);
  assert.equal(saved.status, result.status);
  assert.equal(saved.root, await realpath(root));
  assert.ok(saved.time.finished_at);
  assert.ok(saved.steps.length);
  return saved;
}
const cli = (root, source, cwd) => run([process.execPath, path.join(root, 'tools', 'prepare-worktree.mjs'), '--tools-from', source], cwd);

test('linked checkout reuses absolute fixed tools without altering source, branch or sibling files', async (t) => {
  const f = await fixture(t);
  const sourceFile = path.join(f.primary, 'tools', 'toolchain.json');
  const sourceBytes = await readFile(sourceFile);
  await writeFile(path.join(f.a, 'session-a.txt'), 'only A');
  const result = await prepareWorktree(f.a, { toolsFrom: f.primary });
  assert.equal(result.status, 'pass', result.error);
  const saved = await report(f.a, result);
  assert.equal(saved.tracked_config.sha256, hash(sourceBytes));
  assert.equal(saved.source_config.sha256, hash(sourceBytes));
  assert.equal(saved.effective_config.sha256, hash(await readFile(derived(f.a))));
  assert.equal(saved.reused, false);
  const loaded = await loadToolchain(f.a, {});
  assert.equal(loaded.config_path, derived(f.a));
  for (const [name, item] of Object.entries(loaded.manifest.tools)) {
    assert.ok(path.isAbsolute(name === 'gut' ? item.addons_path : item.path));
    assert.equal(toolPath(f.a, loaded.manifest, name), toolPath(f.primary, manifest(), name));
  }
  assert.equal((await lstat(path.join(f.a, '.tools'))).isSymbolicLink(), false);
  assert.deepEqual(await readFile(sourceFile), sourceBytes);
  assert.equal(await git(f.primary, 'branch', '--show-current'), 'main');
  assert.equal(await git(f.a, 'branch', '--show-current'), 'fixture/a');
  assert.equal(await git(f.b, 'branch', '--show-current'), 'fixture/b');
  await assert.rejects(readFile(path.join(f.b, 'session-a.txt')), { code: 'ENOENT' });
  await assert.rejects(readFile(derived(f.primary)), { code: 'ENOENT' });
  await assert.rejects(readFile(derived(f.b)), { code: 'ENOENT' });
});

test('CLI root follows script location from another cwd, preserving paths containing spaces', async (t) => {
  const f = await fixture(t);
  const actual = await cli(f.a, f.primary, f.directory);
  assert.equal(actual.code, 0, actual.stderr + actual.stdout);
  const result = JSON.parse(actual.stdout);
  assert.equal(result.root, f.a);
  assert.equal(result.tools_from, f.primary);
  assert.equal((await report(f.a, result)).status, 'pass');
  await assert.rejects(readFile(path.join(f.directory, '.tools', 'worktree', 'toolchain.json')), { code: 'ENOENT' });
});

test('same source and bytes prepare idempotently with unique reports', async (t) => {
  const f = await fixture(t);
  const first = await prepareWorktree(f.a, { toolsFrom: f.primary });
  const bytes = await readFile(derived(f.a));
  const second = await prepareWorktree(f.a, { toolsFrom: f.primary });
  assert.equal(first.status, 'pass');
  assert.equal(second.status, 'pass');
  assert.equal(second.reused, true);
  assert.notEqual(first.run_id, second.run_id);
  assert.deepEqual(await readFile(derived(f.a)), bytes);
  await report(f.a, first); await report(f.a, second);
});

test('simultaneous same-source CLI preparation publishes one complete configuration and keeps both reports', async (t) => {
  const f = await fixture(t);
  const actual = await Promise.all([cli(f.a, f.primary, f.directory), cli(f.a, f.primary, f.b)]);
  const results = actual.map((item) => { assert.equal(item.code, 0, item.stdout + item.stderr); return JSON.parse(item.stdout); });
  assert.notEqual(results[0].run_id, results[1].run_id);
  assert.deepEqual(results.map((item) => item.reused).sort(), [false, true]);
  for (const item of results) await report(f.a, item);
  assert.equal((await readdir(path.join(f.a, '.tools', 'worktree'))).length, 1);
  assert.equal((await readdir(path.join(f.a, 'artifacts', 'worktree-setup'))).length, 2);
});

test('competing different sources cannot overwrite the winning configuration', async (t) => {
  const f = await fixture(t);
  await fakeTools(f.b);
  const actual = await Promise.all([cli(f.a, f.primary, f.directory), cli(f.a, f.b, f.directory)]);
  assert.deepEqual(actual.map((item) => item.code).sort(), [0, 1]);
  const results = actual.map((item) => JSON.parse(item.stdout));
  const accepted = results.find((item) => item.status === 'pass'), rejected = results.find((item) => item.status === 'fail');
  assert.match(rejected.error, /not overwritten/);
  assert.equal((await loadToolchain(f.a, {})).config_hash, accepted.effective_config.sha256);
  assert.equal((await json(derived(f.a))).worktree.tools_from, accepted.tools_from);
  await report(f.a, accepted); await report(f.a, rejected);
});

test('relative source, same checkout, primary target and unrelated Git repository produce failure reports', async (t) => {
  const f = await fixture(t), other = await fixture(t);
  const attempts = [
    [f.a, 'relative', /absolute checkout path/],
    [f.a, f.a, /different checkouts/],
    [f.primary, f.a, /primary checkout/],
    [f.a, other.primary, /same Git common directory/],
    [f.a, path.join(f.primary, 'tools'), /checkout root/],
  ];
  for (const [root, source, expected] of attempts) {
    const result = await prepareWorktree(root, { toolsFrom: source });
    assert.equal(result.status, 'fail');
    assert.match(result.error, expected);
    const saved = await report(root, result);
    assert.ok(saved.failure_context.step);
    await assert.rejects(readFile(derived(root)), { code: 'ENOENT' });
  }
});

test('bad source configuration, missing executables and differing exact or minimum policies fail before publishing', async (t) => {
  const f = await fixture(t), file = path.join(f.primary, 'tools', 'toolchain.json');
  const variations = [
    ['{', /Toolchain configuration/],
    [{ ...manifest(), tools: { ...manifest().tools, godot: { path: '.tools/absent', version: manifest().tools.godot.version } } }, /ENOENT/],
    [{ ...manifest(), tools: { ...manifest().tools, node: { path: process.execPath, version: '99.0.0' } } }, /mismatch: node/],
    [{ ...manifest(), tools: { ...manifest().tools, git: { path: '/usr/bin/git', version_policy: 'minimum', min_version: '2.39.0' } } }, /mismatch: git/],
    [{ ...manifest(), tools: { ...manifest().tools, gh: undefined } }, /mismatch: gh/],
  ];
  for (const [value, expected] of variations) {
    await writeFile(file, typeof value === 'string' ? value : JSON.stringify(value));
    const result = await prepareWorktree(f.a, { toolsFrom: f.primary });
    assert.equal(result.status, 'fail'); assert.match(result.error, expected);
    await report(f.a, result);
    await assert.rejects(readFile(derived(f.a)), { code: 'ENOENT' });
  }
});

test('existing changed configuration is preserved and re-preparation requires explicit removal', async (t) => {
  const f = await fixture(t);
  assert.equal((await prepareWorktree(f.a, { toolsFrom: f.primary })).status, 'pass');
  const bytes = await readFile(derived(f.a));
  const changed = { ...manifest(), scope: 'changed source metadata' };
  await writeFile(path.join(f.primary, 'tools', 'toolchain.json'), JSON.stringify(changed));
  const rejected = await prepareWorktree(f.a, { toolsFrom: f.primary });
  assert.equal(rejected.status, 'fail'); assert.match(rejected.error, /not overwritten/);
  assert.deepEqual(await readFile(derived(f.a)), bytes);
  await report(f.a, rejected);
  await rm(derived(f.a));
  const prepared = await prepareWorktree(f.a, { toolsFrom: f.primary });
  assert.equal(prepared.status, 'pass', prepared.error);
  assert.notEqual(prepared.effective_config.sha256, hash(bytes));
});

test('malformed derived config and explicit missing config never fall back, while explicit tracked config remains usable', async (t) => {
  const f = await fixture(t);
  await mkdir(path.dirname(derived(f.a)), { recursive: true });
  await writeFile(derived(f.a), '{');
  await assert.rejects(loadToolchain(f.a, {}), (error) => error.config_path === derived(f.a));
  for (const invalid of ['', null, 42]) await assert.rejects(loadToolchain(f.a, { ASTRA_TOOLCHAIN_CONFIG: invalid }), /invalid explicit overrides/);
  const absent = path.join(f.a, 'absent.json');
  await assert.rejects(loadToolchain(f.a, { ASTRA_TOOLCHAIN_CONFIG: absent }), (error) => error.config_path === absent && error.code === 'ENOENT');
  assert.equal((await loadToolchain(f.a, { ASTRA_TOOLCHAIN_CONFIG: 'tools/toolchain.json' })).config_path, path.join(f.a, 'tools', 'toolchain.json'));
  const result = await prepareWorktree(f.a, { toolsFrom: f.primary });
  assert.equal(result.status, 'fail'); assert.match(result.error, /not overwritten/);
  assert.equal(await readFile(derived(f.a), 'utf8'), '{');
});

test('shared directory symlinks and non-executable files fail without modifying the source', async (t) => {
  const f = await fixture(t);
  await symlink(path.join(f.primary, '.tools'), path.join(f.a, '.tools'), 'dir');
  const result = await prepareWorktree(f.a, { toolsFrom: f.primary });
  assert.equal(result.status, 'fail'); assert.match(result.error, /must not be a symlink/);
  await assert.rejects(readFile(derived(f.primary)), { code: 'ENOENT' });
  await report(f.a, result);
  await rm(path.join(f.a, '.tools'));
  await chmod(path.join(f.primary, '.tools', 'runtime', 'godot'), 0o644);
  const unavailable = await prepareWorktree(f.a, { toolsFrom: f.primary });
  assert.equal(unavailable.status, 'fail'); assert.match(unavailable.error, /EACCES/);
});

test('another prepared linked source resolves its effective tools and ignores target config or Git environment overrides', async (t) => {
  const f = await fixture(t);
  assert.equal((await prepareWorktree(f.b, { toolsFrom: f.primary })).status, 'pass');
  const result = await prepareWorktree(f.a, { toolsFrom: f.b, environment: { ...process.env,
    ASTRA_TOOLCHAIN_CONFIG: 'absent.json', GIT_DIR: '/absent/repository', GIT_WORK_TREE: '/absent/checkout' } });
  assert.equal(result.status, 'pass', result.error);
  const saved = await report(f.a, result);
  assert.equal(saved.source_config.path, derived(f.b));
  assert.equal((await loadToolchain(f.a, {})).manifest.tools.godot.path, path.join(f.primary, '.tools', 'runtime', 'godot'));
});

test('invalid CLI arguments are rejected with exit 2 and a readable local failure report', async (t) => {
  const f = await fixture(t);
  const actual = await run([process.execPath, path.join(f.a, 'tools', 'prepare-worktree.mjs'), '--force'], f.directory);
  assert.equal(actual.code, 2);
  const result = JSON.parse(actual.stdout);
  assert.equal(result.status, 'fail'); assert.match(result.error, /other arguments are rejected/);
  assert.equal((await report(f.a, result)).failure_context.step, 'arguments');
  await assert.rejects(readFile(derived(f.a)), { code: 'ENOENT' });
});


test('derived provenance rejects another root, relative paths and changed tracked or source configuration', async (t) => {
  const f = await fixture(t);
  assert.equal((await prepareWorktree(f.a, { toolsFrom: f.primary })).status, 'pass');
  const initial = await json(derived(f.a));
  const variations = [
    { ...initial, worktree: undefined },
    { ...initial, worktree: { ...initial.worktree, root: f.b } },
    { ...initial, tools: { ...initial.tools, godot: { ...initial.tools.godot, path: '.tools/relative' } } },
  ];
  for (const invalid of variations) {
    await writeFile(derived(f.a), JSON.stringify(invalid));
    await assert.rejects(loadToolchain(f.a, {}), /provenance|must be absolute/);
  }
  await writeFile(derived(f.a), JSON.stringify(initial));
  const trackedPath = path.join(f.a, 'tools', 'toolchain.json');
  const originalTracked = await readFile(trackedPath);
  await writeFile(trackedPath, JSON.stringify({ ...manifest(), scope: 'changed pin' }));
  await assert.rejects(loadToolchain(f.a, {}), /stale/);
  await writeFile(trackedPath, originalTracked);
  await writeFile(path.join(f.primary, 'tools', 'toolchain.json'), JSON.stringify({ ...manifest(), scope: 'changed source' }));
  await assert.rejects(loadToolchain(f.a, {}), /stale/);
});


test('preparation refuses a target whose derived runtime configuration is not Git-ignored', async (t) => {
  const f = await fixture(t);
  await writeFile(path.join(f.a, '.gitignore'), 'artifacts/\n');
  const result = await prepareWorktree(f.a, { toolsFrom: f.primary });
  assert.equal(result.status, 'fail');
  assert.match(result.error, /check-ignore/);
  assert.equal((await report(f.a, result)).failure_context.step, 'checkout-isolation');
  await assert.rejects(readFile(derived(f.a)), { code: 'ENOENT' });
});
