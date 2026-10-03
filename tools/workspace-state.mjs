import { execFile, spawn } from 'node:child_process';
import { randomUUID, createHash } from 'node:crypto';
import { mkdir, readFile, realpath, readdir, rm, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { promisify } from 'node:util';
import { createWriteStream } from 'node:fs';
import { pipeline } from 'node:stream/promises';

const execute = promisify(execFile);
function gitEnvironment() { const env = { ...process.env }; for (const key of ['GIT_DIR', 'GIT_WORK_TREE', 'GIT_INDEX_FILE', 'GIT_COMMON_DIR']) delete env[key]; return env; }
export const sha = (bytes) => createHash('sha256').update(bytes).digest('hex');
export async function gitRaw(root, ...args) {
  return (await execute('git', args, { cwd: root, timeout: 15000, maxBuffer: 32 * 1024 * 1024,
    env: gitEnvironment() })).stdout;
}
export async function git(root, ...args) {
  return (await gitRaw(root, ...args)).trim();
}
export async function context(directory) {
  const root = await realpath(directory);
  if (await realpath(await git(root, 'rev-parse', '--show-toplevel')) !== root) throw Error('Use the checkout root.');
  const common = await realpath(path.resolve(root, await git(root, 'rev-parse', '--git-common-dir')));
  const state = path.join(common, 'astra-workspaces');
  await mkdir(path.join(state, 'claims'), { recursive: true });
  return { root, common, state };
}
export async function registeredHuman(ctx) {
  try { return JSON.parse(await readFile(path.join(ctx.state, 'human.json'), 'utf8')); }
  catch (e) { if (e.code === 'ENOENT') return null; throw e; }
}
async function gate(ctx, operation) {
  const directory = path.join(ctx.state, 'gate');
  try { await mkdir(directory); } catch (e) {
    if (e.code === 'EEXIST') throw Error('Workspace gate occupied or unknown. Retry after its owner exits; never steal it.');
    throw e;
  }
  const token = randomUUID();
  await writeFile(path.join(directory, 'owner.json'), JSON.stringify({ token, pid: process.pid, root: ctx.root }));
  try { return await operation(); }
  finally {
    const owner = JSON.parse(await readFile(path.join(directory, 'owner.json')));
    if (owner.token === token) await rm(directory, { recursive: true });
  }
}
export async function claims(ctx) {
  const names = await readdir(path.join(ctx.state, 'claims'));
  return Promise.all(names.map(async (name) => {
    const record = JSON.parse(await readFile(path.join(ctx.state, 'claims', name)));
    if (typeof record.token !== 'string' || name !== `${record.token}.json` || !Number.isInteger(record.pid) || record.pid <= 0 || !path.isAbsolute(record.root ?? '') || !['editor','play','resource-write','handoff','handoff-review','review','sync'].includes(record.kind) || !Array.isArray(record.files)) throw Error(`Invalid/unknown claim retained: ${name}`);
    if (record.files.length) resources(record.files);
    return record;
  }));
}
export function resources(files) {
  if (!Array.isArray(files) || !files.length) throw Error('Explicit resource paths required.');
  return [...new Set(files.map((file) => {
    if (file === '*') return file;
    if (typeof file !== 'string' || file.includes('\\') || file.split('/').some(p => !p || p === '..' || p === '.') || path.isAbsolute(file) || !/\.(tscn|tres)$/.test(file)) throw Error(`Invalid resource path: ${file}`);
    return file;
  }))].sort();
}
export async function assertEnginesClosed() {
  // Unsaved state is not observable. Fail closed for any unmanaged or managed Godot process.
  const { stdout } = await execute('ps', ['-axo', 'pid=,comm='], { timeout: 5000, maxBuffer: 8 * 1024 * 1024 });
  const lines = stdout.split('\n').filter(line => {
    const parsed = line.match(/^\s*\d+\s+(.+?)\s*$/);
    return parsed && /^godot(?:[._-].*)?$/i.test(path.basename(parsed[1]));
  });
  if (lines.length) throw Error(`Godot process present; save and close before handoff/sync:\n${lines.join('\n')}`);
}
export async function acquire(ctx, files, kind) {
  const normalized = files.length ? resources(files) : [];
  for (const file of normalized.filter(f => f !== '*')) {
    let candidate = path.join(ctx.root, file);
    while (candidate !== ctx.root) {
      try { if (await realpath(candidate) !== candidate) throw Error(`Symlink or noncanonical resource: ${file}`); break; }
      catch(e) { if (e.code !== 'ENOENT') throw e; candidate = path.dirname(candidate); }
    }
  }
  return gate(ctx, async () => {
    if (normalized.length) await assertEnginesClosed();
    const active = await claims(ctx);
    for (const claim of active) {
      const overlap = normalized.length && claim.files.length && (normalized.includes('*') || claim.files.includes('*') || normalized.some(f => claim.files.includes(f)));
      if (claim.root === ctx.root || overlap) throw Error(`Workspace/resource occupied: ${JSON.stringify(claim)}`);
    }
    const record = { token: randomUUID(), pid: process.pid, root: ctx.root, kind, files: normalized, started_at: new Date().toISOString() };
    await writeFile(path.join(ctx.state, 'claims', `${record.token}.json`), JSON.stringify(record, null, 2), { flag: 'wx' });
    return record;
  });
}
export async function release(ctx, record) {
  return gate(ctx, async () => {
    const file = path.join(ctx.state, 'claims', `${record.token}.json`);
    const saved = JSON.parse(await readFile(file));
    if (saved.pid !== process.pid || saved.token !== record.token) throw Error('Claim ownership changed; retain it.');
    await rm(file);
  });
}
export async function withLease(root, files, kind, operation) {
  const ctx = await context(root), record = await acquire(ctx, files, kind);
  let retain = false;
  try { return await operation(ctx, record); }
  catch(e) { retain = !!e.retainClaim; throw e; }
  finally { if (!retain) await release(ctx, record); }
}
export async function runCommand(root, command, environment = process.env) {
  if (!command.length) throw Error('Explicit command required.');
  if (process.platform === 'win32') throw Error('Workspace launcher requires POSIX process groups.');
  return new Promise((resolve, reject) => {
    const child = spawn(command[0], command.slice(1), { cwd: root, env: environment, detached: true, stdio: 'inherit' });
    const alive = () => { if (!child.pid) return false; try { process.kill(-child.pid, 0); return true; } catch (e) { return e.code !== 'ESRCH'; } };
    const kill = (signal) => { if (child.pid) try { process.kill(-child.pid, signal); } catch (e) { if (e.code !== 'ESRCH') throw e; } };
    let cancelled, timer;
    const stop = signal => { cancelled = signal; kill(signal); timer ??= setTimeout(() => kill('SIGKILL'), 500); };
    const interrupt = () => stop('SIGINT'), terminate = () => stop('SIGTERM');
    process.on('SIGINT', interrupt); process.on('SIGTERM', terminate);
    const cleanup = () => { clearTimeout(timer); process.off('SIGINT', interrupt); process.off('SIGTERM', terminate); };
    let spawnError;
    child.on('error', e => { spawnError=e; if (child.pid) kill('SIGTERM'); });
    child.on('close', async code => {
      if (alive()) kill('SIGTERM');
      for (let i=0; alive() && i<30; i++) { if(i===10) kill('SIGKILL'); await new Promise(r=>setTimeout(r,50)); }
      cleanup();
      if (alive()) { const e=Error('Child processes still active; retain workspace claim.'); e.retainClaim=true; reject(e); }
      else if (spawnError) reject(spawnError);
      else resolve(cancelled === 'SIGINT' ? 130 : cancelled === 'SIGTERM' ? 143 : code ?? 1);
    });
  });
}
export async function snapshot(root) {
  // -z preserves whitespace; include untracked creative assets, exclude Git-ignored caches/reports.
  const { stdout } = await execute('git', ['ls-files', '-z', '--cached', '--others', '--exclude-standard'], { cwd: root, timeout: 15000, maxBuffer: 32 * 1024 * 1024, env: gitEnvironment() });
  const files = {};
  for (const file of [...new Set(stdout.split('\0').filter(Boolean))].sort()) {
    try {
      const resolved = await realpath(path.join(root, file));
      if (resolved !== path.join(root, file)) throw Error(`Symlink or noncanonical handoff path: ${file}`);
      files[file] = sha(await readFile(resolved));
    }
    catch(e) { if(e.code === 'ENOENT') files[file] = null; else throw e; }
  }
  return { root, branch: await git(root, 'branch', '--show-current'), head: await git(root, 'rev-parse', 'HEAD'),
    index_sha256: sha((await execute('git', ['ls-files', '--stage', '-z'], { cwd: root, timeout: 15000, env: gitEnvironment() })).stdout),
    status: (await execute('git', ['status', '--porcelain=v1', '-z', '--untracked-files=all'], { cwd: root, timeout: 15000, env: gitEnvironment() })).stdout, files_sha256: files };
}
export async function verifyHandoff(file, ownToken = null) {
  const saved = JSON.parse(await readFile(file));
  if (saved.schema_version !== 1 || saved.kind !== 'human-handoff' || saved.saved_and_closed !== true) throw Error('Invalid handoff.');
  const ctx = await context(saved.snapshot.root);
  const human = await registeredHuman(ctx);
  if (!human || human.root !== ctx.root || human.branch !== saved.snapshot.branch) throw Error('Handoff is not the registered human workspace.');
  await assertEnginesClosed();
  const active = await claims(ctx);
  if (active.some(c => c.token !== ownToken && (c.root === ctx.root || c.files.includes('*')))) throw Error('Workspace occupied; handoff verification blocked.');
  const frozen = path.join(path.dirname(file), 'files');
  if (saved.files_path !== frozen || await realpath(frozen) !== frozen) throw Error('Invalid frozen handoff path.');
  for (const [name, expected] of Object.entries(saved.snapshot.files_sha256)) {
    if (expected === null) continue;
    if (path.isAbsolute(name) || name.split('/').some(part=>!part || part==='..' || part==='.') || name.includes('\\')) throw Error('Invalid frozen file path.');
    const target = path.join(frozen, name);
    if (await realpath(target) !== target || sha(await readFile(target)) !== expected) throw Error(`Frozen handoff changed: ${name}`);
  }
  if (JSON.stringify(await snapshot(ctx.root)) !== JSON.stringify(saved.snapshot)) throw Error('Handoff changed; save/close and create a new handoff.');
  return saved;
}

export async function assertIntegrationOwner(ctx) {
  const owner = JSON.parse(await readFile(path.join(ctx.common, 'astra-integration.lock/owner.json')));
  let pid = process.pid;
  for (let attempt=0; pid>1 && attempt<100; attempt++) {
    if (pid === owner.pid) return owner;
    const { stdout } = await execute('ps', ['-p', String(pid), '-o', 'ppid='], { timeout: 5000 });
    pid = Number(stdout.trim());
  }
  throw Error('This command must run inside the integration lock owner process tree.');
}

export async function writeGitDiff(root, destination) {
  // Stream large binary assets; preserve exact patch bytes without execFile buffer limits.
  const child=spawn('git',['diff','--binary','HEAD'],{cwd:root,env:gitEnvironment(),detached:true,stdio:['ignore','pipe','pipe']});
  let stderr='',error,timedOut=false;
  child.stderr.on('data',b=>{stderr=(stderr+b).slice(-8000);});
  child.on('error',e=>{error=e;});
  const timer=setTimeout(()=>{timedOut=true;if(child.pid)try{process.kill(-child.pid,'SIGKILL')}catch{}},15000);
  const closed=new Promise(resolve=>child.on('close',resolve));
  try {
    await pipeline(child.stdout,createWriteStream(destination));
    const code=await closed;
    if(error||timedOut||code!==0)throw Error(`Handoff diff failed: ${error?.message||stderr||code}, timeout=${timedOut}`);
  } finally {clearTimeout(timer);}
}
