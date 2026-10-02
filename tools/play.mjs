#!/usr/bin/env node
import { spawn } from 'node:child_process';
import { randomUUID } from 'node:crypto';
import { mkdir, stat } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { loadToolchain, toolPath } from './toolchain-config.mjs';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const args = process.argv.slice(2);
if (args.length > 1 || (args.length === 1 && args[0] !== '--editor')) {
  console.error('Usage: node tools/play.mjs [--editor]');
  process.exitCode = 2;
} else {
  try {
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
    const child = spawn(engine, command, { cwd: root, env: environment, stdio: 'inherit' });
    child.on('error', (error) => { console.error(`无法启动 Godot：${error.message}。参见 tools/README.md。`); process.exitCode = 1; });
    child.on('exit', (code) => { process.exitCode = code ?? 1; });
  } catch (error) { console.error(error.message); process.exitCode = 1; }
}
