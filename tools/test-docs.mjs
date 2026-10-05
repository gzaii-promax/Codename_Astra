import assert from 'node:assert/strict';
import test from 'node:test';
import { spawnSync } from 'node:child_process';
import { cp, mkdir, mkdtemp, readFile, rm, writeFile } from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { validateMarkdown } from './check-docs.mjs';

const entries = ['README.md', 'AGENTS.md', 'ARCHITECTURE.md', 'docs/index.md', 'docs/status.md'];
function fixture(text) {
  const documents = new Map(entries.map((file) => [file, '# 已保存\n']));
  documents.set('README.md', text);
  return { documents, files: new Set([...entries, 'world/map_world.tscn', 'docs/有 空格.md']) };
}
const check = (text) => { const { documents, files } = fixture(text); return validateMarkdown(documents, files); };

test('saved local files, nested links, Unicode paths and external URLs are accepted', () => {
  const result = check('# 入口\n[状态](docs/status.md#已保存)\n[场景](world/map_world.tscn)\n[说明](<docs/有 空格.md>)\n[外部](https://example.invalid/page)');
  assert.equal(result.errors.length, 0); assert.equal(result.local_link_count, 3);
});
test('deleted source links, obsolete headings and out-of-repository paths fail with locations', () => {
  const result = check('[缺失](world/deleted.tscn)\n[旧标题](docs/status.md#旧标题)\n[外部文件](../secret.md)');
  assert.equal(result.errors.length, 3); assert.deepEqual(result.errors.map((e) => e.line), [1, 2, 3]);
});
test('reference definitions are checked but fenced and inline code examples are not treated as links', () => {
  const result = check('```md\n[示例](missing.md)\n```\n`[示例](missing.md)`\n[状态]: docs/status.md\n[失效]: missing.md');
  assert.equal(result.local_link_count, 2); assert.equal(result.errors.length, 1);
});
test('missing required entries and empty documents cannot produce a clean result', () => {
  const { documents, files } = fixture('# 项目'); documents.delete('AGENTS.md'); documents.set('docs/status.md', ' ');
  const result = validateMarkdown(documents, files);
  assert.ok(result.errors.some((e) => e.file === 'AGENTS.md')); assert.ok(result.errors.some((e) => e.file === 'docs/status.md'));
});
test('the real docs entrypoint preserves a failed link report and succeeds after the document is repaired', async (t) => {
  const root = await mkdtemp(path.join(os.tmpdir(), 'astra-docs-check-'));
  t.after(() => rm(root, { recursive: true, force: true }));
  assert.equal(spawnSync('git', ['init', '--quiet', root]).status, 0);
  await mkdir(path.join(root, 'tools')); await mkdir(path.join(root, 'docs'));
  await mkdir(path.join(root, '.github/workflows'), { recursive: true });
  await writeFile(path.join(root, '.github/workflows/check.yml'), 'name: fixture\n');
  for (const name of ['check.mjs', 'check-docs.mjs', 'test-docs.mjs', 'toolchain-config.mjs', 'change-scope.mjs', 'test-change-scope.mjs']) await cp(fileURLToPath(new URL(name, import.meta.url)), path.join(root, 'tools', name));
  for (const file of entries) await writeFile(path.join(root, file), '# 已保存\n');
  await writeFile(path.join(root, 'README.md'), '# 入口\n[旧文件](docs/deleted.md)\n');
  const invoke = () => spawnSync(process.execPath, [path.join(root, 'tools/check.mjs'), '--scope', 'docs'], { encoding: 'utf8', timeout: 15000 });
  const failed = invoke(); assert.equal(failed.status, 1, failed.stderr);
  const first = JSON.parse(failed.stdout), failure = JSON.parse(await readFile(path.join(root, first.report_path), 'utf8'));
  assert.equal(failure.scope, 'docs'); assert.equal(failure.status, 'fail');
  assert.equal(failure.checks[1].actual.errors[0].target, 'docs/deleted.md');
  await writeFile(path.join(root, 'README.md'), '# 入口\n[状态](docs/status.md#已保存)\n');
  const repaired = invoke(); assert.equal(repaired.status, 0, repaired.stderr);
  const second = JSON.parse(repaired.stdout);
  assert.notEqual(second.run_id, first.run_id); assert.equal(second.status, 'pass');
  assert.equal(JSON.parse(await readFile(path.join(root, first.report_path), 'utf8')).status, 'fail');
  assert.equal(JSON.parse(await readFile(path.join(root, 'artifacts/test-runs/latest.json'), 'utf8')).run_id, second.run_id);
  await writeFile(path.join(root, 'target.tscn'), '[gd_scene format=3]\n');
  assert.equal(spawnSync('git', ['-C', root, 'add', 'target.tscn']).status, 0);
  await writeFile(path.join(root, 'README.md'), '[场景](target.tscn)'); await rm(path.join(root, 'target.tscn'));
  const deleted = invoke(); assert.equal(deleted.status, 1, deleted.stderr);
  const deletedReport = JSON.parse(await readFile(path.join(root, JSON.parse(deleted.stdout).report_path), 'utf8'));
  assert.equal(deletedReport.checks[1].actual.errors[0].target, 'target.tscn');
});
test('nested labels, single quoted titles and parentheses cannot hide a broken destination', () => {
  const result = check("[嵌套 [标签]](missing.md)\n[失效](missing.md '说明')\n[括号](missing(file).md)\n[语法错误](<unclosed.md)");
  assert.equal(result.errors.length, 4);
});
test('Setext headings, linked headings, code labels and footnotes have rendered anchor semantics', () => {
  const { documents, files } = fixture('[标题](docs/status.md#状态)\n[代码](docs/status.md#field)\n[普通](docs/status.md#当前)\n[^1]: 注释文本');
  documents.set('docs/status.md', '# [状态](index.md)\n## `field`\n当前\n---\n');
  assert.equal(validateMarkdown(documents, files).errors.length, 0);
});
