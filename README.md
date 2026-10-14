# PersonalFinancesPro

面向多网店的平台外经营账本，计划使用 Flutter 支持 Android 与 iOS。

> 当前阶段：产品设计已确认，OpenDesign 原型已更新为 Apple 风格及消息式 AI 对话，Flutter 工程基础计划已同步。尚未初始化 Flutter 项目，没有可运行的 Android/iOS App。

## 首版范围

- 多店铺、厂家采购与付款、配件及包装采购。
- 退货问题件通过其他渠道出售的收入及关联费用。
- 外部快递充值与实际消耗分别记录，不重复计算现金支出。
- 本地收支统计、CSV 导出、完整备份与恢复。
- 自定义 DeepSeek API Key，识别对话核心意图、追问及修改草稿；记账回复呈现 Markdown 表格，消息内按钮或明确文字确认后记账并更新状态。

平台订单、平台退款和内部扣费暂不接入；平台外现金净额不是店铺利润。首页优先查看实付支出、厂家待付款和问题件回收，不突出负收支差额。

## 技术方向

Flutter stable、Cupertino Apple 风格、Clean 分层、纯 Dart 领域规则、SQLite 本地存储；参考 Flutter 官方架构指南及 Effective Dart。首版不提供账号、后台或自动跨设备同步。

详细范围、记账口径、安全约束及验收标准见：

- [首版设计文档](docs/superpowers/specs/2026-10-13-shop-ledger-design.md)
- [UI 实现规范](docs/ui/UI_DESIGN.md)
- [Flutter 工程基础计划](docs/superpowers/plans/2026-10-13-flutter-foundation.md)
- [Apple 风格与安全区调整](docs/superpowers/plans/2026-10-13-apple-ui-revision.md)
- [对话记账交互计划](docs/superpowers/plans/2026-10-13-conversation-ui.md)

## UI 预览

已在用户本机 OpenDesign App 更新 `PersonalFinancesPro · UI规划`，使用 frontend-design 与 Apple 设计系统作为参考。四入口为首页、账本、消息式 AI 对话和设置；使用灰白分组、大标题、克制蓝色操作，并按动态安全区布局。

AI 原型可以发送示例句，查看 Markdown 形式的表格、补充店铺/账户、修改运费，再点击消息内“确认入账”或回复“确认这笔”“记上吧”。成功后原消息变为已入账，旧版本与已提交按钮不能再次入账；普通对话和否定回复不会产生账目。

**这是限定例句/规则驱动的交互演示，不是真实 AI 判断。** 所有数据只在内存中，刷新重置；不接 DeepSeek，不接受 Key，不具备任意自然语言理解或数据库持久化。

无需 OpenDesign 也可本地查看导出的原型：

```sh
python3 -m http.server 8765 --bind 127.0.0.1 --directory docs/ui/prototype
# 浏览器打开 http://127.0.0.1:8765/index.html
```

[首页截图](docs/ui/screenshots/home.png) · [账本截图](docs/ui/screenshots/ledger.png) · [AI 对话截图](docs/ui/screenshots/ai-draft.png) · [设置截图](docs/ui/screenshots/settings.png)

网页原型只是 Flutter UI 实现参考，不会嵌入正式 App。已模拟9组宽度/上下安全区场景及聊天输入栏位置；真机系统栏、横向刘海、文字缩放与键盘仍需 Flutter Widget/设备验证，不能据此声称双端兼容已完成。

## 隐私

正式 App 的设计要求：账本存储在用户设备；AI 功能在用户同意后向所配置服务商发送本次任务所需内容，服务商可能收取 API 费用；API Key 使用系统安全存储，不随账本备份导出。上述能力尚未在 Flutter 中实现。

开源仅公开代码，不公开用户账本。不要向仓库提交真实财务数据、密钥、备份或签名文件。导出的备份包含经营数据，需要自行保管；未备份的数据可能在卸载后丢失。

## 开发与验证

| 交付项 | 当前状态 |
|---|---|
| 产品与架构设计 | 已确认 |
| OpenDesign Apple 风格/对话原型 | 已更新，并验证实际 sandbox 预览 |
| 原型金额、消息意图及浏览器交互检查 | 已通过；仍为虚构数据演示 |
| Flutter 双端工程、原生页面与 CI | 已有工程基础计划，尚未实现 |
| SQLite 账本、采购付款、快递预付 | 尚未实现 |
| 统计、导出、备份恢复 | 尚未实现 |
| DeepSeek 安全配置与对话记账 | 尚未实现 |
| Android/iOS 构建验证 | 尚未执行；环境存在待解决问题 |

原型模型检查使用 Node，无测试框架依赖：

```sh
node docs/ui/prototype/check.mjs
node docs/ui/prototype/check-chat.mjs
```

浏览器检查需要现有 puppeteer-core 和 Chrome；本次复用了 OpenDesign 自带依赖，没有添加 Flutter 运行依赖。可通过 `PUPPETEER_MODULE` 指定现有模块路径，通过 `CHROME_PATH` 指定 Chrome 可执行文件，再运行：

```sh
node docs/ui/prototype/browser-check.mjs
```

工程基础计划固定 Flutter stable 3.29.2（本机现有版本，非最新版本声明），使用该 SDK 自带 Dart，不使用 PATH 上不匹配的独立 Dart。当前不能运行 `flutter run` 或 Flutter 应用测试。

## License

[MIT](LICENSE)
