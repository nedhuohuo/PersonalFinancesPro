# Apple-style Spending-first UI Revision Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans for current-session execution. Steps use checkbox (`- [ ]`) syntax for tracking. Do not delegate without operator authorization.

**Goal:** 将现有 OpenDesign 原型改为 Apple 风格、支出导向，并在浏览器验证动态顶部/底部安全区规则。

**Architecture:** 继续使用既有原型金额模型，不重写金额或记账规则。网页采用固定视口内的 flex 正常布局：顶部安全区、标题、可滚动内容、独立标签栏及底部系统安全区；正式 Flutter 采用 Cupertino + go_router 的单一导航 shell。

**Tech Stack:** 本机 OpenDesign Apple 设计系统、HTML/CSS、现有 JavaScript 模型与 Node 检查、现有 puppeteer-core/Chrome；正式 App 使用 Flutter Cupertino。

**Spec:** `docs/ui/UI_DESIGN.md`；业务口径来自 `docs/superpowers/specs/2026-10-13-shop-ledger-design.md`。

## Global Constraints

- 用户授权由开发者衡量视觉细节，明确采用 Apple 风格。
- 不把平台外收支差额当作利润或首页主指标。
- 首页本月实付支出不包含未付款采购；问题件回收不包含普通收入和厂家退款。
- 不写死系统状态栏或底部导航栏高度，不重复消费安全区。
- 原型只保存内存示例，不能声称已实现 Flutter 真机系统栏或键盘兼容。
- 不调用真实模型，不接收密钥，不添加 App 运行依赖。
- 当前目录分支 `feat/flutter-ledger` 开发，main 保持不变。

## Files

- Modify `docs/ui/prototype/index.html`：Apple 分组界面、支出主指标、正常布局、env 安全区。
- Modify `docs/ui/prototype/browser-check.mjs`：新的指标语义与安全区回归。
- Keep `docs/ui/prototype/prototype-model.mjs` and `check.mjs` money rules unchanged.
- Update `docs/ui/UI_DESIGN.md`, product spec, foundation plan and README to reflect Cupertino.
- Regenerate `docs/ui/screenshots/*.png`; upload updated UI and business docs to the existing local OpenDesign project.

## Task 1: Red tests for scope and safe areas

**Interfaces:** Existing `totals(entries, shopId)` and `formatMoney(cents)` stay unchanged. UI consumes `data-stat="expense"` and `data-stat="resale"`; net appears only in the ledger's collapsed summary.

- [ ] Replace homepage expectations with:

```js
assert.equal(await page.$eval('#home [data-stat="expense"]', e => e.textContent.trim()), '4,600.00');
assert.equal(await page.$eval('#home [data-stat="resale"]', e => e.textContent.trim()), '1,640.00');
assert.equal(await page.$('#home [data-stat="net"]'), null);
await page.select('#shop-filter', 'shop1');
assert.equal(await page.$eval('#home [data-stat="expense"]', e => e.textContent.trim()), '2,020.00');
assert.equal(await page.$eval('#home [data-stat="resale"]', e => e.textContent.trim()), '360.00');
```

- [ ] Simulate safe-area values with root CSS variables; test 0/0, 24/24 and 54/34 at 320/390/430 widths. Observe actual click-target rectangles rather than assert CSS source strings:

```js
await page.evaluate(([top, bottom]) => {
  document.documentElement.style.setProperty('--safe-top', `${top}px`);
  document.documentElement.style.setProperty('--safe-bottom', `${bottom}px`);
}, [54, 34]);
const positions = await page.evaluate(() => ({
  headerTop: document.querySelector('header').getBoundingClientRect().top,
  tabBottom: Math.max(...Array.from(document.querySelectorAll('nav button'),
    e => e.getBoundingClientRect().bottom)),
  contentBottom: document.querySelector('main').getBoundingClientRect().bottom,
  navTop: document.querySelector('nav').getBoundingClientRect().top,
}));
assert.ok(positions.headerTop >= 54);
assert.ok(positions.tabBottom <= 844 - 34);
assert.ok(positions.contentBottom <= positions.navTop);
```

- [ ] Add a generic 100-yuan income through the manual form; assert problem-item recovery remains 1,640 yuan and paid expense remains 4,600 yuan. Adjust subsequent record-count expectations for that real extra demo record.
- [ ] Run the browser check and confirm the new homepage assertion fails on the old prototype. Existing model check remains green.

## Task 2: Minimal Apple interface revision

- [ ] Replace the presentation markup/styles as a complete rewrite while preserving model imports and exact money validation.
- [ ] Use neutral grouped surfaces, large Apple-style title, monochrome spending and restrained blue controls. Non-interactive money cards are not disguised as buttons.
- [ ] Move “记一笔” into the header; remove the floating action that covers transactions. Navigation uses labelled icon/text controls with clear current state, not Material selection pills.
- [ ] Use `viewport-fit=cover`, CSS `env(safe-area-inset-*)`, a flex app with `height:100dvh`, and an `overflow:auto` content region. Footer is a normal flex child with actual bottom safe-area padding; no fixed bottom offsets or manually estimated content footer gap.
- [ ] Derive problem-item recovery with the existing totals function over income records in category `问题件销售`; cash difference remains in ledger details. All repeated metric nodes are updated consistently.
- [ ] Keep all existing functional scenarios and disabled native-only actions; escape user text, preserve once-only draft confirmation and do not accept real credentials.
- [ ] Run model and browser tests. Review regenerated screenshots for hierarchy, content clipping, neutral expense color and clear scope explanation.

## Task 3: Native design synchronization and publish

- [ ] Update foundation plan to CupertinoApp/CupertinoTheme, CupertinoTabBar, explicit single-owner safe areas and keyboard behavior. Update Widget test examples to target Cupertino tabs and synthetic view insets, not Material destinations.
- [ ] Update product spec and README, retaining the incomplete-app status. Mark the original Material prototype plan as superseded by this revision, not a competing source of truth.
- [ ] Switch the existing OpenDesign project designSystemId to `apple` through the local version-matched API, update only owned files, verify hashes and actual preview behavior.
- [ ] Verify format/whitespace, docs consistency, model/browser suites and remote commit equality. Push the existing development branch without merging main.
