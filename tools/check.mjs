#!/usr/bin/env node
import { spawn } from 'node:child_process';
import { createHash, randomUUID } from 'node:crypto';
import { cp, mkdir, readFile, rename, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { loadToolchain, toolPath, versionMatches } from './toolchain-config.mjs';

const runnerPath = fileURLToPath(import.meta.url);
const root = path.resolve(path.dirname(runnerPath), '..');
const argv = process.argv.slice(2);
if (argv.length !== 2 || argv[0] !== '--scope' || !['toolchain', 'game'].includes(argv[1])) {
  console.error('Usage: node tools/check.mjs --scope toolchain|game; unsupported arguments are rejected.');
  process.exit(2);
}
if (argv[1] === 'game') {
  const { runGameChecks } = await import('./check-game.mjs');
  await runGameChecks();
  process.exit(process.exitCode ?? 0);
}

const started = new Date();
const runId = `${started.toISOString().replace(/[-:.]/g, '')}-${randomUUID().slice(0, 8)}`;
const runDir = path.join(root, 'artifacts', 'test-runs', runId);
const fixture = path.join(runDir, 'fixture-project');
const logsDir = path.join(runDir, 'logs');
const relative = (value) => path.relative(root, value).split(path.sep).join('/');
const reportPath = path.join(runDir, 'report.json');
const invocation = [process.execPath, runnerPath, '--scope', 'toolchain'];
const report = {
  schema_version: 1,
  run_id: runId,
  scope: 'toolchain',
  status: 'blocked',
  cwd: root,
  time: { started_at: started.toISOString(), finished_at: null, duration_ms: null },
  channel: 'automated_test',
  code_state: { git: 'unavailable', commit: null, reason: 'Git state has not been read.', files_sha256: {} },
  tool_versions: {},
  expected_check_ids: [],
  checks: [],
  reason: 'Run has not completed.',
};
await mkdir(logsDir, { recursive: true });

function errorId(id) {
  return `ERR-TOOLCHAIN-${id.replace(/[^a-z0-9]+/gi, '-').toUpperCase()}`;
}

async function addInternal(id, purpose, expected, action) {
  report.expected_check_ids.push(id);
  const check = {
    id, purpose, execution_kind: 'internal', command: invocation, cwd: root,
    timeout_ms: 5000, expected, actual: {}, exit_code: null,
    log_path: relative(path.join(logsDir, `${id}.log`)), status: 'blocked', error_id: null,
  };
  let deadline;
  try {
    check.actual = await Promise.race([
      action(),
      new Promise((_, reject) => {
        deadline = setTimeout(() => reject(new Error(`Internal check exceeded ${check.timeout_ms} ms.`)), check.timeout_ms);
      }),
    ]);
    check.status = 'pass';
  } catch (error) {
    check.actual = { observed_status: 'blocked', error: String(error), stack: error.stack };
    check.error_id = errorId(id);
  } finally {
    clearTimeout(deadline);
  }
  await writeFile(path.join(root, check.log_path), JSON.stringify(check.actual, null, 2) + '\n');
  report.checks.push(check);
  return check;
}

// Commands use argv without a shell. Every spawned process gets a bounded deadline.
async function execute(command, cwd, timeoutMs, logPath) {
  const start = Date.now();
  let stdout = '';
  let stderr = '';
  let timedOut = false;
  let spawnError = null;
  let terminationError = null;
  let pid = null;
  const result = await new Promise((resolve) => {
    const child = spawn(command[0], command.slice(1), {
      cwd, env: process.env, detached: process.platform !== 'win32', stdio: ['ignore', 'pipe', 'pipe'],
    });
    pid = child.pid ?? null;
    child.stdout.on('data', (data) => { stdout += data.toString(); });
    child.stderr.on('data', (data) => { stderr += data.toString(); });
    child.on('error', (error) => { spawnError = String(error); });
    function terminate(signal) {
      if (!pid) return;
      try {
        if (process.platform === 'win32') child.kill(signal);
        else process.kill(-pid, signal);
      } catch (error) {
        if (error.code !== 'ESRCH') terminationError = String(error);
      }
    }
    let hardKill;
    const deadline = setTimeout(() => {
      timedOut = true;
      terminate('SIGTERM');
      hardKill = setTimeout(() => terminate('SIGKILL'), 500);
    }, timeoutMs);
    child.once('close', (exitCode, signal) => {
      clearTimeout(deadline);
      clearTimeout(hardKill);
      resolve({ exit_code: exitCode, signal });
    });
  });
  let terminated = true;
  if (pid) {
    try { process.kill(process.platform === 'win32' ? pid : -pid, 0); terminated = false; }
    catch (error) { if (error.code !== 'ESRCH') terminated = false; }
  }
  const observedStatus = spawnError ? 'blocked' : timedOut ? 'timeout' : result.exit_code === 0 ? 'pass' : 'fail';
  await writeFile(logPath, [
    `command(argv): ${JSON.stringify(command)}`, `cwd: ${cwd}`, `timeout_ms: ${timeoutMs}`,
    '--- stdout ---', stdout, '--- stderr ---', stderr,
    '--- process result ---', JSON.stringify({ ...result, timed_out: timedOut, pid, terminated, spawn_error: spawnError, termination_error: terminationError }), '',
  ].join('\n'));
  return {
    ...result, observed_status: observedStatus, timed_out: timedOut, pid, terminated,
    spawn_error: spawnError, termination_error: terminationError, duration_ms: Date.now() - start,
    stdout, stderr,
  };
}

function checkPassed(id) {
  return report.checks.find((check) => check.id === id)?.status === 'pass';
}

async function addProcess(id, purpose, command, expected, judge, dependencies = [], timeoutMs = 15000, cwd = root) {
  report.expected_check_ids.push(id);
  const logPath = path.join(logsDir, `${id}.log`);
  const check = {
    id, purpose, command, cwd, timeout_ms: timeoutMs, expected, actual: {}, exit_code: null,
    log_path: relative(logPath), status: 'blocked', error_id: null,
  };
  const unmet = dependencies.filter((dependency) => !checkPassed(dependency));
  if (unmet.length) {
    check.actual = { observed_status: 'blocked', reason: 'Required checks did not pass.', unmet_dependencies: unmet };
    await writeFile(logPath, JSON.stringify(check.actual, null, 2) + '\n');
  } else {
    const actual = await execute(command, cwd, timeoutMs, logPath);
    check.exit_code = actual.exit_code;
    check.actual = actual;
    let matches = false;
    try { matches = Boolean(await judge(actual)); }
    catch (error) { actual.evidence_error = String(error); }
    check.status = matches ? 'pass' : actual.observed_status === 'blocked' ? 'blocked' : actual.timed_out ? 'timeout' : 'fail';
    // Full output remains in the log; JSON keeps useful diagnostic context without duplicating it.
    check.actual.stdout_tail = actual.stdout.slice(-3000);
    check.actual.stderr_tail = actual.stderr.slice(-3000);
    delete check.actual.stdout;
    delete check.actual.stderr;
  }
  if (check.status !== 'pass') check.error_id = errorId(id);
  report.checks.push(check);
  return check;
}

const cleanExit = (actual) => actual.exit_code === 0 && !actual.timed_out && !actual.spawn_error;
const noEngineErrors = (actual) => !/(?:SCRIPT ERROR:|Parse Error:|^ERROR:)/m.test(actual.stdout + actual.stderr);

async function finish() {
  const missing = report.expected_check_ids.filter((id) => !report.checks.some((check) => check.id === id));
  const unexpected = report.checks.filter((check) => check.status !== 'pass');
  report.status = missing.length || !report.checks.length ? 'blocked'
    : unexpected.some((check) => check.status === 'fail') ? 'fail'
    : unexpected.some((check) => check.status === 'timeout') ? 'timeout'
    : unexpected.length ? 'blocked' : 'pass';
  report.reason = report.status === 'pass'
    ? 'All required toolchain checks executed and their evidence matched expectations. This does not verify game functionality or feel.'
    : `Unresolved checks: ${unexpected.map((check) => check.id).join(', ')}; missing checks: ${missing.join(', ') || 'none'}.`;
  report.time.finished_at = new Date().toISOString();
  report.time.duration_ms = Date.now() - started.getTime();
  report.summary = {
    expected: report.expected_check_ids.length,
    executed: report.checks.length,
    matched: report.checks.filter((check) => check.status === 'pass').length,
    unexpected: unexpected.map((check) => ({ id: check.id, status: check.status, error_id: check.error_id })),
    missing,
  };
  await writeFile(reportPath, JSON.stringify(report, null, 2) + '\n');
  // Read back the saved report. A write without readable evidence cannot establish success.
  const saved = JSON.parse(await readFile(reportPath, 'utf8'));
  if (saved.run_id !== runId || saved.checks.length !== report.expected_check_ids.length) {
    throw new Error('Saved report failed completeness verification.');
  }
  const pointerPath = path.join(root, 'artifacts', 'test-runs', 'latest.json');
  const temporaryPointer = `${pointerPath}.${runId}.tmp`;
  await writeFile(temporaryPointer, JSON.stringify({
    schema_version: 1, run_id: runId, scope: report.scope, status: report.status,
    report_path: relative(reportPath), finished_at: report.time.finished_at,
  }, null, 2) + '\n');
  await rename(temporaryPointer, pointerPath);
  console.log(JSON.stringify({ run_id: runId, status: report.status, report_path: relative(reportPath), summary: report.summary }));
  process.exitCode = report.status === 'pass' ? 0 : 1;
}

try {
  let manifest;
  await addInternal('manifest', 'Read and validate fixed toolchain configuration.', { schema_version: 1, required_tools: ['godot', 'gut', 'python', 'gdlint', 'gdformat', 'node', 'git'] }, async () => {
    const configuration = await loadToolchain(root);
    manifest = configuration.manifest;
    if (manifest.schema_version !== 1 || !manifest.tools) throw new Error('Unsupported or missing toolchain schema.');
    for (const name of ['godot', 'gut', 'python', 'gdlint', 'gdformat', 'node', 'git']) {
      const item = manifest.tools[name];
      if (!(item?.version || item?.min_version) || !(name === 'gut' ? item.addons_path : item.path)) throw new Error(`Missing tool configuration: ${name}`);
    }
    report.toolchain_config = { path: relative(configuration.config_path), sha256: configuration.config_hash, manifest };
    return { observed_status: 'pass', manifest_path: relative(configuration.config_path), schema_version: 1 };
  });
  for (const sourcePath of ['tools/check.mjs', 'tools/check-game.mjs', 'tools/toolchain-config.mjs', 'tools/bootstrap.mjs', 'tools/test-toolchain.mjs', 'tools/prepare-worktree.mjs', 'tools/test-worktree.mjs', 'tools/test-worktree-runtime.mjs', 'tools/with-integration-lock.mjs', 'tools/play.mjs', 'tools/workspace-state.mjs', 'tools/workspace.mjs', 'tools/test-human-workspace.mjs', 'docs/human-editing.md', 'docs/design-baselines.md', 'tools/toolchain.json', 'tools/requirements-gdtoolkit.lock', '.github/workflows/check.yml', 'tools/read-junit.py', 'docs/testing.md', 'docs/worktrees.md', 'AGENTS.md']) {
    report.code_state.files_sha256[sourcePath] = createHash('sha256').update(await readFile(path.join(root, sourcePath))).digest('hex');
  }
  const tool = (name) => toolPath(root, manifest, name);
  const versionTools = ['node', 'git', 'python', 'godot', 'gdlint', 'gdformat'];
  if (manifest?.tools?.gh) versionTools.push('gh');
  for (const name of versionTools) {
    const expectedVersion = manifest?.tools?.[name]?.version ?? manifest?.tools?.[name]?.min_version ?? null;
    const policy = manifest?.tools?.[name]?.version_policy ?? 'exact';
    const check = await addProcess(`version-${name}`, `Verify executable and configured ${name} version policy.`, [tool(name), '--version'], { exit_code: 0, version: expectedVersion, version_policy: policy }, (actual) => {
      const output = (actual.stdout + actual.stderr).trim();
      const version = name === 'godot' ? output.split(/\s/)[0] : output.match(/\d+\.\d+\.\d+/)?.[0];
      actual.version = version ?? null;
      report.tool_versions[name] = { path: tool(name), expected_version: expectedVersion, version_policy: policy, actual_version: version ?? null };
      return cleanExit(actual) && versionMatches(manifest.tools[name], version);
    }, ['manifest']);
    if (!report.tool_versions[name]) report.tool_versions[name] = { path: tool(name), expected_version: expectedVersion, actual_version: null, status: check.status };
  }
  if (checkPassed('version-git')) {
    const repository = await execute([tool('git'), 'rev-parse', '--is-inside-work-tree'], root, 5000, path.join(logsDir, 'git-repository.log'));
    if (cleanExit(repository) && repository.stdout.trim() === 'true') {
      const head = await execute([tool('git'), 'rev-parse', 'HEAD'], root, 5000, path.join(logsDir, 'git-state.log'));
      const workingTree = await execute([tool('git'), 'status', '--porcelain'], root, 5000, path.join(logsDir, 'git-status.log'));
      report.code_state.git = cleanExit(head) ? 'repository' : 'repository_no_commit';
      report.code_state.commit = cleanExit(head) ? head.stdout.trim() : null;
      report.code_state.working_tree_status = cleanExit(workingTree) ? workingTree.stdout.trim() : 'unavailable';
      report.code_state.reason = 'Observed local Git state; files_sha256 identifies the tested working files.';
    } else {
      report.code_state.git = 'no_repository';
      report.code_state.reason = 'No readable local Git repository; files_sha256 identifies tested files.';
    }
  }
  await addProcess('version-gut', 'Read GUT plugin metadata and verify pinned version.', [tool('node'), '-e', `const f=require('node:fs'); const c=f.readFileSync(process.argv[1],'utf8'); const m=c.match(/^version="([^\"]+)"/m); if(!m)process.exit(1); console.log(m[1]);`, path.join(tool('gut'), 'plugin.cfg')], { exit_code: 0, version: manifest?.tools?.gut?.version ?? null }, (actual) => {
    const version = actual.stdout.trim();
    actual.version = version;
    report.tool_versions.gut = { path: tool('gut'), expected_version: manifest.tools.gut.version, actual_version: version };
    return cleanExit(actual) && version === manifest.tools.gut.version;
  }, ['manifest', 'version-node']);

  await addInternal('fixture-prepare', 'Generate an isolated toolchain fixture with no game implementation.', { path: relative(fixture), game_functionality: false }, async () => {
    if (!checkPassed('version-gut')) throw new Error('GUT source is unavailable or its version is unverified.');
    await mkdir(path.join(fixture, 'tests', 'success'), { recursive: true });
    await mkdir(path.join(fixture, 'tests', 'failure'), { recursive: true });
    await mkdir(path.join(fixture, 'checks'), { recursive: true });
    await mkdir(path.join(fixture, 'addons'), { recursive: true });
    await cp(tool('gut'), path.join(fixture, 'addons', 'gut'), { recursive: true });
    const files = {
      'project.godot': 'config_version=5\n\n[application]\nconfig/name="Agent Toolchain Fixture"\n\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n',
      'fixture_parse.gd': 'extends SceneTree\n\n\nfunc _initialize() -> void:\n\tprint("TOOLCHAIN_RUNTIME_OK")\n\tquit(0)\n',
      'tests/success/test_success.gd': 'extends GutTest\n\n\nfunc test_toolchain_success() -> void:\n\tassert_eq(2 + 2, 4, "fixture success assertion")\n',
      'tests/failure/test_failure.gd': 'extends GutTest\n\n\nfunc test_toolchain_failure() -> void:\n\tassert_eq(2 + 2, 5, "INTENTIONAL_TOOLCHAIN_FAILURE")\n',
      'checks/lint_valid.gd': 'extends RefCounted\n\n\nfunc answer() -> int:\n\treturn 42\n',
      'checks/lint_invalid.gd': 'extends RefCounted\n\n\nfunc BadName() -> int:\n\treturn 42\n',
      'checks/format_invalid.gd': 'extends RefCounted\nfunc answer()->int:\n  return 42\n',
    };
    for (const [name, content] of Object.entries(files)) await writeFile(path.join(fixture, name), content);
    return { observed_status: 'pass', fixture_path: relative(fixture), generated_files: Object.keys(files), game_functionality: false };
  });
  const godotCommand = (id, args) => [tool('godot'), '--headless', '--path', fixture, '--log-file', path.join(logsDir, `${id}.engine.log`), ...args];
  await addProcess('godot-import', 'Headless import and register fixture/GUT scripts and resources.', godotCommand('godot-import', ['--editor', '--import']), { exit_code: 0, engine_errors: 0 }, (actual) => cleanExit(actual) && noEngineErrors(actual), ['version-godot', 'fixture-prepare'], 60000);
  await addProcess('godot-parse', 'Parse the valid fixture script using Godot check-only.', godotCommand('godot-parse', ['--check-only', '--script', 'res://fixture_parse.gd']), { exit_code: 0, engine_errors: 0 }, (actual) => cleanExit(actual) && noEngineErrors(actual), ['godot-import'], 15000);
  await addProcess('godot-runtime', 'Execute a headless fixture and require its completion marker.', godotCommand('godot-runtime', ['--script', 'res://fixture_parse.gd']), { exit_code: 0, marker: 'TOOLCHAIN_RUNTIME_OK' }, (actual) => cleanExit(actual) && noEngineErrors(actual) && actual.stdout.includes('TOOLCHAIN_RUNTIME_OK'), ['godot-parse'], 15000);

  for (const mode of ['success', 'failure']) {
    const xmlPath = path.join(runDir, `gut-${mode}.xml`);
    const expectedCode = mode === 'success' ? 0 : 1;
    const gutId = `gut-${mode}`;
    await addProcess(gutId, `Run the ${mode === 'success' ? 'passing' : 'intentionally failing'} GUT assertion.`, godotCommand(gutId, ['--script', 'res://addons/gut/gut_cmdln.gd', `-gdir=res://tests/${mode}`, '-gexit', '-glog=2', `-gjunit_xml_file=${xmlPath}`]), { exit_code: expectedCode, intended_failure: mode === 'failure', xml_path: relative(xmlPath) }, (actual) => !actual.timed_out && !actual.spawn_error && actual.exit_code === expectedCode && noEngineErrors(actual), ['godot-import'], 45000);
    await addProcess(`junit-${mode}`, 'Independently parse JUnit XML and verify actual test/assertion evidence.', [tool('python'), path.join(root, 'tools', 'read-junit.py'), xmlPath], { exit_code: 0, tests: 1, assertions: 1, failures: mode === 'failure' ? 1 : 0, skipped: 0, errors: 0 }, (actual) => {
      if (!cleanExit(actual)) return false;
      const evidence = JSON.parse(actual.stdout);
      actual.junit = evidence;
      actual.xml_path = relative(xmlPath);
      return evidence.tests === 1 && evidence.assertions === 1 && evidence.failures === (mode === 'failure' ? 1 : 0) && evidence.skipped === 0 && evidence.errors === 0
        && evidence.cases[0].name === `test_toolchain_${mode}`
        && (mode !== 'failure' || evidence.cases[0].failures.some((text) => text.includes('INTENTIONAL_TOOLCHAIN_FAILURE')));
    }, [`gut-${mode}`, 'version-python'], 10000);
  }
  await addProcess('lint-success', 'Accept a valid GDScript fixture.', [tool('gdlint'), path.join(fixture, 'checks', 'lint_valid.gd')], { exit_code: 0 }, cleanExit, ['fixture-prepare', 'version-gdlint']);
  await addProcess('lint-failure', 'Capture the intentional function naming violation.', [tool('gdlint'), path.join(fixture, 'checks', 'lint_invalid.gd')], { exit_code: 1, rule: 'function-name', intended_failure: true }, (actual) => actual.exit_code === 1 && !actual.timed_out && /function-name/.test(actual.stdout + actual.stderr), ['fixture-prepare', 'version-gdlint']);
  await addProcess('format-success', 'Accept an already formatted GDScript fixture.', [tool('gdformat'), '--check', path.join(fixture, 'checks', 'lint_valid.gd')], { exit_code: 0 }, cleanExit, ['fixture-prepare', 'version-gdformat']);
  await addProcess('format-failure', 'Capture intentionally unformatted GDScript without editing it.', [tool('gdformat'), '--check', path.join(fixture, 'checks', 'format_invalid.gd')], { exit_code: 1, intended_failure: true }, (actual) => actual.exit_code === 1 && !actual.timed_out && /would (?:be )?reformat|would reformat|reformatted/i.test(actual.stdout + actual.stderr), ['fixture-prepare', 'version-gdformat']);
  await addProcess('process-timeout', 'Prove a stalled fixture process is terminated and its timeout retained.', [tool('node'), '-e', 'console.log("INTENTIONAL_TIMEOUT_STARTED"); setInterval(() => {}, 1000);'], { observed_status: 'timeout', terminated: true, intended_timeout: true, marker: 'INTENTIONAL_TIMEOUT_STARTED' }, (actual) => actual.timed_out && actual.terminated && !actual.termination_error && actual.stdout.includes('INTENTIONAL_TIMEOUT_STARTED'), ['version-node'], 300);
  await finish();
} catch (error) {
  await addInternal('runner-error', 'Retain an unexpected runner exception.', { runner_exception: false }, async () => { throw error; });
  await finish();
}
