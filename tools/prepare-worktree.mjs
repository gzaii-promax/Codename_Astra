#!/usr/bin/env node
import { spawnSync } from 'node:child_process';
import { constants } from 'node:fs';
import { createHash, randomUUID } from 'node:crypto';
import { access, link, lstat, mkdir, readFile, realpath, rm, stat, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { loadToolchain, toolPath } from './toolchain-config.mjs';

const digest = (value) => createHash('sha256').update(value).digest('hex');
const derivedRelative = '.tools/worktree/toolchain.json';

function git(root, args, environment) {
  const cleanEnvironment = { ...environment };
  for (const name of ['GIT_DIR', 'GIT_WORK_TREE', 'GIT_COMMON_DIR', 'GIT_INDEX_FILE', 'GIT_NAMESPACE']) delete cleanEnvironment[name];
  const actual = spawnSync('git', ['-C', root, ...args], { env: cleanEnvironment, encoding: 'utf8', timeout: 10000, maxBuffer: 1024 * 1024 });
  if (actual.error || actual.status !== 0) throw new Error(`Git ${args.join(' ')} failed: ${actual.error?.message ?? actual.stderr.trim()}`);
  return actual.stdout.trim();
}

async function checkout(root, environment) {
  const top = await realpath(git(root, ['rev-parse', '--show-toplevel'], environment));
  if (top !== root) throw new Error(`Expected a checkout root, got ${root}; Git root is ${top}.`);
  const gitDir = await realpath(git(root, ['rev-parse', '--absolute-git-dir'], environment));
  const commonDir = await realpath(git(root, ['rev-parse', '--path-format=absolute', '--git-common-dir'], environment));
  git(root, ['ls-files', '--error-unmatch', 'tools/toolchain.json'], environment);
  return { root, git_dir: gitDir, common_git_dir: commonDir, linked: gitDir !== commonDir };
}

async function localDirectories(root, relative) {
  let directory = root;
  for (const part of relative.split('/')) {
    directory = path.join(directory, part);
    try { await mkdir(directory); }
    catch (error) { if (error.code !== 'EEXIST') throw error; }
    const item = await lstat(directory);
    if (!item.isDirectory() || item.isSymbolicLink()) throw new Error(`Local directory must not be a symlink or file: ${directory}`);
  }
  return directory;
}

function policy(item, name) {
  const kind = item?.version_policy || 'exact';
  if (kind === 'minimum' && name === 'git' && typeof item.min_version === 'string' && !item.version) {
    return { version_policy: kind, min_version: item.min_version };
  }
  if (kind === 'exact' && typeof item?.version === 'string' && item.version) return { version_policy: kind, version: item.version };
  throw new Error(`Unsupported version policy for ${name}.`);
}

// A fully written temporary file is linked atomically. Unlike rename, link refuses
// an existing destination, including another process's successful preparation.
async function publish(root, bytes, runId) {
  const directory = await localDirectories(root, '.tools/worktree');
  const destination = path.join(root, derivedRelative);
  const temporary = path.join(directory, `.toolchain-${runId}.json`);
  await writeFile(temporary, bytes, { flag: 'wx', mode: 0o600 });
  try {
    try { await link(temporary, destination); return false; }
    catch (error) {
      if (error.code !== 'EEXIST') throw error;
      const info = await lstat(destination);
      if (info.isFile() && !info.isSymbolicLink() && (await readFile(destination, 'utf8')) === bytes) return true;
      throw new Error(`Existing derived configuration differs or is unsafe: ${destination}. It was not overwritten. Stop processes using this worktree, inspect the configuration, remove only ${derivedRelative}, then prepare again. For changed tool versions use an independent bootstrap instead.`);
    }
  } finally { await rm(temporary, { force: true }); }
}

export async function prepareWorktree(root, { toolsFrom, environment = process.env, argumentError = null } = {}) {
  const started = new Date();
  const runId = `${started.toISOString().replace(/[-:.]/g, '')}-${randomUUID()}`;
  root = path.resolve(root);
  const report = { schema_version: 1, scope: 'worktree-setup', run_id: runId, status: 'fail', root,
    tools_from: toolsFrom ?? null, time: { started_at: started.toISOString() }, steps: [],
    tracked_config: null, source_config: null, effective_config: null, reused: false, error: null };
  const reportsDirectory = await localDirectories(root, 'artifacts/worktree-setup');
  const runDirectory = path.join(reportsDirectory, runId);
  await mkdir(runDirectory);
  async function step(id, action) {
    const entry = { id, status: 'fail' };
    report.steps.push(entry);
    try { entry.actual = await action(); entry.status = 'pass'; return entry.actual; }
    catch (error) { entry.error = String(error); report.failure_context = { step: id, message: error.message, code: error.code ?? null }; throw error; }
  }
  try {
    await step('arguments', async () => {
      if (argumentError) throw new Error(argumentError);
      if (typeof toolsFrom !== 'string' || !path.isAbsolute(toolsFrom)) throw new Error('--tools-from requires an absolute checkout path.');
      return { tools_from: toolsFrom };
    });
    const locations = await step('checkout-isolation', async () => {
      root = await realpath(root);
      report.root = root;
      const sourceRoot = await realpath(toolsFrom);
      report.tools_from = sourceRoot;
      if (sourceRoot === root) throw new Error('Tool source and target must be different checkouts.');
      const target = await checkout(root, environment), source = await checkout(sourceRoot, environment);
      if (!target.linked) throw new Error('Target must be a linked Git worktree; the primary checkout cannot be prepared.');
      if (target.common_git_dir !== source.common_git_dir) throw new Error('Tool source and target must share the same Git common directory.');
      for (const directory of ['.tools', '.tools/worktree']) {
        try {
          const item = await lstat(path.join(root, directory));
          if (!item.isDirectory() || item.isSymbolicLink()) throw new Error(`Local directory must not be a symlink or file: ${path.join(root, directory)}`);
        } catch (error) { if (error.code !== 'ENOENT') throw error; }
      }
      git(root, ['check-ignore', '-q', '--', derivedRelative], environment);
      return { target, source };
    });
    const tracked = await step('tracked-configuration', async () => {
      const loaded = await loadToolchain(root, { ASTRA_TOOLCHAIN_CONFIG: 'tools/toolchain.json' });
      report.tracked_config = { path: loaded.config_path, sha256: loaded.config_hash };
      return loaded;
    });
    const source = await step('source-configuration', async () => {
      // The target process's override must not select a different source's config.
      const loaded = await loadToolchain(locations.source.root, {});
      report.source_config = { path: loaded.config_path, sha256: loaded.config_hash };
      return loaded;
    });
    const effective = await step('compatible-tools', async () => {
      if (tracked.manifest.platform !== source.manifest.platform) throw new Error('Source and target toolchain platforms differ.');
      const manifest = structuredClone(tracked.manifest);
      for (const [name, target] of Object.entries(manifest.tools)) {
        const available = source.manifest.tools[name];
        if (!available || JSON.stringify(policy(target, name)) !== JSON.stringify(policy(available, name))) {
          throw new Error(`Tool version or policy mismatch: ${name}. Use an independent bootstrap for changed tool requirements.`);
        }
        const executable = toolPath(locations.source.root, source.manifest, name);
        const info = await stat(executable);
        if (name === 'gut' ? !info.isDirectory() : !info.isFile()) throw new Error(`Invalid tool file type: ${name}: ${executable}`);
        await access(executable, name === 'gut' ? constants.R_OK : constants.X_OK);
        if (name === 'gut') target.addons_path = executable;
        else target.path = executable;
        if (target.base_path) target.base_path = path.resolve(locations.source.root, available.base_path || target.base_path);
      }
      manifest.scope = 'Linked worktree; fixed tools reused by absolute paths; local caches and reports';
      manifest.worktree = { schema_version: 1, root, tools_from: locations.source.root,
        common_git_dir: locations.target.common_git_dir, tracked_config_sha256: tracked.config_hash,
        source_config_path: source.config_path, source_config_sha256: source.config_hash };
      return manifest;
    });
    const bytes = JSON.stringify(effective, null, 2) + '\n';
    report.effective_config = { path: path.join(root, derivedRelative), sha256: digest(bytes) };
    report.reused = await step('publish-local-configuration', () => publish(root, bytes, runId));
    await step('configuration-readback', async () => {
      const loaded = await loadToolchain(root, {});
      if (loaded.config_path !== report.effective_config.path || loaded.config_hash !== report.effective_config.sha256) throw new Error('Derived configuration readback differs.');
      return { config_path: loaded.config_path, config_hash: loaded.config_hash };
    });
    report.status = 'pass';
  } catch (error) { report.error = String(error); }
  report.time.finished_at = new Date().toISOString();
  report.time.duration_ms = Date.now() - started.getTime();
  const reportFile = path.join(runDirectory, 'report.json');
  await writeFile(reportFile, JSON.stringify(report, null, 2) + '\n', { flag: 'wx' });
  const saved = JSON.parse(await readFile(reportFile, 'utf8'));
  if (saved.run_id !== runId || saved.status !== report.status) throw new Error('Worktree setup report readback failed.');
  // No shared latest pointer: concurrent preparations retain distinct reports.
  return { ...saved, report_path: path.relative(root, reportFile).split(path.sep).join('/') };
}

const entry = fileURLToPath(import.meta.url);
if (process.argv[1] && path.resolve(process.argv[1]) === entry) {
  const args = process.argv.slice(2);
  const valid = args.length === 2 && args[0] === '--tools-from';
  const result = await prepareWorktree(path.resolve(path.dirname(entry), '..'), {
    toolsFrom: valid ? args[1] : null,
    argumentError: valid ? null : 'Usage: node tools/prepare-worktree.mjs --tools-from /absolute/verified-checkout; other arguments are rejected.',
  });
  console.log(JSON.stringify({ run_id: result.run_id, status: result.status, root: result.root,
    tools_from: result.tools_from, effective_config: result.effective_config, reused: result.reused,
    report_path: result.report_path, error: result.error }));
  process.exitCode = valid ? (result.status === 'pass' ? 0 : 1) : 2;
}
