#!/usr/bin/env node
import { randomUUID } from 'node:crypto';
import { mkdir, stat } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { loadToolchain, toolPath } from './toolchain-config.mjs';
import { context, withLease, runCommand } from './workspace-state.mjs';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const args = process.argv.slice(2);
if (args.length > 1 || (args.length === 1 && args[0] !== '--editor')) {
  console.error('Usage: node tools/play.mjs [--editor]');
  process.exitCode = 2;
} else {
  try {
    if (args[0] === '--editor' && !(await stat(path.join(root, '.git'))).isFile()) throw Error('Main is integration/play only. Open the fixed human workspace or an isolated AI checkout.');
    await context(root);
    const { manifest } = await loadToolchain(root);
    const engine = toolPath(root, manifest, 'godot');
    const runId = `${new Date().toISOString().replace(/[-:.]/g, '')}-${randomUUID().slice(0, 8)}`;
    const logDirectory = path.join(root, 'artifacts', 'play', runId);
    await mkdir(logDirectory, { recursive: true });
    const environment = { ...process.env };
    const linked = (await stat(path.join(root, '.git'))).isFile();
    if (linked && !environment.ASTRA_SETTINGS_PATH) {
      const settingsDirectory = path.join(root, '.tools', 'play');
      await mkdir(settingsDirectory, { recursive: true });
      environment.ASTRA_SETTINGS_PATH = path.join(settingsDirectory, 'settings.cfg');
    }
    const command = ['--path', root, '--log-file', path.join(logDirectory, 'godot.log')];
    if (args[0] === '--editor') command.push('--editor');
    console.error(`Godot project: ${root}\nSettings: ${environment.ASTRA_SETTINGS_PATH || 'default user://settings.cfg'}\nLog: ${path.join(logDirectory, 'godot.log')}`);
    process.exitCode = await withLease(root, args[0] === '--editor' ? ['*'] : [], args[0] === '--editor' ? 'editor' : 'play', () => runCommand(root, [engine, ...command], environment));
  } catch (error) { console.error(error.message); process.exitCode = 1; }
}
