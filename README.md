# PersonalFinancesPro

面向多网店的平台外经营账本，使用 Flutter 开发 Android 与 iOS 应用。

> 当前阶段：本地 SQLite 手动账本已实现，包含资料管理、现金账、采购与厂家付款/退款、期初欠款、问题件转卖、快递预付及轻量汇总。真实 AI、CSV、完整 JSON 备份/恢复、原生设备备份行为验证与商店发布不在本阶段；不能据此声称双端真机验收完成。

## 首版范围

- 多店铺、厂家采购与付款、配件及包装采购。
- 退货问题件通过其他渠道出售的收入及关联费用。
- 外部快递充值与实际消耗分别记录，不重复计算现金支出。
- 本地现金账筛选、首页快照及账本明细汇总；不是完整统计/报表系统。

后续范围：CSV 导出、完整 JSON 备份与恢复，以及自定义 DeepSeek API Key 的真实对话识别、草稿追问/修改、明确确认后入账。当前 Flutter 应用的 AI 发送、Key 配置与确认入账均禁用。

平台订单、平台退款、内部扣费和平台主营收入暂不接入，也不管理库存；平台外现金净额不是店铺利润。账户标签只标记收付款来源，不是银行/微信/支付宝真实余额。采购单与期初欠款本身不是现金支出，快递消耗不重复记现金支出；快递钱包余额是全局余额，不按店铺拆分。首页优先查看实付支出、厂家待付款和问题件回收，不突出负收支差额。

## 技术方向

Flutter stable 3.29.2、Cupertino Apple 风格、Clean 分层、纯 Dart 领域规则、SQLite 本地存储；参考 Flutter 官方架构指南及 Effective Dart。首版不提供账号、后台或自动跨设备同步。

数据依赖固定为运行时 `sqflite: 2.4.2`、`path: 1.9.1`；开发测试使用 `sqflite_common_ffi: 2.3.5`，在临时真实 SQL 文件上验证事务、关闭重开与关联汇总。金额以整数分存储/计算，业务日期为严格 `YYYY-MM-DD`，审计时间为 UTC。

本仓库固定 `.flutter-version` 为 `3.29.2`。使用任意已安装的同版本 Flutter SDK，并显式调用该 SDK 的命令：

```sh
export FLUTTER_SDK=/path/to/flutter-3.29.2
"$FLUTTER_SDK/bin/flutter" --version # 应显示 Flutter 3.29.2
"$FLUTTER_SDK/bin/dart" --version
```

详细范围、记账口径、安全约束及验收标准见：

- [首版设计文档](docs/superpowers/specs/2026-10-13-shop-ledger-design.md)
- [UI 实现规范](docs/ui/UI_DESIGN.md)
- [Flutter 工程基础计划](docs/superpowers/plans/2026-10-13-flutter-foundation.md)
- [本地账本实现计划](docs/superpowers/plans/2026-10-14-local-ledger.md)
- [Apple 风格与安全区调整](docs/superpowers/plans/2026-10-13-apple-ui-revision.md)
- [对话记账交互计划](docs/superpowers/plans/2026-10-13-conversation-ui.md)

## UI 预览

已在用户本机 OpenDesign App 更新 `PersonalFinancesPro · UI规划`，使用 frontend-design 与 Apple 设计系统作为参考。四入口为首页、账本、消息式 AI 对话和设置；使用灰白分组、大标题、克制蓝色操作，并按动态安全区布局。

AI 原型可以发送示例句，查看 Markdown 形式的表格、补充店铺/账户、修改运费，再点击消息内“确认入账”或回复“确认这笔”“记上吧”。成功后原消息变为已入账，旧版本与已提交按钮不能再次入账；普通对话和否定回复不会产生账目。

**这个网页 AI 原型是限定例句/规则驱动的交互演示，不是真实 AI 判断。** 网页演示数据只在内存中，刷新重置；不接 DeepSeek，不接受 Key，不具备任意自然语言理解或数据库持久化。它与已持久化的 Flutter 手动 SQLite 账本是两个独立入口，网页中的确认不会写入 Flutter 账本。

无需 OpenDesign 也可本地查看导出的原型：

```sh
python3 -m http.server 8765 --bind 127.0.0.1 --directory docs/ui/prototype
# 浏览器打开 http://127.0.0.1:8765/index.html
```

[首页截图](docs/ui/screenshots/home.png) · [账本截图](docs/ui/screenshots/ledger.png) · [AI 对话截图](docs/ui/screenshots/ai-draft.png) · [设置截图](docs/ui/screenshots/settings.png)

网页原型只是 Flutter UI 实现参考，不会嵌入正式 App。已模拟9组宽度/上下安全区场景及聊天输入栏位置；真机系统栏、横向刘海、文字缩放与键盘仍需 Flutter Widget/设备验证，不能据此声称双端兼容已完成。

## 功能完成状态

| 交付项 | 当前状态 |
|---|---|
| 产品与架构设计 | 已确认 |
| OpenDesign Apple 风格/对话原型 | 已更新，并验证实际 sandbox 预览 |
| Flutter 双端工程骨架 | 已初始化 |
| 纯 Dart 金额模型 | 已实现整数分，精确解析最多两位小数，超精度拒绝 |
| Cupertino 手动账本与资料页面 | 已实现首页、账本、AI、设置四入口；AI 仍禁用 |
| 领域边界检查与 CI | 已实现格式、边界、分析、全测试；Android debug 构建仅在 main 分支执行 |
| 本地 SQLite 与资料管理 | 已实现店铺、往来方、分类、账户标签、转卖渠道；支持停用并保留历史引用 |
| 普通现金账 | 已实现新增、编辑、筛选、作废/恢复；业务关联账由所属业务管理 |
| 采购、厂家付款/退款、期初欠款 | 已实现事务保存、关联现金账及生命周期校验 |
| 问题件转卖及关联费用 | 已实现独立费用账户、业务关联及净回收 |
| 快递预付 | 已实现期初余额、分店铺/公共充值与消耗、退款、全局记录余额 |
| 轻量快照与汇总 | 已实现现金收支、厂家待付、问题件回收和快递事件汇总；业务关联决定分类，不靠分类名称 |
| 完整统计/CSV、完整 JSON 备份恢复 | 后续阶段，尚未实现 |
| DeepSeek 安全配置与对话记账 | 后续阶段，尚未实现；Flutter 内 AI 发送/Key/确认保持禁用 |
| 原生备份排除证据 | 已有源码静态检查、通道模拟及数据库打开前拒绝测试；不是设备备份行为证明 |
| Android/iOS 原生验收与商店发布 | Android 工具链/许可验证独立；iOS 构建与双端设备验证明确延后；未发布 |

## 隐私

当前 Flutter 手动账本存储在设备本地，不向 AI 发送数据。数据库打开前必须获得已验证排除自动系统备份的实际目录；验证失败或目录不匹配会阻止打开/写入并显示错误，不清空或替换已有账本。Android 使用应用私有数据库目录与备份/迁移排除配置；iOS 原生通道设置并读回目录备份排除属性。现有测试仅覆盖源码静态配置、模拟通道和打开前拒绝语义，不证明真实 Android 云备份/设备迁移或 iOS/iCloud 备份行为，仍需独立设备验证。

真实 AI 与 Key 安全存储尚未实现；后续接入须经用户同意，仅发送本次任务所需内容，说明服务商 API 费用，并确保 Key 不进入账本备份。

开源仅公开代码，不公开用户账本。不要向仓库提交真实财务数据、密钥、备份或签名文件；数据库及 WAL/SHM、备份/导出目录、环境配置与签名密钥均有忽略规则。当前无完整备份/恢复入口，系统自动备份排除也不等于用户备份能力；卸载或设备损坏可能导致数据丢失。未来导出的备份含经营数据，需自行保管。

## 开发与验证

使用固定 SDK，不依赖 PATH 上的 Flutter/Dart：

```sh
export FLUTTER_SDK=/path/to/flutter-3.29.2
"$FLUTTER_SDK/bin/flutter" pub get
"$FLUTTER_SDK/bin/dart" format --output=none --set-exit-if-changed lib test tool
"$FLUTTER_SDK/bin/dart" run tool/check_domain_boundaries.dart
"$FLUTTER_SDK/bin/flutter" analyze
"$FLUTTER_SDK/bin/flutter" test
```

原型模型检查使用 Node，无测试框架依赖：

```sh
node docs/ui/prototype/check.mjs
node docs/ui/prototype/check-chat.mjs
```

浏览器检查需要现有 puppeteer-core 和 Chrome；本次复用了 OpenDesign 自带依赖，没有添加 Flutter 运行依赖。可通过 `PUPPETEER_MODULE` 指定现有模块路径，通过 `CHROME_PATH` 指定 Chrome 可执行文件，再运行：

```sh
node docs/ui/prototype/browser-check.mjs
```

## License

[MIT](LICENSE)
