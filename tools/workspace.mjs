#!/usr/bin/env node
import { mkdir, readFile, realpath, writeFile, access } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { randomUUID } from 'node:crypto';
import { context, git, gitRaw, registeredHuman, claims, withLease, assertEnginesClosed, snapshot, verifyHandoff, runCommand, assertIntegrationOwner, sha, writeGitDiff } from './workspace-state.mjs';
import { withIntegrationLock } from './with-integration-lock.mjs';

const ownRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
export async function setupHuman(root, target, revision) {
  const ctx = await context(root);
  await assertIntegrationOwner(ctx);
  if ((await claims(ctx)).length) throw Error('Workspace claims active; defer setup.');
  if (!path.isAbsolute(target) || !/^[0-9a-f]{40}$/.test(revision ?? '')) throw Error('Human path must be absolute; base must be a full commit SHA.');
  const destination = path.join(await realpath(path.dirname(target)), path.basename(target));
  const roots = (await git(root, 'worktree', 'list', '--porcelain')).split('\n').filter(l => l.startsWith('worktree ')).map(l => l.slice(9));
  const registered = await registeredHuman(ctx);
  if (roots.filter(r => r !== registered?.root).some(r => destination === r || destination.startsWith(r + path.sep) || r.startsWith(destination + path.sep))) throw Error('Human workspace must be separate, never nested.');
  if (registered) {
    if (registered.root !== destination) throw Error('A fixed human workspace is already registered; do not create another.');
    if (await git(destination, 'branch', '--show-current') !== registered.branch) throw Error('Human branch changed.');
    return registered;
  }
  try { await access(destination); throw Error('Existing human path must not be overwritten.'); } catch(e) { if(e.code !== 'ENOENT') throw e; }
  const branch = 'codex/human-editing';
  // Exact commit verified before changing shared refs; never copy primary dirty files.
  if (await git(root, 'rev-parse', `${revision}^{commit}`) !== revision) throw Error('Base is not a commit.');
  await git(root, 'worktree', 'add', '--no-track', '-b', branch, destination, revision);
  const record = { schema_version: 1, root: destination, branch, base: revision, created_at: new Date().toISOString() };
  await writeFile(path.join(ctx.state, 'human.json'), JSON.stringify(record, null, 2) + '\n', { flag: 'wx' });
  return record;
}
export async function handoff(root, saved, closed) {
  if (!saved || !closed) throw Error('Explicit --saved --closed required; tools cannot inspect unsaved editor state.');
  const ctx = await context(root), human = await registeredHuman(ctx);
  if (!human || human.root !== ctx.root || await git(root, 'branch', '--show-current') !== human.branch) throw Error('Use the registered human workspace and fixed branch.');
  return withLease(root, ['*'], 'handoff', async () => {
    await assertEnginesClosed();
    const record = { schema_version: 1, kind: 'human-handoff', saved_and_closed: true, created_at: new Date().toISOString(), snapshot: await snapshot(ctx.root) };
    const directory = path.join(root, 'artifacts', 'handoffs', `${Date.now()}-${randomUUID().slice(0,8)}`);
    await mkdir(directory, { recursive: true });
    const file = path.join(directory, 'report.json');
    record.files_path = path.join(directory, 'files');
    for (const [name, hash] of Object.entries(record.snapshot.files_sha256)) {
      if (hash === null) continue;
      const bytes = await readFile(path.join(root, name));
      if (sha(bytes) !== hash) throw Error('Human workspace changed while freezing handoff.');
      const target = path.join(record.files_path, name);
      await mkdir(path.dirname(target), {recursive:true}); await writeFile(target, bytes);
    }
    await writeGitDiff(root, path.join(directory, 'tracked.diff'));
    if (JSON.stringify(await snapshot(root)) !== JSON.stringify(record.snapshot)) throw Error('Human workspace changed while freezing handoff.');
    await writeFile(file, JSON.stringify(record, null, 2) + '\n');
    return { report_path: file, snapshot: record.snapshot };
  });
}
export async function checkHandoff(root, report) {
  const ctx = await context(root);
  const preliminary = JSON.parse(await readFile(report));
  const source = await context(preliminary.snapshot.root);
  if (source.common !== ctx.common || source.root === ctx.root) throw Error('AI review must use another checkout in the same repository.');
  return withLease(source.root, ['*'], 'handoff-review', async (_, record) => withLease(ctx.root, [], 'review', async () => {
    const saved = await verifyHandoff(report, record.token);
    const reviewBefore = await snapshot(ctx.root);
    const base = await git(ctx.root, 'merge-base', 'HEAD', saved.snapshot.head);
    const sourceChanges = new Set((await gitRaw(source.root, 'diff', '--name-only', '--no-renames', '-z', base)).split('\0'));
    for (const file of (await gitRaw(source.root, 'ls-files', '-z', '--others', '--exclude-standard')).split('\0')) sourceChanges.add(file);
    const agentChanges = (await gitRaw(ctx.root, 'diff', '--name-only', '--no-renames', '-z', base)).split('\0').filter(Boolean);
    agentChanges.push(...(await gitRaw(ctx.root, 'ls-files', '-z', '--others', '--exclude-standard')).split('\0').filter(Boolean));
    const overlap = [...new Set(agentChanges.filter(f => sourceChanges.has(f)))];
    if (overlap.length) throw Error(`Handoff conflict requires review, no automatic overwrite: ${overlap.join(', ')}`);
    await verifyHandoff(report, record.token);
    if (JSON.stringify(await snapshot(ctx.root)) !== JSON.stringify(reviewBefore)) throw Error('Review workspace changed during handoff check.');
    return { status: 'pass', report_path: report, source_head: saved.snapshot.head, review_head: reviewBefore.head, source_changes: [...sourceChanges].filter(Boolean) };
  }));
}
export async function sync(root, revision, saved, closed) {
  if (!saved || !closed) throw Error('Explicit --saved --closed required.');
  if (!/^[0-9a-f]{40}$/.test(revision ?? '')) throw Error('Sync needs a full verified commit SHA.');
  const ctx = await context(root), human = await registeredHuman(ctx);
  await assertIntegrationOwner(ctx);
  const branch = await git(root, 'branch', '--show-current');
  const primary = path.dirname(ctx.common);
  if (!(ctx.root === primary && branch === 'main') && !(human?.root === ctx.root && branch === human.branch)) throw Error('Only primary main or fixed human workspace can use guarded sync.');
  return withLease(root, ['*'], 'sync', async () => {
    await assertEnginesClosed();
    if (await git(root, 'status', '--porcelain', '--untracked-files=all')) throw Error('Dirty checkout preserved; commit/review handoff before sync.');
    await git(root, 'merge', '--ff-only', revision);
    return { status: 'pass', root: ctx.root, head: await git(root, 'rev-parse', 'HEAD') };
  });
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const args = process.argv.slice(2), command = args.shift();
  let root = ownRoot;
  try {
    const separatorIndex=args.indexOf('--');
    const rootIndex = args.slice(0, separatorIndex<0?args.length:separatorIndex).indexOf('--root');
    if (rootIndex >= 0) { root = args[rootIndex+1]; args.splice(rootIndex,2); if(!path.isAbsolute(root ?? '')) throw Error('--root must be absolute.'); }
    root=(await context(root)).root;
    const value = key => { const i=args.indexOf(key); if(i<0) return undefined; const v=args[i+1]; args.splice(i,2); return v; };
    const flag = key => { const i=args.indexOf(key); if(i<0)return false; args.splice(i,1); return true; };
    let result;
    if (command === 'setup-human') {
      const target=value('--path'), revision=value('--base'); if(args.length)throw Error('Unknown arguments.');
      const ctx=await context(root);
      if((await claims(ctx)).length) throw Error('Workspace claims active; defer setup.');
      result = await withIntegrationLock(root,[process.execPath,fileURLToPath(import.meta.url),'_setup-human','--root',root,'--path',target,'--base',revision]);
      process.exitCode=result; result=undefined;
    } else if (command === '_setup-human') {
      // Internal operation only when this process belongs to the integration lock command group.
      const ctx=await context(root), owner=await assertIntegrationOwner(ctx);
      if(owner.command?.[2] !== '_setup-human' || owner.worktree !== root) throw Error('Setup requires integration lock.');
      const target=value('--path'), revision=value('--base'); if(args.length)throw Error('Unknown arguments.');
      result=await setupHuman(root,target,revision);
    } else if (command === 'handoff') {
      const saved=flag('--saved'),closed=flag('--closed'); if(args.length)throw Error('Unknown arguments.'); result=await handoff(root,saved,closed);
    } else if (command === 'check-handoff') {
      const report=value('--report'); if(args.length)throw Error('Unknown arguments.'); result=await checkHandoff(root,report);
    } else if(command === 'sync') {
      const revision=value('--revision'),saved=flag('--saved'),closed=flag('--closed'); if(args.length)throw Error('Unknown arguments.');
      // Required: caller holds common integration lock around verification, merge and this sync.
      const ctx=await context(root); await assertIntegrationOwner(ctx);
      result=await sync(root,revision,saved,closed);
    } else if(command === 'edit') {
      if(args[0] !== '--files')throw Error('Usage: edit --files <a.tscn> ... -- <command> [args]');
      const separator=args.indexOf('--'); if(separator<2)throw Error('Explicit files and command required.');
      const files=args.slice(1,separator), argv=args.slice(separator+1);
      const ctx=await context(root),human=await registeredHuman(ctx);
      if(ctx.root===path.dirname(ctx.common)||human?.root===ctx.root)throw Error('Agent edits require an isolated agent checkout.');
      result=await withLease(root,files,'resource-write',()=>runCommand(root,argv)); process.exitCode=result;result=undefined;
    } else if(command === 'status') {
      if(args.length)throw Error('Unknown arguments.'); const ctx=await context(root); result={root:ctx.root,human:await registeredHuman(ctx),claims:await claims(ctx)};
    } else throw Error('Usage: workspace.mjs setup-human|handoff|check-handoff|sync|edit|status [options]');
    if(result!==undefined)console.log(JSON.stringify(result,null,2));
  } catch(e) { console.error(e.message); process.exitCode=1; }
}
