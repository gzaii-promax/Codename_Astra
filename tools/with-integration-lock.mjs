#!/usr/bin/env node
import { execFile, spawn } from 'node:child_process';
import { randomUUID } from 'node:crypto';
import { mkdir, readFile, realpath, rm, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { promisify } from 'node:util';

const execute = promisify(execFile);
export async function withIntegrationLock(root, command) {
  if (!command.length) throw new Error('An explicit command is required.');
  if (process.platform === 'win32') throw new Error('Integration lock runner currently requires POSIX process groups.');
  const { stdout } = await execute('git', ['rev-parse', '--git-common-dir'], { cwd: root });
  const common = await realpath(path.resolve(root, stdout.trim()));
  const directory = path.join(common, 'astra-integration.lock');
  const token = randomUUID();
  try { await mkdir(directory); }
  catch (error) {
    if (error.code !== 'EEXIST') throw error;
    let owner;
    try { owner = await readFile(path.join(directory, 'owner.json'), 'utf8'); }
    catch { owner = 'Owner record unavailable; do not remove a possibly starting lock.'; }
    const blocked = new Error(`Integration is occupied: ${directory}\n${owner}`);
    blocked.exitCode = 73;
    throw blocked;
  }
  let recorded = false, safeToRelease = true;
  try {
    await writeFile(path.join(directory, 'owner.json'), JSON.stringify({
      token, pid: process.pid, worktree: root, started_at: new Date().toISOString(), command,
    }, null, 2) + '\n', { flag: 'wx' });
    recorded = true;
    console.error(`Integration lock acquired: ${directory}`);
    return await new Promise((resolve, reject) => {
      const child = spawn(command[0], command.slice(1), { cwd: root, detached: true, stdio: 'inherit' });
      safeToRelease = !child.pid;
      let hardKill, cancelledSignal;
      const alive = () => {
        if (!child.pid) return false;
        try { process.kill(-child.pid, 0); return true; }
        catch (error) { return error.code !== 'ESRCH'; }
      };
      const kill = (signal) => {
        if (!child.pid) return;
        try { process.kill(-child.pid, signal); }
        catch (error) { if (error.code !== 'ESRCH') console.error(`Process group termination: ${error.message}`); }
      };
      const cancel = (signal) => {
        cancelledSignal = signal;
        kill(signal);
        if (!hardKill) hardKill = setTimeout(() => kill('SIGKILL'), 500);
      };
      const interrupt = () => cancel('SIGINT');
      const terminate = () => cancel('SIGTERM');
      process.on('SIGINT', interrupt); process.on('SIGTERM', terminate);
      const removeHandlers = () => {
        process.off('SIGINT', interrupt); process.off('SIGTERM', terminate);
      };
      child.on('error', (error) => { safeToRelease = !child.pid; removeHandlers(); reject(error); });
      child.on('close', async (code, signal) => {
        // A script may exit before its descendants. Keep ownership until the entire group ends.
        if (alive()) kill('SIGTERM');
        for (let attempt = 0; alive() && attempt < 30; attempt++) {
          if (attempt === 10) kill('SIGKILL');
          await new Promise((done) => setTimeout(done, 50));
        }
        clearTimeout(hardKill); removeHandlers();
        safeToRelease = !alive();
        if (!safeToRelease) reject(new Error(`Process group ${child.pid} still exists; integration lock retained.`));
        else {
          const endedBy = cancelledSignal || signal;
          resolve(endedBy === 'SIGINT' ? 130 : endedBy === 'SIGTERM' ? 143 : code ?? 1);
        }
      });
    });
  } finally {
    if (!recorded) await rm(directory, { recursive: true });
    else if (safeToRelease) {
      const owner = JSON.parse(await readFile(path.join(directory, 'owner.json'), 'utf8'));
      if (owner.token !== token) throw new Error(`Lock ownership changed; leave it intact: ${directory}`);
      await rm(directory, { recursive: true });
    }
  }
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const args = process.argv.slice(2);
  if (args[0] !== '--' || args.length < 2) {
    console.error('Usage: node tools/with-integration-lock.mjs -- <command> [args...]');
    process.exitCode = 2;
  } else {
    try {
      process.exitCode = await withIntegrationLock(path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..'), args.slice(1));
    } catch (error) { console.error(error.message); process.exitCode = error.exitCode ?? 1; }
  }
}
