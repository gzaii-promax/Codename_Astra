// Diagnostic labels only: this function never decides acceptance or changes JUnit evidence.
const labels = [
  ['design_baseline', /\bDESIGN_BASELINE:/],
  ['mechanism', /\bMECHANISM:/],
];

// GUT 9.7.1 XML may contain only the first failure for a failing case.
// Read the detailed execution section; the later summary repeats those assertions.
function gutFailureMessages(rawLog) {
  const result = new Map();
  let suite = null, name = null, pending = null;
  const flush = () => {
    if (pending && suite && name) {
      const key = JSON.stringify([suite, name]);
      const messages = result.get(key) ?? [];
      messages.push(pending.join('\n'));
      result.set(key, messages);
    }
    pending = null;
  };
  const lines = rawLog.replace(/\u001b\[[0-9;]*m/g, '').split(/\r?\n/);
  for (const line of lines) {
    if (/^= Run Summary/.test(line)) { flush(); break; }
    const suiteMatch = line.match(/^res:\/\/(.+\.gd)\s*$/);
    const testMatch = line.match(/^\* (test_\w+)\s*$/);
    const failedMatch = line.match(/^\s*\[Failed\]:\s*(.*)$/);
    if (suiteMatch) { flush(); suite = suiteMatch[1]; name = null; }
    else if (testMatch) { flush(); name = testMatch[1]; }
    else if (failedMatch) { flush(); pending = [failedMatch[1]]; }
    else if (/^\s*(?:\[[^\]]+\]:|--- Awaiting)/.test(line) || !line.trim()) flush();
    else if (pending && /^\s+/.test(line)) pending.push(line.trim());
    else flush();
  }
  flush();
  return result;
}

export function classifyGameFailures(evidence, rawGutLog = '') {
  if (typeof rawGutLog !== 'string') throw new Error('GUT log must be text.');
  const rawMessages = gutFailureMessages(rawGutLog);
  if (!Array.isArray(evidence?.cases) || evidence.cases.length === 0) {
    throw new Error('Classification requires nonempty parsed JUnit cases.');
  }
  const counts = { design_baseline: 0, mechanism: 0, mixed: 0, unclassified: 0 };
  const cases = [];
  for (const item of evidence.cases) {
    if (typeof item.name !== 'string' || typeof item.classname !== 'string'
        || !Array.isArray(item.failures) || !Array.isArray(item.errors)
        || ![...item.failures, ...item.errors].every((message) => typeof message === 'string')
        || !Number.isInteger(item.skipped) || item.skipped < 0) {
      throw new Error('Malformed JUnit case cannot be classified.');
    }
    if (!item.failures.length && !item.errors.length && !item.skipped) continue;
    const categories = new Set();
    const logMessages = rawMessages.get(JSON.stringify([item.classname, item.name])) ?? [];
    for (const message of [...item.failures, ...item.errors, ...logMessages]) {
      const matches = labels.filter(([, expression]) => expression.test(message));
      if (!matches.length) categories.add('unclassified');
      for (const [category] of matches) categories.add(category);
    }
    if (item.skipped) categories.add('unclassified');
    const category = categories.size === 1 ? [...categories][0] : 'mixed';
    counts[category] += 1;
    cases.push({
      name: item.name, classname: item.classname, category,
      labels: [...categories].sort(), failures: item.failures.length,
      errors: item.errors.length, skipped: item.skipped,
      gut_log_failed_assertions: logMessages.length,
      evidence_coverage: logMessages.length ? 'junit_and_gut_log' : 'junit_only',
    });
  }
  return {
    schema_version: 1, status: 'available',
    basis: 'Explicit failed-assertion labels only; diagnostics do not establish cause or user approval.',
    evidence_limit: 'GUT XML may retain only the first failing assertion. Matching detailed GUT log assertions supplement it; junit_only cases may be incomplete. Unreadable reports and engine failures still require raw-log review.',
    failed_cases: cases.length, counts, cases,
  };
}
