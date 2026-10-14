import assert from 'node:assert/strict';
import { existsSync } from 'node:fs';
import { createDemoState, totals } from './prototype-model.mjs';

const url = new URL('./prototype-chat.mjs', import.meta.url);
assert.ok(existsSync(url), 'Conversation bookkeeping model has not been implemented');
const { createDemoChat, sendDemoMessage, confirmDemoMessage } = await import(url);
const sale = '一店12件问题衣服卖给老王，微信收到360元，支付宝付20元运费';
const active = result => result.chat.messages.find(message => message.id === result.chat.activeDraftMessageId);

// Ordinary questions and confirmation without a draft cannot create cash records.
let result = sendDemoMessage(createDemoChat(), createDemoState(), '这个账本能判断我是否亏损吗？');
assert.equal(result.chat.activeDraftMessageId, null);
assert.equal(result.ledger.entries.length, 7);
result = sendDemoMessage(result.chat, result.ledger, '确认');
assert.equal(result.ledger.entries.length, 7);
assert.equal(result.chat.activeDraftMessageId, null);

// Missing shop/account must be clarified before a confirmable draft exists.
let missing = sendDemoMessage(createDemoChat(), createDemoState(), '买纸箱280元');
assert.ok(missing.chat.pendingInfo);
assert.equal(missing.chat.activeDraftMessageId, null);
missing = sendDemoMessage(missing.chat, missing.ledger, '确认');
assert.equal(missing.ledger.entries.length, 7);
missing = sendDemoMessage(missing.chat, missing.ledger, '二店，微信');
assert.equal(active(missing).status, 'pending');
assert.match(active(missing).markdown, /\| 项目 \| 内容 \|/);
assert.match(active(missing).markdown, /280\.00/);
assert.equal(active(missing).entries[0].shopId, 'shop2');
missing = confirmDemoMessage(missing.chat, missing.ledger, missing.chat.activeDraftMessageId);
assert.equal(missing.ledger.entries.length, 8);

// Draft preview changes no ledger data; denial, questions and vague assent cannot confirm.
result = sendDemoMessage(createDemoChat(), createDemoState(), sale);
const firstId = result.chat.activeDraftMessageId;
assert.equal(active(result).status, 'pending');
assert.equal(active(result).revision, 1);
assert.match(active(result).markdown, /360\.00/);
assert.match(active(result).markdown, /20\.00/);
assert.equal(result.ledger.entries.length, 7);
for (const text of ['先别确认', '确认之前改金额', '确认后还能改吗？', '好的']) {
  result = sendDemoMessage(result.chat, result.ledger, text);
  assert.equal(result.ledger.entries.length, 7, `unsafe confirmation: ${text}`);
  assert.equal(result.chat.activeDraftMessageId, firstId);
}
result = sendDemoMessage(result.chat, result.ledger, '二店买纸箱280元，微信支付');
assert.equal(result.chat.activeDraftMessageId, firstId, 'A second record must not silently replace the pending draft');

// Updating a draft expires the old message/version; stale confirmation must not save.
result = sendDemoMessage(result.chat, result.ledger, '改成二店，运费改成25元');
assert.notEqual(result.chat.activeDraftMessageId, firstId);
assert.equal(result.chat.messages.find(message => message.id === firstId).status, 'superseded');
assert.equal(active(result).revision, 2);
assert.equal(active(result).entries[0].shopId, 'shop2');
assert.equal(active(result).entries[1].cents, 2500);
assert.match(active(result).markdown, /25\.00/);
let stale = confirmDemoMessage(result.chat, result.ledger, firstId);
assert.equal(stale.ledger.entries.length, 7);

// Text confirmation and button confirmation share exactly-once commit and message state.
result = sendDemoMessage(result.chat, result.ledger, '确认这笔');
assert.equal(active(result).status, 'committed');
assert.doesNotMatch(active(result).text, /尚未入账/);
assert.equal(result.ledger.entries.length, 9);
assert.deepEqual(totals(result.ledger.entries, 'all'), { income: 200000, expense: 462500, net: -262500 });
result = sendDemoMessage(result.chat, result.ledger, '记上吧');
assert.equal(result.ledger.entries.length, 9);
// A new incomplete record must not bind confirmation to the previously saved record.
let incompleteAfterSave = sendDemoMessage(result.chat, result.ledger, '买纸箱280元');
assert.equal(incompleteAfterSave.chat.activeDraftMessageId, null);
incompleteAfterSave = sendDemoMessage(incompleteAfterSave.chat, incompleteAfterSave.ledger, '确认');
assert.match(incompleteAfterSave.chat.messages.at(-1).text, /信息还没补全/);
assert.equal(incompleteAfterSave.ledger.entries.length, 9);
incompleteAfterSave = sendDemoMessage(incompleteAfterSave.chat, incompleteAfterSave.ledger, sale);
assert.ok(incompleteAfterSave.chat.pendingInfo, 'A new intent must not erase missing-field context');
assert.equal(incompleteAfterSave.chat.activeDraftMessageId, null);
result = sendDemoMessage(result.chat, result.ledger, '二店买纸箱280元，微信支付');
assert.equal(active(result).status, 'pending');
const packagingId = result.chat.activeDraftMessageId;
result = confirmDemoMessage(result.chat, result.ledger, packagingId);
assert.equal(active(result).status, 'committed');
assert.doesNotMatch(active(result).text, /尚未入账/);
assert.equal(result.ledger.entries.length, 10);
result = confirmDemoMessage(result.chat, result.ledger, packagingId);
assert.equal(result.ledger.entries.length, 10);

// Explicit cancellation cannot leave a live confirm action behind.
let cancelled = sendDemoMessage(createDemoChat(), createDemoState(), sale);
const cancelledId = cancelled.chat.activeDraftMessageId;
cancelled = sendDemoMessage(cancelled.chat, cancelled.ledger, '取消这笔');
assert.equal(cancelled.chat.messages.find(message => message.id === cancelledId).status, 'cancelled');
cancelled = confirmDemoMessage(cancelled.chat, cancelled.ledger, cancelledId);
assert.equal(cancelled.ledger.entries.length, 7);
assert.throws(() => sendDemoMessage(createDemoChat(), createDemoState(), 'x'.repeat(2001)));
console.log('PASS: intent-safe conversations, missing-field follow-up, Markdown draft, revision invalidation, text/button shared exactly-once confirmation and cancellation');
