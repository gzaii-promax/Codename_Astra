import { createHash } from 'node:crypto';
import { lstat, readFile, realpath } from 'node:fs/promises';
import path from 'node:path';

const required = ['godot', 'gut', 'python', 'gdlint', 'gdformat', 'node', 'git'];
const semver = (value) => /^\d+\.\d+\.\d+$/.test(value ?? '')
  ? value.split('.').map(Number) : null;

export function versionMatches(item, actual) {
  if (item?.version_policy !== 'minimum') return Boolean(item?.version && actual === item.version);
  const minimum = semver(item.min_version), observed = semver(actual);
  if (!minimum || !observed) return false;
  for (let index = 0; index < 3; index++) {
    if (observed[index] !== minimum[index]) return observed[index] > minimum[index];
  }
  return true;
}

export function toolPath(root, manifest, name) {
  const item = manifest?.tools?.[name];
  const target = name === 'gut' ? item?.addons_path : item?.path;
  return path.resolve(root, typeof target === 'string' && target ? target : '__missing_tool__');
}

export async function loadToolchain(root, environment = process.env) {
  let selected = environment.ASTRA_TOOLCHAIN_CONFIG;
  if (selected !== undefined && (typeof selected !== 'string' || !selected)) {
    const error = new Error('ASTRA_TOOLCHAIN_CONFIG must be a non-empty configuration path; invalid explicit overrides never fall back.');
    error.config_path = selected;
    throw error;
  }
  if (selected === undefined) {
    const derived = path.join(root, '.tools', 'worktree', 'toolchain.json');
    try { await lstat(derived); selected = derived; }
    catch (error) { if (error.code !== 'ENOENT') throw error; }
  }
  const config_path = path.resolve(root, selected || 'tools/toolchain.json');
  try {
    const source = await readFile(config_path);
    const manifest = JSON.parse(source.toString('utf8'));
    if (manifest.schema_version !== 1 || !manifest.tools) throw new Error('Unsupported or missing toolchain schema.');
    for (const name of required) {
      const item = manifest.tools[name];
      const target = name === 'gut' ? item?.addons_path : item?.path;
      if (!item || typeof target !== 'string' || !target) throw new Error(`Missing tool configuration: ${name}`);
      if (item.version_policy === 'minimum') {
        if (name !== 'git' || item.version || !semver(item.min_version)
          || !versionMatches({ version_policy: 'minimum', min_version: '2.39.0' }, item.min_version)) {
          throw new Error(`Unsupported minimum version policy: ${name}`);
        }
      } else if (!item.version || (item.version_policy && item.version_policy !== 'exact')) {
        throw new Error(`Missing or unsupported version policy: ${name}`);
      }
    }
    if (config_path === path.resolve(root, '.tools', 'worktree', 'toolchain.json')) {
      const origin = manifest.worktree;
      if (origin?.schema_version !== 1 || origin.root !== await realpath(root)
        || !path.isAbsolute(origin.tools_from ?? '') || origin.tools_from === origin.root
        || !path.isAbsolute(origin.common_git_dir ?? '') || !path.isAbsolute(origin.source_config_path ?? '')
        || !/^[a-f0-9]{64}$/.test(origin.tracked_config_sha256 ?? '')
        || !/^[a-f0-9]{64}$/.test(origin.source_config_sha256 ?? '')) {
        throw new Error('Invalid derived worktree configuration provenance. Prepare this worktree again after inspecting and removing its derived configuration.');
      }
      for (const [name, item] of Object.entries(manifest.tools)) {
        if (!path.isAbsolute(name === 'gut' ? item.addons_path ?? '' : item.path ?? '')) {
          throw new Error(`Derived tool path must be absolute: ${name}`);
        }
      }
      const tracked = createHash('sha256').update(await readFile(path.join(root, 'tools', 'toolchain.json'))).digest('hex');
      const original = createHash('sha256').update(await readFile(origin.source_config_path)).digest('hex');
      if (tracked !== origin.tracked_config_sha256 || original !== origin.source_config_sha256) {
        throw new Error('Derived worktree configuration is stale: tracked or source configuration changed. Inspect and remove its derived configuration before preparing again; use independent bootstrap for changed tool versions.');
      }
    }
    return { manifest, config_path, config_hash: createHash('sha256').update(source).digest('hex') };
  } catch (error) {
    error.message = `Toolchain configuration ${config_path}: ${error.message}`;
    error.config_path = config_path;
    throw error;
  }
}
