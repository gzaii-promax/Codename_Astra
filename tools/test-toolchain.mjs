import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { chmod, cp, mkdir, mkdtemp, readFile, rm, writeFile } from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import test from 'node:test';
import { loadToolchain, toolPath, versionMatches } from './toolchain-config.mjs';
import { bootstrap, execute, fileHash, pythonRuntimeSource, resolveExecutable, verifyArchive } from './bootstrap.mjs';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const fixture = async (t) => {
  const directory = await mkdtemp(path.join(os.tmpdir(), 'astra-toolchain-test-'));
  t.after(() => rm(directory, { recursive: true, force: true }));
  return directory;
};

test('local configuration retains exact versions and has official pinned archives', async () => {
  const { manifest, config_path, config_hash } = await loadToolchain(root, { ASTRA_TOOLCHAIN_CONFIG: 'tools/toolchain.json' });
  assert.equal(config_path, path.join(root, 'tools', 'toolchain.json'));
  assert.equal(config_hash, await fileHash(config_path));
  assert.equal(manifest.tools.git.version, '2.54.0');
  assert.ok(manifest.tools.gh.path);
  assert.match(manifest.tools.godot.archive_url, /^https:\/\/github.com\/godotengine\/godot-builds\/releases\/download\//);
  assert.match(manifest.tools.gut.archive_url, /^https:\/\/github.com\/bitwes\/Gut\/archive\//);
  assert.match(manifest.download_checksums.godot_archive, /^[a-f0-9]{64}$/);
});

test('default Python uses exact standalone release rather than any host Python; explicit override remains available', async () => {
  const { manifest } = await loadToolchain(root, { ASTRA_TOOLCHAIN_CONFIG: 'tools/toolchain.json' });
  const source = pythonRuntimeSource(manifest, { PATH: '/usr/bin' });
  assert.equal(source.kind, 'archive');
  assert.equal(source.release, '20260929');
  assert.match(source.url, /20260929\/cpython-3\.12\.14%2B20260929-aarch64-apple-darwin-install_only_stripped\.tar\.gz$/);
  assert.equal(source.sha256, '1bb3e53d231ee2c8881e8daf6426f4dd95bff0dda496af0f3af300357aa998d0');
  assert.deepEqual(pythonRuntimeSource(manifest, { ASTRA_PYTHON: '/explicit/python3' }), { kind: 'explicit', executable: '/explicit/python3' });
  const invalid = structuredClone(manifest);
  delete invalid.download_checksums.python_archive;
  assert.throws(() => pythonRuntimeSource(invalid, {}), /Missing pinned standalone/);
});

test('relative and absolute explicit configurations load actual bytes and SHA256', async (t) => {
  const directory = await fixture(t);
  const { manifest } = await loadToolchain(root, { ASTRA_TOOLCHAIN_CONFIG: 'tools/toolchain.json' });
  manifest.tools.git = { path: '/usr/bin/git', version_policy: 'minimum', min_version: '2.39.0' };
  delete manifest.tools.gh;
  const source = JSON.stringify(manifest) + '\n';
  const file = path.join(directory, 'effective.json');
  await writeFile(file, source);
  for (const requested of ['effective.json', file]) {
    const loaded = await loadToolchain(directory, { ASTRA_TOOLCHAIN_CONFIG: requested });
    assert.equal(loaded.config_path, file);
    assert.equal(loaded.config_hash, createHash('sha256').update(source).digest('hex'));
    assert.deepEqual(loaded.manifest.tools.git, manifest.tools.git);
  }
});

test('bad config, incomplete tools and underspecified minimum policies reject', async (t) => {
  const directory = await fixture(t);
  await mkdir(path.join(directory, 'tools'));
  const file = path.join(directory, 'tools', 'toolchain.json');
  await writeFile(file, '{');
  await assert.rejects(loadToolchain(directory, {}), (error) => error instanceof SyntaxError && error.config_path === file && error.message.includes(file));
  const { manifest } = await loadToolchain(root, { ASTRA_TOOLCHAIN_CONFIG: 'tools/toolchain.json' });
  const variations = [
    { ...manifest, schema_version: 2 },
    { ...manifest, tools: { ...manifest.tools, python: undefined } },
    { ...manifest, tools: { ...manifest.tools, node: { path: '/bin/node', version_policy: 'minimum', min_version: '24.0.0' } } },
    { ...manifest, tools: { ...manifest.tools, git: { path: '/bin/git', version_policy: 'minimum', min_version: '2.38.9' } } },
    { ...manifest, tools: { ...manifest.tools, git: { path: '/bin/git', version_policy: 'minimum', min_version: '2.39.0', version: '2.54.0' } } },
  ];
  for (const invalid of variations) {
    await writeFile(file, JSON.stringify(invalid));
    await assert.rejects(loadToolchain(directory, {}));
  }
  const absent = path.join(directory, 'absent.json');
  await assert.rejects(loadToolchain(directory, { ASTRA_TOOLCHAIN_CONFIG: 'absent.json' }), (error) => error.code === 'ENOENT' && error.config_path === absent && error.message.includes(absent));
});

test('Git minimum comparisons preserve patch, minor and major ordering', () => {
  const policy = { version_policy: 'minimum', min_version: '2.39.0' };
  for (const version of ['2.39.0', '2.39.1', '2.54.0', '3.0.0']) assert.equal(versionMatches(policy, version), true);
  for (const version of ['2.38.99', '1.99.99', '2.39', '2.39.0-rc1', undefined]) assert.equal(versionMatches(policy, version), false);
  assert.equal(versionMatches({ version: '4.7.2.stable.official.ed1daf0bf' }, '4.7.2.stable.official.ed1daf0bf'), true);
  assert.equal(versionMatches({ version: '4.7.2.stable.official.ed1daf0bf' }, '4.7.2.stable.official.other'), false);
  assert.equal(versionMatches({ version: '2.54.0' }, '2.55.0'), false);
});

test('tool paths support relative, absolute and unavailable fallback without hiding loader errors', () => {
  const manifest = { tools: { node: { path: '/opt/node' }, gut: { addons_path: '.tools/gut/addons/gut' } } };
  assert.equal(toolPath('/project', manifest, 'node'), '/opt/node');
  assert.equal(toolPath('/project', manifest, 'gut'), '/project/.tools/gut/addons/gut');
  assert.equal(toolPath('/project', undefined, 'python'), '/project/__missing_tool__');
});

test('runtime lookup honors explicit path, PATH order and executable bit', async (t) => {
  const directory = await fixture(t);
  const first = path.join(directory, 'one'), second = path.join(directory, 'two');
  await mkdir(first); await mkdir(second);
  await writeFile(path.join(first, 'python3'), '#!/bin/sh\n');
  const executable = path.join(second, 'python3');
  await writeFile(executable, '#!/bin/sh\n'); await chmod(executable, 0o755);
  assert.equal(await resolveExecutable('python3', directory, { PATH: `${first}${path.delimiter}${second}` }), executable);
  assert.equal(await resolveExecutable('./two/python3', directory, {}), executable);
  assert.equal(await resolveExecutable(executable, directory, {}), executable);
  await assert.rejects(resolveExecutable('missing-python', directory, { PATH: second }), /not found/);
});

test('every archive checksum is recomputed; cached Python tarball corruption and absent digests fail', async (t) => {
  const directory = await fixture(t), file = path.join(directory, 'python.tar.gz');
  await writeFile(file, 'verified official fixture');
  const expected = await fileHash(file);
  assert.equal(await verifyArchive(file, expected), expected);
  await writeFile(file, 'corrupted cached archive');
  await assert.rejects(verifyArchive(file, expected), /SHA256 mismatch/);
  await assert.rejects(verifyArchive(file, null), /Missing valid pinned/);
});

test('commands preserve argv literals, nonzero exits and terminate stalled processes', async () => {
  const literal = '$(printf secret)';
  const success = await execute([process.execPath, '-e', 'console.log(process.argv[1])', literal], { cwd: root });
  assert.equal(success.exit_code, 0);
  assert.equal(success.stdout.trim(), literal);
  assert.equal(success.timed_out, false);
  const failure = await execute([process.execPath, '-e', 'process.exit(7)'], { cwd: root });
  assert.equal(failure.exit_code, 7);
  const timeout = await execute([process.execPath, '-e', 'setInterval(()=>{}, 1000)'], { cwd: root, timeoutMs: 100 });
  assert.equal(timeout.timed_out, true);
  assert.equal(timeout.terminated, true);
  assert.throws(() => process.kill(process.platform === 'win32' ? timeout.pid : -timeout.pid, 0), { code: 'ESRCH' });
  assert.notEqual(timeout.exit_code, 0);
  const missing = await execute(['/this-executable-does-not-exist'], { cwd: root });
  assert.match(missing.spawn_error, /ENOENT/);
});

test('bootstrap prerequisite failure saves readable evidence and removes stale config', async (t) => {
  const directory = await fixture(t);
  await mkdir(path.join(directory, 'tools'));
  for (const file of ['bootstrap.mjs', 'toolchain-config.mjs', 'requirements-gdtoolkit.lock']) await cp(path.join(root, 'tools', file), path.join(directory, 'tools', file));
  const { manifest } = await loadToolchain(root, { ASTRA_TOOLCHAIN_CONFIG: 'tools/toolchain.json' });
  manifest.tools.node.version = '0.0.0';
  await writeFile(path.join(directory, 'tools', 'toolchain.json'), JSON.stringify(manifest));
  await mkdir(path.join(directory, '.tools', 'ci'), { recursive: true });
  await writeFile(path.join(directory, '.tools', 'ci', 'toolchain.json'), '{"stale":true}');
  const result = await bootstrap(directory, {});
  assert.equal(result.status, 'fail');
  assert.match(result.error, process.platform === 'darwin' && process.arch === 'arm64' ? /Node version mismatch/ : /darwin-arm64 only/);
  const pointer = JSON.parse(await readFile(path.join(directory, 'artifacts', 'bootstrap', 'latest.json')));
  const report = JSON.parse(await readFile(path.join(directory, pointer.report_path)));
  assert.equal(pointer.status, 'fail');
  assert.equal(report.run_id, result.run_id);
  assert.equal(report.steps.at(-1).status, 'fail');
  assert.match(await readFile(path.join(directory, report.steps.at(-1).log_path), 'utf8'), /Error:/);
  await assert.rejects(readFile(path.join(directory, '.tools', 'ci', 'toolchain.json')), { code: 'ENOENT' });
});
