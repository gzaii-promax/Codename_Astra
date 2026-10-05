import { spawnSync } from 'node:child_process';
import { createHash, randomUUID } from 'node:crypto';
import { mkdir, readFile, rename, writeFile } from 'node:fs/promises';
import path from 'node:path';

const sha256 = (data) => createHash('sha256').update(data).digest('hex');
const required = ['README.md', 'AGENTS.md', 'ARCHITECTURE.md', 'docs/index.md', 'docs/status.md'];
const stripFences = (text) => text.replace(/^([ \t]*)(`{3,}|~{3,})[^\n]*\n[\s\S]*?^\1\2[^\n]*$/gm,
  (block) => block.replace(/[^\n]/g, ' '));
const stripExamples = (text) => stripFences(text).replace(/(`+)[^\n]*?\1/g, (code) => ' '.repeat(code.length));

function destination(text, start, inline = true) {
  let i = start; while (/\s/.test(text[i] ?? '') && i < text.length) i++;
  let raw = '', depth = 0;
  if (text[i] === '<') {
    const end = text.indexOf('>', i + 1);
    if (end < 0 || text.slice(i, end).includes('\n')) throw Error('Unclosed angle-bracket destination.');
    raw = text.slice(i + 1, end); i = end + 1;
  } else {
    for (; i < text.length; i++) {
      const char = text[i];
      if (/\s/.test(char) || (char === ')' && depth === 0 && inline)) break;
      if (char === '\\' && i + 1 < text.length) { raw += text[++i]; continue; }
      if (char === '(') depth++; if (char === ')') depth--;
      raw += char;
    }
    if (depth !== 0) throw Error('Unbalanced destination parentheses.');
  }
  if (inline) {
    while (/\s/.test(text[i] ?? '') && i < text.length) i++;
    if (['"', "'", '('].includes(text[i])) {
      const closing = text[i] === '(' ? ')' : text[i]; i++;
      while (i < text.length && text[i] !== closing) { if (text[i] === '\\') i++; i++; }
      if (i >= text.length) throw Error('Unclosed link title.'); i++;
      while (/\s/.test(text[i] ?? '') && i < text.length) i++;
    }
    if (text[i] !== ')') throw Error('Unclosed inline link.');
  }
  return { raw, end: i };
}

function markdownLinks(text) {
  const result = [];
  for (let i = 0; i < text.length; i++) {
    if (text[i] === '\\') { i++; continue; }
    if (text[i] !== '[') continue;
    const start = i; let depth = 1, close = i + 1;
    for (; close < text.length && depth; close++) {
      if (text[close] === '\\') { close++; continue; }
      if (text[close] === '[') depth++; if (text[close] === ']') depth--;
    }
    if (depth || text[close] !== '(') continue;
    try { const parsed = destination(text, close + 1); result.push({ index: start, raw: parsed.raw }); i = parsed.end; }
    catch (error) { result.push({ index: start, raw: '', parse_error: error.message }); }
  }
  for (const match of text.matchAll(/^ {0,3}\[(?!\^)[^\]\n]+\]:\s*/gm)) {
    try { result.push({ index: match.index, raw: destination(text, match.index + match[0].length, false).raw }); }
    catch (error) { result.push({ index: match.index, raw: '', parse_error: error.message }); }
  }
  return result;
}

function anchors(text) {
  const result = new Set(), seen = new Map();
  const headingText = stripFences(text);
  const headings = [...headingText.matchAll(/^ {0,3}#{1,6}\s+(.+?)\s*#*\s*$/gm), ...headingText.matchAll(/^([^\n]+)\n {0,3}(?:=+|-+)\s*$/gm)].sort((a, b) => a.index - b.index);
  for (const match of headings) {
    const label = match[1].replace(/!?\[([^\]]+)\]\([^)]*\)/g, '$1');
    const slug = label.replace(/<[^>]*>/g, '').toLowerCase().replace(/[^\p{L}\p{N}_\-\s]/gu, '').replace(/\s/g, '-');
    const count = seen.get(slug) ?? 0;
    result.add(count ? `${slug}-${count}` : slug); seen.set(slug, count + 1);
  }
  return result;
}

// Local links only: this is a structural check, not a network or prose accuracy check.
export function validateMarkdown(documents, files) {
  const errors = [], links = [];
  for (const file of required) if (!documents.get(file)?.trim()) errors.push({ file, reason: 'Missing or empty required document.' });
  for (const [file, content] of documents) {
    if (!content.trim()) errors.push({ file, reason: 'Empty document.' });
    const text = stripExamples(content);
    for (const match of markdownLinks(text)) {
      const raw = match.raw;
      const line = text.slice(0, match.index).split('\n').length;
      if (match.parse_error) { errors.push({ file, line, reason: match.parse_error }); continue; }
      if (/^[a-z][a-z\d+.-]*:/i.test(raw) || raw.startsWith('//')) continue;
      try {
        const [target, fragment] = raw.split('#');
        const decoded = decodeURIComponent(target.split('?')[0]);
        const resolved = decoded ? path.posix.normalize(path.posix.join(path.posix.dirname(file), decoded)) : file;
        const link = { file, line, target: raw, resolved }; links.push(link);
        if (decoded.startsWith('/') || resolved === '..' || resolved.startsWith('../')) errors.push({ ...link, reason: 'Local link leaves the repository.' });
        else if (!files.has(resolved)) errors.push({ ...link, reason: 'Local target is not a repository source file.' });
        else if (fragment && documents.has(resolved) && !anchors(documents.get(resolved)).has(decodeURIComponent(fragment))) errors.push({ ...link, reason: 'Missing Markdown heading anchor.' });
      } catch (error) { errors.push({ file, line, target: raw, reason: `Invalid local link: ${error.message}` }); }
    }
  }
  return { document_count: documents.size, local_link_count: links.length, errors, links };
}

export async function runDocsChecks(root) {
  const started = new Date(), runId = `${started.toISOString().replace(/[-:.]/g, '')}-${randomUUID().slice(0, 8)}`;
  const runDir = path.join(root, 'artifacts/test-runs', runId), logs = path.join(runDir, 'logs');
  const relative = (file) => path.relative(root, file).split(path.sep).join('/');
  const report = { schema_version: 1, run_id: runId, scope: 'docs', status: 'blocked', cwd: root,
    channel: 'automated_test', time: { started_at: started.toISOString() },
    tool_versions: { node: { actual_version: process.versions.node } },
    code_state: { commit: null, files_sha256: {} }, expected_check_ids: ['sources', 'links'], checks: [],
    evidence_limit: 'Checks nonempty Markdown and repository-local file/heading links. Does not verify claims, external links, game behavior, or user feel.' };
  await mkdir(logs, { recursive: true });
  const git = (...args) => {
    const result = spawnSync('git', args, { cwd: root, encoding: 'utf8', timeout: 5000, maxBuffer: 8 * 1024 * 1024 });
    if (result.error || result.status !== 0) throw Error(result.error?.message ?? result.stderr.trim());
    return result.stdout;
  };
  const documents = new Map(); let files;
  for (const id of report.expected_check_ids) {
    const item = { id, purpose: id === 'sources' ? 'Identify current repository documents and source hashes.' : 'Reject missing local files, heading anchors and empty documents.',
      execution_kind: 'internal', command: [process.execPath, path.join(root, 'tools/check.mjs'), '--scope', 'docs'], cwd: root,
      timeout_ms: 10000, expected: { errors: 0 }, actual: {}, exit_code: null, status: 'blocked', log_path: relative(path.join(logs, `${id}.log`)) };
    let deadline;
    try {
      const action = async () => {
        if (id === 'sources') {
          files = new Set(git('ls-files', '--cached', '--others', '--exclude-standard', '-z').split('\0').filter(Boolean));
          for (const deleted of git('ls-files', '--deleted', '-z').split('\0')) files.delete(deleted);
          try { report.code_state.commit = git('rev-parse', 'HEAD').trim(); } catch { /* A new repository may have no commit yet. */ }
          report.code_state.working_tree_status = git('status', '--porcelain').trim();
          for (const file of [...files].filter((name) => name.endsWith('.md')).sort()) {
            const content = await readFile(path.join(root, file), 'utf8'); documents.set(file, content);
            report.code_state.files_sha256[file] = sha256(content);
          }
          for (const file of ['tools/check.mjs', 'tools/check-docs.mjs', 'tools/test-docs.mjs', 'tools/toolchain-config.mjs', 'tools/change-scope.mjs', 'tools/test-change-scope.mjs', '.github/workflows/check.yml']) {
            report.code_state.files_sha256[file] = sha256(await readFile(path.join(root, file)));
          }
          if (!documents.size) throw Error('No repository Markdown documents were found.');
          return { observed_status: 'pass', document_count: documents.size, files: [...documents.keys()] };
        }
        if (!files) throw Error('Repository sources could not be read.');
        const result = validateMarkdown(documents, files);
        item.status = result.errors.length ? 'fail' : 'pass';
        return { observed_status: item.status, ...result };
      };
      item.actual = await Promise.race([action(), new Promise((_, reject) => { deadline = setTimeout(() => reject(Error('Documentation check timed out.')), item.timeout_ms); })]);
      if (id === 'sources') item.status = 'pass';
    } catch (error) { item.actual = { observed_status: 'blocked', error: String(error) }; }
    finally { clearTimeout(deadline); }
    await writeFile(path.join(root, item.log_path), JSON.stringify(item.actual, null, 2) + '\n');
    if (item.status !== 'pass') item.error_id = `ERR-DOCS-${id.toUpperCase()}`;
    report.checks.push(item);
  }
  report.status = report.checks.some((item) => item.status === 'blocked') ? 'blocked' : report.checks.some((item) => item.status === 'fail') ? 'fail' : 'pass';
  report.summary = { expected: 2, executed: report.checks.length, matched: report.checks.filter((item) => item.status === 'pass').length,
    unexpected: report.checks.filter((item) => item.status !== 'pass').map(({ id, status, error_id }) => ({ id, status, error_id })), missing: [] };
  report.time.finished_at = new Date().toISOString(); report.time.duration_ms = Date.now() - started.getTime();
  report.reason = report.status === 'pass' ? 'Documentation structure checks completed; see evidence_limit.' : 'Documentation checks did not complete successfully; read the linked logs.';
  const reportPath = path.join(runDir, 'report.json');
  await writeFile(reportPath, JSON.stringify(report, null, 2) + '\n');
  const saved = JSON.parse(await readFile(reportPath, 'utf8'));
  if (saved.run_id !== runId || saved.checks.length !== 2) throw Error('Saved documentation report is incomplete.');
  const pointer = path.join(root, 'artifacts/test-runs/latest.json'), temporary = `${pointer}.${runId}.tmp`;
  await writeFile(temporary, JSON.stringify({ schema_version: 1, run_id: runId, scope: 'docs', status: report.status, report_path: relative(reportPath), finished_at: report.time.finished_at }, null, 2) + '\n');
  await rename(temporary, pointer);
  console.log(JSON.stringify({ run_id: runId, status: report.status, report_path: relative(reportPath), summary: report.summary }));
  process.exitCode = report.status === 'pass' ? 0 : 1;
  return report;
}
