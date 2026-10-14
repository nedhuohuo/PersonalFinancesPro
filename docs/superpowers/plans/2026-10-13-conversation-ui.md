# Intent-driven Conversation Bookkeeping UI Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans for inline execution. Steps use checkbox (`- [ ]`) syntax for tracking; no unrequested delegation.

**Goal:** 将原型 AI 页面改成消息式对话，记账回复呈现 Markdown 表格，按钮和明确的文字确认共用草稿提交与消息状态更新。

**Architecture:** 复用现有整数分模型及 commitDraft。一个纯原型会话模块管理消息、待补充信息和一个活动草稿；过期消息不能提交。正式 Flutter 使用 DeepSeek 结构化意图和领域状态机，不把原型的规则演示冒充真实 AI。

**Tech Stack:** 现有 Apple 风格 HTML、JavaScript ES modules、Node assert、现有 puppeteer-core/Chrome、OpenDesign 本机工作台。

**Spec:** `docs/ui/UI_DESIGN.md` 的 AI 对话要求，以及产品设计文档的金额、入库和隐私约束。

## Global Constraints

- 消息流和底部输入栏采用 Apple 风格，继续正常布局与动态系统安全区。
- 草稿确认前不修改账本；确认成功后原 AI 消息状态改为已入账。
- 按钮确认与文字确认使用同一个草稿 ID、版本校验和一次性提交。
- 否定、疑问、修改或含糊回复不能因为含有“确认”而入账。
- 只允许修改未入账草稿，过期消息不可提交；一次只保留一个待确认草稿。
- 模型输出的表格只是展示；表格金额来自通过本地校验的结构化数据，不从 Markdown 反向解析金额入库。
- 原型没有真实模型、数据库或持久化，只演示限定例句；不接收真实 Key。

## Files and interfaces

- Create `docs/ui/prototype/prototype-chat.mjs`：`createDemoChat()`、`sendDemoMessage(chat, ledger, text)`、`confirmDemoMessage(chat, ledger, messageId)`；后两者返回 `{chat, ledger}`。
- Create `docs/ui/prototype/check-chat.mjs`：测试消息意图、补问、草稿 Markdown、版本失效和共用确认。
- Modify `index.html`：消息列表、消息状态、表格和确认按钮、底部消息输入栏。
- Modify `browser-check.mjs`：服务新模块，验证真实 DOM 对话与两种确认路径。
- Update UI/product docs、README、OpenDesign 文件和截图；同步原生 AI 阶段的语义，不改变工程基础尚未实施的状态。

## Task 1: Red checks for conversations

- [x] 在实现会话模块前写入并运行检查；模块缺失时明确失败。
- [x] 断言普通问答不创建草稿、记账生成带有效 Markdown 表格的 pending 消息、账本仍为7笔。
- [x] 断言“先别确认”和“确认之前改金额”不入账；补充店铺/账户后才产生可确认草稿。
- [x] 断言修改店铺/运费产生版本2，版本1为 superseded；确认旧消息仍为7笔。
- [x] 文字“确认这笔”增加2笔到9笔且原消息 committed；再次“记上吧”不增加。
- [x] 新通用包装支出草稿用按钮确认增加1笔；无草稿确认只返回澄清。

```js
const initial = createDemoState();
let result = sendDemoMessage(createDemoChat(), initial,
  '一店12件问题衣服卖给老王，微信收到360元，支付宝付20元运费');
const oldId = result.chat.activeDraftMessageId;
assert.equal(result.ledger.entries.length, 7);
result = sendDemoMessage(result.chat, result.ledger, '改成二店，运费改成25元');
assert.notEqual(result.chat.activeDraftMessageId, oldId);
const stale = confirmDemoMessage(result.chat, result.ledger, oldId);
assert.equal(stale.ledger.entries.length, 7);
result = sendDemoMessage(result.chat, result.ledger, '确认这笔');
assert.equal(result.ledger.entries.length, 9);
result = sendDemoMessage(result.chat, result.ledger, '记上吧');
assert.equal(result.ledger.entries.length, 9);
```

## Task 2: Message state and UI

- [x] 最小会话结构保存 messages、activeDraftMessageId、pendingInfo 和 nextId；无数据库或第三方状态框架。
- [x] 限定演示例句包括问题件收入/运费、二店纸箱采购和缺少资料的纸箱采购；规则演示明确标记，不声称任意自然语言识别。
- [x] Markdown 表格统一由结构化 entries 形成“项目/内容”两列表格，适合手机阅读；普通用户文字作为转义文本渲染，不执行 HTML。
- [x] 原型文字确认使用明确、完整的演示表达白名单，不用 includes('确认')；普通问答不改 ledger。
- [x] 发送消息、生成/修订草稿和确认时返回新会话状态；提交先校验活动消息及状态，再调用既有 commitDraft，更新原消息。
- [x] 消息流自身可滚动，输入栏作为同一个 flex 布局的底部子区域，保持发送按钮可见；不用在系统导航区定位绝对按钮。
- [x] 审核 pending/superseded/committed/cancelled 的不同消息状态和按钮禁用，使用示例标识，不给出虚假的真实入库成功。

## Task 3: Browser and handoff

- [x] 浏览器验证：发送例句、回复表格、否定不提交、修改旧版本禁用、文字确认原消息变更、重复确认不重复、另一草稿按钮确认、无脚本错误。
- [x] 保持已有支出指标、恢复款分类、安全区、手动输入和逃逸文本测试通过。摄取 AI 消息完整长图；图片只含虚构数据。
- [x] 通过本机 OpenDesign 更新当前项目的会话模块、HTML 和设计文档，检查文件哈希及实际对话预览。
- [x] 完整产品设计补充 DeepSeek 意图协议、最近必要上下文、Markdown 展示与结构化提交的分离、草稿状态机及幂等确认；正式 App 仍未实现。
- [x] 运行全部三个 Node 模型检查/浏览器检查及 git whitespace 检查，推送当前开发分支，不合并 main。
