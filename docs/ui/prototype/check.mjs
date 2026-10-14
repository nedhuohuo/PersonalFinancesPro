import assert from 'node:assert/strict';
import { existsSync } from 'node:fs';

const modelUrl = new URL('./prototype-model.mjs', import.meta.url);
assert.ok(existsSync(modelUrl), 'UI prototype model has not been implemented');
const { parseAmount, formatMoney, totals, createDemoState, commitDraft } = await import(modelUrl);

// Catches lost cents, silent rounding, unsafe numbers and accidental sign acceptance.
assert.equal(parseAmount('18.00'), 1800);
assert.equal(parseAmount('0.01'), 1);
assert.equal(parseAmount(' 18.5 '), 1850);
assert.equal(parseAmount('90000000000000.00'), 9000000000000000);
for (const input of ['18.005', '-1', '0', '', '1e3', 'NaN', '1,000', '90000000000000.01']) {
  assert.throws(() => parseAmount(input), undefined, `must reject ${JSON.stringify(input)}`);
}
assert.equal(formatMoney(-296000), '-2,960.00');
assert.equal(formatMoney(9000000000000000), '90,000,000,000,000.00');
assert.equal(formatMoney(1), '0.01');

// Catches treating expense as income, hard-coded overview totals or broken shop filters.
const initial = createDemoState();
assert.deepEqual(totals(initial.entries, 'all'), { income: 164000, expense: 460000, net: -296000 });
assert.deepEqual(totals(initial.entries, 'shop1'), { income: 36000, expense: 202000, net: -166000 });
assert.deepEqual(totals(initial.entries, 'shop2'), { income: 128000, expense: 128000, net: 0 });
assert.deepEqual(totals([], 'all'), { income: 0, expense: 0, net: 0 });

// Catches partial saves, duplicate confirmations, duplicate IDs and invalid drafts.
const draft = { id: 'demo-confirmation', entries: [
  { id: 'new-income', kind: 'income', cents: 36000, shopId: 'shop1' },
  { id: 'new-freight', kind: 'expense', cents: 2000, shopId: 'shop1' },
] };
const saved = commitDraft(initial, draft);
assert.equal(saved.entries.length, initial.entries.length + 2);
assert.equal(initial.entries.length, 7);
assert.equal(commitDraft(saved, draft), saved);
assert.deepEqual(totals(saved.entries, 'all'), { income: 200000, expense: 462000, net: -262000 });
for (const invalid of [
  { id: 'empty', entries: [] },
  { id: 'duplicate-entry', entries: [draft.entries[0], draft.entries[0]] },
  { id: 'bad-second', entries: [draft.entries[0], { ...draft.entries[1], cents: 0 }] },
  { id: 'unknown-kind', entries: [{ ...draft.entries[0], kind: 'profit' }] },
  { id: 'unknown-shop', entries: [{ ...draft.entries[0], shopId: 'missing' }] },
  { id: 'unsafe-amount', entries: [{ ...draft.entries[0], cents: Number.MAX_SAFE_INTEGER + 1 }] },
  { id: 'reused-entry', entries: [initial.entries[0]] },
]) {
  assert.throws(() => commitDraft(initial, invalid));
  assert.equal(initial.entries.length, 7);
}
assert.throws(() => totals([
  { kind: 'income', cents: 9000000000000000, shopId: 'shop1' },
  { kind: 'income', cents: 1, shopId: 'shop1' },
], 'all'));
console.log('PASS: exact amounts, shop-filtered totals and atomic/idempotent demo draft confirmation');
