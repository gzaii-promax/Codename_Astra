import assert from 'node:assert/strict';
import { execFile, spawn } from 'node:child_process';
import { chmod, copyFile, mkdir, mkdtemp, readFile, realpath, rm, symlink, writeFile } from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { promisify } from 'node:util';
import test from 'node:test';
import { context, acquire, release, claims, git, runCommand, withLease, assertEnginesClosed, snapshot, verifyHandoff } from './workspace-state.mjs';
import { setupHuman, handoff, checkHandoff, sync } from './workspace.mjs';
import { withIntegrationLock } from './with-integration-lock.mjs';
const execute=promisify(execFile), tools=path.dirname(fileURLToPath(import.meta.url));
async function fixture(t) {
  const base=await realpath(await mkdtemp(path.join(os.tmpdir(),'astra human ')));
  t.after(()=>rm(base,{recursive:true,force:true}));
  // Fixture process inventory is isolated from the user's live editor. Ancestry uses real ps.
  const inventory=path.join(base,'inventory'); await mkdir(inventory);
  await writeFile(path.join(inventory,'ps'),'#!/bin/sh\nif [ "$1" = "-axo" ]; then exit 0; fi\nexec /bin/ps "$@"\n');
  await chmod(path.join(inventory,'ps'),0o755);
  const oldPath=process.env.PATH; process.env.PATH=inventory+path.delimiter+oldPath;
  t.after(()=>{process.env.PATH=oldPath;});
  const primary=path.join(base,'main'),ai=path.join(base,'ai'),human=path.join(base,'human editing');
  await mkdir(primary); await execute('git',['init','-b','main'],{cwd:primary});
  await git(primary,'config','user.name','Fixture'); await git(primary,'config','user.email','test@invalid');
  await mkdir(path.join(primary,'world')); await mkdir(path.join(primary,'tools'));
  for(const file of ['workspace-state.mjs','workspace.mjs','with-integration-lock.mjs']) await copyFile(path.join(tools,file),path.join(primary,'tools',file));
  await writeFile(path.join(primary,'.gitignore'),'artifacts/\n.tools/\n');
  await writeFile(path.join(primary,'world/room.tscn'),'original'); await writeFile(path.join(primary,'project.godot'),'config');
  await git(primary,'add','.'); await git(primary,'commit','-m','fixture');
  const head=await git(primary,'rev-parse','HEAD'); await git(primary,'worktree','add','-b','codex/ai',ai,head);
  await git(primary,'worktree','add','-b','codex/human-editing',human,head);
  const ctx=await context(primary);
  await writeFile(path.join(ctx.state,'human.json'),JSON.stringify({schema_version:1,root:human,branch:'codex/human-editing',base:head}));
  return {base,primary,ai,human,head,ctx};
}
test('scene claims conflict across worktrees; code-only play remains independent',async t=>{
  const f=await fixture(t), human=await acquire(await context(f.human),['*'],'editor');
  await assert.rejects(acquire(await context(f.ai),['world/room.tscn'],'resource-write'),/occupied/);
  const play=await acquire(await context(f.ai),[],'play'); await release(await context(f.ai),play);
  await release(await context(f.human),human);
  const write=await acquire(await context(f.ai),['world/room.tscn'],'resource-write'); await release(await context(f.ai),write);
});
test('atomic two contenders permit exactly one writer',async t=>{
  const f=await fixture(t), a=await context(f.ai),b=await context(f.human);
  const results=await Promise.allSettled([acquire(a,['world/room.tscn'],'resource-write'),acquire(b,['world/room.tscn'],'resource-write')]);
  assert.equal(results.filter(r=>r.status==='fulfilled').length,1);
  const i=results.findIndex(r=>r.status==='fulfilled'); await release(i===0?a:b,results[i].value);
});
test('unknown incomplete and stale claims never expire or get removed',async t=>{
  const f=await fixture(t),file=path.join(f.ctx.state,'claims/unknown.json');
  await writeFile(file,'{'); await assert.rejects(acquire(await context(f.ai),[],'play')); assert.equal(await readFile(file,'utf8'),'{');
  await writeFile(file,JSON.stringify({token:'unknown',pid:99999999,root:f.human,files:['*'],kind:'editor'}));
  await assert.rejects(acquire(await context(f.ai),['world/room.tscn'],'resource-write'),/occupied/); assert.ok(await readFile(file));
});
test('resource paths reject traversal, absolute and symlink escapes',async t=>{
  const f=await fixture(t),ctx=await context(f.ai); await symlink(f.human,path.join(f.ai,'escape'));
  for(const file of ['../room.tscn','/world/room.tscn','world//room.tscn','escape/world/room.tscn']) await assert.rejects(acquire(ctx,[file],'resource-write'),/Invalid|canonical/);
});
test('spawn failure and failed command release claims; retained child state remains occupied',async t=>{
  const f=await fixture(t); await assert.rejects(withLease(f.ai,['world/room.tscn'],'resource-write',()=>{throw Error('spawn failed');}));
  assert.equal((await claims(f.ctx)).length,0);
  await assert.rejects(withLease(f.ai,['world/room.tscn'],'resource-write',()=>{const e=Error('child alive');e.retainClaim=true;throw e;}));
  assert.equal((await claims(f.ctx)).length,1);
});
test('handoff requires explicit saved/closed and fixed human identity, preserving dirty data',async t=>{
  const f=await fixture(t); await writeFile(path.join(f.human,'world/room.tscn'),'human unsaved to git');
  const before=await snapshot(f.human);
  await assert.rejects(handoff(f.human,true,false),/saved.*closed/);await assert.rejects(handoff(f.human,false,true),/saved.*closed/);
  await assert.rejects(handoff(f.ai,true,true),/registered/);
  const result=await handoff(f.human,true,true); const saved=await verifyHandoff(result.report_path);
  assert.deepEqual(saved.snapshot,before);assert.equal(saved.kind,'human-handoff');
  assert.equal(await readFile(path.join(f.primary,'world/room.tscn'),'utf8'),'original');
});
test('handoff detects staged, unstaged, untracked, delete, rename, index and HEAD drift',async t=>{
  const f=await fixture(t);
  await git(f.human,'mv','world/room.tscn','world/renamed.tscn');
  await writeFile(path.join(f.human,'world/renamed.tscn'),'modified');await writeFile(path.join(f.human,'new.tres'),'new');
  const result=await handoff(f.human,true,true),record=await verifyHandoff(result.report_path);
  assert.equal(record.snapshot.files_sha256['world/room.tscn'],undefined);
  assert.ok(record.snapshot.files_sha256['new.tres']);
  await git(f.human,'add','world/renamed.tscn'); await assert.rejects(verifyHandoff(result.report_path),/changed/);
  const result2=await handoff(f.human,true,true);await writeFile(path.join(f.human,'new.tres'),'later');await assert.rejects(verifyHandoff(result2.report_path),/changed/);
});
test('symlink creative handoff is rejected rather than hashing outside checkout',async t=>{
  const f=await fixture(t);await symlink(path.join(f.primary,'project.godot'),path.join(f.human,'new.tres'));
  await assert.rejects(handoff(f.human,true,true),/canonical/);
});
test('review catches same-file conflicts including human committed changes and preserves both',async t=>{
  const f=await fixture(t);await writeFile(path.join(f.human,'world/room.tscn'),'human');await git(f.human,'add','.');await git(f.human,'commit','-m','human saved');
  await writeFile(path.join(f.ai,'world/room.tscn'),'ai');const hand=await handoff(f.human,true,true);
  await assert.rejects(checkHandoff(f.ai,hand.report_path),/conflict/);
  assert.equal(await readFile(path.join(f.human,'world/room.tscn'),'utf8'),'human');assert.equal(await readFile(path.join(f.ai,'world/room.tscn'),'utf8'),'ai');
});
test('nonoverlapping handoff review succeeds and recorded hashes can be read independently',async t=>{
  const f=await fixture(t);await writeFile(path.join(f.human,'world/room.tscn'),'human');await writeFile(path.join(f.ai,'code.gd'),'AI');
  const hand=await handoff(f.human,true,true);assert.equal((await checkHandoff(f.ai,hand.report_path)).status,'pass');
  const raw=JSON.parse(await readFile(hand.report_path));assert.ok(raw.snapshot.files_sha256['world/room.tscn']);assert.ok(raw.snapshot.index_sha256);
  await writeFile(path.join(raw.files_path,'world/room.tscn'),'artifact tampered');
  await assert.rejects(verifyHandoff(hand.report_path),/Frozen handoff changed/);
});
test('process scan failure and unknown Godot process fail closed',async t=>{
  const f=await fixture(t),bin=path.join(f.base,'bin');await mkdir(bin);const ps=path.join(bin,'ps');
  const original=process.env.PATH;t.after(()=>{process.env.PATH=original;});process.env.PATH=bin+path.delimiter+original;
  await writeFile(ps,'#!/bin/sh\nexit 7\n');await chmod(ps,0o755);await assert.rejects(assertEnginesClosed());
  await writeFile(ps,'#!/bin/sh\nprintf "  999 /Applications/Godot.app/Contents/MacOS/Godot\\n"\n');
  await assert.rejects(assertEnginesClosed(),/Godot process/);await assert.rejects(acquire(await context(f.ai),['world/room.tscn'],'resource-write'),/Godot process/);
});
test('sync rejects dirty main staged/unstaged/untracked without changing hashes or branch',async t=>{
  const f=await fixture(t);await writeFile(path.join(f.primary,'project.godot'),'human config');await git(f.primary,'add','project.godot');
  await writeFile(path.join(f.primary,'world/room.tscn'),'disk edit');await writeFile(path.join(f.primary,'new.tres'),'new');
  const before=await snapshot(f.primary);
  const argv=[process.execPath,path.join(f.ai,'tools/workspace.mjs'),'sync','--root',f.primary,'--revision',f.head,'--saved','--closed'];
  assert.equal(await withIntegrationLock(f.ai,argv),1);assert.deepEqual(await snapshot(f.primary),before);
});
test('unrelated caller cannot borrow another integration lock',async t=>{
  const f=await fixture(t);await mkdir(path.join(f.ctx.common,'astra-integration.lock'));await writeFile(path.join(f.ctx.common,'astra-integration.lock/owner.json'),JSON.stringify({pid:99999999}));
  await assert.rejects(sync(f.primary,f.head,true,true),/process tree/);await assert.rejects(setupHuman(f.ai,path.join(f.base,'new human'),f.head),/process tree/);
});
test('guarded clean FF sync succeeds; divergent human branch refuses without reset',async t=>{
  const f=await fixture(t);await writeFile(path.join(f.ai,'code.gd'),'AI');await git(f.ai,'add','.');await git(f.ai,'commit','-m','change');const head=await git(f.ai,'rev-parse','HEAD');
  const argv=[process.execPath,path.join(f.ai,'tools/workspace.mjs'),'sync','--root',f.primary,'--revision',head,'--saved','--closed'];
  assert.equal(await withIntegrationLock(f.ai,argv),0);assert.equal(await git(f.primary,'rev-parse','HEAD'),head);
  await writeFile(path.join(f.human,'human.gd'),'human');await git(f.human,'add','.');await git(f.human,'commit','-m','human');const before=await snapshot(f.human);
  argv[4]=f.human;assert.equal(await withIntegrationLock(f.ai,argv),1);assert.deepEqual(await snapshot(f.human),before);
});
test('setup creates one fixed nonnested human checkout at explicit base, preserves dirty main, and is idempotent',async t=>{
  const f=await fixture(t);await rm(path.join(f.ctx.state,'human.json'));await git(f.primary,'worktree','remove',f.human);await git(f.primary,'branch','-d','codex/human-editing');
  await writeFile(path.join(f.primary,'project.godot'),'user dirty');const before=await snapshot(f.primary);
  const argv=[process.execPath,path.join(f.ai,'tools/workspace.mjs'),'setup-human','--path',f.human,'--base',f.head];
  await execute(argv[0],argv.slice(1),{cwd:f.ai,timeout:15000});await execute(argv[0],argv.slice(1),{cwd:f.ai,timeout:15000});
  assert.equal(await git(f.human,'rev-parse','HEAD'),f.head);assert.deepEqual(await snapshot(f.primary),before);
});

test('real spawn failure and failing child propagate finite errors and release owned claim',async t=>{
  const f=await fixture(t);
  await assert.rejects(withLease(f.ai,['world/room.tscn'],'resource-write',()=>runCommand(f.ai,['/unavailable-astra-command'])),/ENOENT/);
  assert.equal((await claims(f.ctx)).length,0);
  assert.equal(await withLease(f.ai,['world/room.tscn'],'resource-write',()=>runCommand(f.ai,[process.execPath,'-e','process.exit(17)'])),17);
  assert.equal((await claims(f.ctx)).length,0);
});
test('edit wrapper preserves child --root arguments and canonical primary root is refused',async t=>{
  const f=await fixture(t),cli=path.join(f.ai,'tools/workspace.mjs');
  const result=await execute(process.execPath,[cli,'edit','--files','world/room.tscn','--',process.execPath,'-e','console.log(JSON.stringify(process.argv.slice(1)))','--','--root','/child-value'],{cwd:f.ai,timeout:15000});
  assert.deepEqual(JSON.parse(result.stdout),['--root','/child-value']);
  await assert.rejects(execute(process.execPath,[cli,'edit','--root',f.primary+'/.','--files','world/room.tscn','--',process.execPath,'-e','process.exit(0)'],{cwd:f.ai,timeout:15000}),/isolated/);
});
test('handoff patch retains bytes and conflict detection supports whitespace filenames',async t=>{
  const f=await fixture(t),name='world/new\n room.tscn';
  await writeFile(path.join(f.human,name),'human');await writeFile(path.join(f.ai,name),'ai');
  await writeFile(path.join(f.human,'world/room.tscn'),'original\nlast line  ');
  const result=await handoff(f.human,true,true);
  const raw=(await execute('git',['diff','--binary','HEAD'],{cwd:f.human})).stdout;
  assert.equal(await readFile(path.join(path.dirname(result.report_path),'tracked.diff'),'utf8'),raw);
  await assert.rejects(checkHandoff(f.ai,result.report_path),/conflict/);
});

test('cancelled writer holds claim through grandchild shutdown then releases',async t=>{
  const f=await fixture(t),ready=path.join(f.ai,'ready'),stopping=path.join(f.ai,'stopping');
  const script=path.join(f.ai,'child.mjs');
  await writeFile(script,`import {writeFileSync} from 'node:fs'; writeFileSync(${JSON.stringify(ready)},String(process.pid)); process.on('SIGTERM',()=>{writeFileSync(${JSON.stringify(stopping)},'stopping');setTimeout(()=>process.exit(0),150)});setInterval(()=>{},1000);`);
  const wrapper=spawn(process.execPath,[path.join(f.ai,'tools/workspace.mjs'),'edit','--files','world/room.tscn','--',process.execPath,script],{cwd:f.ai,stdio:['ignore','pipe','pipe']});
  let error='';wrapper.stderr.on('data',b=>error+=b);const finish=new Promise(r=>wrapper.on('close',r));
  t.after(()=>{if(wrapper.exitCode===null)wrapper.kill('SIGKILL');});
  const wait=async file=>{for(let i=0;i<100;i++){try{return await readFile(file,'utf8')}catch{await new Promise(r=>setTimeout(r,10))}}throw Error(error||'deadline');};
  const pid=Number(await wait(ready));wrapper.kill('SIGTERM');await wait(stopping);
  await assert.rejects(acquire(await context(f.human),['world/room.tscn'],'resource-write'),/occupied/);
  assert.equal(await finish,143,error);assert.equal((await claims(f.ctx)).length,0);assert.throws(()=>process.kill(pid,0));
});
