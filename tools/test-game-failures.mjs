import assert from 'node:assert/strict';
import test from 'node:test';
import { classifyGameFailures } from './classify-game-failures.mjs';

const makeCase = (name, failures = [], errors = [], skipped = 0) => ({
  name, classname: 'test_contract.gd', failures, errors, skipped,
});
const classify = (...cases) => classifyGameFailures({ cases });

test('passing evidence has zero failed cases and preserves the original evidence', () => {
  const evidence = { cases: [makeCase('test_pass')], failures: 0, errors: 0 };
  const original = structuredClone(evidence);
  const result = classifyGameFailures(evidence);
  assert.equal(result.status, 'available');
  assert.equal(result.failed_cases, 0);
  assert.deepEqual(result.counts, { design_baseline: 0, mechanism: 0, mixed: 0, unclassified: 0 });
  assert.deepEqual(evidence, original);
});

test('design mismatches stay explicit diagnostics rather than becoming passes or approval', () => {
  const evidence = { cases: [makeCase('test_speed', ['DESIGN_BASELINE: expected 56, actual 72'])], failures: 1 };
  const original = structuredClone(evidence);
  const result = classifyGameFailures(evidence);
  assert.equal(result.failed_cases, 1);
  assert.equal(result.counts.design_baseline, 1);
  assert.equal(result.cases[0].category, 'design_baseline');
  assert.deepEqual(evidence, original);
  assert.equal(evidence.failures, 1);
});

test('mechanism failures and both labels in one GUT failure remain distinguishable', () => {
  const result = classify(
    makeCase('test_wall', ['MECHANISM: crossed solid wall']),
    makeCase('test_jump', ['DESIGN_BASELINE: height mismatch\nMECHANISM: release had no effect']),
  );
  assert.equal(result.counts.mechanism, 1);
  assert.equal(result.counts.mixed, 1);
  assert.deepEqual(result.cases[1].labels, ['design_baseline', 'mechanism']);
});

test('unlabeled failures, engine errors, and skips are unclassified rather than guessed from names', () => {
  const result = classify(
    makeCase('test_speed_design', ['Expected 56']),
    makeCase('test_collision_mechanism', [], ['Parse Error: missing class']),
    makeCase('test_skip', [], [], 1),
  );
  assert.equal(result.failed_cases, 3);
  assert.equal(result.counts.unclassified, 3);
  assert.equal(result.cases[2].skipped, 1);
});

test('labeled failure plus an unlabeled error is mixed and retains the unknown part', () => {
  const result = classify(makeCase('test_mixed', ['DESIGN_BASELINE: speed changed'], ['SCRIPT ERROR: Nil']));
  assert.equal(result.counts.mixed, 1);
  assert.deepEqual(result.cases[0].labels, ['design_baseline', 'unclassified']);
  assert.equal(result.cases[0].errors, 1);
});

test('incidental words do not count as explicit assertion labels', () => {
  const result = classify(makeCase('test_invalid_labels', ['NOT_DESIGN_BASELINE: text', 'MECHANISM changed']));
  assert.equal(result.counts.unclassified, 1);
});

test('missing, empty, and malformed reports cannot masquerade as clean evidence', () => {
  for (const evidence of [undefined, {}, { cases: [] }, { cases: [{}] },
    { cases: [makeCase('test_bad', [undefined])] }, { cases: [makeCase('test_bad', [], [], -1)] }]) {
    assert.throws(() => classifyGameFailures(evidence));
  }
});


test('real GUT layout supplements first-only XML, removes ANSI, and ignores passing assertions and repeated summary', () => {
  const evidence = { cases: [makeCase('test_walk', ['DESIGN_BASELINE: displacement'])] };
  const log = [
    'res://test_contract.gd', '* test_walk',
    '\u001b[32m    [Passed]:  \u001b[0mMECHANISM: accepted',
    '\u001b[31m    [Failed]:  \u001b[0mDESIGN_BASELINE: displacement', '      at line 12',
    '\u001b[31m    [Failed]:  \u001b[0mMECHANISM: velocity does not integrate', '      at line 16',
    '', '= Run Summary', 'res://test_contract.gd', '- test_walk',
    '    [Failed]:  MECHANISM: velocity does not integrate',
  ].join('\n');
  const result = classifyGameFailures(evidence, log);
  assert.equal(result.cases[0].category, 'mixed');
  assert.equal(result.cases[0].gut_log_failed_assertions, 2);
  assert.equal(result.cases[0].evidence_coverage, 'junit_and_gut_log');
  assert.deepEqual(evidence.cases[0].failures, ['DESIGN_BASELINE: displacement']);
});

test('supplemental failures bind to the exact suite and case rather than contaminating another case', () => {
  const log = 'res://another.gd\n* test_design\n    [Failed]: MECHANISM: other suite\n'
    + 'res://test_contract.gd\n* test_other\n    [Failed]: MECHANISM: other case\n';
  const result = classifyGameFailures({ cases: [makeCase('test_design', ['DESIGN_BASELINE: speed'])] }, log);
  assert.equal(result.cases[0].category, 'design_baseline');
  assert.equal(result.cases[0].gut_log_failed_assertions, 0);
  assert.equal(result.cases[0].evidence_coverage, 'junit_only');
  assert.match(result.evidence_limit, /may be incomplete/);
});

test('multiline failure labels and unlabeled supplemental assertions retain all diagnostic categories', () => {
  const log = 'res://test_contract.gd\n* test_mixed\n    [Failed]: expected value\n'
    + '      MECHANISM: multiline message\n      at line 20\n    [Failed]: missing reference\n';
  const result = classifyGameFailures({ cases: [makeCase('test_mixed', ['DESIGN_BASELINE: size'])] }, log);
  assert.equal(result.cases[0].category, 'mixed');
  assert.deepEqual(result.cases[0].labels, ['design_baseline', 'mechanism', 'unclassified']);
});
