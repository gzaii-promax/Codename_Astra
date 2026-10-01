#!/usr/bin/env node
import { spawn } from 'node:child_process';
import { readFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const config = JSON.parse(await readFile(path.join(root, 'tools/toolchain.json'), 'utf8'));
const engine = path.resolve(root, config.tools.godot.path);
const child = spawn(engine, ['--path', root], { cwd: root, stdio: 'inherit' });
child.on('error', (error) => {
  console.error(`无法启动 Godot：${error.message}。参见 tools/README.md。`);
  process.exitCode = 1;
});
child.on('exit', (code) => { process.exitCode = code ?? 1; });
