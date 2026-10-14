# 网店账本 UI 实现规范

状态：用户授权由开发者决定设计，明确采用 Apple 风格并兼容系统安全区；已完成的网页原型仍不是 Flutter 应用。

## 设计依据与定位

- 工作台：用户本机 Open Design 0.24.1；项目 `PersonalFinancesPro · UI规划`，ID `4e9536c2-a3f8-4c3f-acd9-11eae8f64a62`。
- 使用内置 frontend-design 与 Apple 设计系统作为视觉参考。apple-hig 目录目前是指向上游的目录项，不宣称已安装完整 HIG 工作流。
- Apple 设计系统提取自官网，不直接等同于 iOS App HIG。本项目采用 iOS 分组列表、大标题、原生分段控件和标签栏；不照搬官网的产品照片、80px 标题和营销布局。
- 正式 App 使用 Flutter Cupertino 组件实现 Apple 风格，两端视觉一致；Android 保留系统返回、键盘与系统导航行为，不伪装为 iPhone。
- 不嵌入 HTML 原型，不启动外部设计代理，不打包 Apple 专有 SF Pro 字体或 SF Symbols 资源。iOS 使用系统字体；Android 使用合法的平台字体和 Flutter Cupertino 图标包。

## 首页信息判断

电商平台承担主要收入，而本账本暂不接平台账务。大量支出是统计边界造成的常态，不是亏损证据。

首页依次展示：

1. **本月实付支出**：主指标，使用中性深色大金额，不显示负号或亏损红色。
2. **当前厂家待付款**：独立的存量指标，不与当月支出相加；点击查看采购单。
3. **本月问题件回收**：仅问题件二次销售实收，普通收入和厂家退款不能混入。
4. **支出分类与最近账单**：说明花在哪里、付给谁、归属哪家店。
5. 快递记录余额放在快递预付视图，不塞入首页主金额，避免让充值资产与现金支出混淆。

平台外收入、支出和收支差额保留在账本的次级汇总中；不在首页突出差额。明确“不含平台收入，不代表利润或亏损”。厂家退款另列，不能伪装为问题件销售。

## 视觉与人体感受

- 方向：安静、清晰的经营工具，而非营销海报。少装饰、分组白底、柔和页面灰、单一蓝色操作信号。
- 大标题 32，主金额 38，正文 17，辅助信息 13–15，底部标签 11–12；等宽数字便于金额扫描。
- 页面留白 16，组内留白 16–20，组间距 16；卡片圆角 18、输入框与按钮 12。分隔线细而低对比，无厚边框和大阴影。
- 普通支出是中性色；绿色用于回收款，红色只用于错误、作废或真正需要注意的状态。方向另有收入/支出文字和正负符号，不只靠颜色。
- 常用动作在拇指可达区域，四个固定主入口保持顺序；新增采用清晰的文字按钮，不用遮住账单的悬浮按钮。
- 最小点击区域 48×48 logical pixels，覆盖 iOS 与 Android；减少动画时关闭非必要过渡。
- 不截断金额，长交易名称可换行；字号增大时内容滚动，不强制压缩系统文字。

### App 语义 token

| 角色 | 浅色 | 深色 |
|---|---|---|
| background | #F2F2F7 | #000000 |
| groupedSurface | #FFFFFF | #1C1C1E |
| label / 普通支出 | #1D1D1F | #F5F5F7 |
| secondaryLabel | #636366 | #AEAEB2 |
| separator | #D2D2D7 | #38383A |
| link / selection | #0071E3 | #64A8FF |
| filledAction | #0071E3 | #0071E3 |
| onFilledAction | #FFFFFF | #FFFFFF |
| recovery | #207A35 | #30D158 |
| error | #D70015 | #FF6961 |

这些是面向本 App 的派生语义值，不声称逐项等于所有 iOS 版本的系统色。正式 Flutter 通过 CupertinoDynamicColor/CupertinoTheme 按环境解析，不在页面散落颜色常量。

## 系统高度与安全区：单一负责者

### 状态栏与顶部

- 使用 MediaQuery 的实际 inset。正式版由 Cupertino 导航栏/大标题栏处理顶部状态栏，页面不再叠加相同 SafeArea。
- 横向刘海与挖孔同样通过实际 left/right inset 处理，内容留白至少 16。
- 不写死 20、24、44、54 等状态栏高度；测试中的 54/34 仅为模拟设备条件，不是生产值。
- 明暗模式同步状态栏前景与页面背景；保留系统图标，不自行绘制时间、电量或刘海。

### 底部系统栏与 App 标签栏

- 系统手势区/三键导航区和 App 标签栏是两层，分别处理，不能把其中一层当作另一层。
- 标签栏由自身内容高度加实际底部安全区构成，安全区只加一次；App 内容区与标签栏采用正常布局分开，不覆盖账单或确认按钮。
- 若采用 go_router 的 StatefulNavigationShell，不将同一个 shell 放进 CupertinoTabScaffold 的四个 tabBuilder；使用单一 shell 配合 CupertinoTabBar，避免多次挂载。
- CupertinoTabBar 自身负责实际底部 inset，footer 外不再叠加 bottom SafeArea，避免默认标签栏重复消耗。
- 标签栏显示时，Shell 的 Expanded 分支内容通过 MediaQuery.removePadding(removeBottom:true) 移除已由 footer 负责的 bottom padding，但保留 viewInsets；页面自身负责顶部导航与左右安全区。键盘出现、标签栏隐藏时不再删除不存在的 footer inset。
- 不用固定的 bottom:92 或 paddingBottom:150 估计标签栏占用，也不将整页 height 直接设为屏幕高度减一个常数。

### 键盘与弹层

- keyboard inset 来自 MediaQuery.viewInsets.bottom，与系统底部 viewPadding 区分。
- 键盘弹出时隐藏主标签栏；页面由 CupertinoPageScaffold 的 resizeToAvoidBottomInset 负责收缩一次。
- 表单使用滚动布局，聚焦字段和保存操作可滚动到键盘上方；不能整页再叠加一遍键盘高度。
- 弹层与全屏表单保留实际安全区；取消脏表单需确认。Android 返回与 iOS 返回手势不能丢失编辑内容而不提示。
- 网页原型通过 CSS env(safe-area-inset-*) 和正常布局展示安全区规则；它无法证明真机键盘和系统栏兼容。真机验证属于 Flutter 实施阶段。

## 页面与 Cupertino 映射

### 首页

- 大标题、店铺选择与期间，白色支出主卡；厂家待付款和问题件回收为第二级双列卡。
- 简洁业务入口：采购付款、问题件收入、快递预付。
- 分组最近账单，默认支出中性色，收入带正号和小范围绿色。
- CupertinoSliverNavigationBar、CupertinoButton、CupertinoListSection/Tile；金额不用自绘图表。

### 账本

- CupertinoSlidingSegmentedControl：现金账 / 采购单 / 快递预付。
- 店铺、收支筛选保留，列表按业务日期分组。闭合的次级汇总中展示平台外收入、支出与差额及范围提醒。
- 采购明确区分采购应付、已付款和待付；快递明确区分充值、消耗及记录余额。
- 账单详情可读，正式版提供编辑、作废、恢复和审计。原型不伪装这些功能已经可用。

### 手动记账

- 正式版使用滚动的 Cupertino 表单页面，而非固定高度浮窗；分类、日期、账户使用 Cupertino 选择方式。
- 金额整数分精确解析、最多两位小数；保存前校验方向、账户与归属。
- 采购、二次销售及关联费用、快递充值沿用业务文档，不因视觉调整改变金额口径。
- 原型只演示普通收支并存于内存，专用业务操作明确标为正式 App 提供。

### AI 记账

- 真正的消息式对话：可滚动的用户/AI 消息流，底部固定在布局内的多行输入栏和发送按钮；不再使用大表单加“生成草稿”入口。
- 正式 AI 区分记账、补充信息、修改未入账草稿、确认、取消和普通问答；普通问答不生成账目，平台内订单收入提示范围限制。
- 记账消息展示由校验后的结构化数据生成的 Markdown 表格，按钮由本地 UI 挂在消息底部，不执行 Markdown 里的动作。显示金额必须与实际提交金额一致。
- 信息缺失时在对话中追问，不可确认。用户补充后生成完整草稿；改店铺或金额时产生新版本，旧消息标记“已更新”，旧确认按钮失效。
- 首版同一会话只保留一个待确认草稿；另一笔新记账意图先询问如何处理旧草稿，不静默覆盖或确认旧账。
- 点击“确认入账”或输入明确的确认意图共用同一个草稿 ID/版本提交操作；入库成功才将原消息状态改为“已入账”。提交中和已入账按钮禁用。
- “先别确认”“确认之前改金额”等否定、修改或疑问不能触发入账；“好的”等含糊回应先澄清。重复确认只提示已处理，不再次写入。
- 确认后的账目若需修改，转入明确的账单编辑流程，不让后续普通聊天直接修改已入账记录。
- 原型仅用预置例句及规则演示上述消息流，没有真实模型、持久化或任意自然语言理解能力；仍不接收 Key。正式版接 DeepSeek 后由结构化意图和本地状态机配合执行，详细协议见产品文档第4节。
- 原型可试：发送“买纸箱280元”后回复“二店，微信”；或用问题件出售例句，回复“改成二店，运费改成25元”，再回复“确认这笔”。两种确认方式已通过模型、浏览器与 OpenDesign sandbox 预览检查。

### 设置

- iOS 风格分组列表：基础资料、AI、安全与数据、关于项目。
- CupertinoSwitch、CupertinoFormSection/TextFormFieldRow、CupertinoAlertDialog。
- 非敏感配置与 Key 分开；Key 安全存储，改服务地址显示接收主机并确认。
- 原型禁用配置、真实连接和备份操作，保留“正式 App 提供”的明确说明。

## 状态、响应式与验收

- 空：真实的零支出与“记第一笔”引导，不生成虚构增长率或亏损结论。
- 加载/失败：有独立状态、重试与数据保留，不清库兜底。
- 无匹配：保留筛选，与初次空账本区分。
- 保存中：禁用重复提交，失败保留输入；草稿已确认也禁用确认。
- 明暗主题、320/390/430 宽度、横向安全区和大字模式都纳入验收。
- 原型测试模拟 top/bottom：0/0、24/24、54/34，验证标签栏点击目标位于系统区之外，最后一行可滚动到标签栏上方。
- Flutter Widget 测试模拟实际 padding/viewPadding/viewInsets：刘海、Android 三键导航、手势导航、键盘与文字缩放；系统设备测试再确认真实 API 与手势。
- 原型验证命令：`node docs/ui/prototype/check.mjs` 和配置现有 puppeteer-core 后运行 `node docs/ui/prototype/browser-check.mjs`。
- 截图只含虚构数据，长图为设计交付，不冒充真机系统截图。

参考：

- CupertinoTabBar：https://api.flutter.dev/flutter/cupertino/CupertinoTabBar-class.html
- CupertinoPageScaffold：https://api.flutter.dev/flutter/cupertino/CupertinoPageScaffold-class.html
- MediaQueryData.viewInsets：https://api.flutter.dev/flutter/widgets/MediaQueryData/viewInsets.html
- SafeArea：https://api.flutter.dev/flutter/widgets/SafeArea-class.html
