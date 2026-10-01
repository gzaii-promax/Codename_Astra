import { createHash } from 'node:crypto';
import { readFile } from 'node:fs/promises';
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
  const config_path = path.resolve(root, environment.ASTRA_TOOLCHAIN_CONFIG || 'tools/toolchain.json');
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
    return { manifest, config_path, config_hash: createHash('sha256').update(source).digest('hex') };
  } catch (error) {
    error.message = `Toolchain configuration ${config_path}: ${error.message}`;
    error.config_path = config_path;
    throw error;
  }
}
