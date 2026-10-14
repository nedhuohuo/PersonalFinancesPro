# PersonalFinancesPro

面向多网店的平台外经营账本，计划使用 Flutter 支持 Android 与 iOS。

> 当前阶段：产品设计已确认，OpenDesign UI 原型已完成，正在评审 Flutter 工程基础计划。尚未初始化 Flutter 项目，没有可运行的 Android/iOS App。

## 首版范围

- 多店铺、厂家采购与付款、配件及包装采购。
- 退货问题件通过其他渠道出售的收入及关联费用。
- 外部快递充值与实际消耗分别记录，不重复计算现金支出。
- 本地收支统计、CSV 导出、完整备份与恢复。
- 自定义 DeepSeek API Key，对话生成草稿，确认后记账。

平台订单、平台退款和内部扣费暂不接入；平台外现金净额不是店铺利润。

## 技术方向

Flutter stable、Clean 分层、纯 Dart 领域规则、SQLite 本地存储；参考 Flutter 官方架构指南及 Effective Dart。首版不提供账号、后台或自动跨设备同步。

详细范围、记账口径、安全约束及验收标准见：

- [首版设计文档](docs/superpowers/specs/2026-10-13-shop-ledger-design.md)
- [UI 实现规范](docs/ui/UI_DESIGN.md)
- [Flutter 工程基础计划](docs/superpowers/plans/2026-10-13-flutter-foundation.md)

## UI 预览

已在用户本机 OpenDesign App 创建 `PersonalFinancesPro · UI规划`，使用内置 frontend-design 与 Material 设计系统。原型为蓝白紧凑工具风格，包含首页、账本、AI 草稿确认和设置；只保存内存示例，不连接 AI，也不接收 API Key。

无需 OpenDesign 也可本地查看导出的原型：

```sh
python3 -m http.server 8765 --bind 127.0.0.1 --directory docs/ui/prototype
# 浏览器打开 http://127.0.0.1:8765/index.html
```

[首页截图](docs/ui/screenshots/home.png) · [账本截图](docs/ui/screenshots/ledger.png) · [AI 草稿截图](docs/ui/screenshots/ai-draft.png) · [设置截图](docs/ui/screenshots/settings.png)

网页原型只是 Flutter UI 实现参考，不会嵌入正式 App。

## 隐私

正式 App 的设计要求：账本存储在用户设备；AI 功能在用户同意后向所配置服务商发送本次任务所需内容，服务商可能收取 API 费用；API Key 使用系统安全存储，不随账本备份导出。上述能力尚未在 Flutter 中实现。

开源仅公开代码，不公开用户账本。不要向仓库提交真实财务数据、密钥、备份或签名文件。导出的备份包含经营数据，需要自行保管；未备份的数据可能在卸载后丢失。

## 开发与验证

| 交付项 | 当前状态 |
|---|---|
| 产品与架构设计 | 已确认 |
| OpenDesign UI 原型 | 已完成，等待视觉复核 |
| 原型金额与浏览器交互检查 | 已通过 |
| Flutter 双端工程、原生页面与 CI | 已有工程基础计划，尚未实现 |
| SQLite 账本、采购付款、快递预付 | 尚未实现 |
| 统计、导出、备份恢复 | 尚未实现 |
| DeepSeek 安全配置与对话记账 | 尚未实现 |
| Android/iOS 构建验证 | 尚未执行；环境存在待解决问题 |

原型模型检查使用 Node，无测试框架依赖：

```sh
node docs/ui/prototype/check.mjs
```

浏览器检查需要现有 puppeteer-core 和 Chrome；本次复用了 OpenDesign 自带依赖，没有添加 Flutter 运行依赖。可通过 `PUPPETEER_MODULE` 指定现有模块路径，通过 `CHROME_PATH` 指定 Chrome 可执行文件，再运行：

```sh
node docs/ui/prototype/browser-check.mjs
```

工程基础计划固定 Flutter stable 3.29.2（本机现有版本，非最新版本声明），使用该 SDK 自带 Dart，不使用 PATH 上不匹配的独立 Dart。当前不能运行 `flutter run` 或 Flutter 应用测试。

## License

[MIT](LICENSE)
