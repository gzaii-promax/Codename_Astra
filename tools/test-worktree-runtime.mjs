import assert from 'node:assert/strict';
import { execFile, spawn } from 'node:child_process';
import { chmod, cp, mkdir, mkdtemp, readFile, realpath, rm, writeFile } from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { promisify } from 'node:util';
import test from 'node:test';
import { withIntegrationLock } from './with-integration-lock.mjs';

const execute = promisify(execFile);
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
async function repository(t) {
  const base = await realpath(await mkdtemp(path.join(os.tmpdir(), 'astra runtime ')));
  t.after(() => rm(base, { recursive: true, force: true }));
  const primary = path.join(base, 'primary'), linked = path.join(base, 'linked checkout');
  await mkdir(primary);
  await execute('git', ['init', '-b', 'main'], { cwd: primary });
  await execute('git', ['-c', 'user.name=Test', '-c', 'user.email=test@invalid', 'commit', '--allow-empty', '-m', 'fixture'], { cwd: primary });
  await execute('git', ['worktree', 'add', '-b', 'codex/test', linked, 'main'], { cwd: primary });
  return { base, primary, linked, lock: path.join(primary, '.git', 'astra-integration.lock') };
}

test('integration command uses its checkout and propagates success/failure; locks release', async (t) => {
  const { linked, lock } = await repository(t);
  const file = path.join(linked, 'result with spaces.json');
  assert.equal(await withIntegrationLock(linked, [process.execPath, '-e', 'require("fs").writeFileSync(process.argv[1], JSON.stringify({cwd:process.cwd()}))', file]), 0);
  assert.equal(JSON.parse(await readFile(file)).cwd, linked);
  assert.equal(await withIntegrationLock(linked, [process.execPath, '-e', 'process.exit(17)']), 17);
  await assert.rejects(readFile(path.join(lock, 'owner.json')), { code: 'ENOENT' });
});

test('two linked checkouts share one mutex; competing command never starts or alters owner', async (t) => {
  const { primary, linked, lock } = await repository(t);
  const ready = path.join(linked, 'ready'), forbidden = path.join(primary, 'should-not-run');
  const first = withIntegrationLock(linked, [process.execPath, '-e', 'require("fs").writeFileSync(process.argv[1], "ready"); setTimeout(()=>{}, 800)', ready]);
  for (let i = 0; i < 100; i++) {
    try { await readFile(ready); break; } catch { await new Promise((r) => setTimeout(r, 10)); }
  }
  assert.equal(await readFile(ready, 'utf8'), 'ready');
  const owner = await readFile(path.join(lock, 'owner.json'), 'utf8');
  await assert.rejects(withIntegrationLock(primary, [process.execPath, '-e', 'require("fs").writeFileSync(process.argv[1], "bad")', forbidden]), (e) => e.exitCode === 73);
  assert.equal(await readFile(path.join(lock, 'owner.json'), 'utf8'), owner);
  await assert.rejects(readFile(forbidden), { code: 'ENOENT' });
  assert.equal(await first, 0);
  assert.equal(await withIntegrationLock(primary, [process.execPath, '-e', 'process.exit(0)']), 0);
});

test('spawn failure releases owned lock but an incomplete foreign lock stays intact', async (t) => {
  const { primary, lock } = await repository(t);
  await assert.rejects(withIntegrationLock(primary, ['/unavailable-astra-command']), { code: 'ENOENT' });
  await mkdir(lock);
  await assert.rejects(withIntegrationLock(primary, [process.execPath, '-e', 'process.exit(0)']), (e) => e.exitCode === 73 && /Owner record unavailable/.test(e.message));
  assert.deepEqual(await readFile(path.join(primary, '.git', 'HEAD'), 'utf8'), 'ref: refs/heads/main\n');
  await assert.rejects(readFile(path.join(lock, 'owner.json')), { code: 'ENOENT' });
  await rm(lock, { recursive: true });
});

test('lock CLI rejects missing explicit command', async () => {
  await assert.rejects(execute(process.execPath, [path.join(root, 'tools/with-integration-lock.mjs')]), (e) => e.code === 2 && /Usage/.test(e.stderr));
});

async function launcher(t) {
  const repo = await repository(t);
  for (const checkout of [repo.primary, repo.linked]) {
    await mkdir(path.join(checkout, 'tools'));
    for (const file of ['play.mjs', 'toolchain-config.mjs']) await cp(path.join(root, 'tools', file), path.join(checkout, 'tools', file));
    const engine = path.join(checkout, 'fake-godot');
    await writeFile(engine, `#!/bin/sh\nexec '${process.execPath}' '${path.join(checkout, 'fake-engine.mjs')}' "$@"\n`);
    await chmod(engine, 0o755);
    await writeFile(path.join(checkout, 'fake-engine.mjs'), 'console.log(JSON.stringify({args:process.argv.slice(2),cwd:process.cwd(),settings:process.env.ASTRA_SETTINGS_PATH??null}));\n');
    const manifest = JSON.parse(await readFile(path.join(root, 'tools/toolchain.json')));
    manifest.tools.godot.path = engine;
    await writeFile(path.join(checkout, 'tools/toolchain.json'), JSON.stringify(manifest));
  }
  return repo;
}
const cleanEnvironment = () => {
  const environment = { ...process.env };
  delete environment.ASTRA_SETTINGS_PATH; delete environment.ASTRA_TOOLCHAIN_CONFIG;
  return environment;
};

test('worktree play and editor inherit isolated settings/logs even from another cwd', async (t) => {
  const { primary, linked } = await launcher(t);
  const outputs = [];
  for (const args of [[], ['--editor']]) {
    const { stdout } = await execute(process.execPath, [path.join(linked, 'tools/play.mjs'), ...args], { cwd: primary, env: cleanEnvironment() });
    outputs.push(JSON.parse(stdout));
  }
  for (const [i, result] of outputs.entries()) {
    assert.equal(result.cwd, linked);
    assert.equal(result.settings, path.join(linked, '.tools/play/settings.cfg'));
    assert.equal(result.args.includes('--editor'), i === 1);
    assert.equal(result.args[1], linked);
    assert.ok(result.args[3].startsWith(path.join(linked, 'artifacts/play/')));
  }
  assert.equal(outputs[0].settings, outputs[1].settings);
  assert.notEqual(outputs[0].args[3], outputs[1].args[3]);
});

test('primary keeps user settings; explicit settings override is preserved', async (t) => {
  const { primary, linked } = await launcher(t);
  const main = JSON.parse((await execute(process.execPath, [path.join(primary, 'tools/play.mjs')], { env: cleanEnvironment() })).stdout);
  assert.equal(main.settings, null);
  const custom = path.join(linked, 'custom.cfg');
  const output = JSON.parse((await execute(process.execPath, [path.join(linked, 'tools/play.mjs')], { env: { ...cleanEnvironment(), ASTRA_SETTINGS_PATH: custom } })).stdout);
  assert.equal(output.settings, custom);
});

test('launcher refuses unknown arguments and broken explicit config', async (t) => {
  const { linked } = await launcher(t);
  const script = path.join(linked, 'tools/play.mjs');
  await assert.rejects(execute(process.execPath, [script, '--unknown']), (e) => e.code === 2 && /Usage/.test(e.stderr));
  await assert.rejects(execute(process.execPath, [script], { env: { ...cleanEnvironment(), ASTRA_TOOLCHAIN_CONFIG: 'absent.json' } }), (e) => e.code === 1 && /Toolchain configuration/.test(e.stderr));
});

for (const signal of ['SIGINT', 'SIGTERM']) {
  test(`cancellation ${signal} reaches grandchild and holds lock through its shutdown`, async (t) => {
    const { primary, linked, lock } = await repository(t);
    await mkdir(path.join(linked, 'tools'));
    await cp(path.join(root, 'tools/with-integration-lock.mjs'), path.join(linked, 'tools/with-integration-lock.mjs'));
    const ready = path.join(linked, 'grandchild-ready'), stopping = path.join(linked, 'grandchild-stopping');
    const script = path.join(linked, 'grandchild.mjs');
    await writeFile(script, `import {writeFileSync} from 'node:fs';
writeFileSync(${JSON.stringify(ready)}, String(process.pid));
const stop=()=>{writeFileSync(${JSON.stringify(stopping)}, 'stopping'); setTimeout(()=>process.exit(0),150);};
process.on('SIGINT',stop);process.on('SIGTERM',stop);setInterval(()=>{},1000);
`);
    const parent = `const {spawn}=require('child_process');
const child=spawn(process.execPath,[process.argv[1]],{stdio:'inherit'});
process.on('SIGINT',()=>{});process.on('SIGTERM',()=>{});
child.on('exit',()=>process.exit(0));`;
    const wrapper = spawn(process.execPath, [path.join(linked, 'tools/with-integration-lock.mjs'), '--', process.execPath, '-e', parent, script], { stdio: ['ignore', 'pipe', 'pipe'] });
    let stderr = ''; wrapper.stderr.on('data', (data) => { stderr += data; });
    const finished = new Promise((resolve) => wrapper.on('close', (code) => resolve(code)));
    t.after(() => { try { wrapper.kill('SIGKILL'); } catch {} });
    const waitFor = async (file) => {
      for (let i=0;i<200;i++) { try { return await readFile(file,'utf8'); } catch { await new Promise((resolve)=>setTimeout(resolve,10)); } }
      throw new Error(`Timed out waiting for ${file}; ${stderr}`);
    };
    const grandchildPid = Number(await waitFor(ready));
    wrapper.kill(signal);
    await waitFor(stopping);
    await assert.rejects(withIntegrationLock(primary,[process.execPath,'-e','process.exit(0)']), (e)=>e.exitCode===73);
    assert.equal(await finished,signal==='SIGINT'?130:143,stderr);
    assert.throws(()=>process.kill(grandchildPid,0),(e)=>e.code==='ESRCH');
    await assert.rejects(readFile(path.join(lock,'owner.json')),{code:'ENOENT'});
    assert.equal(await withIntegrationLock(primary,[process.execPath,'-e','process.exit(0)']),0);
  });
}
