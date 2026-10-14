# OpenDesign UI Prototype Implementation Plan

> 历史计划：下列 Material 风格描述是初版执行记录，已由 `2026-10-13-apple-ui-revision.md` 及 `2026-10-13-conversation-ui.md` 替代。当前正式依据为 `docs/ui/UI_DESIGN.md`，不再按旧 Material 布局实施。

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Native subagents are not authorized for this task; the current session uses the user's local OpenDesign App as the design workbench.

**Goal:** 使用本机 OpenDesign 产出可交互的移动端 UI 原型和 Flutter UI 实现依据，不把网页原型当作正式 App。

**Architecture:** 本机 OpenDesign 是设计预览工作台，当前会话使用其内置 frontend-design skill 与 Material 设计系统创作原型，不启动额外代理。原型使用独立的纯 JavaScript 示例模型，所有记录只保存在内存；Flutter 正式实现遵循已批准的 Clean 设计。

**Tech Stack:** OpenDesign 0.24.1、HTML/CSS、原生 JavaScript ES modules、Node assert；正式应用采用 Flutter Material 3。

**Spec:** `docs/superpowers/specs/2026-10-13-shop-ledger-design.md`

**Execution record:** 当前会话已按红绿测试完成原型，并通过 Node 模型检查、Chrome 交互检查、320/390/430px 布局检查及 OpenDesign 原型预览和文件哈希回读。尚未实现 Flutter 应用。

## Global Constraints

- 平台外现金净额不能称为店铺利润。
- 首版以人民币为唯一货币。
- 金额以整数分存储和计算，不用 `double` 处理金额。
- 原型只用虚构示例，不接收或保存 API Key，不请求真实 AI API，不写入真实账本。
- 原型不是 Android/iOS 应用；显示“示例数据 / 非正式 App”。
- 本机已创建的 OpenDesign 项目 ID：`4e9536c2-a3f8-4c3f-acd9-11eae8f64a62`。端口属于当前运行实例，不写入生产配置。

---

## File map

- `docs/ui/UI_DESIGN.md`：导航、视觉 token、页面区域、组件和状态规范，以及 Flutter 映射。
- `docs/ui/prototype/index.html`：四入口、记账弹层、详情和 AI 确认交互。
- `docs/ui/prototype/prototype-model.mjs`：虚构交易、精确金额解析、筛选统计和一次性草稿提交。
- `docs/ui/prototype/check.mjs`：Node 原生断言检查，独立于 Flutter 和 OpenDesign 进程。

## Task 1: UI contract

**Files:** Create `docs/ui/UI_DESIGN.md`.

**Interfaces:** Consumes approved business spec; produces color/spacing/component tokens and per-page behavior for prototype and Flutter.

- [ ] 定义四入口：首页、账本、AI 记账、设置。账本包含现金账、采购单和快递预付视图。
- [ ] 采用 OpenDesign Material `tokens.css` 的蓝色体系：primary `#1A73E8`、background `#F8FAFD`、surface `#FFFFFF`、text `#202124`、secondary text `#5F6368`、border `#DADCE0`、income `#188038`、expense `#D93025`。金额同时显示正负与收入/支出文字，不能仅靠颜色。
- [ ] 明确 Material 包中的 DESIGN.md 和 tokens.css 不一致：本项目以实际 tokens.css 为原型颜色来源，避免混用紫色及蓝色。
- [ ] 定义 4/8/12/16/24/32 间距、16 页面内边距、12 卡片圆角、48 最小点击目标；字体使用平台中文系统字体。
- [ ] 为各主入口及表单规定加载、空、错误、正常、编辑及确认状态；只在正式版提供真正存储和 API 调用。

## Task 2: Executable model check

**Files:** Create `docs/ui/prototype/check.mjs`, then `docs/ui/prototype/prototype-model.mjs`.

**Interfaces:**
- Produces `parseAmount(text: string): number`, `formatMoney(cents: number): string`.
- Produces `totals(entries: Array, shopId: string): {income: number, expense: number, net: number}`.
- Produces `createDemoState(): {entries: Array, committedDraftIds: Array<string>}`.
- Produces `commitDraft(state: Object, draft: {id: string, entries: Array}): Object`; a repeated draft ID returns the original state.

- [ ] Write the failing check first. Required assertions:

```js
assert.equal(parseAmount('18.00'), 1800);
assert.throws(() => parseAmount('18.005'));
assert.throws(() => parseAmount('-1'));
assert.throws(() => parseAmount('0'));
assert.equal(formatMoney(-296000), '-2,960.00');
assert.deepEqual(totals(createDemoState().entries, 'all'), {
  income: 164000, expense: 460000, net: -296000,
});
const initial = createDemoState();
const draft = { id: 'demo-confirmation', entries: [
  { id: 'new-income', kind: 'income', cents: 36000, shopId: 'shop1' },
  { id: 'new-freight', kind: 'expense', cents: 2000, shopId: 'shop1' },
] };
const saved = commitDraft(initial, draft);
assert.equal(saved.entries.length, initial.entries.length + 2);
assert.equal(commitDraft(saved, draft), saved);
```

- [ ] Run `node docs/ui/prototype/check.mjs`; verify it fails because the model has not been implemented, not because of a syntax error.
- [ ] Implement exact string-to-cents parsing with BigInt before converting to a safe integer; reject excessive precision, zero, negative, exponent notation and amounts over `9,000,000,000,000,000` cents. Format whole/fraction portions separately, without floating-point division.
- [ ] Seed seven fictional records: income 360/1280 yuan; expenses 2000/20/280/1000/1300 yuan. Compute overview from those records rather than hard-coded totals.
- [ ] Validate all draft entries before appending; reject duplicate IDs, unknown kind/shop, unsafe amount and overflow. Re-confirming the same draft never appends twice.
- [ ] Run the check and confirm all assertions pass.

## Task 3: Interactive prototype and OpenDesign handoff

**Files:** Create `docs/ui/prototype/index.html` and `docs/ui/prototype/browser-check.mjs`; keep `docs/ui/prototype/check.mjs` focused on real model behavior.

**Interfaces:** Consumes Task 2 exports; exposes four navigation buttons, shop selection, state selection, a manual entry form and a demo AI confirmation flow.

- [ ] Add runtime browser checks for four-page navigation, shop filtering, manual amount validation, escaped user text, disabled credential entry and no external requests. Use the existing OpenDesign puppeteer-core dependency and Chrome, not source-text assertions.
- [ ] Implement a responsive single mobile column with fixed bottom navigation and a persistent “记一笔” action. Desktop presents a mobile viewport with design-review controls; narrow screens fit without forcing a 390px minimum width.
- [ ] Navigation uses semantic buttons and `aria-current`; dialogs use native `<dialog>`, visible labels and cancellation. Respect `prefers-reduced-motion`.
- [ ] Provide shop filtering and normal/empty/loading/error preview states. Use native labelled inputs/selects and the exact amount parser rather than a UI dependency.
- [ ] Render user-entered text using textContent or escape it before templating; do not concatenate raw input into innerHTML.
- [ ] Manual form stores a demo entry only in memory. The AI view explains that it is a pre-scripted demonstration, generates a fixed labelled sample draft, and allows a single confirmation with duplicate protection.
- [ ] API credentials are disabled. Unimplemented export, real connection testing and other native-only actions are disabled and labelled, not fake-success buttons.
- [ ] Upload UI contract and prototype assets through the version-matched local OpenDesign project files API. Verify read-back hashes and preview availability; do not invoke chat/agent execution endpoints.
- [ ] Run `node docs/ui/prototype/check.mjs`, `node docs/ui/prototype/browser-check.mjs` with the installed puppeteer module path, and `git diff --check`. Review screenshots; verify the uploaded OpenDesign preview executes the module without script errors.
- [ ] Commit only project UI artifacts and docs, push to the approved public repository. Keep local app ports, personal configuration and logs out of production code.

## Review and next deliverable

用户可在 OpenDesign 中查看“PersonalFinancesPro · UI规划”。这些产物是 Flutter 页面实现依据，不是完整经营账本。UI 方向确认后，使用单独的工程基础计划实现 SDK 固定、双端工程、主题、路由、Clean 边界和最小测试/CI，再按业务依赖顺序实现后续阶段。
