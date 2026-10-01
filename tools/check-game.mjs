#!/usr/bin/env node
import { spawn } from 'node:child_process';
import { createHash, randomUUID } from 'node:crypto';
import { cp, mkdir, readdir, readFile, rename, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const sourceDirs = ['shared', 'combat', 'skills', 'player', 'world', 'assets', 'ui', 'tests'];
const hash = (data) => createHash('sha256').update(data).digest('hex');
const relative = (value) => path.relative(root, value).split(path.sep).join('/');
const clean = (result) => result.exit_code === 0 && !result.timed_out && !result.spawn_error;
const noEngineErrors = (result) => !/(?:SCRIPT ERROR:|Parse Error:|^ERROR:)/m.test(result.stdout + result.stderr);

async function filesUnder(directory) {
  let entries;
  try { entries = await readdir(directory, { withFileTypes: true }); }
  catch (error) { if (error.code === 'ENOENT') return []; throw error; }
  const files = [];
  for (const entry of entries) {
    const item = path.join(directory, entry.name);
    if (entry.isDirectory()) files.push(...await filesUnder(item));
    else if (entry.isFile()) files.push(item);
  }
  return files.sort();
}

// Uses argv without a shell and kills the process group on timeout.
async function execute(command, logPath, timeoutMs = 15000) {
  let stdout = '', stderr = '', timedOut = false, spawnError = null, terminationError = null;
  const started = Date.now();
  let pid;
  const result = await new Promise((resolve) => {
    const child = spawn(command[0], command.slice(1), {
      cwd: root, env: process.env, detached: process.platform !== 'win32', stdio: ['ignore', 'pipe', 'pipe'],
    });
    pid = child.pid;
    child.stdout.on('data', (data) => { stdout += data; });
    child.stderr.on('data', (data) => { stderr += data; });
    child.on('error', (error) => { spawnError = String(error); });
    const kill = (signal) => {
      try { if (pid) process.platform === 'win32' ? child.kill(signal) : process.kill(-pid, signal); }
      catch (error) { if (error.code !== 'ESRCH') terminationError = String(error); }
    };
    let hardKill;
    const deadline = setTimeout(() => {
      timedOut = true;
      kill('SIGTERM');
      hardKill = setTimeout(() => kill('SIGKILL'), 500);
    }, timeoutMs);
    child.once('close', (exitCode, signal) => {
      clearTimeout(deadline); clearTimeout(hardKill); resolve({ exit_code: exitCode, signal });
    });
  });
  let terminated = true;
  try { if (pid) { process.kill(process.platform === 'win32' ? pid : -pid, 0); terminated = false; } }
  catch (error) { if (error.code !== 'ESRCH') terminated = false; }
  const actual = { ...result, stdout, stderr, timed_out: timedOut, spawn_error: spawnError,
    termination_error: terminationError, terminated, duration_ms: Date.now() - started,
    observed_status: spawnError ? 'blocked' : timedOut ? 'timeout' : result.exit_code === 0 ? 'pass' : 'fail' };
  await writeFile(logPath, `command(argv): ${JSON.stringify(command)}\ncwd: ${root}\ntimeout_ms: ${timeoutMs}\n--- stdout ---\n${stdout}\n--- stderr ---\n${stderr}\n--- process result ---\n${JSON.stringify({ ...actual, stdout: undefined, stderr: undefined })}\n`);
  return actual;
}

export async function runGameChecks() {
  const started = new Date();
  const runId = `${started.toISOString().replace(/[-:.]/g, '')}-${randomUUID().slice(0, 8)}`;
  const runDir = path.join(root, 'artifacts/test-runs', runId);
  const logs = path.join(runDir, 'logs'), snapshot = path.join(runDir, 'game-project');
  const invocation = [process.execPath, path.join(root, 'tools/check.mjs'), '--scope', 'game'];
  const report = { schema_version: 1, run_id: runId, scope: 'game', status: 'blocked', cwd: root,
    channel: 'automated_test', time: { started_at: started.toISOString() }, tool_versions: {},
    code_state: { git: 'unavailable', commit: null, files_sha256: {} },
    snapshot_path: relative(snapshot), expected_check_ids: [], checks: [] };
  await mkdir(logs, { recursive: true });
  const passed = (id) => report.checks.some((item) => item.id === id && item.status === 'pass');
  async function check(id, purpose, expected, command, judge, dependencies = [], timeoutMs = 15000) {
    report.expected_check_ids.push(id);
    const logPath = path.join(logs, `${id}.log`);
    const item = { id, purpose, expected, command: command ?? invocation, cwd: root, timeout_ms: timeoutMs,
      log_path: relative(logPath), actual: {}, exit_code: null, status: 'blocked', error_id: null };
    const unmet = dependencies.filter((dependency) => !passed(dependency));
    try {
      if (unmet.length) item.actual = { observed_status: 'blocked', unmet_dependencies: unmet };
      else if (command) {
        const result = await execute(command, logPath, timeoutMs);
        item.exit_code = result.exit_code;
        item.status = await judge(result) ? 'pass' : result.observed_status === 'pass' ? 'fail' : result.observed_status;
        item.actual = { ...result, stdout_tail: result.stdout.slice(-4000), stderr_tail: result.stderr.slice(-4000) };
        delete item.actual.stdout; delete item.actual.stderr;
      } else { item.execution_kind = 'internal'; item.actual = await judge(); item.status = 'pass'; }
    } catch (error) { item.actual = { observed_status: 'blocked', error: String(error), stack: error.stack }; }
    if (!command || unmet.length) await writeFile(logPath, JSON.stringify(item.actual, null, 2) + '\n');
    if (item.status !== 'pass') item.error_id = `ERR-GAME-${id.toUpperCase()}`;
    report.checks.push(item);
    return item;
  }
  let manifest, expectedTests = [], sourceFiles = [];
  await check('manifest', 'Read pinned tools and explicit nonempty game test contract.', { nonempty_test_manifest: true }, null, async () => {
    manifest = JSON.parse(await readFile(path.join(root, 'tools/toolchain.json'), 'utf8'));
    const contract = JSON.parse(await readFile(path.join(root, 'tests/manifest.json'), 'utf8'));
    expectedTests = contract.test_names;
    if (!Array.isArray(expectedTests) || !expectedTests.length || new Set(expectedTests).size !== expectedTests.length) throw Error('Game test names must be nonempty and unique.');
    for (const name of ['godot', 'gut', 'python', 'gdlint', 'gdformat', 'git']) if (!manifest.tools?.[name]?.version) throw Error(`Missing pinned tool: ${name}`);
    return { observed_status: 'pass', expected_tests: expectedTests };
  });
  const tool = (name) => path.resolve(root, manifest?.tools?.[name]?.path ?? manifest?.tools?.[name]?.addons_path ?? '__missing_tool__');
  for (const name of ['godot', 'python', 'gdlint', 'gdformat']) {
    await check(`version-${name}`, `Verify pinned ${name}.`, { version: manifest?.tools?.[name]?.version }, [tool(name), '--version'], (result) => {
      const output = (result.stdout + result.stderr).trim();
      const version = name === 'godot' ? output.split(/\s/)[0] : output.match(/\d+\.\d+\.\d+/)?.[0];
      report.tool_versions[name] = { path: tool(name), expected_version: manifest.tools[name].version, actual_version: version };
      return clean(result) && version === manifest.tools[name].version;
    }, ['manifest']);
  }
  await check('sources', 'Snapshot actual project, test contract and pinned GUT; retain hashes and Git state.', { project: 'project.godot', fixture: false }, null, async () => {
    await mkdir(snapshot, { recursive: true });
    const project = await readFile(path.join(root, 'project.godot'));
    await writeFile(path.join(snapshot, 'project.godot'), project);
    sourceFiles = [path.join(root, 'project.godot')];
    for (const directory of sourceDirs) {
      const files = await filesUnder(path.join(root, directory));
      if (files.length) { await cp(path.join(root, directory), path.join(snapshot, directory), { recursive: true }); sourceFiles.push(...files); }
    }
    if (!sourceFiles.some((file) => file.endsWith('training_arena.tscn'))) throw Error('Main training arena is missing.');
    const tests = sourceFiles.filter((file) => /\/tests\/.*\.gd$/.test(file));
    const discovered = [];
    for (const file of tests) { const data = await readFile(file, 'utf8'); discovered.push(...[...data.matchAll(/^func (test_[\w]+)\(/gm)].map((match) => match[1])); }
    if (discovered.length !== expectedTests.length || expectedTests.some((name) => !discovered.includes(name))) throw Error('Discovered game tests differ from explicit manifest.');
    const plugin = await readFile(path.join(tool('gut'), 'plugin.cfg'), 'utf8');
    const version = plugin.match(/^version="([^"]+)"/m)?.[1];
    if (version !== manifest.tools.gut.version) throw Error('GUT pinned version mismatch.');
    report.tool_versions.gut = { path: tool('gut'), expected_version: version, actual_version: version };
    await cp(tool('gut'), path.join(snapshot, 'addons/gut'), { recursive: true });
    // Hash the tested snapshot rather than a live file another agent might edit during this run.
    for (const file of sourceFiles) report.code_state.files_sha256[relative(file)] = hash(await readFile(path.join(snapshot, relative(file))));
    for (const file of ['tools/check.mjs', 'tools/check-game.mjs', 'tools/read-junit.py', 'tools/toolchain.json', 'docs/testing.md']) report.code_state.files_sha256[file] = hash(await readFile(path.join(root, file)));
    const git = await execute([tool('git'), 'rev-parse', 'HEAD'], path.join(logs, 'git-state.log'));
    report.code_state.git = clean(git) ? 'repository' : 'no_commit_available';
    report.code_state.commit = clean(git) ? git.stdout.trim() : null;
    const dirty = await execute([tool('git'), 'status', '--porcelain'], path.join(logs, 'git-status.log'));
    report.code_state.working_tree_status = clean(dirty) ? dirty.stdout.trim() : 'unavailable';
    return { observed_status: 'pass', source_files: sourceFiles.map(relative), expected_tests: expectedTests, snapshot_path: relative(snapshot) };
  }, ['manifest']);
  const gdFiles = sourceFiles.filter((file) => file.endsWith('.gd')).map((file) => path.join(snapshot, relative(file)));
  const engine = (id, args) => [tool('godot'), '--headless', '--path', snapshot, '--log-file', path.join(logs, `${id}.engine.log`), ...args];
  await check('lint', 'Lint all own game and test GDScript; exclude vendor and historical artifacts.', { exit_code: 0 }, [tool('gdlint'), ...gdFiles], clean, ['sources', 'version-gdlint']);
  await check('format', 'Verify all own game and test GDScript formatting without edits.', { exit_code: 0 }, [tool('gdformat'), '--check', ...gdFiles], clean, ['sources', 'version-gdformat']);
  await check('import', 'Headless import actual project and register classes.', { exit_code: 0, engine_errors: 0 }, engine('import', ['--editor', '--import']), (result) => clean(result) && noEngineErrors(result), ['sources', 'version-godot'], 60000);
  const xml = path.join(runDir, 'game.xml');
  await check('gut', 'Execute actual game unit and physics integration tests.', { exit_code: 0, xml_path: relative(xml) }, engine('gut', ['--script', 'res://addons/gut/gut_cmdln.gd', '-gdir=res://tests/game', '-ginclude_subdirs', '-gexit', '-glog=2', `-gjunit_xml_file=${xml}`]), (result) => clean(result) && noEngineErrors(result), ['import'], 60000);
  await check('junit', 'Independently require every expected test and assertion; reject skips and missing evidence.', { test_names: expectedTests, failures: 0, errors: 0, skipped: 0 }, [tool('python'), path.join(root, 'tools/read-junit.py'), xml], (result) => {
    if (!clean(result)) return false;
    const evidence = JSON.parse(result.stdout); result.junit = evidence;
    const names = evidence.cases.map((item) => item.name);
    return evidence.tests === expectedTests.length && new Set(names).size === names.length && expectedTests.every((name) => names.includes(name)) && evidence.failures === 0 && evidence.errors === 0 && evidence.skipped === 0;
  }, ['import', 'version-python']);
  await check('startup', 'Run main scene for 120 headless frames and reject engine errors.', { exit_code: 0, engine_errors: 0, frames: 120 }, engine('startup', ['--quit-after', '120']), (result) => clean(result) && noEngineErrors(result), ['import'], 15000);
  const unexpected = report.checks.filter((item) => item.status !== 'pass');
  report.summary = { expected: report.expected_check_ids.length, executed: report.checks.length, matched: report.checks.length - unexpected.length, unexpected: unexpected.map(({ id, status, error_id }) => ({ id, status, error_id })), missing: [] };
  report.status = unexpected.some((item) => item.status === 'fail') ? 'fail' : unexpected.some((item) => item.status === 'timeout') ? 'timeout' : unexpected.length ? 'blocked' : 'pass';
  report.reason = report.status === 'pass' ? 'All actual game checks passed; feel requires user feedback.' : `Unresolved: ${unexpected.map((item) => item.id).join(', ')}`;
  report.time.finished_at = new Date().toISOString(); report.time.duration_ms = Date.now() - started.getTime();
  const reportPath = path.join(runDir, 'report.json');
  await writeFile(reportPath, JSON.stringify(report, null, 2) + '\n');
  const saved = JSON.parse(await readFile(reportPath, 'utf8'));
  if (saved.checks.length !== saved.expected_check_ids.length || !saved.checks.length) throw Error('Report readback/completeness failed.');
  const pointer = path.join(root, 'artifacts/test-runs/latest.json'), temporary = `${pointer}.${runId}.tmp`;
  await writeFile(temporary, JSON.stringify({ schema_version: 1, run_id: runId, scope: 'game', status: report.status, report_path: relative(reportPath), finished_at: report.time.finished_at }, null, 2) + '\n');
  await rename(temporary, pointer);
  console.log(JSON.stringify({ run_id: runId, status: report.status, report_path: relative(reportPath), summary: report.summary }));
  process.exitCode = report.status === 'pass' ? 0 : 1;
  return report;
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) await runGameChecks();
