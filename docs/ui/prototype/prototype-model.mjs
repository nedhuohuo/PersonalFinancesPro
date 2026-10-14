const LIMIT = 9000000000000000;
const SHOP_IDS = new Set(['shop1', 'shop2', 'public']);

export function parseAmount(text) {
  if (typeof text !== 'string') throw new Error('请输入金额');
  const match = /^(\d+)(?:\.(\d{1,2}))?$/.exec(text.trim());
  if (!match) throw new Error('金额必须为正数，最多两位小数');
  const cents = BigInt(match[1]) * 100n + BigInt((match[2] ?? '').padEnd(2, '0'));
  if (cents <= 0n || cents > BigInt(LIMIT)) throw new Error('金额超出允许范围');
  return Number(cents);
}

export function formatMoney(cents) {
  if (!Number.isSafeInteger(cents) || Math.abs(cents) > LIMIT) throw new Error('金额无效');
  const digits = BigInt(Math.abs(cents)).toString().padStart(3, '0');
  const whole = digits.slice(0, -2).replace(/\B(?=(\d{3})+(?!\d))/g, ',');
  return `${cents < 0 ? '-' : ''}${whole}.${digits.slice(-2)}`;
}

function validateEntry(entry) {
  if (!entry || !['income', 'expense'].includes(entry.kind)) throw new Error('收支类型无效');
  if (!Number.isSafeInteger(entry.cents) || entry.cents <= 0 || entry.cents > LIMIT) throw new Error('金额无效');
  if (!SHOP_IDS.has(entry.shopId)) throw new Error('请选择已存在的店铺');
}

export function totals(entries, shopId = 'all') {
  let income = 0n;
  let expense = 0n;
  for (const entry of entries) {
    validateEntry(entry);
    if (shopId !== 'all' && shopId !== entry.shopId) continue;
    if (entry.kind === 'income') income += BigInt(entry.cents);
    else expense += BigInt(entry.cents);
  }
  if (income > BigInt(LIMIT) || expense > BigInt(LIMIT)) throw new Error('汇总金额超出允许范围');
  return { income: Number(income), expense: Number(expense), net: Number(income - expense) };
}

export function createDemoState() {
  return { committedDraftIds: [], entries: [
    { id: 'supply-payment', kind: 'expense', cents: 200000, shopId: 'shop1', title: '宏达厂 · 采购付款', category: '厂家货款', account: '支付宝', date: '2026-10-13', source: '手动', note: '200件上衣；采购应付3,680元，已付2,000元' },
    { id: 'resale-income', kind: 'income', cents: 36000, shopId: 'shop1', title: '老王 · 问题件二次销售', category: '问题件销售', account: '微信', date: '2026-10-13', source: '手动', note: '12件瑕疵衣服，线下尾货渠道' },
    { id: 'resale-freight', kind: 'expense', cents: 2000, shopId: 'shop1', title: '二次销售 · 运费', category: '出货运费', account: '支付宝', date: '2026-10-13', source: '手动', note: '关联问题件销售；本次净回收340元，不是利润' },
    { id: 'packaging', kind: 'expense', cents: 28000, shopId: 'shop2', title: '纸箱与包装袋', category: '配件包装', account: '微信', date: '2026-10-13', source: '手动', note: '电商平台外采购' },
    { id: 'shipping-recharge', kind: 'expense', cents: 100000, shopId: 'shop2', title: '中通 · 快递单充值', category: '快递充值', account: '银行卡', date: '2026-10-13', source: '手动', note: '消耗记录不会再次计入现金支出' },
    { id: 'workspace-rent', kind: 'expense', cents: 130000, shopId: 'public', title: '公共仓库 · 租金', category: '其他经营', account: '银行卡', date: '2026-10-13', source: '手动', note: '公共经营支出，首版不自动分摊' },
    { id: 'resale-second', kind: 'income', cents: 128000, shopId: 'shop2', title: '尾货商 · 问题件二次销售', category: '问题件销售', account: '微信', date: '2026-10-13', source: '手动', note: '问题件通过其他渠道出售，记录实际收款' },
  ] };
}

export function commitDraft(state, draft) {
  if (!draft || typeof draft.id !== 'string' || !draft.id.trim()) throw new Error('草稿标识无效');
  if (state.committedDraftIds.includes(draft.id)) return state;
  if (!Array.isArray(draft.entries) || draft.entries.length === 0) throw new Error('草稿没有账单');
  const ids = new Set(state.entries.map(entry => entry.id));
  for (const entry of draft.entries) {
    validateEntry(entry);
    if (typeof entry.id !== 'string' || !entry.id.trim() || ids.has(entry.id)) throw new Error('账单标识重复或无效');
    ids.add(entry.id);
  }
  const entries = [...state.entries, ...draft.entries.map(entry => ({ ...entry }))];
  totals(entries);
  return { entries, committedDraftIds: [...state.committedDraftIds, draft.id] };
}
