import { parseAmount, formatMoney, totals, commitDraft } from './prototype-model.mjs';

const shops = { shop1: '一店', shop2: '二店', public: '公共经营' };
const shopIds = { 一店: 'shop1', 二店: 'shop2', 公共经营: 'public' };
const SALE = '一店12件问题衣服卖给老王，微信收到360元，支付宝付20元运费';
const PACKAGING = '二店买纸箱280元，微信支付';

// ponytail: scripted demo intents only; Flutter will use DeepSeek structured intents.
export function createDemoChat() {
  return { nextId: 1, activeDraftMessageId: null, pendingInfo: null, messages: [
    { id: 'message-0', role: 'assistant', text: '告诉我一笔平台外收支，我会整理成表格，等你确认后再记账。当前是原型演示，未连接真实 AI。' },
  ] };
}

function copy(chat) {
  return { ...chat, messages: [...chat.messages], pendingInfo: chat.pendingInfo && { ...chat.pendingInfo } };
}

function append(chat, role, text, extra = {}) {
  const message = { id: `message-${chat.nextId++}`, role, text, ...extra };
  chat.messages.push(message);
  return message;
}

function reply(chat, ledger, text) {
  append(chat, 'assistant', text);
  return { chat, ledger };
}

function draftRows(entries) {
  const rows = [['日期', '2026-10-13（示例）'], ['归属店铺', shops[entries[0].shopId]]];
  for (const entry of entries) rows.push([
    entry.kind === 'income' ? '收入' : '支出',
    `${entry.title} · ¥${formatMoney(entry.cents)} · ${entry.account}`,
  ]);
  if (entries[0].note) rows.push(['交易说明', entries[0].note]);
  const sum = totals(entries);
  if (sum.income) rows.push(['净回收', `¥${formatMoney(sum.net)}（不是利润）`]);
  return rows;
}

function addDraft(chat, entries, previous = null) {
  totals(entries); // Reuse exact amount and shop validation before offering confirmation.
  const rows = draftRows(entries);
  const escape = text => text.replace(/\\/g, '\\\\').replace(/\|/g, '\\|').replace(/[\r\n]+/g, ' ');
  const markdown = ['| 项目 | 内容 |', '| --- | --- |', ...rows.map(([key, value]) => `| ${escape(key)} | ${escape(value)} |`)].join('\n');
  if (previous) chat.messages = chat.messages.map(message => message.id === previous.id ? { ...message, status: 'superseded', text: '这份草稿已被更新，请核对最新版本。' } : message);
  const message = append(chat, 'assistant', previous ? '已按你的补充更新草稿，请核对后确认。' : '已整理为以下表格，尚未入账。', {
    draftId: previous?.draftId || crypto.randomUUID(),
    revision: (previous?.revision || 0) + 1,
    status: 'pending', entries, rows, markdown,
  });
  chat.activeDraftMessageId = message.id;
  chat.pendingInfo = null;
}

function packagingEntries(id, info) {
  return [{ id: `${id}-packaging`, kind: 'expense', cents: 28000, shopId: info.shopId, title: '纸箱与包装袋（对话示例）', category: '配件包装', account: info.account, date: '2026-10-13', source: 'AI交互演示', note: '预置例句，无真实模型调用' }];
}

export function confirmDemoMessage(original, ledger, messageId) {
  const chat = copy(original);
  const message = chat.messages.find(item => item.id === messageId && item.status);
  if (!message || messageId !== chat.activeDraftMessageId) return reply(chat, ledger, '这条草稿已过期或不存在，请核对最新待确认消息。');
  if (message.status === 'committed') return reply(chat, ledger, '这笔已经入账（演示），不会重复记录。');
  if (message.status !== 'pending') return reply(chat, ledger, '这条草稿不能再确认，请先提供新的记账内容。');
  const saved = commitDraft(ledger, { id: message.draftId, entries: message.entries });
  chat.messages = chat.messages.map(item => item.id === messageId ? { ...item, status: 'committed', text: '这份表格已确认，账目已记入演示账本。' } : item);
  return reply(chat, saved, `已入账 ${message.entries.length} 笔（演示）。原消息状态已更新，可以继续记录下一笔。`);
}

export function sendDemoMessage(original, ledger, input) {
  if (typeof input !== 'string' || !input.trim() || input.length > 2000) throw new Error('消息请输入1至2000个字符');
  const chat = copy(original);
  const text = input.trim().replace(/[。！!]+$/g, '');
  append(chat, 'user', input.trim());
  const active = chat.messages.find(message => message.id === chat.activeDraftMessageId);
  if (/^(确认|确认这笔|确认入账|请确认这笔|记上吧|记下来吧|没问题[，, ]?记上)$/.test(text)) {
    if (!active) return reply(chat, ledger, chat.pendingInfo ? '信息还没补全，请先告诉我店铺和付款账户，再确认。' : '目前没有可确认的草稿，请先告诉我记账内容。');
    return confirmDemoMessage(chat, ledger, active.id);
  }
  if (/^(先别|不要|暂不|先不|先等等)/.test(text)) return reply(chat, ledger, active?.status === 'pending' ? '好的，保持待确认，不入账。你可以继续补充或修改。' : '好的，不新增账目。未补全的信息会保留；已入账记录请在账本中明确操作。');
  if (/^(取消这笔|不记了)$/.test(text)) {
    if (active?.status === 'pending') chat.messages = chat.messages.map(message => message.id === active.id ? { ...message, status: 'cancelled', text: '这份草稿已取消，没有写入账本。' } : message);
    chat.pendingInfo = null;
    if (active?.status === 'pending') chat.activeDraftMessageId = null;
    return reply(chat, ledger, active?.status === 'committed' ? '已入账记录不能通过聊天取消，请到账单详情操作。' : '已取消未入账的草稿，没有修改账本。');
  }
  if (/^(改成|改为|运费改成|运费改为)/.test(text)) {
    if (active?.status !== 'pending') return reply(chat, ledger, '当前没有可修改的待确认草稿；已入账账单请在账本中明确编辑。');
    const shop = text.match(/(?:改成|改为)(一店|二店|公共经营)/)?.[1];
    const freight = text.match(/运费(?:改成|改为)([\d.]+)元?/)?.[1];
    if (!shop && !freight) return reply(chat, ledger, '请明确修改内容，例如：改成二店，运费改成25元。');
    if (freight && !active.entries.some(entry => entry.category === '出货运费')) return reply(chat, ledger, '这笔草稿没有运费，请说明要修改哪个项目。');
    try {
      const cents = freight ? parseAmount(freight) : null;
      const entries = active.entries.map(entry => ({ ...entry, shopId: shop ? shopIds[shop] : entry.shopId, cents: entry.category === '出货运费' && cents !== null ? cents : entry.cents }));
      addDraft(chat, entries, active);
      return { chat, ledger };
    } catch (error) { return reply(chat, ledger, error.message); }
  }
  if (chat.pendingInfo) {
    const shop = text.match(/^(一店|二店|公共经营)(?:[，, ]|$)/)?.[1];
    const account = text.match(/(?:^|[，, ])(微信|支付宝|银行卡)$/)?.[1];
    if (shop || account) {
      if (shop) chat.pendingInfo.shopId = shopIds[shop];
      if (account) chat.pendingInfo.account = account;
      if (!chat.pendingInfo.shopId || !chat.pendingInfo.account) return reply(chat, ledger, '请继续补充店铺和付款账户，信息齐全后我再整理表格。');
      addDraft(chat, packagingEntries(crypto.randomUUID(), chat.pendingInfo));
      return { chat, ledger };
    }
  }
  if ([SALE, PACKAGING, '买纸箱280元'].includes(text)) {
    if (chat.pendingInfo || active?.status === 'pending') return reply(chat, ledger, chat.pendingInfo ? '上一笔还缺资料，请先补全或取消，再记另一笔；我不会覆盖原内容。' : '还有一笔待确认草稿。请先确认、修改或取消它，再记下一笔；我不会覆盖旧草稿。');
    if (text === '买纸箱280元') {
      chat.activeDraftMessageId = null;
      chat.pendingInfo = { shopId: null, account: null };
      return reply(chat, ledger, '这笔纸箱采购280元属于哪家店？用哪个账户付款？可以回复：二店，微信。');
    }
    const id = crypto.randomUUID();
    const entries = text === PACKAGING ? packagingEntries(id, { shopId: 'shop2', account: '微信' }) : [
      { id: `${id}-income`, kind: 'income', cents: 36000, shopId: 'shop1', title: '问题件二次销售（对话示例）', category: '问题件销售', account: '微信', date: '2026-10-13', source: 'AI交互演示', note: '老王，12件问题衣服，线下尾货' },
      { id: `${id}-freight`, kind: 'expense', cents: 2000, shopId: 'shop1', title: '关联运费（对话示例）', category: '出货运费', account: '支付宝', date: '2026-10-13', source: 'AI交互演示', note: '与二次销售收入同时确认' },
    ];
    addDraft(chat, entries);
    return { chat, ledger };
  }
  if (/确认|好的|可以/.test(text)) return reply(chat, ledger, '我没有确认入账。如果要提交最新草稿，请明确说“确认这笔”；要修改时请指定字段和金额。');
  return reply(chat, ledger, /利润|亏损|盈利|赚/.test(text) ? '平台主要收入尚未纳入，不能据此判断利润或亏损。这里只统计平台外支出与回收。' : '这是普通对话，没有创建账单。原型仅演示示例句、补充资料、修改及确认流程；正式版接入 DeepSeek 后识别更丰富的意图。');
}
