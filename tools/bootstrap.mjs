#!/usr/bin/env node
import { spawn } from 'node:child_process';
import { constants, createReadStream } from 'node:fs';
import { createHash, randomUUID } from 'node:crypto';
import { access, chmod, cp, mkdir, readFile, readdir, rename, rm, stat, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { loadToolchain, versionMatches } from './toolchain-config.mjs';

export async function fileHash(file) {
  const digest = createHash('sha256');
  for await (const chunk of createReadStream(file)) digest.update(chunk);
  return digest.digest('hex');
}

export async function verifyArchive(file, expected) {
  if (!/^[a-f0-9]{64}$/.test(expected ?? '')) throw new Error('Missing valid pinned SHA256 digest.');
  const actual = await fileHash(file);
  if (actual !== expected) throw new Error(`Archive SHA256 mismatch: ${path.basename(file)}; expected ${expected}, got ${actual}.`);
  return actual;
}

export async function resolveExecutable(candidate, root, environment = process.env) {
  const options = path.isAbsolute(candidate) || candidate.includes(path.sep)
    ? [path.resolve(root, candidate)] : (environment.PATH ?? '').split(path.delimiter).filter(Boolean).map((entry) => path.resolve(entry, candidate));
  for (const item of options) {
    try { if ((await stat(item)).isFile()) { await access(item, constants.X_OK); return item; } }
    catch (error) { if (!['ENOENT', 'EACCES', 'ENOTDIR'].includes(error.code)) throw error; }
  }
  throw new Error(`Executable not found or not executable: ${candidate}`);
}

export async function execute(command, { cwd, timeoutMs = 15000, environment = process.env } = {}) {
  let stdout = '', stderr = '', timed_out = false, spawn_error = null;
  const started = Date.now();
  let pid;
  const outcome = await new Promise((resolve) => {
    const child = spawn(command[0], command.slice(1), { cwd, env: environment,
      detached: process.platform !== 'win32', stdio: ['ignore', 'pipe', 'pipe'] });
    pid = child.pid;
    // Bound captured output; commands never print environment variables or credentials.
    child.stdout.on('data', (data) => { stdout = (stdout + data).slice(-100000); });
    child.stderr.on('data', (data) => { stderr = (stderr + data).slice(-100000); });
    child.on('error', (error) => { spawn_error = String(error); });
    const kill = (signal) => {
      try { if (pid) process.platform === 'win32' ? child.kill(signal) : process.kill(-pid, signal); }
      catch (error) { if (error.code !== 'ESRCH') stderr += `\nTermination failed: ${error.message}`; }
    };
    let hardKill;
    const deadline = setTimeout(() => { timed_out = true; kill('SIGTERM'); hardKill = setTimeout(() => kill('SIGKILL'), 500); }, timeoutMs);
    child.once('close', (exit_code, signal) => {
      clearTimeout(deadline); clearTimeout(hardKill); resolve({ exit_code, signal });
    });
  });
  let terminated = true;
  if (pid) {
    try { process.kill(process.platform === 'win32' ? pid : -pid, 0); terminated = false; }
    catch (error) { if (error.code !== 'ESRCH') terminated = false; }
  }
  return { ...outcome, pid: pid ?? null, terminated, stdout, stderr, timed_out, spawn_error, duration_ms: Date.now() - started };
}

export async function bootstrap(root, environment = process.env) {
  const started = new Date();
  const runId = `${started.toISOString().replace(/[-:.]/g, '')}-${randomUUID().slice(0, 8)}`;
  const runDir = path.join(root, 'artifacts', 'bootstrap', runId), logs = path.join(runDir, 'logs');
  const destination = path.join(root, '.tools', 'ci'), stage = path.join(destination, `stage-${runId}`);
  const relative = (file) => path.relative(root, file).split(path.sep).join('/');
  const report = { schema_version: 1, run_id: runId, status: 'blocked', platform: `${process.platform}-${process.arch}`,
    time: { started_at: started.toISOString() }, source_files_sha256: {}, steps: [], effective_config: null };
  await mkdir(logs, { recursive: true });
  // A failed retry cannot leave a previous successful configuration looking current.
  await rm(path.join(destination, 'toolchain.json'), { force: true });
  async function step(id, action) {
    const logPath = path.join(logs, `${id}.log`);
    const item = { id, status: 'blocked', log_path: relative(logPath) };
    report.steps.push(item);
    try {
      item.actual = await action(logPath);
      item.status = 'pass';
      if (!item.actual?.command) await writeFile(logPath, JSON.stringify(item.actual, null, 2) + '\n');
      return item.actual;
    } catch (error) {
      item.status = 'fail'; item.error = String(error);
      await writeFile(logPath, (await readFile(logPath, 'utf8').catch(() => '')) + `\n${item.error}\n`);
      throw error;
    }
  }
  async function command(logPath, argv, timeoutMs = 15000) {
    const actual = await execute(argv, { cwd: root, timeoutMs, environment });
    await writeFile(logPath, `command(argv): ${JSON.stringify(argv)}\ncwd: ${root}\ntimeout_ms: ${timeoutMs}\n--- stdout ---\n${actual.stdout}\n--- stderr ---\n${actual.stderr}\n--- result ---\n${JSON.stringify({ ...actual, stdout: undefined, stderr: undefined })}\n`);
    if (actual.exit_code !== 0 || actual.timed_out || actual.spawn_error || !actual.terminated) throw new Error(`Command failed: ${path.basename(argv[0])}; exit=${actual.exit_code}, timeout=${actual.timed_out}, terminated=${actual.terminated}, spawn=${actual.spawn_error}.`);
    return { command: argv, ...actual };
  }
  try {
    const { manifest, config_hash } = await step('configuration', async () => {
      if (process.platform !== 'darwin' || process.arch !== 'arm64') throw new Error('Bootstrap supports darwin-arm64 only.');
      const pinned = await loadToolchain(root, {});
      for (const file of ['tools/toolchain.json', 'tools/requirements-gdtoolkit.lock', 'tools/bootstrap.mjs', 'tools/toolchain-config.mjs']) {
        report.source_files_sha256[file] = await fileHash(path.join(root, file));
      }
      return { manifest: pinned.manifest, config_hash: pinned.config_hash };
    });
    const nodeVersion = process.versions.node;
    await step('runtime-node', async () => {
      if (!versionMatches(manifest.tools.node, nodeVersion)) throw new Error(`Node version mismatch: expected ${manifest.tools.node.version}, got ${nodeVersion}.`);
      return { path: process.execPath, version: nodeVersion };
    });
    const python = await resolveExecutable(environment.ASTRA_PYTHON || 'python3', root, environment);
    await step('runtime-python', async (logPath) => {
      const actual = await command(logPath, [python, '--version']);
      const version = (actual.stdout + actual.stderr).match(/\d+\.\d+\.\d+/)?.[0];
      if (!versionMatches(manifest.tools.python, version)) throw new Error(`Python version mismatch: expected ${manifest.tools.python.version}, got ${version}.`);
      return { ...actual, version };
    });
    const git = await resolveExecutable(environment.ASTRA_GIT || 'git', root, environment);
    const gitPolicy = { path: git, version_policy: 'minimum', min_version: manifest.ci?.git_min_version };
    if (!versionMatches({ version_policy: 'minimum', min_version: '2.39.0' }, gitPolicy.min_version)) throw new Error('CI Git minimum must be at least 2.39.0.');
    await step('runtime-git', async (logPath) => {
      const actual = await command(logPath, [git, '--version']);
      const version = (actual.stdout + actual.stderr).match(/\d+\.\d+\.\d+/)?.[0];
      if (!versionMatches(gitPolicy, version)) throw new Error(`Git must satisfy minimum ${gitPolicy.min_version}; got ${version}.`);
      return { ...actual, version, policy: gitPolicy };
    });
    await mkdir(stage, { recursive: true });
    const archiveDirectory = path.join(destination, 'downloads');
    await mkdir(archiveDirectory, { recursive: true });
    async function archive(id, url, expected) {
      const target = path.join(archiveDirectory, `${id}.zip`);
      const exists = await stat(target).then(() => true).catch((error) => { if (error.code === 'ENOENT') return false; throw error; });
      if (!exists) await step(`download-${id}`, async (logPath) => {
        const temporary = path.join(stage, `${id}.zip`);
        const actual = await command(logPath, ['/usr/bin/curl', '--disable', '--fail', '--location', '--silent', '--show-error', '--connect-timeout', '20', '--max-time', '240', '--output', temporary, url], 250000);
        await verifyArchive(temporary, expected);
        await rename(temporary, target);
        return { ...actual, url, sha256: expected };
      });
      await step(`verify-${id}-archive`, async () => ({ archive: relative(target), sha256: await verifyArchive(target, expected), cached: exists }));
      return target;
    }
    const godotArchive = await archive('godot', manifest.tools.godot.archive_url, manifest.download_checksums.godot_archive);
    const gutArchive = await archive('gut', manifest.tools.gut.archive_url, manifest.download_checksums.gut_archive);
    await step('extract-godot', async (logPath) => command(logPath, ['/usr/bin/ditto', '-x', '-k', godotArchive, path.join(stage, 'godot')], 60000));
    await step('extract-gut', async (logPath) => command(logPath, ['/usr/bin/ditto', '-x', '-k', gutArchive, path.join(stage, 'gut')], 60000));
    const godotStage = path.join(stage, 'godot', 'Godot.app', 'Contents', 'MacOS', 'Godot');
    await chmod(godotStage, 0o755);
    await step('verify-godot-signature', async (logPath) => command(logPath, ['/usr/bin/codesign', '--verify', '--deep', '--strict', path.join(stage, 'godot', 'Godot.app')], 30000));
    await step('verify-godot', async (logPath) => {
      const actual = await command(logPath, [godotStage, '--headless', '--version']);
      const version = (actual.stdout + actual.stderr).trim().split(/\s/)[0];
      if (!versionMatches(manifest.tools.godot, version)) throw new Error(`Godot version mismatch: ${version}.`);
      return { ...actual, version };
    });
    const gutEntries = await readdir(path.join(stage, 'gut'));
    if (gutEntries.length !== 1 || !/^Gut-/.test(gutEntries[0])) throw new Error('Unexpected GUT archive structure.');
    const gutStage = path.join(stage, 'gut', gutEntries[0], 'addons', 'gut');
    await step('verify-gut', async () => {
      const metadata = await readFile(path.join(gutStage, 'plugin.cfg'), 'utf8');
      const version = metadata.match(/^version="([^"]+)"/m)?.[1];
      if (!versionMatches(manifest.tools.gut, version)) throw new Error(`GUT version mismatch: ${version}.`);
      return { version };
    });
    // Recreate environments and installations even with cached archives, avoiding unverified directory skips.
    const venv = path.join(destination, 'gdtoolkit-venv');
    await rm(venv, { recursive: true, force: true });
    await step('python-venv', async (logPath) => command(logPath, [python, '-m', 'venv', venv], 60000));
    const venvPython = path.join(venv, 'bin', 'python');
    await step('python-packages', async (logPath) => command(logPath, [venvPython, '-m', 'pip', '--isolated', 'install', '--index-url', 'https://pypi.org/simple', '--disable-pip-version-check', '--no-input', '--require-hashes', '--force-reinstall', '--only-binary=:all:', '--timeout', '30', '--retries', '2', '-r', path.join(root, 'tools', 'requirements-gdtoolkit.lock')], 240000));
    await step('python-dependencies', async (logPath) => command(logPath, [venvPython, '-m', 'pip', '--isolated', 'check']));
    for (const name of ['gdlint', 'gdformat']) await step(`verify-${name}`, async (logPath) => {
      const actual = await command(logPath, [path.join(venv, 'bin', name), '--version']);
      const version = (actual.stdout + actual.stderr).match(/\d+\.\d+\.\d+/)?.[0];
      if (!versionMatches(manifest.tools[name], version)) throw new Error(`${name} version mismatch: ${version}.`);
      return { ...actual, version };
    });
    for (const name of ['godot', 'gut']) await rm(path.join(destination, name), { recursive: true, force: true });
    await rename(path.join(stage, 'godot'), path.join(destination, 'godot'));
    await mkdir(path.join(destination, 'gut'), { recursive: true });
    await cp(gutStage, path.join(destination, 'gut', 'addons', 'gut'), { recursive: true });
    const effective = structuredClone(manifest);
    effective.scope = 'CI darwin-arm64; reproducible dependencies and existing toolchain/game checks';
    effective.tools.godot.path = relative(path.join(destination, 'godot', 'Godot.app', 'Contents', 'MacOS', 'Godot'));
    effective.tools.gut.addons_path = relative(path.join(destination, 'gut', 'addons', 'gut'));
    effective.tools.python = { path: relative(venvPython), version: manifest.tools.python.version, base_path: python };
    for (const name of ['gdlint', 'gdformat']) effective.tools[name].path = relative(path.join(venv, 'bin', name));
    effective.tools.node = { path: process.execPath, version: manifest.tools.node.version };
    effective.tools.git = gitPolicy;
    delete effective.tools.gh;
    delete effective.system_tools_verified;
    delete effective.godot_signature;
    delete effective.deferred;
    effective.bootstrap = { run_id: runId, source_config_sha256: config_hash,
      requirements_sha256: report.source_files_sha256['tools/requirements-gdtoolkit.lock'] };
    const config = path.join(destination, 'toolchain.json');
    await writeFile(config, JSON.stringify(effective, null, 2) + '\n');
    const loaded = await loadToolchain(root, { ASTRA_TOOLCHAIN_CONFIG: config });
    report.effective_config = { path: relative(config), sha256: loaded.config_hash };
    report.status = 'pass';
  } catch (error) { report.status = 'fail'; report.error = String(error); }
  finally {
    try { await rm(stage, { recursive: true, force: true }); }
    catch (error) { report.status = 'fail'; report.cleanup_error = String(error); }
    report.time.finished_at = new Date().toISOString();
    report.time.duration_ms = Date.now() - started.getTime();
    const reportFile = path.join(runDir, 'report.json');
    await writeFile(reportFile, JSON.stringify(report, null, 2) + '\n');
    const saved = JSON.parse(await readFile(reportFile, 'utf8'));
    if (saved.run_id !== runId || saved.steps.length !== report.steps.length) throw new Error('Bootstrap report readback failed.');
    await writeFile(path.join(root, 'artifacts', 'bootstrap', 'latest.json'), JSON.stringify({ run_id: runId, status: saved.status, report_path: relative(reportFile) }, null, 2) + '\n');
    console.log(JSON.stringify({ run_id: runId, status: saved.status, report_path: relative(reportFile), error: saved.error ?? null }));
  }
  return report;
}

const entry = fileURLToPath(import.meta.url);
if (process.argv[1] && path.resolve(process.argv[1]) === entry) {
  if (process.argv.length !== 2) { console.error('Usage: node tools/bootstrap.mjs; arguments are rejected.'); process.exitCode = 2; }
  else {
    const result = await bootstrap(path.resolve(path.dirname(entry), '..'));
    process.exitCode = result.status === 'pass' ? 0 : 1;
  }
}
